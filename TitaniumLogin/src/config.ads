--  Compile-time configuration for TitaniumLogin.
--  Rebuild to change any of these; no runtime config files.

package Config is
   pragma SPARK_Mode (Off);

   --  PAM service name. Use "login" if no titaniumlogin PAM stack is installed.
   Pam_Service : constant String := "titaniumlogin";

   --  Session helper installed by install-all (shipped as TitaniumLogin/session.sh).
   Session_Script : constant String := "/usr/lib/titanium/session.sh";

   --  Display search range (exclusive of 0; typically reserved for :0).
   First_Display : constant := 1;
   Last_Display  : constant := 10;

   --  How long to wait for the X server to become ready.
   Display_Ready_Attempts : constant := 50;
   Display_Ready_Delay_Ms : constant := 200;

   --  TitaniumWM exit codes that still return to the login loop (documented contract).
   Exit_Display_Lost : constant := 75;
   Exit_Session_Fail : constant := 76;

   Banner : constant String := "TitaniumLogin";

end Config;
