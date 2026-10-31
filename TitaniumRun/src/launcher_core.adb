pragma SPARK_Mode (On);

package body Launcher_Core is

   procedure Init (Buffer : out Input_Buffer) is
   begin
      Buffer.Length := 0;
      Buffer.Content := (others => ' '); 
      
      pragma Assert (Buffer.Length = 0);
   end Init;

   procedure Insert_Char (Buffer : in out Input_Buffer; C : Character) is
   begin
      pragma Assert (Buffer.Length < Max_Input_Len);
      
      Buffer.Length := Buffer.Length + 1;
      --  Cast Input_Index to Integer to index standard String
      Buffer.Content(Integer(Buffer.Length)) := C;
      
      pragma Assert (Buffer.Content(Integer(Buffer.Length)) = C);
   end Insert_Char;

   procedure Backspace (Buffer : in out Input_Buffer) is
   begin
      pragma Assert (Buffer.Length > 0);
      Buffer.Length := Buffer.Length - 1;
   end Backspace;

   function Is_Full (Buffer : Input_Buffer) return Boolean is
   begin
      return Buffer.Length = Max_Input_Len;
   end Is_Full;

   function Is_Empty (Buffer : Input_Buffer) return Boolean is
   begin
      return Buffer.Length = 0;
   end Is_Empty;

end Launcher_Core;
