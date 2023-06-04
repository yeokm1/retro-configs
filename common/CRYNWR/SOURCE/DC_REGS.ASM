;*******************************************************************************
;
; DC_REGS.ASM
;
; ASM file for Dec Tulip and Fast Ethernet boards that provides chips' Registers
; access routines.
;
;Written by:   Moti Haimovsky
;
; Date:        14-APR-1997
;
;
; Copyright (C) 1994 by Digital Equipment Corporation 
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  23-Apr-1997 2.60  - Modified PutDeviceInSleepMode routine to Reaset PHYER's
;				      SIA for more power saving.
;*******************************************************************************
include  SEG_DEFS.INC
.386
include	DC_REGS.inc
include	Nic.inc
include	SysSrvcs.inc
.8086
include  DC_REGS.ash
.386

START_CODE_SEGMENT_RUNTIME

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       WriteCSR6Reg
;
;       Routine to write CSR6.
;       In Tulip Pass 1 there is a bug when CSR6 is written and a carrier
;       presents on the wire. In order to work around the bug (pass 1 only), we
;       will disable the SIA (and so SIA will not detect carrier), write CSR6
;       with it's value and then rewrite the SIA with it's original value.
;       This workaround may cause receive packet damage (bad CRC etc.) which is
;       acceptable, and also TX which can be damadged.
;       Write to CSR6 happens once in a long while, so the chance of having
;       damages goes to 0.
;
;       Since this routine resets and initializes the SIA registers it has to
;       handle the case of FullDuplex where Tulip is not in AutoConfiguration
;       mode which means that we have to rewrite the other SIA regs (CSR15 and
;       CSR14)
;
;       Called by: o
;
; On Entry:
;
;               Flags:
;
;               Note:   Interrupts disabled.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WriteCSR6Reg       proc    near

	push    eax
	push    dx

	;Write CSR6
	;----------
	mov     dx,  Nic.CSR6_Address
	mov     eax, Nic.Shadow_CSR6
	out     dx, eax

	pop     dx
	pop     eax
	ret

WriteCSR6Reg       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       WriteCSR6Tulip
;
;       Routine to write CSR6.
;       In Tulip Pass 1 there is a bug when CSR6 is written and a carrier
;       presents on the wire. In order to work around the bug (pass 1 only), we
;       will disable the SIA (and so SIA will not detect carrier), write CSR6
;       with it's value and then rewrite the SIA with it's original value.
;       This workaround may cause receive packet damage (bad CRC etc.) which is
;       acceptable, and also TX which can be damadged.
;       Write to CSR6 happens once in a long while, so the chance of having
;       damages goes to 0.
;
;       Since this routine resets and initializes the SIA registers it has to
;       handle the case of FullDuplex where Tulip is not in AutoConfiguration
;       mode which means that we have to rewrite the other SIA regs (CSR15 and
;       CSR14)
;
;       Called by: o
;
; On Entry:
;
;               Flags:
;
;               Note:   Interrupts disabled.
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WriteCSR6Tulip       proc    near
	
	push    eax
	push    dx

	;Reset SIA
	;---------
	xor     eax, eax
	mov     dx, Nic.CSR13_Address
	out     dx, eax

	;Write CSR6
	;----------
	call    WriteCSR6Reg

	;Rewrite the SIA regs
	;--------------------
	call    WriteInternalPhyRegs

	pop     dx
	pop     eax
	ret

WriteCSR6Tulip       endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         WriteGEPRegisterFnet
;
;
;
; Description:
; On Entry:
;               ax        GEP word to be written
;
; On Return:
;
;               Flags:
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WriteGEPRegisterFnet    proc	near

	push    eax
	push    dx

	;Clear high portion of eax
	;-------------------------
	push    ax
	xor     eax, eax
	pop     ax

	mov     dx, Nic.CSR12_Address
	out     dx, eax

WGReg_Exit:
	clc
	pop     dx
	pop     eax
	ret

WriteGEPRegisterFnet    endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         WriteGEPRegisterTwinet
;
;
;
; Description:
; On Entry:
;               ax        GEP word to be written
;
; On Return:
;
;               Flags:
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WriteGEPRegisterTwinet  proc	near

	push    eax
	push    dx

	mov     dx, Nic.CSR15_Address
	mov     Nic.CSR15_.GEP_, ax
	mov     eax, Nic.CSR15_.Value
	out     dx, eax

	pop     dx
	pop     eax
	ret

WriteGEPRegisterTwinet  endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ReadGEPRegisterFnet
;
;
;
; Description:
; On Entry:
;               ax        GEP word Read
;
; On Return:
;
;               Flags:
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadGEPRegisterFnet     proc	near

	push    dx
	push    eax

	mov     dx, Nic.CSR12_Address
	in      eax, dx

	mov     dx, ax
	pop     eax
	mov     ax, dx
	pop     dx
	ret

ReadGEPRegisterFnet     endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         ReadGEPRegisterTwinet
;
;
;
; Description:
; On Entry:
;               ax        GEP word Read
;
; On Return:
;
;               Flags:
;               Note:
; returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ReadGEPRegisterTwinet   proc 	near

	push    dx
	push    eax

	mov     dx, Nic.CSR15_Address
	in      eax, dx
	shr     eax, 16

	mov     dx, ax
	pop     eax
	mov     ax, dx
	pop     dx
	ret

ReadGEPRegisterTwinet   endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       PutDeviceInMode
;
;       Routine Puts the device in the desired mode (If the device is capable
;					             doing so such as Tulip3 or
;						     FasterNet 1.2, 2.0).
;
;       Called by: o
;
;       assumes:        ds      is set to CGroup
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PutDeviceInMode	proc	near

	push	bx
	push	di

	cmp	Nic.BusType, BUS_TYPE_PCI
	jne	SHORT PDIM_NotPCIDevice

	cmp	Nic.CurrentPowerMode, cx
	je	SHORT PDIM_Done

	;Store New mode
	;--------------
	mov	Nic.CurrentPowerMode, cx

	;Write CFDA in a PCI machine
	;---------------------------
	mov	bx, Nic.PCIDeviceAccessHandle
	mov     di, PCI_CFDA_OFFSET + 2                ;Let di point at the High portion of CFDA
	call	PCIWriteCfgWord
PDIM_NotPCIDevice:
PDIM_Done:

	pop	di
	pop	bx
	ret

PutDeviceInMode	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       PutDeviceInSleepMode
;
;       Routine Puts the device in Sleep mode (If the device is capable in doing so
;					       such as Tulip3 or FasterNet 1.2, 2.0).
;
;       Called by: o    Driver ShutDown
;
;       assumes:        ds      is set to CGroup
;
;       returns:       
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PutDeviceInSleepMode	proc	near

	push	eax
	push	cx
	push	dx


	;--------------------------
	;Put the chip in sleep mode
        ;--------------------------
	mov	cx, CFDA_SLEEP_MODE
	call	PutDeviceInMode
        pop	dx
	pop	cx
        pop	eax
	ret

PutDeviceInSleepMode	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       PutDeviceInRunMode
;
;       Routine Puts the device in Run mode (If the device is capable in doing so
;					       such as Tulip3 or FasterNet 1.2, 2.0).
;
;       Called by: o
;
;       assumes:        ds      is set to CGroup
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
PutDeviceInRunMode	proc	near

	push	cx
	mov	cx, CFDA_RUN_MODE
	call	PutDeviceInMode
	pop	cx
	ret

PutDeviceInRunMode	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       ExitFromSleepMode
;
;       Routine moves device from sleep mode to snooze or run modes
;	(If the device is capable in doing so such as Tulip3 or FasterNet 1.2, 2.0).
;	It also waites for chip to recover from this action.
;
;       Called by: o
;
;       assumes:        ds      is set to CGroup
;
;       returns:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ExitFromSleepMode	proc	near

	;If device is NOT in Sleep mode - exit
        ;-------------------------------------
	cmp	Nic.CurrentPowerMode, CFDA_SLEEP_MODE
	jne	SHORT EFSM_Exit

	pushf
	push	cx

	;---------------------------
	;move device from Sleep mode
        ;---------------------------
	mov	cx, CFDA_SNOOZE_MODE
	call	PutDeviceInMode
      
	cli
	push	WORD PTR 20000		;10mSec in Tick-counter ticks
	call	Delay
	add	sp, 2

	pop	cx
	popf

EFSM_Exit:
	ret

ExitFromSleepMode	endp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;       SoftwareResetDevice
;
;       Routine performs software reset to Tulip or Fasternet.
;
;       Called by: o 
;
;       assumes:        ds      is set to CGroup
;                       CLD has been executed
;                       Interrupts are disabled
;
;       returns:        bp      points to Tulip I/O address
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SoftwareResetDevice      proc    near

	push	eax
	push	cx

	;--------------------------------------------------------------------------
	;Exit from sleep mode to the appropriate power mode before starting to work
	;--------------------------------------------------------------------------
	call	ExitFromSleepMode

	mov	cx, Nic.PowerMode
	call	PutDeviceInMode 

IF NOS EQ ODI
	;------------------------------------------------------------------
	;Read and update missed frame counter since it's value will be lost
	;after Tulip reset.
        ;------------------------------------------------------------------
	call	UpdateMissedFrameCounter
ENDIF
	;-----------------------------------
	;Perform software reset to our chip.
        ;-----------------------------------
	xor     eax, eax
	mov     al, CSR0_SWR
	mov     dx, Nic.CSR0_Address
	out  	dx, eax

	call	PostResetDelay

	;-------------------------------------------------------------
	;Leave Device in the needed Burst Limit, Little Endian,
	;Descriptor skip lengtt, internal bus arbitration mode ETC.
	;-------------------------------------------------------------
	mov     eax, Nic.CSR0_Value
	mov     dx, Nic.CSR0_Address
	out  	dx, eax

	;------------------------
	;Update shadow CSR6 value
        ;------------------------
	and     Nic.Shadow_CSR6, NOT (DWORD PTR (CSR6_START_RX_COMMAND OR CSR6_START_TX_COMMAND))

	pop	cx
	pop	eax
        clc
	ret

SoftwareResetDevice      endp

IF NOS EQ ODI
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         UpdateMissedFrameCounter
;
; Description:  This routine reads CSR8 (missed frame counter) and adds the
;               value read from it to the missed frame counter located in
;		the statistics table.                                     
;
;       assumes:
;       returns:   
;       Updates: RxMissedFrame
;
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
UpdateMissedFrameCounter	proc

	push	dx
        push	eax

	;get missed frame counter
        ;------------------------
	mov     dx, Nic.CSR8_Address
	in   	eax, dx				

	;Clear unused bits
	;-----------------
	and	eax, Nic.CSR8_MaskOFF
	jz	SHORT UMFC_Exit			;No readings - No need to update.

	;Update Missed frame statistics counter
        ;--------------------------------------
	push	eax
	and     eax, 1FFFFh                     ;get rid of not used bits
	add	DriverStatRxOverflow, eax	;add it's value to statistics
	pop	eax

	;Update Rx fifo overflow statistics counter 
	;------------------------------------------
	shr	eax, 17		;Align overflow counter
	add	RxFifoOverflow, eax

UMFC_Exit:
	pop	eax
	pop	dx
	ret
UpdateMissedFrameCounter	endp

ENDIF

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:         GenerateTUInterrupt
;
; Description:  This routine generate an interrupt for the DC21X4 chip,
;		by starting and stopping the transmit machine. This
;		generates a TU interrupt. Important : this routine does
;		not write CSR7's TU bit, but only sets this on CSR7_image.
;
;       assumes:
;       returns:
;
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GenerateTUInterrupt	PROC

	push	Nic.Shadow_CSR6
	and	Nic.Shadow_CSR6, not CSR6_START_TX_COMMAND
	call	Nic.WriteCSR6
	or	Nic.Shadow_CSR6, CSR6_START_TX_COMMAND
	call	Nic.WriteCSR6
	pop	Nic.Shadow_CSR6
	test	Nic.Shadow_CSR6, CSR6_START_TX_COMMAND	
	jnz	SHORT gti_set_csr7
	call	Nic.WriteCSR6
gti_set_csr7:
	or	Nic.Shadow_CSR7, CSR7_TUM
	ret

GenerateTUInterrupt	ENDP

END_CODE_SEGMENT_RUNTIME


;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT DC_REGS.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT DC_REGS.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT DC_REGS.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT DC_REGS.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT DC_REGS.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT DC_REGS.ASM Illegal NOS value.
ENDIF



END
