with Titanium_BG;        use Titanium_BG;
with Wallpaper_Registry; use Wallpaper_Registry;
with Interfaces;         use Interfaces;

package Desert_Mountain
  with SPARK_Mode => On
is
   pragma Elaborate_Body;

   -- Static scene coordinates moved to package constants
   Coyote_X : constant Integer := 220;
   Coyote_Y : constant Integer := 210;

   type Buzzard_State is (Circling, Descending, Feasting, Ascending);

   type Desert_Mountain_Wallpaper is new Wallpaper_Item with record
      Frame_Count    : Unsigned_32 := 0;
      RNG_Seed       : Unsigned_32 := 54321;
      
      -- Buzzard State
      Bird_X         : Integer := 100;
      Bird_Y         : Integer := 40;
      State          : Buzzard_State := Circling;
      State_Timer    : Natural := 0;
   end record;

   overriding procedure Render
     (Self   : in out Desert_Mountain_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

   overriding procedure Update
     (Self  : in out Desert_Mountain_Wallpaper;
      Frame : in     Natural);

   overriding function Name (Self : Desert_Mountain_Wallpaper) return String;

end Desert_Mountain;
