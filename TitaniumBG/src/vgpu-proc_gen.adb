with Interfaces; use Interfaces;

package body VGPU.Proc_Gen 
  with SPARK_Mode => On
is

   -- Simple deterministic hash for procedural noise
   function Hash (X, Y : Integer; Seed : Unsigned_32) return Unsigned_32 is
      Result : Unsigned_32 := Seed;
   begin
      -- Linear Congruential-style hash using unsigned math
      Result := Result xor (Unsigned_32(abs X) * 1664525);
      Result := Result xor (Unsigned_32(abs Y) * 1013904223);
      return Result;
   end Hash;

   -----------------------------------------------------------------------------
   -- Get_Pixel_Color
   -----------------------------------------------------------------------------
   function Get_Pixel_Color
     (VX      : Integer;
      VY      : Integer;
      Seed    : Unsigned_32;
      Context : Texture_Type) return Pixel_Color
   is
      H : constant Unsigned_32 := Hash(VX, VY, Seed);
   begin
      case Context is
         when Wood_Grain =>
            if VY mod 8 = 0 then
               return 16#00_20_10_05#; -- Dark plank gap
            elsif (H mod 100) > 95 then
               return 16#00_30_18_08#; -- Darker grain knot
            else
               return 16#00_45_25_10#; -- Natural wood
            end if;

         when Rough_Stone =>
            if (H mod 100) > 80 then
               return 16#00_30_30_30#;
            elsif (H mod 100) > 60 then
               return 16#00_60_60_60#;
            else
               return 16#00_45_45_45#;
            end if;

         when Grass_Tuft =>
            if (H mod 1000) > 980 then
               return 16#00_20_50_20#;
            else
               return 16#00_D0_D0_E0#;
            end if;
      end case;
   end Get_Pixel_Color;

end VGPU.Proc_Gen;
