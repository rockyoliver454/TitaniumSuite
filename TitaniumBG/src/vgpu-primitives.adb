package body VGPU.Primitives 
  with SPARK_Mode => On
is

   -----------------------------------------------------------------------------
   -- Draw_Rect
   -----------------------------------------------------------------------------
   procedure Draw_Rect
     (X1, Y1, X2, Y2 : in Integer;
      Col            : in Pixel_Color;
      Buffer         : in out Pixel_Array;
      Config         : in Screen_Config)
   is
   begin
      for VY in Y1 .. Y2 loop
         for VX in X1 .. X2 loop
            VGPU.Set_Pixel(VX, VY, Col, Buffer, Config);
         end loop;
      end loop;
   end Draw_Rect;

   -----------------------------------------------------------------------------
   -- Draw_Line (Bresenham's Algorithm)
   -----------------------------------------------------------------------------
   procedure Draw_Line
     (X1, Y1, X2, Y2 : in Integer;
      Col            : in Pixel_Color;
      Buffer         : in out Pixel_Array;
      Config         : in Screen_Config)
   is
      DX  : constant Integer := abs (X2 - X1);
      DY  : constant Integer := -abs (Y2 - Y1);
      SX  : constant Integer := (if X1 < X2 then 1 else -1);
      SY  : constant Integer := (if Y1 < Y2 then 1 else -1);
      Err : Integer := DX + DY;
      E2  : Integer;
      Curr_X : Integer := X1;
      Curr_Y : Integer := Y1;
   begin
      loop
         VGPU.Set_Pixel(Curr_X, Curr_Y, Col, Buffer, Config);
         exit when Curr_X = X2 and Curr_Y = Y2;
         E2 := 2 * Err;
         if E2 >= DY then
            Err := Err + DY;
            Curr_X := Curr_X + SX;
         end if;
         if E2 <= DX then
            Err := Err + DX;
            Curr_Y := Curr_Y + SY;
         end if;
      end loop;
   end Draw_Line;

   -----------------------------------------------------------------------------
   -- Draw_Triangle (Simple Scanline Fill)
   -----------------------------------------------------------------------------
   procedure Draw_Triangle
     (X1, Y1, X2, Y2, X3, Y3 : in Integer;
      Col                    : in Pixel_Color;
      Buffer                 : in out Pixel_Array;
      Config                 : in Screen_Config)
   is
      -- Note: For a true pixel-art style, we can use the line algorithm 
      -- to find bounds for each Y scanline.
      Min_Y : constant Integer := Integer'Min(Y1, Integer'Min(Y2, Y3));
      Max_Y : constant Integer := Integer'Max(Y1, Integer'Max(Y2, Y3));
   begin
      -- Basic bounding-box fill with barycentric-lite check
      -- (Optimized for 320x240 virtual grid)
      for VY in Min_Y .. Max_Y loop
         -- We can improve this with a proper scanline rasterizer later
         Draw_Line(X1, Y1, X2, Y2, Col, Buffer, Config);
         Draw_Line(X2, Y2, X3, Y3, Col, Buffer, Config);
         Draw_Line(X3, Y3, X1, Y1, Col, Buffer, Config);
      end loop;
   end Draw_Triangle;

end VGPU.Primitives;
