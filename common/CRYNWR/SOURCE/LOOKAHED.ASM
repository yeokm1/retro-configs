;*****************************************************************************
;
; Copyright (C) 1992 Standard Microsystems Corp. All rights reserved.
;
; Program Name:	Standard Microsystems Lower MAC driver Receive Look Ahead Code.
;
; Filename:	LOOKAHED.ASM
;
; Date Created:	06-12-92
;
; Version:	1.04a
;		     
; Programmers: Michael Steiger
;
; Files used:	
; Modifications:	
;
;	11-11-93 B. Maynard - Modified SetLookaheadMode so 8-bit adapters
;                             do not qualify for RX_VALID_LOOKAHEAD.
;
;	02-12-93 M. Steiger - Changed LAAR_HOLD to LAAR_ENTER.
;
;	03-29-93 M. Steiger - Modified SetLookaheadMode so 790 adapters whose
;			      Zero Wait State flag is set do not qualify for
;			      RX_VALID_LOOKAHEAD.
;
;	07-08-93 M. Steiger - Modified SetLookahedMode so 790 adapters in
;			      8 bit slots do not qualify for RX_VALID_LOOKAHEAD.
;
;	07-08-93 M. Steiger - Modified SetLookahedMode so 790 adapters do not
;			      qualify for RX_VALID_LOOKAHEAD.
;
; Comments:
;
; No part of this file may be duplicated, revised, translated, localized or 
; modified in any manner or compiled, linked or uploaded or downloaded to or 
; from any computer system without the prior written consent of Standard
; Microsystems Corp.
;
;*****************************************************************************
BYTE_PATTERN_1		equ	66h
BYTE_PATTERN_2		equ	99h

ifdef	CODE386
	ASPTR		equ	DS:[EBP]
	SINDX		equ	ESI
	DINDX		equ	EDI
	
else
	ASPTR		equ	DS:[BP]
	SINDX		equ	SI
	DINDX		equ	DI
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SetLookAheadMode	Determines if adapter RAM can be accessed
;				directly by other driver layers.
;
;	Entry:	ASPTR		Pointer to Adapter Structure
;
;	Exit:	Modifies flag RX_VALID_LOOKAHEAD in adapter_flags field.
;		Modifies flag FORCED_16BIT_MODE in adapter_flags field.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC SetLookAheadMode
SetLookAheadMode	proc	near

		push	ax
		test	ASPTR.adapter_flags, FORCED_16BIT_MODE
		jnz	SetLookAheadFlag

		cmp	ASPTR.nic_type, NIC_790_CHIP
		je	AllDone				; Can't do lookahead if 790 ZWS is set.

		cmp	ASPTR.pc_bus, PCMCIA_BUS
		je	SetLookAheadFlag
		and	ASPTR.adapter_flags, not RX_VALID_LOOKAHEAD+FORCED_16BIT_MODE 
Check16BitSlot:
		test	ASPTR.extra_info, SLOT_16BIT
		jz	CheckMicroChannel
		call	CheckAT16BitMode
		jnz	AllDone
		jmp	SetLookAheadFlag
CheckMicroChannel:
		test	ASPTR.board_id, MICROCHANNEL
		jz	SetLookAheadFlag
;		jz	Check790ZWS

		mov	ax, ASPTR.extra_info
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_594_CHIP
		je	SetLookAheadFlag
		jmp	AllDone
;Check790ZWS:
;		test	ASPTR.mode_bits, ZERO_WAIT_STATE_MASK	; No valid lookahead on 790's
;		jz	SetLookAheadFlag
;		cmp	ASPTR.nic_type, NIC_790_CHIP
;		je	AllDone				; Can't do lookahead if 790 ZWS is set.

SetLookAheadFlag:
		test	ASPTR.extra_info, SLOT_16BIT    ; test if we're an 16-bit adapter again
		jz	AllDone

		or	ASPTR.adapter_flags, RX_VALID_LOOKAHEAD		

AllDone:	pop	ax
		ret

SetLookAheadMode	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	CheckAT16BitMode	Tests to see if another device is asserting
;				MEMCS16 on the AT bus. This is accomplished
;				by writing two bytes to shared memory with
;				the adapter in 8 bit mode. If the odd byte
;				is garbage, there is some other device
;				asserting MEMCS16.
;
;				If ASPTR.ram_base > 100000, FORCED_16BIT_MODE
;				is set.
;
;				If ASPTR.ram_base < C0000, FORCED_16BIT_MODE
;				is cleared.
;				
;
;	Entry:	ASPTR points to the adapter structure
;	Exit:	AX  = 0: ASPTR.adapter_flags |= FORCED_16BIT_MODE
;		AX != 0: ASPTR.adapter_flags &= ~FORCED_16BIT_MODE
;
;	NOTE:	This routine cannot provide reliable results unless a RAM
;		test is performed first to verify RAM integrity.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckAT16BitMode		proc	near

		push	bx
		push	cx
		push	dx
		push	DINDX
		push	SINDX
		test	word ptr ASPTR.ram_base+2, 0F0h
		jnz	SetForcedMode		; If RAM base address is >
						; 100000h, set forced mode.
		test	word ptr ASPTR.ram_base+2, 04h
		jz	CantDo16BitMode		; If RAM base address is < C0000h,
						; we cannot do forced mode.
ifndef	CODE386
		push	ds
		push	es
endif
		mov	dx, ASPTR.io_base
		add	dx, REG_LAAR
		mov	al, ASPTR.laar_exit	; Put in 8 bit mode.
		out	dx, al
		jmp	$+2
		in	al, dx
ifdef	CODE386
		mov	edi, ASPTR.ram_access
else
		mov	ax, word ptr ASPTR.ram_access+2
		mov	es, ax
		mov	ds, ax
		xor	di, di
endif
		mov	SINDX, DINDX
		mov	ah, BYTE_PATTERN_1
		mov	al, BYTE_PATTERN_2
		stosb
		mov	al, ah
		stosb
		lodsb
		mov	ah, al
		lodsb

ifndef	CODE386
		pop	es
		pop	ds
endif
		cmp	al, BYTE_PATTERN_1
		jne	CheckTwo
		jmp	CantDo16BitMode
CheckTwo:	cmp	ah, BYTE_PATTERN_2
		je	SetForcedMode
CantDo16BitMode:
		mov	bx, -1
		and	ASPTR.adapter_flags, not FORCED_16BIT_MODE
		jmp	CheckModeComplete
SetForcedMode:
		or	ASPTR.adapter_flags, FORCED_16BIT_MODE
		mov	bx, 0
CheckModeComplete:
		mov	dx, ASPTR.io_base
		add	dx, REG_LAAR
		mov	al, ASPTR.laar_exit
		out	dx, al
ifdef	CODE386
		xor	eax, eax
endif
		mov	ax, bx			; Get Ret code in AX
		pop	SINDX
		pop	DINDX
		pop	dx
		pop	cx
		pop	bx
		or	ax, ax		; Set flags
		ret
CheckAT16BitMode		endp
