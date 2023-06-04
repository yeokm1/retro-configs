	include	defs.asm
	include	tpropkt.inc
	include	tpropkti.mac

code	SEGMENT	word public
	assume	cs:code, ds:code

	even

extrn	sys_features : byte

if ROUTING eq 1 
	include	cache.inc
	public	cache_memory, cache_head
cache_memory:
	rept	NO_CACHE_ENTRIES
	db		SIZE cache_entry dup (?)
	endm
fake_rif	cache_entry <,,,FAKE_ROUTE,>
cache_head	dw	cache_memory
endif

	public	tx_buff_no, buff_ptrs, rx_buff_ptr
tx_buff_no		dw	?	; The next Tx buffer to use
buff_ptrs		dw	TX_BUF_CNT dup (?)
rx_buff_ptr		dw	?	; Start of receive buffer.
next_rx_ptr		dw	?	; Points to the end of the receiver buffer
						;  i.e. the start of the next receive buffer
	public	inw_routine, outw_routine, repins, repouts
inw_routine		dw	?	; Address of subroutine to read in a word
outw_routine	dw	?	; Address of subroutine to write out a word
repins			dw	?	; Address of subroutine to do multiple word reads
repouts			dw	?	; Address of subroutine to do multiple word writes

tx_hdr_buff		dw	(TOKEN_HDR_SIZE + ROUTE_INFO_SIZE + DATA_IN_HEADER)/2

; a temp buffer for the received header
; needs to be 8 header bytes + 2 ethernet address bytes + 2 type bytes
;    plus some room for IEEE802.3  bytes
MIN_RX_DATA_SIZE	EQU 2*EADDR_LEN + 2 + 6 	; 2 ids @6 + type @2 + 6
RCV_HDR_SIZE	EQU	 RBUF_HEAD_LEN + TOKEN_HDR_SIZE + ROUTE_INFO_SIZE  + \
													MIN_RX_DATA_SIZE
rcv_hdr			db	RCV_HDR_SIZE dup(0)
add_buff		db	EADDR_LEN dup(0)

	public	int_no, io_addr, base_addr, which_int, int_swap
int_no		db	3,0,0,0		;must be four bytes long for get_number.
io_addr		dw	0,0			; I/O address specified on the command line
base_addr	dw 	0000h		; I/O address as located via the I/O scan

which_int	db	0			; which packet interrupt is currently active
							; 0 - Ethernet non-zero = IEE802.5
int_swap	db	0			; non-zero if default interrupt order is swapped

	public	driver_class, driver_type
	public	driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK,IEEE8023,0	;null terminated list of classes.
if PKT_INTS	eq 2
	public	driver2_class
driver2_class	db	IEEE8025,0	;null terminated list of classes.
endif

	driver_type	db	0FFh		; from the packet spec
	driver_name	db	"Token Pro"	; name of the driver.

driver_function	db	2

	public	int_num
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

;-> current address
	extrn	my_address: byte

received_ours	db	0
	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	0
		dw	rcv_mode_2
		dw	rcv_mode_3
		dw	0
		dw	0 ;		dw	rcv_mode_5		; Multi-cast mode not available
		dw	rcv_mode_6

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


send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret
	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
	cmp		byte ptr which_int, 0	; Check if being called by the Ethernet int
	jne		check_token_length		; No - do the token length checks
	cmp		cx, GIANT			; Is this packet too large?
	ja		send_pkt_toobig
	cmp		cx, RUNT			; Minimum length for Ether
	jae		oklen
	mov		cx, RUNT			; Make sure size at least RUNT
	jmp		SHORT oklen
check_token_length:
	cmp		cx, TOKEN_GIANT		; Is this packet too large?
	ja		send_pkt_toobig
	cmp		cx, TOKEN_RUNT		; Minimum length for Ether
	jae		oklen
	mov		cx, TOKEN_RUNT		; Make sure size at least TOKEN_RUNT
oklen:
; Get the next XT buffer address from the buff_ptr array
	mov		ax, tx_buff_no		; Get the next buffer # to use
	mov		bx, ax				; Make a copy
	inc		ax					; Advance the buffer #
	cmp		ax, TX_BUF_CNT		; Advanced too far ?
	jl		count_ok			; No - the next count is ok
	xor		ax, ax				; Next count will be zero
count_ok:
	mov		tx_buff_no, ax		; Store the updated buffer #
	sal		bx, 1				; Make bx a word count
	mov		ax, buff_ptrs[bx]	; Get the buffer address
	push	ax					; Store for later
; Setup the TX frame at the appropriate point in the TX area
	LOAD_BANK_PORT	BANK0, HOST_ADDRESS
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		ax, XMT_CMD			; The command to be obeyed
	outw
	xor		ax, ax
	outw						; Clear the status field
	outw						; No chaining of frames

	cmp		byte ptr which_int, 0	; Check if being called by the Ethernet int
	je		token_header_add	; If zero then need to add token header info
	mov		ax, cx				; Write the packet length
	outw
	jmp		write_packet_data	; Now just write out the packet

token_header_add:
	mov		bx, cx				; Save packet count
	mov		ax, cs
	mov		es, ax
	mov		di, offset tx_hdr_buff+TX_DEST_ADDR
	mov		cx, (2*EADDR_LEN)/2
	rep		movsw				; Copy destination & source addresses

	push	ds
	push	si
	mov		ax, cs
	mov		ds, ax

if ROUTING	eq	1
	mov		si, offset tx_hdr_buff+TX_DEST_ADDR
	extrn	locate_and_prioritize : near
	call	locate_and_prioritize ; See if destination address is in the cache
	jc		found_address_in_cache
	mov		di, offset fake_rif
found_address_in_cache:
	mov		si, di				; Save pointer to cache entry
	mov		ax, [di+route]
	and		ax, ROUTE_SIZE_MASK	; Size of the routing information
else
	xor		ax, ax				; Routing size is 0
endif

	add		ax, bx				; Packet size + routing length
	add		ax, TOKEN_HDR_SIZE	; Add length of header
	mov		di, offset tx_hdr_buff	; Pointer to the header buffer
	stosw						; Write the length into the header buffer
	mov		ax, LLC_FIELDS		
	stosw						; Write the control field into header buffer
	add		di, 2*EADDR_LEN		; Now di -> start of RIF info

if ROUTING eq 1
	or		byte ptr cs:[di-EADDR_LEN], RII_BIT
	add		si, route			; Now si -> the routing information in entry
	mov		cx, [si]			; Get 1'st word of routing info
	and		cx, ROUTE_SIZE_MASK	; Get length of RIF in words
	shr		cx, 1				; Will always be even
	rep		movsw				; Copy the RIF info
								; Change RIF direction
	xor		byte ptr tx_hdr_buff[TX_ROUTE+1], ROUTE_DIR_BIT
endif

	pop		si					; Recover the pointer to the user's data
	pop		ds					; si -> packet type bytes

	mov		ax, [si]			; Get the packet type
	xchg	ah, al
	cmp 	ax, 1500
	ja		BlueBookPacket
; Must be an IEE802.3 format packet - so copy the exisiting LLC info
	add		si, 02h				; Skip over the length field
	mov		cx, LLC_SIZE+ SNAP_SIZE+2 ; Include the last 2 type bytes
	rep		movsw				; Copy the LLC
	; Adjust the size of the packet - no additional header required and the two
	; Ctrl field bytes compensate for the two missing data length bytes
	sub		tx_hdr_buff, TOKEN_HDR_SIZE
	; bx = remaining bytes to copy
	sub		bx, TOKEN_HDR_SIZE + DATA_IN_HEADER
	jmp		SHORT	check_for_arp
	
BlueBookPacket:
	mov		ax, LLC_SSAP_DSAP	; build LLC portion
	stosw
	mov		al, LLC_CON
	stosb
	xor		ax, ax				; 3 bytes for Ptype in SNAP
	stosw
	stosb
	movsw						; Copy the type byte
	sub		bx, DATA_IN_HEADER	; Compensate for data included in the header
check_for_arp:
if ARP_CONVERSION	eq 1
	cmp		[si-2], ARP_TYPE		; Is this an ARP packet
	jne		not_arp
; Need to change the hardware field of the ARP data from 0001 to 0006
	add		si, 0002h			; Skip over the user's first word
	mov		ax, ARP_TX_FIX
	stosw
; debug
	; Some Token ring interfaces will not ARP to RUNT length packets
	; Modify the length in the hdr to be the true size of an ARP packet
	mov		ax, tx_hdr_buff+TX_ROUTE 	; Get length of RIF in words
	and		ax, ROUTE_SIZE_MASK			; Ignore all but size bits
	add		ax, ARP_PACKET_SIZE			; Add size of arp packet
	mov		WORD PTR tx_hdr_buff, ax	; Store the actual size
	mov		bx, ARP_LEFT_SIZE	; ARP length less data included in the header
	jmp		SHORT	done_arp_fix
endif

not_arp:
	movsw						; Copy (unmodified) the first data word
done_arp_fix:
	; Copy out the contents of the tx_hdr_buff
	mov		cx, di				; Points to the last entry in the header buffer
	mov		bp, ds				; Save SEG pointer to user data
	mov		di, si				; Save OFFSET pointer to user data
	mov		ax, cs				; Get the drivers segment into ds
	mov		ds, ax
	mov		si, offset tx_hdr_buff	; Pointer to the header buffer
	sub		cx, si				; CX now holds length of header
	call	repouts				; Write packet header
	mov		si, di				; Recover OFFSET pointer to user data
	mov		ds, bp				; Recover SEG pointer to user data
	mov		cx, bx				; Get modified length of original packet

; Write the contents of the packet.
write_packet_data:
	call	repouts				; Packet length is in CX

; Now check to see if the EXEC unit is ready for another XMIT command
	SET_BANK_PORT	BANK0, STATUS_REG
	mov		ax, 1
	call	set_timeout
wait_send:
	in		al, dx				; Get the exec unit status
	test	al, EXEC_STATUS		; Is the exec unit idle
	je		wait_send_done		; Yes - then we can proceed
	call	do_timeout
	jnz	wait_send
send_problem:
	pop		ax					; Clear from the stack the buffer start address
	mov		dh, CANT_SEND		; Indicate an error.
	stc
	ret

; Need to load the transmit register and issue a new transmit command.
; Load Transmit Pointer Register.
wait_send_done:
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	pop		ax					; Get back the buffer start address
	outw

;initiate the transmission.
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		ax, XMT_CMD
	outw							; Send out the command
	clc
	ret

	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	  ds:nothing
	call	set_ether	
	xor		dh, dh					; Clear error conditions
	clc
	ret


rcv_mode_2:
	mov		al, MATCH_ID
	jmp	short set_rcv_mode
rcv_mode_3:
	mov		al, MATCH_BRDCAST
	jmp	short set_rcv_mode
rcv_mode_5:
	mov		al, MATCH_MULTICAST
	jmp	short set_rcv_mode
rcv_mode_6:
	mov		al, MATCH_ALL
set_rcv_mode:
; Need to protect against interrupts but they are currently off
	LOAD_BANK_PORT	BANK2, RCV_MODES_REG
	out		dx, al
	SET_BANK_PORT	BANK0, COMMAND_REG
; Interrupts could be reenabled here if they were disabled above
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
	call	reset_chip
	ret

	public	set_ether
set_ether	PROC NEAR
; Set the Individual address registers with the Ethernet address
; pointed to by si
	LOAD_BANK_PORT	BANK2, I_ADD_REG0
	mov		cx, EADDR_LEN/2
next_ind_add:
	lodsw
; Need to reverse the bits in each byte so that the address is in
; written in non-canonical order
	push	cx					; cx will be used to hold a bit count
	mov		bx, ax				; Get the next word to reverse
	mov		cx, 10h				; cx = bit count for a word
reverse_next_bit:
	rol		bx, 1				; revers by copying bit by bit form bx to ax
	rcr		ax, 1
	loop	reverse_next_bit
	xchg	ah, al				; Reversal code also swaped the bytes
	outw						; Write the reversed
	pop		cx					; Get back the word count
	inc		dx					; Advance to the next address word
	inc		dx
	loop	next_ind_add
	LOAD_BANK_PORT	BANK0, COMMAND_REG	; Return back to the default bank
	ret
set_ether	ENDP


	public	reset_chip
reset_chip	PROC	NEAR
	LOAD_BANK_PORT	BANK0, COMMAND_REG
	mov		al, RESET_CMD
	out		dx, al
	call	wait_27ms			 ; need to wait at least 200 micro seconds
	ret
reset_chip	ENDP

	public	wait_27ms, wait
wait_27ms:
	mov		ax, 1			;only have to wait 4us.
NOWARN RES
wait:
WARN
	call	set_timeout
wait_27ms_1:
	call	do_timeout
	jne		wait_27ms_1
	ret


	public	reset_interface
reset_interface:
;reset the interface.
	assume	ds:code
	ret

;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
;handle has been previous found by a call to receive locate
	extrn	recv_found: near

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
	extrn	count_handles : near

;this macro writes the given character to the given row and column on
;  an CGA.
to_scrn	macro	r, c, ch
	local	black,done
  if 0
	push	bx
	push	es
	mov	bx,0b800h
	mov	es,bx
	mov	bx,es:[r*160+c*2]
	test	bh,1
	jne	black
	mov	bh,07h
	jmp	short done
black:
	mov	bh,70h
done:
	mov	bl,ch
	mov	es:[r*160+c*2],bx
	pop	es
	pop	bx
  endif
	endm

	public	recv
recv:
; Called from the recv isr.  All registers have been saved, and ds=cs.
; Upon exit, the interrupt will be acknowledged.
	assume	ds:code, es:code
	to_scrn	23,74,'R'
	mov		ax, cs			; Do the assume
	mov		ds, ax
	mov		es, ax

	LOAD_BANK_PORT	BANK0, INT_MASK_REG
	mov		al, ALL_MASK	; Turn off the RC interrupt
	out		dx, al
	SET_BANK_PORT	BANK0, STATUS_REG
	in		al, dx			; Get status of what interrupted
	test	al, RX_INT		; Did we get a packet?
	jne		recv_1			; Yes
	jmp		recv_exit
recv_1:
	mov		al, RX_INT				; Acknowledge (and hence clear) the
	out		dx, al					; RX interrupt

	SET_BANK_PORT	BANK0, HOST_ADDRESS
next_packet:
	mov		ax, rx_buff_ptr
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT

	mov		cx, RCV_HDR_SIZE		; Read the header in.
	mov		di, offset rcv_hdr
	call	repins

	mov		al, rcv_hdr[RBUF_CMD]		; Get status of the received packet
	and		al, NOT (WRAP_BIT + BIT1)	; Ignore these two bits

	cmp		al, RCV_DONE			; Received a packet
	je		not_chain_end			; Yes - deal with it

	jmp		recv_exit				; Jne is too far

not_chain_end:
	mov		ax,  WORD PTR rcv_hdr[RBUF_NEXT_LOW]
	mov		next_rx_ptr, ax			; Remember where the next one is.

; Did we receive our own broadcast?
	; First deal with the routing info usage of the source address
	mov		bh, rcv_hdr[SOURCE_ADDR]			; Save source address MSB
	and		rcv_hdr[SOURCE_ADDR], NOT RII_BIT 	; Clear routing info bit
	mov		di, offset rcv_hdr+SOURCE_ADDR
	mov		si, offset my_address
	mov		cx, EADDR_LEN/2
	repe	cmpsw
	jne		not_our_own			; Jump if not
	to_scrn	23,79,'O'
	inc		received_ours		; Remember that we received it.
	jmp		recv_update

not_our_own:
	mov		ax, WORD PTR rcv_hdr[RBUF_STAT_LOW]
	and		ax, RX_OK or RX_ERROR	;  check for errors.
	cmp		ax, RX_OK
	je		recv_noerrs
	call	count_in_err
	to_scrn	23,72,'E'
	jmp		recv_update

recv_noerrs:
	mov		dh, bh						; Original MSB of source address in dh
	xor		bp, bp						; bp will hold the RIF size
	test	dh, RII_BIT					; Any routing information ?
	je		no_rx_route_info			; No - proceed with rif size = 0
	mov		bp, WORD PTR rcv_hdr[RX_ROUTING] ; Get the route information size
	and		bp, ROUTE_SIZE_MASK			; Mask the non-size bits

no_rx_route_info:
; Determine what class this packet type belongs to
	lea		di, rcv_hdr[RX_LLC][bp]		; di=> start of LLC in the received data
	mov		dl, IEEE8025				; Try TOKEN RING class first
	extrn	recv_locate : near
	call	recv_locate					; Carry clear if class & type expected
	jc		try_next_class
	mov		rcv_hdr[SOURCE_ADDR], dh	; Restore original source address MSB
	mov		cx, WORD PTR rcv_hdr[RBUF_SIZE_LOW]	; Get the size of the frame
	sub		cx, CRC_SIZE				; Subtract the size of the CRC
	jmp		SHORT get_user_buffer		; No header to remove for this class

try_next_class:
	mov		dl, IEEE8023				; Next class to try
	call	recv_locate
	jc		try_last_class
; Length of Ctrl fields should be removed from packet size, however packet size
; should be increased by the same amount for the length field in 8023 header
	mov		cx, WORD PTR rcv_hdr[RBUF_SIZE_LOW]	; Get the size of the frame
	sub		cx, CRC_SIZE				; Subtract the size of the CRC
	mov		bx, LLC_SIZE + SNAP_SIZE	; Offset for type in 802.2 header
	jmp		SHORT	adjust_for_rif_size

try_last_class:	
	add		di, LLC_SIZE + SNAP_SIZE	; di => type bytes in the header
	mov		dl, BLUEBOOK				; Is type expected for BLUEBOOK class
	call	recv_locate
	jnc		got_bluebook

no_match:
	extrn	recv_drop : near
	call	recv_drop					; No match found
	jmp		recv_update_discard			; No futher class to try

got_bluebook:
	mov		cx, WORD PTR rcv_hdr[RBUF_SIZE_LOW]	; Get the size of the frame
	sub		cx, TOKEN_HDR_SIZE + CRC_SIZE ; Remove token header + CRC from size
	xor		bx, bx						; Used for offset of type in header

adjust_for_rif_size:
	sub		cx, bp						; Remove length of routing info
if ARP_CONVERSION eq 1
	cmp		WORD PTR [di][bx], ARP_TYPE	; Is this an ARP packet ?
	jne		no_ARP_length_fix			; No ARP fix required
	mov		WORD PTR [di+2][bx], ARP_RX_FIX	; Write the fix
no_ARP_length_fix:
endif

	cmp		cx, RUNT		; Make length at least RUNT
	jge		get_user_buffer	; Jump if length is fine
	mov		cx, RUNT

get_user_buffer:
	push	cx				; Save packet length
	call	recv_found		; See if size wanted - handle previously set
	assume	es:nothing
	pop		cx				; Recover packet length
	mov		ax, es			; Did recv_found give us a null pointer?
	or		ax, di			; ..
	je		recv_update_discard	; If null, don't copy the data

	push	cx				; We will want the count and pointer
	push	es				;  to hand to client after copying,
	push	di				;  so save them at this point

	push	cx				; Save the packet length count for our later use

	cmp		dl, IEEE8025	; Is this a IEEE8025 packet class
	jne		not_ieee8025
	xor		bp, bp			; Clear the routing info length
	; Setup the first copy so that the control bytes are also copied
	mov		si, offset rcv_hdr+RBUF_HEAD_LEN
	mov		cx, (2*EADDR_LEN + CTRL_FIELD_SIZE)/2
	jmp		SHORT copy_address_ctrl_bytes	; No need to update the cache
not_ieee8025:
	or		bp, bp			; bp = route information length
	je		nothing_to_add	; Jump if no routing information
	extrn	add_to_cache : near
	call	add_to_cache
nothing_to_add:
	cmp		dl, IEEE8023	; Is this a IEEE8023 packet class
	je		copy_I
	add		bp, LLC_SIZE + SNAP_SIZE; Ethernet packet will have LCC stripped

; Copy the packet into the users buffer - three parts
; I - copy the addresses (+ Ctrl byte for IEEE802.5)
copy_I:
	mov		si, offset rcv_hdr + DEST_ADDR	; Point to start of addresses
	mov		cx, (2*EADDR_LEN)/2	; Number of words in two addresses
copy_address_ctrl_bytes:
	pop		bx				; Recover packet length
	sub		bx, cx			; Compensate for number of word to be copied
	sub		bx, cx			; Done twice as cx is a word count
	rep		movsw			; Copy the addresses (+ Ctrl bytes if IEEE802.5)

	cmp		dl, IEEE8023	; Is this a IEEE8023 packet class
	jne		copy_II			; No - then no length to add
	mov		ax, bx			; Get length of packet data + LCC header
	stosw					; Write the length of the packet

copy_II:
; II - copy from the type bytes onwards (or RIF if IEEE802.5)
	add		si, bp		; Point to type/LLC/rif of rx packet
	; Check to see how many bytes of packet data are left in the buffer
	mov		cx, offset rcv_hdr + RCV_HDR_SIZE	; cx = address after buffer
	sub		cx, si		; cx now holds number of bytes left in the buffer
	cmp		bx, cx		; Check if remaining packet length is larger 
	jge		copy_buff_rest	; If bx is larger then buffer is all used
	mov		cx, bx		; otherwise only part of the buffer is used
copy_buff_rest:
	sub		bx, cx		; Adjust the remaining packet length after the next copy
	shr		cx, 1		; Convert the byte count to a word count
	rep		movsw		; Copy remains of the packet in the hdr buffer
	jnc		copy_III	; Jump if cx was initially even
	movsb				; Copy the remaining last byte

copy_III:
; III - copy the rest by reading from the I/O port
	or		bx, bx		; Check if there are any more to copy
	je		no_more		; No more left
	mov		cx, bx		; Remaining packet count is in bx
	LOAD_PORT	LOCAL_MEM_PORT	; dx has been corrupted
	call	repins		; read the rest of the packet in.
no_more:
	pop		si			; Recover pointer to destination
	pop		ds			; Tell client it's his source
	pop		cx			; And it's this long
	assume	ds:nothing
	call	recv_copy	; Give it to him
	jmp		short recv_update

recv_update_discard:
	to_scrn	23,73,'D'
recv_update:
	assume  ds: code, ds : code
	mov     ax, cs		; Do the assume again for the next loop
	mov     ds, ax
	mov		es, ax
	mov		ax, next_rx_ptr
	mov		rx_buff_ptr, ax

; Stop register updated to 1 less than the first free location
	cmp		ax, RX_AREA_BEG
	jne		no_wrap
	mov		ax, RX_AREA_END + 1
no_wrap:
	dec		ax 
	mov		bx, ax							; Save for later in bx
; Need a LOAD_PORT as DX could have been
; modified by the recv_copy routine however the bank is still OK.
	LOAD_PORT		RCV_STOP_LOW
	outw
; Also need to update the stop register value in the download code
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, STOP_REG_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		ax, bx							; Recover value of stop register
	outw

	SET_BANK_PORT	BANK0, HOST_ADDRESS
	to_scrn	23,75,'A'
	jmp		next_packet		; Go back and get more packets.

recv_exit:
	LOAD_BANK_PORT	BANK0, INT_MASK_REG
	mov		al, ALL_MASK AND NOT RX_MASK	; Reenble the RX interrupt
	out		dx, al
	to_scrn	23,74,' '
	ret

	include	timeout.asm

	public	timer_isr
timer_isr:
; if the first instruction is an iret, then the timer is not hooked
	iret

; any code after this will not be kept after initialization. Buffers
; used by the program, if any, are allocated from the memory between
; end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

code	ENDS
	END
