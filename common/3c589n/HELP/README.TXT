
README.TXT File
3Com Corporation
3Com EtherLink III LAN PC Card (3C589 PC Card)

Please read this file before installing the 3Com EtherLink III LAN PC Card.
This file contains information that became available after the 3Com 
EtherLink III LAN PC Card User Guide went to the printer.

This file is divided into two sections:
     General Information  - Read for all network operating systems
     Novell NetWare Information - Read if you are using Novell NetWare

               Important General Information 
               =============================

For DOS and Windows 3.x

The 3Com 3C589 works with laptops that contain Card Services.  If you are
not running Card Services on your system, please note that the 3C589 will
work with laptops that have an Intel PCMCIA (PC Card) controller or
compatible controller.  If Card Services is not installed, it might not
work with other controllers.

You may override some driver configuration parameters (IRQ, I/O base and
CIS Memory base address).  See the sample NET.CFG or PROTOCOL.INI files
on the EtherDisk diskette for proper syntax. 

Full-Duplex Operation
=====================

For NetWare ODI
The DOS ODI NetWare driver supports full-duplex operation (that is,
sending  and receiving data simultaneously).  WARNING: You MUST be
connected to a switched full-duplex Ethernet hub to use this feature
(this feature disables collision detection).  

To enable this feature add the ODI Keyword "FULL DUPLEX" to the 
NET.CFG file.

For NDIS 2.0
To enable the NDIS 2.0 full duplex feature, add the Full Duplex key word
to the PROTOCOL.INI file as follows:

ORIGINAL (Half Duplex):
	[ms$elpc3]
	DRIVERNAME=ELPC3$

MODIFIED (Full Duplex):
	[ms$elpc3]
	DRIVERNAME=ELPC3$
	FULL_DUPLEX=YES


Novell NetWare Information
==========================

The 3C589 EtherLink III LAN EtherDisk contains a Novell NetWare DOS
ODI Driver (3C589.COM), and a Novell NetWare OS\2 ODI driver (3C589.SYS).
The 3C589.COM DOS ODI driver is Novell certified.  The 3C589.SYS OS/2 ODI 
driver Novell certification is still in progress.

If you are using 3Com's automatic installation program, AutoLink, delete 
references to any other network adapter in the AUTOEXEC.BAT file and in the 
NET.CFG file prior to executing AutoLink. You can delete the NET.CFG file, 
and a new one will be copied over. 



(%VER README.TXT v1.2b)

 
