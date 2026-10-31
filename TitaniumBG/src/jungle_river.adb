with VGPU;
with VGPU.Primitives;
with VGPU.Ditherer;
with VGPU.Proc_Gen;
with VGPU.Shaders;
with VGPU.Shaders.Glitter;
with VGPU.Proc_Flora;

package body Jungle_River
  with SPARK_Mode => On
is

   -----------------------------------------------------------------------------
   -- Render
   -----------------------------------------------------------------------------
   overriding procedure Render
     (Self   : in out Jungle_River_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config)
   is
      -- Palette
      C_Sky_Top    : constant Pixel_Color := 16#00_00_15_30#; 
      C_Sky_Bot    : constant Pixel_Color := 16#00_30_50_15#; 
      C_River_Deep : constant Pixel_Color := 16#00_00_10_20#; 
      C_River_Lit  : constant Pixel_Color := 16#00_00_35_50#; 
      C_Bank_Mud   : constant Pixel_Color := 16#00_15_08_02#; 
      C_Wet_Mud    : constant Pixel_Color := 16#00_08_04_01#; -- Darker, saturated edge
      C_Shore_Line : constant Pixel_Color := 16#00_60_90_90#; -- Foam/Glow color
      
      Intensity : Natural;
      Gen_Col   : Pixel_Color;

      -- Flora DNA
      Main_Bank_DNA : constant VGPU.Proc_Flora.Flora_DNA := 
        (Trunk_Height  => 55, Trunk_Width => 8, Canopy_Spread => 40,
         Cluster_Count => 18, Cluster_Size  => 14);

   begin
      -- 1. ATMOSPHERIC SKY
      for VY in 0 .. 110 loop
         for VX in 0 .. VGPU.Virtual_Width - 1 loop
            Intensity := (VY * 255) / 110;
            if VGPU.Ditherer.Is_Active(VX, VY, Intensity, VGPU.Ditherer.Bayer_4x4) then
               VGPU.Set_Pixel(VX, VY, C_Sky_Bot, Buffer, Config);
            else
               VGPU.Set_Pixel(VX, VY, C_Sky_Top, Buffer, Config);
            end if;
         end loop;
      end loop;

      -- 2. THE BANK: Procedural mud with a specific "Wet Edge"
      for VY in 111 .. 145 loop
         for VX in 0 .. VGPU.Virtual_Width - 1 loop
            -- Most of the bank uses standard mud
            if VY < 142 then
               Gen_Col := VGPU.Proc_Gen.Get_Pixel_Color(VX, VY, 99, VGPU.Proc_Gen.Rough_Stone);
               VGPU.Set_Pixel(VX, VY, Gen_Col, Buffer, Config);
               
               -- Random Undergrowth
               if VGPU.Proc_Gen.Get_Pixel_Color(VX, VY, 77, VGPU.Proc_Gen.Grass_Tuft) /= 16#00_D0_D0_E0# then
                  VGPU.Set_Pixel(VX, VY, 16#00_05_20_05#, Buffer, Config);
               end if;
            else
               -- SHORELINE IMPROVEMENT: The "Wet Mud" zone (Transition pixels)
               VGPU.Set_Pixel(VX, VY, C_Wet_Mud, Buffer, Config);
            end if;
         end loop;
      end loop;

      -- 3. PROCEDURAL FLORA
      for I in 0 .. 3 loop
         VGPU.Proc_Flora.Draw_Tree
           (VX => 60 + (I * 95), VY => 142, DNA => Main_Bank_DNA,
            Seed => Unsigned_32(I * 456 + 10), Buffer => Buffer, Config => Config);
      end loop;

      -- 4. THE RIVER: Upgraded with a distinct Shoreline/Waterline
      for VY in 146 .. VGPU.Virtual_Height - 1 loop
         declare
            Reflect_Col : Pixel_Color := C_River_Deep;
         begin
            for VX in 0 .. VGPU.Virtual_Width - 1 loop
               
               -- SHORELINE IMPROVEMENT: The "Waterline Glow" (First row of water)
               if VY = 146 then
                  -- Use Glitter shader to make the shore foam sparkle
                  Gen_Col := VGPU.Shaders.Glitter.Apply_Glitter
                    (VX => VX, VY => VY, Base_Col => C_Shore_Line, 
                     Frame => Natural(Self.Frame_Count), Intensity => 12);
                  VGPU.Set_Pixel(VX, VY, Gen_Col, Buffer, Config);
               
               -- SHORELINE IMPROVEMENT: The "Shore Shadow" (Next 2 rows of water)
               elsif VY > 146 and VY < 149 then
                  VGPU.Set_Pixel(VX, VY, 16#00_00_05_10#, Buffer, Config);

               else
                  -- Standard River Rendering
                  declare
                     Wave_X : constant Integer := VX + Self.Flow_Offset;
                     Is_Water_Pixel : constant Boolean := 
                       VGPU.Ditherer.Is_Active(VX, VY, 180, VGPU.Ditherer.Bayer_4x4);
                  begin
                     if Is_Water_Pixel then
                        if ((Wave_X + VY/2) mod 32) < 4 then
                           Reflect_Col := C_River_Lit;
                        else
                           Reflect_Col := C_River_Deep;
                        end if;
                     end if;
                     
                     Gen_Col := VGPU.Shaders.Glitter.Apply_Glitter
                       (VX => VX, VY => VY, Base_Col => Reflect_Col, 
                        Frame => Natural(Self.Frame_Count), Intensity => 6);
                     
                     VGPU.Set_Pixel(VX, VY, Gen_Col, Buffer, Config);
                  end;
               end if;
            end loop;
         end; 
      end loop;

      -- 5. FOREGROUND VINES
      VGPU.Primitives.Draw_Line(20, 0, 15, 80, 16#00_05_15_02#, Buffer, Config);
      VGPU.Primitives.Draw_Line(305, 0, 290, 70, 16#00_05_15_02#, Buffer, Config);

   end Render;

   -----------------------------------------------------------------------------
   -- Update
   -----------------------------------------------------------------------------
   overriding procedure Update
     (Self  : in out Jungle_River_Wallpaper;
      Frame : in     Natural)
   is
   begin
      Self.Frame_Count := Self.Frame_Count + 1;
      
      if Self.Frame_Count mod 3 = 0 then
         Self.Flow_Offset := Self.Flow_Offset + 1;
         if Self.Flow_Offset > 4096 then
            Self.Flow_Offset := 0;
         end if;
      end if;
   end Update;

   overriding function Name (Self : Jungle_River_Wallpaper) return String is ("Jungle River");

end Jungle_River;
