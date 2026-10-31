package body VGPU.Fractal 
  with SPARK_Mode => On
is

   -----------------------------------------------------------------------------
   -- Get_Mandelbrot_Iter
   -----------------------------------------------------------------------------
   function Get_Mandelbrot_Iter
     (VX       : Integer;
      VY       : Integer;
      Max_Iter : Positive;
      Zoom     : Fixed) return Natural 
   is
      -- Map 320x240 into a coordinate system roughly [-2, 1] x [-1, 1]
      -- C_Re = (VX - 200) / Zoom
      -- C_Im = (VY - 120) / Zoom
      C_Re : Fixed := Fixed(Shift_Left(Unsigned_32(VX - 200), Shift_Amt)) / Zoom;
      C_Im : Fixed := Fixed(Shift_Left(Unsigned_32(VY - 120), Shift_Amt)) / Zoom;
      
      Z_Re : Fixed := 0;
      Z_Im : Fixed := 0;
      
      Z_Re_Sq : Fixed := 0;
      Z_Im_Sq : Fixed := 0;
      
      Count : Natural := 0;
      
      -- Escape radius squared (4.0 in 16.16 fixed point)
      Four_Fixed : constant Fixed := 4 * One;
   begin
      -- Standard iterative Mandelbrot algorithm
      for I in 1 .. Max_Iter loop
         -- Fixed-point multiplication: (A * B) / Scale
         Z_Re_Sq := Fixed(Shift_Right(Unsigned_32(Integer_64(Z_Re) * Integer_64(Z_Re)), Shift_Amt));
         Z_Im_Sq := Fixed(Shift_Right(Unsigned_32(Integer_64(Z_Im) * Integer_64(Z_Im)), Shift_Amt));
         
         -- Escape check: z_re^2 + z_im^2 > 4
         exit when (Z_Re_Sq + Z_Im_Sq) > Four_Fixed;
         
         -- Z = Z^2 + C
         -- Z_Im = 2 * Z_Re * Z_Im + C_Im
         Z_Im := Fixed(Shift_Right(Unsigned_32(Integer_64(Z_Re) * Integer_64(Z_Im)), Shift_Amt - 1)) + C_Im;
         -- Z_Re = Z_Re^2 - Z_Im^2 + C_Re
         Z_Re := Z_Re_Sq - Z_Im_Sq + C_Re;
         
         Count := I;
      end loop;
      
      return Count;
   end Get_Mandelbrot_Iter;

end VGPU.Fractal;
