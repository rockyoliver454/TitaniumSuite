with Titanium_BG;          use Titanium_BG;
with Titanium_BG.Memory;   use Titanium_BG.Memory; 
with Wallpaper_Registry;   use Wallpaper_Registry;
with Wallpaper_Instances;  use Wallpaper_Instances; -- Use static storage
with X11;                  use X11;
with Interfaces.C;         use Interfaces.C;
with Interfaces;           use Interfaces; 
with System;               
with Ada.Text_IO;

procedure Main is
   Config : Screen_Config;
   
   -- X11 Variables
   Disp       : Display_Ptr;
   Root       : Window;
   Attrs      : aliased XWindowAttributes;
   Res        : int;
   pragma Unreferenced (Res); 

   X_Image    : System.Address;
   Screen_Idx : int;
   The_GC     : GC;
   Depth      : int;
   
   Frame_Counter : Natural := 0;

begin
   Ada.Text_IO.Put_Line ("TitaniumBG: Initializing Registry...");

   -- 1. REGISTER WALLPAPERS
   Init;
   
   -- Use 'Access now that they are library-level (static) objects
   Register (WP_Plasma, Plasma_Inst'Access);
   Register (WP_Snow,   Snow_Inst'Access);
   Register (WP_Jungle, Jungle_Inst'Access);
   Register (WP_Desert_Mountain, Desert_Inst'Access);
   
   -- Start with Snow to test the fix
   Set_Active (WP_Desert_Mountain);

   -- 2. X11 BOILERPLATE
   Disp := XOpenDisplay (Interfaces.C.To_C (String'("")));
   if Disp = Display_Ptr (System.Null_Address) then
      Ada.Text_IO.Put_Line ("Error: Cannot open display.");
      return;
   end if;

   Root       := XDefaultRootWindow (Disp);
   Screen_Idx := XDefaultScreen (Disp);
   The_GC     := XDefaultGC (Disp, Screen_Idx);
   Depth      := XDefaultDepth (Disp, Screen_Idx);

   Res := XGetWindowAttributes (Disp, Root, Attrs'Access);
   Config.Width  := Integer (Attrs.Width);
   Config.Height := Integer (Attrs.Height);

   X_Image := XCreateImage
     (Display        => Disp,
      Visual         => Attrs.Visual,
      Depth          => unsigned(Depth),
      Format         => 2, 
      Offset         => 0,
      Data           => Buffer(0)'Address,
      Width          => unsigned(Config.Width),
      Height         => unsigned(Config.Height),
      Bitmap_Pad     => 32,
      Bytes_Per_Line => 0);

   -- 3. MAIN LOOP
   loop
      Render_Current (Buffer, Config);
      Update_Current (Frame_Counter);
      
      -- Auto-cycle every 1000 frames
      --if Frame_Counter mod 1000 = 0 and Frame_Counter > 0 then
      --   Next_Mode;
      --   Ada.Text_IO.Put_Line ("Switching to: " & Get_Current_Name);
      --end if;

      --Frame_Counter := Frame_Counter + 1;

      Res := XPutImage
        (Display  => Disp,
         Drawable => Root,
         Context  => The_GC,
         Image    => X_Image,
         Src_X    => 0, Src_Y => 0,
         Dest_X   => 0, Dest_Y => 0,
         Width    => unsigned(Config.Width),
         Height   => unsigned(Config.Height));

      delay 0.033;
   end loop;

end Main;
