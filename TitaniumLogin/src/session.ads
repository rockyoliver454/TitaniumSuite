--  Drop privileges and exec the Titanium session script.

with Posix_Thin;

package Session is
   pragma SPARK_Mode (Off);

   function Run_As_User
     (Username     : String;
      Display_Name : String) return Posix_Thin.Pid_T;
   --  Fork a child that setuid/setgid to Username, sets env, execs
   --  Config.Session_Script. Returns child pid, or -1 on failure.

   function Wait_For_Exit (Pid : Posix_Thin.Pid_T) return Integer;
   --  Blocking wait; returns process exit code (or 128+signal).

end Session;
