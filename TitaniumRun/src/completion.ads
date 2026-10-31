pragma SPARK_Mode (On);

package Completion is

   --  Configuration: Fixed Bounds for Memory Safety
   Max_Candidates : constant := 8192;  -- Store up to 2048 commands
   Max_Name_Len   : constant := 16;    -- Truncate names > 16 chars (e.g. "firefox")
   Max_Results    : constant := 5;     -- Only show top 5 matches

   subtype Name_String is String (1 .. Max_Name_Len);
   
   type Candidate_List is array (1 .. Max_Candidates) of Name_String;
   
   --  The State Machine
   type Database is record
      Items : Candidate_List;
      Count : Integer range 0 .. Max_Candidates;
   end record;

   --  Result container for the UI
   type Match_Array is array (1 .. Max_Results) of Name_String;
   type Match_Result is record
      Items : Match_Array;
      Count : Integer range 0 .. Max_Results;
   end record;

   --  Initialize the database (Sets count to 0)
   procedure Init (DB : out Database);

   --  Add a command (Used during startup loading)
   procedure Add_Candidate (DB : in out Database; Name : String)
     with Pre => DB.Count < Max_Candidates;

   --  Find matches for a given query (SPARK verified logic)
   procedure Search 
     (DB      : Database; 
      Query   : String; 
      Matches : out Match_Result);

end Completion;
