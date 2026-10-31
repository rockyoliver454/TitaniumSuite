--  Find a free display, start X, wait until ready, stop X.

with Posix_Thin;

package Display_Mgr is
   pragma SPARK_Mode (Off);

   subtype Display_Number is Natural range 0 .. 63;

   function Find_Free_Display (Num : out Display_Number) return Boolean;
   --  Prefer :1 .. :10. True if a candidate path looks free.

   function Start_X
     (Num : Display_Number;
      Pid : out Posix_Thin.Pid_T) return Boolean;
   --  Fork/exec Xorg or /usr/bin/X. Pid is the X server process.

   function Wait_Until_Ready (Num : Display_Number) return Boolean;

   procedure Stop_X (Pid : Posix_Thin.Pid_T);

   function Display_Name (Num : Display_Number) return String;
   --  e.g. ":3"

end Display_Mgr;
