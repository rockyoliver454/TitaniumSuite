with Interfaces; use Interfaces;

package Titanium_BG is
   pragma Pure;

   -- Static Resolution Config (Max Allocation)
   Max_Width  : constant Integer := 3840;
   Max_Height : constant Integer := 2160;
   Max_Pixels : constant Integer := Max_Width * Max_Height;

   type Pixel_Color is new Unsigned_32;

   -- The linear buffer type
   type Pixel_Array is array (0 .. Max_Pixels - 1) of Pixel_Color
     with Convention => C;

   -- Configuration for the current run
   type Screen_Config is record
      Width  : Integer;
      Height : Integer;
   end record;

end Titanium_BG;
