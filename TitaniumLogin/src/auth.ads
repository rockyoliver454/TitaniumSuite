--  PAM authentication wrapper with conversation callback.

package Auth is
   pragma SPARK_Mode (Off);

   function Authenticate
     (Username : String;
      Password : String) return Boolean;
   --  pam_start / pam_authenticate / pam_acct_mgmt / pam_setcred / pam_end.
   --  Returns True only when the full sequence succeeds.

end Auth;
