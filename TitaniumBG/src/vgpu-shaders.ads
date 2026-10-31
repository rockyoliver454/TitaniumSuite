with Titanium_BG; use Titanium_BG;
with Interfaces;  use Interfaces;
package VGPU.Shaders 
  with SPARK_Mode => On
is
   -- Procedural Glow: Returns a color that oscillates over time (Flicker)
   function Glow_Flicker
     (Base_Col : Pixel_Color;
      Frame    : Natural;
      Seed     : Unsigned_32) return Pixel_Color;

   -- Simple Additive Blend: Mixes two colors without overflow
   function Blend_Add
     (Col_A : Pixel_Color;
      Col_B : Pixel_Color) return Pixel_Color;

   -- Ambient Occlusion Lite: Darkens a color based on its vertical position
   function Apply_Vignette
     (VX, VY  : Integer;
      Base    : Pixel_Color) return Pixel_Color;

end VGPU.Shaders;
