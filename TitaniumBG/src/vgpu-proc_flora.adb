with VGPU.Primitives;
with VGPU.Ditherer;
with VGPU.Proc_Gen;

package body VGPU.Proc_Flora 
  with SPARK_Mode => On
is

   procedure Draw_Tree
     (VX, VY : in Integer;
      DNA    : in Flora_DNA;
      Seed   : in Unsigned_32;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config)
   is
      Current_Seed : Unsigned_32 := Seed;
      
      -- Simple RNG helper for branch/leaf placement
      function Quick_Rand return Integer is
      begin
         Current_Seed := Current_Seed * 1664525 + 1013904223;
         return Integer(Current_Seed mod 1024);
      end Quick_Rand;

      C_Trunk : constant Pixel_Color := 16#00_30_15_05#;
      C_Leaf  : constant Pixel_Color := 16#00_05_40_05#;
      
      TX, TY  : Integer;
      RX, RY  : Integer;
   begin
      -- 1. Draw Trunk (Rectangle Primitive)
      VGPU.Primitives.Draw_Rect
        (VX - DNA.Trunk_Width / 2, VY - DNA.Trunk_Height,
         VX + DNA.Trunk_Width / 2, VY,
         C_Trunk, Buffer, Config);

      -- 2. Draw Canopy Clusters (Dithered Leaf Blobs)
      for I in 1 .. DNA.Cluster_Count loop
         -- Calculate random offset for each cluster
         RX := (Quick_Rand mod (DNA.Canopy_Spread * 2)) - DNA.Canopy_Spread;
         RY := (Quick_Rand mod DNA.Canopy_Spread);
         
         TX := VX + RX;
         TY := VY - DNA.Trunk_Height - RY;

         -- Draw a "Leaf Cluster" using a dithered circle-like rectangle
         for CY in TY - DNA.Cluster_Size .. TY + DNA.Cluster_Size loop
            for CX in TX - DNA.Cluster_Size .. TX + DNA.Cluster_Size loop
               -- Only draw if within circular radius and dither check passes
               if (CX - TX)**2 + (CY - TY)**2 <= DNA.Cluster_Size**2 then
                  if VGPU.Ditherer.Is_Active(CX, CY, 160, VGPU.Ditherer.Bayer_4x4) then
                     VGPU.Set_Pixel(CX, CY, C_Leaf, Buffer, Config);
                  end if;
               end if;
            end loop;
         end loop;
      end loop;
   end Draw_Tree;

end VGPU.Proc_Flora;
