package Icon_Images is

   --  Icon image loader.  Two user-friendly formats, both trivially
   --  parseable with no external libs:
   --    * PPM "P6"  (binary, maxval 255) — GIMP exports these
   --    * BMP 24-bit uncompressed (BI_RGB), bottom-up or top-down
   --  Output is always a Tile x Tile 0xRRGGBB buffer, nearest-
   --  neighbour scaled to fit the icon's glyph square.

   Tile : constant := 28;
   type Pixel_Buffer is array (0 .. Tile * Tile - 1) of Natural;

   --  True on success; Buf holds Tile*Tile packed 0xRRGGBB pixels.
   --  Any parse problem returns False and Buf is untouched beyond
   --  what was written before the failure.
   function Load_Tile
     (Path : String;
      Buf  : out Pixel_Buffer) return Boolean;

end Icon_Images;
