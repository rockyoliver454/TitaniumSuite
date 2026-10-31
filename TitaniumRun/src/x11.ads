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
   
   --  Events (We only care about KeyPress for this tool)
   type XEvent is record
      Type_Code : Interfaces.C.int;
      Pad       : Interfaces.C.char_array (1 .. 192); 
   end record;
   pragma Convention (C, XEvent);

   --  Constants
   KeyPress      : constant Interfaces.C.int := 2;
   Expose        : constant Interfaces.C.int := 12;
   
   --  Pixel values and Masks must be unsigned_long to allow logical "or"
   Black_Pixel   : constant Interfaces.C.unsigned_long := 0;
   White_Pixel   : constant Interfaces.C.unsigned_long := 16777215;
   
   KeyPressMask  : constant Interfaces.C.unsigned_long := 1;
   ExposureMask  : constant Interfaces.C.unsigned_long := 32768;

   --  Keysyms
   XK_BackSpace : constant Interfaces.C.unsigned_long := 65288; -- 0xFF08
   XK_Return    : constant Interfaces.C.unsigned_long := 65293; -- 0xFF0D
   XK_Escape    : constant Interfaces.C.unsigned_long := 65307; -- 0xFF1B

   --------------------------------------------------------------------------
   --  Imports
   --------------------------------------------------------------------------

   function XOpenDisplay (Display_Name : Interfaces.C.Strings.chars_ptr) 
     return Display_Ptr
     with Import, Convention => C, External_Name => "XOpenDisplay";

   --  DefaultRootWindow is actually a macro in C. We must compose it manually.
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

   procedure XMapWindow 
     (Display : Display_Ptr;
      W       : Window)
     with Import, Convention => C, External_Name => "XMapWindow";

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

   function XGrabKeyboard 
     (Display      : Display_Ptr;
      Grab_Window  : Window;
      Owner_Events : Interfaces.C.int;
      Pointer_Mode : Interfaces.C.int;
      Key_Mode     : Interfaces.C.int;
      Time         : Interfaces.C.unsigned_long) 
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XGrabKeyboard";

   function XLookupString 
     (Event_Struct  : System.Address;
      Buffer_Return : in out Interfaces.C.char_array;
      Bytes_Buffer  : Interfaces.C.int;
      Keysym_Return : access Interfaces.C.unsigned_long;
      Status_Return : System.Address) 
     return Interfaces.C.int
     with Import, Convention => C, External_Name => "XLookupString";

end X11;
