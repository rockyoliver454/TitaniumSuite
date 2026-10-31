with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Directories;
with Ada.Text_IO;

with Config;

package body Display_Mgr is

   package C  renames Interfaces.C;
   package CS renames Interfaces.C.Strings;
   use type C.int;
   use type C.unsigned;

   procedure C_Exit (Status : C.int);
   pragma Import (C, C_Exit, "_exit");

   procedure Discard (Rc : C.int) is
   begin
      null;
   end Discard;

   function Display_Name (Num : Display_Number) return String is
      Img : constant String := Natural'Image (Num);
   begin
      return ":" & Img (Img'First + 1 .. Img'Last);
   end Display_Name;

   function Socket_Path (Num : Display_Number) return String is
      Img : constant String := Natural'Image (Num);
   begin
      return "/tmp/.X11-unix/X" & Img (Img'First + 1 .. Img'Last);
   end Socket_Path;

   function Lock_Path (Num : Display_Number) return String is
      Img : constant String := Natural'Image (Num);
   begin
      return "/tmp/.X" & Img (Img'First + 1 .. Img'Last) & "-lock";
   end Lock_Path;

   function Path_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   exception
      when others =>
         return False;
   end Path_Exists;

   function Find_Free_Display (Num : out Display_Number) return Boolean is
   begin
      for Candidate in Config.First_Display .. Config.Last_Display loop
         if not Path_Exists (Socket_Path (Candidate))
           and then not Path_Exists (Lock_Path (Candidate))
         then
            Num := Candidate;
            return True;
         end if;
      end loop;
      Num := 0;
      return False;
   end Find_Free_Display;

   type Exec_Argv is array (0 .. 5) of CS.chars_ptr;
   pragma Convention (C, Exec_Argv);

   function Start_X
     (Num : Display_Number;
      Pid : out Posix_Thin.Pid_T) return Boolean
   is
      Child : Posix_Thin.Pid_T;
      Disp  : constant String := Display_Name (Num);
   begin
      Pid := 0;
      Child := Posix_Thin.Fork;
      if Child < 0 then
         return False;
      end if;

      if Child = 0 then
         declare
            Xorg    : constant CS.chars_ptr := CS.New_String ("Xorg");
            Xbin    : constant CS.chars_ptr := CS.New_String ("/usr/bin/X");
            Arg_D   : constant CS.chars_ptr := CS.New_String (Disp);
            Arg_Nl  : constant CS.chars_ptr := CS.New_String ("-nolisten");
            Arg_Tcp : constant CS.chars_ptr := CS.New_String ("tcp");
            Argv    : aliased Exec_Argv;
         begin
            Discard (C.int (Posix_Thin.Setsid));

            Argv :=
              (0 => Xorg, 1 => Arg_D, 2 => Arg_Nl, 3 => Arg_Tcp,
               4 => CS.Null_Ptr, 5 => CS.Null_Ptr);
            Discard (Posix_Thin.Execvp (Xorg, Argv'Address));

            Argv :=
              (0 => Xbin, 1 => Arg_D, 2 => CS.Null_Ptr,
               others => CS.Null_Ptr);
            Discard (Posix_Thin.Execv (Xbin, Argv'Address));

            Ada.Text_IO.Put_Line ("TitaniumLogin: failed to exec X server");
            C_Exit (1);
         end;
      end if;

      Pid := Child;
      return True;
   end Start_X;

   function Wait_Until_Ready (Num : Display_Number) return Boolean is
      Disp     : constant String := Display_Name (Num);
      Delay_Us : constant C.unsigned :=
        C.unsigned (Config.Display_Ready_Delay_Ms) * 1000;

      type Probe_Argv is array (0 .. 3) of CS.chars_ptr;
      pragma Convention (C, Probe_Argv);
   begin
      for I in 1 .. Config.Display_Ready_Attempts loop
         if Path_Exists (Socket_Path (Num)) then
            declare
               Child : Posix_Thin.Pid_T;
               Stat  : aliased C.int := 0;
            begin
               Child := Posix_Thin.Fork;
               if Child = 0 then
                  declare
                     Bin   : constant CS.chars_ptr :=
                       CS.New_String ("xdpyinfo");
                     Dflag : constant CS.chars_ptr :=
                       CS.New_String ("-display");
                     Dval  : constant CS.chars_ptr := CS.New_String (Disp);
                     Argv  : aliased Probe_Argv :=
                       (0 => Bin, 1 => Dflag, 2 => Dval, 3 => CS.Null_Ptr);
                  begin
                     Discard (Posix_Thin.Execvp (Bin, Argv'Address));
                     C_Exit (1);
                  end;
               elsif Child > 0 then
                  Discard (C.int (Posix_Thin.Waitpid (Child, Stat'Access, 0)));
                  if Posix_Thin.Wifexited (Stat)
                    and then Posix_Thin.Wexitstatus (Stat) = 0
                  then
                     return True;
                  end if;
               else
                  return True;
               end if;
            end;
         end if;
         Posix_Thin.Usleep (Delay_Us);
      end loop;
      return Path_Exists (Socket_Path (Num));
   end Wait_Until_Ready;

   procedure Stop_X (Pid : Posix_Thin.Pid_T) is
      Stat : aliased C.int := 0;
      W    : Posix_Thin.Pid_T;
   begin
      if Pid <= 0 then
         return;
      end if;
      Discard (Posix_Thin.Kill (Pid, Posix_Thin.SIGTERM));
      Posix_Thin.Usleep (500_000);
      W := Posix_Thin.Waitpid (Pid, Stat'Access, 1);
      if W = 0 then
         Discard (Posix_Thin.Kill (Pid, Posix_Thin.SIGKILL));
         Discard (C.int (Posix_Thin.Waitpid (Pid, Stat'Access, 0)));
      end if;
   end Stop_X;

end Display_Mgr;
