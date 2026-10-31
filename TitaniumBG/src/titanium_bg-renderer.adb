package body Titanium_BG.Renderer
  with SPARK_Mode => On
is
   -- Sine Table (0..255)
   type Sine_Table is array (0 .. 255) of Unsigned_32;
   Sines : constant Sine_Table := 
     (128, 131, 134, 137, 140, 143, 146, 149, 152, 155, 158, 162, 165, 167, 170, 173,
      176, 179, 182, 184, 187, 190, 192, 195, 198, 200, 203, 205, 208, 210, 212, 215,
      217, 219, 221, 223, 225, 227, 229, 231, 233, 234, 236, 238, 239, 241, 242, 243,
      245, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 254, 255, 255, 255, 255,
      255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 245,
      243, 242, 241, 239, 238, 236, 234, 233, 231, 229, 227, 225, 223, 221, 219, 217,
      215, 212, 210, 208, 205, 203, 200, 198, 195, 192, 190, 187, 184, 182, 179, 176,
      173, 170, 167, 165, 162, 158, 155, 152, 149, 146, 143, 140, 137, 134, 131, 128,
      124, 121, 118, 115, 112, 109, 106, 103, 100, 97, 94, 90, 87, 85, 82, 79,
      76, 73, 70, 68, 65, 62, 60, 57, 54, 52, 49, 47, 44, 42, 40, 37,
      35, 33, 31, 29, 27, 25, 23, 21, 19, 18, 16, 14, 13, 11, 10, 9,
      7, 6, 5, 4, 3, 2, 1, 0, 0, 1, 1, 1, 2, 2, 2, 3, 
      3, 3, 3, 3, 2, 2, 1, 1, 0, 1, 2, 3, 4, 5, 6, 7,
      9, 10, 11, 13, 14, 16, 18, 19, 21, 23, 25, 27, 29, 31, 33, 35,
      37, 40, 42, 44, 47, 49, 52, 54, 57, 60, 62, 65, 68, 70, 73, 76,
      79, 82, 85, 87, 90, 94, 97, 100, 103, 106, 109, 112, 115, 118, 121, 124);

   procedure Render_Frame
     (Buffer : in out Pixel_Array;
      State  : in out Generator_State;
      Config : in Screen_Config)
   is
      X, Y  : Unsigned_32;
      Limit : Integer;
      Val   : Unsigned_32;
      R, G, B : Unsigned_32;
      
      -- Pseudo-Random Noise Accumulator
      Rand : Unsigned_32;
   begin
      Limit := Config.Width * Config.Height;
      if Limit > Buffer'Length then Limit := Buffer'Length; end if;

      -- Initialize Rand based on frame count (deterministic chaos)
      Rand := State.Frame_Count * 12345 + 6789;

      for I in 0 .. Limit - 1 loop
         Y := Unsigned_32 (I) / Unsigned_32 (Config.Width);
         X := Unsigned_32 (I) mod Unsigned_32 (Config.Width);

         case State.Current_Mode is
            
            when Plasma =>
               -- 1. PLASMA
               Val := Sines(Integer((X + State.Frame_Count) and 255)) + 
                      Sines(Integer((Y + State.Frame_Count) and 255));
               R := (Val * 4) and 255;
               G := (Val * 2) and 255;
               B := (Val * 8) and 255;
               Buffer (I) := Pixel_Color (Shift_Left(R, 16) or Shift_Left(G, 8) or B);

            when Xor_Grid =>
               -- 2. XOR GRID
               Val := ((X + State.Reg_A) xor (Y + State.Reg_B)) * State.Frame_Count;
               Buffer (I) := Pixel_Color (Val and 16#00FF_FFFF#);

            when Static_Noise =>
               -- 3. STATIC NOISE
               Rand := Rand * 1664525 + 1013904223; -- Linear Congruential Generator
               Val := Rand;
               
               -- Matrix Green Tint
               R := 0;
               G := (Val / 256) and 255; 
               B := 0;
               Buffer (I) := Pixel_Color (Shift_Left(R, 16) or Shift_Left(G, 8) or B);
         end case;
      end loop;

      -- Update State Registers
      State.Frame_Count := State.Frame_Count + 1;
      State.Reg_A := State.Reg_A + 1;
      State.Reg_B := State.Reg_B + 2;
   end Render_Frame;

end Titanium_BG.Renderer;
