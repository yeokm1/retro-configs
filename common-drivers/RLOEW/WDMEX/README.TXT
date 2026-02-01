                WDMEX Windows Driver Model API Extender

                             Version 0.3

                              01/02/2017

                       Copyright (C) 2012-2017
                          By Rudolph R. Loew

WDMEX

Choose the Standard or Forced Version of WDMEX to Install.
The Forced Version installs all available Functions even if they already
exist. The Standard Version only forces 3 Functions.

Install the chosen WDMEX.VXD into the Windows\System Folder.
Add Device=WDMEX.VXD to SYSTEM.INI File under [386Enh] Header
Reboot


DISPPE32

Disppe32 displays PE File Information. The default is to show the Header
and Module Information. Numbers in Parenthesis are the File Offsets.
Options display the Import and Export Tables. The Options are as follows:

-H  Hide Header. Does not display Header Info
-I  Import List. Displays Import Entries
-E  Export List. Displays Export Entries
-A  All.         Displays Ordinal Only Exports, use with -E
-N  Name Only    Display Import or Export Names Only
-D  DLL          Display DLL Address for API Imports. -------- = Not Found
-P  PELDR        Display PELDR Address for WDM Imports. -------- = Not Found
-M  Module       Display Module  Address for WDM Imports. -------- = Not Found
-B  BadImport    Displays only failed Imports
-V  Version      Displays Version Data
-S  Stub         Tests and Displays Stubbed Imports

If a second address appears in the PELDR listing, this indicates that the
address has been overwritten. The first one is the address stored in the
current Module Table. The Second is one that is being used by the PE Loader.

The Stub check looks for the Stub Pattern used in many System DLLs such as
KERNEL32.DLL. A letter "S" and the Hex Code, used by the Stub Routine to
handle the Return Code and Stack adjustment, is shown. The Import is
displayed even if the -B Option is used.


GETPELDR

Getpeldr displays the PELDR WDM Functions currently active. The Default is to
show all Functions. No Modules are loaded, so Functions may be available via
dynamic loading that are not shown.

The Options are as follows:

Module  Display all entries for all instances of the Module Name
Name    Display all entries for all instances of the Function Name
-       Display all Module instances with number of Function contained within.


NOTE:

Some Hypervisors do not support the SGDT instruction in Ring 3 Code. This
will prevent GETPELDR and DISPPE32 -P from running. Alternative versions of
these programs are available for these Hypervisors.
