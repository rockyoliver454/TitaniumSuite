with Interfaces.C; use Interfaces.C;
with Ada.Unchecked_Conversion;
with X11; use X11;
with WM_State; use WM_State;
with WM_ICCCM;
with Layout;

package body WM_Keys is

   pragma Warnings (Off);
   function To_Key is new Ada.Unchecked_Conversion (XEvent, XKeyEvent);
   pragma Warnings (On);

   -- Grab a key under Mod1 plus CapsLock/NumLock variants
   procedure Grab_Key_Variants (Code : KeyCode; Base_Mods : Mask) is
      Root : constant Window := XDefaultRootWindow (Global_Display);
      type Mod_List is array (Positive range <>) of Mask;
      Mods : constant Mod_List := (
         Base_Mods,
         Base_Mods or LockMask,
         Base_Mods or Mod2Mask,
         Base_Mods or LockMask or Mod2Mask
      );
   begin
      for M of Mods loop
         XGrabKey (Global_Display, Code, M, Root, 1, 1, 1);
      end loop;
   end Grab_Key_Variants;

   procedure Setup_Keys is
      type Key_Array is array (1 .. 12) of KeySym;
      Keys : constant Key_Array := (
         XK_1, XK_2, XK_3, XK_4, XK_5, XK_6,
         XK_7, XK_8, XK_9, XK_0, XK_minus, XK_equal
      );
   begin
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_Right), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_Left), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_Up), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_Down), Mod1Mask);

      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_Right), Mod1Mask or ShiftMask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_Left), Mod1Mask or ShiftMask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_Up), Mod1Mask or ShiftMask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_Down), Mod1Mask or ShiftMask);

      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_q), Mod1Mask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_q), Mod1Mask or ShiftMask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_Return), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_d), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_m), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_h), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_r), Mod1Mask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_space), Mod1Mask or ControlMask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_Escape), Mod1Mask or ShiftMask);
      -- Alt+F1: TitaniumHelp key-reference popup (WASM-produced content)
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_F1), Mod1Mask);

      -- Multi-monitor: focus / move across screens
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_comma), Mod1Mask);
      Grab_Key_Variants (XKeysymToKeycode (Global_Display, XK_period), Mod1Mask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_comma), Mod1Mask or ShiftMask);
      Grab_Key_Variants (
         XKeysymToKeycode (Global_Display, XK_period), Mod1Mask or ShiftMask);

      for I in 1 .. 12 loop
         Grab_Key_Variants (
            XKeysymToKeycode (Global_Display, Keys (I)), Mod1Mask);
         Grab_Key_Variants (
            XKeysymToKeycode (Global_Display, Keys (I)), Mod1Mask or ShiftMask);
      end loop;
   end Setup_Keys;

   procedure Handle_Key (Event : X11.XEvent) is
      K_Event : constant XKeyEvent := To_Key (Event);

      Code_Right : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_Right);
      Code_Left : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_Left);
      Code_Up : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_Up);
      Code_Down : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_Down);

      Code_Q     : constant KeyCode := XKeysymToKeycode (Global_Display, XK_q);
      Code_Enter : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_Return);
      Code_D     : constant KeyCode := XKeysymToKeycode (Global_Display, XK_d);
      Code_M     : constant KeyCode := XKeysymToKeycode (Global_Display, XK_m);
      Code_H     : constant KeyCode := XKeysymToKeycode (Global_Display, XK_h);
      Code_R     : constant KeyCode := XKeysymToKeycode (Global_Display, XK_r);
      Code_Space : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_space);
      Code_Esc : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_Escape);
      Code_Comma : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_comma);
      Code_Period : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_period);
      Code_Help : constant KeyCode :=
        XKeysymToKeycode (Global_Display, XK_F1);

      type Code_Array is array (1 .. 12) of KeyCode;
      WS_Codes : constant Code_Array := (
         XKeysymToKeycode (Global_Display, XK_1),
         XKeysymToKeycode (Global_Display, XK_2),
         XKeysymToKeycode (Global_Display, XK_3),
         XKeysymToKeycode (Global_Display, XK_4),
         XKeysymToKeycode (Global_Display, XK_5),
         XKeysymToKeycode (Global_Display, XK_6),
         XKeysymToKeycode (Global_Display, XK_7),
         XKeysymToKeycode (Global_Display, XK_8),
         XKeysymToKeycode (Global_Display, XK_9),
         XKeysymToKeycode (Global_Display, XK_0),
         XKeysymToKeycode (Global_Display, XK_minus),
         XKeysymToKeycode (Global_Display, XK_equal)
      );

      Is_Shift : constant Boolean :=
        (K_Event.State and unsigned (ShiftMask)) /= 0;
   begin
      for I in 1 .. 12 loop
         if K_Event.Code = WS_Codes (I) then
            if Is_Shift then
               if WM_State.Focused_Client /= 0 then
                  WM_State.Clients (WM_State.Focused_Client).Workspace :=
                    WM_State.Workspace_Type (I);
                  WM_State.Next_Focus;
                  Layout.Tile_Windows (
                     WM_State.Screen_Width, WM_State.Screen_Height);
                  WM_State.Apply_Focus_X11;
               end if;
            else
               WM_State.Current_Workspace := WM_State.Workspace_Type (I);
               WM_State.Focused_Client := 0;
               WM_State.Next_Focus;
               WM_State.Sync_Active_From_Globals;
               Layout.Tile_Windows (
                  WM_State.Screen_Width, WM_State.Screen_Height);
               WM_State.Apply_Focus_X11;
            end if;
            return;
         end if;
      end loop;

      if K_Event.Code = Code_Comma then
         if Is_Shift then
            WM_State.Move_Focused_To_Prev_Screen;
         else
            WM_State.Focus_Prev_Screen;
         end if;
         Layout.Tile_Windows (
            WM_State.Screen_Width, WM_State.Screen_Height);
         WM_State.Apply_Focus_X11;
         return;
      elsif K_Event.Code = Code_Period then
         if Is_Shift then
            WM_State.Move_Focused_To_Next_Screen;
         else
            WM_State.Focus_Next_Screen;
         end if;
         Layout.Tile_Windows (
            WM_State.Screen_Width, WM_State.Screen_Height);
         WM_State.Apply_Focus_X11;
         return;
      end if;

      if K_Event.Code = Code_Esc then
         WM_State.Running := False;

      elsif K_Event.Code = Code_R then
         WM_State.Resize_Mode := not WM_State.Resize_Mode;
         WM_State.Update_Tab_Colors;

      elsif K_Event.Code = Code_Space then
         if WM_State.Focused_Client /= 0 then
            WM_State.Clients (WM_State.Focused_Client).Is_Floating :=
              not WM_State.Clients (WM_State.Focused_Client).Is_Floating;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         end if;

      elsif K_Event.Code = Code_Right then
         if Is_Shift then
            WM_State.Move_Client_Next;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         elsif WM_State.Resize_Mode then
            WM_State.Master_Factor := WM_State.Master_Factor + 0.05;
            WM_State.Clamp_Master_Factor;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
         else
            WM_State.Next_Focus;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         end if;

      elsif K_Event.Code = Code_Left then
         if Is_Shift then
            WM_State.Move_Client_Prev;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         elsif WM_State.Resize_Mode then
            WM_State.Master_Factor := WM_State.Master_Factor - 0.05;
            WM_State.Clamp_Master_Factor;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
         else
            WM_State.Prev_Focus;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         end if;

      elsif K_Event.Code = Code_Up then
         if Is_Shift then
            WM_State.Move_Client_Prev;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         elsif WM_State.Resize_Mode and WM_State.Focused_Client /= 0 then
            WM_State.Clients (WM_State.Focused_Client).Height_Ratio :=
              WM_State.Clients (WM_State.Focused_Client).Height_Ratio - 0.1;
            WM_State.Clamp_Height_Ratio (WM_State.Focused_Client);
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
         end if;

      elsif K_Event.Code = Code_Down then
         if Is_Shift then
            WM_State.Move_Client_Next;
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         elsif WM_State.Resize_Mode and WM_State.Focused_Client /= 0 then
            WM_State.Clients (WM_State.Focused_Client).Height_Ratio :=
              WM_State.Clients (WM_State.Focused_Client).Height_Ratio + 0.1;
            WM_State.Clamp_Height_Ratio (WM_State.Focused_Client);
            Layout.Tile_Windows (
               WM_State.Screen_Width, WM_State.Screen_Height);
         end if;

      elsif K_Event.Code = Code_M then
         WM_State.Current_Mode := WM_State.Mode_Monocle;
         Layout.Tile_Windows (
            WM_State.Screen_Width, WM_State.Screen_Height);

      elsif K_Event.Code = Code_H then
         for I in WM_State.Valid_Index loop
            WM_State.Clients (I).Is_Floating := False;
         end loop;
         WM_State.Current_Mode := WM_State.Mode_Tiled;
         Layout.Tile_Windows (
            WM_State.Screen_Width, WM_State.Screen_Height);

      elsif K_Event.Code = Code_Q then
         if WM_State.Focused_Client /= 0 then
            declare
               Victim : constant X11.Window :=
                 WM_State.Clients (WM_State.Focused_Client).ID;
            begin
               if Is_Shift then
                  -- Alt+Shift+Q: force kill
                  WM_ICCCM.Force_Kill (Victim);
               else
                  -- Alt+Q: soft close (WM_DELETE_WINDOW or destroy)
                  WM_ICCCM.Soft_Close (Victim);
               end if;
               Layout.Tile_Windows (
                  WM_State.Screen_Width, WM_State.Screen_Height);
               WM_State.Apply_Focus_X11;
            end;
         end if;

      elsif K_Event.Code = Code_D then
         declare
            Result : int;
            pragma Unreferenced (Result);
         begin
            Result := System_Call (To_C ("titaniumrun &"));
         end;

      elsif K_Event.Code = Code_Help then
         declare
            Result : int;
            pragma Unreferenced (Result);
         begin
            Result := System_Call (To_C ("titaniumhelp &"));
         end;

      elsif K_Event.Code = Code_Enter then
         declare
            Result : int;
            pragma Unreferenced (Result);
         begin
            Result := System_Call (To_C ("xterm &"));
         end;
      end if;
   end Handle_Key;

end WM_Keys;
