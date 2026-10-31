with Ada.Streams.Stream_IO;
with Interfaces; use Interfaces;
with Interfaces.C; use Interfaces.C;
with WM_State; use WM_State;
with X11; use X11;

package body Session_Persist is

   Magic_Value   : constant Unsigned_32 := 16#54494D53#; -- "TIMS"
   Format_Version : constant Unsigned_32 := 1;

   type Session_Header is record
      Magic             : Unsigned_32 := Magic_Value;
      Version           : Unsigned_32 := Format_Version;
      Client_Count      : Unsigned_32 := 0;
      Current_Workspace : Unsigned_32 := 1;
      Current_Mode      : Unsigned_32 := 0; -- 0=Tiled, 1=Monocle
      Master_Factor     : Float := 0.55;
   end record;

   type Session_Client is record
      Win_Id       : Unsigned_64 := 0;
      Workspace    : Unsigned_32 := 1;
      Is_Floating  : Unsigned_32 := 0;
      Height_Ratio : Float := 1.0;
   end record;

   type Client_Store is array (1 .. WM_State.Max_Clients) of Session_Client;

   Pending       : Client_Store := (others => <>);
   Pending_Count : Natural := 0;
   Have_Pending  : Boolean := False;

   procedure C_Exit (Status : int)
     with Import, Convention => C, External_Name => "exit";

   procedure Save_Session is
      use Ada.Streams.Stream_IO;
      File : File_Type;
      S    : Stream_Access;
      H    : Session_Header;
      N    : Natural := 0;
   begin
      begin
         Create (File, Out_File, Session_File_Name);
      exception
         when others =>
            begin
               Open (File, Out_File, Session_File_Name);
            exception
               when others =>
                  return;
            end;
      end;

      begin
         S := Stream (File);

         for I in WM_State.Valid_Index loop
            if WM_State.Clients (I).Is_Active then
               N := N + 1;
            end if;
         end loop;
         if N > WM_State.Max_Clients then
            N := WM_State.Max_Clients;
         end if;

         H.Magic := Magic_Value;
         H.Version := Format_Version;
         H.Client_Count := Unsigned_32 (N);
         H.Current_Workspace := Unsigned_32 (WM_State.Current_Workspace);
         if WM_State.Current_Mode = WM_State.Mode_Monocle then
            H.Current_Mode := 1;
         else
            H.Current_Mode := 0;
         end if;
         H.Master_Factor := WM_State.Master_Factor;

         Session_Header'Write (S, H);

         declare
            Written : Natural := 0;
         begin
            for I in WM_State.Valid_Index loop
               exit when Written >= N;
               if WM_State.Clients (I).Is_Active then
                  declare
                     E : Session_Client;
                  begin
                     E.Win_Id := Unsigned_64 (WM_State.Clients (I).ID);
                     E.Workspace := Unsigned_32 (WM_State.Clients (I).Workspace);
                     if WM_State.Clients (I).Is_Floating then
                        E.Is_Floating := 1;
                     else
                        E.Is_Floating := 0;
                     end if;
                     E.Height_Ratio := WM_State.Clients (I).Height_Ratio;
                     Session_Client'Write (S, E);
                     Written := Written + 1;
                  end;
               end if;
            end loop;
         end;

         Close (File);
      exception
         when others =>
            begin
               if Is_Open (File) then
                  Close (File);
               end if;
            exception
               when others =>
                  null;
            end;
      end;
   end Save_Session;

   procedure Try_Load_Session is
      use Ada.Streams.Stream_IO;
      File : File_Type;
      S    : Stream_Access;
      H    : Session_Header;
      N    : Natural;
   begin
      Have_Pending := False;
      Pending_Count := 0;

      begin
         Open (File, In_File, Session_File_Name);
      exception
         when others =>
            return;
      end;

      begin
         S := Stream (File);
         Session_Header'Read (S, H);

         if H.Magic /= Magic_Value or else H.Version /= Format_Version then
            Close (File);
            return;
         end if;

         -- Global layout state (safe even if no windows rematch)
         if H.Current_Workspace >= 1
           and then H.Current_Workspace <= Unsigned_32 (WM_State.Workspace_Type'Last)
         then
            WM_State.Current_Workspace :=
              WM_State.Workspace_Type (H.Current_Workspace);
         end if;

         if H.Current_Mode = 1 then
            WM_State.Current_Mode := WM_State.Mode_Monocle;
         else
            WM_State.Current_Mode := WM_State.Mode_Tiled;
         end if;

         WM_State.Master_Factor := H.Master_Factor;
         WM_State.Clamp_Master_Factor;

         N := Natural (H.Client_Count);
         if N > WM_State.Max_Clients then
            N := WM_State.Max_Clients;
         end if;

         Pending_Count := 0;
         for I in 1 .. N loop
            declare
               E : Session_Client;
            begin
               Session_Client'Read (S, E);
               Pending_Count := Pending_Count + 1;
               Pending (Pending_Count) := E;
            end;
         end loop;
         Have_Pending := Pending_Count > 0;

         Close (File);
      exception
         when others =>
            begin
               if Is_Open (File) then
                  Close (File);
               end if;
            exception
               when others =>
                  null;
            end;
            Have_Pending := False;
            Pending_Count := 0;
      end;
   end Try_Load_Session;

   procedure Apply_Restore_Hints (Win : X11.Window) is
      Idx : WM_State.Client_Index;
   begin
      if not Have_Pending or else Win = 0 then
         return;
      end if;

      Idx := WM_State.Find_Client (Win);
      if Idx = 0 then
         return;
      end if;

      for I in 1 .. Pending_Count loop
         if Pending (I).Win_Id = Unsigned_64 (Win) then
            if Pending (I).Workspace >= 1
              and then Pending (I).Workspace <=
                Unsigned_32 (WM_State.Workspace_Type'Last)
            then
               WM_State.Clients (Idx).Workspace :=
                 WM_State.Workspace_Type (Pending (I).Workspace);
            end if;
            WM_State.Clients (Idx).Is_Floating := Pending (I).Is_Floating /= 0;
            WM_State.Clients (Idx).Height_Ratio := Pending (I).Height_Ratio;
            WM_State.Clamp_Height_Ratio (Idx);
            return;
         end if;
      end loop;
   end Apply_Restore_Hints;

   procedure Handle_IO_Error (Display : X11.Display_Ptr) is
      pragma Unreferenced (Display);
   begin
      WM_State.Running := False;
      begin
         Save_Session;
      exception
         when others =>
            null;
      end;
      -- Xlib forbids returning from an IO error handler
      C_Exit (int (Exit_Display_Lost));
   end Handle_IO_Error;

end Session_Persist;
