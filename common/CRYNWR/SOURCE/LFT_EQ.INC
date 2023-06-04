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
; File:         lft_eq.inc
;
; Description:  Contains equates for 9232 LMAC
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lft_eq.ivc  $
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
;   Rev 1.0   02 Dec 1994 19:03:00   WATANABE
;Initial Release.
;
;
;+!/? ***********************************************************************



;/**************************************************************************\
; *  RAM size 
;\**************************************************************************/
CNFG_SIZE_64kb		equ	64
CNFG_SIZE_128kb        equ     128



;/**************************************************************************\
; *  registers 
;\**************************************************************************/

IFDEF CODE_386

rAX     equ     <eax>
rBX     equ     <ebx>
rCX     equ     <ecx>
rDX     equ     <edx>
rSI     equ     <esi>
rDI     equ     <edi>
rBP     equ     <ebp>

pAS     equ     <[ebp]>
pBX     equ     <[ebx]>
pSI     equ     <[esi]>
pDI     equ     <[edi]>
pEBX    equ     <[ebx]>
pESI    equ     <[esi]>
pEDI    equ     <[edi]>

ELSE

rAX     equ     <ax>
rBX     equ     <bx>
rCX     equ     <cx>
rDX     equ     <dx>
rSI     equ     <si>
rDI     equ     <di>
rBP     equ     <bp>

pAS     equ     <ds:[bp]>
pBX     equ     <[bx]>
pSI     equ     <[si]>
pDI     equ     <[di]>
pEBX    equ     <es:[bx]>
pESI    equ     <es:[si]>
pEDI    equ     <es:[di]>

ENDIF



;/**************************************************************************\
;*                                                                          *
;*         Definition of SCEC's Constants  - scec_eq.inc                    *
;*                                                                          *
;\**************************************************************************/

;       MMU Commands

NOOP                    equ     0       
AllocateTx              equ     20h             ;To be or-ed depending on the 
						; size to be requested
ResetMMU                equ     40h
RemoveFromTopRXFifo     equ     60h
RemoveReleaseTopRXFifo  equ     80h
ReleaseSpecificPacket   equ     0a0h
EnqueueIntoTXFifo       equ     0c0h
ResetTxFifos            equ     0e0h

;       Pointer Register Selection Bits

ReceiveArea             equ     8000h
AutoIncrement           equ     4000h
ReadMode                equ     2000h

;       Interrupt Status & Mask Bits

SCECUnmaskByte          equ     33h             ;TXEmpty, Alloc. disabled
SCECMaskAllByte         equ     00h     
AllocationIntEna        equ     08h     
AllocationIntDis        equ     0f7h    
ValidInts               equ     3bh
ReceiveInt              equ     01h     
TransmissionInt         equ     02h     
TxEmptyInt              equ     04h     
AllocInt                equ     08h
RxOverrunInt            equ     10h     
EPHInt                  equ     20h     

;       SCEC Register's values after reset

ControlResetValue       equ     00a0h

; 000x 0xx0 100x x000       MMU not bypassed, Doesn't receive packet with bad 
; CRC, Not in PowerDown mode, Not autorelease mode, UDOE disabled, Link Error
; enabled, counter error disabled, transmit error enabled

TCRResetValue           equ     0081h

; xx00 00x0 1xxx x001       No EPH Loop, Doesn't Stop Tx on SQET, No FullDpx,  
; Monitor Carr. off, CRC inserted on TX, Pad w/00 for Frames < 64 bytes, No  
; Force Collisions, No Loopback, Transmit enabled

;
; stripping CRC will work with Rev. D
;
RCRResetValue           equ     0300h
;RCRResetValue           equ     0100h

RCR_ALMUL               equ     0004h           ; accept all multicast

; 00xx 0011 xxxx x000, No reset, No filter carrier, PLL gain = 0, CRC on RX
; striped, Receiver on, Accept multicast matching only, No promiscuous mode,
; Clear RXabort

;       Miscellaneouns Bit Masks

EPHSR_MaskLinkError     equ     4000h   
ControlClrLEMask        equ     0ff7fh
ControlSetLEMask        equ     0080h
AUISelection            equ     0100h   
TwistedSelection        equ     0feffh  
TXENA_SetMask           equ     0001h   
TXENA_ClrMask           equ     0fffeh  
RXENA_ClrMask           equ     0feffh  
FailedBitMask           equ     80h     
OddFrameBitMask         equ     10h
SetOddBitControlByte    equ     2000h
ClrOddBitControlByte    equ     0000h
TEmptyBitMask           equ     80h     
IntSelectionMask        equ     0006h
IntSelectionClrMask     equ     0fff9h
SelectBankMask          equ     0030h
Reload_StoreMask        equ     0003h
ByteCountMask           equ     07ffh
RcvBadMask              equ     4000h
MMUBusyMask             equ     0001h
IssueResetMask          equ     8000h
FlushResetMask          equ     0000h
PRMSBitMask		 equ	0002h
PromiscuousSetBit       equ     0002h
PromiscuousClrBit       equ     0fffdh
RcvBadClrBit            equ     0bfffh
RcvBadSetBit            equ     4000h
CRCErrorBit             equ     0001h
CRCAlignErrorBit        equ     0002h
ClrRAMSizeBit           equ     0ffdfh
SetRAMSizeBit           equ     0020h
FixedBitsOn91C92        equ     0028h
NotFixedBitsOn91C92     equ     0ffd7h
SMC9000Pattern          equ     0033h
ChipFEAST               equ     07h
MIRMultiplierMask       equ     0eh

;       Transmission error bits

SCEC_16Collision        equ     0010h   
SCEC_SQET               equ     0020h   
SCEC_LateCollision      equ     0200h   
SCEC_CarrierSenseLost   equ     0400h   
SCEC_TxUnderrun         equ     8000h   
;
; vvvvv TW - the following is changed for testing
; vvvvv has to confirm with Paul why they used
; vvvvv 8600h instead of 8630h
;
;
;SCEC_FatalErrors	equ	8600h
SCEC_FatalErrors        equ     8630h

;       Transmission Statatistics Bits

SCEC_StatisticsBits     equ     08ceh   
SCEC_SuccessTx          equ     0001h   
SCEC_SingleCollision    equ     0002h   
SCEC_MultipleCollision  equ     0004h   
SCEC_LastTXMulticast    equ     0008h   
SCEC_LastTXBroadcast    equ     0040h   
SCEC_TXDeferred         equ     0080h   
SCEC_ExcessiveDeferral  equ     0800h   

;       Reception Error Bits

SCEC_RXErrorBits        equ     0a400h  
SCEC_TooLongRXFrame     equ     0800h   
SCEC_TooShortRXFrame    equ     0400h   
SCEC_BadRxCRC           equ     2000h   
SCEC_AlignmentError     equ     8000h   

;       Reception Statistics Bits

SCEC_RxBroadcastBit     equ     4000h   
SCEC_RxMulticastBit     equ     01h

;/**************************************************************************\
;*                                                                          *
;*      Miscellaneous constants                                             *
;*                                                                          *
;\**************************************************************************/

SendRetryCount          equ     0    ;No soft retries in this driver version
DefaultMaxTxFreeCount   equ     3    ;Default Init value for MSMTxFreeCount

CR                      equ     13   ;Carriage Return
LF                      equ     10   ;Line Feed

ON                      equ     1
OFF                     equ     0


NumIOPorts              equ     8


