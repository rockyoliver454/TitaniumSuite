with Titanium_BG; use Titanium_BG;

package VGPU 
  with SPARK_Mode => On
is
   -- Virtual resolution for the "Pixel Art" feel
   Virtual_Width  : constant := 320;
   Virtual_Height : constant := 240;

   -- Draws a virtual pixel to the real buffer with perfect scaling
   procedure Set_Pixel
     (VX     : in Integer;
      VY     : in Integer;
      Col    : in Pixel_Color;
      Buffer : in out Pixel_Array;
      Config : in Screen_Config);

end VGPU;
