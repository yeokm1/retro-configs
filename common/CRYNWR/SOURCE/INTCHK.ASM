;put into the public domain by Russell Nelson, nelson@clutx.clarkson.edu

signature	db	'PKT DRVR',0
signature_len	equ	$-signature

	public	chk_int
chk_int:
;enter with al = interrupt number
;exit with es:bx -> interrupt handler, zr if there's a packet driver there,
;exit with nz if no packet driver there.
	mov	ah,35h			;get their packet interrupt.
	int	21h
	lea	di,3[bx]
	mov	si,offset signature
	mov	cx,signature_len
	repe	cmpsb
	ret

