with Titanium_BG; use Titanium_BG;

package VGPU.Fonts 
  with SPARK_Mode => On
is
   -- Draws a single character at virtual coordinates
   procedure Draw_Char
     (VX, VY : in Integer;
      Char   : in Character;
      Col    : in Pixel_Color;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

   -- Draws a string of text
   procedure Draw_Text
     (VX, VY : in Integer;
      Text   : in String;
      Col    : in Pixel_Color;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

end VGPU.Fonts;
