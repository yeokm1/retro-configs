                
*** Please read and process below files in DOS environment. ***

=== Compressed file contains 4 sub-files. ===

1. README.TXT  : Description of how to update the new BIOS for Transcend's
		 motherboards.
2. TSFLASH.EXE : BIOS upgrade utility for Transcend motherboard.
3. xxxxxxxx.BIN: BIOS file name and version number.
		 xxxxxxxx.BIN file name depend on your motherboard mode.
		 Please refer the "BIOS UPGRADE CHAPTER OF USER'S MANUAL"
4. TSFLASH.OVL: Utility for TSFLASH.EXE operation.


=== How to Upgrade your motherboard BIOS. ===

Please follow below description step by step.

1. Run "TSFLASH bios_file_name" under MS-DOS environment.
   You also can run "TSFLASH /?" to get the command's format.

   Example:  A:>TSFLASH /?

	     Format: TSFLASH [(bios_file_name)||(/V)]

		     bios_file_name: Upgrade BIOS file name
		     /V: Display utility version information

	     Example: TSFLASH xxxxxxxx.BIN
		      TSFLASH /V


2. If you get the following message:

(A)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ The upgrading BIOS version is not compatible with your current motherboard.  ³
³ Please check it on the web, or check it with your vendor.		       ³
³									       ³
³ Transcend Information Inc.-> http://www.transcendusa.com ( English version ) ³
³			    -> http://www.transcend.com.tw ( Chinese version ) ³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> You got a wrong BIOS version. Please download the correct one again.

(B)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ This file is not a correct BIOS file, or it's too old for this MOTHER-BOARD. ³
³ Please check it on the web, or check it with your vendor.		       ³
³									       ³
³ Transcend Information Inc.-> http://www.transcendusa.com ( English version ) ³
³			    -> http://www.transcend.com.tw ( Chinese version ) ³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> You have entered the wrong BIOS file name ( it may not be a BIOS file ).
	  Please input the correct one and retry it again.
 ---> You have entered an old version BIOS file name ( it is too old to fit on
	  this MOTHER-BOARD ). Please use the correct one, or download the
	  correct one on the web again.

(C)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ This file can not be opened correctly. Please check the file existed or not. ³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> You have entered a wrong BIOS file name that does not existed. Or, there
	  is an error on the disk. Please check if the file exists in the disk.

(D)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ This file can not be read correctly. Please check the file.		       ³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> You got a defective disk. Please check the file and disk.

(E)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ We can not find any BIOS file (.BIN) in current directory. Please check it.  ³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> The TSFLASH program can not find the XXXXXXXX.BIN file in current
	  directory. You may have lost the ( .BIN ) file, or you have executed
	  the TSFLASH program at wrong directory.

(F)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ There are too many BIOS files (.BIN) in current directory. Please choose the ³
³ correct one ( by TSFLASH xxxxxxxx.BIN ), or delete the wrong one. You can    ³
³ keep only one file ( .BIN ) in current directory.			       ³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> There are too many BIOS files ( .BIN ) in current directory.
	  You have two ways to solve this problem.
	  1. Please choose the correct BIOS file by TSFLASH xxxxxxxx.BIN to
	     process the BIOS upgrade.
	  2. Please delete the un-used BIOS file, and retry it again.

(G)
ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
³ We can not find the file TSFLASH.OVL. Please check if the file exists or not.³
ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

 ---> The system can not find the TSFLASH.OVL file in current directory. Please
	  check the file and disk.


3. If you do not get any error message shown as above, you are running the
   correct BIOS upgrade operation.

4. Finish the upgrade operation and re-boot to start the new version BIOS.
