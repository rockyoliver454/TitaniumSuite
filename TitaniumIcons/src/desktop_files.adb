with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Environment_Variables;

package body Desktop_Files is

   --  (no use type needed — Bounded ops are visible via instance scope)

   --  Strip freedesktop field codes (%f %F %u %U %i %c %k %% and friends)
   --  from an Exec line.  Bounded in/out.
   function Sanitize_Exec (Raw : Exec_String.Bounded_String)
      return Exec_String.Bounded_String
   is
      S    : constant String := Exec_String.To_String (Raw);
      Outp : Exec_String.Bounded_String := Exec_String.Null_Bounded_String;
      I    : Natural := S'First;
   begin
      while I <= S'Last loop
         if S (I) = '%' then
            if I + 1 <= S'Last then
               if S (I + 1) = '%' then
                  Exec_String.Append (Outp, '%');
               end if;
               I := I + 2;          --  drop code, keep "%%"->'%'
            else
               I := I + 1;          --  trailing '%' — drop
            end if;
         else
            Exec_String.Append (Outp, S (I));
            I := I + 1;
         end if;
      end loop;
      return Outp;
   end Sanitize_Exec;

   --  Parse one .desktop file into an entry.
   procedure Parse_File
     (Path  : String;
      E     : out Icon_Entry)
   is
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 4096);
      Len  : Natural;
      Eq   : Natural;

      function Value (Key : String) return String is
      begin
         if Len > Key'Length
           and then Line (1 .. Key'Length) = Key
           and then Line (Key'Length + 1) = '='
         then
            return Line (Key'Length + 2 .. Len);
         end if;
         return "";
      end Value;

      function Bool_Value (Key : String) return Boolean is
         V : constant String := Value (Key);
      begin
         return V = "true" or else V = "1" or else V = "yes";
      end Bool_Value;

      In_Desktop_Entry : Boolean := False;
   begin
      E := (others => <>);
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Len);
         if Len > 0 then
            if Line (1) = '[' then
               In_Desktop_Entry :=
                 Len >= 15
                 and then Line (1 .. 15) = "[Desktop Entry]";
            elsif In_Desktop_Entry then
               Eq := Ada.Strings.Fixed.Index (Line (1 .. Len), "=");
               if Eq > 1 then
                  declare
                     K : constant String := Line (1 .. Eq - 1);
                     V : constant String := Value (K);
                  begin
                     if K = "Name" then
                        E.Name := Name_String.To_Bounded_String (V);
                     elsif K = "Exec" then
                        E.Exec := Exec_String.To_Bounded_String (V);
                     elsif K = "Icon" then
                        E.Icon_Name := Name_String.To_Bounded_String (V);
                     elsif K = "Terminal" then
                        E.Terminal := Bool_Value (K);
                     elsif K = "NoDisplay" then
                        E.Hidden := Bool_Value (K);
                     elsif K = "Hidden" then
                        E.Hidden := Bool_Value (K);
                     end if;
                  end;
               end if;
            end if;
         end if;
      end loop;
      Ada.Text_IO.Close (File);

      E.Exec := Sanitize_Exec (E.Exec);
      E.Valid := Name_String.Length (E.Name) > 0
                 and then Exec_String.Length (E.Exec) > 0;
   exception
      when others =>
         E := (others => <>);   --  malformed file: skip, never crash
   end Parse_File;

   procedure Load_Desktop_Icons
     (Table : out Icon_Table;
      Count : out Natural)
   is
      Home : constant String := Ada.Environment_Variables.Value
        ("HOME", "");
      Dir  : constant String :=
        (if Home'Length = 0 then "/root/Desktop" else Home & "/Desktop");
      Search  : Ada.Directories.Search_Type;
      Dir_Ent : Ada.Directories.Directory_Entry_Type;
      Started : Boolean := False;
   begin
      Count := 0;
      Table := (others => (others => <>));

      if not Ada.Directories.Exists (Dir) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search, Dir, "*.desktop",
         Filter => (Ada.Directories.Ordinary_File => True,
                    others => False));
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Ent);
         exit when Count >= Max_Icons;

         declare
            Full : constant String := Ada.Directories.Full_Name (Dir_Ent);
            E    : Icon_Entry;
         begin
            Parse_File (Full, E);
            if E.Valid and then not E.Hidden then
               Count := Count + 1;
               Table (Count) := E;
            end if;
         end;
      end loop;

      if Started then
         Ada.Directories.End_Search (Search);
      end if;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         --  best-effort: return what we parsed so far
   end Load_Desktop_Icons;

end Desktop_Files;
