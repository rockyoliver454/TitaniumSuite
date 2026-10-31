with Titanium_BG; use Titanium_BG;
with Interfaces;  use Interfaces;

package VGPU.Shaders.Glitter 
  with SPARK_Mode => On
is
   -- Applies a glittering effect to a base color based on coordinate and time.
   -- Intensity: 0 (No glitter) to 255 (Max sparkle frequency)
   function Apply_Glitter
     (VX, VY    : Integer;
      Base_Col  : Pixel_Color;
      Frame     : Natural;
      Intensity : Unsigned_32) return Pixel_Color;

end VGPU.Shaders.Glitter;
