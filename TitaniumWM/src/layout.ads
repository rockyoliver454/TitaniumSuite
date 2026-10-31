package Layout is
   pragma SPARK_Mode (On);

   -- Recalculates positions for all active clients and moves them.
   -- This is the "Pure" logic entry point.
   procedure Tile_Windows (Display_Width, Display_Height : Integer);

end Layout;
