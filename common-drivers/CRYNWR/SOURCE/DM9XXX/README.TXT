
	     Installation Instructions for the DAVICOM DM9X Series
		    PCI Fast Ethernet Adapter Packet Driver



1. Compatibility

    This driver support those PCI Fast Ethernet adapters with the
    following componets:

	1. DAVICOM's DM9102(integrated MAC controller with phyical
	   layer device).

	2. DAVICOM's DM9100(MAC controller) with DM9101(MII PHY) or
	   with other vendors' MII PHY.


2. Using the packet drivers

    Before intalling the packet driver, you have to choose an interrupt
    number as as entry point to the packet driver. The range is between
    0x60 and 0x7E. Interrupt 0x67 is used by EMS, and 0x7E through 0x77
    are used by second 8259, user should avoid using these interrupts.

    Execute DM9PCIPD.COM by typing the following command under DOS prompt
    or add this command to the AUTOEXEC.BAT file:

	DM9PCIPD [options] <packet_int_no>


3. Command Options

    -d -- This switch delays the initialization of adapter until the first
	  time the packet driver is accessed by upper layer protocol stack
	  or application. It usually used in a PROM boot enviroment.

    -n -- Netware can use two different kinds of frame types "IEEE 802.3"
	  and "Ethernet II". When -n switch is used, packet driver will
	  convert Ethernet II frame into Novell's version of IEEE 802.3.

    -w -- A switch used with Windows, obsoleted by WINPKT.COM.


    -u -- Unload packet driver.


    -a -- Performing power-up and dynamic auto negotiation to find out
	  what speed(10Mb/s or 100Mb/s) and duplex mode(Full/Half) it
	  should be.


    -xf -- Forced to operate in 100Mb/s and full duplex mode.


    -xh -- Forced to operate in 100Mb/s and half duplex mode.


    -f -- Forced to operate in 10Mb/s and full duplex mode.


    -h -- Forced to operate in 100Mb/s and full duplex mode.


    -slot=<slot_num> -- Used to specify a speficif adapter that this driver
	  should work with when multiple adapters with DAVICOM's DM9x
	  series controller co-exist in the system. <slot_num> is a logical
	  PCI slot number which identify the sequence that the adpter found
	  in the PCI slots. The range is between 1 and 15.


    User can specify only one command options among -a, -xf -xh, -f, -h.
    If none of the avove command options is specified, packet driver
    will operate in auto negotioation mode as default.


4. Installing Netware with a Packet Driver

    If you want to load the packet driver and still use Netware service,
    Intel has developed a IPX driver named PDIPX, which talk to packet driver,
    can work for this purpose.	Install packet driver instead of ODI driver
    as the the following steps:

	(1). Load LSL.COM

		>LSL

	(2). Load packet drvier

		>DM9PCIPD <packet_int_no>

	(3). Execute PDIPX.COM

		>PDIPX

	(4) Invoke VLM


5. Run Winsock and Internet Applications under Windows 3.x Enhanced Mode

    WINPKT.COM is a program provides a packet driver interface between
    Windows 3.x  enhanced mode applications and a real packet driver.
    This program solves the problem that Windows move application around
    the memory in enhanced mode. Install WINPKT after the packet driver
    and before starting Windows as the following steps:

	(1). Load packet driver in DOS promt

		>DM9PCIPD <packet_int_no>

	(2). Execute WINPKT.COM in DOS promt

		>WINPKT <packet_int_no>

		The [packet_int_no] here must be the same as the one
		used by DM9PCIPD packet driver.

	(3). Invoke Windows and run the Winsock.

		Winsock must use the same interrupt vector number as
		the WINPKT.

	(4). TCP/IP related Windows applications are ready to run.


