-- Phase B: bounded binary session dump (compile-time path, no config language).
-- Save on clean quit / display loss; best-effort restore on startup.
with X11;

package Session_Persist is
   pragma SPARK_Mode (Off);

   -- Compile-time session path (rebuild to change; never parsed from user input)
   Session_File_Name : constant String := "/tmp/titaniumwm.session";

   -- Process exit status contract (TitaniumLogin / startx can branch on these)
   Exit_Normal           : constant := 0;
   Exit_Display_Lost     : constant := 75;
   Exit_Reconnect_Failed : constant := 76;

   procedure Save_Session;
   -- Best-effort load: restores workspace/mode/master and pending per-window
   -- hints. Never raises; stale or missing files are ignored.
   procedure Try_Load_Session;

   -- Apply pending restore hints when a window is (re)managed
   procedure Apply_Restore_Hints (Win : X11.Window);

   -- Xlib IO error handler: Save_Session then exit(75). Must not return.
   procedure Handle_IO_Error (Display : X11.Display_Ptr)
     with Convention => C;

end Session_Persist;
