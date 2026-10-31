with Titanium_BG;        use Titanium_BG;
with Wallpaper_Registry; use Wallpaper_Registry;
with Interfaces;         use Interfaces;

package Snowy_Village
  with SPARK_Mode => On
is
   -- FIX: Resolve SPARK freezing point ambiguity
   pragma Elaborate_Body;

   -- Configuration constants
   Max_Flakes : constant := 200;

   -- A single snowflake particle
   type Snowflake is record
      X      : Integer := 0;
      Y      : Integer := 0;
      Speed  : Integer := 1;
      Active : Boolean := False;
   end record;

   type Flake_Array is array (1 .. Max_Flakes) of Snowflake;

   type Snowy_Village_Wallpaper is new Wallpaper_Item with record
      Frame_Count : Unsigned_32 := 0;
      Flakes      : Flake_Array;
      RNG_Seed    : Unsigned_32 := 12345; -- Simple LCG State
   end record;

   overriding procedure Render
     (Self   : in out Snowy_Village_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

   overriding procedure Update
     (Self  : in out Snowy_Village_Wallpaper;
      Frame : in     Natural);

   overriding function Name (Self : Snowy_Village_Wallpaper) return String;

end Snowy_Village;
