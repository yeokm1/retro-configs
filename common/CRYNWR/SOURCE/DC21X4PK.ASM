version	equ	4

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
;   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA

	include	defs.asm

cgroup	group	code,init,_text

code	segment para public 'code'
code	ends

_text	segment para public 'code'
_text	ends

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

	public	int_no
int_no	db	0,0,0,0			;must be four bytes long for get_number.

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK,0	;null terminated list of classes.
driver_type	db	0		;assigned by Crynwr Software, <info@crynwr.com>
driver_name	db	'skeleton',0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver specification
	db	9	;minor rev of packet driver specification
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0		;there is no mode zero.
		dw	0,0,rcv_mode_3
		dw	0,0,rcv_mode_6

	public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	mov	dh,BAD_COMMAND
	stc
	ret

	public	as_send_pkt
; The Asynchronous Transmit Packet routine.
; Enter with es:di -> i/o control block, ds:si -> packet, cx = packet length,
;   interrupts possibly enabled.
; Exit with nc if ok, or else cy if error, dh set to error number.
;   es:di and interrupt enable flag preserved on exit.
as_send_pkt:
	ret

	public	drop_pkt
; Drop a packet from the queue.
; Enter with es:di -> iocb.
drop_pkt:
	assume	ds:nothing
	ret

	public	xmit
; Process a transmit interrupt with the least possible latency to achieve
;   back-to-back packet transmissions.
; May only use ax and dx.
xmit:
	assume	ds:nothing
	ret


	extrn	SetStationAddress: near
	public	set_address
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
 	assume	ds:code
set_address:
	call	SetStationAddress
	or	ax,ax
	je	set_address_exit
	stc
set_address_exit:
 	ret


rcv_mode_3:
	mov	ax,3
	call	SetPacketFilter
	ret

rcv_mode_6:
	mov	ax,4
	call	SetPacketFilter
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	mov	dh,NO_MULTICAST
	stc
	ret


	public	terminate
terminate:
	extrn	CloseAdapter: near
	call	CloseAdapter
	ret


	public	reset_interface
reset_interface:
;reset the interface.
	assume	ds:code
	ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
	extrn	recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn	recv_copy: near

;call this routine to schedule a subroutine that gets run after the
;recv_isr.  This is done by stuffing routine's address in place
;of the recv_isr iret's address.  This routine should push the flags when it
;is entered, and should jump to recv_exiting_exit to leave.
;enter with ax = address of routine to run.
	extrn	schedule_exiting: near

;recv_exiting jumps here to exit, after pushing the flags.
	extrn	recv_exiting_exit: near

	extrn	count_in_err: near
	extrn	count_out_err: near

	public	recv
recv:
;called from the recv isr.  All registers have been saved, ds=cs,
;our interrupt has been acknowledged, and our interrupts have been
;masked at the interrupt controller.
	assume	ds:code
	ret


code	ends

init	segment para public 'code'
	assume	cs:cgroup, ds:cgroup

	public	usage_msg, mca_usage_msg
mca_usage_msg	label	byte
usage_msg	db	"usage: dc21x4pk [options] <packet_int_no>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for a DC21X4X device, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1998, Digital (version 2.62)",CR,LF,'$'

;called when you're ready to receive interrupts.
	extrn	set_recv_isr: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> dword to print.
	extrn	print_number: near

;-> the unique Ethernet address of the card.  Filled in by the etopen routine.
	extrn	rom_address: byte

;-> current address.  Normally the same as rom_address, unless changed
;by the set_address() call.
	extrn	my_address: byte

bind_failed_msg	db	"Bind failed.$"
open_failed_msg	db	"Open failed.$"
filter_failed_msg db	"Filter failed.$"

	public	etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.  Exit with nc if all went well, or cy, dx -> $ terminated error msg.
;if all is okay,
	extrn	InitDriverInit: near
	call	InitDriverInit
	jc	etopen_4
	extrn	Bind: near
	call	Bind
	or	ax,ax		; did it work?
	mov	dx,offset cgroup:bind_failed_msg
	jne	etopen_4	; no
	extrn	OpenAdapter: near
	call	OpenAdapter
	or	ax,ax		; did it work?
	mov	dx,offset cgroup:open_failed_msg
	jne	etopen_4	; no
	extrn	SetPacketFilter: near
	mov	ax,3
	call	SetPacketFilter
	or	ax,ax		; did it work?
	mov	dx,offset cgroup:filter_failed_msg
	jne	etopen_4	; no
	call	set_recv_isr	; glom onto the timer interrupt.
	clc
	jmp	etopen_1

etopen_4:
	mov	bx,dx
etopen_2:
	mov	al,[bx]
	or	al,al
	je	etopen_3
	cmp	al,'$'
	je	etopen_3
	inc	bx
	jmp	etopen_2
etopen_3:
	mov	byte ptr [bx],'$'
	stc
etopen_1:
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	ret

init	ends

	end
