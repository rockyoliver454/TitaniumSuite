with Ada.Text_IO;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Desktop_Files;

package body Layout_Store is

   package BS renames Desktop_Files.Name_String;
   package PS renames Desktop_Files.Exec_String;

   function Home return String is
     (Ada.Environment_Variables.Value ("HOME", "/root"));

   function Config_Dir return String is
     (Home & "/.config/titaniumicons");

   function Config_Path return String is
     (Config_Dir & "/layout.conf");

   --  Read a k=v field out of a line's tail.  Fields are space-
   --  separated; the LAST field (image=) may contain spaces.
   function Field (Line : String; Key : String) return String is
      Pat : constant String := Key & "=";
      P   : Natural;
   begin
      --  search " key=" or line-start "key="
      if Line'Length >= Pat'Length
        and then Line (Line'First .. Line'First + Pat'Length - 1) = Pat
      then
         P := Line'First;
      else
         P := Ada.Strings.Fixed.Index (Line, " " & Pat);
         if P > 0 then
            P := P + 1;
         end if;
      end if;
      if P = 0 then
         return "";
      end if;
      declare
         S : constant Natural := P + Pat'Length;
         E : Natural := S;
      begin
         while E <= Line'Last and then Line (E) /= ' ' loop
            E := E + 1;
         end loop;
         if E > S then
            return Line (S .. E - 1);
         end if;
         return "";
      end;
   end Field;

   procedure Load (T : out Layout_Table; N : out Natural) is
      use Ada.Text_IO;
      F    : File_Type;
      Line : String (1 .. 2048);
      Len  : Natural;
   begin
      T := (others => (others => <>));
      N := 0;
      if not Ada.Directories.Exists (Config_Path) then
         return;
      end if;
      Open (F, In_File, Config_Path);
      while not End_Of_File (F) loop
         Get_Line (F, Line, Len);
         if Len > 5 and then Line (1 .. 5) = "icon=" then
            declare
               L : constant String := Line (1 .. Len);
               B : constant String := Field (L, "icon");
               E : Natural;
            begin
               if B'Length > 0 and then N < Max_Entries then
                  N := N + 1;
                  E := N;
                  T (E).Base := BS.To_Bounded_String (B);
                  begin
                     T (E).Nx := Natural'Value (Field (L, "nx"));
                     T (E).Ny := Natural'Value (Field (L, "ny"));
                     T (E).Has_Pos := True;
                  exception
                     when others =>
                        T (E).Has_Pos := False;
                  end;
                  begin
                     T (E).Color := Natural'Value (Field (L, "color"));
                  exception
                     when others =>
                        T (E).Color := 0;
                  end;
                  declare
                     Im : constant String := Field (L, "image");
                  begin
                     if Im'Length > 0 and then Im /= "-" then
                        T (E).Image := PS.To_Bounded_String (Im);
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then Close (F); end if;
         --  keep whatever parsed
   end Load;

   function Find
     (T : Layout_Table; N : Natural; Base : String) return Natural is
   begin
      for I in 1 .. N loop
         if BS.To_String (T (I).Base) = Base then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   function Upsert
     (T : in out Layout_Table; N : in out Natural; Base : String)
      return Natural is
      I : constant Natural := Find (T, N, Base);
   begin
      if I > 0 then
         return I;
      elsif N >= Max_Entries then
         return 0;
      else
         N := N + 1;
         T (N) := (Base => BS.To_Bounded_String (Base), others => <>);
         return N;
      end if;
   end Upsert;

   procedure Save
     (T : Layout_Table; N : Natural; Scr_W, Scr_H : Natural)
   is
      use Ada.Text_IO;
      Tmp : constant String := Config_Path & ".tmp";
      F   : File_Type;

      function Trim (V : Natural) return String is
         S : constant String := Natural'Image (V);
      begin
         return S (S'First + 1 .. S'Last);
      end Trim;
   begin
      Ada.Directories.Create_Path (Config_Dir);
      Create (F, Out_File, Tmp);
      Put_Line (F, "# TitaniumIcons layout - back this file up to keep");
      Put_Line (F, "# icon positions.  Positions are resolution-");
      Put_Line (F, "# independent normalized units (0..65535 per axis)");
      Put_Line (F, "# via deskicons.wasm - icon colour + image follow.");
      Put_Line (F, "version=1");
      Put_Line (F, "screen=" & Trim (Scr_W) & "x" & Trim (Scr_H));
      for I in 1 .. N loop
         declare
            Im : constant String := PS.To_String (T (I).Image);
         begin
            Put_Line
              (F,
               "icon=" & BS.To_String (T (I).Base)
               & " nx=" & Trim (T (I).Nx)
               & " ny=" & Trim (T (I).Ny)
               & " color=" & Trim (T (I).Color)
               & " image=" & (if Im'Length = 0 then "-" else Im));
         end;
      end loop;
      Close (F);
      Ada.Directories.Rename (Tmp, Config_Path);
   exception
      when others =>
         if Is_Open (F) then Close (F); end if;
   end Save;

end Layout_Store;
