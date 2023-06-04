--------------------------------------------------------------
Windows 95 High-Speed Processor Support v. 3.0 By LoneCrusader
--------------------------------------------------------------

CONTENTS OF THIS PACKAGE:
-------------------------

README.TXT - Self Explanatory.

FIX95CPU.EXE - Self-Extracting Bootable Floppy Disk image.

FIX95CPU.IMA - A standard image of the Bootable Floppy.
	(For Virtual Machines.)

FIX95CPU.ISO - A standard Bootable CD image.
	(For Virtual Machines, or systems without a floppy drive.)

VMM2XUPD.EXE - HotFix with updated VMM.VXD's for Windows 95 B OSR2.
	(Install in Windows 95 B OSR2 after Setup has completed.)

-------------------------

NOTE:

The first section of this README will explain the issues addressed
by this patch. If you are familiar with these issues, you may skip to
the second section for step-by-step instructions.


SECTION ONE:
------------

Windows 95 has two specific errors when dealing with processors
with speeds higher than 350 MHz. With a little patience however,
both of these errors are fixable.


The first error occurs with processors greater than 350 MHz.
Microsoft released a patch for this error, AMDK6UPD.EXE. This
patch IS NOT just for AMD processors. It will work for Intel
Pentium 4 processors as well. The problem with Microsoft's patch
is that it must be run from within Windows. When your system
encounters this error, you will not be able to boot into Windows.
This error will be displayed on the first reboot during the
installation process.

Here is the text of the error:

      While initializing device IOS:
      Windows Protection Error.  You need to restart your computer.

The only way to fix this error is to manually install the files
contained in the Microsoft AMDK6UPD.EXE patch. This package automates
the process for you, so I will not go into further detail on that
issue here.


The second error occurs with processors greater than 2.1 GHz.
This problem also affected Windows 98 (First Edition), and Microsoft
issued a HotFix for Windows 98, but not for Windows 95. According to
Microsoft, there is no fix for this problem in Windows 95... WRONG!
This error is very similar to the previous one, and it will also be
displayed on the first reboot of the install process, after you have
fixed the previous error.

Here is the text of the error:

      While initializing device NDIS:
      Windows Protection Error.  You need to restart your computer.

This error is corrected by an updated file contained in the DUN14-95.EXE
Dial-Up Networking 1.4 Update for Windows 95. This package automates
the process for you, so I will not go into further detail on that
issue here.


NOTE:
	This update renders the AMDK6UPD.EXE patch OBSOLETE, as it
	installs newer versions of some system files contained within
	AMDK6UPD.EXE. While the main purpose of this update is to
	enable the use of High-Speed Processors, I decided to include
	any available newer versions of the system files already
	contained in this patch.


List of Issues (MSKB Articles) FIXED by this update:
----------------------------------------------------

Q192841 - Difficulties Using AMD K6-2 or Athlon Central Processing Unit
Q234259 - Revision to AMD K6-2/350 Central Processing Unit Update
Q312108 - Windows Protection Error in NDIS with CPU Faster Than 2.1 GHz
Q231942 - Cannot Undock Notebook Computer with LS-120 Removable Drive
Q175629 - Large IDE Hard Disk May Run In Compatibility Mode
Q274175 - Error Opening/Copying File/Folder Eight Levels Deep on CD-ROM
Q159153 - Error Messages While Backing Up to Some Floppy Disk Drives


This update also includes a patched version of CDFS.VXD using PTCHCDFS,
a free update by Rudolph Loew (rloew) to fix the incorrect size value
(1.99GB) reported by Windows 9X for DVD's.

A separate bug exists in Windows 95 RTM/A that causes DVD sizes over
4GB to not have their byte counts displayed properly, showing "---"
instead, but the correct total size of the DVD will still be displayed.
Installing other update packages for Windows 95 RTM/A may yield a
solution to this, but has not been tested.


Also included in this version is a HotFix, VMM2XUPD.EXE, which installs
the latest version of VMM.VXD for Windows 95 B OSR2. This package should
be installed when Windows 95 B OSR2 Setup has completed. This update will
not run on Windows 95 RTM/A and is not required on Windows 95 C OSR2.5.


Credits & Other Information:
----------------------------

Rudolph Loew has also created a free UDF filesystem driver for reading
UDF formatted CD's/DVD's in Windows 95. It can be obtained from his site
at {http://rloew1.no-ip.com} or mirror at {http://rloew.limewebs.com}.

Many thanks go out to Rudolph Loew for his assistance with this project!

Credit also goes to Petr at MSFN for providing patched files for 95 RTM.

And finally credit to Queue at MSFN for creating the ANSI Windows Logo.

For further information and updates, visit this topic at MSFN Forums:
http://www.msfn.org/board/index.php?showtopic=141402

This package makes use of the General Replace (GR) text replace utility
created by Andrew Sharrad, which can be found at:
http://www.sharradsoftware.co.uk



SECTION TWO:
------------

Follow these Instructions to get Windows 95 up and running.

You Will Need:

	Blank Floppy Disk or Blank CD
	Files Contained In FIX95CPU.ZIP

NOTE:
	If your system does not have a floppy drive, the FIX95CPU.ISO
	Bootable CD image in this package can be used (with Nero or
	a similar CD burning program) to create a bootable CD that can
	be used instead of a floppy.

NOTE:
	These instructions and the FIX95CPU installer assume that
	you are installing Windows 95 to C:\ Drive, however you can
	use a directory other than C:\WINDOWS.


 1. On another computer, use the self-extracting Floppy Disk image
	(FIX95CPU.EXE) or the Bootable CD image (FIX95CPU.ISO)
	provided in FIX95CPU.ZIP to create a custom Boot Disk
	that will contain this patch.

 2. Prepare your system and run Windows 95 Setup.

 3. When Windows 95 asks you to Restart, insert the Boot Disk or
	Boot CD that you created with the enclosed image, and click
	Finish. You should have the Boot Disk or Boot CD inserted
	BEFORE Windows Setup continues and the IOS error is displayed
	in order to speed up the boot process by combining .VXD's
	with WININIT.EXE, but this version allows for installation
	after the IOS error has been displayed.

 4. The Boot Disk will start your computer in DOS mode. Press SPACE and
	you will be given an opportunity to view this README file.
	Choose Y or N, and then all you need to do is press SPACE again
	to bring up the next page of the README, or to apply the patch.
	The program will output its actions to the screen so you can see
	what is being done.
	
	Pressing CTRL-C at any time will terminate the FIX95CPU program.

 5. When finished, press SPACE to reboot your system, then remove the
	Boot Disk or Boot CD so Windows 95 Setup can continue normally.


If you are installing Windows 95 RTM/A or C OSR2.5, you are finished.

For Windows 95 B OSR2 ONLY:


 6. When Setup is complete and your Windows Desktop loads, run
	VMM2XUPD.EXE to update VMM.VXD to the latest version, and you
	will be prompted to restart.

	This update is not necessary on Windows 95 C OSR2.5.

	If you have Windows 95 RTM/A or C OSR2.5, skip this step.
	The VMM2XUPD.EXE will not install on Windows 95 RTM/A.

	The VMM2XUPD.EXE update addresses the following issue:
	Q179897 - Memory Management Problems with Pentium Processors


You have successfully completed all steps.

Install the drivers for your hardware and your programs.


	Have Fun!


---------------------------------------

KNOWN ISSUES:
-------------

 1. If you plan to install the Microsoft USB Supplement to Windows
	95 OSR2 (USBSUPP.EXE), be aware that this update will sometimes
	overwrite the file C:\WINDOWS\SYSTEM\VMM32\NTKERN.VXD without
	prompting you to keep the newer file already installed by this
	patch. If this occurs, the following error will be displayed:

	While initializing device NTKERN:
	Windows Protection Error.  You need to restart your computer.

	This can be corrected by recopying the NTKERN.VXD contained in
	this patch to your system.


---------------------------------------


LEGAL INFO:
-----------

THIS SOFTWARE IS PROVIDED FREE OF CHARGE WITH ABSOLUTELY NO WARRANTIES
	OR GUARANTEES.
BY USING THIS SOFTWARE, YOU AGREE THAT YOU USE IT AT YOUR OWN RISK AND
	OF YOUR OWN FREE WILL.
THE AUTHOR(S) OF THIS SOFTWARE SHALL NOT BE HELD LIABLE FOR ANYTHING
	RESULTING FROM THE USE OR MISUSE OF THIS SOFTWARE.
IF YOU MODIFY THIS SOFTWARE, PLEASE REMEMBER TO CREDIT THE ORIGINAL
	AUTHOR(S) FOR THE ORIGINAL CONCEPT(S).

---------------------------------------

    This software brought to you by Conner McCoy (LoneCrusader) with
                  assistance from Rudolph Loew (rloew).

---------------------------------------