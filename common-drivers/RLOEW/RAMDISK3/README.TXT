        PRELIMINARY MANUAL FOR HIMEMEX NON-XMS RAMDISKS VERSION 2.0



This Package contains the 32-Bit and/or 64-Bit versions of the HIMEMEX
NON-XMS RAMDISK as well as the HIMEMEX.SYS Memory Manager.

Both versions can be run simultaneously.
Multiple instances of either RAMDISK can be run simultaneously.



HIMEMEX:

HIMEMEX.SYS is a RAM Memory Manager that provides basic Memory Allocation
functions for 32-Bit and 64-Bit RAM Memory as well as providing a 64-Bit
Virtual/Physical RAM copy function for use by RAMDISKs and other Applications.
HIMEMEX.SYS is an overlay over but is not a replacement for HIMEM.SYS. 
HIMEM.SYS is still needed for Windows and Programs not specifically written
for HIMEMEX.


RAMDSK32.COM:

RAMDSK32.COM is a 32-Bit RAMDISK which uses HIMEMEX.SYS to Allocate and
Transfer 32-Bit RAM. XMS supported RAM is not used so that Windows will not
attempt to manage the RAMDISK.



RAMDSK64.COM:

RAMDSK64.COM is a 64-Bit RAMDISK which uses HIMEMEX.SYS to Allocate and
Transfer 64-Bit RAM. This RAM is not accessible to Windows or 32-Bit Programs.



INSTALLATION:

Place the HIMEMEX.SYS file in a known location.
Add a line to your CONFIG.SYS File to install the HIMEMEX Driver.
This line should be immediately before or after the line Installing HIMEM.SYS
and before EMM386.
Do not use DEVICEHIGH.

The Installation Syntax is:

DEVICE=<path>HIMEMEX [/I | /S] [/E:# | /E] [/A:# | /L:#] [/V]

        /I=INT30 Method  /S=SYSENTER Method  Default=PROTHOOK Method
        /E:#=EMM386 Virtualization Port  /E=EMM386 ON/OFF
        /A:#=Preallocate 32-Bit Memory (KB)
        /L:#=Preallocate 32-Bit Memory Above Address (KB)
        /V=Verbose
        # = Port or Memory (KB) in Hexadecimal

Add "LastDrive=Z" as the first line in your CONFIG.SYS File to make room
for your RAM Disks.

If you have more than 2.5GB of RAM, add the option "NUMHANDLES=64" to the
HIMEM.SYS line in your CONFIG.SYS File.


Place the RAMDSKxx.COM file(s) in a known location.
Add line(s) to your AUTOEXEC.BAT File to run the RAMDISK Program.
Do not use LOADHIGH or LH.

The command Syntax is:

RAMDSKxx Size
or
RAMDSKxx X: Size

Size is the size of the RAMDISK in KB.
X: is the Drive letter to be assigned to the RAMDISK.
Default is the first available Drive Letter.
RAMDSK64 will default to all 64-Bit RAM if no Size is Specified.
RAMDSK32 requires a Size to be Specified.

If using the Default PROTHOOK Method, Install the PROTHOOK.VXD as follows:

Place PROTHOOK.VXD in Windows\SYSTEM Directory.
Add the following line to the [386Enh] section of your SYSTEM.INI File:

device=prothook.vxd

Only one instance of the Hook Program is required regardless of the number
of RAMDISKs used.

If you want Windows to recognize a RAMDISK as a RAM DISK rather than a
Hard Drive, add the following line to your AUTOEXEC.BAT file after the
RAMDISK Command(s):

LABEL X: MS-RAMDRIVE

Where X: is the Drive letter assigned to the RAMDISK.

If you intend to use the RAMDISK for Swapping, do not use MS-RAMDRIVE as a
label.

Caution: Disable Hard Drive Spin-Down if using a RAMDISK for Swap, otherwise
         deadlock can occur.


WINDOWS ACCESS METHODS


PROTHOOK (Default)

This method uses a Hook added to the Exception Handler in Windows.
This is currently the default choice.

PROS:

No modifications to DOS.
Compatable with Windows ME.
Hook can be used by both 16-Bit and 32-Bit Programs.
Hook can be integrated into RAM Limitation Patch.
Works with all CPUs.

CONS:

Modifies Windows.
Installation more complex. PROTHOOK.VXD must be installed as well as HIMEMEX.
Separate Hook required for each copy of Windows.
RAM Limitation Patch integrated version slightly reduces size of a system
stack.


SYSENTER

This method uses the SYSENTER command as a Hook to Priviledged Mode.

PROS:

No modifications to Windows.
No modifications to DOS in most cases.
Simpler Installation.
Hook can be used by both 16-Bit and 32-Bit Programs.
One Hook required per CONFIG.SYS File.

CONS:

Not Compatable with Windows ME without using DDO.
Not compatable with old CPUs.
SYSENTER MSRs have to be setup before running EMM386. HIMEMEX must be
installed before EMM386 is installed.


INT30

This method uses the Windows Breakpoint Coded as a Hook to Priviledged Mode.

PROS:

No modifications to Windows.
Simplest Installation.
Works with all CPUs.

CONS:

Hook cannot be used by 32-Bit Programs.
Modifications or Updates to Windows may break the Hook.
Not Compatable with Windows ME unless integrated into RAMDISK.




EMM386 ACCESS METHODS


VIRTUAL I/O PORT (Default PORT=7C80)

This method uses a Virtual I/O Port to access RING 0 while EMM386 is running.
The /E:# Argument can be used to select an alternate I/O Port.
This is currently the default choice except in SYSENTER Mode..

PROS:

EMM386 does not have to be turned off to access the RAMDISK.
RAMDISK Data can be transferred to/from Memory remapped by EMM386.

CONS:

Virtual I/O Port may block an Actual I/O Port. (Port can be changed)
Fewer Virtual I/O Ports may be available for other Programs.


EMM ON/OFF

This method uses the SYSENTER command as a Hook to Priviledged Mode.

PROS:

No I/O Ports are blocked.
All Virtual I/O Ports are be available for other Programs.

CONS:

EMM386 has to be turned off to access the RAMDISK.
RAMDISK Data cannot be transferred to/from Memory remapped by EMM386.


EMM SYSENTER MODE

This method uses the SYSENTER command as a Hook to Priviledged Mode.
This is currently the default choice in SYSENTER Mode.
Use /E or /E:Port to Override.

PROS:

EMM386 does not have to be turned off to access the RAMDISK.
RAMDISK Data can be transferred to/from Memory remapped by EMM386.
No I/O Ports need to be reserved.
One Hook required per CONFIG.SYS File.

CONS:

Not Compatable with Windows ME without using DDO.
Not compatable with old CPUs.
Only available in SYSENTER Mode.
SYSENTER MSRs have to be setup before running EMM386. HIMEMEX must be
installed before EMM386 is installed.



PREALLOCATION

Preallocation reserves 32-Bit RAM for later allocation to RAMDISKs or other
HIMEMEX aware Programs.

If HIMEMEX.SYS is loaded after HIMEM.SYS, it will take the Preallocated RAM
away from the RAM managed by HIMEM.SYS in the same manner as normal
Allocation requests to HIMEMEX.

If HIMEMEX.SYS is loaded before HIMEM.SYS, it will hook Interrupt 15 and
reduce the amount of memory reported by Interrupt 15. Neither HIMEM.SYS nor
Windows will ever see this RAM. This may resolve some Driver issues in
Windows not resolved by using RAMDISKs or MaxPhysPage.

The amount of RAM is specified in KB and is entered in Hexadecimal.

For example: /A:180000 = 1.5GiB

Preallocated RAM will be used before HIMEM RAM for normal Allocations.

Preallocation using the /L: Allocates all 32-Bit RAM above the specified
address. this can be used to set the available RAM to Windows to a specific
amount.

For example: /A:100000 = 1GiB will prevent Windows 9x from crashing if it is
not Patched with the RAM Limitation Patch.



VERBOSE

The VERBOSE option prints out a summary of the settings for the HIMEMEX.SYS
Driver as well as any Preallocated 32-Bit and/or 64-Bit RAM.



ISSUES AND LIMITATIONS:


RAMDSK32 currently only initializes itself as a FAT16 Drive. It will use 64KB
Clusters if over 2GB which may cause some issues with some Programs. It will
not load if less than 2.1MB. RAMDSK64 will switch to FAT32 if larger than 2GB.

Out of bounds accesses to the RAMDISK Driver are not checked.

If HIMEM.SYS is not loaded or has not yet been loaded only Fast A20 (Port 92)
will be set by HIMEMEX. Keyboard A20 Control is not used.

A20 is not checked or set after initialization.

If HIMEM.SYS is not loaded, only 64-Bit RAM and Preallocated 32-Bit RAM is
available.

HIMEMEX only supports Memory Allocation. Memory cannot be freed.
