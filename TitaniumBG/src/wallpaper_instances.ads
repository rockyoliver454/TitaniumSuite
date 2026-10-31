with Plasma;
with Snowy_Village;
with Jungle_River;
with Desert_Mountain;

package Wallpaper_Instances is
   -- Moving these here puts them in static memory (data segment) 
   -- instead of the stack, preventing STORAGE_ERROR.
   Plasma_Inst : aliased Plasma.Plasma_Wallpaper;
   Snow_Inst   : aliased Snowy_Village.Snowy_Village_Wallpaper;
   Jungle_Inst : aliased Jungle_River.Jungle_River_Wallpaper;
   Desert_Inst : aliased Desert_Mountain.Desert_Mountain_Wallpaper;
end Wallpaper_Instances;
