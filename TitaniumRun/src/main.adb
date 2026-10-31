with System;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;
with X11; use X11;
with Launcher_Core; use Launcher_Core;
with Completion; use Completion; -- New Package
with GNAT.OS_Lib;
with Ada.Directories;

procedure Main is
   
   use type System.Address;
   use type Interfaces.C.unsigned_long;

   --  X11 Globals
   Display_Name : Strings.chars_ptr := Strings.Null_Ptr;
   Screen_Num   : int := 0; 
   Dpy  : Display_Ptr;
   Win  : Window;
   Root : Window;
   GC_H : GC;
   EvT  : XEvent;
   
   --  Logic Globals
   Buffer  : Input_Buffer;
   DB      : Database;        -- The Cache
   Results : Match_Result;    -- Current Search Results
   Running : Boolean := True;
   
   Key_Sym   : aliased unsigned_long;
   Text_Buf  : char_array (1 .. 10);
   Count     : int;
   
   XK_Tab    : constant unsigned_long := 65289; -- 0xFF09

   --  Loader: Not SPARK, handles dirty FS IO
   procedure Load_System_Binaries is
      use Ada.Directories;
      
      --  The "Titanium" Standard Path List
      --  We use an array of access strings to allow varying lengths easily
      type String_Access is access constant String;
      
      Search_Paths : constant array (1 .. 5) of String_Access := 
        (new String'("/usr/bin"), 
         new String'("/bin"), 
         new String'("/usr/local/bin"), 
         new String'("/sbin"), 
         new String'("/usr/sbin"));

      --  Helper to scan a single path safely
      procedure Scan_Directory (Path : String) is
         Search_Item : Search_Type;
         Dir_Ent     : Directory_Entry_Type;
      begin
         --  Check if it exists first to avoid exception spam
         if not Exists (Path) or else Kind (Path) /= Directory then
            return;
         end if;

         Start_Search (Search_Item, Path, "");
         
         while More_Entries (Search_Item) loop
            Get_Next_Entry (Search_Item, Dir_Ent);
            
            --  Filter: No hidden files, no directories, check capacity
            if Simple_Name(Dir_Ent)(1) /= '.' 
               and then Kind(Dir_Ent) = Ordinary_File 
            then
               if DB.Count < Max_Candidates then
                  Add_Candidate(DB, Simple_Name(Dir_Ent));
               else
                  exit; -- Stop if cache is full
               end if;
            end if;
         end loop;
         End_Search (Search_Item);
      exception
         when others => null; -- Safety: Ignore any read permission errors
      end Scan_Directory;

   begin
      Init(DB);
      
      --  Iterate over our hardcoded list
      for I in Search_Paths'Range loop
         if DB.Count < Max_Candidates then
            Scan_Directory (Search_Paths(I).all);
         end if;
      end loop;
   end Load_System_Binaries;
   procedure Draw_UI is
      X_Offset : int := 10;
   begin
      XClearWindow (Dpy, Win);
      
      --  1. Draw User Input
      if not Is_Empty(Buffer) then
         declare
            C_Str : char_array (1 .. size_t(Buffer.Length));
         begin
            for I in 1 .. Buffer.Length loop
               C_Str(size_t(I)) := char(Buffer.Content(Integer(I)));
            end loop;
            XDrawString(Dpy, Win, GC_H, X_Offset, 15, C_Str, int(Buffer.Length));
            
            -- Move Offset for results
            X_Offset := X_Offset + (int(Buffer.Length) * 7) + 20; 
         end;
      end if;

      --  2. Draw Auto-Complete Suggestions (in Grey/Dim if possible, or just space them)
      if Results.Count > 0 then
         for I in 1 .. Results.Count loop
            declare
               -- Ada String to C String conversion
               Res_Str : String := Results.Items(I);
               C_Res   : char_array (1 .. Res_Str'Length);
            begin
               for C in Res_Str'Range loop
                  C_Res(size_t(C)) := char(Res_Str(C));
               end loop;
               
               -- Draw
               XDrawString(Dpy, Win, GC_H, X_Offset, 15, C_Res, Max_Name_Len);
               
               -- Shift Right
               X_Offset := X_Offset + 120; 
            end;
         end loop;
      end if;

   end Draw_UI;

begin
   --  1. Load Data (Takes ~50ms)
   Load_System_Binaries;
   
   Init(Buffer);

   Dpy := XOpenDisplay(Display_Name);
   if Dpy = System.Null_Address then return; end if;

   Root := XRootWindow(Dpy, XDefaultScreen(Dpy));
   Win := XCreateSimpleWindow(Dpy, Root, 0, 0, 1920, 25, 0, Black_Pixel, Black_Pixel);
   
   XSelectInput(Dpy, Win, KeyPressMask or ExposureMask);
   XMapWindow(Dpy, Win);
   
   --  Grab Input
   declare
      Grab_Res : int := XGrabKeyboard(Dpy, Win, 1, 1, 1, 0); 
   begin null; end;
   
   GC_H := XDefaultGC(Dpy, Screen_Num);
   XSetForeground(Dpy, GC_H, White_Pixel);

   while Running loop
      XNextEvent(Dpy, EvT);

      if EvT.Type_Code = KeyPress then
         Count := XLookupString(EvT'Address, Text_Buf, 10, Key_Sym'Access, System.Null_Address);

         if Key_Sym = XK_Escape then
            Running := False;
         
         elsif Key_Sym = XK_Return then
            --  Launch Logic
            declare
               User_Cmd : String := Buffer.Content(1 .. Integer(Buffer.Length));
               Shell_Args : GNAT.OS_Lib.Argument_List (1 .. 2);
               Success    : Boolean;
            begin
               Shell_Args(1) := new String'("-c");
               Shell_Args(2) := new String'(User_Cmd & " &");
               GNAT.OS_Lib.Spawn("/bin/sh", Shell_Args, Success);
               GNAT.OS_Lib.Free(Shell_Args(1));
               GNAT.OS_Lib.Free(Shell_Args(2));
            end;
            Running := False;

         elsif Key_Sym = XK_BackSpace then
            if not Is_Empty(Buffer) then
               Backspace(Buffer);
            end if;

         --  TAB Completion
         elsif Key_Sym = XK_Tab then
            if Results.Count > 0 then
               --  Auto-fill the buffer with the first result
               --  Clear current buffer
               Init(Buffer);
               --  Fill with match (strip trailing spaces)
               declare
                  Match : String := Results.Items(1);
               begin
                  for C in Match'Range loop
                     if Match(C) /= ' ' then
                        Insert_Char(Buffer, Match(C));
                     end if;
                  end loop;
               end;
            end if;

         else
            if Count > 0 and then not Is_Full(Buffer) then
               Insert_Char(Buffer, Character(Text_Buf(1)));
            end if;
         end if;

         --  Re-run Search on every keystroke
         if not Is_Empty(Buffer) then
            Search(DB, Buffer.Content(1 .. Integer(Buffer.Length)), Results);
         else
            Results.Count := 0;
         end if;

         Draw_UI;

      elsif EvT.Type_Code = Expose then
         Draw_UI;
      end if;

   end loop;

end Main;
