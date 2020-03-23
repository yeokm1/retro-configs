version	equ	7

	include	defs.asm

;Ported from Phil Karn's asy.c and slip.c, a C-language driver for the IBM-PC
;8250 by Russell Nelson.  Any bugs are due to Russell Nelson.
;16550 support ruthlessly stolen from Phil Karn's 8250.c. 
;  Bugs by Denis DeLaRoca
;
 if ETHERSLIP
; Modified by Michael Martineau to provide a class 1 interface.
; Additional modifications by Joe Doupnik, jrd@cc.usu.edu, 5 Nov 1991
;  Do not use "c0h" as leading vendor byte in artifical Ethernet address.
;  Use originator's Ethernet address as destination of ARP Reply address.
;
 endif
; Stopped failures from lost transmit interrupts (by eliminating the ints
; altogether). Remove unneeded transmitter buffer.
; Version 6 by Joe Doupnik, jrd@cc.usu.edu, Utah State University, Dec 1991.
; Fix hardware handshaking problems.  Philip R. "Pib" Burns,
;   Northwestern University, September, 1992.

;  Copyright, 1988, 1991, Russell Nelson

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

code	segment	word public
	assume	cs:code, ds:code

	include	8250defs.asm

;Slip Definitions
FR_END		equ	0c0h		;Frame End
FR_ESC		equ	0dbh		;Frame Escape
T_FR_END	equ	0dch		;Transposed frame end
T_FR_ESC	equ	0ddh		;Transposed frame escape

	public	int_no
int_no		db	4,0,0,0		; interrupt number.
io_addr		dw	03f8h,0		; I/O address for COM1
baud_rate	dw	12c0h,0		; support baud higher than 65535
baudclk		label	word
		dd	115200		; 1.8432 Mhz / 16
hardware_switch	db	0		; if zero, don't use hw handshaking
is_16550        db      0               ; 0=no, 1=yes (try using fifo)

	public	driver_class, driver_type, driver_name 
	public	driver_function, parameter_list
  if	ETHERSLIP
driver_class	db	1,0,0,0		;from the packet spec
driver_type	db	0,0,0,0		;from the packet spec
driver_name	db	'ETHERSLIP',0	;name of the driver.
  else
driver_class	db	6,0,0,0		;from the packet spec
driver_type	db	0,0,0,0		;from the packet spec
driver_name	db	'SLIP8250',0	;name of the driver.
  endif
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN    ;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

  ifdef debug
	public recv_buf_size, recv_buf,	recv_buf_end, recv_buf_head
	public recv_buf_tail, recv_pkt_ready
  endif
recv_buf_size	dw	3000,0		;receive buffer size
recv_buf	dw	?		;->receive buffer
recv_buf_end	dw	?		;->after end of buffer
recv_buf_head	dw	?		;->next character to get
recv_buf_tail	dw	?		;->next character to store
recv_pkt_ready	dw	0		; flag indicating a packet is ready
  if ETHERSLIP
  else
IP_TYPE	DW	0800H
  endif

  ifdef debug
	public packet_sem, xmit_time
  endif
packet_sem	dw	0		; semaphore for	packets received
asyrxint_cnt	dw	0		; loop counter in asyrxint
xmit_time	dw	0		; loop timer for asyrxint

  if	ETHERSLIP
;
; ARP request/reply packet structure.
;
arp		struc 
arp_hw		dw ? 		; Hardware address length, bytes 
arp_prot	dw ? 		; Protocol type 
arp_hwalen	db ? 		; hardware address length, bytes 
arp_pralen 	db ? 		; Length of protocol address 
arp_opcode      dw ? 		; ARP opcode (request/reply) 
arp_shwaddr	db 6 dup(?)	; Sender hardware address field 
arp_sprotaddr	dd ?		; Sender Protocol address field 
arp_thwaddr	db 6 dup(?)	; Target hardware address field 
arp_tprotaddr	dd ?		; Target protocol address field 
arp		ends

;
; recv_find() requires a pointer to the Ethernet packet type.  Since
; the incoming packet does not contain an Ethernet packet type field,
; memory must be allocated to hold the Ethernet packet type.  Space is
; required for both IP and ARP types.
;
ip_type		label	byte
		db	08
		db	00	

arp_type	label	byte
		db	08
		db	06	

;
; Pseudo-Ethernet address to return in the ARP reply packet.
;
your_addr	label 	byte
		db	00
		db	00
		db	0
		db	22h
		db	34h
		db	66h
  endif

raw_mode	db	0		;=1 if we send and receive raw chars.

	public	rcv_modes
rcv_modes	dw	8		;number	of receive modes in our table
		dw	0,0,0,rcv_mode_3
		dw	0,0,0,rcv_mode_7


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
;
; mod 7/25/89 John Grover
; - operates with interrupts on. Xmits one byte per interrupt
; - only turns transmitter buffer empty interrupt off when
; - all bytes of all packets are transmitted.

send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)

;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, or else cy if error, dh set to error number.
;called from telnet layer via software interrupt
; We just send each byte in turn. No UART interrupts are needed nor wanted.
; In fact the overdone receiver material omits to note that xmtr interrupts
; can be lost while processing rcvr ones. Small benefits are no stalled
; programs, no transmitter buffer, no problems at 19200 b/s. Joe Doupnik
;
; Unfortunately the revised code didn't handle hardware handshaking.
; Added back by Pib, September, 1992.
;
	assume	ds:nothing, es:nothing
	sti				; enable interrupts
	cmp	raw_mode,0
	je	not_send_raw
send_raw:
	lodsb
	call	send_char
	loop	send_raw
	clc
	ret
not_send_raw:
  if	ETHERSLIP
;	
; Strip off Ethernet header.
;
	add	si,12
	mov	ax, word ptr ds:[si]
	add	si,2
	sub	cx,14
;
; Check packet type.  If an ARP packet then construct an ARP reply
; packet. Otherwise, process the incoming IP packet.
;
	cmp	ax,0608h
	jne	noarp
	call	arp_reply
	jmp	send_pkt_end

noarp:
  endif
	mov	al,FR_END		; Flush out any line garbage
	call	send_char
	jc	send_pkt_end		; c = failure to send

;Copy input to output, escaping special characters
send_pkt_1:
	lodsb
	cmp	al,FR_ESC	  ; escape FR_ESC with FR_ESC and T_FR_ESC
	jne	send_pkt_2
	mov	al,FR_ESC
	call	send_char
	jc	send_pkt_end
	mov	al,T_FR_ESC
	jmp	short send_pkt_3
send_pkt_2:
	cmp	al,FR_END	  ; escape FR_END with FR_ESC and T_FR_END
	jne	send_pkt_3
	mov	al,FR_ESC
	call	send_char
	jc	send_pkt_end
	mov	al,T_FR_END
send_pkt_3:
	call	send_char
	jc	send_pkt_end
	loop	send_pkt_1		; do cx user characters
	mov	al,FR_END		; terminate it with a FR_END
	call	send_char
	jc	send_pkt_end
	clc
send_pkt_end:
	ret

; mod 7/25/89 John Grover
; redone by Joe Doupnik, Dec 1991
; CTS check added by Pib, September, 1992.
	assume	ds:nothing, es:nothing
send_char:				; send the character in al
	push	dx
	push	cx
        push    bx
	xchg	ah,al			; put data char into ah
	xor	cx,cx			; 64K retry counter
        mov     bl,hardware_switch      ; Get hardware check (CTS) switch
sendch1:mov	dx,io_addr		; 03f8h base address
	add	dx,LSR			; 03fdh get port status
	in	al,dx
	test	al,LSR_THRE		; Transmitter (THRE) ready?
        jz      sendch4                 ; No -- loop and check again.
        cmp     bl,0                    ; Yes -- check CTS ready if needed.
        jz      sendch2                 ; No check -- send the character.
        mov     dx,io_addr              ; Else get 03f8h base address
        add     dx,MSR                  ; 03fdh get port status
	in	al,dx
        test    al,MSR_CTS              ; Is CTS ready?
        jnz     sendch2                 ; nz = yes
sendch4:jmp     $+2                     ; use time, prevent overdriving UART
	jmp	$+2
	loop	sendch1
	stc				; carry set for failure
	jmp	short sendch3		; timeout
sendch2:xchg	al,ah			; now send it
	mov	dx,io_addr		; 03f8h, use a little time
	jmp	$+2
	out	dx,al			; send the byte
	clc				; status of success
sendch3:pop	bx
	pop	cx
	pop	dx
	ret

  if	ETHERSLIP
;
; Formulate a dummy ARP reply packet.  ds:si points at the incoming
; IP packet.
;

arp_reply:

;
; Save the registers.  Not sure that we need to but it works and I 
; don't want to change it right now.
;
	push	ds
	push	es
	push	si
	push	di
	push	cx

;
; Check to see if the ARP request is to find the hardware address
; of the local host.  If so, then don't formulate a reply packet.
;
	mov	cx,4
	mov	ax,si
	mov	di,ax
	mov	ax,ds
	mov	es,ax
	add	di,arp_sprotaddr
	add	si,arp_tprotaddr
	repe	cmpsb			; Compare source and target
					; protocol address
	jnz	arp_reply_2
	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds
	ret

arp_reply_2:
;
; Restore registers.
;
	pop	cx
	pop	di
	pop	si
	push	si
	push	di
	push	cx
;
; Restore Ethernet header.
;
	add	cx,14
	sub	si,14 
;
; Ask application layer for a memory buffer in which to store
; incoming packet.
;
	push	ds
	push	si			;save si in case we reject it.
	push	bx
	push	cx
	mov	ax,cs
	mov	es,ax
	mov	ds,ax
	mov	di, offset arp_type
	mov	dl,cs:driver_class
	call	recv_find		;look up our type.
	pop	cx
	pop	bx
	pop	si
	pop	ds

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	arp_reply_1		;yes - just free the frame.

	push	cx
	push	es
	push	di
;
; Save si,di for future use.
;
	mov	bx,si
	mov	dx,di
;
; Set up ARP Reply by first copying the ARP Request packet.
;
	rep	movsb
;
; Skip Ethernet header
;
	add	bx,14
	add 	dx,14
;
; Swap target and source protocol addresses from ARP request to ARP 
; reply packet.
;
	push	es		; mods by Joe Doupnik
	mov	si,ds
	mov	es,si
	mov	si,bx		; incoming packet interior
	sub	si,2+6		; walk back to originator's Ethernet address
	mov	cx,6		; six bytes of Ethernet address
	mov	di,dx		; outgoing packet
	sub	di,2+6+6	; Ethernet destination address
	rep	movsb		; copy originator's address as new dest
	pop	es		;

	mov	si,bx
	mov	di,dx	
	mov	cx,4
	add	si,arp_tprotaddr
	add	di,arp_sprotaddr
	rep	movsb

	mov	si,bx
	mov	di,dx
	mov	cx,4
	add	si,arp_sprotaddr
	add	di,arp_tprotaddr
	rep	movsb
;
; Swap target and source hardware addresses from ARP request to ARP 
; reply packet.
;
	mov	si,bx
	mov	di,dx
	mov	cx,6
	add	si,arp_shwaddr
	add	di,arp_thwaddr
	rep	movsb
;
; Load source hardware address in ARP reply packet.
;
	mov	si,bx
	mov	di,dx
	mov	cx,6
	mov	ax,cs
	mov	ds,ax
	mov	si,offset your_addr
	add	di,arp_shwaddr
	rep	movsb
;
; Set opcode to REPLY.
;
	mov	di,dx
	mov	word ptr es:[di].arp_opcode,0200h
; 
; Give ARP reply packet that has been constructed to the application
; layer.
;
	pop	si
	pop	ds
	pop	cx
	assume	ds:nothing
	call	recv_copy
	assume	ds:code

arp_reply_1:

	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds

	ret
  endif

	public	set_address
set_address:
;set the address of the interface.
;enter with es:di -> place to get the address, cx = size of address buffer.
;exit with nc, cx = actual size of address, or cy if buffer not big enough.
	assume	ds:nothing
	clc
	ret


rcv_mode_3:
;exit raw mode
	mov	raw_mode,0
	ret

rcv_mode_7:
;enter raw mode
	mov	raw_mode,1
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


;called	when we	want to determine what to do with a received packet.
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

	public	recv

;
; mod 7/25/89 John Grover
;
; - added code to check modem status change interrupt. If CTS is
; - low  turn off transmitter buffer empty interrupt. If CTS is
; - high turn it on.

recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code
	mov	ax,offset recv_exiting	;schedule recv_exiting to be called
	call	schedule_exiting	;  on exit.
recv_2:
	loadport
	setport	IIR
	in	al,dx			;any interrupts at all?
	test	al,IIR_IP
	jne	recv_1			;no.
	and	al,IIR_ID
	cmp	al,IIR_RDA		;Receiver interrupt
	jne	recv_3
	call	asyrxint
	jmp	recv_2
recv_3:
recv_5:
;process IIR_MSTAT here.
;  If CTS and packet ready then
;    enable the	transmit buffer empty interrupt
;  else
;    disable the transmit buffer empty interrupt
;
	cmp	al, IIR_MSTAT
	jne	recv_1
;	setport	MSR			; make sure of CTS status
;	in	al, dx
;	test	al, MSR_CTS		; is CTS bit set
;	jz	recv_5_1		; no - disable xmit buffer empty int
	jmp	recv_2

recv_5_1:
	jmp	recv_2

;process IIR_RLS here
recv_1:
	ret


;Process 8250 receiver interrupts
;
; mod 7/25/89 John Grover
; - this branches off when bps < 9600. See asyrxint_a.
; - Above 9600 bps we go into a loop to process a packet at
; - a time. If not data ready for a certain amount of time,
; - the process exits and waits for the next byte. This certain
; - amount of time to wait depends on the bps and CPU processor speed
; - and is determined in the initialization of the driver.
; - Upon receiving the FR_END character for the first frame in the
; - buffer a semaphore is set which tells recv_frame to run.

asyrxint:

	movseg	es,ds
	xor	bx, bx
	cmp	baud_rate, 9600         ; below 9600 we're strictly
	jbe	asyrxint_a              ; interrupt driven
	mov	bx, xmit_time
asyrxint_a:
	mov	di,recv_buf_tail
	xor	bp, bp			; set flag to indicate 1st char
					; processed
	mov	si, packet_sem          ; optimization
	loadport
	mov	ah, LSR_DR

asyrxint_again:
	xor	cx, cx			; initialize counter
	setport	LSR
asyrxint_in:
	in	al,dx			; check for data ready
	test	al,LSR_DR
	jnz	asyrxint_gotit		; yes - break out of loop
	inc	cx			; no - increase loop counter
	cmp	cx, bx			; timeout?
	jae	asyrxint_exit		; yes - leave
	jmp	asyrxint_in		; no - keep looping

asyrxint_gotit:
	setport	RBR
	in	al,dx

;Process incoming data;
; If buffer is full, we have no choice but
; to drop the character
	cmp	di,recv_buf_head	; check for buffer collision
	jne	asyrxint_ok		; none - continue
	or	si, si                  ; maybe - if there are packets
	jnz	asyrxint_exit		; yes exit

asyrxint_ok:
	stosb

	cmp	di,recv_buf_end		; did we hit the end of the buffer?
	jne	asyrxint_3		; no.
	mov	di,recv_buf		; yes - wrap around.

asyrxint_3:
	cmp	raw_mode,0		;raw mode?
	jne	asyrxint_raw
	cmp	al,FR_END		; might	this be	the end of a frame?
	jne	asyrxint_reset		; no - reset flag and loop
asyrxint_raw:
	inc	si                      ; yes - indicate packet ready
	cmp	si, 1                   ; determine if semaphore is <> 1
	jne	asyrxint_chk_flg        ; yes - recv_frame must be active
	inc	recv_pkt_ready          ; no - set flag to start recv_frame

asyrxint_chk_flg:
	cmp	bp, 0                   ; was this the first char?
	jne	asyrxint_1              ; no - exit handler
asyrxint_reset:
	inc	bp			; set 1st character flag
	jmp	asyrxint_again		; get another character

asyrxint_exit:
asyrxint_1:
	mov	recv_buf_tail,di
	mov	packet_sem, si

	ret


; --------------------------------------------------------------
;
;  recv_exiting
;
recv_exiting:
	assume	ds:nothing
	pushf
	cmp	recv_pkt_ready, 1       ; is a packet ready?
	jne	recv_isr_exit           ; no - skip to end
	push	ax
	push	bx
	push	cx
	push	dx
	push	ds
	push	es
	push	bp
	push	di
	push	si
	movseg	ds,cs
	assume	ds:code
	mov	recv_pkt_ready,	0	; reset flag
	sti				; enable interrupts

	call	recv_frame

	pop	si
	pop	di
	pop	bp
	pop	es
	pop	ds
	pop	dx
	pop	cx
	pop	bx
	pop	ax
recv_isr_exit:
	jmp	recv_exiting_exit


; --------------------------------------------------------------
;
;  recv_frame
;
; mod 7/25/89 John Grover
;
; - recv_frame now operates with interrupts on. It is triggered
; - by the recv_pkt_ready flag and continues until all bytes
; - in all packets in the buffer have been transmitted to the upper
; - layer.
;
recv_frame_end:
	dec	packet_sem
	cmp	packet_sem, 0		; are there more packets ready?
	jnz	recv_frame              ; yes - execute again
	ret

  ifdef debug
	public recv_frame
  endif
recv_frame:
	cmp	packet_sem, 0		; should we do this?
	jz	recv_frame_end		; no - exit
	mov	si,recv_buf_head	;process characters.
	xor	cx,cx			;count up the size here.
	cmp	raw_mode,0		;raw mode?
	je	recv_frame_1		;no, interpret escapes, etc.
	cmp	si,recv_buf_tail	;any more characters?
	je	recv_frame_end
recv_frame_raw_1:
	inc	cx			;count a character.
	call	recv_char
	cmp	si,recv_buf_tail
	jne	recv_frame_raw_1
	jmp	short recv_frame_2	;we have the count here.
recv_frame_1:

	call	recv_char		;get a char.
	je	recv_frame_2		;go if no more chars.
	cmp	al,FR_ESC		;an escape?
	je	recv_frame_1		;yes - don't count this char.
recv_frame_7:
	inc	cx			;no - count this one.
	jmp	recv_frame_1
recv_frame_2:

	jcxz	recv_frame_3		;count zero? yes - free the frame
  if	ETHERSLIP
;
; Add Ethernet header.  As well, ensure that minimum packet size is 60
; bytes; some application packages actually check for minimum packet size.
;
	cmp	raw_mode,0		;in raw mode, we don't fake Ethernet.
	jne	recv_next
	add	cx,14 
	cmp	cx, 60
	jge 	recv_next
	mov	cx, 60	
;
recv_next:
  else
; we don't need to set the type because none are defined for SLIP.
  endif
	push	cx			;save the count.
	push	si			;save si in case we reject it.
	push	bx
  if	ETHERSLIP
	movseg	es,cs
	mov	di,offset ip_type
  else
	MOV	DI,CS
	MOV	ES,DI
	mov	di,0
  endif
	mov	dl,cs:driver_class
	call	recv_find		;look up our type.
	pop	bx
	pop	si
	pop	cx

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_frame_3		;yes - just free the frame.

	push	cx
	push	es			;remember where the buffer pointer is
	push	di
  if	ETHERSLIP
;
; Fix up the Ethernet header added to the incoming packet.
;
	call	fix_header
  endif

	mov	si,recv_buf_head	;process characters.
	cmp	raw_mode,0		;raw mode?
	je	recv_frame_4		;no, interpret characters.
recv_frame_raw_2:
	call	recv_char		;get a character.
	stosb				;store it.
	loop	recv_frame_raw_2	;get another.
	jmp	short recv_frame_6	;all done.
recv_frame_4:
	call	recv_char
	je	recv_frame_6		;yes - we're all done.
	cmp	al,FR_ESC		;an escape?
	jne	recv_frame_5		;no - just store it.

	call	recv_char		;get the next character.
	je	recv_frame_6
	cmp	al,T_FR_ESC
	mov	al,FR_ESC		;assume T_FR_ESC
	je	recv_frame_5		;yup, that's it	- store FR_ESC
	mov	al,FR_END		;nope, store FR_END
recv_frame_5:
	stosb				;store the byte.
	jmp	recv_frame_4
recv_frame_6:
	mov	recv_buf_head,si	;we're skipped to the end.

	pop	si			;now give the frame to the client.
	pop	ds
	pop	cx
	assume	ds:nothing

	call	recv_copy
	movseg	ds,cs
	assume	ds:code
	jmp	recv_frame_end

recv_frame_3:
	mov	recv_buf_head,si	;remember the new starting point.
	jmp	recv_frame_end


; --------------------------------------------------------------
;
;  recv_char
;
; mod 7/25/89 John Grover
; - Now	uses buffer pointers to determine if there are
; - characters left.
;

recv_char:
;enter with si -> receive buffer, bx = receive count.  Wrap around if needed.
;return with nz, al = next char.  Return zr if there are no more chars in
;  this frame.
;
	lodsb
	cmp	si,recv_buf_end
	jb	recv_char_1
	mov	si,recv_buf
recv_char_1:
	cmp	si, recv_buf_tail
	je	recv_char_2
	cmp	al,FR_END
recv_char_2:
	ret
  if	ETHERSLIP
;
; Set destination and source addressess and packet type in an
; Ethernet header.
;
fix_header:
;
; Set destination address.
;
	mov	ax,0000h
	stosw
	mov	ax,0c3c4h
	stosw
	mov	ax,0c2cch
	stosw
;
; Set source address.
;
	mov	ax,0201h
	stosw
	mov	ax,0403h
	stosw
	mov	ax,0605h
	stosw
;
; Set packet type to IP.
;
	mov	ax, 0008h
	stosw	
	ret
  endif

;Set bit(s) in I/O port
setbit:
;enter with dx = port, ah = bit to set.
	in	al,dx
	or	al,ah
	out	dx,al
	ret


;Clear bit(s) in I/O port
clrbit:
;enter with dx = port, ah = bit to set.
	in	al,dx
	not	al			;perform an and-not using DeMorgan's.
	or	al,ah
	not	al
	out	dx,al
	ret


	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
	db	3000 dup(?)
end_free_mem	label	byte

	public	usage_msg
  if	ETHERSLIP
usage_msg	db	"usage: ETHERSLIP [options] <packet_int_no> [-h] [hardware_irq]",CR,LF
		db	"   [io_addr] [baud_rate]",CR,LF
		db	"   [send_buf_size] [recv_buf_size]",CR,LF
		db	"   -h enables hardware handshaking",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for ETHERSLIP, version ",'0'+(majver / 10),'0'+(majver mod 10),"."
		db	'0'+version,CR,LF
		db	"Portions Copyright 1988 Phil Karn",CR,LF,'$'
		db	"Portions Copyright 1991 Michael Martineau",CR,LF
		db	" 5 Nov 1991",cr,lf,'$'
  else
usage_msg	db	"usage: SLIP8250 [options] <packet_int_no> "
		db	"[-h] [driver_class] [hardware_irq]",CR,LF
		db	"   [io_addr] [baud_rate]",CR,LF
		db	"   [recv_buf_size]",CR,LF
		db	"   -h enables hardware handshaking",CR,LF
		db	"   The driver_class should be SLIP, KISS, AX.25,"
		db	" or a number.",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for SLIP8250, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1988 Phil Karn",CR,LF
		db	"Portions Copyright 1991 Joe Doupnik",CR,LF
                db      "Hardware flow-control mods by Philip R. Burns",CR,LF
		db	"Portions Copyright 1992 Crynwr Software",CR,LF,'$'
  endif

approximate_msg	db	"Warning: This baud rate can only be approximated"
		db	"using the 8250",CR,LF
		db	"because it is not an even divisor of 115200"
		db	CR,LF,'$'

is_16550_msg    db      "16550 Uart detected, FIFO will be used",CR,LF,'$'

no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in SLIP8250.ASM",CR,LF,'$'

class_name_ptr	dw	?
class_name	db	"Interface class ",'$'
  if ETHERSLIP
  else
kiss_name	db	"KISS",CR,LF,'$'
ax25_name	db	"AX.25",CR,LF,'$'
slip_name	db	"SLIP",CR,LF,'$'
  endif
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
baud_rate_name	db	"Baud rate ",'$'
recv_buf_name	db	"Receive buffer size ",'$'
unusual_com1	db	"That's unusual!  Com1 (0x3f8) usually uses IRQ 4!"
		db	CR,LF,'$'
unusual_com2	db	"That's unusual!  Com2 (0x2f8) usually uses IRQ 3!"
		db	CR,LF,'$'

	extrn	set_recv_isr: near
	extrn	maskint: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

;enter with si -> argument string.
;skip spaces and tabs.  Exit with si -> first non-blank char.
	extrn	skip_blanks: near


;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	jne	not_switch
	cmp	byte ptr [si+1],'h'	;did they specify '-h'?
	je	got_hardware_switch
	stc				;no, must be an error.
	ret
got_hardware_switch:
	mov	hardware_switch,1
	add	si,2			;skip past the switch's characters.
	jmp	parse_args		;go parse more arguments.
not_switch:
  if ETHERSLIP
  else
	or	al,20h			; to lower case (assuming letter)
	cmp	al,'k'
	jne	parse_args_2
	mov	driver_class,10		;KISS, from packet spec
	mov	dx,offset kiss_name
	jmp	short parse_args_1
parse_args_2:
	cmp	al,'s'
	jne	parse_args_3
	mov	driver_class,6		;SLIP, from packet spec
	mov	dx,offset slip_name
	jmp	short parse_args_1
parse_args_3:
	cmp	al,'a'
	jne	parse_args_4
	mov	driver_class,9		;AX.25, from packet spec.
	mov	dx,offset ax25_name
	jmp	short parse_args_1
parse_args_4:
	mov	di,offset driver_class
	mov	bx,offset class_name
	call	get_number
	mov	class_name_ptr,0
	jmp	short parse_args_6
parse_args_1:
	mov	class_name_ptr,dx
parse_args_5:
	mov	al,[si]			;skip to the next blank or CR.
	cmp	al,' '
	je	parse_args_6
	cmp	al,CR
	je	parse_args_6
	inc	si			;skip the character.
	jmp	parse_args_5
parse_args_6:
  endif
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	mov	di,offset baud_rate
	call	get_number
	mov	di,offset recv_buf_size
	call	get_number
	clc
	ret


; --------------------------------------------------------------
;
;  etopen
;
; mod 7/25/89 John Grover
; - Contains a loop to determine a pseudo timeout for asyrxint.
; - The value is determined by transmitting characters in a
; - loop whose clock cycles are nearly the same as the "sister"
; - loop in asyrxint. The per character, maximum time used
; - basis which is then multiplied by a factor to achieve a timeout
; - value for the particular bps and CPU speed of the host.

	public	etopen
etopen:
	mov	al,int_no
	call	maskint			;disable these interrupts.

  if ETHERSLIP
;
; Pseudo-Ethernet address to return when get_address() is called.
;
	mov	word ptr rom_address[0],2*256+0	;locally assigned
	mov	word ptr rom_address[2],0*256+12h
	mov	word ptr rom_address[4],34h*256+56h
  endif

;
; mod  3/16/90  Denis DeLaRoca
; - determine if 16550 uart is present
; - if so initialize fifo buffering
;
	loadport
	setport	FCR
	mov	al,FIFO_ENABLE
	out	dx,al                   ;outportb(base+FCR,(char) FIFO_ENABLE)
	setport	IIR
	in	al,dx                   ;inportb(base+IIR)
	and	al,IIR_FIFO_ENABLED     ;     & IIR_FIFO_ENABLED
	cmp	al,IIR_FIFO_ENABLED	;both bits must be on   NEW, 11/20/90
	jnz	not_16550               ;nope, we don't have 16550 chip
	mov	is_16550,1              ;yes, note fact
	mov	al,FIFO_SETUP           ;and setup FIFO
	setport	FCR
	out	dx,al                   ;outportb(base+FCR,(char) FIFO_SETUP)

	mov	dx,offset is_16550_msg
	mov	ah,9
	int	21h			;let user know about 16550

not_16550:
	loadport			;Purge the receive data buffer
	setport	RBR
	in	al,dx

	;Set line control register: 8 bits, no parity
	mov	al,LCR_8BITS
	setport	LCR
	out	dx,al

	;Turn on receive interrupt enable in 8250, leave transmit
	; and modem status interrupts turned off for now
	mov	al,IER_DAV
	setport	IER
	out	dx,al

	;Set modem control register: assert DTR, RTS, turn on 8250
	; master interrupt enable (connected to OUT2)

	mov	al,MCR_DTR or MCR_RTS or MCR_OUT2
	setport	MCR
	out	dx,al

;compute the divisor given the baud rate.
	mov	dx,baudclk+2
	mov	ax,baudclk
	mov	bx,0
asy_speed_1:
	inc	bx
	sub	ax,baud_rate
	sbb	dx,baud_rate+2
	jnc	asy_speed_1
	dec	bx
	add	ax,baud_rate
	adc	dx,baud_rate+2
	or	ax,dx
	je	asy_speed_2

	mov	dx,offset approximate_msg
	mov	ah,9
	int	21h

asy_speed_2:

	loadport			;Purge the receive data buffer
	setport	RBR
	in	al,dx

	mov	ah,LCR_DLAB		;Turn on divisor latch access bit
	setport	LCR
	call	setbit

	mov	al,bl			;Load the two bytes of the divisor.
	setport	DLL
	out	dx,al
	mov	al,bh
	setport	DLM
	out	dx,al

	mov	ah,LCR_DLAB		;Turn off divisor latch access bit
	setport	LCR
	call	clrbit

;set up the various pointers.

	mov	dx,recv_buf_size
	call	malloc
	jnc	have_memory
	mov	dx,offset no_memory_msg
	stc
	ret
have_memory:
	mov	recv_buf,dx
	mov	recv_buf_head,dx
	mov	recv_buf_tail,dx
	add	dx,recv_buf_size
	mov	recv_buf_end,dx

	; the following code attempts to determine a pseudo timeout
	; value	to use in the loop that waits for an incoming character
	; in asyrxint. The value returned in xmit_time is the number of
	; loops processed between characters - therefore the loop used below
	; is and should	remain similar to the loop used in asyrxint.

	xor	ax, ax			; we'll send a 0
	mov	ah, LSR_THRE
	mov	cx, 10h			; take the highest of 16 runs
	xor	si, si			; will hold highest value

xmit_time_start:

	xor	di, di			; initialize counter
	loadport
	setport	THR			; xmit a character
	out	dx, al
	setport	LSR		       ; set up	to check for an empty buffer

	; next is the loop actually being timed

xmit_time_top:
	in	al, dx
	test	al, ah
	jnz	xmit_time_done
	inc	di
	cmp	cx, cx			; these next few instructions do nothing
	jmp	xmit_time_1		;  except maintain similarity with the
					;  "sister" loop in asyrxint
xmit_time_1:
	jmp	xmit_time_top

xmit_time_done:				; end of timed loop



	cmp	si, di			; compare highest value with new value
	ja	xmit_time_end		; no bigger - just loop
	mov	si, di			; bigger - save it

xmit_time_end:
	loop	xmit_time_start		; bottom of outer loop

	shl	si, 1			; we'll wait 8 characters worth
	shl	si, 1
	shl	si, 1
	mov	xmit_time, si		; retain largest value

	; end of pseudo timer determination

	call	set_recv_isr		;Set interrupt vector to SIO handler

	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	clc				;indicate no errors.
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	cmp	class_name_ptr,0
	je	echo_args_1

	mov	dx,offset class_name
	mov	ah,9
	int	21h
	mov	dx,class_name_ptr
	mov	ah,9
	int	21h
	jmp	short echo_args_2
echo_args_1:
	mov	di,offset driver_class
	mov	dx,offset class_name
	call	print_number
echo_args_2:

	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number

	cmp	io_addr,03f8h		;is this com1?
	jne	ia_com2
	mov	dx,offset unusual_com1
	cmp	int_no,4		;com1 usually uses IRQ 4.
	jne	ia_unusual
	jmp	short ia_usual
ia_com2:
	cmp	io_addr,02f8h		;is this com2?
	jne	ia_usual		;no.
	mov	dx,offset unusual_com2
	cmp	int_no,3		;com2 usually uses IRQ 3.
	je	ia_usual
ia_unusual:
	mov	ah,9
	int	21h
ia_usual:
	mov	di,offset baud_rate
	mov	dx,offset baud_rate_name
	call	print_number
	mov	di,offset recv_buf_size
	mov	dx,offset recv_buf_name
	call	print_number
	ret
code	ends
	end

