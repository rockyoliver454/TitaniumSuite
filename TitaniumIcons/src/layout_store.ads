with Ada.Strings.Bounded;
with Desktop_Files;

package Layout_Store is

   --  ~/.config/titaniumicons/layout.conf — the file a user backs up
   --  to keep icon positions and appearance.  Positions are stored
   --  normalized to 0..65535 per axis (resolution-independent);
   --  see phase8/albwasm/deskicons.alb for the encode math.

   Max_Entries : constant := 64;

   subtype Base_String is Desktop_Files.Name_String.Bounded_String;
   subtype Path_String is Desktop_Files.Exec_String.Bounded_String;

   type Layout_Entry is record
      Base    : Base_String;
      Has_Pos : Boolean := False;
      Nx      : Natural := 0;
      Ny      : Natural := 0;
      Color   : Natural := 0;                  --  palette index
      Image   : Path_String;                   --  empty = none
   end record;

   type Layout_Table is array (1 .. Max_Entries) of Layout_Entry;

   --  Absolute path of the config dir / file ($HOME-aware).
   function Config_Dir  return String;
   function Config_Path return String;

   --  Read the file; missing file => N = 0 (defaults everywhere).
   procedure Load (T : out Layout_Table; N : out Natural);

   --  Index of Base in T, or 0.
   function Find
     (T : Layout_Table; N : Natural; Base : String) return Natural;

   --  Index of Base, creating an empty entry at the end if needed.
   --  Returns 0 when the table is full.
   function Upsert
     (T : in out Layout_Table; N : in out Natural; Base : String)
      return Natural;

   --  Rewrite the whole file (bounded, atomic-ish: tmp + rename).
   --  Scr_W/H are informational (resolution at save time).
   procedure Save
     (T : Layout_Table; N : Natural; Scr_W, Scr_H : Natural);

end Layout_Store;
