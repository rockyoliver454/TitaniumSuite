with Titanium_BG; use Titanium_BG;
with Interfaces;  use Interfaces;

package Titanium_BG.Renderer
  with SPARK_Mode => On
is
   -- The "Playlist"
   type Algo_Mode is (Plasma, Xor_Grid, Static_Noise);

   type Generator_State is record
      Frame_Count  : Unsigned_32;
      Current_Mode : Algo_Mode;
      Reg_A        : Unsigned_32; -- General purpose register 1
      Reg_B        : Unsigned_32; -- General purpose register 2
   end record;

   procedure Render_Frame
     (Buffer : in out Pixel_Array;
      State  : in out Generator_State;
      Config : in Screen_Config)
     with
       Global  => null,
       Depends => (Buffer => (Buffer, State, Config),
                   State  => State);

end Titanium_BG.Renderer;
