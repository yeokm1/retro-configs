;input a word from IO port
inw	macro
	in	ax,dx			;read IO port
	endm

;write a word to an IO port
outw	macro
	out	dx,ax			;write IO port
	endm

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

;this code inputs from a port that can accept either byte or word transfers.
;if the board is in a 8-bit slot, it always receives byte transfers.
;if the board is in a 16-bit slot, it has the IOCS16 line asserted on word I/O.

repinsw:
; If buffer doesn't begin on a word boundary, get the first byte
	test	di,1			; if(buf & 1){
	jz	ibufeven		;
	in	al,dx			; al = in(dx);
	stosb				; *di++ = al
	dec	cx			; cx--;
	je	icnteven
ibufeven:
	cmp	is_186,0		; Can we use rep insw?
	je	repinsw_1		; no - have to do it slowly.
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
	.286
	rep	insw
	.8086
	jmp	short inobuf
repinsw_1:
; Do the bulk of the buffer, a word at a time
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
	jcxz	inobuf			; if(cx != 0){
rb:	in	ax,dx			; do { al = in(dx);
	stosw				; *si++ = ax; (di is word pointer)
	loop	rb			; } while(--cx != 0);
; now check for odd trailing byte
inobuf:
	jnc	icnteven
	in	al,dx
	stosb				; *di++ = al
icnteven:
	ret


;this code outputs to a port that can accept either byte or word transfers.
;if the board is in a 8-bit slot, it always receives byte transfers.
;if the board is in a 16-bit slot, it has the IOCS16 line asserted on word I/O.

repoutsw:
	test	si,1			; (buf & 1) ?
	jz	obufeven		; no
	lodsb				; al = *si++;
	out	dx,al			; out(dx,al);
	dec	cx			; cx--;
	je	ocnteven
obufeven:
	cmp	is_186,0		; Can we use rep outsb?
	je	out86			; no - have to do it slowly.
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
	.286
	rep	outsw
	.8086
	jmp	short onobuf
out86:
	shr	cx,1			; cx = cnt >> 1; (convert to word count)
; Do the bulk of the buffer, a word at a time
	jcxz	onobuf			; if(cx != 0){
xb:	lodsw				; do { ax = *si++; (si is word pointer)
	out	dx,ax
	loop	xb			; } while(--cx != 0); }
; now check for odd trailing byte
onobuf:
	jnc	ocnteven
	lodsb				;   out(dx,*si++);
	out	dx,al
ocnteven:
	ret
