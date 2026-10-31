with VGPU;
with VGPU.Primitives;
with VGPU.Ditherer;
with VGPU.Proc_Gen;
with VGPU.Shaders;
with VGPU.Shaders.Glitter;

package body Snowy_Village
  with SPARK_Mode => On
is

   -----------------------------------------------------------------------------
   -- Internal Helpers
   -----------------------------------------------------------------------------
   procedure Next_Random (Seed : in out Unsigned_32; Result : out Unsigned_32) is
   begin
      -- Linear Congruential Generator for deterministic "in-house" noise
      Seed := Seed * 1664525 + 1013904223;
      Result := Seed;
   end Next_Random;

   -----------------------------------------------------------------------------
   -- Render
   -----------------------------------------------------------------------------
   overriding procedure Render
     (Self   : in out Snowy_Village_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config)
   is
      -- Palette Definitions
      C_Sky_Dark  : constant Pixel_Color := 16#00_02_02_15#;
      C_Sky_Light : constant Pixel_Color := 16#00_08_08_35#;
      C_Window    : constant Pixel_Color := 16#00_FF_AA_00#; -- Warm Glow
      C_Snow_Base : constant Pixel_Color := 16#00_DD_DD_DD#; -- Default Snow
      
      Intensity : Natural;
      Gen_Col   : Pixel_Color;
   begin
      -- 1. RENDER SKY: Uses VGPU.Ditherer with Bayer 4x4 Matrix for software shading
      for VY in 0 .. 185 loop
         for VX in 0 .. VGPU.Virtual_Width - 1 loop
            -- Intensity increases downward for an atmospheric gradient
            Intensity := (VY * 150) / 185; 
            
            if VGPU.Ditherer.Is_Active(VX, VY, Intensity, VGPU.Ditherer.Bayer_4x4) then
               VGPU.Set_Pixel(VX, VY, C_Sky_Light, Buffer, Config);
            else
               VGPU.Set_Pixel(VX, VY, C_Sky_Dark, Buffer, Config);
            end if;
         end loop;
      end loop;

      -- 2. RENDER GROUND: Uses VGPU.Proc_Gen for randomized "tuft" texturing
      for VY in 186 .. VGPU.Virtual_Height - 1 loop
         for VX in 0 .. VGPU.Virtual_Width - 1 loop
            Gen_Col := VGPU.Proc_Gen.Get_Pixel_Color(VX, VY, 123, VGPU.Proc_Gen.Grass_Tuft);
            VGPU.Set_Pixel(VX, VY, Gen_Col, Buffer, Config);
         end loop;
      end loop;

      -- 3. RENDER CABIN: Uses Primitives, Proc_Gen, and Shaders
      -- Walls: Procedural Wood Grain
      for VY in 150 .. 185 loop
         for VX in 130 .. 190 loop
            -- Window Logic: Centered on the cabin with a Shader-based flickering glow
            if VX > 150 and VX < 170 and VY > 160 and VY < 175 then
               Gen_Col := VGPU.Shaders.Glow_Flicker(C_Window, Natural(Self.Frame_Count), 50);
            else
               -- Wall Texture
               Gen_Col := VGPU.Proc_Gen.Get_Pixel_Color(VX, VY, 456, VGPU.Proc_Gen.Wood_Grain);
            end if;
            
            VGPU.Set_Pixel(VX, VY, Gen_Col, Buffer, Config);
         end loop;
      end loop;

      -- Roof: Geometric lines using Bresenham's Algorithm
      -- Draws a triangular slope for that 2.5D look
      for RX in 0 .. 35 loop
         VGPU.Primitives.Draw_Line
           (X1 => 130 + RX, Y1 => 150 - RX, 
            X2 => 190 - RX, Y2 => 150 - RX, 
            Col => 16#00_20_10_05#, Buffer => Buffer, Config => Config);
      end loop;

      -- 4. RENDER SNOWFLAKES: Particle system through the VGPU scaling pipeline with Glitter Shader
      for K in Self.Flakes'Range loop
         if Self.Flakes(K).Active then
            declare
               VX : constant Integer := Self.Flakes(K).X mod VGPU.Virtual_Width;
               VY : constant Integer := Self.Flakes(K).Y mod VGPU.Virtual_Height;
               
               -- Apply the glitter shader to make the snow sparkle
               Final_Col : constant Pixel_Color := 
                 VGPU.Shaders.Glitter.Apply_Glitter
                   (VX        => VX, 
                    VY        => VY, 
                    Base_Col  => C_Snow_Base, 
                    Frame     => Natural(Self.Frame_Count), 
                    Intensity => 8); 
            begin
               VGPU.Set_Pixel(VX, VY, Final_Col, Buffer, Config);
            end;
         end if;
      end loop;
   end Render;

   -----------------------------------------------------------------------------
   -- Update
   -----------------------------------------------------------------------------
   overriding procedure Update
     (Self  : in out Snowy_Village_Wallpaper;
      Frame : in     Natural)
   is
      Rnd : Unsigned_32;
   begin
      Self.Frame_Count := Self.Frame_Count + 1;

      for K in Self.Flakes'Range loop
         -- Initialize snowflakes if inactive
         if not Self.Flakes(K).Active then
             Next_Random(Self.RNG_Seed, Rnd);
             Self.Flakes(K).X := Integer(Rnd mod Unsigned_32(VGPU.Virtual_Width)); 
             
             Next_Random(Self.RNG_Seed, Rnd);
             Self.Flakes(K).Y := Integer(Rnd mod Unsigned_32(VGPU.Virtual_Height));
             
             Next_Random(Self.RNG_Seed, Rnd);
             Self.Flakes(K).Speed := Integer(Rnd mod 3) + 1;
             
             Self.Flakes(K).Active := True;
         end if;

         -- Update Physics
         Self.Flakes(K).Y := Self.Flakes(K).Y + Self.Flakes(K).Speed;
         
         -- Wind Effect (Jitter)
         if Self.Frame_Count mod 3 = 0 then
            Next_Random(Self.RNG_Seed, Rnd);
            if (Rnd mod 2) = 0 then
               Self.Flakes(K).X := Self.Flakes(K).X - 1;
            else
               Self.Flakes(K).X := Self.Flakes(K).X + 1;
            end if;
         end if;

         -- Screen Wrap
         if Self.Flakes(K).Y >= VGPU.Virtual_Height then 
             Self.Flakes(K).Y := 0;
             Next_Random(Self.RNG_Seed, Rnd);
             Self.Flakes(K).X := Integer(Rnd mod Unsigned_32(VGPU.Virtual_Width));
         end if;
      end loop;
   end Update;

   -----------------------------------------------------------------------------
   -- Name
   -----------------------------------------------------------------------------
   overriding function Name (Self : Snowy_Village_Wallpaper) return String is
   begin
      return "Snowy Village";
   end Name;

end Snowy_Village;
