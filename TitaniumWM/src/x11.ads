with Interfaces.C; use Interfaces.C;
with System;

package X11 is
   pragma SPARK_Mode (Off);
   --  Basic Types
   type Display_Ptr is new System.Address;
   type Window      is new unsigned_long;
   type Atom        is new unsigned_long;
   type Mask        is mod 2**64;
   type KeySym      is new unsigned_long;
   type KeyCode     is new unsigned_char;
   type GC          is new System.Address;
   --  Constants
   SubstructureRedirectMask : constant Mask := 16#00100000#;
   SubstructureNotifyMask   : constant Mask := 16#00080000#;
   StructureNotifyMask      : constant Mask := 16#00020000#;
   KeyPressMask             : constant Mask := 16#00000001#;
   ExposureMask             : constant Mask := 16#00008000#;
   CWOverrideRedirect       : constant Mask := 16#00000200#;
   NoEventMask              : constant Mask := 0;

   --  Modifiers
   ShiftMask    : constant Mask := (1 * 2**0);
   LockMask     : constant Mask := (1 * 2**1);  -- CapsLock
   ControlMask  : constant Mask := (1 * 2**2);
   Mod1Mask     : constant Mask := (1 * 2**3);
   Mod2Mask     : constant Mask := (1 * 2**4);  -- NumLock on typical PCs
   --  Mouse Buttons & Masks
   Button1      : constant := 1;
   Button3      : constant := 3;
   ButtonPressMask      : constant Mask := 4;
   ButtonReleaseMask    : constant Mask := 8;
   PointerMotionMask    : constant Mask := 64;
   Button1Mask          : constant Mask := 256;
   Button3Mask          : constant Mask := 1024;
   --  Keysyms
   XK_Tab       : constant KeySym := 16#FF09#;
   XK_Return    : constant KeySym := 16#FF0D#;
   XK_q         : constant KeySym := 16#0071#;
   XK_h         : constant KeySym := 16#0068#;
   XK_d         : constant KeySym := 16#0064#;
   XK_r         : constant KeySym := 16#0072#;
   XK_m         : constant KeySym := 16#006d#;
   XK_space     : constant KeySym := 16#0020#;
   XK_Left      : constant KeySym := 16#FF51#;
   XK_Up        : constant KeySym := 16#FF52#;
   XK_Right     : constant KeySym := 16#FF53#;
   XK_Down      : constant KeySym := 16#FF54#;
   XK_Escape    : constant KeySym := 16#FF1B#;
   -- Number Keys for Workspaces
   XK_1         : constant KeySym := 16#0031#;
   XK_2         : constant KeySym := 16#0032#;
   XK_3         : constant KeySym := 16#0033#;
   XK_4         : constant KeySym := 16#0034#;
   XK_5         : constant KeySym := 16#0035#;
   XK_6         : constant KeySym := 16#0036#;
   XK_7         : constant KeySym := 16#0037#;
   XK_8         : constant KeySym := 16#0038#;
   XK_9         : constant KeySym := 16#0039#;
   XK_0         : constant KeySym := 16#0030#;
   XK_minus     : constant KeySym := 16#002d#;
   XK_equal     : constant KeySym := 16#003d#;
   XK_comma     : constant KeySym := 16#002c#;
   XK_period    : constant KeySym := 16#002e#;
   -- ClientMessage / ICCCM
   CurrentTime  : constant unsigned_long := 0;
   --  Event Types
   type Event_Type is (
      Unknown,
      KeyPress,
      ButtonPress,
      Expose,
      DestroyNotify,
      UnmapNotify,
      MapRequest,
      ConfigureNotify,
      ConfigureRequest,
      ClientMessage
   );
   for Event_Type use (
      Unknown          => 0,
      KeyPress         => 2,
      ButtonPress      => 4,
      Expose           => 12,
      DestroyNotify    => 17,
      UnmapNotify      => 18,
      MapRequest       => 20,
      ConfigureNotify  => 22,
      ConfigureRequest => 23,
      ClientMessage    => 33
   );
   --  XEvent Structures
   -- Xlib XEvent is a 24-long union (192 bytes on LP64). Keep Ada storage
   -- at least that large so XNextEvent cannot overrun the object.
   type XEvent_Padding is array (1 .. 24) of long;
   type XEvent is record
      Ex_Type : int;
      Serial  : unsigned_long;
      Send    : int;
      Display : Display_Ptr;
      Win     : Window;
      Pad     : XEvent_Padding;
   end record;
   pragma Convention (C, XEvent);
   pragma Assert (XEvent'Size >= 192 * System.Storage_Unit);
   type XKeyEvent is record
      Ex_Type     : int;
      Serial      : unsigned_long;
      Send        : int;
      Display     : Display_Ptr;
      Win         : Window;
      Root        : Window;
      Subwindow   : Window;
      Time        : unsigned_long;
      X, Y        : int;
      X_Root      : int;
      Y_Root      : int;
      State       : unsigned;
      Code        : KeyCode;
      Same_Screen : int;
   end record;
   pragma Convention (C, XKeyEvent);
   type Pad_Array is array (1 .. 18) of long;
   type XMapRequestEvent is record
      Ex_Type : int;
      Serial  : unsigned_long;
      Send    : int;
      Display : Display_Ptr;
      Parent  : Window;
      Win     : Window;
      Pad     : Pad_Array;
   end record;
   pragma Convention (C, XMapRequestEvent);

   type XExposeEvent is record
      Ex_Type : int;
      Serial  : unsigned_long;
      Send    : int;
      Display : Display_Ptr;
      Win     : Window;
      X, Y    : int;
      W, H    : int;
      Count   : int;
   end record;
   pragma Convention (C, XExposeEvent);

   type XConfigureEvent is record
      Ex_Type     : int;
      Serial      : unsigned_long;
      Send        : int;
      Display     : Display_Ptr;
      Event       : Window;
      Win         : Window;
      X, Y        : int;
      W, H        : int;
      Border_W    : int;
      Above       : Window;
      Override    : int;
   end record;
   pragma Convention (C, XConfigureEvent);

   type XConfigureRequestEvent is record
      Ex_Type      : int;
      Serial       : unsigned_long;
      Send         : int;
      Display      : Display_Ptr;
      Parent       : Window;
      Win          : Window;
      X, Y         : int;
      W, H         : int;
      Border_W     : int;
      Above        : Window;
      Detail       : int;
      Value_Mask   : unsigned_long;
   end record;
   pragma Convention (C, XConfigureRequestEvent);

   type XWindowChanges is record
      X, Y         : int;
      W, H         : int;
      Border_Width : int;
      Sibling      : Window;
      Stack_Mode   : int;
   end record;
   pragma Convention (C, XWindowChanges);

   type XDestroyWindowEvent is record
      Ex_Type : int;
      Serial  : unsigned_long;
      Send    : int;
      Display : Display_Ptr;
      Event   : Window;
      Win     : Window;
   end record;
   pragma Convention (C, XDestroyWindowEvent);
   type XUnmapEvent is record
      Ex_Type : int;
      Serial  : unsigned_long;
      Send    : int;
      Display : Display_Ptr;
      Event   : Window;
      Win     : Window;
      From_Configure : int;
   end record;
   pragma Convention (C, XUnmapEvent);

   -- ICCCM ClientMessage (data.l[0] = WM_DELETE_WINDOW for soft close)
   type Client_Message_Data_L is array (0 .. 4) of long;
   type XClientMessageEvent is record
      Ex_Type      : int;
      Serial       : unsigned_long;
      Send         : int;
      Display      : Display_Ptr;
      Win          : Window;
      Message_Type : Atom;
      Format       : int;
      Data_L       : Client_Message_Data_L;
   end record;
   pragma Convention (C, XClientMessageEvent);

   type XSetWindowAttributes is record
      Background_Pixmap : unsigned_long := 0;
      Background_Pixel  : unsigned_long := 0;
      Border_Pixmap     : unsigned_long := 0;
      Border_Pixel      : unsigned_long := 0;
      Bit_Gravity       : int := 0;
      Win_Gravity       : int := 0;
      Backing_Store     : int := 0;
      Backing_Planes    : unsigned_long := 0;
      Backing_Pixel     : unsigned_long := 0;
      Save_Under        : int := 0;
      Event_Mask        : Mask := 0;
      Do_Not_Propagate  : Mask := 0;
      Override_Redirect : int := 0;
      Colormap          : unsigned_long := 0;
      Cursor            : unsigned_long := 0;
   end record;
   pragma Convention (C, XSetWindowAttributes);

   type XErrorEvent is record
      Ex_Type       : int;
      Display       : Display_Ptr;
      ResourceID    : unsigned_long;
      Serial        : unsigned_long;
      Error_Code    : unsigned_char;
      Request_Code  : unsigned_char;
      Minor_Code    : unsigned_char;
   end record;
   pragma Convention (C, XErrorEvent);

   type XErrorEvent_Ptr is access all XErrorEvent;

   type XErrorHandler is access function (
      Display : Display_Ptr;
      Error   : XErrorEvent_Ptr
   ) return int;
   pragma Convention (C, XErrorHandler);

   function XSetErrorHandler (Handler : XErrorHandler) return XErrorHandler
      with Import, Convention => C, External_Name => "XSetErrorHandler";

   type XIOErrorHandler is access procedure (Display : Display_Ptr);
   pragma Convention (C, XIOErrorHandler);

   function XSetIOErrorHandler (Handler : XIOErrorHandler) return XIOErrorHandler
      with Import, Convention => C, External_Name => "XSetIOErrorHandler";

   -- Atom / protocol helpers (ICCCM)
   function XInternAtom (
      Display        : Display_Ptr;
      Atom_Name      : char_array;
      Only_If_Exists : int
   ) return Atom
     with Import, Convention => C, External_Name => "XInternAtom";

   -- Protocols is the address of an Atom* out-parameter (Xlib allocates)
   function XGetWMProtocols (
      Display   : Display_Ptr;
      W         : Window;
      Protocols : System.Address;
      Count     : access int
   ) return int
     with Import, Convention => C, External_Name => "XGetWMProtocols";

   procedure XFree (Data : System.Address)
      with Import, Convention => C, External_Name => "XFree";

   function XSendEvent (
      Display    : Display_Ptr;
      W          : Window;
      Propagate  : int;
      Event_Mask : long;
      Event_Send : access XEvent
   ) return int
     with Import, Convention => C, External_Name => "XSendEvent";

   function XKillClient (Display : Display_Ptr; Resource : Window) return int
      with Import, Convention => C, External_Name => "XKillClient";

   --  Imported Functions
   function XOpenDisplay (Display_Name : char_array) return Display_Ptr
      with Import, Convention => C, External_Name => "XOpenDisplay";
   function XDefaultRootWindow (Display : Display_Ptr) return Window
      with Import, Convention => C, External_Name => "XDefaultRootWindow";
   function XDefaultScreen (Display : Display_Ptr) return int
      with Import, Convention => C, External_Name => "XDefaultScreen";
   procedure XSelectInput (Display : Display_Ptr; W : Window; Event_Mask : Mask)
      with Import, Convention => C, External_Name => "XSelectInput";
   procedure XNextEvent (Display : Display_Ptr; Event : out XEvent)
      with Import, Convention => C, External_Name => "XNextEvent";
   --  Returns nonzero if a queued event of Event_Type was removed into
   --  Event_Return; used to drain stale MotionNotify during drags.
   function XCheckTypedEvent (
      Display      : Display_Ptr;
      Event_Type   : int;
      Event_Return : access XEvent
   ) return int
      with Import, Convention => C, External_Name => "XCheckTypedEvent";
   procedure XMapWindow (Display : Display_Ptr; W : Window)
      with Import, Convention => C, External_Name => "XMapWindow";
   procedure XUnmapWindow (Display : Display_Ptr; W : Window)
      with Import, Convention => C, External_Name => "XUnmapWindow";
   function XDisplayWidth (Display : Display_Ptr; Screen_Number : int) return int
      with Import, Convention => C, External_Name => "XDisplayWidth";
   function XDisplayHeight (Display : Display_Ptr; Screen_Number : int) return int
      with Import, Convention => C, External_Name => "XDisplayHeight";
   procedure XRaiseWindow (Display : Display_Ptr; W : Window)
      with Import, Convention => C, External_Name => "XRaiseWindow";
   procedure XGrabButton (
      Display   : Display_Ptr;
      Button    : unsigned;
      Modifiers : Mask;
      Grab_Win  : Window;
      Owner     : int;
      Event_Mask: Mask;
      Ptr_Mode  : int;
      Kbd_Mode  : int;
      Confine   : Window;
      Cursor    : unsigned_long
   ) with Import, Convention => C, External_Name => "XGrabButton";
   function XQueryPointer (
      Display : Display_Ptr;
      W       : Window;
      Root    : out Window;
      Child   : out Window;
      Root_X  : out int;
      Root_Y  : out int;
      Win_X   : out int;
      Win_Y   : out int;
      Mask    : out unsigned
   ) return int
     with Import, Convention => C, External_Name => "XQueryPointer";
   function XGetGeometry (
      Display      : Display_Ptr;
      Drawable     : Window;
      Root         : out Window;
      X, Y         : out int;
      Width, Height: out unsigned;
      Border_Width : out unsigned;
      Depth        : out unsigned
   ) return int
     with Import, Convention => C, External_Name => "XGetGeometry";
   procedure XMoveResizeWindow (
      Display : Display_Ptr;
      W       : Window;
      X, Y    : int;
      Width   : unsigned;
      Height  : unsigned
   ) with Import, Convention => C, External_Name => "XMoveResizeWindow";

   procedure XConfigureWindow (
      Display    : Display_Ptr;
      W          : Window;
      Value_Mask : unsigned;
      Values     : access XWindowChanges
   ) with Import, Convention => C, External_Name => "XConfigureWindow";

   procedure XFlush (Display : Display_Ptr)
      with Import, Convention => C, External_Name => "XFlush";
   function XCreateSimpleWindow (
      Display      : Display_Ptr;
      Parent       : Window;
      X, Y         : int;
      Width, Height : unsigned;
      Border_Width : unsigned;
      Border       : unsigned_long;
      Background   : unsigned_long
   ) return Window
     with Import, Convention => C, External_Name => "XCreateSimpleWindow";
   procedure XChangeWindowAttributes (
      Display : Display_Ptr;
      W       : Window;
      Valuemask : Mask;
      Attributes : access XSetWindowAttributes
   ) with Import, Convention => C, External_Name => "XChangeWindowAttributes";
   procedure XDestroyWindow (Display : Display_Ptr; W : Window)
      with Import, Convention => C, External_Name => "XDestroyWindow";
   procedure XSetWindowBackground (Display : Display_Ptr; W : Window; Color : unsigned_long)
      with Import, Convention => C, External_Name => "XSetWindowBackground";
   procedure XSetWindowBorder (Display : Display_Ptr; W : Window; Color : unsigned_long)
      with Import, Convention => C, External_Name => "XSetWindowBorder";
   procedure XSetWindowBorderWidth (Display : Display_Ptr; W : Window; Width : unsigned)
      with Import, Convention => C, External_Name => "XSetWindowBorderWidth";
   procedure XClearWindow (Display : Display_Ptr; W : Window)
      with Import, Convention => C, External_Name => "XClearWindow";
   function XWhitePixel (Display : Display_Ptr; Screen_Number : int) return unsigned_long
      with Import, Convention => C, External_Name => "XWhitePixel";
   function XBlackPixel (Display : Display_Ptr; Screen_Number : int) return unsigned_long
      with Import, Convention => C, External_Name => "XBlackPixel";
   function XKeysymToKeycode (Display : Display_Ptr; Key_Sym : KeySym) return KeyCode
      with Import, Convention => C, External_Name => "XKeysymToKeycode";
   procedure XGrabKey (
      Display   : Display_Ptr;
      Code      : KeyCode;
      Modifiers : Mask;
      Grab_Win  : Window;
      Owner     : int;
      Ptr_Mode  : int;
      Kbd_Mode  : int
   ) with Import, Convention => C, External_Name => "XGrabKey";
   procedure XSetInputFocus (
      Display : Display_Ptr;
      Focus   : Window;
      Revert  : int;
      Time    : unsigned_long
   ) with Import, Convention => C, External_Name => "XSetInputFocus";
   function XCreateGC (
      Display  : Display_Ptr;
      Drawable : Window;
      Mask     : unsigned_long;
      Values   : System.Address
   ) return GC
     with Import, Convention => C, External_Name => "XCreateGC";
   procedure XSetForeground (Display : Display_Ptr; G : GC; Foreground : unsigned_long)
      with Import, Convention => C, External_Name => "XSetForeground";
   procedure XDrawString (
      Display  : Display_Ptr;
      Drawable : Window;
      G        : GC;
      X, Y     : int;
      String   : char_array;
      Length   : int
   ) with Import, Convention => C, External_Name => "XDrawString";
   function System_Call (Command : char_array) return int
      with Import, Convention => C, External_Name => "system";

   -- Xinerama multi-monitor
   type XineramaScreenInfo is record
      Screen_Number : int;
      X_Org         : short;
      Y_Org         : short;
      Width         : short;
      Height        : short;
   end record;
   pragma Convention (C, XineramaScreenInfo);

   function XineramaIsActive (Display : Display_Ptr) return int
      with Import, Convention => C, External_Name => "XineramaIsActive";

   function XineramaQueryScreens
     (Display : Display_Ptr; Number : access int) return System.Address
      with Import, Convention => C, External_Name => "XineramaQueryScreens";

   Global_Display : Display_Ptr := Display_Ptr (System.Null_Address);

end X11;
