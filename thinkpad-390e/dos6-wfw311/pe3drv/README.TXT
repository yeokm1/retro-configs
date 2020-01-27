.                XIRCOM POCKET ETHERNET ADAPTER III
.                       Release Version 3.53
.                           Sept 17, 1997
=====================================================================

Thank you for purchasing the Xircom Pocket Ethernet Adapter III (PE3).  
Xircom has done everything to ensure that our adapter is compatible
with the widest range of notebook and laptop PCs. As a company, we 
are equally committed to customer satisfaction and timely response 
to the needs and concerns of our customers.  

If you have compatibility issues related to your specific 
environment, or you have general questions, please contact Xircom
Technical Support.  Information on Xircom Technical Support is 
located at the end of this file.

Remember to register your Xircom adapter to receive information 
about future software upgrades and new products.


CONTENTS
========
   1) Features of this Release
   2) Novell NetWare ODI Driver Notes
   3) Microsoft Windows NDIS 3.0 Driver Notes
   4) Known Issues
   5) Machine Specific Notes
   6) Xircom Technical Support


1) FEATURES OF THIS RELEASE
   ===================
   New features of release 3.53 of the Xircom Pocket Ethernet 
   Adapter III Network drivers:

   - Includes new PE3NDIS.VXD driver which improves compatibility
     with Pentium 100MHz and faster processor machines.

   - Resolves Win95 installation issue with HP Omnibook 4000CT

   - Includes updated INF file for increased support of Windows for Workgroups 3.x


2) NOVELL NETWARE ODI DRIVER NOTES
   ================================

   Promiscuous Mode Support
   ------------------------
   The PE3ODI.COM driver passes all but one of the Novell
   Promiscuous Mode tests.  The only test which fails is the 
   "very short packet" test.  This can not be supported due to 
   limitations in the PE3 adapter hardware.


3) MICROSOFT WINDOWS NDIS 3.0 DRIVER NOTES
   ===========================================
   The Xircom adapter must be attached prior to starting Windows
   for Workgroups, Windows 95, and Windows NT and can not be 
   removed until the system is shut down.

   If you wish to use the parallel port for printing, the Xircom
   adapter must be removed prior to starting any Windows system.

   Windows 95
   ------------
   This version of the Xircom Windows 95 Driver (PE3NDIS.VXD) 
   contains improvements that are not in the driver available 
   on the Microsoft Windows 95 CD.

   Instructions are provided for manually installing the Xircom 
   network driver for the first time on a system using Windows 95
   alone or with NetWare. These instructions assume that Windows 
   95 and the Pocket Ethernet Adapter III hardware have already 
   been installed. Do not use the automatic hardware detection 
   feature of Windows 95. Remove any earlier version of the Xircom 
   drivers before installing the new version.

   The following topics are covered for Windows 95:

   - How to install for Windows 95 using the NDIS 3.0 driver
   - How to install for Windows 95 and NetWare

   Windows 95 using the NDIS 3.0 driver

   1. In the Windows 95 Control Panel, double-click the Network icon. 

   2. From the Configuration tab in the Network window, click Add. 

   3. From the Select Network Component Type window, select Adapter 
      and click Add. 

   4. From the Select Network adapters window, click Have Disk. 

   5. When prompted for the manufacturer's installation disk, insert 
      the Xircom Network Drivers diskette.

   6. Select "Xircom Windows 95" and click OK.

   7. Complete the installation process, inserting the Xircom Network 
      Drivers diskette if required.

   8. When asked if you want to restart the computer, click Yes.

   9. To verify successful installation, double-click the System icon
      in the Control Panel, choose the Device Manager tab in the 
      System Properties window, and look for Xircom Pocket Ethernet 
      III under Network adapters.

   An X or a circled exclamation point on top of the Xircom Pocket 
   Ethernet III icon indicates a problem. Select Xircom Pocket 
   Ethernet III and click Properties to see an explanation. Then 
   proceed to the troubleshooting heading that follows for additional
   information.

   If there is no X or a circled exclamation point on top of the 
   Xircom Pocket Ethernet III icon, the installation has been 
   successful. If you want to connect to a NetWare network, skip 
   to the heading "Microsoft Windows 95 and NetWare" below.

   Troubleshooting guidelines.

   1. To review the Adapter configuration, double-click the 
      Network icon in the Control Panel.

   2. Select the Xircom Pocket Ethernet III component and 
      click Properties. 

   3. From the Properties window, select the Advanced tab. 

   4. Confirm that the Properties and their associated Values are 
      correct and that there are no conflicts with other installed
      devices, using the bulleted steps below. 

     - Double-click the System icon in the Control Panel.
     - Choose the Device Manager tab. 
     - Double-click the Ports device, select the Printer Port, 
       and click Properties. 
     - Examine the Properties of the Printer Port. 
     - Choose the Resources tab to examine the information 
       necessary for proper Pocket Ethernet Adapter III 
       configuration, and to verify that there are no conflicts 
       with other devices.

    Windows 95 and NetWare

    1. Install the Xircom Pocket Ethernet Adapter III driver 
       and verify the installation as described above under the
       heading "Windows 95 using the NDIS 3.0 driver."

    2. In the Control Panel, double-click the Network icon.

    3. From the Configuration tab in the Network window, click Add.

    4. From the Select Network Component Type window, select 
       Client and click Add. 

    5. Under Manufacturers in the Select Network Client window, 
       select Microsoft.

    6. In the Network Clients window, select Client for 
       NetWare Networks. 

    7. Click OK (you will be returned to the Network window).

    8. From the Configuration tab in the Network window, click Add.

    9. From the Select Network Component Type window, select 
       Protocol and click Add. 

    10. Select Microsoft as the manufacturer and IPX/SPX-compatible
        Protocol under Network Protocols, then click OK to return 
        to the Network window.

    11. Click OK to close the Network window, then restart the 
        computer when prompted.

  
   Windows NT
    ----------
   This version of the Xircom NT Driver (PE3NDIS.SYS) supports 
   Windows NT Versions 3.5 and 3.51.  This driver contains 
   improvements that are not in the driver available on the 
   Microsoft Windows NT CD.

   Before installing the adapter and driver it is advised to 
   determine the I/O port number and interrupt level used by 
   your parallel port.  The easiest method to find out the I/O 
   port is to use the Windows NT utility WINMSD.  

   1. Start WINMSD.

   2. Click the "Devices" button.  

   3. Double click the "\Device\ParallelPortN" entry in listbox, 
      where N is 0 for LPT1, 1 for LPT2, etc.   The port will be 
      displayed in the last window.  

   LPT1 on most computers is port 378 and interrupt 7, and 
   interrupt 5 is used for port 278.  However, on IBM and  
   COMPAQ systems LPT1 is port 3BC and interrupt 7.

   It is not necessary to disable the NT Parallel driver.
   The network drivers load first and the parallel port 
   driver will be disabled automatically if a Xircom adapter
   is detected. At this point it is normal to see messages 
   in the Event Viewer indicating that the parallel port 
   was not started.

   If you wish to use the parallel port for printing, the
   XIRCOM adapter must be removed prior to starting Windows
   NT. If the Pocket Ethernet III driver is still installed
   you will see an error message that the driver failed to 
   load. Click OK to by-pass this message.

   If problems are encountered the Windows NT Event Viewer
   should be used to check the event log.  The Xircom driver
   logs errors indicating the cause of any problems.  


4) KNOWN LIMITATIONS
   =================

   The Novell 32-Bit DOS/WIN client is not compatible with the 
   PE3.LAN driver.   

   With some configurations, the PE3.LAN driver will generate 
   the error "Primary interrupt controller has detected a lost
   hardware interrupt" and the connection will be dropped.  

   The Xircom Parallel Port Multiplexor is not supported with NDIS
   3.0 Windows for Workgroups, Windows 95, and Windows NT drivers,
   nor OS/2 drivers.

   Enhanced Parallel Port (EPP) mode is not supported with NDIS 3.0
   Windows for Workgroups, Windows 95, Windows NT drivers.

   ECP (Enhanced Capability Port) mode is not supported.

   The PE3 only supports SCO UNIX version 3.0, no other versions will
   be supported.     

   The PE3 does not operate using I/O address 3BC. Xircom recommends
   using the LPT1, Interrupt 7 and I/O address 378.   


5) MACHINE-SPECIFIC ISSUES
   =======================

   IBM PS/2 Model 70, IBM ThinkPad 720, and ThinkPad 350
   -----------------------------------------------------
   These machines utilize a different implementation of the 
   parallel port which requires the "RDS" keyword to be placed 
   in the appropriate network configuration file.  
   
   The "RDS" keyword forces the driver to use the autofeed pin
   (pin14) as a data strobe.

   If you are using ODI, place the keyword in the NET.CFG file.
   If you are using NDIS, add it to the PROTOCOL.INI file.  Other 
   machines may also have this different implementation and
   may require this keyword to be added. 

   IBM ThinkPad 500 
   ----------------
   When using the Windows for Workgroups 3.11 NDIS 3.0 driver 
   (PE3NDIS.386) make sure that the parallel port setting is set 
   to OFF.  To do this, go to CMOS setup by pressing Func+F3.  
   Set the parallel port setting OFF (not Auto).  The port should 
   remain in this mode for it to function properly.  The driver 
   should then load normally.

6) XIRCOM TECHNICAL SUPPORT
   ========================

   To obtain technical support for your Xircom product, please call or
   send a facsimile to the appropriate number listed below.
   
   Access the Xircom TechLine quick-search database of problem
   solutions at up to 14400 bps, No parity, 8 data bits, 1 stop bit
   (N-8-1). Use ANSI for your terminal emulation (you must have
   ANSI.SYS loaded on your system to use the Xircom KnowledgeLine).
   
   Access the Xircom INFOSYS BBS at up to 14400 bps (28800 in the
   U.S.), No parity, 8 data bits, 1 stop bit (N-8-1).  Use ANSI, TTY, 
   or NONE for your terminal emulation as the Xircom BBS PCs do not 
   support DEC VT-type terminal emulation's.

   XIRCOM CORPORATE          North and South America
   ========================  ------------------------------------------
   Xircom, Inc.              Sales Support ............. (800) 438-4526
   Corporate Headquarters    Sales Support ............. (805) 376-9300
   2300 Corporate Center Dr. Technical Support ......... (805) 376-9200
   Thousand Oaks, CA  91320  KnowledgeLine ............. (805) 375-7202
   .                         24-Hr Documents-by-Fax .... (800) 775-0400
   .                         24-Hr Documents-by-Fax .... (805) 376-9020
   .                         24-Hr Fax - Corporate ..... (805) 376-9311
   Shipping Address:         24-Hr Fax - Sales Support.. (805) 376-9220
   2101 Corporate Center Dr. 24-Hr Fax - Tech Support .. (805) 376-9100
   Thousand Oaks, CA  91320  24-Hr Data Lines - BBS .... (805) 376-9130
   .                         24-Hr Internet E-mail ...... cs@xircom.com
   .                         24-Hr World Wide Web http://www.xircom.com
   .                         24-Hr CompuServe .......... CIS: GO XIRCOM
   .                         HOURS (Sales): 8:00a.m. to 5:00p.m.,
			     Mon-Fri 
   .                         HOURS (Tech):  5:00a.m. to 6:00p.m., 
                             Mon-Fri

   XIRCOM EUROPE             Europe, Middle East, and Africa
   ========================  ------------------------------------------
   Xircom Europe N.V.        Sales Support ......... +32/(0)3 450.08.11
   King Square               Technical Support ..... +32/(0)3 450.08.60
   De Villermontstraat 16    24-Hr Documents-by-Fax. +32/(0)3 450.08.00
   2550 Kontich, Belgium     24-Hr Fax ............. +32/(0)3 450.09.90
   .                         24-Hr Data Lines - BBS. +32/(0)3 457.64.10
   .                         24-Hr Internet E-mail .  eurots@xircom.com
   .                         24-Hr World Wide Web http://www.xircom.com
   .                         24-Hr CompuServe ............ GO XIRCOM
   .                         HOURS (Sales): 9:00 to 17:00, Mon-Thu;
                                            to 16:00, Fri
   .                         HOURS (Tech):  9:00 to 18:00, Mon-Fri
 
   XIRCOM ASIA PACIFIC       Asia Pacific
   ========================  ------------------------------------------
   Xircom Asia Pacific (Pte) Ltd Sales & Technical Support+65  323 1511
   76 Shenton Way                24-Hr Fax ...............+65  224 3313
   Unit #06-01                   24-Hr Data Lines - BBS.. +65  323 0455
   Singapore 079119              24-Hr World Wide Web 
                                 http://www.xircom.com
   .                             24-Hr CompuServe ........... GO XIRCOM
   .                             HOURS:  9:00a.m. to 5:30p.m.,  Mon-Fri

-----------------------------------------------------------------------

Thank you for making Xircom a part of your network.

Xircom acknowledges all tradenames and trademarks used in this document
as the property of their respective owners.

==================================[  END  ]==================================


