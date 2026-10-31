with Interfaces; use Interfaces;

package body VGPU.Fonts 
  with SPARK_Mode => On
is

   -- Basic 8x8 Bitmap Font Data (Standard ASCII 32-126)
   -- Each character is 8 bytes (one per row)
   type Char_Bitmap is array (0 .. 7) of Unsigned_8;
   type Font_Array is array (Character'(' ') .. Character'('~')) of Char_Bitmap;

   -- A minimalist retro font definition
   Font_Data : constant Font_Array := (
      ' ' => (16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#),
      '!' => (16#18#, 16#18#, 16#18#, 16#18#, 16#00#, 16#18#, 16#18#, 16#00#),
      '0' => (16#3C#, 16#66#, 16#6E#, 16#7E#, 16#76#, 16#66#, 16#3C#, 16#00#),
      '1' => (16#18#, 16#38#, 16#18#, 16#18#, 16#18#, 16#18#, 16#7E#, 16#00#),
      'A' => (16#3C#, 16#66#, 16#66#, 16#7E#, 16#66#, 16#66#, 16#66#, 16#00#),
      'B' => (16#7C#, 16#66#, 16#66#, 16#7C#, 16#66#, 16#66#, 16#7C#, 16#00#),
      'C' => (16#3C#, 16#66#, 16#60#, 16#60#, 16#60#, 16#66#, 16#3C#, 16#00#),
      'T' => (16#7E#, 16#18#, 16#18#, 16#18#, 16#18#, 16#18#, 16#18#, 16#00#),
      'I' => (16#3C#, 16#18#, 16#18#, 16#18#, 16#18#, 16#18#, 16#3C#, 16#00#),
      'N' => (16#66#, 16#76#, 16#7E#, 16#7E#, 16#6E#, 16#66#, 16#66#, 16#00#),
      'U' => (16#66#, 16#66#, 16#66#, 16#66#, 16#66#, 16#66#, 16#3C#, 16#00#),
      'M' => (16#66#, 16#7E#, 16#7E#, 16#66#, 16#66#, 16#66#, 16#66#, 16#00#),
      'V' => (16#66#, 16#66#, 16#66#, 16#66#, 16#66#, 16#3C#, 16#18#, 16#00#),
      'L' => (16#60#, 16#60#, 16#60#, 16#60#, 16#60#, 16#60#, 16#7E#, 16#00#),
      'G' => (16#3C#, 16#66#, 16#60#, 16#6E#, 16#66#, 16#66#, 16#3C#, 16#00#),
      'E' => (16#7E#, 16#60#, 16#60#, 16#7C#, 16#60#, 16#60#, 16#7E#, 16#00#),
      others => (16#FF#, 16#81#, 16#81#, 16#81#, 16#81#, 16#81#, 16#FF#, 16#00#) -- Box fallback
   );

   -----------------------------------------------------------------------------
   -- Draw_Char
   -----------------------------------------------------------------------------
   procedure Draw_Char
     (VX, VY : in Integer;
      Char   : in Character;
      Col    : in Pixel_Color;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config)
   is
      Char_Data : Char_Bitmap;
      Row       : Unsigned_8;
   begin
      -- Handle out of bounds character range
      if Char not in Font_Data'Range then
         return;
      end if;

      Char_Data := Font_Data(Char);

      for Y_Offset in 0 .. 7 loop
         Row := Char_Data(Y_Offset);
         for X_Offset in 0 .. 7 loop
            -- Check the bit for this pixel (Shift and mask)
            if (Shift_Right(Row, 7 - X_Offset) and 1) = 1 then
               VGPU.Set_Pixel(VX + X_Offset, VY + Y_Offset, Col, Buffer, Config);
            end if;
         end loop;
      end loop;
   end Draw_Char;

   -----------------------------------------------------------------------------
   -- Draw_Text
   -----------------------------------------------------------------------------
   procedure Draw_Text
     (VX, VY : in Integer;
      Text   : in String;
      Col    : in Pixel_Color;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config)
   is
      Cursor_X : Integer := VX;
   begin
      for I in Text'Range loop
         Draw_Char(Cursor_X, VY, Text(I), Col, Buffer, Config);
         Cursor_X := Cursor_X + 8; -- Advance by font width
         
         -- Basic wrapping if needed
         if Cursor_X >= VGPU.Virtual_Width then
            return;
         end if;
      end loop;
   end Draw_Text;

end VGPU.Fonts;
