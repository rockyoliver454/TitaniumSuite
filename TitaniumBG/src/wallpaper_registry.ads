with Titanium_BG; use Titanium_BG;

package Wallpaper_Registry is
   
   --  MIRROR DESIGN PHILOSOPHY:
   --  Use an Enum ID system rather than a dynamic list.
   --  This allows O(1) lookups and strict categorization.
   type Wallpaper_ID is (
      WP_None, 
      WP_Plasma, 
      WP_Snow,
      WP_Jungle,
      WP_Desert_Mountain
      );

   --  The Interface (Contract)
   --  Equivalent to the 'Texture' struct in your registry, but for code.
   type Wallpaper_Item is interface;

   procedure Render 
     (Self   : in out Wallpaper_Item;
      Buffer : in out Pixel_Array;
      Config : in     Screen_Config) is abstract;

   procedure Update
     (Self  : in out Wallpaper_Item;
      Frame : in     Natural) is abstract;
      
   function Name (Self : Wallpaper_Item) return String is abstract;

   -----------------------------------------------------------------------------
   -- MANAGEMENT
   -----------------------------------------------------------------------------
   procedure Init;
   
   --  Register a wallpaper pointer to a specific ID slot.
   --  'Item' must be aliased and declared in a scope that outlives the loop (e.g. Main).
   procedure Register (ID : Wallpaper_ID; Item : access Wallpaper_Item'Class);
   
   --  Switch the active wallpaper.
   procedure Set_Active (ID : Wallpaper_ID);
   
   --  Cycle to the next registered wallpaper.
   procedure Next_Mode;

   -----------------------------------------------------------------------------
   -- CORE LOOP WRAPPERS
   -----------------------------------------------------------------------------
   procedure Render_Current (Buffer : in out Pixel_Array; Config : in Screen_Config);
   procedure Update_Current (Frame : in Natural);
   function Get_Current_Name return String;

end Wallpaper_Registry;
