package body VGPU.Shaders 
  with SPARK_Mode => On
is

   -----------------------------------------------------------------------------
   -- Glow_Flicker
   -----------------------------------------------------------------------------
   function Glow_Flicker
     (Base_Col : Pixel_Color;
      Frame    : Natural;
      Seed     : Unsigned_32) return Pixel_Color
   is
      -- Use the Frame and Seed to create a pseudo-sinusoidal flicker
      Intensity : constant Unsigned_32 := (Unsigned_32(Frame) + Seed) mod 64;
      R : Unsigned_32 := Shift_Right(Unsigned_32(Base_Col) and 16#00FF0000#, 16);
      G : Unsigned_32 := Shift_Right(Unsigned_32(Base_Col) and 16#0000FF00#, 8);
      B : Unsigned_32 := Unsigned_32(Base_Col) and 16#000000FF#;
   begin
      -- Add a flicker offset to the components
      if R > Intensity then R := R - Intensity; else R := 10; end if;
      if G > Intensity then G := G - Intensity; else G := 10; end if;
      
      return Pixel_Color(Shift_Left(R, 16) or Shift_Left(G, 8) or B);
   end Glow_Flicker;

   -----------------------------------------------------------------------------
   -- Blend_Add
   -----------------------------------------------------------------------------
   function Blend_Add
     (Col_A : Pixel_Color;
      Col_B : Pixel_Color) return Pixel_Color
   is
      R : Unsigned_32 := (Shift_Right(Unsigned_32(Col_A), 16) and 16#FF#) + 
                         (Shift_Right(Unsigned_32(Col_B), 16) and 16#FF#);
      G : Unsigned_32 := (Shift_Right(Unsigned_32(Col_A), 8) and 16#FF#) + 
                         (Shift_Right(Unsigned_32(Col_B), 8) and 16#FF#);
      B : Unsigned_32 := (Unsigned_32(Col_A) and 16#FF#) + 
                         (Unsigned_32(Col_B) and 16#FF#);
   begin
      -- Clamp to 255
      if R > 255 then R := 255; end if;
      if G > 255 then G := 255; end if;
      if B > 255 then B := 255; end if;
      
      return Pixel_Color(Shift_Left(R, 16) or Shift_Left(G, 8) or B);
   end Blend_Add;

   -----------------------------------------------------------------------------
   -- Apply_Vignette
   -----------------------------------------------------------------------------
   function Apply_Vignette
     (VX, VY  : Integer;
      Base    : Pixel_Color) return Pixel_Color
   is
      -- Simple darkening at the corners to create focus
      Dist_X : constant Integer := abs(VX - 160);
      Dist_Y : constant Integer := abs(VY - 120);
      Factor : constant Unsigned_32 := Unsigned_32((Dist_X + Dist_Y) / 10);
      
      R : Unsigned_32 := Shift_Right(Unsigned_32(Base) and 16#00FF0000#, 16);
      G : Unsigned_32 := Shift_Right(Unsigned_32(Base) and 16#0000FF00#, 8);
      B : Unsigned_32 := Unsigned_32(Base) and 16#000000FF#;
   begin
      if R > Factor then R := R - Factor; else R := 0; end if;
      if G > Factor then G := G - Factor; else G := 0; end if;
      if B > Factor then B := B - Factor; else B := 0; end if;
      
      return Pixel_Color(Shift_Left(R, 16) or Shift_Left(G, 8) or B);
   end Apply_Vignette;

end VGPU.Shaders;
