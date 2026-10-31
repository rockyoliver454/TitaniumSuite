with Titanium_BG;        use Titanium_BG;
with Wallpaper_Registry; use Wallpaper_Registry;
with Interfaces;         use Interfaces;

package Jungle_River
  with SPARK_Mode => On
is
   pragma Elaborate_Body;

   type Jungle_River_Wallpaper is new Wallpaper_Item with record
      Frame_Count : Unsigned_32 := 0;
      Flow_Offset : Integer     := 0;
      RNG_Seed    : Unsigned_32 := 98765;
   end record;

   overriding procedure Render
     (Self   : in out Jungle_River_Wallpaper;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config);

   overriding procedure Update
     (Self  : in out Jungle_River_Wallpaper;
      Frame : in     Natural);

   overriding function Name (Self : Jungle_River_Wallpaper) return String;

end Jungle_River;
