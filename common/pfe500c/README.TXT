
		 PCMCIA 10/100 Ethernet Card
		  Driver Diskette (Ver 1.30) Overview

			       TOPIC
		======================================
		       1.  DISKETTE CONTENTS
		       2.  CLIENT DRIVER
		       3.  SOCKET and CARD SERVICES INSTALLATION ADVISORY
		       4.  DIAGNOSTIC PROGRAM
		       5.  NETWARE DOS ODI DRIVER
		       6.  PACKET DRIVER
		       7.  NDIS2 DRIVER FOR WINDOWS FOR WORKGROUPS 3.11
		       8.  NDIS DRIVER FOR LAN MANAGER V2.1
		       9.  NDIS 3.1 DRIVER FOR WINDOWS 95
		      10.  NDIS 3.1 DRIVER FOR WINDOWS 98
		      11.  NDIS 3.1 DRIVER FOR WINDOWS NT 3.51
		      12.  NDIS 3.1 DRIVER FOR WINDOWS NT 4.0
		      13.  NDIS 3.1 DRIVER FOR WINDOWS NT 2000	
		      14.  DRIVER FOR LINUX



[1] DISKETTE CONTENTS


      Files and
      Subdirectories      Contents
      --------------------------------------------------------------------
      \EN0100A             Tag File
      \README.TXT          This file
      \DIAG.EXE            PCMCIA Card Diagnostic Program
      \INSTALL.EXE         PCMCIA Installation Program
      \CARDGO.EXE          PCMCIA Client Driver
      \EN0100A.INF         Windows 95/98 Installation File
      \PMNDIS3.sys         Windows 9x NDIS3 device driver
      \NETWARE.ODI         Directory of Novell Netware DOS ODI Driver
      \PKTDRV              Directory of FTP Compliant Packet Driver Directory
      \NDIS2               Directory of NDIS V2.0 Driver
      \WFW311              Directory of NDIS V2.0 Enhance Mode Driver for WFW311
      \MSLANMAN.DOS        Directory of NDIS V2.0 Driver for Lan Manager V2.1
      \LANTASTI.V60        Directory of NDIS V2.0 Driver for Lantastic V6.0
      \WINNT351            Directory of NDIS V3.1 Driver for Windows NT 3.51
      \WINNT40             Directory of NDIS V3.1 Driver for Windows NT 4.0
      \WIN2000		   Directory of NDIS V3.1 Driver for Windows 2000
      \LINUX		   Directory of Linux Driver			


[2] ClIENT DRIVER (For DOS and Windows 3.1 Only)

      The Client Driver is a  PCMCIA  controller enable  program. This enable
      program only need for DOS and Windows 3.1 system.
      To load the client driver, type

	  CARDGO [/IRQ=x][/IO=xxx][/MEM=xxxx][/?]

      in DOS command line, or

	  DEVICE=[PATHNAME]CARDGO.EXE [/IRQ=x][/IO=xxx][/MEM=xxxx]

      in config.sys file.

	  where:

	  [/IRQ=x]     This specifies the hardware interrupt (IRQ) where your
		       card will be indicated.
		       The valid IRQs are 3,4,5,9,10,11.

	  [/IO=xxx]    This specifies the I/O address. The valid ports are 300,
		       320,340,360,240,280

	  [/MEM=xxxx]  This specifies the memory window address. The valid
		       MEMs are D000, D400, D800, DC00.

	  [/?]         This specifies to indicate the program to display all
		       the possible syntax only.

      The default syntax is:

		CARDGO /IRQ=5 /IO=300 /MEM=D400

      After you executed the CARDGO.EXE, you will see the following display for
      make sure install successful. Especially you must see the Node ID value.

		Slot          : 0                   (for example)
		IRQ           : 5                   (for example)
		IO PORT       : 300                 (for example)
		Memory        : D400                (for example)

      Here is the list of error messages the driver may display and correction
      method we suggested:


      [Error 1]
	"The PCMCIA controller is not present or recognized"
	   There is no PCMCIA controller on your computer.  Find another computer
	with PCMCIA controller to use it.

      [Error 2]
	"There is no card in PCMCIA slot.  Insert the card"
	   Card is not found in PCMCIA slot.  Insert it.

      [Error 3]
	"The card in PCMCIA slot is not PCMCIA 10/100 Ethernet Card. Insert it"
	   Card is not found in PCMCIA slot.  Insert it.

      [Error 4]
	"The I/O ports do not respose.  Change another one"
	   I/O ports do not response.  Change anther one using /IO=xxx.

      [Error 5]
	"The I/O ports specified are invalid.  Change another one"
	   I/O ports are invalid.  Change anther one using /IO=xxx.

      [Error 6]
	"The IRQ specified is invalid.  Change another one"
	   IRQ setting is invalid.  Change anther one using /IRQ=x.

      [Error 7]
	"The memory address specified is invalid.  Change another one"
	   Memory setting is invalid. Change another one using /MEM=xxxx.

      [Error 8]
	"Enabler has been registered"
	    This Client Driver has been registered once. Don't run it again.

      [Error 9]
	"Enabler can't registered as a client"
	"Can't map memory"
	"Configuration can't be requested"
	    These three errors are concerned with Socket and Card services
	of the PCMCIA controller.  Try another third part Socket and Card
	service support this PCMCIA controller.

[3] SOCKET and CARD SERVICES INSTALLATION ADVISORY

      For those who installed EMM386.EXE in your config.sys, please exclude
      memory address D400-D7FF from your system. 10/100 Ethernet Card
      Enabler program will use this space to read Ethernet ID and CIS from
      on-board serial EEPROM.
      [Example]
		DEVICE=EMM386.EXE NOEMS X=D400-D7FF
				or
		DEVICE=EMM386.EXE NOEMS X=D000-DFFF

      For those who installed Card and Socket Services device driver in your
      config.sys, please run CARDGO.EXE(see Client Driver) after those device
      drivers. The default configuration is IRQ=5, IO=300 and MEM=D400.

      [Phoenix PCM+ V3.0]
	DEVICE=C:\PCM3\CNFIGNAM.EXE /SETUP-DEFAULTS
	DEVICE=C:\PCM3\PCMSS.EXE
	DEVICE=C:\PCM3\PCMCS.EXE
	DEVICE=C:\PCM3\PCMRMAN.SYS
	DEVICE=C:\PCM3\PCMSCD.EXE
	DEVICE=CARDGO.EXE

      [SystemSoft CardSoft V3.1]
	DEVICE=C:\CARDSOFT\SS365SL.EXE  //Socket Service for Intel Compatible //
	DEVICE=C:\CARDSOFT\CS.EXE
	DEVICE=C:\CARDSOFT\CSALLOC.EXE
	DEVICE=CARDGO.EXE

      [Award CArdware V2.0]
	DEVICE=C:\CARDWARE\SSPCIC.EXE
	DEVICE=C:\CARDWARE\PCCS.EXE
	DEVICE=C:\CARDWARE\PCRM.EXE /AUTODETECT
	DEVICE=CARDGO.EXE
	      [Note] Please do not use PCENABLE.EXE

      [AMI AMICARDZ]
	DEVICE=C:\AMI\SSSL.SYS
	DEVICE=C:\AMI\AMICS.SYS
	DEVICE=CARDGO.EXE
	      [Note] Please do not use PCBE.SYS

      [Databook CardTalk V3.02]
	DEVICE=C:\CARDTALK\TMB250.SYS /io:240
	DEVICE=C:\CARDTALK\CTALKCS.EXE
	DEVICE=C:\CARDTALK\CARDTALK.EXE /A /IOW=300-31F /MEMW=D000-D7FF
	DEVICE=CARDGO.EXE

      [IBM Thinkpad Socket and Card Services V2.12]
	DEVICE=C\EMM386.EXE NOEMS I=B000-B7FF X=C800-CFFF X=D000-DFFF
	DEVICE=C:\THINKPAD\IBMDSS01.SYS /D
	DEVICE=C:\THINKPAD\IBMDOSCS.SYS
	DEVICE=C:\THINKPAD\DICRMU01.SYS /MA=C800-DFFF
	DEVICE=C:\THINKPAD\$ICPMDOS.SYS


[4] DIAGNOSTIC PROGRAM

       DIAG.EXE is a complete test program that users can make
       sure if the card is good or not. It provides the following
       card test functions:

	  . IRQ verify
	  . IO base verify
	  . RAM test
	  . Card Node ID test
	  . Internal Loopback test
	  . External Loopback test

       [Note] Before execute diagnostic program, you must make sure the client
	      driver, CARDGO.EXE, is installed.

[5] NETWARE DOS ODI DRIVER

      This directory contains Ethernet DOS ODI driver PMODI.COM that
      supports NetWare 3.x and 4.x, NetWare Lite and other ODI interface
      application.

	     PMODI.COM : DOS/ODI Driver for NetWare 3.x and 4.0.
  
      The following instructions let you to install Novel NetWare Ver. 386
      DOS ODI Driver :

	1. Run INSTALL.EXE
	2. Follow the instruction to select a set of available hardware
	   resource for the card.
	3. Select the 'Netware ODI Driver' to install the driver.
	4. Reboot your computer.

      The install program will copy the following files to your hard disk.  

	   a. LSL.COM           ---- supported by Novell
	   b. PMODI.COM       ---- Novell DOS ODI Driver ,supported
				     by manufacturer
	   c. IPXODI.COM        ---- supported by Novell
	   d. NETx.COM          ---- supported by Novell
	   e. NET.CFG           ---- optional,configuration file
	   f. STARTNET.BAT      ---- login batch file

      After reboot your workstation, you may type 'STARTNET' to login to
      your Novell servers.

      The NET.CFG file is the configuratin file for the ODI driver.
      You  can  see  Netware 386  Installation  appendix E for more
      information about NET.CFG.


[6] PACKET DRIVER

      The PMPKT.COM is the Packet driver.
      To load the packet driver , type PMPKT 0X60.

      PMPKT syntax:
	PMPKT [-h] [-n] [-d] [-w] [-u] <PACKET_INT_NO> [IRQ] [IO_BASE]

      where:

      [-h]         Show on-line help.
      [-n]         Convert ETHERNET II header to IEEE 802.3 header.
      [-d]         Do not start LAN card until this driver is
		   called by the higher layer programs first.
      [-w]         Running under Windows environment.
      [-u]         Unload packet driver.
      <PACKET_INT_NO>    This specifies the software interrupt (IRQ) where
			 you'll load the packet driver. It must be in the range
			 0x60 to 0x80.
      [IRQ]        This specifies the hardware interrupt (IRQ) where your
		   card will be indicated.
      [IO_BASE]    This specifies the I/O address .

      Example:

	 The following command line loads the Ethernet Packet Driver
	 at software interrupt 60h, at I/O address 300, at hardware interrupt 5.

		  PMPKT 0x60 0x5 0x300
			   or
		      PMPKT 0x60

	 Note: The default I/O address is 300 .
	 Note: The default hardware interrupt is 5
	 Note: The placement of 0x prior to the parameters.



[7] NDIS2 DRIVER FOR WINDOWS FOR WORKGROUPS 3.11


 A) Install NDIS driver to the WFW 3.11

    The drivers named PMNDIS.DOS contained in the directory
    conform to the Network Driver Interface
    Specification (NDIS) defined by Microsoft/3Com.


    NDIS Driver Installation on Windows for Workgroups
    --------------------------------------------------

    1. Run Windows by typing WIN from the DOS prompt.
    2. Click the "Network" icon in the Main Program
       Group.
    3. Click the "Network Setup" icon from the Network window.
    4. Select "Drivers" item from the Network Setup dialog box.
    5. Select "Add Adapters" item in the Option dialog box.
    6. Select "Unlisted or Updated Network Adapter" when the
       Install driver field appears.
    7. Type destination drive and path name in your PC.
       Make sure the full path of the directory (i.e. A:\WFW311)
       is given.
    8. Insert PCMCIA 10/100 Ethernet Card Driver Diskette in
       your floppy drive, and press <Enter> to start the
       installation process.

    9. When the "PCMCIA 10/100 Ethernet Card" dialog box appear,
       press<Ok> to select the adapter.

    10.Follow screen instructions to complete the process.

    11.Restart your computer.



[8] NDIS DRIVER FOR LAN MANAGER V2.1

	     Installation Introduction for LAN Manager V2.1
	   --------------------------------------------------
       a. Type "lmsetup" In LanManager Directory. Press Enter.

       b. Choice "Network Drivers..." in " Configuration ". Press Enter.

       c. Choice <Add New Configs> ,press Enter.
	  Network Adapter Driver appears.

       d. Choice <Other Driver> , press Enter.

       e. Insert the Driver Disk to specified drive (A:\> or B:\>),key in the
	  specified drive (A:\> or B:\>),then push <OK> button.

       f. Select a available Network Adapter Driver,
	     "PCMCIA 10/100 Ethernet Card"
	  Push <OK> button.

       g. Press the SPACEBAR to select the protocol what you want.

       h. Push <OK> button.
	  Configuration Complete appear.

       i. Push <Save> button.

       j. Press "F3" to exit.

       k. Press Enter.

       l. Copy "CARDGO.EXE" in Driver Diskette to LanManager Directory.


       Sample configuration files:

       [CONFIG.SYS]

	 a.<V2.1>

	   DEVICE=C:\LANMAN.DOS\CARDGO.EXE
	   DEVICE=C:\LANMAN.DOS\DRIVERS\PROTMAN\PROTMAN.DOS /i:C:\LANMAN.DOS
	   DEVICE=C:\LANMAN.DOS\DRIVERS\PMNDIS.DOS


       [Protocol.ini file for LAN Manager]

	a. V2.1
	 [PROTMAN]
	   DRIVERNAME = PROTMAN$
	   DYNAMIC = YES
	   PRIORITY = NETBEUI

	 [NETBEUI_XIF]
	   Drivername = netbeui$
	   SESSIONS = 6
	   NCBS = 12
	   BINDINGS = "PMNDIS_NIF"
	   LANABASE = 0

	 [PMNDIS_NIF]
	  ; protocol.ini section for PCMCIA 10/100 Ethernet Card

	   IOBASE = 0x300
	   INTERRUPT = 5
	   DRIVERNAME = PMNDIS$

       [Autoexec.bat file for LAN Manager]

	 a. V2.1
	   @REM ====== LANMAN 2.1 === DO NOT MODIFY BETWEEN THESE LINES
	   SET PATH=C:\LANMAN.DOS\NETPROG;%PATH%
	   NET START WORKSTATION
	   LOAD NETBEUI
	   @REM ====== LANMAN 2.1 === DO NOT MODIFY BETWEEN THESE LINES


[9]  NDIS 3.1 DRIVER FOR WINDOWS 95


     INSTALLATION PROCEDURE:

     1) Insert 10/100 Ethernet Card into the PCMCIA slot.
	The system displays the "New Hardware Found" window,
	with "PCMCIA-10/100 Ethernet Card" as the device name.

     2) Select "Drivers from disk provided by hardware manufacturer"
	if it is retail version Windows 95 (4.00.950).

     3) Insert the driver diskette into the floppy drive, type "a:" if the floppy
	drive is a:, then press enter.
	
     4) Occasionally, the system may ask for files from the Windows 95
	CD-ROM. Follow the prompt until the installation is complete.

     5) Reboot the machine to start the network.


[10]  NDIS 3.1 DRIVER FOR WINDOWS 98

     INSTALLATION PROCEDURE:

     1) Insert 10/100 Ethernet Card into the PCMCIA slot.
	The system displays the "New Hardware Found" window,
	with "PCMCIA-10/100 Ethernet Card" as the device name.

     2) Click Next, then select "Search for the best driver for your device.",
	and click Next to continue.

     3) Check "Specific location" only and uncheck others.  Type "a:" if the floppy
	drive is f:. Then place the driver disc in CD-ROM drive.

     4) Select the found updated driver, PCMCIA 10/100 Ethernet Card,
	then click Next.

     5) Occasionally, the system may ask for files from the Windows 98
	CD-ROM. Follow the prompt until the installation is complete.

     6) Reboot the computer to start the network.

   
[11]  NDIS 3.1 DRIVER FOR WINDOWS NT 3.51

     INSTALLATION PROCEDURE:

     1) Open the Control Panel, and choose Network Settings.
     2) Click the Add Adapter button.
     3) Select <Other> Requires disk from manufacturer.
     4) Type in the path a:\WINNT351 if the floppy drive is a:.
     5) Select the "PCMCIA 10/100 Ethernet Card".
     6) Set the IRQ level and I/O Port Address to any free resources,
	Valid IRQ's=3,4,5,9,10,11.
	Valid I/O's=300,320,340,360.
	And set connection type as "AutoSense".
     7) Click on OK and back to the Network Settings.
     8) Click on OK and Restart the Machine.

[12]  NDIS 3.1 DRIVER FOR WINDOWS NT 4.0

     INSTALLATION PROCEDURE:

     1) Open the Control Panel, and choose Network
     2) Select Adapter tab and click the Add button.
     3) Click Have Disk button.
     4) Type in the path a:\WINNT40 if the floopy drive is a:.
     5) Select the "PCMCIA 10/100 Ethernet Card".
     6) Set the IRQ level and I/O Port Address to any free resources,
	Valid IRQ's=3,4,5,9,10,11.
	Valid I/O's=300,320,340,360.
	And set connection type as "AutoSense".
     7) Click on OK and back to the Network Settings.
     8) Click on OK and Restart the Machine.


[13] NDIS 3.1 DRIVER FOR WINDOWS 2000

     INSTALLATION PROCEDURE:

     1) Insert PCMCIA 10/100Mbps Ethernet Card into the PCMCIA slot.
        The system displays the "Found New Hardware Wizard" window.
        Clink Next to continue.

     2) The "Found New Hardware Wizard" prompt you what do you want the wizard
        to do. select the "Search for a suitable driver for my device.",
        and click Next to continue.

     3) Check the "Specify a location" while the wizard asking where do you
        want Windows to search for driver files. Then click Next to continue.

     4) Insert the driver disk and specify the path, 'a:\win2000'. then click
        Next to continue.

     5) After the wizard found the INF file and the driver, click Next.

     6) When the "Digital Signature Not Found" window pops up, click 'Yes'
        button to continue installation.

     7) After copying the drivers, the wizard shows "Completing the Found New
        Hardware Wizard", click Finish to close the wizard.

   
[14] DRIVER FOR LINUX

File List
---------
    The complete file list is as follows:

    README
    makefile
    ken0100a.h
    8390.c
    pcnet_cs.c
    lan.o
  
Before Installation
-------------------
	Before you start rebuilding the driver, you must have PCMCIA binaries and
    source installed in your system. PCMCIA module version 3.0.9 or
    later are quaranteed to work well with this device driver.

    Latest version of PCMCIA module is available at ftp://csb.stanford.edu.

Installation:
-------------

 1. To login as the root.
 
 2. To copy the driver code from the Installation diskette, simply do 
    
    > mcopy a:ken0100-a-v1.0.tgz . 
    > gzip -cd ken0100-a-v1.0.tgz | tar xvf -
 
 3. To generate the driver
 
    Modify the PCMCIASRC variable in your makefile to the location of your 
    PCMCIA source.
    
    Modify the KERN_VER variable in your makefile.
    
    After you finish the modification of variables in your makefile, you can
    rebuild the driver by doing

    > make 
 
 4. To install the driver
 
    > make install

 5. To configure the PCMCIA 10/100 Ethernet card
 
    > cd /etc/pcmcia
    
    To add the following text into the "config" file (The mode of the "config"
    file must be the "write" mode.)
    
    > vi config
    
        card "PCMCIA 10/100Mbps Ethernet Card"
	   version "PCMCIA", "10/100 Ethernet Card"
	   bind "pcnet_cs"
    
    To configure the PCMCIA NIC interface
    
    > vi network.opts
     
 6. To reboot the Linux
    
    > shutdown -r now
