--  TitaniumHelp — hotkey reference popup for the Titanium Suite.
--
--  Bound to Alt+F1 inside TitaniumWM.  The displayed key table is
--  PRODUCED BY WASM: it runs `albwasm /opt/alb/keys.wasm help`, which
--  executes an ALB-authored WASM module whose alb.print_str host
--  import emits the text.  If the WASM path fails (module or shim
--  missing), a compiled-in fallback table keeps the popup useful.
--
--  Any key press or mouse click dismisses the window.
--
--  Ada 2012, bounded state, defensive X11 FFI — suite coding standard.

with Interfaces.C;          use Interfaces.C;
with Interfaces.C.Strings;
with System;
with Ada.Unchecked_Conversion;
with Ada.Text_IO;
with GNAT.OS_Lib;

with X11; use X11;

procedure Main is

   --------------------------------------------------------------------------
   --  Content (bounded)
   --------------------------------------------------------------------------
   Max_Lines  : constant := 64;
   Max_Cols   : constant := 72;
   subtype Line_Text is String (1 .. Max_Cols);
   type Line_Array is array (1 .. Max_Lines) of Line_Text;
   type Len_Array  is array (1 .. Max_Lines) of Natural;

   Lines    : Line_Array := (others => (others => ' '));
   Lens     : Len_Array  := (others => 0);
   Count    : Natural := 0;

   --------------------------------------------------------------------------
   --  Colours (match TitaniumIcons palette)
   --------------------------------------------------------------------------
   C_Box      : constant unsigned_long := 16#00202830#;
   C_Header   : constant unsigned_long := 16#00304860#;
   C_Text     : constant unsigned_long := 16#00E8E8E8#;
   C_Text_Hi  : constant unsigned_long := 16#00FFD080#;

   --------------------------------------------------------------------------
   --  Geometry
   --------------------------------------------------------------------------
   Char_W     : constant Interfaces.C.int := 6;
   Line_H     : constant Interfaces.C.int := 14;
   Pad        : constant Interfaces.C.int := 14;
   Header_H   : constant Interfaces.C.int := 26;

   --------------------------------------------------------------------------
   --  Built-in fallback table (kept in sync with wm_keys.adb bindings)
   --------------------------------------------------------------------------
   procedure Load_Fallback is
      procedure Put (S : String) is
      begin
         if Count < Max_Lines then
            Count := Count + 1;
            Lens (Count) := Natural'Min (S'Length, Max_Cols);
            Lines (Count) (1 .. Lens (Count)) :=
              S (S'First .. S'First + Lens (Count) - 1);
         end if;
      end Put;
   begin
      Put ("  Alt+1..0,-,=     workspace 1-12");
      Put ("  Alt+Shift+num    move window to workspace");
      Put ("  Alt+Left/Right   focus previous/next window");
      Put ("  Alt+Shift+arrows move window in stack");
      Put ("  Alt+Up/Down      stack height (resize mode)");
      Put ("  Alt+R            resize mode toggle");
      Put ("  Alt+M / Alt+H    monocle / tiled layout");
      Put ("  Alt+Ctrl+Space   toggle floating");
      Put ("  Alt+, / Alt+.    focus previous/next screen");
      Put ("  Alt+Shift+,/.    move window across screens");
      Put ("  Alt+Q / Shift+Q  close / force-kill window");
      Put ("  Alt+Enter        xterm");
      Put ("  Alt+D            run prompt");
      Put ("  Alt+F1           this help");
      Put ("  Alt+Shift+Esc    quit TitaniumWM");
      Put ("");
      Put ("  Alt+drag title   float + move window");
      Put ("  click or any key closes this window");
   end Load_Fallback;

   --------------------------------------------------------------------------
   --  WASM content: albwasm /opt/alb/keys.wasm help -> captured text
   --------------------------------------------------------------------------
   procedure Load_From_WASM is
      Out_File : constant String := "/tmp/titaniumhelp.txt";
      Args     : GNAT.OS_Lib.Argument_List (1 .. 2);
      OK       : Boolean;
      Rc       : Integer;
      F        : Ada.Text_IO.File_Type;
      Buf      : String (1 .. Max_Cols + 1);
      Last     : Natural;
   begin
      Args (1) := new String'("/opt/alb/keys.wasm");
      Args (2) := new String'("help");
      GNAT.OS_Lib.Spawn ("albwasm", Args, Out_File, OK, Rc);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));
      if not OK then
         return;
      end if;

      declare
         use Ada.Text_IO;
      begin
         Open (F, In_File, Out_File);
         while not End_Of_File (F) and then Count < Max_Lines loop
            Get_Line (F, Buf, Last);
            if Last > Max_Cols then
               Last := Max_Cols;
            end if;
            Count := Count + 1;
            Lens (Count) := Last;
            if Last > 0 then
               Lines (Count) (1 .. Last) := Buf (1 .. Last);
            end if;
         end loop;
         Close (F);
      exception
         when others =>
            if Is_Open (F) then Close (F); end if;
      end;
   exception
      when others =>
         null;   --  any spawn/IO failure: fallback text is used
   end Load_From_WASM;

   --------------------------------------------------------------------------
   --  X11 state
   --------------------------------------------------------------------------
   use type System.Address;

   Dpy  : Display_Ptr := System.Null_Address;
   Scr  : Interfaces.C.int := 0;
   Root : Window;
   G    : GC;
   Win  : Window;

   Win_W : Interfaces.C.int;
   Win_H : Interfaces.C.int;

   procedure Paint is
      Buf : Interfaces.C.char_array (0 .. Max_Cols - 1);
      Title : constant String := "TitaniumWM keys (Alt = modifier)";
   begin
      XClearWindow (Dpy, Win);

      --  header band + title
      XSetForeground (Dpy, G, C_Header);
      XFillRectangle (Dpy, Win, G, 0, 0,
                      unsigned (Win_W), unsigned (Header_H));
      XSetForeground (Dpy, G, C_Text_Hi);
      for I in Title'Range loop
         Buf (size_t (I - Title'First)) :=
           Interfaces.C.To_C (Title (I .. I), False) (0);
      end loop;
      XDrawString (Dpy, Win, G, Pad, 18, Buf,
                   Interfaces.C.int (Title'Length));

      --  body lines
      XSetForeground (Dpy, G, C_Text);
      for I in 1 .. Count loop
         if Lens (I) > 0 then
            for J in 1 .. Lens (I) loop
               Buf (size_t (J - 1)) :=
                 Interfaces.C.To_C (Lines (I) (J .. J), False) (0);
            end loop;
            XDrawString (Dpy, Win, G, Pad,
                         Header_H + Pad + Interfaces.C.int (I - 1) * Line_H,
                         Buf, Interfaces.C.int (Lens (I)));
         end if;
      end loop;
      XFlush (Dpy);
   end Paint;

   Attrs : aliased XSetWindowAttributes;
   Ev    : XEvent;

begin
   --  Try the WASM-sourced table first; fall back if it produced nothing.
   Load_From_WASM;
   if Count = 0 then
      Load_Fallback;
   end if;
   if Count = 0 then
      return;   --  nothing to show at all
   end if;

   declare
      C_Name : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("");
   begin
      Dpy := XOpenDisplay (C_Name);
      Interfaces.C.Strings.Free (C_Name);
   end;

   if Dpy = System.Null_Address then
      return;
   end if;

   Scr  := XDefaultScreen (Dpy);
   Root := XRootWindow (Dpy, Scr);
   G    := XDefaultGC (Dpy, Scr);

   --  Size to content, centred on screen
   Win_W := Pad * 2 + Char_W * 56;
   Win_H := Header_H + Pad * 2 + Interfaces.C.int (Count) * Line_H;

   Win := XCreateSimpleWindow
     (Dpy, Root,
      (XDisplayWidth (Dpy, Scr)  - Win_W) / 2,
      (XDisplayHeight (Dpy, Scr) - Win_H) / 2,
      unsigned (Win_W), unsigned (Win_H), 0, 0, C_Box);

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
   XChangeWindowAttributes (Dpy, Win,
                            CWOverrideRedirect or CWBackPixel,
                            Attrs'Access);

   XSelectInput (Dpy, Win,
                 ExposureMask or KeyPressMask or ButtonPressMask);

   declare
      WN : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("titanium-help");
   begin
      XStoreName (Dpy, Win, WN);
      Interfaces.C.Strings.Free (WN);
   end;

   XMapWindow (Dpy, Win);
   XRaiseWindow (Dpy, Win);
   --  override-redirect windows don't get passive focus — take it so
   --  any keypress can dismiss the popup
   XSetInputFocus (Dpy, Win, Revert_To_Parent, 0);
   XFlush (Dpy);
   Paint;

   --  Event loop: repaint on Expose, die on any key or click.
   loop
      XNextEvent (Dpy, Ev);
      if Ev.Type_Code = Expose then
         Paint;
      elsif Ev.Type_Code = KeyPress
        or else Ev.Type_Code = ButtonPress
      then
         exit;
      end if;
   end loop;

   XDestroyWindow (Dpy, Win);
   XCloseDisplay (Dpy);

exception
   when others =>
      if Dpy /= System.Null_Address then
         XCloseDisplay (Dpy);
      end if;
end Main;
