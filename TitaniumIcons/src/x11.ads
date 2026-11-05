with System;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;

package X11 is
   --  Must be Preelaborate because C.Strings is Preelaborate, not Pure
   pragma Preelaborate;

   --  Standard X11 Types
   subtype Display_Ptr is System.Address;
   subtype Window      is Interfaces.C.unsigned_long;
   subtype Drawable    is Window;
   subtype GC          is System.Address;

   --  Generic event union view (same pad trick as TitaniumRun).
   type XEvent is record
      Type_Code : Interfaces.C.int;
      Pad       : Interfaces.C.char_array (1 .. 192);
   end record;
   pragma Convention (C, XEvent);

   --  XAnyEvent view — used to recover the window that got the event.
   --  Padded to the same storage size as XEvent so the unchecked
   --  conversion view is size-exact (matches Xlib union semantics).
   type XAnyEvent is record
      Type_Code  : Interfaces.C.int;
      Serial     : Interfaces.C.unsigned_long;
      Send_Event : Interfaces.C.int;
      Display    : Display_Ptr;
      Win        : Window;
      Pad        : Interfaces.C.char_array (1 .. 156);
   end record;
   pragma Convention (C, XAnyEvent);

   --  XButtonEvent / XMotionEvent share this layout.  ButtonRelease
   --  and MotionNotify are read through the same view.
   type XButtonEvent is record
      Type_Code   : Interfaces.C.int;
      Serial      : Interfaces.C.unsigned_long;
      Send_Event  : Interfaces.C.int;
      Display     : Display_Ptr;
      Win         : Window;
      Root_W      : Window;
      Subwindow   : Window;
      Time_V      : Interfaces.C.unsigned_long;
      X_Pos       : Interfaces.C.int;
      Y_Pos       : Interfaces.C.int;
      X_Root      : Interfaces.C.int;
      Y_Root      : Interfaces.C.int;
      State       : Interfaces.C.unsigned;
      Button      : Interfaces.C.unsigned;
      Same_Screen : Interfaces.C.int;
      Pad         : Interfaces.C.char_array (1 .. 104);
   end record;
   pragma Convention (C, XButtonEvent);

   --  XKeyEvent — identical layout to XButtonEvent except the
   --  Button field is the hardware keycode.
   type XKeyEvent is record
      Type_Code   : Interfaces.C.int;
      Serial      : Interfaces.C.unsigned_long;
      Send_Event  : Interfaces.C.int;
      Display     : Display_Ptr;
      Win         : Window;
      Root_W      : Window;
      Subwindow   : Window;
      Time_V      : Interfaces.C.unsigned_long;
      X_Pos       : Interfaces.C.int;
      Y_Pos       : Interfaces.C.int;
      X_Root      : Interfaces.C.int;
      Y_Root      : Interfaces.C.int;
      State       : Interfaces.C.unsigned;
      Keycode     : Interfaces.C.unsigned;
      Same_Screen : Interfaces.C.int;
      Pad         : Interfaces.C.char_array (1 .. 104);
   end record;
   pragma Convention (C, XKeyEvent);

   --  XConfigureEvent — root size changes (resolution resistance).
   type XConfigureEvent is record
      Type_Code         : Interfaces.C.int;
      Serial            : Interfaces.C.unsigned_long;
      Send_Event        : Interfaces.C.int;
      Display           : Display_Ptr;
      Event_W           : Window;
      Win               : Window;
      X_Pos             : Interfaces.C.int;
      Y_Pos             : Interfaces.C.int;
      Width             : Interfaces.C.int;
      Height            : Interfaces.C.int;
      Border_Width      : Interfaces.C.int;
      Above             : Window;
      Override_Redirect : Interfaces.C.int;
      Pad               : Interfaces.C.char_array (1 .. 104);
   end record;
   pragma Convention (C, XConfigureEvent);

   --  XWindowAttributes for XGetWindowAttributes (we only read
   --  x/y/width/height but the C struct must be full-size).
   type XWindowAttributes is record
      X_Pos            : Interfaces.C.int;
      Y_Pos            : Interfaces.C.int;
      Width            : Interfaces.C.int;
      Height           : Interfaces.C.int;
      Border_Width     : Interfaces.C.int;
      Depth            : Interfaces.C.int;
      Visual           : System.Address;
      Root_W           : Window;
      C_Class          : Interfaces.C.int;
      Bit_Gravity      : Interfaces.C.int;
      Win_Gravity      : Interfaces.C.int;
      Backing_Store    : Interfaces.C.int;
      Backing_Planes   : Interfaces.C.unsigned_long;
      Backing_Pixel    : Interfaces.C.unsigned_long;
      Save_Under       : Interfaces.C.int;
      Colormap         : Interfaces.C.unsigned_long;
      Map_Installed    : Interfaces.C.int;
      Map_State        : Interfaces.C.int;
      All_Event_Masks  : Interfaces.C.long;
      Your_Event_Mask  : Interfaces.C.long;
      Do_Not_Propagate : Interfaces.C.long;
      Override_Red     : Interfaces.C.int;
      Screen_Ptr       : System.Address;
   end record;
   pragma Convention (C, XWindowAttributes);

   --  Events we care about
   KeyPress        : constant Interfaces.C.int := 2;
   ButtonPress     : constant Interfaces.C.int := 4;
   ButtonRelease   : constant Interfaces.C.int := 5;
   MotionNotify    : constant Interfaces.C.int := 6;
   Expose          : constant Interfaces.C.int := 12;
   ConfigureNotify : constant Interfaces.C.int := 22;

   KeyPressMask        : constant Interfaces.C.unsigned_long := 1;
   ButtonPressMask     : constant Interfaces.C.unsigned_long := 4;
   ButtonReleaseMask   : constant Interfaces.C.unsigned_long := 8;
   EnterWindowMask     : constant Interfaces.C.unsigned_long := 16;
   LeaveWindowMask     : constant Interfaces.C.unsigned_long := 32;
   PointerMotionMask   : constant Interfaces.C.unsigned_long := 64;
   Button1MotionMask   : constant Interfaces.C.unsigned_long := 256;
   ExposureMask        : constant Interfaces.C.unsigned_long := 32768;
   StructureNotifyMask : constant Interfaces.C.unsigned_long := 131072;

   --  Grab results / modes
   GrabSuccess    : constant Interfaces.C.int := 0;
   GrabModeSync   : constant Interfaces.C.int := 0;
   GrabModeAsync  : constant Interfaces.C.int := 1;
   CurrentTime    : constant Interfaces.C.unsigned_long := 0;

   --  KeySyms used by the text dialog
   Key_BackSpace : constant Interfaces.C.unsigned_long := 16#FF08#;
   Key_Return    : constant Interfaces.C.unsigned_long := 16#FF0D#;
   Key_Escape    : constant Interfaces.C.unsigned_long := 16#FF1B#;
   Key_Left      : constant Interfaces.C.unsigned_long := 16#FF51#;
   Key_Up        : constant Interfaces.C.unsigned_long := 16#FF52#;
   Key_Right     : constant Interfaces.C.unsigned_long := 16#FF53#;
   Key_Down      : constant Interfaces.C.unsigned_long := 16#FF54#;
   Key_Home      : constant Interfaces.C.unsigned_long := 16#FF50#;
   Key_End       : constant Interfaces.C.unsigned_long := 16#FF57#;
   Key_Delete    : constant Interfaces.C.unsigned_long := 16#FFFF#;

   --  Attribute bitmask values for XChangeWindowAttributes
   CWOverrideRedirect : constant Interfaces.C.unsigned_long := 512;
   CWBackPixel        : constant Interfaces.C.unsigned_long := 2;
   CWBorderPixel      : constant Interfaces.C.unsigned_long := 4;

   --  XSetWindowAttributes — C layout must match Xlib exactly.
   type XSetWindowAttributes is record
      Background_Pixmap    : Interfaces.C.unsigned_long;
      Background_Pixel     : Interfaces.C.unsigned_long;
      Border_Pixmap        : Interfaces.C.unsigned_long;
      Border_Pixel         : Interfaces.C.unsigned_long;
      Bit_Gravity          : Interfaces.C.int;
      Win_Gravity          : Interfaces.C.int;
      Backing_Store        : Interfaces.C.int;
      Backing_Planes       : Interfaces.C.unsigned_long;
      Backing_Pixel        : Interfaces.C.unsigned_long;
      Save_Under           : Interfaces.C.int;
      Event_Mask           : Interfaces.C.long;
      Do_Not_Propagate     : Interfaces.C.long;
      Override_Redirect    : Interfaces.C.int;
      Colormap             : Interfaces.C.unsigned_long;
      Cursor               : Interfaces.C.unsigned_long;
   end record;
   pragma Convention (C, XSetWindowAttributes);

   --  XPoint for XDrawPoints
   type XPoint is record
      X : Interfaces.C.short;
      Y : Interfaces.C.short;
   end record;
   pragma Convention (C, XPoint);

   type XPoint_Array is array (Natural range <>) of XPoint;
   pragma Convention (C, XPoint_Array);

   --------------------------------------------------------------------------
   --  Imports
   --------------------------------------------------------------------------

   function XOpenDisplay (Display_Name : Interfaces.C.Strings.chars_ptr)
     return Display_Ptr
     with Import, Convention => C, External_Name => "XOpenDisplay";

   function XDefaultScreen (Display : Display_Ptr) return int
     with Import, Convention => C, External_Name => "XDefaultScreen";

   function XRootWindow (Display : Display_Ptr; Screen_Number : int) return Window
     with Import, Convention => C, External_Name => "XRootWindow";

   function XCreateSimpleWindow
     (Display       : Display_Ptr;
      Parent        : Window;
      X, Y          : Interfaces.C.int;
      Width, Height : Interfaces.C.unsigned;
      Border_Width  : Interfaces.C.unsigned;
      Border        : Interfaces.C.unsigned_long;
      Background    : Interfaces.C.unsigned_long)
     return Window
     with Import, Convention => C, External_Name => "XCreateSimpleWindow";

   procedure XSelectInput
     (Display : Display_Ptr;
      W       : Window;
      Mask    : Interfaces.C.unsigned_long)
     with Import, Convention => C, External_Name => "XSelectInput";

   procedure XChangeWindowAttributes
     (Display    : Display_Ptr;
      W          : Window;
      Value_Mask : Interfaces.C.unsigned_long;
      Attributes : access XSetWindowAttributes)
     with Import, Convention => C, External_Name => "XChangeWindowAttributes";

   procedure XMapWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XMapWindow";

   procedure XUnmapWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XUnmapWindow";

   procedure XDestroyWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XDestroyWindow";

   procedure XMoveWindow
     (Display : Display_Ptr;
      W       : Window;
      X, Y    : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XMoveWindow";

   procedure XRaiseWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XRaiseWindow";

   procedure XLowerWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XLowerWindow";

   procedure XNextEvent
     (Display : Display_Ptr;
      Event   : out XEvent)
     with Import, Convention => C, External_Name => "XNextEvent";

   function XPending
     (Display : Display_Ptr)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XPending";

   procedure XFlush
     (Display : Display_Ptr)
     with Import, Convention => C, External_Name => "XFlush";

   procedure XSync
     (Display : Display_Ptr;
      Discard : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XSync";

   procedure XDrawString
     (Display : Display_Ptr;
      D       : Drawable;
      G       : GC;
      X, Y    : Interfaces.C.int;
      String  : Interfaces.C.char_array;
      Length  : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XDrawString";

   procedure XDrawRectangle
     (Display       : Display_Ptr;
      D             : Drawable;
      G             : GC;
      X, Y          : Interfaces.C.int;
      Width, Height : Interfaces.C.unsigned)
     with Import, Convention => C, External_Name => "XDrawRectangle";

   procedure XDrawPoints
     (Display : Display_Ptr;
      D       : Drawable;
      G       : GC;
      Points  : access XPoint_Array;
      Npoints : Interfaces.C.int;
      Mode    : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XDrawPoints";

   procedure XFillRectangle
     (Display       : Display_Ptr;
      D             : Drawable;
      G             : GC;
      X, Y          : Interfaces.C.int;
      Width, Height : Interfaces.C.unsigned)
     with Import, Convention => C, External_Name => "XFillRectangle";

   procedure XCopyArea
     (Display   : Display_Ptr;
      Src, Dest : Drawable;
      G         : GC;
      Src_X, Src_Y : Interfaces.C.int;
      Width, Height : Interfaces.C.unsigned;
      Dest_X, Dest_Y : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XCopyArea";

   function XCreatePixmap
     (Display : Display_Ptr;
      D       : Drawable;
      Width, Height : Interfaces.C.unsigned;
      Depth   : Interfaces.C.unsigned)
     return Window
     with Import, Convention => C, External_Name => "XCreatePixmap";

   procedure XFreePixmap
     (Display : Display_Ptr;
      P       : Window)
     with Import, Convention => C, External_Name => "XFreePixmap";

   function XDefaultGC
     (Display : Display_Ptr;
      Screen_Number : Interfaces.C.int)
     return GC
     with Import, Convention => C, External_Name => "XDefaultGC";

   function XDefaultDepth
     (Display : Display_Ptr;
      Screen_Number : Interfaces.C.int)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XDefaultDepth";

   procedure XClearWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XClearWindow";

   procedure XSetForeground
     (Display : Display_Ptr;
      G       : GC;
      Pixel   : Interfaces.C.unsigned_long)
     with Import, Convention => C, External_Name => "XSetForeground";

   procedure XStoreName
     (Display      : Display_Ptr;
      W            : Window;
      Window_Name  : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "XStoreName";

   function XGetWindowAttributes
     (Display       : Display_Ptr;
      W             : Window;
      Attributes    : access XWindowAttributes)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XGetWindowAttributes";

   function XGrabPointer
     (Display       : Display_Ptr;
      Grab_Window   : Window;
      Owner_Events  : Interfaces.C.int;
      Event_Mask    : Interfaces.C.unsigned;
      Pointer_Mode  : Interfaces.C.int;
      Keyboard_Mode : Interfaces.C.int;
      Confine_To    : Window;
      Cursor_V      : Interfaces.C.unsigned_long;
      Time_V        : Interfaces.C.unsigned_long)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XGrabPointer";

   procedure XUngrabPointer
     (Display : Display_Ptr;
      Time_V  : Interfaces.C.unsigned_long)
     with Import, Convention => C, External_Name => "XUngrabPointer";

   function XGrabKeyboard
     (Display       : Display_Ptr;
      Grab_Window   : Window;
      Owner_Events  : Interfaces.C.int;
      Pointer_Mode  : Interfaces.C.int;
      Keyboard_Mode : Interfaces.C.int;
      Time_V        : Interfaces.C.unsigned_long)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XGrabKeyboard";

   procedure XUngrabKeyboard
     (Display : Display_Ptr;
      Time_V  : Interfaces.C.unsigned_long)
     with Import, Convention => C, External_Name => "XUngrabKeyboard";

   function XLookupString
     (Event        : access XKeyEvent;
      Buffer       : out Interfaces.C.char_array;
      Buffer_Size  : Interfaces.C.int;
      Keysym       : access Interfaces.C.unsigned_long;
      Compose      : System.Address)
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XLookupString";

   --  libc
   function System_Call (Command : char_array) return int
     with Import, Convention => C, External_Name => "system";

   type Timespec is record
      Tv_Sec  : Interfaces.C.long;
      Tv_Nsec : Interfaces.C.long;
   end record
     with Convention => C_Pass_By_Copy;

   function NanoSleep (Req, Remaining : access Timespec) return int
     with Import, Convention => C, External_Name => "nanosleep";

   function Clock_Gettime (Clock_Id : int; Ts : access Timespec) return int
     with Import, Convention => C, External_Name => "clock_gettime";

end X11;
