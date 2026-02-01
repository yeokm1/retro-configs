            R. Loew Electronics Large File Emulator for XP

                          Version 1.0

                           03/18/2018

                     Copyright (C) 2011-2018
                       By Rudolph R. Loew


This Package intercepts User Mode FileSystem API requests so that a set of
smaller Files will appear as a single large File. This allows Programs to
Create Files that are larger than 4GiB on FAT32 Partitions or on remote
shares hosted on Windows 98, 98SE or, ME. These Files can then be Read or
Modified by other Programs. Downloading and Playing or Archiving Blu-Ray
Videos are a example of what can be done with this Package.

This package is intended to be used with the Windows 98/98SE/ME Version of
the FILE64 Package.



REQUIREMENTS

Windows XP.
Windows 98/98SE/ME Large File Emulator.



INSTALLATION

1. Place the FILE64.DLL and PATCH64.EXE Files in your WINDOWS\SYSTEM32 Folder.
2. Go to your WINDOWS\SYSTEM32 Folder.
3. Run:
   PATCH64 KERNEL32.DLL KERNEL32.MOD
4. Reboot to your Windows Recovery Disk or other means to access the Windows
   Partition offline.
5. Go back to your WINDOWS\SYSTEM32 Folder.
6. Rename KERNEL32.DLL to KERNEL32.ORI.
7. Rename KERNEL32.MOD to KERNEL32.DLL.
8. Reboot.


UNINSTALL

1. Boot to your Windows Recovery Disk or other means to access the Windows
   Partition offline.
2. Rename or remove the KERNEL32.DLL File.
3. Rename KERNEL32.ORI to KERNEL32.DLL.
4. Reboot.


USAGE

Refer to the Manual for the Windows 98/98SE/ME Version of FILE64 except as
follows when working with files larger than 4GiB-4096 Bytes:

FILE64 Enabled Folders can be created on NTFS or ExFat Partitions to support
remote access by or through 9x Systems.

These files can be copied between Enabled Folders on any Partition and
Un-Enabled Folders on NTFS or ExFat Partitions.

Remote access by or through a 9x System requires that the Files be placed in
an Enabled Folder regardless of Partition Type.

Any OS that accesses Files in an Enabled Folder must have FILE64 Installed.

MoveFileEx is not currently supported, so some Move Operations may not work
from File Explorer.

FILE64 is not required on the OSes that hold these Files or their
intermediaries if the Files are placed in an Enabled Folder. These OSes will
not be able to properly access the Files.



LIMITATIONS

Only basic Unicode is provided. Usage with non-English character File Names
may result in unexpected results.



CONTENTS

FILE64.DLL      Large File Emulation API Library
PATCH64.EXE     Patch Program for KERNEL32.DLL.
README.TXT      This File
LICENSE.TXT     License terms and conditions
HISTORY.TXT     Revision History



LICENSE

Read the Licensing terms and conditions in the LICENSE.TXT file before
using the Program. Installation of the Program constitutes acceptance
of all of the terms and conditions in the LICENSE.TXT file.



ORDERING

To purchase copies of this Software Send $10 US + $1 S&H per copy to:

Rudolph Loew
506 Bieling Rd.
Elmont, NY 11003
USA

Payment can be made as follows:

1. Cash
2. Money Order drawn on a US Bank or Post Office
3. Personal Check drawn on a US Bank (Delivery made after Check clears)
4. International Postal Money Order accepted by the US Postal Service
5. Paypal payment to rloew@hotmail.com
6. Western Union

Warning: International Checks or Money Orders, not described above, will not
be accepted and will not be returned without an additional $2 US handling
charge.

Other Payment terms and methods may be available through authorized
Distributors of this Product. The following is a list of authorized
Distributors at this time:

C. C. Anderson  http://slesarc.x10host.com

Delivery is by E-Mail. You MUST include the E-Mail address you want the
Software to be sent to. It will be a Zipped Attachment.
Please type or print your E-Mail address clearly. Sending me an E-Mail when
you place an order will insure that I have your correct E-Mail address.

Prices and Terms may change at any time. Download the current Demo Version
of this Software from http://rloew1.no-ip.com if you want to test before
ordering.

For additional information or help placing your order,
I can be reached in the following ways:

E-Mail: rloew@hotmail.com
Phone:  1-516-352-9078



QUESTIONS AND COMMENTS

Please direct any questions or comments about the Program or the
Documentation to me at rloew@hotmail.com or as described under ORDERING.
Please send any Bug Reports to rloew@hotmail.com.


MAILING LIST

If you would like to be notified about updates and/or fixes or other products
from Rudolph Loew, E-Mail me at rloew@hotmail.com and ask to be put on my
Mailing list. Your E-Mail address will not be given out nor will you receive
any unsolicited mail. You can unsubscribe at any time.
