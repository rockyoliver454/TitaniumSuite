with System;
with X11; use X11;

package body WM_State is

   procedure Clamp_Master_Factor is
   begin
      if Master_Factor < Master_Factor_Min then
         Master_Factor := Master_Factor_Min;
      elsif Master_Factor > Master_Factor_Max then
         Master_Factor := Master_Factor_Max;
      end if;
   end Clamp_Master_Factor;

   procedure Clamp_Height_Ratio (Idx : Client_Index) is
   begin
      if Idx = 0 then
         return;
      end if;
      if Clients (Idx).Height_Ratio < Height_Ratio_Min then
         Clients (Idx).Height_Ratio := Height_Ratio_Min;
      elsif Clients (Idx).Height_Ratio > Height_Ratio_Max then
         Clients (Idx).Height_Ratio := Height_Ratio_Max;
      end if;
   end Clamp_Height_Ratio;

   function Focus_Is_Valid return Boolean is
   begin
      if Focused_Client = 0 then
         return False;
      end if;
      if Focused_Client > Client_Count then
         return False;
      end if;
      if not Clients (Focused_Client).Is_Active then
         return False;
      end if;
      if Clients (Focused_Client).Workspace /= Current_Workspace then
         return False;
      end if;
      if Clients (Focused_Client).Screen /= Active_Screen then
         return False;
      end if;
      return True;
   end Focus_Is_Valid;

   procedure Recover_Focus is
   begin
      if Focus_Is_Valid then
         return;
      end if;
      Focused_Client := 0;
      Next_Focus;
   end Recover_Focus;

   procedure Init_Graphics is
      Screen_Num : int := 0;
   begin
      Screen_Num    := XDefaultScreen (Global_Display);
      Screen_Width  := Integer (XDisplayWidth (Global_Display, Screen_Num));
      Screen_Height := Integer (XDisplayHeight (Global_Display, Screen_Num));

      if Screen_Width < 64 then
         Screen_Width := 64;
      end if;
      if Screen_Height < 64 then
         Screen_Height := 64;
      end if;

      Text_GC := XCreateGC (
         Global_Display,
         XDefaultRootWindow (Global_Display),
         0,
         System.Null_Address);
      XSetForeground (Global_Display, Text_GC, XWhitePixel (Global_Display, 0));
   end Init_Graphics;

   function Find_Client (Window : X11.Window) return Client_Index is
   begin
      if Window = 0 then
         return 0;
      end if;
      for I in Valid_Index loop
         pragma Loop_Invariant (I in Valid_Index);
         if Clients (I).Is_Active and then
            (Clients (I).ID = Window or Clients (I).Tab_ID = Window)
         then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Client;

   procedure Update_Tab_Colors is
      Color   : unsigned_long;
      Color_I : Integer;
   begin
      for I in Valid_Index loop
         if Clients (I).Is_Active
           and then Clients (I).Workspace = Current_Workspace
           and then Clients (I).Screen = Active_Screen
         then
            Color_I := Clients (I).Color_Idx;
            if I = Focused_Client then
               Color := 16#FF4400#;
               XSetWindowBorder (Global_Display, Clients (I).ID, Border_Active);
            else
               Color := Tab_Colors (Color_I mod 4);
               XSetWindowBorder (Global_Display, Clients (I).ID, Border_Inactive);
            end if;

            XSetWindowBackground (Global_Display, Clients (I).Tab_ID, Color);
            XClearWindow (Global_Display, Clients (I).Tab_ID);
            declare
               -- Decimal label; safe for all Valid_Index values (1 .. 64)
               Label : constant String :=
                 "Tab " & Integer'Image (Integer (I));
               Str : constant char_array := To_C (Label);
            begin
               XDrawString (
                  Global_Display,
                  Clients (I).Tab_ID,
                  Text_GC,
                  5,
                  13,
                  Str,
                  int (Label'Length));
            end;
         end if;
      end loop;
   end Update_Tab_Colors;

   procedure Apply_Focus_X11 is
   begin
      Recover_Focus;
      if Focus_Is_Valid then
         XSetInputFocus (Global_Display, Clients (Focused_Client).ID, 1, 0);
         Update_Tab_Colors;
      end if;
   end Apply_Focus_X11;

   procedure Next_Focus is
      Start      : Client_Index := Focused_Client;
      Next       : Client_Index;
      Loop_Count : Integer := 0;
   begin
      if Client_Count = 0 then
         Focused_Client := 0;
         return;
      end if;

      if Start = 0 or else Start > Client_Count then
         Start := Client_Count;
      end if;

      Next := Start;
      loop
         if Next = Max_Clients then
            Next := 1;
         else
            Next := Next + 1;
         end if;

         if Next <= Client_Count
           and then Clients (Next).Is_Active
           and then Clients (Next).Workspace = Current_Workspace
           and then Clients (Next).Screen = Active_Screen
         then
            Focused_Client := Next;
            return;
         end if;

         Loop_Count := Loop_Count + 1;
         exit when Next = Start or Loop_Count > Max_Clients;
      end loop;

      Focused_Client := 0;
   end Next_Focus;

   procedure Prev_Focus is
      Start      : Client_Index := Focused_Client;
      Prev       : Client_Index;
      Loop_Count : Integer := 0;
   begin
      if Client_Count = 0 then
         Focused_Client := 0;
         return;
      end if;

      if Start = 0 or else Start > Client_Count then
         Start := 1;
      end if;

      Prev := Start;
      loop
         if Prev <= 1 then
            Prev := Max_Clients;
         else
            Prev := Prev - 1;
         end if;

         if Prev <= Client_Count
           and then Clients (Prev).Is_Active
           and then Clients (Prev).Workspace = Current_Workspace
           and then Clients (Prev).Screen = Active_Screen
         then
            Focused_Client := Prev;
            return;
         end if;

         Loop_Count := Loop_Count + 1;
         exit when Prev = Start or Loop_Count > Max_Clients;
      end loop;

      Focused_Client := 0;
   end Prev_Focus;

   procedure Add_Client (Window : X11.Window) is
      New_Tab : X11.Window;
      Screen  : int;
      White   : unsigned_long;
      Black   : unsigned_long;
      Attrs   : aliased XSetWindowAttributes;
   begin
      if Client_Count = Max_Clients then
         return;
      end if;
      if Window = 0 then
         return;
      end if;
      if Find_Client (Window) /= 0 then
         return;
      end if;

      Screen := XDefaultScreen (Global_Display);
      White  := XWhitePixel (Global_Display, Screen);
      Black  := XBlackPixel (Global_Display, Screen);
      New_Tab := XCreateSimpleWindow (
         Global_Display,
         XDefaultRootWindow (Global_Display),
         0, 0, 10, 10,
         1, Black, White);

      Attrs.Override_Redirect := 1;
      XChangeWindowAttributes (
         Global_Display,
         New_Tab,
         CWOverrideRedirect,
         Attrs'Access);
      XSelectInput (Global_Display, New_Tab, ButtonPressMask or ExposureMask);

      Client_Count := Client_Count + 1;
      Clients (Client_Count) := (
         ID              => Window,
         Tab_ID          => New_Tab,
         Is_Active       => True,
         Color_Idx       => Integer (Client_Count),
         Is_Floating     => False,
         Float_X         => 0,
         Float_Y         => 0,
         Float_W         => 0,
         Float_H         => 0,
         Height_Ratio    => 1.0,
         Workspace       => Current_Workspace,
         Supports_Delete => False,
         Screen          => Active_Screen
      );

      XSetWindowBorderWidth (Global_Display, Window, Border_Width);
      Focused_Client := Client_Count;
      Sync_Active_From_Globals;
   end Add_Client;

   procedure Remove_Client (Window : X11.Window) is
      Idx       : Client_Index;
      Old_Focus : Client_Index;
      Tab       : X11.Window;
   begin
      Idx := Find_Client (Window);
      if Idx = 0 then
         return;
      end if;

      Old_Focus := Focused_Client;
      Tab       := Clients (Idx).Tab_ID;

      if Tab /= 0 then
         XDestroyWindow (Global_Display, Tab);
      end if;

      if Idx < Client_Count then
         for I in Idx .. Client_Count - 1 loop
            Clients (I) := Clients (I + 1);
         end loop;
      end if;

      Clients (Client_Count) := (
         ID              => 0,
         Tab_ID          => 0,
         Is_Active       => False,
         Color_Idx       => 0,
         Is_Floating     => False,
         Float_X         => 0,
         Float_Y         => 0,
         Float_W         => 0,
         Float_H         => 0,
         Height_Ratio    => 1.0,
         Workspace       => 1,
         Supports_Delete => False,
         Screen          => 1
      );
      Client_Count := Client_Count - 1;

      -- Compact shifted indices after removal (critical for focus correctness)
      if Old_Focus = Idx then
         Focused_Client := 0;
      elsif Old_Focus > Idx then
         Focused_Client := Old_Focus - 1;
      else
         Focused_Client := Old_Focus;
      end if;

      Recover_Focus;
      Update_Tab_Colors;
   end Remove_Client;

   procedure Swap_Clients (A, B : Client_Index) is
      Temp : Client_Record;
   begin
      if A = B or A = 0 or B = 0 then
         return;
      end if;
      if A > Client_Count or B > Client_Count then
         return;
      end if;

      Temp := Clients (A);
      Clients (A) := Clients (B);
      Clients (B) := Temp;

      if Focused_Client = A then
         Focused_Client := B;
      elsif Focused_Client = B then
         Focused_Client := A;
      end if;
   end Swap_Clients;

   procedure Move_Client_Next is
      Target : Client_Index := 0;
   begin
      if Focused_Client = 0 or Focused_Client >= Client_Count then
         return;
      end if;
      for I in Focused_Client + 1 .. Client_Count loop
         if Clients (I).Is_Active
           and then Clients (I).Workspace = Current_Workspace
           and then Clients (I).Screen = Active_Screen
         then
            Target := I;
            exit;
         end if;
      end loop;

      if Target /= 0 then
         Swap_Clients (Focused_Client, Target);
      end if;
   end Move_Client_Next;

   procedure Move_Client_Prev is
      Target : Client_Index := 0;
   begin
      if Focused_Client <= 1 then
         return;
      end if;
      for I in reverse 1 .. Focused_Client - 1 loop
         if Clients (I).Is_Active
           and then Clients (I).Workspace = Current_Workspace
           and then Clients (I).Screen = Active_Screen
         then
            Target := I;
            exit;
         end if;
      end loop;

      if Target /= 0 then
         Swap_Clients (Focused_Client, Target);
      end if;
   end Move_Client_Prev;

   procedure Sync_Globals_From_Active is
      S : Screen_Record renames Screens (Active_Screen);
   begin
      if not S.Present then
         return;
      end if;
      Current_Workspace := S.Workspace;
      Current_Mode      := S.Mode;
      Master_Factor     := S.Master_Factor;
      Focused_Client    := S.Focused;
      Screen_Width      := S.W;
      Screen_Height     := S.H;
   end Sync_Globals_From_Active;

   procedure Sync_Active_From_Globals is
   begin
      Screens (Active_Screen).Workspace     := Current_Workspace;
      Screens (Active_Screen).Mode          := Current_Mode;
      Screens (Active_Screen).Master_Factor := Master_Factor;
      Screens (Active_Screen).Focused       := Focused_Client;
   end Sync_Active_From_Globals;

   procedure Init_Monitors is
      use System;
      Num      : aliased int := 0;
      Info_Addr : System.Address;
      Count    : Natural := 0;
   begin
      for S in Screen_Id loop
         Screens (S).Present := False;
      end loop;

      if XineramaIsActive (Global_Display) /= 0 then
         Info_Addr := XineramaQueryScreens (Global_Display, Num'Access);
         if Info_Addr /= Null_Address and then Num > 0 then
            declare
               type Info_Array is array (0 .. int (Max_Screens - 1))
                 of XineramaScreenInfo;
               pragma Convention (C, Info_Array);
               Infos : Info_Array;
               for Infos'Address use Info_Addr;
               Limit : constant Natural :=
                 Natural'Min (Natural (Num), Max_Screens);
            begin
               for I in 0 .. Limit - 1 loop
                  declare
                     Sid : constant Screen_Id := Screen_Id (I + 1);
                  begin
                     Screens (Sid).Present := True;
                     Screens (Sid).X := Integer (Infos (int (I)).X_Org);
                     Screens (Sid).Y := Integer (Infos (int (I)).Y_Org);
                     Screens (Sid).W := Integer (Infos (int (I)).Width);
                     Screens (Sid).H := Integer (Infos (int (I)).Height);
                     if Screens (Sid).W < 64 then
                        Screens (Sid).W := 64;
                     end if;
                     if Screens (Sid).H < 64 then
                        Screens (Sid).H := 64;
                     end if;
                     Count := Count + 1;
                  end;
               end loop;
               XFree (Info_Addr);
            end;
         end if;
      end if;

      if Count = 0 then
         Screens (1).Present := True;
         Screens (1).X := 0;
         Screens (1).Y := 0;
         Screens (1).W := Screen_Width;
         Screens (1).H := Screen_Height;
         Count := 1;
      end if;

      Screen_Count  := Count;
      Active_Screen := 1;
      Sync_Globals_From_Active;
   end Init_Monitors;

   procedure Focus_Next_Screen is
      Start : constant Screen_Id := Active_Screen;
      Cur   : Screen_Id := Active_Screen;
   begin
      Sync_Active_From_Globals;
      loop
         if Cur = Max_Screens then
            Cur := 1;
         else
            Cur := Cur + 1;
         end if;
         exit when Cur = Start;
         if Screens (Cur).Present then
            Active_Screen := Cur;
            Sync_Globals_From_Active;
            return;
         end if;
      end loop;
   end Focus_Next_Screen;

   procedure Focus_Prev_Screen is
      Start : constant Screen_Id := Active_Screen;
      Cur   : Screen_Id := Active_Screen;
   begin
      Sync_Active_From_Globals;
      loop
         if Cur = 1 then
            Cur := Max_Screens;
         else
            Cur := Cur - 1;
         end if;
         exit when Cur = Start;
         if Screens (Cur).Present then
            Active_Screen := Cur;
            Sync_Globals_From_Active;
            return;
         end if;
      end loop;
   end Focus_Prev_Screen;

   procedure Move_Focused_To_Next_Screen is
      Start : constant Screen_Id := Active_Screen;
      Cur   : Screen_Id := Active_Screen;
      Idx   : constant Client_Index := Focused_Client;
   begin
      if Idx = 0 then
         return;
      end if;
      Sync_Active_From_Globals;
      loop
         if Cur = Max_Screens then
            Cur := 1;
         else
            Cur := Cur + 1;
         end if;
         exit when Cur = Start;
         if Screens (Cur).Present then
            Clients (Idx).Screen := Cur;
            Clients (Idx).Workspace := Screens (Cur).Workspace;
            Screens (Start).Focused := 0;
            Active_Screen := Cur;
            Focused_Client := Idx;
            Sync_Globals_From_Active;
            Screens (Active_Screen).Focused := Idx;
            return;
         end if;
      end loop;
   end Move_Focused_To_Next_Screen;

   procedure Move_Focused_To_Prev_Screen is
      Start : constant Screen_Id := Active_Screen;
      Cur   : Screen_Id := Active_Screen;
      Idx   : constant Client_Index := Focused_Client;
   begin
      if Idx = 0 then
         return;
      end if;
      Sync_Active_From_Globals;
      loop
         if Cur = 1 then
            Cur := Max_Screens;
         else
            Cur := Cur - 1;
         end if;
         exit when Cur = Start;
         if Screens (Cur).Present then
            Clients (Idx).Screen := Cur;
            Clients (Idx).Workspace := Screens (Cur).Workspace;
            Screens (Start).Focused := 0;
            Active_Screen := Cur;
            Focused_Client := Idx;
            Sync_Globals_From_Active;
            Screens (Active_Screen).Focused := Idx;
            return;
         end if;
      end loop;
   end Move_Focused_To_Prev_Screen;

   function Ignore_X_Error (
      Display : X11.Display_Ptr;
      Error   : X11.XErrorEvent_Ptr
   ) return int is
      pragma Unreferenced (Display, Error);
   begin
      return 0;
   end Ignore_X_Error;

end WM_State;
