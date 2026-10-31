with Ada.Text_IO;

package body Wallpaper_Registry is

   -----------------------------------------------------------------------------
   -- INTERNAL STORAGE
   -----------------------------------------------------------------------------
   --  Mirroring the 'Registry : array (Texture_ID) of Texture' design
   Registry_Array : array (Wallpaper_ID) of access Wallpaper_Item'Class := (others => null);
   
   --  Mirroring the 'Is_Real' / safety flags
   Is_Registered  : array (Wallpaper_ID) of Boolean := (others => False);
   
   Current_ID     : Wallpaper_ID := WP_None;
   Is_Initialized : Boolean := False;

   -----------------------------------------------------------------------------
   -- INIT
   -----------------------------------------------------------------------------
   procedure Init is
   begin
      if not Is_Initialized then
         Is_Initialized := True;
         Ada.Text_IO.Put_Line ("WALLPAPER_REGISTRY: System Initialized.");
      end if;
   end Init;

   -----------------------------------------------------------------------------
   -- REGISTER
   -----------------------------------------------------------------------------
   procedure Register (ID : Wallpaper_ID; Item : access Wallpaper_Item'Class) is
   begin
      if not Is_Initialized then Init; end if;

      Registry_Array(ID) := Item;
      Is_Registered(ID)  := True;

      Ada.Text_IO.Put_Line ("WALLPAPER_REGISTRY: Registered ID " & ID'Image);

      -- Auto-activate if this is the first valid wallpaper
      if Current_ID = WP_None then
         Current_ID := ID;
      end if;
   end Register;

   -----------------------------------------------------------------------------
   -- SET ACTIVE
   -----------------------------------------------------------------------------
   procedure Set_Active (ID : Wallpaper_ID) is
   begin
      if Is_Registered(ID) then
         Current_ID := ID;
         Ada.Text_IO.Put_Line ("WALLPAPER_REGISTRY: Switched to " & ID'Image);
      else
         Ada.Text_IO.Put_Line ("WALLPAPER_REGISTRY: Error - Attempted to switch to unregistered ID " & ID'Image);
      end if;
   end Set_Active;

   -----------------------------------------------------------------------------
   -- NEXT MODE
   -----------------------------------------------------------------------------
   procedure Next_Mode is
      Next : Wallpaper_ID := Current_ID;
   begin
      loop
         if Next = Wallpaper_ID'Last then
            Next := Wallpaper_ID'First;
         else
            Next := Wallpaper_ID'Succ(Next);
         end if;
         
         -- Stop if we found a registered one or circled back to start
         exit when Is_Registered(Next) or else Next = Current_ID;
      end loop;

      if Is_Registered(Next) then
         Current_ID := Next;
      end if;
   end Next_Mode;

   -----------------------------------------------------------------------------
   -- RENDER CURRENT
   -----------------------------------------------------------------------------
   procedure Render_Current (Buffer : in out Pixel_Array; Config : in Screen_Config) is
   begin
      if Current_ID /= WP_None and then Registry_Array(Current_ID) /= null then
         Registry_Array(Current_ID).Render(Buffer, Config);
      end if;
   end Render_Current;

   -----------------------------------------------------------------------------
   -- UPDATE CURRENT
   -----------------------------------------------------------------------------
   procedure Update_Current (Frame : in Natural) is
   begin
      if Current_ID /= WP_None and then Registry_Array(Current_ID) /= null then
         Registry_Array(Current_ID).Update(Frame);
      end if;
   end Update_Current;

   -----------------------------------------------------------------------------
   -- GET CURRENT NAME
   -----------------------------------------------------------------------------
   function Get_Current_Name return String is
   begin
      if Current_ID /= WP_None and then Registry_Array(Current_ID) /= null then
         return Registry_Array(Current_ID).Name;
      else
         return "None";
      end if;
   end Get_Current_Name;

end Wallpaper_Registry;
