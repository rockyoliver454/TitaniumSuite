-- src/titanium_bg-memory.ads
with Titanium_BG; use Titanium_BG;

package Titanium_BG.Memory is
   -- This moves the massive array off the stack and into static memory (BSS)
   Buffer : aliased Pixel_Array;
end Titanium_BG.Memory;
