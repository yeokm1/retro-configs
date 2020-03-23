	include	defs.asm
	include	tpropkt.inc
	include	tpropkti.mac

NOWARN RES
version equ 2
WARN

code	SEGMENT	word public
	assume	cs:code, ds:code
; The following are all defined in tpropkt.asm
	extrn	inw_routine : word, outw_routine : word
	extrn	repins : word, repouts : word
	extrn	int_no : byte, io_addr : word, base_addr : word, int_num : word
	extrn	driver_type : byte, driver_name : byte
	extrn	tx_buff_no : word, buff_ptrs : word, rx_buff_ptr : word
	extrn	reset_chip : near, set_ether : near
	extrn	set_timeout : near, do_timeout : near
	
	extrn	is_186 : byte		;=0 if 808[68], =1 if 80[123]86.

; The following are all defined in tpropkti.asm
	extrn	inw_16 : near, outw_16 : near
	extrn	inw_2_8 : near, outw_2_8 : near
	extrn	quick_rep_ins_16 : near, rep_ins_16 : near
	extrn	quick_rep_ins_2_8 : near, rep_ins_2_8 : near
	extrn	quick_rep_outw_16 : near, rep_outw_16 : near
	extrn	quick_rep_outw_2_8 : near, rep_outw_2_8 : near

NOWARN RES
	extrn	wait_27ms : near, wait : near
WARN

	extrn	my_address: byte
	public	usage_msg
	usage_msg	db	"usage: tpropkt [options] <packet_int_no> <hardware_irq> <io_addr>",CR,LF,'$'

	public	copyright_msg
	copyright_msg	db	"Packet driver for the ",my_name,", version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF

		db	"Portions written by Morien W. Roberts",CR,LF,'$'

this_board_msg	db	"This board is a ",'$'
memory_bad_msg	db	"Ethernet buffer memory bad",CR,LF,'$'
testing_mem_msg	db	CR,LF,"Testing memory .",'$'

download_msg		db	CR,LF,"Downloading 80186 MAC code..",'$'
download_bad_msg	db	" DOWNLOAD FAILED",CR,LF,'$'
download_ok_msg		db	" sucessfully completed",CR,LF,'$'

config_ring_bad_msg	db	" CONFIG RING FAILED",CR,LF,'$'

join_ring_msg		db	"Attempting to join ring",'$'
join_ring_msg16		db	CR,LF,"Joined ring at 16 Mbits",CR,LF,'$'
join_ring_msg4		db	CR,LF,"Joined ring at 4 Mbits",CR,LF,'$'
join_ring_bad_msg	db	CR,LF,"***JOIN FAILED***",CR,LF,'$'

eeprom_word1		dw	?

byte_msg	db "Performing 8 bit I/O transfers",CR,LF,'$'
word_msg	db "Performing 16 bit I/O transfers",CR,LF,'$'

irq_too_big_msg	 db "The ",my_name," Adapter is in an 8-bit slot but is configured to",CR,LF
db "use an interrupt that is not available in an 8-bit slot.  The driver will not",CR,LF
db "load.  Please use TokenSet to select an interrupt less than 8 or, for better",CR,LF
db "performance, move the adapter to a 16-bit slot.",CR,LF,'$'

eight_in_sixteen_msg	label	byte
db "The ",my_name," Adapter is configured for 8-bit operation but is in a",CR,LF
db "16-bit slot.  For better performance, use TokenSet to configure for a 16-bit",CR,LF
db "bus slot.",CR,LF,'$'

sixteen_better_msg	label	byte
db "The ",my_name," Adapter is installed in an 8-bit slot.  For better",CR,LF
db "performance move the adapter to a 16-bit slot.",CR,LF,'$'

int_bad_msg	db	"That interrupt number is not supported.",CR,LF
		db	"The ",my_name," EEPROM is currently configured to use",CR,LF
		db	"IRQs "
dummy_msg	db '$'
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
specified_failed 	db  "A ",my_name," adapter was not found at specified address.",CR,LF,'$'
scan_failed db  "Scan of I/O space did not find a ",my_name," adapter.",CR,LF,'$'
found_two	db	"Found two ",my_name," adapters.",CR,LF,'$'
board_name	dw  ?	; Filled with the address of one of the next two lines
board_name_8	db      02h, "Mozart ",0,48
board_name_16	db      02h, "Wolfgang ",0,48
irq_map		dw	?	; Read from the eeprom - holds mapping of the Mozart IRQs
irq_count	dw	?	; Number of bit sset in the irq_map
no_prom		db	0	; <> 0 if ethernet address specified on the command line
mozart_int	db	?	; Int number on the Mozart board (0 - 7)

join_ring_buff	dw	0020h, 00000h, 0000h, 0026h
jrb_stat_add	dw  EADDR_LEN/2 dup (50)
jrb_pid			dw 9 dup (00h)
jrb_options		dw  CONG_AVODI
jrb_TRM_RX		dw ?	; Filled in by join ring command
jrb_last_MAC	dw ?	; Filled in by join ring command
jrb_p_table		dw ?	; Filled in by join ring command
jrb_stop_add	dw STOP_REG_LOC
jrb_rx_upp_add	dw RX_AREA_END+1
jrb_rx_low_add	dw RX_AREA_BEG
jrb_watch_dog	dw WATCH_DOG
join_ring_buff_end :

config_ring_buff	dw	CONFIG_CMD
					dw	0000h, 0000h
					dw	CONFIG_CMD_LEN
config_options		dw	ALL_NON_MAC
;FMRO		EQU	0008h		; Media rate option : 1 = 16 Mbits
;		EQU 0010h		; Early token release
;ASMR		EQU	0080h		; Auto sense media rate
;ALL_NON_MAC	EQU	0200h		; Pass Non-MAC frames in promiscuous mode
;	MOV    	config_policy_flags,  RING_CONFIG_TR_HARD_ERROR_REPORT 2000h OR \
;	   			RING_CONFIG_TR_SOFT_ERROR_REPORT 1000h OR \
;	   			RING_CONFIG_ACTIVATE_TR_STATUS_CHANGE 0800h
config_stat_add		dw	EADDR_LEN/2 dup (50)
config_ring_buff_end :

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
	call	etopen_mozart
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

; This code simply goes through the irq_map and informs which interrupts are
; available.  The irq_map was obtained from the eeprom. The interrupt list
; is generated one by one and separated by commas except the last two
; interrupts which are separated with an '&'.

; First the number of possible interrupts is determined
	xor		ax, ax				; Clear the bit total count
	mov		bx, irq_map			; Copy the irq_map
	mov		cx, 10h				; Number of bits to check
next_bit:
	sar		bx, 1				; Get the right most bit into carry
	adc		al, 0				; Add 1 to bit total only if bit was set
	loop	next_bit			; Continue until all 16 bits are done
	dec		ax					; Count to start from 0
	mov		irq_count, ax		; Store the count of bits seen

	print	int_bad_msg		 	; Infrom the user of the int problem
	mov		bx, irq_map			; Copy the irq_map
	mov		cx, 10h				; Number of bits to check
	xor		dx, dx
	mov		si, dx				; Clear the count of number of bits found
	mov		ax, 1
check_next:
	test	irq_map, ax			; Is this int available
	je		not_available
	inc		si					; Inc number of bits processed
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
	extrn	decout	: near
	call	decout
	pop		si
	cmp		si, irq_count
	jg		no_output
	je		output_&
	mov		al, ','
	jmp		SHORT output_it
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
	; here with bl = IRQ number as seen by the board.
	LOAD_BANK_PORT	BANK1, REG1
	in		al, dx				; Get current value (8 bits)
	test	al, WORD_WIDTH		; Is chip configured for word transfers
	jne		width_okay			; Yes, cool
	mov		ah, al				; Save the original.
	or		al, WORD_WIDTH		; Configure for 8.  Try 16.
	out		dx, al
	in		al, dx				; Did it stick?
	test	al, WORD_WIDTH
	mov		cx, offset eight_in_sixteen_msg
	jne		width_16_okay		; Yes, must be configured 8 in 16.
	mov		cx, offset sixteen_better_msg
	cmp		bl, 7				; A real 8-bit slot -- is int <= 7?
	jbe		width_16_okay		; Yes.
	mov		dx, offset irq_too_big_msg
	stc
	ret
width_16_okay:
	mov		al, ah				; Restore the original mode.
	out		dx, al
	mov		dx, cx
	print_it					; Announce the message
width_okay:

; Convert the IRQ# to the INTR bit pattern for the Mozart board
; Need to find which MOZART interrupt this is
	xor		dl, dl					; dl holds the INTR bit pattern
	mov		cl, bl					; Get back the copy of the int_no
	xor		ch, ch
	jcxz	found_it
	mov		ax, irq_map				; Convertion map
next_irq_map_bit:
	sar		ax, 1
	jnc		not_set
	inc		dl						; Inc the INTR bit pattern
not_set:
	loop	next_irq_map_bit
found_it:
	mov		mozart_int, dl			; Store the INTR bit pattern

	mov		si, board_name
	print	this_board_msg

	movseg	es, ds					; Copy the driver name to where we need it.
	mov		di, offset driver_name

check_board_copy:
	lodsb
	stosb
	or		al, al
	je		check_board_done_print
	call	chrout					; Print the character.
	jmp		check_board_copy
check_board_done_print:
	print	testing_mem_msg

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
	call	download_code		; Down load the mac code into the 80186
	jc		download_bad
	jmp		short download_ok

download_bad:
	mov		dx, offset download_bad_msg
	stc
	ret

download_ok:
	print	download_ok_msg

	call	crlf
	mov		al, int_no			; Get board's interrupt vector
	add		al, 8
	cmp		al, 8+8				; Is it a slave 8259 interrupt?
	jb		set_int_num			; No.
	add		al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor		ah, ah				; Clear high byte
	mov		int_num, ax			; Set parameter_list int num.

	movseg	es,ds
	mov		si, offset rom_address
	mov		di, offset my_address
	repmov	EADDR_LEN

	call	set_RX_TX_areas

if ROUTING eq 1
	extrn	initialize_cache : near
	call	initialize_cache
endif
	call	join_ring 	; Various error messages are set in the join ring code
	jnc		join_ring_ok
	ret

join_ring_ok:
	call	setup_mozart_ints
	call	set_recv_isr
	clc
	ret

	public	download_code
download_code	PROC	NEAR
; This routine loads the MAC code into the 1'st block of the 80186 memory
	print	download_msg			; Inform the user
; First disable and reset the 80186
	LOAD_BANK_PORT	BANK0, COMMAND_REG
	mov		al, DISABLE_80186
	out		dx, al

; Wait 2mS for the reset to take place
	call	wait_27ms		; Docs specify only 2mS

; Select block 0 - i.e. the 80186 block
	SET_BANK_PORT	BANK0, BLOCK_SEL_REG
	xor		al, al
	out		dx, al

; Set up the address register to point to location 0000 in block 0
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	xor		ax, ax
	outw

; Copy the refresh part of the mac code
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		cx, REFRSH_CODE_SIZE
	mov		si, offset mac_code
	call	repouts

; Select block 1 - i.e. the 'last' block
	SET_BANK_PORT	BANK0, BLOCK_SEL_REG
	mov		al, 11h
	out		dx, al

; Set up the address to point to the restart location in block 1
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, RESTART_LOC
	outw

; Copy the jmp 0:50 command (start of the mac code) to the restart location
	push	si		; Save current position of the mac copy
	mov		cx, RESTART_JMP_SIZE
	mov		si, offset mac_code
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	call	repouts
	pop		si		; Recover the previous mac copy position

; Select block 0 - i.e. the 80186 block
	SET_BANK_PORT	BANK0, BLOCK_SEL_REG
	xor		al, al
	out		dx, al

; Enable the 80186 and release 80186 from reset
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, ENABLE_80186
	out		dx, al

; Set up the address to point to location SECOND_PART (0C00) in block 0
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, SECOND_PART
	outw

	mov		cx, mac_length				; Total length of the download code
	sub		cx, REFRSH_CODE_SIZE		; Less bytes previously loaded
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	call	repouts

; Inform the 80186 that the download is complete
; Set up the address to point to the FLAG_LOC location in block 0
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, DOWNLOAD_FLAG_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	xor		ax, ax
	outw								; Clear the flag location

; Check for a mac_handshake
;	mov		ax, 100h
	mov		ax, 80h
	call	set_timeout
wait_mac_handshake:
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, HANDSHAKE_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	inw									; Read handshake value
	cmp		ax, HANDSHAKE_VALUE			; Check for expected handshake value
	je		got_handshake				; Yes - then we can proceed
	call	do_timeout					; Check if any time is left
	jnz		wait_mac_handshake			; Jump if some time is left
	stc									; Indicate an error.
got_handshake:
	ret
download_code	ENDP
	
	public	set_RX_TX_areas
set_RX_TX_areas	PROC	NEAR
; Sets up all the RX and TX buffers variables as well as setting the buffer
; registers in the Mozart chip. Code works on one bank at a time to minimize
; bank swapping.
; Partion the Mozart RAM into three sections :
; shared memory area, RX area and a TX area - in this order
	LOAD_BANK_PORT	BANK1, RCV_LOW_LIMIT_REG
	mov		al, RX_AREA_BEG / 100h
	out		dx, al
	SET_BANK_PORT	BANK1, RCV_UPPER_LIMIT_REG
	mov		al, RX_AREA_END / 100h
	out		dx, al
	SET_BANK_PORT	BANK1, XMT_LOW_LIMIT_REG
	mov		al, TX_AREA_BEG / 100h 
	out		dx, al
	SET_BANK_PORT	BANK1, XMT_UPPER_LIMIT_REG
	mov		al, (RAM_SIZE / 100h) -1
	out		dx, al

; Specify which adapter memory block is to be used for the TX and RX buffers
	SET_BANK_PORT	BANK0, BLOCK_SEL_REG
	mov		al, 11h
	out		dx, al

; Setup the XMT start address register - 16 bit write
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	mov		ax, TX_AREA_BEG
	outw

; Setup the RCV start address register - 16 bit write
	SET_BANK_PORT	BANK0, BAR_LOW	; Specify start of the receive area
	mov		ax, RX_AREA_BEG
	mov		rx_buff_ptr, ax
	outw

; As per docs - first byte of the receive buffer should be initialized to zero
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	xor	ax, ax
	outw

; Setup the RCV stop address register - 16 bit write
	SET_BANK_PORT	BANK0, RCV_STOP_LOW	; Specify end of receive area
	mov		ax, RX_AREA_END - 1
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
	ret
set_RX_TX_areas	ENDP


setup_mozart_ints	PROC	NEAR
; Enables the Mozart interrupt and masks all but the RX interrupt.

; Specify which interrupt to use
	LOAD_BANK_PORT	BANK1, INT_NO_REG
	mov		al, mozart_int
	out		dx, al

	SET_BANK_PORT	BANK1, REG1
	in		al, dx
	or		al, INT_ENABLE
	out		dx, al

; Allow only RX events to interrupt
	SET_BANK_PORT	BANK0, INT_MASK_REG
	mov		al, ALL_MASK AND NOT RX_MASK ; Enable only RX interrupts
	out		dx, al

; Issue a RCV_ENABLE command
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, RCV_ENABLE
	out		dx, al 
	ret
setup_mozart_ints	ENDP

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
	mov		ax, bx				; get the pattern word
	mov		cx, RAM_SIZE SHR 2	; number of words to write
	mov		cx, 7ff0h
	mov		cx, 8000h
test_memory_write:
	outw						; write our pattern.
	add		ax, si				; increment the pattern.
	loop	test_memory_write
	
	mov		al, '.'
	call	chrout
	
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	xor	ax,ax					; start at zero again.
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT

	mov		cx,	RAM_SIZE SHR 2	; number of words to read
test_memory_read:
	inw
	cmp		ax, bx				; does it compare correctly?
	jne		test_memory_fail	; no, quit.
	add		bx, si				; increment the pattern.
	loop	test_memory_read	; otherwise, continue
	clc
	ret

test_memory_fail:
	stc
	ret

etopen_mozart	PROC	NEAR
	call	find_base				; Go and find the chip
	jc		exit_etopen_mozart		; Return if error is found
	call	reset_chip
	call	get_ethernet_address	; Fetch ethernet address if necessary
	call	get_IRQ_map				; Fetch the IRQ map from the eeprom
	call	config_chip				; Configure chip
	clc								; No errors to report at this point
exit_etopen_mozart:
	ret
etopen_mozart	ENDP

set_ether_for_join	PROC	NEAR
; Routine writes the Ethernet address into the config and join ring commands
	mov		ax, cs
	mov		es, ax
	mov		si, offset rom_address
	mov		di, offset config_stat_add
	mov		cx, EADDR_LEN/2
	rep		movsw
	mov		si, offset rom_address
	mov		di, offset jrb_stat_add
	mov		cx, EADDR_LEN/2
	rep		movsw
	ret
set_ether_for_join	ENDP

config_ring PROC NEAR
; Write the contents of the config ring parameter block
	LOAD_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, JOIN_RING_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		cx, offset config_ring_buff_end - offset config_ring_buff
	mov		si, offset config_ring_buff
	call	repouts

; Load transmit register to the start of config ring parameter block
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	mov		ax, JOIN_RING_LOC
	outw

; Issue the config ring command
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, CONFIG_CMD
	out		dx, al

	SET_BANK_PORT	BANK0, STATUS_REG
wait_exec_done:
	in		al, dx					; Get exec status
	and		al, EXEC_STATUS			; Ignore all but exec status bits
	jnz		wait_exec_done			; Zero when command complete

	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, JOIN_RING_LOC+2
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	inw								; Config ring command status
	and		ax, CMD_OK_BIT			; Check the command OK bit
	jz		config_ring_failed		; jump if not ok
	clc
	ret

config_ring_failed:
	stc
	mov		dx, offset config_ring_bad_msg
	stc
	ret
config_ring	ENDP

join_ring	PROC NEAR
; Routine attempts to join the ring
	mov	bx,1			; Offset into eeprom for start of map
	mov	cx,2			; Number of bytes to read
	mov	di,offset eeprom_word1	; Where to write the ethernet address
	call	get_eeprom_data

	print	join_ring_msg				; Inform the user
	test	eeprom_word1, EEPROM_RING_SPEED_16	;do they want 16MBPS?
	je	join_at_4mbps
	or	config_options,FMRO	;yes, join at 16mbps.
join_at_4mbps:

	test	eeprom_word1, EEPROM_AUTODETECT		;autodetect speed?
	je	join_at_fixed
	or	config_options,ASMR	;yes, autodetect.
join_at_fixed:

	test	eeprom_word1, EEPROM_EARLY_TR
	je	join_no_early
	or	config_options,FETO	;yes, use early token release.
join_no_early:

	call	config_ring					; Configure ring prior to join
	jnc		config_ring_ok

config_ring_ok:
; Setup the address register to the appropriate point in the shared memory area
	LOAD_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, JOIN_RING_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
; Write the contents of the join ring parameter command
	mov		cx, offset join_ring_buff_end - offset join_ring_buff
	mov		si, offset join_ring_buff
	call	repouts

; Setup the copy of the stop register in block 1 memory
; Prespecified location in the join ring command = STOP_REC_LOC
	SET_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, STOP_REG_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	mov		ax, RX_AREA_END - 1h		; Initial value of the RCV_STOP_REG
	outw

; issue the join ring command
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	mov		ax, JOIN_RING_LOC
	outw
	SET_BANK_PORT	BANK0, COMMAND_REG
	mov		al, JOIN_RING_CMD
	out		dx, al

	mov		cx, 1Eh			; Set total delay about 1 min
wait_join:
	mov		ax, 60h			; Delay for about 2 seconds
	call	wait
	mov		al, '.'
	call	chrout
	; Setup registers to read from the JOIN_RINGLOC address
	LOAD_BANK_PORT	BANK0, HOST_ADDRESS
	mov		ax, JOIN_RING_LOC
	outw
	SET_BANK_PORT	BANK0, LOCAL_MEM_PORT
	inw								; Read join ring command word
	and		al, CMD_DONE_BIT		; Mask all but the done bit
	jnz		join_done				; Join complete if bit is non-zero

	loop	wait_join
join_ring_failed:
	mov		dx, offset join_ring_bad_msg
	stc
	ret

join_done:
	inw								; Join ring status
	test	ax, CMD_OK_BIT		; Check the command OK bit
	je	join_ring_failed	;it failed.
	test	ax,JOINED_AT_16
	je	join_speed_4
	print	join_ring_msg16			; Inform the user
	jmp	join_ring_success
join_speed_4:
	print	join_ring_msg4			; Inform the user
join_ring_success:
	clc
	ret
join_ring ENDP

config_chip	PROC	NEAR
; Set the correct transfer routines
	LOAD_BANK_PORT	BANK1, REG1
	in		al, dx				; Get current value (8 bits)
	test	al, WORD_WIDTH		; Is chip configured for word transfers
	je		eight_bit			; No then do 8 bit transfers

								; Setup the 16 bit routines
	mov		board_name, offset board_name_16 + 1
	mov		dx, offset word_msg	; Using word transfers message
	mov		inw_routine, offset inw_16
	mov		outw_routine, offset outw_16

	cmp		is_186,0			; Can we use fast routines ?
	je		slow_16_bit			; No - have to do use the slower routines
	mov		repins, offset quick_rep_ins_16
	mov		repouts, offset quick_rep_outw_16
	jmp		SHORT routines_are_set
slow_16_bit:
	mov		repins, offset rep_ins_16
	mov		repouts, offset rep_outw_16
	jmp		SHORT routines_are_set

eight_bit:						; Setup the 8 bit routines
	mov		board_name, offset board_name_8 + 1
	mov		dx, offset byte_msg	; Using byte transfers message
	mov		inw_routine, offset inw_2_8
	mov		outw_routine, offset outw_2_8
	cmp		is_186,0			; Can we use fast routines ?
	je		slow_8_bit			; No - have to do use the slower routines
	mov		repins, offset quick_rep_ins_2_8
	mov		repouts, offset quick_rep_outw_2_8
	jmp		SHORT routines_are_set
slow_8_bit:
	mov		repins, offset rep_ins_2_8
	mov		repouts, offset rep_outw_2_8
routines_are_set:
	print_it					; Announce which routines we are using

; Partion the memory for the eventual memory test
; 1'st the desired memory block is selected - 2nd block as suggested in the docs
; The XMT and RCV buffers are configured to use all 64k bytes in the block
; The buffers are overlaped so as to avoid the undesirable automatic
; wrap_around of the host address register

; Specify the second memory block, user RX and TX buffers is to be tested
; DX has been corrupted so a LOAD is required
	LOAD_BANK_PORT	BANK0, BLOCK_SEL_REG
	mov		al, 11h
	out		dx, al

; Use all the memory for the XMT buffer
	SET_BANK_PORT	BANK1, XMT_LOW_LIMIT_REG
	mov		al, 00h
	out		dx, al

	SET_BANK_PORT	BANK1, XMT_UPPER_LIMIT_REG
	mov		al, (RAM_SIZE / 100h) -1
	out		dx, al

	SET_BANK_PORT	BANK1, RCV_LOW_LIMIT_REG
	mov		al, 00h
	out		dx, al

	SET_BANK_PORT	BANK1, RCV_UPPER_LIMIT_REG
	mov		al, (RAM_SIZE / 100h) -1
	out		dx, al

; Setup the XMT start address register - 16 bit write
	SET_BANK_PORT	BANK0, XMT_ADDR_REG
	mov		ax, 0000h
	outw

; Setup the RCV start address register - 16 bit write
	SET_BANK_PORT	BANK0, BAR_LOW
	mov		ax, 0000h
	outw

; Setup the RCV stop address register - 16 bit write
	SET_BANK_PORT	BANK0, RCV_STOP_LOW
	mov		ax, 0FFFEh
	outw

; Set the Individual address registers with the Ethernet address
	mov		si, offset rom_address
	call	set_ether
	call	set_ether_for_join
	ret
config_chip	ENDP

	public	find_base
find_base	PROC	NEAR
	mov		bh, R_ROBIN_BITS+ID_MASK	; The mask bits for the signature
	cmp		io_addr, 0h			; Has a base address been specified
	jz		full_scan			; No - start scan from the begining
	mov		dx, io_addr			; Start scan from specified address
	mov		di, dx				; DI holds last I/O address to examine
	jmp		SHORT add_id_reg
full_scan:
	mov		dx, FIRST_IO		; First I/O Address to examine
	mov		di, LAST_IO			; DI holds last I/O address to examine
add_id_reg:
	add		dx, ID_REG			; Start at the signature register
f_b_cont:
	in		al, dx
	mov		bl, al				; Keep a copy
	and		al, ID_MASK			; Mask off bits not required
	cmp		al, ID_BITS1  		; Do we have the signature
	jz		check_sig			; Looks promising go and check it
	cmp		al, ID_BITS2  		; Do we have the signature
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
	jmp		SHORT f_b_failed2
f_b_failed1:
	mov		dx, offset scan_failed	; Message to announce later
f_b_failed2:
	stc							; Set carry and return
	ret

check_sig:
	; Routine to check the round robin counter at the ID register
	; FIrst task is to sync the counter bits to 0
	and		bl, R_ROBIN_BITS	; Get only the round_robin counter bits
	rol		bl, 1				; Bits are required in B1 and B0 of BL
	rol		bl, 1
	mov		cx, 03h				; Get into cl the number of INs that are
	sub		cl, bl				;   to sync the round robin counter
	jcxz	sync_ok				; Jump if already synchronized
cont_sync:
	in		al, dx				; Read from the ID Register
	loop	cont_sync
; Now that it is synchronized, the count can be checked.
; A loop would be more compact but this code is faster and will not be kept by
; the TSR.
sync_ok:
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the counter & ID bits in al
	cmp		al, ID_SIG1			; Check if it is the expected value
	jnz 	f_b_cont1			; No - move on to consider the next IO port
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the counter & ID bits in al
	cmp		al, ID_SIG2			; Check if it is the expected value
	jnz 	f_b_cont1			; No - move on to consider the next IO port
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the counter & ID bits in al
	cmp		al, ID_SIG3			; Check if it is the expected value
	jnz 	f_b_cont1			; No -  move on to consider the next IO port
	in		al, dx				; Get the next value of the ID Register
	and		al, bh				; Leave only the counter & ID bits in al
	cmp		al, ID_SIG4			; Check if it is the expected value
	jnz 	f_b_cont1			; No -  move on to consider the next IO port
; Check that another Mozart has not been found
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
;	ror		si, 1				; Advance byte ready for next bit
	loop	get_next_bit		; Continue until all 16 bits have been read
	mov		cl, 4h				; Final rotate for SI gets the word aligned
	ror		si, cl				;    correctly
;	mov		cl, 5h				; Final rotate for SI gets the word aligned
;	rol		si, cl				;    correctly

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
	mov		ax, ds				; ES needs to be correct
	mov		es, ax
	cmp		no_prom, 0			; User specified ethernet address
	jne		no_need			 	; Yes - no need to read the eeprom address
	mov		bx, 02h				; Offset into eeprom for start of address
	mov		cx, EADDR_LEN		; Number of bytes to read
	mov		di, offset	rom_address	; Where to write the ethernet address
	call	get_eeprom_data		; Get the ethernet address
	mov		cx, EADDR_LEN/2		; Number of words to reverse
	mov		di, offset	rom_address	; Where to start the reverse
	call	reverse_bits		; Reverse the bits in ethernet address words
	call	reverse_address		; Reverse the byte order of the address
no_need:
	ret
get_ethernet_address	ENDP

reverse_bits	PROC	NEAR
; Routine that reverses the bits in the words read from the eeprom.
; Bit 15 becomes bit 0 and v.v - then swap the hi/low bytes
reverse_bits_1:
	push	cx
	mov		bx, [di]			; Get the next word to reverse
	mov		cx, 10h
reverse_bits_2:
	rol		bx, 1
	rcr		ax, 1
	loop	reverse_bits_2
	xchg	ah, al
	stosw
	pop		cx
	loop	reverse_bits_1
	ret
reverse_bits	ENDP

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
	call	get_eeprom_data
	ret
get_IRQ_map	ENDP

	extrn	get_hex: near
	include	getea.asm
	include mac.inc

code	ENDS
	END
