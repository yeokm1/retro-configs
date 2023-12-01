hexout_ptr	dw	0
hexout_color	db	70h

hexout_set:
	mov	cs:hexout_color,ah
	call	hexout_byte
	mov	cs:hexout_color,70h
	ret

hexout_more:	;old name for this subr.
hexout_byte:
	push	di
	mov	di,cs:hexout_ptr
	call	hexout
	add	di,4
	cmp	di,25*80*2
	jb	hexout_byte_1
	xor	di,di
hexout_byte_1:
	mov	cs:hexout_ptr,di
	pop	di
	ret

hexout:
;enter with al = number, di->place on screen to store chars.
	push	ax
	push	es

	push	di
	mov	di,0b800h
	mov	es,di
	pop	di

	push	ax
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1
	call	nibble2hex
	mov	byte ptr es:[di+0],al
	mov	al,cs:hexout_color
	mov	byte ptr es:[di+1],al
	pop	ax
	call	nibble2hex
	mov	byte ptr es:[di+2],al
	mov	al,cs:hexout_color
	mov	byte ptr es:[di+3],al

	mov	byte ptr es:[di+4],' '	;output a space as a cursor.
	mov	al,cs:hexout_color
	xor	al,11h
	mov	byte ptr es:[di+5],al

	pop	es
	pop	ax
	ret


nibble2hex:
	and	al,0fh
	add	al,90h			;binary digit to ascii hex digit.
	daa
	adc	al,40h
	daa
	ret


hexout_char:
;enter with al = character
	push	ax
	push	es
	push	di

	mov	di,0b800h
	mov	es,di

	mov	di,cs:hexout_ptr
	mov	ah,cs:hexout_color
	stosw
	cmp	di,25*80*2
	jb	hexout_char_1
	xor	di,di
hexout_char_1:
	mov	cs:hexout_ptr,di
	xor	ah,11h
	stosw

	pop	di
	pop	es
	pop	ax
	ret


hexout_word:
	push	ax
	push	ax
	mov	al,ah
	mov	ah,07h
	call	hexout_set
	pop	ax
	mov	ah,07h
	call	hexout_set
	pop	ax
	ret
