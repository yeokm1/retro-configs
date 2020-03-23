version		equ	5
DEBUG		equ	0
;History:31,1

;  Copyright 1991, 1992, 1993 Russell Nelson

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

;
;	Waits for SCB command unit to become idle
;
;	MUST NOT TRASH CX OR THE ISSUE_COMMAND PROCEDURE WILL FAIL
;cmd_clear exits with cy if the command didn't become idle in one millisecond.

cmd_clear	macro
	local	exit

	lea	dx, [bp].@SCB_CMD		;BP -> I/O Base

	in	ax, dx				;Read SCB command
	or	ax, ax				;Wait for command accepted
	jz	exit

	call	cmd_wait
exit:
	endm

;
; Drives channel attention to the 586.  We don't care whats in AX, the write
; will cause the ASIC to drive CA to the 586.
;
	issue_ca	MACRO
	lea	dx, [bp].@CA_Ctrl
	out	dx, al
	endm


;
;
;  Enable and disable exp16s interrupts.
;
enable_board_ints	macro
	lea	dx, [bp].@Sel_IRQ
	mov	al, encoded_int_no
	or	al, 08h
	out	dx, al
	endm

disable_board_ints	macro
	lea	dx, [bp].@Sel_IRQ
	mov	al, encoded_int_no
	out	dx, al
	endm


RxBufferSize	equ	1518+14+18	;Max Rx packet+MAC header+
						; 18 (alignment)
TxBufferSize	equ	1518+14+20	;Max Tx packet+MAC header+
						; 20 (alignment)

	include	exp16.inc

_64K_not_32K	db	0	;<>0 if we have 64K of memory.
_16_not_8_bit_slot	db	0	;<>0 if we're in a 16-bit slot.

;possible values for connection_type:
CONN_BNC	equ	0
CONN_AUI	equ	1
CONN_TPE	equ	2
CONN_AUTO	equ	3
connection_type	db	?

;Memory Sizes
mem_size_address	equ	00H
_32K		equ	00000h
_64K		equ	00001h

CONNECTION_ADDRESS	equ	00H
CONNECTION_FIELD	equ	0001000000000000B

AUTO_CON_ADDRESS	EQU	01H
AUTO_CON_MASK	EQU	10000000B

TPE_address	equ	05H
TPE_type_field	equ	0000000000000001B

int_num_address	equ	00H
int_num_field	equ	1110000000000000B
int_field_shift	equ	13

EE_ETHERNET_ADD_LOW	equ	2
EE_ETHERNET_ADD_MID	equ	3
EE_ETHERNET_ADD_HIGH	equ	4
EE_INT		equ	0
EE_SHIFT	equ	13

;	Slot Width
slot_width_mask	equ	04h
_16_bit_slot	equ	0000h
_8_bit_slot	equ	0001h

_16_bit_override_bit	equ	08h


;
;	EXP16 base port structure
;
@EXP16BasePorts	struc
@Data_Reg	dw	?		;Data Transfer Register.
@Write_Ptr	dw	?		;Write Address Pointer.
@Read_Ptr	dw	?		;Read Address Pointer.
@CA_Ctrl	db	?		;Channel Attention Control.
@Sel_IRQ	db	?		;IRQ Select.
@SMB_Ptr	dw	?		;Shadow Memory Bank Pointer.
	db	?
@MEM_Ctrl	db	?
@MEM_Page_Ctrl	db	?
@Config		db	?
@EEPROM_Ctrl	db	?
@ID_Port	db	?
@EXP16BasePorts	ends

ECR1		equ	300eh

@ISR_Ports	struc
	db	0C008h dup(?)
@SCB_STAT	dw	?
@SCB_CMD	dw	?
@SCB_CBL	dw	?
@SCB_RFA	dw	?
;        @SCB_CRCERRS    dw      ?
;        @SCB_ALNERRS    dw      ?
;        @SCB_RSCERRS    dw      ?
;        @SCB_OVRNERRS   dw      ?
@ISR_Ports	ends


	@memory_page_struc	STRUC
	DB	4000H DUP (?)
	@mem_loc_0	DW	?
	@mem_loc_2	DW	?
	@mem_loc_4	DW	?
	@mem_loc_6	DW	?
	@mem_loc_8	DW	?
	@mem_loc_10	DW	?
	@mem_loc_12	DW	?
	@mem_loc_14	DW	?
	DB	4000H - 16 DUP (?)
	@mem_loc_16	DW	?
	@mem_loc_18	DW	?
	@mem_loc_20	DW	?
	@mem_loc_22	DW	?
	@mem_loc_24	DW	?
	@mem_loc_26	DW	?
	@mem_loc_28	DW	?
	@mem_loc_30	DW	?
	@memory_page_struc	ENDS

;
;
;	TData Segment
;
;	This segment template represents the 64-KB segment that the 82586
;	can address.  Shared memory can be either 32K or 64K for the EXP16.
;	All structures must be quad-word aligned.
;
;	Offset	Type of Block	Block Size	Cnt
;	------	-------------	----------	---
;	0000h	ISCP		8		1
;	0008h	SCB		16		1
;	0020h	CommandBlock	104		1
;	00E0h	SendBlock(s)	1568		variable
;	????h	ReceiveBlock(s)	1568		variable
;	FFF6h	SCP		10		1
;

TData_64	segment at 0

	ISCP	ISysConfigPtr  <>
	SCB	SystemControlBlock <>

	ORG	20H

	CB	CommandBlock	<>

	Send_Blocks	DB	SIZE SendBlock * Number_of_Tx_Buffers dup (?)
	Receive_Blocks	LABEL	WORD


	ORG	(0FFFFh - SIZE SCPS + 1) AND 0FFE0H
	SCP	LABEL	BYTE

	ORG	0FFFFh - SIZE SCPS + 1
	THeapTop	LABEL	BYTE			;Top of available memory

end_of_send_blocks	=	20h + SIZE CommandBlock + (Number_of_Tx_Buffers * SIZE SendBlock)
num_rx_buf_32k	=	(07FFFh - SIZE SCPS + 1 - end_of_send_blocks) / (SIZE ReceiveBlock)
num_rx_buf_64k	=	(0FFFFh - SIZE SCPS + 1 - end_of_send_blocks) / (SIZE ReceiveBlock)

	TData_64	ENDS


	public	int_no
int_no		db	3,0,0,0		;must be four bytes long for get_number.
io_addr		dw	-1,-1		; I/O address for card
encoded_int_no	db	?		;encoded for exp16.

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	91		;from the packet spec
driver_name	db	'EtherExpress16',0	;name of the driver.
driver_function	db	26
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num		dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,
save_err	db	0		;error bits on promiscuous recieve
pro0		db	0
pro1		db	0

	BART_Board_ID	EQU	0BABAH
	BUD_board_ID	EQU	0BABBH
	mca_hp_board_ID	EQU	0BABCH

board_id	dw	?

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
	dw	0			;There is no mode zero
	dw	0
	dw	rcv_mode_2
	dw	rcv_mode_3
	dw	rcv_mode_4	;haven't set up perfect filtering yet.
	dw	0
	dw	rcv_mode_6

;
;	82586 Configuration Parameters
;
	config_params	LABEL	WORD
	num_config_params	LABEL	BYTE	;12 BYTEs
	DB	0CH

	fifo_limit	LABEL	BYTE
	DB	14

	srdy	LABEL	BYTE	;srdy = 1
	save_bad_frame	LABEL	BYTE	;do not save bad frame
	DB	40H

	address_length	LABEL	BYTE	;6 BYTEs
	auto_insert_address	LABEL	BYTE	;auto insert off (1)
	preamble_length	LABEL	BYTE	;2 BYTEs
	internal_loopback	LABEL	BYTE	;0 = OFF  1 = ON
	external_loopback	LABEL	BYTE	;0 = OFF  1 = ON
	DB	2EH	;26h in IPXWS

	linear_priority	LABEL	BYTE	;default is 0
	accel_contention_resolution	LABEL	BYTE	;default is 0
	exp_backoff_method	LABEL	BYTE	;0 = 802.3  1 = Alternate
	DB	00H

	interframe_spacing	LABEL	BYTE	;default is 60H (96 bits)
	DB	60H

	slot_time_low	LABEL	BYTE	;0
	DB	00H

	slot_time_high	LABEL	BYTE	;2
	retry_num	LABEL	BYTE	;15
	DB	0F2H

	promiscuous_mode	LABEL	BYTE	;0 = OFF  1 = ON
	broadcast_disable	LABEL	BYTE	;0 = OFF  1 = ON
	encode_decode	LABEL	BYTE	;0 = NRZ  1 = MANCHESTER
	transmit_on_no_carrier	LABEL	BYTE	;0 = STOP 1 = CONTINUE
	no_crc_insertion	LABEL	BYTE	;0 = OFF  1 = ON
	crc_type	LABEL	BYTE	;0 = 32 bit autodin II
						;1 = 16 bit CCITT
	bit_stuffing	LABEL	BYTE	;0 = 802.3  1 = HDLC
	padding	LABEL	BYTE	;0 = OFF  1 = ON
	DB	00H

	carrier_sense_filter	LABEL	BYTE	;0 = OFF  1 = 0N
	carrier_sense_source	LABEL	BYTE	;0 = external  1 = internal
	collision_detect_filter	LABEL	BYTE	;default = 0
	collision_detect_source	LABEL	BYTE	;0 = external  1 = internal
	DB	00H

	min_frame_length	LABEL	BYTE	;60 BYTEs
	DB	60
	DB	00H	;undefined


RxBufferCount	dw	?
TxBufferCount	dw	?

	Receive_Head	DW	?
	Receive_Tail	DW	?

HEADER_LEN	equ	EADDR_LEN + EADDR_LEN + MAX_P_LEN
	even
our_type	db	HEADER_LEN dup(?)

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.
	extrn	sys_features: byte

	include	io16.asm

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


	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
	cmp	pro1,1
	je	no_size_check1

	cmp	cx,GIANT		; Is this packet too large?
	jna	no_size_check1
	jmp	send_pkt_toobig

no_size_check1:

	push	bp
	mov	bp,io_addr

	disable_board_ints
	cmd_clear	; wait for command processor to clear

	cmp	pro1,1			; on pro drive do not ajust size
	je	oklen

	cmp	cx,RUNT		; minimum length for Ether
	jae	oklen
	mov	cx,RUNT		; make sure size at least RUNT
oklen:
;
; Set SMB pointer to the transmit buffer.
;
	lea	dx,[BP].@SMB_Ptr
	mov	ax,offset send_blocks
	out	dx,ax
;
; Write evenized, padded packet length (>= RUNT bytes) to 586 TBD byte
; count field.  OR on the End of Frame bit.
;
	lea	dx,[BP].@TBD_ByteCount
	mov	ax,cx
	or	ah,byte_BIT_EOF
	out	dx,ax
;
; Set the TxCB command field for transmit.  Also set the EL bit (End of List).
;
	lea	dx, [BP].@TxCB_Command
	mov	ax, BIT_EL+GA_Transmit
	out	dx, ax
;
; Set write pointer to the data buffer for current send block.  Also
; set DX to the data register.
;
	lea	dx, [BP].@Write_Ptr
	mov	ax, offset send_blocks
	add	ax, offset TB_Data
	out	dx, ax
	mov	dx, bp			;@Data_Reg

	inc	cx		;round size up to next even number.
	and	cx,not 1
	call	repoutsw

send_continue:
;
; Set the SCBs command block pointer to this send packet.
;
	lea	dx, [BP].@SCB_CBL
	mov	ax, offset send_blocks
	out	dx, ax

;
; Set the SCB command to start the command unit.
;
	lea	dx, [BP].@SCB_CMD
	mov	ax, CUC_START
	out	dx, ax
	issue_ca

	cmd_clear	; wait for frame transmit to start
	lea	dx,[BP].@SMB_Ptr
	mov	ax,offset send_blocks
	out	dx,ax

	lea	dx,[BP].@TxCB_status
transmiting:
	in	ax,dx

	test	ax,BIT_C		; check status of transmit
	jz	transmiting

	test	ax,BIT_OK		; how was the x-mit
	jnz	tx_ok

	enable_board_ints
	pop	bp
	mov	dh,CANT_SEND
	jmp	tx_bad

tx_ok:
	enable_board_ints

	pop	bp

	clc
	ret

send_pkt_toobig:
	mov	dh,NO_SPACE
tx_bad:
	stc
	ret


;	ReadTickCounter
;
;	Read the 16 bit timer tick count register (system board timer 0).
;	The count register decrements by 2 (even numbers) every 838ns.
;
;	Assumes:	Interrupts disabled
;
;	Returns:	AX with the current count
;			Interrupts disabled

ReadTickCounter:

	push	dx

	mov	dx, 43h				;Command 8254 timer to latch
	xor	al, al				; T0's current count
	out	dx, al

	mov	dx, 40h				;read the latched count
	in	al, dx				; LSB first
	mov	ah, al
	in	al, dx				; MSB next
	xchg	al, ah				;put count in proper order

	pop	dx
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:code
	push	bp
	push	si
;
; Set up individual address command block.
;
	mov	bp,ds:io_addr
	cmd_clear
	mov	bx, BIT_EL+GA_IA_Setup
	call	setup_command_block
	pop	si

;
; Copy individual address command parameters to individual address
; command block.
;
	mov	cx, EADDR_LEN/2
move_node_address:
	lodsw
	out	dx, ax
	loop	move_node_address

;
; Signal 586 to execute individual address command.
;
	mov	ax, CUC_Start
	mov	bx, BIT_CNA
	call	issue_command

	lea	dx, [bp].@SMB_Ptr		;Move IO frame to the command
	mov	ax, offset cb			; command block.
	out	dx, ax

	lea	dx,[BP].@CB_Status
working1:
	in	ax,dx

	test	ax,BIT_C		; check status of set_ia
	jz	working1

	test	ax,BIT_OK
	jnz	set_ok
	stc
	jmp	set_address_done

set_ok:
	mov	cx,5000h		; on 486's if we do not delay this command does not work
set1:
	mov	bx,cx
	mov	ax,[bx]
	loop	set1			; just for delay

	mov	cx,EADDR_LEN		;return their address length.
	clc
set_address_done:
	pop	bp
	ret


rcv_mode_2:
	and	promiscuous_mode,not 3
	or	promiscuous_mode,2	;disable broadcasts.
	mov	min_frame_length,60
	and	save_bad_frame,not 80h
	mov	pro0,0
;;;	mov     pro1,0			;not present in NSA version
	jmp	short configure_command
rcv_mode_4:
rcv_mode_3:
	and	promiscuous_mode,not 3	;clear promiscuous mode.
	mov	min_frame_length,60
	and	save_bad_frame,not 80h
	mov	pro0,0
;;;	mov     pro1,0			;not present in NSA version
	jmp	short configure_command
rcv_mode_6:
	and	promiscuous_mode,not 3
	or	promiscuous_mode,1	;set promiscuous mode.
	mov	min_frame_length,60	;allow runt. but let it come in as a bad frame
	or	save_bad_frame,80h	; yes we want bad frames here
	mov	pro0,1
	mov	pro1,1
;
configure_command:
	mov	bp,io_addr
;
; Set up configure command block.
;
	mov	bx, bit_el + GA_Configure	;Set command block for a
	call	setup_command_block		; configure command. BIT_EL
						; means last command.
;
; Copy configure command parameters to configure command block.
;
	mov	si,offset config_params		;Set DS:SI to parameters and
	mov	cx, 6				; copy them to the command

move_config_params:

	lodsw
	out	dx, ax
	loop	move_config_params
;
; Signal 586 to execute configure command.
;
	mov	ax, CUC_Start
	mov	bx, BIT_CNA
	call	issue_command
	ret


;*****************************************************************
; TDR cable tester
; enter with es:di pointing to time int
;*****************************************************************

	public	do_tdr
do_tdr:
	push	bp
	push	es
	push	di
	mov	bp,io_addr
;
; Set up configure command block.
;
	mov	bx, bit_el + GA_TDR	;Set command block for a
	call	setup_command_block		; TDR command. BIT_EL
						; means last command.
; Signal 586 to execute configure command.
;
	mov	ax, CUC_Start
	mov	bx, BIT_CNA
	call	issue_command

	lea	dx, [bp].@SMB_Ptr		;Move IO frame to the command
	mov	ax, offset cb			; command block.
	out	dx, ax

	lea	dx,[BP].@CB_Status
working:
	in	ax,dx

	test	ax,BIT_C		; check status of transmit
	jz	working

	lea	dx,[bp].@CB_Parm0
	in	ax,dx

	pop	di
	pop	es
	pop	bp

	test	ax,LNK_OK
	jz	tdr_bad_cable
	clc
	ret

tdr_bad_cable:

	push	ax
	and	ax,TDR_TIME
	stosw	; store time
	pop	ax

	mov	cl,12
	shr	ax,cl
	and	ax,7
	mov	dh,al

	stc
	ret


;
;	BX = 586 command word
;
setup_command_block:

;
; Setup command block's command, status, and link fields.
;
	lea	dx, [bp].@SMB_Ptr		;Move IO frame to the command
	mov	ax, offset cb			; command block.
	out	dx, ax

	lea	dx, [bp].@CB_link		;Set command block's link to
	out	dx, ax				; itself.

	lea	dx, [bp].@SCB_CBL		;Point SCB command list
	out	dx, ax				; pointer to command block.

	lea	dx, [bp].@CB_command		;Set command block's command
	mov	ax, bx				; word to value passed in
	out	dx, ax				; BX.

;
; Return with the write pointer set to the command block parameter
; offset.
;
	lea	dx, [bp].@Write_Ptr		;Set write pointer to command
	lea	ax, CB.CB_Param0		; parameter field.
	out	dx, ax

	mov	dx, bp			;@Data_Reg
	ret


;
; Wait for 586 command register to be clear (  1 millisecond max)
; Issue command
; Wait for command to complete              (500 milliseconds max)
; Acknowledge command complete
;
;
issue_command:

;
; Make sure 586 command in SCB is clear.
;
	mov	cx, ax
	cmd_clear
	jc	issue_command_error_exit
	mov	ax, cx
;
; Put command code in AX into SCB command register and signal the
; 586 to look at it.  The cmd_clear macro leaves DX pointing to
; the SCB command register.
;
	out	dx, ax
	issue_ca

wait_for_commad_status_outer_loop:
;
; Wait here for 586 to complete the command.  586 should never take
; more than 500 Milliseconds to complete a command.
;
	call	readtickcounter
	mov	cx, ax
	lea	dx, [bp].@SCB_STAT

wait_for_commad_status:

	in	ax, dx
	cmp	ax, bx
	je	acknowledge_command_complete

	call	readtickcounter
	neg	ax
	add	ax, cx
	cmp	ax, ten_mils
	jb	wait_for_commad_status

_586_command_error:
;
; Signal error by pointing AX to error message, and setting
; condition codes.
;
	mov	dx,offset _586_not_responding_msg
	stc
issue_command_error_exit:
	ret

acknowledge_command_complete:
;
; Tell the 586 that we know its done by copying the status back to
; the command register's acknowledge fields.  BX has status.
;
	lea	dx, [bp].@SCB_CMD
	out	dx, ax
	issue_ca
;
; Signal no error.
;
	xor	ax, ax
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error hf we didn't.
	mov	dh,NO_MULTICAST
	stc
	ret


	public	terminate
terminate:
	push	bp
	mov	bp,io_addr

	cmd_clear	; wait until last command is done processing

	disable_board_ints	; shut off board ints

	lea	dx,[bp].@SCB_CMD
	mov	ax, RUC_SUSPEND		; suspend recieve unit
	out	dx, ax
	issue_ca

	pop	bp			; now ok to un-hook interrupts and release
	ret	; driver

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
;	extrn	resource_err_in:word

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code
;
; Set BP to the base IO address of exp16.  Also disable exp16s ability
; to generate interrupts.
;
	mov	bp,io_addr
	disable_board_ints
;
; Make sure that command unit is clear before reading the status.
;
	cmd_clear
;
; Get the SCB status to see why exp16 interrupted us.  Also need to
; copy the status back to the command word to acknowledge the 586
; interrupt.  Issue channel attention to get the 586 to realize the
; interrupt aknowledge.
;
;	lea	dx, [bp].@SCB_RSCERRS
;	in	ax,dx
;	mov	word ptr resource_err_in,ax
;	lea	dx, [bp].@SCB_OVRNERRS
;	in	ax,dx
;	add	word ptr resource_err_in,ax

	lea	dx, [bp].@SCB_STAT
	in	ax, dx
	and	ax, ACK_INT_MASK

	lea	dx, [bp].@SCB_CMD
	out	dx, ax
	issue_ca	; AX is not changed.
;
; Check for frame receive status.  Jump if no frames received,
; otherwise processes the receive.
;
	test	AX, BIT_FR OR BIT_RNR
	jz	ExitDriverISR
	call	ProcessRx
ExitDriverISR:
;
; Here if there was a bad receive status.  Make sure the receive unit
; of the 586 is running.  Read in the SCB status and jump if we need
; to restart the receive unit.  We choose to have the jump to restart
; the RU since most of the time we will not need to do this.  This
; saves cycle times when exiting without a restart.
;
	lea	dx, [bp].@SCB_STAT
	in	ax, dx
	test	ax, READY
	jz	restart_RU

drvisr_continue:
	enable_board_ints
	ret


restart_RU:
;
; Need to restart the receive unit of the 586.  Set the SCB pointer to
; the receive frame area.
;
	lea	dx, [bp].@SCB_RFA
	mov	ax, Receive_Head
	out	dx, ax
;
; Make sure 586 is in a state to accept a command.
;
	cmd_clear
;
; Put the receive unit start command into the SCB command word and
; issue the channel attention.
;
; NOTE: cmd_clear macro leaves DX pointing to the SCB command word.
;
;	lea	dx, [bp].@SCB_CMD
	mov	ax, RUC_START
	out	dx, ax
	issue_ca
	jmp	drvisr_continue


ProcessRx:

;
; Prime the pump that services receives by setting AX to the receive
; head.  There could be over 30 packets received.
;
	mov	ax,Receive_Head

CheckNextReceiveStatus:

;
; Save receive head pointer in BX.  BX should not be altered during
; this loop.
;
	mov	bx, ax
;
; Set SMB pointer to the top of the receive frame.
;
	lea	dx, [bp].@SMB_Ptr
	out	dx, ax
;
; Get the status for this receive frame.  Check to make sure that
; it completed with no errors.  If not, then jump to check the
; 586 receive unit.
;
	lea	dx, [bp].@FD_Status
	in	ax, dx

	mov	save_err,1		; be sure we done accdently report an error

	test	ax, BIT_C		; command compleat
	jz	PRx_no
	test	ax,BIT_OK		; good frame
	jnz	ProcessRx_1

	call	count_in_err
	mov	save_err,0
	cmp	pro0,1
	je	PRx_bad			; if not in pro-mode lose bad frames and inc error
;	call	count_in_err
	jmp	recv_isr_9
PRx_no:
	ret

PRx_bad:
	mov	dh,0			;build save_err.
	test	ax,BIT_S7
	jz	PR_no_frag
	or	dh,2
PR_no_frag:
	test	ax,BIT_S11
	jz	PR_no_crc
	or	dh,4
PR_no_crc:
	test	ax,BIT_S10
	jz	PR_no_align
	or	dh,8
PR_no_align:
	test	ax,BIT_S8
	jz	PR_no_dma
	or	dh,16
PR_no_dma:
	test	ax,BIT_S9
	jz	PR_no_ru
	or	dh,32
PR_no_ru:
	mov	save_err,dh

ProcessRx_1:
;
; Set the read pointer to access the LengthTypeField.
;
; NOTE: BX was set to receive head at the beginning of this
;       procedure.
;
	lea	dx, [bp].@Read_Ptr
	lea	ax, [BX].IPX_DestAddr_HIGH
	out	dx, ax
	mov	dx, bp			;@Data_Reg

	mov	ax,cs
	mov	es,ax
	mov	di,offset our_type
	mov	cx,HEADER_LEN
	call	repinsw

;
; Get the packet size from the 586 data structure.
;
	lea	dx, [bp].@RBD_ByteCount
	in	ax, dx
	and	ah, 3fh
	mov	cx, ax

	mov	di,offset our_type+EADDR_LEN+EADDR_LEN

	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp	ax, 1518
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
	push	bx
	push	cx			; for some reison recv_find trashes cx
	mov	dh,save_err
	call	recv_find
	mov	bp,cs:io_addr		; just in case
	pop	cx
	pop	bx

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_isr_9		;yes - just free the frame.
	push	es			;remember where the buffer pointer is.
	push	di
	push	cx
  if 0
;
; Copy the packet's header into their buffer.
;
	push	cx
	mov	si,offset our_type
	mov	cx,HEADER_LEN/2
	rep	movsw
	pop	cx
	sub	cx,HEADER_LEN
  endif
;
; Set the read pointer to access the packet.
;
; NOTE: BX was set to receive head at the beginning of this
;       procedure.
;
	lea	dx, [bp].@Read_Ptr
  if 0
	lea	ax, [BX].IPX_DestAddr_HIGH + HEADER_LEN
  else
	lea	ax, [BX].IPX_DestAddr_HIGH
  endif
	out	dx, ax
	mov	dx, bp			;@Data_Reg
;
; Now read the packet into es:di
;
	call	repinsw

	pop	cx
	pop	si
	pop	ds
	assume	ds:nothing
	call	recv_copy		;tell them that we copied it.
	mov	ax,cs			;restore our ds.
	mov	ds,ax
	assume	ds:code

recv_isr_9:
;
; Restore SMB pointer to the top of the receive frame.
;
	mov	bp,io_addr		; just in case
	mov	ax,bx
	lea	dx, [bp].@SMB_Ptr
	out	dx, ax

;
; Clear the current receive frames status.
;
	lea	dx, [bp].@FD_Status
	xor	ax, ax
	out	dx, ax
;
; Set the end of list bit for the current receive frame.
;
	lea	dx, [bp].@FD_command
	mov	ax, BIT_EL
	out	dx, ax
;
; Read in the pointer to the next receive frame.
;
	lea	dx, [bp].@FD_Link
	in	ax, dx
;
; Update our local pointer to the receive resources:
;
; Receive_tail <-- Receive head
; Receive_head <-- next receive frame.
;
	mov	BX, Receive_Head
	mov	Receive_Tail, BX
	mov	Receive_Head, AX
	mov	cx, ax
;
; Clear previous receive frame descriptors end of list bit to free up
; a receive resource.  We do this by moving the write pointer to the
; the command word in the previous receive frame and then writing a
; zero to it.
;
	lea	dx, [bp].@Write_Ptr
	lea	ax, [bx].FD_command
	out	dx, ax

	mov	dx, bp			;@Data_Reg
	xor	ax, ax
	out	dx, ax
;
; Check for another receive frame.
;
	mov	ax, cx
	jmp	CheckNextReceiveStatus



; This procedure is called from the cmd_clear macro after the macro determines
; that we must wait for a command to clear.
;
;	 MUST NOT TRASH CX OR THE ISSUE_COMMAND PROCEDURE WILL FAIL.
;
cmd_wait:
;enter with dx -> SCB_CMD
;exit with nc if it cleared in one millisecond, cy if not.

	call	readtickcounter			;Reference clock.  die after
	mov	bx, ax				; 1 ms.

wait_cmd_clear:

	in	ax, dx				;Read SCB command
	or	ax, ax				;Wait for command accepted
	jz	exit

	call	readtickcounter
	neg	ax
	add	ax, bx

	cmp	ax, one_mil
	jb	wait_cmd_clear

	stc
exit:
	ret


	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public	end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte


	public	usage_msg
usage_msg	db	"usage: exp16 [options] <packet_int_no> <io_addr>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for the Intel EtherExpress 16, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
	db	"Copyright 1991 Intel Corp",CR,LF
	db	"Portions Copyright 1993 Crynwr Software",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> dword to print.
	extrn	print_number: near


;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

chan_sel	db	0	;Channel select for SYS_MCA machines

	public	etopen
etopen:
;initialize the driver.
	assume	ds:code
;
; Get board information (Node address, etc.).  Returns with BP
; set to the board IO base address (if not errors).
;
	call	get_system_info
	jc	driver_init_error_exit

	disable_board_ints
;
; If they're in an 8-bit slot, make sure that they aren't using the slave PIC.
;
	cmp	_16_not_8_bit_slot,0	;are they using a 16-bit slot?
	jne	check_config_exit	;yes -- cool.

	mov	dx,offset irq_config_error
	cmp	int_no, 9		;no - don't let them use the upper IRQs.
	jb	check_config_exit
driver_init_error_exit:
	stc
	ret
check_config_exit:

;
; Initialize the 586 and the 586 data structures.
;
	call	init_586
	jc	driver_init_error_exit

; test iochrdy
	test	sys_features,SYS_MCA
	jnz	skip_iochrdy_test
	call	iochrdy_test
skip_iochrdy_test:

	cmp	connection_type,CONN_AUTO
	jne	no_auto_con
	call	auto_connector
	jnc	did_auto_con
	mov	dx,offset no_wire_msg
	mov	ah,9
	int	21h
	jmp	short	did_auto_con
no_auto_con:
	call	write_connector_setting_to_hardware
did_auto_con:

;
; Set up Interrupt line, start the receive unit, and Enable exp16s interrupt.
;
	call	set_recv_isr
	call	ru_start
	enable_board_ints	;;; only one left in broken version.

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

write_connector_setting_to_hardware:
	assume	ds:code
	test	sys_features,SYS_MCA
	je	isa_connector_bart

	mov	bl,80h
	cmp	connection_type,CONN_TPE	;did they ask for TPE?
	je	mca_tpe_connector
	mov	bl,0
mca_tpe_connector:

	call	enable_slot
	mov	dx,102h			;stuff the AUI/Other bit in.
	in	al,dx
	and	al,not 04h
	cmp	connection_type,CONN_AUI
	je	mca_tpe_connector_1
	or	al,04h
mca_tpe_connector_1:
	out	dx,al

	mov	dx,103h			;stuff the BNC/TPE bit in.
	in	al,dx
	and	al,not 80h
	cmp	connection_type,CONN_BNC
	je	mca_tpe_connector_2
	or	al,80h			;<>0 means TPE
mca_tpe_connector_2:
	out	dx,al
	call	disable_slot

	jmp	no_connector_bart
isa_connector_bart:
	cmp	board_id,BART_Board_ID	;a real BART?
	je	no_connector_bart	;yes, it doesn't *have* an ECR1.
	mov	bp,io_addr
	lea	dx,ECR1[bp]
	in	al,dx
	and	al,not 82h		;turn off Other/not_AUI (read as
					;   MCA/ISA), and TPE/not_BNC
	cmp	connection_type,CONN_AUI
	je	set_connector_bart
	or	al,80h			;set Other/not_AUI
	cmp	connection_type,CONN_BNC
	je	set_connector_bart
	or	al,02h			;set TPE/not_BNC
set_connector_bart:
	out	dx,al
no_connector_bart:

	mov	cx,10			;10*10 milliseconds = 100 millis
	cmp	connection_type,CONN_AUI
	jne	set_connector_delay
	mov	cx,50			;50*10 milliseconds = 500 millis
set_connector_delay:
; Our delay procedure can not accept a value over 27 milliseconds,
; so we use a loop to delay the 100 milliseconds.
set_connector_delay_1:
	push	cx
	mov	di, ten_mils
	call	eeprom_delay
	pop	cx
	loop	set_connector_delay_1
	ret


; int number to IRQ translate table.
IRQ_xlat_table	LABEL	BYTE
	db	 12, 2, 3, 4, 5, 10, 11, 15

io_addresses	label word
	dw	300h,310h,320h,330h,340h,350h,360h,370h
	dw	200h,210h,220h,230h,240h,250h,260h,270h
	dw	0

enable_slot:
	mov	al,chan_sel
	out	96h, al			; select channel
	mov	al, 0ffh
	out	94h, al			; protect system board
	ret

disable_slot:
	xor	al,al			;disable pos
	out	96h,al
	ret

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	test	sys_features,SYS_MCA
	jne	parse_args_mc
	jmp	parse_args_1

parse_args_mc:
;The following code to read the POS registers is courtesy of Racal-Interlan.

; channel selector resides at io 96h
; POS register base is at io 100h
; EXP16/MC ID is 0628bh

; search thro' the slots for a EXP16/MC card
	mov	cx, 8			; for all channels(slots)

; channel select value for slots 0,1,2.. is 8,9,A etc
; start with slot 0, and then 7,6,5,4,3,2,1
get_05:
	mov	ax, cx			; channel number
	or	ax, 08h			; reg. select value
	mov	chan_sel,al		; save each one, the LAST will right

; read adapter id
	call	enable_slot
	mov	dx, 101h
	in	al, dx			; adapter id - ms byte
	mov	ah, al
	dec	dx
	in	al, dx			; adapter id - ls byte

; Check if EXP16/MC
	cmp	ax, 0628bh
	je	get_10
	loop	get_05

	call	disable_slot

	mov	dx,offset Board_Not_Installed
	stc
	ret

get_10:
; found our Adapter
	call	write_pos_to_eeprom

	clc
	ret

parse_args_1:
	mov	di,offset io_addr
	call	get_number
	clc
	ret

	include	exp16mca.asm

;-----------------------------------------------------------------------------
; It is safe to assume that the command unit is up and running ready
; for the first send.  And that there are at least two send buffers 
; available.
;
; This procedure works by sending a 64 byte packet to itself.  We do not turn
; on loopback, so we do not expect to see a receive.  Instead, we
; expect to see that the send completed OK.  If the send does not complete OK, 
; then this routine switches to other connectors and the test is repeated. 
;-----------------------------------------------------------------------------
auto_connector:

; Let's start doing the test send with AUI option first.  If we tried BNC
; first, and they were using AUI, it would seem like the BNC worked.  So
; we switch to AUI, which turns off the BNC power supply.
	MOV	connection_type, CONN_AUI
	CALL	write_connector_setting_to_hardware

; Test connection to see if it works.  Jump if it does.
	call	test_send
	clc
	je	auto_connector_exit

; Toggle AUI/Other setting and try to send a packet.  Jump if send 
; works.  Now try sending on BNC.
	MOV	connection_type, CONN_BNC
	CALL	write_connector_setting_to_hardware
	call	test_send
	clc
	je	auto_connector_exit

; Here if we just tried a send the BNC.  If this is 
; a three connector card, then we toggle the BNC/TPE setting.
; Jump if connection is found.
	MOV	connection_type, CONN_TPE
	CALL	write_connector_setting_to_hardware
	call	test_send
	clc
	je	auto_connector_exit
	stc
auto_connector_exit:
	ret


test_packet	label	byte
	db	EADDR_LEN dup(?)
	db	EADDR_LEN dup(?)
	db	00h,2eh			;A 46 in network order
	db	0,0			;DSAP=0 & SSAP=0 fields
	db	0f3h,0			;Control (Test Req + P bit set)

; This procedure sends a packet on the wire and wait for the send to
; complete.  It the checks to see if the send completed OK and returns
; the results.
test_send:

	mov	si,offset rom_address	;set the destination address.
	movseg	es,cs
	mov	di,offset test_packet
	repmov	EADDR_LEN
	mov	si,offset rom_address	;set the source address.
	repmov	EADDR_LEN

	mov	cx,60
	mov	si,offset test_packet
	call	send_pkt

	call	ReadTickCounter
	mov	cx, ax

	mov	bp,io_addr
	lea	dx, [bp].@TxCB_Status
send_test_wait:
	in	ax,dx
	test	ax,8000h		;did it finish?
	jne	send_test_done

; See if we have been here for a millisecond.  Jump if not.
	call	ReadTickCounter
	neg	ax
	add	ax, cx
	cmp	ax, one_mil
	jb	send_test_wait

	in	ax,dx			;get the transmit status back again.

send_test_done:

	mov	cx, ax			; Save status in CX.

	xor	ax, ax			; Clear the transmit command block status.
	out	dx, ax

; Send is complete.  Get the status and compare to OK send and return.
; Save flags for return.

	and	cx, 0f000h
	cmp	cx, 0a000h
	ret

no_wire_msg		db	"***Unable to detect a cable on any connector***",CR,LF,'$'
bnc_connector_msg	db	"Using the BNC connector",CR,LF,'$'
aui_connector_msg	db	"Using the AUI connector",CR,LF,'$'
tpe_connector_msg	db	"Using the twisted-pair connector",CR,LF,'$'

_8_bit_slot_msg	db	"The board is in an 8-bit slot",CR,LF,'$'
_16_bit_slot_msg	db	"The board is in a 16-bit slot",CR,LF,'$'

badset_msg	db	"Set Address Command Failed",CR,LF,'$'


	public	print_parameters
print_parameters:
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	io_addr.segm,0
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number

	mov	dx,offset bnc_connector_msg	;print the connection type.
	cmp	connection_type,CONN_BNC
	je	print_parameters_1
	mov	dx,offset aui_connector_msg
	cmp	connection_type,CONN_AUI
	je	print_parameters_1
	mov	dx,offset tpe_connector_msg
print_parameters_1:
	mov	ah,9
	int	21h

	mov	dx,offset _16_bit_slot_msg	;print the slot size.
	cmp	_16_not_8_bit_slot,0
	jne	print_parameters_2
	mov	dx,offset _8_bit_slot_msg
print_parameters_2:
	mov	ah,9
	int	21h

	ret


init_586:
;enter with bp=io_addr, 586 reset.

;
; Set the number of transmit and receive buffers according to the
; amount of RAM on the adapter.
;
	MOV	AX, Number_of_Tx_Buffers
	MOV	BX, num_rx_buf_32k

	cmp	_64K_not_32K,0
	je	save_number_of_buffers

	MOV	BX, num_rx_buf_64k

save_number_of_buffers:

	MOV	TxBufferCount, AX
	MOV	RxBufferCount, BX
;
; initialize SCP.  Move IO frame to top of SCP.
;
	LEA	DX, [bp].@SMB_Ptr
	MOV	AX, OFFSET scp
	OUT	DX, AX
;
; Write initial SCP values:
;	bus width	0 = 16 bit   1 = 8 bit.
;	ISCP address	always found at address 000000.
;
	LEA	DX, [BP].@SCP_SystemBus
	MOV	AL, bus_width
	OUT	DX, AX

	LEA	DX, [BP].@SCP_ISCP_Ptr_low
	XOR	AX, AX
	OUT	DX, AX
	LEA	DX, [BP].@SCP_ISCP_Ptr_high
	OUT	DX, AX

;
; Initialize ISCP.  Move IO frame to top of ISCP.  NOTE: AX falls
; through as zero.
;
	LEA	DX, [bp].@SMB_Ptr
	OUT	DX, AX
;
; Write initial ISCP values:
;	ISCP BUSY	1 = Indicates 586 is in initialization
;			process.  586 sets this byte to 0 when
;			initialization is complete.
;
;	SCB address     Always 000008
;
	LEA	DX, [BP].@iscp_busy
	MOV	AX, initialize_586
	OUT	DX, AX

	LEA	DX, [BP].@ISCP_SCB_Ptr_low
	XOR	AX, AX
	OUT	DX, AX
	LEA	DX, [BP].@ISCP_SCB_Ptr_high
	OUT	DX, AX
	LEA	DX, [BP].@iscp_scb_offset
	MOV	AX, OFFSET scb
	OUT	DX, AX

;
; Initialize SCB.  Move Write Ptr to top of SCB.  NOTE: AX falls
; through as offset to SCB.
;
	XOR	AX, AX
	LEA	DX, [BP].@SCB_Status
	OUT	DX, AX
	LEA	DX, [BP].@SCB_Command
	OUT	DX, AX
	LEA	DX, [BP].@SCB_CommandList
	OUT	DX, AX
	LEA	DX, [BP].@SCB_RecBlockList
	OUT	DX, AX
	LEA	DX, [BP].@SCB_CRC_Errors
	OUT	DX, AX
	LEA	DX, [BP].@SCB_ALN_Errors
	OUT	DX, AX
	LEA	DX, [BP].@SCB_RSC_Errors
	OUT	DX, AX
	LEA	DX, [BP].@SCB_OVR_Errors
	OUT	DX, AX

;
; Initialize Receive Block(s).  First set head pointer and link from
; SCB to first frame descriptor.  NOTE: IO frame points to ISCB.
; The SCB link field can be addresses becasue the SCB is physically
; contiguous to the ISCB.
;
	mov	ax,offset Receive_Blocks
	lea	dx, [bp].@SCB_RecBlockList	;IO address of SCB RF link
	out	dx, ax

;
; Initialize the frame descriptor structures.  Move the Write ptr
; the top of the current frame descriptor.  AX falls through with the
; offset to the first frame descriptor.  DI is used to keep track of
; the address of the current frame descriptor.  The frame descriptor,
; receive buffer descriptor, and receive buffer are all contiguous in
; memory, and make up the frame descriptor structure.
;
	MOV	DI, AX				;DI is current frame descriptor
	MOV	RECEIVE_HEAD, DI
	MOV	CX, RxBufferCount		;CX is number of frame
						; descriptors to initialize.
init_receive_frames:

	LEA	DX, [bp].@SMB_Ptr
	MOV	AX, DI				; descriptor.
	OUT	DX, AX

;
; Init Frame Descriptor (FD).
;
	XOR	AX, AX				;Init frame descriptor status
	LEA	DX, [BP+4000H]
	OUT	DX, AX				; and command to zero.
	LEA	DX, [BP+4002H]
	OUT	DX, AX

	MOV	AX, RECEIVE_HEAD		;Init frame descriptors link
	CMP	CX, 1				; to next frame descriptor.
	JE	next_receive_link		; If this is the last receive
						; block, then set its link to
	LEA	AX, [DI+SIZE ReceiveBlock]	; the first receive block.

next_receive_link:

	LEA	DX, [BP+4004H]
	OUT	DX, AX

	LEA	AX, [DI+OFFSET RBD_ByteCount] ;Init frame descriptors
	LEA	DX, [BP+4006H]
	OUT	DX, AX			; link to its receive buffer descriptor.
;
; Init Receive Buffer Descriptor (RBD).
;
	LEA	DX, [BP+4008H]
	OUT	DX, AX			;Init the RBD Actual count to zero.

	MOV	AX, -1			;Init the RBD link to next RBD
	LEA	DX, [BP+400AH]
	OUT	DX, AX			; to minus 1 (unused link).

	LEA	AX, [DI+RB_Data]	;Init the RDB link to the data
	LEA	DX, [BP+400CH]
	OUT	DX, AX			; buffer.
	XOR	AX, AX
	LEA	DX, [BP+400EH]
	OUT	DX, AX

	MOV	AX, RxBufferSize OR BIT_EL	;Init the RBD count and status
	LEA	DX, [BP+8000H]
	OUT	DX, AX

	MOV	RECEIVE_TAIL, DI	;Set receive tail pointer.
	ADD	DI, SIZE ReceiveBlock	;Point DI to next frame
	LOOP	init_receive_frames	; descriptor.
;
; Initialize the send block structures.  Move the Write pointer the
; top of the current send block.  AX falls through with address of
; first send block.  DI is used to keep track of the address of the
; current send block.  The Transmit command block, transmit buffer
; descriptor, and transmit buffer are all contiguous in memory, and
; make up the send block structure.
;
	MOV	DI, OFFSET send_blocks
	MOV	CX, TxBufferCount

	LEA	DX, [BP].@SMB_Ptr
	XOR	AX, AX
	OUT	DX, AX

	MOV	AX, DI
	LEA	DX, [BP].@SCB_CommandList
	OUT	DX, AX

init_send_blocks:

	LEA	DX, [BP].@SMB_Ptr		;Set write pointer to send
	MOV	AX, DI				; block.
	OUT	DX, AX
;
; Init Transmit Control Block (TCB).
;
	XOR	AX, AX			;Init transmit control block
	LEA	DX, [BP+4000H]
	OUT	DX, AX			; status to zero.

	LEA	DX, [BP+4002H]
	OUT	DX, AX			;Init transmit control block
					; command to anything.  The
	MOV	AX, offset send_blocks	; Init transmit control block
	CMP	CX, 1			; link to next send block.
	JE	next_send_link		; If this is the last send
					; block, then point it to
	LEA	AX, [DI+SIZE SendBlock]	; the first block.

next_send_link:

	LEA	DX, [BP+4004H]
	OUT	DX, AX

	LEA	AX, [DI+OFFSET TBD_ByteCount]	;Init transmit control block
	LEA	DX, [BP+4006H]
	OUT	DX, AX				; link to Transmit Buffer
						; descriptor.
;
; Init Transmit Buffer Descriptor (TBD).
;
	LEA	DX, [BP+4008H]
	OUT	DX, AX			;Init Transmit Buffer Descriptor
					;  byte count to anything
	MOV	AX, -1			;Init Transmit Buffer Descriptor
	LEA	DX, [BP+400AH]
	OUT	DX, AX			;  link to next TBD.

	LEA	AX, [DI+OFFSET TB_Data]	;Init Transmit Buffer Descriptor
	LEA	DX, [BP+400CH]
	OUT	DX, AX			; link to transmit
	XOR	AX, AX			; buffer.  Low part of pointer
	LEA	DX, [BP+400EH]
	OUT	DX, AX			; is done first.

	ADD	DI, SIZE SendBlock		;Point DI to next send block
	LOOP	init_send_blocks		; and loop to initialize it.

;
; Enable loopback to insure nothing acidently hits the cable while
; the 586 gets initialized.
;
	LEA	DX, [BP].@Config
	IN	AX, DX
	OR	AL, loopback_enable
	OUT	DX, AL
;
; Free the 586 from reset.
;
	CALL	free_586_reset
;
; Initialize and configure the 586.  Carry flag set means error and
; dx will point to error message.
;
	CALL	init_cmd
	mov	dx,offset bad_init_msg
	jc	init_exp16_ram_exit

	CALL	configure_command
	mov	dx,offset bad_config_msg
	jc	init_exp16_ram_exit

	CALL	diagnose_command
	jc	init_exp16_ram_exit

	movseg	es,cs
	mov	si,offset rom_address
	mov	cx,EADDR_LEN
	call	set_address
	jnc	sa_ok

	mov	dx,offset badset_msg
	mov	ah,9
	int	21h
sa_ok:
;
; Disable loopback.
;
	LEA	DX, [BP].@Config
	IN	AX, DX
	AND	AL, NOT loopback_enable
	OUT	DX, AL

	clc
	ret

init_exp16_ram_exit:
	stc
	RET


; This procedure must wait until the ASIC finishes reset.  This will take
; around 240 uSec.  This loop will time out after 500 uSec.
;
	five_hundred_micros	EQU	1194
;
reset_board:
;enter with bp=io_addr

	LEA	DX, [BP].@EEPROM_Ctrl
	MOV	AL, ASIC_Reset
	OUT	DX, AL

	XOR	AL, AL
	OUT	DX, AL

;
; Get current tick count.  This loop will wait for 500 uSec to pass
; before failing.
;
	CALL	ReadTickCounter
	MOV	BX, AX

reset_delay:

	PUSH	BX
	LEA	DX, [BP].@ID_Port	; Set DX to the auto-id port.
	CALL	check_for_exp16_hardware
	POP	BX

	CMP	AX, BART_Board_ID
	JE	reset_board_exit

	CALL	ReadTickCounter
	NEG	AX
	ADD	AX, BX
	CMP	AX, five_hundred_micros
	JB	reset_delay

	mov	dx, offset reset_error
	stc
	RET

reset_board_exit:

	MOV	BX, AX
	clc
	RET


reset_586:
;enter with bp = io_addr
	lea	dx, [bp].@EEPROM_Ctrl
	mov	al, _586_Reset
	out	dx, al
	ret


free_586_reset:
;enter with bp = io_addr
	lea	dx, [bp].@EEPROM_Ctrl
	xor	al, al
	out	dx, al
	ret

check_for_exp16_hardware:
;enter with dx = ID port (or maybe shadow ID port).
;
; BX will have board ID when the loop is done.  CX is the loop count.
;
	XOR	BX, BX
	MOV	CX, 4

get_board_id_loop:
;
; Init registers for loop.  CX needs to be used in the loop, and AH
; could be set from the last loop.
;
	PUSH	CX
	XOR	AH, AH
;
; Read ID port.  See description above.
;
	IN	AL, DX
;
; Make nibble ID a shift count in CL.
;
	MOV	CL, AL
	AND	CL, 00000011B
	SHL	CL, 1
	SHL	CL, 1
;
; Move ID nibble to low order bits of AX, then shift then into place.  Put
; the board ID nibble into BX.  After four passes, BX will have board ID.
;
	SHR	AL, 1
	SHR	AL, 1
	SHR	AL, 1
	SHR	AL, 1
	SHL	AX, CL
	OR	BX, AX
;
; Recover loop count, and loop.
;
	POP	CX
	LOOP	get_board_id_loop
;
; Return board ID in AX.
;
	MOV	AX, BX
	RET


;
; Command #1:  Initialize
;
init_cmd:
	XOR	AX, AX				; Init command
	MOV	BX, BIT_CX + BIT_CNA		; status
	CALL	issue_command
	RET

diagnose_command:
;return nc if no problem, else cy,dx->error message.
;
; Set up individual address command block.
;
	MOV	BX, BIT_EL+GA_diagnose
	CALL	setup_command_block
;
; Execute the diagnose command.
;
	MOV	AX, CUC_Start
	MOV	BX, BIT_CNA
	CALL	issue_command
;
; Check diagnostics results.
;
	LEA	DX, [BP].@SMB_Ptr		;Move IO frame to the command
	MOV	AX, OFFSET cb			; command block.
	OUT	DX, AX

	LEA	DX, [BP].@mem_loc_0		;Read in the diagnose status
	IN	AX, DX				; word.
;
; Assume 586 failed the test.  Set AX to an error message and exit
; with the zero bit cleared.
;
	test	ax, 0800H			;Test failure bit.  If set,
	jnz	diagnose_error			; then error exit.
	clc
	ret
diagnose_error:
	mov	dx,offset _586_diagnostic_failure
	stc
	ret


;
; Command #4:  RU_START
;
ru_start:
;
; Set SCBs pointer to receive blocks at head of list.
;
	lea	dx, [bp].@SCB_RFA		;Set pointer to receive blocks
	mov	ax, receive_head		; to the head of the receive
	out	dx, ax				; block list.
;
; Signal 586 to start the receive unit.  cmd_clear leaves DX pointing
; to SCB command register.
;
	cmd_clear
	mov	ax, ruc_start
	out	dx, ax
	issue_CA
	ret


find_a_board:
	mov	bx,offset io_addresses
no_exp16_here:
	mov	bp,[bx]
	cmp	bp,0
	je	no_exp16s
	inc	bx
	inc	bx
	push	bx
	call	reset_board
	pop	bx
	jc	no_exp16_here

	clc
	ret

no_exp16s:
	stc
	ret

get_system_info:
;exit with zr if okay, or nz, dx -> error message if not okay.
	cmp	io_addr,-1
	jne	addr_override
	call	find_a_board
	jnc	board_id_ok
	jmp	bad_or_no_board

addr_override:

	MOV	bp, io_addr

;
; Next, get the exp16 board ID.  If the ID is not what we expect, then
; exit with error code in AX.
;
	call	reset_board
	jnc	board_id_ok
;
; Could search for exp16 board, but we error exit instead.
;
bad_or_no_board:

	mov	dx, offset board_not_installed
	stc
	JMP	SHORT get_system_info_exit

board_id_ok:
	mov	io_addr,bp

	LEA	DX, [BP].@ID_Port	; Set DX to the auto-id port.
	or	DX,3000h		;use the shadow port
	CALL	check_for_exp16_hardware
	mov	board_id,ax

;
; Since the software will be reading the EEPROM during the
; initialization, the 586 needs to be inactive.  This is because the
; control lines to the EEPROM are shared between the 586 and this
; software.  To keep from getting fouled up, the 586 reset line is
; asserted here (now that we have a base IO address, and we know that
; the hardware is present).  The 586 is not released from reset until
; after its data structures are intialized.
;
	CALL	reset_586
;
; Validate the EEPROM by doing a checksum.
;
	mov	cx, 40h
	CALL	check_eeprom
	JC	get_system_info_exit
;
; Get the amount of memory on the adapter.
;
	CALL	test_buffer_memory
	JC	get_system_info_exit

;
; Get the connection type.  If carry clear, then AL has connection
; type.  Otherwise AX has error code.
;
	CALL	get_connection_type
	JC	get_system_info_exit
	MOV	connection_type, AL
;
; Read the Ethernet address out of the EEPROM.
;
	MOV	AX, EE_ETHERNET_ADD_HIGH
	CALL	read_eeprom
	xchg	ah,al
	MOV	word ptr rom_address[0], AX

	MOV	AX, EE_ETHERNET_ADD_MID
	CALL	read_eeprom
	xchg	ah,al
	MOV	word ptr rom_address[2], AX

	MOV	AX, EE_ETHERNET_ADD_LOW
	CALL	read_eeprom
	xchg	ah,al
	MOV	word ptr rom_address[4], AX

	mov	ax,EE_INT
	call	read_eeprom
	mov	cl,EE_SHIFT
	shr	ax,cl
	mov	encoded_int_no,al
	mov	bx,offset irq_xlat_table
	xlat
	mov	int_no,al

;
; Get the Slot width.  If carry clear, then AL has the slot width.
; Otherwise AX has error code.
;
	LEA	DX, [BP].@Config
	IN	AL, DX
;
; Slot width is found in the adapters configuration register.
;
	and	al, slot_width_mask
	mov	_16_not_8_bit_slot, al

	clc
	ret

get_system_info_exit:
;we only ever get here with cy set.
	RET

;
;
; Return connection type in AL with carry clear.
;
;
get_connection_type:

	cmp	board_id,BART_Board_ID	;a real BART?
	je	get_auto_cnt_exit	;yes, it doesn't *have* an ECR1.

	MOV	AX, AUTO_CON_ADDRESS	;get the auto-connection bit.
	CALL	read_eeprom
	TEST	AX, AUTO_CON_MASK	;set?
	Je	get_auto_cnt_exit	;no, okay.
	mov	bl,CONN_AUTO		;yes, we should autosense the connector.
	jmp	short get_connection_type_ret
get_auto_cnt_exit:

;
; Read the connection address from the EEPROM.
;
	MOV	AX, connection_address
	CALL	read_eeprom		;Read_eeprom does not trash DI

;
; Assume AUI type connection.  Check connection fields to see if this
; is a BNC connection.  Jump if it is BNC.
;
	MOV	BL, CONN_AUI
	TEST	AX, CONNECTION_FIELD
	JZ	get_connection_type_ret

;
; Here if NOT BNC.  Must read another EEPROM word to tell if AUI or
; TPE.  Assume AUI and then check for TPE.
;
	MOV	AX, tpe_address
	CALL	read_eeprom		;Read_eeprom does not trash DI

;
; Check for AUI connection.
;
	mov	bl,CONN_BNC
	TEST	AX, TPE_type_field
	JZ	get_connection_type_ret

;
; Here if TPE type connection.
;
	MOV	BL, CONN_TPE

get_connection_type_ret:

	MOV	AL, BL

	CLC
	RET


;
;
; Do a checksum on the EEPROM.
;
; The checksum is the same as the board ID.
;
check_eeprom:
;enter with bp=io_addr, cx = count of bytes to sum starting at 0.
;exit with nc if okay, cy, dx -> error message if not.

	xor	bx, bx

checksum_loop:

	mov	ax, cx
	dec	ax
	call	read_eeprom

	add	bx, ax
	loop	checksum_loop

	cmp	bx, BART_Board_ID
	jne	checksum_error

	clc
	ret

checksum_error:
	mov	dx,offset eeprom_checksum_error
	stc
	ret


test_buffer_memory:
;enter with bp=io_addr
;exit with nc and al=_64k_not_32k if no error, or cy and di -> address in error.

; Set up SI with the maximum number of words to test.  If there is an
; error testing the high 32K of memory, then we will restart the
; test at 32K.  When the tests pass, the memory size is passed back
; in AX.
;
	mov	si, 64 * (1024/2)
;
; Warm up the buffer memory with 16 word writes.
;
	mov	cx, 16
	call	write_zeros

	cmp	cs:is_186,0
	jne	start_memory_tests

restart_memory_tests:
;
; Here if error testing memory and SI is set to 64K buffer size.
; We restart the tests for 32K buffer only.  If an error occurs
; with SI set to 32K, then a memory error is reported.
;
	mov	si, 32 * (1024/2)

start_memory_tests:
;
; Zero RAM.  Set write pointer to the base address and then fill the
; bufffer memory with zeros.
;
	mov	cx, si
	call	write_zeros

	call	word_memory_test_pattern
	jc	buffer_mem_error_exit

	cmp	cs:is_186,0
	je	_8088_quick_exit

	mov	cx, si
	call	write_zeros

	call	byte_memory_test_pattern
	jc	buffer_mem_error_exit

_8088_quick_exit:
;
; Zero RAM.  Set write pointer to the base address and then fill the
; bufffer memory with zeros.
;
	mov	cx, si
	call	write_zeros

;
; Set _64K_not_32K to the size of the memory that passed diagnostics.
;
	cmp	si, 32 * (1024/2)	;did we quit at 32K
	je	buffer_mem_exit		;yes, we only have 32K.

	mov	_64K_not_32K,1		;no, we must have 64K.

buffer_mem_exit:
	clc
	ret

buffer_mem_error_exit:
;
; If error occured, and SI is not set for 32K, then retry tests with
; SI set for 32K.  If the error occurs and the size is 32K, then the
; Exp16 board memory is bad.
;
	CMP	SI, 32 * (1024/2)
	JNE	restart_memory_tests

	MOV	DX, OFFSET buffer_memory_error
	STC	;Set carry to indicate error.
	RET


write_zeros:
;enter with bp=io_addr, cx=number of zero words to write.
;
; Move write pointer to the beginning of the buffer memory.
;
	LEA	DX, [BP].@Write_Ptr
	XOR	AX, AX
	OUT	DX, AX
;
; Set DX to the data register and write out zeros CX times.
;
	mov	dx, bp			;@Data_Reg
warm_up:
	out	dx, ax
	loop	warm_up
	ret


word_memory_test_pattern:
;enter with si = number of words to test.

;
; Set CX to number of words to test.  Set BX to beginning og pattern.
;
	MOV	CX, SI
	MOV	BX, 1

;
; Set DI to beginning of the buffer.
;
	XOR	DI, DI

word_inc_pattern:

	CALL	loop_set_up
	IN	AX, DX
	OR	AX, AX
	JNE	word_memory_test_pattern_error

;
; Write Test Pattern.
;
	MOV	AX, BX
	OUT	DX, AX

;
; Increment BX to next test pattern value.
;
	ADD	BX, 3

;
; Increment DI to next test memory location.
;
	ADD	DI, 2
	LOOP	word_inc_pattern

;
; Set Read pointer to beginning of buffer.
;
	LEA	DX, [BP].@read_ptr
	XOR	AX, AX
	OUT	DX, AX
	MOV	DX, BP			;@Data_Reg

;
; Set CX to number of words to test.  Set BX to beginning og pattern.
;
	MOV	CX, SI
	MOV	BX, 1

word_check_pattern:

	IN	AX, DX
	CMP	AX, BX
	JNE	word_memory_test_pattern_error

;
; Increment BX to next test pattern value.
;
	ADD	BX, 3

	LOOP	word_check_pattern

	CLC
	RET

word_memory_test_pattern_error:

	STC
	RET


byte_memory_test_pattern:
;enter with si = number of bytes to test.

;
; Set CX to number of bytes to test.  Set BX to beginning of pattern.
;
	MOV	CX, SI
	SHL	CX, 1
	MOV	BL, 1

;
; Set DI to beginning of the buffer.
;
	XOR	DI, DI

byte_inc_pattern:

	CALL	loop_set_up
	IN	AL, DX
	OR	AL, AL
	JNE	byte_memory_test_pattern_error

;
; Write Test Pattern.
;
	MOV	AL, BL
	OUT	DX, AL

;
; Increment BX to next test pattern value.
;
	ADD	BL, 3

;
; Increment DI to next test memory location.
;
	INC	DI

	LOOP	byte_inc_pattern

;
; Set Read pointer to beginning of buffer.
;
	LEA	DX, [BP].@read_ptr
	XOR	AX, AX
	OUT	DX, AX
	MOV	DX, BP			;@Data_Reg

;
; Set CX to number of bytes to test.  Set BX to beginning of pattern.
;
	MOV	CX, SI
	SHL	CX, 1
	MOV	BL, 1

byte_check_pattern:

	IN	AL, DX
	CMP	AL, BL
	JNE	byte_memory_test_pattern_error

;
; Increment BX to next test pattern value.
;
	add	bl, 3

	loop	byte_check_pattern

	clc
	ret

byte_memory_test_pattern_error:

	stc
	ret

loop_set_up:
;enter with bp=io_addr, di=buffer address.
;exit with ax=value at di, dx=I/O address to access buffer memory at DI

	PUSH	DI

	MOV	AX, DI			;SMB_Ptr must be on 16 byte
	AND	AX, 0FFE0H
	AND	DI, 0001FH

	LEA	DX, [BP].@SMB_Ptr		;Set IO page frame to the
	OUT	DX, AX


	TEST	DI, 0010H
	JZ	loop_set_up_1

	ADD	DI, @MEM_LOC_0

loop_set_up_1:
	AND	DI, 0FFEFH
	LEA	DX, [BP+DI].@MEM_LOC_0		;Set DX for IO from buffer and

	POP	DI

	RET


read_eeprom:
;enter with bp=io_addr, ax = EEPROM location.
;exit with ax = EEPROM contents.
;preserves di.
	push	di
	push	bx
	push	cx

;  Point to EEPROM control port.

	lea	dx, [bp].@eeprom_ctrl
	mov	bx, ax

; Select the EEPROM.  Mask off the ASIC and 586 reset bits and set
; the ee_cs bit in the EEPROM control register.

	in	al, dx
	and	al, 10110010b
	or	al, ee_cs
	out	dx, al

; Write out read opcode and EEPROM location.

	mov	ax, eeprom_read_opcode		;Set AX to READ opcode and
	mov	cx, 3				;Send it to the EEPROM circuit
	call	shift_bits_out

	mov	ax, bx				;Tell EEPROM which register is
	mov	cx, 6				; to be read.  6 bit address.
	call	shift_bits_out

	call	shift_bits_in			;AX gets EEPROM register

	call	eeprom_clean_up			;Leave EEPROM in known state.

	pop	cx
	pop	bx
	pop	di
	ret


;-----------------------------------------------------------------------------
;  Writes the specified value to the specified EEPROM register at the 
;  specified base I/O address.
;
;  Entry  - BP  Base IO.
;           AX  EEPROM location to write.
;	    BX  Value to write
;
;  Return - AX = 0 if no error
;	    AX = Pointer to Error message
;
;-----------------------------------------------------------------------------
write_eeprom:
;enter with bp=io_addr, ax = EEPROM location, bx = new contents.
;exit with ax = 0 if no error, ax -> error if error.
;preserves di.

	push	bx
	mov	bx, ax

	lea	dx, [bp].@EEPROM_Ctrl	;Point to EEPROM port.

	in	al, dx	  			;Select EEPROM
	and	al, 10110000b
	or	al, ee_cs
	out	dx, al

; Send Erase/write enable opcode to the EEPROM.
	mov	ax, EEPROM_EWEN_opcode	;Send erase/write enable
	mov	cx, 5			; command to the EEPROM.
	call	shift_bits_out

	mov	cx, 4			;Send 4 don't cares as
	call	shift_bits_out		; required by the eeprom

	call	stand_by

; Send the erase opcode to the EEPROM and wait for the command to 
; complete.
	mov	ax, EEPROM_erase_opcode	;Send Erase command to the
	mov	cx, 3			; EEPROM.
	call	shift_bits_out

	mov	ax, bx			;Send EEPROM location the the
	mov	cx, 6			; EEPROM.  6 bit address.
	call	shift_bits_out

	call	wait_eeprom_cmd_done	;wait for end-of-operation
	jc	write_fault_pop		; go if error

	call	stand_by

; Send the write opcode, location to write, and data to write to the
; EEPROM.  Wait for the write to complete.
	mov	ax, EEPROM_write_opcode	;Send write command to the 
	mov	cx, 3			; EEPROM.
	call	shift_bits_out

	mov	ax, bx			;Send the EEPROM location to
	mov	cx, 6			; the EEPROM.  5 bit address.
	call	shift_bits_out

	pop	ax			;Send data to write to the 
	mov	cx, 16			; EEPROM.  16 bits.
	call	shift_bits_out

	call	wait_eeprom_cmd_done	;Await end-of-command
	jc	write_fault		;go if error

	call	stand_by

; Send the erase write disable command to the EEPROM.
	mov	ax, EEPROM_EWDS_opcode		;Disable the Erase/write
	mov	cx, 5				; command previously sent to
	call	shift_bits_out			; EEPROM.

	mov	cx, 4	      			;Send 4 don't cares as
	call	shift_bits_out			; required by the eeprom

	call	eeprom_clean_up

	clc
	ret

write_fault_pop:
	add	sp, 2				;Get rid of data on stack
write_fault:
;;;	lea	ax, eeprom_write_error
	stc
	ret


shift_bits_out:
;enter with ax=data to be shifted, cx=# of bits to be shifted.

	push	bx

; Data bits are right justified in the AX register.  Move the data
; into BX and left justify it.  This will cause addresses to to
; be sent to the EEPROM high order bit first.

	mov	bx, ax
	mov	ch, 16
	sub	ch, cl
	xchg	cl, ch
	shl	bx, cl
	xchg	cl, ch
	xor	ch, ch

; Get the EEPROM control register into AL.  Mask of the ASIC asn 586
; reset bits.

	in	al, dx
	and	al, 10111111b

; Set or clear DI bit in EEPROM control register based on value of
; data in BX.

out_shift_loop:
	and	al, not ee_di			;Assume data bit will be zero

	rcl	bx, 1				;Is the data bit a one?
	jnc	out_with_it			;No
	or	al, ee_di			;Yes
out_with_it:
	out	dx, al				;Output a 0 or 1 on data pin

; Set up time for data is .4 Microseconds.  So to be safe (incase of
; this software is run on a cray), call delay.
	mov	di, 1
	call	eeprom_delay

	call	raise_eeprom_clock	; Clock the data into the EEPROM.
	call	lower_eeprom_clock
	loop	out_shift_loop		;Send next bit

	and	al, not ee_di		;Force data bit to zero
	out	dx, al			;Output a 0 on data pin

	pop	bx

	ret

shift_bits_in:
;exit with ax = register contents.
	push	bx
	push	cx

; BX will receive the 16 bits read from the EEPROM.  Data is valid in
; data out bit (DO) when clock is high.  There for, this procedure
; raises clock and waits a minimum amount of time.  DO is read, and
; clock is lowered.

	in	al, dx				;Init AL to eeprom control
	and	al, 10111111b			; register.

	xor	bx, bx				;Init holding register
	mov	cx, 16				;We'll shift in 16 bits

in_shift_loop:
	shl	bx, 1			;Adjust holding register for
					; next bit
	call	raise_eeprom_clock

	in	al, dx
	and	al, 10111111b

	test	al, ee_do		;Was the data bit a one?
	jz	in_eeprom_delay		;No

	or	bx, 1			;Yes, reflect data bit state
					; in holding register.

in_eeprom_delay:
	call	lower_eeprom_clock
	loop	in_shift_loop		;CONTINUE

	mov	ax, bx			;AX = data

	pop	cx
	pop	bx
	ret

raise_eeprom_clock:
	or	al, ee_sk		;Clock the bit out by raising
	jmp	short eeprom_clock_common
lower_eeprom_clock:
	and	al, not ee_sk			;Lower ee_sk
eeprom_clock_common:
	out	dx, al
	mov	di, ee_tick
	call	eeprom_delay			;Waste time
	ret


wait_eeprom_cmd_done:
;Wait for ee_do to go high, indicating end-of-write or end-of-erase
;operation.  Wait at most 20 ms (EEPROM needs at most 10).
;exit with nc if no error.

	push	bx
	push	cx

	call	stand_by

	call	readtickcounter
	mov	di, ax

ee_do_wait_loop:

	call	readtickcounter
	neg	ax
	add	ax, di

	cmp	ax, 28640		;12 Millisecond wait
	jb	ee_do_wait_loop

	in	al, dx			;Get EEPROM control register

	test	al, EE_DO		;ee_do high?
	jnz	ee_do_found

	stc
	jmp	short wait_eeprom_cmd_done_exit

ee_do_found:

	clc				;"clean" status (no timeout)

wait_eeprom_cmd_done_exit:

	pop	cx
	pop	bx
	ret


stand_by:
; lower chip select for 1 microsecond.
	in	al, dx	  			;de-select EEPROM
	and	al, (10111110b) and (not ee_cs)
	out	dx, al

	mov	di, 2
	call	eeprom_delay

	or	al, ee_cs
	out	dx, al

	ret

; Lower EEPROM chip select and DI.
; Clock EEPROM twice and leave clock low.

eeprom_clean_up:

	push	ax

	in	al, dx
	and	al, 10111111b
	and	al, not (ee_cs or ee_di)
	out	dx, al

	call	raise_eeprom_clock
	call	lower_eeprom_clock

	pop	ax
	ret

; DI has number of 838 Nanoseconds clock counts
eeprom_delay:

	push	ax
	push	bx
	push	dx

	call	readtickcounter
	mov	bx, ax

eeprom_delay_loop:

	call	readtickcounter
	neg	ax
	add	ax, bx
	cmp	ax, di
	jb	eeprom_delay_loop

	pop	dx
	pop	bx
	pop	ax
	ret

iochrdy_test:
; First test to see if the driver is supposed to run this test.
	MOV	AX, lock_bit_address
	CALL	read_eeprom

	TEST	AX, lock_bit_mask
	JNZ	iochrdy_test_exit
; Get the configuration register.

	LEA	DX, [BP].@config
	IN	AL, DX

; Set the iochrdy test bit with and set iochrdy to late.
	OR	AL, iochrdy_test_mask+iochrdy_late
	CLI
	OUT	DX, AL

; Test IOCHRDY with IO.
	LEA	DX, [BP].@mem_loc_0
	IN	AX, DX

; Read in the results of the test.  Save results in BL.
	LEA	DX, [BP].@config
	IN	AL, DX
	MOV	BL, AL

; Turn iochrdy test off.
	AND	AL, NOT iochrdy_test_mask
	OUT	DX, AL
	STI

; Test results.  Exit if IOCHRDY_LATE bit is set correctly.
	TEST	BL, iochrdy_test_result
	JZ	iochrdy_test_exit

; Here if test failed.  Clear the 16 bit override bit (force 8 bit
; transfers) and print a warning message.
	AND	AL, NOT _16_bit_override_bit
	OUT	DX, AL

	mov	dx, offset iochrdy_problem
	mov	ah,9
	int	21h


iochrdy_test_exit:

	RET



iochrdy_problem	db	"IOCHRDY Problem.  EtherExpress forced into 8 Bit Mode.",CR,LF,'$'
buffer_memory_error	db	"Memory error on the EtherExpress board",CR,LF,'$'

reset_error	db	"ASIC reset failure on EtherExpress board",CR,LF,'$'

_586_diagnostic_failure	db	"82586 diagnostic failure on the "
	db	"EtherExpress board",CR,LF,'$'

_586_not_responding_msg	db	"82586 did not respond to command "
	db	"on the EtherExpress board",CR,LF,'$'

command_unit_not_idle	db	"82586 command unit is not "
	db	"responding on the EtherExpress board",CR,LF,'$'

invalid_int_number	db	"EtherExpress board IRQ/Interrupt number "
	db	"not specified correctly",CR,LF,'$'

eeprom_checksum_error	db	"EEPROM failed checksum",CR,LF,'$'

Board_Not_Installed	db	"EtherExpress Board not found",CR,LF,'$'

irq_config_error	db	"IRQ selection is for 16 bit slot only.",CR,LF,'$'

bad_config_msg	db	"Could not configure the 82586",CR,LF,'$'

bad_init_msg	db	"Could not initialize the 82586",CR,LF,'$'

code	ends

	end
