;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Copyright (C) 1992 Standard Microsystems Corporation.
;	All Rights Reserved.
;
;	WEEROM.ASM	Routines for computing/writing 584 EEROM checksum.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


PUBLIC	Write584Checksum
PUBLIC	WriteCheckSumByte


; -------------- Include Files -------------------

;.xlist
;include	LMSTRUCT.INC
;include	BICNIC.INC
;include	EEROM.INC
;.list


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Write584Checksum
;
;	On Call:	ASPtr	Pointer to Adapter Structure
;
;	Returns:	AX	SUCCESS
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ifdef	LARGE
Write584Checksum	proc	far
else
Write584Checksum	proc	near
endif

	push	bx
	push	cx
	push	si
	pushf
	cli
	xor	si, si
	mov	cx, 15
	mov	bh, 0
	mov	bl, 8
	mov	dx, ASPtr.io_base
LoopLoop:
	call	SumEERomData
	add	si, ax
	inc	bh
	loop	LoopLoop
	mov	bl, 7
	call	SumEERomData
	add	ax, si
	mov	ah, CHECKSUM
	sub	ah, al
	call	WriteCheckSumByte
	mov	ax, SUCCESS
	$POPFF
	pop	si
	pop	cx
	pop	bx
	ret

Write584Checksum	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	WriteCheckSumByte
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WriteCheckSumByte	proc	near

	push	bx
	push	cx
	push	dx
	push	di
	mov	di, dx		; Save I/O base addr in DI

	call	SaveConfigZero

	call	SelectOtherRegister

	mov	dx, di		; Get I/O address
	add	dx, REG_EAR	; Add EEROM Reg offset
	in	al, dx		; Get current EEROM reg contents
	or	al, 0F0h	; Set EEROM page 16
	out	dx, al		; Write back to EEROM addr register.
	
	mov	dx, di		; Get I/O addr in DX
	mov	al, RECALL_DATA
	call	RecallEERomData
				; Offsets 08 thru 0F (LAN Address Regs)
				; now contain the entire bank of EEROM data.
	mov	dx, di
	add	dx, REG_CKSM
	mov	al, ah
	out	dx, al		; Write checksum byte in AH to io_base+REG_CKSM

	mov	dx, di		; Get I/O base address
	call	StoreEERomData

;------------ Restore config 0. It was corrupted during the previous
;		store operation.

	mov	dx, di
	add	dx, REG_LAR0
	mov	cx, 8
	lea	bx, cs:ConfigZero
WriteConfigZeroLoop:
	mov	al, cs:[bx]
	out	dx, al
	inc	bx
	inc	dx
	loop	WriteConfigZeroLoop

	mov	dx, di
	add	dx, REG_EAR
	in	al, dx
	jmp	$+2
	and	al, 0Fh		; Select pg 0 by clearing EEROM page bits
	out	dx, al

	mov	dx, di

	call	StoreEERomData

;------------ All done. Recall LAN address and exit.

	mov	dx, di
	mov	al, RECALL_LANADDR
	call	RecallEERomData
	
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
WriteCheckSumByte	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SaveConfigZero		proc	near

	push	ax
	push	bx
	push	cx
	push	dx
	push	di

	mov	bx, dx		; Save I/O base addr in BX

	call	SelectOtherRegister

	mov	dx, bx
	add	dx, REG_EAR
	in	al, dx
	jmp	$+2
	and	al, 0Fh		; Select pg 0 by clearing EEROM page bits
	out	dx, al

	mov	dx, bx
	mov	al, RECALL_DATA
	call	RecallEERomData

	lea	di, cs:ConfigZero
	mov	cx, 8
	mov	dx, bx
	add	dx, REG_LAR0

SaveConfigZeroLoop:
	in	al, dx
	mov	cs:[di], al
	inc	dx
	inc	di
	loop	SaveConfigZeroLoop

	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

ConfigZero	db	8 dup (0)

SaveConfigZero		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	StoreEERomData		DX = I/O base address
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

StoreEERomData		proc	near
	push	ax
	push	dx
	add	dx, REG_ICR
	in	al, dx
	and	al, ICR_IR2	; Mask all but IR2 Interrupt bit.
	or	al, ICR_STO+ICR_OTH ; Set Store bit and Other Reg bit
	out	dx, al
PollStore:
	jmp	$+2
	in	al, dx
	test	al, ICR_STO
	jnz	PollStore	; Poll until store is complete.
	pop	dx
	pop	ax
	ret
StoreEERomData		endp

