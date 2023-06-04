;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Copyright (C) 1992 Standard Microsystems Corporation.
;	All Rights Reserved.
;
;	REEROM.ASM	Routines for reading 584 EEROM checksum.
;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; -------------- Include Files -------------------
;.xlist
;include	BICNIC.INC
;include	LMSTRUCT.INC
;include	EEROM.INC
;.list

PUBLIC	Read584Checksum
PUBLIC	SumEERomData
PUBLIC	RecallEERomData
PUBLIC	SelectOtherRegister

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Read584Checksum
;
;	On Call:	ASPtr	Pointer to Adapter Structure
;
;	Returns:	AX	SUCCESS
;				HARDWARE_FAILED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Read584Checksum		proc	near
	push	bx
	push	cx
	push	dx
	push	si
	pushf
	cli
	xor	si, si
	mov	cx, 16
	mov	bh, 0
	mov	bl, 8
	mov	dx, ASPtr.io_base
LoopSummit:
	call	SumEERomData
	add	si, ax
	inc	bh
	loop	LoopSummit
	mov	ax, si
	cmp	al, CHECKSUM
	mov	ax, SUCCESS
	je	CheckSumSuccess
	mov	ax, EEROM_CKSUM_ERROR
CheckSumSuccess:
	popf
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
Read584Checksum		endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SumEERomData	sums 584 EEROM data
;
;			Entry:	BH	Bank number
;				BL	Number of bytes to sum
;			      	DX	I/O Base Address
;
;			Return:	AL	Sum
;				AH	0
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SumEERomData		proc	near

	push	bx
	push	cx
	push	dx
	push	di
	mov	di, dx		; Save I/O base addr in DI

	call	SelectOtherRegister

	mov	dx, di		; Get I/O address

	add	dx, REG_EAR	; Add EEROM Reg offset
	in	al, dx		; Get current EEROM reg contents
	and	al, 0Fh		; Mask off EEROM page bits
	mov	cl, 4		; 
	shl	bh, cl		; Get page number aligned in hi nibble
	or	al, bh		; OR in with remaining contents of EAR
	out	dx, al		; Write back to EEROM addr register.
	
	mov	dx, di		; Get I/O addr in DX

	mov	al, RECALL_DATA
	call	RecallEERomData	; Offsets 08 thru 0F (LAN Address Regs)
				; now contain the entire bank of EEROM data.
	xor	cx, cx		; 
	mov	cl, bl		; Get # of bytes to sum in CX
	mov	dx, di		; Get I/O base address
	add	dx, REG_LAR0	; Get offset of first LAN addr reg.
	xor	ax, ax
SumLoop:
	in	al, dx
	add	ah, al
	inc	dx
ifdef	NEC
	inc	dx
endif
	loop	SumLoop		; Sum CX bytes

	mov	dx, di		; Get I/O base address

	mov	al, RECALL_LANADDR
	call	RecallEERomData

	mov	al, ah
	xor	ah, ah	
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
SumEERomData		endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SelectOtherRegister	DX = I/O base address
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SelectOtherRegister	proc	near
	push	ax
	push	dx
	add	dx, REG_ICR
	in	al, dx	   	; Get ICR contents
	and	al, ICR_IR2	; Mask off all but IR2 bit
	or	al, ICR_OTH	; 
	out	dx, al		; Select "OTHER" register access
	pop	dx
	pop	ax
	ret
SelectOtherRegister	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RecallEERomData		DX = I/O base address
;				AL = Flag: RECALL_DATA
;				     	   RECALL_LANADDR
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RecallEERomData		proc	near
	push	ax
	push	dx
	mov	ah, al
	add	dx, REG_ICR	; Get offset of ICR
	in	al, dx		; Get contents of ICR
	and	al, ICR_IR2	; Mask off all but IRQ bit 2
	or	al, ICR_RLA
	cmp	ah, RECALL_LANADDR
	je	WritePortData
	or	al, ICR_OTH
WritePortData:
	out	dx, al
PollRLA:
	jmp	$+2
	in	al, dx
	test	al, ICR_RLA
	jnz	PollRLA
	pop	dx
	pop	ax
	ret
RecallEERomData		endp
