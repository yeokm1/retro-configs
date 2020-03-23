;History:180,18
;Sun Jan 05 22:13:57 1992 increased RST_IVAL from 4 to 7.
;Tue Feb 27 10:56:15 1990 send_pkt wasn't timing out properly.
version	equ	1

	include	defs.asm

;Ported from Philip Prindeville's arcnet driver for PCIP
;by Russell Nelson.  Any bugs are due to Russell Nelson.

;Ported from Philip Prindevilles's and Russell Nelson's ARCNET
;driver to RFC1201 and class Ethernet by Martin Wilmes (Q91@DHDURZ1.BITNET).
;So any bugs are now due to Martin Wilmes.

;  Parts Copyright, 1988-1992, Russell Nelson, Crynwr Software
;  Copyright 1991 Martin Wilmes

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

;Registers:

;the following I/O addresses are mapped to the COM 9026
IMASK		equ	0		; writeable
STATUS		equ	0		; readable
COMMAND		equ	1
;the following I/O addresses are mapped to the 8253 counter/timer
CNTR0		equ	4
CNTR1		equ	5
CNTR2		equ	6
MODE		equ	7
;reading the following I/O addresse performs a software reset.
SW_RST		equ	8

; time needed to do various things (in clock ticks)
RST_IVAL	equ	7		;reset
SEND_IVAL	equ	4		;send
ACK_IVAL        equ     4               ;acknowledge

; Maximum number of replays of an unacknowledged packet
SEND_REPLAY     equ     5               ;times a packet should be replayed
                                        ;when we get no acknowledge, not
                                        ;yet used

; ARP type for ARCnet
ARP_ARC		equ	001h           ; We are ARCnet but show up as EtherNet

; broadcast address is nid 0
ARC_BCAST	equ	0              ;ARCnet Broadcast address

; packet sizes
ARC_MTU		equ	249            ;These are the length of client data!
ARC_MnTU	equ	252            ;
ARC_XMTU	equ	504            ;
;
;status/interrupt mask bit fields
;
ST_TA		equ	001h		; transmitter available
ST_TMA		equ	002h		; transmitted msg. ackd
ST_RECON	equ	004h		; system reconfigured
ST_TEST		equ	008h		; test flag
ST_POR		equ	010h		; power-on-reset
ST_ETS1		equ	020h		; unused
ST_ETS2		equ	040h		; unused
ST_RI		equ	080h		; receiver inhibited

;
;in the command register, the following bits have these meanings:
;		0-2	command
;		3-4	page number (enable rvc/xmt)
;		 7	rcv b'casts


DSBL_XMT	equ	001h		; disable transmitter
DSBL_RCV	equ	002h		; disable receiver
ENBL_XMT	equ	003h		; enable transmitter
ENBL_RCV	equ	004h		; enable receiver
DFN_CONF	equ	005h		; define configuration
CLR_FLGS	equ	006h		; clear flags
LD_TST_FLG	equ	007h		; load test flags

; flags for clear flags operation

FL_POR		equ	008h		; power-on-reset
FL_RECON	equ	010h		; system reconfigured

; flags for load test flags operation

FL_TST		equ	008h		; test flag (diagnostic)

; byte deposited into first address of buffers when POR
TSTWRD		equ	0321Q

; handy macros for enable receiver/transmitter

BCAST		equ	080h		; receiver only

; flags for define configuration

CONF_NORM	equ	000h		; 1-249 byte packets
CONF_XTND	equ	008h		; 250-504 byte packets


         public    no_confident
NO_CONFIDENT    db      1

; designations for receiver/transmitter buffers.  sorry, no cleverness here
RCVPAGE		equ	0
XMTPAGE		equ	3

; Flag which indicates that we should build and expect 802.3 framed Novell
; IPX packets from the IPX-Shell, set to N_OPTION in this case
OPTION_8023     db      0

; Maximum number of fragments we can store in our receive-buffer
MAX_FRAGMENTS   equ     3

; Data for sending splitted packets

send_did        db      0                   ;Destination ID
send_sid        db      0                   ;Source ID
Stored_CX       dw      0                   ;Rest of packet not send yet
Protocol_ID     db      0                   ;The ARCnet protocol ID
Split_Number    db      0                   ;Number of fragments we have to send
Pkt_Number      db      0                   ;Number of the current packet
Sequence_Number dw      0                   ;Sequence number, start with zero
send_times      db      0                   ;times a packet has been replayed

; Data for receiving splitted packets

last_expected      db      0feh             ;Splitflag of last Packet in a
                                            ;sequence - 1
expected_packet    db      0                ;Used to test a sequence
expected_sequence  dw      0
recv_protocol      dw      0                ;Ethernet protocol
recv_num_frags     db      0                ;Number of fragments we received
recv_protocolbyte  db      0                ;ARCnet protocol
recv_offset        dw      0
recv_packet        dw      0
last_length        dw      0

; We store all but the last fragments of incomplete sequences in our own
; buffer. This is not necessary since the ARCnet card has 4 pages and we
; should receive a maximum of 3 fragments in a sequence. Using our own
; buffer has two advantages: Our driver becomes faster because it uses
; idle times when the packet not complete to test the sequence and
; reassemble the client data and our own buffer makes it easier to
; change the driver to receive more than 3 fragments if required.
recv_buffer        db      (MAX_FRAGMENTS-1)*504 dup (0feh)

	public	int_no
int_no		db	5,0,0,0		; interrupt number.
io_addr		dw	02e0h,0		; I/O address for card (jumpers)
mem_base	dw	0d800h,0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	1,0,0           ;We show as Ethernet driver, class 1.
                                        ;when the OPTION_8023 flag is set, we
                                        ;don not refuse calls for a class 11
                                        ;driver since the PDIPX-shell asks for
                                        ;a class 11 driver
driver_type	db	14       	;Datapoint RIM (from the packet spec)
driver_name	db	'ARCEther',0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	6	;length of MAC-layer address
	dw	1514	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

	public	rcv_modes
rcv_modes	dw	4		;number of receive modes in our table.
		dw	0,0,0,rcv_mode_3

	include	popf.asm
	include	movemem.asm

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
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

        push    ds
        push    si
        push    cx

        mov     send_did,0		;Assume that destination is broadcast
        mov     cx,3
        mov     ax,ds:[si+4]
        cmp     ax,0ffffh		;A first fast check for non-Broadcast
        jne     send_non_broadcast
send_adress_loop:
        lodsw
        cmp     ax,0ffffh
        jne     send_after_loop
        loop    send_adress_loop
        jmp     nr_3			;destination is indeed broadcast

send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret

send_after_loop:
        dec     cx                      ;read the rest of the ethernet adress
        rep     lodsw
send_non_broadcast:
        mov     cs:send_did,ah          ;arcnet address is highest byte of
                                        ;the ethernet address
nr_3:
        pop     cx
        pop     di
        pop     es                     ;We change ds:si to to es:di because we
                                       ;we want to access our own data more easily.
        mov     ax,cs
        mov     ds,ax
        assume  ds:code

        mov     al,es:[di+11]		;source ID
        mov     send_sid,ah
        mov     ax,es:[di+12]		;Ethernet Protocol
        cmp     ax,0008h		;IP Packet
        jne     nr_5
        mov     protocol_ID,212		;IP on ARCnet
        jmp     nr_10
nr_5:
        cmp     ax,0608h		;ARP packet
        jne     nr_6
        mov     protocol_ID,213		;ARP on ARCnet
        mov     cx,18+14		;18Bytes is ARP and RARP on Arcnet
					;14 Byte for EtherNet Header and Protocol
					;which we forget later
        jmp     nr_10
nr_6:
        cmp     ax,3580h		;RARP packet
        jne     nr_7
        mov     protocol_ID,214		;RARP on ARCnet
        mov     cx,18+14
        jmp     nr_10
nr_7:
        test    OPTION_8023,N_OPTION	;do we expect 802.3 packets?
        jnz     nr_7a
        cmp     ax,3781h		;No: check for Bluebox IPX protocol
        jne     nr_8
        mov     protocol_id,250		;IPX on ARCnet
        jmp     nr_10
nr_7a:
        mov     ax,es:[di+14]		;Every IPX packet begins with ffff.
        cmp     ax,0ffffh		;so we check the begin of the client
					;data for this signature
        jne     nr_8
        mov     protocol_ID,250
        jmp     nr_10

nr_8:
        mov     ax,es:[di+12]		;Ethernet Protocol
        cmp     ax,0CAACh		;LANSoft
        jne     nr_5
        mov     protocol_ID,251		;LANSoft on ARCnet
        jmp     nr_10
nr_error:				;We do not now this protocol and
        assume  ds:nothing		;cannot send
        mov     dh,CANT_SEND
        stc
        ret

nr_10:
        sub     cx,14			;Forget EtherNet-Header
        add     di,14
        inc     sequence_number
					;
					;Look if we can send it as one packet or have to split the packet
					;
        xor     al,al
        mov     Split_Number,0		;Number of splits is zero in case of one packet
        mov     pkt_number,0		;Fragment number is zero for the first packet
	cmp	cx,ARC_XMTU		;length of client data longer than long frame?
	jbe	new_send		;no, we can send it as one packet
        mov     split_number,1		;division takes so long, so we just
        cmp     cx,1008			;compare
        jbe     new_send
        mov     split_number,3
					;
;Wait for transmitter ready.
        ;
New_send:
        push    es			;save current position of paket
        push    di
New_send_2:
	loadport
	setport	STATUS

	mov	ax,SEND_IVAL		;only wait this long for it.
	call	set_timeout		;otherwise we can't send.
send_pkt_3:
	in	al,dx			;if not busy, exit.
	and	al,ST_TA
	jne	send_pkt_2
	call	do_timeout		;did we time out yet?
	jne	send_pkt_3		;no, not yet.

        loadport
	setport	COMMAND			;stop the transmit.
	mov	al,DSBL_XMT
	out	dx,al
	mov	dh,CANT_SEND		;timed out, can't send.
        pop     si
        pop     ds
        assume  ds:nothing
        stc
	ret

send_pkt_2:
;store the packet on the board.
	mov	es,mem_base
	mov	di,XMTPAGE * 512

        mov     al,send_sid
        mov     ah,send_did
	stosw				;move the SID and DID to the board.
        mov     Stored_CX,cx            ;remeber the packet length

        cmp     cx,ARC_MTU              ;Decide which frame we use
        jbe     Send_normal_1           ;normal frame
        cmp     cx,ARC_MNTU
        jbe     send_pkt_5a             ;exceptional frame
        ;                               ;build header for long frame
        xor    ax,ax
        cmp    cx,ARC_XMTU              ;length less than long Frame ?
        jbe    send_Long_1              ;yes, send it
        mov    cx,ARC_XMTU              ;No: send 504 bytes
send_Long_1:
        mov    ax,508                   ;number of bytes - 4 Byte header
        sub    ax,cx                    ;Offset is 508 - clientData
        mov    ah,al                    ;length in ah for stosw and long frame
        xor    al,al                    ;al=0 indicates non-normal frame
        stosw                           ;
        mov     al,ah                   ;Move offset to back to al
        xor     ah,ah                   ;
        sub     al,4                    ; -4 Byte for long frame
        add     di,ax                   ;jump over unused bytes
        jmp     send_splits
send_pkt_5a:                            ; build header for exceptional frame
        ;
        mov     ax,504                  ;Octet-Zahl - 8 Byte (long frame - 4 padding bytes)
        sub     ax,cx                   ;Offset is 504 - clientData
        mov     ah,al                   ;
        xor     al,al                   ;
        stosw                           ;
        mov     al,ah                   ;
        xor     ah,ah                   ;
        sub     al,4                    ;
        add     di,ax                   ;
        mov     al,Protocol_ID          ;First padding byte
        mov     ah,0ffh                 ;indicates exceptional frame
        stosw                           ;
        mov     ax,0ffffh               ;Another two padding bytes
        stosw                           ;
        jmp     send_splits

        ;                               header for normal frame
send_normal_1:
        mov     ax,252                  ;
        sub     ax,cx                   ;Offset is 252 - clientData
        xor     ah,ah
        stosb                           ;store offset
        sub     al,3                    ;
        add     di,ax                   ;jump over unused bytes

Send_Splits:
        mov    al,Protocol_ID
        xor    ah,ah                    ;We hope it was only one packet
        cmp    Split_number,0
        je     Send_Transmit_split      ;Ok, it was only one
        cmp    Pkt_number,0             ;A sequence: is it the first fragment
        jne    Send_Splits_2            ;
        mov    ah,Split_Number          ;yes: Splitflag is (T-2)*2+1
        jmp    send_Transmit_split      ;and send it
Send_Splits_2:
        mov    ah,Pkt_number            ;

Send_Transmit_split:
        stosw                           ;
        mov    ax,Sequence_Number       ;
        stosw
        cmp    protocol_ID,213          ;ARP and RARP packets differ between
        je     send_arp                 ;ARCnet and Ethernet, because the hardware
        cmp    protocol_ID,214          ;type is 7 for ARCnet and 1 for Ethernet and
        je     send_ARP                 ;address length are 1 for ARCnet and 6 for Ethernet
        cld
        pop    si                       ;its and IP or IPX packet: just send it
        pop    ds                       ;ds:si for movsw
        assume ds:nothing
        push   cx
        call   movemem                  ;und nun noch cx bytes clientdata bertragen   ****
        pop    cx
        push   ds                       ;the next fragment
        push   si
        mov    ax,cs
        mov    ds,ax
        assume ds:code
        jmp    send_transmit
Send_ARP:
        pop    si
        pop    ds
        assume ds:nothing
        mov    ax,0700h                 ;HardwareType ARCnet
        stosw
        mov    ax,0008h                 ;Protocol is IP
        stosw
        mov    ax,0401h                 ;Hardware and IP-Length
        stosw
        add    si,6
        movsw                           ;move opcode
        add    si,5
        movsb                           ;sender hardware adress
        movsw                           ;sender IP Adress
        movsw
        push   cx
        mov    cx,3
Send_ARP_loop:                          ;check ARP destination for broadcast
        lodsw
        cmp    ax,0ffffh
        je     Send_ARP_1
        loop   Send_ARP_loop
        xor    al,al
        jmp    Send_ARP_2
send_ARP_1:
        dec    cx
        rep    lodsw
        mov    al,ah
send_ARP_2:
        stosb

        movsw                   ;destination IP address
        movsw
        pop    cx               ;cx was on the stack
        push   ds
        push   si
        mov    ax,cs
        mov    ds,ax
        assume ds:code
send_transmit:                  ;now send the packet

	mov	al,ENBL_XMT or (XMTPAGE shl 3)
	loadport
	setport	COMMAND
	out	dx,al
        mov     al,pkt_number
        cmp     al,split_number                   ;was it the last fragment
        jae     send_ende                         ;yes: sending is done
        add     pkt_number,2
        mov     cx,Stored_CX
        sub     cx,ARC_XMTU                       ;No: we did send a long packet
        jmp     New_Send_2
send_ende:
        pop     si
        pop     ds
        assume  ds:nothing
	clc
	ret


;Set address on controller
	public	set_address
set_address:
	assume	ds:nothing
;enter with ds:si -> address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
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
	assume	ds:code
	loadport
	setport	IMASK
	mov	al,0
	out	dx,al

        loadport
	setport COMMAND
	mov	al,DSBL_RCV
	out	dx,al
	mov	al,DSBL_XMT
	out	dx,al

        loadport
	setport	STATUS			;do we need to do this [rnn]?
	in	al,dx

	ret


	public	reset_interface
reset_interface:
;reset the interface.
;we don't do anything.
	ret


	include	timeout.asm

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
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code

recv_1:
        loadport			;get the status to see if we got
	setport	STATUS			;a false alarm.
	in	al,dx
        test	al,ST_RI
        jnz     recv_1a                 ;its a packet, don't exit
        ret
recv_1a:
        mov     es,mem_base             ;access the card via es:bx
	mov	bx,RCVPAGE * 512

;get packet length and splitflag
        mov     ax,es:[bx+2]            ;look for offset
        mov     cx,252                  ;-4 for client data
        cmp     al,0                    ;test for non-normal frame
        jne     short recv_my_1
        mov     cx,508
        mov     al,ah
recv_my_1:
        xor     ah,ah
        add     bx,ax                 ;jump to packet
        sub     cx,ax
        mov     ax,es:[bx]
        cmp     ah,0ffh               ;test for exceptional frame
        jne     short recv_my_2
        add     bx,4
        sub     cx,4
        mov     ax,es:[bx]            ;get the real splitflag
recv_my_2:
        test    ah,1
        jz      recv_more             ;with the first fragment of a packet we
                                      ;must be very fast because Novell
                                      ;transmits fast, so we don't jump
        cmp     ah,(MAX_FRAGMENTS - 2)*2+1
        ja      recv_reset
recv_new:
        mov     last_expected,ah      ;in a new sequence the splitflag is
                                      ;last splitflag -1 or zero for one packet
        mov     recv_protocolbyte,al  ;protocol for tests
        mov     di,es:[bx+2]
        mov     expected_sequence,di
        mov     recv_offset,offset recv_buffer
        xor     ah,ah                 ;zero it because otherwise we would
                                      ;think the sequence is complete with the
                                      ;first packet
recv_my_5:
        cmp    ah,last_expected       ;was it the last fragment?
        jae    recv_to_application    ;Never store the last fragment
        push   ax
        mov    ds,mem_base            ;move packet to the buffer
        assume ds:nothing
        mov    si,bx
        add    si,4
        mov    bx,cs
        mov    es,bx
        mov    di,cs:recv_offset

        cld
        call   movemem
        mov    ax,cs
        mov    ds,ax
        assume ds:code
        pop    ax
        mov    recv_offset,di
        mov    expected_packet,ah
        add    expected_packet,2        ;the next packet to expect
recv_isr_9:

	loadport			;enable reception again.
	setport	COMMAND
	mov	al,ENBL_RCV or (RCVPAGE shl 3) or BCAST
	out	dx,al

	jmp	recv_1
recv_reset:
        mov     last_expected,0feh      ;If a in-sequenve packet tests not ok
        jmp     recv_isr_9

recv_more:
        cmp     ah,0
        je      recv_new                 ;splitflag zero is a new packet
        cmp     last_expected,0feh       ;Are we in a sequence?
        je      recv_isr_9               ;No
        cmp     ah,expected_packet       ;Test splitflag,protocolbyte and sequence number
        jb      recv_isr_9               ;Its a replayed (or wrong) packet
        ja      recv_reset               ;Packet out of order
        cmp     recv_protocolbyte,al
        jne     recv_reset
        mov     di,es:[bx+2]
        cmp     di,expected_sequence
        jne     recv_reset
        cmp     ah,(MAX_FRAGMENTS - 1)*2    ;we can only store MAX_FRAGMENT
        jbe     recv_My_5
        jmp     recv_reset

recv_to_application:                          ;we gathered the whole sequence
                                              ;and have now (hopefully) enough
                                              ;time to build the EtherNet Packet
        add     bx,4
        mov     recv_packet,bx                ;offset of client data for the last fragment
        mov     last_length,cx                ;length of client data of the last fragment
        mov     ax,ds
        mov     es,ax
        mov     cx,recv_offset
        sub     cx,offset recv_buffer         ;length of reassembled part

        mov     last_expected,0feh            ;the sequence is complete
        add     cx,14                         ;for the EtherNet-Header
        add     cx,last_length                ;and the last fragment

        mov     al,recv_protocolbyte
        mov     dl,driver_class
        cmp     al,250                  ;is it IPX
        jne     recv_new_4              ;No
        mov     recv_protocol,3781h
        test    OPTION_8023,N_OPTION    ;Is 802.3-Option set ?
        jz      recv_new_10             ;No, proceed as normal
        mov     dl,11                   ;Yes, now we are driver class 11
        mov     recv_protocol,0ffffh    ;and use novell protocol ffffh
        jmp     recv_new_10

recv_isr_9a:
        jmp     recv_isr_9

recv_new_4:
        cmp     al,212
        jne     recv_new_5
        mov     recv_protocol,0008h     ;IP packet
        jmp     recv_new_10
recv_new_5:
        cmp     al,213
        jne     recv_new_6
        mov     recv_protocol,0608h     ;ARP Packet
        mov     cx,42
        jmp     recv_new_10
recv_new_6:
        cmp     al,214
        jne     recv_new_7
        mov     recv_protocol,3580h     ;RARP Packet
        mov     cx,42
        jmp     recv_new_10

recv_new_7:
	cmp	al,251
	jne	recv_new_8
        mov     recv_protocol,0CAACh     ;LANSoft
        jmp     recv_new_10

recv_new_8:
        ;mov     ah,al
        ;mov     recv_protocol,ax        ;We dont know the frame and
                                         ;double te protocol ID for inspection of
                                         ;these packets by a watch client
        jmp      recv_isr_9              ;to be comaptible with other drivers,
                                         ;we just free the frame
recv_new_10:
        push    cx
        mov     ax,ds
        mov     es,ax
        mov     di,offset recv_protocol
        call    recv_find                ;find a client who wants this packet
        pop     cx

        mov     ax,es                        ;is this pointer null?
        or      ax,di

        je      recv_isr_9a                  ;Yes, forget the packet

        push    cx                           ;remember length and buffer address
        push    es
        push    di

        mov     si,RCVPAGE*512               ;sid and did of the last fragment
        mov     ds,mem_base
        assume  ds:nothing
        lodsw
        push    cx
        push    ax
        mov     bx,cs
        mov     ds,bx
        assume  ds:code

        cmp     ah,0                            ;receiving broadcast
        jne     recv_directed
        mov     cx,3
        mov     ax,0ffffh
        rep     stosw
        jmp     short recv_source
recv_directed:                                  ;directed packets
        xor     ax,ax
        mov     cx,2
        rep     stosw
        pop     ax
        push    ax
        xor     al,al
        stosw
recv_source:                                    ;source address
        xor     ax,ax
        mov     cx,2
        rep     stosw
        pop     ax
        mov     ah,al
        xor     al,al
        stosw
        mov     ax,recv_protocol                ;Ethernet protocol
        stosw

        mov     si,offset recv_buffer           ;with ARP and RARP its
        cmp     recv_protocol,0608h             ;its just the opposite as in
        je      recv_arp                        ;case of sending packets
        cmp     recv_protocol,3580h
        je      recv_arp
        pop     cx
        sub     cx,14
        sub     cx,last_length
        cld
        jcxz    recv_move_last
        call    movemem                        ;The first fragments
recv_move_last:
        mov     cx,last_length
        mov     si,recv_packet
        mov     ds,mem_base
        assume  ds:nothing
        cld
        call    movemem                        ;And the last fragment
        jmp     recv_copied
recv_arp:
        pop     cx
        mov     si,recv_packet
        mov     ds,mem_base
        assume  ds:nothing
        cld
        xor     al,al
        mov     ah,1
        stosw                         ;Put Hardware-Type EtherNet at ist place
        mov     ax,0008h
        stosw                         ;Protocol used is IP
        mov     ax,0406h              ;Length of Ethernet and IP-Adress
        stosw
                                      ;now we transfer ARCnet-Client-Data to Ethernet-Client-Data
        add     si,6
        movsw                         ;move opcode
        mov     cx,5
        xor     al,al                 ;Padd first five byte of source address with zero
        rep     stosb
        movsb                         ;Move ARCNet-Hardware Adress
        movsw                         ;Sender IP-Adress
        movsw
        lodsb                         ;now we check destination for Broadcast
        cmp     al,0
        je      recv_hw_bcast
        mov     ah,al                 ;directed ARP
        xor     al,al
        mov     cx,5
        rep     stosb
        mov     al,ah
        stosb
        jmp     recv_client_2
recv_hw_bcast:
        mov    ax,0ffffh              ;Target was Broadcast
        mov    cx,3
        rep    stosw
recv_client_2:
        movsw                         ;Target IP-Address
        movsw
recv_copied:
        cmp     cs:recv_protocol,0ffffh  ;Novell 802.3 packet ?
        jne     recv_copied_2

        pop     di                    ;Yes: put length in prot field
        push    di
	mov	ax,es:[di+16]   	; get len
	xchg	ah,al
	inc	ax			; make even (rounding up)
	and	al,0feh
	xchg	ah,al
	mov	es:[di+12],ax   	; save in prot field

recv_copied_2:

        pop     si
        pop     ds
        pop     cx
        assume  ds:nothing
        call    recv_copy               ;tell the client that we
        mov     ax,cs                   ;copied the packet
        mov     ds,ax
        assume  ds:code
        jmp     recv_isr_9

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
usage_msg	db	"usage: arcether [options] <packet_int_no> <hardware_irq> <io_addr> <mem_base>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for Novell ARCnet TCP/IP and IPX version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1988 Philip Prindeville",CR,LF
                db      "Copyright 1991 Martin Wilmes",CR,LF,'$'

no_arcnet_msg	db	"No ARCnet found at that address.",CR,LF,'$'
failed_test_msg	db	"Failed self test.",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
mem_base_name	db	"Memory address ",'$'

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near
        extrn   flagbyte

;=length of our address.
	extrn	address_len: word

;-> the assigned address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
        test    cs:flagbyte,N_OPTION            ;Check if -n Option was used
        jz      next_arg
        xor     cs:flagbyte,N_OPTION            ;if yes: clear this flag and
        or      OPTION_8023,N_OPTION            ;set our own flag, because
        mov     cs:[driver_class+1],11          ;standard N_OPTION does not
                                                ;work with a ARCnet-Driver
                                                ;and has another meaning for us
next_arg:
	mov	di,offset int_no
                                                
                                                
	call	get_number
	mov	di,offset io_addr
	call	get_number
	mov	di,offset mem_base
	call	get_number
	clc
	ret


no_arcnet_error:
	mov	dx,offset no_arcnet_msg
	stc
	ret
failed_test_error:
	mov	dx,offset failed_test_msg
error:
	stc
	ret


	public	etopen
etopen:
;reset the board via the I/O reset port, then wait for it to become sane again.

	mov	ax,mem_base		;test the memory first.
	mov	cx,2048
	call	memory_test
	jne	no_arcnet_error

	mov	es,mem_base

	loadport
	setport SW_RST
	in	al,dx

	mov	ax,RST_IVAL
	call	set_timeout
etopen_1:
	call	do_timeout
	jne	etopen_1

        loadport
	setport	STATUS
	in	al,dx

;since we've just reset:
;	reset the POR flag,
;	check the diagnostic byte in the buffer,
;	grab the node ID, and assign it to the host number.

	test	al,ST_POR
	je	etopen_2

        loadport
	setport	COMMAND
	mov	al,CLR_FLGS or FL_POR or FL_RECON
	out	dx,al

	mov	al,es:[0]
	cmp	byte ptr es:[0],TSTWRD
	je	etopen_3
	jmp	failed_test_error	;failed power on self-test.
etopen_3:
	mov	al,es:[1]
	mov	rom_address[5],al
	mov	address_len,ARCADDR_LEN
etopen_2:

;another simple diagnostic:
;	force test flag on in RIM,
;	check to see that it is set,
;	reset it.

	loadport
	setport	COMMAND
	mov	al,LD_TST_FLG or FL_TST
	out	dx,al

        loadport
	setport STATUS
	in	al,dx

	test	al,FL_TST
	jne	etopen_4
	jmp	failed_test_error	;failed forced self-test.
etopen_4:
        loadport
	setport	COMMAND
	mov	al,LD_TST_FLG
	out	dx,al
        loadport
	setport STATUS
	in	al,dx

	pushf
	cli

	call	set_recv_isr

;now we enable the board to interrupt
;us on packet received.  Not transmiter available
;(i.e. transmission complete).  We don't have
;any control over POR, since it is NMI...
;RECON seems useless.

	loadport
	setport	IMASK
	mov	al,ST_RI
	out	dx,al

	; we should allow extended packets
        loadport
	setport	COMMAND
	mov	al,DFN_CONF or CONF_XTND
	out	dx,al

	mov	al,ENBL_RCV or (RCVPAGE shl 3) or BCAST;
	out	dx,al

	popf

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

	public	print_parameters
print_parameters:
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	mov	di,offset mem_base
	mov	dx,offset mem_base_name
	call	print_number
	ret

	include	memtest.asm

code	ends

	end
