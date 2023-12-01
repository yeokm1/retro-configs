version	equ	1
;History:697,1

	include	defs.asm

;  Copyright, 1988-1992, Russell Nelson, Crynwr Software

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

code	segment word public
	assume	cs:code, ds:code

	org	2ch
phd_env	label	word

	org	5ch
phd_fcb1	label	byte

	org	6ch
phd_fcb2	label	byte

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1

stack	label	byte

comment /

Plan:

Keep a circular queue of events.  The size of the queue is a settable
parameter.  Discard events that fall off the end.  Remember how many events
were discarded.  Remember when the events occurred.

Type of events to remember:
	calls to the packet driver
	upcalls to the receiver handler (both kinds)

/

; In addition to the function numbers specified in the FTP Software
; packet driver spec, the following pseudo-functions are defined:

EVENT_RECEIVE	equ	255		;receiver upcall.

event_struc	struc
event_length	dw	?		;length of this event.
event_function	db	?		;the event function number.
event_time	dw	?,?		;timer tick at the time of the call.
event_error	db	?		;set to value of dh after the SWI.
event_struc	ends

di_struc	struc
		db	(size event_struc) dup (?)
di_version	dw	?
di_class	db	?
di_type		dw	?
di_number	db	?
di_basic	db	?
di_struc	ends

at_struc	struc
		db	(size event_struc) dup (?)
at_if_class	db	?
at_if_type	dw	?
at_if_number	db	?
at_typelen	dw	?
at_handle	dw	?
at_struc	ends

handle_struc	struc
		db	(size event_struc) dup (?)
event_handle	dw	?
handle_struc	ends

ga_struc	struc
		db	(size event_struc) dup (?)
ga_handle	dw	?
ga_length	dw	?
ga_struc	ends

srm_struc	struc
		db	(size event_struc) dup (?)
srm_mode	dw	?
srm_handle	dw	?
srm_struc	ends

queue_length	dw	10000,?		;length of the queue.
queue_tail	dw	?		;points after the last item in the queue.
queue_ptr	dw	?		;points to the new item in the queue.
queue_head	dw	?		;points to the first item in the queue.
queue_end	dw	?		;points to the end of the queue, but
					;there is room for one more event after
					;this one.

entry_point	db	?,0,0,0

parm	dw	0
parm2	dw	their_dioa,?
parm3	dw	phd_fcb1,?
parm4	dw	phd_fcb2,?

comspec_env_str	db	"COMSPEC="
comspec_env_len	equ	$-comspec_env_str

program		db	64 dup(?)
their_dioa	db	0,0dh,128-2 dup(?)

saved_ax	label	word
saved_al	db	?
saved_ah	db	?
saved_bx	dw	?
saved_ds	dw	?
saved_f		dw	?

functions	label	word
	dw	f_driver_info		;function 1
	dw	f_access_type
	dw	f_release_type
	dw	f_send_pkt
	dw	f_terminate
	dw	f_get_address
	dw	f_reset_interface	;function 7
	dw	f_set_rcv_mode		;function 20
	dw	f_get_rcv_mode
	dw	f_set_multicast_list
	dw	f_get_multicast_list
	dw	f_get_statistics
	dw	f_set_address		;function 25

their_isr	dd	?

our_isr:
	jmp	our_isr_0		;the required signature.
	db	'PKT DRVR',0

our_isr_0:
	assume	ds:nothing
	mov	saved_ds,ds
	mov	saved_bx,bx
	mov	saved_ax,ax
	cld

	mov	bx,sp
	mov	bx,ss:[bx+4]		;get the original flags.
	mov	saved_f,bx


	mov	bx,cs			;set up ds.
	mov	ds,bx
	assume	ds:code

;the following code runs with ax, bx, ds, and flags saved in save_*.
;otherwise, all the registers are the same as those we were called with.

	mov	bl,ah			;jump to the correct function.
	mov	bh,0
	cmp	bx,7			;highest function is 7.
	jbe	our_isr_3
	cmp	bx,20
	jb	our_isr_bad
	cmp	bx,25
	ja	our_isr_bad
	sub	bx,20-7-1		;map 20 right after 7.
our_isr_3:
	add	bx,bx			;*2
	jmp	functions-2[bx]		;table starts at 1.

our_isr_bad:
	call	do_their_isr
	jmp	our_isr_done

f_driver_info:
	mov	bx,(size di_struc)
	call	queue_advance
	call	do_their_isr
	jc	f_driver_info_1

	mov	ax,saved_bx
	mov	[bx].di_version,ax
	mov	[bx].di_class,ch
	mov	[bx].di_type,dx
	mov	[bx].di_number,cl
	mov	al,saved_al
	mov	[bx].di_basic,al
;we ignore the name -- too much work.
f_driver_info_1:
	jmp	our_isr_done

f_get_statistics:
;strictly speaking, we should remember the statistics, but I'm not going to now.
f_terminate:
f_reset_interface:
f_release_type:
f_get_rcv_mode:
	mov	bx,(size handle_struc)
	call	queue_advance
	mov	ax,saved_bx
	mov	[bx].event_handle,ax
	call	do_their_isr
	jmp	our_isr_done

f_access_type:
	mov	bx,(size at_struc)
	call	queue_advance
	mov	al,saved_al
	mov	[bx].at_if_class,al
	mov	ax,saved_bx
	mov	[bx].at_if_type,ax
	mov	[bx].at_if_number,dl
	mov	[bx].at_typelen,cx
	mov	their_recv.segm,es
	mov	their_recv.offs,di
	mov	ax,cs			;and stick our receiver in.
	mov	es,ax
	mov	di,offset our_recv
	call	do_their_isr
	jc	f_access_type_1
	mov	ax,saved_ax
	mov	[bx].at_handle,ax
f_access_type_1:
	les	di,their_recv		;now restore ds and si.
	jmp	our_isr_done


f_send_pkt:
	mov	bx,(size event_struc)
	add	bx,cx
	call	queue_advance
;make a copy of their packet.
	push	cx
	push	si
	push	di
	push	ds
	push	es
	lea	di,[bx] + (size event_struc)
	mov	ax,cs
	mov	es,ax
	mov	ds,saved_ds
	rep	movsb
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	cx
	call	do_their_isr
	jmp	our_isr_done

f_get_address:
	mov	bx,(size ga_struc)
	add	bx,cx
	call	queue_advance
	mov	ax,saved_bx		;save their handle
	mov	[bx].ga_handle,ax
	call	do_their_isr
	jc	f_get_address_1
;make a copy of their address.
	mov	[bx].ga_length,cx	;we need to save this because it
					;might be less than the total allocated.
	push	cx
	push	si
	push	di
	push	ds
	push	es
	mov	si,di			;get es:di into ds:si
	mov	ax,es
	mov	ds,ax
	lea	di,[bx] + (size ga_struc)	;get our pointer into es:di.
	mov	ax,cs
	mov	es,ax
	rep	movsb
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	cx
f_get_address_1:
	jmp	our_isr_done


f_set_rcv_mode:
	mov	bx,(size srm_struc)
	add	bx,2
	call	queue_advance
	mov	ax,saved_bx		;save their handle.
	mov	[bx].srm_handle,ax
	mov	[bx].srm_mode,cx	;save their mode.
	call	do_their_isr
	jmp	our_isr_done

f_set_multicast_list:
f_get_multicast_list:
f_set_address:
	mov	bx,(size event_struc)
	call	queue_advance
	call	do_their_isr

our_isr_done:
	push	saved_f			;restore their flags, see [2]
	popf

	mov	ax,saved_ax
	mov	bx,saved_bx
	mov	ds,saved_ds		;restore the two registers we destroyed.
	assume	ds:nothing

	retf	2			;return, popping their old flags, [2].
	assume	ds:code


;do_their_isr executes their isr with the original registers.
;called with all their registers except f, ds, and bx.
;exits with all their registers except ds, ax, and bx.  bx is queue_ptr
do_their_isr:

;setup their context.
	mov	ax,saved_f		;restore their flags, see [1]
	and	ax,not 200h		;clear the interrupt flag, as required
	push	ax			;  when faking an interrupt.
	mov	ax,saved_ax
	mov	bx,saved_bx
	mov	ds,saved_ds		;restore the two registers we destroyed.
	assume	ds:nothing

;	[1] we pushed the flags earlier.
	call	their_isr		;now fake their interrupt.

;save their context.
	mov	saved_ax,ax		;save the new registers.
	mov	saved_bx,bx
	mov	saved_ds,ds
	mov	ax,cs			;set up a pointer to the next event.
	mov	ds,ax
	assume	ds:code
	pushf				;save the new flags.
	pop	ax
	and	saved_f,200h		;merge the interrupt flag in saved_f
	or	saved_f,ax		;  with the new flags.

;remember whether it succeeded or not.
	mov	bx,queue_ptr
	mov	[bx].event_error,NO_ERROR	;assume that all was okay.
	jnc	our_isr_1
	mov	[bx].event_error,dh	;it wasn't.
our_isr_1:
	ret


their_recv	dd	?

our_recv:
	assume	ds:nothing
	mov	saved_ds,ds
	mov	saved_bx,bx
	mov	saved_ax,ax
	cld

	mov	bx,cs			;set up ds.
	mov	ds,bx
	assume	ds:code

	or	ax,ax			;first call or second?
	je	our_recv_first

	mov	bx,(size handle_struc)
	add	bx,cx
	call	queue_advance
	mov	[bx].event_function,EVENT_RECEIVE	;not a real function.
	mov	[bx].event_error,0		;no errors possible.
	mov	ax,saved_bx
	mov	[bx].event_handle,ax	;remember which handle it was.

	push	cx
	push	si
	push	di
	push	ds
	push	es
	lea	di,[bx] + (size handle_struc)
	mov	ax,cs
	mov	es,ax
	mov	ds,saved_ds
	rep	movsb
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	cx

	jmp	short our_recv_done
our_recv_first:
;ignore the first upcall.
our_recv_done:
	mov	ax,saved_ax
	mov	bx,saved_bx
	mov	ds,saved_ds		;restore the two registers we destroyed.
	assume	ds:nothing

	jmp	their_recv
	assume	ds:code


queue_advance:
;enter with bx = number of bytes that we require in the queue.
;exit with bx,queue_ptr set to a pointer to our entry.
;preserve everything but ds, bx, and the flags.
queue_advance_3:
	mov	ax,queue_tail
	add	ax,bx
	cmp	ax,queue_head		;if we don't overlap the head, we're
	jbe	queue_advance_1		;  okay.

	xchg	bx,queue_head		;get queue_head and save bx.
	add	bx,[bx].event_length
	cmp	bx,queue_end		;see if we hit the end.
	xchg	queue_head,bx		;store queue_head and restore bx.
	jb	queue_advance_3		;if we're less than the end, continue.
;we have to wrap here.
	push	bx
	mov	bx,queue_tail
	mov	ax,queue_end		;make an event length that's too large.
	sub	ax,offset queue_begin
	mov	[bx].event_length,ax
	mov	bx,offset queue_begin	;and restart from the beginning.
	mov	queue_tail,bx		;ensure that we nuke some more.
	mov	queue_head,bx
	pop	bx
	jmp	queue_advance_3
queue_advance_1:
	xchg	ax,queue_tail		;update the tail and get this ptr.
	mov	queue_ptr,ax		;save this pointer.
	xchg	ax,bx
	mov	[bx].event_length,ax	;store the length of this entry here.

	mov	ah,saved_ah		;store their function value.
	mov	[bx].event_function,ah

;remember when it happened.
	push	dx
	push	ds
	mov	ax,40h
	mov	ds,ax
	mov	ax,ds:6ch		;get the timer tick count.
	mov	dx,ds:6eh
	pop	ds
	mov	[bx].event_time+0,ax
	mov	[bx].event_time+2,dx
	pop	dx

	ret


copyleft_msg	label	byte
 db "Packet driver tracer version ",'0'+(majver / 10),'0'+(majver mod 10),'.',version+'0'," copyright 1988-92, Russell Nelson.",CR,LF
 db "This program is free software; see the file COPYING for details.",CR,LF
 db "NO WARRANTY; see the file COPYING for details.",CR,LF
crlf_msg	db	CR,LF,'$'

entry_point_name	db	"Packet interrupt number ",'$'
buffer_size_name	db	"Buffer size ",'$'

before_exec_msg	db	"Now run your network software and type 'exit' when finished",CR,LF,'$'
run_dump_msg	db	"Now run 'dump' to interpret 'trace.out'",CR,LF,'$'

disk_full_msg	db	"Disk Full!",'$'

already_msg	db	CR,LF,"There is no packet driver at ",'$'
packet_int_msg	db	CR,LF
		db	"Error: <packet_int_no> should be in the range 0x60 to 0x80"
		db	'$'

usage_msg	db	"usage: trace entry_point <buffer_size>",'$'

queue_error_msg	db	"Error: <buffer_size> should be larger than 2000 and less than 64000",'$'

trace_out	db	"TRACE.OUT",0	;filename that we write the dump to.

usage_error:
	mov	dx,offset usage_msg
error:
	mov	ah,9
	int	21h
	int	20h

already_error:
	mov	dx,offset already_msg
	mov	di,offset entry_point
	call	print_number
	int	20h

start_1:
	mov	sp,offset stack

	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	mov	si,offset phd_dioa+1
	cmp	byte ptr [si],CR	;end of line?
	je	usage_error

	mov	di,offset entry_point	;parse the packet interrupt number
	call	get_number		;  for them.

	mov	di,offset queue_length	;parse the packet interrupt number
	call	get_number		;  for them.

	cmp	byte ptr [si],CR	;end of line?
	jne	usage_error

	cmp	queue_length+2,0
	jne	start_3
	cmp	queue_length,2000
	ja	start_2
start_3:
	mov	dx,offset queue_error_msg
	jmp	error
start_2:

	mov	di,offset entry_point	;parse the packet interrupt number
	mov	dx,offset entry_point_name
	call	print_number		;  for them.

	mov	di,offset queue_length	;parse the packet interrupt number
	mov	dx,offset buffer_size_name
	call	print_number		;  for them.

;initialize the queue
	mov	bx,offset queue_begin
	mov	queue_tail,bx
	add	bx,queue_length
	mov	queue_end,bx		;initialize the head of the queue.
	mov	[bx].event_length,1	;anything >0 will ensure that we're >end.
	mov	queue_head,bx

;do some error checking.
	cmp	entry_point,60h	;make sure that the packet interrupt
	jae	pkt_int_ok		;  number is in range.
	cmp	entry_point,80h
	jbe	pkt_int_ok
	mov	dx,offset packet_int_msg
	jmp	error
pkt_int_ok:

	mov	al,entry_point	;is there a packet driver there?
	call	chk_int
	je	start_4			;yes, so we can trace it.
	jmp	already_error		;no, give them an error.
start_4:
	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	mov	ah,25h			;install our packet interrupt
	mov	dx,offset our_isr
	int	21h

	mov	dx,offset before_exec_msg
	mov	ah,9
	int	21h

;
; Now free the memory we don't need.
;
	mov	bx,queue_end
	add	bx,size event_struc	;leave room for one more.
	add	bx,0fh			;round up to next highest paragraph.
	mov	cl,4
	shr	bx,cl
	movseg	es,cs
	mov	ah,4ah
	int	21h

; Now we execute command.com

	mov	ax,cs
	mov	word ptr parm2+2,ax
	mov	word ptr parm3+2,ax
	mov	word ptr parm4+2,ax

	mov	si,offset their_dioa+1	;re-parse the two fcbs.
	mov	di,offset phd_fcb1
	movseg	es,ds
	mov	ax,2901h
	int	21h

	mov	di,offset phd_fcb2
	mov	ax,2901h
	int	21h

	mov	si,offset comspec_env_str	;see if this is the one.
	mov	cx,comspec_env_len
	call	getenv

	mov	si,offset program
copyname:
	mov	al,es:[di]
	mov	ds:[si],al
	inc	si
	inc	di
	or	al,al
	jne	copyname

	movseg	es,cs

	mov	ah,4bh
	mov	bx,offset parm
	mov	dx,offset program
	mov	al,0
	int	21h

	mov	bx,cs			;restore our segment registers.
	mov	ds,bx
	mov	es,bx
	mov	ss,bx
	mov	sp,offset stack

; Give up our packet interception.

	mov	al,entry_point	;release our_isr.
	mov	ah,25h
	push	ds
	lds	dx,their_isr
	int	21h
	pop	ds

; Now we write our captured information out to disk.

	mov	dx,offset trace_out	;create "trace.out".
	mov	ah,3ch
	mov	cx,0
	int	21h

	mov	bx,ax

	mov	si,queue_head
write_out:
	mov	dx,si
	mov	cx,[si].event_length	;write this event out.
	add	si,cx			;is this the end of the queue?
	cmp	si,queue_end		;
	ja	write_out_1

	mov	ah,40h
	int	21h
	cmp	ax,cx
	jne	write_out_full

	jmp	write_out

write_out_1:
	mov	si,offset queue_begin	;yes.
write_out_2:
	cmp	si,queue_tail		;quit when we hit the tail.
	jae	write_out_3

	mov	dx,si			;set dx for the file write below.
	mov	cx,[si].event_length	;write this event out.
	add	si,cx

	mov	ah,40h
	int	21h
	cmp	ax,cx
	jne	write_out_full

	jmp	write_out_2
write_out_3:
	mov	ah,3eh			;close the file.
	int	21h

	mov	dx,offset run_dump_msg
	mov	ah,9
	int	21h

	int	20h

write_out_full:
	mov	ah,9
	mov	dx,offset disk_full_msg
	int	21h
	int	20h


	include	intchk.asm
	include	getnum.asm
	include	printnum.asm
	include	skipblk.asm
	include	getdig.asm
	include	decout.asm
	include	digout.asm
	include	chrout.asm
	include	getenv.asm
	include	crlf.asm

end_code	label	byte

queue_begin	label	byte

code	ends

	end	start
