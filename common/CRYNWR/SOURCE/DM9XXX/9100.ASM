;*****************************************************************************
;* Name : 9100.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description : Initializes card & setup receive mode.
;*	Include file :
;*		timeout.asm
;*		xmt.asm
;*		rcv.asm
;*		srom.asm
;*		port.asm
;*		rtdata.asm
;*		isr.asm
;*		timer_isr.asm
;*		etopen.asm
;*
;* Functions :
;*	. etopen		;; Initializes card
;*	. rcv_mode_1		;; Setup receive mode
;*	. rcv_mode_2
;*	. rcv_mode_3
;*	. rcv_mode_4
;*	. rcv_mode_5
;*	. rcv_mode_6
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96
;*
;
; Maintainers:
;
; John H.T. Ho		htho
;
;
; Revision History:
;
; Date	     Modfier.	Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.1.31	htho	support 1M HomePNA
;
; 2000.3.27	htho	AUTOSENSE_ALARM = 18 -> 6
;
; 2000.4.6	htho	port rese while rx hang
;
; 2000.6.27	htho	support resend remote command for home pna
;
;*
;*****************************************************************************


  ife SM_RSTART_PG
	%err	SM_RSTART_PG cannot be zero because of a decrement/unsigned jump.
  endif


longpause macro
	local lp_not_mc
	push cx
	push ax
	mov  cx,1600	; 1.6ms = 1600*1.0us
	test sys_features,SYS_MCA
	je   lp_not_mc
	shl  cx,1	; twice as many loops for Microchannel
lp_not_mc:
	in al,61h
	loop lp_not_mc
	pop  ax
	pop  cx
endm

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

;-> current address
	extrn	my_address: byte

	public	mcast_list_bits, mcast_all_flag
mcast_list_bits db	0,0,0,0,0,0,0,0 ;Bit mask from last set_multicast_list
mcast_all_flag	db	0		;Non-zero if hware should have all
					; ones in mask rather than this list.

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0		;There is no mode zero
		dw	rcv_mode_1
		dw	rcv_mode_2
		dw	rcv_mode_3
		dw	rcv_mode_4
		dw	rcv_mode_5
		dw	rcv_mode_6

;
;	a temp buffer for the received header
;
RCV_HDR_SIZE	equ	26		; 2 ids @6 + protocol @2+8, + header @4
rcv_hdr 	db	RCV_HDR_SIZE dup(0)

;
;	The board data
;
		public	board_data
BOARD_DATA_SIZE equ	32
board_data	db	BOARD_DATA_SIZE dup(0)


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

; Routines to set address filtering modes in the DM9100
	PUBLIC rcv_mode_1
rcv_mode_1:	; Turn off receiver
	push	dx
	push	eax
	mov	dx, p_CR6
	in	eax, dx
	or	eax, CR6_M_RXSC 	 ;; Stop receive
	out	dx, eax
	pop	eax
	pop	dx
	ret

	PUBLIC	rcv_mode_2
rcv_mode_2:	; Receive only packets to this interface
	call	XmtSendDummyFrame
	call XmtGetSetupBuffer		;; Return AX near point to buffer

	mov  di, ax			; ES:DI points to start of setup buffer
	mov	cx, 16
only_loop:
	mov	si, OFFSET my_address

	xor  eax, eax
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	loop	only_loop

	call	XmtSendSetupFrame
	ret

	PUBLIC rcv_mode_3
rcv_mode_3:	; Mode 2 plus broadcast packets (This is the default)
	call	XmtSendDummyFrame
	call XmtGetSetupBuffer		;; Return AX near point to buffer

	mov	bx, ax			;; Store setup buffer pointer
	call	Fill_FF_Multicast	;; Fill all FF to buffer

	call	Fill_myaddress_multicast	;; Add address to the first of buffer

	call	XmtSendSetupFrame

	mov	dx, p_CR6
	in	eax, dx
	and	eax, not CR6_M_PM
	and	eax, not CR6_M_PAM
	out	dx, eax

	ret

rcv_mode_4:	; Mode 3 plus selected multicast packets
	call	XmtSendDummyFrame
	call XmtGetSetupBuffer		;; Return AX near point to buffer

	mov	bx, ax			;; Store setup buffer pointer
	call	Fill_FF_Multicast	;; Fill all FF to buffer
	call	Fill_myaddress_multicast	;; Add address to the first of buffer
						;; Return ES:DI-> 1st multicast
	call	Fill_multicasttable
	call	XmtSendSetupFrame
	ret

rcv_mode_5:	; Mode 3 plus ALL multicast packets
	call	XmtSendDummyFrame
	call XmtGetSetupBuffer		;; Return AX near point to buffer

	mov	bx, ax			;; Store setup buffer pointer
	call	Fill_FF_Multicast	;; Fill all FF to buffer

	call	Fill_myaddress_multicast	;; Add address to the first of buffer

	call	XmtSendSetupFrame

	mov	dx, p_CR6
	in	eax, dx
	and	eax, not CR6_M_PM
	or	eax, CR6_M_PAM
	out	dx, eax

	ret

rcv_mode_6:	; Receive all packets (Promiscuous physical plus all multi)
	mov	dx, p_CR6	       ;; Set pass all multicast & promiscuous
	in	eax, dx 		;; command
	or	eax, CR6_M_PM
	out	dx, eax

	ret


Fill_FF_Multicast:	;; Enter with AX = setup buffer.
	push	es

	mov  di, ax			; ES:DI points to setup buffer
	mov	ax, ds
	mov	es, ax
	mov  cx, HW_K_SETUP_FRAME_SIZE	;; (192)
	shr  cx, 2
	mov  eax, 0FFFFFFFFh
	rep  stosd			; Setup buffer with local address

	pop	es
	ret

Fill_myaddress_multicast:	;;Enter with bx = setup buffer
	push	es

	mov	ax, ds
	mov	es, ax
	mov	si, OFFSET my_address

	mov  di, bx			; ES:DI points to start of setup buffer
	xor  eax, eax
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer

	pop	es
	ret

Fill_multicasttable:	;; Enter with ES:DI -> current pointer of setup buffer
; Now, determine the number of entries in the MulticastTable, and add
; those entries to the setup frame.
	push	es

	mov	ax, ds
	mov	es, ax

	mov  cx, MulticastTable.table_current
	mov  si, OFFSET MulticastTable.table_multiaddr
	mov	dx, MulticastTable.table_maxnum

purf_loop:
	cmp  cx, 0
	je   purf_done

	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer

; 16 bytes storage for each address
	add  si, 10			; DS:SI points to next entry in
					; MulticastTable
	dec  cx
	dec	dx
	jmp  purf_loop

purf_done:
	cmp	dx, 0			;; Fill all multicast space ?
	je	purf_exit		;; Yes
	mov	cx, dx
	sub	si, 6			;; point to previouse entry

pad_loop:
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer
	lodsw				; Load word into AX
	stosd				; Store dword EAX in setup buffer

	sub	si, 6			;; Return to previouse entry
	loop	pad_loop

purf_exit:
	pop	es
	ret

	public	terminate
terminate:
	terminate_board
	ret

; Linkages to non-device-specific routines
;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
;It returns with es:di = 0 if don't want this type or if no buffer available.
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

;--------------------------------------------------------------------+
; Name : timer_isr
;
; Description:
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
;;;;++, 2000.4.6, htho
	PUBLIC	interval_rx_cnt
interval_rx_cnt DW	?
;;;;++
TxHangCounter	DW	?
RxHangCounter	DW	?
TxNumOfHangs	DW	?
RxNumOfHangs	DW	?

TX_HANG_VALUE	EQU	18
RX_HANG_VALUE	EQU	18

;;TX_HANG_VALUE   EQU	  18
;;RX_HANG_VALUE   EQU	  18

Xmt_block_reset 	DB	'DM9100 Debug: Reset adapter because transmit block'
			DB	CR, LF
Xmt_block_reset_len	EQU	$ - Xmt_block_reset
;;++, 980310, Hu-Tiong, for Dynamic Auto Sense
;;-+, 2000.3.27, htho
;AUTOSENSE_ALARM	 EQU	 18	 ; Auto Sense timer should activated every second
AUTOSENSE_ALARM 	EQU	6	; Auto Sense timer should activated every 1/3 second
;;-+
AutoCount		db	0
TimerSemaphore		db	0
;;++
;;++, 980925, Hu-Tiong
LINK_PASS		EQU	0
LINK_FAIL		EQU	1
PreviousLinkStatus	dw	LINK_PASS
AUTO_STATE_IDLE 	EQU	0
AUTO_STATE_START	EQU	1
AutoState		dw	AUTO_STATE_IDLE

stack_buf		dw	1024 dup(?)
stack_top		label	word
their_stack		dd	?

	include phy.inc
;;++

EXTRN	their_timer : DWORD

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
;;-+, 980310, Hu-Tiong
;;	pushf		  ; Save flags
;;	cli		  ; Block interrupts
	cli
;;;;++, 2000.6.27, htho, support resend remote command for home pna
ifdef HOMEPNA
;	extrn	resend_remote_cmd_cnt: byte
;	extrn	resend_remote_cmd_timer: word
	cmp	cs:send_remote_cmd, 1
	jne	@F
	cmp	cs:resend_remote_cmd_cnt, 0
	je	@F
	inc	cs:resend_remote_cmd_timer
@@:
endif
;;;;++
	pushf
	call	cs:[their_timer]

	cli
	cmp	cs:TimerSemaphore, 0
	je	timer_isr_main

	iret
timer_isr_main:
	inc	cs:TimerSemaphore
;;-+
	push	ds			; Save current data segment
	push	ax

	push	cs
	pop	ds			; DS = CS

	mov	word ptr their_stack, sp
	mov	word ptr their_stack+2, ss

	mov	ax, cs
	mov	ss, ax
	mov	sp, offset stack_top
	sti

	push	es
	pushad

;;;;++, 2000.6.27, htho, support resend remote command for home pna
ifdef HOMEPNA
	cmp	resend_remote_cmd_cnt, 0
	jle	@F
	cmp	resend_remote_cmd_timer, 8 * 18
	jb	@F

	pushf
	cli
	sub	resend_remote_cmd_timer, 8 * 18
	dec	resend_remote_cmd_cnt
	popf

	call	Write_PNA_CR16
@@:
endif
;;;;++

	cmp	AutoCount, AUTOSENSE_ALARM ; is auto sense timer time-out
	jae	execute_autosense

	inc	AutoCount		; incement auto sense timer
	jmp	CheckTxHangCounter

execute_autosense:
	call	DynamicAutoDetect

	mov	AutoCount, 0

CheckTxHangCounter:
;;++

	cmp  TxHangCounter, 0	; If counter=0 nothing to be done
	je   RxHangCheck

	inc  TxHangCounter	; Increment TxHangCounter

	mov  dx, p_CR5	       ; If CR5 TXDU bit set - Zero TxHangCounter
	in   eax, dx
	test eax, CR5_M_TXDU	 ;; TU -- Transmit buffer Unavailable
	jz   Check_Hang 	; Jump if clear
;;- Clear Transmit buffer Unavailable bit
	mov  eax, CR5_M_TXDU	 ; If set: (1) Clear TU bit.
	out  dx, eax
	mov  TxHangCounter, 0	; (2) Set TxHangCounter to 0.
	jmp  RxHangCheck

Check_Hang:
	cmp  TxHangCounter, TX_HANG_VALUE  ; See if Tx machine hangs (19)
	jbe  RxHangCheck		   ; If not - Exit

	mov  TxHangCounter, 0
	inc  TxNumOfHangs		   ;	    (2) Inc hangs counter

	call PortUpdateReceiveFilter

RxHangCheck:
;;;;++, 2000.4.6, htho
	pushf
	cli
	cmp	interval_rx_cnt, 0
	jne	CheckRxHangCounter
	mov	dx, p_CR8
	in	eax, dx
	cmp	eax, 0
	je	CheckRxHangCounter

	sti
	call	PortUpdateReceiveFilter
	cli

CheckRxHangCounter:
	mov	interval_rx_cnt, 0
	popf
;;;;++

	cmp  RxHangCounter, 0	; If counter=0 nothing to be done
	je   Timer_Exit

	inc  RxHangCounter	; Increment RxHangCounter

	cmp  RxHangCounter, RX_HANG_VALUE  ; See if counter too large
	jbe  Timer_Exit 		   ; If not - Exit

	mov  RxHangCounter, 0		  ; 1) Zero RxHangCounter

	mov  si, RcvCurrentDescriptor	   ; 2) If Curr receive descriptor
	mov  eax, [si].RCV_DESCRIPTOR.RDES0;	host owned - reset Chip.
	test eax, RDES0_M_OWN
	jnz  Timer_Exit
	;; OWN = Host
	inc  RxNumOfHangs		   ; Inc RxHangs counter

	call PortUpdateReceiveFilter	   ; Reset Chip.

Timer_Exit:
	popad
	pop	es

	cli
	mov	sp, word ptr their_stack
	mov	ss, word ptr their_stack+2

	pop  ax
	pop  ds 	  ; Restore data segment
;;-+, 980310, Hu-Tiong
;;	popf		  ; Restore flags
;;	jmp  CS:[their_timer]
	mov	cs:TimerSemaphore, 0
;;-+

	iret
;;-----------------------
include xmt.asm
include rcv.asm
include srom.asm
include port.asm
include rtdata.asm
include isr.asm
;;++, 2000.1.31, hu-tiong
;IFDEF	 DEBUGDOS
;include debug.asm
;ENDIF	 ;-- DEBUGDOS
;;++
;;-----------------------
;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem

;;-+
;;	ALIGN 4
	ALIGN 16
;;-+
end_resident	label	byte
end_free_mem	label	byte

Filler DB 32768 DUP (?)     ; This over allocates the data segment for driver
			    ; init. The InitAllocatePhysicalBlock
			    ; routine grabs what ever it needs, and returns
			    ; the rest to the OS on return from driver init.
			    ; If the space isn't LINKED into the driver, then
			    ; it isn't ours to split up, and give back to the
			    ; OS.

;standard EN0_DCFG contents:
endcfg	db	048h			; Set burst mode, 8 deep FIFO
include etopen.asm

