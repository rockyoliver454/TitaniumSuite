package body Posix_Thin is

   use type C.int;
   use type C.unsigned;
   use type C.long;

   function As_Bits (Status : C.int) return C.unsigned is
   begin
      --  Reinterpret wait(2) status bits (non-negative in practice).
      if Status < 0 then
         return C.unsigned (-Status);
      end if;
      return C.unsigned (Status);
   end As_Bits;

   function Wifexited (Status : C.int) return Boolean is
   begin
      return (As_Bits (Status) and 16#7F#) = 0;
   end Wifexited;

   function Wexitstatus (Status : C.int) return C.int is
   begin
      return C.int ((As_Bits (Status) / 256) mod 256);
   end Wexitstatus;

   function Load_Lflag (Blob : Termios_Blob) return C.unsigned is
      B0 : constant C.unsigned := C.unsigned (Blob (Lflag_Offset));
      B1 : constant C.unsigned := C.unsigned (Blob (Lflag_Offset + 1));
      B2 : constant C.unsigned := C.unsigned (Blob (Lflag_Offset + 2));
      B3 : constant C.unsigned := C.unsigned (Blob (Lflag_Offset + 3));
   begin
      return B0 + (B1 * 256) + (B2 * 65536) + (B3 * 16777216);
   end Load_Lflag;

   procedure Store_Lflag (Blob : in out Termios_Blob; Value : C.unsigned) is
      V : C.unsigned := Value;
   begin
      Blob (Lflag_Offset) := C.unsigned_char (V mod 256);
      V := V / 256;
      Blob (Lflag_Offset + 1) := C.unsigned_char (V mod 256);
      V := V / 256;
      Blob (Lflag_Offset + 2) := C.unsigned_char (V mod 256);
      V := V / 256;
      Blob (Lflag_Offset + 3) := C.unsigned_char (V mod 256);
   end Store_Lflag;

   procedure Echo_Off (Fd : C.int; Saved : out Termios_Blob; Ok : out Boolean) is
      Modified : Termios_Blob;
      Rc       : C.int;
      Lflag    : C.unsigned;
   begin
      Saved := (others => 0);
      Rc := Tcgetattr (Fd, Saved'Address);
      if Rc /= 0 then
         Ok := False;
         return;
      end if;
      Modified := Saved;
      Lflag := Load_Lflag (Modified);
      Lflag := Lflag and not ECHO_Flag;
      Store_Lflag (Modified, Lflag);
      Rc := Tcsetattr (Fd, TCSANOW, Modified'Address);
      Ok := Rc = 0;
   end Echo_Off;

   procedure Echo_Restore (Fd : C.int; Saved : Termios_Blob) is
      Ignore : C.int;
      Local  : Termios_Blob := Saved;
   begin
      Ignore := Tcsetattr (Fd, TCSANOW, Local'Address);
      pragma Unreferenced (Ignore);
   end Echo_Restore;

   function C_Read
     (Fd    : C.int;
      Buf   : System.Address;
      Count : C.size_t) return C.long;
   pragma Import (C, C_Read, "read");

   procedure Read_Byte (Fd : C.int; Ch : out Character; Got : out Boolean) is
      Buf : Character := ASCII.NUL;
      N   : C.long;
   begin
      N := C_Read (Fd, Buf'Address, 1);
      if N <= 0 then
         Got := False;
         Ch  := ASCII.NUL;
      else
         Got := True;
         Ch  := Buf;
      end if;
   end Read_Byte;

   procedure Read_Line (Fd : C.int; Line : out String; Last : out Natural) is
      Ch  : Character;
      Got : Boolean;
      Idx : Natural := 0;
   begin
      Line := (others => ASCII.NUL);
      loop
         exit when Idx >= Line'Length;
         Read_Byte (Fd, Ch, Got);
         exit when not Got;
         exit when Ch = ASCII.LF or else Ch = ASCII.CR;
         if Ch = ASCII.BS or else Ch = Character'Val (127) then
            if Idx > 0 then
               Line (Line'First + Idx - 1) := ASCII.NUL;
               Idx := Idx - 1;
            end if;
         elsif Character'Pos (Ch) >= 32 then
            Idx := Idx + 1;
            Line (Line'First + Idx - 1) := Ch;
         end if;
      end loop;
      Last := Idx;
   end Read_Line;

end Posix_Thin;
