;put into the public domain by Russell Nelson, nelson@crynwr.com
;requires pixel.asm

x_inc		dw	?		;either move_left or move_right
y_inc		dw	?		;either move_up or move_down
larger_delta	dw	?
smaller_delta	dw	?
line_color	db	?

line:
	mov	line_color,al
	mov	ax,move_right
	mov	x_inc,ax
	mov	ax,move_down
	mov	y_inc,ax
	sub	si,cx			;si=delta x
	sub	di,dx			;di=delta y
	or	si,si
	jge	line_to_1
	neg	si
	mov	ax,move_left
	mov	x_inc,ax
line_to_1:
	or	di,di
	jge	line_to_2
	neg	di
	mov	ax,move_up
	mov	y_inc,ax
line_to_2:
	cmp	si,di
	jge	x_by_one

y_by_one:
;delta y >= delta x
	mov	larger_delta,si
	mov	smaller_delta,di
	mov	si,di			;use dx to test when dx is incremented
	sar	si,1			;/2
	push	di
	call	open_vid
	pop	cx
	inc	cx			;include endpoint.
y_by_one_1:
	mov	al,line_color
	call	set_bit
	mov	bx,smaller_delta
	add	si,larger_delta
	cmp	si,bx			;past the larger yet?
	jl	y_by_one_2		;no.
	sub	si,bx			;yes - subtract it off.
	call	x_inc
y_by_one_2:
	call	y_inc
	loop	y_by_one_1
	call	close_vid
	ret

x_by_one:
;delta x > delta y
	mov	larger_delta,si
	mov	smaller_delta,di
	call	open_vid
	mov	cx,si
	inc	cx			;include endpoint.
	sar	si,1
x_by_one_1:
	mov	al,line_color
	call	set_bit
	mov	bx,larger_delta
	add	si,smaller_delta
	cmp	si,bx			;past the larger yet?
	jl	x_by_one_2		;no.
	sub	si,bx			;larger.
	call	y_inc
x_by_one_2:
	call	x_inc
	loop	x_by_one_1
	call	close_vid
	ret


