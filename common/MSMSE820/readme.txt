  
  MICROSOFT MOUSE RELEASE NOTES (software version 8.20)
  Copyright (C) Microsoft Corp. 1992
  
  This document contains information that supplements the 
  "Microsoft Mouse User's Guide" and accompanying software.
  
  CONTENTS

      I. Setting the Environment Variable
     II. Using the Mouse Control Panel in Windows
    III. Using High or Expanded Memory with MS-DOS 5.0
     IV. Using the Mouse with Win 2.X
      V. Installing an OS/2 Mouse Driver
         (OS/2 versions 1.2 and 1.3 only)
     VI. Using the MOUSEPWR Feature
  
  
  _________________________________________________________________
  
  
  I. SETTING THE ENVIRONMENT VARIABLE
  
  If the MOUSE.INI file is not in the same directory as the mouse
  driver, an MS-DOS environment variable is set to point to the file's
  location. Usually the Setup program does this automatically by
  installing a line similar to the following one in your
  AUTOEXEC.BAT file:

  set mouse=c:\mouse

  If necessary, you can add this line yourself; or you can modify
  it if you move the MOUSE.INI file to a different directory.

  Note: The mouse device driver MOUSE.SYS does not access the
  MOUSE.INI file if it is not in the same dirctory. If your system
  uses MOUSE.SYS and the MOUSE.INI file is not in the same directory,
  you cannot save changes to MOUSE.INI.


  _________________________________________________________________
  

  II. USING THE MOUSE CONTROL PANEL IN WINDOWS
  
  The mouse setup program installs a mouse group, which includes
  the Mouse Control Panel, into the Windows Program Manager
  (version 3.0 and later). The group also contains this README file.

  In Windows 3.10, Setup also integrates the Mouse Control Panel
  into the Windows Control Panel. Both Mouse Control Panels function
  exactly the same. 

  If you wish, you can delete the mouse group from the Windows 3.10
  Program Manager after you have read this README file. You can
  then use the Mouse Control Panel located in the Windows Control
  Panel to customize your mouse.
  
  
  _________________________________________________________________
  
  
  III. USING HIGH OR EXPANDED MEMORY WITH MS-DOS 5.0
  
  The /U or /E mouse command-line switches are no longer supported.
  Instead, use the loadhigh or devicehigh commands in MS-DOS 5.0 to
  load the mouse driver into high or expanded memory. For more
  information, see the Microsoft MS-DOS Operating System version
  5.0 User's Guide and Reference.
  
  
 __________________________________________________________________
  
  
  IV. USING THE MOUSE WITH WIN 2.X
  
  To use your mouse with Windows version 2.X, you must reinstall
  your version of Windows using the installation software provided
  with it. Windows 2.X mouse support is provided by the driver file
  WIN2MOU.DRV. This file is supplied on the mouse Setup disk
  in uncompressed format.
  

  To install for Windows 2.X:
  ---------------------------
  
    1. Using your Windows installation disks, type
  
     a:setup

    2. When you are asked to review your display adapter, keyboard,
    and mouse or pointing device, select Microsoft Mouse and press
    ENTER.

    3. From the list of pointing devices, select Other (at the
    bottom of the list) and press ENTER.

    4. Insert the mouse Setup disk in drive A and press ENTER.

    5. Select Windows 2.X Microsoft Mouse (the Windows 2.X 
    mouse driver on the disk) and press ENTER.

    6. Choose No Change and press ENTER to continue with 
    Windows Setup.

    7. Finish setting up Windows by following the instructions on
    your screen.
  
  
  _________________________________________________________________
  
  
  V. INSTALLING AN OS/2 MOUSE DRIVER
     (OS/2 versions 1.2 and 1.3 only)
  
  
  This release includes the following Microsoft OS/2 Mouse driver:
  
   OS2MOUSE.SYS     for OS/2 version 1.2 and 1.3

  This driver works with the following pointing devices:
  
       Microsoft Serial-PS/2 Mouse
       Microsoft Bus (Inport) Mouse
       Microsoft BallPoint Mouse
  
  You do not need a separate driver for each type of mouse.
  You must install the OS/2 mouse driver manually.
  
  To install the OS/2 mouse driver:
  ---------------------------------
   (The following procedure assumes your device drivers
   are in directory C:\OS2.)
  
   1. Copy OS2MOUSE.SYS to C:\OS2.
  
   2. Edit your CONFIG.SYS file to remove the line that points
   to your current mouse driver. This line will vary according
   to the type of mouse installed, but it will be similar to this:
  
   DEVICE=C:\OS2\IBMMOU1.SYS                (remove this line)
  
   3. If you are using OS/2 version 1.2, you must also remove 
   the line that includes MOUSE.SYS. This line will vary according
   to the type of mouse installed, but it will be similar to this:
  
   DEVICE=C:\OS2\MOUSE.SYS  TYPE=MSSER$     (remove this line)
  
   4. Insert the following line in your CONFIG.SYS file:
  
   DEVICE=C:\OS2\OS2MOUSE.SYS
  
   5. Save these changes and restart your computer.
  
  
  _________________________________________________________________
  
  
  VI. USING THE MOUSEPWR FEATURE

  Some laptops have the capability to go into a sleep mode to
  conserve power when not being used. If your laptop has this
  capability (laptop SL systems), you may want to use the
  MOUSEPWR feature, which is included on the mouse Setup
  disk. MOUSEPWR restores presleep mode settings of the mouse
  when you resume work on the laptop.

  It's not necessary to use MOUSEPWR if your system has Advanced
  Power Management (APM). However, the MOUSEPWR feature requires
  very little memory (976 bytes) and won't conflict with APM if both
  are loaded on your system.

  The MOUSEPWR feature is not automatically copied during the
  mouse setup program. Use the MS-DOS copy command to load
  MOUSEPWR.COM to your system. The MOUSEPWR feature must
  be loaded at the MS-DOS prompt only (not in Windows).

  If you decide to load MOUSEPWR to your system, add it to your
  AUTOEXEC.BAT file so that it conveniently loads each time you
  turn your system on. For example, if MOUSEPWR is in the root
  directory, add the following line to your AUTOEXEC.BAT file:

  c:\mousepwr.com

  Otherwise, you'll need to load MOUSEPWR manually each time you
  want to use it. For example, type the following line at the MS-DOS
  prompt to load the MOUSEPWR feature:

  \mouse\mousepwr.com

  where 'mouse' is the directory containing the MOUSEPWR.COM file.
  
  
_________________________________________________________________________
  
  
