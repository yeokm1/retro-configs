
About svgaptch

This tool should patch svga256.drv to make it VESA compliant.
Svga256.drv is a 256 color video driver included in WfW 3.11 with support 
for special graphics chipsets only. 

To install do:

 1. copy svga256.drv in the directory where svgaptch.exe is located 
 2. enter "svgaptch -p". It should display some messages what it has
    done.
 3. copy the patched svga256.drv back to the windows 3.1 system directory.
 4. with setup.exe in windows directory select one of the super vga
    256-color modes.

