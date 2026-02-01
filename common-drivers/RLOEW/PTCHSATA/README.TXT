                  MANUAL FOR SATA PATCH VERSION 1.1a


The SATA Patch consists of two parts:

The PTCHSATA.EXE file Patches the Hard Disk Driver ESDI_506.PDR to properly
support shared Interrupts and to disable Virtual Mode I/O not supported by
many SATA Controllers.

The SATA.INF file is a modified, stripped down version of the Microsoft
MSHDC.INF file.

It provides the necessary support for Motherboard Chipset SATA Controllers
that would ordinarily be confused with standard PATA Controllers.

SATA Controllers operate in NATIVE Mode when PATA Controllers are also
present. This requires a different configuration to be passed to the
ESDI_506.PDR Driver.

NOTE: This file will not eliminate the 137GB Hard Drive limit for either the
      PATA or SATA Controllers. You will need a Driver Patch such as my
      High Capacity Disk Patch.

      This file has not been tested with, and may not work with, the Intel
      Application Accelerator, VIA MPD or SIS Drivers.

CAUTION: This Patch may corrupt old CHS only Drives (8GB or less).



INSTALLATION:


NEW WINDOWS INSTALLATION

1. Install Windows until the first Reboot,
2. Boot to DOS using a Floppy Disk.
3. Run PTCHSATA.
4. Copy the SATA.INF file to the C:\WINDOWS\INF Folder if using the Default
   setting or the INF Folder in the Directory you Installed Windows into.
5. Reboot
6. Continue Windows Installation.


EXISTING WINDOWS SYSTEM

1. Boot Windows in Safe Mode.
2. Run PTCHSATA.
3. Copy the SATA.INF file to the C:\WINDOWS\INF Folder if using the Default
   Windows location or the INF Folder in the Directory you Installed Windows
   into.
4. Go to Device Manager.
5. Expand "Hard disk controllers"
6. Select and Delete all IDE Controllers.
7. Reboot
