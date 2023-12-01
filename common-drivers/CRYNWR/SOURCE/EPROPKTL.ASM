;History:1045,1

	include	defs.asm
	include	options.inc
	include	82595.inc
	include	pnp.inc

cgroup	group code, _text, init

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup

	even

extrn	sys_features : byte
extrn	is_186	: byte		;=0 if 808[68], =1 if 80[123]86.
extrn	decout	: near
extrn	rx_buff_ptr	: word
extrn	buff_ptrs : word
extrn	tx_buff_no : word
extrn	lan_595_int : byte
extrn	int_no 			: byte
extrn	int_num : word
extrn	mem_map_io	: word
extrn	pnp_card_no	: byte
extrn	base_addr : word
extrn	send_pkt : near
extrn	set_ether : near
extrn	reset_chip : near
extrn	wait_27ms : near
NOWARN
extrn	wait : near
WARN
extrn	do_timeout : near
extrn	set_timeout : near
extrn	repins : word
extrn	repouts : word
extrn	outw_routine : word
extrn	inw_routine : word

extrn	inw_16	: near
extrn	rep_ins_16	: near
extrn	rep_ins_2_8	: near
extrn	quick_rep_ins_2_8	: near
extrn	quick_rep_ins_16	: near
extrn	outw_16	: near
extrn	rep_outs_16	: near
extrn	rep_outs_2_8 : near
extrn	quick_rep_outs_2_8 : near
extrn	quick_rep_outs_16	: near
extrn	mem_rep_ins	: near
extrn	mem_rep_outs : near

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

	extrn	get_hex: near
	include	getea.asm
	include	messages.inc
	
io_addr		dw	0,0		; I/O address specified on the command line
irq_map		dw	?	; Read from the eeprom - holds mapping of the 5 82595 IRQs
irq_sel		db	?	; Read from the eeprom - holds default IRQ selection
no_prom		db	0	; <> 0 if ethernet address specified on the command line

serial_id		dw	EISA_ID_SIG, PART_NO_SIG
end_serial_id:
pnp_isa_struct	db	PNP_ISA_STRUCT_LEN	dup (?)
pnp_data_seg	dw	0
pnp_buffer		db	50h	dup (?)
pnp_code		dd	0		; Address of the plag and play code
pnp_sign		db	"$PnP"	; Plug and Play BIOS signature
pnp_key			db	06Ah, 0B5h, 0DAh, 0EDh, 0F6h, 0FBh, 07Dh, 0BEh
				db	0DFh, 06Fh, 037h, 01Bh, 00Dh, 086h, 0C3h, 061h
				db	0B0h, 058h, 02Ch, 016h, 08Bh, 045h, 0A2h, 0D1h
				db	0E8h, 074h, 03Ah, 09Dh, 0CEh, 0E7h, 073h
last_pnp_k_byte	db	039h
end_pnp_key:
multiple_cards	db	0			; Set if more than one 'matching' card is found
temp_storage	dw	0, 0
select_reg		db	0


id_strings	DB 'NETIDBLK'	; NET ID Block Signature
			DB 'INTEL   '	; 8 Bytes Vendor (space padded)
			DB '82595   '	; 8 Bytes Product (space padded)

eeprom_buff	dw	CHKSUM_LEN DUP (0)
nidblk_seg	dw	0,0

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

; Enter with si -> argument string.
; Skip spaces and tabs.  Exit with si -> first non-blank char.
	extrn	skip_blanks: near

	public	parse_args
parse_args:
; Exit with nc if all went well, cy otherwise.
	mov		di, offset cgroup:int_no
	call	get_number
	mov		di, offset cgroup:io_addr
	call	get_number
	mov		di, offset cgroup:mem_map_io
	call	get_number
	call	skip_blanks
	cmp		al, CR			; Does an Ethernet address follow?
	je		parse_args_1	; No.
	inc		no_prom			; We don't have an Ethernet PROM.
; Enter with ds:si -> Ethernet address to parse, es:di -> place to put it.
	movseg	es,ds
	mov		di, offset cgroup:rom_address
	call	get_eaddr
parse_args_1:
	clc
	ret

	public	etopen
etopen:
; Initialize the driver.
; Fill in rom_address with the assigned address of the board.
	assume	ds:code
	call	etopen_82595
	jnc		etopen_ok
	ret

; First check to see what bus we're using.
etopen_ok:
; PCMCIA or ISA busses?
	mov	ax,36
	call	wait
	LOAD_BANK_PORT	BANK2, 1
	in		al, dx					; Get current value
	test	al,10h
	je		etopen_isa
	print	found_pcmcia_msg
	mov		dl, -1
; Need to set dl to the interrupt to use
	jmp		found_it	;go if PCMCIA.

; Next check to see if this interrupt is available for the board
etopen_isa:
	mov		cl, int_no
	cmp		cl, 0		; See if user has specified an interrupt
	jne		user_int_no	; Non zero if user has specifed an interrupt

; Convert the default interrupt select # to an actual interrupt #
	mov		dl, irq_sel	; One less than the number of bits to match
	mov		bl, -1		; Start off with interrupt # = -1
	mov		ax, irq_map
next_sel_bit:
	inc		bl					; Increase the interrupt #
	sar		ax, 1
	jnc		next_sel_bit
	dec		dl					; Decrease the bit count
	jge		next_sel_bit		; Jump if there are more bits to match
	mov		int_no, bl			; Store the actual interrupt #
	jmp		short int_no_ok			; This interrupt must be OK

user_int_no:
	mov		bl, cl				; Make a copy of the interrupt no
	mov		ax, 0001h	
	shl		ax, cl
	test	irq_map, ax			; If bit is set then this IRQ is OK
	jne		int_no_ok			; Yes this interrupt is OK

; This routine goes through the IRQ map and informs the user which interrupts
; are available. The interrupt list is generated one by one and separated by
; commas except the last two interrupts which are separted with an '&'.
	print	int_bad_msg
	mov		bx, irq_map
	mov		cx, 10h				; Maxiumum of 16 bits to process
next_irq_bit:
	shr		bx, 1				; Get the next IRQ bit from the map
	jnc		irq_bit_not_set		; Nothing to print if bit is not set
	mov		ax, 10h
	sub		ax, cx				; Ax = the bit position
	push	bx					; Decout routine corrupts bx and cx
	push	cx
	xor		dx, dx				; Decout routine prints 1 32 bit number with
	call	decout				;   the MSW in dx
	pop		cx
	pop		bx
	cmp		bx, 1				; Are there any more bits left if the IRQ map
	jbe		n_m_t_o_i_b_left	; Jump if only one or if no more bits are set
	print	separator1_msg		; More then 1 bit left, need a ',' to separate
	jmp		short irq_bit_not_set
n_m_t_o_i_b_left:
	jl		no_more_irq_bits	; Jump if IRQ map is empty - no '&' required
	print	separator3_msg		; Spearate output with a '&'
irq_bit_not_set:
	loop	next_irq_bit		; Contine until all bits are processed
no_more_irq_bits:
	call	crlf
	mov 	dx, offset cgroup:dummy_msg	; No other message to print
	stc							; Return with an error status
	ret

int_no_ok:
;here with bl = IRQ number as seen by the board.
	LOAD_BANK_PORT	BANK1, REG1
	in		al, dx		; Get current value (8 bits)
	test	al, WORD_WIDTH		; Is chip configured for word transfers
	jne		width_okay		; yes, cool
	mov		ah, al			; save the original.
	or		al, WORD_WIDTH		; configure for 8.  Try 16.
	out		dx, al
	in		al, dx			; did it stick?
	test	al, WORD_WIDTH
	mov		cx, offset cgroup:eight_in_sixteen_msg
	jne		width_16_okay		; yes, must be configured 8 in 16.
	mov		cx, offset cgroup:sixteen_better_msg
	cmp		bl, 7			; a real 8-bit slot -- is int <= 7?
	jbe		width_16_okay		; yes.
	mov		dx, offset cgroup:irq_too_big_msg
	stc
	ret
width_16_okay:
	mov		al, ah			;restore the original mode.
	out		dx, al
	mov		dx, cx
	print_it
width_okay:

; Need to find which LAN 595 interrupt this is
	xor		dl, dl
	mov		cl, bl			; Get back the copy of the int_no
	xor		ch, ch
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

	print	testing_mem_msg
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
	mov		dx, offset cgroup:memory_bad_msg
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

	call	set_RX_TX_areas
	call	do_select_media
	call	set_recv_isr
	clc
	ret

set_RX_TX_areas	PROC	NEAR
; Sets up all the RX and TX buffers variables as well as setting the buffer
; registers in the 82595 chip.
; Enables the 82595 interrupt and masks all but the RX interrupt.
; Issues a selective rest command and then a receive enable command.
; Allow interrupts to occur - the 82595 interrupt mask will be cleared later
	LOAD_BANK_PORT	BANK1, INT_NO_REG
	mov		al, lan_595_int
	cmp		al, -1		; nothing to set if -1 : PCMCIA bus
	je		part_ram
	out		dx, al

part_ram:
; Partition the 82595 RAM into a RX area and TX area with the RX area first.
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
	
enable_82595_ints	PROC	NEAR
; Enables the 82595 interrupt and masks all but the RX interrupt.
; Allow interrupts to occur - the 82595 interrupt mask will be cleared later
	LOAD_BANK_PORT	BANK1, INT_NO_REG
	mov		al, lan_595_int
	cmp		al, -1		; nothing to set if -1 : PCMCIA bus
	je		no_int_to_set
	out		dx, al

no_int_to_set:
; Issue a RCV_ENABLE command
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, RCV_ENABLE
	out		dx, al 
	ret
enable_82595_ints	ENDP




	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov		di, offset cgroup:int_no
	mov		dx, offset cgroup:int_no_name
	call	print_number
	mov		di, offset cgroup:io_addr
	mov		dx, offset cgroup:io_addr_name
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
	xor		ax, ax			;start at zero again.
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
; debug - next 3 lines are remove as P&P support is switched off
;	call	setup_plug_and_play	; Carry clear if P&P card found
;	jnc		got_base			; Jump if carry clear - got our card
;	call	write_activate_key	; No P&P BIOS ? - activate all Intel P&P cards
	call	find_base			; Go and find the chip
	jc		exit_etopen_82595
got_base:
	call	dump_eeprom			; Copy eeprom contents to RAM
	call	chksum_eeprom		; Validate eeprom contents
	jc		check_netidblk		; Failed - check for netid block
	call	check_bases
	; If a full reset is performed in the reset_chip it is necessary to make
	; certain that the IO base address read from the EEPROM agrees with the
	; io address assigned by the P&P bios.
	jmp		short	configure

check_netidblk:
	call	locate_netidblk		; Fetch Init values from netid block
	jnc		configure

	cmp		no_prom, 0			; Did they specify everything we need?
	je		configure			; No, give up.
	print	assumed_msg			; Yes, tell them we're assuming they're right.
configure:
	call	reset_chip
	call	config_chip			; Configure chip
	clc							; No errors to report at this point
exit_etopen_82595:
	ret
etopen_82595	ENDP

check_bases		PROC	NEAR
	; If a full reset is performed in the reset_chip it is necessary to make
	; certain that the IO base address read from the EEPROM agrees with the
	; IO address assigned by the P&P bios.
	; The code to do this would appear here.
	; As only a selective reset is performed in reset_chip there is no need
	; for this routine.
	ret
check_bases		ENDP

config_chip	PROC	NEAR
; Set the correct transfer routines
	LOAD_BANK_PORT	BANK1, REG1
	in		al, dx				; Get current value (8 bits)
	test	al, WORD_WIDTH		; Is chip configured for word transfers
	je		eight_bit			; No then do 8 bit transfers

								; Setup the 16 bit routines
	mov		dx, offset cgroup:word_msg	; Using word transfers message
	mov		inw_routine, offset cgroup:inw_16
	mov		outw_routine, offset cgroup:outw_16

	cmp		mem_map_io, 0		; Has memory mapped I/O been specified
	jne		memory_io			; Yes - go and set those routines

	cmp		is_186, 0			; Can we use fast routines ?
	je		slow_16_bit			; No - have to do use the slower routines
	mov		repins, offset cgroup:quick_rep_ins_16
	mov		repouts, offset cgroup:quick_rep_outs_16
	jmp		short routines_are_set
slow_16_bit:
	mov		repins, offset cgroup:rep_ins_16
	mov		repouts, offset cgroup:rep_outs_16
	jmp		short routines_are_set

eight_bit:						; Setup the 8 bit routines
	mov		dx, offset cgroup:byte_msg	; Using byte transfers message
	mov		inw_routine, offset cgroup:inw_16
	mov		outw_routine, offset cgroup:outw_16

	cmp		mem_map_io, 0		; Has memory mapped I/O been specified
	jne		memory_io			; Yes - go and set those routines

	cmp		is_186, 0			; Can we use fast routines ?
	je		slow_8_bit			; No - have to do use the slower routines
	mov		repins, offset cgroup:quick_rep_ins_2_8
	mov		repouts, offset cgroup:quick_rep_outs_2_8
	jmp		short routines_are_set
slow_8_bit:
	mov		repins, offset cgroup:rep_ins_2_8
	mov		repouts, offset cgroup:rep_outs_2_8
	jmp		short routines_are_set

memory_io:						; Data port is mapped to a memory location
	mov		repins, offset cgroup:mem_rep_ins
	mov		repouts, offset cgroup:mem_rep_outs

routines_are_set:
	print_it					; Announce which routines we are using
; DX has been corrupted
	LOAD_BANK_PORT	BANK1, REC_LOW_LIMIT_REG

; Partition the RAM to have a 32k receive buffer and a 32 transmitter buffer
; As there is actually only 32k of RAM available the receive buffer has it all
; so that during the memory test there will not be any undesirable automated
; wrap-around of the host address register.
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
	mov		si, offset cgroup:rom_address
	call	set_ether
	LOAD_BANK_PORT	BANK2, RECV_MODES_REG	; Set default receive modes
	mov		al, MATCH_BRDCAST
	out		dx, al
	LOAD_BANK_PORT	BANK0, COMMAND_REG 		; Issue a selective reset command
	mov		al, SEL_RESET
	out		dx, al
	call	wait_27ms
	clc
	ret
config_chip	ENDP

do_select_media	PROC NEAR
; Now find what media is being used
	LOAD_BANK_PORT	BANK2, REG3			; Access port select register
	mov		al, byte ptr [eeprom_buff+1*2] 	; Word 1 holds PORT selection data
	shr		al, 1							; EEPROM configuration needs to be
	shr		al, 1							;   shifted by 3 bits
	shr		al, 1							; Also need BNC_TPE from word 5
	test	byte ptr [eeprom_buff+5*2], EE_CONF_BNC_TPE
	je		bnc_tpe_clear
	or		al,  BNC_TPE
bnc_tpe_clear:
	out		dx, al
	test	al, APORT_DIS
	jne		no_autodetection
	mov		dx, offset cgroup:using_auto_msg	; Auto detecting media
	print_it			
	LOAD_PORT	REG3					; Access port select register
	in		al, dx						; Get current state
no_autodetection:
	mov		cl, al
	xor		ch, ch
	and		cx, BNC_TPE+TPE_AUI			; Ignore all except port selection bits
	cmp		cx, TPE_AUI			 		; Configured for 10-Base-T ?
	jne		not_using_10B_T
	mov		dx, offset cgroup:using_10B_T_msg	; Setup message for twisted pair
	jmp		short announce_media
not_using_10B_T:
	cmp		cx, TPE_AUI+BNC_TPE	 		; Configured for 10-Base-2 ?
	jne		not_using_10B_2
	mov		dx, offset cgroup:using_10B_2_msg	; Setup message for BNC
	jmp		short announce_media
not_using_10B_2:
	cmp		cx, BNC_TPE					; Configured for AUI ?
	jne		using_bnc_aui
	mov		dx, offset cgroup:using_AUI_msg	; Setup message for AUI
	jmp		short announce_media
using_bnc_aui:
	mov		dx, offset cgroup:using_bnc_aui_msg	; Setup message for AUI or BNC
announce_media:
	print_it
	cmp		cx, TPE_AUI					; Is 10-Base-T is being used
	jne 	exit_config_chip
	call	do_fdx_hdx_negotiation
exit_config_chip:
	ret
do_select_media	ENDP

do_fdx_hdx_negotiation	PROC NEAR
	LOAD_BANK_PORT	BANK2, FDX_HDX	; Get auto-negotiation status
	in		al, dx
	test	al, A_N_ENABLE			; Is auto-negotiation require ?
	jne		need_negotiation		; Jump if so
	test	word ptr [eeprom_buff+1*2], EE_CONF_FDX	; Full duplex set in EEPROM
	je		no_negotiation			; Jump if not
	or		al, FDX_ENABLE			; Set full duplex bit
	out		dx, al					; Update register
	jmp		short full_duplex
need_negotiation:
	push	dx
	print 	negotiation_msg			; Announce that negotiation is in progress
	pop		dx
	mov		al, A_N_ENABLE+FDX_ENABLE
	out		dx, al
	mov		ax, 200					; Wait, if necessary, for about 5
	call	set_timeout				;    seconds (150 is too small)
get_link_status:
	in		al, dx					; Get status of the negotiation
	test	ax, NEG_STATUS			; Non-zero when the negotation is done
	jne		negotiation_done		; Jump if so
	call	do_timeout				; Any more time left ?
	jnz		get_link_status			; Continue to wait if so
negotiation_problem:
	print	neg_problem_msg			; Otherwise announce negotiation problem
	jmp		short exit_do_fdx_neg

negotiation_done:
	; Intel specs state that a double read is necssary for this register
	in		al, dx					; Get status of the negotiation
	mov		ah, al					; Save a copy of al
	and		ah, NEG_STATUS			; Clear all but the negotiation status
	cmp		ah, NEG_STATUS_OK		; Check if negotiation completed correctly
	jne		negotiation_problem		; Jump if negotiation problem

no_negotiation:
	test	al, FDX_ENABLE			; Is this a full duplex link ?
	je		half_duplex				; Jump if not
full_duplex:
	print	full_duplex_msg			; Announce full duplex
	jmp		short exit_do_fdx_neg
half_duplex:
	print	half_duplex_msg			; Announce half duplex
exit_do_fdx_neg:
	ret
do_fdx_hdx_negotiation	ENDP


write_activate_key	PROC	NEAR
	; Provides a back-door way to activate an Intel P&P card
	; First need to modify the PNP initiation key to the PNP activate all key
	mov		last_pnp_k_byte, LAST_KEY_BYTE
	call	write_pnp_key
	ret
write_activate_key	ENDP

	public	write_pnp_key
write_pnp_key	PROC	NEAR
	; Code to take all the configured P & P cards from the wait for key state
	; to the sleep state.
	cli							; Protect against other access to the port
	mov		dx, PNP_ADD_PORT	; Port to send out the LFSR key
	xor		al, al
	out		dx, al				; Writing 2 0's will reset the LFSR
	out		dx, al
	mov		si, offset cgroup:pnp_key
	mov		cx, offset cgroup:end_pnp_key - offset cgroup:pnp_key
next_pnp_key_byte:
	lodsb						; Get the next byte in the P & P key
	out		dx, al
	loop next_pnp_key_byte
	sti							; Others can now access the P & P register
	ret
write_pnp_key	ENDP


	public	setup_plug_and_play
setup_plug_and_play	PROC	NEAR
; Search the BIOS for the Plug and Play signiature
	push	es
	mov		dx, 0F000H	; ROM Segment to search for P & P BIOS
	mov		es, dx		; Need in es for the string comparison
	xor		di, di		; Start at offset 0
continue_pnp_search:
	mov		si, offset cgroup:pnp_sign	; Need to initialize for each search
	mov		cx, 2		; No of words to compare
	repe	cmpsw
	je		looks_like_pnp
	and		di, 0FFF0h	; Clear lower 4 bits of di pointer
next_pnp_search:
	add		di, 10H		; Advance search by 16 bytes
	jne		continue_pnp_search
	mov		dx, offset cgroup:no_pnp_bios_msg
	jmp		no_pnp
looks_like_pnp:
	; Check to see if the PNP checksum is zero
	and		di, 0FFF0h			; Clear lower 4 bits of di pointer
	mov		cx, 20h				; Number of bytes in the checksum
	xor		al, al				; Initialize the checksum
check_next_byte:
	add		al, es:[di]			; Form the checksum
	inc		di
	loop	check_next_byte
	sub		di, 20h				; Recover value of di prior to the check
	or		al, al				; Set the flags = result of checksum test
	jne		next_pnp_search		; Contine the search if checksum <> 0
found_pnp:
	print	pnp_bios_msg		; Announce that a PNP BIOS was found
	mov		ax, es:[di+0Dh]
	mov		pnp_code.offs, ax	; Set offset of pointer to PNP code
	mov		ax, es:[di+0Fh]
	mov		pnp_code.segm, ax	; Set segment of pointer to PNP code
	mov		ax, es:[di+1Bh]
	mov		pnp_data_seg, ax	; Set segment of PNP data
; Check to see if any cards have been configured by the PNP BIOS
	push	ax					; PNP data segment
	push	cs					; Segment of PNP ISA structure
	mov		ax,	offset cgroup:pnp_isa_struct
	push	ax					; Segment of PNP ISA structure
	mov		ax, GET_PNP_ISA_STRUCT
	push	ax					; Command to get the PNP ISA structure
	call	pnp_code			; Get the structure
	add		sp, 8				; Recover the stack
	cmp		ax, PNP_FUNCTION_OK	; Check if function returned correctly
	jne		no_pnp_card 		; No PNP card if a non-zero return
	cmp		pnp_isa_struct[PNP_CSN_CNT_OFF], 00	; Check that a card was found
	je		no_pnp_card

; Arrive here if there is a PNP BIOS and at least one card
; debug - this should not be called
;	call	write_pnp_key		; Set all PNP cards to sleep state
	; check all cards to see if they match the expected crystal sig
	mov		ax, cs
	mov		es, ax				; reset es back to this segment

	mov		bl, 01h				; bl holds the card count
check_next_card:
	WRITE_PNP_REG_BL  PNP_WAKE
	mov		di, offset cgroup:pnp_buffer
								; cx = no of bytes to read
	mov		cx, offset cgroup: end_serial_id - offset cgroup:serial_id
	
get_next_rsrc_byte:
wait_pnp_rsrc_ready:
	READ_PNP_REG PNP_STATUS		; Check the status before reading next byte
	test	al, PNP_RSRC_READY
	je		wait_pnp_rsrc_ready	; If bit is zero - not read
	READ_PNP_REG PNP_RSRC_DATA	; Get the next byte
	stosb					
	loop	get_next_rsrc_byte	; Loop until all bytes read

	; Now check to see if this card is the desired card
	mov		di, offset cgroup:pnp_buffer
	mov		si, offset cgroup:serial_id
	mov		cx, (offset cgroup:end_serial_id - offset cgroup:serial_id) /2
	repe	cmpsw
	je		found_a_match
pnp_io_add_failed:
	inc		bl					; Match failed - increase the card count
	cmp		bl, pnp_isa_struct[PNP_CSN_CNT_OFF]	; Compare with # of cards
	jle		check_next_card		; Any more left to check ?
no_pnp_card:
	cmp		base_addr, 0h		; Did we find a card ?
	jne		pnp_card_found		; Jump if so
	mov		dx, offset cgroup:no_pnp_card_msg	; Set message
	jmp		short no_pnp		; The card was not found by the P & P 
pnp_card_found:
	cmp		multiple_cards, 0	; Have multiple cards been found ?
	je		one_pnp_card		; Jump if not
	mov		dx, offset cgroup:specify_which_msg	; Set message
	jmp		short no_pnp		; Two many mathing P & P cards found
one_pnp_card:
	mov		ax, base_addr		; Copy address for the print params routine
	mov		io_addr, ax
	print	pnp_card_msg
	clc
	jmp		short pnp_check_exit

found_a_match:
	; Get all the PNP resources assigned to this card
	READ_PNP_REG PNP_CNF_IO_H
	mov		ah, al				; Store the high part of the address in ah
	READ_PNP_REG PNP_CNF_IO_L	; Low part of the address will be in al
	cmp		io_addr, 00h		; Has the base io address been specified
	je		no_io_add_specified	; Jump if not, otherwise check to see if this
	cmp		ax, io_addr			;   the specified address
	jne		pnp_io_add_failed	; No - continue the search
no_io_add_specified:			; Everything has matched - card is found
	cmp		base_addr, 0h		; Value should initially be zero
	jz		first_pnp_found		; Ok to proceed
	call	found_many			; Deal with multiple cards
	jmp		short pnp_io_add_failed	; Continue the search
first_pnp_found:
	mov		pnp_card_no, bl
	mov		base_addr, ax

	READ_PNP_REG PNP_CNF_INT
	mov		int_no, al
	jmp		pnp_io_add_failed	; Continue the search

no_pnp:
	print_it
	stc
pnp_check_exit:
	pop		es
	ret
setup_plug_and_play	ENDP

found_many	PROC	NEAR
	; Called when multiple cards are found
	push	bx
	push	di
	push	dx
	cmp		multiple_cards, 0	; Have multiple cards been previously found
	jnz		no_need_m_error		; Jump if so
	mov		multiple_cards, 1 	; Mark for next time
	print	more_than_one_msg	; Announce the multiple cards problem
	mov		ax, base_addr		; Display the IO address of the first card
	mov		di, offset cgroup:temp_storage
	mov		[di], ax
	mov		dx, offset cgroup:dummy_msg
	call	print_number		; (Corrupts bx)
no_need_m_error:
	pop		ax					; Display the IO base address of current card
	push	ax
	mov		di, offset cgroup:temp_storage
	mov		[di], ax
	mov		dx, offset cgroup:dummy_msg
	call	print_number
	pop		dx
	pop		di
	pop		bx
	ret
found_many	ENDP

	public	find_base
find_base	PROC	NEAR
	mov		bh, R_ROBIN_BITS	; The mask bits for the round robin counter
	cmp		io_addr, 0h			; Has a base address been specified
	jz		full_scan			; No - start scan from the begining
	mov		dx, io_addr			; Start scan from specified address
	add		dx, ID_REG
	mov		di, dx				; DI holds last I/O address to examine
	jmp		short f_b_cont
full_scan:
	mov		dx, FIRST_IO		; First I/O Address to examine
	mov		di, LAST_IO			; DI holds last I/O address to examine
f_b_cont:
	in		al, dx
	mov		bl, al				; Keep a copy
	and		al, ID_REG_MASK		; Mask off bits not required
	cmp		al, ID_REG_SIG		; Do we have the signature
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
	mov		dx, offset cgroup:specified_failed
	jmp		short f_b_failed2
f_b_failed1:
	mov		dx, offset cgroup:scan_failed	; Message to announce later
f_b_failed2:
	stc							; Set carry and return
	ret

check_sig:
	; Routine to check the round robin counter at the ID register
	; FIrst task is to sync the counter bits to 0
	and		bl, bh		; Get only the round_robin counter bits
	rol		bl, 1		; Bits are required in B1 and B0 of BL
	rol		bl, 1
	mov		cx, 03h		; Get into cl the number of INs that are
	sub		cl, bl		;   to sync the round robin counter
	jcxz	sync_ok			; Jump if already synchronized
cont_sync:
	in		al, dx		; Read from the ID Register
	loop	cont_sync
; Now it is synchronized the count can be checked.
; A loop would be more compact but this code is faster and will not be kept by
; the TSR.
sync_ok:
	in		al, dx			; Get the next value of the ID Register
	and		al, bh			; Leave only the round_robin counter bits in al
	cmp		al, 00h			; Check if it is the expected count
	jnz 	f_b_cont1		; No - move on to consider the next IO port
	in		al, dx			; Get the next value of the ID Register
	and		al, bh			; Leave only the round_robin counter bits in al
	cmp		al, 40h			; Check if it is the expected count
	jnz 	f_b_cont1		; No - move on to consider the next IO port
	in		al, dx			; Get the next value of the ID Register
	and		al, bh			; Leave only the round_robin counter bits in al
	cmp		al, 80h			; Check if it is the expected count
	jnz 	f_b_cont1		; No -  move on to consider the next IO port
	in		al, dx			; Get the next value of the ID Register
	and		al, bh			; Leave only the round_robin counter bits in al
	cmp		al, 0C0h		; Check if it is the expected count
	jnz 	f_b_cont1		; No -  move on to consider the next IO port
; Check that another 82595 has not been found
	cmp		base_addr, 0h	; Value should initially be zero
	jz		first_found		; Ok to proceed
	mov		dx, offset cgroup:found_two; Message to announce later
	stc						; Set carry and return
	ret
first_found:
	sub		dx, ID_REG		; Get the read base
	mov		base_addr, dx	; Store the base address
	add		dx, ID_REG		; Point back to the ID register
	jmp 	f_b_cont1		; Continue the scan of IO addresses
find_base	ENDP


get_eeprom_data PROC NEAR
					; Called with :
					; bx = starting offset address in the EEPROM
					; cx = number of bytes to read
					; ds:di = buffer to place the data
					; si is use for temporary storage

	LOAD_BANK_PORT	BANK2, EEPROM_REG; Set the eeprom port
get_next_eeprom_byte:
	mov		al, EECS	; EEPROM chip select
	out		dx, al		; Enable the eeprom

;get_next_eeprom_byte:
	push	cx			; Number of bytes left to read
	push	bx			; Address of next byte in eeprom

; First select eeprom for reading
eeprom_ok:
	mov		al, EEDI OR EECS; Set a 1 in the data bit
	write_eeprom_bit		; Write a 1
	write_eeprom_bit		; Write a 1
	mov		al, EECS	; Set a 0 in the data bit
	write_eeprom_bit		; Write a 1

	pop		bx		; Next eeprom address bits
	inc		bx
	push	bx			; Store eeprom address bits
	dec		bx

	ror		bl,1		; Align the address bits so that the MSB
	ror		bl,1		; is at the EEDI position
	ror		bl,1
	mov		cx, 06h		; Number of bits in each address is 6
next_add_bit:
	mov		bh, bl		; Save a copy of the address bits
	and		bl, EEDI	; Clear all bits except EEDI
	and		al, NOT EEDI	; Clear the EDIT bit
	or		al, bl		; EDDI bit in al is now set as required
	write_eeprom_bit		; Write the address bit
	jz		eeprom_address_done;  no need to do all 6 bits
	mov		bl, bh		; Retrive the address bits	
	rol		bl, 1		; Rotate the address bits
	loop	next_add_bit		; Write out all 6 bits

eeprom_address_done:			; Now ready to read the EEPROM data
	xor		si, si		; Byte will be assembled in si
	mov		cx, 10h		; Number of bits to fetch
get_next_bit:
	read_eeprom_bit			; Value of eeprom bit returned in bl
	and		bx, EEDO	; Clear all but the eeprom data output bit
	or		si, bx		; Add the bit to the assembled byte
	rol		si, 1		; Advance byte ready for next bit
	loop	get_next_bit		; Continue until all 16 bits have been read

	mov		cl, 4h		; Final rotate for SI gets the word aligned
	ror		si, cl		;  correctly

	mov		[di], si	; Store the word
	add		di, 2		; Advance the buffer pointer

	pop		bx		; Next EEPROM address to read from
	pop		cx		; Remaining bytes to read
	dec		cx		; Two bytes are read each time
	dec		cx		; So cx is decremented by two
	mov		al, 0		; Disable the EEPROM
	out		dx, al		; Perform the operation
	jcxz	no_more			; If zero then we have finished
	jmp		get_next_eeprom_byte
no_more:
	mov		al, 0		; Disable the EEPROM
	out		dx, al		; Perform the operation
	SET_BANK_PORT	BANK0, COMMAND_REG; Setup the default bank
	ret
get_eeprom_data ENDP

dump_eeprom	PROC	NEAR
	push	bx
	push	cx
	push	di

	xor		bx, bx					; Offset into eeprom for start of address
	mov		cx, CHKSUM_LEN * 2		; Number of bytes to read
	mov		di, offset cgroup:eeprom_buff	; Where to write the data
	call	get_eeprom_data			; Get the ethernet address

	pop		di
	pop		cx
	pop		bx
	ret
dump_eeprom	ENDP

chksum_eeprom	PROC	NEAR
	push	bx

	mov		si, offset cgroup:eeprom_buff	; offset of data
	mov		cx, CHKSUM_LEN		; words to chksum
	xor		bx, bx			; Seed chksum buffer so that final sum is zero
chksum_loop:
	lodsw					; get a word
	add		bx, ax			; sum it
	loop	chksum_loop

	cmp		bx, CHKSUM_VAL	; Does it sum to correct signature?
	jne		chksum_bad

	cmp		no_prom, 0			; User specified ethernet address
	jne		user_address	 	; Yes - no need to read the eeprom address

; Routine that reverses the ethernet address read from the eeprom.
; Originally read in LSB to MSB, required in MSB to LSB order for rom_address

	mov		ax, ds				; ES needs to be correct
	mov		es, ax
	mov		cx, EADDR_LEN/2		; Number of word to move/byte swap
	mov		di, offset cgroup:rom_address	; Where to write ethernet address
	mov		bx, offset cgroup:eeprom_buff
	add		bx, (4 SHL 1)		; WORD 4 is end of address
load_and_reverse_address:
	mov		ax, word ptr [bx]	; get the next word of ethernet address
	xchg	ah, al				; Need to swap the bytes
	stosw						; save the word to es:di]
	dec		bx
	dec		bx
	loop	load_and_reverse_address
user_address:
	mov		al, byte ptr [eeprom_buff+02h]	; Word 1 holds interrupt # selection
	and		al, 07h					; Mask all but the selection bits
	mov		irq_sel, al
	mov		ax, [eeprom_buff+0Eh]	; Word 7 is IRQ bit map
	mov		irq_map, ax

	clc
	jmp		short chksum_ok
chksum_bad:
	print	eeprom_chksum_bad
	stc						; set flag for chksum bad
chksum_ok:
	pop		bx
	ret
chksum_eeprom	ENDP

locate_netidblk	PROC
	push	es
	mov		ax, 0C000h			; Scan from C000:0 -> F000:FFFFh
new_segment:
	mov		es, ax				; load es with new seg to scan
	xor		di, di				; zero offset
	mov		cx, 0FFC8h			; bytes to scan in this segment
nid_continue:
	mov		si, offset cgroup:id_strings	; point to strings to scan for
	lodsb						; get first byte of id strings
	repne	scasb				; look for match for 1st byte
	jz      nid_continue1

	jmp		next_64K_segment	; no match? -> try a new segment
nid_continue1:
	lea		bx, [di-1]			; bx saves base address of netidblk
	push	cx					; save bytes left in this segment
	mov		cx, 7				; bytes left in 1st id string
	repe	cmpsb
	pop		cx
	jnz		nid_continue		; if no match, continue searching segment

	inc		di					; skip 2 bytes
	inc		di
	push	cx					; save bytes left in this segment
	mov		cx, 16				; bytes in 2 remaining id strings
	repe	cmpsb
	pop		cx
	jnz		nid_continue		; if no match, continue searching segment

	push	di
	push	cx
	push	bx
	mov		ax, bx
	shr		ax, 1
	shr		ax, 1
	shr		ax, 1
	shr		ax, 1
	mov		di, es
	add		ax, di
	mov		[nidblk_seg], ax
	mov		di, offset cgroup:nidblk_seg
	mov		dx, offset cgroup:nidblk_found
	call	print_number		; display address of block we found
	pop		bx
	pop		cx
	pop		di

	mov		al, es:[bx+20h]
	and		ax, 0FCh			; pickup high byte (contains IO mapping)
	shl		ax, 1
	shl		ax, 1
	cmp		[io_addr], ax		; is netidblk for card @ same address ?
	je		nid_continue2

	print	nidblk_wrong_io 	; Anounce why we are not using NETID info
	jmp		nid_continue

nid_continue2:
	push	cx
	push	ds

	mov		cx, NETID_LEN		; get byte-length of block
	mov		si, bx				; si addresses block
	push	es
	pop		ds
	xor		ah, ah				; zero chksum buffer
chksum_netidblk:
	lodsb
	add		ah, al				; build chksum
	loop	chksum_netidblk

	pop		ds
	pop		cx
	or		ah, ah
	jz		nid_continue3

	print	nidblk_chksum_bad ; Anounce why we are not using NETID info
	jmp		nid_continue
nid_continue3:
	mov		ax, es:[bx.eepromW7]	; Word 7 is IRQ bit map
	mov		irq_map, ax

	cmp		no_prom, 0			; User specified ethernet address
	jne		nid_no_address	 	; Yes - no need to read the eeprom address

;	test	byte ptr es:[di], 0	; does block contain an ethernet address ?
;	jnz		nid_continue

	mov		cx, EADDR_LEN		; Number of word to move/byte swap
	add		bx, 29h
	mov		di, offset cgroup:rom_address	; Where to write ethernet address
move_ethernet_address:
	mov		al, byte ptr es:[bx]
	mov		byte ptr [di], al
	inc		di
	dec		bx
	loop	move_ethernet_address
nid_no_address:
	call	crlf
	clc
	jmp		short nid_fini

next_64k_segment:
	mov		ax, es
	add		ax, 1000h			; increment segment
	jc		nid_not_found

	jmp		new_segment			; carry set = end of scan, not found.
nid_not_found:
	mov		dx, offset cgroup:nidblk_scan_fail
	stc
nid_fini:
	pop		es
	ret
locate_netidblk	ENDP

code	ends

_text	segment para public 'code'
_text	ends

init	segment para public 'code'
init	ends

	END
