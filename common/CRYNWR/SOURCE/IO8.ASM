;put into the public domain by Russell Nelson, nelson@clutx.clarkson.edu

;input a word from IO port
inw	macro
	in	al, dx			;read low address byte
	mov	ah, al			;save byte
	in	al,61h			;wait a bit.
	inc	dx			;next IO address
	in	al, dx			;read high address byte
	xchg	ah, al			;swap bytes 
	dec	dx			;restore IO address
	endm

;write a word to an IO port
outw	macro
	out	dx, al			;write low address byte
	push	ax			;wait a little bit.
	in	al,61h
	pop	ax
	xchg	ah, al			;get next byte
	inc	dx			;next IO address
	out	dx, al			;write high address byte
	xchg	ah, al			;restore AX
	dec	dx			;restore DX
	endm

;this code is exactly like the "rep insb" instruction.  It works even if
;you've got an 8088.

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

repinsb:
	cmp	is_186,0		; Can we use rep insb?
	je	repinsb_1		; no - have to do it slowly.
	.286
	rep	insb
	.8086
	jmp	short icnteven
repinsb_1:
; If buffer doesn't begin on a word boundary, get the first byte
	test	di,1			; if(buf & 1){
	jz	ibufeven		;
	in	al,dx			; al = in(dx);
	stosb				; *di++ = al
	dec	cx			; cx--;
ibufeven:
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
; Do the bulk of the buffer, a word at a time
	jcxz	inobuf			; if(cx != 0){
rb:	in	al,dx			; do { al = in(dx);
	mov	ah,al
	in	al,dx			; ah = in(dx);
	xchg	al,ah
	stosw				; *si++ = ax; (di is word pointer)
	loop	rb			; } while(--cx != 0);
; now check for odd trailing byte
inobuf:
	jnc	icnteven
	in	al,dx
	stosb				; *di++ = al
icnteven:
	ret


;this code is exactly like the "rep outsb" instruction.  It works even if
;you've got an 8088.

repoutsb:
	cmp	is_186,0		; Can we use rep outsb?
	je	out86			; no - have to do it slowly.
	.286
	rep	outsb
	.8086
	jmp	short ocnteven
out86:
	test	si,1			; (buf & 1) ?
	jz	obufeven		; no
	lodsb				; al = *si++;
	out	dx,al			; out(dx,al);
	dec	cx			; cx--;
obufeven:
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
; Do the bulk of the buffer, a word at a time
	jcxz	onobuf			; if(cx != 0){
xb:	lodsw				; do { ax = *si++; (si is word pointer)
	out	dx,al			; out(dx,lowbyte(ax));
	mov	al,ah
	out	dx,al			; out(dx,hibyte(ax));
	loop	xb			; } while(--cx != 0); }
; now check for odd trailing byte
onobuf:
	jnc	ocnteven
	lodsb				;   out(dx,*si++);
	out	dx,al
ocnteven:
	ret
