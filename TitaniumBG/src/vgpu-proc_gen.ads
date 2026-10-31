with Titanium_BG; use Titanium_BG;
with Interfaces;  use Interfaces;

package VGPU.Proc_Gen 
  with SPARK_Mode => On
is
   -- Procedural texture types
   type Texture_Type is (Wood_Grain, Rough_Stone, Grass_Tuft);

   -- Returns a color modification or a specific pixel color based on coordinates
   -- and a seed to ensure the pattern stays static as the "camera" stays still.
   function Get_Pixel_Color
     (VX      : Integer;
      VY      : Integer;
      Seed    : Unsigned_32;
      Context : Texture_Type) return Pixel_Color;

end VGPU.Proc_Gen;
