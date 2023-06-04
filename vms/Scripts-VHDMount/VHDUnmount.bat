@ECHO OFF
TITLE Unmount VHD
ECHO Unmount VHD
ECHO Written by: Jason Faulkner
ECHO SysadminGeek.com
ECHO.
ECHO.

SETLOCAL

SET DiskPartScript="%TEMP%\DiskpartScript.txt"

ECHO SELECT VDISK FILE="%~1" > %DiskPartScript%
ECHO DETACH VDISK >> %DiskPartScript%

DiskPart /s %DiskPartScript%

ENDLOCAL
