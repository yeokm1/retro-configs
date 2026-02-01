        Preliminary User's Manual for DLLHOOK System API Hooker


The DLLHOOK System API Hooker Patches the Entrypoint Address Resolver used
by the Executable Program Loader and GetProcAddress to locate API Entry
Points. This allows multiple API's to be Patched in any number of Modules
using a single set of Patches.

Since the actual APIs are not Patched, DLLHOOK must be running before an
Application is started in order to redirect the APIs. To Patch Windows
Explorer, you will need to Start DLLHOOK from the RUNSERVICE Key in the
Registry.



CONFIGURATION:

DLLHOOK is configured by creating a DLLHOOK.INI File containing the
redirection information. This file must be placed in the same Folder as
the DLLHOOK Executable that will use it.

The DLLHOOK.INI File is a Text File that can be created by any Editor that
does not add formatting information.

A Redirection Line consists of up to 4 items. Spaces are not allowed in any
item. The format is as follows:

LIBRARY NAME NEWLIBRARY [NEWNAME]

LIBRARY is the name of the DLL containing the Entry Point to be redirected.

NAME is the name of the Entry Point.

NEWLIBRARY is the name of the DLL  containing the Entry Point to be
 redirected to.

NEWNAME is the optional name of the Entry Point to be redirected to.
 If none is given, the original Name is used.


The following special characters can be used for Wildcards etc.

A "-" (Minus Character) can be used as a Wildcard for the LIBRARY or NAME
 entry but not both.

A "-" (Minus Character) can be used in the NEWLIBRARY or NEWNAME entry, but
 not both, to retain the same value as the LIBRARY or NAME entry.

A "+" (Plus Character) can be used as a Wildcard for the NAME entry, but will
 only apply to Entry Points that are Undefined.

A "*" (Star Character) can be used to repeat the corresponding Entry from the
 previous Line.

If you are redirecting several Entry Points from one DLL to another, you
would place the full specification on the first line, then use the "*"
characters as the LIBRARY and NEWLIBRARY entries in the later lines.

You can add one or more blocks of Redirection Lines contained in other Files
by placing an "@" (at character) followed by a File Name on a Single Line.

Ex.  @redirect.ini

Note: The DLLHOOK.INI and any Included Files are scanned when DLLHOOK is
started. Any changes will not take affect until DLLHOK is stopped and
restarted.

Placing "/S" alone on a Line will cause DLLHOOK to put up a Message Box if
an Unknown Entry Point is processed.

Placing "/L" alone on a Line will cause DLLHOOK to Log Unknown Entry Points
 to C:\DLLHOOK.LOG.

Any line starting with a ";" (Semicolon Character) is treated as a Comment
 and is ignored.

A summary of this Format is shown in the Sample DLLHOOK.INI File included.



REDIRECTION BYPASS

User supplied DLLs containing Code redirected to by DLLHOOK often will need
to access the original APIs for support of for pass-thrus. Two bypass options
are built into DLLHOOK to provide this access. Prepending "DLLHOOK_" to an
Entry Name will cause DLLHOOK to strip the "DLLHOOK_" off and return the
Entry Point Address with redirection. Prepending "dllhook_" will do the same
but will also remove any C++ style decoration ("@" and any following
characters). This supports DLLs written in C++. Names containing "@"
Characters cannot use this bypass. Chaining (see below) should not be used
with Redirection Bypasses on a given Entry Point as the Bypass is only to
the previous instance.



INSTALLATION:

Place the DLLHOOK.EXE and DLLHOOK.INI Files in your Windows Folder.

If you want to be able to redirect Windows Explorer APIs, run the
DLLHOOK.REG Registry Script by Clicking it's ICON or running REGEDIT as
follows:

REGEDIT DLLHOOK.REG

Then Reboot your Computer.

If you do not need to redirect APIs for Windows Explorer or other startup
Programs, you can add an Icon for DLLHOOK to your Startup Folder.

Otherwise you must run DLLHOOK.EXE manually before running Programs you want
DLLHOOK to redirect.



UNINSTALL:

Remove any Startup Commands that start DLLHOOK.

If you installed the Registry Entry to Start DLLHOOK, run the DLLHOOKU.REG
Registry Script by Clicking it's ICON or running REGEDIT as follows:

REGEDIT DLLHOOKU.REG

Then Reboot your Computer.

Remove the Icon for DLLHOOK from your Startup Folder if you added one.

Delete the DLLHOOK.EXE and DLLHOOK.INI Files from your Windows Folder.



ACTIVATION:

If you have Installed the Registry Entry to Start DLLHOOK, it will be active
after every Boot. Otherwise you will need to Start it by Running DLLHOOK.
Most Programs that are Started before DLLHOOK is Started will be unaffected.
Only Programs that use GetProcAddress to get System File API Addresses later
will be affected.



DEACTIVATION

If you have Installed the Registry Entry to Start DLLHOOK, it will be active
after every Boot. To Deactivate DLLHOOK, shutdown DLLHOOK by running:

DLLHOOK /R

Most Programs that were Started while DLLHOOK was Active will still use the
redirected APIs. Only Programs that use GetProcAddress to get System File
API Addresses later will start using the original API.



CHAINING:

You can run additional instances of DLLHOOK with separate DLLHOOK.INI Files
that can overlay additional redirections on top of a currently running
DLLHOOK.

To do so, you must place each DLLHOOK.INI in a separate Folder along with a
copy of DLLHOOK.EXE. You must explicitly execute these copies, not a common
copy. Two instances of the same DLLHOOK copy will not run.

These additional instances can be deactivated individually but you must
explicitily choose the particular copy of DLLHOOK.EXE to deactivate.

DLLHOOK can be used with KernelEx 4.52 only. Redirects in DLLHOOK will
override any redirects in KernelEx but cannot be mapped to the original
functions that KernelEx redirected.



LIMITATIONS:

The Show and Log Options mzy cause the System to Hang if certain DLLs are
Redirected.

Shutdown problems may occur if you use the Power Button, or a forced
ExitWindows Call depending upon which APIs are redirected.

XCOPY cannot be used while DLLHOOK is Active if certain File System APIs are
redirected.
