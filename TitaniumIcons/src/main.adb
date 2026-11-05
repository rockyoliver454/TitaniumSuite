--  TitaniumIcons — desktop icon daemon for the Titanium Suite.
--
--  Scans ~/Desktop/*.desktop, creates one override-redirect window per
--  entry (above TitaniumBG's wallpaper, below managed windows), draws a
--  label + glyph, and launches Exec on ButtonPress.
--
--  Features: left-click launches (with an ALB/WASM click-flash), drag
--  repositions icons, right-click opens a context menu (Open / Rename /
--  Color / Set Image / Properties).  Positions, colours and image
--  paths persist to ~/.config/titaniumicons/layout.conf — a flat,
--  backupable file — normalized 0..65535 via deskicons.wasm so they
--  survive resolution changes.
--
--  Ada 2012, bounded state, defensive X11 FFI — suite coding standard.

with Interfaces.C;          use Interfaces.C;
with Interfaces.C.Strings;
with System;
with Ada.Unchecked_Conversion;
with Ada.Text_IO;

with X11;           use X11;
with Desktop_Files; use Desktop_Files;
with Layout_Store;  use Layout_Store;
with Icon_Images;   use Icon_Images;

procedure Main is

   --------------------------------------------------------------------------
   --  Geometry
   --------------------------------------------------------------------------
   Icon_W      : constant Interfaces.C.int := 96;
   Icon_H      : constant Interfaces.C.int := 72;
   Icon_Gap    : constant Interfaces.C.int := 12;
   Margin_Left : constant Interfaces.C.int := 12;
   Margin_Top  : constant Interfaces.C.int := 12;
   Drag_Thresh : constant := 4;               --  px before press = move

   --------------------------------------------------------------------------
   --  Colours (24-bit RGB)
   --------------------------------------------------------------------------
   C_Box      : constant unsigned_long := 16#00202830#;  --  dark slate
   C_Box_Hi   : constant unsigned_long := 16#00304860#;  --  glyph square
   C_Text     : constant unsigned_long := 16#00E8E8E8#;  --  near-white
   C_Text_Hi  : constant unsigned_long := 16#00FFD080#;  --  accent glyph
   C_Menu_Bg  : constant unsigned_long := 16#00222A33#;
   C_Menu_Hi  : constant unsigned_long := 16#003A4A5C#;
   C_Menu_Ed  : constant unsigned_long := 16#00506A80#;
   C_Dlg_Bg   : constant unsigned_long := 16#00283038#;
   C_Field    : constant unsigned_long := 16#00141820#;
   C_Dark     : constant unsigned_long := 16#00101820#;

   --------------------------------------------------------------------------
   --  Click flash — curve from /opt/alb/flash.wasm via albwasm
   --------------------------------------------------------------------------
   Flash_Ms    : constant := 240;
   Frame_Ms    : constant := 15;
   Num_Frames  : constant := Flash_Ms / Frame_Ms;   --  16
   Flash_Tbl   : array (0 .. Num_Frames - 1) of unsigned_long;
   Flash_Start : array (1 .. Desktop_Files.Max_Icons) of Natural;
   Flashing    : array (1 .. Desktop_Files.Max_Icons) of Boolean :=
                   (others => False);

   --------------------------------------------------------------------------
   --  Icon palette — RGB values come from deskicons.wasm (loaded at
   --  startup); names are display-side only.
   --------------------------------------------------------------------------
   Num_Colors   : constant := 10;
   Color_Rgb    : array (0 .. Num_Colors - 1) of unsigned_long;
   Color_Fb     : constant array (0 .. Num_Colors - 1) of unsigned_long :=
     (16#00304860#, 16#002D6FBE#, 16#00E08020#, 16#008050B0#,
      16#0030A050#, 16#00C03030#, 16#00209090#, 16#00D0B020#,
      16#00D06090#, 16#00606870#);
   Color_Name   : constant array (0 .. Num_Colors - 1)
                    of String (1 .. 7) :=
     ("Default", "Blue   ", "Orange ", "Purple ", "Green  ",
      "Red    ", "Teal   ", "Yellow ", "Pink   ", "Gray   ");

   --------------------------------------------------------------------------
   --  State (bounded — never grows past Desktop_Files.Max_Icons)
   --------------------------------------------------------------------------
   Icons    : Desktop_Files.Icon_Table;
   Count    : Natural := 0;
   Wins     : array (1 .. Desktop_Files.Max_Icons) of Window;
   Pos_X    : array (1 .. Desktop_Files.Max_Icons) of Interfaces.C.int;
   Pos_Y    : array (1 .. Desktop_Files.Max_Icons) of Interfaces.C.int;
   Col_Idx  : array (1 .. Desktop_Files.Max_Icons) of Natural :=
                (others => 0);
   Pixmap_Of: array (1 .. Desktop_Files.Max_Icons) of Window :=
                (others => 0);

   Layout   : Layout_Store.Layout_Table;
   N_Layout : Natural := 0;

   use type System.Address;

   Dpy    : Display_Ptr := System.Null_Address;
   Scr    : Interfaces.C.int := 0;
   Root   : Window;
   Icon_Gc   : GC;
   Scr_W  : Interfaces.C.int := 1024;
   Scr_H  : Interfaces.C.int := 768;

   --------------------------------------------------------------------------
   --  Drag state
   --------------------------------------------------------------------------
   Drag_I      : Natural := 0;                 --  icon being dragged
   Drag_Off_X  : Interfaces.C.int := 0;
   Drag_Off_Y  : Interfaces.C.int := 0;
   Drag_SX     : Interfaces.C.int := 0;        --  press root coords
   Drag_SY     : Interfaces.C.int := 0;
   Drag_Moved  : Boolean := False;

   --------------------------------------------------------------------------
   --  Context menu
   --------------------------------------------------------------------------
   Menu_I      : Natural := 0;                 --  icon the menu belongs to
   Menu_Win    : Window := 0;
   Sub_Win     : Window := 0;
   Menu_X, Menu_Y : Interfaces.C.int := 0;
   Sub_X,  Sub_Y  : Interfaces.C.int := 0;
   Menu_Item_H : constant Interfaces.C.int := 22;
   Menu_Wd     : constant Interfaces.C.int := 150;
   Sub_Wd      : constant Interfaces.C.int := 130;
   Menu_Items  : constant array (1 .. 5) of String (1 .. 12) :=
     ("Open        ", "Rename...   ", "Color      >", "Set Image...",
      "Properties  ");
   Color_Item  : constant := 3;

   --------------------------------------------------------------------------
   --  Text-input dialog (rename / image path / property edit)
   --------------------------------------------------------------------------
   type Dlg_Kind is (Dlg_None, Dlg_Rename, Dlg_Image,
                     Dlg_Prop_Name, Dlg_Prop_Exec, Dlg_Prop_Icon);
   Dlg_Mode    : Dlg_Kind := Dlg_None;
   Dlg_Win     : Window := 0;
   Dlg_Icon    : Natural := 0;
   Dlg_Bad     : Boolean := False;             --  last input failed
   Dlg_Wd      : constant Interfaces.C.int := 330;
   Dlg_Ht      : constant Interfaces.C.int := 74;
   Buf         : String (1 .. 256);
   Buf_Len     : Natural := 0;
   Buf_Cur     : Natural := 0;                 --  caret index (0..Len)

   --------------------------------------------------------------------------
   --  Properties window
   --------------------------------------------------------------------------
   Prop_I      : Natural := 0;
   Prop_Win    : Window := 0;
   Prop_Sel    : Natural := 1;
   Prop_Wd     : constant Interfaces.C.int := 420;
   Prop_Rows   : constant := 6;
   Prop_Row_H  : constant Interfaces.C.int := 24;
   Prop_Ht     : constant Interfaces.C.int :=
                   Prop_Row_H * (Prop_Rows + 1) + 8;
   Prop_X, Prop_Y : Interfaces.C.int := 0;

   --------------------------------------------------------------------------
   --  Helpers
   --------------------------------------------------------------------------

   function To_Any is new Ada.Unchecked_Conversion (XEvent, XAnyEvent);
   function To_Btn is new Ada.Unchecked_Conversion (XEvent, XButtonEvent);
   function To_Key is new Ada.Unchecked_Conversion (XEvent, XKeyEvent);
   function To_Cfg is new Ada.Unchecked_Conversion (XEvent, XConfigureEvent);

   function Trim (V : Natural) return String is
      S : constant String := Integer'Image (V);
   begin
      return S (S'First + 1 .. S'Last);
   end Trim;

   procedure Draw_Text
     (W : Window; X, Y : Interfaces.C.int; S : String) is
      CB : Interfaces.C.char_array (0 .. S'Length - 1);
   begin
      for I in S'Range loop
         CB (size_t (I - S'First)) :=
           Interfaces.C.To_C (S (I .. I), False) (0);
      end loop;
      if S'Length > 0 then
         XDrawString (Dpy, W, Icon_Gc, X, Y, CB,
                      Interfaces.C.int (S'Length));
      end if;
   end Draw_Text;

   --  Word-wrap a label onto ≤2 lines centred in Icon_W.
   procedure Draw_Label (W : Window; Name : String) is
      Max_Chars : constant := 18;
      L1  : constant String :=
        (if Name'Length <= Max_Chars
         then Name
         else Name (Name'First .. Name'First + Max_Chars - 1));
   begin
      Draw_Text (W, (Icon_W - Interfaces.C.int (L1'Length) * 6) / 2,
                 Icon_H - 12, L1);
   end Draw_Label;

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

   --  Fallback curve (mirrors flash.alb).
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

   function Now_Ms return Natural is
      Ts : aliased Timespec;
      Rc : Interfaces.C.int;
      pragma Unreferenced (Rc);
   begin
      Rc := Clock_Gettime (1, Ts'Access);
      return Natural (Ts.Tv_Sec) * 1000 + Natural (Ts.Tv_Nsec / 1_000_000);
   end Now_Ms;

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

   --------------------------------------------------------------------------
   --  WASM-backed layout math — deskicons.wasm via albwasm, with a
   --  byte-identical Ada fallback so a missing module degrades, not dies.
   --------------------------------------------------------------------------

   function Encode_Pos (Coord, Dim : Interfaces.C.int) return Natural is
      V : Long_Long_Integer;
   begin
      if Dim <= 0 then return 0; end if;
      V := Long_Long_Integer (Coord) * 65535 / Long_Long_Integer (Dim);
      if V < 0 then return 0;
      elsif V > 65535 then return 65535;
      else return Natural (V);
      end if;
   end Encode_Pos;

   function Resolve_Pos (Nx, Dim, Isize : Interfaces.C.int) return Interfaces.C.int is
      V, Hi : Long_Long_Integer;
   begin
      Hi := Long_Long_Integer (Dim) - Long_Long_Integer (Isize);
      if Hi < 0 then Hi := 0; end if;
      V := Long_Long_Integer (Nx) * Long_Long_Integer (Dim) / 65535;
      if V < 0 then return 0;
      elsif V > Hi then return Interfaces.C.int (Hi);
      else return Interfaces.C.int (V);
      end if;
   end Resolve_Pos;

   --  One shell round-trip: encode (x,y) -> normalized via deskicons.wasm.
   --  Falls back to Encode_Pos when the module/shim can't run.
   procedure Encode_Wasm
     (X, Y : Interfaces.C.int; Nx, Ny : out Natural)
   is
      Rc : Interfaces.C.int;
      pragma Unreferenced (Rc);
      F  : Ada.Text_IO.File_Type;
      Line : String (1 .. 64);
      Len  : Natural;
      Sp   : Natural;
   begin
      Rc := System_Call (To_C
        ("echo `albwasm /opt/alb/deskicons.wasm encode_pos " &
         Trim (Natural (X)) & " " & Trim (Natural (Scr_W)) &
         "` `albwasm /opt/alb/deskicons.wasm encode_pos " &
         Trim (Natural (Y)) & " " & Trim (Natural (Scr_H)) &
         "` > /tmp/ti_enc 2>/dev/null"));
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "/tmp/ti_enc");
         Ada.Text_IO.Get_Line (F, Line, Len);
         Ada.Text_IO.Close (F);
         Sp := 1;
         while Sp <= Len and then Line (Sp) /= ' ' loop Sp := Sp + 1; end loop;
         Nx := Natural'Value (Line (1 .. Sp - 1));
         Ny := Natural'Value (Line (Sp + 1 .. Len));
      exception
         when others =>
            Nx := Encode_Pos (X, Scr_W);
            Ny := Encode_Pos (Y, Scr_H);
      end;
   end Encode_Wasm;

   --  Batch-resolve every icon's stored normalized position against
   --  the current screen size — one system() call for all icons.
   procedure Resolve_All_Wasm is
      InF, F : Ada.Text_IO.File_Type;
      Rc : Interfaces.C.int;
      pragma Unreferenced (Rc);
      Line : String (1 .. 96);
      Len  : Natural;
      S1, S2 : Natural;
      I      : Natural;
   begin
      --  input file: "<iconidx> <nx> <ny>" per line
      Ada.Text_IO.Create (InF, Ada.Text_IO.Out_File, "/tmp/ti_pos_in");
      for K in 1 .. Count loop
         declare
            B  : constant String :=
              Name_String.To_String (Icons (K).Base);
            LI : constant Natural := Find (Layout, N_Layout, B);
         begin
            if LI > 0 and then Layout (LI).Has_Pos then
               Ada.Text_IO.Put_Line (InF,
                 Trim (K) & " " & Trim (Layout (LI).Nx)
                 & " " & Trim (Layout (LI).Ny));
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (InF);

      Rc := System_Call (To_C
        ("while read i nx ny; do " &
         "x=$(albwasm /opt/alb/deskicons.wasm resolve_pos $nx " &
         Trim (Natural (Scr_W)) & " " & Trim (Natural (Icon_W)) &
         "); y=$(albwasm /opt/alb/deskicons.wasm resolve_pos $ny " &
         Trim (Natural (Scr_H)) & " " & Trim (Natural (Icon_H)) &
         "); echo \"$i $x $y\"; done < /tmp/ti_pos_in > /tmp/ti_pos_out 2>/dev/null"));

      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "/tmp/ti_pos_out");
      while not Ada.Text_IO.End_Of_File (F) loop
         Ada.Text_IO.Get_Line (F, Line, Len);
         S1 := 1;
         while S1 <= Len and then Line (S1) /= ' ' loop S1 := S1 + 1; end loop;
         S2 := S1 + 1;
         while S2 <= Len and then Line (S2) /= ' ' loop S2 := S2 + 1; end loop;
         if S2 <= Len then
            I := Natural'Value (Line (1 .. S1 - 1));
            if I >= 1 and then I <= Count then
               Pos_X (I) := Interfaces.C.int
                 (Natural'Value (Line (S1 + 1 .. S2 - 1)));
               Pos_Y (I) := Interfaces.C.int
                 (Natural'Value (Line (S2 + 1 .. Len)));
            end if;
         end if;
      end loop;
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (InF) then Ada.Text_IO.Close (InF); end if;
         if Ada.Text_IO.Is_Open (F) then Ada.Text_IO.Close (F); end if;
         --  per-icon Ada fallback below covers a failed batch
         for K in 1 .. Count loop
            declare
               B  : constant String :=
                 Name_String.To_String (Icons (K).Base);
               LI : constant Natural := Find (Layout, N_Layout, B);
            begin
               if LI > 0 and then Layout (LI).Has_Pos then
                  Pos_X (K) := Resolve_Pos
                    (Interfaces.C.int (Layout (LI).Nx), Scr_W, Icon_W);
                  Pos_Y (K) := Resolve_Pos
                    (Interfaces.C.int (Layout (LI).Ny), Scr_H, Icon_H);
               end if;
            end;
         end loop;
   end Resolve_All_Wasm;

   --------------------------------------------------------------------------
   --  Colour palette — load via deskicons.wasm, fallback to Color_Fb
   --------------------------------------------------------------------------
   procedure Load_Color_Table is
      Rc : Interfaces.C.int;
      pragma Unreferenced (Rc);
      F    : Ada.Text_IO.File_Type;
      Line : String (1 .. 64);
      Len  : Natural;
      P1, P2 : Natural;
   begin
      Rc := System_Call (To_C
        ("for i in 0 1 2 3 4 5 6 7 8 9; do " &
         "echo `albwasm /opt/alb/deskicons.wasm rgb $i 0` " &
         "`albwasm /opt/alb/deskicons.wasm rgb $i 1` " &
         "`albwasm /opt/alb/deskicons.wasm rgb $i 2`; " &
         "done > /tmp/ti_colors 2>/dev/null"));
      for K in Color_Rgb'Range loop
         Color_Rgb (K) := Color_Fb (K);
      end loop;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "/tmp/ti_colors");
         for K in Color_Rgb'Range loop
            exit when Ada.Text_IO.End_Of_File (F);
            Ada.Text_IO.Get_Line (F, Line, Len);
            P1 := 1;
            while P1 <= Len and then Line (P1) /= ' ' loop P1 := P1 + 1; end loop;
            P2 := P1 + 1;
            while P2 <= Len and then Line (P2) /= ' ' loop P2 := P2 + 1; end loop;
            if P2 <= Len then
               declare
                  R : constant Natural := Natural'Value (Line (1 .. P1 - 1));
                  G : constant Natural := Natural'Value (Line (P1 + 1 .. P2 - 1));
                  B : constant Natural := Natural'Value (Line (P2 + 1 .. Len));
               begin
                  Color_Rgb (K) := unsigned_long (R) * 65536
                                 + unsigned_long (G) * 256
                                 + unsigned_long (B);
               end;
            end if;
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then Ada.Text_IO.Close (F); end if;
      end;
   end Load_Color_Table;

   --------------------------------------------------------------------------
   --  Painting
   --------------------------------------------------------------------------
   procedure Paint_Icon_At (I : Positive; Bg : unsigned_long) is
      W  : constant Window := Wins (I);
      Nm : constant String := Name_String.To_String (Icons (I).Name);
      Tile_C : constant unsigned_long := Color_Rgb (Col_Idx (I));
      Lum    : constant Natural :=
        Natural ((Tile_C / 65536) and 16#FF#) * 30 / 100
        + Natural ((Tile_C / 256) and 16#FF#) * 59 / 100
        + Natural (Tile_C and 16#FF#) * 11 / 100;
      Glyph_Buf : Interfaces.C.char_array (0 .. 7);
   begin
      XSetForeground (Dpy, Icon_Gc, Bg);
      XFillRectangle (Dpy, W, Icon_Gc, 0, 0,
                      unsigned (Icon_W), unsigned (Icon_H));

      if Pixmap_Of (I) /= 0 then
         XCopyArea (Dpy, Pixmap_Of (I), W, Icon_Gc,
                    0, 0, 28, 28, (Icon_W - 28) / 2, 8);
      else
         XSetForeground (Dpy, Icon_Gc, Tile_C);
         XFillRectangle (Dpy, W, Icon_Gc,
                         (Icon_W - 28) / 2, 8, 28, 28);
         if Nm'Length > 0 then
            XSetForeground (Dpy, Icon_Gc,
              (if Lum > 140 then C_Dark else C_Text_Hi));
            Glyph_Buf (0) := Interfaces.C.To_C
              (Nm (Nm'First .. Nm'First), False) (0);
            XDrawString (Dpy, W, Icon_Gc,
                         (Icon_W - 6) / 2, 27, Glyph_Buf, 1);
         end if;
      end if;

      XSetForeground (Dpy, Icon_Gc, C_Text);
      Draw_Label (W, Nm);
      XFlush (Dpy);
   end Paint_Icon_At;

   procedure Paint_Icon (I : Positive) is
   begin
      Paint_Icon_At (I, C_Box);
   end Paint_Icon;

   --  Build (or rebuild) the image pixmap for icon I from its layout
   --  image path.  One XDrawPoints request per pixel — one-time cost.
   procedure Load_Icon_Pixmap (I : Positive) is
      B  : constant String := Name_String.To_String (Icons (I).Base);
      LI : constant Natural := Find (Layout, N_Layout, B);
      Buf : Icon_Images.Pixel_Buffer;
      Pt  : aliased XPoint_Array (0 .. 0);
      Depth : Interfaces.C.int;
   begin
      if LI = 0
        or else Exec_String.Length (Layout (LI).Image) = 0
      then
         return;
      end if;
      if not Load_Tile (Exec_String.To_String (Layout (LI).Image), Buf)
      then
         return;
      end if;
      Depth := XDefaultDepth (Dpy, Scr);
      if Pixmap_Of (I) /= 0 then
         XFreePixmap (Dpy, Pixmap_Of (I));
      end if;
      Pixmap_Of (I) := XCreatePixmap
        (Dpy, Wins (I), 28, 28, unsigned (Depth));
      for P in Buf'Range loop
         XSetForeground (Dpy, Icon_Gc, unsigned_long (Buf (P)));
         Pt (0).X := Interfaces.C.short (P mod 28);
         Pt (0).Y := Interfaces.C.short (P / 28);
         XDrawPoints (Dpy, Pixmap_Of (I), Icon_Gc,
                      Pt'Unchecked_Access, 1, 0);
      end loop;
   end Load_Icon_Pixmap;

   --------------------------------------------------------------------------
   --  Context menu
   --------------------------------------------------------------------------
   Menu_Ht : constant Interfaces.C.int := Menu_Item_H * 5 + 4;
   Sub_Ht  : constant Interfaces.C.int := Menu_Item_H * Num_Colors + 4;

   procedure Paint_Menu is
   begin
      if Menu_Win = 0 then return; end if;
      XSetForeground (Dpy, Icon_Gc, C_Menu_Bg);
      XFillRectangle (Dpy, Menu_Win, Icon_Gc, 0, 0,
                      unsigned (Menu_Wd), unsigned (Menu_Ht));
      XSetForeground (Dpy, Icon_Gc, C_Menu_Ed);
      XDrawRectangle (Dpy, Menu_Win, Icon_Gc, 0, 0,
                      unsigned (Menu_Wd - 1), unsigned (Menu_Ht - 1));
      XSetForeground (Dpy, Icon_Gc, C_Text);
      for It in Menu_Items'Range loop
         Draw_Text (Menu_Win, 10,
                    Interfaces.C.int (It) * Menu_Item_H - 6,
                    Menu_Items (It));
      end loop;
   end Paint_Menu;

   procedure Paint_Sub is
   begin
      if Sub_Win = 0 then return; end if;
      XSetForeground (Dpy, Icon_Gc, C_Menu_Bg);
      XFillRectangle (Dpy, Sub_Win, Icon_Gc, 0, 0,
                      unsigned (Sub_Wd), unsigned (Sub_Ht));
      XSetForeground (Dpy, Icon_Gc, C_Menu_Ed);
      XDrawRectangle (Dpy, Sub_Win, Icon_Gc, 0, 0,
                      unsigned (Sub_Wd - 1), unsigned (Sub_Ht - 1));
      for K in 0 .. Num_Colors - 1 loop
         XSetForeground (Dpy, Icon_Gc, Color_Rgb (K));
         XFillRectangle (Dpy, Sub_Win, Icon_Gc,
                         8, Interfaces.C.int (K) * Menu_Item_H + 6,
                         12, 12);
         XSetForeground (Dpy, Icon_Gc, C_Text);
         Draw_Text (Sub_Win, 28,
                    Interfaces.C.int (K + 1) * Menu_Item_H - 6,
                    Color_Name (K));
      end loop;
   end Paint_Sub;

   procedure Close_Menu is
   begin
      if Sub_Win /= 0 then
         XDestroyWindow (Dpy, Sub_Win);
         Sub_Win := 0;
      end if;
      if Menu_Win /= 0 then
         XUngrabPointer (Dpy, CurrentTime);
         XDestroyWindow (Dpy, Menu_Win);
         Menu_Win := 0;
      end if;
      Menu_I := 0;
   end Close_Menu;

   procedure Open_Sub is
      Attrs : aliased XSetWindowAttributes;
   begin
      Attrs := (others => 0);
      Attrs.Override_Redirect := 1;
      Attrs.Background_Pixel  := C_Menu_Bg;
      Sub_X := Menu_X + Menu_Wd - 2;
      Sub_Y := Menu_Y + Menu_Item_H * (Color_Item - 1) + 2;
      --  keep the submenu on-screen
      if Sub_X + Sub_Wd > Scr_W then
         Sub_X := Menu_X - Sub_Wd + 2;
      end if;
      if Sub_Y + Sub_Ht > Scr_H then
         Sub_Y := Scr_H - Sub_Ht - 2;
      end if;
      Sub_Win := XCreateSimpleWindow
        (Dpy, Root, Sub_X, Sub_Y,
         unsigned (Sub_Wd), unsigned (Sub_Ht), 0, 0, C_Menu_Bg);
      XChangeWindowAttributes
        (Dpy, Sub_Win, CWOverrideRedirect or CWBackPixel, Attrs'Access);
      XSelectInput (Dpy, Sub_Win, ExposureMask);
      XMapWindow (Dpy, Sub_Win);
      XRaiseWindow (Dpy, Sub_Win);
   end Open_Sub;

   procedure Open_Menu (I : Positive; XR, YR : Interfaces.C.int) is
      Attrs : aliased XSetWindowAttributes;
      Rc    : Interfaces.C.int;
      pragma Unreferenced (Rc);
   begin
      Close_Menu;
      Menu_I := I;
      Menu_X := XR;
      Menu_Y := YR;
      if Menu_X + Menu_Wd > Scr_W then
         Menu_X := Scr_W - Menu_Wd - 2;
      end if;
      if Menu_Y + Menu_Ht > Scr_H then
         Menu_Y := Scr_H - Menu_Ht - 2;
      end if;
      Attrs := (others => 0);
      Attrs.Override_Redirect := 1;
      Attrs.Background_Pixel  := C_Menu_Bg;
      Menu_Win := XCreateSimpleWindow
        (Dpy, Root, Menu_X, Menu_Y,
         unsigned (Menu_Wd), unsigned (Menu_Ht), 0, 0, C_Menu_Bg);
      XChangeWindowAttributes
        (Dpy, Menu_Win, CWOverrideRedirect or CWBackPixel, Attrs'Access);
      XSelectInput (Dpy, Menu_Win, ExposureMask or ButtonPressMask);
      XMapWindow (Dpy, Menu_Win);
      XRaiseWindow (Dpy, Menu_Win);
      --  grab so clicks anywhere reach us (outside click = dismiss)
      Rc := XGrabPointer
        (Dpy, Menu_Win, 0,
         unsigned (ButtonPressMask or ButtonReleaseMask),
         GrabModeAsync, GrabModeAsync, 0, 0, CurrentTime);
   end Open_Menu;

   --------------------------------------------------------------------------
   --  Text-input dialog
   --------------------------------------------------------------------------
   Dlg_Title : constant array (Dlg_Kind range Dlg_Rename .. Dlg_Prop_Icon)
                 of String (1 .. 16) :=
     ("Rename:         ",
      "Image path:     ",
      "Name:           ",
      "Exec:           ",
      "Icon name:      ");

   procedure Paint_Dlg is
   begin
      if Dlg_Win = 0 then return; end if;
      XSetForeground (Dpy, Icon_Gc, C_Dlg_Bg);
      XFillRectangle (Dpy, Dlg_Win, Icon_Gc, 0, 0,
                      unsigned (Dlg_Wd), unsigned (Dlg_Ht));
      XSetForeground (Dpy, Icon_Gc, C_Menu_Ed);
      XDrawRectangle (Dpy, Dlg_Win, Icon_Gc, 0, 0,
                      unsigned (Dlg_Wd - 1), unsigned (Dlg_Ht - 1));
      XSetForeground (Dpy, Icon_Gc, C_Text);
      Draw_Text (Dlg_Win, 10, 20,
                 (if Dlg_Mode in Dlg_Rename .. Dlg_Prop_Icon
                  then Dlg_Title (Dlg_Mode)
                  else "Input:          "));
      --  input field
      XSetForeground (Dpy, Icon_Gc, C_Field);
      XFillRectangle (Dpy, Dlg_Win, Icon_Gc, 8, 30,
                      unsigned (Dlg_Wd - 16), 26);
      XSetForeground (Dpy, Icon_Gc, C_Menu_Ed);
      XDrawRectangle (Dpy, Dlg_Win, Icon_Gc, 8, 30,
                      unsigned (Dlg_Wd - 16), 26);
      XSetForeground (Dpy, Icon_Gc, C_Text);
      declare
         Max_Ch : constant := (Dlg_Wd - 24) / 7;   --  ~7px/char
         V0 : constant Natural :=
           (if Buf_Len > Natural (Max_Ch)
            then (if Buf_Cur >= Natural (Max_Ch)
                  then Buf_Cur - Natural (Max_Ch) + 1
                  else 0)
            else 0);
         V  : constant String := Buf (V0 + 1 .. Buf_Len);
      begin
         if V'Length > 0 then
            Draw_Text (Dlg_Win, 12, 49, V);
         end if;
         --  caret
         XFillRectangle (Dpy, Dlg_Win, Icon_Gc,
                         12 + Interfaces.C.int (Buf_Cur - V0) * 7,
                         35, 2, 16);
      end;
      if Dlg_Bad then
         XSetForeground (Dpy, Icon_Gc, 16#00E05050#);
         Draw_Text (Dlg_Win, 10, Dlg_Ht - 6, "bad value - try again");
      else
         XSetForeground (Dpy, Icon_Gc, 16#008090A0#);
         Draw_Text (Dlg_Win, 200, Dlg_Ht - 6, "Enter ok / Esc cancel");
      end if;
      XFlush (Dpy);
   end Paint_Dlg;

   procedure Close_Dlg is
      Rc : Interfaces.C.int;
      pragma Unreferenced (Rc);
   begin
      if Dlg_Win /= 0 then
         XUngrabKeyboard (Dpy, CurrentTime);
         XUngrabPointer (Dpy, CurrentTime);
         XDestroyWindow (Dpy, Dlg_Win);
         Dlg_Win := 0;
      end if;
      Dlg_Mode := Dlg_None;
      Dlg_Bad  := False;
      --  a dialog opened over Properties leaves it input-less;
      --  hand the grabs back so its keys still work
      if Prop_Win /= 0 then
         Rc := XGrabKeyboard (Dpy, Prop_Win, 0,
                              GrabModeAsync, GrabModeAsync, CurrentTime);
         Rc := XGrabPointer (Dpy, Prop_Win, 0,
                             unsigned (ButtonPressMask),
                             GrabModeAsync, GrabModeAsync, 0, 0,
                             CurrentTime);
      end if;
   end Close_Dlg;

   procedure Open_Dlg
     (Mode : Dlg_Kind; I : Positive; Initial : String) is
      Attrs : aliased XSetWindowAttributes;
      Rc    : Interfaces.C.int;
      pragma Unreferenced (Rc);
      DX, DY : Interfaces.C.int;
   begin
      Close_Dlg;
      Dlg_Mode := Mode;
      Dlg_Icon := I;
      Buf_Len  := Natural'Min (Initial'Length, Buf'Last);
      Buf (1 .. Buf_Len) := Initial (Initial'First ..
                                     Initial'First + Buf_Len - 1);
      Buf_Cur  := Buf_Len;
      Dlg_Bad  := False;
      DX := (Scr_W - Dlg_Wd) / 2;
      DY := (Scr_H - Dlg_Ht) / 3;
      Attrs := (others => 0);
      Attrs.Override_Redirect := 1;
      Attrs.Background_Pixel  := C_Dlg_Bg;
      Dlg_Win := XCreateSimpleWindow
        (Dpy, Root, DX, DY,
         unsigned (Dlg_Wd), unsigned (Dlg_Ht), 0, 0, C_Dlg_Bg);
      XChangeWindowAttributes
        (Dpy, Dlg_Win, CWOverrideRedirect or CWBackPixel, Attrs'Access);
      XSelectInput (Dpy, Dlg_Win,
                    ExposureMask or KeyPressMask or ButtonPressMask);
      XMapWindow (Dpy, Dlg_Win);
      XRaiseWindow (Dpy, Dlg_Win);
      Rc := XGrabKeyboard (Dpy, Dlg_Win, 0,
                           GrabModeAsync, GrabModeAsync, CurrentTime);
      Rc := XGrabPointer (Dpy, Dlg_Win, 0,
                          unsigned (ButtonPressMask),
                          GrabModeAsync, GrabModeAsync, 0, 0, CurrentTime);
      Paint_Dlg;
   end Open_Dlg;

   --------------------------------------------------------------------------
   --  Properties window
   --------------------------------------------------------------------------
   procedure Paint_Prop is
      Im  : Exec_String.Bounded_String;
      LI  : Natural;
      Row_S : Interfaces.C.int;
   begin
      if Prop_Win = 0 or else Prop_I = 0 then return; end if;
      LI := Find (Layout, N_Layout,
                  Name_String.To_String (Icons (Prop_I).Base));
      XSetForeground (Dpy, Icon_Gc, C_Dlg_Bg);
      XFillRectangle (Dpy, Prop_Win, Icon_Gc, 0, 0,
                      unsigned (Prop_Wd), unsigned (Prop_Ht));
      XSetForeground (Dpy, Icon_Gc, C_Menu_Ed);
      XDrawRectangle (Dpy, Prop_Win, Icon_Gc, 0, 0,
                      unsigned (Prop_Wd - 1), unsigned (Prop_Ht - 1));
      XSetForeground (Dpy, Icon_Gc, C_Text);
      Draw_Text (Prop_Win, 10, 20, "Properties — click a row to edit");

      for R in 1 .. Prop_Rows loop
         Row_S := Prop_Row_H + Interfaces.C.int (R - 1) * Prop_Row_H + 8;
         if R = Prop_Sel then
            XSetForeground (Dpy, Icon_Gc, C_Menu_Hi);
            XFillRectangle (Dpy, Prop_Win, Icon_Gc, 4,
                            Row_S - 15, unsigned (Prop_Wd - 8),
                            unsigned (Prop_Row_H));
         end if;
         XSetForeground (Dpy, Icon_Gc, C_Text);
         declare
            Txt : String (1 .. 300);
            L   : Natural := 0;
            procedure Put (S : String) is
               N : constant Natural := Natural'Min (S'Length, 300 - L);
            begin
               Txt (L + 1 .. L + N) := S (S'First .. S'First + N - 1);
               L := L + N;
            end Put;
         begin
            case R is
               when 1 =>
                  Put ("Name     : ");
                  Put (Name_String.To_String (Icons (Prop_I).Name));
               when 2 =>
                  Put ("Exec     : ");
                  Put (Exec_String.To_String (Icons (Prop_I).Exec));
               when 3 =>
                  Put ("Terminal : ");
                  Put (if Icons (Prop_I).Terminal then "true" else "false");
               when 4 =>
                  Put ("Icon name: ");
                  Put (Name_String.To_String (Icons (Prop_I).Icon_Name));
               when 5 =>
                  Put ("Image    : ");
                  if LI > 0 then
                     Im := Layout (LI).Image;
                  else
                     Im := Exec_String.Null_Bounded_String;
                  end if;
                  Put (if Exec_String.Length (Im) = 0
                       then "(letter glyph)"
                       else Exec_String.To_String (Im));
               when others =>
                  Put ("Color    : ");
                  Put (Color_Name (Col_Idx (Prop_I)));
                  Put ("   Pos: ");
                  Put (Trim (Natural (Pos_X (Prop_I))));
                  Put (",");
                  Put (Trim (Natural (Pos_Y (Prop_I))));
            end case;
            Draw_Text (Prop_Win, 10, Row_S, Txt (1 .. L));
         end;
      end loop;
      XSetForeground (Dpy, Icon_Gc, 16#008090A0#);
      Draw_Text (Prop_Win, 10, Prop_Ht - 8,
                 "Esc close   Enter=edit   row3=toggle row6=color");
      XFlush (Dpy);
   end Paint_Prop;

   procedure Close_Prop is
   begin
      if Prop_Win /= 0 then
         XUngrabKeyboard (Dpy, CurrentTime);
         XUngrabPointer (Dpy, CurrentTime);
         XDestroyWindow (Dpy, Prop_Win);
         Prop_Win := 0;
      end if;
      Prop_I := 0;
   end Close_Prop;

   procedure Open_Prop (I : Positive) is
      Attrs : aliased XSetWindowAttributes;
      Rc    : Interfaces.C.int;
      pragma Unreferenced (Rc);
   begin
      Close_Prop;
      Prop_I   := I;
      Prop_Sel := 1;
      Prop_X := (Scr_W - Prop_Wd) / 2;
      Prop_Y := (Scr_H - Prop_Ht) / 3;
      Attrs := (others => 0);
      Attrs.Override_Redirect := 1;
      Attrs.Background_Pixel  := C_Dlg_Bg;
      Prop_Win := XCreateSimpleWindow
        (Dpy, Root, Prop_X, Prop_Y,
         unsigned (Prop_Wd), unsigned (Prop_Ht), 0, 0, C_Dlg_Bg);
      XChangeWindowAttributes
        (Dpy, Prop_Win, CWOverrideRedirect or CWBackPixel, Attrs'Access);
      XSelectInput (Dpy, Prop_Win,
                    ExposureMask or KeyPressMask or ButtonPressMask);
      XMapWindow (Dpy, Prop_Win);
      XRaiseWindow (Dpy, Prop_Win);
      Rc := XGrabKeyboard (Dpy, Prop_Win, 0,
                           GrabModeAsync, GrabModeAsync, CurrentTime);
      Rc := XGrabPointer (Dpy, Prop_Win, 0,
                          unsigned (ButtonPressMask),
                          GrabModeAsync, GrabModeAsync, 0, 0, CurrentTime);
      Paint_Prop;
   end Open_Prop;

   --  Apply a committed dialog buffer for the given mode.
   procedure Commit_Dlg is
      I  : constant Natural := Dlg_Icon;
      V  : constant String := Buf (1 .. Buf_Len);
      LI : Natural;
   begin
      if I = 0 or else V'Length = 0 then
         Close_Dlg;
         return;
      end if;
      case Dlg_Mode is
         when Dlg_Rename | Dlg_Prop_Name =>
            if Set_Key (Exec_String.To_String (Icons (I).Path),
                        "Name", V)
            then
               Icons (I).Name := Name_String.To_Bounded_String (V);
               Paint_Icon (I);
               Close_Dlg;
            else
               Dlg_Bad := True;
               Paint_Dlg;
            end if;
         when Dlg_Image =>
            declare
               Bufv : Icon_Images.Pixel_Buffer;
            begin
               if Load_Tile (V, Bufv) then
                  LI := Upsert (Layout, N_Layout,
                                Name_String.To_String (Icons (I).Base));
                  if LI > 0 then
                     Layout (LI).Image := Exec_String.To_Bounded_String (V);
                  end if;
                  Load_Icon_Pixmap (I);
                  Save (Layout, N_Layout,
                        Natural (Scr_W), Natural (Scr_H));
                  Paint_Icon (I);
                  Close_Dlg;
               else
                  Dlg_Bad := True;
                  Paint_Dlg;
               end if;
            end;
         when Dlg_Prop_Exec =>
            if Set_Key (Exec_String.To_String (Icons (I).Path),
                        "Exec", V)
            then
               Icons (I).Exec := Exec_String.To_Bounded_String (V);
               Close_Dlg;
               if Prop_Win /= 0 then Paint_Prop; end if;
            else
               Dlg_Bad := True;
               Paint_Dlg;
            end if;
         when Dlg_Prop_Icon =>
            if Set_Key (Exec_String.To_String (Icons (I).Path),
                        "Icon", V)
            then
               Icons (I).Icon_Name := Name_String.To_Bounded_String (V);
               Close_Dlg;
               if Prop_Win /= 0 then Paint_Prop; end if;
            else
               Dlg_Bad := True;
               Paint_Dlg;
            end if;
         when others =>
            Close_Dlg;
      end case;
   end Commit_Dlg;

   --------------------------------------------------------------------------
   --  Launch (unchanged behaviour: /bin/sh, detached, no zombies)
   --------------------------------------------------------------------------
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
         null;
   end Launch;

   --------------------------------------------------------------------------
   --  Layout persistence for the icon currently at pixel Pos_X/Pos_Y
   --------------------------------------------------------------------------
   procedure Save_Icon_Pos (I : Positive) is
      LI : Natural;
      Nx, Ny : Natural;
   begin
      LI := Upsert (Layout, N_Layout,
                    Name_String.To_String (Icons (I).Base));
      if LI = 0 then return; end if;
      Encode_Wasm (Pos_X (I), Pos_Y (I), Nx, Ny);
      Layout (LI).Nx := Nx;
      Layout (LI).Ny := Ny;
      Layout (LI).Has_Pos := True;
      Save (Layout, N_Layout, Natural (Scr_W), Natural (Scr_H));
   end Save_Icon_Pos;

   procedure Apply_Color (I : Positive; K : Natural) is
      LI : Natural;
   begin
      Col_Idx (I) := K;
      LI := Upsert (Layout, N_Layout,
                    Name_String.To_String (Icons (I).Base));
      if LI > 0 then
         Layout (LI).Color := K;
         Save (Layout, N_Layout, Natural (Scr_W), Natural (Scr_H));
      end if;
      Paint_Icon (I);
   end Apply_Color;

   --------------------------------------------------------------------------
   --  Menu item dispatch
   --------------------------------------------------------------------------
   procedure Menu_Action (Item : Natural) is
      I : constant Natural := Menu_I;
   begin
      case Item is
         when 1 =>                 --  Open
            Close_Menu;
            if I > 0 then
               Launch (I);
               Flash_Start (I) := Now_Ms;
               Flashing (I) := True;
            end if;
         when 2 =>                 --  Rename
            Close_Menu;
            if I > 0 then
               Open_Dlg (Dlg_Rename, I,
                         Name_String.To_String (Icons (I).Name));
            end if;
         when 3 =>                 --  Color -> submenu (stays open)
            if Sub_Win = 0 then
               Open_Sub;
            end if;
         when 4 =>                 --  Set Image
            Close_Menu;
            if I > 0 then
               declare
                  LI : constant Natural :=
                    Find (Layout, N_Layout,
                          Name_String.To_String (Icons (I).Base));
               begin
                  Open_Dlg (Dlg_Image, I,
                    (if LI > 0
                     then Exec_String.To_String (Layout (LI).Image)
                     else ""));
               end;
            end if;
         when 5 =>                 --  Properties
            Close_Menu;
            if I > 0 then
               Open_Prop (I);
            end if;
         when others =>
            Close_Menu;
      end case;
   end Menu_Action;

   --------------------------------------------------------------------------
   --  Re-resolve icon positions after a screen-size change and
   --  physically move the windows.
   --------------------------------------------------------------------------
   procedure Relayout is
   begin
      Resolve_All_Wasm;
      for I in 1 .. Count loop
         XMoveWindow (Dpy, Wins (I), Pos_X (I), Pos_Y (I));
      end loop;
      XFlush (Dpy);
   end Relayout;

   --------------------------------------------------------------------------
   --  Setup
   --------------------------------------------------------------------------
   Attrs   : aliased XSetWindowAttributes;
   Ev      : XEvent;
   Av      : XAnyEvent;
   Bv      : XButtonEvent;
   Kv      : aliased XKeyEvent;
   Cv      : XConfigureEvent;
   Elapsed : Natural;
   Wa      : aliased XWindowAttributes;
   Rc0     : Interfaces.C.int;
   pragma Unreferenced (Rc0);

begin
   Desktop_Files.Load_Desktop_Icons (Icons, Count);
   if Count = 0 then
      return;
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
   Icon_Gc   := XDefaultGC (Dpy, Scr);

   Rc0 := XGetWindowAttributes (Dpy, Root, Wa'Access);
   Scr_W := Wa.Width;
   Scr_H := Wa.Height;
   XSelectInput (Dpy, Root, StructureNotifyMask);

   Load (Layout, N_Layout);
   Load_Flash_Table;
   Load_Color_Table;

   --  default column, then stored positions win
   for I in 1 .. Count loop
      Pos_X (I) := Margin_Left;
      Pos_Y (I) := Margin_Top
                 + Interfaces.C.int (I - 1) * (Icon_H + Icon_Gap);
      declare
         LI : constant Natural := Find
           (Layout, N_Layout, Name_String.To_String (Icons (I).Base));
      begin
         if LI > 0 then
            Col_Idx (I) :=
              (if Layout (LI).Color < Num_Colors
               then Layout (LI).Color else 0);
         end if;
      end;
   end loop;
   Resolve_All_Wasm;

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
        (Dpy, Root, Pos_X (I), Pos_Y (I),
         unsigned (Icon_W), unsigned (Icon_H),
         0, 0, C_Box);

      XChangeWindowAttributes (Dpy, Wins (I),
                               CWOverrideRedirect or CWBackPixel,
                               Attrs'Access);

      XSelectInput (Dpy, Wins (I),
                    ExposureMask or ButtonPressMask
                    or ButtonReleaseMask or Button1MotionMask
                    or PointerMotionMask);

      declare
         WN : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String
             ("titanium-icon-" & Integer'Image (I));
      begin
         XStoreName (Dpy, Wins (I), WN);
         Interfaces.C.Strings.Free (WN);
      end;

      XMapWindow (Dpy, Wins (I));
      XLowerWindow (Dpy, Wins (I));
      Load_Icon_Pixmap (I);
      Paint_Icon (I);
   end loop;

   XFlush (Dpy);

   --------------------------------------------------------------------------
   --  Event loop — polled so the click-flash animates between events
   --------------------------------------------------------------------------
   loop
      while XPending (Dpy) > 0 loop
         XNextEvent (Dpy, Ev);
         if Ev.Type_Code = Expose then
            Av := To_Any (Ev);
            if Av.Win = Menu_Win then
               Paint_Menu;
            elsif Av.Win = Sub_Win then
               Paint_Sub;
            elsif Av.Win = Dlg_Win then
               Paint_Dlg;
            elsif Av.Win = Prop_Win then
               Paint_Prop;
            else
               for I in 1 .. Count loop
                  if Wins (I) = Av.Win then
                     Paint_Icon (I);
                  end if;
               end loop;
            end if;

         elsif Ev.Type_Code = ConfigureNotify then
            Cv := To_Cfg (Ev);
            if Cv.Event_W = Root
              and then (Cv.Width /= Scr_W or else Cv.Height /= Scr_H)
            then
               Scr_W := Cv.Width;
               Scr_H := Cv.Height;
               Relayout;
            end if;

         elsif Ev.Type_Code = MotionNotify then
            Bv := To_Btn (Ev);
            if Drag_I > 0 then
               if abs (Bv.X_Root - Drag_SX) > Drag_Thresh
                 or else abs (Bv.Y_Root - Drag_SY) > Drag_Thresh
               then
                  Drag_Moved := True;
               end if;
               if Drag_Moved then
                  Pos_X (Drag_I) := Bv.X_Root - Drag_Off_X;
                  Pos_Y (Drag_I) := Bv.Y_Root - Drag_Off_Y;
                  XMoveWindow (Dpy, Wins (Drag_I),
                               Pos_X (Drag_I), Pos_Y (Drag_I));
                  XFlush (Dpy);
               end if;
            end if;

         elsif Ev.Type_Code = ButtonRelease then
            Bv := To_Btn (Ev);
            if Drag_I > 0 and then Bv.Button = 1 then
               XUngrabPointer (Dpy, CurrentTime);
               if Drag_Moved then
                  Save_Icon_Pos (Drag_I);
                  XLowerWindow (Dpy, Wins (Drag_I));
               else
                  Launch (Drag_I);
                  Flash_Start (Drag_I) := Now_Ms;
                  Flashing (Drag_I) := True;
               end if;
               Drag_I := 0;
               Drag_Moved := False;
            end if;

         elsif Ev.Type_Code = ButtonPress then
            Bv := To_Btn (Ev);
            if Bv.Win = Menu_Win or else Bv.Win = Sub_Win
              or else (Menu_Win /= 0 and then Menu_I > 0)
            then
               --  menu is modal-ish: hits inside act, outside dismiss
               if Sub_Win /= 0
                 and then Bv.X_Root >= Sub_X
                 and then Bv.X_Root < Sub_X + Sub_Wd
                 and then Bv.Y_Root >= Sub_Y
                 and then Bv.Y_Root < Sub_Y + Sub_Ht
               then
                  declare
                     K : constant Natural :=
                       Natural ((Bv.Y_Root - Sub_Y - 2) / Menu_Item_H);
                  begin
                     if K < Num_Colors and then Menu_I > 0 then
                        Apply_Color (Menu_I, K);
                     end if;
                  end;
                  Close_Menu;
               elsif Bv.X_Root >= Menu_X
                 and then Bv.X_Root < Menu_X + Menu_Wd
                 and then Bv.Y_Root >= Menu_Y
                 and then Bv.Y_Root < Menu_Y + Menu_Ht
               then
                  declare
                     It : constant Natural :=
                       Natural ((Bv.Y_Root - Menu_Y - 2) / Menu_Item_H);
                  begin
                     if It >= 1 and then It <= 5 then
                        Menu_Action (It);
                     end if;
                  end;
               else
                  Close_Menu;
               end if;

            elsif Bv.Win = Dlg_Win then
               --  text dialog: inside = refocus only; outside = cancel
               if Bv.X_Root < (Scr_W - Dlg_Wd) / 2
                 or else Bv.X_Root > (Scr_W + Dlg_Wd) / 2
                 or else Bv.Y_Root < (Scr_H - Dlg_Ht) / 3
                 or else Bv.Y_Root > (Scr_H - Dlg_Ht) / 3 + Dlg_Ht
               then
                  Close_Dlg;
               end if;

            elsif Bv.Win = Prop_Win then
               --  outside dismisses; a row click selects+edits
               if Bv.X_Root < Prop_X
                 or else Bv.X_Root > Prop_X + Prop_Wd
                 or else Bv.Y_Root < Prop_Y
                 or else Bv.Y_Root > Prop_Y + Prop_Ht
               then
                  Close_Prop;
               else
                  declare
                     Ry : constant Interfaces.C.int :=
                       Bv.Y_Root - Prop_Y - Prop_Row_H - 8;
                     R  : constant Natural :=
                       (if Ry >= 0
                        then Natural (Ry / Prop_Row_H) + 1
                        else 0);
                  begin
                     if R >= 1 and then R <= Prop_Rows then
                        Prop_Sel := R;
                        case R is
                           when 1 =>
                              Open_Dlg (Dlg_Prop_Name, Prop_I,
                                Name_String.To_String (Icons (Prop_I).Name));
                           when 2 =>
                              Open_Dlg (Dlg_Prop_Exec, Prop_I,
                                Exec_String.To_String (Icons (Prop_I).Exec));
                           when 3 =>
                              Icons (Prop_I).Terminal :=
                                not Icons (Prop_I).Terminal;
                              Rc0 := (if Set_Key
                                (Exec_String.To_String (Icons (Prop_I).Path),
                                 "Terminal",
                                 (if Icons (Prop_I).Terminal
                                  then "true" else "false"))
                                then 0 else 1);
                              Paint_Prop;
                           when 4 =>
                              Open_Dlg (Dlg_Prop_Icon, Prop_I,
                                Name_String.To_String
                                  (Icons (Prop_I).Icon_Name));
                           when 5 =>
                              declare
                                 LI2 : constant Natural := Find
                                   (Layout, N_Layout,
                                    Name_String.To_String
                                      (Icons (Prop_I).Base));
                              begin
                                 Open_Dlg (Dlg_Image, Prop_I,
                                   (if LI2 > 0
                                    then Exec_String.To_String
                                      (Layout (LI2).Image)
                                    else ""));
                              end;
                           when others =>
                              Apply_Color
                                (Prop_I, (Col_Idx (Prop_I) + 1) mod Num_Colors);
                              Paint_Prop;
                        end case;
                     else
                        Paint_Prop;
                     end if;
                  end;
               end if;

            else
               for I in 1 .. Count loop
                  if Wins (I) = Bv.Win then
                     if Bv.Button = 3 then
                        Open_Menu (I, Bv.X_Root, Bv.Y_Root);
                     elsif Bv.Button = 1 then
                        Drag_I     := I;
                        Drag_Off_X := Bv.X_Pos;
                        Drag_Off_Y := Bv.Y_Pos;
                        Drag_SX    := Bv.X_Root;
                        Drag_SY    := Bv.Y_Root;
                        Drag_Moved := False;
                        Rc0 := XGrabPointer
                          (Dpy, Wins (I), 0,
                           unsigned (ButtonReleaseMask
                                     or Button1MotionMask
                                     or PointerMotionMask),
                           GrabModeAsync, GrabModeAsync, 0, 0,
                           CurrentTime);
                     end if;
                  end if;
               end loop;
            end if;

         elsif Ev.Type_Code = KeyPress then
            if Dlg_Win /= 0 then
               Kv := To_Key (Ev);
               declare
                  Ks   : aliased unsigned_long := 0;
                  ChB  : Interfaces.C.char_array (0 .. 31);
                  NCh  : Interfaces.C.int;
               begin
                  NCh := XLookupString
                    (Kv'Access, ChB, 32, Ks'Access, System.Null_Address);
                  if Ks = Key_Escape then
                     Close_Dlg;
                  elsif Ks = Key_Return then
                     Commit_Dlg;
                  elsif Ks = Key_Left and then Buf_Cur > 0 then
                     Buf_Cur := Buf_Cur - 1;
                     Paint_Dlg;
                  elsif Ks = Key_Right and then Buf_Cur < Buf_Len then
                     Buf_Cur := Buf_Cur + 1;
                     Paint_Dlg;
                  elsif Ks = Key_Home then
                     Buf_Cur := 0;
                     Paint_Dlg;
                  elsif Ks = Key_End then
                     Buf_Cur := Buf_Len;
                     Paint_Dlg;
                  elsif Ks = Key_BackSpace and then Buf_Cur > 0 then
                     Buf (Buf_Cur .. Buf_Len - 1) :=
                       Buf (Buf_Cur + 1 .. Buf_Len);
                     Buf_Len := Buf_Len - 1;
                     Buf_Cur := Buf_Cur - 1;
                     Paint_Dlg;
                  elsif Ks = Key_Delete and then Buf_Cur < Buf_Len then
                     Buf (Buf_Cur + 1 .. Buf_Len - 1) :=
                       Buf (Buf_Cur + 2 .. Buf_Len);
                     Buf_Len := Buf_Len - 1;
                     Paint_Dlg;
                  else
                     for C in 0 .. Natural (NCh) - 1 loop
                        declare
                           Ch : constant Character :=
                             Interfaces.C.To_Ada (ChB (size_t (C)));
                        begin
                           if Buf_Len < Buf'Last
                             and then Ch >= ' '
                             and then Ch <= '~'
                           then
                              Buf (Buf_Cur + 2 .. Buf_Len + 1) :=
                                Buf (Buf_Cur + 1 .. Buf_Len);
                              Buf (Buf_Cur + 1) := Ch;
                              Buf_Len := Buf_Len + 1;
                              Buf_Cur := Buf_Cur + 1;
                           end if;
                        end;
                     end loop;
                     if NCh > 0 then
                        Paint_Dlg;
                     end if;
                  end if;
               end;
            elsif Prop_Win /= 0 then
               Kv := To_Key (Ev);
               declare
                  Ks  : aliased unsigned_long := 0;
                  ChB : Interfaces.C.char_array (0 .. 15);
                  NCh : Interfaces.C.int;
                  pragma Unreferenced (NCh);
               begin
                  NCh := XLookupString
                    (Kv'Access, ChB, 16, Ks'Access, System.Null_Address);
                  if Ks = Key_Escape then
                     Close_Prop;
                  elsif Ks = Key_Up and then Prop_Sel > 1 then
                     Prop_Sel := Prop_Sel - 1;
                     Paint_Prop;
                  elsif Ks = Key_Down and then Prop_Sel < Prop_Rows then
                     Prop_Sel := Prop_Sel + 1;
                     Paint_Prop;
                  elsif Ks = Key_Return then
                     case Prop_Sel is
                        when 1 =>
                           Open_Dlg (Dlg_Prop_Name, Prop_I,
                             Name_String.To_String (Icons (Prop_I).Name));
                        when 2 =>
                           Open_Dlg (Dlg_Prop_Exec, Prop_I,
                             Exec_String.To_String (Icons (Prop_I).Exec));
                        when 3 =>
                           Icons (Prop_I).Terminal :=
                             not Icons (Prop_I).Terminal;
                           Rc0 := (if Set_Key
                             (Exec_String.To_String (Icons (Prop_I).Path),
                              "Terminal",
                              (if Icons (Prop_I).Terminal
                               then "true" else "false"))
                             then 0 else 1);
                           Paint_Prop;
                        when 4 =>
                           Open_Dlg (Dlg_Prop_Icon, Prop_I,
                             Name_String.To_String
                               (Icons (Prop_I).Icon_Name));
                        when 5 =>
                           declare
                              LI2 : constant Natural := Find
                                (Layout, N_Layout,
                                 Name_String.To_String
                                   (Icons (Prop_I).Base));
                           begin
                              Open_Dlg (Dlg_Image, Prop_I,
                                (if LI2 > 0
                                 then Exec_String.To_String
                                   (Layout (LI2).Image)
                                 else ""));
                           end;
                        when others =>
                           Apply_Color
                             (Prop_I,
                              (Col_Idx (Prop_I) + 1) mod Num_Colors);
                           Paint_Prop;
                     end case;
                  end if;
               end;
            end if;
         end if;
      end loop;

      --  animation tick
      for I in 1 .. Count loop
         if Flashing (I) then
            Elapsed := Now_Ms - Flash_Start (I);
            if Elapsed >= Flash_Ms then
               Flashing (I) := False;
               Paint_Icon (I);
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
      null;   --  display loss / BadWindow: die quietly, respawn restarts
end Main;
