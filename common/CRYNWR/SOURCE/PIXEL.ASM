;put into the public domain by Russell Nelson, nelson@crynwr.com
;code to do graphics at 320x200x256 on both EGAs and VGAs.

; we want to be able to call these routines as if they were real addresses,
; and we don't want to have to index into a table.  Therefore, the init_vid
; routine will copy the correct set of addresses into the following locations.

address_list	label	word
;After calling open_vid, you can't change es, di, dx, or ah.
;al and bx will get trashed, but they need not be preserved.
open_vid	dw	?	;enter with cx,dx=initial point.
move_right	dw	?	;move the point right.
move_left	dw	?	;move the point left.
move_up		dw	?	;move the point up.
move_down	dw	?	;move the point down.
set_bit		dw	?	;set the pixel at the point to al.
set_line	dw	?	;set the row of pixels at the point to
				;the list of cx pixels at ds:si.
close_vid	dw	?	;clean up after open_vid
uninit_vid	dw	?	;clean up after init_vid, return to text mode.
address_end	label	word

ega_adrs	dw	init_vid_ega, open_vid_ega, move_right_ega, move_left_ega
		dw	move_up_ega, move_down_ega, set_bit_ega, set_line_ega
		dw	close_vid_ega, uninit_vid_ega

vga_adrs	dw	init_vid_vga, open_vid_vga, move_right_vga, move_left_vga
		dw	move_up_vga, move_down_vga, set_bit_vga, set_line_vga
		dw	close_vid_vga, uninit_vid_vga


init_vid:
;test for VGA.
	mov	ax,1a00h
	int	10h
	cmp	al,1ah
	mov	si,offset vga_adrs
  ifndef FORCE_EGA
	je	have_vga
  endif
	mov	si,offset ega_adrs
have_vga:
	lodsw				;get the init_vid_* routine.
	push	ds
	pop	es
	mov	di,offset address_list
	mov	cx,(offset address_end - offset address_list) / 2
	rep	movsw
	jmp	ax			;jump to the proper init_vid routine.


init_vid_vga:
	mov	ax,13h			;put the screen into vga mode.
	int	10h

	call	pal_save		;save the palette
	call	pal_setgrey		;set to a gray palette.

	ret

uninit_vid_vga:
	call	pal_restore

	mov	ax,3h			;put the screen into text mode.
	int	10h

	ret


init_vid_ega:
	mov	ax,10h			;put the screen into ega mode.
	int	10h

	mov	ax,1000h		;change the palette entry for 7
	mov	bx,77Q*256 + 7		;  to 77 octal.
	int	10h

	mov	ax,1000h		;. .
	mov	bx,007Q*256 + 08h
	int	10h

	mov	ax,1000h		;. .
	mov	bx,010Q*256 + 09h
	int	10h

	mov	ax,1000h		;. .
	mov	bx,020Q*256 + 0ah
	int	10h

	mov	ax,1000h		;. .
	mov	bx,030Q*256 + 0bh
	int	10h

	mov	ax,1000h		;. .
	mov	bx,040Q*256 + 0ch
	int	10h

	mov	ax,1000h		;. .
	mov	bx,050Q*256 + 0dh
	int	10h

	mov	ax,1000h		;. .
	mov	bx,060Q*256 + 0eh
	int	10h

	mov	ax,1000h		;. .
	mov	bx,070Q*256 + 0fh
	int	10h

	ret


uninit_vid_ega:
	mov	ax,3h			;put the screen into text mode.
	int	10h

	ret


pal_save:
;Save existing palette
	mov	ax,1017h		;get all palette registers.
	mov	bx,0			;first palette register.
	mov	cx,256			;read all palette registers.
	push	ds
	pop	es
	mov	dx,offset save_dacs
	int	10h

	ret


pal_setgrey:
	mov	di,offset gray_dacs
	mov	al,0
pal_setgrey_1:
	mov	cx,3 * 256 / 64		;3 colors, 256 grays, 64 slots.
	rep	stosb

	inc	al
	cmp	al,64
	jb	pal_setgrey_1

	mov	dx,offset gray_dacs
	jmp	short pal_set

pal_restore:
	mov	dx,offset save_dacs
pal_set:
	mov	ax,1012h		;set all palette registers.
	mov	bx,0			;first palette register.
	mov	cx,256			;read all palette registers.
	push	ds
	pop	es
	int	10h

	ret


open_vid_vga:
;enter with cx,dx = point on screen.
;exit with es:di,ah -> byte/bit on screen.
	mov	ax,0a000h
	mov	es,ax
	mov	ax,320			;width of screen.
	mul	dx
	add	ax,cx			;add the offset in.
	mov	di,ax			;remember our pointer.
	ret


move_right_vga:
	inc	di
	ret

move_left_vga:
	dec	di
	ret

move_up_vga:
	sub	di,320			;width of screen.
	ret

move_down_vga:
	add	di,320			;width of screen.
	ret

set_line_vga:
;enter with the current pixel set up, ds:si -> row of pixels, cx=number of
;pixels.  Exit with the same point set up.
	push	di
	shr	cx,1
	rep	movsw
	jnc	set_line_vga_1
	movsb
set_line_vga_1:
	pop	di
	ret


set_bit_vga:
	mov	es:[di],al
	ret

close_vid_vga:
	ret


; the EGA code follows.  It uses a group of four pixels to achieve the
; appearance of 14 different graylevels.

open_vid_ega:
;enter with cx,dx = point on screen.
;exit with es:di,ah -> byte/bit on screen.
	mov	ax,0a000h
	mov	es,ax
	mov	ax,640/8*2		;bytes per scan line * scan lines per pixel
	mul	dx
	mov	di,ax
	mov	ax,cx			;/8*2
	shr	ax,1
	shr	ax,1
	add	di,ax

	mov	dx,03ceh		;graphics controller
	mov	ax,0205h		;write mode 2.
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
	dec	dx
	mov	al,08h			;select bitmap register.
	out	dx,al
	inc	dx

	shl	cx,1			;compute the bit.
	and	cl,7
	mov	ah,80h
	shr	ah,cl
	ret


move_right_ega:
	shr	ah,1			;move right by a bit.
	ror	ah,1			;move right by another bit,
	adc	di,0			;  and handle byte increment.
	ret


move_left_ega:
	rol	ah,1			;move left by a bit,
	adc	di,0			;  and handle byte increment.
	shl	ah,1			;move left by another bit.
	ret


move_up_ega:
	sub	di,80*2			;width of screen.
	ret


move_down_ega:
	add	di,80*2			;width of screen.
	ret


set_line_ega:
;enter with the current pixel set up, ds:si -> row of pixels, cx=number of
;pixels.  Exit with the same point set up.
	push	ax
	push	di
set_line_ega_1:
	lodsb
	call	set_bit
;beginning of in-line move_right
	shr	ah,1			;move right by a bit.
	ror	ah,1			;move right by another bit,
	adc	di,0			;  and handle byte increment.
;end of in-line move_right
	loop	set_line_ega_1
	pop	di
	pop	ax
	ret


set_bit_ega:
	mov	bl,al
	xor	bh,bh

	mov	al,ah
	out	dx,al
	mov	al,ulpal[bx]
	xchg	es:[di],al		;store the palette value.
	mov	al,llpal[bx]
	xchg	es:[di+80],al		;store the palette value.

	shr	ah,1			;move right by a bit.

	mov	al,ah
	out	dx,al
	mov	al,urpal[bx]
	xchg	es:[di],al		;store the palette value.
	mov	al,lrpal[bx]
	xchg	es:[di+80],al		;store the palette value.

	shl	ah,1			;restore the bit.

	ret


close_vid_ega:
	mov	al,0ffh			;mask = all ones.
	out	dx,al
	dec	dx
	mov	ax,0005h		;write mode 0
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al

	ret

ulpal	db	20 dup(00h)
	db	20 dup(09h)
	db	20 dup(0bh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(07h)
	db	20 dup(07h)
	db	20 dup(07h)
	db	20 dup(07h)
urpal	db	20 dup(00h)
	db	20 dup(00h)
	db	20 dup(0ch)
	db	20 dup(0eh)
	db	20 dup(0fh)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(07h)
llpal	db	20 dup(00h)
	db	20 dup(0ch)
	db	20 dup(0ch)
	db	20 dup(0dh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(07h)
	db	20 dup(07h)
lrpal	db	20 dup(00h)
	db	20 dup(0ah)
	db	20 dup(0bh)
	db	20 dup(0bh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(0fh)
	db	20 dup(08h)
	db	20 dup(08h)
	db	20 dup(07h)
	db	20 dup(07h)
	db	20 dup(07h)

save_dacs	db	256 * 3 dup(?)
gray_dacs	db	256 * 3 dup(?)


