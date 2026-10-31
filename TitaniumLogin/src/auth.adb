with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;

with Pam_Thin;
with Posix_Thin;
with Config;

package body Auth is

   package C  renames Interfaces.C;
   package CS renames Interfaces.C.Strings;
   use type C.int;
   use type C.size_t;
   use type CS.chars_ptr;
   use type System.Address;

   type Auth_Data is record
      Password : CS.chars_ptr;
   end record;
   pragma Convention (C, Auth_Data);

   package Auth_Data_Conv is new
     System.Address_To_Access_Conversions (Auth_Data);

   package Address_Conv is new
     System.Address_To_Access_Conversions (System.Address);

   function Conversation
     (Num_Msg     : C.int;
      Msg         : System.Address;
      Resp        : System.Address;
      Appdata_Ptr : System.Address) return C.int;
   pragma Convention (C, Conversation);

   function Dup_C_String (S : String) return CS.chars_ptr is
      Tmp : CS.chars_ptr := CS.New_String (S);
      Dup : CS.chars_ptr;
   begin
      Dup := Posix_Thin.Strdup (Tmp);
      CS.Free (Tmp);
      return Dup;
   end Dup_C_String;

   function Conversation
     (Num_Msg     : C.int;
      Msg         : System.Address;
      Resp        : System.Address;
      Appdata_Ptr : System.Address) return C.int
   is
      use type Auth_Data_Conv.Object_Pointer;

      Data : constant Auth_Data_Conv.Object_Pointer :=
        Auth_Data_Conv.To_Pointer (Appdata_Ptr);

      type Msg_Access is access all Pam_Thin.Pam_Message;
      pragma Convention (C, Msg_Access);

      type Msg_Access_Array is array (0 .. Integer (Num_Msg) - 1) of Msg_Access;
      pragma Convention (C, Msg_Access_Array);

      package Msg_Arr_Conv is new
        System.Address_To_Access_Conversions (Msg_Access_Array);

      type Resp_Array is array (0 .. Integer (Num_Msg) - 1) of
        aliased Pam_Thin.Pam_Response;
      pragma Convention (C, Resp_Array);

      package Resp_Arr_Conv is new
        System.Address_To_Access_Conversions (Resp_Array);

      Resp_Block : System.Address;
      Msgs       : Msg_Arr_Conv.Object_Pointer;
      Arr        : Resp_Arr_Conv.Object_Pointer;
      Out_Slot   : Address_Conv.Object_Pointer;
      Bytes      : C.size_t;
   begin
      if Num_Msg <= 0 or else Data = null then
         return 1;
      end if;

      Bytes := C.size_t (Num_Msg) *
        C.size_t (Pam_Thin.Pam_Response'Size / System.Storage_Unit);
      Resp_Block := Posix_Thin.Malloc (Bytes);
      if Resp_Block = System.Null_Address then
         return 1;
      end if;

      --  Msg points at an array of pointers to pam_message
      Msgs := Msg_Arr_Conv.To_Pointer (Msg);
      Arr  := Resp_Arr_Conv.To_Pointer (Resp_Block);

      for I in Arr'Range loop
         Arr (I).Resp := CS.Null_Ptr;
         Arr (I).Resp_Retcode := 0;
         case Msgs (I).Msg_Style is
            when Pam_Thin.PAM_PROMPT_ECHO_OFF =>
               Arr (I).Resp := Posix_Thin.Strdup (Data.Password);
            when Pam_Thin.PAM_PROMPT_ECHO_ON =>
               Arr (I).Resp := Dup_C_String ("");
            when others =>
               null;
         end case;
      end loop;

      Out_Slot := Address_Conv.To_Pointer (Resp);
      Out_Slot.all := Resp_Block;
      return Pam_Thin.PAM_SUCCESS;
   exception
      when others =>
         return 1;
   end Conversation;

   function Authenticate
     (Username : String;
      Password : String) return Boolean
   is
      User_C : CS.chars_ptr := CS.New_String (Username);
      Pass_C : CS.chars_ptr := CS.New_String (Password);
      Svc_C  : CS.chars_ptr := CS.New_String (Config.Pam_Service);

      Data : aliased Auth_Data := (Password => Pass_C);
      Conv : aliased constant Pam_Thin.Pam_Conv :=
        (Conv        => Conversation'Access,
         Appdata_Ptr => Data'Address);

      Pamh   : aliased Pam_Thin.Pam_Handle := Pam_Thin.Null_Handle;
      Status : C.int := 1;
      Ok     : Boolean := False;
      Ignore : C.int;
   begin
      Status := Pam_Thin.Pam_Start
        (Service_Name     => Svc_C,
         User             => User_C,
         Pam_Conversation => Conv'Access,
         Pamh             => Pamh'Access);

      if Status = Pam_Thin.PAM_SUCCESS then
         Status := Pam_Thin.Pam_Authenticate (Pamh, 0);
      end if;

      if Status = Pam_Thin.PAM_SUCCESS then
         Status := Pam_Thin.Pam_Acct_Mgmt (Pamh, 0);
      end if;

      if Status = Pam_Thin.PAM_SUCCESS then
         Status := Pam_Thin.Pam_Setcred
           (Pamh, Pam_Thin.PAM_ESTABLISH_CRED);
      end if;

      Ok := Status = Pam_Thin.PAM_SUCCESS;

      if Pamh /= Pam_Thin.Null_Handle then
         if Ok then
            Ignore := Pam_Thin.Pam_Setcred
              (Pamh, Pam_Thin.PAM_DELETE_CRED);
         end if;
         Ignore := Pam_Thin.Pam_End (Pamh, Status);
         pragma Unreferenced (Ignore);
      end if;

      CS.Free (User_C);
      CS.Free (Pass_C);
      CS.Free (Svc_C);
      return Ok;
   exception
      when others =>
         if User_C /= CS.Null_Ptr then
            CS.Free (User_C);
         end if;
         if Pass_C /= CS.Null_Ptr then
            CS.Free (Pass_C);
         end if;
         if Svc_C /= CS.Null_Ptr then
            CS.Free (Svc_C);
         end if;
         return False;
   end Authenticate;

end Auth;
