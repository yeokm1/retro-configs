                   NVIDIA GRAPHICS CARD SIZE PATCH

                             Version 3.0

                              06/04/2017

                        Copyright (C) 2015-2017
                          By Rudolph R. Loew
                             
                             

The nVidia Graphics Card Size Patch Package provides two solutions to the
problem of NVidia Graphics Cards that use memory banking to access Video RAM.
This causes a problem in most Windows 95, 98, 98SE or ME Systems when a 512MB
Graphics Card reports only 256MB of Memory Mapped I/O Space when configured.

One Patch changes the Video Driver Code to properly support the smaller
directly accessible Video Memory of the Card. The second Patch modifies the
Graphics Card BIOS to report the full size of the Video RAM when
configured.

Another Patch is provided to Disable Video Option ROM Configuration. Some
BIOS and Graphics Card combinations set an Invalid Option ROM address that
confuses the Configurator.

A set of Interrupt Fixup Files (FIXINTR) are provided to handle loss of
Interrupts due to mishandling of End Of Interrupt (EOI) commands by the
NVidia Graphics Driver. Symptoms of this problem include Mouse Pointer
freezing, DISK Write Error BSODs and USB problems.

If the FIXINTR Files do not work on your System, use the FIXEOI.VXD File.

The Shutdown Patch is included with the Driver Patch.


REQUIREMENTS

DOS
Windows 95, 98, 98SE or ME.
6xxx or 7xxx Series nVidia Graphics Card.
nVidia Graphics Card Driver Version 82.69 (not included) (for Driver Patch)


CONTENTS

PATCHNVC.EXE    Graphics Driver Patch
PTCHNVSZ.EXE    BIOS Image Patch Program
PATCHOPT.EXE    Patch PCI.VXD to Disable Video Option ROM Config
NVFLASH.EXE     nVidia BIOS Flash Program  (Copyright www.techpowerup.com)
CWSDPMI.EXE     DPMI Support Program       (Copyright CW Sandmann)
NVSIZE.EXE      Display Video RAM and MMIO Space Sizes 
README.TXT      This File
MANUAL.TXT      Users Manual
LICENSE.TXT     License terms and conditions
HISTORY.TXT     Revision History
FIXINTR.VXD     Interrupt Fixup VXD (All IRQs)
FIXINTR#.VXD    Interrupt Fixup VXD (Individual IRQs) #=IRQ
FIXEOI.VXD      Alternate Interrupt Fixup VXD (All IRQs)

NVCHECK.EXE     Compatibility Check Program (included in free Package)
TESTEOI.VXD     Test VXD for Interrupt EOI bug (included in free Package)
NVCHECK.TXT     Compatibility Check and Test Manual (included in free Package)


LICENSE

Read the Licensing terms and conditions in the LICENSE.TXT file before
using the Patch Program. Usage of any of the Patch Programs constitutes
acceptance of all of the terms and conditions in the LICENSE.TXT file.


COMPATIBILITY CHECK

The Compatibility Check Program NVCHECK.EXE is available separately for free
at http://rloew1.no-ip.com to test if this Patch is compatible with and is
needed by your Graphics Card. This Program can be used before Purchase.


INTERRUPT EOI BUG CHECK

The Interrupt EOI Bug Check VXD TESTEOI.VXD is available separately for free
at http://rloew1.no-ip.com to test if an Interrupt Fixup VXD is needed by
your Graphics Card. This File can be used before Purchase.


THIRD-PARTY SOFTWARE

NVFLASH.EXE and CWSDPMI.EXE are available at http://www.techpowerup.com

NVidia Graphics Driver 82.69 is an unofficially modified Driver available
at http://www.mdgx.com/files/nv8269.php


ORDERING

To purchase additional copies of this Software for other Computers:
Send $20 US + $1 S&H per copy to:

To purchase additional copies of only the Interrupt Fixup VXDs for other
Computers, send $10 US + $1 S&H per copy to:

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

C. C. Anderson  http://slesarc.x10hosting.com

Delivery is by E-Mail. You MUST include the E-Mail address you want the
Software to be sent to.
Please type or print your E-Mail address clearly. Sending me an E-Mail when
you place an order will insure that I have your correct E-Mail address.

Prices and Terms may change at any time.

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
