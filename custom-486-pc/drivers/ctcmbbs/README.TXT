		Plug and Play Tips for DOS/Windows 3.1x
======================================================================

Welcome to the world of Plug and Play (PnP).

If you are going to install your Creative PnP card in a PnP system 
like Windows 95, you only need to "plug" the card into your personal 
computer and the card will "play" shortly after the system reboots.

However, if you want to install this card in a non-PnP environment 
such as DOS/Windows 3.1x, you need to use Creative PnP Configuration 
Manager (CTCM) and Creative PnP Configuration Utility (CTCU).

The information in this text file is organized as follows:
	1.  Installing CTCM & CTCU
	2.  Using CTCM
	3.  Using CTCU
	4.  The CTCU Interface
	5.  PnP Concepts
	6.  PnP in DOS/Windows 3.1x
	7.  Creative's Approach to PnP
	8.  Common Questions and Answers
	9.  Copyright Notice

======================================================================

1.  	INSTALLING CTCM & CTCU
    	----------------------
	To install CTCM and CTCU in DOS/Windows 3.1x:
	1. Insert the PnP Configuration Manager installation diskette 
	   into your floppy drive.
	2. Exit to DOS if you are in Windows 3.1x.
	3. Type A:INSTALL (or B:INSTALL if your diskette is in 
	   drive B:) and press <ENTER>.
	4. Follow the instructions on the screen to complete the 
	   installation.

	The installation program will install CTCM as a DOS device 
	driver by adding the following line to the CONFIG.SYS file:
		DEVICE=<C:\CTCM>\CTCM.EXE
	where <C:\CTCM> is the directory of your CTCM files.

	This CTCM statement will be placed before all the statements 
	that load other low-level device drivers (such as CTSB16.SYS 
	and SBIDE.SYS) so that your Creative PnP cards will be 
	configured before these device drivers try to use them.

	The installation program will also add the following lines to 
	the AUTOEXEC.BAT file:
 		SET CTCM=<C:\CTCM>
 		<C:\CTCM>\CTCU /S /W=<C:\WINDOWS>

	where <C:\CTCM> and <C:\WINDOWS> are the directories of 
	your CTCM/CTCU and Windows 3.1x files respectively.

	After the installation, CTCM and CTCU will be invoked each 
	time you boot your system.  CTCM will scan for and configure 
	Creative PnP cards.  CTCU will run in silent mode and update 
	the parameters needed by your Creative and Windows drivers.


2.  	USING CTCM
    	----------
	To re-configure a Creative PnP card:
	1. Exit to DOS if you are in Windows 3.1x; or shut down to 
	   MS-DOS Mode if you are in Windows 95.
	2. Change to the directory of your CTCM files.  The default 
	   directory is C:\CTCM.
	3. Type CTCM and press <ENTER>.
	   CTCM will configure your Creative PnP card(s) and update 
	   the BLASTER environment variable if it detects a Creative 
	   audio card in your system.

	NOTE: 	CTCM configures Creative PnP cards only.  But it can 
		work with or without another PnP configuration 
		manager installed in the same system. Just make sure 
		that the statement which invokes CTCM in your 
		CONFIG.SYS file is placed AFTER the statement that 
		calls the other configuration manager.


3.  	USING CTCU
    	----------
	Creative PnP Configuration Utility (CTCU) allows you to view, 
	free or re-allocate resources reserved for a card. So you 
	should run CTCU when one of the following situations happens:
	a. Your PnP cards' settings do not work properly.
	   For example, some systems do not support high DMA (Direct 
	   Memory Access). If one of your PnP devices is set to use 
	   high DMA, you need to run CTCU to select another set 
	   of configuration which does not use high DMA.
	b. You need to add resource settings for new and existing 
	   legacy (non-PnP) cards.
	c. You have changed the resource settings of legacy cards.
	d. You have removed a legacy card from your system.

	NOTE: 	CTCU does not access the resource settings database 
		used by ICM.  So, do not use CTCU to change or 
		disable your card settings if you already have ICM 
		installed and working properly.  Use ICU instead.

	To run CTCU in DOS/Windows 3.1x:
	1. Exit to DOS if you are in Windows 3.1x.
	2. Change to the directory of your CTCM and CTCU files.
	   The default directory is C:\CTCM.
	3. Type CTCU and press <ENTER>.
	   The CTCU interface appears.

	The CTCU command has two optional switches: /S and 
	/W=C:\<WINDOWS>.   You can type it in the following way:

	 	CTCU /S /W=<C:\WINDOWS>

	where <C:\WINDOWS> is the directory of your Windows 3.1x 
	files, and the switches are as follows:

	Parameter       Description

	  /S            Notifies CTCU to run in silent mode. 
	                This means that CTCU will not display any 
	                messages or screens.  It will simply update 
	                the parameters required by the Creative 
	                drivers.  If you do not use the /S switch, 
	                CTCU will run in full-screen mode.

	  /W            Informs CTCU to update the PnP hardware 
	                information of your Windows drivers in the 
	                SYSTEM.INI file.  If you do not use this 
	                switch, CTCU will prompt you to enter the 
	                name of the directory where your Windows 
	                files can be found.


4.  	THE CTCU INTERFACE
    	------------------
	When you run CTCU in full-screen mode, you can pull down the 
	menu to select one of the following sections:
	4.1  PnP Cards section
	4.2  Legacy Cards section
	4.3  System Devices section
	4.4  PCI Devices section

	You can use your mouse or keyboard to move around and select 
	an item or action in CTCU:

	Mouse Action
	- To pull down the CTCU menu or select an item in the menu or 
	  box using your mouse, click on the item. 

	Keyboard Action
	- To pull down the CTCU menu using your keyboard, press <ALT> 
	  followed by a key.
	  For example, to pull down the Menu, press <ALT, M>.
	- To select an item in a menu or box, use the arrow keys to 
	  move your screen cursor to that item.
	- To move your screen cursor from box to box within the same 
	  window, press <TAB>. To see more details about the item, 
	  double-click the item or press <ENTER> after you have moved 
	  your screen cursor to that item. 

	NOTE: 	The instructions in the following sections are written
		with the assumption that you will use your mouse in CTCU.


4.1  	PnP Cards Section
     	-----------------
	NOTE: 	You can use this section to view the resource settings 
		of the PnP cards in your system and change the settings 
		of Creative PnP cards only.

	When you select the PnP Cards section from the CTCU menu, the 
	Plug and Play window will appear, listing the PnP cards in the 
	system.  Choosing a card here will, in turn, display a list of 
	logical devices on that particular card. 

	To view the resources for a PnP device, double-click the device 
	you want.  Alternatively, select the device from the list and 
	click the Resources button.  The Resources window will appear.

	Resources Window
	----------------
	The Resources window displays the current resource settings of  
	a particular logical device.  The settings shown may include 
	input/output (I/O) ranges, interrupts, Direct Memory Access 
	(DMA) channels and 32-bit memory ranges, depending on the PnP
	card you have and the configuration chosen. 

	To change the resource configuration, click the down arrow 
	next to the Configuration box and then select a suitable 
	configuration which has all the settings that your card needs.

	To disable a logical device, click the Disable check box.  A 
	mark will appear in the box, informing CTCM not to configure 
	this device the next time it runs.

	Reconfigure Button
	------------------
	To view or change a resource setting, double-click the setting 
	you want, or alternatively, select the setting and click the 
	Reconfigure button in the Resources window.  Depending on the 
	setting that you have chosen, one of the following windows 
	will appear:
	a.  I/O Range window
	b.  Interrupt window
	c.  Direct Memory Access window
	d.  Memory Range window

	The I/O Range window displays the current I/O resource setting 
	and a list of possible settings.  To change this setting, 
	select one from the list.  Make sure that the new setting does 
	not conflict with the other cards' settings.  Then double-click 
	the new setting or click the OK button.

	The Interrupt window displays the current interrupt resource 
	setting and a list of possible settings.  To change this 
	setting, select one from the list.  Make sure that the new 
	setting does not conflict with the other cards' settings.  
	Then double-click the new setting or click the OK button.

	The Direct Memory Access window displays the current DMA 
	resource setting and a list of possible settings.  To change 
	this setting, select one from the list.  Make sure that the 
	new setting does not conflict with the other cards' settings. 
	Then double-click the new setting or click the OK button.

	The Memory Range window displays the current 32-bit memory 
	resource setting and a list of possible settings.  To change 
	this setting, select one from the list.  Make sure that the 
	new setting does not conflict with the other cards' settings. 
	Then double-click the new setting or click the OK button.

	NOTE: 	Each of these windows has a Conflicting Devices 
		message box which will inform you of any hardware 
		conflicts that may result from the settings you have 
		just selected for your card.

		To see the list of settings available in each window, 
		click the down arrow next to the Choices box.

	Test Button
	-----------
	Once you have reconfigured the resource settings of your card, 
	select the setting and click the Test button in the Resources 
	window.  CTCU will test the settings allocated to your device 
	and inform you of the outcome.

	If the testing is not successful, you should reconfigure and 
	test the settings again.

	NOTE: 	CTCU supports the testing of Creative's audio and 
		wavetable devices only.


4.2  	Legacy Cards Section
     	--------------------
	NOTE: 	You can use this section to enter, view or change 
		the resource settings of all the legacy (non-PnP) 
		cards in your system. 

	When you select the Legacy Cards section from the CTCU menu, 
	the Legacy window will appear.  You can view, alter or add a 
	legacy (non-PnP) card's resource settings by clicking one of 
	these buttons:
	a.  View All button
	b.  View button
	c.  Add button
	d.  Remove button
	e.  Change button

	View All Button
	---------------
	Clicking this button in the Legacy window opens the View All 
	window, which lists all the resources you have reserved in 
	your system. These resources are grouped by type and displayed 
	in four boxes: Input/Output range (I/O), Interrupt Request 
	line (IRQ), Direct Memory Access channel (DMA), and 32-bit 
	memory range (Mem).

	View Button
	-----------
	Clicking this button in the Legacy window opens the View 
	window which lists the resources reserved for a selected legacy 
	card in your system. 

	Add Button
	----------
	Clicking this button in the Legacy window opens the Add window 
	where you can enter details for a legacy card in your system 
	if it is not listed in the Legacy Window.

	NOTE: 	You must enter the card's name in the Card Name field.  
		The other fields can be left blank if the card does not 
		use that resource(s).

	Remove Button
	-------------
	Clicking this button in the Legacy window removes a selected 
	card's settings from your system.  Once the settings are 
	removed, you can proceed to remove the card from your system. 

	NOTE: 	To re-install the same card, you have to enter the 
		card's original settings again. 

		Alternatively, you can retain a card's resource 
		settings by simply marking the settings for retrieval 
		in the Change window (refer to the next section).

	Change Button
	-------------
	Clicking this button in the Legacy window opens the Change 
	window which displays the current resources that have been 
	reserved for a selected legacy card.  You can also change any 
	of the resources as well as the card's name here.

	NOTE: 	To store a card's system settings for future use, 
		select the Card Removed check box in the Change window 
		and click OK.  To re-use the same resources after 
		re-installing the card, simply clear the check box to 
		retrieve its original settings. 

	WARNING: Be very careful when you add or change resource 
		 information for a legacy card.  Verify that all the 
		 hardware settings of the legacy cards in your system 
		 tally with what have been specified in CTCM.  Filling 
		 in incorrect data may reserve resources which will not 
		 be used by any device.  In addition, CTCM would not be 
		 informed of resource(s) actually reserved by the 
		 legacy card.  This may in turn lead to resource 
		 conflicts.


4.3  	System Devices Section
     	----------------------
	NOTE: 	You can use this section to view but not change the 
		resource settings of the system devices in your computer.  

	When you select the System Devices section from the CTCU menu, 
	the System Device Resources window appears, listing all the 
	resources used by your system devices.

	These resources are grouped by type and displayed in four boxes: 
	input/output range (I/O), interrupt (IRQ), Direct Memory Access 
	channel (DMA) and 32-bit memory range (Mem).


4.4  	PCI Devices Section
     	-------------------
	NOTE: 	You can use this section to view but not change the 
		resource settings of the PCI devices in your computer.

	When you select the PCI Devices section from the CTCU menu, 
	the PCI Devices window appears. You can view one or all of 
	existing PCI cards' resource settings by clicking one of these
	buttons:
	a. View All button
	b. View button

	NOTE: 	Peripheral Component Interconnect (PCI) local bus is a
		newly developed bus system that utilizes a 33MHz 32-bit 
		data path.  This bus architecture transfers data at a 
		much faster rate than standard ISA bus. 

	View All Button
	---------------
	Clicking this button in the PCI Devices window opens the View 
	All window, which lists all the resources used by the PCI cards 
	in your system.

	View Button
	-----------
	Clicking this button in the PCI Devices window opens the View 
	window which lists the resources reserved for a selected PCI 
	card in your system.


5.  	PNP CONCEPTS
    	------------
	When you add a hardware card to your personal computer (PC), 
	you must reserve some system resources -- such as input/output 
	address spaces, interrupts, Direct Memory Access channels or 
	memory spaces -- for the card.  You must also make sure that 
	there is no hardware conflict, that is, the resources reserved 
	by one card are not used by another card in the same system.

	Before Plug and Play (PnP) was introduced, you can reserve 
	system resources only by manually changing the settings of 
	some dip switches or jumpers on a legacy (non-PnP) card.  
	This can be quite difficult since you have to understand how 
	the hardware settings correspond to the system resources that 
	your card requires.  It can also be very tedious since you may 
	need to change the dip switch or jumper settings several times 
	before your card can be configured without any hardware 
	conflict.

	With the emergence of Plug and Play (PnP), a revolutionary 
	design philosophy and a new PC architecture specification, the 
	PC, hardware cards, drivers and the operating system can now 
	work together without such user intervention.

	You no longer need to change any hardware settings on your card 
	before it can work properly in a PC.  Instead, a PnP BIOS or 
	software would find out the types of resources each card needs 
	and allocate the resources accordingly.

	Generally, a PnP card requires one of the following to work:
	5.1  PnP System BIOS
	5.2  PnP Operating System
	5.3  PnP Configuration Drivers and Utilities
	
	NOTE: 	The PnP BIOS specification went through several 
		revisions.  The version 1.0a specification was 
		finalized in May 1994, with further clarifications 
		documented in October 1994.  As a result, older PnP 
		systems shipped are not fully compliant with this 
		specification.  So, there are some compatibility 
		problems.  For more details, read the section 
		"PnP in DOS/Windows 3.1x" below.

5.1  	PnP System BIOS
     	---------------
	The PnP system BIOS is the lowest level of your PnP system.  
	Its main functions are to provide information on the resource 
	settings of your system devices and to configure PnP cards.

	Some PnP system BIOS configure PnP cards automatically.  Other 
	BIOS give you an option in their setup utilities to disable 
	their PnP configuration capability.  Please refer to your 
	system manual for more details.

5.2  	PnP Operating System
     	--------------------
	A PnP operating system provides a fully PnP user environment.  
	It can support PnP cards on its own, with or without a PnP 
	system BIOS.  Its main functions are to determine which 
	resources have been reserved by the legacy and PnP cards in 
	your system, and then dynamically allocate free resources to 
	newly added PnP cards.

	Windows 95 is an example of a PnP operating system.  When you 
	install	or upgrade to Windows 95 for the first time, it will 
	automatically determine the resource settings of the existing 
	cards in your system and allocate other resources to new PnP 
	cards.

	When you add a legacy card later, however, you will need to 
	run the "Add New Hardware" wizard in Control Panel so that 
	Windows 95 can detect this card.  To avoid any conflicts that 
	may be introduced by the hardware settings of this new legacy 
	card, Windows 95 may also re-assign different resources to 
	existing PnP cards.

5.3  	PnP Configuration Drivers and Utilities
     	---------------------------------------
	If you do not have a PnP operating system, you need to install 
	a PnP configuration driver and utility to perform the 
	allocation and configuration functions of a PnP operating 
	system.

	A PnP configuration driver determines the resource settings of 
	all your system devices and legacy cards, configures PnP cards, 
	and provides relevant configuration information to other 
	drivers or applications that access your PnP cards.

	A PnP configuration utility allows you to view, enter or change 
	the resource settings of the PnP and legacy cards in your 
	system.  The new or changed settings are then used by the PnP 
	configuration driver to configure new PnP cards.

	Intel Configuration Manager (ICM) and ISA Configuration Utility 
	(ICU) are examples of a PnP configuration driver and a PnP 
	configuration utility.  For more details, please read the 
	section "PnP in DOS/Windows 3.1x" below.


6.  	PNP IN DOS/WINDOWS 3.1X
    	-----------------------
	DOS/Windows 3.1x is not a PnP operating system.  So, to 
	configure PnP cards, you need to install a PnP configuration 
	driver and a PnP configuration utility.

	Currently, a generic set of PnP configuration driver and 
	utility that you can find in the market for the DOS/Windows 
	3.1x environment is ICM.  Consisting of Intel Configuration 
	Manager (ICM) and ISA Configuration Utility (ICU), this driver 
	and utility set was developed by Intel Corporation as an interim
	solution to facilitate PnP configuration when a PnP operating 
	system is not available.  It may come pre-installed in your PC 
	or bundled with your PnP cards.

	However, due to the compatibility problem mentioned earlier 
	(please refer to the note in the section "PnP Concepts" above), 
	you may encounter one of the following error message or problems 
	when you use ICM version 1.43 to configure your PnP card:
	- "Error: Failed NVS write, Error=82h"
	- Failure to detect PnP BIOS machine
	- Failure to assign new configuration to PnP card

	And ICM may not be able to configure your PnP card properly.


7.  	CREATIVE'S APPROACH TO PNP
    	--------------------------
	To solve problems similar to those mentioned in the previous 
	section, we have developed a set of DOS-based PnP configuration 
	driver and utility for the DOS/Windows 3.1x environment.  They 
	are called Creative PnP Configuration Manager (CTCM) and 
	Creative PnP Configuration Utility (CTCU).

	CTCM can be loaded as a device driver through a statement in 
	the CONFIG.SYS file.  It can also be run from the DOS prompt.  
	It configures Creative PnP cards only and provides configuration 
	information to other drivers or DOS applications.

	CTCU is used when your DOS/Windows 3.1x system does not have 
	ICM and ICU.  It allows you to perform the following functions 
	on the devices in your system:
	a. Enter, view, change or remove the settings of legacy cards.
	b. View, change, or disable the settings of Creative PnP cards.
	c. View the settings of system devices and non-Creative PnP cards.

7.1  	Why Use CTCM and CTCU?
     	----------------------
	There are several reasons why we offer CTCM and CTCU:
	a. CTCM provides a consistent method for configuring all 
	   Creative PnP cards.  It works with or without PnP BIOS or 
	   ICM.  If your PnP BIOS or ICM has already configured your 
	   PnP card(s), CTCM will simply retain those settings.

	b. If the PnP BIOS or ICM did not configure your Creative PnP 
	   cards properly, due to incompatibility problems similar to 
	   those mentioned in the section "PnP in DOS/Windows 3.1x" 
	   above, CTCM may be able to allocate resources to these cards.

	c. You need not reboot your system after using CTCU to change 
	   Creative PnP card settings, if you do not have any DOS device 
	   drivers (e.g., SBIDE.SYS or CTSB16.SYS) loaded.  You only 
	   need to run CTCM to reconfigure the card.  This is possible 
	   because CTCM can be activated from the DOS prompt, unlike ICM.

7.2  	Limitations of CTCM and CTCU
     	----------------------------
	If you use a non-PnP operating system like DOS/Windows 3.1x 
	and do not have a PnP BIOS or ICM, your PnP card works like a 
	software-configurable card.

	In such an environment, CTCM needs to know which resources have 
	been reserved by all the legacy and PnP cards, and system 
	devices in your system before it can allocate conflict-free 
	resources to your new Creative PnP card.

	CTCM can get the resource settings of PnP cards and system 
	devices from the PnP cards and BIOS.  But you need to use CTCU 
	to enter the resource settings of all the legacy cards in your 
	PC, and then run CTCM to configure your Creative PnP card.

	You may still encounter hardware conflicts if the resource 
	settings specified through CTCU are incomplete or wrong.  If 
	this happens, use CTCU to select a different group of resources 
	for the Creative PnP card that caused the conflict.  You may 
	need to try a few combinations until you find one that works.  
	This can be tedious, but it is easier than the legacy way of 
	changing dip switches or jumpers.


8.  	COMMON QUESTIONS AND ANSWERS
    	----------------------------
	This section gives the answers to some common questions that 
	you may have while installing a Creative PnP card in the DOS
	/Windows 3.1x environment.

8.1  	General Question
     	----------------
	Question:       I have a PnP BIOS as well as a PnP operating 
	                system or a PnP configuration driver and 
	                utility.  Which one should I use to configure 
	                my PnP card?
	Answer:         If you have a PnP operating system or a PnP 
	                configuration driver and utility, it is better 
	                to let your PnP operating system or 
	                configuration driver configure your PnP card.  
	                Try to set your BIOS so that it will not 
	                configure PnP cards since it may not have 
	                access to the hardware setting information of 
	                your legacy (non-PnP) cards and thus may give 
	                your PnP card some settings that will conflict 
	                with those of existing legacy cards.


8.2  	ICM (or other Configuration Manager) Questions
     	----------------------------------------------
	Question:       Must I remove ICM (or another configuration 
	                manager) in order to use CTCM?
	Answer:         No, you do not have to remove ICM (or another 
	                configuration manager) to use CTCM.  If both 
	                CTCM and ICM are installed in your system, 
	                just make sure the CTCM statement in your 
	                CONFIG.SYS file is placed after the ICM 
	                statement.

	Question:       What should I do if I cannot configure my 
	                Creative PnP card using ICM?
	Answer:         If you cannot configure your PnP card using 
	                ICM, try removing ICM.  Then use CTCU and 
	                CTCM to change and reconfigure your card 
	                settings.

	                For more details on using CTCU or CTCM, please 
	                see the sections "Using CTCM" and "Using CTCU" 
	                above.

8.3  	CTCU Questions
     	--------------
	Question:       Can I run CTCU to change or disable my card 
	                settings if I have ICM in my system?
	Answer:         No, do not use CTCU to change or disable your 
	                card settings since CTCU does not access or 
	                update the resource settings database used by ICM.

	                You should use ICU instead to change or disable 
	                your card's settings if ICM is already loaded 
	                into your system.

	Question:       I cannot run CTCU in full-screen mode. Why?
	Answer:         If you try to run CTCU in full-screen mode 
	                after loading SHARE.EXE into your system, CTCU 
	                will not load successfully. The reason is this: 
	                SHARE.EXE file has been opened by the Overlay 
	                Manager and because of sharing restrictions, 
	                the Resource Manager will fail when it tries to 
	                load CTCU.EXE.

	                So if SHARE.EXE is loaded, you have to unload 
	                SHARE.EXE before running CTCU.EXE in 
	                full-screen mode. To do this, comment out the 
	                line that loads SHARE.EXE in the AUTOEXEC.BAT 
	                file and then reboot the machine. 

	                If SHARE.EXE was loaded from the command line, 
	                and not from a statement in the AUTOEXEC.BAT 
	                file, you do not need to change the AUTOEXEC.BAT 
	                file, but you still need to reboot the system.

	                Note: 	CTCU.EXE will successfully run in silent 
	                      	mode, even if SHARE.EXE is loaded.

8.4  	CTCM Question
     	-------------
	Question:       How do I use CTCM to configure both legacy and 
	                PnP cards in DOS/Windows 3.1x?
	Answer:         First run CTCU to add information about the 
	                hardware resources used by these legacy cards. 
	                Next, run CTCM to configure your Creative PnP 
	                card(s).

	                Alternatively, if you do not know your legacy 
	                cards' settings, use CTCU to change the settings 
	                of your PnP card.  Then run CTCM and test 
	                whether your card works properly.  This is a 
	                trial-and-error	method since CTCM will not be 
	                "informed" about the resources that have been 
	                reserved by your legacy cards.  You may need to 
	                try different combinations of settings before 
	                you can configure your PnP cards successfully, 
	                without any hardware conflicts with existing 
	                cards.

	Question:       My system hangs or reboots whenever I load CTCM. 
	                What should I do?
	Answer:         The memory area of your PnP BIOS machine is 
	                probably mapped by EMM386 using the HIGHSCAN 
	                option and thus, can get corrupted easily.  
	                When it does, CTCM will not work properly.  

	                To solve this problem, remove the HIGHSCAN 
	                option in the EMM386 statement in the 
	                CONFIG.SYS file.

	                For example, change the statement
	                 DEVICE=<C:\dir>\EMM386.EXE HIGHSCAN <other parameters>
	                to 
	                 DEVICE=<C:\dir>\EMM386.EXE <other parameters>

	                where <C:\dir> is the directory of your EMM386 
	                programs, and <other parameters> are the other 
	                parameters in the EMM386 statement.


9.  	COPYRIGHT NOTICE
    	----------------
	No part of this document may be reproduced or transmitted in
	any form or by any means without the prior written consent of
	Creative Technology Ltd.

	Copyright © 1996 Creative Technology Ltd. All rights reserved.
	Microsoft, MS-DOS, Windows 3.1x, and Windows 95 are trademarks 
	of Microsoft Corporation. All other products are trademarks or 
	registered trademarks of their respective owners.


======================= E N D   O F   F I L E ========================
