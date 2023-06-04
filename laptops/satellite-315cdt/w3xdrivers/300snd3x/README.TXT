 --------------------------------------------------------------------------
                              YAMAHA OPL3-SAx
                                Audio Driver
                        for Windows for Workgroups

                      Steps to install the audio driver
 --------------------------------------------------------------------------

(1)  In the Control Panel window, choose the Drivers icon.
(2)  In the Drivers dialog box, choose the Add button. The drivers listed
     in the Add dialog box are those supplied with Windows for Workgroups.
(3)  In the List Of Drivers box, select the Unlisted or Updated Driver and
     choose the OK button.
(4)  In the Install Driver dialog box, indicate C:\300SND3X (or the path to 
     the directory where you stored the extracted files) and click the OK 
     button.
(5)  In the Add Unlisted or Updated Driver dialog box, select the YAMAHA
     OPL3-SA WAVE & MIDI and choose the OK button.
(6)  In the YAMAHA OPL3-SA Series Driver dialog box, choose the OK button.
(7)  In the System Setting Change dialog box, choose the Do not restart 
     button.
(8)  Exit Windows.
(9)  Execute following commands.
      REN C:\WINDOWS\SYSTEM\midimap.cfg midimap.old
      COPY A:\msmixmgr.dll C:\WINDOWS\SYSTEM
      COPY A:\midimap.cfg C:\WINDOWS\SYSTEM
(10) Open system.ini by text editor and register the following descriptions.

      [boot]
      drivers=... msmixmgr.dll

      [YAMAHA]
      CPLMPUBoth=1
      DelSoftSynth=1

(11) Start Windows.

Note: If you would like to install this version over the previous version
      which has pre-installed on the machine, you should do it after
      deleteing the YAMAHA's driver files on the Cabs directory.
      
 **end**
