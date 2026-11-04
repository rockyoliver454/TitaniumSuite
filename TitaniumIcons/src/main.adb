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
with GNAT.OS_Lib;

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

   procedure Paint_Icon (I : Positive) is
      W  : constant Window := Wins (I);
      Nm : constant String := Name_String.To_String (Icons (I).Name);
      Glyph_Buf : Interfaces.C.char_array (0 .. 7);
   begin
      XClearWindow (Dpy, W);

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
   end Paint_Icon;

   --  Launch an Exec line.  Split on whitespace (bounded, ≤8 args).
   procedure Launch (I : Positive) is
      Cmd  : constant String := Exec_String.To_String (Icons (I).Exec);
      Args : GNAT.OS_Lib.Argument_List (1 .. 8);
      N    : Natural := 0;
      P    : GNAT.OS_Lib.Process_Id;
      pragma Unreferenced (P);

      procedure Push (Tok : String) is
      begin
         if N < Args'Length and then Tok'Length > 0 then
            N := N + 1;
            Args (N) := new String'(Tok);
         end if;
      end Push;

      Start : Natural;
   begin
      if Cmd'Length = 0 then
         return;
      end if;

      --  whitespace-split
      Start := 0;
      for Ix in Cmd'Range loop
         if Cmd (Ix) /= ' ' and then Cmd (Ix) /= ASCII.HT then
            if Start = 0 then
               Start := Ix;
            end if;
         elsif Start /= 0 then
            Push (Cmd (Start .. Ix - 1));
            Start := 0;
         end if;
      end loop;
      if Start /= 0 then
         Push (Cmd (Start .. Cmd'Last));
      end if;

      if N = 0 then
         return;
      end if;

      --  Terminal entries go through xterm -e; direct exec otherwise.
      if Icons (I).Terminal then
         declare
            Full : GNAT.OS_Lib.Argument_List (1 .. N + 2);
         begin
            Full (1) := new String'("-e");
            for J in 1 .. N loop
               Full (J + 1) := Args (J);
            end loop;
            P := GNAT.OS_Lib.Non_Blocking_Spawn ("xterm", Full (1 .. N + 1));
         end;
      else
         P := GNAT.OS_Lib.Non_Blocking_Spawn (Args (1).all, Args (2 .. N));
      end if;

      for J in 1 .. N loop
         GNAT.OS_Lib.Free (Args (J));
      end loop;
   exception
      when others =>
         null;   --  spawn failure: icon stays, session lives
   end Launch;

   --------------------------------------------------------------------------
   --  Setup
   --------------------------------------------------------------------------
   Attrs : aliased XSetWindowAttributes;
   Ev    : XEvent;
   Av    : XAnyEvent;

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
   --  Event loop
   --------------------------------------------------------------------------
   loop
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
            end if;
         end loop;
      end if;
   end loop;

exception
   when others =>
      null;   --  display loss / BadWindow: die quietly, respawn restarts us
end Main;
