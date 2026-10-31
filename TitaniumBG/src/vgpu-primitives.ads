with Titanium_BG; use Titanium_BG;
with VGPU;

package VGPU.Primitives 
  with SPARK_Mode => On
is
   -- Draws a solid rectangle
   procedure Draw_Rect
     (X1, Y1, X2, Y2 : in Integer;
      Col            : in Pixel_Color;
      Buffer         : in out Pixel_Array;
      Config         : in Screen_Config);

   -- Draws a line using Bresenham's Algorithm (Integer only)
   procedure Draw_Line
     (X1, Y1, X2, Y2 : in Integer;
      Col            : in Pixel_Color;
      Buffer         : in out Pixel_Array;
      Config         : in Screen_Config);

   -- Draws a filled triangle (Critical for roofs and trees)
   procedure Draw_Triangle
     (X1, Y1, X2, Y2, X3, Y3 : in Integer;
      Col                    : in Pixel_Color;
      Buffer                 : in out Pixel_Array;
      Config                 : in Screen_Config);

end VGPU.Primitives;
