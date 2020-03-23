
	include	defs.asm
	include	82595.inc

version equ 0

code	SEGMENT	word public
	assume	cs:code, ds:code
	include	lan595io.asm

	even

extrn	sys_features : byte
extrn	decout	: near

rx_buff_ptr	dw	?		; Start of receive buffer.
next_rx_ptr	dw	?		; Points to the end of the receiver buffer
						;  i.e. the start of the next receive buffer
inw_routine		dw	?	; Address of subroutine to read in a word
outw_routine	dw	?	; Address of subroutine to write out a word
repins			dw	?	; Address of subroutine to do multiple word reads
repouts			dw	?	; Address of subroutine to do multiple word writes

tx_buff_no		dw	?	; The next Tx buffer to use
buff_ptrs		dw	TX_BUF_CNT dup (?)

; a temp buffer for the received header
; needs to be 8 header bytes + 2 ethernet address bytes + 2 type bytes
;    plus some room for IEEE802.3  bytes
;RCV_HDR_SIZE	equ	30		; header @8 + 2 ids @6 + type @2+8,
RCV_HDR_SIZE	equ	30		; header @8 + 2 ids @6 + type @2+6,
rcv_hdr			db	RCV_HDR_SIZE dup(0)

lan_595_int	db	?	; Int number on the LAN 595 board (0 - 4)
	public	int_no
int_no		db	3,0,0,0		;must be four bytes long for get_number.
io_addr		dw	0,0			; I/O address specified on the command line
base_addr	dw 	0000h		; I/O address as located via the I/O scan

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK,IEEE8023,0	;null terminated list of classes.

	driver_type	db	0		;from the packet spec
	driver_name	db	10h dup(?)	;name of the driver.

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
	cmp		cx,GIANT			; Is this packet too large?
	ja		send_pkt_toobig

	cmp		cx, RUNT			; Minimum length for Ether
	jae		oklen
	mov		cx, RUNT			; Make sure size at least RUNT
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
	mov		ax, cx				; Get the packet length
	outw						; Write the length into the packet frame

; Write the contents of the packet.
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
	LOAD_BANK_PORT	BANK2, RECV_MODES_REG
	out		dx, al
	; Need to write to RE3 for the REV_MODES_REG command to take affect
	SET_BANK_PORT	BANK2, REG3
	in		al, dx
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

set_ether	PROC NEAR
; Set the Individual address registers with the Ethernet address
; pointed to by si
	LOAD_BANK_PORT	BANK2, I_ADD_REG0
	mov		cx, EADDR_LEN/2
next_ind_add:
	lodsw
	outw
	inc		dx						; Advance to the next address word
	inc		dx
	loop	next_ind_add
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

	public	wait_27ms
wait_27ms:
	mov	ax,1			;only have to wait 4us.
wait:
	call	set_timeout
wait_27ms_1:
	call	do_timeout
	jne	wait_27ms_1
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
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code
	to_scrn	23,74,'R'

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
	mov		ax, rx_buff_ptr
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT

next_packet:
	mov		cx, RCV_HDR_SIZE		;read the header in.
	mov		ax, cs
	mov		es, ax
	mov		di, offset rcv_hdr
	call	repins
	cmp		WORD PTR rcv_hdr[RBUF_CMD], RCV_DONE	; End of chain ?
	je		not_chain_end				; No - deal with it
found_zero:
	jmp		recv_exit					; Yes - jne is too far

not_chain_end:
	mov		ax,  WORD PTR rcv_hdr[RBUF_NEXT_LOW]
	mov		next_rx_ptr, ax			; Remember where the next one is.

; Did we receive our own broadcast?
	mov		di, offset rcv_hdr+RBUF_HEAD_LEN+EADDR_LEN
	mov		si, offset my_address
	mov		cx, EADDR_LEN/2
	repe	cmpsw
	jne		not_our_own		; Jump if not
	to_scrn	23,79,'O'
	inc		received_ours		;remember that we received it.
	jmp		recv_update

not_our_own:
	mov		ax,  WORD PTR rcv_hdr[RBUF_STAT_LOW]
	and		ax, RX_OK or RX_ERROR	;  check for errors.
	cmp		ax, RX_OK
	je		recv_noerrs
	call	count_in_err
	to_scrn	23,72,'E'
	jmp		recv_update

recv_noerrs:
; Check against the 82595 truncating a packet with a too small type/size
	mov		cx, WORD PTR rcv_hdr[RBUF_SIZE_LOW]	; Get the size of the frame
	cmp		cx, RCV_HDR_SIZE-RBUF_HEAD_LEN		; Should be at least this size
	jl		recv_update				; Too small - discard with no error
length_ok:
	push	cx
	mov		ax, cs			; Set ds = code
	mov		ds, ax
	mov		es, ax
	assume	ds:code
	mov		di, offset rcv_hdr+RBUF_HEAD_LEN+EADDR_LEN+EADDR_LEN
	push	dx					; Need to save the port address
	mov		dl, BLUEBOOK		;assume bluebook Ethernet.
	mov		ax, es:[di]			; Get the packet type
	xchg	ah, al
	cmp 	ax, 1500
	ja		BlueBookPacket
	inc		di			;set di to 802.2 header
	inc		di
	mov		dl, IEEE8023
BlueBookPacket:
	call	recv_find		; See if type and size are wanted
	pop		dx				; Get back the port address
	pop		cx
	mov		ax, es			; Did recv_find give us a null pointer?
	or		ax, di			; ..
	je		recv_update_discard	; If null, don't copy the data

	push	cx			; We will want the count and pointer
	push	es			;  to hand to client after copying,
	push	di			;  so save them at this point

	push	cx			; move the receive header in.
	mov		si, offset rcv_hdr + RBUF_HEAD_LEN
	mov		cx, (RCV_HDR_SIZE - RBUF_HEAD_LEN)/2
	rep	movsw			;move rest of packet
	pop	cx
						;subtract off what we've already copied.
	sub		cx, RCV_HDR_SIZE - RBUF_HEAD_LEN
	call	repins		; read the rest of the packet in.

	pop		si			; Recover pointer to destination
	pop		ds			; Tell client it's his source
	pop		cx			; And it's this long
	assume	ds:nothing
	call	recv_copy	; Give it to him
	mov     ax, cs
	mov     ds, ax
	assume  ds: code
	jmp		short recv_update
recv_update_discard:
	to_scrn	23,73,'D'
recv_update:
	mov		ax, next_rx_ptr
	mov		rx_buff_ptr, ax
; Need to reload the host address register as the host address will not always
; be pointing to the next frame.  Need a LOAD_PORT as DX could have been
; modified by the recv_copy routine however the bank is still OK.
	LOAD_PORT	HOST_ADDRESS
	outw
; Stop register updated to 1 less than the first free location
	or		ax, ax
	jne		no_wrap
	mov		ax, RX_AREA_END + 1
no_wrap:
	dec		ax 
	SET_BANK_PORT	BANK0, RCV_STOP_LOW
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT

	to_scrn	23,75,'A'
	jmp		next_packet						; Go back and get more packets.

recv_exit:
	LOAD_BANK_PORT	BANK0, INT_MASK_REG
	mov		al, ALL_MASK AND NOT RX_MASK	; Reenble the RX interrupt
	out		dx, al
	to_scrn	23,74,' '
	ret

	include	timeout.asm

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte


	public	usage_msg
	usage_msg	db	"usage: lan595 [options] <packet_int_no> <hardware_irq> <io_addr>",CR,LF,'$'

	public	copyright_msg
	copyright_msg	db	"Packet driver for the Intel LAN 595, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF

		db	"Portions written by Morien W. Roberts",CR,LF,'$'

this_board_msg	db	"This board is an ",'$'
memory_bad_msg	db	"Ethernet buffer memory bad",CR,LF,'$'
testing_mem_msg	db	CR,LF,"Testing memory .",'$'

tp_msg	db "Using twisted pair cable",CR,LF,'$'
bnc_msg	db	"Using coax cable",CR,LF,'$'
byte_msg	db "Performing 8 bit I/O transfers",CR,LF,'$'
word_msg	db "Performing 16 bit I/O transfers",CR,LF,'$'

int_bad_msg	db	"That interrupt number is not supported.",CR,LF
		db	"The LAN 595 EEPROM is currently configured to use IRQs "
dummy_msg	db '$'
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
specified_failed 	db  "An 82595 Ethernet adapter was not found at specified address.",CR,LF,'$'
scan_failed db  "Scan of I/O space did not find an 82595 Ethernet adapter.",CR,LF,'$'
found_two	db	"Found two 82595 Ethernet controller cards.",CR,LF,'$'
board_name	db      02h, "Intel LAN 595  ",0,48
irq_map		dw	?	; Read from the eeprom - holds mapping of the 5 82595 IRQs
no_prom		db	0	; <> 0 if ethernet address specified on the command line

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> wword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> wword to print.
	extrn	print_number: near

;-> the Ethernet address of the card.
	extrn	rom_address: byte

;print the character in al.
	extrn	chrout: near

;print a crlf
	extrn	crlf: near

;enter with si -> argument string.
;skip spaces and tabs.  Exit with si -> first non-blank char.
	extrn	skip_blanks: near

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	call	skip_blanks
	cmp	al,CR			;does an Ethernet address follow?
	je	parse_args_1		;no.
	inc	no_prom			;we don't have an Ethernet PROM.
;enter with ds:si -> Ethernet address to parse, es:di -> place to put it.
	movseg	es,ds
	mov	di,offset rom_address
	call	get_eaddr
parse_args_1:
	clc
	ret

	public	etopen
etopen:
;Initialize the driver.
;Fill in rom_address with the assigned address of the board.
	assume	ds:code
	call	etopen_82595
	jnc		etopen_ok
	ret
; First check to see if this interrupt is available for the board
etopen_ok:
	mov		cl, int_no
	cmp		cl, 09h				; Need to change an IRQ9 back to an IRQ2
	jne		not_irq9
	mov		cl, 02h
not_irq9:
	mov		bl, cl				; Make a copy of the interrupt no
	mov		ax, 0001h	
	shl		ax, cl
	test	irq_map, ax			; If bit is set then this IRQ is OK
	jne		int_no_ok			; Yes this interrupt is OK

; This code simply goes through the irq_map an informs which interrupts are
; available.  The irq_map was obtained form the eeprom and should always have
; 5 bits set. The interrupt list is generated one by one and separated by
; commas except the last two interrupts which are separted with an '&'.
	mov 	dx, offset int_bad_msg
	mov		ah, 9
	int		21h
	mov		ax, 0001h
	mov		cx, 10h
	xor		dx, dx
	mov		si, dx
check_next:
	test	irq_map, ax
	je		not_available
	inc		si
	push	ax
	push	cx
	mov		ax, 10h
	sub		ax, cx
;	cmp		al, 02h					; Need to display an IRQ2 as an IRQ9
;	jne		irq_no_ok
;	test	sys_features,TWO_8259	; 2nd 8259 ?
;	je		irq_no_ok				; No, no mapping needed
;	add		al, 07h
;irq_no_ok:
	push	si
	call	decout
	pop		si
	cmp		si, 0004h
	jg		no_output
	je		output_&
	mov		al, ','
	jmp		output_it
output_&:
	mov		al, ' '
	call	chrout
	mov		al, '&'
output_it:
	call	chrout
	mov		al, ' '
	call	chrout
no_output:
	pop		cx
	pop		ax
not_available:
	shl		ax, 1
	loop	check_next
	call	crlf
	mov 	dx, offset dummy_msg	; No more message to print
	stc
	ret

int_no_ok:
; Need to find which LAN 595 interrupt this is
	xor		dl, dl
	mov		cl, bl			; Get back the copy of the int_no
	jcxz	found_it
	mov		ax, irq_map
next_irq_map_bit:
	sar		ax, 1
	jnc		not_set
	inc		dl
not_set:
	loop	next_irq_map_bit
found_it:
	mov		lan_595_int, dl

	mov		si, offset board_name+1		; skip the board revison number
	mov		dx, offset this_board_msg
	mov		ah, 9
	int		21h

	movseg	es,ds			;copy the driver name to where we need it.
	mov		di, offset driver_name

check_board_copy:
	lodsb
	stosb
	or		al, al
	je		check_board_done_print
	call	chrout			;print the character.
	jmp	check_board_copy
check_board_done_print:
	lodsb				;copy the driver type number over
	mov		driver_type, al
	mov		dx, offset testing_mem_msg
	mov		ah, 9
	int		21h

adapter_verify:
	mov		al, '.'
	call	chrout
	mov		bx, 0aa55h		;aa55
	xor		si, si
	call	test_memory
	jc		adapter_verify_bad

	mov		al, '.'
	call	chrout
	mov		bx, 055aah		;55aa
	xor		si, si
	call	test_memory
	jc		adapter_verify_bad

	mov		al, '.'
	call	chrout
	mov		bx, 0			;incrementing
	mov		si, 1
	call	test_memory
	jc		adapter_verify_bad
	jmp		short adapter_ok

adapter_verify_bad:
	mov		dx, offset memory_bad_msg
	stc
	ret

adapter_ok:
	call	crlf
	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	movseg	es,ds
	mov	si,offset rom_address
	mov	di,offset my_address
	repmov	EADDR_LEN

	call	set_recv_isr
	call	set_RX_TX_areas
	clc
	ret
	
	
	public	set_RX_TX_areas
; Sets up all the RX and TX buffers variables as well as setting the buffer
; registers in the 82595 chip.  
; Enables the 82595 interrupt and masks all but the RX interrupt.
; Issues a selective rest command and then a receive enable command.
; Code works on one bank at a time to minimize bank swapping.

set_RX_TX_areas	PROC	NEAR
; Allow interrupts to occur - the 82595 interrupt mask will be cleared later
	LOAD_BANK_PORT	BANK1, INT_NO_REG
	mov		al, lan_595_int
	out		dx, al

; Partion the 82595 RAM into a RX area and TX area with the RX area first.
; Partition the RAM (RAM_SIZE = 32k) to have a RX_AREA_SIZE receive buffer and a
; 32k - RX_AREA_SIZE transmit buffer
	SET_BANK_PORT	BANK1, REC_LOW_LIMIT_REG
	mov		al, RX_AREA_BEG
	out		dx, al
	SET_BANK_PORT	BANK1, REC_UPPER_LIMIT_REG
	mov		al, RX_AREA_END / 256
	out		dx, al
	SET_BANK_PORT	BANK1, XMT_LOW_LIMIT_REG
	mov		al, TX_AREA_BEG / 256 
	out		dx, al
	SET_BANK_PORT	BANK1, XMT_UPPER_LIMIT_REG
	mov		al, (RAM_SIZE / 256) -1
	out		dx, al
	SET_BANK_PORT	BANK1, REG1
	in		al, dx
	or		al, INT_ENABLE
	out		dx, al

; Allow only RX events to interrupt
	SET_BANK_PORT	BANK0, INT_MASK_REG
	mov		al, ALL_MASK AND NOT RX_MASK ; Enable only RX interrupts
	out		dx, al

; Perform the RCV initialization
	SET_BANK_PORT	BANK0, BAR_LOW	; Specify start of the receive area
	mov		ax, RX_AREA_BEG
	outw
	mov		rx_buff_ptr, ax		; Initialize the receive buffer pointer
	SET_BANK_PORT	BANK0, RCV_STOP_LOW	; Specify end of receive area
	mov		ax, RX_AREA_END
	outw

; Perform the TX initialization - no chip registers to set, only buffers
; Set up the various TX buffers, each one will have the maximum size
	mov		ax, cs				; Need to set es to cs
	mov		es, ax
	mov		di, offset buff_ptrs	; Start of buffer pointer array
	mov		cx, TX_BUF_CNT		; Number of buffers
	mov		ax, TX_AREA_BEG		; Start of the first buffer
buff_set:
	stosw						; Store the address of the buffer
	add		ax,	TX_FRAME_SIZE	; Add the max buffer size
	loop	buff_set
	mov		tx_buff_no, 0		; The next TX buffer to use

; Issue a selective reset command
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, SEL_RESET
	out		dx, al
	call	wait_27ms

; Issue a RCV_ENABLE command
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, RCV_ENABLE
	out		dx, al 
	ret
set_RX_TX_areas	ENDP

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

test_memory:
; Enter with bx = pattern to write, si = increment for pattern.
; Set Host address to start of memory
	LOAD_BANK_PORT	BANK0, HOST_ADDRESS
	xor		ax, ax
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		ax, bx			;get the pattern word
	mov		cx, RAM_SIZE/2		;number of words to write
test_memory_write:
	outw					;write our pattern.
	add		ax, si			;increment the pattern.
	loop	test_memory_write
	
	mov		al, '.'
	call	chrout
	
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	xor	ax,ax			;start at zero again.
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT

	mov		cx,	RAM_SIZE/2		;number of words to read
test_memory_read:
	inw
	cmp		ax, bx			;does it compare correctly?
	jne		test_memory_fail	;no, quit.
	add		bx, si			;increment the pattern.
	loop	test_memory_read	; Otherwise, continue
	clc
	ret

test_memory_fail:
	stc
	ret

etopen_82595	PROC	NEAR
	call	find_base				; Go and find the chip
	jc		exit_etopen_82595
	call	reset_chip
	call	get_ethernet_address	; Fetch ethernet address if necessary
	call	get_IRQ_map				; Fetch the IRQ map from teh eeprom
	call	config_chip				; Configure chip
	clc								; No errors to report at this point
exit_etopen_82595:
	ret
etopen_82595	ENDP

config_chip	PROC	NEAR
; Set the correct transfer routines
	LOAD_BANK_PORT	BANK1, REG1
	in		al, dx				; Get current value (8 bits)
	test	al, WORD_WIDTH		; Is chip configured for word transfers
	je		eight_bit			; No then do 8 bit transfers

								; Setup the 16 bit routines
	mov		dx, offset word_msg	; Using word transfers message
	mov		inw_routine, offset inw_16
	mov		outw_routine, offset outw_16

	cmp		is_186,0			; Can we use fast routines ?
	je		slow_16_bit			; No - have to do use the slower routines
	mov		repins, offset quick_rep_ins_16
	mov		repouts, offset quick_rep_outw_16
	jmp		routines_are_set
slow_16_bit:
	mov		repins, offset rep_ins_16
	mov		repouts, offset rep_outw_16
	jmp		routines_are_set

eight_bit:						; Setup the 8 bit routines
	mov		dx, offset byte_msg	; Using byte transfers message
	mov		inw_routine, offset inw_2_8
	mov		outw_routine, offset outw_2_8
	cmp		is_186,0			; Can we use fast routines ?
	je		slow_8_bit			; No - have to do use the slower routines
	mov		repins, offset quick_rep_ins_2_8
	mov		repouts, offset quick_rep_outw_2_8
	jmp		routines_are_set
slow_8_bit:
	mov		repins, offset rep_ins_2_8
	mov		repouts, offset rep_outw_2_8
routines_are_set:
	mov		ah, 09h				; Announce which routines we are using
	int		21h
; DX has been corrupted
	LOAD_BANK_PORT	BANK1, REC_LOW_LIMIT_REG

; Partition the RAM to have a 32k receive buffer and a 32 transmitter buffer
; As there is actually only 32k of RAM available the receive buffer has it all
; so that during the memory test there will be undesirable autmated wrap-around
; of the host address register.
	SET_BANK_PORT	BANK1, REC_LOW_LIMIT_REG
	mov		al, 0
	out		dx,al
	SET_BANK_PORT	BANK1, REC_UPPER_LIMIT_REG
	mov		al, (RAM_SIZE / 256) -1
	out		dx,al
	SET_BANK_PORT	BANK1, XMT_LOW_LIMIT_REG
	mov		al, (RAM_SIZE / 256) 
	out		dx,al
	SET_BANK_PORT	BANK1, XMT_UPPER_LIMIT_REG
	mov		al, 2*(RAM_SIZE / 256) - 1
	out		dx,al

; Set the Individual address registers with the Ethernet address
	mov		si, offset rom_address
	call	set_ether
	LOAD_BANK_PORT	BANK2, RECV_MODES_REG	; Set default receive modes
	mov		al, MATCH_BRDCAST
	out		dx, al

; Delay for the hardware to work out if the TP cable is present - 150ms
	mov	ax,18			;wait a half a second.
	call	wait

	SET_BANK_PORT	BANK2, REG3
	in		al, dx					; Get current value
	and		al, TEST_MODE_MASK 		; Clear the test modes bits
	out		dx, al
; Determine what connector type has been selected
	mov		dx, offset tp_msg
	test	al, TPE_BIT			; Using a twisted pair ?
	jne		using_tp
	mov		dx, offset bnc_msg
using_tp:
	mov		ah, 09h
	int		21h

	LOAD_BANK_PORT	BANK0, COMMAND_REG 		; Issue a selective reset command
	mov		al, SEL_RESET
	out		dx, al
	call	wait_27ms
	ret
config_chip	ENDP

	public	find_base
find_base	PROC	NEAR
	mov		bh, R_ROBIN_BITS	; The mask bits for the round robin counter
	cmp		io_addr, 0h			; Has a base address been specified
	jz		full_scan			; No - start scan from the begining
	mov		dx, io_addr			; Start scan from specified address
	add		dx, ID_REG
	mov		di, dx				; DI holds last I/O address to examine
	jmp		f_b_cont
full_scan:
	mov		dx, FIRST_IO		; First I/O Address to examine
	mov		di, LAST_IO			; DI holds last I/O address to examine
f_b_cont:
	in		al, dx
	mov		bl, al				; Keep a copy
	and		al, ID_REG_MASK		; Mask off bits not required
	cmp		al, ID_REG_SIG  	; Do we have the signature
	jz		check_sig			; Looks promising go and check it
f_b_cont1:
	add		dx, 10h				; Advance the I/O address
	cmp		dx, di				; Have we checked them all ?
	jl		f_b_cont			; No - then continue
	cmp		base_addr, 0h		; Did we find a controller ?
	jz		f_b_failed			; No - then go and complain
	mov		ax, base_addr		; Yes - then copy it over
	mov		io_addr, ax
	ret
f_b_failed:
	cmp		io_addr, 0h			; Has a base address been specified
	jz		f_b_failed1			; No - then the scan failed
	mov		dx, offset specified_failed
	jmp		f_b_failed2
f_b_failed1:
	mov		dx, offset scan_failed	; Message to announce later
f_b_failed2:
	stc							; Set carry and return
	ret

check_sig:
	; Routine to check the round robin counter at the ID register
	; FIrst task is to sync the counter bits to 0
	and		bl, bh				; Get only the round_robin counter bits
	rol		bl, 1				; Bits are required in B1 and B0 of BL
	rol		bl, 1
	mov		cx, 03h				; Get into cl the number of INs that are
	sub		cl, bl				;   to sync the round robin counter
	jcxz	sync_ok				; Jump if already synchronized
cont_sync:
	in		al, dx				; Read from the ID Register
	loop	cont_sync
; Now it is synchronized the count can be checked.
; A loop would be more compact but this code is faster and will not be kept by
; the TSR.
sync_ok:
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the round_robin counter bits in al
	cmp		al, 00h				; Check if it is the expected count
	jnz 	f_b_cont1			; No - move on to consider the next IO port
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the round_robin counter bits in al
	cmp		al, 40h				; Check if it is the expected count
	jnz 	f_b_cont1			; No - move on to consider the next IO port
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the round_robin counter bits in al
	cmp		al, 80h				; Check if it is the expected count
	jnz 	f_b_cont1			; No -  move on to consider the next IO port
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the round_robin counter bits in al
	cmp		al, 0C0h			; Check if it is the expected count
	jnz 	f_b_cont1			; No -  move on to consider the next IO port
; Check that another 82595 has not been found
	cmp		base_addr, 0h		; Value should initially be zero
	jz		first_found			; Ok to proceed
	mov		dx, offset found_two	; Message to announce later
	stc							; Set carry and return
	ret
first_found:
	sub		dx, ID_REG			; Get the read base
	mov		base_addr, dx		; Store the base address
	add		dx, ID_REG			; Point back to the ID register
	jmp 	f_b_cont1			; Continue the scan of IO addresses
find_base	ENDP


get_eeprom_data PROC NEAR
	; Called with :
	; bx = starting offset address in the EEPROM
	; cx = number of bytes to read
	; di = buffer to place the data
	; si is use for temporary storage

	LOAD_BANK_PORT	BANK2, EEPROM_REG	; Set the eeprom port
get_next_eeprom_byte:
	mov		al, EECS				; EEPROM chip select
	out		dx, al					; Enable the eeprom

;get_next_eeprom_byte:
	push	cx					; Number of bytes left to read
	push	bx					; Address of next byte in eeprom

; First select eeprom for reading
eeprom_ok:
	mov		al, EEDI OR EECS	; Set a 1 in the data bit
	write_eeprom_bit			; Write a 1
	write_eeprom_bit			; Write a 1
	mov		al, EECS			; Set a 0 in the data bit
	write_eeprom_bit			; Write a 1

	pop		bx					; Next eeprom address bits
	inc		bx
	push	bx					; Store eeprom address bits
	dec		bx

	ror		bl,1				; Align the address bits so that the MSB
	ror		bl,1				; is at the EEDI position
	ror		bl,1
	mov		cx, 06h				; Number of bits in each address is 6
next_add_bit:
	mov		bh, bl				; Save a copy of the address bits
	and		bl, EEDI			; Clear all bits except EEDI
	and		al, NOT EEDI		; Clear the EDIT bit
	or		al, bl				; EDDI bit in al is now set as required
	write_eeprom_bit			; Write the address bit
	jz		eeprom_address_done	;   no need to do all 6 bits
	mov		bl, bh				; Retrive the address bits	
	rol		bl, 1				; Rotate the address bits
	loop	next_add_bit		; Write out all 6 bits

eeprom_address_done:			; Now ready to read the EEPROM data
	xor		si, si				; Byte will be assembled in si
	mov		cx, 10h				; Number of bits to fetch
get_next_bit:
	read_eeprom_bit				; Value of eeprom bit returned in bl
	and		bx, EEDO			; Clear all but the eeprom data output bit
	or		si, bx				; Add the bit to the assembled byte
	rol		si, 1				; Advance byte ready for next bit
	loop	get_next_bit		; Continue until all 16 bits have been read

	mov		cl, 4h				; Final rotate for SI gets the word aligned
	ror		si, cl				;    correctly

	mov		[di], si			; Store the word
	add		di, 2				; Advance the buffer pointer

	pop		bx					; Next EEPROM address to read from
	pop		cx					; Remaining bytes to read
	dec		cx					; Two bytes are read each time
	dec		cx					; So cx is decremented by two
	mov		al, 0				; Disable the EEPROM
	out		dx, al				; Perform the operation
	jcxz	no_more				; If zero then we have finished
	jmp		get_next_eeprom_byte
no_more:
	mov		al, 0				; Disable the EEPROM
	out		dx, al				; Perform the operation
	SET_BANK_PORT	BANK0, COMMAND_REG	; Setup the default bank
	ret
get_eeprom_data ENDP

get_ethernet_address	PROC	near
	cmp		no_prom, 0			; User specified ethernet address
	jne		no_need			 	; Yes - no need to read the eeprom address
	mov		bx, 02h				; Offset into eeprom for start of address
	mov		cx, EADDR_LEN		; Number of bytes to read
	mov		di, offset	rom_address	; Where to write the ethernet address
	call	get_eeprom_data		; Get the ethernet address
	call	reverse_address		; Need to reverse the address
no_need:
	ret
get_ethernet_address	ENDP

reverse_address	PROC	NEAR
; Routine that reverses the ethernet address read from the eeprom.
; Originally read in LSB to MSB, required in MSB to LSB order for rom_address
	mov		si, offset	rom_address	; 
	mov		di, si				; Will be written back to the same address
	mov		ax, ds				; ES needs to be correct
	mov		es, ax
	mov		cx, EADDR_LEN / 2	; Number of words to be reversed
	; 1'st phase of reversing code pushes the words onto the stack
reverse_1:
	lodsw
	xchg	ah, al				; Need to swap the bytes
	push	ax
	loop	reverse_1
	mov		cx, EADDR_LEN/2		; Number of words to be reversed
	; 2'nd phase of reversing code pops the words back from the stack
reverse_2:
	pop		ax
	stosw
	loop	reverse_2
	ret
reverse_address	ENDP


get_IRQ_map	PROC	near
	mov		bx, 07h				; Offset into eeprom for start of map
	mov		cx, IRQ_MAP_LEN		; Number of bytes to read
	mov		di, offset	irq_map	; Where to write the ethernet address
	call	get_eeprom_data		; Get the ethernet address
	ret
get_IRQ_map	ENDP

	extrn	get_hex: near
	include	getea.asm

code	ENDS
	END
