with Ada.Strings.Bounded;

package Desktop_Files is
   pragma SPARK_Mode (On);

   --  Bounded .desktop parser.  We support the freedesktop subset the
   --  desktop actually needs: Name, Exec, Terminal, NoDisplay, Hidden.
   --  Icon= is parsed but rendered as a text glyph for now (no image
   --  pipeline in Xlib).

   Max_Name_Len : constant := 64;
   Max_Exec_Len : constant := 256;
   Max_Icons    : constant := 64;

   package Name_String is new
     Ada.Strings.Bounded.Generic_Bounded_Length (Max_Name_Len);
   package Exec_String is new
     Ada.Strings.Bounded.Generic_Bounded_Length (Max_Exec_Len);

   type Icon_Entry is record
      Name      : Name_String.Bounded_String;
      Exec      : Exec_String.Bounded_String;
      Icon_Name : Name_String.Bounded_String;
      Terminal  : Boolean := False;
      Hidden    : Boolean := False;
      Valid     : Boolean := False;
   end record;

   type Icon_Table is array (1 .. Max_Icons) of Icon_Entry;

   --  Populate Table from the user's ~/Desktop directory.
   --  Count returns entries that are Valid and not Hidden/NoDisplay.
   procedure Load_Desktop_Icons
     (Table : out Icon_Table;
      Count : out Natural);

end Desktop_Files;
