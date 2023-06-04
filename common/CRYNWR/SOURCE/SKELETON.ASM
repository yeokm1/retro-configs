version	equ	0

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

	include	defs.asm

code	segment	word public
	assume	cs:code, ds:code

	public	int_no
int_no	db	0,0,0,0			;must be four bytes long for get_number.

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK,0	;null terminated list of classes.
driver_type	db	0		;assigned by FTP Software, <jbvb@ftp.com>
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
rcv_modes	dw	4		;number of receive modes in our table.
		dw	0		;there is no mode zero.
		dw	0,0,rcv_mode_3

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


	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
	mov	dh,CANT_SEND
	stc
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	mov	dh,CANT_SET
	stc
	ret


rcv_mode_3:
;receive mode 3 is the only one we support, so we don't have to do anything.
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


	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte


	public	usage_msg
usage_msg	db	"usage: skeleton [options] <packet_int_no>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for a <foo> device, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 19xx, <your name here>",CR,LF,'$'

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

;parse_args is called with si -> first parameter (CR if none).
	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	clc
	ret


	public	etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.  Exit with nc if all went well, or cy, dx -> $ terminated error msg.
;if all is okay,
	clc
	ret
;if we got an error,
	stc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	ret

code	ends

	end
