version	equ	0

;History:87,1
;Sun Aug 09 23:13:00 1992 Hans-Juergen Knoblock fixed a bug wherein the wrong traffic counters were being incremented.

;  Copyright 1990-1992, Russell Nelson, Crynwr Software

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

	include	defs.asm

BS	equ	8

code	segment word public
	assume	cs:code, ds:code

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1

copyleft_msg	label	byte
 db "Packet traffic version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?,?,?
handle		dw	?

signature	db	'PKT DRVR',0
signature_len	equ	$-signature
no_signature_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pkttraf <packet_int_no>",'$'
waiting_msg	label	byte
db "Graphically display network traffic.  The Ethernet address of the",CR,LF
db "highlighted node is shown in the lower right corner.  The space key will",CR,LF
db "advance counter-clockwise, backspace will retreat clockwise, escape will",CR,LF
db "exit.",CR,LF
db CR,LF
db "Press any key to continue.",CR,LF,'$'

	include	pixel.asm
	include	line.asm

MAX_NODES	equ	20

xy_pairs	label	word
	dw	100,198
	dw	130,193
	dw	157,179
	dw	179,157
	dw	193,130
	dw	198,100
	dw	193,69
	dw	179,42
	dw	157,20
	dw	130,6
	dw	100,2
	dw	69,6
	dw	42,20
	dw	20,42
	dw	6,69
	dw	2,99
	dw	6,130
	dw	20,157
	dw	42,179
	dw	69,193

eaddr_list	db	EADDR_LEN * MAX_NODES dup(0)
eaddr_end	dw	eaddr_list

traffic_list	db	MAX_NODES * MAX_NODES dup(0)
traffic_scale	db	0

cursor	db	0			;between 0 and MAX_NODES-1

usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
	int	20h

start_1:
	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	mov	si,offset phd_dioa+1
	cmp	byte ptr [si],CR	;end of line?
	je	usage_error

	mov	di,offset entry_point
	call	get_number

	mov	ah,35h			;get their packet interrupt.
	mov	al,entry_point
	int	21h
	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	lea	di,3[bx]
	mov	si,offset signature
	mov	cx,signature_len
	repe	cmpsb
	mov	dx,offset no_signature_msg
	jne	error

	mov	ax,1ffh			;driver_info
	call	int_pkt
	call	fatal_error

	mov	ah,2			;access all packets.
	mov	al,ch			;their class from driver_info().
	mov	bx,dx			;their type from driver_info().
	mov	dl,cl			;their number from driver_info().
	mov	cx,0			;type length of zero.
	movseg	es,cs
	mov	di,offset our_recv
	call	int_pkt
	call	fatal_error
	mov	handle,ax

	mov	ah,20			;set receive mode.
	mov	bx,handle
	mov	cx,6			;receive all packets.
	call	int_pkt
	call	fatal_error

	mov	dx,offset waiting_msg
	mov	ah,9
	int	21h

	mov	ah,0			;fetch the key.
	int	16h

	call	init_vid

wait_for_key:
	call	draw_eaddr

	cmp	traffic_scale,0		;do we need to rescale?
	je	no_rescale
	mov	si,offset traffic_list
	mov	cx,MAX_NODES*MAX_NODES
rescale:
	shr	byte ptr [si],1		;divide all the traffic in half.
	inc	si
	loop	rescale
	mov	traffic_scale,0
no_rescale:

	xor	bx,bx
	mov	al,4
	mul	cursor
write_dots:
	mov	cx,xy_pairs[bx].offs	;get the X and Y coordinate.
	mov	dx,xy_pairs[bx].segm
	push	ax
	push	bx
	cmp	ax,bx			;at the cursor?
	mov	al,60h			;use a dim dot.
	jne	write_dots_1
	mov	al,0ffh			;use a bright dot.
write_dots_1:
	call	draw_dot
	pop	bx
	pop	ax
	add	bx,4
	cmp	bx,MAX_NODES*4
	jb	write_dots

  if 0
;draw the cursor.
	mov	cx,xy_pairs[bx].offs	;get the X and Y coordinate.
	mov	dx,xy_pairs[bx].segm
	call	draw_bullet
  endif

	mov	si,offset traffic_list
	mov	dh,0
write_nodes:
	mov	dl,dh
	inc	dl
write_nodes_1:
  if 0
	mov	al,MAX_NODES
	mul	dh
	add	al,dl
	adc	ah,0
  endif

	lodsb				;get the amount of traffic.
	push	si
	call	write_one_node		;enter with dh, dl = a pair of nodes,, al = amount of traffic.
	pop	si
	inc	dl
	cmp	dl,MAX_NODES
	jb	write_nodes_1

	mov	ah,1			;check for any key.
	int	16h
	jne	test_for_key		;got a key - go get it.

	inc	dh
	cmp	dh,MAX_NODES - 1
	jb	write_nodes

test_for_key:
	mov	ah,1			;check for any key.
	int	16h
	je	wait_for_key		;no key -- keep waiting.

	mov	ah,0			;fetch the key.
	int	16h

	cmp	al,1bh			;Escape?
	je	all_done
	cmp	al,'q'			;Quit?
	je	all_done
	cmp	al,BS
	je	backspace
	cmp	al,' '
	jne	test_for_key

	inc	cursor			;move over by one.
	cmp	cursor,MAX_NODES	;should we wrap around?
	jb	test_for_key
	mov	cursor,0
	jmp	test_for_key

backspace:
	dec	cursor			;move over by one.
	cmp	cursor,-1		;should we wrap around?
	jne	test_for_key
	mov	cursor,MAX_NODES-1
	jmp	test_for_key


all_done:

	call	uninit_vid

	mov	ah,20			;set receive mode.
	mov	bx,handle
	mov	cx,3			;receive ours + broadcasts.
	call	int_pkt
	call	fatal_error

	mov	ah,3
	mov	bx,handle
	call	int_pkt
	call	fatal_error

	int	20h


int_pkt:
	push	ds
	push	es
	pushf
	cli
	call	their_isr
	pop	es
	pop	ds
	ret


write_one_node:
;enter with dh, dl = a pair of nodes, al = amount of traffic.
;preserve dx.
	push	dx

	mov	bl,dh
	xor	bh,bh
	shl	bx,1
	shl	bx,1
	mov	si,xy_pairs[bx].offs	;get the X and Y coordinate.
	mov	di,xy_pairs[bx].segm

	mov	bl,dl
	xor	bh,bh
	shl	bx,1
	shl	bx,1
	mov	cx,xy_pairs[bx].offs	;get the X and Y coordinate.
	mov	dx,xy_pairs[bx].segm

	call	line
	pop	dx
	ret


dot_color	db	?

draw_dot:
;enter with cx, dx = point to draw a dot around, al = color of dot.
;  ***
; *   *
; * X *
; *   *
;  ***
	mov	dot_color,al
	call	open_vid
	call	move_left
	call	move_left
	call	move_up
	mov	al,dot_color
	call	set_bit
	call	move_down
	mov	al,dot_color
	call	set_bit
	call	move_down
	mov	al,dot_color
	call	set_bit
	call	move_right
	call	move_down
	mov	al,dot_color
	call	set_bit
	call	move_right
	mov	al,dot_color
	call	set_bit
	call	move_right
	mov	al,dot_color
	call	set_bit
	call	move_right
	call	move_right
	call	move_up
	mov	al,dot_color
	call	set_bit
	call	move_up
	mov	al,dot_color
	call	set_bit
	call	move_up
	mov	al,dot_color
	call	set_bit
	call	move_up
	call	move_left
	mov	al,dot_color
	call	set_bit
	call	move_left
	mov	al,dot_color
	call	set_bit
	call	move_left
	mov	al,dot_color
	call	set_bit
	call	close_vid
	ret


draw_bullet:
;enter with cx, dx = point to draw a dot around.
; HGF
; A E
; BCD
	call	open_vid
	call	move_left
	mov	al,0ffh			;A
	call	set_bit
	call	move_down
	mov	al,0ffh			;B
	call	set_bit
	call	move_right
	mov	al,0ffh			;C
	call	set_bit
	call	move_right
	mov	al,0ffh			;D
	call	set_bit
	call	move_up
	mov	al,0ffh			;E
	call	set_bit
	call	move_up
	mov	al,0ffh			;F
	call	set_bit
	call	move_left
	mov	al,0ffh			;G
	call	set_bit
	call	move_left
	mov	al,0ffh			;H
	call	set_bit
	call	close_vid
	ret

draw_eaddr:
	mov	ah,2			;set cursor position
	mov	bh,0
	mov	dh,24
	mov	dl,40-EADDR_LEN*3
	int	10h

	mov	al,cursor
	mov	ah,EADDR_LEN
	mul	ah
	add	ax,offset eaddr_list
	mov	si,ax
	call	print_ether_addr
	ret


our_recv:
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- bump the packet flag.
	movseg	es,cs
	mov	di,offset our_buffer
	retf
our_recv_1:
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es

	cld

	mov	ax,cs
	mov	ds,ax
	mov	es,ax

	call	receive

	pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	retf

receive:
	mov	si,offset our_buffer	;get the "to" address.
	call	find_address
	jc	receive_2		;too many!
	push	ax
	mov	si,offset our_buffer+EADDR_LEN	;get the "from" address.
	call	find_address
	pop	bx
	jc	receive_2		;too many!
	mov	bh,MAX_NODES
	mul	bh
	xor	bh,bh
	add	bx,ax
	cmp	bx,MAX_NODES * MAX_NODES
	jae	receive_2
	cmp	traffic_list[bx],255	;at the maximum already?
	je	receive_1
	inc	traffic_list[bx]	;increase the amount of traffic.
receive_2:
	ret
receive_1:
	inc	traffic_scale
	ret


find_address:
;enter with si -> incoming Ethernet address.
;exit with nc, al = node number, or cy if we can't remember this one.
	mov	cx,MAX_NODES
	mov	di,offset eaddr_list
find_address_1:
	cmp	di,eaddr_end		;did we hit the end?
	jae	find_address_5
	cmpsw
	jne	find_address_2
	cmpsw
	jne	find_address_3
	cmpsw
	jne	find_address_4
	jmp	short find_address_6
find_address_2:
	add	si,2			;increment by another two bytes.
	add	di,2
find_address_3:
	add	si,2			;increment by another two bytes.
	add	di,2
find_address_4:
	add	si,-6			;back si up to the beginning.
	loop	find_address_1		;or run out of slots?
	stc
	ret
find_address_5:
	movsw				;okay, remember it here.
	movsw
	movsw
	mov	eaddr_end,di
find_address_6:
	mov	al,MAX_NODES
	sub	al,cl
	clc
	ret


	include	printea.asm
	include	pkterr.asm
	include	getnum.asm
	include	getdig.asm
	include	skipblk.asm
	include	digout.asm

chrout:
	push	ax			;print the char in al.
	push	bx
	push	bp
	mov	ah,0eh
	mov	bh,0
	mov	bl,0ffh
	int	10h
	pop	bp
	pop	bx
	pop	ax
	ret


	align	4
our_buffer	label	byte

code	ends

	end	start
