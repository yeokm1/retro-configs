                         ENCRYPTED DISK PATCH

                             Version 2.0

                              10/24/2013

                       Copyright (C) 2006-2013
                          By Rudolph R. Loew
                             
                             

The Encrypted Disk Patch Software patches the BIOS and Windows 98/98SE/ME to
provide full Disk Encryption. All files on the Hard Drive(s) are Encrypted
as they are written and Decrypted as they are read so no unencrypted data is
ever placed on the Hard Drive(s). If all of the Hard Drive(s) are Encrypted,
all Temporary Files, Cache Files, History Files, Swap Files, Slack Space,
etc. are Encrypted as well as all Application Files leaving no opportunity
for anyone to recover sensitive data. Laptops with all Hard Drives Encrypted
would no longer be a security threat, as no data or programs could be
recovered from them, if they were stolen.



REQUIREMENTS

Windows 95 Release 2 (See Note Below)
Windows 98, 98SE or ME.
Motherboard IDE Controller recognized by the Default ESDI_506.PDR Port Driver

For Hard Drives larger than 137GB:
High Capacity Disk Patch from Rudolph R. Loew
BIOS support for hard drives >137GB (48-Bit LBA) or
Large Hard Drive Version of the Encrypted Disk Boot Manager

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



DEMO VERSION

The Demo Version of this Software has only the Floppy Based Boot Manager
Setup (DFMINST.COM) and uses a fixed Password on all Encrypted Hard Drives.
Encrypted Hard Drives setup using the Demo Version can be accessed with the
Password " " (1 Space Character without the quotes).

WARNING: Encrypted drives created by the Demo version CANNOT be converted to
         a more secure Password using the Full Version. You must copy the
         files to another drive or use mirroring software to duplicate the
         drive.



CONTENTS

PATCHENC.EXE    Encrypted Patch Program Version 1.0
PATCHEXP.EXE    Windows Driver Expander Version 1.0
FMINST.COM      Floppy Based Encrypted Boot Manager Version 1.0
BMINST.COM      Encrypted Boot Manager Installer Version 1.0
FLOPINST.COM    Floppy Based Encrypted Boot Manager Installer Version 1.0
UNINST.COM      Encrypted Boot Manager UnInstaller Version 1.0
DISKDVR.EXE     Driver Identification Program
README.TXT      This File
MANUAL.TXT      Users Manual
LICENSE.TXT     License terms and conditions
HISTORY.TXT     Revision History
AUTOEXEC.BAT    Automatic Install/Verify Batch File

Demo Version Only
DFMINST.COM     Floppy Based Encrypted Boot Manager Version 1.0 (DEMO)



LICENSE

Read the Licensing terms and conditions in the LICENSE.TXT file before
using the Patch Program. Installation of the Patch constitutes acceptance
of all of the terms and conditions in the LICENSE.TXT file.



ORDERING

To purchase additional copies of this Software:
Send $20 US per copy of the Standard Version or $25 US for the Version
with Hard Drive BIOS Support, to:

Rudolph Loew
506 Bieling Rd.
Elmont, NY 11003
USA

Payment can be made as follows:

1. Cash
2. Money Order drawn on a US Bank or Post Office
3. Personal Check drawn on a US Bank (Delivery made after Check clears)
4. International Postal Money Order accepted by the US Postal Service
5. Bank Account or Cash Balance funded Payment via Paypal to rloew@hotmail.com
   Credit or Debit Card funded Paypal Payments will be DENIED
6. Western Union
7. Other options may be available from the following authorized Distributors:

C. C. Anderson  http://slesarc.x10host.com

Warning: International Checks or Money Orders, not described above, will not
be accepted and will not be returned without an additional $2 US handling
charge.

Delivery is by E-Mail. You MUST include the E-Mail address you want the
Software to be sent to. It will be a 48KB Zipped Attachment.
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

Please direct any questions or comments about the Patch Program or the
Documentation to me at rloew@hotmail.com or as described under ORDERING.
Please send any Bug Reports to rloew@hotmail.com.


MAILING LIST

If you would like to be notified about updates and/or fixes or other products
from Rudolph Loew, E-Mail me at rloew@hotmail.com and ask to be put on my
Mailing list. Your E-Mail address will not be given out nor will you receive
any unsolicited mail. You can unsubscribe at any time.
