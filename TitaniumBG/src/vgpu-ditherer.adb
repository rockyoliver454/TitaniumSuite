package body VGPU.Ditherer 
  with SPARK_Mode => On
is

   -- 4x4 Bayer Matrix (Values 0-15, scaled to 0-255 internally)
   type Matrix_4x4 is array (0 .. 3, 0 .. 3) of Natural;
   Bayer_4 : constant Matrix_4x4 := 
     (( 0,  8,  2, 10),
      (12,  4, 14,  6),
      ( 3, 11,  1,  9),
      (15,  7, 13,  5));

   -----------------------------------------------------------------------------
   -- Is_Active
   -----------------------------------------------------------------------------
   function Is_Active 
     (VX        : Integer; 
      VY        : Integer; 
      Intensity : Natural; 
      Pattern   : Pattern_Type) return Boolean
   is
      Threshold : Natural;
      MX, MY    : Integer;
   begin
      -- 0 Intensity is always off, 255 is always on
      if Intensity = 0 then return False; end if;
      if Intensity >= 255 then return True; end if;

      case Pattern is
         when Solid =>
            return True;

         when Checkerboard =>
            -- Basic 50% dither pattern
            return (VX + VY) mod 2 = 0;

         when Bayer_4x4 =>
            -- Map VX/VY to 4x4 grid
            MX := abs(VX) mod 4;
            MY := abs(VY) mod 4;
            -- Scale 4x4 matrix (0-15) to 0-255 range (approx * 16)
            Threshold := Bayer_4(MX, MY) * 16;
            return Intensity > Threshold;

         when Bayer_8x8 =>
            -- Simplified 8x8 using 4x4 symmetry for SPARK bounds
            MX := abs(VX) mod 8;
            MY := abs(VY) mod 8;
            Threshold := (Bayer_4(MX mod 4, MY mod 4) * 16);
            -- Add slight offset for 8x8 variety
            if MX > 3 then Threshold := Threshold + 8; end if;
            return Intensity > Threshold;
      end case;
   end Is_Active;

end VGPU.Ditherer;
