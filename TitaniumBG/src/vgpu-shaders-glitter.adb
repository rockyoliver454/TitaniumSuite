package body VGPU.Shaders.Glitter 
  with SPARK_Mode => On
is

   function Apply_Glitter
     (VX, VY    : Integer;
      Base_Col  : Pixel_Color;
      Frame     : Natural;
      Intensity : Unsigned_32) return Pixel_Color
   is
      -- Simple deterministic hash to differentiate pixels
      Pixel_ID : constant Unsigned_32 := 
        Unsigned_32(abs VX) * 1664525 + Unsigned_32(abs VY);
      
      -- Calculate twinkle state based on frame and pixel ID
      Twinkle : constant Unsigned_32 := (Unsigned_32(Frame) + Pixel_ID) mod 128;
      
      -- We'll boost the brightness if the twinkle hits the intensity threshold
   begin
      if Twinkle < Intensity then
         -- Flash: Return pure bright white (glitter spark)
         return 16#00_FF_FF_FF#;
      else
         -- Normal: Return the original color
         return Base_Col;
      end if;
   end Apply_Glitter;

end VGPU.Shaders.Glitter;
