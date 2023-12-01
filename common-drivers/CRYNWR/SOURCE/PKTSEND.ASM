version	equ	1
;History:306,1

;  Copyright, 1989-1992, Russell Nelson, Crynwr Software

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

code	segment word public
	assume	cs:code, ds:code

	org	2h
phd_memsize	label	word

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1
copyleft_msg	label	byte
 db "Packet sender version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version," copyright 1990-92, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

their_isr	dd	?
entry_point	db	?,?,?,?
handle		dw	?
packet_flag	dw	0
repeat_switch	db	0
quiet_switch	db	0
async_switch	db	0
delay_count	dd	1
delay_counter	dd	0

pkt_length	dw	?,?
pkt_count	dd	1

driver_class	db	?

async_iocb1	iocb	<0, 0, DONE>	;Two iocbs
async_iocb2	iocb	<0, 0, DONE>

signature	db	'PKT DRVR',0
signature_len	equ	$-signature

no_signature_msg	db	"No packet driver at that address",'$'
usage_msg	db	"usage: pktsend <packet_int_no>",CR,LF
		db	"[-r [-q] | -n number] [ -d delay ] [-f filename | -l length | packet]",'$'
sending_msg	label	byte
	db	"Press space to send packet(s).  Any other key exits.",CR,LF,'$'
repeat_msg	label	byte
	db	"Sending repeat packets.  Any key exits.",CR,LF,'$'
file_not_found	db	"File not found",'$'
read_trouble	db	"Trouble reading the file",'$'
non_number_msg	db	"Non-numeric input found",'$'
mem_trashed_msg	db	CR,LF,"Found trashed memory at ",'$'

line_buffer	db	128 dup(?)

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
	call	skip_blanks
	cmp	al,CR			;end of line?
	je	usage_error

	mov	di,offset entry_point
	call	get_number

another_switch:
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	je	have_switch
	jmp	not_switch
have_switch:
	cmp	byte ptr [si+1],'r'	;did they specify '-r'?
	je	got_repeat_switch
	cmp	byte ptr [si+1],'q'	;did they specify '-q'?
	je	got_quiet_switch
	cmp	byte ptr [si+1],'n'	;did they specify '-n'?
	je	got_number_switch
	cmp	byte ptr [si+1],'l'	;did they specify '-l'?
	je	got_length_switch
	cmp	byte ptr [si+1],'f'	;did they specify '-f'?
	je	start_file
	cmp	byte ptr [si+1],'a'	;did they specify '-a'?
	je	got_async_switch
	cmp	byte ptr [si+1],'d'	;did they specify '-d'?
	je	got_delay_switch
	jmp	usage_error		;no, must be an error.
got_repeat_switch:
	mov	repeat_switch,1
	add	si,2
	jmp	another_switch
got_quiet_switch:
	mov	quiet_switch,1
	add	si,2
	jmp	another_switch
got_number_switch:
	add	si,2
	mov	di,offset pkt_count
	call	get_number
	jmp	another_switch
got_delay_switch:
	add	si,2
	mov	di,offset delay_count
	call	get_number
	mov	ax,delay_count.offs
	or	ax,delay_count.segm
	jne	another_switch
	mov	delay_count.offs,1
	mov	delay_count.segm,0
	jmp	another_switch
got_length_switch:
	add	si,2
	mov	di,offset pkt_length
	call	get_number
	mov	di,offset our_buffer
	add	di,pkt_length
	jmp	start_gotit
got_async_switch:
	mov	async_switch,1
	add	si,2
	jmp	another_switch
not_switch:
	jmp	start_inline		;yes.

start_file:
	add	si,2
	call	skip_blanks
	mov	dx,si			;remember where the filename starts.
start_3:
	lodsb
	cmp	al,' '
	je	start_4
	cmp	al,CR
	jne	start_3
start_4:
	dec	si
	mov	byte ptr [si],0

;read the packet bytes from the named file.

	mov	ax,3d00h		;open for reading.
	int	21h
	jnc	file_found
	mov	dx,offset file_not_found
	jmp	error

file_found:
	mov	handle,ax
	mov	di,offset our_buffer
start_line:
	mov	si,offset line_buffer
again_line:
	mov	ah,3fh			;read a single character.
	mov	bx,handle
	mov	cx,1
	mov	dx,si
	int	21h
	jnc	no_trouble
	mov	dx,offset read_trouble
	jmp	error

no_trouble:
	cmp	ax,1			;did we actually read one?
	je	not_eof
	cmp	si,offset line_buffer	;did we read anything this time?
	je	start_file_eof		;no, it's really eof this time.
	mov	[si],byte ptr CR	;add an extra CR, just in case.
	jmp	short done_reading
not_eof:
	lodsb				;get the character we just read.
	cmp	al,1ah			;^Z?
	je	start_file_eof		;yes, eof now.
	cmp	al,LF			;got the LF?
	jne	again_line		;no, read again.

done_reading:
	mov	si,offset line_buffer
again_chars:
	call	get_number
	jnc	got_a_number
	mov	dx,offset non_number_msg
	jmp	error
got_a_number:
	inc	di
	call	skip_blanks
	cmp	al,CR
	jne	again_chars		;keep going to the end.

	jmp	start_line

start_file_eof:
	mov	ah,3eh			;close the file.
	mov	bx,handle
	int	21h
	jmp	short start_gotit

start_inline:
;read the packet bytes off the command line.
	mov	di,offset our_buffer-1
start_2:
	inc	di			;pre-increment
	call	get_number		;get a byte.
	jnc	start_2			;keep going to the end.

start_gotit:

	sub	di,offset our_buffer
	mov	pkt_length,di

	mov	sp,offset start		;now that we're finished with
					;the parameters, put our stack there.

	mov	di,offset our_buffer + GIANT * 2
	inc	di
	and	di,not 1
	movseg	es,cs
init_memory:
	mov	ax,055aah		;initialize a segment to 055aah.
	mov	cx,di
	neg	cx
	shr	cx,1
	stosw
	sub	cx,2
	rep	stosw
	mov	ax,es
	add	ax,1000h
	mov	es,ax
	add	ax,1000h
	cmp	ax,phd_memsize		;don't go past the end of memory.
	jbe	init_memory

	mov	ah,35h			;get their packet interrupt.
	mov	al,entry_point
	int	21h
	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	lea	di,3[bx]
	mov	si,offset signature
	mov	cx,signature_len
	repe	cmpsb
	je	signature_ok
	jmp	no_signature_err
signature_ok:

	mov	ax,1ffh			;driver_info
	call	int_pkt
	call	fatal_error
	mov	driver_class,ch

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

	cmp	driver_class,1		;Ethernet II?
	je	get_address
	cmp	driver_class,11		;IEEE 802.3?
	jne	no_get_address
get_address:
	mov	ah,6			;get the destination's address.
	mov	bx,handle
	mov	cx,EADDR_LEN
	movseg	es,cs
	mov	di,offset our_buffer+6	;set the 'from' address.
	call	int_pkt
	call	fatal_error
no_get_address:

	cmp	repeat_switch,0
	je	send_not_repeat
	mov	dx,offset repeat_msg
	mov	ah,9
	int	21h
	jmp	short load_count
send_not_repeat:
	mov	dx,offset sending_msg
	mov	ah,9
	int	21h
wait_for_event:

; Did we receive a packet?

	cmp	packet_flag,0
	je	no_packet		;no.

	mov	al,'R'
	call	chrout

	mov	packet_flag,0

no_packet:

; Did they press a key?

	mov	ah,1
	int	16h
	jz	no_key			;no.

	mov	ah,0			;get the key.
	int	16h

	cmp	repeat_switch,0		;are they repeating?
	jne	no_packet_1		;yes, any key means exit.

	cmp	al,' '			;space means retransmit.
	je	load_count
no_packet_1:
	jmp	send_done		;send a packet.

no_key:

; Time to send another packet?

	mov	ax,delay_counter.segm
	or	ax,delay_counter.offs
	jne	count_not_zero

	cmp	repeat_switch,0		;are we auto-repeating?
	je	wait_for_event		;no, wait for an event.

load_count:
	mov	ax,delay_count.offs
	mov	dx,delay_count.segm
	mov	delay_counter.offs,ax
	mov	delay_counter.segm,dx

count_not_zero:

; Finished with delay?

	dec	delay_counter.offs
	jne	wait_for_event
	cmp	delay_counter.segm,0
	je	send_delay_1
	dec	delay_counter.segm
	jne	wait_for_event
send_delay_1:

	mov	ax,pkt_count.offs	;send another series of packets.
	mov	dx,pkt_count.segm

send_again:
	push	ax
	push	dx

	mov	ah,4			;send_pkt
	mov	si,offset our_buffer	;ds:si -> buffer.
	mov	cx,pkt_length
	cmp	async_switch,0		;async?
	je	send_pkt		;no
	mov	ah,12			;as_send_pkt
find_iocb:				;find a free iocb
	mov	di,offset async_iocb1	;try first
	test	[di].flags,DONE		;free?
	jnz	got_iocb		;yes
	mov	di,offset async_iocb2	;no, try second
	test	[di].flags,DONE		;free?
	jz	find_iocb		;no, try first again
got_iocb:				;set up iocb
	mov	word ptr [di].buffer,si
	mov	word ptr [di].buffer+2,ds
	mov	es,word ptr [di].buffer+2
	mov	[di].len,cx
	mov	[di].flags,0		;clear flags (i.e. DONE bit)
send_pkt:
	call	int_pkt
	jnc	pkt_sent_ok
	mov	al,'X'
	call	chrout
	cmp	dh,CANT_SEND		;did the driver just complain a little?
	je	pkt_sent_ok		;yes, pretend all is okay.
	jmp	pkt_sent_bad
pkt_sent_ok:
	pop	dx
	pop	ax
	sub	ax,1			;decrement low word
	sbb	dx,0			;decrement high word
	mov	bx,ax			;check if we reached zero
	or	bx,dx
	jne	send_again		;we didn't

check_repeat:
	cmp	quiet_switch,0
	jne	chrout_done
	mov	al,'T'
	call	chrout

chrout_done:
	jmp	wait_for_event


send_done:
	mov	ah,3			;release the handle.
	mov	bx,handle
	call	int_pkt
	call	fatal_error

	mov	di,offset our_buffer + GIANT * 2
	inc	di
	and	di,not 1
	movseg	es,cs
compare_memory:
	mov	ax,055aah		;compare a segment against 055aah.
	mov	cx,di
	neg	cx
	shr	cx,1
	scasw
	jne	memory_bad
	sub	cx,2
	repe	scasw
	jne	memory_bad
	mov	ax,es
	add	ax,1000h
	mov	es,ax
	add	ax,1000h
	cmp	ax,phd_memsize		;don't go past the end of memory.
	jbe	compare_memory

	int	20h
pkt_sent_bad:
	call	print_error

	mov	ah,3			;release the handle.
	mov	bx,handle
	call	int_pkt
	call	fatal_error

	int	20h

memory_bad:
	mov	dx,offset mem_trashed_msg
	mov	ah,9
	int	21h
	mov	ax,es
	call	wordout
	mov	al,':'
	call	chrout
	mov	ax,di
	dec	ax
	call	wordout
	mov	dx,offset crlf_msg
	mov	ah,9
	int	21h
	int	20h

no_signature_err:
	mov	dx,offset no_signature_msg
	mov	ah,9
	int	21h
	int	20h


our_recv:
	or	ax,ax			;first or second call?
	jne	our_recv_1		;second -- we ignore the packet
	cmp	cs:packet_flag,0	;Do we already have one?
	jne	our_recv_2		;yes - return zero.
	movseg	es,cs
	mov	di,offset our_buffer + GIANT
	retf
our_recv_2:
	xor	di,di
	mov	es,ax
	mov	cx,0
	loop	$
	retf
our_recv_1:
	inc	cs:packet_flag
	retf


int_pkt:
	push	ds
	push	es
	pushf
	cli
	call	their_isr
	pop	es
	pop	ds
	ret

	include	pkterr.asm
	include	getnum.asm
	include	getdig.asm
	include	skipblk.asm
	include	chrout.asm
	include	digout.asm

	align	4
our_buffer	label	byte

code	ends

	end	start
