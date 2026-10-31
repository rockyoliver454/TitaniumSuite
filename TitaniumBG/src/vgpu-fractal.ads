with Titanium_BG; use Titanium_BG;
with Interfaces;  use Interfaces;

package VGPU.Fractal 
  with SPARK_Mode => On
is
   -- We use 16.16 fixed-point (16 bits for integer, 16 bits for fraction)
   -- to avoid floating point math while maintaining precision.
   type Fixed is new Integer_32;
   
   -- Scale factor for 16.16 (2^16)
   Shift_Amt : constant := 16;
   One       : constant Fixed := 2**Shift_Amt;

   -- Calculates the Mandelbrot escape value (0 .. Max_Iter) for a point.
   -- VX, VY are 320x240 coordinates.
   function Get_Mandelbrot_Iter
     (VX       : Integer;
      VY       : Integer;
      Max_Iter : Positive;
      Zoom     : Fixed) return Natural;

end VGPU.Fractal;
