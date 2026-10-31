--  Hand-written thin bindings to libpam.
--  Declares C types locally so pam_appl.h (-dev) is not required to compile.

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package Pam_Thin is
   pragma SPARK_Mode (Off);

   package C  renames Interfaces.C;
   package CS renames Interfaces.C.Strings;

   subtype Pam_Handle is System.Address;
   Null_Handle : constant Pam_Handle := System.Null_Address;

   --  Return codes (subset)
   PAM_SUCCESS : constant C.int := 0;

   --  Message styles
   PAM_PROMPT_ECHO_OFF : constant C.int := 1;
   PAM_PROMPT_ECHO_ON  : constant C.int := 2;
   PAM_ERROR_MSG       : constant C.int := 3;
   PAM_TEXT_INFO       : constant C.int := 4;

   --  pam_setcred flags
   PAM_ESTABLISH_CRED : constant C.int := 16#0002#;
   PAM_DELETE_CRED    : constant C.int := 16#0004#;

   type Pam_Message is record
      Msg_Style : C.int;
      Msg       : CS.chars_ptr;
   end record;
   pragma Convention (C, Pam_Message);

   type Pam_Message_Access is access all Pam_Message;
   pragma Convention (C, Pam_Message_Access);

   type Pam_Message_Ptr_Array is array (C.size_t range <>) of Pam_Message_Access;
   pragma Convention (C, Pam_Message_Ptr_Array);

   type Pam_Response is record
      Resp         : CS.chars_ptr;
      Resp_Retcode : C.int;
   end record;
   pragma Convention (C, Pam_Response);

   type Pam_Response_Access is access all Pam_Response;
   pragma Convention (C, Pam_Response_Access);

   --  Conversation callback: num_msg, msg**, resp**, appdata
   type Conv_Callback is access function
     (Num_Msg     : C.int;
      Msg         : System.Address;
      Resp        : System.Address;
      Appdata_Ptr : System.Address) return C.int;
   pragma Convention (C, Conv_Callback);

   type Pam_Conv is record
      Conv        : Conv_Callback;
      Appdata_Ptr : System.Address;
   end record;
   pragma Convention (C, Pam_Conv);

   function Pam_Start
     (Service_Name : CS.chars_ptr;
      User         : CS.chars_ptr;
      Pam_Conversation : access constant Pam_Conv;
      Pamh         : access Pam_Handle) return C.int;
   pragma Import (C, Pam_Start, "pam_start");

   function Pam_Authenticate
     (Pamh  : Pam_Handle;
      Flags : C.int) return C.int;
   pragma Import (C, Pam_Authenticate, "pam_authenticate");

   function Pam_Acct_Mgmt
     (Pamh  : Pam_Handle;
      Flags : C.int) return C.int;
   pragma Import (C, Pam_Acct_Mgmt, "pam_acct_mgmt");

   function Pam_Setcred
     (Pamh  : Pam_Handle;
      Flags : C.int) return C.int;
   pragma Import (C, Pam_Setcred, "pam_setcred");

   function Pam_End
     (Pamh   : Pam_Handle;
      Status : C.int) return C.int;
   pragma Import (C, Pam_End, "pam_end");

   function Pam_Strerror
     (Pamh   : Pam_Handle;
      Errnum : C.int) return CS.chars_ptr;
   pragma Import (C, Pam_Strerror, "pam_strerror");

end Pam_Thin;
