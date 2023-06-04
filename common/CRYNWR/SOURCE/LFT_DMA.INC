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
; File:         lft_dma.inc
;
; Description:	Defines for ISA compatible DMA channels' registers.
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lft_dma.ivc  $
;
;   Rev 1.4   10 Feb 1995 11:45:08   WATANABE
;1. Fixed loopback test in lft_ext.asm.  Software appended CRC bit is not set
;   properly in the control byte of the packet data area.
;   
;2. Added copyright banner to all files.   
;
;   
;
;   Rev 1.3   02 Feb 1995 10:18:58   WATANABE
;1. Added code to save and restore node address in LM_Loopback_test for
;   EZStart, so when EZStart gets executed again without reboot, the 
;   node address will be correct.
;
;   
;
;   Rev 1.2   25 Jan 1995 17:52:24   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.1   11 Jan 1995 10:15:54   WATANABE
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
;   Rev 1.0   02 Dec 1994 19:03:02   WATANABE
;Initial Release.
;
;
;+!/? ***********************************************************************


;----------------------------DMA-----------------------------------------
DMA_EXTEND  EQU   400H                ;
DMA_DUMMY   EQU     0H                ; DUMMY FOR CHANNEL 4

; --- MODE ---
DMA_MODE0          EQU  000BH
DMA_MODE1          EQU  00D6H
DMA_BLOCK          EQU  10000000B     ; BLOCK MODE
DMA_INCREMENT      EQU  00000000B     ; INCREMENT MODE
DMA_DISABLE_AUTO   EQU  00000000B     ; DISABLE AUTO INITIALIZATION
DMA_READ_TRANSFER  EQU  00001000B     ; READ TRANSFER
DMA_WRITE_TRANSFER EQU  00000100B     ; WRITE TRANSFER

DMA_32_BY_BYTE     EQU  00001000B     ; 32-BIT I/O, COUNTER BY BYTES
DMA_TYPE_C         EQU  00110000B     ; BURST DMA (TYPE C) TIMING MODE

;---- BASE ADDRESS ----------
DMA_BASE0          EQU  000H          ; BASE ADDRESS 0
DMA_BASE1          EQU  002H          ; BASE ADDRESS 1
DMA_BASE2          EQU  004H          ; BASE ADDRESS 2
DMA_BASE3          EQU  006H          ; BASE ADDRESS 3
DMA_BASE5          EQU  0C4H          ; BASE ADDRESS 5
DMA_BASE6          EQU  0C8H          ; BASE ADDRESS 6
DMA_BASE7          EQU  0CCH          ; BASE ADDRESS 7

DMA_LP0            EQU  087H          ; BASE ADDRESS LOW PAGE 0
DMA_LP1            EQU  083H          ; BASE ADDRESS LOW PAGE 1
DMA_LP2            EQU  081H          ; BASE ADDRESS LOW PAGE 2
DMA_LP3            EQU  082H          ; BASE ADDRESS LOW PAGE 3
DMA_LP5            EQU  08bH          ; BASE ADDRESS LOW PAGE 5
DMA_LP6            EQU  089H          ; BASE ADDRESS LOW PAGE 6
DMA_LP7            EQU  08aH          ; BASE ADDRESS LOW PAGE 7

;---- BYTE COUNT REGISTER
DMA_CNT0          EQU  001H          ; COUNTER REGISTER 0
DMA_CNT1          EQU  003H          ; COUNTER REGISTER 1
DMA_CNT2          EQU  005H          ; COUNTER REGISTER 2
DMA_CNT3          EQU  007H          ; COUNTER REGISTER 3
DMA_CNT5          EQU  0C6H          ; COUNTER REGISTER 5
DMA_CNT6          EQU  0CAH          ; COUNTER REGISTER 6
DMA_CNT7          EQU  0CEH          ; COUNTER REGISTER 7

;---- Clear byte pointer
DMA_B_CLEAR0      EQU   0CH          ; MASTER CLEAR 0-3
DMA_B_CLEAR1      EQU  0D8H          ; MASTER CLEAR 5-7

;---- Request Register
DMA_REQ0          EQU   09H          ; REQUEST 0-3
DMA_REQ1          EQU  0D2H          ; REQUEST 5-7

;---- Status Register
DMA_STAT0         EQU   08H          ; STATUS 0-3
DMA_STAT1         EQU  0D0H          ; STATUS 5-7

;---- Command Register
DMA_COMM0         EQU   08H          ; COMMAND 0-3
DMA_COMM1         EQU  0D0H          ; COMMAND 5-7



