;put into the public domain by Russell Nelson, nelson@crynwr.com

dump_hex:
;enter with ds:si -> data to dump in hex & ASCII, cx = length.
	xor	bx,bx
dump_hex_0:
	push	cx
	cmp	cx,16
	jb	dump_hex_1
	mov	cx,16
dump_hex_1:
	call	dump_line
	pop	cx
	add	bx,16
	sub	cx,16
	ja	dump_hex_0
	ret


dump_line:
;enter with ds:si -> data to dump in hex & ASCII, cx = length (<16),
;  bx = offset.
;exit with si advanced by cx.
	push	cx
	mov	ax,bx
	call	wordout
	pop	cx
	mov	al,' '
	call	chrout
	call	chrout
	push	cx
dump_line_1:
	lodsb
	push	cx
	call	byteout
	pop	cx

	mov	al,' '			;put a dash in the middle.
	cmp	cx,9
	jne	dump_line_7
	mov	al,'-'
dump_line_7:
	call	chrout

	loop	dump_line_1
	pop	ax

	push	ax
	mov	cx,16
	sub	cx,ax
	mov	al,' '
	jcxz	dump_line_3
dump_line_2:
	call	chrout
	call	chrout
	call	chrout
	loop	dump_line_2
dump_line_3:
	call	chrout
	pop	cx
	sub	si,cx
dump_line_4:
	lodsb
	cmp	al,' '
	jb	dump_line_5
	cmp	al,7fh
	jb	dump_line_6
dump_line_5:
	mov	al,'.'
dump_line_6:
	call	chrout
	loop	dump_line_4
	call	crlf
	ret

