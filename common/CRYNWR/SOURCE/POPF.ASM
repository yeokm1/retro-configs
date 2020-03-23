;put into the public domain by Russell Nelson, nelson@crynwr.com

	extrn	is_286: byte

	public	fix_popf
fix_popf:
	cmp	is_286,0		;is this a 286?
	je	fix_popf_not

	push	bp
	mov	bp,sp
	push	bx
	mov	bx,2[bp]		;get their IP.
	add	word ptr [bx-2],(offset popf_subr) - (offset fix_popf)
	pop	bx
	pop	bp
popf_subr:
	iret


fix_popf_not:
;it's not a 286, back-patch our code so that it just does the popf.
	push	bp
	mov	bp,sp
	push	bx
	mov	bx,2[bp]		;get their IP.
	mov	word ptr [bx-4],9dh + 90h*256	;popf,nop,nop,nop
	mov	word ptr [bx-2],90h + 90h*256
	pop	bx
	pop	bp
	iret

;On early 286 processors POPF will momentarily enable interrupts even if
;interrupts are currently disabled, and the popped flags still disable them.
popf	macro
	push	cs
	call	fix_popf
	endm

