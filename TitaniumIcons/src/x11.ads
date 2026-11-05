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

   --  Events we care about
   Expose      : constant Interfaces.C.int := 12;
   ButtonPress : constant Interfaces.C.int := 4;

   ExposureMask    : constant Interfaces.C.unsigned_long := 32768;
   ButtonPressMask : constant Interfaces.C.unsigned_long := 4;

   --  Attribute bitmask values for XChangeWindowAttributes
   CWOverrideRedirect : constant Interfaces.C.unsigned_long := 512;
   CWBackPixel        : constant Interfaces.C.unsigned_long := 2;

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

   procedure XDrawString
     (Display : Display_Ptr;
      D       : Drawable;
      G       : GC;
      X, Y    : Interfaces.C.int;
      String  : Interfaces.C.char_array;
      Length  : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XDrawString";

   procedure XFillRectangle
     (Display       : Display_Ptr;
      D             : Drawable;
      G             : GC;
      X, Y          : Interfaces.C.int;
      Width, Height : Interfaces.C.unsigned)
     with Import, Convention => C, External_Name => "XFillRectangle";

   function XDefaultGC
     (Display : Display_Ptr;
      Screen_Number : Interfaces.C.int)
     return GC
     with Import, Convention => C, External_Name => "XDefaultGC";

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

   --  libc
   function System_Call (Command : char_array) return int
     with Import, Convention => C, External_Name => "system";

end X11;
