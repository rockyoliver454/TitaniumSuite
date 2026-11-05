--  TitaniumIcons — desktop icon daemon for the Titanium Suite.
--
--  Scans ~/Desktop/*.desktop, creates one override-redirect window per
--  entry (above TitaniumBG's wallpaper, below managed windows), draws a
--  label + glyph, and launches Exec on ButtonPress.
--
--  Ada 2012, bounded state, defensive X11 FFI — suite coding standard.

with Interfaces.C;          use Interfaces.C;
with Interfaces.C.Strings;
with System;
with Ada.Unchecked_Conversion;
with Ada.Real_Time;    use Ada.Real_Time;
with Ada.Text_IO;

with X11;           use X11;
with Desktop_Files; use Desktop_Files;

procedure Main is

   --------------------------------------------------------------------------
   --  Geometry
   --------------------------------------------------------------------------
   Icon_W      : constant Interfaces.C.int := 96;
   Icon_H      : constant Interfaces.C.int := 72;
   Icon_Gap    : constant Interfaces.C.int := 12;
   Margin_Left : constant Interfaces.C.int := 12;
   Margin_Top  : constant Interfaces.C.int := 12;

   --------------------------------------------------------------------------
   --  Colours (24-bit RGB)
   --------------------------------------------------------------------------
   C_Box      : constant unsigned_long := 16#00202830#;  --  dark slate
   C_Box_Hi   : constant unsigned_long := 16#00304860#;  --  glyph square
   C_Text     : constant unsigned_long := 16#00E8E8E8#;  --  near-white
   C_Text_Hi  : constant unsigned_long := 16#00FFD080#;  --  accent glyph

   --------------------------------------------------------------------------
   --  Click flash — curve comes from /opt/alb/flash.wasm via albwasm
   --  (flash.alb is the ALB-authored reference).  Sampled at 15 ms/frame.
   --------------------------------------------------------------------------
   Flash_Ms    : constant := 240;
   Frame_Ms    : constant := 15;
   Num_Frames  : constant := Flash_Ms / Frame_Ms;   --  16
   Flash_Tbl   : array (0 .. Num_Frames - 1) of unsigned_long;
   Flash_Start : array (1 .. Desktop_Files.Max_Icons) of Time;
   Flashing    : array (1 .. Desktop_Files.Max_Icons) of Boolean :=
                   (others => False);

   --------------------------------------------------------------------------
   --  State (bounded — never grows past Desktop_Files.Max_Icons)
   --------------------------------------------------------------------------
   Icons    : Desktop_Files.Icon_Table;
   Count    : Natural := 0;
   Wins     : array (1 .. Desktop_Files.Max_Icons) of Window;

   use type System.Address;

   Dpy   : Display_Ptr := System.Null_Address;
   Scr   : Interfaces.C.int := 0;
   Root  : Window;
   Icon_Gc    : GC;

   --------------------------------------------------------------------------
   --  Helpers
   --------------------------------------------------------------------------

   function To_Any is new Ada.Unchecked_Conversion (XEvent, XAnyEvent);

   --  Word-wrap a label onto ≤2 lines centred in Icon_W.  Very simple:
   --  break at the space nearest the middle; truncate at 18 chars/line.
   procedure Draw_Label (W : Window; Name : String) is
      Max_Chars : constant := 18;
      Buf : Interfaces.C.char_array (0 .. 63);
      L1  : constant String :=
        (if Name'Length <= Max_Chars
         then Name
         else Name (Name'First .. Name'First + Max_Chars - 1));
   begin
      for I in L1'Range loop
         Buf (size_t (I - L1'First)) :=
           Interfaces.C.To_C (L1 (I .. I), False) (0);
      end loop;
      --  rough centring: 6px/char for the default font
      XDrawString (Dpy, W, Icon_Gc,
                   (Icon_W - Interfaces.C.int (L1'Length) * 6) / 2,
                   Icon_H - 12,
                   Buf, Interfaces.C.int (L1'Length));
   end Draw_Label;

   --  Blend Base toward white by Level (0..255) per channel.
   function Blend_White (Base : unsigned_long; Level : Natural)
      return unsigned_long
   is
      L : constant unsigned_long := unsigned_long (Level);
      function Ch (Shift : Natural) return unsigned_long is
         B : constant unsigned_long := (Base / (2 ** Shift)) and 16#FF#;
      begin
         return B + (255 - B) * L / 255;
      end Ch;
   begin
      return (Ch (0) and 16#FF#)
         or (Ch (8) and 16#FF#) * 16#100#
         or (Ch (16) and 16#FF#) * 16#10000#;
   end Blend_White;

   --  WASM fallback curve (mirrors flash.alb) when the module can't run.
   function Curve (T : Natural) return Natural is
   begin
      if T < 30 then
         return T * 255 / 30;
      elsif T < 60 then
         return 255;
      elsif T < 240 then
         return 255 - (T - 60) * 255 / 180;
      else
         return 0;
      end if;
   end Curve;

   --  Pull the intensity table from /opt/alb/flash.wasm through the
   --  albwasm shim (16 samples, one per frame).  Falls back to Curve.
   procedure Load_Flash_Table is
      Rc : Interfaces.C.int;
      pragma Unreferenced (Rc);
      F  : Ada.Text_IO.File_Type;
      V  : Natural;
   begin
      Rc := System_Call (To_C
        ("for t in 0 15 30 45 60 75 90 105 120 135 150 165 180 195 210 225; do " &
         "albwasm /opt/alb/flash.wasm frame $t; done > /tmp/ti_flash 2>/dev/null"));
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "/tmp/ti_flash");
         for I in Flash_Tbl'Range loop
            V := Natural'Value (Ada.Text_IO.Get_Line (F));
            Flash_Tbl (I) := Blend_White (C_Box, (if V > 255 then 255 else V));
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            for I in Flash_Tbl'Range loop
               Flash_Tbl (I) := Blend_White (C_Box, Curve (I * Frame_Ms));
            end loop;
      end;
   end Load_Flash_Table;

   procedure Paint_Icon_At (I : Positive; Bg : unsigned_long) is
      W  : constant Window := Wins (I);
      Nm : constant String := Name_String.To_String (Icons (I).Name);
      Glyph_Buf : Interfaces.C.char_array (0 .. 7);
   begin
      XSetForeground (Dpy, Icon_Gc, Bg);
      XFillRectangle (Dpy, W, Icon_Gc, 0, 0, unsigned (Icon_W), unsigned (Icon_H));

      --  glyph square: 28x28 centred, first letter of the name
      XSetForeground (Dpy, Icon_Gc, C_Box_Hi);
      XFillRectangle (Dpy, W, Icon_Gc, (Icon_W - 28) / 2, 8, 28, 28);

      if Nm'Length > 0 then
         XSetForeground (Dpy, Icon_Gc, C_Text_Hi);
         Glyph_Buf (0) := Interfaces.C.To_C (Nm (Nm'First .. Nm'First), False) (0);
         XDrawString (Dpy, W, Icon_Gc, (Icon_W - 6) / 2, 27, Glyph_Buf, 1);
      end if;

      XSetForeground (Dpy, Icon_Gc, C_Text);
      Draw_Label (W, Nm);
      XFlush (Dpy);
   end Paint_Icon_At;

   procedure Paint_Icon (I : Positive) is
   begin
      Paint_Icon_At (I, C_Box);
   end Paint_Icon;

   --  Launch an Exec line.  .desktop field codes (%f, %u, ...) are
   --  stripped, then the command runs detached via /bin/sh so PATH
   --  lookup and quoting follow normal shell rules — the same pattern
   --  TitaniumWM's key spawns use, and the only reliable exec route
   --  in this environment.  The trailing '&' makes system() return
   --  immediately and the child reparents to init, so no zombies.
   procedure Launch (I : Positive) is
      Cmd       : constant String := Exec_String.To_String (Icons (I).Exec);
      Cmd_Buf   : String (1 .. 512);
      Cmd_Len   : Natural := 0;
      Skip_Next : Boolean := False;
      Rc        : Interfaces.C.int;
      pragma Unreferenced (Rc);
   begin
      if Cmd'Length = 0 then
         return;
      end if;

      for Ix in Cmd'Range loop
         if Skip_Next then
            if Cmd (Ix) = '%' and then Cmd_Len < Cmd_Buf'Last then
               Cmd_Len := Cmd_Len + 1;
               Cmd_Buf (Cmd_Len) := '%';
            end if;
            Skip_Next := False;
         elsif Cmd (Ix) = '%' then
            Skip_Next := True;
         elsif Cmd_Len < Cmd_Buf'Last then
            Cmd_Len := Cmd_Len + 1;
            Cmd_Buf (Cmd_Len) := Cmd (Ix);
         end if;
      end loop;

      if Cmd_Len = 0 then
         return;
      end if;

      declare
         Line : constant String :=
           (if Icons (I).Terminal
            then "xterm -e " & Cmd_Buf (1 .. Cmd_Len)
            else Cmd_Buf (1 .. Cmd_Len)) & " &";
      begin
         Rc := System_Call (To_C (Line));
      end;
   exception
      when others =>
         null;   --  spawn failure: icon stays, session lives
   end Launch;

   --------------------------------------------------------------------------
   --  Setup
   --------------------------------------------------------------------------
   Attrs   : aliased XSetWindowAttributes;
   Ev      : XEvent;
   Av      : XAnyEvent;
   Now     : Time;
   Elapsed : Natural;

begin
   Desktop_Files.Load_Desktop_Icons (Icons, Count);
   if Count = 0 then
      return;   --  nothing on the desktop; daemon exits silently
   end if;

   declare
      C_Name : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("");
   begin
      Dpy := XOpenDisplay (C_Name);
      Interfaces.C.Strings.Free (C_Name);
   end;

   if Dpy = System.Null_Address then
      return;   --  no X server: not our problem, exit quietly
   end if;

   Scr  := XDefaultScreen (Dpy);
   Root := XRootWindow (Dpy, Scr);
   Icon_Gc   := XDefaultGC (Dpy, Scr);

   Load_Flash_Table;

   --  override-redirect: stays out of the WM's hands entirely
   Attrs := (Background_Pixmap   => 0,
             Background_Pixel    => C_Box,
             Border_Pixmap       => 0,
             Border_Pixel        => 0,
             Bit_Gravity         => 0,
             Win_Gravity         => 0,
             Backing_Store       => 0,
             Backing_Planes      => 0,
             Backing_Pixel       => 0,
             Save_Under          => 0,
             Event_Mask          => 0,
             Do_Not_Propagate    => 0,
             Override_Redirect   => 1,
             Colormap            => 0,
             Cursor              => 0);

   for I in 1 .. Count loop
      Wins (I) := XCreateSimpleWindow
        (Dpy, Root,
         Margin_Left,
         Margin_Top + Interfaces.C.int (I - 1) * (Icon_H + Icon_Gap),
         unsigned (Icon_W), unsigned (Icon_H),
         0, 0, C_Box);

      XChangeWindowAttributes (Dpy, Wins (I),
                               CWOverrideRedirect or CWBackPixel,
                               Attrs'Access);

      XSelectInput (Dpy, Wins (I), ExposureMask or ButtonPressMask);

      declare
         WN : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String
             ("titanium-icon-" & Integer'Image (I));
      begin
         XStoreName (Dpy, Wins (I), WN);
         Interfaces.C.Strings.Free (WN);
      end;

      XMapWindow (Dpy, Wins (I));
      XLowerWindow (Dpy, Wins (I));   --  under managed apps
      Paint_Icon (I);
   end loop;

   XFlush (Dpy);

   --------------------------------------------------------------------------
   --  Event loop — polled so the click-flash can animate between events
   --------------------------------------------------------------------------
   loop
      while XPending (Dpy) > 0 loop
         XNextEvent (Dpy, Ev);
         if Ev.Type_Code = Expose then
            Av := To_Any (Ev);
            for I in 1 .. Count loop
               if Wins (I) = Av.Win then
                  Paint_Icon (I);
               end if;
            end loop;
         elsif Ev.Type_Code = ButtonPress then
            Av := To_Any (Ev);
            for I in 1 .. Count loop
               if Wins (I) = Av.Win then
                  Launch (I);
                  Flash_Start (I) := Clock;
                  Flashing (I) := True;
               end if;
            end loop;
         end if;
      end loop;

      --  animation tick (~66 fps while anything flashes)
      Now := Clock;
      for I in 1 .. Count loop
         if Flashing (I) then
            Elapsed := Natural (To_Duration (Now - Flash_Start (I)) * 1000.0);
            if Elapsed >= Flash_Ms then
               Flashing (I) := False;
               Paint_Icon (I);   --  restore normal look
            else
               Paint_Icon_At (I, Flash_Tbl (Elapsed / Frame_Ms));
            end if;
         end if;
      end loop;

      declare
         Ts  : aliased Timespec := (0, 15_000_000);
         Rc2 : Interfaces.C.int;
         pragma Unreferenced (Rc2);
      begin
         Rc2 := NanoSleep (Ts'Access, null);
      end;
   end loop;

exception
   when others =>
      null;   --  display loss / BadWindow: die quietly, respawn restarts us
end Main;
