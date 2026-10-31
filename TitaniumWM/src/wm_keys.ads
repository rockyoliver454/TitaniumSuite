with X11;

package WM_Keys is
   
   -- Registers Alt+Tab, Alt+Q, Alt+Enter with X11
   procedure Setup_Keys;
   
   -- Called when Main receives a KeyPress event
   procedure Handle_Key (Event : X11.XEvent);

end WM_Keys;
