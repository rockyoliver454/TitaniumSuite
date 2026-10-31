with Titanium_BG; use Titanium_BG;
with Interfaces;  use Interfaces;

package VGPU.Proc_Flora 
  with SPARK_Mode => On
is
   -- The "Blueprint" for a tree, mirrored from core_proc_flora
   type Flora_DNA is record
      Trunk_Height  : Integer;
      Trunk_Width   : Integer;
      Canopy_Spread : Integer;
      Cluster_Count : Integer range 1 .. 20;
      Cluster_Size  : Integer;
   end record;

   -- Renders a tree at the given virtual base coordinates
   procedure Draw_Tree
     (VX, VY : in Integer;
      DNA    : in Flora_DNA;
      Seed   : in Unsigned_32;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

end VGPU.Proc_Flora;
