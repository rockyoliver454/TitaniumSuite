with WM_State; use WM_State;
with X11;
with Interfaces.C; use Interfaces.C;

package body Layout is

   procedure Tile_One_Screen (Sid : Screen_Id) is
      S : Screen_Record renames Screens (Sid);

      Count         : Integer := 0;
      Master_Width  : Integer;
      Stack_X       : Integer;
      Tab_Width     : Integer;
      Tab_X         : Integer;
      Tab_Height    : constant Integer := 20;
      Current_Tab   : Integer := 0;
      Stack_Height  : Integer;
      Stack_Y       : Integer := 0;
      Total_Stack_Weight : Float := 0.0;
      This_Height   : Integer;
      Gap           : constant Integer := Gap_Size;
      Safe_Width    : Integer := S.W;
      Safe_Height   : Integer := S.H;
      Ox            : constant Integer := S.X;
      Oy            : constant Integer := S.Y;
      Local_Mode    : constant Layout_Mode_Type := S.Mode;
      Local_WS      : constant Workspace_Type := S.Workspace;
      Local_Master  : Float := S.Master_Factor;
      Local_Focus   : constant Client_Index := S.Focused;

      function Gap_X (X : Integer) return int is
      begin
         return int (Ox + X + Gap);
      end Gap_X;

      function Gap_Y (Y : Integer) return int is
      begin
         return int (Oy + Y + Gap);
      end Gap_Y;

      function Gap_W (W : Integer) return unsigned is
         Safe_W : Integer := W - (2 * Gap);
      begin
         if Safe_W < 10 then
            Safe_W := 10;
         end if;
         return unsigned (Safe_W);
      end Gap_W;

      function Gap_H (H : Integer) return unsigned is
         Safe_H : Integer := H - (2 * Gap);
      begin
         if Safe_H < 10 then
            Safe_H := 10;
         end if;
         return unsigned (Safe_H);
      end Gap_H;

      function Safe_Unsigned (V : Integer) return unsigned is
      begin
         if V < 1 then
            return 1;
         end if;
         return unsigned (V);
      end Safe_Unsigned;
   begin
      if not S.Present then
         return;
      end if;
      if Safe_Width < 64 then
         Safe_Width := 64;
      end if;
      if Safe_Height < 64 then
         Safe_Height := 64;
      end if;
      if Local_Master < Master_Factor_Min then
         Local_Master := Master_Factor_Min;
      elsif Local_Master > Master_Factor_Max then
         Local_Master := Master_Factor_Max;
      end if;

      for I in Valid_Index loop
         if Clients (I).Is_Active and then Clients (I).Screen = Sid then
            if Clients (I).Workspace = Local_WS then
               if not Clients (I).Is_Floating then
                  Count := Count + 1;
               else
                  X11.XMapWindow (X11.Global_Display, Clients (I).ID);
                  X11.XMapWindow (X11.Global_Display, Clients (I).Tab_ID);
                  X11.XRaiseWindow (X11.Global_Display, Clients (I).ID);
                  X11.XRaiseWindow (X11.Global_Display, Clients (I).Tab_ID);
               end if;
            else
               X11.XUnmapWindow (X11.Global_Display, Clients (I).ID);
               X11.XUnmapWindow (X11.Global_Display, Clients (I).Tab_ID);
            end if;
         end if;
      end loop;

      if Count = 0 then
         return;
      end if;

      if Local_Mode = Mode_Monocle then
         Tab_Width := Safe_Width / Count;
         if Tab_Width < 1 then
            Tab_Width := 1;
         end if;
         for I in Valid_Index loop
            if Clients (I).Is_Active
              and then Clients (I).Screen = Sid
              and then Clients (I).Workspace = Local_WS
              and then not Clients (I).Is_Floating
            then
               Tab_X := Current_Tab * Tab_Width;
               X11.XMapWindow (X11.Global_Display, Clients (I).Tab_ID);
               X11.XMoveResizeWindow (
                  X11.Global_Display, Clients (I).Tab_ID,
                  int (Ox + Tab_X), int (Oy),
                  Safe_Unsigned (Tab_Width), Safe_Unsigned (Tab_Height));
               if I = Local_Focus
                 or else (Local_Focus = 0 and then Current_Tab = 0)
               then
                  X11.XMoveResizeWindow (
                     X11.Global_Display, Clients (I).ID,
                     Gap_X (0), Gap_Y (Tab_Height),
                     Gap_W (Safe_Width), Gap_H (Safe_Height - Tab_Height));
                  X11.XMapWindow (X11.Global_Display, Clients (I).ID);
               else
                  X11.XUnmapWindow (X11.Global_Display, Clients (I).ID);
               end if;
               Current_Tab := Current_Tab + 1;
            end if;
         end loop;
      else
         if Count = 1 then
            Master_Width := Safe_Width;
         else
            Master_Width := Integer (Float (Safe_Width) * Local_Master);
            if Master_Width < 50 then
               Master_Width := 50;
            end if;
            if Master_Width > Safe_Width - 50 then
               Master_Width := Safe_Width - 50;
            end if;
         end if;
         Stack_X := Master_Width;
         Total_Stack_Weight := 0.0;
         Current_Tab := 0;
         for I in Valid_Index loop
            if Clients (I).Is_Active
              and then Clients (I).Screen = Sid
              and then Clients (I).Workspace = Local_WS
              and then not Clients (I).Is_Floating
            then
               Current_Tab := Current_Tab + 1;
               if Current_Tab > 1 then
                  Total_Stack_Weight :=
                    Total_Stack_Weight + Clients (I).Height_Ratio;
               end if;
            end if;
         end loop;
         if Total_Stack_Weight <= 0.0 then
            Total_Stack_Weight := 1.0;
         end if;
         Current_Tab := 0;
         Stack_Height := Safe_Height;
         Stack_Y := 0;
         for I in Valid_Index loop
            if Clients (I).Is_Active
              and then Clients (I).Screen = Sid
              and then Clients (I).Workspace = Local_WS
              and then not Clients (I).Is_Floating
            then
               Current_Tab := Current_Tab + 1;
               if Current_Tab = 1 then
                  X11.XMapWindow (X11.Global_Display, Clients (I).Tab_ID);
                  X11.XMoveResizeWindow (
                     X11.Global_Display, Clients (I).Tab_ID,
                     int (Ox), int (Oy),
                     Safe_Unsigned (Master_Width), Safe_Unsigned (Tab_Height));
                  X11.XMoveResizeWindow (
                     X11.Global_Display, Clients (I).ID,
                     Gap_X (0), Gap_Y (Tab_Height),
                     Gap_W (Master_Width), Gap_H (Safe_Height - Tab_Height));
                  X11.XMapWindow (X11.Global_Display, Clients (I).ID);
               else
                  if Current_Tab = Count then
                     This_Height := Safe_Height - Stack_Y;
                  else
                     This_Height := Integer (
                        Float (Stack_Height)
                        * (Clients (I).Height_Ratio / Total_Stack_Weight));
                  end if;
                  if This_Height < Tab_Height + 10 then
                     This_Height := Tab_Height + 10;
                  end if;
                  X11.XMapWindow (X11.Global_Display, Clients (I).Tab_ID);
                  X11.XMoveResizeWindow (
                     X11.Global_Display, Clients (I).Tab_ID,
                     int (Ox + Stack_X), int (Oy + Stack_Y),
                     Safe_Unsigned (Safe_Width - Master_Width),
                     Safe_Unsigned (Tab_Height));
                  if This_Height > Tab_Height then
                     X11.XMoveResizeWindow (
                        X11.Global_Display, Clients (I).ID,
                        Gap_X (Stack_X), Gap_Y (Stack_Y + Tab_Height),
                        Gap_W (Safe_Width - Master_Width),
                        Gap_H (This_Height - Tab_Height));
                  end if;
                  X11.XMapWindow (X11.Global_Display, Clients (I).ID);
                  Stack_Y := Stack_Y + This_Height;
               end if;
            end if;
         end loop;
      end if;
   end Tile_One_Screen;

   procedure Tile_Windows (Display_Width, Display_Height : Integer) is
      pragma Unreferenced (Display_Width, Display_Height);
   begin
      Sync_Active_From_Globals;
      for Sid in Screen_Id loop
         if Screens (Sid).Present then
            Tile_One_Screen (Sid);
         end if;
      end loop;
      X11.XFlush (X11.Global_Display);
      Update_Tab_Colors;
   end Tile_Windows;

end Layout;
