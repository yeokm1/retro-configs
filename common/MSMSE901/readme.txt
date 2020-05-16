  MICROSOFT MOUSE RELEASE NOTES (Software version 9.01)
  Copyright (C) Microsoft Corp. 1993
  
  This document contains information that supplements the 
  "Microsoft Mouse User's Guide" and accompanying software.
  The Microsoft Mouse software is designed and tested for
  the Microsoft Mouse.
  
  To view best on-screen in Windows Notepad, maximize the
  Notepad window and turn on Word Wrap (if it's not already
  on). To activate Word Wrap, select the Edit menu and
  choose Word Wrap. For best printed results, open this
  document in Windows Write, Microsoft Word, or another
  word processing application, select the entire document 
  and format the text in 10 point Courier before printing.
  
  Tip: To quickly find any section of this README, use
  your word processing application's Search command.
  
  CONTENTS
  
      I.  Important Ergonomic Safety Information
     II.  The Microsoft Mouse Setup Program
          1.  Modifications Made by Setup
          2.  Returning Your System to Pre-Setup Condition
          3.  Setting up to a Floppy Disk System
          4.  Loading MOUSE.EXE into Upper Memory
          5.  The SHARE.EXE File and Multidisk Setup
          6.  Reinstalling Your Virtual Keyboard Driver
    III.  The MOUSEPWR Feature
     IV.  Microsoft Windows NT Support for Your Mouse
      V.  Meet the Mouse
     VI.  Notes on Mouse Manager Features
          1.  Windows and MS-DOS Features
          2.  Magnify
          3.  Screen Wrap
          4.  Snap-to
          5.  Mouse Trails
    VII.  Other Issues
          1.  MS-DOS Support for the IBM XGA Video Card
          2.  Hot Keys on LCD Screens
          3.  Large and Medium Pointers
          4.  Windows 3.0 Support
          5.  Exiting from Microsoft Windows with a Serial Mouse
    VIII.  More Ergonomic Information
  
  _________________________________________________________________
  
  I. IMPORTANT ERGONOMIC SAFETY INFORMATION
  
  *******************************************************************
  * Some studies suggest that long periods of repetitive motion,    *
  * coupled with an improper work environment and incorrect work    *
  * habits, may be linked to certain types of physical discomfort   *
  * or injury. These include carpal tunnel syndrome (CTS),          *
  * tendinitis, and tenosynovitis. It is important to follow all    *
  * instructions carefully. Failure to do so may result in CTS,     *
  * tendinitis, or tenosynovitis. These instructions may not only   *
  * help minimize your chances of experiencing one of these         *
  * conditions, but will also help you to work more comfortably     *
  * and effectively. Ensuring that your chair, work surface, and    *
  * the placement of the mouse are in the correct positions is      *
  * important. In addition, you should take frequent breaks to      *
  * avoid sitting in the same position for extended periods of      *
  * time. See the end of this README for more important ergonomic   *
  * information.                                                    *
  *******************************************************************
  
  _________________________________________________________________
  
  II. THE MOUSE SETUP PROGRAM
  
  1. Modifications to Your System
  
  The following changes are made to your system if you set up the
  software using all the default conditions during the mouse Setup
  program (default directory is c:\mouse).
  
  For the mouse driver in MS-DOS, Setup makes the following changes:
    
    a. Installs or modifies lines similar to the following in AUTOEXEC.BAT:
  
    set mouse=c:\mouse
    c:\mouse\mouse.exe /q
  
    b. Adds mouse to the PATH statement.

    NOTE: Setup adds mouse to the beginning of your PATH statement.
    However, the end of your PATH statement may be truncated if it
    contains too many elements.

    c. Deletes the following line (if it exists) from CONFIG.SYS:
  
    device=c:\mouse.sys
  
  For the mouse driver in Windows, Setup makes the following changes:
  
    a. Adds the following line to the load line in WIN.INI:

    [windows] section            c:\mouse\pointer.exe

    b. Modifies the following lines in SYSTEM.INI:

    [boot] section               mouse.drv=c:\mouse\mouse.drv
    [boot.description] section   mouse.drv=Microsoft Mouse version 9.01
    [386enh] section             keyboard=c:\mouse\mousevkd.386

    c. Adds a group to PROGMAN.INI:
    
    groupn=c:\mouse\mouse.grp
    (where n = group number and \mouse=mouse directory)
  
    d. Setup updates to the latest CTL3D.DLL file to the Windows System
       directory (if it's not already there).
 
    e. If you have Microsoft Windows version 3.0, Setup installs WINHELP.EXE.
  
  2. Returning Your System to Pre-Setup Condition
  
  To return your system to its previous condition before you
  ran the mouse Setup program, make the following modifications:
  
    a. Remove the following line from WIN.INI:

    c:\mouse\pointer.exe    

    b. Change the following lines in SYSTEM.INI to read:

    [boot] section               mouse.drv=mouse.drv
    [boot.description] section   mouse.drv=Microsoft, or IBM PS/2
    [386enh] section             keyboard=*vkd
  
  3. Setting up with a Floppy Disk System
  
  Setup supports only hard disk systems and floppy disk systems
  with two drives. If you are installing files onto a floppy disk
  system that has only one drive, you must decompress and copy the
  files manually. EXPAND.EXE, a file-decompression program, is
  provided on the Setup disk for this purpose.
  
  To install using a single-drive floppy disk system:
  
    a. Insert the Setup disk into drive A and type:

    expand mouse.ex$ b:mouse.exe

    b. When prompted by MS-DOS, remove the Setup disk and insert
       your destination disk.
    c. Reinsert the Setup disk in the drive and type:

    expand mousemgr.ex$ b:mousemgr.exe

    d. When prompted by MS-DOS, remove the Setup disk and
       insert your destination disk.
 
  To load your mouse driver, type:

      mouse

  Run Mouse Manager to set pointer options, if desired.
  To run Mouse Manager, type:

      mousemgr
  
  If you install the software using a dual floppy disk system,
  set up the mouse software from drive b to drive a.
  
  4. Loading MOUSE.EXE into Upper Memory
  
  The MS-DOS mouse driver automatically loads itself into
  upper memory, if available. Using the MS-DOS loadhigh command
  may cause your mouse software to load into low memory.

  5.  The SHARE.EXE File and Multidisk Setup

  For multidisk Setup (360 KB or 720 KB disks) only: 
  Do not load the SHARE.EXE file (included with MS-DOS) before
  you run the mouse Setup program. If SHARE.EXE exists in
  your AUTOEXEC.BAT, it must be removed before running
  the mouse Setup program. After mouse Setup is complete,
  you can reinstall SHARE.EXE.

  6.  Reinstalling Your Virtual Keyboard Driver 

  If you received a message at the end of Setup similar to the one below: 

      Setup replaced your Virtual Keyboard Driver

  you may wish to reinstall your Virtual Keyboard Driver if you are 
  experiencing problems with your mouse. To do this, change the following  
  line in the SYSTEM.INI file to read:

     [386enh] section           keyboard = c:\N.VKD 

  Where N is the path and name of your VKD. The location and name of your 
  former VKD is displayed in the message box at the end of Setup.
  _________________________________________________________________
  
  III. THE MOUSEPWR FEATURE

  Some laptop computers have the capability to go into a sleep mode
  to conserve power when not being used.  Load the MOUSEPWR feature if 
  your mouse becomes erratic after you resume from sleep mode. MOUSEPWR
  restores pre-sleep mode settings of the mouse when you resume
  work on the laptop.
  
  It's not necessary to use MOUSEPWR if your system has Advanced
  Power Management (APM). However, this feature requires very
  little memory (592 bytes) and won't conflict with APM if both
  are loaded on your system.
  
  The MOUSEPWR feature is not automatically copied during the
  mouse Setup program. Use the MS-DOS copy command to load
  MOUSEPWR.COM to your system. The MOUSEPWR feature must
  be loaded at the MS-DOS prompt only (not in Windows). If
  you need to load MOUSEPWR to your system, add it to your
  AUTOEXEC.BAT file so that it loads each time you turn your
  system on. For example, if MOUSEPWR is in the root directory,
  add the following line to your AUTOEXEC.BAT file:
  
  c:\mousepwr.com
  
  Otherwise, you'll need to load MOUSEPWR manually each time you
  want to use it. Type the following line at the MS-DOS prompt
  to load the MOUSEPWR feature manually:
  
  \mouse\mousepwr.com
  
  where 'mouse' is the directory containing the MOUSEPWR.COM file.

  ____________________________________________________________________
  
  IV. MICROSOFT WINDOWS NT SUPPORT FOR YOUR MOUSE
  
  Microsoft Windows NT will have Microsoft mouse drivers included.
  For additional mouse support for Microsoft Windows NT, contact
  Microsoft Customer Service upon release of Microsoft Windows NT.
  Inside the U.S.A., call 1-800-426-9400. Outside the U.S.A.,
  please contact your subsidiary.
  
  ____________________________________________________________________
  
  
  V. MEET THE MOUSE
  
  Meet the Mouse is a short, animated demonstration that is
  available for viewing when you run the mouse Setup program.
  You can also watch Meet the Mouse from Mouse Manager. Meet
  the Mouse takes approximately two minutes to run if you have
  the minimum required configuration set up for Microsoft Windows.
  Meet the Mouse may run slower if you have less than the required 
  configuration, or if you have a 24-bit graphics card.
  
  To save disk space, you can remove this demonstration by deleting
  the ERGODEMO.DLL file from the directory that contains your
  mouse software.
  ____________________________________________________________________
  
  
  VI. NOTES ON MOUSE MANAGER FEATURES
  
  1. MS-DOS and Windows Features
  
  When you choose Set Buttons, Overall Pointer Speed, Acceleration,
  and Orientation from Mouse Manager in Windows, the changes
  do not affect the MS-DOS driver until you reboot your computer.
  However, if you set these features from the Mouse Manager in
  MS-DOS, the changes affect both MS-DOS and Windows.
  
  2. Magnify
  
  Once you activate Magnify with the keyboard key and mouse,
  release the key and mouse button. Click any mouse button
  to return your pointer to normal.
  
  If you move the magnified pointer quickly in highly graphical
  applications, it may take a few seconds for the screen to fully
  redraw.
  
  You cannot use the Magnify feature on pull-down menus because
  the activating keystroke causes the pull-down menu to close. This
  also applies to other items that are deactivated by a single
  keystroke.
  
  3. Screen Wrap
  
  Screen Wrap cannot move off the edge of the screen while
  Microsoft Windows is busy (for example, while the pointer
  is an hour glass).
  
  4. Snap-to

  If Snap-to does not work in some dialog boxes, it is because
  the default buttons in these dialog boxes do not adhere to the
  standard Microsoft Windows user interface specifications.
  
  5. Mouse Trails
  
  You can not adjust the length of Mouse Trails for Paletized
  video drivers through Mouse Manager.
  
  _____________________________________________________________________
  
  VIII. OTHER ISSUES
  
  1. MS-DOS Support for the IBM XGA Video Card
  
  A file called XGA.VDM is on your Mouse Setup disk, but is not 
  automatically copied during Setup. You need to copy this file
  to your mouse directory only if you have an IBM XGA card in your
  system. This file will give you MS-DOS support for your XGA card.
  
  2. Hot Keys on LCD Screens
  
  On some LCD screens some of the hot keys do not show up or are
  not highlighted.
  
  3. Large and Medium Pointers
  
  When using a large or medium sized pointer, some MS-DOS
  applications may not redraw the pointer correctly, resulting
  in "mouse droppings."

  When using a large or medium sized pointer, some applications
  for Windows may not enlarge the pointer correctly.

  4. Windows 3.0 Support
  
  Setup does not update Mouse Manager in the Windows Control
  Panel, version 3.0. But Setup still creates a mouse
  program group which contains Mouse Manager.
  
  There is no support for the mouse driver in an MS-DOS windowed
  application within Windows 3.0. To get mouse support, run your
  MS-DOS application full screen within Windows (ALT + ENTER switches
  between a window and full screen).

  5. Exiting from Microsoft Windows with a Serial Mouse

  If you find that exiting from Microsoft Windows is slow with your 
  serial mouse, try modifying the following line in the SYSTEM.INI file 
  to read:

     [386enh] section           keyboard = *VKD
  
 
  ___________________________________________________________________
 
  VIII. MORE ERGONOMIC INFORMATION
  
  Personalizing your environment so that it is comfortable for your work
  situation promotes a healthy physical and mental lifestyle. Studies
  show that a carefully planned work environment can actually increase
  productivity. Of course, only you can judge what’s best for you, so
  we encourage you to adapt these tips to your own needs.
  
  Exercises
  
  Exercise and frequent breaks play an important part in staying alert
  and comfortable on the job. Take periodic breaks to rest your eyes,
  move your body, and get your circulation flowing. Try some of the
  following exercises several times during the day. 
  
  Gently press your hands against a table, stretch, and hold for five
  seconds. Stretch and massage your fingers, hands, wrists, and forearms
  throughout the day. Gently shake your hands and fingers to relieve
  tension and help blood flow. Rotate your shoulders in a full forward
  circle four times. Then roll them backward four times. Then rotate
  each shoulder separately four times. Do this at least twice daily.
  Organize your work so that you alternate using your computer with
  other activities. Try to use different muscle groups throughout the
  day. Get up and walk around several times a day.
  
  Note:  If you experience pain while using your computer, consult a
  qualified health professional.
  
  Chair and Desk
  
  A chair that is adjustable in height is a good place to start. It
  should be comfortable and provide firm support to the lower back
  (lumbar region). Adjust the chair so that your forearms form
  approximate right angles with your upper arms and so that your
  feet rest flat on the floor. If your feet don’t rest flat on the
  floor, use a footrest that is high enough so that your thighs
  are about parallel to the floor while you’re seated.
  
  If at all possible, place your system on a desk designed for a
  computer. Traditional writing desks are sometimes too high for
  computer use. A proper height between your chair and your desk
  is essential. And don’t forget good posture -- slouching puts
  unnecessary strain on your back and weakens muscles.
  
  Display and Lighting
  
  Place the display screen directly in front of you at a comfortable
  viewing distance. Sit in your chair and make sure that the top of
  the display is no higher than eye level. Make sure you can’t see
  glare and bright reflections on the screen (anti-glare filters help)
  or on your mouse, and keep your screen clean and dust free.
  
  It’s important to look away from your display frequently. Several
  times every hour, focus on an object about 20 feet away and slowly
  inhale through your nose and exhale through your mouth.
  
  Keyboard and Mouse
  
  Position the keyboard directly in front of you on the desk. While
  you’re typing and using the mouse, keep your shoulders relaxed and
  let your upper arms hang freely at your sides. Let your elbows hang
  loosely near your body and allow enough room on your desk for
  unhindered movement of the mouse. Your forearms should be nearly
  parallel and at approximate right angles to the floor as you type
  and use the mouse.
  
  Position the mouse at the same height as your keyboard. If you can,
  try to avoid light sources that can reflect on the surfaces of your
  mouse and keyboard. Use your entire arm to move the mouse around
  on your desktop whenever possible. The Microsoft Mouse is designed
  so that you can rest your hand on it whenever possible, and so that
  you don’t have to grip it unusually hard when using it. Avoid
  excessive tension in your hand by relaxing -- don’t pinch the
  mouse too hard.
  
  The high-performance level of the Microsoft Mouse makes it
  unnecessary to use a mouse pad. However, if you do use a mouse
  pad, make sure it is not so thick that it raises your arm and
  the mouse. Your arm should maintain an approximate right angle
  to the horizontal table top. The mouse pad should provide smooth
  friction for ease of use -- it should not be too slippery. It
  should also be lint free so the mouse ball doesn’t get dirty.
  
  The design of the Microsoft Mouse accommodates a wide variety
  of grips and lets you use the mouse in either hand. The mouse
  allows for several possible work positions, which can help you
  avoid unnecessary strain on your arms and hands. By periodically
  varying the way you hold the mouse, you don’t repeat the same
  motion over a long period of time. The software that comes with
  the Microsoft Mouse (Mouse Manager) supports the mouse design
  by letting you customize the software for variable work positions.
  It’s a good idea to periodically readjust your software as you get
  better acquainted with your mouse.
  _________________________________________________________________
  
