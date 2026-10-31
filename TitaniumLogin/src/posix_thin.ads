--  Minimal POSIX / libc imports used by TitaniumLogin.
--  Intentionally thin for Linux + FreeBSD portability.

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package Posix_Thin is
   pragma SPARK_Mode (Off);

   package C  renames Interfaces.C;
   package CS renames Interfaces.C.Strings;

   subtype Pid_T  is C.int;
   subtype Uid_T  is C.unsigned;
   subtype Gid_T  is C.unsigned;

   --  signals
   SIGTERM : constant C.int := 15;
   SIGKILL : constant C.int := 9;

   --  Opaque termios buffer: c_iflag..c_lflag share the same leading layout
   --  on Linux and FreeBSD (lflag at byte offset 12). Remainder is opaque.
   Termios_Bytes : constant := 256;
   type Termios_Blob is array (0 .. Termios_Bytes - 1) of C.unsigned_char;
   pragma Convention (C, Termios_Blob);

   Lflag_Offset : constant := 12;
   ECHO_Flag    : constant C.unsigned := 8;  --  0000010
   TCSANOW      : constant C.int := 0;

   type Passwd is record
      Pw_Name   : CS.chars_ptr;
      Pw_Passwd : CS.chars_ptr;
      Pw_Uid    : Uid_T;
      Pw_Gid    : Gid_T;
      Pw_Gecos  : CS.chars_ptr;
      Pw_Dir    : CS.chars_ptr;
      Pw_Shell  : CS.chars_ptr;
   end record;
   pragma Convention (C, Passwd);

   type Passwd_Access is access all Passwd;
   pragma Convention (C, Passwd_Access);

   function Getpwnam (Name : CS.chars_ptr) return Passwd_Access;
   pragma Import (C, Getpwnam, "getpwnam");

   function Fork return Pid_T;
   pragma Import (C, Fork, "fork");

   function Setsid return Pid_T;
   pragma Import (C, Setsid, "setsid");

   function Setgid (Gid : Gid_T) return C.int;
   pragma Import (C, Setgid, "setgid");

   function Setuid (Uid : Uid_T) return C.int;
   pragma Import (C, Setuid, "setuid");

   function Initgroups (User : CS.chars_ptr; Group : Gid_T) return C.int;
   pragma Import (C, Initgroups, "initgroups");

   function Chdir (Path : CS.chars_ptr) return C.int;
   pragma Import (C, Chdir, "chdir");

   function Clearenv return C.int;
   pragma Import (C, Clearenv, "clearenv");

   function Setenv
     (Name      : CS.chars_ptr;
      Value     : CS.chars_ptr;
      Overwrite : C.int) return C.int;
   pragma Import (C, Setenv, "setenv");

   function Execv
     (Path : CS.chars_ptr;
      Argv : System.Address) return C.int;
   pragma Import (C, Execv, "execv");

   function Execvp
     (File : CS.chars_ptr;
      Argv : System.Address) return C.int;
   pragma Import (C, Execvp, "execvp");

   function Waitpid
     (Pid     : Pid_T;
      Status  : access C.int;
      Options : C.int) return Pid_T;
   pragma Import (C, Waitpid, "waitpid");

   function Kill (Pid : Pid_T; Sig : C.int) return C.int;
   pragma Import (C, Kill, "kill");

   function Access_Check (Path : CS.chars_ptr; Mode : C.int) return C.int;
   pragma Import (C, Access_Check, "access");

   F_OK : constant C.int := 0;
   X_OK : constant C.int := 1;

   function Tcgetattr (Fd : C.int; Termios_P : System.Address) return C.int;
   pragma Import (C, Tcgetattr, "tcgetattr");

   function Tcsetattr
     (Fd               : C.int;
      Optional_Actions : C.int;
      Termios_P        : System.Address) return C.int;
   pragma Import (C, Tcsetattr, "tcsetattr");

   function Malloc (Size : C.size_t) return System.Address;
   pragma Import (C, Malloc, "malloc");

   procedure C_Free (Ptr : System.Address);
   pragma Import (C, C_Free, "free");

   function Strdup (S : CS.chars_ptr) return CS.chars_ptr;
   pragma Import (C, Strdup, "strdup");

   procedure Usleep (Usec : C.unsigned);
   pragma Import (C, Usleep, "usleep");

   function Wifexited (Status : C.int) return Boolean;
   function Wexitstatus (Status : C.int) return C.int;

   procedure Echo_Off (Fd : C.int; Saved : out Termios_Blob; Ok : out Boolean);
   procedure Echo_Restore (Fd : C.int; Saved : Termios_Blob);

   --  Canonical tty/line read into Line. Stops on LF/CR, EOF, or Line'Length.
   procedure Read_Line (Fd : C.int; Line : out String; Last : out Natural);

end Posix_Thin;
