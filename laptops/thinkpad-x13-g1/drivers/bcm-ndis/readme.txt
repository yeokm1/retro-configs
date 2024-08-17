

                           ============================
                            R E A D M E    N O T E S
                           ============================


	                     Broadcom Ethernet Driver
                                       for
                                  DOS/OS2 NDIS2

                   Copyright (c) 2002-2013 Broadcom Corporation
		               All rights reserved.



CUSTOM KEYWORDS in driver in protocol.ini:

BusNum
DevNum
FuncNum or PortNum
LineSpeed
Duplex
NodeAddress
FixCheckSumOff
AcceptAllMC
NoTagStatus


BusNum:

This decimal parameter, range from 0-255, specifies the PCI bus number on which the
ethernet controller is located.

DevNum:

This decimal parameter, range from 0-31, specifies the PCI device number assigned
to the ethernet controller.

FuncNum or PortNum:

This decimal parameter, range from 0-7, specifies the PCI function or port number
assigned to the ethernet controller.

LineSpeed:

This decimal parameter, 10 or 100, specifies the speed of the network connection.

NOTE: According to IEEE specifications, line speed of 1000 can not be forced and its
      only achievable by auto negotiation.

Duplex:

This string parameter, HALF or FULL, specifies duplex mode on the ethernet controller.
The Linespeed parameter must be set when this keyword is used. If neither the Duplex
nor the Linespeed paramaters are specified the ethernet controller will default to
autonegotiate mode.

NodeAddress:

This string parameter specifies the network address used by the the ethernet controller.
If Multicast Address or Broadcast Address was specified, the default MAC Address will
be used.

FixCheckSumOff:

This string parameter turns off the driver's work-around for the TCP/IP stack to
recognize the 1's complimented version of the checksum.

AcceptAllMC:

This string parameter informs the driver to deliver ALL Multicast packets to the upper
Protocol.

NoTagStatus:

This string parameter sets driver NOT to utilize the default method Tag Status of handling
interrupts for none 5700 NIC. This helps stabilize on certain platforms when using with
protocol such as Netbeui and RPL.


NOTE: The first three keywords are used concurrently and have been included for 
      manufacturing purposes.  Do not use them unless you are familiar with PCI
      device configuration.
      These three keywords are needed if multiple NetXtreme boards are on a system 
      and (a) specific NetXtreme adapter/s need to be loaded in specific order.

      In addition to these three keywords, the driver has ability to detect and load on
      the NIC that has a good link. In case of multiple NICs with multiple good links,
      its will loads on the first NIC found with good link.


Example of the use of these key words in the protocol.ini:
		
[B57]
    DriverName = "B57$"
    BusNum = 3
    DevNum = 14
    PortNum = 2
    LineSpeed = 100
    Duplex = Full
    NodeAddress = "001020304050"

To add more adapter(up to 4) repeat the below entry, where n can be from 2 to 4.

[B57_n]
    DriverName = "B57n$"
    BusNum =
    DevNum =

Example of using addition entries to load more than one adapter in the protocol.ini:

[B57]
    DriverName = "B57$"
    BusNum = 3
    DevNum = 10

[B57_2]
    DriverName = "B572$"
    BusNum = 3
    DevNum = 11

[B57_3]
    DriverName = "B573$"
    BusNum = 3
    DevNum = 12

[B57_4]
    DriverName = "B574$"
    BusNum = 3
    DevNum = 13


NOTE: RPL boot up when using v1.13, the Boot Block Configuration file *.cnf MUST specify
      in the DRV Type's second field the additional memory (53KB-60KB) used by the driver
      as follows:

      DRV BBLOCK\NDIS\B57.DOS ~ 53 ~

NOTE: In some cases due to memory constraints the command NET START may not function
      properly.  For these situations NET START BASIC is recommended. For some applications
      that utilize "autostart" by using NET LOGON or NET USE, there are two keywords in the
      \NET\SYSTEM.INI file under heading [network] that will dictate which NET Service to
      run when using "autostart":

      1) preferredredir
      2) autostart

      Make sure these two keywords are as follows:
    
      1) preferredredir=basic
      2) autostart=basic
