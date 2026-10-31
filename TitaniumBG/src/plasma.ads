with Titanium_BG;        use Titanium_BG;
with Wallpaper_Registry; use Wallpaper_Registry;
with Interfaces;         use Interfaces;

package Plasma
  with SPARK_Mode => On
is
   -- FIX: Resolve SPARK freezing point error E0003
   pragma Elaborate_Body;

   type Mode_Type is (Plasma_Effect, Xor_Effect, Noise_Effect);

   type Plasma_Wallpaper is new Wallpaper_Item with record
      Frame_Count  : Unsigned_32 := 0;
      Reg_A        : Unsigned_32 := 0;
      Reg_B        : Unsigned_32 := 0;
      Current_Mode : Mode_Type   := Plasma_Effect;
   end record;

   overriding procedure Render
     (Self   : in out Plasma_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

   overriding procedure Update
     (Self  : in out Plasma_Wallpaper;
      Frame : in     Natural);

   overriding function Name (Self : Plasma_Wallpaper) return String;

end Plasma;
