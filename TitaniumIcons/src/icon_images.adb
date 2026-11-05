with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;

package body Icon_Images is

   package SIO renames Ada.Streams.Stream_IO;

   Max_Src  : constant := 1024;            --  src pixels per axis cap
   Max_File : constant := 4 * 1024 * 1024; --  bytes read cap

   --  byte buffer held on the heap (multi-MB stack arrays overflow
   --  the default 8 MB pthread stack)
   type Byte_Buf is array (Natural range <>) of Natural;
   type Byte_Ptr is access Byte_Buf;
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Buf, Byte_Ptr);

   --  Read up to Max_File bytes of Path into a fresh buffer.
   function Read_File (Path : String) return Byte_Ptr is
      F   : SIO.File_Type;
      S   : SIO.Stream_Access;
      E   : Ada.Streams.Stream_Element;
      Pos : Natural := 0;
   begin
      SIO.Open (F, SIO.In_File, Path);
      S := SIO.Stream (F);
      declare
         Sz : constant Natural := Natural (Ada.Streams.Stream_IO.Size (F));
         N  : constant Natural := Natural'Min (Sz, Max_File);
         D  : Byte_Ptr := new Byte_Buf (0 .. N - 1);
      begin
         while Pos < N and then not SIO.End_Of_File (F) loop
            Ada.Streams.Stream_Element'Read (S, E);
            D (Pos) := Natural (E);
            Pos := Pos + 1;
         end loop;
         SIO.Close (F);
         return new Byte_Buf'(D (0 .. Pos - 1));
      exception
         when others =>
            Free (D);
            if SIO.Is_Open (F) then SIO.Close (F); end if;
            return null;
      end;
   exception
      when others =>
         if SIO.Is_Open (F) then SIO.Close (F); end if;
         return null;
   end Read_File;

   --  Nearest-neighbour scale an SWxSH 0xRRGGBB image into Buf.
   procedure Scale
     (Src : Byte_Buf; SW, SH : Natural; Buf : out Pixel_Buffer)
   is
      SX, SY : Natural;
   begin
      for DY in 0 .. Tile - 1 loop
         SY := DY * SH / Tile;
         for DX in 0 .. Tile - 1 loop
            SX := DX * SW / Tile;
            Buf (DY * Tile + DX) := Src (Src'First + SY * SW + SX);
         end loop;
      end loop;
   end Scale;

   --  Parse "P6 <ws> <w> <ws> <h> <ws> <maxval> <1 ws> <binary>"
   function Load_PPM
     (Data : Byte_Buf; Buf : out Pixel_Buffer) return Boolean
   is
      Pos   : Natural := Data'First + 2;   --  skip "P6"
      W, H  : Natural := 0;
      Max   : Natural := 0;
      C     : Natural;

      procedure Skip_Ws is
      begin
         loop
            while Pos <= Data'Last
              and then (Data (Pos) = 32 or else Data (Pos) = 9
                        or else Data (Pos) = 10 or else Data (Pos) = 13)
            loop
               Pos := Pos + 1;
            end loop;
            if Pos <= Data'Last and then Data (Pos) = 35 then  -- '#'
               while Pos <= Data'Last and then Data (Pos) /= 10 loop
                  Pos := Pos + 1;
               end loop;
            else
               exit;
            end if;
         end loop;
      end Skip_Ws;

      function Number return Natural is
         V : Natural := 0;
      begin
         Skip_Ws;
         while Pos <= Data'Last
           and then Data (Pos) >= 48 and then Data (Pos) <= 57
         loop
            V := V * 10 + (Data (Pos) - 48);
            Pos := Pos + 1;
         end loop;
         return V;
      end Number;

      Src : Byte_Ptr;
   begin
      W   := Number;
      H   := Number;
      Max := Number;
      if W = 0 or else H = 0 or else Max = 0 or else Max > 255
        or else W > Max_Src or else H > Max_Src
      then
         return False;
      end if;
      Pos := Pos + 1;                       --  single ws after maxval
      if Pos + W * H * 3 - 1 > Data'Last then
         return False;
      end if;
      Src := new Byte_Buf (0 .. W * H - 1);
      for I in Src'Range loop
         C := Pos + I * 3;
         Src (I) := Data (C) * 65536 + Data (C + 1) * 256 + Data (C + 2);
      end loop;
      Scale (Src.all, W, H, Buf);
      Free (Src);
      return True;
   exception
      when others =>
         if Src /= null then Free (Src); end if;
         return False;
   end Load_PPM;

   --  Parse a 24-bit uncompressed BMP (BITMAPINFOHEADER or later).
   function Load_BMP
     (Data : Byte_Buf; Buf : out Pixel_Buffer) return Boolean
   is
      function U16 (P : Natural) return Natural is
        (Data (P) + Data (P + 1) * 256);
      function U32 (P : Natural) return Natural is
        (Data (P) + Data (P + 1) * 256 + Data (P + 2) * 65536
         + Data (P + 3) * 16777216);

      Data_Off : Natural;
      Hdr_Size : Natural;
      W, H     : Integer;
      Bpp      : Natural;
      Comp     : Natural;
      Row_Pad  : Natural;
      Top_Down : Boolean;
      Src      : Byte_Ptr;
      X, Y, SY : Natural;
      P        : Natural;
   begin
      if Data'Length < 54
        or else Data (Data'First) /= 66     --  'B'
        or else Data (Data'First + 1) /= 77 --  'M'
      then
         return False;
      end if;
      Data_Off := U32 (Data'First + 10);
      Hdr_Size := U32 (Data'First + 14);
      if Hdr_Size < 40 then
         return False;
      end if;
      W    := Integer (U32 (Data'First + 18));
      Bpp  := U16 (Data'First + 28);
      Comp := U32 (Data'First + 30);
      declare
         H_L : Long_Long_Integer := Long_Long_Integer (U32 (Data'First + 22));
      begin
         Top_Down := H_L >= 2 ** 31;
         if Top_Down then
            H_L := H_L - 2 ** 32;      --  two's-complement negative
         end if;
         H := Integer (H_L);
      end;
      if W <= 0 or else H = 0 or else Bpp /= 24 or else Comp /= 0
        or else W > Max_Src or else (if H < 0 then -H else H) > Max_Src
      then
         return False;
      end if;
      H := (if H < 0 then -H else H);
      Row_Pad := (4 - (W * 3) mod 4) mod 4;
      Src := new Byte_Buf (0 .. W * H - 1);
      for R in 0 .. H - 1 loop
         SY := (if Top_Down then R else H - 1 - R);
         P  := Data'First + Data_Off + R * (W * 3 + Row_Pad);
         if P + W * 3 - 1 > Data'Last then
            Free (Src);
            return False;
         end if;
         for Col in 0 .. W - 1 loop
            X := P + Col * 3;
            Y := SY * W + Col;
            Src (Y) := Data (X + 2) * 65536   --  BGR -> RGB
                     + Data (X + 1) * 256
                     + Data (X);
         end loop;
      end loop;
      Scale (Src.all, W, H, Buf);
      Free (Src);
      return True;
   exception
      when others =>
         if Src /= null then Free (Src); end if;
         return False;
   end Load_BMP;

   function Load_Tile
     (Path : String;
      Buf  : out Pixel_Buffer) return Boolean
   is
      Data : Byte_Ptr := Read_File (Path);
      Ok   : Boolean := False;
   begin
      Buf := (others => 0);
      if Data = null or else Data'Length < 2 then
         if Data /= null then Free (Data); end if;
         return False;
      end if;
      if Data (Data'First) = 80 and then Data (Data'First + 1) = 54 then
         Ok := Load_PPM (Data.all, Buf);        --  "P6"
      elsif Data (Data'First) = 66 and then Data (Data'First + 1) = 77 then
         Ok := Load_BMP (Data.all, Buf);        --  "BM"
      end if;
      Free (Data);
      return Ok;
   end Load_Tile;

end Icon_Images;
