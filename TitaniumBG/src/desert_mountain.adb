with VGPU;
with VGPU.Primitives;
with VGPU.Ditherer;
with VGPU.Proc_Gen;
with Interfaces; -- Added for Unsigned_32 types

package body Desert_Mountain
  with SPARK_Mode => On
is

   -----------------------------------------------------------------------------
   -- Render
   -----------------------------------------------------------------------------
   overriding procedure Render
     (Self   : in out Desert_Mountain_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config)
   is
      C_Sky_Top    : constant Pixel_Color := 16#00_60_30_10#;
      C_Sky_Bot    : constant Pixel_Color := 16#00_E0_AA_40#;
      C_Mtn_Dark   : constant Pixel_Color := 16#00_30_15_08#;
      C_Mtn_Light  : constant Pixel_Color := 16#00_70_40_15#;
      C_Sand_Main  : constant Pixel_Color := 16#00_C5_95_35#;
      C_Sand_Dark  : constant Pixel_Color := 16#00_A0_70_25#;
      C_Coyote     : constant Pixel_Color := 16#00_50_40_30#;
      C_Buzzard    : constant Pixel_Color := 16#00_05_05_05#;
      C_Cactus     : constant Pixel_Color := 16#00_20_35_10#;
      C_Rock       : constant Pixel_Color := 16#00_45_45_40#;

      Intensity    : Natural;
      Gen_Col      : Pixel_Color;
      Sky_Boundary : constant Integer := 140; 
   begin
      -- 1. SKY (Bayer Dithered)
      for VY in 0 .. Sky_Boundary loop
         pragma Assert (VY < VGPU.Virtual_Height); -- Rule 5: Assertion
         for VX in 0 .. VGPU.Virtual_Width - 1 loop
            Intensity := (VY * 255) / Sky_Boundary;
            
            if VGPU.Ditherer.Is_Active(VX, VY, Intensity, VGPU.Ditherer.Bayer_4x4) then
               VGPU.Set_Pixel(VX, VY, C_Sky_Bot, Buffer, Config);
            else
               VGPU.Set_Pixel(VX, VY, C_Sky_Top, Buffer, Config);
            end if;
         end loop;
      end loop;

      -- 2. MOUNTAINS
      for I in 0 .. 3 loop
         declare
            Base_X : constant Integer := I * 100 - 30;
            Peak_H : constant Integer := 50 + (I * 20);
         begin
            for Step in 0 .. Peak_H loop
               declare
                  X_Dark  : constant Integer := Base_X + Step;
                  X_Light : constant Integer := Base_X + Peak_H + Step;
               begin
                  if X_Dark >= 0 and X_Dark < VGPU.Virtual_Width then
                     VGPU.Primitives.Draw_Line(X_Dark, Sky_Boundary - Step, X_Dark, Sky_Boundary, C_Mtn_Dark, Buffer, Config);
                  end if;
                  
                  if X_Light >= 0 and X_Light < VGPU.Virtual_Width then
                     VGPU.Primitives.Draw_Line(X_Light, Sky_Boundary - (Peak_H - Step), X_Light, Sky_Boundary, C_Mtn_Light, Buffer, Config);
                  end if;
               end;
            end loop;
         end;
      end loop;

      -- 3. ENHANCED SAND
      for VY in (Sky_Boundary + 1) .. VGPU.Virtual_Height - 1 loop
         for VX in 0 .. VGPU.Virtual_Width - 1 loop
            if (VX + VY / 2) mod 40 < 4 then
               Gen_Col := C_Sand_Dark;
            else
               Gen_Col := C_Sand_Main;
            end if;

            if (VGPU.Proc_Gen.Get_Pixel_Color(VX, VY, 11, VGPU.Proc_Gen.Rough_Stone) mod 4 = 0) then
               Gen_Col := C_Sand_Dark;
            end if;

            VGPU.Set_Pixel(VX, VY, Gen_Col, Buffer, Config);
         end loop;
      end loop;

      -- 4. ROCKS & CACTI
      for I in 1 .. 6 loop
         declare
            RX : constant Integer := (I * 55) mod VGPU.Virtual_Width;
            RY : constant Integer := 150 + ((I * 17) mod 80);
         begin
            pragma Assert (RX < VGPU.Virtual_Width and RY < VGPU.Virtual_Height);
            VGPU.Primitives.Draw_Rect(RX, RY, RX + 4, RY + 2, C_Rock, Buffer, Config);
            VGPU.Primitives.Draw_Rect(RX + 20, RY - 15, RX + 22, RY, C_Cactus, Buffer, Config);
            VGPU.Primitives.Draw_Line(RX + 18, RY - 10, RX + 20, RY - 10, C_Cactus, Buffer, Config);
         end;
      end loop;

      -- 5. THE COYOTE
      pragma Assert (Coyote_X < VGPU.Virtual_Width and Coyote_Y < VGPU.Virtual_Height);
      VGPU.Primitives.Draw_Rect(Coyote_X - 4, Coyote_Y, Coyote_X + 4, Coyote_Y + 2, C_Coyote, Buffer, Config);
      VGPU.Primitives.Draw_Rect(Coyote_X + 2, Coyote_Y - 2, Coyote_X + 5, Coyote_Y, C_Coyote, Buffer, Config);

      -- 6. THE BUZZARD
      declare
         BX : constant Integer := Self.Bird_X;
         BY : constant Integer := Self.Bird_Y;
      begin
         if BX >= 10 and BX < VGPU.Virtual_Width - 10 and
            BY >= 10 and BY < VGPU.Virtual_Height - 10
         then
            if Self.State = Feasting then
               VGPU.Primitives.Draw_Rect(BX - 2, BY - 3, BX + 2, BY, C_Buzzard, Buffer, Config);
            else
               VGPU.Primitives.Draw_Line(BX - 4, BY - 2, BX, BY, C_Buzzard, Buffer, Config);
               VGPU.Primitives.Draw_Line(BX, BY, BX + 4, BY - 2, C_Buzzard, Buffer, Config);
            end if;
         end if;
      end;
   end Render;

   -----------------------------------------------------------------------------
   -- Update
   -----------------------------------------------------------------------------
   overriding procedure Update
     (Self  : in out Desert_Mountain_Wallpaper;
      Frame : in     Natural)
   is
      use type Interfaces.Unsigned_32; -- Rule 6: Scope local use
   begin
      -- Corrected Type Handling: Using Unsigned_32'Last for Frame_Count checks
      if Self.Frame_Count < Interfaces.Unsigned_32'Last then
         Self.Frame_Count := Self.Frame_Count + 1;
      end if;
      
      if Self.State_Timer < Natural'Last then
         Self.State_Timer := Self.State_Timer + 1;
      end if;

      case Self.State is
         when Circling =>
            Self.Bird_X := 160 + Integer(40 - (Integer(Self.Frame_Count mod 80)));
            Self.Bird_Y := 40 + Integer(Self.Frame_Count mod 20);
            if Self.State_Timer > 400 then 
               Self.State := Descending;
            end if;

         when Descending =>
            if Self.Bird_X < Coyote_X then 
               Self.Bird_X := Self.Bird_X + 1;
            elsif Self.Bird_X > Coyote_X then 
               Self.Bird_X := Self.Bird_X - 1; 
            end if;
            
            if Self.Bird_Y < Coyote_Y - 2 then 
               Self.Bird_Y := Self.Bird_Y + 1; 
            end if;
            
            if abs(Self.Bird_X - Coyote_X) < 2 and then Self.Bird_Y >= Coyote_Y - 2 then
               Self.State := Feasting;
               Self.State_Timer := 0;
            end if;

         when Feasting =>
            if Self.Frame_Count mod 15 = 0 then
               Self.Bird_X := Coyote_X + (if Self.Frame_Count mod 30 = 0 then 1 else -1);
            end if;
            if Self.State_Timer > 300 then 
               Self.State := Ascending;
            end if;

         when Ascending =>
            if Self.Bird_Y > 0 then
               Self.Bird_Y := Self.Bird_Y - 1;
            end if;
            
            if Self.Bird_X > 0 then
               Self.Bird_X := Self.Bird_X - 1;
            end if;
            
            if Self.Bird_Y < 30 or Self.Bird_X < 30 then 
               Self.State := Circling;
               Self.State_Timer := 0;
            end if;
      end case;
   end Update;

   overriding function Name (Self : Desert_Mountain_Wallpaper) return String is ("Desert Mountain");
end Desert_Mountain;
