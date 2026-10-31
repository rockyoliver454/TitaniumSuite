--  TitaniumLogin — console display manager (runs before X).
--  Authenticate → start X → session (titaniumbg + titaniumwm) → loop.

with Ada.Text_IO;
with Interfaces.C;

with Config;
with Auth;
with Display_Mgr;
with Session;
with Posix_Thin;

procedure Main is
   pragma SPARK_Mode (Off);

   package C renames Interfaces.C;
   use Ada.Text_IO;
   use type Posix_Thin.Pid_T;

   Stdin_Fd : constant C.int := 0;

   procedure Clear_Screen is
   begin
      Put (ASCII.ESC & "[2J" & ASCII.ESC & "[H");
      Flush;
   end Clear_Screen;

   procedure Read_Line
     (Prompt : String; Line : out String; Last : out Natural)
   is
   begin
      Put (Prompt);
      Flush;
      Posix_Thin.Read_Line (Stdin_Fd, Line, Last);
   end Read_Line;

   procedure Read_Password (Password : out String; Last : out Natural) is
      Saved : Posix_Thin.Termios_Blob;
      Ok    : Boolean := False;
   begin
      --  Ada.Text_IO.Get skips line terminators, so Enter never ended the
      --  password. Read the tty directly; canonical mode still delivers a
      --  line on Return, with echo off.
      Password := (others => ASCII.NUL);
      Last := 0;
      Put ("Password: ");
      Flush;
      Posix_Thin.Echo_Off (Stdin_Fd, Saved, Ok);
      Posix_Thin.Read_Line (Stdin_Fd, Password, Last);
      if Ok then
         Posix_Thin.Echo_Restore (Stdin_Fd, Saved);
      end if;
      New_Line;
   exception
      when others =>
         if Ok then
            Posix_Thin.Echo_Restore (Stdin_Fd, Saved);
         end if;
         New_Line;
   end Read_Password;

   procedure Pause_Brief is
   begin
      Posix_Thin.Usleep (1_200_000);
   end Pause_Brief;

   Username  : String (1 .. 128);
   User_Last : Natural;
   Password  : String (1 .. 256);
   Pass_Last : Natural;

   Disp_Num  : Display_Mgr.Display_Number;
   X_Pid     : Posix_Thin.Pid_T;
   Sess_Pid  : Posix_Thin.Pid_T;
   Exit_Code : Integer;
   Try_Session : Boolean;
begin
   loop
      Clear_Screen;
      Put_Line (Config.Banner);
      Put_Line ("--------------------------------");
      New_Line;

      Try_Session := False;
      Read_Line ("Username: ", Username, User_Last);

      if User_Last > 0 then
         Read_Password (Password, Pass_Last);

         declare
            User : constant String := Username (1 .. User_Last);
            Pass : constant String := Password (1 .. Pass_Last);
         begin
            Password := (others => ASCII.NUL);

            if not Auth.Authenticate (User, Pass) then
               Put_Line ("Authentication failed.");
               Pause_Brief;
            else
               Put_Line ("Authentication ok.");
               Try_Session := True;

               if not Display_Mgr.Find_Free_Display (Disp_Num) then
                  Put_Line ("No free display (:1-:10).");
                  Try_Session := False;
                  Pause_Brief;
               end if;
            end if;

            if Try_Session then
               Put_Line
                 ("Starting X on "
                  & Display_Mgr.Display_Name (Disp_Num)
                  & " ...");

               if not Display_Mgr.Start_X (Disp_Num, X_Pid) then
                  Put_Line ("Failed to start X server.");
                  Pause_Brief;
               elsif not Display_Mgr.Wait_Until_Ready (Disp_Num) then
                  Put_Line ("X server did not become ready.");
                  Display_Mgr.Stop_X (X_Pid);
                  Pause_Brief;
               else
                  Sess_Pid := Session.Run_As_User
                    (User, Display_Mgr.Display_Name (Disp_Num));

                  if Sess_Pid < 0 then
                     Put_Line ("Failed to start session.");
                     Display_Mgr.Stop_X (X_Pid);
                     Pause_Brief;
                  else
                     Exit_Code := Session.Wait_For_Exit (Sess_Pid);

                     --  Exit 75/76 (display lost / session fail) and any
                     --  other code: always return to this login loop.
                     if Exit_Code = Config.Exit_Display_Lost
                       or else Exit_Code = Config.Exit_Session_Fail
                     then
                        Put_Line
                          ("Session ended (display/session failure,"
                           & Integer'Image (Exit_Code) & ").");
                     else
                        Put_Line
                          ("Session ended (exit"
                           & Integer'Image (Exit_Code) & ").");
                     end if;

                     Display_Mgr.Stop_X (X_Pid);
                     Pause_Brief;
                  end if;
               end if;
            end if;
         end;
      end if;

      Password := (others => ASCII.NUL);
   end loop;
end Main;
