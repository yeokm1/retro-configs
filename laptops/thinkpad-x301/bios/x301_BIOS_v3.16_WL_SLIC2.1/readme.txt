ThinkPad x301 v3.16 BIOS with Whitelist removed and SLIC 2.1 tables added

MD5 (01BD000.ROM) = c2edad686446e8c668dc57833bd32aaf

Flash from Windows with Included Flash Utility. 
Flash original version first (either from official Lenovo source or the bios_original folder)
Reboot and then flash the modified bios in the bios_mod folder.

Upon opening WinPhlash.exe (32 or 64 bit), 
click "Advanced Settings" then check and uncheck the boxes so it looks like this:

("Flags" Tab):
[ ] Verify BIOS part number
[ ] Flash only if BIOS version is different
[ ] Flash only if BIOS version is newer
[ ] Verify BIOS image size
[ ] Verify BIOS checksum
[ ] Zero block before erasing
[x] Verify block after programming
[x] Disable Axx swaping automatic detection (if present)
[ ] Clear CMOS Checksum

("DMI" tab)
"Update": Select "Update the BIOS and not DMI" 


