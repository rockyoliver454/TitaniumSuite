with X11;
with Interfaces.C; use Interfaces.C;
with System;

package WM_State is
   pragma SPARK_Mode (On);

   Max_Clients : constant := 64;
   Max_Screens : constant := 4;

   Running : Boolean := True;

   Screen_Width  : Integer := 1024;
   Screen_Height : Integer := 768;
   Gap_Size      : constant Integer := 10;
   Border_Width  : constant unsigned := 2;

   Border_Active   : constant unsigned_long := 16#FF4400#;
   Border_Inactive : constant unsigned_long := 16#444444#;

   type Workspace_Type is range 1 .. 12;
   Current_Workspace : Workspace_Type := 1;

   Master_Factor     : Float := 0.55;
   Master_Factor_Min : constant Float := 0.1;
   Master_Factor_Max : constant Float := 0.9;
   Height_Ratio_Min  : constant Float := 0.1;
   Height_Ratio_Max  : constant Float := 10.0;

   type Layout_Mode_Type is (Mode_Tiled, Mode_Monocle);
   Current_Mode : Layout_Mode_Type := Mode_Monocle;

   Resize_Mode : Boolean := False;

   type Client_Index is range 0 .. Max_Clients;
   subtype Valid_Index is Client_Index range 1 .. Max_Clients;

   type Screen_Id is range 1 .. Max_Screens;
   type Screen_Record is record
      Present       : Boolean          := False;
      X, Y, W, H    : Integer          := 0;
      Workspace     : Workspace_Type   := 1;
      Mode          : Layout_Mode_Type := Mode_Monocle;
      Master_Factor : Float            := 0.55;
      Focused       : Client_Index     := 0;
   end record;
   type Screen_Array is array (Screen_Id) of Screen_Record;

   Screens       : Screen_Array;
   Screen_Count  : Natural := 1;
   Active_Screen : Screen_Id := 1;

   type Color_Array is array (0 .. 3) of unsigned_long;
   Tab_Colors : constant Color_Array := (
      16#0055FF#,
      16#00AA00#,
      16#DD00DD#,
      16#00AAAA#
   );

   Text_GC : X11.GC := X11.GC (System.Null_Address);

   type Client_Record is record
      ID              : X11.Window     := 0;
      Tab_ID          : X11.Window     := 0;
      Is_Active       : Boolean        := False;
      Color_Idx       : Integer        := 0;
      Is_Floating     : Boolean        := False;
      Height_Ratio    : Float          := 1.0;
      Workspace       : Workspace_Type := 1;
      Supports_Delete : Boolean        := False;
      Screen          : Screen_Id      := 1;
   end record;
   type Client_Array is array (Valid_Index) of Client_Record;

   Clients : Client_Array := (others => (
      ID              => 0,
      Tab_ID          => 0,
      Is_Active       => False,
      Color_Idx       => 0,
      Is_Floating     => False,
      Height_Ratio    => 1.0,
      Workspace       => 1,
      Supports_Delete => False,
      Screen          => 1
   ));
   Client_Count   : Client_Index := 0;
   Focused_Client : Client_Index := 0;
   Last_Stack     : Client_Index := 0;

   procedure Add_Client (Window : X11.Window)
     with Pre => Client_Count < Max_Clients;
   procedure Remove_Client (Window : X11.Window);
   function Find_Client (Window : X11.Window) return Client_Index;

   procedure Next_Focus;
   procedure Prev_Focus;
   procedure Move_Client_Next;
   procedure Move_Client_Prev;

   procedure Apply_Focus_X11;
   procedure Update_Tab_Colors;
   procedure Init_Graphics;

   procedure Clamp_Master_Factor;
   procedure Clamp_Height_Ratio (Idx : Client_Index);
   function Focus_Is_Valid return Boolean;

   procedure Init_Monitors
     with SPARK_Mode => Off;
   procedure Sync_Globals_From_Active;
   procedure Sync_Active_From_Globals;
   procedure Focus_Next_Screen;
   procedure Focus_Prev_Screen;
   procedure Move_Focused_To_Next_Screen;
   procedure Move_Focused_To_Prev_Screen;

   function Ignore_X_Error (
      Display : X11.Display_Ptr;
      Error   : X11.XErrorEvent_Ptr
   ) return Interfaces.C.int
     with Convention => C, SPARK_Mode => Off;

end WM_State;
