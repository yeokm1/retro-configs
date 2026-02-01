                      DOS DISK/FAT32 TRIM Program

                             Version 1.3

                              08/10/2017

                        Copyright (C) 2015-2017
                          By Rudolph R. Loew


The DOS DISK/FAT32 TRIM Program allows the user to send TRIM Commands to SSD
Drives so that the Drives Controller can reuse data blocks that are no longer
needed.


REQUIREMENTS:

Bootable DOS OS for full control, or put in AUTOEXEC.BAT to run at Startup.
SSD or other Drive that supports TRIM Command.
Hard Disk Controller BIOS that reports Control Ports via INT 13 AH=48
USB or Firewire Connected Drives are NOT supported.
Only FAT32 Filesystem supported for selective TRIM.


PURPOSE:

Operating systems older than Windows 7 do not provide TRIM functionality
so SSD Drives accumulate no longer used data blocks that it doesn't know
can be reused. This can greatly slow Write operations to the Drive.


MODES:

The TRIM Program can be run in four Modes.

The "Free" Mode TRIMs the unused Sectors in a FAT32 Partition. This is the
normal use for this Program.

The "Zero" Mode TRIMs all Sectors that contain all Zeroes in a SSD that
returns all Zeroes when reading a Trimmed Sector. This can provide a more
aggresive TRIM before or after performing a "Free" Mode TRIM but has to scan
the entire Drive or Partition so it may take hours to execute. A "Free" Mode
Trim should be done afterwards to TRIM unused non-zero Sectors. A "Zero" Mode
Trim is best done when first setting up a Hard Drive that already has data on
it or the first time TRIM is used.

The "All" Mode TRIMs an entire Partition or Disk. This effectively erases
all data PERMANENTLY. This mode is used to intitalize a Disk or Partition
before Formatting or to erase a Drive before disposing of it. A Disk will
become unpartitioned. A Partition will become unformatted. A "Zero" or "Free"
Mode Trim is not needed after using "All" Mode.

The "Range" Mode allows you to ERASE specific Ranges in a Partition or Disk.
This is for Advanced Users who only want to TRIM specific areas.
Ranges do not include the Stop Number so specifying 4 and 8 will TRIM Sectors
4, 5, 6 and 7.


WARNING:

All TRIM operations irreversibly erase the data in the affected Sectors.
Using the "All" Mode can erase an entire Hard Drive in a few Seconds.

Using the "Free" Mode will eliminate all deleted data in the Partition.
You will not be able to use a Recovery or Undelete Program to retrieve
deleted data after running TRIM.

It is strongly recommended that you successfully run a Disk Checker, such
as SCANDISK, on a partition, before running TRIM in "Free" Mode.

If the two FAT Tables do not match, TRIM will abort when it reaches the
mismatch. The Partition may be partially trimmed in this case. There is no
danger to this if the FAT Tables are not otherwise corrupted. TRIM can be
restarted after correcting the FAT Errors.


DRIVES AND PARTITIONS:

The TRIM Program accepts INT 13 Disk Numbers starting at 0x80 or Drive
Letters starting with C:.

Specifying Disk Numbers tells TRIM to use absolute Sector Numbers for the
Ranges in "Range" Mode, the entire Physical Disk in "Zero" Mode, or to erase
the entire Physical Disk in "All" Mode. The "Free" Mode Option will not work
unless the Disk is configured Floppy Style without Partitions. This allows
TRIM to be used on a Disk that is or will be used in an External Enclosure.

Specifying Drive Letters tells TRIM to use relative Sector Numbers for the
Ranges in "Range" Mode, to Trim only the Partition in "Zero" Mode, or to
erase only the Partition in "All" Mode. The "Free" Mode Option would normally
be used with Drive Letters except as noted above.


PROMPTS:

Since TRIM operations destroy data irreversibly, the TRIM Program Prompts
before sending Commands.

Free Mode simply requires a "Y" or "Yes" to Continue. This can be overridden
by using the -NoQuery Option. For example:  TRIM -Noquery C: Free
Range Mode requires that you Type "Erase" to Continue.
All Mode requires that you Type "Erase ALL" to Continue.
Zero Mode does not affect non-zero Sectors so it does not require a Prompt.

Capitalization must be exact on erase operations. Extra characters are
ignored. Do not include the quotes.

If you respond correctly, the Command will be executed, and TRIM will then
Print "DONE".

If not, the Program will Exit without printing "DONE".


SYNTAX:

The syntax for the TRIM Program is:

TRIM [-NoQuery] Drive|Disk Free|Zero|All|[Start Stop]....

The -NoQuery Option bypasses the confirmation Prompt when using Free Mode.
This is for use in Batch Files.

Drive is the Drive Letter of a Partition to TRIM.
or
Disk is the INT 13 Number of the Disk to TRIM. First Hard Disk is 0x80 or 128.

F or Free to select TRIM Free Blocks
or
Z or Zero to select TRIM Zero Filled Blocks
or
A or All to TRIM entire partition or Disk
or
Zero or more Start and Stop Sector Ranges

If neither "F" nor "Z" nor "A" nor any Ranges are specified, no TRIM will
occur. Only the Disk or Partition Info will be printed.


WINDOWS:

The TRIM Program cannot be run from Windows, even in a DOS Box. It must be
run from Real Mode DOS.

In Windows 95, 98 and 98SE it can be run from AUTOEXEC.BAT or by going to
"Command Prompt Only" from the Boot Menu.

For Windows ME or XP, you need to have a separate Boot Floppy, CD or Bootable
USB Key to run the TRIM Program.


ERROR MESSAGES:

IF TRIM encounters a problem, it will print one of the following Error
Messages:

Invalid Drive                          Drive Number or Letter does not exist.
Cannot Get Disk Info                   BIOS does not report Drive Information.
                                       or not Hard Disk
TRIM not supported                     Drive does not support TRIM.
Greater than 2TiB Drive Not Supported  This Version of TRIM is limited to 2TiB.
Starting after 2Tib Not Supported      TeraByte Plus Partitions not supported.
Cannot Zero TRIM This Disk             Drive does not Read Trimmed Sectors
                                       as Zero Filled.
Large Sector Format Not Supported      TRIM requires 512 Byte Sectors.
Length Longer Than Partition           FAT32 header has invalid End Sector.
Missing Range End                      Start of Range specified but no End.
Invalid Range                          End of Range not greater than Start.
TRIM Failed Code #                     TRIM Command Failed.
Read Error on Sector #                 A Read Error occurred during scan.
Not FAT32 Formatted                    Free Mode requires valid FAT32 header.


EXAMPLES:

TRIM D: F       Trim free sectors in D:
TRIM E: A       Erase all data in E: Partition and Unformat.
TRIM 0x81 A     Erase all data in the Second Hard Drive and Unpartition.
TRIM 0x82 Z     Trim all Zero Filled Sectors in the Third Hard Drive.
TRIM H: Z       Trim all Zero Filled Sectors in the H: Partition.
TRIM F: 9 32    Trim reserved space in standard DOS/WIN9X FAT32 Partition F:. 
TRIM -N C: F    Trim free sectors in C: without prompting.
TRIM G:         Show Partition Info for G: and take no action.



LICENSE

Read the Licensing terms and conditions in the LICENSE.TXT file before
using the Program. Installation of the Program constitutes acceptance
of all of the terms and conditions in the LICENSE.TXT file.



ORDERING

To purchase full copies of this Software:
Send $10 US + $1 S&H per copy to:

Rudolph Loew
506 Bieling Rd.
Elmont, NY 11003
USA

Payment can be made as follows:

1. Cash
2. Money Order drawn on a US Bank or Post Office
3. Personal Check drawn on a US Bank (Delivery made after Check clears)
4. International Postal Money Order accepted by the US Postal Service
5. Paypal to rloew@hotmail.com
6. Western Union

Warning: International Checks or Money Orders, not described above, will not
be accepted and will not be returned without an additional $2 US handling
charge.

Other Payment terms and methods may be available through authorized
Distributors of this Product. The following is a list of authorized
Distributors at this time:

C. C. Anderson  http://slesarc.x10host.com

Delivery is by E-Mail. You MUST include the E-Mail address you want the
Software to be sent to. It will be a 69KB Zipped Attachment.
Please type or print your E-Mail address clearly. Sending me an E-Mail when
you place an order will insure that I have your correct E-Mail address.

Prices and Terms may change at any time. Download the current Version of this
Software from http://rloew1.no-ip.com or from Simtel before ordering.

For additional information or help placing your order,
I can be reached in the following ways:

E-Mail: rloew@hotmail.com
Phone:  1-516-352-9078
VOIP:   IP = conference.no-ip.org  PORT = 8192 (Conference Console)



QUESTIONS AND COMMENTS

Please direct any questions or comments about the Program or the
Documentation to me at rloew@hotmail.com or as described under ORDERING.
Please send any Bug Reports to rloew@hotmail.com.


MAILING LIST

If you would like to be notified about updates and/or fixes or other products
from Rudolph Loew, E-Mail me at rloew@hotmail.com and ask to be put on my
Mailing list. Your E-Mail address will not be given out nor will you receive
any unsolicited mail. You can unsubscribe at any time.

