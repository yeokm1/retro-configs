version        equ     4

;******************************************************************************;
;*                                                                            *;
;*     File: tiara.asm                                                        *;
;*     Auth: Brian Fisher                                                     *;
;*           Queens University                                                *;
;*           Computing and Communications Services                            *;
;*           Rm 2-50 Dupuis Hall                                              *;
;*           Kingston Ontario                                                 *;
;*                                                                            *;
;*     Date: January 24 1990                                                  *;
;*                                                                            *;
;*     Purp: (3C501) Packet driver for tiara Ethernet Card.                   *;
;*                                                                            *;
;*============================================================================*;
;*     Revs: January 25 1990   V 1.6.0 Clean up code and document.            *;
;*           Feb     24 1991   V 1.8.2 Gets IRQ and I/O info from MCH POS regs*;
;*                                                                            *;
;*============================================================================*;
;*                                                                            *;
;*     Thanks, Mehdi Safipour, of tiara Computer Systems, who supplied the    *;
;*     programming manual and examples.                                       *;
;*                                                                            *;
;*============================================================================*;
;*                                                                            *;
;*     Logic -                                                                *;
;*                                                                            *;
;*     Initialization - classic, by-the-book initialization, with one         *;
;*     exception:  The manual didn't mention the fact that receive            *;
;*     interrupts will not always work unless the receive buffer is           *;
;*     vacuumed.                                                              *;
;*                                                                            *;
;*     Byte/Word I/O mode was determined by code ruthlessly copied from       *;
;*     NI5010.ASM, auth: Russ Nelson.                                         *;
;*                                                                            *;
;*     Transmit-no surprises, data goes whoosh!                               *;
;*                                                                            *;
;*     Receive-interrupt driven receive makes upcalls to inform the ULP of    *;
;*     its status.  The 16 byte ethernet header is copied from the card to    *;
;*     a temporary buffer, to determine the ether-type.  Recv_find is called  *;
;*     to acquire a buffer from the ULP.  If no buffer, the packet is dropped.*;
;*     If a buffer is acquired, the packet is copied into it, and recv_copy   *;
;*     informs the ULP that the data is there.                                *;
;*                                                                            *;
;******************************************************************************;
;

DLCR_XMIT_STAT EQU     0		;NICE I/O Register offsets
DLCR_RECV_STAT EQU     1
DLCR_XMIT_MASK EQU     2
DLCR_RECV_MASK EQU     3
DLCR_XMIT_MODE EQU     4
DLCR_RECV_MODE EQU     5
DLCR_CONFIG    EQU     6
DLCR_RBNK      EQU     7
DLCR_NODE_ID   EQU     8
DLCR_TDR_LOW   EQU     0eh
DLCR_TDR_HIGH  EQU     0FH
BMPR_MEM_PORT  EQU     8
BMPR_PKT_LEN   EQU     10
PROM_ID        EQU     18H
TMST           EQU     80h
TMT_OK         EQU     80h
BUF_EMPTY      EQU     40h
card_disable   equ     82h		; written to DLCR_CONFIG to disable card
card_enable    equ     02h		; written to DLCR_CONFIG to enable card
clear_status   equ     00000111B	; used to clear status info
;                      !!!!!!!!
;                      !!!!!!!+--------CLEAR BUS WRITE ERROR
;                      !!!!!!+---------CLEAR 16 COLLISION
;                      !!!!!+----------CLEAR COLLISION
;                      !!!!+-----------RES
;                      !!!+------------NC
;                      !!+-------------NC
;                      !+--------------NC
;                      +---------------NC
;
no_tx_irqs      equ     0              ; written to clear transmit IRQs
clr_rcv_status  equ     0CFh           ; clears receive status
en_rcv_irqs     equ     10000000B      ; enable receive interrupts
;
;                      !!!!!!!!--------
;                      !!!!!!!+--------ENABLE OVERFLOW
;                      !!!!!!+---------ENABLE CRC
;                      !!!!!+----------ENABLE ALIGN
;                      !!!!+-----------ENABLE SHORT PKT
;                      !!!+------------DISABLE REMOTE RESET
;                      !!+-------------RESERVED
;                      !+--------------RESERVED
;                      +---------------ENABLE PKT READY
;
xmit_mode       equ     00000010B
;                       !!!!!!!!---------ENABLE CARRIER DETECT
;                       !!!!!!!+---------DISABLE LOOPBACK
;
;
recv_mode       equ     00000010B                 ; set receive mode
;
;                       !!!!!!!!---------ACCEPT ALL PACKETS
;                       !!!!!!!+---------ACCEPT PHYSICAL, MULTICAST, AND
;                       !!!!!!+----------BROADCAST PACKETS
;                       !!!!!+-----------DISABLE REMOTE RESET
;                       !!!!+------------DISABLE SHORT PACKETS
;                       !!!+-------------USE 6 BYTE ADDRESS
;                       !!+--------------NC
;                       !+---------------NC
;                       +----------------DISABLE CRC TEST MODE

debug	= 0

	include defs.asm

code segment word public
	assume  cs:code, ds:code

	public  int_no
int_no	db      3,0,0,0			;must be four bytes long for get_number
io_adr	dw	300h,0			; default I/O address
	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db      BLUEBOOK,IEEE8023,0	;from the packet spec
driver_type	db      1		;from the packet spec
driver_name	db      'tiara',0	;name of the driver.
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

	public  rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	rcv_mode_1
		dw	0
		dw	rcv_mode_3
		dw	0		;haven't set up perfect filtering yet.
		dw	0
		dw	rcv_mode_6


;
;      Receive Packet Header Buffer: Required because addresses and e-type
;      must be read from tiara card before upcall to find a buffer can be
;      made.  Need the number of bytes, and the e-type for the call...
;
ether_buff	db	EADDR_LEN  dup(?)
		db	EADDR_LEN  dup(?)
ether_type	db	4 dup(?)
usr_ptr		dd	?                 ; temp storage or recv_buff ptr

writebport  macro   from_base,value
	mov	dx,cs:[io_adr]		; write byte value to port
	add	dx,from_base
	mov	al,value
	out	dx,al
	endm

;sends $ terminated string to screen
print$ macro   string
	mov	ah,9
	mov	dx,offset &string&	; print $ terminated string
	int	21h
	endm

mark           = 0F90h                 ; marker debug pos on screen 25

marker  macro   st,nd
  IF  debug NE 0                       ; do marker if debug <> 0
      pushf                            ; show 2 char marker on
      push es                          ; 25th line, 1st column
      push ax
      mov  ax,0B800h
      mov  es,ax
      mov  al,'&st&'
      mov  byte ptr es:[mark],al
      mov  al,byte ptr es:[mark+1]     ; get color value
      inc  al
      and  al,0Fh
      or   al,1
      mov  byte ptr es:[mark+1],al     ; advance it to show activity
      mov  al,'&nd'
      mov  byte ptr es:[mark+2],al
      mov  al,byte ptr es:[mark+3]
      inc  al
      and  al,0Fh
      or   al,1
      mov  byte ptr es:[mark+3],al
      pop  ax
      pop  es
      popf
    ENDIF
  endm

	include	timeout.asm

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
;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, pr else cy if error, dh set to error number.

              assume  ds:nothing
              marker  T,X

  if 1
              mov     ax,18
              call    set_timeout
              mov     dx,cs:[io_adr]
              add     dx,BMPR_PKT_LEN
wait_tmt:
              in      al,dx		; read count register until timeout...
              or      al,al
              jz      send_ok
              call    do_timeout
              jnz     wait_tmt
              mov     dh,CANT_SEND
              stc
              ret
send_ok:
  endif

              cmp     cx,RUNT                 ; big enough?
              jae     send_runt_ok
              mov     cx,RUNT                 ; at least runt!
send_runt_ok:
              cmp     cx,GIANT                ; small enough?
              jbe     send_size_ok
              mov     dh,NO_SPACE
              stc                             ; Error
              ret
send_size_ok:
;
;      8086/8088 byte mode send
;
              mov     ax,cx
              inc     cx
              shr     cx,1                    ; words to send

              mov     dx,cs:[io_adr]
              add     dx,BMPR_MEM_PORT
              cmp     cs:is_186,0  ; use BYTE or WORD mode?
              jne     send_w_mode
              out     dx,al
              xchg    ah,al
              out     dx,al
 xb:
              lodsw                           ; load word, ind ds:si
              out     dx,al
              xchg    ah,al
              out     dx,al
              loop    xb                      ; set packet length (byte mode)
              jmp     wait_tmt_ok
send_w_mode:
              out     dx,ax
              .286
              rep	outsw
              .8086
wait_tmt_ok:
              mov     dx,cs:[io_adr]	;tell the board that we've loaded one packet.
              add     dx,BMPR_PKT_LEN
              mov     al,TMST + 1
              out     dx,al

              clc
              ret

	public  set_address
set_address:
;enter with ds:si -> Ethernet address,CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	mov	dh,CANT_SET
	stc
	ret


rcv_mode_1:
	writebport	DLCR_RECV_MODE,0	; don't receive any packets
	ret


rcv_mode_3:
	writebport	DLCR_RECV_MODE,2	; receive mine, broads, and multis.
	ret


rcv_mode_6:
	writebport	DLCR_RECV_MODE,3	; receive all packets.
	ret


	public  set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	mov     dh,NO_MULTICAST
	stc
	ret

	public	terminate
terminate:
	writebport	DLCR_RECV_MODE,0	; don't receive any packets
	ret

	public  reset_interface
reset_interface:                       ;reset the interface.
	assume  ds:code
	ret

;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
	extrn   recv_find: near

;called after we've copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn   recv_copy: near

	extrn   count_in_err: near
	extrn   count_out_err: near

	public  recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.

	assume  ds:code
	marker  R,X

;clear receive masks to prevent further IRQs

	writebport	DLCR_RECV_MASK,0
recv_0:
	mov     ax,cs
	mov     ds,ax
	writebport      DLCR_RECV_STAT,clr_rcv_status

;are there any packets to read?

	mov     dx,cs:[io_adr]
	add     dx,DLCR_RECV_MODE
	in      al,dx
	test    al,BUF_EMPTY
	jz      recv_1                    ; 0 if at least one valid pkt..
	jmp     recv_99

;yes, read out a receive packet...

recv_1:
              cmp     cs:is_186,0
              jne     recv11
              jmp     read_b_mode
;
;        read packet out in word mode
;
recv11:
	mov	dx,cs:[io_adr]    ; get status and reserved byte
	add	dx,BMPR_MEM_PORT
	in	ax,dx
	in	ax,dx                           ; get packet size
	push	ax
					;read first 16 bytes from receive buffer into ether_buff
	mov	ax,cs
	mov	es, ax
	mov	di,offset ether_buff
	mov	cx,16/2                            ; word mode, remember...
	.286
	rep	insw			; read words into ether_buff
	.8086

;
;      If the sender is myself, ignore the packet.  This allows async
;      send/receive without messing up...
;
	mov	si,offset ether_buff+EADDR_LEN       ; we want the SOURCE
	mov	di,offset my_address
	mov	cx,EADDR_LEN/2
	repe	cmpsw
	jne	not_mine
	jmp	word_flush                      ; mine, so flush it
;
;      cx = length, es:di = pointer to ethertype
;
not_mine:
	pop	cx
	push	cx
	mov	di,offset ether_type
	mov	ax,cs
	mov	es,ax			; es:di -> ether type, cx = size# bytes
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
	call	recv_find		; got a buffer?
	mov	ax,es
	or	ax,di			; pointer zero?
	je	word_flush		; no pointer, discard data
;
;      es:di -> users buffer, do copy...
;      ds:si -> source of copy
;
	mov	cs:[usr_ptr.segm],es; save ULP pointer
	mov	cs:[usr_ptr.offs],di
	mov	ax,cs
	mov	ds,ax
	mov	si,offset ether_buff	; copy header to users buffer
	mov	cx,16/2			; 8 words to copy
	rep	movsw
	mov	dx,cs:[io_adr]		;copy rest of data to user
	add	dx,BMPR_MEM_PORT	; buffer in es:di ->
	pop	cx
	push	cx
	sub	cx,16
	shr	cx,1
	.286
	rep	insw			; read word, store at es:di ->
	.8086
	jnc	word_even
	in	ax,dx
	stosb
word_even:
	pop	cx			;call recv_copy to say copy done
	lds	si,cs:[usr_ptr]
	call	recv_copy
	jmp	recv_0			; go get another packet
word_flush:
	mov	dx,cs:[io_adr]
	add	dx,BMPR_MEM_PORT
	pop	cx
	sub	cx,16			; adjust word count
	shr	cx,1
word_f:
	in	ax,dx
	loop	word_f
	jmp	recv_0
;
;             go see of any more packets comming....
;
;             READ in BYTE MODE
;
read_b_mode:
	mov	dx,cs:[io_adr]	;get status and reserved byte
	add	dx,BMPR_MEM_PORT
	in	al,dx		; vacuum status and reserved
	in	al,dx
	in	al,dx		; get packet size
	xchg	al,ah		; low byte in ah
	in	al,dx		; get packet size
	xchg	al,ah		; fix size ah/al order
	push	ax		; keep number of bytes
	;      read first 16 bytes from receive buffer into ether_buff
	mov	ax,cs
	mov	es,ax
	mov	di,offset ether_buff
	mov	cx,16			; byte mode, 16 byte header
rdb:
	in	al,dx			; read 16 bytes into ether_buff
	stosb
	loop	rdb
;
;      If the sender is myself, ignore the packet.
;
	mov	si,offset ether_buff+EADDR_LEN       ; we want the SOURCE
	mov	di,offset my_address
	mov	cx,EADDR_LEN/2
	repe	cmpsw
	jne	not_mineb
	jmp	byte_flush                  ; mine, so flush it
;
;      cx = length, es:di = pointer to ethertype
;
not_mineb:
	pop	cx
	push	cx
	mov	di,offset ether_type
	mov	ax,cs
	mov	es,ax             ; es:di -> ether type, cx = size#bytes
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket1
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket1:
	call	recv_find                   ; got a buffer?
	mov	ax,es
	or	ax,di                       ; pointer zero?
	je	byte_flush                  ; no pointer, discard data
;
;      es:di -> users buffer, do copy...
;      ds:si -> source of copy
;
	mov	cs:[usr_ptr.segm],es	; save ULP pointer
	mov	cs:[usr_ptr.offs],di
	mov	ax,cs
	mov	ds,ax
	mov	si,offset ether_buff        ; copy header to users buffer
	mov	cx,16/2			; 16 bytes in header to copy
	rep	movsw
	mov	dx,cs:io_adr     ; copy rest of data to users
	add	dx,BMPR_MEM_PORT            ; buffer in es:di ->
	pop	cx
	push	cx
	sub	cx,16
cpyb:
	in	al,dx			; read byte
	stosb				; store at es:di ->
	loop	cpyb
	pop	cx			; call recv_copy to say copy done
	lds	si,cs:[usr_ptr]
	call	recv_copy
	jmp	recv_0			; go get another packet...
byte_flush:
	mov	dx,cs:io_adr
	add	dx,BMPR_MEM_PORT
	pop	cx
	sub	cx,16			; adjust byte count header
byte_f:
	in	al,dx
	loop	byte_f
	jmp	recv_0			; go to see if any more packets comming...
recv_99:
;      receive ok, restore recive mask and exit
;
	writebport	DLCR_RECV_MASK,en_rcv_irqs
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

io_adr_msg	db	"I/O Base Address: ",'$'
int_no_msg	db	"Interrupt Level: ",'$'
no_card_msg	db	"INIT: No card at I/O address specified",CR,LF,'$'

	public  usage_msg
usage_msg   db  "usage: tiara [options] <packet_int_no> <hardware_irq> <io_adr>",CR,LF,'$'

	public  copyright_msg
copyright_msg	label	byte
 db CR,LF
 db "tiara:  Driver for tiara Card, Version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version, CR,LF
 db "         - for PC, PC-AT, and Micro Channel (IBM tm)",CR,LF
 db "portions Copyright 1993, Crynwr Software",CR,LF
 db "portions - Copyright 1990, 1991 Queens University",CR,LF
 db "    Written by Brian Fisher",CR,LF
 db CR,LF,'$'

	extrn   set_recv_isr: near
;enter with si-> argument string,di->wword to store.
;if there is no number, don't change  the number.

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn   get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

;-> the current Ethernet address of the card.
	extrn	my_address: byte

	public  parse_args
parse_args:
;      parse  hardware interrupt number and I/O base address from the
;      command line.
;
	mov	di,offset int_no	; interrupt level?
	call	get_number
	jc	_parse_exit
	mov	di,offset io_adr	; first comes the I/O base address
	call	get_number
_parse_exit:
	clc
	ret

	public etopen
etopen:
	writebport	DLCR_CONFIG,card_disable	; disable etherstar
	writebport	DLCR_XMIT_STAT,clear_status	; clr xmit status
	writebport	DLCR_XMIT_MASK,no_tx_irqs	; disable xmit IRQ's
	writebport	DLCR_RECV_STAT,clr_rcv_status	; clear rcv status
	writebport	DLCR_RECV_MASK,en_rcv_irqs	; enable rcv IRQ's
	writebport	DLCR_XMIT_MODE,xmit_mode	; set xmit mode
	writebport	DLCR_RECV_MODE,recv_mode	; set receive mode
	writebport	DLCR_RBNK,020h	;turn on IDR8-IDR15.

;
;      Set Node ID:
;
	movseg	es,cs
	mov	di,offset rom_address
	mov	cx,EADDR_LEN		; calc base of I/O regs for node id
	mov	bx,cs:io_adr
	mov	dx,bx
	add	bx,DLCR_NODE_ID
	add	dx,PROM_ID		; and base of PROM for copy
	mov	ah,0ffh			;start with all bits set.
etopen0:
	in	al,dx			; read byte of factory address
	stosb
	and	ah,al			;remove any bits that are zeroes.
	xchg	bx,dx
	out	dx,al			; write to register
	xchg	bx,dx
	inc	dx
	inc	bx
	loop	etopen0			; until copy is done...
;
;       Verify card address is not all 1's
;
        cmp     ah,-1
        jne     etopen0a
        jmp     etopen_nocard           ;   all 1's, no card found
etopen0a:
;
;      Verify card exists by comparing address to PROM
;
	mov	cx,EADDR_LEN
etopen1:
	dec	dx
	dec	bx
	in	al,dx
	xchg	bx,dx
	mov	ah,al
	in	al,dx
	xchg	bx,dx
	cmp	al,ah
	jne	etopen_nocard		; no card found
	loop	etopen1

	writebport	DLCR_RBNK,028h	;turn on BMR8-BMR15
	writebport	DLCR_CONFIG,card_enable
	call	set_recv_isr                ; install receive IRQ routine

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
etopen_nocard:
	mov	dx,offset no_card_msg	; couldn't verify card exists...
	stc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov	di,offset int_no	; interrupt level.
	mov	dx,offset int_no_msg
	call	print_number
	mov	di,offset io_adr	; now comes the I/O base address
	mov	dx,offset io_adr_msg
	call	print_number
	ret

code	ends

	end
