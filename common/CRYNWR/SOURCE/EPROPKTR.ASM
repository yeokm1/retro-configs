;History:38,1

	include	defs.asm
	include	82595.inc
	include	pnp.inc

cgroup	group code, _text, init

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup
	include	82595io.asm

	even

	public rx_buff_ptr
rx_buff_ptr	dw	?		; Start of receive buffer.
next_rx_ptr	dw	?		; Points to the end of the receiver buffer
						;  i.e. the start of the next receive buffer
	public inw_routine, outw_routine, repins, repouts
inw_routine		dw	?	; Address of subroutine to read in a word
outw_routine	dw	?	; Address of subroutine to write out a word
repins			dw	?	; Address of subroutine to do multiple word reads
repouts			dw	?	; Address of subroutine to do multiple word writes
	public mem_map_io
mem_map_io	dw	0,0		; Memory mapped I/O address from the command line

	public tx_buff_no, buff_ptrs
tx_buff_no		dw	?	; The next Tx buffer to use
buff_ptrs		dw	TX_BUF_CNT dup (?)

; a temp buffer for the received header
; needs to be 8 header bytes + 2 ethernet address bytes + 2 type bytes
;    plus some room for IEEE802.3  bytes
;RCV_HDR_SIZE	equ	30		; header @8 + 2 ids @6 + type @2+8,
RCV_HDR_SIZE	equ	30		; header @8 + 2 ids @6 + type @2+6,
rcv_hdr			db	RCV_HDR_SIZE dup(0)

	public	pnp_card_no, base_addr, int_no, lan_595_int
pnp_card_no	db	0			; Zero if no PNP card is found
base_addr	dw 	0000h		; I/O address as located via the I/O scan
int_no		db	0,0,0,0		; must be four bytes long for get_number.
lan_595_int	db	?			; Int number on the LAN 595 board (0 - 4)
							; Set to -1 if using a PCMCIA bus

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK,IEEE8023,0	;null terminated list of classes.
driver_type	db	255		;from the packet spec
driver_name	db	"EPROPKT",0	;name of the driver.

driver_function	db	8 + 2	; Mix capability + packet status returned in DH

parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1

	public	int_num
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

;-> current address
	extrn	my_address: byte

received_ours	db	0
	public	rcv_modes
rcv_modes	dw	8		;number of receive modes in our table.
		dw	0		;There is no mode zero
		dw	0
		dw	rcv_mode_2
		dw	rcv_mode_3
		dw	rcv_mode_4
		dw	0
		dw	rcv_mode_6
		dw	rcv_mode_7

curr_rcv_mode	db	MATCH_BRDCAST		; The current receive mode
save_err	db	0		; Errors in last frame received (promiscuous mode only)

	public	bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	cmp	ah,26
	jne	bad_command_intercept_1
	jmp	do_tdr
bad_command_intercept_1:
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
rcv_mode_4:
	mov		al, MATCH_BRDCAST
	jmp	short set_rcv_mode
rcv_mode_6:
	mov		al, MATCH_ALL
	jmp	short set_rcv_mode
rcv_mode_7:
	mov		al, MATCH_BRDCAST or MULTI_IA
set_rcv_mode:
	mov		curr_rcv_mode, al
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
; wait until the previous command has finished executing
	LOAD_BANK_PORT	BANK0, STATUS_REG
set_multicast_list_1:
	in		al, dx				; Get the status byte
	and		al, EXEC_STATUS		; Get exec status
	jnz		set_multicast_list_1
; Configure the MC Setup memory structure
	xor		bx, bx				; Use the first TX buffer
	mov		ax, buff_ptrs[bx]	; Get the buffer address
	mov		bx,	ax				; Store for later
; Setup the TX frame at the appropriate point in the TX area
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		ax, MC_SETUP_CMD	; The command to be executed
	outw
	xor		ax, ax
	outw						; Clear the status field
	outw						; No chaining of frames
	mov		ax, cx
	outw						; Output the count.

;output the MC/IA data.  Count is in CX.
	call	repouts

; Need to load the transmit register and issue a MC Setup command.
; Load Transmit Pointer Register.
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	mov		ax, bx				; Get back the buffer start address
	outw

; Initiate the MC Setup
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		ax, MC_SETUP_CMD
	outw						; Send out the command

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
;	call	wait_27ms			 ; need to wait at least 200 micro seconds
;	mov		ax,10h	; 40h works 10h too small - best value = ?
	mov		ax,40h
	call	wait
	ret
reset_chip	ENDP

	public	wait_27ms, wait
wait_27ms:
	mov	ax,1			;only have to wait 4us.
NOWARN
wait:
WARN
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
	in		al,dx		;is it already masked off?
	test		al, RX_MASK
	jne		recv_exit_1	;yes, we got doubly-interrupted.
	mov		al, ALL_MASK	; Turn off the RC interrupt
	out		dx, al
	SET_BANK_PORT	BANK0, STATUS_REG
	in		al, dx			; Get status of what interrupted
	test	al, RX_INT		; Did we get a packet?
	jne		recv_1			; Yes
recv_exit_1:
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
	mov		di, offset cgroup:rcv_hdr
	call	repins
	cmp		WORD PTR rcv_hdr[RBUF_CMD], RCV_DONE	; End of chain ?
	je		not_chain_end				; No - deal with it
found_zero:
	jmp		recv_exit					; Yes - jne is too far

not_chain_end:
	mov		ax,  WORD PTR rcv_hdr[RBUF_NEXT_LOW]
	mov		next_rx_ptr, ax			; Remember where the next one is.

; Did we receive our own broadcast?
	mov		di, offset cgroup:rcv_hdr+RBUF_HEAD_LEN+EADDR_LEN
	mov		si, offset cgroup:my_address
	mov		cx, EADDR_LEN/2
	repe	cmpsw
	jne		not_our_own			; Jump if not
	to_scrn	23,79,'O'
	inc		received_ours		; Remember that we received it.
	jmp		recv_update

not_our_own:
; Check to make sure that frame has been received with no errors.
; If errors are found then only return frame if in promiscuous mode.
; In promiscuous mode the frame status is assembled and placed in save_err.
	mov		ax,  WORD PTR rcv_hdr[RBUF_STAT_LOW]	; Get frame status
	mov	save_err, 1		; Set default value of no error

	test	ax, RX_OK		; Error free frame ?
	jne		recv_noerrs		; Jump if so

	call	count_in_err
	to_scrn	23,72,'E'

	cmp	curr_rcv_mode, MATCH_ALL	; Currently in promiscuous mode ?
	jne	recv_update		; No - ignore bad frame

; Find the error bits in the status of the current frame and save in save_err
	mov	ch, 0
	test	ax, SHORT_FRAME_BIT
	je	RX_not_short
	or	ch, 02h
RX_not_short:
	test	ax, CRC_BIT
	je	RX_crc_ok
	or	ch, 04h
RX_crc_ok:
	test	ax, ALIGN_BIT
	je	RX_align_ok
	or	ch, 08h
RX_align_ok:
	test	ax, OVER_RUN_BIT
	je	RX_no_over_run
	or	ch, 10h
RX_no_over_run:
	mov	save_err, ch

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
	mov		di, offset cgroup:rcv_hdr+RBUF_HEAD_LEN+EADDR_LEN+EADDR_LEN
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
	mov		dh,	save_err	; Get the error status into dh for Intel
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
	mov		si, offset cgroup:rcv_hdr + RBUF_HEAD_LEN
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
	mov	ax, cs
	mov	ds, ax
	assume	ds: code
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

;*****************************************************************
; TDR cable tester
; enter with es:di pointing to time int
;*****************************************************************
	public do_tdr
do_tdr:
; wait until the previous command has finished executing
	LOAD_BANK_PORT	BANK0, STATUS_REG
not_idle1:
	in		al, dx				; Get the status byte
	and		al, EXEC_STATUS		; Get exec status
	jnz		not_idle1
; Configure the TDR memory structure
	xor		bx, bx				; Use the first TX buffer
	mov		ax, buff_ptrs[bx]	; Get the buffer address
	mov		bx,	ax				; Store for later
; Setup the TX frame at the appropriate point in the TX area
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		ax, TDR_CMD			; The command to be executed
	outw
	xor		ax, ax
	outw						; Clear the status field
	outw						; No chaining of frames
	outw						; Byte count of zero

; Need to load the transmit register and issue a TDR command.
; Load Transmit Pointer Register.
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	mov		ax, bx				; Get back the buffer start address
	outw

; Initiate the TDR
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		ax, TDR_CMD
	outw						; Send out the command

; Wait until the command has finished executing
	SET_BANK_PORT	BANK0, STATUS_REG
not_idle2:
	in		al, dx				; Get the status byte
	and		al, EXEC_STATUS		; Get exec status
	jnz		not_idle2

; Get status of the TDR command
	mov		ax, bx				; Get back the buffer start address
	add		ax, 2h				; Advance to the status word (no wrap check)
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	inw							; Read the TDR command status

	test	ax, LNK_OK
	jz	tdr_bad_cable
	clc
	ret

tdr_bad_cable:
	push	ax
	and	ax, TDR_TIME
	stosw				; store time
	pop	ax

	mov	cl, 12
	shr	ax, cl
	and	ax, 7
	mov	dh, al
	stc
	ret


	include	timeout.asm

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

code	ends

_text	segment para public 'code'
_text	ends

init	segment para public 'code'
init	ends

	END
