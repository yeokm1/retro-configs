
                   XIRCOM CARDBUS ETHERNET ADAPTERS 
                    Software Release Version 3.12 
                            August 29,2000 
__________________________________________________________________

Thank you for purchasing your Xircom CardBus Ethernet adapter. The 
drivers in this software release are compatible with the following 
Xircom CardBus Ethernet Adapters:

Product Name				      Model Number
------------                                  ------------

CreditCard CardBus Ethernet 10/100 Adapter    CBE-10/100BTX
CreditCard CardBus Ethernet II 10/100 Adapter CBE2-100BTX
RealPort CardBus Ethernet 10/100 Adapter      RBE-100BTX
RealPort2 CardBus Ethernet 10/100 Adapter     R2BE-100BTX

Xircom has done everything to ensure that our adapters are 
compatible with the widest range of portable PCs possible.  Xircom 
is equally committed to customer satisfaction and timely response 
to the needs and concerns of our customers.

For the latest information on all Xircom products, visit the 
Xircom Website at: http://www.xircom.com/


CONTENTS
--------

 1) Xircom CardBus Ethernet Adapter Characteristics
 2) What's New in the 3.12 Software Release
 3) Notes Regarding Card and Socket Services
 4) Release Notes/Known Limitations
 5) Using the CBE/CBE2/RBE/R2BE in Windows 2000 
 6) Machine Specific Notes
 7) SNMP Agent
 8) SCO Unix Support
 9) Linux Support
10) Xircom Technical Support


1) XIRCOM CARDBUS ETHERNET ADAPTER CHARACTERISTICS
==================================================

10/100Mbps connectivity - Allows portable PCs equipped with a 
CardBus slot to connect to 100Base-TX Ethernet networks to take 
advantage of higher network bandwidth. See model descriptions 
below for additional information.

NWay Auto-negotiation of 10 or 100Mbps Ethernet connection rate - 
Upon initialization, the adapter will automatically adopt the 
speed of the network port to which it is attached, allowing it to 
be used seamlessly on either 10Mbps (10Base-T) or 100Mbps 
(100Base-TX) network segments.

Support for Windows NT 4.0 Card and Socket Services from 
SystemSoft, Phoenix, Softex and Award.

Full suite of network driver support - Allows 10Mbps or 100Mbps 
connection across a wide range of operating systems and networks. 
Native 32-bit NDIS3 and NDIS4 driver support for Windows 95 and 
Windows NT 4.0 is included. An NDIS5 driver is included for use 
with Windows 98 and Windows 2000.

Includes Xircom's Battery Save (TM) technology. When the LAN cable 
is disconnected from the adapter, the CBE2 automatically puts 
itself into a low power state. When the LAN cable is reattached, 
it automatically powers itself back up.

Advanced power management capabilities including Wake on LAN, 
Magic Packet, and support for the ACPI and CardBus Power 
Management Specifications. However, current operating systems lack 
support for these features.  Support was not included in Windows 
98 Second Edition, and is not expected in the initial release of 
Windows 2000 for CardBus or PC Card adapters.

A LAN connection diagnostic program for use under any Microsoft 
Windows operating system.

SNMP network management agent included - Allows a portable PC to 
be managed using SNMP-based network management software.

Models available:
-----------------

R2BE-100BTX     Supports both 10Base-T and 100Base-TX with an
                integrated RJ45 connector.
RBE-100BTX	Supports both 10Base-T and 100Base-TX with an
                integrated RJ45 connector.
CBE2-100BTX     Supports both 10Base-T and 100Base-TX with a
                single cable connector
CBE-100BTX      Supports both 10Base-T and 100Base-TX with a
                single cable connector


2) WHAT'S NEW IN THE 3.12 SOFTWARE RELEASE
==========================================

-Improved support for late model Toshiba laptops.

-NWay auto-negotiation is now user-configurable.  (See Section 4 
for details.) 

-Revised advanced driver keywords. 

-Improved DOS driver resource scan. 

-Improved automatic NDIS driver selection.

-The Realview utility is now included.  Documentation for all 
features are included in the Realview built-in context sensitive 
help.

-Includes CAT files that have been tested and certified by Microsoft 
Windows Hardware Quality Labs for Windows 98, Windows Me 
and Windows 2000.

 
3) NOTES REGARDING CARD AND SOCKET SERVICES
===========================================

The Personal Computer Memory Card International Association 
(PCMCIA) has developed specifications governing the use of PC 
Cards (formerly PCMCIA cards) in personal computer systems. The 
software components that implement these specifications are called 
Card and Socket Services.  This software supports the ability of 
PC Card- aware device drivers (known as clients) to share cards, 
sockets and system resources.

Xircom CardBus Ethernet Adapters support the following Card and 
Socket Services Software:

Windows 95
----------

Phoenix Card Manager 95 v. 4.0 for Windows 95 from Phoenix
Technologies Ltd.

SystemSoft CardWorks for Windows 95

Windows NT 4.0
--------------

CardExecutive for NT 4.0 from Phoenix Technologies

CardWizard for NT 4.0 from SystemSoft Corporation

PC Card Controller for NT from Softex Inc.

CardWare for Windows NT 4.0 from Award Software (full support if
version 6.0.015 or later)


Using CardWizard for NT 4.0 from SystemSoft Corp.
-------------------------------------------------

The default NT 4.0 NDIS4 driver (as well as the alternative NDIS3 
driver) has built-in support for SystemSoft CardWizard.  No 
special drivers or procedures are needed.  When installing under 
CardWizard the correct driver is located in the root of the CD-
ROM, or of Floppy Diskette 2 if installing from floppy.


Using Card Executive for NT 4.0 from Phoenix Technologies
---------------------------------------------------------

If using Phoenix Card Executive for NT 4.0, it is necessary to use 
a special driver, CBENT.SYS. This driver is found in the \CBENT 
directory of the CD-ROM, or of Disk 2 if using diskettes. When 
prompted by Card Executive for the driver, insert either the CD-
ROM or Disk 2 and browse to the \CBENT directory.

Note: It is recommended that when installing the driver from 
within the Card Executive application that you initially allow 
Softex to search for the drivers PRIOR TO actually inserting the 
CD or diskette. A message should appear indicating that the driver 
could not be found and then you will be prompted for the path. 
Enter the path to the \CBENT directory, insert the CD or diskette 
and continue. If this is not done, the application may not prompt 
you for the directory path, and the incorrect driver (CBEN4.SYS) 
may be installed from the root of the CD-ROM or diskette.   


Using PC Card Controller for NT 4.0 from Softex, Inc.
-----------------------------------------------------

Follow the above instructions for using Card Executive from 
Phoenix Technologies.   


Using CardWare for Windows NT 4.0 from Award Software
-----------------------------------------------------

If using Award CardWare for NT 4.0, it is necessary to use the 
standard NDIS4 or NDIS3 driver.  The NDIS4 driver is CBEN4.SYS and 
is found in the root of the CD-ROM and of Diskette 2. The NDIS3 
driver is CBE.SYS and is found in the \NDIS3 directory of CD-ROM 
and of Diskette 2. 

When using CBE.SYS or CBEN4.SYS with versions of Award CardWare 
prior to 6.0.015 the CardBus driver will co-exist with Award's 
software but full functionality including hot swapping and hot 
insertion are not supported.  Full support including hot insertion 
and hot swapping are available with Award version 6.0.015 or 
later.

DO NOT USE CBENT.SYS with Award CardWare.  It does not support
Award CardWare.


4) RELEASE NOTES/KNOWN LIMITATIONS
==================================

The version number for the entire release of this driver set is
version 3.12.  The following environments are supported:

Driver Name	  Description
-----------       -----------
		
CBE.SYS		  NDIS3 Driver for Microsoft Windows 95 (OSR2),
                  Windows 98 and NT 4.0
CBEN4.SYS	  NDIS4 Driver for Microsoft Windows 95 (OSR2),
                  Windows 98 and NT 4.0
CBEN5.SYS	  NDIS5 Driver for Microsoft Windows 98, 
                  Millennium and Windows 2000
CBENT.SYS	  NDIS3 Driver for use with NT 4.0 Card and Socket
                  Services supporting PCMCIA Proposal 187,
                  specifically Phoenix Card Executive and Softex
                  PC Card Controller.  
CBEODI.COM	  16-bit ODI Driver for DOS and Windows 3.X
CBE.LAN	          32-bit ODI Client/Server Driver for DOS,
                  Windows 3.X and Windows 95
CBENDIS.EXE	  NDIS2 Driver for Windows 3.X supporting 
		  LAN MANAGER, LAN REQUESTER and Lantastic 7.0
CBEODI.OS2	  ODI Driver for OS/2
CBENDIS.OS2	  NDIS2 Driver for OS/2
CBEPD.COM	  DOS Packet Driver
CBETEST.EXE	  DOS Diagnostic Test Program
CBEDIAG.EXE	  Windows Diagnostic Test Program (Windows 95
                  OSR2, 98, NT 4.0 and 2000 only)
APUNINST.EXE	  Xircom Utilities Uninstaller 


NWay auto negotiation changes
-----------------------------

This release features a new implementation of NWay auto 
negotiation.  NWay is an industry-standard way for hubs, switches, 
and network cards to automatically determine each other's speed 
and duplex capabilities, and set each device's communication 
settings to the fastest mutually supported speed.  In earlier 
driver releases, as is normal in the industry, forcing the speed 
and duplex settings completely disables auto negotiation.  This 
was done because the forced settings were meant as a backup when 
connecting to older non- NWay devices.  When forced settings are 
used when connecting to other NWay devices, (perhaps to restrict 
bandwidth), the other device must also have it's speed and duplex 
settings forced as it cannot reliably sense the settings without 
negotiation messages.  

In this driver release NWay negotiation is active by default 
whether or not the settings are forced.  Other NWay devices, even 
in auto mode, will be able to determine your card's settings and 
negotiate to match them.  In cases where the standard behavior is 
not successful, some early NWay devices and non-NWay devices do 
not always respond well to negotiation signals.

A new keyword, Line Negotiation, can eliminate the negotiation 
messages when the settings are forced.  The forced + no 
negotiation messages settings also allow immediate link if 
required by any special circumstances.  

The keywords and their settings are as follows:

Keyword              Settings             Behavior 
-------              --------             ---------

Line Configuration   Auto (default)       Full NWay negotiation, 
                                          Line Negotiation keyword
                                          ignored.
                     100 Mbps/Full Duplex
                     100 Mbps/Half Duplex
                     10  Mbps/Full Duplex
                     10  Mbps/Half Duplex

Line Negotiation     On (default)         NWay messaging sent in 
					  all modes 
					  
		     Off                  NWay messaging disabled 
		                          if Line Configuration 
		                          is forced		  
					   

Automatic NDIS Driver Selection
-------------------------------

This driver release now supports automatic NDIS version selection 
for installs under Windows 9x and Windows 2000.  For installs 
under Windows 9X or Windows 2000, direct the install to the root 
of the CD (or of floppy disk 1) when the drivers are requested.

The network property page tab of the CBE/RBE has a new entry
"NdisVersion".  This entry contains the following:

Under

Windows 95OSR2: AutoSelect, NDIS3, NDIS4
Windows 98: 	AutoSelect, NDIS3, NDIS4, NDIS5
Windows 98SE: 	AutoSelect, NDIS3, NDIS4, NDIS5
Windows 2000:   "NdisVersion" does not exist and NDIS5 is the
                default driver. The NDIS Switcher is not used
                with Windows 2000.

AutoSelect (the default) will choose the highest NDIS version 
supported by the OS.  The user can also manually switch between 
the different supported versions of NDIS by going to NdisVersion 
in the network properties of the adapter and selecting the desired 
driver. Only drivers supported by the particular OS will be shown.

NOTE:  NDIS switching is not supported in Windows NT 4.0.  The 
NDIS4 driver will be installed by default by pointing to the root 
of the CD or of Disk 1 if diskettes are created.  The NDIS3 driver 
may be installed by pointing to the \NDIS3 subdirectory.


TCP/IP Routing
--------------

This release contains a resolution for TCP/IP problems that occur 
when the same network is accessed via a LAN connection and then 
subsequently via a remote dial-up connection in Windows 95/98. 
Typically, when the computer is connected to the network via the 
LAN, routing tables are constructed that direct packets intended 
for the network to the LAN interface. If the computer is then used 
remotely and an attempt is made to connect to the same network via 
dial-up networking, these packets may not be routed to the dial-up 
interface because the presence of the active LAN interface results 
in the system continuing to route packets to it instead.  In such 
instances, the simplest solution is to remove the LAN interface 
from the computer, or to use a network disabled profile.  If 
neither of these solutions is satisfactory, a third option is now 
available.

The drivers included with this release now support a new 
configuration keyword named "DynamicLinkDetect" to overcome this 
difficulty. The value of this keyword (ON or OFF) can be set by 
going to Control Panel/Network/Network of Xircom.../Properties 
/Advanced. The default value is ON. The activity governed by this 
keyword operates as follows:

ON - The Ethernet interface is always active once the driver 
initializes the adapter. An Ethernet cable need not be connected 
to the port at boot time for the network side of the adapter to 
initialize. If the cable is plugged in later or unplugged and then 
re-connected, the adapter will dynamically detect the presence of 
the link and connect to the LAN. This is the setting recommended 
unless the symptoms described above are encountered.

OFF - The driver will only initialize the Ethernet interface if an 
active connection to the network is present at boot time. If the 
presence of an active link is not detected, the Ethernet portion 
of the card will shut down. The OS will "assume" that the 
interface is not present, and no packets will be routed to it.  As 
a result, the IP routing trouble discussed previously should be 
eliminated.


Auto Polarity Correction
------------------------

Certain 10/100 switches (generally those using Broadcom 
transceivers) implement automatic correction for polarity reversed 
cables that is not completely compatible with the same correction 
provided by the CBE/RBE.  If the network speed is forced to 
10Mbps, severe throughput problems may be experienced.  To resolve 
this problem, a new Auto Polarity keyword in the adapter's 
advanced properties has been added. If needed, the default setting 
of ON (meaning that the card will compensate for reversed cables) 
can be set to OFF to disable polarity correction. This will 
restore normal throughput.


Initialization Delay
--------------------

Certain switches and routers are unable to immediately forward 
network traffic when a network adapter first establishes link to 
one of their ports due to initialization delays (generally while 
routing tables are being updated).  This problem is most commonly 
seen when the network adapter is connected directly to ports on 
the switch.  This may cause an initial DHCP request to fail or 
prevent login to a server.  

The adapter by default (when used under some operating systems) 
will have almost no delay between link and the initial network 
request.  A new keyword, Initialization Delay, has been added to 
the adapter's advanced properties which will prevent forwarding of 
network requests for a user-selectable period of time.  Delays can 
be added ranging from one to sixty seconds.  In most cases adding 
a delay in the one to three second range will be sufficient to 
resolve the problem.   


Known Limitations  
-----------------

Support for O2Micro chipsets under NT 4.0 requires that the
laptop BIOS initialize the CardBus controller as a PCI device
and set up PCI routing. 

In order to connect to a 100Base-TX Ethernet network, a Category 5 
unshielded twisted pair (UTP) network cable terminating in a male 
RJ-45 connector must be connected to a 100Mbps hub or switch. 
Check with your LAN Administrator if you are not certain of your 
network speed and infrastructure.

The Xircom CardBus Ethernet 10/100 Adapters are designed to 
connect to a 100Base-TX network. They do not support 100VG-AnyLAN 
or 100BaseT4 networks.

When running the LAN Requester install, the CBENDIS.EXE file does 
not get copied to the NET directory. The file needs to be manually 
copied from the CD-ROM to the NET directory on the user's hard 
drive.

When running the Lantastic 7.0 install, the CBENDIS.EXE file does 
not get copied to the LANTASTI directory. The file needs to be 
manually copied from the CD-ROM to the LANTASTI directory on the 
users hard drive.

The 32-bit ODI driver (CBE.LAN) supports promiscuous mode. There 
is one limitation in its support. Fragment errors are captured, 
but they are classified, counted and reported as undersized 
errors. Therefore, the total count for undersized errors includes 
the total of undersized and fragment errors.

When using Award CardWare for NT 4.0 with CBE.SYS or CBEN4.SYS, 
the driver will co-exist with Award's software but not hot swap or 
hot insert unless Award version 6.0.015 or later is used.

When using the Packet Driver with the Intel 10/100 Stackable hub, 
network connections may be lost at 10Mbps.

When attempting to use CBE or CBE2 with a second PC Card 16-bit 
adapter e.g. modems, flash cards, ATA cards) in the other slot, it 
may be necessary to boot up with CBE or CBE2 first then hot- 
insert the second adapter.


5) USING THE CBE/CBE2/RBE/R2BE IN WINDOWS 2000
==============================================

 Note:  Windows 2000 does not have built-in drivers for the R2BE-
 100, and the update procedure given in steps 1, 2, and 3 below 
 does not need to be followed for the R2BE.  The R2BE may be 
 installed directly from this driver set by pointing to the root 
 of either the CD-ROM or of Disk 1 when Windows requests the 
 drivers.  The correct driver will automatically be installed. 
 Then continue with step 4 below.

Windows 2000 contains built-in drivers for the Xircom CBE, CBE2 
and RBE as well as many other Xircom Cards.  The built-in drivers 
are functional but lack some features of this release.  To update 
the Windows 2000 driver do the following:

1.  You will need to have the Xircom CBE/CBE2/RBE/R2BE installed 
and inserted in the laptop to proceed.  Go to 
Start/Settings/Control Panel, double click on Network and Dial-up 
Connections, and double click on Local Area Connection.  Select 
Properties.

2.  Click the Configure button on the top of the Local Area 
Connection Properties screen, just under the "Connect using:" 
listing for the Xircom CardBus Ethernet Adapter 10/100.  Next 
select the Driver tab, and click the Update Driver button. This 
starts the Upgrade Device Driver Wizard.  Click Next.  On the next 
screen select  "Search for a suitable driver for my device 
(recommended)".  Click Next. On the Locate Driver Files screen, 
select "Specify a location", and click Next.  Enter the path to 
the Xircom driver CD, diskette, or directory where you extracted 
the files.  For example, if you were installing from the CD and 
your CD-ROM drive was drive D, you would enter "D:\".

3.  The Wizard will announce that it has a suitable driver already 
installed, and that it has also found other drivers suitable for 
this device.  Select the "Install one of the other drivers" check 
box and click Next.  You will then see a screen showing both the 
Microsoft-provided driver, and the new Xircom driver (identified 
as Xircom Ethernet Adapter 10/100, and with a path listed to your 
driver CD or diskette).  Select the Xircom driver, and click Next.

4.  You will then be notified that Microsoft has not digitally 
signed the software, and asked if you want to continue the 
installation. Click Yes.  The updated drivers will then be copied 
to your computer.  Click Finish, and then click Close.  Click OK 
to close the Local Area Connection Properties box.  Reboot the 
machine to utilize the new driver.  By following step 1 above, 
clicking the Configure button, and selecting the Advanced tab you 
may now access the new driver settings.


  
6) MACHINE SPECIFIC NOTES
=========================

Visit the Xircom web site for the latest machine specific
information.

CardBus adapters require a portable computer with a CardBus PC 
Card Slot.  For a list of CardBus portable computers, visit 
Xircom's web site at www.xircom.com.  Most laptops introduced 
after January 1997 incorporate CardBus PC Card slots.  If you're 
not sure if your system supports CardBus, visit the Xircom web 
site or contact the manufacturer of your laptop.

Machines using O2Micro CardBus chipsets
---------------------------------------

O2 Micro controllers cannot be used with CardBus adapters under 
Windows NT unless the BIOS of the laptop initializes the 
controllers as PCI devices and sets up PCI routing.  Several 
manufacturers have released or are in the process of releasing 
BIOS updates to provide compatibility with NT 4.0.  If you desire 
to run NT on one of these laptops, contact the manufacturer for 
more information.

Compaq Armada 1580
------------------

If using the DOS 16-bit drivers, it is necessary to insert the
CBE in the bottom slot

NEC Versa LX and SX
-------------------

Support for CardBus cards in these laptops in either NT or DOS 
requires the use of the following Laptop BIOS versions or later. 
Note that the reported BIOS version will be 420000 after these 
updates are installed.

Versa LX PII- 2.45.15, 1-27-99 Versa LX MMX- 2.44.15, 1-27-99 
Versa SX PII- 2.47.15, 1-27-99 Versa SX MMX- 2.46.15, 1-27-99

Texas Instruments Extensa 650, 660 and 900 ------------------------
------------------

If using the DOS 16-bit drivers on the TI Extensa 650, it is 
necessary to insert the CBE in the top slot. If using the DOS 16-
bit drivers on the TI Extensa 660 and TI Extensa 900, it is 
necessary to insert the CBE in the bottom slot.

Toshiba Satellite Pro 490
-------------------------

On the Satellite Pro 490, it is necessary to set the CBE2 Address 
mode to Memory mode. To do this, run Control Panel, Network. 
Highlight the Xircom CardBus Ethernet adapter and click on 
Properties.  Go to the Advanced tab. Under Property, highlight 
Address Mode and change the value from IO to Memory. Click OK. The 
system will need to reboot for the change to take affect.

                          
7)  SNMP AGENT 
==============

    Xircom provides SNMP support for the Xircom CardBus Ethernet
    Adapters.

    To use the agent under DOS, follow these instructions:
    ------------------------------------------------------

    1.  Copy all of the contents of the SNMP directory on the CD-
    ROM to your hard disk drive, typically to the \NWCLIENT 
    directory.

    2.  Edit the SNMP.CFG file and add the correct IP address and 
    other configuration information. Contact your system 
    administrator if necessary.

    3.  Edit the NET.CFG file (typically in \NWCLIENT) to
        include:
        Frame Ethernet_II

    4.  After the LAN driver is loaded, load the SNMP driver, 
    XAGENT_O.EXE, by changing to the directory where it exists, 
    typing XAGENT_O and press ENTER. 
    
    Alternatively, add the following line to AUTOEXEC.BAT: 
    
            CD\NWCLIENT XAGENT_O 
    
    Note: 
    You must change to the directory (NWCLIENT) before loading the 
    driver, otherwise it won't load properly.

    To use the agent under Windows 95, follow these instructions:
    -------------------------------------------------------------

    1. First install the Microsoft SNMP agent:

    For Win95:
    Control panel ->  Network ->  Add ->  Service ->

    either:
    Microsoft -> SNMP Agent
    or:
    Have disk ->
    WIN95CD\\admin\nettools\snmp

    2. Then install the Xircom Extension agent:

    Control panel ->  Network ->  Add ->  Service ->
    Have disk ->

    3. Insert the Xircom Installation CD-ROM or diskette   

    Enter the path to the CD-ROM or diskette.

    Select:

    Xircom SNMP extension agent ->
    OK

    To use the agent under Windows NT, follow these instructions:
    -------------------------------------------------------------

    1. First ensure that the NT network has been installed and
       configured with:

       -NWLINK IPX/SPX;
       -TCP/IP (with SNMP Service);

    2. For Windows NT:
       Main ->  Control panel ->  Network ->  Add Software ->

    3. Select "Other" from the Add Network Software menu, click
       on "continue"

    4. Insert the Xircom Installation CD-ROM or diskette and
       click OK
   
    5. The "Xircom SNMP Mobile Extension Agent" appears in the
       Select OEM Option window

    6. Click OK and complete the installation 

    7. Reboot  
    

8) SCO UNIX Support
===================

    Xircom CardBus PC cards are certified for use with SCO UNIX 
    OpenServer 5.X and SCO Unixware 7.1X.  Drivers may be 
    downloaded from the Xircom driver download area 
    at www.xircom.com.

9) LINUX SUPPORT
================

    Drivers for Xircom products under Linux are currently 
    developed and supported by the Linux On Line Community.  The 
    latest status on driver development may be found at:

    http://pcmcia.sourceforge.org/cgi-bin/HyperNews/get/     
    pcmcia/xircom.html


10) XIRCOM TECHNICAL SUPPORT
===========================

    To obtain technical support for your Xircom product, please
    call or send a facsimile to the appropriate number
    listed below.

    
XIRCOM CORPORATE - North and South America
----------------------------------------------------------------
Xircom, Inc.                 
Corporate Headquarters       
2300 Corporate Center Dr.    
Thousand Oaks, CA  91320     

Shipping Address:            
2101 Corporate Center Dr.    
Thousand Oaks, CA  91320     

24-Hr E-mail    cs@xircom.com

Sales Support.............(800) 438-4526
Sales Support.............(805) 376-9300
Technical Support..........(805) 376-9200
24-Hr Fax - Corporate.....(805) 376-9311
24-Hr Fax - Sales Support (805) 376-9220
24-Hr Fax - Cust. Support (805) 376-9100
                            

24-Hr Internet     http://www.xircom.com

HOURS (Sales):   8 a.m. to 5 p.m., Mon-Fri
HOURS (Support): 5 a.m. to 5 p.m., Mon-Fri  


XIRCOM EUROPE - Europe, Middle East, and Africa
-----------------------------------------------------------------

Xircom Europe N.V.           
Veldkant 31                  
B-2550 Kontich, Belgium      

Sales Support........ +32/(0)3 450.08.11
24-Hr Fax............ +32/(0)3 450.09.90

Technique Support Telephone Numbers
Native English........ +32/(0)70 233 307
Native German......... +32/(0)70 233 850
Native French......... +32/(0)70 233 851
Native Dutch.......... +32/(0)70 233 852
24-Hr E-mail............ eurots@xircom.com
24-Hr Internet...... http://www.xircom.com
HOURS (Sales):   9:00 to 17:00, Mon-Thu; to 16:00, Fri
HOURS (Support): 9:00 to 18:00, Mon-Fri  


Regional Sales and Marketing Offices 
-----------------------------------------------------------------

Xircom France SARL           
41 bis avenue de l'Europe    
BP 264
F - 78147 Velizy CEDEX
France
Sales Support......... +33/(1) 34 63 09 40
24-Hr Fax ............ +33/(1) 34 63 09 41

Xircom Deutschland GmbH      
Airport Business Center      
Am Soldnermoos 17
85399 Hallbergmoos
Germany
Sales Support........ +49/(0)89 607 68 350
24-Hr Fax ........... +49/(0)89 607 68 355

Xircom Italy SRL             
Via Giovanni da Udine, 34    
20156 Milano
Italy
Sales Support.......... (+39) 02 3809.3605
24-Hr Fax.............. (+39) 02 3809.3606

Xircom AB                    
Kanalvagen 10C               
S - 194 61 Upplands Vasby
Sweden
Sales Support........ +46/(0) 8 590.332.80
24-Hr Fax ........... +46/(0) 8 590.717.81


Xircom U.K. Ltd.             
Worting House                
Basingstoke
UK - Hampshire RG23 8PY
Sales Support........ +44/(0) 1256 332 552
24-Hr Fax ........... +44/(0) 1256 332 553  


XIRCOM ASIA PACIFIC            Asia Pacific
----------------------------------------------------------------

Xircom Asia Pacific (Pte) Ltd
1 Kim Seng Promenade #15-01  
Great Word City East Tower   
Singapore 237994         
  
Sales Support................ +65 732 5001
Customer Support............. +65 732 2245
24-Hr Fax ................... +65 732 5002

24-Hr Internet...... http://www.xircom.com
24-Hr Email...... http://asiats@xircom.com
HOURS:  9:00 to 17:00, Mon-Fri   


Regional Sales and Marketing Office
-----------------------------------

Xircom Australia Pty Ltd     
Level 12, 80 Mount Street    
North Sydney, NSW 2060       
Australia                    

Sales Support............. +61 2 8923 7000
Customer Support.......... +61 2 8923 7090
24-Hr Fax................. +61 2 8923 7099
24-Hr Data Lines - BBS.. +61(02) 9911 7758
24-Hr Email...... http://aunzts@xircom.com

Xircom - Japan
----------------------------------------------------------------

Xircom Japan KK              
Tohtam Building 2F           
3-10-5 Shibuya               
Shibuya-ku Tokyo 150-0002    
Japan                        

Sales Support............. +81-3-3407-0033
Customer Support...... +81 (0) 3 3407-1900
24-Hr Fax................. +81-3-3407-0180
24-Hr Internet...... http://www.xircom.com
24-Hr Email.... http://japan_ts@xircom.com
HOURS:  9:00 TO 17:00, Mon-Fri   
       

WORLDWIDE ELECTRONIC SUPPORT
----------------------------------------------------------------
cs@xircom.com...........US Customer Support
eurots@xircom.com.......European Customer Support
asiats@xircom.com.......Asia/Pacific Customer Support
aunzts@xircom.com.......Australian/New Zealand Customer Support
japan_ts@xircom.com.....Japan Customer Support
sales@xircom.com........Xircom Sales
---------------------------------------------------------------

Thank you for making Xircom a part of your network.

Xircom acknowledges all tradenames and trademarks used in this
document as the property of their respective owners.

GJ 8-29-00 15:00 =================end========================