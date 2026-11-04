with System;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;

package X11 is
   --  Same thin binding style as the rest of the Titanium Suite.
   pragma Preelaborate;

   subtype Display_Ptr is System.Address;
   subtype Window      is Interfaces.C.unsigned_long;
   subtype Drawable    is Window;
   subtype GC          is System.Address;
   subtype KeySym      is Interfaces.C.unsigned_long;
   subtype Mask        is Interfaces.C.unsigned_long;
   subtype Atom        is Interfaces.C.unsigned_long;
   subtype Time        is Interfaces.C.unsigned_long;
   subtype Cursor      is Interfaces.C.unsigned_long;
   subtype Colormap    is Interfaces.C.unsigned_long;
   subtype Pixmap      is Interfaces.C.unsigned_long;

   --  Events
   type XEvent is record
      Type_Code : Interfaces.C.int;
      Pad       : Interfaces.C.char_array (1 .. 192);
   end record;
   pragma Convention (C, XEvent);

   type XAnyEvent is record
      Type_Code   : Interfaces.C.int;
      Serial      : Interfaces.C.unsigned_long;
      Send_Event  : Interfaces.C.int;
      Display     : Display_Ptr;
      Win         : Window;
   end record;
   pragma Convention (C, XAnyEvent);

   KeyPress      : constant Interfaces.C.int := 2;
   ButtonPress   : constant Interfaces.C.int := 4;
   Expose        : constant Interfaces.C.int := 12;

   --  Event masks
   KeyPressMask    : constant Mask := 16#00000001#;
   ButtonPressMask : constant Mask := 16#00000008#;
   ExposureMask    : constant Mask := 16#00008000#;

   --  XSetWindowAttributes / valuemask bits
   type XSetWindowAttributes is record
      Background_Pixmap : Pixmap;
      Background_Pixel  : Interfaces.C.unsigned_long;
      Border_Pixmap     : Pixmap;
      Border_Pixel      : Interfaces.C.unsigned_long;
      Bit_Gravity       : Interfaces.C.int;
      Win_Gravity       : Interfaces.C.int;
      Backing_Store     : Interfaces.C.int;
      Backing_Planes    : Interfaces.C.unsigned_long;
      Backing_Pixel     : Interfaces.C.unsigned_long;
      Save_Under        : Interfaces.C.int;
      Event_Mask        : Mask;
      Do_Not_Propagate  : Mask;
      Override_Redirect : Interfaces.C.int;
      Colormap          : Interfaces.C.unsigned_long;
      Cursor            : Interfaces.C.unsigned_long;
   end record;
   pragma Convention (C_Pass_By_Copy, XSetWindowAttributes);

   CWBackPixel        : constant Mask := 16#00000002#;
   CWOverrideRedirect : constant Mask := 16#00000200#;

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

   function XDisplayWidth (Display : Display_Ptr; Screen_Number : int) return int
     with Import, Convention => C, External_Name => "XDisplayWidth";

   function XDisplayHeight (Display : Display_Ptr; Screen_Number : int) return int
     with Import, Convention => C, External_Name => "XDisplayHeight";

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

   procedure XChangeWindowAttributes
     (Display    : Display_Ptr;
      W          : Window;
      Valuemask  : Mask;
      Attributes : access XSetWindowAttributes)
     with Import, Convention => C, External_Name => "XChangeWindowAttributes";

   procedure XSelectInput
     (Display : Display_Ptr;
      W       : Window;
      Mask    : Interfaces.C.unsigned_long)
     with Import, Convention => C, External_Name => "XSelectInput";

   procedure XMapWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XMapWindow";

   procedure XRaiseWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XRaiseWindow";

   Revert_To_Parent : constant Interfaces.C.int := 2;

   procedure XSetInputFocus
     (Display   : Display_Ptr;
      W         : Window;
      Revert_To : Interfaces.C.int;
      Time      : Interfaces.C.unsigned_long)
     with Import, Convention => C, External_Name => "XSetInputFocus";

   procedure XStoreName
     (Display      : Display_Ptr;
      W            : Window;
      Window_Name  : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "XStoreName";

   procedure XNextEvent
     (Display : Display_Ptr;
      Event   : out XEvent)
     with Import, Convention => C, External_Name => "XNextEvent";

   procedure XDrawString
     (Display : Display_Ptr;
      D       : Drawable;
      G       : GC;
      X, Y    : Interfaces.C.int;
      String  : Interfaces.C.char_array;
      Length  : Interfaces.C.int)
     with Import, Convention => C, External_Name => "XDrawString";

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

   procedure XFillRectangle
     (Display : Display_Ptr;
      D       : Drawable;
      G       : GC;
      X, Y    : Interfaces.C.int;
      Width, Height : Interfaces.C.unsigned)
     with Import, Convention => C, External_Name => "XFillRectangle";

   procedure XFlush
     (Display : Display_Ptr)
     with Import, Convention => C, External_Name => "XFlush";

   procedure XDestroyWindow
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XDestroyWindow";

   procedure XCloseDisplay
     (Display : Display_Ptr)
     with Import, Convention => C, External_Name => "XCloseDisplay";

end X11;
