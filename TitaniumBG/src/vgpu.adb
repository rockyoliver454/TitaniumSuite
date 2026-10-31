package body VGPU 
  with SPARK_Mode => On
is

   procedure Set_Pixel
     (VX     : in Integer;
      VY     : in Integer;
      Col    : in Pixel_Color;
      Buffer : in out Pixel_Array;
      Config : in Screen_Config)
   is
      X_Start : constant Integer := (VX * Config.Width) / Virtual_Width;
      X_End   : constant Integer := ((VX + 1) * Config.Width) / Virtual_Width;
      Y_Start : constant Integer := (VY * Config.Height) / Virtual_Height;
      Y_End   : constant Integer := ((VY + 1) * Config.Height) / Virtual_Height;
   begin
      if VX < 0 or VX >= Virtual_Width or VY < 0 or VY >= Virtual_Height then
         return;
      end if;

      for Y in Y_Start .. Y_End - 1 loop
         for X in X_Start .. X_End - 1 loop
            if Y * Config.Width + X < Buffer'Length then
               Buffer (Y * Config.Width + X) := Col;
            end if;
         end loop;
      end loop;
   end Set_Pixel;

end VGPU;
