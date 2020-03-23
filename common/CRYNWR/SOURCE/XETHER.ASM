;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; (C) Copyright 1992 Standard Microsystems Corp. All rights reserved.
;
; XETHER.ASM	Extended LMAC Routines for Ethernet adapters
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.xlist
;include	POPFF.MAC
.list


IFNDEF  EZSTART
ifdef	LARGE
extrn	InternalLoopback:	far
else
extrn	InternalLoopback:	near
endif
ENDIF

db		'@(#) SMC Ethernet Extended Lower MAC Module v1.8',0,'$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Nic_Test	Tests Ethernet Network Interface controller chips
;			8390, 690, 790.
;
;		Entry:	ds:[bp]	Ptr to adapter structure
;		Exit:	AX	Ret code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC     LM_Nic_Test
		push	bx
		push	cx
		push	dx
		pushf
		cli
		mov	ax, ds:[bp].nic_type
		cmp	ax, NIC_8390_CHIP
		je	Test690Nic
		cmp	ax, NIC_690_CHIP
		je	Test690Nic
		cmp	ax, NIC_790_CHIP
		je	Test790Nic
		jmp	UnsupportedNicChip
Test790Nic:			     		; Test 790 NIC in 690 mode.
		mov	al, CMD_PAGE2
		call	Select690Page
		mov	dx, ds:[bp].io_base
		add	dx, REG_ENH
		mov	al, 0
		out	dx, al
		
Test690Nic:

;;; The first test writes a test pattern to the PhysAddrRegs (page 1), then
;;; writes the data pattern inverted to the same regs on page 0. The data
;;; written to the page 1 regs is then compared against the original data
;;; pattern. This test verifies that there is a NIC out there. The offsets
;;; tested are 11h thru 17h.

		mov	al, CMD_PAGE1+CMD_STP
		call	Select690Page
		mov	al, NIC_TEST_PATTERN	; Get test value
		mov	ah, al			; Save test value in AH for comparison.
		mov	bx, REG_PAR0		; Fill pg 1 regs with test pattern
		mov	cx, 1			; 
		call	Fill690Regs
		mov	al, 0FFh		; Set compare mask.
		call	Comp690RegData
		jc	Nic690RegisterError

		mov	al, CMD_PAGE0+CMD_STP	; Select page 0
		call	Select690Page
		mov	al, ah			; Get test pattern in AL
		not	al			; Invert test pattern
		call	Fill690Regs		; Fill pg 0 regs with inverted pattern
		mov	al, CMD_PAGE1+CMD_STP
		call	Select690Page		; Switch back to page 1
		mov	al, 0FFh		; Set compare mask.
		call	Comp690RegData		; Previous data written to page
		jc	Nic690RegisterError	; 1 registers should be intact.

;;; The second test verifies data that is read and written on different pages. This
;;; test verifies page 2 access, as well as access to the one of the remaining registers
;;; that were not covered in the first test.

;		mov	al, CMD_PAGE0+CMD_STP
;		call	Select690Page
;		mov	dx, ds:[bp].io_base
;		add	dx, REG_CNTR2
;		in	al, dx			; Clear MP count (if any).
;		mov	dx, ds:[bp].io_base
;		mov	ah, 01Fh
;		mov	al, ah			; 
;		mov	bx, REG_IMR
;		mov	cx, 1			; Fill the IMR with test
;		call	Fill690Regs		; pattern.
;		mov	al, 01Fh		; Set compare mask.
;		call	Comp690RegData		; This data should not compare ok.
;		jnc	Nic690RegisterError
;		mov	al, CMD_PAGE2+CMD_STP
;		call	Select690Page
;		mov	al, 01Fh		; Set compare mask.
;		call	Comp690RegData
;		jc	Nic690RegisterError	; The register written on page 0
						; is read accessed on page 2.
		mov	al, CMD_PAGE0+CMD_STP	; Restore NIC to Page 0.
		call	Select690Page
		mov	ax, SUCCESS
LmNicTestExit:
		$POPFF
		pop	dx
		pop	cx
		pop	bx
		ret
Nic690RegisterError:
		mov	ax, NIC_REG_ERROR
		jmp	LmNicTestExit
UnsupportedNicChip:
		mov	ax, UNSUPPORTED_NIC_CHIP
		jmp	LmNicTestExit

ASM_ETH_PROC_END  LM_Nic_Test

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   LM_Internal_Loopback_Test
;
;	Performs Internal Loopback test on adapter indicated by DS:[BP].
;
;	
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IFNDEF  EZSTART

ASM_PROCDEF     LM_Internal_Loopback_Test

		push	bx
		push	cx
		push	dx
		push	ds
		push	es

;		les	bx, ds:[bp].easp	; ES:BX points to extended
;						; adapter structure.
;		mov	ah, es:[bx].loopback_mode
;		cmp	ah, LPBK_MODE3
;		je	LpbkModeSupported
;		cmp	ah, LPBK_MODE2
;		je	LpbkModeSupported
;		cmp	ah, LPBK_MODE1
;		je	LpbkModeSupported
;		cmp	ah, LPBK_MODE0
;		je	LpbkModeSupported
;		jmp	LpbkModeNotSupported
;LpbkModeSupported:
		call	InternalLoopback
IntLoopExit:
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bx
		ret
;LpbkModeNotSupported:
;		mov	ax, MODE_NOT_SUPPORTED
;		jmp	IntLoopExit
ASM_PROCEND     LM_Internal_Loopback_Test

ENDIF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Select690Page	Selects 8390/690 register page
;
;		Entry:	AL =	CMD_PAGE0
;				CMD_PAGE1
;				CMD_PAGE2
;
;		Exit:	All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	Select690Page
endif
Select690Page	proc	near

		push	ax
		push	dx
		push	es

		or	al, CMD_RD2			; OR in Remote DMA complete
							; for 8390's
		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		jne	AccessPorts
		mov	es, word ptr ds:[bp].ram_access.2
		mov	es:[REG_OFFSET+REG_CMD], al
		jmp	PageSelected
AccessPorts:
		mov	dx, ds:[bp].io_base 
		add	dx, REG_CMD
		out	dx, al
PageSelected:
		pop	es
		pop	dx
		pop	ax
		ret

Select690Page	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Fill690Regs	Fills 690 regs with single byte pattern
;
;	Entry:	ds:[bp]	Ptr to Adapter structure
;		AL	Data pattern
;		CX	Count of registers to fill
;		BX	Starting offset from I/O base address
;
;	Exit:	All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	Fill690Regs
endif
Fill690Regs	proc	near

		push	bx
		push	cx
		push	dx
		push	ds
		push	es
		push	si

		mov	es, word ptr ds:[bp].ram_access.2
		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		jne	FillIoRegs
		mov	di, bx				; Get offset parameter in DI.
		add	di, REG_OFFSET			; Add offset of PCM card register
FillLoop:						; set.
		stosb
		jmp	$+2
		loop	FillLoop
		jmp	WroteAllData
FillIoRegs:
		mov	dx, ds:[bp].io_base
		add	dx, bx
WriteIoRegs:
		out	dx, al
		jmp	$+2
		inc	dx
		loop	WriteIoRegs
WroteAllData:
		pop	si
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bx
		ret

Fill690Regs	endp		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Comp690RegData	Compares data in 690 regs with single byte pattern
;			in AH.
;
;	Entry:	ds:[bp]	Ptr to Adapter structure
;		AL	Bitwise Mask, 0 = mask all, FFh = mask none.
;		AH	Data pattern
;		CX	Count of registers to Comp
;		BX	Starting offset from I/O base address
;
;	Exit:	CARRY	Set if miscompare occurred.
;			All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	Comp690RegData
endif
Comp690RegData	proc	near

		push	ax
		push	bx
		push	cx
		push	dx
		push	es
		push	si

		mov	dx, ds:[bp].io_base
		add	dx, bx				; Add offset for I/O type

		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		jne	UseIoPorts
		mov	si, bx				; Get offset parameter in DI.
		add	si, REG_OFFSET			; Add offset of registers
UseIoPorts:
		mov	bx, ax				; Save mask in BL
CompLoop:
		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		jne	GetIoData
		push	ds
		mov	ds, word ptr ds:[bp].ram_access.2
		lodsb					; Get value in AL (Mem Mapped),
		pop	ds
		jmp	GotData				; (SI automatically increments).
GetIoData:
		in	al, dx				; Get value in AL (IO Mapped).
GotData:
		and	al, bl				; Mask off unwanted bits.
		inc	dx
		cmp	al, ah
		jne	CompDataError
		loop	CompLoop
		clc
Comp690DataExit:
		pop	si
		pop	es
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
CompDataError:
		stc
		jmp	Comp690DataExit
Comp690RegData	endp

