Readme.txt for Sound Blaster 16/AWE for DOS/Windows 3.1
=======================================================

This file contains the following sections:

   1.  Package contents
   2.  Installing the software
   3.  If your audio card is a Plug and Play audio card
   4.  Update existing software
   5.  Full-duplex constraints
   6.  Online documentation


1. Package contents

   This package contains the following software:

     -  Audio drivers
     -  DOS Mixer program
     -  DOS Diagnostic program
     -  Creative Mixer (Windows 3.1 version)
     -  AWE Control Panel (Windows 3.1 version - for SBAWE card)


2. Installing the software

   To install the software:
     1.  Exit to DOS if you are in Windows.
     2.  Put the entire set of files in this package into a
         sub-directory on your hard disk (or diskette).
     3.  At the DOS prompt, change to the drive/directory where the
         installation files are located.
     4.  Type INSTALL, and press the ENTER key.
     5.  Follow the instructions on the screen to complete the
         installation.


3. If your audio card is a Plug and Play audio card

   If your audio card is a Plug and Play audio card, you need to
   install a Plug and Play Configuration Manager before you proceed
   with the software installation.

    * If you do not have a Configuration Manager, please download the
      Creative PnP Configuration Manager (CTCM) from the Creative Labs
      FTP site or World Wide Web site.


4. Update existing software

   To update your existing audio software, install this package to
   your existing audio software directory.  The installation program
   will replace the existing files in the directory with the updated
   versions, and the original versions will be copied to a BACKUP
   directory.

   If you specify your Windows 3.1 directory during the installation,
   the installation program will backup the existing files in your
   Windows directory to another extension (e.g. the file CSPMAN.DLL
   will be renamed to CSPMAN.D~L), and replace them with the updated
   files.


5. Full-Duplex Constraints

   To make full use of the full-duplex recording and playback feature,
   please make sure you observe the following constraints:

   a. Start only one session of simultaneous playback and recording.
   b. Use the same sampling rate for both operations.
   c. Preferably play back and record audio files which are in 
      uncompressed (that is, Pulse Code Modulation or PCM) wave format.
   d. Reduce the sampling rate for both operations  if  your  audio 
      playback and recording session is too slow.
   e. Start your Windows 3.1 in enhanced mode.
   f. Check that the version number of the CSPMAN.DLL file in your 
      Windows SYSTEM directory is 3.51 or later.


6. Online Documentation

   To help you obtain information on the applications in this package 
   easily, we have compiled a set of on-line documentation which can be 
   accessed from your audio card's group window in Windows 3.1.  Just 
   double-click on the icon(s) with names that start with the words 
   "How to Use".


                 ******** END OF README.TXT ********
