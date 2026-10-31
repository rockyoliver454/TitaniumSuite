pragma SPARK_Mode (On);

package Launcher_Core is

   --  Use a named number for the constant to allow universal integer matching
   Max_Input_Len : constant := 64;
   
   type Input_Index is range 0 .. Max_Input_Len;
   subtype Valid_Index is Input_Index range 1 .. Max_Input_Len;
   
   type Input_Buffer is record
      Content : String (1 .. Max_Input_Len);
      Length  : Input_Index;
   end record;

   procedure Init (Buffer : out Input_Buffer)
     with Post => Buffer.Length = 0;

   procedure Insert_Char (Buffer : in out Input_Buffer; C : Character)
     with 
       Pre  => Buffer.Length < Max_Input_Len,
       Post => Buffer.Length = Buffer'Old.Length + 1 
               and then Buffer.Content(Integer(Buffer.Length)) = C;

   procedure Backspace (Buffer : in out Input_Buffer)
     with 
       Pre  => Buffer.Length > 0,
       Post => Buffer.Length = Buffer'Old.Length - 1;

   function Is_Full (Buffer : Input_Buffer) return Boolean;
   function Is_Empty (Buffer : Input_Buffer) return Boolean;

end Launcher_Core;
