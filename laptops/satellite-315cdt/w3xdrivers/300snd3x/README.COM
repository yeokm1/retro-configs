�8TXT2COM Conversion utility. Vers 1.1
Copyright 1987 by Keith P. Graham
This file cannot be distributed for SALE without
express written permission from Keith P. Graham
238 Germonds Road, W. Nyack, NY 10994, (914) 623-4161
To view the contents of this file
enter the name of the file from the DOS prompt.
�s  �>~u�6��H�M����'���� �P �w�ֲ QR��  ��<tE<
tA<~u)�<~t#�<0|�<f�<9~�<A|�<F~�<a|���ˬ�	� � ���ZY����ZYÃ.u�>u }	�u  ���u��d��u�>u�|��u����u  �s  ���u  �{- �s��:�� �s�� �-��>s t�.s�� ���>s u���.s�@�s��>}�1�w ������{= ���- 9s|����s���s����>}�1�w �������� "^4��� � ��  ����	�!�n�
�!�>o�z��o� Ƈp ��p� <�  �!s�p��=�!s�Q��ش@�y��!�>�!�<��>s }�s  á{= ~- 9s~�s���s  ù �s�w QC9{Y�KS��>}�1�>u t�u�<t	<
t�����[CY�w��ô ��č>�
 ��u��
�ً�K��ô� � �O�>���  ��  ��6#�P �  Q��	� � ���մ�  �EY��ù
 �s@�  ���0���  ���0���  ���0���  ���0���  �
 �u@�  ���0��  ���0� �  ���0���  � ��  ��6��P � Q��	� � ���մ�  �EY��ô�� �O�>��ô�� �O�>��À<0|[�<fV�<9~�<A|L�<F~�<a|B�|0|<�|f6�|9~�|A|*�|F~�|a|�<9~,$���ج<9~,$؈��  If you want to write to a file enter the file name.
  If you want to print the file enter LPT1 or LPT2

  ENTER: $@                                                                   Esc=Quit, T=write text, Keys=,,,,PgUp,PgDn,Home,End   Line=0000  Column=000                      KMGOIQPH                                                                                       �+ j --------------------------------------------------------------------------
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
��)]_���#	n	�	
"
p
�
�
H��� "W�� 02BVln���X`j