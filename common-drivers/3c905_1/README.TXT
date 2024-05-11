                        3Com (R) Corporation
3C90x 10 Mbps and 10/100 Mbps PCI NIC Family
Release Notes and Frequently Asked Questions

------------------------------------------------------------

The EtherCD version 5.4 CD supports 3Com 10 Mbps 
and 10/100 Mbps PCI bus-mastering network interface
cards (NICs) with a common driver set.  Key product
features include:

-   Parallel Tasking II (R) architecture for high performance
-   Bus mastering for low CPU utilization and optimal overall 
    system performance 
-   Automatic selection of media type and link speed  for 
    10/100 Mbps NICs
-   Full duplex enabled for switched 10/100 Mbps environments
-   Broad driver support, including NetWare, NDIS 2.01, 
    NDIS 3.0, NDIS 4.0, NDIS 5.0, and others 
-   SNMP manageability
-   Lifetime limited warranty 


Release Notes and Frequently Asked Questions
-----------------------------------------------------------
This file contains release notes and answers to some frequently
asked questions to help you obtain maximum performance from 
your 3Com NIC.  This information is updated regularly on the 
3Com World Wide Web site (www.3Com.com).


    Release Notes
    ---------------------

         >>>DynamicAccess LAN agent and 
         Windows Millennium Edition (Me)
        
        DynamicAccess LAN agent software is not supported 
        on PCs running Windows Me.  If you tried installing 
        DynanmicAccess LAN agent on a Windows Me PC, 
        you may lose network connectivity.  To resolve this,
        remove the DynamicAccess LAN agent software:

        1.  Open the Add/Remove Programs icon in the 
             Windows Control Panel.
        2.  Select the DynamicAccess Software entry, and 
             then click Remove.
        3.  Reboot the PC when prompted.
       

        >>> Installing ODI 32 LAN driver supporting multiple 
        3C905B or 3905C NICs
               
        If you are using the ODI 32 LAN driver in a system with 
        more than one 3C905B or 3C905C NIC installed and you
        are using Novell server revision 5.1, you need to upgrade 
        the Novell 5.1 server to either Service Pack 1 or Novell 5.1 
        International versions.  If this upgrade is not done and you
        unload the ODI 32 LAN driver, the server will abend.

      
        >>> Warm booting with the DOS-based drivers running

        3Com has found that some older systems do not reset the 
        PCI Bus when the <CTRL>+<ALT>+<DEL> key combination
        (a "warm boot") is used to restart the PC.  If the system 
        does not reset the PCI Bus when a warm boot occurs, the 
        3Com NIC remains in a running state that can cause problems
        if there is any network activity before the driver is reloaded. 
        This problem can be avoided by pressing the PC's reset 
        button (if your PC has one) or by  turning the PC completely off 
        before restarting. 


        >>> DOS diagnostics incompatibility with 3C905B NIC in 
        Plug and Play PCI computers

        During testing, 3Com encountered incompatibilities with the 
        3C905B&C NIC family and the some PCs when loading the 
        3Com DOS Configuration and  Diagnostics program. This 
        happens when the PnP OS option is enabled in the BIOS 
        settings.  When the computer is booted, configuration 
        resources are not assigned to the NIC.  3Com recommends 
        that you change the PnP OS setting to disabled, save that
        configuration, reboot the computer to DOS, then run the 
        3Com DOS Configuration and Diagnostic program.
 

        >>> Network Test using a crossover cable

        The Network Test in the 3Com Diagnostics program for 
        Windows verifies the NIC's ability to transmit and receive 
        data while on the network.  There are two ways to perform
        the test:

        --Connect two PCs to the same network (using a hub 
           or switch).
        --Connect two PCs directly to each other using a 
           crossover cable.

             Connecting Two PCs to the Same Network
             -----------------------------------------------
             1. Connect one PC (the echo server) and another PC 
                (the echo client) together through a hub or a switch
                that generates a constant link beat.

             2. Set each NICs' Media Type and Duplex settings
                  to AutoSelect.

             3. Run the test.

            Connecting Two PCs Using a Crossover Cable 
            -----------------------------------------------
            1. Connect the two PCs together using a crossover cable.

            2. Manually set the Media Type to 10 Mbps or 100 Mbps 
                and the Duplex mode to full or half duplex.

            3. Run the test.  


        >>> Error: " Invalid PCI Interrupt Level, Probable Hardware 
        Incompatibility while executing DOS diagnostics"

        3Com has observed that some PCs may display the above 
        error message when the 3Com DOS Configuration and 
        Diagnostics program is launched. To avoid this problem, 
        the "Plug & Play O/S " option should be disabled in the 
        system BIOS. Consult your PC's documentation for the
        proper steps to disable this option.


        >>> DOS Configuration and Diagnostics program unable 
        to recognize 3C90x NICs in Windows NT 3.51, 
        Windows NT 4.0, Windows 2000, and Windows XP.

        3Com has observed that the 3Com DOS Configuration and
        Diagnostics program does not recognize 3C90x NICs when
        running under a DOS window  using Windows NT 3.51, 
        Windows NT 4.0, or Windows 2000.  To avoid this problem, 
        boot your PC with a DOS-bootable diskette and then launch 
        the program.


        >>> When running the 3Com DOS Configuration and 
       Diagnostics program on a NIC with an MBA boot ROM 
       installed, the N-WAY Auto Select option sometimes 
       disappears from the list.

         Re-run the diagnostics program without rebooting.  This
         restores all available settings.  This situation was observed 
         intermittently on multiple machines but does not have any
         impact on the performance of the NIC.


        >>> When running the 3Com DOS Configuration and 
        Diagnostics program, the diagnostic tests take the NIC 
        off-line and force the link to 10 Mbps Half Duplex. 

        Running the Group1 test forces a link renegotiation and the
        correct speed is set.  Link renegotiation can also be forced by 
        disconnecting and reconnecting the cables.  These change of 
        states can be observed  with the NIC link (LNK) LED and the 
        switch port status.

        This scenario was observed only when the NIC was set to 
        NWAY - Auto and connected to a LinkSwitch 3000 port that was 
        also set to auto negotiate.  This situation does not have any 
        impact on the performance of the NIC.


        >>> Error when running the 3Com DOS Configuration and 
        Diagnostics program from a DOS window under Windows 98

        To avoid possible errors, 3Com suggests booting from a 
        DOS-bootable diskette when running the DOS diagnostics 
        program.  Alternatively, the DOS diagnostics program can be 
        run by rebooting your PC in  "Safe Mode - Command Prompt Only".


        >>> 3C90x-COMBO NICs require a reboot to reestablish 
        network connectivity when switching between ports on the 
        NIC

        When changing from one port to another on a 
        3C90x-COMBO NIC, you must reboot your PC to establish 
        a network connection. This includes any change from AUI 
        or BNC to TP, TP to BNC or AUI, and any changes between
        BNC and AUI.


        >>> Intermittent LED behavior on 3C905B NICs

        3Com has observed that your PC must be power cycled after 
        you have changed speed settings from 10 Mbps to 100 Mbps. 
        The reboot allows the LEDs to indicate the correct speed settings.


        >>> Client 32 installations in Windows 98

        3Com does not recommend using the ODI LAN driver for 
        Client 32 installations under Windows 98.  The Windows NDIS 
        driver should be used instead. 


         >>> Changing media type or duplex mode in the 3Com 
         NIC Diagnostics program for Windows using the NDIS 3
         driver in Windows 95 (Retail)

        When you change the media type or duplex mode using
        the 3Com NIC Diagnostics program for Windows, you must 
        exit the diagnostics program and reboot the PC for the 
        changes to take effect.


        >>> DynamicAccess control panel icon is disabled after 
        removing the 3Com NIC Diagnostics program

        If you remove the 3Com NIC Diagnostics program on a
        PC running Windows 98 or Windows 95 (OSR2) with the
        DynamicAccess LAN agent installed, the DynamicAccess 
        control panel icon will be disabled.  Remove and reinstall
        the DynamicAccess LAN agent to fix the problem.


        >>> Installing the DynamicAccess LAN agent in a 
        Windows 95 PC that does not have a NIC installed

        Do not install the DynamicAccess LAN agent on a PC that 
        does not have a NIC installed.  Doing so results in the 
        following error message:

        "3Com Dynamic Access Software did not install successfully. 
         From the start button run DAW95RMV.EXE..."

        Do not run the DAW95RMV.EXE program.  See the DynamicAccess 
        Software User Guide, located with the DynamicAccess LAN agent 
        software on the EtherCD, for instructions on how to remove the 
        DynamicAccess LAN agent.


        >>> Windows 95 and Windows 98 installation notes

        This information applies to Windows 95 and Windows 98 
        operating systems.

        When installing a 3Com NIC under Windows 95/98, the operating 
        system automatically detects the presence of the NIC and asks for 
        the diskette containing the driver software for the NIC (diskette 
        1).  At this point, you can choose to cancel the installation of 
        driver software and install it later.  Even though the driver 
        installation has been canceled, the fact that the NIC is installed 
        is recorded in the System Registry.

        Later, when you install the driver software using the Network icon 
        in the Windows Control Panel, the operating system assumes
        that you are installing another instance of a NIC, not installing 
        software for the already recorded instance.  This results in
        two instances of the NIC being recorded in the System Registry. 
        The 3Com NIC does not operate correctly under these 
        circumstances.

        To fix this problem, open the System icon in the Windows Control 
        Panel.  In the Device Manager, under Network adapters, the two 
        instances of the 3Com NIC are shown.  Remove the one that is 
        marked as disabled, and restart your computer. The entry for the 
        remaining NIC in the same dialog box should show that the NIC 
        is operating correctly.    

        >>> Windows NT 4.0 installation notes

        This information applies to Windows NT 4.0 operating systems.

        The oldest Windows NT 4.0 service pack that can be used with
        EtherCD 5.4 is Service Pack (SP) 4.  Some components require even
        more recent service packs.  Consult the help files for those
        components.



    Frequently Asked Questions (FAQs)
    -------------------------------------------------

        NOTE:  Specific FAQs for Remote Wake-Up are in the 
        WAKEFAQ.TXT file located in the HELP directory on the 
        EtherCD (or EtherDisk diskette 2).


        Q:  How do I remove the software that comes with my 
              3Com NIC if I have a compatibility problem?

        A:  You may remove the 3Com NIC Diagnostics program 
              from your system at any time by running the uninstaller 
              in the Windows Add/Remove Programs Control Panel.
              If you remove all of the 3Com NICs from the Control 
              Panel, the uninstall program runs automatically.


        Q:  Which PCI slot is best for my 3Com 10/100 PCI NIC?

        A:  3Com PCI NICs are designed to work in PCI slots that 
              support bus-mastering data transfers.  Refer to your 
              PC manual for information on which slots support 
              bus-mastering data transfers.


        Q:  Which PCI slot(s) are "bus mastering" in my PCI machine?

        A:  Generally, if you have three PCI slots in a machine, one slot 
              is designated as a "slave-only" slot (that is, it does not 
              support bus-mastering data transfers).  Slots are not always 
              marked clearlyto distinguish between slave-only and 
              bus-mastering slots.  Refer to your owner's manual or contact 
              your computer manufacturer for this information.  Also, make 
              sure that you have the latest version of your system's BIOS. 


        Q.  Does my PCI NIC support shared interrupts?

        A.  The drivers for the 3Com NICs support shared interrupts. 
              However, because there is no industry-standard way to 
              support shared interrupts, other NICs may support them
              differently, or not at all.  If you have another PCI NIC that 
              does not support shared interrupts (for example, a SCSI 
              host adapter), either contact the manufacturer for a shared
              interrupt driver or try running the system setup program
              to assign it a different interrupt.  

            3Com has found that OS/2 version 1.3 does not support 
            shared interrupts, but it is only a problem if you are using 
            the OS/2 NDIS 2.01 driver in LAN Manager version 2.2. 
            3Com has also found some problems with sharing
            interrupts under Windows 95. More details are available
            in the "Release Notes" section earlier in this document. 
            If this is a problem, try using the 3Com DOS Configuration 
            and Diagnostic program to give each NIC a different IRQ, 
            and change the BIOS on your system to match.


        Q:  What interrupts should I avoid using with my 3Com NIC?

        A:  You should avoid using any interrupts used by ISA/EISA 
            boards that do not properly support shared interrupts 
            (level-triggered).  If you do not know or are unsure 
            whether your devices supports shared interrupts, then
            avoid using them.  In addition, try to avoid using the 
            same interrupt as your local hard drive (normally 
            IRQ 14 for IDE drives and IRQ 11 for most SCSI
            host controllers), because not all hard drives support 
            shared interrupts at this time.  For Novell NetWare 
            servers, you should also avoid using IRQ 7 or 15.  
            These IRQs only support nonshared devices and 
            may cause problems if they are shared between two
            devices.   


        Q:  Are the 3Com ODI drivers Novell-certified?

        A:  Yes, 3Com's ODI drivers are Novell tested and
              approved.


        Q:  How do I update my 3C90x drivers in Windows?

        A:  Obtain the latest drivers from the 3Com Web site 
              (www.3com.com).  You can update the drivers using 
              the Update NIC Drivers option on the EtherCD.  See
              the user guide (UsrGuide.PDF) for instructions.


3Com Technical Support
-----------------------------------

Refer to the 3Com 10/100 PCI NICs user guide
(UsrGuide.PDF) for technical support information.  
This information is also available in the 
\HELP\SUPPORT.TXT file on the EtherCD
(or EtherDisk diskette 2).



-----------------------------------------------------------

3Com, EtherDisk, and DynamicAccess are registered trademarks 
of 3Com Corporation.


                  (%VER README.TXT - Release Notes v 5.4.5)
