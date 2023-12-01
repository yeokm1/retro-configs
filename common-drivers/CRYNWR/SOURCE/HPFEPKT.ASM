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

; Version 0: Started with the Crynwr Software packet driver 
IFDEF HP_PROD
; skeleton, skeleton.asm. Version 0 is for the HP Cascade chip 
ELSE; NOT HP_PROD
; skeleton, skeleton.asm. Version 0 is for the ATT2MD01 chip 
ENDIF; NOT HP_PROD
; ISA/EISA I/O mode only.

	include	defs.asm
; change below to include att2md01.inc for NOT HP_PROD
	include hpfepkt.inc

;  HP 100 VG cards are 16 bit at least, assume 286 instructions OK
.286

;code	segment	word public
code	segment	para public 'CODE'
	assume	cs:code, ds:code

	extrn	is_eisa: byte	;Defined in tail.asm
	extrn	sys_features: byte	;bitmask of system features.
	extrn	is_186: byte		;=0 if 808[68], =1 if 80[1234]86.
	extrn	is_286: byte		;=0 if 80[1]8[68], =1 if 80[234]86.
	extrn	is_386: byte		;=0 if 80[12]8[68], =1 if 80[34]86.

	extrn 	multicast_count: word

	extrn	re_enable_interrupts: near

	public	int_no, io_addr, mem_addr, memory_mapped, bm_read, bm_write
	public  send_wait_cnt, card_type, card_sw_model, rx_ratio, lan_type
	public  rx_curr_cnt, rx_pkt_stat, rx_pkt_leng
int_no	db	0,0,0,0		;must be four bytes long for get_number.
io_addr		dw	-1,-1	; I/O address for card (jumpers)
mem_addr	dw	?,0	; Memory Mapped address
memory_mapped	db	0	; Memory Mapped flag
send_wait_cnt	dw 	0	; send_pkt wait for room counter
card_type	db 	?	; Card type index found during init.
card_sw_model	db 	?	; Card sw model byte. Contains config info?
bm_write_fl	db	0	; Bus Master Write Flag
bm_read_fl	db	0	; Bus Master Read Flag
rx_ratio	db	70	; Ratio of card resident RX buffers as a percent
				; of RX+TX buffers. Make tuneable parameter 
				;later.
lan_type	db	0	; LAN type current valid values are 10 or 100
rx_curr_cnt	db	0	; count of RX pkts on card.

;******************************************************************************
; SRAM Size Lookup Table.  These values are missing the lower 4 bits since
; the stop address registers dont have these bits.  Also, the 1M entry is
; -1 byte so it will fit in a 16 bit table.  This will cause the percentages
; to be off by an insignificant margin.
;******************************************************************************
;                        8k,  16k,  32k,  64k,   128k   256k   512k,    1M
SRAMTable       dw      200h, 400h, 800h, 1000h, 2000h, 4000h, 8000h, 0FFFFh

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0	;null terminated list of classes.
driver_type	db	60		;Wild card matches any type
IFDEF HP_PROD
driver_name	db	'HPFEPKT',0	;name of the driver.
ELSE ;NOT HP_PROD
driver_name	db	'ATT2MD01',0	;name of the driver.
ENDIF ;NOT HP_PROD
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

include	block.asm

	public	mcast_list_bits, mcast_all_flag
mcast_list_bits	db	8 dup(0)
mcast_all_flag  db	0

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0		;there is no mode zero.
		dw	rcv_mode_1
		dw	rcv_mode_2
		dw	rcv_mode_3
		dw	rcv_mode_4
		dw	rcv_mode_5
		dw	rcv_mode_6
		dw	rcv_mode_7

mac1mode	db	MAC1MODE3 	; Mode 3 default
mac2mode	db	MAC2MODE3		; Normal modes
rxtxmode	dw	RX_FLAG or TX_FLAG

;*************************************************************
; A place to put the incomming header for passing to recv_find
;*************************************************************

RX_HWHDR_SIZE	equ	4	; 4 bytes of hardware header
RX_LOOK_SIZE	equ	24	; 2 MACs @6 + protocol @2+8 + pad to 4 byte
				; alignment
RX_ETYPE_OFFSET equ	12	; offset to the ethernet type field
ALIGN 4

rcv_hdr		label	byte
rx_pkt_leng	dw	0	; current RX packet length
rx_pkt_stat	dw	0	; current RX packet status
rx_look_data	db	RX_LOOK_SIZE dup (0)

;******************************************************************************
; DisableRxTx/EnableRxTx flags to indicate what to disable/enable
;******************************************************************************
RX_FLAG                 equ     1
TX_FLAG                 equ     2
RxTxMask                db      ?       ; Used to mask/unmask Rx and Tx bits
RxTxIdleMask            db      ?       ; Used to determine when Rx/Tx is idle



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

IFDEF REVA
send_pkt_page	dw	?	; Save location for current page.
ENDIF; REVA

ALIGN 16				; Align on a cache line
	
	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

	cli					; system interrupts off
	loadport			; initialize DX to card address
IFDEF REVA

	; It is possible that this can be called from within a receive
	; ISR. If so we are already in the performance page, so save
	; the current page now

	setport PagingReg
	in	ax, dx
	and	ax, 000fh
	mov	send_pkt_page, ax
	jz	send_pkt_0
	SWITCH_PAGE PERFORMANCE_PAGE	; REVA Chip must be left in page 6!
send_pkt_0:
	loadport

ENDIF; REVA

	INTS_OFF			; disable card ints,
	call re_enable_interrupts	; now safe from re-entrancy
	mov	send_wait_cnt, 0ffffh	; wait a long time
;
; Check for packet errors
;
	cmp	cx, GIANT	; Is packet too large
	ja	send_pkt_ex
	
	cmp cx,	RUNT		; Is the frame long enough?
	jnb	tx_oklen	; Go if OK
	mov cx,	RUNT		; Stretch frame to minimum allowed

tx_oklen:
;
; Record prior TX completions
;
	setport InterruptStatusReg
	in	ax, dx					
	and	ax, TX_COMPLETE OR TX_ERROR
	out	dx, ax				; Clear the interrupt bits
	and ax, TX_ERROR
	jz	send_pkt_mem_ck
	
	; Log the TX_ERROR here

	call 	count_out_err

;
; Check for room on the card
;

send_pkt_mem_ck:
	setport	TxMemoryFreeCountReg+2
	in	ax, dx
	or	ax, ax
	jns	send_pkt_no_mem		; Auto Compare says not enough memory
	
send_pkt_ok_mem:

	setport	DataReg 		; Send frame length to card memory manager
	mov	ax, cx
	out	dx, ax
	setport FragmentLengthReg	; and send length as a fragment length
	out	dx, ax
	
	call	block_output
	
	loadport
	setport OptionMSWReg		; Tell the card to TX
    	mov 	ax, TX_CMD or SET_LB
    	out 	dx, ax
    	jmp 	send_pkt_done
	
send_pkt_no_mem:
;
; Not enough packet memory to add a tx packet, should we wait around?
;  Check MAC Status, OK continue else set ok interrupt and return
;  CANT_SEND
;
;  Wait a packet time or so
;  Room now? OK jmp back to send_pkt_ok_mem
;  otherwise set tx complete interrupt and return NO_SPACE
;
	dec	send_wait_cnt
	jnz	tx_oklen	; if the counter rolls over, take the error exit.
	jmp	send_pkt_ex
;
send_pkt_done:
	clc
	jmp	send_pkt_x
	
send_pkt_ex:
	mov	dh,CANT_SEND
	stc

send_pkt_x:	
	cli			; protect hardware, iret will restore proper state.
	pushf			; save error status
	push 	dx		; save return byte
	loadport		; not sure how I got here
	INTS_ON			; enable card interrups
IFDEF REVA
;******************************************************************************
; Switch to page 6 so the EISA IDs will be visible in case the user does a
; three-finger reset while driver is operating (Rev. A chip only).
; UNLESS we were already on page 0 when we entered this routine!
;******************************************************************************
    	mov	ax, send_pkt_page
	or	ax, ax
	jz	send_pkt_xx
    	SWITCH_PAGE ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
send_pkt_xx:
ENDIF; REVA
	pop 	dx		; recover return byte
	popf			; and error status

	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing

	pushf
	cli

	push 	ds
	push	si
	push	cx
	movseg	ds, cs
	assume  ds:code

	mov	ax, RX_FLAG or TX_FLAG		; Stop receiver
	call DisableRxTx

	loadport
	SWITCH_PAGE MAC_ADDRESS_PAGE
	setport	MACAddressReg

	pop	cx
	pop	si
	pop	ds
	assume 	ds:nothing

set_mac_loop:
	outsb
	inc	dx
	loop	set_mac_loop

	push	ds
	movseg 	ds, cs
	assume	ds:code
	mov	ax, rxtxmode	; Start RX and TX if required
	call 	EnableRxTx

	loadport
IFDEF REVA
;******************************************************************************
; Switch to page 6 so the EISA IDs will be visible in case the user does a
; three-finger reset while driver is operating (Rev. A chip only).
;******************************************************************************
    	SWITCH_PAGE     ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
ELSE; NOT REVA
	SWITCH_PAGE PERFORMANCE_PAGE ;restore performance page
ENDIF; NOT REVA

	pop	ds
	assume	ds:nothing
	popf
	ret


	public rcv_mode_1, rcv_mode_2, rcv_mode_3, rcv_mode_4, rcv_mode_5
	public rcv_mode_6, rcv_mode_7, set_rcv_modes

rcv_mode_1:
	mov	mac1mode, MAC1MODE1
	mov	mac2mode, MAC2MODE1
	mov	rxtxmode, TX_FLAG
	mov	mcast_all_flag, 0
	jmp	set_rcv_modes

rcv_mode_2:
	mov	mac1mode, MAC1MODE2
	mov	mac2mode, MAC2MODE2
	mov	rxtxmode, TX_FLAG OR RX_FLAG
	mov	mcast_all_flag, 0
	jmp	set_rcv_modes

rcv_mode_3:
	mov	mac1mode, MAC1MODE3
	mov	mac2mode, MAC2MODE3
	mov	rxtxmode, TX_FLAG OR RX_FLAG
	mov	mcast_all_flag, 0
	jmp	set_rcv_modes

rcv_mode_4:
	mov	mac1mode, MAC1MODE4
	mov	mac2mode, MAC2MODE4
	mov	rxtxmode, TX_FLAG OR RX_FLAG
	mov	mcast_all_flag, 0
	jmp	set_rcv_modes

rcv_mode_5:
	mov	mac1mode, MAC1MODE5
	mov	mac2mode, MAC2MODE5
	mov	rxtxmode, TX_FLAG OR RX_FLAG
	mov	mcast_all_flag, 1
	jmp	set_rcv_modes

rcv_mode_6:
	mov	mac1mode, MAC1MODE6
	mov	mac2mode, MAC2MODE6
	mov	rxtxmode, TX_FLAG OR RX_FLAG
	mov	mcast_all_flag, 1
	jmp	set_rcv_modes

rcv_mode_7:
	mov	mac1mode, MAC1MODE7
	mov	mac2mode, MAC2MODE7
	mov	rxtxmode, TX_FLAG OR RX_FLAG
	mov	mcast_all_flag, 1
	jmp	set_rcv_modes

set_rcv_modes:
	pushf		; save interrupt flag
	cli	; and disable interrupts while we play with the card.

	mov	ax, RX_FLAG or TX_FLAG	; Stop MAC
	call DisableRxTx

	; Left on MAC_CONTROL_PAGE by DisableRxTx

	loadport
	setport MACConfiguration1Reg

	mov	al, mac1mode
	out	dx, al

	setport MACConfiguration2Reg

	mov	al, mac2mode
	out	dx, al

	call	set_hw_multi		; set the multicast hash table
					; per set_mcast_all flag
					; (also enables rx & tx)
					; and restores proper page.

	popf	;restore interrupts
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	assume ds:code

	mov	cx,ax			;keep a count of addresses in cx.
	mov	di,offset mcast_list_bits
	xor	ax,ax
	mov	[di+0],ax
	mov	[di+2],ax
	mov	[di+4],ax
	mov	[di+6],ax
	jcxz	set_mcl_2
set_mcl_1:
	call	add_mc_bits
	loop	set_mcl_1
set_mcl_2:
	call    set_hw_multi	; Set the multicast mask bits in chip
	clc
	ret

add_mc_bits:
;entry:	ds:si -> multicast address, di-> sixty-four bit multicast filter.
;preserve cx, di, increment si by EADDR_LEN
	push	cx
	mov	cx,EADDR_LEN
	mov	dx,0ffffh			; this is msw.
	mov	bx,0ffffh			; set 32 bit number
add_mcb_1:
	lodsb
	call	upd_crc			; update crc
	loop	add_mcb_1		; and loop.

	; shift the upper 6 bits into a 6 bit integer

	shr	dh, 1
	shr	dh, 1

	; because the indexing is backwards in ATT2MD01 (and pcnetisa)
	; subtract the index from 63.

	neg	dh
	add	dh, 63

	mov	al,dh			; get the top 3 bits
	shr	al, 1
	shr	al, 1
	shr	al, 1
	and	al,7
	mov	bl,al			; save in bl
	xor	bh,bh			; make bx into an index to the byte.

	mov	al,dh			; get the bottom 3 bits
	and	al,7
	mov	cl,al			; save in cl
	mov	al,1
	shl	al,cl			; set the correct bit,

	or	[bx+di],al
	pop	cx
	ret

;
;	dx is high,
;	bx is low.
;	al is data

upd_crc:
	push	cx
	mov	cx,8		; do 8 bits
	mov	ah,0
upd_crc1:
	shl	bx,1		; shift bx
	rcl	dx,1		; through dx
	rcl	ah,1		; carry is at bottom of ah
	xor	ah,al		; xor with lsb of data
	rcr	ah,1		; and put in carry bit
	jnc	upd_crc2
;
;	autodin is x^32+x^26+x^23x^22+x^16+x^12+x^11+x^10+x^8+x^7+x^5+x^4+x^2+x^1
;
	xor	dx,0000010011000001b
	xor	bx,0001110110110110b + 1	;plus one for end-around carry.
upd_crc2:
	shr	al,1		; shift the data
	loop	upd_crc1
	pop	cx
	ret

	public set_hw_multi
set_hw_multi:

	pushf	; save interrupt flag
	cli	; and disable interrupts while we play with the card.

	mov	ax, RX_FLAG or TX_FLAG		; Stop receiver
	call DisableRxTx

	loadport
	SWITCH_PAGE MAC_ADDRESS_PAGE

	setport HashByte0Reg
	mov	cx, 8
	mov	si, offset mcast_list_bits

	mov	al, mcast_all_flag
	or	al, al
	jz	hash_loop
	mov	al, 0ffh
	jmp	set_mcast_all

hash_loop:
	outsb
	inc	dx
	loop	hash_loop
	jmp	set_hw_multi_done

set_mcast_all:
	out	dx, al
	inc	dx
	loop	set_mcast_all

set_hw_multi_done:
	mov	ax, rxtxmode	; Start RX and TX if required
	call 	EnableRxTx

	loadport
IFDEF REVA
;******************************************************************************
; Switch to page 6 so the EISA IDs will be visible in case the user does a
; three-finger reset while driver is operating (Rev. A chip only).
;******************************************************************************
    	SWITCH_PAGE     ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
ELSE; NOT REVA
	SWITCH_PAGE PERFORMANCE_PAGE ;restore performance page
ENDIF; NOT REVA

	popf	;restore interrupts
	ret

	public	terminate
terminate:
	pushf
	cli
	call stop_interface

	loadport
	RESET_CARD
	
	loadport
IFDEF REVA
;******************************************************************************
; Switch to page 6 so the EISA IDs will be visible in case the user does a
; three-finger reset while driver is operating (Rev. A chip only).
;******************************************************************************
    	SWITCH_PAGE     ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
ELSE; NOT REVA
	SWITCH_PAGE PERFORMANCE_PAGE ;restore performance page
ENDIF; NOT REVA

	popf
	ret


	public	reset_interface
reset_interface:
;reset the interface.
	assume	ds:code

	; should put a full rendition of etopen here, but no packet driver
	; I ever looked at does, so...

	pushf
	cli

	call stop_interface

	loadport
	RESET_CARD

	;reload MAC address from rom_address

	mov	si, offset rom_address
	mov	cx, EADDR_LEN
	call	set_address
	mov	si, offset rom_address
	mov	di, offset my_address
	movseg	es, ds
	mov	cx, EADDR_LEN
	rep	movsb

	;reinit rcv_mode variables
	  ; note, since we can't get at the rcv_mode_num variable
	  ; in head.asm, we can't resync, so don't do this here.	

	; mov	al, MAC1MODE3
	; mov	mac1mode, al
	; mov	al, MAC2MODE3
	; mov	mac2mode, al
	; mov	ax, RX_FLAG OR TX_FLAG
	; mov	rxtxmode, ax

	;reinit mcast bits

	xor	ax, ax
	mov 	multicast_count, ax
	mov	mcast_all_flag, al
	mov	cx, 8
	mov	di, offset mcast_list_bits
	movseg	es, cs
	rep	stosb

	mov	ax, rxtxmode
	push	ax
	xor	ax, ax
	mov	rxtxmode, ax	; save & setup rxtxmode so set_hw_mcast
	call	set_hw_multi    ; won't turn it on
	pop	ax
	mov	rxtxmode, ax

	;re-do sense_lan

	call 	sense_lan
	
	mov	al, lan_type
	cmp	al, LAN_100		; If on 100BaseVG, must login
	jnz	reset_start		; to the hub

	;relogin100vg if 100vg lan

	call	login100vghub

reset_start:

	call start_interface

	popf
	ret
	
	public	stop_interface
stop_interface:
;
; Assume Interrupts Off
; Tri-state card interrupts
; Zero the INT_EN bit
; Set Bus Master to slave
; Disable transmitter and receiver
;	return carry bit set if TX or RX fails to stop in 1.2mS
; Put the card into reset
;   return carry bit clear
;
	loadport
	setport OptionLSWReg

	; set TRI_INT and clear INT_EN

	mov	ax, TRI_INT or SET_HB or INT_EN or RESET_LB
	out	dx, ax
	
	; read the option register here, if held in RESET, skip the
	; TX_IDLE/RX_IDLE wait.
	
	in	ax, dx
	mov	bx, ax

        
	; Disable bus mastering

    	SWITCH_PAGE HARDWARE_MAP_PAGE
    	setport BMReg
    	in      al, dx                  ; Get current value
    	and     al, NOT BM_SLAVE        ; Set BM_SLAVE bit to 0
    	out     dx, al

; Stop TX & RX

	SWITCH_PAGE	MAC_CONTROL_PAGE
	setport	MACConfiguration1Reg	; Get the MAC configuration register
	in	al, dx
	and	al, NOT (RX_EN OR TX_EN)
	out	dx, al
	
	clc		; set no error return

	; option register saved in BX

	test	bx, HW_RST
	jz	stop_txrx_ok

; Wait loop for TX & RX Idle bits to set

	mov	cx,	6000		; Will provied >= 1.2ms
stop_txrx_loop:				;   since fastest bus time is 200ns (on MCA)
	in	al, dx
	and	al, TX_IDLE OR RX_IDLE
	cmp	al, TX_IDLE OR RX_IDLE
	jz	SHORT stop_txrx_ok
	loop	SHORT stop_txrx_loop
	
; Get here if TX or RX refused to stop

	stc						; set error return
	
stop_txrx_ok:
	ret
	
;*******************************************************************
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

	loadport
IFDEF REVA
	SWITCH_PAGE PERFORMANCE_PAGE ;RevA chip only, restore performance page
ENDIF; REVA
	INTS_OFF			; Card interrupts off

	sti		; interrupts on, we may be here awhile

rx_outer_loop:

	; Find out how many packets on card to be received, if zero just
	; exit

	loadport
	setport	RxPktCountReg
	in	ax, dx		; read the number of RX packets	
	mov	rx_curr_cnt, al ; and save
	or	al, al
	jz	rx_exit		; test and exit if none

rx_inner_loop:

	; lets receive a packet here, get the header first

	mov	cx, RX_LOOK_SIZE+4	; pkt header + 4 bytes
	mov	di, OFFSET rcv_hdr
	movseg	es, ds
	call	block_input

	; now check to see if it's a valid packet
	;  Note, all received packets are 'good'. If we don't set
	;  any of the accept errors bits in the MAC control registers
	;  then we won't receive them, if we do, then we want them.
	;  Need to find some non packet driver spec method of passing
	;  these up for LAN analysis programs and the like.

	mov	cx, rx_pkt_leng ; size of received packet

	; point es:di to the ethernet type field as default

	mov	di, offset rx_look_data+RX_ETYPE_OFFSET
	mov	dl, BLUEBOOK	; and assume bluebook Ethernet.
	mov	ax, es:[di]	; get type
	xchg	ah, al		; make it a size
	cmp	ax, 1500	; is it bigger than allowed?
	ja	notdot3		; yes, it's not an 802.3 size

	; no it's an 802.3 size, adjust pointer to
	; 802.2 DSAP

	inc	di
	inc	di
	mov	dl, IEEE8023

notdot3:
	push	cx		; save the frame size
	call	recv_find	; check & send it up
	pop	cx		; I can't find anywhere that recv_find
				; must preserve or return meaningful cx,
				; but it seems to. This may be superfluous.

	; recv_find returns a NULL pointer if the packet is not 
	; needed, else pointer to buffer.

	mov	ax, es		; check for
	or	ax, di		; NULL pointer
	jz	pkt_sent	; If NULL just drop the packet

	; save es:di buffer pointer for up call and size

	push	cx
	push	es
	push	di

	; move the already copied bytes to the buffer

	mov	si, offset rx_look_data
	mov	ax, cx			; save the size incase it's less
	sub	cx, RX_LOOK_SIZE

	jbe	all_here	; take the jump if the packet size is
				; less than or equal to the lookahead size

	mov	ax, cx		; save the remainder in ax
	mov	cx, RX_LOOK_SIZE
	rep	movsb		; adjusts si for the next call

	; now copy the rest of the packet from the card

	mov	cx, ax		; recover the remainder
	call	block_input
	jmp	recv_sendup

all_here:

	; entire packet already copied into lookahead buffer, just copy it

	mov	cx, ax		; recover the size
	rep	movsb		; adjusts si for the next call

	; data copied, send it up

recv_sendup:
	pop	si	; recover buffer pointer and packet length
	pop	ds	; but put then in ds:si for the upcall
	pop	cx
	assume 	ds:nothing
	call	recv_copy
	movseg	ds, cs
	assume	ds:code

pkt_sent:

	; Tell the card to go to the next packet

	loadport
	setport	OptionMSWReg
	mov	ax, ADV_NXT_PKT OR SET_LB
	out	dx, ax


	dec	rx_curr_cnt	; done with this packet
				;  Any more we know about to do?
	jnz	rx_inner_loop	; YES, ok do them

	; All packets originally on the card have been received or
	; discarded. Blindly acknowledge the interrupts then go
	; check for new packets

	setport InterruptStatusReg
	mov	ax, RX_PACKET OR RX_ERROR OR SET_HB
	out	dx, ax

	jmp	rx_outer_loop	; NO, check for new RX packets

rx_exit:

	cli
	loadport		; not sure how I got here
	INTS_ON			; enable card interrups
IFDEF REVA
;******************************************************************************
; Switch to page 6 so the EISA IDs will be visible in case the user does a
; three-finger reset while driver is operating (Rev. A chip only).
;******************************************************************************
    SWITCH_PAGE     ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
ENDIF; REVA
	ret

	public EnableRxTx
;******************************************************************************
;                                                                             *
;                           EnableRxTx                                        *
;                                                                             *
; PURPOSE:     Enables the cards receiver and transmitter.                    *
;                                                                             *
; PARAMETERS:                                                                 *
;       ON ENTRY:                                                             *
;       DS      - CGroup.                                                     *
;       AX      - RX_FLAG is set if Rx is to be enabled.                      *
;                 TX_FLAG is set if Tx is to be enabled.                      *
;       Int     - Disabled.                                                   *
;                                                                             *
;       ON EXIT:                                                              *
;       Successful:                                                           *
;       C flag clear 							      *
;       Rx and/or Tx are enabled.                                             *
;                                                                             *
;       Unsuccessful:                                                         *
;       C flag set                                                            *
;                                                                             *
;       All registers may be destroyed.                                       *
;                                                                             *
; SIDE EFFECTS & CAVEATS:                                                     *
;       Hardware page is set to a non-PERFORMANCE_PAGE.                       *
;                                                                             *
; ALGORITHM:   								      *
;       Determine what is to be neabled                                       *
;       Set RX_EN and/or TX_EN bits to 1, depending on what is to be enabled  *
;       clear C flag                                                          *
;									      *
;******************************************************************************

EnableRxTx:

;******************************************************************************
; Initialize mask for enable Rx and/or Tx.
;******************************************************************************
        mov     RxTxMask, 0             ; Used to turn Rx/Tx bits 1
        mov     RxTxIdleMask, 0         ; Used to wait for idle bits

;******************************************************************************
; Enable Rx if requested.
;******************************************************************************
        test    ax, RX_FLAG             ; Enable Rx?
        jz      SHORT DoneEnableRx      ; Jump if not
        or      RxTxMask, RX_EN         ; Set RX_EN bit to 0
        or      RxTxIdleMask, RX_IDLE   ; Set RX_IDLE bit to 1
DoneEnableRx:

;******************************************************************************
; Enable Tx if requested.
;******************************************************************************
        test    ax, TX_FLAG             ; Enable Tx?
        jz      SHORT DoneEnableTx      ; Jump if not
        or      RxTxMask, TX_EN         ; Set TX_EN bit to 0
        or      RxTxIdleMask, TX_IDLE   ; Set RX_IDLE bit to 1
DoneEnableTx:

;******************************************************************************
; Switch to MAC control page
;******************************************************************************
	loadport
        SWITCH_PAGE     MAC_CONTROL_PAGE        ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Enable Rx and Tx
;******************************************************************************
        setport MACConfiguration1Reg        ; Read in reg
        in      al, dx
        or      al, RxTxMask                    ; Set bits to 1
        out     dx, al

;******************************************************************************
; Indicate success
;******************************************************************************
        clc

EnableExit:
        ret

	public DisableRxTx
;******************************************************************************
;                                                                             *
;                             DisableRxTx                                     *
;                                                                             *
; PURPOSE:     Disables the cards receiver and/or transmitter.                *
;                                                                             *
; PARAMETERS:                                                                 *
;       ON ENTRY:                                                             *
;       DS      - CGroup.                                                     *
;       AX      - RX_FLAG bit is set if Rx is to be disabled.                 *
;                 TX_FLAG bit is set if Tx is to be disabled.                 *
;       Int     - Disabled.                                                   *
;                                                                             *
;       ON EXIT:                                                              *
;       Successful:                                                           *
;       C flag - clear.                                                       *
;       Rx and/or Tx are disabled.                                            *
;                                                                             *
;       Unsuccessful:                                                         *
;       C flag - Set.                                                         *
;       Rx and/or Tx state unknown.                                           *
;       All registers may be destroyed.                                       *
;                                                                             *
; SIDE EFFECTS & CAVEATS:                                                     *
;       Hardware page is set to a non-PERFORMANCE_PAGE.                       *
;                                                                             *
; ALGORITHM:   								      *
;       Determine what is to be disabled                                      *
;       Set RX_EN and/or TX_EN bits to 0, depending on what is to be disabled *
;       Wait ~1.2ms for RX_IDLE and/or TX_IDLE to go to idle                  *
;       If idle                                                               *
;           Clear C flag                                                      *
;       Else                                                                  *
;           Set DX to address of error message                                *
;           Set C flag                                                        *
;									      *
;******************************************************************************

DisableRxTx:

;******************************************************************************
; Initialize masks for disable Rx and/or Tx.
;******************************************************************************
        mov     RxTxMask, 0FFh          ; Used to turn Rx/Tx bits 0
        mov     RxTxIdleMask, 0         ; Used to wait for idle bits

;******************************************************************************
; Disable Rx if requested.
;******************************************************************************
        test    ax, RX_FLAG             ; Disable Rx?
        jz      SHORT DoneDisableRx     ; Jump if not
        and     RxTxMask, NOT RX_EN     ; Set RX_EN bit to 0
        or      RxTxIdleMask, RX_IDLE   ; Set RX_IDLE bit to 1
DoneDisableRx:

;******************************************************************************
; Disable Tx if requested.
;******************************************************************************
        test    ax, TX_FLAG             ; Disable Tx?
        jz      SHORT DoneDisableTx     ; Jump if not
        and     RxTxMask, NOT TX_EN     ; Set TX_EN bit to 0
        or      RxTxIdleMask, TX_IDLE   ; Set TX_IDLE bit to 1
DoneDisableTx:

;******************************************************************************
; Switch to MAC control page.
;******************************************************************************
	loadport
        SWITCH_PAGE     MAC_CONTROL_PAGE ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Disable Rx and Tx.
;******************************************************************************
        setport MACConfiguration1Reg ; Read in reg
        in      al, dx
        and     al, RxTxMask             ; Zero needed bits
        out     dx, al

;******************************************************************************
; Wait until they are idle
;******************************************************************************
        mov     cx, 6000                ; This will provide >= 1.2ms
TurnOffRxTxLoop:                        ;   since fastest bus time
        in      al, dx                  ;   is 200ns(on MCA).
        and     al, RxTxIdleMask        ; Isolate Rx and/or Tx bits
        cmp     al, RxTxIdleMask        ; Is bit(s) set?
        je      SHORT DisableExit       ; Jump if it is
        loop    SHORT TurnOffRxTxLoop

;******************************************************************************
; Rx and/or Tx wouldn't go idle.
;******************************************************************************

	stc
	ret

DisableExit:

	clc
        ret

;timer routines
	include timeout.asm

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret
	
	public	sense_lan
sense_lan:

; Sense which LAN connection to use on the card, if not specified 
; in the card configuration bits.

;       If the MAC Sel bit in each are the same(autoselect)                   *
;           If the LINK_BEAT_ST in the 10 reg is 0                            *
;               Set lan_type to LAN_100                        		      *
;           Else                                                              *
;               Set lan_type to LAN_10                             	      *
;       Else if MAC Sel in 100 is 1                                           *
;           Set lan_type to LAN_100                                 	      *
;       Else                                                                  *
;           Set lan_type to LAN_10                                  	      *

;      NOTE! Autoselect depends on LINK BEAT for 10BaseT. Absense of LINK BEAT
;      will select 10BaseVG


;******************************************************************************
; Switch to LAN Configuration Page (page 4).
;******************************************************************************
	loadport
	SWITCH_PAGE     MAC_CONTROL_PAGE        ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Determine which port was selected.  If both MAC are selected or if neither
; is selected then auto-sense.
;******************************************************************************
        setport LANCntrCfgVGReg
        in      ax, dx
        mov     cx, ax

        setport LANCntrCfg10Reg
        in      ax, dx

        test    cx, MAC100_SEL
        jz      SHORT VGNotSelected

        test    ax, MAC10_SEL           
        jnz     SHORT LANAutoSelected

        mov     lan_type, LAN_100
        jmp     SHORT sense_lan_exit

VGNotSelected:
        test    ax, MAC10_SEL           
        jz      SHORT LANAutoSelected

        mov     lan_type, LAN_10
        jmp     SHORT sense_lan_exit

LANAutoSelected:
        mov     lan_type, LAN_100
        test    ax, LINK_BEAT_ST
        jz      SHORT sense_lan_exit
        mov     lan_type, LAN_10

sense_lan_exit:

        ret

	public	login100vghub
login100vghub:

;******************************************************************************
;                                                                             *
;                           login100vghub				      *
;                                                                             *
; PURPOSE:     Login the endnode to the hub.                                  *
;                                                                             *
; PARAMETERS:                                                                 *
;       Successful:                                                           *
;       	Carry flag clear 					      *
;                                                                             *
;       Unsuccessful:                                                         *
;       	Carry flag set						      *
;		dx points to error message 				      *
;                                                                             *
;       All registers may be destroyed.                                       *
;                                                                             *
; SIDE EFFECTS & CAVEATS:                                                     *
;       Hardware page is set to a non-PERFORMANCE_PAGE.                       *
;                                                                             *
;       It is assumed that the 100 MAC has been selected.                     *
;                                                                             *
;       The delays in this routine are based on the fastest I/O cycle.  Which *
;       is 200ns on MCA.                                                      *
;                                                                             *
;       Card must be out of reset when this routine is called.                *
;                                                                             *
; ALGORITHM:   								      *
;       Switch to MAC_CONTROL_PAGE                                            *
;       Set the VG_RESET bit to 1 to make sure VG isn't in reset state        *
;       Call DownLink to bring down the VG link                               *
;       If carry flag set                                                     *
;           Set DX to error message                                           *
;           Return                                                            *
;       Switch to MAC_CONTROL_PAGE                                            *
;       Set the LOAD_ADDR and LINK_CMD bits to 1 to start login procedure     *
;       Wait up to 500us for LINK_CABLE_ST to be 1                            *
;       If it didn't go to 1                                                  *
;           set carry flag                                                    *
;           Return                                                            *
;       Wait up to 15 seconds for LINK_UP_ST and LINK_GOOD_ST to be 1         *
;       If they are all set                                                   *
;           clear carry							      *
;           Return                                                            *
;       Else                                                                  *
;           Bring link down                                                   *
;           Bring link up with an address of 0                                *
;           set carry							      *
;           Return                                                            *
;									      *
;******************************************************************************

;******************************************************************************
; Switch to MAC control page
;******************************************************************************
	loadport
        SWITCH_PAGE     MAC_CONTROL_PAGE        ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Make sure VG isn't in reset
;******************************************************************************
        setport LANCntrCfgVGReg             ; Get current value
        in      ax, dx

        or      ax, VG_RESET                    ; Set bit to 1
        out     dx, ax

; check for tones here, if no tones, cable not connected

        mov     cx, 2500                ; 2500 loops of 200ns = 500us
tones_loop:
;******************************************************************************
; Can the card hear tones(is cable attached?)
;******************************************************************************
        in      ax, dx
        test    ax, LINK_CABLE_ST       ; Are tones on the cable?
        jnz     SHORT cable_ok       ; Jump if yes

        loop    SHORT tones_loop

	mov	dx, offset no_lan_msg	; dx points to error msg
	push	dx

        jmp     SHORT LoginNodeFailed   ; Didn't hear tones within 500us

;******************************************************************************
; Down the link so our address can be trained
;******************************************************************************

cable_ok:
        call    DownLink
	jnc	linkdown_ok 	; if Downlink fails, simply reset the VG

	loadport
        setport LANCntrCfgVGReg             ; Get current value
        in      ax, dx

        and     ax, NOT VG_RESET                    ; Set bit to 0
        out     dx, ax
        or      ax, VG_RESET                        ; Set bit to 1
	out	dx, ax
        
linkdown_ok:
	loadport
;******************************************************************************
; load the cards MAC address and bring up the link.
;******************************************************************************
        setport	LANCntrCfgVGReg     ; Get current value
        in      ax, dx

        ; Turn on load address and link command

        or      ax, LOAD_ADDR or LINK_CMD
        out     dx, ax

;******************************************************************************
; Make sure the cable is hooked up, which is quick, before waiting the entire
; 15 seconds to see if the node logged into the hub.  It should normally
; take 250us. Wait a max of 500us.
;******************************************************************************
        mov     cx, 2500                ; 2500 loops of 200ns = 500us
LinkCableLoop:
;******************************************************************************
; Can the card hear tones(is cable attached?)
;******************************************************************************
        in      ax, dx
        test    ax, LINK_CABLE_ST       ; Are tones on the cable?
        jnz     SHORT LinkCableOK       ; Jump if yes

        loop    SHORT LinkCableLoop

	mov	dx, offset no_lan_msg	; dx points to error msg
	push	dx

        jmp     SHORT LoginNodeFailed   ; Didn't hear tones within 500us

LinkCableOK:
;******************************************************************************
; Wait for the endnode to login to the hub.  It should normally take a few
; milliseconds.  Wait a max of 15 seconds in worst case.
;******************************************************************************
        mov     ax, 545                         ; 545 loops of 27.5ms = ~15sec
	call	set_timeout
LinkUpLoop:

;******************************************************************************
; Check to see if the link is up
;******************************************************************************
        in      ax, dx
        and     ax, LINK_UP_ST or LINK_GOOD_ST
	mov	bx, ax				; save for error analysis
        xor     ax, LINK_UP_ST or LINK_GOOD_ST
        jz      SHORT LoginNodeExit

;******************************************************************************
; Wait for timeout
;******************************************************************************
        call    do_timeout
        jnz     SHORT LinkUpLoop       ; Jump if haven't looped max time

	; if we get here, we failed either LINK_UP_ST or LINK_GOOD_ST

	test	bx, LINK_GOOD_ST
	jnz	bad_up_st
	mov	dx, offset no_100_train_msg
	push	dx
	jmp	LoginNodeFailed

bad_up_st:
	mov	dx, offset no_100_frame_msg
	push	dx

LoginNodeFailed:
;******************************************************************************
; Down the link so our a 0 address can be trained
;******************************************************************************
        call    DownLink

UpLinkWith0:
;******************************************************************************
; Switch to MAC control page
;******************************************************************************
	loadport
        SWITCH_PAGE     MAC_CONTROL_PAGE        ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Bring the link up with an address of 0.
;******************************************************************************

        setport LANCntrCfgVGReg     ; Get current value
        in      ax, dx

;******************************************************************************
; Set LOAD_ADDR and PROM_MODE bits to 0.  i.e. Tell hub our address is 0 and
; disable promiscuous mode.  Setting the address to 0 will tell the hub not
; to send any packets. Bring up with 0 address so the LEDs still work.
;******************************************************************************
        and     ax, NOT (LOAD_ADDR or PROM_MODE)

;******************************************************************************
; Tell the card to start training.  The driver isn't going to wait around
; since it shouldn't matter if it succeeds or fails.
;******************************************************************************
        or      ax, LINK_CMD
        out     dx, ax

        stc			; indicate failure
	pop	dx		; recover error message

LoginNodeExit:
        ret

	public	start_interface
;******************************************************************************
;                                                                             *
;                          start_interface                                    *
;                                                                             *
; PURPOSE:     Enable TX, RX and Interrupts				      *
;                                                                             *
; PARAMETERS:                                                                 *
;       ON ENTRY:                                                             *
;       DS      - CGroup.                                                     *
;       Int     - Disabled.                                                   *
;                                                                             *
;       ON EXIT:                                                              *
;       Successful:                                                           *
;       carry flag is clear                                                   *
;       Card is active on the network.                                        *
;	Page is set to PERFORMANCE_PAGE (except on REVA)                      *
;                                                                             *
;       Unsuccessful:                                                         *
;       carry flag is set						      *
;                                                                             *
;       All registers may be destroyed.                                       *
;                                                                             *
; SIDE EFFECTS & CAVEATS:                                                     *
;       Assumes hardware ISR is hooked and driver is ready to go              *
;                                                                             *
; ALGORITHM:   								      *
;       Take card out of reset                                                *
;	Setup MAC Modes                                                       *
;       Enable the receiver and transmitter                                   *
;       Set card to operating page                                            *
;       Enable interrupts                                                     *
;       Take interrupts out of tri-state                                      *
;									      *
;******************************************************************************

start_interface:
;******************************************************************************
; Take card out of reset
;******************************************************************************
	loadport
        UNRESET_CARD                    ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Set up the MAC modes to current state.
;******************************************************************************
        SWITCH_PAGE     MAC_CONTROL_PAGE        ; Modifies DX/AX, DS->CGroup
	setport MACConfiguration2Reg
	mov	al, mac2mode
	out	dx, al
	setport MACConfiguration1Reg
	in	al, dx
	and	al, MAC1MODEMASK
	or	al, mac1mode
	out	dx, al

;******************************************************************************
; Enable the transmitter and receiver.
;******************************************************************************
        mov     ax, rxtxmode  		; Enable both Rx and Tx if enabled
        call    EnableRxTx              ; Changes page
        jc      SHORT entxrxerr

;******************************************************************************
; Set card paging register to operating page.
;******************************************************************************

	loadport
IFDEF REVA
    	SWITCH_PAGE     ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
ELSE; NOT REVA
	SWITCH_PAGE	PERFORMANCE_PAGE
ENDIF; NOT REVA

;******************************************************************************
; Enable interrupts
;******************************************************************************
        setport	OptionLSWReg
        mov     ax, INT_EN or SET_LB    ; Set bit to 1
        out     dx, ax


;******************************************************************************
; UnTri-state the interrupts.
;******************************************************************************
        mov     ax, TRI_INT or RESET_HB ; Set bit to 0
	out     dx, ax

;******************************************************************************
; clear carry for success
;******************************************************************************
        clc
	ret

entxrxerr:

	loadport
IFDEF REVA
    	SWITCH_PAGE     ID_MAC_ADDRESS_PAGE     ; Modifies DX/AX, DS->CGroup
ELSE; NOT REVA
	SWITCH_PAGE	PERFORMANCE_PAGE
ENDIF; NOT REVA

	stc			; indicate error
        ret

	public DownLink
;******************************************************************************
;                                                                             *
;                              DownLink                                       *
;                                                                             *
;                                                                             *
; PURPOSE:     Takes down the VG link.                                        *
;                                                                             *
; PARAMETERS:                                                                 *
;       ON ENTRY:                                                             *
;       DS      - CGroup.                                                     *
;       Int     - Disabled.                                                   *
;                                                                             *
;       ON EXIT:                                                              *
;       Successful:                                                           *
;       C flag - Clear.                                                       *
;                                                                             *
;       Unsuccessful:                                                         *
;       C flag - Set.                                                         *
;       All registers may be destroyed.                                       *
;                                                                             *
; SIDE EFFECTS & CAVEATS:                                                     *
;       Hardware page is set to a non-PERFORMANCE_PAGE.                       *
;                                                                             *
; ALGORITHM:   								      *
;       Switch to the MAC_CONTROL_PAGE page                                   *
;       Bring the link down                                                   *
;       Wait up to 500ms for the LINK_UP_ST, LINK_CABLE_ST, and LINK_GOOD_ST  *
;         bits to go to 0(link down).                                         *
;       If link went down, clear C flag                                       *
;       Else, set C flag                                                    *
;									      *
;******************************************************************************

DownLink:

;******************************************************************************
; Switch to MAC control page
;******************************************************************************
	loadport
        SWITCH_PAGE     MAC_CONTROL_PAGE        ; Modifies DX/AX, DS->CGroup

;******************************************************************************
; Get current state of VG MAC.
;******************************************************************************
        setport LANCntrCfgVGReg
        in      ax, dx

;******************************************************************************
; Bring the link down.  
;******************************************************************************
        and     ax, NOT LINK_CMD
        out     dx, ax
        
;******************************************************************************
; Wait for the link to come down.  Wait a max of 550ms.  The normal time
; should be arount 500us.
;******************************************************************************
        mov     ax, 20                          ; 20 loops of 27.5ms
	call	set_timeout
	loadport
        setport LANCntrCfgVGReg
LinkDownLoop:

;******************************************************************************
; Check to see if the link went down.
;******************************************************************************
        in      ax, dx
        test    ax, LINK_UP_ST or LINK_CABLE_ST or LINK_GOOD_ST ; Did it go down?
        jz      SHORT LinkDown                  ; Jump if yes

;******************************************************************************
; Wait for timeout
;******************************************************************************
	push	dx
        call    do_timeout
	pop	dx
        jnz     SHORT LinkDownLoop       ; Jump if haven't looped max time

;******************************************************************************
; Set failure flag since link didn't go down
;******************************************************************************
        stc
	ret

LinkDown:

	clc
        ret


;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte


	public	usage_msg
IFDEF HP_PROD
usage_msg	db	"usage: hpfepkt [options] <packet_int_no> [slot|io_addr]",CR,LF,'$'
ELSE ;NOT HP_PROD
usage_msg	db	"usage: att2md01 [options] <packet_int_no> [slot|io_addr]",CR,LF,'$'
ENDIF ;HP_PROD

	public	copyright_msg
IFDEF HP_PROD
copyright_msg	db	"Packet driver for HP 10/100 Megabit LAN Adapters, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
ELSE ;NOT HP_PROD
copyright_msg	db	"Packet driver for ATT 2MD01 Chip 10/100 Megabit LAN Adapters, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
ENDIF ;HP_PROD
		db	"Portions Copyright 1994, Hewlett-Packard Company",CR,LF,'$'

no_board_msg	db	"No 10/100 Megabit LAN card detected.",CR,LF,'$'
io_addr_bad_msg	label	byte
		db	"Invalid Slot or Address Specified",CR,LF,'$'
no_network_msg	db	"Check network connector - no network connection detected.",CR,LF,'$'
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
mem_addr_name	db	"Memory address ",'$'
con_10_tp_msg	db	"10 Megabit Twisted Pair Network Detected",CR,LF,'$'
con_100_vg_msg  db  "100 Megabit Voice Grade Network Detected",CR,LF,'$'
no_lan_msg 	db  "No LAN connection detected, check connector",CR,LF,'$'
no_100_train_msg db  "100 Megabit cable training failed, check cable",CR,LF,'$'
no_100_frame_msg db  "100 Megabit node not accepted by hub, check frame type or security",CR,LF,'$'
multi_board_msg db  "Multiple LAN cards detected, please specifiy slot or io_addr",CR,LF,'$'
IFDEF HP_PROD
eid_cksum_msg	db	"Card ID (EISA ID) Checksum Failed",CR,LF,'$'
eid_unsup_msg	db	"Card found is not supported by this driver revision",CR,LF,'$'
eid_newver_msg	db	"Card version found is newer than those supported by this driver revision",CR,LF,'$'
pre_rel_card	db      "Unsupported pre-release HP adapter found, "
		db	"please return to HP",CR,LF,'$'
ENDIF ;HP_PROD
mac_cksum_msg	db	"Card MAC Address Checksum Failed",CR,LF,'$'
mem_cfg_msg	db	"Card memory map config invalid for packet driver",CR,LF,'$'
mac_no_stop_msg db	"Card TX or RX did not stop, run diagnostics",CR,LF,'$'
irq_chg_msg	db	"Card IRQ Changed, suspect conflicting uses",CR,LF,'$'
eeprom_fail_msg	db	"Card registers failed to load from EEPROM",CR,LF,'$'
no_start_msg	db	"Card failed to initialize",CR,LF,'$'

IFDEF HP_PROD
; Card Specific Tables

card_table_size	dw	5

; Card types are the index into the following tables,
;   Current card types are:
;	0	HPJ2577_TYPE_REVA  10/100 EISA card with REVA Cascade Chip
;	1	HPJ2573_TYPE_REVA  10/100 ISA card with REVA Cascade Chip
;	2	HP27248B_TYPE 10 only EISA card with Cascade Chip
;	3	HPJ2577_TYPE 10/100 EISA card with Cascade Chip
;	4	HPJ2573_TYPE 10/100 ISA card with Cascade Chip


; Card ID is an array of EISA IDs, search this table to determine card type.
; Word 2 of each entry is a flag (0) that the card is supported officially, or
; a pointer to an error message.

card_id			dd	HPJ2577_REVA_EID
			dw	OFFSET pre_rel_card
			dd	HPJ2573_REVA_EID
			dw	OFFSET pre_rel_card
			dd	HP27248B_EID
			dw	OFFSET no_board_msg
       			dd	HPJ2577_EID
			dw	0
			dd	HPJ2573_EID
			dw	0

; card_sw_rev is the highest software model known by the driver for this
; card type. Driver will support this and all lower software models

card_sw_rev		db	0
ENDIF ;HP_PROD

; Init code temporary variables

eisa_srch		db	0
tmp_io_addr		dw	0
save_page		dw	?
eisa_id			dd	?
				db	?		; extra room for the checksum

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

	mov	di,offset io_addr
	call	get_number

	push	si

	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board
	
;
; If address specified is less than 0100h, assume it is a slot number
; on an EISA bus, and convert to an IO address. Allow user to supply
; any slot between 1 and 15, or and address between 100 and 3FF or EISA
; address between 1000 and FFFF. For non-standard addresses, mask and
; set bits to establish the correct address with the same most significant
; bits as the user supplied.
;
	cmp	io_addr, 0100h
	jae 	addr_not_slot

	cmp 	io_addr, 16
	jae 	bad_addr
	
	; convert slot to eisa address
	
	mov	ax, io_addr
	shl	ax, 12
	mov	io_addr, ax

addr_not_slot:
	cmp 	io_addr, 01000h
	jae 	eisa_addr
	cmp 	io_addr, 03ffh
	ja 	bad_addr
	
	; Make the address a valid ISA address
	
	mov 	ax, io_addr
	and	ax, NOT 03Fh
	mov 	io_addr, ax
	jmp	addr_cnvrted
	
eisa_addr:
	cmp 	io_addr, 0ffffh
	ja 	bad_addr
	cmp 	is_eisa, 0
	jz 	bad_addr

	; Make the address a valid EISA address
	
	mov 	ax, io_addr
	and	ax, NOT 0FFFh
	or	ax, 0C38h
	mov 	io_addr, ax

addr_cnvrted:
	mov	tmp_io_addr, ax
	call	detect_board		; Check out the specified address.
	je	found_one

bad_addr:
	mov	dx,offset io_addr_bad_msg
	jmp	parse_args_err

	public find_board
;********************************************************************
; Find_Board search algorithm
;    Search ISA addresses,
;    IF EISA
;      Search EISA addresses
;    IF more than ONE board found, error out.

find_board:
	mov	io_addr,100h		;Search for the card
	mov	io_addr+2,0
find_board_0:
	call	detect_board
	je	find_board_found
find_board_again:
	cmp	eisa_srch, 0
	jnz 	eisa_incr
	add	io_addr,20h		;not at this port, try another.
	cmp	io_addr,400h
	jmp	isa_incr

eisa_incr:
	add 	io_addr, 01000h
	cmp 	io_addr, 00C38h
isa_incr:
	jne	find_board_0
	
	; At least one pass done, check for EISA
	
	cmp 	is_eisa, 0
	jz	no_eisa			;not an EISA PC, search done.
	cmp 	eisa_srch, 0
	jnz	no_eisa			; EISA and ISA searched, done
	
	inc	eisa_srch		; Here we are EISA, start EISA search
	mov	io_addr, 01C38h
	jmp 	find_board_0

no_eisa:
	cmp 	tmp_io_addr, 0			; Did we find a board?
	jnz	found_one

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	jmp	SHORT parse_args_err

find_board_found:
	cmp	tmp_io_addr, 0		; First or second board found?
	jz	first_board
	
	mov	dx,offset multi_board_msg ;Fail, multi boards user must specify
					  ;slot or address
	jmp	SHORT parse_args_err
	
first_board:				; Remember first board and keep searching
	mov	ax, io_addr
	mov 	tmp_io_addr, ax
	jmp 	find_board_again
	
found_one:
	mov	ax, tmp_io_addr
	mov	io_addr, ax
	
IFDEF HP_PROD
	call 	check_board
	jc	parse_args_err
ELSE ;NOT HP_PROD	

; Read and save IRQ
;
;  WARNING! Will Robinson, Danger approches!
;    This driver reads the required IRQ from the card registers, and
;    does not use (or allow) command line input of card IRQ.
;    Since the driver does not 'own' the card until after etopen called
;    (delayed open option allowed) it is possible that the IRQ read here
;    is incorrect if it has been changed by other software. The only way
;    to be sure that the correct IRQ is here is to reset the card and
;    reload from EEPROM, which the driver can't do here. Must ASSUME IRQ
;	 is valid and re-check in etopen. If mismatch in etopen, fail that call.
;    If delayed open option (-d) selected that etopen will fail silently.
;    It would be nice to defer reading IRQ from the card until etopen, but
;	 the driver initialize code in tail.asm requires int_no be filled in now.

; NOTE! Interrupts OFF while page switched as someone (boot ROM?) may be currently
;       using this card.

	pushf				; save current interrupt flag
	cli					; interrupts off here
	loadport
	setport PagingReg
	in	ax, dx			; read current paging register
	mov 	save_page, ax	; and save
	mov	ax, HARDWARE_MAP_PAGE
	out 	dx, ax			; switch to EISA ID and MAC address page
	
	loadport
	setport	IRQChannelReg			;get the IRQ Channel
	in	al, dx
	and	al, IRQ_MASK
	mov	int_no, al

	setport PagingReg
	mov	ax, save_page
	out 	dx, ax
	popf			; restore interupt flag

ENDIF ;NOT HP_PROD

	pop		si
	clc
	ret

parse_args_err:
	mov	ah,9					  ;print error message
	int	21h
	pop		si
	stc
	ret

	public	etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.  Exit with nc if all went well, or cy, dx -> $ terminated error msg.

; Note: rom_address filled in at find card time.

; Algorithm to reset and open ATT2MD01 based 10/100 VG cards
;   
;   Stop the card
;   Command the EEPROM to load the ATT2MD01 chip
;	Read, checksum and save the MAC address
;   Confirm IRQ read earlier.
;	Setup the option registers to defaults
;   Disable bus mastering
;	Take card out of reset
;	Figure out which IO mode to use and setup block transfer pointers
;	Set card interrupt mask and ack any interrputs
;	Initialize the card MMU
;	Figure out whic LAN to use to establish MAC parameters
;	Initialize the card MAC

; Interrupts off until we disable card interrupts (just incase some other
; card driver is also active)
	
	cli
	call	stop_interface
	jc	eto_no_stop
	call	re_enable_interrupts
	jmp	eto_stop_ok
	
eto_no_stop:
	call 	re_enable_interrupts
	mov	dx, offset mac_no_stop_msg
	stc
	jmp	eto_exit
	
eto_stop_ok:

	loadport
	RESET_CARD
	
	call 	load_eeprom
	jc	eto_eeprom_fail
	jmp 	eto_eeprom_ok
	
eto_eeprom_fail:
	mov	dx, offset eeprom_fail_msg
	jmp	eto_exit
	
eto_eeprom_ok:

; set the option registers to defaults

	call 	setoptdefaults

; Enable Bus Mastering here if configured on card (LATER...)

IFDEF HP_PROD

; read, checksum and save the MAC Address
; NOTE: if the card moved due to the previous EEPROM Load,
;       this should fail.

	loadport
	SWITCH_PAGE ID_MAC_ADDRESS_PAGE
	setport PhysicalLANAddressReg
	xor	bl, bl
	movseg	es, cs
	mov	di, offset rom_address
	mov	cx, 7			;6 bytes of address + 1 checksum byte
eto_ck_mac_lp:
	in	al, dx
	add	bl, al
	stosb
	inc	dx
	loop	eto_ck_mac_lp
	cmp	bl, 0ffh			;Is checksum good??
	jnz	eto_cksum_mac_fail		;NO, exit
	jmp	eto_mac_ck_ok

eto_cksum_mac_fail:
	mov	dx, offset mac_cksum_msg
	stc
	jmp	eto_exit

eto_mac_ck_ok:

ELSE; NOT HP_PROD

; read the MAC address

	loadport
	SWITCH_PAGE ID_MAC_ADDRESS_PAGE
	setport PhysicalLANAddressReg
	movseg	es, cs
	mov	di, offset rom_address
	mov	cx, 6			;6 bytes of address
eto_mac_lp:
	in	al, dx
	stosb
	inc	dx
	loop	eto_mac_lp

ENDIF; NOT HP_PROD

; Program the MAC address and default Hash table entries

	loadport
	SWITCH_PAGE MAC_ADDRESS_PAGE
	setport	MACAddressReg
	mov	cx, EADDR_LEN
	mov	si, offset rom_address

eto_mac_loop:
	outsb
	inc	dx
	loop	eto_mac_loop

	loadport
	setport HashByte0Reg
	mov	cx, 8
	mov	si, offset mcast_list_bits

eto_hash_loop:
	outsb
	inc	dx
	loop	eto_hash_loop

; Verify previous IRQ read
	
	loadport
	SWITCH_PAGE HARDWARE_MAP_PAGE
	setport	IRQChannelReg			;get the IRQ Channel
	in	al, dx
	and	al, IRQ_MASK
	cmp	int_no, al
	jnz	eto_irq_chg
	jmp	eto_irq_ok
	
eto_irq_chg:
	mov	dx, offset irq_chg_msg
	stc
	jmp	eto_exit

eto_irq_ok:

; Get the block memory transfer method, regular I/O, memory mapped I/O, or
; Bus master (read or write or both).
	
; Preload I/O mode block move pointers
	
	mov	bx, offset io_input_286
	mov	cx, offset io_output_286
	cmp	is_386, 0
	jz	eto_286_0
	mov	bx, offset io_input_386
	mov	cx, offset io_output_386
eto_286_0:
	mov	block_input_ptr, bx
	mov	block_output_ptr, cx

	setport OptionLSWReg
	in	ax, dx
	mov	bx, ax
	test	bx, MEM_EN
	jz	eto_no_mem_en

; Memory Map I/O enabled, set it up.	

	setport	MemMapMSWReg		;get the high memory map location
	in	ax, dx
	mov	cx, ax				; save in bx
	and	ax, NOT 000Fh		; verify below 1 Meg
	jnz	eto_bad_mem_cfg
	setport	MemMapLSWReg		;get the low memory map location
	in	ax, dx
	and	ax, 0e000h		; paranoia force 8K alignment
	shr	ax, 4			;make into a segment address
	shl	cx, 12
	or	ax, cx
	mov	mem_addr, ax
	inc	memory_mapped
	mov	ax, offset mem_input_286 	; Overwrite block move pointers
	mov	cx, offset mem_output_286
	cmp	is_386, 0
	jz	eto_286_1
	mov	ax, offset mem_input_386
	mov	cx, offset mem_output_386
eto_286_1:
	mov	block_input_ptr, ax
	mov	block_output_ptr, cx

; Right here we should do a cache check using the card to verify that
; data in and out transfers using memory mapped I/O work in this PC.
; However, since the debug register is broken in REVA ATT2MD01 chips,
; skip that check for now.
	
	jmp	eto_no_mem_en

eto_bad_mem_cfg:
	mov	dx, OFFSET mem_cfg_msg
	stc
	jmp	eto_exit

eto_no_mem_en:
	test	bx, BM_WRITE
	jz	eto_no_bm_write
	mov	ax, offset bm_input
	mov	block_input_ptr, ax
	inc	bm_write_fl

eto_no_bm_write:
	test	bx, BM_READ
	jz      eto_no_bm_read
	mov	ax, offset bm_output
	mov	block_output_ptr, ax
	inc	bm_read_fl
	
eto_no_bm_read:

	loadport
	SWITCH_PAGE PERFORMANCE_PAGE
	setport	InterruptStatusReg
	mov	ax, 0FFFFh
	out	dx, ax				; Ack all bits
	
	setport InterruptMaskReg
	mov	ax, 0FEFEh
	out	dx, ax				; Mask off all ints
	mov	ax, (RX_PACKET or RX_ERROR or SET_HB) or (TX_ERROR or SET_LB)
	out	dx, ax				; and enable a few

; Set the MMU up to default values

	call 	set_mmu_default
	
; Figure out which LAN to use

	call 	sense_lan
	
	mov	al, lan_type
	cmp	al, LAN_100		; If on 100BaseVG, must login
	jnz	eto_set_recv_isr	; to the hub

	call	login100vghub		; returns dx->errmsg + carry if fails

        jnc     eto_set_recv_isr
	jmp     eto_exit

eto_set_recv_isr:

	pushf			; save interrupt state
	cli			; interrupts off, prevent chicken & egg
				; problems with starting card and hooking
				; interrupt

	call	set_recv_isr		; Put ourselves into the interrupt chain

	; convert the IRQ into an interrupt number

        mov     al, int_no              ; Get board's interrupt vector
        add     al, 8
        cmp     al, 8+8                 ; Is it a slave 8259 interrupt?
        jb      set_int_num             ; No.
        add     al, 70h - 8 - 8         ; Map it to the real interrupt.
set_int_num:
        xor     ah, ah                  ; Clear high byte
        mov     int_num, ax             ; Set parameter_list int num.

eto_start_card:

	call	start_interface
	
	; start_interface sets the card into it's operating mode
	; so besure the driver ISR is ready to go before calling
	; start interface, and don't muck with the card without
	; interrupts off from here on out.

	jnc	eto_done

	popf			; recover interrupt state
	stc			; indicate error
	mov	dx, offset no_start_msg
	jmp	SHORT eto_exit

eto_done:
	popf		; recover interrupt state
	clc		; indicate no error

eto_exit:
	ret


	public	print_parameters
print_parameters:
;echo our command-line parameters
	assume	ds:code

	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	cmp	memory_mapped,0
	je	print_parameters_1
	mov	di,offset mem_addr
	mov	dx,offset mem_addr_name
	call	print_number

print_parameters_1:
	mov	al, lan_type
	cmp	al, LAN_100		; print lan connection
	jz	pp_100
	mov	dx, offset con_10_tp_msg
	jmp	pp_con

pp_100:
	mov	dx, offset con_100_vg_msg

pp_con:
	mov	ah, 9
	int	21h

	ret

	public detect_board
detect_board:
;see if this adapter is an ATT2MD01 Chip based board.
;exit with z flag set if adapter is at io_addr,
;z flag clear if not        

;
;	Check Hardware Family ID bytes
;
	loadport	

    	in      al, dx                  ; Read in first byte of the ID
    	cmp     al, HW_ID_0             ; Does it match?
    	jne     SHORT detect_board_exit      ; Jump if it doesn't match

    	inc     dx                      ; Read in second byte of the ID
    	in      al, dx 
    	cmp     al, HW_ID_1             ; Does it match?
    	jne     SHORT detect_board_exit      ; Jump if it doesn't match
     
    	inc     dx                      ; Read in third byte of the ID
    	in      al, dx 
    	and     al, 0F0h                ; Lower nibble isn't pard of ID
    	cmp     al, HW_ID_2_REVA        ; Does it match?
    	jne     SHORT detect_board_exit      ; Jump if it doesn't match
        
    	inc     dx                      ; Read in fourth byte of the ID
    	in      al, dx 
    	cmp     al, HW_ID_3             ; Does it match?
    	
    ; final cmp will leave Z set if good

detect_board_exit:
	ret

IFDEF HP_PROD
;***********************************************************************
; Check_Board verifies that the found board is one we can talk to by
; checking the EISA ID and checksum.
; NOTE: when the pages are swapped, interrupts must be off, and the
;       current page must be restored. This is because we don't 'own'
;       the card until after etopen is called, some bootrom may be 
;       using it.
; Check board returns nc if board is OK and initializes several
; variables. If board does not check out, check_board returns cy
; and points dx at an appropriate error message.
;
;***********************************************************************
	public check_board
check_board:
	loadport
	setport PagingReg
	
	pushf				; save current interrupt flag
	cli					; interrupts off here
	in	ax, dx			; read current paging register
	mov 	save_page, ax	; and save
	mov	ax, ID_MAC_ADDRESS_PAGE
	out 	dx, ax			; switch to EISA ID and MAC address page
	
	setport BoardIDReg
    	mov     cx, 5                   ; 4 bytes of EISA ID + checksum byte
    	mov     ah, 0                   ; Initialize checksum value
	mov	bx, OFFSET eisa_id
cb_cksum_eid_loop:
    	in      al, dx                  ; Read in next byte of EISA ID
    	add     ah, al                  ; Add it to checksum value
    	mov	BYTE PTR [bx], al
    	inc	bx
    	inc     dx                      ; Get value from next EISA ID reg
    	loop    SHORT cb_cksum_eid_loop

    	cmp     ah, 0FFh                        ; Is checksum OK?
    	jne     SHORT cb_cksum_eid_fail      ; Jump if not
    
; Search EISA ID table for supported card ID

	mov	cx, card_table_size
	mov	si, OFFSET card_id
	xor	bx, bx				; bx contains card ID
	mov	card_type, bl

cb_id_loop:	
	mov	di, OFFSET eisa_id
	mov	ax,	[di]
	cmp	ax, [bx + si + 0]
	jnz	cb_id_le
	mov	ax, [di + 2]
	cmp	al, [bx + si + 2]
	jnz	cb_id_le
	
; Upper nibble of last byte of EISA ID is part of the ID, lower nibble is the
; care revision level. Last byte is in AH.

	mov	al,	[bx + si + 3]
	push	ax
	and	ax, 0f0f0h
	cmp	ah, al
	pop	ax
	jz	cb_id_ok

cb_id_le:
	add	bx, 6			; 6 bytes per ID
	inc	card_type
	loop	cb_id_loop
	
; Failed to find a card this driver supports

	mov	dx, OFFSET eid_unsup_msg
	jmp	SHORT cb_err_exit
	

cb_id_ok:
	; first check for unsupported ATT2MD01 versions

IFNDEF PRE_REL
	mov	dx,	[bx + si + 4] ; ZERO or pointer to error message
	or	dx, dx
	jnz	cb_err_exit
ENDIF

        ; Check card version (EISA ID last byte, low nibble)

	and	ax, 0f0fh
	cmp	ah, al
	jbe	cb_ver_ok
	
	mov	dx, OFFSET eid_newver_msg
	jmp	SHORT cb_err_exit

; Check software Model byte here when it finally gets defined,
; for now just save it away.

cb_ver_ok:
	loadport
	setport	SoftwareModelReg
	in	al, dx
	mov	card_sw_model, al

; Read and save IRQ
;
;  WARNING! Will Robinson, Danger approches!
;    This driver reads the required IRQ from the card registers, and
;    does not use (or allow) command line input of card IRQ.
;    Since the driver does not 'own' the card until after etopen called
;    (delayed open option allowed) it is possible that the IRQ read here
;    is incorrect if it has been changed by other software. The only way
;    to be sure that the correct IRQ is here is to reset the card and
;    reload from EEPROM, which the driver can't do here. Must ASSUME IRQ
;    is valid and re-check in etopen. If mismatch in etopen, fail that call.
;    If delayed open option (-d) selected that etopen will fail silently.
;    It would be nice to defer reading IRQ from the card until etopen, but
;    the driver initialize code in tail.asm requires int_no be filled in now.

	SWITCH_PAGE HARDWARE_MAP_PAGE

	setport	IRQChannelReg			;get the IRQ Channel
	in	al, dx
	and	al, IRQ_MASK
	mov	int_no, al

;   done

	jmp	SHORT cb_exit

cb_cksum_eid_fail:
	mov	dx, offset eid_cksum_msg

cb_err_exit:

	push	dx
	loadport
	setport PagingReg
	mov	ax, save_page
	out 	dx, ax
	pop	dx
	popf			; restore interupt flag
	stc
	ret

cb_exit:

	loadport
	setport PagingReg
	mov	ax, save_page
	out 	dx, ax
	popf			; restore interupt flag
	clc
	ret
ENDIF ;HP_PROD

	public	load_eeprom
load_eeprom:
;
; Toggle EEPROM_LOAD from 0 to 1
; Wait at least 600uS for EE_LOAD bit to set
;	return carry bit set on failure
; return carry bit clear
;

	loadport
	SWITCH_PAGE EEPROM_CONTROL_PAGE
	setport	EEPROMControlReg	; Toggle EEPROM_LOAD bit
	in	ax, dx
	and	ax, NOT EEPROM_LOAD
	out	dx, ax
	or	ax, EEPROM_LOAD
	out	dx, ax

; watch for EE_LOAD to clear

	setport OptionMSWReg
	clc									; preset success
	mov	cx, 6000		; 1.2 Ms is too long
	
load_ee_loop:
	in	ax, dx
	test	ax, EE_LOAD
	jz	load_ee_exit
	loop	load_ee_loop
	
; failed if we fall through here

	stc									; indicate failure

load_ee_exit:
	ret

	public	setoptdefaults
setoptdefaults:
;
; Set option registers to the following defaults:
;
;	memnonic   (reg)bit    val	   meaning
;	DEBUG_EN     1  15	0 	Disable debug dump
IFDEF HP_PROD
;	RX_HDR	     1  14	0	Disable early pkt rx in BM mode
ELSE; NOT HP_PROD
;	RES_14	     1  14	0	Disable early pkt rx in BM mode
ENDIF; NOT HP_PROD
;	MMAP_DIS     1  13	1	Disable Memory Map I/O	
;	EE_EN	     1  12	0	Disable EEPROM write
;	IO_EN	     1   5	1	Enable IO mode I/O
;	FAKE_INT     1 	 3	0	Disable forced interrupt
;	PRIORITY     2   7	0	Disable global priority TX
;	ADV_NXT_PKT  2	 2	0	Don't advance
;	TX_CMD	     2   1	0	Don't TX now
;

	loadport
	setport OptionLSWReg
	mov	ax, (MMAP_DIS or SET_HB) or (IO_EN or SET_LB)
	out	dx, ax
IFDEF HP_PROD
	mov     ax, (DEBUG_EN or RX_HDR or EE_EN or RESET_HB) or (FAKE_INT or RESET_LB)
ELSE; NOT HP_PROD
	mov     ax, (DEBUG_EN or RES_14 or EE_EN or RESET_HB) or (FAKE_INT or RESET_LB)
ENDIF; NOT HP_PROD
	out	dx, ax
	setport OptionMSWReg
	mov	ax, PRIORITY_TX or ADV_NXT_PKT or TX_CMD or RESET_LB
	out	dx, ax
	ret
	
	public set_mmu_default
set_mmu_default:

; Find amount of memory on card
; Divide it up by the rx_ratio
; Set RxMemoryStopReg to that value
; Set TxMemoryStopReg to mem max - 16 bytes for slave mode
;   or (mem max - PDL storage) for bus master
        
; Find out how much memory on card

	loadport
	SWITCH_PAGE HARDWARE_MAP_PAGE 

    	setport SRAMReg             ; Reg that hold RAM size
    	in      al, dx                  ; Read in index of RAM size
    	and     ax, 0E0h                ; Mask everything but size
    	shr     ax, 5                   ; Shift down to an integer
    	mov     cl, al                  ; Move into cl for shift

; Possible values are 200, 400, 800, 1000, 2000, 4000, 8000, 10000h.
; Values are missing the four least significant bits since the stop
; registers don't have these bits anyway. The last value (10000h) is
; rolled down to 0ffffh to fit in 16 bits. The lost memory is not
; significant.

    	mov     ax, 200h		; load base value
    	shl	ax, cl			; shift for actual
	
; Special case the 10000 value

	cmp	ax, 0
	jnz	mmu_0
	dec	ax

mmu_0:
	push	ax			; save for later
	
; Calculate the RX stop value

	xor	cx, cx
	mov	cl, rx_ratio
	mul	cx
	mov	cx, 100
	div	cx
	
; Switch to MMU page and set the end of the RX ring

	mov	bx,	ax
	loadport
	RESET_CARD		; card must be in reset to program MMU
	SWITCH_PAGE MMU_CONFIG_PAGE
	mov	ax, bx
	setport RxMemoryStopReg
	out	dx, ax
	
; Calculate and write the Tx Stop

	setport TxMemoryStopReg
	pop	ax
	dec	ax		; lose 16 more bytes, can't point at actual
				; end of memory
	out	dx, ax
	
; Done

	UNRESET_CARD		; to activate new MMU program
	ret
	
code	ends
	end
