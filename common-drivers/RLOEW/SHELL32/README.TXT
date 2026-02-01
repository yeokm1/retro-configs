                        R. Loew SHELL32 EXTENDER

                             Version 1.0

                              05/05/2015

                          Copyright (C) 2015
                          By Rudolph R. Loew


The R. Loew SHELL32 Extender adds three missing functions to the Windows 98SE
SHELL32 that are often used by software written for later operating systems.

The added functions are:

SHGetFolderPathA
SHGetFolderPathW
SHGetFolderLocation

The first two are forwarded to SHFOLDER.DLL and the third is translated to
use the SHGetSpecialFolderLocation API Entry.

The package consists of the following files:

SHELL32.DLL     SHELL32 API Redirector with Icons and translation code.
SHELLXX.DLL     Modified original SHELL32.DLL for all other API Functions.
SHFOLDER.DLL    Unmodified Last Update to SHFOLDER.DLL.
SHFOLDXX.DLL    Modified Last Update to SHFOLDER.DLL for use by Redirector.
README.TXT      These instructions.

Installation:

Boot your system into DOS not Windows.
Go to your WINDOWS\SYSTEM Folder.
Rename SHELL32.DLL to SHELL32.OLD
Rename SHFOLDER.DLL to SHFOLDER.OLD if it exists.
Copy the four DLL Files from this Package into this Folder.
Reboot.

UnInstall:

Boot your system into DOS not Windows.
Go to your WINDOWS\SYSTEM Folder.
Delete SHELL32.DLL, SHELLXX.DLL, SHFOLDER.DLL and SHFOLDXX.DLL
Rename SHELL32.OLD to SHELL32.DLL
Rename SHFOLDER.OLD to SHFOLDER.DLL if it exists.
Reboot.
