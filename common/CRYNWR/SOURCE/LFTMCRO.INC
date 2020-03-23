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
; File:         lftmcro.inc
;
; Description:  Macro definitions for 9232 LMAC
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lftmcro.ivc  $
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
;   Rev 1.2   25 Jan 1995 17:52:24   WATANABE
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
;   Rev 1.0   02 Dec 1994 19:03:02   WATANABE
;Initial Release.
;
;
;+!/? ***********************************************************************

;/**************************************************************************\
;*                                                                          *
;*      Macro definitions        -scecmcro.inc                              *
;*                                                                          *
;\**************************************************************************/
setprn macro bitno
        push    dx
        push    ax
        pushf
        mov     dx, 378h
        in      al, dx
        or      al, (1 shl bitno)
        out     dx, al
        popf
        pop     ax
        pop     dx
        endm

clrprn macro bitno
        push    dx
        push    ax
        pushf
        mov     dx, 378h
        in      al, dx
        and     al, NOT (1 shl bitno)
        out     dx, al
        popf
        pop     ax
        pop     dx
        endm

resetprn macro
        push    dx
        push    ax
        mov     ax,0
        mov     dx, 378h
        out     dx,al
        pop     ax
        pop     dx
        endm

;-----------------
; MACRO - PUSHALL
;-----------------

PUSHALL	MACRO

        push ds
        push es
        push si
        push di
        push dx
        push cx
        push bx
        ENDM

;----------------
; MACRO - POPALL
;----------------

POPALL 	MACRO

        pop bx
        pop cx
        pop dx
        pop di
        pop si
        pop es
        pop ds
        ENDM
;--------------------------------
; ASM Procedure Start Definition
;--------------------------------
		
ASM_FST_PROCDEF	MACRO	X

IFDEF  EZSTART

	IFDEF	CODE_386
		EVEN
		PUBLIC	FST_&X
	PROC	NEAR
	ELSE
	IFDEF	LARGE
		EVEN
		PUBLIC	FST_&X
FST_&X	PROC	FAR
	ELSE
		EVEN
		PUBLIC	FST_&X
FST_&X	PROC	NEAR
	
	ENDIF
	ENDIF
ELSE
	IFDEF   CODE_386
		EVEN
		PUBLIC  X
X		PROC    NEAR
	ELSE
	IFDEF   LARGE
		EVEN
		PUBLIC  X
X               PROC    FAR
	ELSE
		EVEN
		PUBLIC  X
X               PROC    NEAR
	
	ENDIF
	ENDIF
ENDIF
		ENDM


;--------------------------------
; ASM Procedure Start Definition
;--------------------------------
		
ASM_PROCDEF	MACRO	ProcNameStub

	IFDEF	CODE_386
		EVEN
		PUBLIC	ProcNameStub
ProcNameStub	PROC	NEAR
	ELSE
	IFDEF	LARGE
		EVEN
		PUBLIC	ProcNameStub
ProcNameStub	PROC	FAR
	ELSE
		EVEN
		PUBLIC	ProcNameStub
ProcNameStub	PROC	NEAR
	
	ENDIF
	ENDIF
		ENDM

;------------------------------
; ASM Procedure End Definition
;------------------------------

ASM_FST_PROCEND	MACRO	X


IFDEF  EZSTART
FST_&X          ENDP
ELSE
X               ENDP
ENDIF

		ENDM

;------------------------------
; ASM Procedure End Definition
;------------------------------

ASM_PROCEND	MACRO	ProcNameStub

ProcNameStub		ENDP

		ENDM

;------------------------------
; ASM Procedure call Definition
;------------------------------
ASM_FST_CALL	MACRO	X

IFDEF   EZSTART
	IFDEF	CODE_386
	call	FST_&X
	ELSE
	IFDEF	LARGE
	call	far ptr	FST_&X
	ELSE
		EVEN
	call	near ptr FST_&X
	ENDIF
	ENDIF
ELSE
	IFDEF	CODE_386
	call	X
	ELSE
	IFDEF	LARGE
	call	far ptr	X
	ELSE
		EVEN
	call	near ptr X
	ENDIF
	ENDIF
ENDIF
		ENDM

;------------------------------
; ASM Procedure call Definition
;------------------------------
ASM_CALL	MACRO	ProcCallStub

	IFDEF	CODE_386
	call	ProcCallStub
	ELSE
	IFDEF	LARGE
	call	far ptr	ProcCallStub
	ELSE
		EVEN
	call	near ptr ProcCallStub
	ENDIF
	ENDIF
		ENDM


;
;       IncUMACCounter 
;
;       increment the counter in the UMAC data space (Adapter structure)
;

IncUMACCounter  macro	counter

IFDEF   CODE_386
        mov     rDI, pAS. counter
ELSE
	 les     rDI, pAS. counter
ENDIF
        add     word ptr pEDI, 1
IFNDEF  COUNTER16
        adc     word ptr pEDI+2, 0
ENDIF

			endm


;
;       SelectBank
;
;       Changes to the SCEC bank of registers specified in the bank parameter
;

SelectBank              macro   bank

	push    ax
	mov     dx, pAS.BankSelect
	mov     ax, bank
;       shl     al, 1
;       shl     al, 1
;       shl     al, 1
;       shl     al, 1
	out     dx, al
	pop     ax

			endm




;
;       WaitForMMUReady
;
;       Polls the MMU busy bit (LSB of MMUCommandRegister) until it is 0
;

WaitForMMUReady         macro
	LOCAL   ReadAgain,MMUOK
	mov     rCX, 10
ReadAgain:                                      ;Wait until MMU is ready
	in      ax, dx                          ;Increment counters on timeout
	test    ax, MMUBusyMask
	jz      MMUOK
	loop    ReadAgain

IFDEF  DEBUG
	add     pAS.MMUTimeoutCount, 1
	adc     pAS.MMUTimeoutCount + 2, 0
ENDIF

MMUOK:
			endm

;
;       EnableSCECInterrupts
;
;       Enables Tx, Rx, RxOvrn and EPH interrupts by writting '1's 
;       to Interrupt Mask Register. If AllocationRequestedFlag = 1 
;       it also enables Allocation interrupt.
;        

EnableSCECInterrupts    macro
	LOCAL   SkipEnableAllocInt

	mov     dx, pAS.Interrupt               ;Enable the board's interrupt 
	inc     dx                              ; line
	mov     al, SCECUnmaskByte              
	cmp     pAS.AllocationRequestedFlag, 0
	je      SkipEnableAllocInt
	or      al, AllocationIntEna            ;In case allocation failed we 
SkipEnableAllocInt:                             ; also set allocint bit
	out     dx, al  

			endm


;
;       PreventViolatingHardwareTimings
;
;       This macro does a read operation to the Pointer Register
;       to prevent violations of the hardware timings. It is used
;       in the following cases:
;
;       1) Between setting the Pointer for a Rd. operation
;          and reading from Data Register
;       2) Between writing to the Data Register and reloading
;          the Pointer
;

PreventViolatingHardwareTimings macro

       push    dx
       push    ax
       mov     dx, 061h
	in      ax, dx
       pop     ax
       pop     dx

				endm

;
;       SetMaxMSMTxFreeCount
;
;       This macro copies the contents of the SCECTxQueueSize variable
;       to MSMTxFreeCount
;
;       CAUTION:        It destroys the contents of the al register.
;

SetMaxMSMTxFreeCount    macro
	
	mov     al, SCECTxQueueSize
	mov     MSMTxFreeCount, al

			endm

;
;       Convert256ByteUnitsToSCECPages
;
;       Shifts SCECShrForSCECPage times to the right the value given 
;       in ax.

Convert256ByteUnitsToSCECPages  macro
	LOCAL   DontShift

	cmp     pAS.SCECShrForPageSize, 0
	je      DontShift
	push    cx
	mov     cl, pAS.SCECShrForPageSize
	shr     ax, cl
	pop     cx
DontShift:

				endm

