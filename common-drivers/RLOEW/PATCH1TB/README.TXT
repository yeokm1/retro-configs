              PRELIMINARY MANUAL FOR 1TB PATCH VERSION 1.0

The PATCH1TB.EXE file Patches the FileSystem Driver VFAT.VXD to correctly
handle Partitions larger than 1TiB with amy Alignment.

It corrects a bug in the handling of Disk I/O requests where signed
arithmetic was used when it should not have been. The bug appears when
accessing Directories that are located above 1TiB from the start of the
Partition.

NOTE: This file will not eliminate the 137GB Hard Drive limit for the
      ESDI_506.PDR Hard Disk Driver. You will need a Driver Patch such as my
      High Capacity Disk Patch.



INSTALLATION:


NEW WINDOWS INSTALLATION

1. Install Windows until the first Reboot,
2. Boot to DOS using a Floppy Disk.
3. Run PATCH1TB.
5. Reboot
6. Continue Windows Installation.


EXISTING WINDOWS SYSTEM

1. Boot Windows in Safe Mode or DOS from a Floppy.
2. Run PATCH1TB.
3. Reboot.
