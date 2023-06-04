;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
;	(c) COPYRIGHT 1995 Standard Microsystems Corporation,
;	ALL RIGHTS RESERVED.
;
; File:         lft_opts.inc
;
; Description:  compiling options switches for 9232 LMAC
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lft_opts.ivc  $
;
;   Rev 1.4   10 Feb 1995 11:45:08   WATANABE
;1. Fixed loopback test in lft_ext.asm.  Software appended CRC bit is not set
;   properly in the control byte of the packet data area.
;   
;2. Added copyright banner to all files.   
;
;   
;
;   Rev 1.3   02 Feb 1995 10:19:00   WATANABE
;1. Added code to save and restore node address in LM_Loopback_test for
;   EZStart, so when EZStart gets executed again without reboot, the 
;   node address will be correct.
;
;   
;
;   Rev 1.2   25 Jan 1995 17:52:26   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.1   11 Jan 1995 10:15:56   WATANABE
;1. Fixed a problem in TxIntr when restoring pointer register.  
;2. Enabled strip CRC bit in Receive Control Register.  Disable strip
;   CRC was a workaround for Rev. C and prior FEAST chip when there
;   were data corruption at the end of the frame.
;3. Added workaround for Rev. D FEAST chip.  For maximum Ethernet
;   frame size 1514 bytes, the TooLong bit in Receive Status word will
;   be set incorrectly.  LMAC will ignore that status.
;4. Fixed LM_Loopback_Test by adding delay after setting the transmit
;   control register.
;   
;
;   Rev 1.0   02 Dec 1994 19:03:00   WATANABE
;Initial Release.
;
;
;+!/? ***********************************************************************




;*************************************************************************
;                       Compiling Options Switches
;*************************************************************************
;
;
;       The standard version of the SMC9000 ODI driver compiles with
;       all of this switches set to 0
;
;
;
;       Debbuging options
;       -----------------
;

K9DEBUG         EQU     0        ;DEBUG = 1             Debugging enabled
				 ;                      Outputs tracing
				 ;                      characters to the 
				 ;                      screen.

K9SHOW_REGS     EQU     0        ;SHOW_REGS = 1         Outputs 91C90
				 ;                      registers' contents
				 ;                      to the screen.

COLOR           EQU     1        ;COLOR = 1             Selects color monitor
				 ;                      Monochrome if 0. It 
				 ;                      only affects the DEBUG
				 ;                      and SHOW_REGS options
				 ;                      Set it according to 
				 ;                      to your monitor type.


;
;       Testing options
;       ---------------
;

TESTING_PARSER  EQU     0        ;TESTING_PARSER = 1    Enables searching
				 ;                      AVAILABLE_MEM_SIZE,
				 ;                      SCEC_TX_QUEUE_SIZE
				 ;                      and TX_VARS (the 
				 ;                      latter only when
				 ;                      SPECIAL_VARS = 1)
				 ;                      keywords in NET.CFG 
				 ;                      file.

MEM_UTIL        EQU     0        ;MEM_UTIL = 1          Memory utilization
				 ;                      statistics enabled

SPECIAL_VARS    EQU     0        ;SPECIAL_VARS = 1      Selects special mem
				 ;                      utilization vars.
				 ;                      Select between Tx or
				 ;                      or Rx vars using the
				 ;                      TX_VARS keyword
				 ;                      NOTE: Only available
				 ;                      if MEM_UTIL = 1

EARLYTX         EQU     0        ;EARLYTX = 1           CopyTxData does an 
				 ;                      early enqueue of the
				 ;                      packet (after MEDIA
				 ;                      HEADER is copied)
				 ;
				 ;      ONLY FOR PERFORMANCE TESTING.
				 ;      BE CAREFUL !!! MAY HANG SLOW
				 ;      MACHINES


