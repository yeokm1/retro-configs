        PAGE    60,130
        TITLE   PLIP Module of PLIP
;
;  PAGE and TITLE directives added to dress up listing.
;  Fred C. Macall  1 June 2003.
;
;  send_pkt revised to always check all five response bits for the value
;  expected at each point.  This is to reduce the chances for mistakes
;  caused by noise or ringing in the cable.  send_pkt also revised to
;  insure that it sends zeros on the un-used three lines.
;  Eight delaying IN al,061h instructions added to the send_nibble_1 loop.
;  (To match the delaying instructions in recv_byte's loops.)
;
;  etopen_1 and the area following end_resident revised to make the
;  receive buffer a little bigger than necessary.  Just to be sure.
;
;  recv revised to disable maskable interrupts while actually receiving
;  a packet.  This may be needed to keep a slow PC's timer interrupts
;  from interfering with the reception of packets from a fast PC.
;  recv also revised to check the received count byte so as to guard
;  against buffer overrun.  recv_byte revised to double check each
;  received nibble in order to reduce the chances for mistakes caused by
;  noise or ringing in the cable.  recv_free's time out value reduced to
;  match the value stated in the existing comment.
;
;  version upped to 2.
;  Copyright notice extended.
;  Fred C. Macall  4 June 2003.
;
;  send_pkt extended to send 00Ch alternating with 004h when bidding
;  to transfer a packet.  This is intended to bring the bid to recv's
;  attention, even where the receiving PC's parallel port needs a low
;  level or negative transition, instead of a high level or positive
;  transition, on the -ACK line, to produce an IRQ.
;  (Zeke's parallel port is of this kind!)
;  recv extended to accept the reception of 004h and 00Ch, in addition
;  to 008h, when checking for a spurious interrupt.
;  These changes may break this version's compatibility with other
;  (or, older) versions of PLIP.  If they work out, we'll add a
;  command line parameter to effect them.
;  Fred C. Macall  5 June 2003.
;
;  (Yesterday's changes have solved all apparent problems, other than
;  apparent TOD clock interrupts loss and spurious receive interrupts,
;  with PLIP on the Zeke - Digerydo connection!)
;  send_pkt revised, as promised, to stick with the traditional 008h bid
;  code unless A_OPTION is set.
;  recv revised to count spurious receive interrupts only in the separate
;  counter incremented by count_in_spur.
;  Fred C. Macall  6 June 2003.
;
;  timer_isr stuff commented out to make way for HEAD.ASM's new timer_isr.
;  Fred C. Macall  15 June 2003.
;
;  recv_free revised to not wait for the receipt of a zero when int_no is
;  zero.  (i.e.:  No wait when we're timer interrupt driven.)
;  Fred C. Macall  19 June 2003.
;
;  recv extended to place no debug digit on the display if C_OPTION is set.
;  Fred C. Macall  26 June 2003.
;
version	equ	2
;;;History:656,1

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

comment \

The following says how to transfer a sequence of bytes.  The bytes
are structured as [ count-low, count-high, bytes, bytes, bytes, checksum ].

Send		Recv
008h or 00Ch alternating with 004h->
		<-001h
[ repeat the following
010h+low_nib->
		<-010h
high_nib->
		<-000h
until all bytes have been transferred ]
\

DATA		equ	0
REQUEST_IRQ	equ	08h
STATUS		equ	1
CONTROL		equ	2

	public	int_no
int_no	db	7,0,0,0			;must be four bytes long for get_number.
io_addr	dw	0378h,0			; I/O address for card (jumpers)

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	1,0		;null terminated list of classes.
driver_type	db	90		;from the packet spec
driver_name	db	'parallel',0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

recv_buffer	dw	?		;-> buffer.
recv_count	dw	?

send_nib_count	db	?
recv_byte_count	db	?

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0,0,0,rcv_mode_3
		dw	0,0,rcv_mode_6

	include	timeout.asm

hexout_ptr	dw	0
hexout_color	db	70h

hexout_more:
	ret
	push	di
	mov	di,cs:hexout_ptr
	call	hexout
	add	di,4
	cmp	di,25*80*2
	jb	hexout_more_1
	xor	di,di
hexout_more_1:
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

        EXTRN   flagbyte: byte

	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

;  Wait for the other end to ack the interrupt.
        MOV     ax,18                   ;  About half a second.
	call	set_timeout

;  Cause an interrupt on the other end.
;  If the A_OPTION (Antique hardware helper) bit isn't set, send 008h.
;  Otherwise, send 00Ch alternating with 004h.
        MOV     bl,004h                 ;  BL = initial bid code.

send_pkt_1:
	loadport
	setport	DATA
        XCHG    ax,bx                   ;  AL = bid code.
        TEST    flagbyte,A_OPTION       ;  If sending to an antique,
        JNZ     SHORT send_pkt_xor      ;    go continue.
        SUB     al,al                   ;  Forget last bid.
;                                            So, don't alternate.
send_pkt_xor:
        XOR     al,REQUEST_IRQ          ;  Alternate 00Ch with 004h.
;                                            Or, simply load 008h.
	out	dx,al
        XCHG    ax,bx                   ;  BL = bid code, again.
	setport	STATUS
	in	al,dx
        AND     al,0F8h
        CMP     al,080h+(001h*8)        ;  Wait for them to output 001h.
	JZ	send_pkt_2
	call	do_timeout
	jne	send_pkt_1
        jmp     short send_pkt_4        ;  If time-out, they're not listening.

send_pkt_2:
	mov	send_nib_count,0
	setport	DATA
	mov	al,cl			;send the count.
	call	send_byte
	jc	send_pkt_4		;it timed out.
	mov	al,ch
	call	send_byte
	jc	send_pkt_4		;it timed out.
	xor	bl,bl
send_pkt_3:
	lodsb				;send the data bytes.
	add	bl,al
	call	send_byte
	jc	send_pkt_4		;it timed out.
	loop	send_pkt_3

	mov	al,bl			;send the checksum.
	mov	hexout_color,30h	;aqua
	call	hexout_more
	call	send_byte
	jc	send_pkt_4		;it timed out.

	mov	al,0			;go back to quiescent state.
	out	dx,al
	clc
	ret

send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret

send_pkt_4:
	loadport
	setport	DATA
	mov	al,send_nib_count
	mov	hexout_color,20h	;green
	call	hexout_more
	xor	al,al			;clear the data.
	out	dx,al
	mov	dh,CANT_SEND
	stc
	ret
;
; It's important to ensure that the most recent setport is a setport DATA.
;
send_byte:
;enter with al = byte to send.
;exit with cy if it timed out.
	push	ax
        AND     al,01Fh         ;  Send zero on the un-used lines.
	OR	al,010h			;set the clock bit.
	call	send_nibble
	pop	ax
	jc	send_nibble_2
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1			;clock bit is cleared by shr.

send_nibble:
;enter with setport DATA, al[3-0] = nibble to output.
;exit with dx set to DATA.
	out	dx,al
	AND	al,010h			;  Get the bit we're waiting for to come back.
	shl	al,1			;put it in the right position.
	shl	al,1
	shl	al,1
	mov	ah,al
	mov	hexout_color,60h	;orange
	call	hexout_more

	setport	STATUS
	push	cx
	xor	cx,cx
send_nibble_1:
        IN      al,061h
        IN      al,061h
        IN      al,061h
        IN      al,061h
        IN      al,061h
        IN      al,061h
        IN      al,061h
        IN      al,061h

	in	al,dx			;  Keep getting the status until
	XOR	al,080h
	AND	al,0F8h
	cmp	al,ah			;    we get the status we're looking for.
	loopne	send_nibble_1
	pop	cx
	jne	send_nibble_2

	mov	hexout_color,50h	;purple
	call	hexout_more

	inc	send_nib_count
	setport	DATA			;leave with setport DATA.
	clc
	ret

send_nibble_2:
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
rcv_mode_6:
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

;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
	extrn	malloc: near

	extrn	count_in_err: near
	extrn	count_out_err: near
        EXTRN   count_in_spur: near

recv_char	db	'0'

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code

	loadport			;see if we've gotten a real interrupt.
	setport	STATUS

        CLI                     ;  Disable maskable interrupts.

	in	al,dx
        AND     al,0F8h         ;  The bottom three bits are undefined.
        XOR     al,080h         ;  This bit should be received as on.
        TEST    al,09Fh         ;  So, all these bits should be off, now.
        JNZ     SHORT spurious  ;  If any bad boys, it's . . .
        TEST    al,060h         ;  At least one of these should be on.
        JNZ     SHORT recv_real ;  If have one, go continue.

spurious:
        STI                     ;  Enable all interrupts again.

        CALL    count_in_spur
	JMP	recv_free

recv_real:
        TEST    flagbyte,C_OPTION       ;  If have a clean display requested,
        JNZ     SHORT SETESDI           ;    go continue without placing a
;                                              debug digit on the display.
	mov	al,recv_char
	inc	recv_char
	and	recv_char,'7'
	to_scrn	24,79,al
SETESDI:
	movseg	es,ds
	mov	di,recv_buffer

	loadport
	setport	DATA
	mov	al,1			;say that we're ready.
	out	dx,al

	mov	recv_byte_count,0

	setport	STATUS
	call	recv_byte		;get the count.
	jc	recv_err			;it timed out.
	mov	cl,al
	call	recv_byte
	jc	recv_err			;it timed out.
	mov	ch,al
        CMP     cx,GIANT                ;  If (count) is to large,
        JA      SHORT recv_err          ;    go choke.
	xor	bl,bl
	mov	recv_count,cx
recv_1:
	call	recv_byte		;get a data byte.
	jc	recv_err			;it timed out.
	add	bl,al
	stosb
	loop	recv_1

	call	recv_byte		;get the checksum.
	jc	recv_err			;it timed out.
	cmp	al,bl			;checksum okay?
	jne	recv_err		;no.

        STI                             ;  Enable all interrupts.

	movseg	es,cs
	mov	di,recv_buffer
	push	es
	push	di

	mov	cx,recv_count
	add	di,EADDR_LEN+EADDR_LEN	;skip the ethernet addreses and
					;  point to the packet type.
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
	push	cx
	call	recv_find
	pop	cx

	pop	si
	pop	ds
	assume	ds:nothing

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_free		;yes - just free the frame.

	push	es
	push	di
	push	cx
	rep	movsb
	pop	cx
	pop	si
	pop	ds
	assume	ds:nothing

	call	recv_copy

	jmp	short recv_free

recv_err:
	call	count_in_err
recv_free:

        STI                     ;  Insure all interrupts enabled.

	movseg	ds,cs
	assume	ds:code

        CMP     int_no,0        ;  If not hardware interrupt driven,
        JZ      SHORT recv_4    ;    go finish-up.
;  Wait for the other end to reset to zero.
	MOV	ax,4			;  1/9th of a second.
	call	set_timeout
	loadport
	setport	STATUS
recv_pkt_1:
	in	al,dx
	AND	al,0F8h
	CMP	al,080h			;wait for them to output 000h.
	je	recv_4

	mov	hexout_color,20h	;green
	call	hexout_more

	call	do_timeout
	jne	recv_pkt_1

	mov	al,recv_byte_count
	mov	hexout_color,20h	;green
	call	hexout_more
recv_4:
	loadport
	setport	DATA
	xor	al,al
	out	dx,al
	ret

	setport	STATUS			;this code doesn't get executed,
					;but it sets up for call to recv_byte.

recv_byte:
;called with setport STATUS.
;exit with nc, al = byte, or cy if it timed out.

	push	cx
	SUB	cx,cx
        MOV     al,0FFh                 ;  AL = something we don't want.
;  Do up to 65536 times:
recv_low_nibble:
        MOV     ah,al                   ;  Save (data value)
;                                            for consecutive match check.
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h

	in	al,dx			;get the next data value.
        AND     al,0F8h                 ;  Clarify (data value).
	TEST	al,080h			;  Wait for handshake low (transmitted hi).
	loopne	recv_low_nibble
        JNZ     SHORT recv_byte_1
;  Also, look for two consecutive reads matching.
        INC     cx                      ;  Set back dec.d(loop count).
        CMP     ah,al                   ;  If no match,
        LOOPNZ  SHORT recv_low_nibble   ;    see about a repeat.
;  End do upto 65536 times.
;  (Have a match or (loop count) is exhausted.)
        JNZ     SHORT recv_byte_1       ;  If (no match), go restore cx
;                                            and return with Carry set.

	SHR	ah,1			;  Put our bits into position.
	SHR	ah,1
	SHR	ah,1
;;;     AND     ah,00Fh                 ;  Don't need this one.

	MOV	al,010h			;  Send our handshake back.
	setport	DATA
	out	dx,al
	setport	STATUS

        PUSH    ax
	SUB	cx,cx
        SUB     al,al                   ;  AL = something we don't want.
;  Do up to 65536 times.
recv_high_nibble:
        MOV     ah,al
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h
	in	al,61h

	in	al,dx			;get the next data value.
        AND     al,0F8h
	TEST	al,080h			;  Check for handshake high (transmitted low).
	loope	recv_high_nibble
        JZ      SHORT recv_byte_2
        INC     cx
        CMP     ah,al
        LOOPNZ  SHORT recv_high_nibble
;  End do up to 65536 times.
        JNZ     SHORT recv_byte_2

        XCHG    ax,cx                   ;  CL =
        SHL     cl,1                    ;    justified(high nibble).
        POP     ax                      ;  AH = un-stacked(low nibble),
        OR      ah,cl                   ;    combined with (high nibble).
        POP     cx                      ;  Un-stack CX.

	mov	al,0			;send our handshake back.
	setport	DATA
	out	dx,al
	setport	STATUS

	inc	recv_byte_count

	mov	al,ah
	mov	hexout_color,40h	;red
	call	hexout_more
	clc
	ret

recv_byte_2:
        POP     ax
recv_byte_1:
        POP     cx
	stc
	ret

;;;	public	timer_isr
;;;timer_isr:
;;;;if the first instruction is an iret, then the timer is not hooked
;;;	iret

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
	db	GIANT+20 dup(?)
end_free_mem	label	byte

	public	usage_msg, mca_usage_msg
mca_usage_msg	label	byte
usage_msg	db	"usage: parallel [options] <packet_int_no> [-t] <hardware_irq> <io_addr> [<Ethernet_address>]",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for parallel port interfaces, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1992, Russell Nelson",CR,LF
                DB      "Modifications:  Fred C. Macall (fmacall@nccw.net), 2003.",CR,LF,'$'

no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in PARALLEL.ASM",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

test_switch	db	0
test_bit	db	1

	extrn	set_recv_isr: near

	extrn	chrout: near
	extrn	skip_blanks: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> dword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	jne	not_switch
	cmp	byte ptr [si+1],'t'	;did they specify '-t'?
	je	got_test_switch
	stc				;no, must be an error.
	ret
got_test_switch:
	mov	test_switch,1
	add	si,2			;skip past the switch's characters.
	jmp	parse_args		;go parse more arguments.
not_switch:

	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number

	mov	rom_address[0],2	;locally administered.

	mov	ax,40h
	mov	es,ax
	mov	ax,es:[6ch]
	mov	word ptr rom_address[2],ax
	mov	ax,es:[6eh]
	mov	word ptr rom_address[4],ax

	movseg	es,ds
	mov	di,offset rom_address
	call	get_eaddr
	clc
	ret


	public	etopen
etopen:
	loadport
	setport	CONTROL			;enable interrupts on the board.
	mov	al,10h
	out	dx,al

	cmp	test_switch,0
	je	etopen_1

	mov	ax,5
	call	set_timeout
etopen_2:
;print the status of the incoming lines.
	loadport
	setport	STATUS
	in	al,dx
	xor	al,80h
	mov	ah,al
	mov	cx,5			;print five bits.
etopen_3:
	push	ax			;time to toggle the outgoing bits?
	call	do_timeout
	jne	etopen_4		;no.
	setport	DATA			;yes, shuffle the bit around.
	mov	al,test_bit
	shr	al,1
	jnc	etopen_5
	mov	al,10h
etopen_5:
	mov	test_bit,al
	out	dx,al
	setport	STATUS
	mov	ax,5
	call	set_timeout
etopen_4:
	pop	ax
	shl	ah,1
	mov	al,'0'
	adc	al,0
	call	chrout
	loop	etopen_3
	mov	al,CR
	call	chrout

	mov	ah,1			;did they hit a key?
	int	16h
	jz	etopen_2		;no.

	mov	ah,0			;yes, suck the key out.
	int	16h

	setport	DATA			;reset the data port.
	xor	al,al
	out	dx,al

etopen_1:
;  Leave a little extra room in the receive buffer.
	mov	dx,GIANT+20		;  Allocate memory for the receive buffer.
	call	malloc
	jc	no_memory
	mov	recv_buffer,dx

	call	set_recv_isr

	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	clc
	ret
no_memory:
	mov	dx,offset no_memory_msg
	stc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	ret

	extrn	get_hex: near
	include	getea.asm

code	ends

	end
