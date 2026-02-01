                       HIGH CAPACITY DISK PATCH

                             Version 5.3

                             10/11/2008

                       Copyright (C) 2003-2008
                          By Rudolph R. Loew
                             
                             

The High Capacity Disk Patch Program patches Windows 98/98SE/ME to provide
direct support for Hard Drives larger than 137GB without requiring a
controller card or the Intel Application Accelerator which can only be
used with some Intel Chipset Motherboards. The Patch installs support for the
48-Bit LBA addressing mode required for Hard Drives larger than 137GB.



REQUIREMENTS

Windows 95 Release 2 (See Note Below)
Windows 98, 98SE or ME.
Motherboard IDE and/or SATA Controller recognized by the Default ESDI_506.PDR
 Port Driver. Customized SATA .INF files are required, contact author for
 further information

BIOS support for hard drives >137GB (48-Bit LBA) or
A Windows Compatable Boot Manager that supports Hard Drives >137GB.
A Mini Boot Manager is now available from Rudolph R. Loew

NOTE: Some documentation and utilities may report this limit as 128GB.

WARNING: Some BIOSes have defective support for 48-Bit LBA. Rearranging
         Drives may cause a previously working system to fail. Verify
         support using 48BITLBA.EXE for all Drive arrangements you plan to
         use. In particular, VIA EPIA BIOSes before 07/05 may claim to
         support 48-Bit LBA, and will show the full size of the Drive, but
         will not actually support the Drive if it is not the Primary Master.
         Users of VIA EPIA motherboards should contact the Author to obtain
         a Patched BIOS if needed.

NOTE: Windows 95 performance has not been tested. If you are using the
      original version, upgrade the existing Disk Driver with REMIDEUP.EXE
      available from Microsoft at:
      http://support.microsoft.com/kb/171353/EN-US/
      before Installing the Patch.



CONTENTS

PATCHATA.EXE    Patch Program Version 5.2
48BITLBA.EXE    48-Bit Support Test Program Version 5.1
DISKDVR.EXE     Driver Identification Program
README.TXT      This File
MANUAL.TXT      Users Manual
LICENSE.TXT     License terms and conditions
HISTORY.TXT     Revision History
AUTOEXEC.BAT    Automatic Install/Verify Batch File



LICENSE

Read the Licensing terms and conditions in the LICENSE.TXT file before
using the Patch Program. Installation of the Patch constitutes acceptance
of all of the terms and conditions in the LICENSE.TXT file.



ORDERING

To purchase additional copies of this Software for other Computers:
Send $10 US per copy to:

Rudolph Loew
506 Bieling Rd.
Elmont, NY 11003
USA

Payment can be made as follows:

1. Cash
2. Money Order drawn on a US Bank or Post Office
3. Personal Check drawn on a US Bank (Delivery made after Check clears)
4. International Postal Money Order accepted by the US Postal Service
5. Bank Account or Cash Balance Payment via Paypal to rloew@hotmail.com
   Credit or Debit Card funded Paypal Payments will be DENIED
6. Western Union

Warning: International Checks or Money Orders, not described above, will not
be accepted and will not be returned without an additional $2 US handling
charge.

Other Payment terms and methods may be available through authorized
Distributors of this Product. The following is a list of authorized
Distributors at this time:

C. C. Anderson  http://www.geocities.com/slesarc

Delivery is by E-Mail. You MUST include the E-Mail address you want the
Software to be sent to. It will be a 44KB Zipped Attachment.
Please type or print your E-Mail address clearly. Sending me an E-Mail when
you place an order will insure that I have your correct E-Mail address.

Prices and Terms may change at any time. Download the current Version of this
Software from http://www.geocities.com/rloew or from Simtel before ordering.

For additional information or help placing your order,
I can be reached in the following ways:

E-Mail: rloew@hotmail.com
Phone:  1-516-352-9078
VOIP:   IP = conference.no-ip.org  PORT = 8192 (Conference Console)



QUESTIONS AND COMMENTS

Please direct any questions or comments about the Patch Program or the
Documentation to me at rloew@hotmail.com or as described under ORDERING.
Please send any Bug Reports to rloew@hotmail.com.


MAILING LIST

If you would like to be notified about updates and/or fixes or other products
from Rudolph Loew, E-Mail me at rloew@hotmail.com and ask to be put on my
Mailing list. Your E-Mail address will not be given out nor will you receive
any unsolicited mail. You can unsubscribe at any time.
