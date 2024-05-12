Copyright ( 1998-1999 3dfx )
All Rights Reserved

NOTE: This software is released AS IS.  It is not intended for use
on non-3dfx products.  Use of this software is subject to the terms 
in the 3dfx license agreement.

This product may be covered by one or more of the following
US patents: 5,724,561  5,740,343  5,808,621  5,822,452  5,831,624

=======================================================================
What's included in this distribution?
=======================================================================
This installer comes with a MiniGL driver for Quake, Quake 2, Hexen 2, 
Sin, Half-Life and Heretic 2.

=======================================================================
Installation
=======================================================================
Double-click on miniinst.exe to run the 3dfx MiniGL Installer.  The 
Installer will present you with a simple dialog box with the proper 
default settings.  Click on the Next button to complete the installation.

=======================================================================
Additional Information and Questions
=======================================================================

What if I want to just extract the files?
-----------------------------------------------------------------------
Extracting the files is unnecessary for the vast number of users.  We 
recommend you let the installer software do the work for you.  If you 
want to extract the files follow these steps.

Start the installer.
Check the second radio button down.
Click on Next.  It will then ask you for a folder.  If you don't know 
what to do, choose "Desktop."  

The installer then creates a folder on your desktop named "3dfx MiniGL",
extracts files into it, and opens the folder.  Inside the folder will 
be the readme and one folder for each game supported.  The correctly 
named miniport is in each game directory.  For instance, for Sin, you 
would open the "Sin" folder and place the file(s) from there into the 
place Sin is installed on your hard drive.  

What does it search for?
-----------------------------------------------------------------------

The installer will search only hard drives, and it will search for the 
game's EXE file, and an older version of the miniport.

Does the installer back stuff up?
-----------------------------------------------------------------------
By default, yes.  When you choose "OK" to copy the files after the 
installer has found your games, it will create backups of your old 
MiniGLs.  The first backup of this will be "Backup of <filename>".  
Subsequent backups will be named "Backup (#) of <filename>" where the 
highest # is the most recent backup.

Are there any issues?
-----------------------------------------------------------------------
Quake - If you experience flickering in the overlay at the bottom of 
the screen, you will need to bring up the console and enter
"gl_triplebuffer 1".  This will enable triple buffering. 

In Quake, Quake2, Sin, and Hexen2, alt-tabbing out of the MiniGL on a 
Voodoo3, Voodoo Banshee, or Voodoo Rush will not clear the screen.  
You need to quit the game to get back to the Windows desktop.

As of yet, you cannot do windowed rendering on either Voodoo3, 
Voodoo Banshee or Voodoo Rush.  They will always open full screen.  
This will be addressed on Voodoo Banshee when a full OpenGL ICD is 
released.

The Sin game is only supported to 1280x960 resolution.  This is a game
limitation with hardware acceleration and will be addressed by the game
author.