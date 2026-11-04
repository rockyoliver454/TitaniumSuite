with Interfaces.C; use Interfaces.C;
with Ada.Unchecked_Conversion;
with System;
with Layout;
with X11; use X11;
with WM_State; use WM_State;
with WM_Keys;
with WM_ICCCM;
with Session_Persist;

procedure Main is
   pragma SPARK_Mode (Off);

   Display     : Display_Ptr;
   Root        : Window;
   Event       : XEvent;
   Old_Handler : X11.XErrorHandler;
   Old_IO      : X11.XIOErrorHandler;
   pragma Unreferenced (Old_Handler, Old_IO);

   procedure C_Exit (Status : int)
     with Import, Convention => C, External_Name => "exit";

   pragma Warnings (Off);
   function To_MapRequest is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XMapRequestEvent);
   function To_Destroy is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XDestroyWindowEvent);
   function To_Key is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XKeyEvent);
   function To_Unmap is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XUnmapEvent);
   function To_Configure is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XConfigureEvent);
   function To_ConfigureRequest is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XConfigureRequestEvent);
   pragma Warnings (On);

   procedure Grab_Client_Buttons (Win : Window) is
      type Mod_List is array (Positive range <>) of Mask;
      Mods : constant Mod_List := (
         Mod1Mask,
         Mod1Mask or LockMask,
         Mod1Mask or Mod2Mask,
         Mod1Mask or LockMask or Mod2Mask
      );
   begin
      for M of Mods loop
         XGrabButton (
            Display, 1, M, Win, 0,
            ButtonPressMask or ButtonReleaseMask or PointerMotionMask,
            1, 1, 0, 0);
         XGrabButton (
            Display, 3, M, Win, 0,
            ButtonPressMask or ButtonReleaseMask or PointerMotionMask,
            1, 1, 0, 0);
      end loop;
   end Grab_Client_Buttons;

   procedure Handle_One_Event is
      E_Type : Event_Type;
   begin
      if Event.Ex_Type = 17 then
         declare
            D_Event : constant XDestroyWindowEvent := To_Destroy (Event);
         begin
            WM_State.Remove_Client (D_Event.Win);
            Layout.Tile_Windows (WM_State.Screen_Width, WM_State.Screen_Height);
            WM_State.Apply_Focus_X11;
         end;
         return;
      end if;

      if Event.Ex_Type = 18 then
         declare
            U_Event : constant XUnmapEvent := To_Unmap (Event);
            Idx     : constant Client_Index := WM_State.Find_Client (U_Event.Win);
            Ignore  : Boolean := False;
         begin
            if Idx /= 0 then
               if WM_State.Clients (Idx).Workspace /= WM_State.Current_Workspace then
                  Ignore := True;
               end if;

               if WM_State.Current_Mode = WM_State.Mode_Monocle
                 and then Idx /= WM_State.Focused_Client
               then
                  Ignore := True;
               end if;

               if not Ignore then
                  WM_State.Remove_Client (U_Event.Win);
                  Layout.Tile_Windows (
                     WM_State.Screen_Width, WM_State.Screen_Height);
                  WM_State.Apply_Focus_X11;
               end if;
            end if;
         end;
         return;
      end if;

      if Event.Ex_Type = 2 then
         E_Type := KeyPress;
      elsif Event.Ex_Type = 4 then
         E_Type := ButtonPress;
      elsif Event.Ex_Type = 20 then
         E_Type := MapRequest;
      elsif Event.Ex_Type = 22 then
         E_Type := ConfigureNotify;
      elsif Event.Ex_Type = 23 then
         E_Type := ConfigureRequest;
      elsif Event.Ex_Type = 33 then
         E_Type := ClientMessage;
      else
         E_Type := Unknown;
      end if;

      case E_Type is
         when MapRequest =>
            declare
               MR_Event : constant XMapRequestEvent := To_MapRequest (Event);
            begin
               if WM_State.Client_Count < WM_State.Max_Clients then
                  if WM_State.Find_Client (MR_Event.Win) = 0 then
                     WM_State.Add_Client (MR_Event.Win);
                     WM_ICCCM.Probe_Delete_Protocol (MR_Event.Win);
                     Session_Persist.Apply_Restore_Hints (MR_Event.Win);
                     Grab_Client_Buttons (MR_Event.Win);
                  end if;
               end if;
               XMapWindow (Display, MR_Event.Win);
               Layout.Tile_Windows (
                  WM_State.Screen_Width, WM_State.Screen_Height);
               WM_State.Apply_Focus_X11;
            end;

         when ConfigureRequest =>
            declare
               CR      : constant XConfigureRequestEvent :=
                 To_ConfigureRequest (Event);
               Changes : aliased XWindowChanges;
            begin
               Changes.X := CR.X;
               Changes.Y := CR.Y;
               Changes.W := CR.W;
               Changes.H := CR.H;
               Changes.Border_Width := CR.Border_W;
               Changes.Sibling := CR.Above;
               Changes.Stack_Mode := CR.Detail;
               XConfigureWindow (
                  Display,
                  CR.Win,
                  unsigned (CR.Value_Mask),
                  Changes'Access);
            end;

         when ConfigureNotify =>
            declare
               CE : constant XConfigureEvent := To_Configure (Event);
            begin
               if CE.Win = Root then
                  if Integer (CE.W) > 0 and Integer (CE.H) > 0 then
                     WM_State.Screen_Width  := Integer (CE.W);
                     WM_State.Screen_Height := Integer (CE.H);
                     Layout.Tile_Windows (
                        WM_State.Screen_Width, WM_State.Screen_Height);
                  end if;
               end if;
            end;

         when ButtonPress =>
            declare
               B_Event : constant XKeyEvent := To_Key (Event);
               Root_Win, Child_Win : Window;
               Root_X, Root_Y, Win_X, Win_Y : int;
               Mask_Out : unsigned;

               Geo_Root : Window;
               Geo_X, Geo_Y : int;
               Geo_W, Geo_H, Geo_B, Geo_D : unsigned;

               Motion_Event : aliased XEvent;
               Last_Motion  : XEvent;
               Res          : int;
               Drained      : int;

               Target_Client_Idx : Client_Index;
               Target_Win        : Window;
               Drag_Active       : Boolean;
               Drag_Moved        : Boolean := False;
               --  Pointer must travel past this before a window leaves
               --  the tile: a bare Alt+click is focus only, not a float.
               Drag_Threshold    : constant int := 4;
               --  Bounded drain for motion compression (MISRA: bounded loop).
               Max_Drain         : constant int := 256;
               pragma Unreferenced (Res);
            begin
               Target_Client_Idx := WM_State.Find_Client (B_Event.Win);
               if Target_Client_Idx /= 0 then
                  WM_State.Focused_Client := Target_Client_Idx;
                  Layout.Tile_Windows (
                     WM_State.Screen_Width, WM_State.Screen_Height);
                  WM_State.Apply_Focus_X11;

                  if WM_State.Clients (Target_Client_Idx).Tab_ID = B_Event.Win then
                     null;
                  else
                     Target_Win := WM_State.Clients (Target_Client_Idx).ID;
                     Res := XQueryPointer (
                        Display, B_Event.Root, Root_Win, Child_Win,
                        Root_X, Root_Y, Win_X, Win_Y, Mask_Out);
                     Res := XGetGeometry (
                        Display, Target_Win, Geo_Root, Geo_X, Geo_Y,
                        Geo_W, Geo_H, Geo_B, Geo_D);

                     Drag_Active := True;
                     while Drag_Active loop
                        XNextEvent (Display, Motion_Event);

                        if Motion_Event.Ex_Type = 17 then
                           declare
                              D_Ev : constant XDestroyWindowEvent :=
                                To_Destroy (Motion_Event);
                           begin
                              if D_Ev.Win = Target_Win
                                or else WM_State.Find_Client (D_Ev.Win) =
                                        Target_Client_Idx
                              then
                                 WM_State.Remove_Client (D_Ev.Win);
                                 Drag_Active := False;
                              else
                                 WM_State.Remove_Client (D_Ev.Win);
                              end if;
                           end;
                        elsif Motion_Event.Ex_Type = 18 then
                           declare
                              U_Ev : constant XUnmapEvent :=
                                To_Unmap (Motion_Event);
                           begin
                              if U_Ev.Win = Target_Win then
                                 WM_State.Remove_Client (U_Ev.Win);
                                 Drag_Active := False;
                              end if;
                           end;
                        elsif Motion_Event.Ex_Type = 5 then
                           Drag_Active := False;
                        elsif Motion_Event.Ex_Type = 6 then
                           if WM_State.Find_Client (Target_Win) = 0 then
                              Drag_Active := False;
                           else
                              --  Motion compression: X queues a MotionNotify
                              --  per pixel-step and the app redraw takes
                              --  longer than that; draining keeps only the
                              --  newest position so the window tracks the
                              --  pointer instead of lagging behind it.
                              Last_Motion := Motion_Event;
                              for J in 1 .. Max_Drain loop
                                 Drained := XCheckTypedEvent (
                                    Display, 6, Motion_Event'Access);
                                 exit when Drained = 0;
                                 Last_Motion := Motion_Event;
                              end loop;
                              declare
                                 ME : constant XKeyEvent :=
                                   To_Key (Last_Motion);
                                 Delta_X : constant int := ME.X_Root - Root_X;
                                 Delta_Y : constant int := ME.Y_Root - Root_Y;
                                 New_W   : int;
                                 New_H   : int;
                              begin
                                 --  Float on first real movement only.
                                 if not Drag_Moved
                                   and then
                                     (WM_State.Clients
                                        (Target_Client_Idx).Is_Floating
                                      or else abs Delta_X > Drag_Threshold
                                      or else abs Delta_Y > Drag_Threshold)
                                 then
                                    Drag_Moved := True;
                                    if not WM_State.Clients
                                      (Target_Client_Idx).Is_Floating
                                    then
                                       WM_State.Clients
                                         (Target_Client_Idx).Is_Floating :=
                                           True;
                                       --  Reflow siblings around the freed
                                       --  slot, then keep the dragged
                                       --  window on top.
                                       Layout.Tile_Windows (
                                          WM_State.Screen_Width,
                                          WM_State.Screen_Height);
                                       WM_State.Apply_Focus_X11;
                                       XRaiseWindow (Display, Target_Win);
                                    end if;
                                 end if;

                                 if Drag_Moved then
                                    if B_Event.Code = 1 then
                                       XMoveResizeWindow (
                                          Display, Target_Win,
                                          Geo_X + Delta_X, Geo_Y + Delta_Y,
                                          Geo_W, Geo_H);
                                       XMoveResizeWindow (
                                          Display,
                                          WM_State.Clients
                                            (Target_Client_Idx).Tab_ID,
                                          Geo_X + Delta_X,
                                          (Geo_Y + Delta_Y) - 20,
                                          Geo_W, 20);
                                       WM_State.Clients
                                         (Target_Client_Idx).Float_X :=
                                           Integer (Geo_X + Delta_X);
                                       WM_State.Clients
                                         (Target_Client_Idx).Float_Y :=
                                           Integer (Geo_Y + Delta_Y);
                                       WM_State.Clients
                                         (Target_Client_Idx).Float_W := Geo_W;
                                       WM_State.Clients
                                         (Target_Client_Idx).Float_H := Geo_H;
                                    elsif B_Event.Code = 3 then
                                       New_W := int (Geo_W) + Delta_X;
                                       New_H := int (Geo_H) + Delta_Y;
                                       if New_W > 50 and New_H > 50 then
                                          XMoveResizeWindow (
                                             Display, Target_Win,
                                             Geo_X, Geo_Y,
                                             unsigned (New_W),
                                             unsigned (New_H));
                                          XMoveResizeWindow (
                                             Display,
                                             WM_State.Clients
                                               (Target_Client_Idx).Tab_ID,
                                             Geo_X, Geo_Y - 20,
                                             unsigned (New_W), 20);
                                          WM_State.Clients
                                            (Target_Client_Idx).Float_W :=
                                              unsigned (New_W);
                                          WM_State.Clients
                                            (Target_Client_Idx).Float_H :=
                                              unsigned (New_H);
                                          WM_State.Clients
                                            (Target_Client_Idx).Float_X :=
                                              Integer (Geo_X);
                                          WM_State.Clients
                                            (Target_Client_Idx).Float_Y :=
                                              Integer (Geo_Y);
                                       end if;
                                    end if;
                                 end if;
                              end;
                           end if;
                        end if;
                     end loop;

                     --  Only reflow if the pointer actually moved: a plain
                     --  Alt+click changes focus without tearing the layout.
                     if Drag_Moved then
                        Layout.Tile_Windows (
                           WM_State.Screen_Width, WM_State.Screen_Height);
                        WM_State.Apply_Focus_X11;
                     end if;
                  end if;
               end if;
            end;

         when KeyPress =>
            WM_Keys.Handle_Key (Event);

         when ClientMessage =>
            WM_ICCCM.Handle_Client_Message (Event);

         when others =>
            null;
      end case;
   end Handle_One_Event;

begin
   Display := XOpenDisplay (To_C (""));
   X11.Global_Display := Display;
   if Display = X11.Display_Ptr (System.Null_Address) then
      C_Exit (int (Session_Persist.Exit_Reconnect_Failed));
   end if;

   Old_Handler := X11.XSetErrorHandler (WM_State.Ignore_X_Error'Access);
   Old_IO := X11.XSetIOErrorHandler (Session_Persist.Handle_IO_Error'Access);

   Root := XDefaultRootWindow (Display);
   XSelectInput (
      Display, Root,
      SubstructureRedirectMask or SubstructureNotifyMask or StructureNotifyMask);

   WM_ICCCM.Init_Atoms;
   Session_Persist.Try_Load_Session;
   WM_Keys.Setup_Keys;
   WM_State.Init_Graphics;
   WM_State.Init_Monitors;

   while WM_State.Running loop
      begin
         XNextEvent (Display, Event);
         Handle_One_Event;
      exception
         when others =>
            begin
               Layout.Tile_Windows (
                  WM_State.Screen_Width, WM_State.Screen_Height);
               WM_State.Apply_Focus_X11;
            exception
               when others =>
                  null;
            end;
      end;
   end loop;

   Session_Persist.Save_Session;
   X11.XFlush (Display);
end Main;
