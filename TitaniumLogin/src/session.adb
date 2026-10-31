with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Text_IO;

with Config;

package body Session is

   package C  renames Interfaces.C;
   package CS renames Interfaces.C.Strings;
   use type C.int;
   use type C.unsigned;
   use type Posix_Thin.Passwd_Access;

   procedure C_Exit (Status : C.int);
   pragma Import (C, C_Exit, "_exit");

   procedure Discard (Rc : C.int) is
   begin
      null;
   end Discard;

   procedure Set_Env (Name, Value : String) is
      N : CS.chars_ptr := CS.New_String (Name);
      V : CS.chars_ptr := CS.New_String (Value);
   begin
      Discard (Posix_Thin.Setenv (N, V, 1));
      CS.Free (N);
      CS.Free (V);
   end Set_Env;

   function Run_As_User
     (Username     : String;
      Display_Name : String) return Posix_Thin.Pid_T
   is
      Child : Posix_Thin.Pid_T;
   begin
      Child := Posix_Thin.Fork;
      if Child < 0 then
         return -1;
      end if;

      if Child > 0 then
         return Child;
      end if;

      declare
         Name_C    : constant CS.chars_ptr := CS.New_String (Username);
         Pw        : Posix_Thin.Passwd_Access;
         Home      : String (1 .. 512);
         Home_Len  : Natural := 0;
         Shell_S   : String (1 .. 512);
         Shell_Len : Natural := 0;
      begin
         Pw := Posix_Thin.Getpwnam (Name_C);
         if Pw = null then
            Ada.Text_IO.Put_Line
              ("TitaniumLogin: unknown user after auth");
            C_Exit (1);
         end if;

         declare
            H : constant String := CS.Value (Pw.Pw_Dir);
            S : constant String := CS.Value (Pw.Pw_Shell);
         begin
            if H'Length > Home'Length or else S'Length > Shell_S'Length then
               Ada.Text_IO.Put_Line
                 ("TitaniumLogin: home/shell path too long");
               C_Exit (1);
            end if;
            Home_Len := H'Length;
            Home (1 .. Home_Len) := H;
            Shell_Len := S'Length;
            Shell_S (1 .. Shell_Len) := S;
         end;

         Discard (Posix_Thin.Initgroups (Name_C, Pw.Pw_Gid));

         if Posix_Thin.Setgid (Pw.Pw_Gid) /= 0 then
            Ada.Text_IO.Put_Line ("TitaniumLogin: setgid failed");
            C_Exit (1);
         end if;

         if Posix_Thin.Setuid (Pw.Pw_Uid) /= 0 then
            Ada.Text_IO.Put_Line ("TitaniumLogin: setuid failed");
            C_Exit (1);
         end if;

         Discard (Posix_Thin.Chdir (Pw.Pw_Dir));
         Discard (Posix_Thin.Clearenv);

         Set_Env ("USER", Username);
         Set_Env ("LOGNAME", Username);
         Set_Env ("HOME", Home (1 .. Home_Len));
         Set_Env ("SHELL", Shell_S (1 .. Shell_Len));
         Set_Env ("DISPLAY", Display_Name);
         Set_Env ("PATH",
                  "/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin");

         declare
            type Argv3 is array (0 .. 2) of CS.chars_ptr;
            pragma Convention (C, Argv3);
            Sh  : constant CS.chars_ptr := CS.New_String ("/bin/sh");
            Scr : constant CS.chars_ptr :=
              CS.New_String (Config.Session_Script);
            A   : aliased Argv3 := (0 => Sh, 1 => Scr, 2 => CS.Null_Ptr);
         begin
            Discard (Posix_Thin.Execv (Sh, A'Address));
         end;

         declare
            type Argv4 is array (0 .. 3) of CS.chars_ptr;
            pragma Convention (C, Argv4);
            Sh   : constant CS.chars_ptr := CS.New_String ("/bin/sh");
            Dash : constant CS.chars_ptr := CS.New_String ("-c");
            Cmd  : constant CS.chars_ptr :=
              CS.New_String ("titaniumbg & exec titaniumwm");
            A    : aliased Argv4 :=
              (0 => Sh, 1 => Dash, 2 => Cmd, 3 => CS.Null_Ptr);
         begin
            Discard (Posix_Thin.Execv (Sh, A'Address));
         end;

         Ada.Text_IO.Put_Line ("TitaniumLogin: session exec failed");
         C_Exit (1);
      end;

      return -1;
   end Run_As_User;

   function Wait_For_Exit (Pid : Posix_Thin.Pid_T) return Integer is
      Stat : aliased C.int := 0;
      W    : Posix_Thin.Pid_T;
   begin
      if Pid <= 0 then
         return 1;
      end if;
      W := Posix_Thin.Waitpid (Pid, Stat'Access, 0);
      if W < 0 then
         return 1;
      end if;
      if Posix_Thin.Wifexited (Stat) then
         return Integer (Posix_Thin.Wexitstatus (Stat));
      end if;
      declare
         Bits : C.unsigned;
      begin
         if Stat < 0 then
            Bits := 0;
         else
            Bits := C.unsigned (Stat);
         end if;
         return 128 + Integer (Bits and 16#7F#);
      end;
   end Wait_For_Exit;

end Session;
