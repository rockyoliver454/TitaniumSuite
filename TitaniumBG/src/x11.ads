with Interfaces.C; use Interfaces.C;
with System;

package X11 is
   type Display_Ptr is new System.Address;
   type Window      is new Unsigned_long;
   type GC          is new System.Address;
   type Visual_Ptr  is new System.Address;
   
   type XWindowAttributes is record
      X, Y, Width, Height : int;
      Border_Width        : int;
      Depth               : int;
      Visual              : Visual_Ptr;
      Root                : Window;
      Class               : int;
      Bit_Gravity         : int;
      Win_Gravity         : int;
   end record
     with Convention => C_Pass_By_Copy;

   function XOpenDisplay (Display_Name : char_array) return Display_Ptr
     with Import, Convention => C, External_Name => "XOpenDisplay";

   function XDefaultRootWindow (Display : Display_Ptr) return Window
     with Import, Convention => C, External_Name => "XDefaultRootWindow";
     
   function XDefaultGC (Display : Display_Ptr; Screen_Num : int) return GC
     with Import, Convention => C, External_Name => "XDefaultGC";
     
   function XDefaultScreen (Display : Display_Ptr) return int
     with Import, Convention => C, External_Name => "XDefaultScreen";
     
   function XDefaultDepth (Display : Display_Ptr; Screen_Num : int) return int
     with Import, Convention => C, External_Name => "XDefaultDepth";

   function XGetWindowAttributes
     (Display : Display_Ptr;
      W       : Window;
      Attrs   : access XWindowAttributes) return int
     with Import, Convention => C, External_Name => "XGetWindowAttributes";

   function XCreateImage
     (Display : Display_Ptr;
      Visual  : Visual_Ptr;
      Depth   : unsigned;
      Format  : int;
      Offset  : int;
      Data    : System.Address;
      Width   : unsigned;
      Height  : unsigned;
      Bitmap_Pad : int;
      Bytes_Per_Line : int) return System.Address
     with Import, Convention => C, External_Name => "XCreateImage";

   function XPutImage
     (Display : Display_Ptr;
      Drawable : Window;
      Context : GC;
      Image   : System.Address;
      Src_X, Src_Y : int;
      Dest_X, Dest_Y : int;
      Width, Height : unsigned) return int
     with Import, Convention => C, External_Name => "XPutImage";

end X11;
