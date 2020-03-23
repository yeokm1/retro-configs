;Licensed by Intel for distribution without complete source.
;History:1570,1
;Thu Apr 05 13:33:33 2001 Handle unprogrammed EEPROM.
;Wed Jan 03 22:51:55 2001 Add DEVIDE_ID4 to support the Pro/100 VA  -A. Wik
;Wed Dec 27 17:09:22 2000 Attempt to continue even though we seem to have no phy devices.
;Wed Dec 27 16:24:24 2000 Move messages from messages.inc into il.asm
;Mon Aug 23 14:28:56 1999 newer devices have bigger eeproms
;Mon Aug 23 13:16:28 1999 Add support for multiple device ids.
;Thu Jul 22 16:30:35 1999 default to half duplex, and fix some missing (but unused) symbols.
;Wed Jan 21 09:15:26 1998 Need to turn on bus_master in PCI command register.
;Wed Dec 10 16:15:46 1997 we were printing the self test FAILED msg twice.
;    Jan 15          1997 Change incorporated into main distribution by Russell Nelson.
;    Dec 18          1996 Fujitsu Computers, by M. Viima.  EEPROM access changed so that the driver works properly in a 166 Pentium, too.
	include	options.inc
	include	chip.inc
	include	defs.asm

if	CHIP EQ INTEL_82596
	include	82596.inc
else
	include	82557.inc
endif

	include	pci.inc

cgroup	group code, _text, init

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup

	even

extrn	sys_features : byte
extrn	is_186	: byte		;=0 if 808[68], =1 if 80[123]86.
extrn	is_pci	: byte		;=0 if PCI, =1 if PCI
extrn	decout	: near
extrn	int_no 			: byte
extrn	int_num : word
extrn	mem_map_io	: word
extrn	base_addr : word
extrn	send_pkt : near
extrn	set_ether : near
extrn	do_config : near
extrn	config_mii_mode : byte
extrn	config_cdt : byte
extrn	config_duplex : byte
extrn	reset_chip : near
extrn	wait_27ms : near
NOWARN
extrn	wait : near
WARN
extrn	do_timeout : near
extrn	set_timeout : near
extrn	timeout : word
extrn	timeout_counter : word
extrn	timeout_value : word

extrn	multicast_fix : word
extrn	issue_cmd : near
extrn	wait_scb_non_active : near
extrn	tx_buff_no : word
extrn	buff_ptrs : word
extrn	cmd_buff1 : byte
extrn	cmd_buff2 : byte
extrn	start_rfd : byte
extrn	start_rbd : byte
extrn	start_rx_buff : byte
extrn	first_rfd : word
extrn	last_rfd : word
extrn	first_rbd : word
extrn	last_rbd : word
extrn	enable_board_int : near
extrn	disable_board_int : near
	
if	CHIP EQ INTEL_82596
	extrn	scb_buff	: word
endif

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

	extrn	get_hex: near
	include	getea.asm
	include	lookstr.asm
	include	toupper.asm
	extrn	wordout: near

if LANGUAGE eq US_ENGLISH
	public	usage_msg, copyright_msg

bad_key_msg		db	"Unknown keyword on the command line.", CR,LF
usage_msg	label	byte
	db "usage: ",short_name
 	db " [options] <packet_int_no> <slot_no> {connector} {speed} {duplex}",CR,LF
	db "connector=[AUTO|UTP|BNC|AUI] speed=[SLOW|FAST] duplex=[HALF|FULL]",CR,LF,'$'
copyright_msg	label byte
	db "Packet driver for ",long_name,", vers "
	db '0'+(majver / 10),'0'+(majver mod 10),".1",'0'+(vers mod 10),CR,LF
	db "Supports: PCI.",CR,LF
	db "Portions written by Morien W. Roberts; "

need_pci_msg		db	"A PCI BIOS is required for this driver.",CR,LF,'$'
irq_problem_msg		db	"Problem reading IRQ from PCI configuration.",CR,LF,'$'
self_test_msg		db	"Performing self test of chip....",'$'
self_test_ok_msg	db	"     PASSED.",CR,LF,'$'
self_test_no_msg	db	"     FAILED.",CR,LF,'$'
virtual_services	db	"Using virtual memory services of memory manager."
					db	CR,LF,'$'
no_virtual_services	db	"Not using any memory manager services.",CR,LF,'$'
problem_in_phys_add	db	"Problem with virtual memory services.",CR,LF,'$'
if	CHIP EQ INTEL_82596
iscp_init_problem	db	"Problem with ISCP command.",CR,LF,'$'
else
load_base_msg		db	"Config failure - loading base registers.",CR,LF,'$'
fix_root_msg		db	"Multicast setup workaround used for ",'$'
fix_10bits			db	"10 Mbits",CR,LF,'$'
fix_100bits			db	"100 Mbits",CR,LF,'$'
fix_both			db	"both 10 Mbits and 100 Mbits",CR,LF,'$'
support_10_msg		db	"This board only supports 10 Mbits", CR,LF,'$'
support_100_msg		db	"This board supports 100 Mbits", CR,LF,'$'
phy_dev_code_0		db	"No PHY device installed",CR,LF,'$'
phy_dev_code_1		db	"Intel 82553 (PHY 100) A or B step",CR,LF,'$'
phy_dev_code_2		db	"Intel 82553 (PHY 100) C step",CR,LF,'$'
phy_dev_code_3		db	"Intel 82503 10Mps",CR,LF,'$'
phy_dev_code_4		db	"National DP83840 100BASE-TX, C step",CR,LF,'$'
phy_dev_code_5		db	"Seeq 80C240 - 100BASE-T4",CR,LF,'$'
phy_dev_code_6		db	"Seeq 80C24 - 10Mps",CR,LF,'$'
phy_dev_code_7		db	"Intel 82555",CR,LF,'$'
phy_dev_code_8		db	"Unknown-8",CR,LF,'$'
phy_dev_code_9		db	"Unknown-9",CR,LF,'$'
phy_dev_code_10		db	"National DP83840 100BASE-TX,",CR,LF,'$'
phy_dev_code_11		db	"Unknown-11",CR,LF,'$'
phy_dev_code_X		db	"Unknown",CR,LF,'$'
phys_1_msg			db	"PHY device 1 - ",'$'
phys_2_msg			db	"PHY device 2 - ",'$'
no_support_p_layer	db	"PHY device not supported in this driver",CR,LF,'$'
no_support_2_phy	db	"This driver does not support 2 PHY devices",CR,LF,'$'
tx_full_msg		db	"Negotiated speed 100Mbs (100Base-TX) full duplex",CR,LF,'$'
t4_half_msg		db	"Negotiated speed 100Mbs (100Base-T4) half duplex",CR,LF,'$'
tx_half_msg		db	"Negotiated speed 100Mbs (100Base-TX) half duplex",CR,LF,'$'
t_full_msg		db	"Negotiated speed 10Mbs (10Base-T) full duplex",CR,LF,'$'
t_half_msg		db	"Negotiated speed 10Mbs (10Base-T) half duplex",CR,LF,'$'
def_10_half_msg		db	"Using 10Mbs link at half duplex",CR,LF,'$'
def_10_full_msg		db	"Using 10Mbs link at full duplex",CR,LF,'$'
def_100_half_msg	db	"Using 100Mbs link at half duplex",CR,LF,'$'
def_100_full_msg	db	"Using 100Mbs link at full duplex",CR,LF,'$'
frcd_10_half_msg	db	"FORCED 10Mbs link at half duplex",CR,LF,'$'
frcd_10_full_msg	db	"FORCED 10Mbs link at full duplex",CR,LF,'$'
frcd_100_half_msg	db	"FORCED 100Mbs link at half duplex",CR,LF,'$'
frcd_100_full_msg	db	"FORCED 100Mbs link at full duplex",CR,LF,'$'
wait_neg_msg		db	"Waiting for negotiation to complete ",'$'
no_lp_msg		db	"Link partner does not support negotiation",CR,LF,'$'
negotiation_problem	db	CR,LF,"* * * * * * * "
					db	"WARNING - NWAY negotiation failed to complete "
					db	"* * * * * * *",CR,LF,'$'
no_neg_bits_msg	db	"ERROR - Link partner negotiatied no capabilities",CR,LF,'$'
no_common_capability	db "No common link capability",CR,LF,'$'
auto_detect_nr_msg	db	"AUTO DETECT OF MEDIA "
					db	"NOT YET AVAILABLE FOR THIS CARD",CR,LF,'$'
endif
config_msg 			db	"Config failure - config operation failed.",CR,LF,'$'
ether_add_msg		db	"Config failure - setting ethernet address.",CR,LF,'$'
int_no_name			db	"Interrupt number ",'$'
base_addr_name		db	"I/O port ",'$'
separator1_msg		db	", $"
separator3_msg		db	" & $"
specified_failed 	db	"An ",long_name
					db	" was not found at specified address.",CR,LF,'$'
scan_failed 		db	"Scan of I/O space did not find ",long_name,CR,LF,'$'
reading_eeprom_chksum	db	"Reading EEPROM and calculating checksum...",'$'
eeprom_chksum_bad	db	CR,LF,"EEPROM Failed checksum validation; ",CR,LF,'$'

using_auto_msg	db	"Auto detecting media",CR,LF,'$'
using_10B_T_msg	db	"Using twisted pair cable",CR,LF,'$'
using_AUI_msg	db	"Using AUI interface",CR,LF,'$'
using_10B_2_msg	db	"Using coax cable",CR,LF,'$'
no_dev_rec	db	"No PHY_DEV_REC",CR,LF,'$'

	public ether_add_msg1, ether_add_msg2
ether_add_msg1		db	"Config failure - ethernet 1.",CR,LF,'$'
ether_add_msg2		db	"Config failure - ethernet 2.",CR,LF,'$'
endif


last_timeout		dw	?
copy_timeout		dw	?
copy_timeout_counter	dw	?
copy_timeout_value	dw	?
get_speed_from_phy	dw	?

cnvrt_to_phys_add	dw	?	; Address of subroutine to convert to physical add
	even
virtual_mem_struct:
		dd      0		;- 0 Region Size
		dd		0		;- 4 Region Offset
		dw		0		;- 8 Region Segment
		dw		0		;- A Buffer ID
		dw		0		;- C Low Physical Address
		dw		0		;- E High Physical Address
	
slot_no		dw	16,0		; slot # specified on the command line

pci_bus_dev_no	dw	?			; Storage for PCI bus / device number
vendorid	dw	?			; Storage for vendor id of the used pci device
deviceid	dw	?			; Storage for device id of the used pci device
connector		db	?

temp_connector	dw	AUTO_CONNECTOR
user_speed		dw	0
user_duplex		dw	0
speed			dw	FAST_100
duplex			dw	HALF_DUPLEX
forced_speed_duplex	db	0

media_strings	label	byte
	db	"AUTO",0
	dw	 AUTO_CONNECTOR
	db	"UTP",0
	dw	 TPE_CONNECTOR
	db	"BNC",0
	dw	 BNC_CONNECTOR
	db	"AUI",0
	dw	 AUI_CONNECTOR 
	db	0

speed_strings	label	byte
	db	"SLOW",0
	dw	SPEED_SLOW
	db	"FAST",0
	dw	SPEED_FAST
	db	"HALF",0
	dw	DUPLEX_HALF
	db	"FULL",0
	dw	DUPLEX_FULL
	db	0

	ALIGN	16
self_test_buff	dd	0, -1		; Results of the self-test test placed here

	ALIGN	16
temp_buffer	db	80 dup (0)		; TX buffer for media detect

if	CHIP EQ INTEL_82596
	ALIGN	16
scp_buff	db	size SCP_STRUC dup (0)
	ALIGN	16
iscp_buff	db	size ISCP_STRUC dup (0)
else
got_mii_phy		db	NOT MII_PHY
checksum	dw	0
address_bitmask	dw	0
EEPROM_MAX	equ	100h
eeprom_buff	dw	EEPROM_MAX DUP (0)
phy_layer_chip	dw	offset cgroup:phy_dev_code_0
		dw	offset cgroup:phy_dev_code_1
		dw	offset cgroup:phy_dev_code_2
		dw	offset cgroup:phy_dev_code_3
		dw	offset cgroup:phy_dev_code_4
		dw	offset cgroup:phy_dev_code_5
		dw	offset cgroup:phy_dev_code_6
		dw	offset cgroup:phy_dev_code_7
		dw	offset cgroup:phy_dev_code_8
		dw	offset cgroup:phy_dev_code_9
		dw	offset cgroup:phy_dev_code_10
		dw	offset cgroup:phy_dev_code_11
unknown_plc	dw	offset cgroup:phy_dev_code_X

supported_plc	dw	SUPPORTED 				; Table of support PHY devices
		dw	SUPPORTED
		dw	NOT_SUPPORTED
		dw	NOT_SUPPORTED
		dw	SUPPORTED
		dw	NOT_SUPPORTED
		dw	SUPPORTED
		dw	SUPPORTED
		dw	SUPPORTED
		dw	SUPPORTED
		dw	SUPPORTED
		dw	SUPPORTED
		dw	NOT_SUPPORTED

setup_routines	dw	offset cgroup:no_setup_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:setup_83840_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:setup_82555_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:setup_83840_routine
		dw	offset cgroup:no_setup_routine
		dw	offset cgroup:no_setup_routine

speed_duplex_msg	dw	offset cgroup:def_10_half_msg
			dw	offset cgroup:def_10_full_msg
			dw	offset cgroup:def_100_half_msg
			dw	offset cgroup:def_100_full_msg
			dw	offset cgroup:frcd_10_half_msg
			dw	offset cgroup:frcd_10_full_msg
			dw	offset cgroup:frcd_100_half_msg
			dw	offset cgroup:frcd_100_full_msg
endif

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
	mov		di, offset cgroup:slot_no
	call	get_number
parse_args_again:
	call	skip_blanks
	cmp		al, CR			; Does an Ethernet address follow?
	je		parse_args_done	; No.

;upcase the string
	push	si
parse_args_0:
	mov		al,[si]
	call	to_upper
	mov		[si],al
	inc		si
	cmp		al, CR
	jne		parse_args_0
	pop		si

;is it a media string?
	mov		di, offset cgroup:media_strings
	call	lookup_string
	jc		parse_args_1
	mov		temp_connector, bx
	jmp		parse_args_again

;is it a line speed string?
parse_args_1:
	mov		di, offset cgroup:speed_strings
	call	lookup_string
	jc		parse_args_2
	cmp		bx, SPEED_SLOW
	jne		not_speed_slow
	mov		user_speed, SLOW_10
	jmp		parse_args_again
not_speed_slow:
	cmp		bx, SPEED_FAST
	jne		not_speed_fast
	mov		user_speed, FAST_100
	jmp		parse_args_again
not_speed_fast:
	cmp		bx, DUPLEX_HALF
	jne		not_duplex_half
	mov		user_duplex, HALF_DUPLEX
	jmp		parse_args_again
not_duplex_half:
	cmp		bx, DUPLEX_FULL
	jne		parse_args_again
	mov		user_duplex, FULL_DUPLEX
	jmp		parse_args_again

parse_args_2:
	mov		dx, offset cgroup:bad_key_msg
	mov		ah,9
	int		21h
	int		20h

parse_args_done:
	clc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov		di, offset cgroup:int_no
	mov		dx, offset cgroup:int_no_name
	call	print_number
	mov		di, offset cgroup:base_addr
	mov		dx, offset cgroup:base_addr_name
	call	print_number
	ret

	public	etopen
etopen:
; Initialize the driver.
; Fill in rom_address with the assigned address of the board.
	assume	ds:code
	cmp		is_pci, 1
	je		have_pci_bus
	mov 	dx, offset cgroup:need_pci_msg	; A PCI bus is required
	stc
	ret

have_pci_bus:
	.386					; Must have >= 386
	call	check_virtual_mem_services
	call	etopen_chip
	jc		short exit_etopen
	mov		al, int_no		; Get board's interrupt vector
	add		al, 8
	cmp		al, 8+8			; Is it a slave 8259 interrupt?
	jb		short set_int_num		; No.
	add		al, 70h - 8 - 8	; Map it to the real interrupt.
set_int_num:
	xor		ah, ah			; Clear high byte
	mov		int_num, ax		; Set parameter_list int num.
	call	setup_receive	; Setup receive buffers & start reception
	call	set_recv_isr
	call	enable_board_int
	clc
exit_etopen:
	ret


check_virtual_mem_services	PROC	NEAR
	; Check to see if virtual DMA service is being provided.
	; Bit 5 of the Bios Flags at 40:7Bh is set if virtual services present
	; Sets the appropriate routine to use for conversion to physical addresses
    mov     ax, 40h
	mov		es, ax
	test	BYTE PTR es:[007bh], 20h
	jz		short no_virtual_services_found
	print 	virtual_services	; Announce virtual DMA services present
	mov		cnvrt_to_phys_add, offset cgroup:virtual_address_convert
	jmp		short exit_check_virtual_mem_services
no_virtual_services_found:
	print 	no_virtual_services	; Announce no virtual DMA services
	mov		cnvrt_to_phys_add, offset cgroup:linear_address_convert
exit_check_virtual_mem_services:
	ret
check_virtual_mem_services	ENDP


linear_address_convert	PROC	NEAR
	; Address to be converted is in es:si
	; Converted physical address is returned in eax
	xor		eax, eax
	mov		ax, es
	shl		eax, 4
	movzx	esi, si			; Make certain that top part of SI is clear
	add		eax, esi
	ret
linear_address_convert	ENDP

virtual_address_convert	PROC	NEAR
	mov     di, offset cgroup:virtual_mem_struct
	; Lock the memory,
	; which in turn returns the physical address in the DMA descriptor
	mov     word ptr [di], 200h
	mov     word ptr [di+2], 0
	mov     word ptr [di+4], si
	mov     word ptr [di+6], 0
	mov     [di+8], es

    mov     ax, 8103h		; Lock DMA region
    mov     dx, 0ch			; No alloc, no remap
    push    ds
    pop     es
    int     4Bh
	jc		short exit_virtual_address_convert

							; Now unlock the DMA region
    mov     ax, 8104h		; Unlock DMA region
    mov     dx, 0			; No copy
    int     4Bh
no_unlock:
    mov     eax, [di+0ch]
	clc
exit_virtual_address_convert:
	ret
virtual_address_convert	ENDP

etopen_chip	PROC	NEAR
	call	find_base			; Go and find the chip
	jc		short exit_etopen_chip
	call	reset_chip
	call	test_chip
	jc		short exit_etopen_chip
if	CHIP EQ INTEL_82557
	; test_chip clears the interrupt mask bit that is set in reset_chip
	call	disable_board_int	; Mask the board interrupts
	print	reading_eeprom_chksum
	call	dump_eeprom			; Copy eeprom contents to RAM

	cmp		checksum, CHKSUM_VAL	; Does it sum to correct signature?
	je		short chksum_ok

	print	eeprom_chksum_bad
	stc						; set flag for chksum bad
	jmp		short exit_etopen_chip
chksum_ok:
	print	self_test_ok_msg
; Copy over the ethernet address
	mov		ax, ds				; ES needs to be correct
	mov		es, ax
	mov		cx, EADDR_LEN/2		; Number of word to move/byte swap
	mov		si, offset cgroup:eeprom_buff
	mov		di, offset cgroup:rom_address	; Where to write ethernet address
	rep		movsw

	call	get_connector_info	; Get info about media
	jc		short exit_etopen_chip
else
	call	init_plx_chip		; Initialize the pci interface chip
    call    init_scp			; Initialize the SCP, ISCP, SCB
	jc		short exit_etopen_chip
scp_int_ok:
	call	read_ia_pci			; Get Ethernet address from PCI Config space
	jc		short exit_etopen_chip
endif

	call	setup_cmd_buffs		; Setup buffer for commands
	call	config_chip			; Configure chip
	jc		short exit_etopen_chip_1
	call	do_select_media
exit_etopen_chip_1:
	ret
configure:
	call	setup_cmd_buffs		; Setup buffer for commands
	call	config_chip			; Configure chip
	jc		short exit_etopen_chip
	call	do_select_media
exit_etopen_chip:
	ret
etopen_failed:
	stc							; Give up.
	ret
etopen_chip	ENDP

test_chip	PROC	NEAR
	print	self_test_msg			; Announce the start of the self test
	mov		ax, cs
	mov		es, ax
	mov		si, offset cgroup:self_test_buff
	call	cnvrt_to_phys_add
	jnc		short cnvrt_ok
	print	problem_in_phys_add
	stc
	jmp		short exit_test_chip
cnvrt_ok:
	or		al, SELF_TEST_CMD
if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_PORT_OFFSET
else
	LOAD_PORT	PORT
endif
	out		dx, eax
	STALL							; Hold things up - briefly
	mov		ax, 1					; Wait, if necessary, for about 27 mili-
	call	set_timeout				;    seconds (5 should be enough)
check_test_buff:
	cmp		self_test_buff, 0h	; Test both DWORDS in the buffer
	je		short not_passed		; Need to pass both tests
	cmp		self_test_buff+4, 0h
	jne		short not_passed
	print	self_test_ok_msg
	; 82557 self test resets the chip, need time to recover - 48h too small
	mov		ax, 50h					
	call	wait
	clc
	jmp		short exit_test_chip
not_passed:
	call	do_timeout				; Any more time left ?
	jnz		check_test_buff			; Continue to wait if so
	mov	dx,offset self_test_no_msg		; No - announce failure
	stc
exit_test_chip:
	ret
test_chip	ENDP

if	CHIP EQ INTEL_82557
disable_chip_int	PROC NEAR
	LOAD_PORT	SCB_CMD
	mov		ax, MASK_INT_BIT
	out		dx, ax
	ret
disable_chip_int	ENDP

endif

if	CHIP EQ INTEL_82557

one_mil	EQU	02387

;	readtickcounter
;
;	Read the 16 bit timer tick count register (system board timer 0).
;	The count register decrements by 2 (even numbers) every 838ns.
;
;	Assumes:	Interrupts disabled
;
;	Returns:	AX with the current count
;			Interrupts disabled

readtickcounter:
	xor	al, al			;Command 8254 timer to latch
	out	43h, al			; T0's current count

	in	al, 40h			;read the latched count
	mov	ah, al			; LSB first
	in	al, 40h			; MSB next
	xchg	al, ah			;put count in proper order
	ret


eeprom_delay_1ms:
	push	ax
	push	cx
	call	readtickcounter
	mov	cx, ax
eeprom_delay_1ms_1:
	call	readtickcounter
	neg	ax
	add	ax, cx
	cmp	ax, one_mil
	jb	eeprom_delay_1ms_1
	pop	cx
	pop	ax
	ret

write_eeprom_bit:
	out	dx, al
	call	eeprom_delay_1ms	; wait for the clock to rise
 	or	al, EESK		; Set the eeprom strobe
	out	dx,	al		; Write rising edge of strobe to eeprom
	and	al, NOT EESK		; Clear the eeprom strobe
	out	dx,	al		; Write falling edge of strobe to eeprom
	ret

read_eeprom_bit:
	mov	al, EECS OR EESK
	out	dx, al			; Write rising edge of strobe to eeprom
	call	eeprom_delay_1ms	; wait for the clock to rise
	in	al, dx			; Get the data bit
	mov	bl, al			; Place the result in bl
	mov	al, EECS		; Clear the eeprom strobe
	out	dx, al			; Write falling edge of strobe to eeprom
	ret

;output the READ opcode
write_read_opcode:
	mov	al, EEDI OR EECS	; Set a 1 in the data bit
	call	write_eeprom_bit	; Write a 1
	call	write_eeprom_bit	; Write a 1
	mov	al, EECS		; Set a 0 in the data bit
	call	write_eeprom_bit	; Write a 1
	ret

dump_eeprom	PROC	NEAR
	push	bx
	push	cx
	push	di

	xor	bx, bx			; Offset into eeprom for start of address
	mov	di, offset cgroup:eeprom_buff; Where to write the data
					; Called with :
					; bx = starting offset address in the EEPROM
					; cx = number of bytes to read
					; ds:di = buffer to place the data
					; si is use for temporary storage

	LOAD_PORT	EEPROM_REG	; Set the eeprom port

; now read location zero by clocking out bits until the eeprom reads.
	call	write_read_opcode
	mov	cx,1
get_eeprom_size:
	mov	al, EEDO OR EECS	; set DO to see when eeprom writes a zero
	call	write_eeprom_bit
	shl	cx,1
	in	al,dx
	test	al,EEDO			; when we clock in a zero, the eeprom
	jz	short get_eeprom_size_1	; has gotten it's whole address.
	cmp	cx,EEPROM_MAX
	jb	get_eeprom_size
get_eeprom_size_1:
	mov	address_bitmask,cx
	mov	al, 0			; Disable the EEPROM
	out	dx, al			; Perform the operation

	xor	bx,bx			; start with word zero.
get_next_eeprom_word:
	push	cx			; Number of words left to read
	push	bx			; Address of next word in eeprom

	call	write_read_opcode
	mov	cx, address_bitmask	; Number of bits in each address
next_add_bit:
	shr	cx,1
	mov	al, EECS		; get the chip select bit
	test	bl,cl
	je	short next_add_bit_1
	or	al,EEDI			; if the bit was a one, bring it in.
next_add_bit_1:
	call	write_eeprom_bit	; Write the address bit
	cmp	cx,1
	jne	next_add_bit		; Write out all bits

eeprom_address_done:			; Now ready to read the EEPROM data
	xor	si, si			; Byte will be assembled in si
	mov	cx, 10h			; Number of bits to fetch
get_next_bit:
	call	read_eeprom_bit		; Value of eeprom bit returned in bl
	and	bx, EEDO		; Clear all but the eeprom data output bit
	or	si, bx			; Add the bit to the assembled byte
	rol	si, 1			; Advance byte ready for next bit
	loop	get_next_bit		; Continue until all 16 bits have been read

	mov	cl, 4h			; Final rotate for SI gets the word aligned
	ror	si, cl			;  correctly

	mov	[di], si		; Store the word
  if 0
	mov	ax,si
	call	wordout
	mov	al,' '
	call	chrout
  endif
	add	checksum, si		; add it into the checksum.
	add	di, 2			; Advance the buffer pointer

	pop	bx			; Next EEPROM address to read from
	inc	bx
	pop	cx			; Remaining bytes to read
 	mov	al, 0			; Disable the EEPROM
	out	dx, al			; Perform the operation
	loop	get_next_eeprom_word

	; Now check if the eeprom buffer contains only 0xFFFF (expect MAC address and checksum).
	; In that case, make the checksum invalid.
	; This has to be done, because the Intel EEPROM tool will NOT program the eeprom expect
	; the MAC address and checksum when the eeprom file is write protected.
	; But as long as the checksum is valid, the chip functions will in most cases not work
	; cause they have wrong informations taken from the eeprom.

	cmp	checksum, CHKSUM_VAL
	jne	short check_all_ff_done	; special handling not neccessary if checksum is already invalid

	mov	cx, address_bitmask
	sub	cx, 3+1			; 3 for the MAC address and 1 for the checksum
	jc	short check_all_ff_done	; skip function if cx was too low
	mov	di, offset cgroup:eeprom_buff
	add	di, 3*2			; skip the MAC address
check_all_ff_loop:
	mov	ax, [di]
	cmp	ax, 0FFFFh
	jne	short check_all_ff_done
	add	di, 2
	loop	check_all_ff_loop

ifdef SPECIAL_FFFF_HANDLING_82559ER
	;
	; Fill the buffer with valid values for the 82559ER.
	; This can be done, because the 82559ER has the PHY device built-in and all the
	; values describing the PHY device are known.
	;

	; check if it is a 82559ER
	mov	ax, vendorid
	cmp	ax, 8086h
	jne	short make_checksum_bad		; not a intel part
	mov	ax, deviceid
	cmp	ax, 1209h			; 1209h=82559ER
	jne	short make_checksum_bad		; not the 82559ER

	;
	; now, store valid values for words 3, 5-7
	;
	mov	di, offset cgroup:eeprom_buff

	mov	ax, 0203h			; xx03h:10MB + 100MB
	mov	[di+3*2], ax

	mov	ax, 0201h			; xx01h: connectors=RJ-45
	mov	[di+5*2], ax

	mov	ax, 4701h			; PHY1=82555
	mov	[di+6*2], ax

	mov	ax, 0000h			; PHY2=none
	mov	[di+7*2], ax

	jmp	short check_all_ff_done
endif

make_checksum_bad:
	; make the checksum invalid, cause eeprom is partially unprogrammed
	mov	ax, CHKSUM_VAL
	not	ax
	mov	checksum, ax		; make the checksum invalid

check_all_ff_done:

	pop		di
	pop		cx
	pop		bx
	ret
dump_eeprom	ENDP

get_connector_info	PROC	NEAR
	cmp		WORD PTR eeprom_buff[PHY_DEV_REC_2], 0FFFFh
	jne	short get_connector_info_1
	; the EEPROM may have non-set words equal to all zeroes or all ones.
	mov		WORD PTR eeprom_buff[PHY_DEV_REC_2], 0
get_connector_info_1:

	mov		cx,	eeprom_buff[COMPATIBILITY]
	and		cx,  MC_100_OK + MC_10_OK
	mov		multicast_fix, cx
	jne		short no_fix_required
	print	fix_root_msg
	or		cx, cx
	jne		short not_fix_both
	print	fix_both
	jmp		short no_fix_required
not_fix_both:
	test	cx, MC_10_OK
	jne		short not_fix_10
	print	fix_10bits
not_fix_10:
	test	cx, MC_100_OK
	jne		short no_fix_required
	print	fix_100bits
no_fix_required:

; Prefer to use a 100Mbps phy.
	cmp		WORD PTR eeprom_buff[PHY_DEV_REC_1], 0000h
	je		short no_ph1_device
	test	eeprom_buff[PHY_DEV_REC_1], TEN_MB_ONLY
	je		short support_100

no_ph1_device:
; If they're both 10, go for it.
	cmp		WORD PTR eeprom_buff[PHY_DEV_REC_2], 0000h
	je		short support_10
; if phy2 is 100, use it.
	test	eeprom_buff[PHY_DEV_REC_2], TEN_MB_ONLY
	je		short support_100

support_10:
	mov		speed, SLOW_10
	mov		duplex, HALF_DUPLEX
	print	support_10_msg
	jmp		short done_support

support_100:
	mov		temp_connector, TPE_CONNECTOR	; Must have TP connector
	mov		got_mii_phy, MII_PHY
	print	support_100_msg
	jmp		short done_support

done_support:
	print	phys_1_msg
	mov		bx, eeprom_buff[PHY_DEV_REC_1]
	and		bx, PHY_DEV_BITS
	xchg	bl, bh
	shl		bx, 01h							; Convert to a word count
	cmp		bx, offset cgroup:unknown_plc-offset cgroup:phy_layer_chip
	jb 	short phy_dev_1_ok
	mov		bx, offset cgroup:unknown_plc-offset cgroup:phy_layer_chip
phy_dev_1_ok:
	mov		dx, phy_layer_chip[bx]
	print_it
	mov		si, 0001h						; Setup physical address in si
	call	setup_routines[bx]
	mov		cx, supported_plc[bx]

	print	phys_2_msg
	mov		bx, eeprom_buff[PHY_DEV_REC_2]
	and		bx, PHY_DEV_BITS
	xchg	bl, bh
	shl		bx, 01h							; Convert to a word count
	cmp		bx, offset cgroup:unknown_plc-offset cgroup:phy_layer_chip
	jb 	short phy_dev_2_ok
	mov		bx, offset cgroup:unknown_plc-offset cgroup:phy_layer_chip
phy_dev_2_ok:
	mov		dx, phy_layer_chip[bx]
	print_it
	or		cx, supported_plc[bx]
	cmp		cx, SUPPORTED
	je		short phy_layer_supported
	or		bx, bx
	je		short one_phy_dev
	mov		dx,offset cgroup:no_support_2_phy
	jmp		short error_get_connector_info
one_phy_dev:
	mov		dx, offset cgroup:no_support_p_layer
	jmp		short error_get_connector_info

phy_layer_supported:
	cmp		duplex, HALF_DUPLEX
	je		short configed_for_half
	mov		config_duplex, FDX_PIN_ENBL + FORCE_FDX

configed_for_half:
	cmp		got_mii_phy, MII_PHY
	jne		short configed_for_503
	mov		config_mii_mode, MII_MODE
	and		config_cdt, NOT CRS_CDT		; Clear CDT for MII interface

configed_for_503:
	cmp		forced_speed_duplex, 0		; Check if forced parameters used
	je		short phy_control_reg_ok
	xor		bx, bx						; Clear negotiation bit
	cmp		speed, FAST_100
	jne		short not_fast
	or		bx, PHY_CTRL_REG_FAST
not_fast:
	cmp		duplex, FULL_DUPLEX
	jne		short not_full
	or		bx, PHY_CTRL_REG_FULL
not_full:
	mov	dx,PHY_CONTROL_REG
	call	write_phy_reg	
phy_control_reg_ok:
	clc
	jmp		short exit_get_connector_info
error_get_connector_info:
	stc
exit_get_connector_info:
	ret
get_connector_info	ENDP

write_phy_reg:
; enter with bx = new register contents, dx = register number,
;  si = phy number.
;   preserves si.
	mov		ax, si		; Get the physical address
	shl		ax, 5h		; Move to the correct position
	or		ax, dx
	or		ax, PHY_WRITE_OPCODE
	shl		eax, 10h
	mov		ax, bx
	load_port	MDI_CTRL_REG
	out		dx, eax
	STALL
	mov		ax, 1		; Wait, if necessary, for about 27ms
	call	set_timeout
write_phy_reg_1:
	in		eax, dx		; Get status of MDI command
	in		eax, dx		; Get status of MDI command
	test	eax, PHY_READY_BIT	; jump when ready
	jne		short write_phy_reg_2
	call	do_timeout		; loop until ready
	jnz		write_phy_reg_1
	stc
write_phy_reg_2:
	ret

read_phy_reg:
; enter with bx = register number, si = phy number.
; exit with ax = register value, nc, or cy if we timed out waiting for it.
;   preserves bx, si.
 	mov		ax, si		; Get the physical address
	shl		ax, 5h		; Move to the correct position
	or		ax, bx
	or		ax, PHY_READ_OPCODE
	shl		eax, 10h
	load_port	MDI_CTRL_REG
	out		dx, eax
	STALL
	mov		ax, 1		; Wait, if necessary, for about 27ms
	call	set_timeout
read_phy_reg_2:
	in		eax, dx			; Get status of MDI command
	in		eax, dx			; Get status of MDI command
	test	eax, PHY_READY_BIT		; Non-zero when ready
	jne		short read_phy_reg_3	; Jump if so
	call	do_timeout			; Any more time left ?
	jnz		read_phy_reg_2		; Continue to wait if so
	stc
read_phy_reg_3:
	ret

else
; Routines for the 82596
init_plx_chip	PROC	NEAR
;- Program UserPins 0-3 in Write Mode. RCVDIS should default to 1.
	LOAD_PORT	PLXP_USER_PINS
	mov     al, 0F0h
	or      al, BIT_2
	out     dx, al

	LOAD_PORT	PLXP_LAN_CONTROL
    in      ax, dx
    or      ax, SOFTWARE_RESET_BIT
    out     dx, ax
    and     ax, NOT SOFTWARE_RESET_BIT
    STALL
    STALL
    out     dx, ax
    STALL
    STALL

;- Enable LAN 0 interrupt and set it to LATCHED mode
	LOAD_PORT	PLXP_INTERRUPT_CONTROL
    in      ax, dx
    or      ax, LAN_0_INTERRUPT_ENABLE
    or      ax, LATCHED_INTWRITE_BIT
    out     dx, ax
    STALL
    STALL

;- Delay 100msec after PLX reset.
	mov		ax,0004h
	call	wait
    ret
init_plx_chip	ENDP


init_scp	PROC	NEAR
; Performs the alternate SCP and ISCP initialization for the 82596
	mov		ax, cs						; Set Up the Alternate SCP Address
	mov		es, ax
	mov		si, offset cgroup:scp_buff
	call	cnvrt_to_phys_add
	jc		error_init_scp
    or      al, ALT_SCP_CMD
	LOAD_PORT	PLXP_PORT_OFFSET
	out		dx, eax
	STALL							; Hold things up - briefly
	mov		ax, 2
	call	wait					; Hold things up for 50ms

; Initialize the SYSBUS byte in System Configuration Pointer (SCP)
; Internal Triggering Of Timers, Active High Edge-Triggered Interrupt
	mov		ax, SYSBUS_CSW OR SYSBUS_LOCK_DIS OR SYSBUS_32_MODE OR SYSBUS_BIT_0
	mov     scp_buff.scp_sysbus, ax
	mov		si, offset cgroup:iscp_buff
	call	cnvrt_to_phys_add
	jc		error_init_scp

    mov     scp_buff.scp_iscp_add, eax
	mov		iscp_buff.iscp_busy, ISCP_BUSY_MARK
    mov     si, 0
	call	cnvrt_to_phys_add
	jc		short error_init_scp

    lea     si, scb_buff
    mov     iscp_buff.iscp_scb_offset, si
    mov     iscp_buff.iscp_scb_lo_add, ax
    shr     eax, 16
    mov     iscp_buff.iscp_scb_hi_add, ax
    mov     scb_buff.scb_status, 0h
    C_ATTENTION						; Issue a channel attention to the 82596

	mov		ax, 1					; Wait, if necessary, for about 27 mili-
	call	set_timeout				;    seconds (10 should be enough)
iscp_busy_wait:
	test	iscp_buff.iscp_busy, ISCP_BUSY_MARK
	jz		short iscp_success
	call	do_timeout				; Any more time left ?
	jnz		short iscp_busy_wait	; Continue to wait if so
	jmp		short iscb_problem

iscp_success:
	mov		ax, scb_buff.scb_status		;- Acknowledge any interrupts
	and		ax, SCB_STATUS_MASK
	mov		scb_buff.scb_command, ax
    C_ATTENTION						; Issue a channel attention to the 82596
	mov		ax, 1					; Minimum time out value
	call	wait_scb_non_active
	jc		short iscb_problem

    mov     ax, DEFAULT_T_OFF		; Load the Bus Throttle values.
    mov     scb_buff.scb_off_timer, ax
    mov     ax, DEFAULT_T_ON
    mov     scb_buff.scb_on_timer, ax
    mov     scb_buff.scb_command, CU_LD_B_T_R
    C_ATTENTION						; Issue a channel attention to the 82596
	mov		ax, 1					; Minimum time out value
	call	wait_scb_non_active
	jnc		short exit_init_scp
iscb_problem:
	print	iscp_init_problem		; Inform the user
	stc

exit_init_scp:
    ret
error_init_scp:
	print	problem_in_phys_add
error_init_iscp:
	stc
	jmp		short	exit_init_scp

init_scp	ENDP


read_ia_pci	PROC	NEAR
	; For the 82596 the Ethernet address is obtained from PCI configuration
	mov		ah, PCI_FUNCTION_ID		; Get IO base
	mov		al, READ_PCI_CONFIG_DWORD
	mov		bx, pci_bus_dev_no		; Recover the bus / device number
    mov     di, PLXP_NODE_ADDR_REGISTER
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
	jne		short error_read_ia_pci
	mov		DWORD PTR rom_address, ecx
	mov		ah, PCI_FUNCTION_ID		; Get IO base
	mov		al, READ_PCI_CONFIG_WORD
    add     di, 4					; Advance to the next 4 bytes
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
	jne		short error_read_ia_pci
	mov		WORD PTR rom_address+4, cx
	clc
exit_read_ia_pci:
	ret
error_read_ia_pci:
	stc
	jmp		short exit_read_ia_pci
read_ia_pci	ENDP

endif

setup_cmd_buffs	PROC	NEAR
; Setup buffer for commands
	mov		word ptr cmd_buff1, C_DONE_BIT	; Mark buffer as available
	mov		word ptr cmd_buff2, C_DONE_BIT	; Mark buffer as available
	mov		buff_ptrs[0], offset cgroup:cmd_buff1	; Settup buffer 'array'
	mov		buff_ptrs[2], offset cgroup:cmd_buff2
	mov		tx_buff_no, 0					; Set next buffer # to use
	ret
setup_cmd_buffs	ENDP

setup_receive	PROC	NEAR
	mov		cx, RBD_COUNT 			; Setup the receive buffer descriptors
	mov		ax, cs
	mov		es, ax
	mov		si, offset cgroup:start_rx_buff
	mov		bx, si					; Bx holds a copy of the virtual offset
	call	cnvrt_to_phys_add
	mov		esi, eax
	mov		di, offset cgroup:start_rbd
	mov		first_rbd, di
	mov		ax, di
next_rbd:
	mov		[di].rbd_status, 0
	add		ax, size rbd_struct				; Pointer to the next RBD
if	CHIP EQ INTEL_82596
	mov		[di].rbd_link, ax
else
	movzx	eax, ax
	mov		[di].rbd_link, eax
	mov		[di].rbd_filler2, 0
endif
	mov		[di].rbd_ptr, esi				; Store physical address
	mov		[di].rbd_size, SIZE_ONE_DATA_BUFF
	mov		[di].rbd_filler1, 0
	mov		[di].rbd_voffset, bx			; Store the virtual offset
	add		esi, SIZE_ONE_DATA_BUFF			; Physical address of next buffer
	add		bx, SIZE_ONE_DATA_BUFF			; Virtual offset of next buffer
	mov		di, ax							; Advance to the next RBD
	loop	next_rbd

	sub		di, size rbd_struct				; Return to previous RBD
	mov		last_rbd, di
	or		[di].rbd_size, EL_BIT			; Mark end of chain
	mov		[di].rbd_link, offset cgroup:start_rbd

	mov		cx, RFD_COUNT 				; Setup the receive buffer descriptors
	mov		di, offset cgroup:start_rfd
	mov		first_rfd, di
	mov		ax, di
next_rfd:
	mov		[di].rfd_status, 0
	mov		[di].rfd_eol, FLEXIBLE_MODE
	add		ax, size rfd_struct		 		; Pointer to the next RFD
if	CHIP EQ INTEL_82596
	mov		[di].rfd_link, ax
else
	movzx	eax, ax
	mov		[di].rfd_link, eax
endif
	mov		[di].rfd_ptr, -1
	mov		[di].rfd_cnt, 0
	mov		[di].rfd_size, 0
	mov		di, ax							; Advance to the next RFD
	loop	next_rfd

	sub		di, size rfd_struct				; Get back to last RFD
	mov		last_rfd, di
	mov		[di].rfd_eol, EL_BIT+FLEXIBLE_MODE	; Mark end of chain
if	CHIP EQ INTEL_82596
	mov		[di].rfd_link, offset cgroup:start_rfd	; Wrap around to start
else
	mov		ax, offset cgroup:start_rfd	; Wrap around to start
	movzx	eax, ax
	mov		[di].rfd_link, eax
endif

							; Setup the start rdf to point to the start rbd
	mov		[start_rfd].rfd_ptr, offset cgroup:start_rbd	

	WAIT_CMD_ACCEPTED 					; Wait for acceptance of last command
if	CHIP EQ INTEL_82596
	mov		scb_buff.scb_rfa_add, offset cgroup:start_rfd
	mov		scb_buff.scb_command, RU_START
	C_ATTENTION
else
	LOAD_PORT	SCB_GEN_PTR
	mov		ax, offset cgroup:start_rfd
	movzx	eax, ax
	out		dx, eax					; Issue the address - upper word is low
	add		dx, SCB_CMD - SCB_GEN_PTR	; Get back to cmd port
	mov		al, RU_START
	out		dx, al					; Issue the command
endif
	ret
setup_receive	ENDP

config_chip	PROC	NEAR
if	CHIP EQ INTEL_82557
	call	load_base_regs
	mov		dx, offset cgroup:load_base_msg
	jc		short exit_config_chip		; Exit if there is a problem
endif

	call	do_config
	mov		dx, offset cgroup:config_msg
	jc		short exit_config_chip	; Exit if there is a problem

	mov		ax, 8					; Wait for the command
	call	wait
; Set the Individual address registers with the Ethernet address
	mov		si, offset cgroup:rom_address
	call	set_ether
;	mov		dx, offset cgroup:ether_add_msg
	jc		short exit_config_chip	; Exit if there is a problem
	clc
exit_config_chip:
	ret
config_chip	ENDP

if	CHIP EQ INTEL_82557
load_base_regs	PROC	NEAR
	WAIT_CMD_ACCEPTED 				; Wait for acceptance of last command
	LOAD_PORT	SCB_GEN_PTR			; Load port address for SCB general pointer
	xor		eax, eax
	mov		ax, cs
	shl		eax, 4
	out		dx, eax					; Load the port with the segment address
	LOAD_PORT	SCB_CMD				; Load port address for SCB command
	mov		al, CU_LD_BASE			; Command to set the CU base register
	out		dx, al					; Issue the command

	WAIT_CMD_ACCEPTED 				; Wait for acceptance of last command
	LOAD_PORT	SCB_STATUS			; Load port address for SCB status
	mov		ax, 1					; Use minimum time-out in the wait routine
	call	wait_scb_non_active		; Can't issue a command if chip is active
	jc		short exit_load_base_regs	; Exit if there is a problem
	LOAD_PORT	SCB_GEN_PTR			; Load port address for SCB general pointer
	xor		eax, eax
	mov		ax, cs
	shl		eax, 4
	out		dx, eax					; Load the port with the segment address
	LOAD_PORT	SCB_CMD				; Load port address for SCB command
	mov		al, RU_LD_BASE			; Command to set the RU base register
	out		dx, al					; Issue the command
exit_load_base_regs:
	ret
load_base_regs	ENDP
endif

do_select_media	PROC NEAR
; First check to see if connector type has been specified
if	CHIP EQ INTEL_82557
	cmp		temp_connector, TPE_CONNECTOR	; Found 100Mbs capability
	clc
	je		short using_tpe					; Jump if so
	print	auto_detect_nr_msg
	jmp		short using_tpe
endif

	cmp		temp_connector, TPE_CONNECTOR
	je		short test_TPE
	cmp		temp_connector, BNC_CONNECTOR
	je		short test_BNC
	cmp		temp_connector, AUI_CONNECTOR
	je		short test_AUI

	print	using_auto_msg		; Auto detecting media
	call	setup_test_packet

test_AUI:						; Try the AUI connector first
	mov		connector, AUI
if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_USER_PINS
	in		al, dx
	or		al, PLXP_USER_1
	and		al, NOT PLXP_USER_0
	out		dx, al
else
; debug 82557 code required from Intel to select AUI connector
endif
	mov		ax,0016h	; Delay about 600 msec for front_end setup
	call	wait
	cmp     temp_connector, AUI_CONNECTOR
	je		short using_aui
	call	send_on_connector
	jc		short test_bnc
using_aui:
	mov		dx, offset cgroup:using_AUI_msg	; Setup message for AUI
	jmp		short announce_media

test_BNC:						; AUI failed, now try BNC
	mov		connector, BNC
if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_USER_PINS
	in		al, dx
	and		al, NOT PLXP_USER_0 AND NOT PLXP_USER_1
	out		dx, al
else
; debug 82557 code required from Intel to select BNC connector
endif
	mov		ax,0016h	; Delay about 600 msec for front_end setup
	call	wait
	cmp		temp_connector, BNC_CONNECTOR
	je		short using_bnc
	call	send_on_connector
	jc		short test_TPE
using_bnc:
	mov		dx, offset cgroup:using_10B_2_msg	; Setup message for BNC
	jmp		short announce_media

test_TPE:									; BNC failed, now try TPE
	mov		connector, TPE
if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_USER_PINS
	in		al, dx
	or		al, PLXP_USER_0 OR PLXP_USER_1
	out		dx, al
else
; debug 82557 code required from Intel to select TPE connector
endif
	mov		ax,0016h	; Delay about 600 msec for front_end setup
	call	wait
	cmp		temp_connector, TPE_CONNECTOR
	je		short using_tpe
	call	send_on_connector
	jc		short default_aui
using_tpe:
	mov		dx, offset cgroup:using_10B_T_msg	; Setup message for twisted pair
	jmp		short announce_media

default_aui:
	mov		connector, AUI 			; At this point all connectors have failed
if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_USER_PINS
	in		al, dx					; Use AUI as default connector
	or		al, PLXP_USER_1
	and		al, NOT PLXP_USER_0
	out		dx, al
else
; debug 82557 code required from Intel to select AUI connector
endif
	mov		dx, offset cgroup:using_AUI_msg	; Setup message for AUI

announce_media:
	print_it
    ret
do_select_media	ENDP

send_on_connector	PROC	NEAR
	mov		[di].tx_status, 0h
if	CHIP EQ INTEL_82596
	mov		scb_buff.scb_cbl_add, di
endif
	call	issue_cmd

	mov		ax, 1					; Wait, if necessary, for about 27 msec
	call	set_timeout
wait_for_send:
	mov		ax, [di].tx_status
	test	ax, CB_STATUS_COMPLETE
	jnz		short send_complete
	call	do_timeout				; Any more time left ?
	jnz		short wait_for_send		; Continue to wait if so

if	CHIP EQ INTEL_82596
	mov		scb_buff.scb_command, CU_ABORT	; Abort the command
	C_ATTENTION
else
; debug 82557 code required for an ABORT
endif
error_send_on_connector:
	stc								; Indicate failure
    ret

send_complete:
    mov     ax, [di].tx_status		; Check if status bits are ok
    test    ax, CB_STATUS_OK
    jz		short error_send_on_connector
if	CHIP EQ INTEL_82596
    test    ax, CB_TX_NO_CARRIER_SENSE	; Also need to check for carrier
    jnz     short error_send_on_connector
else
; debug 82557 code required from INTEL to check for carrier
endif
	clc								; Indicate success
	ret
send_on_connector	ENDP

setup_test_packet	PROC NEAR
	mov		cx, RUNT
	lea		di, temp_buffer		; Buffer to use for test packets
	push	di					; Save start address of buffer
	mov		eax, (EL_BIT + TRANSMIT)*10000h
	stosd						; Store the action command word + status word
if	CHIP EQ INTEL_82596
	mov		ax, -1				; Set the address of next command to NULL
	stosw						; Store the link address - next command
	stosw						; TBD offset is also null
else
	mov		eax, -1				; Set the address of next command to NULL
	stosd						; Store the link address - next command
	stosd						; TBD offset is also null
endif
	mov		ax, RUNT OR TX_EOF_BIT	; Set length of data
	stosw
if	CHIP EQ INTEL_82596
	xor		ax, ax
else
	mov		ax, TX_THRESHOLD	; Set TX threshold
endif
	stosw
	mov		si, offset cgroup:rom_address	; Set destination address as us
	movsd
	movsw
	mov		si, offset cgroup:rom_address
	movsd
	movsw
    mov     ax, RUNT - EADDR_LEN*2 + 2 ; Set packet size (2 * address + size)
    stosw
	pop		di						; Recover start address of buffer
    ret
setup_test_packet	ENDP

  if CHIP EQ INTEL_82557
no_setup_routine:
	ret

  if 0
dump_phy:
	mov	bx,0
dump_phy_1:
	call	read_phy_reg
	jnc	short dump_phy_2
	mov	al,'!'
	call	chrout
	jmp	short dump_phy_3
dump_phy_2:
	call	wordout
dump_phy_3:
	mov	al,' '
	call	chrout
	inc	bx
	cmp	bx,20h
	jb	dump_phy_1
	ret
  endif

get_speed_from_phy_82555:
	mov		bx,16	; Find speed of link
	call		read_phy_reg
	test	ax, 0002h			; Go if autoneg says 100.
	mov		speed, FAST_100					; Got a fast link
	jne		short get_speed_from_phy_82555_1
	mov		speed, SLOW_10					; Got a slow link
get_speed_from_phy_82555_1:
	ret

get_speed_from_phy_83840:
	mov		bx,25	; Find speed of link
	call		read_phy_reg
	test	ax, 0040h			; any fast link pulses?
	mov		speed, FAST_100		; Assume a fast link
	je		short get_speed_from_phy_83840_1	;go if so.
	mov		speed, SLOW_10		; Got a slow link
get_speed_from_phy_83840_1:
	ret


setup_82555_routine:
	mov	get_speed_from_phy, offset cgroup:get_speed_from_phy_82555
	jmp	short into_setup_routine
setup_83840_routine:
	mov	get_speed_from_phy, offset cgroup:get_speed_from_phy_83840
into_setup_routine:
	push	bx			
	mov		bx, PHY_CTRL_REG_FAST + PHY_CTRL_REG_AUTO_ENBL
	or		bx, PHY_CTRL_REG_RESTART_AUTO + PHY_CTRL_REG_FULL
	mov		bx, 8000h
	mov		dx,PHY_CONTROL_REG 		; Start negotiation
	call		write_phy_reg

	print	wait_neg_msg
	mov		ax, 100h						; Set wait for negotiation
	call	set_timeout
	mov		last_timeout, 100h
wait_neg_done:
	mov		ax, timeout 					; The READ_PHY_REG code uses the
	mov		copy_timeout, ax				; set_timeout code so these 3
	mov		ax, timeout_counter 			; values must be 'saved'
	mov		copy_timeout_counter, ax
	mov		ax, timeout_value
	mov		copy_timeout_value, ax
	mov		bx,PHY_STATUS_REG				; Check if negotiation completed
	call		read_phy_reg
	test	ax, PHY_STA_NWAY_COMPLETE		; Is it done ?
	jnz		short can_partner_neg			; Jump if so
	mov		ax, copy_timeout_counter 		; Restore the saved values from
	mov		timeout_counter, ax 			; the set_timeout call
	mov		ax, copy_timeout_value
	mov		timeout_value, ax
	mov		ax, copy_timeout
	mov		timeout, ax 
	cmp		last_timeout, ax				; Display an occasional '.' to
	je		short no_period					; inform user that driver is still
	mov		last_timeout, ax				; alive
	and		ax, 07h
	jne		short no_period
	mov		al, '.'
	call	chrout
no_period:
	call	do_timeout						; Any more time left ?
	jnz		short wait_neg_done				; Yes - check again
	print	negotiation_problem				; Announce problem
	jmp		short no_negotiation_bits		; Try to continue

can_partner_neg:
	call	crlf
	mov		bx,PHY_EXP_REG		; Check if partner can negotiate
	call		read_phy_reg
	test	ax, PHY_ANE_LP_AUTONEG
	jnz		short use_neg_results	; Yes - use results
	print	no_lp_msg						; Announce no negotiation
no_negotiation_bits:
	mov		forced_speed_duplex, 0			; Assume no forced parameters
	mov		duplex, HALF_DUPLEX				; Default = half duplex
	cmp		user_duplex, 0					; Has user specified duplex
	je 		short duplex_set				; Jump if not
	mov		forced_speed_duplex, 1			; Record a forced speed/duplex
	mov		ax, user_duplex					; Get user duplex
	mov		duplex, ax						; And store
duplex_set:
;	call	dump_phy
	call		get_speed_from_phy
	cmp		user_speed, 0					; Has user specified speed
	je 		short speed_set					; Jump if not
	mov		forced_speed_duplex, 1			; Record a forced speed/duplex
	mov		ax, user_speed					; Get user speed
	mov		speed, ax						; And store

speed_set:									; Decide what message to display
	xor		bx, bx
	cmp		forced_speed_duplex, 0			; Check if forced parameters used
	je		short no_forced_params
	mov		bx, 04h							; Forced => messages 4-7
no_forced_params:
	cmp		speed, FAST_100
	jne		short slow_speed
	add		bx, 02h
slow_speed:
	cmp		duplex, FULL_DUPLEX
	jne		short using_half_duplex
	inc		bx
using_half_duplex:
	sal		bx, 1							; Convert to a word count
	mov		dx, speed_duplex_msg[bx]
	jmp		done_83840_speed_duplex

use_neg_results:
	mov		bx,PHY_ADVERT_REG	; Read our capability
	call		read_phy_reg
	and		ax, LINK_ABILITY_BITS	; Ignore other bits
	mov		cx, ax							; Store for later

	mov		bx,PHY_LINK_PART_REG	; Read link partner's capability
	call		read_phy_reg
	and		ax, LINK_ABILITY_BITS	; Ignore other bits
	jnz		short get_common_capabilities	; Should have some bits set
	print	no_neg_bits_msg			; Announce problem
	jmp		no_negotiation_bits	; Try to continue

get_common_capabilities:
	and		ax, cx							; Get the common technology
	jnz		short get_highest_priority		; Should have some bits in common
	print	no_common_capability			; Announce problem
	jmp		no_negotiation_bits				; Try to continue

get_highest_priority:
	; Apply the priority resolution to the common technolgies
	test	ax, TX_FULL_BIT
	jnz		short tx_full
	test	ax, T4_HALF_BIT
	jnz		short t4_half
	test	ax, TX_HALF_BIT
	jnz		short tx_half
	test	ax, T_FULL_BIT
	jnz		short t_full

t_half:
	mov		speed, SLOW_10
	mov		duplex, HALF_DUPLEX
	mov		dx, offset cgroup:t_half_msg
	jmp		short done_83840_speed_duplex

tx_full:
	mov		speed, FAST_100
	mov		duplex, FULL_DUPLEX
	mov		dx, offset cgroup:tx_full_msg
	jmp		short done_83840_speed_duplex

t4_half:
	mov		speed, FAST_100
	mov		duplex, HALF_DUPLEX
	mov		dx, offset cgroup:t4_half_msg
	jmp		short done_83840_speed_duplex

tx_half:
	mov		speed, FAST_100
	mov		duplex, HALF_DUPLEX
	mov		dx, offset cgroup:tx_half_msg
	jmp		short done_83840_speed_duplex

t_full:
	mov		speed, SLOW_10
	mov		duplex, FULL_DUPLEX
	mov		dx, offset cgroup:t_full_msg

done_83840_speed_duplex:
	print_it								; Announce speed / duplex found

	mov		bx,NSC_CONG_CTRL_REG		; Apply neccessary fixes
	call		read_phy_reg
	mov		bx, ax
	or		bx, NSC_TX_CONG_F_CONNECT	; This bit always needs to be set
	cmp		duplex, HALF_DUPLEX
	je		short no_full_duplex_fix
	or		bx, NSC_TX_CONG_TXREADY	; Needs to be set for full duplex
no_full_duplex_fix:
	mov		dx,NSC_CONG_CTRL_REG	; Write the fix
	call		write_phy_reg

	pop		bx
	ret
  endif


	public	find_base
find_base	PROC	NEAR
	call	get_pci_info		; Go and search the card
	jc		short f_b_failed	; Jump if card not found

;get the command register.
	mov		ah, PCI_FUNCTION_ID		; Get IO base
	mov		al, READ_PCI_CONFIG_WORD
	mov		bx, pci_bus_dev_no		; Recover the bus / device number
	mov		di, COMMAND_REGISTER
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
	jne		short f_b_failed
;turn on bus master mode.
	or		cl, CMD_BUS_MASTER + CMD_IO_SPACE + CMD_MEMORY_SPACE
;write it back out again.
	mov		ah, PCI_FUNCTION_ID		; Get IO base
	mov		al, WRITE_PCI_CONFIG_WORD
	mov		di, 4h		;COMMAND_REGISTER
	int		PCI_BIOS_INTERRUPT

	ret
f_b_failed:
	mov		dx, offset cgroup:scan_failed	; Message to announce later
	stc							; Set carry and return
	ret
find_base	ENDP

get_pci_info	PROC	NEAR
	mov		si,slot_no
	sub		si,16+1		;specified as 16, we need to be -1.
try_next_index:
	inc		si		; Start out with index # = 0
 	mov		ah, PCI_FUNCTION_ID
	mov		al, FIND_PCI_DEVICE
	mov		cx, DEVICE_ID	; Look for particular device
	mov		dx, VENDOR_ID
	mov		deviceid, cx
	mov		vendorid, dx
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
  ifdef DEVICE_ID2
	je		short try_next_index_1
 	mov		ah, PCI_FUNCTION_ID
	mov		al, FIND_PCI_DEVICE
	mov		cx, DEVICE_ID2	; Look for particular device
	mov		dx, VENDOR_ID
	mov		deviceid, cx
	mov		vendorid, dx
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
try_next_index_1:
  endif
  ifdef DEVICE_ID3
	je		short try_next_index_2
 	mov		ah, PCI_FUNCTION_ID
	mov		al, FIND_PCI_DEVICE
	mov		cx, DEVICE_ID3	; Look for particular device
	mov		dx, VENDOR_ID
	mov		deviceid, cx
	mov		vendorid, dx
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
try_next_index_2:
  endif
  ifdef DEVICE_ID4
	je		short try_next_index_3
 	mov		ah, PCI_FUNCTION_ID
	mov		al, FIND_PCI_DEVICE
	mov		cx, DEVICE_ID4	; Look for particular device
	mov		dx, VENDOR_ID
	mov		deviceid, cx
	mov		vendorid, dx
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
try_next_index_3:
  endif
	jne		short error_get_pci_info ; Not found - exit
	mov		ah, PCI_FUNCTION_ID	; Get IO base
	mov		al, READ_PCI_CONFIG_DWORD
	mov		di, 14h			; Base address register for IO info
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
	jne		short try_next_index
	mov		pci_bus_dev_no, bx	; Save bus / device number
	mov		bl, cl			; Check that this base register has IO info
	and		bl, 03h					
	cmp		bl, 01h			; Check the IO space indicator bits
	jne		try_next_index	; No - should not happen
	and		cl, 0FCh		; Mask lower 2 bits of IO address

	mov		base_addr, cx
	mov		bx, pci_bus_dev_no	; Recover the bus / device number
	mov		ah, PCI_FUNCTION_ID	; Get IRQ number
	mov		al, READ_PCI_CONFIG_BYTE
	mov		di, 3ch			; PCI register for IRQ info
	int		PCI_BIOS_INTERRUPT
	cmp		ah, PCI_SUCCESSFULL
	je		short got_irq
	print	irq_problem_msg
	stc
	jmp		try_next_index		; Continue the search.
got_irq:
	mov		int_no, cl
	clc
	ret
error_get_pci_info:
	stc
	ret
get_pci_info	ENDP

code	ends

_text	segment para public 'code'
_text	ends

init	segment para public 'code'
init	ends

	END
