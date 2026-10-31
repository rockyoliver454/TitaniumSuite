with Titanium_BG; use Titanium_BG;

package VGPU.Ditherer 
  with SPARK_Mode => On
is
   -- Patterns suitable for the 320x240 aesthetic
   type Pattern_Type is (Solid, Checkerboard, Bayer_4x4, Bayer_8x8);

   -- Returns True if the virtual pixel at (VX, VY) should be filled 
   -- based on the requested intensity (0 .. 255).
   function Is_Active 
     (VX        : Integer; 
      VY        : Integer; 
      Intensity : Natural; 
      Pattern   : Pattern_Type) return Boolean;

end VGPU.Ditherer;
