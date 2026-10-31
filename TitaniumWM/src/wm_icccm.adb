with Ada.Unchecked_Conversion;
with Interfaces.C; use Interfaces.C;
with System; use System;
with System.Address_To_Access_Conversions;
with WM_State; use WM_State;
with X11; use X11;

package body WM_ICCCM is

   Atom_WM_Protocols     : Atom := 0;
   Atom_WM_Delete_Window : Atom := 0;

   pragma Warnings (Off);
   function To_Client_Message is new Ada.Unchecked_Conversion
     (Source => XEvent, Target => XClientMessageEvent);
   function From_Client_Message is new Ada.Unchecked_Conversion
     (Source => XClientMessageEvent, Target => XEvent);
   pragma Warnings (On);

   procedure Init_Atoms is
   begin
      Atom_WM_Protocols := XInternAtom
        (Global_Display, To_C ("WM_PROTOCOLS"), 0);
      Atom_WM_Delete_Window := XInternAtom
        (Global_Display, To_C ("WM_DELETE_WINDOW"), 0);
   end Init_Atoms;

   function Window_Supports_Delete (Win : Window) return Boolean is
      Protocols_Addr : System.Address := System.Null_Address;
      Count          : aliased int := 0;
      Status         : int;
      Found          : Boolean := False;
   begin
      if Win = 0 or else Atom_WM_Delete_Window = 0 then
         return False;
      end if;

      Status := XGetWMProtocols (
         Global_Display,
         Win,
         Protocols_Addr'Address,
         Count'Access);

      if Status = 0 or else Count <= 0
        or else Protocols_Addr = System.Null_Address
      then
         return False;
      end if;

      declare
         type Atom_Array is array (0 .. Integer (Count) - 1) of Atom;
         package Arr_Conv is new
           System.Address_To_Access_Conversions (Atom_Array);
         Arr : constant Arr_Conv.Object_Pointer :=
           Arr_Conv.To_Pointer (Protocols_Addr);
      begin
         for I in Arr'Range loop
            if Arr (I) = Atom_WM_Delete_Window then
               Found := True;
               exit;
            end if;
         end loop;
      end;

      XFree (Protocols_Addr);
      return Found;
   exception
      when others =>
         if Protocols_Addr /= System.Null_Address then
            XFree (Protocols_Addr);
         end if;
         return False;
   end Window_Supports_Delete;

   procedure Probe_Delete_Protocol (Win : Window) is
      Idx : constant WM_State.Client_Index := WM_State.Find_Client (Win);
   begin
      if Idx = 0 then
         return;
      end if;
      WM_State.Clients (Idx).Supports_Delete := Window_Supports_Delete (Win);
   exception
      when others =>
         if Idx /= 0 then
            WM_State.Clients (Idx).Supports_Delete := False;
         end if;
   end Probe_Delete_Protocol;

   procedure Soft_Close (Win : Window) is
      Idx     : WM_State.Client_Index;
      Supports : Boolean;
      Ev       : aliased XEvent;
      CM       : XClientMessageEvent;
      Res      : int;
      pragma Unreferenced (Res);
   begin
      if Win = 0 then
         return;
      end if;

      Idx := WM_State.Find_Client (Win);
      if Idx /= 0 then
         Supports := WM_State.Clients (Idx).Supports_Delete;
      else
         Supports := Window_Supports_Delete (Win);
      end if;

      if Supports and then Atom_WM_Protocols /= 0
        and then Atom_WM_Delete_Window /= 0
      then
         -- ICCCM: ClientMessage WM_PROTOCOLS / WM_DELETE_WINDOW
         CM.Ex_Type      := 33; -- ClientMessage
         CM.Serial       := 0;
         CM.Send         := 1;
         CM.Display      := Global_Display;
         CM.Win          := Win;
         CM.Message_Type := Atom_WM_Protocols;
         CM.Format       := 32;
         CM.Data_L       := (0 => long (Atom_WM_Delete_Window),
                             1 => long (CurrentTime),
                             2 => 0, 3 => 0, 4 => 0);
         Ev := From_Client_Message (CM);
         Res := XSendEvent (
            Global_Display, Win, 0, long (NoEventMask), Ev'Access);
         XFlush (Global_Display);
         -- Do not Remove_Client yet; wait for DestroyNotify / UnmapNotify
      else
         XDestroyWindow (Global_Display, Win);
         if Idx /= 0 then
            WM_State.Remove_Client (Win);
         end if;
      end if;
   exception
      when others =>
         null;
   end Soft_Close;

   procedure Force_Kill (Win : Window) is
      Res : int;
      pragma Unreferenced (Res);
   begin
      if Win = 0 then
         return;
      end if;
      Res := XKillClient (Global_Display, Win);
      WM_State.Remove_Client (Win);
      XFlush (Global_Display);
   exception
      when others =>
         begin
            XDestroyWindow (Global_Display, Win);
            WM_State.Remove_Client (Win);
         exception
            when others =>
               null;
         end;
   end Force_Kill;

   procedure Handle_Client_Message (Event : XEvent) is
      CM : XClientMessageEvent;
      pragma Unreferenced (CM);
   begin
      -- Decode for diagnostics / future EWMH-light; never crash the WM
      CM := To_Client_Message (Event);
   exception
      when others =>
         null;
   end Handle_Client_Message;

end WM_ICCCM;
