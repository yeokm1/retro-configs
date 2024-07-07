@echo off
cls
echo This will create three Xircom disks for installation
echo If you want to proceed, press any key.  Otherwise, press ctrl-c
pause

echo Please insert a blank formatted disk into drive A
echo Label this disk: Windows 3.x and DOS

pause
xcopy .\disk1\*.* a:\*.* /s

echo Please remove the disk from drive A
echo Please insert another blank formatted disk into drive A
echo Label this disk: Windows 95, 98 and NT Drivers

pause
xcopy .\disk2\*.* a:\*.* /s

echo Please remove the disk from drive A
echo Please insert another blank formatted disk into drive A
echo Label this disk: Windows 95, 98 and NT Applications

pause
xcopy .\disk3\*.* a:\*.* /s

:end
 