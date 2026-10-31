package body Completion is

   procedure Init (DB : out Database) is
   begin
      DB.Count := 0;
      DB.Items := (others => (others => ' '));
      
      --  Initialize result container default
   end Init;

   procedure Add_Candidate (DB : in out Database; Name : String) is
      Len : Integer;
   begin
      if DB.Count < Max_Candidates then
         DB.Count := DB.Count + 1;
         
         --  Safe copy with truncation
         if Name'Length > Max_Name_Len then
            Len := Max_Name_Len;
         else
            Len := Name'Length;
         end if;
         
         --  Clear old data first (determinism)
         DB.Items(DB.Count) := (others => ' ');
         DB.Items(DB.Count)(1 .. Len) := Name(Name'First .. Name'First + Len - 1);
      end if;
   end Add_Candidate;

   procedure Search 
     (DB      : Database; 
      Query   : String; 
      Matches : out Match_Result) 
   is
      Match_Count : Integer := 0;
      Q_Len       : Integer := Query'Length;
   begin
      --  Reset Output
      Matches.Count := 0;
      Matches.Items := (others => (others => ' '));
      
      if Q_Len = 0 then
         return;
      end if;

      --  Linear scan of our cache
      for I in 1 .. DB.Count loop
         --  Check bounds to avoid reading past the stored name
         --  Logic: Does Candidate start with Query?
         if Match_Count < Max_Results then
            declare
               Cand : Name_String := DB.Items(I);
               Is_Match : Boolean := True;
            begin
               --  Manual loop is cleaner for SPARK than slice comparison sometimes
               for C in 1 .. Q_Len loop
                  if C > Max_Name_Len or else Cand(C) /= Query(Query'First + C - 1) then
                     Is_Match := False;
                     exit;
                  end if;
               end loop;

               if Is_Match then
                  Match_Count := Match_Count + 1;
                  Matches.Items(Match_Count) := Cand;
               end if;
            end;
         else
            exit; -- Optimization: Stop after finding 5
         end if;
      end loop;
      
      Matches.Count := Match_Count;
   end Search;

end Completion;
