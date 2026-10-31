-- Phase C: light ICCCM client contract (SPARK Off — X FFI).
-- Soft_Close prefers WM_DELETE_WINDOW when advertised; Force_Kill is decisive.
with X11;

package WM_ICCCM is
   pragma SPARK_Mode (Off);

   -- Intern WM_PROTOCOLS / WM_DELETE_WINDOW (call once after XOpenDisplay)
   procedure Init_Atoms;

   -- Query XGetWMProtocols; cache Supports_Delete on the managed client
   procedure Probe_Delete_Protocol (Win : X11.Window);

   -- Alt+Q: cooperative close if supported, else XDestroyWindow + Remove_Client
   procedure Soft_Close (Win : X11.Window);

   -- Alt+Shift+Q: XKillClient + Remove_Client (decisive)
   procedure Force_Kill (Win : X11.Window);

   -- Swallow / ignore ClientMessage safely (never raise)
   procedure Handle_Client_Message (Event : X11.XEvent);

end WM_ICCCM;
