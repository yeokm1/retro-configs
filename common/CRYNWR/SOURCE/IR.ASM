;Licensed by Intel for distribution without complete source.
;History:1,1
;Tue Aug 21 12:54:06 2001 call setup_53040 on an 82555 as well.
;Wed Aug 01 22:00:25 2001 Add some calls to count_in_err
;Fri Aug 11 15:58:39 2000 Change the way the xmit routine works so we can implement IRQ chaining "right"

	include	options.inc
	include	chip.inc
	include	defs.asm

if	CHIP EQ INTEL_82596
	include	82596.inc
else
	include	82557.inc
endif

cgroup	group code, _text, init

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup
	
	include	timeout.asm

extrn ether_add_msg1 : word
extrn ether_add_msg2 : word
extrn their_timer : dword

	public mem_map_io
mem_map_io		dw	0,0		; Memory mapped I/O address from the command line

	public tx_buff_no, buff_ptrs
tx_buff_no		dw	?
old_buff_no		dw	?
buff_ptrs		dw	offset cgroup:cmd_buff1
				dw	offset cgroup:cmd_buff2

rbd_counter		db	0		; Used to guard against no EOF set

	align	4
	public cmd_buff1, cmd_buff2
cmd_buff1		db	GIANT + 10h dup (?)
	align	4
cmd_buff2		db	GIANT + 10h dup (?)

if	CHIP EQ INTEL_82557
timer_count	dw	0h			; Watchdog timer for the receiver lockup
endif

	public	base_addr, int_no
base_addr	dw 	0,0		; I/O address as located via the I/O scan
int_no		db	0,0,0,0		; must be four bytes long for get_number.

	public	driver_class, driver_type, driver_name
driver_class	db	BLUEBOOK,IEEE8023,0	;null terminated list of classes.
driver_type	db	255		;from the packet spec
driver_name	db	short_name, 0	;name of the driver.

	public	driver_function, parameter_list
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
			;number of receive modes in our table.
rcv_modes	dw (offset cgroup:end_rcv_modes - offset cgroup:mode_zero)/2
mode_zero	dw	0               ;There is no mode zero
			dw	0
			dw	rcv_mode_2	; Individual address only
			dw	rcv_mode_3	; Mode 2 + Broadcast address
			dw	rcv_mode_4	; Mode 3 + Limited Multi-Cast addresses
			dw	rcv_mode_5	; Mode 4 + all Multi_Cast addresses
			dw	rcv_mode_6	; All packets - promiscuous mode
end_rcv_modes:

curr_rcv_mode	db	MATCH_BRDCAST		; The current receive mode
save_err	db	0		; Errors in last frame received (promiscuous mode only)

	ALIGN	4
config_start:
if	CHIP EQ INTEL_82596
; This structure needs to be 14 bytes long but is rounded up to 16 bytes in
; order to make use of DWORD transfers
	db	CB_CFIG_PREFETCH_BIT + (offset cgroup:true_config_end - offset cgroup:config_start)
	db	CB_CFIG_NO_MONITOR_MODE + DEFAULT_FIFO
	db	40h
	db	CB_CFIG_PREAMBLE_LEN + CB_CFIG_NO_SRCADR + CB_CFIG_ADDRESS_LEN
	db	0h
	db	CB_CFIG_IFS
	db	CB_CFIG_SLOTTIME_LOW
	db	CB_CFIG_MAX_RETRIES + CB_CFIG_SLOTTIME_HIGH
	db	0h
	db	0h
	db	RUNT
	db	CB_CFIG_NO_MONITOR_MODE + CB_CFIG_MCAST_DISABLE + CB_CFIG_NO_CDT_SAC + CB_CFIG_AUTO_RETX + CB_CFIG_NO_CRC_IN_MEM + CB_CFIG_LENGTH_DISABLE + CB_CFIG_PRECRS_DISABLE
	db	0h
	db	NOT (CB_CFIG_BACKOFF_DISABLE + CB_CFIG_MULTIIA_ENABLE)
else
	public	config_mii_mode, config_cdt, config_duplex
; This structure needs to be 22 bytes long but is rounded up to 24 bytes in
; order to make use of DWORD transfers
	db	offset cgroup:true_config_end - offset cgroup:config_start
	db	TX_FIFO_LMT +  RX_FIFO_LMT
	db	ADPATIVE_IFS
	db	0h
	db	RX_DMA_MAX
	db	DMBC_EN + TX_DMA_MAX
	db	CI_INT + LATE_SCB + 32h
	db	UNDR_RTRY_1 + DISC_SHORT
config_mii_mode:
	db	0h				 	;	For MII interface - db	MII_MODE
	db	0h
	db	PREAMBLE_LEN_7 + NSAI + 6h
	db	NRML_LINR_PRTY
; debug
;	db	DEF_IFS_SPACING
	db	0f0h ;- works 0a0h too small
	db	0h
	db	0f2h
config_cdt:
	db	CRS_CDT + 48h		;	For MII interface - db 48h
	db	0h
	db	40h
	db	PADDING_ENBL + STRIPPING_ENBL + 0F0h
config_duplex:
	db	0h					;  For full duplex set to FDX_PIN_ENBL
	db	3fh
	db	05h
endif
true_config_end:
	db	0				; 2 extra bytes to make config data
	db	0				; size be a a multiple of DWORDS
config_end:

temp_ru_status	dw	?
	
curs			dw 0

if	CHIP EQ INTEL_82557
	public	multicast_fix
multicast_fix	dw	?	; All drivers currently need fix - so this is ignored
endif


;this macro writes the given character to the given row and column on a CGA.
to_scrn	macro	r, c, ch
	local	di_ok,black,done,one_more
  if 0
jumps
  .8086
	push	bx
	push	es
	push	di
	mov		di, cs:curs
	cmp		di, 3200
	jb		short di_ok
	mov		di, 0
di_ok:
	mov		bx,0b800h
	mov		es,bx
	mov		bx,es:[di+r*160+c*2]
	test	bh,1
	jne		short black
	mov		bh,07h
	jmp		short done
black:
	mov		bh,70h
done:
	mov		bl,ch
	mov		es:[di+r*160+c*2],bx
	add		di, 2
	mov		cs:curs, di
	pop		di
	pop		es
	pop		bx
	.386
  endif
	endm

	.386					; Must have >= 386 for these routines to be called
	public	bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	cmp		ah, 26
	jne		short bad_command_intercept_1
if	CHIP EQ INTEL_82596
	jmp		do_tdr
else
;	no tdr capability for the 82557
endif
bad_command_intercept_1:
	mov		dh, BAD_COMMAND
	stc
	ret

get_buffer	PROC	NEAR
; Get the next buffer address from the buff_ptr array
	mov		ax, cs
	mov		es, ax
	mov		ax, cs:tx_buff_no		; Get next buffer # to use
	mov		di, ax					; Save into di
	mov		cs:old_buff_no, ax		; Save buffer #
	inc		ax						; Advance the buffer #
	cmp		ax, 2					; Advanced too far ?
	jl		short count_ok			; No - the next count is ok
	xor		ax, ax					; Next count will be zero
count_ok:
	mov		cs:tx_buff_no, ax		; Store the updated buffer #
	sal		di, 1					; Make bx a word count
	mov		di, cs:buff_ptrs[di]	; Get the buffer address

	mov		ax, 1
	call	set_timeout
wait_cmd_to_complete:
	test	word ptr cs:[di], C_DONE_BIT
	jnz		short buff_finished_with
	to_scrn	2,0,'W'
	call	do_timeout				; Any more time left ?
	jnz		short wait_cmd_to_complete
	mov		ax, cs:old_buff_no		; Recover the original buffer #
	mov		cs:tx_buff_no, ax		; Store for next time
	stc
	ret

buff_finished_with:
	clc
	ret
get_buffer	ENDP

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
; Return cy if we should abort the interrupt reception.
xmit:
	assume	ds:nothing
 	WAIT_CMD_ACCEPTED
	LOAD_PORT	SCB_STATUS
	in		ax, dx
	and		ax, SCB_STATUS_MASK
	clc
	jnz		short xmit_1
	stc
xmit_1:
	ret

	public	wait_scb_non_active
wait_scb_non_active	PROC	NEAR
	call	set_timeout				; AX previously set with the timeout
check_scb_again:
if	CHIP EQ INTEL_82596
	mov		ax, cs:scb_buff.scb_status ; Get the status bits
else
	in		ax, dx					; Get the status bits
endif
	and		ax, CU_STATUS_BITS		; Mask all but the cu status
	cmp		ax, CU_ACTIVE			; Is the cu active
	clc								; Clear carry for exit
	jne		short exit_wait_scb_non_active	; Jump if so
	call	do_timeout				; No - any more time left ?
	jnz		check_scb_again			; Continue to wait if so
	stc								; Otherwise exit with carry set
exit_wait_scb_non_active:
	ret
wait_scb_non_active	ENDP
	
	
	public  issue_cmd
issue_cmd	PROC	NEAR
	; di holds the start of the buffer for the command
cmd_accept_wait:
	WAIT_CMD_ACCEPTED 				; Wait for acceptance of last command
									; Now wait for that command to be completed
	mov		ax, 40h					; Wait, if necessary, for about 1 s
if	CHIP EQ INTEL_82557
	add		dx,	SCB_STATUS - SCB_CMD	; Get to the status port
endif
	call	wait_scb_non_active		; Can't issue a command if chip is active
	jc		short exit_issue_cmd	; Exit if still active
	pushf							; Save interrupt status
	cli								; Prevent the receiver from interrupting
if	CHIP EQ INTEL_82596
	cmp		cs:scb_buff.scb_command, 0	; Did the receiver interrupt earlier
else
	add		dx,	SCB_CMD - SCB_STATUS	; Get to the command port
	in		al, dx
	cmp		al, 0					; Did the receiver interrupt earlier
endif
	jz		short cmd_accepted		; No - safe to issue command
	popf							; Recover flags
	jmp		short cmd_accept_wait	; Need to wait again

cmd_accepted:
if	CHIP EQ INTEL_82596
	mov		cs:scb_buff.scb_command, CU_START
	mov		cs:scb_buff.scb_cbl_add, di
	STALL
	C_ATTENTION
	STALL
else
	add		dx,	SCB_GEN_PTR - SCB_CMD	; Get to the general pointer port
	xor		eax, eax
	mov		ax, di
	out		dx, eax					; Issue the address - upper word is low
	add		dx, SCB_CMD - SCB_GEN_PTR	; Get back to cmd port
	mov		al, CU_START
	out		dx, al					; Issue the command
endif

	popf							; Restore interrupt status
exit_issue_cmd_ok:
	clc
exit_issue_cmd:
	ret
issue_cmd	ENDP

send_problem:
	to_scrn	2,0,'P'
	mov		dh, CANT_SEND		; Indicate an error.
	stc
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
	jae		short oklen
	mov		cx, RUNT			; Make sure size at least RUNT
oklen:
	to_scrn	2,0,'T'
	mov		ax, cs
	mov		es, ax

	call	get_buffer
	jc		send_problem
	mov		bx, di				; Save the start of the buffer
	mov		eax, (EL_BIT + S_BIT + TRANSMIT)*10000h
	stosd						; Store the action command word + status word
if	CHIP EQ INTEL_82596
	mov		ax, -1
	stosw						; Write the address of the next command
	stosw						; Store the TBD array null pointer
	mov		eax, TX_EOF_BIT
else
	mov		eax, -1				; Write the address of the next command
	stosd						; Store the link address - next command
	stosd						; Store the TBD array null pointer
	mov		eax, TX_THRESHOLD*10000h + TX_EOF_BIT
endif
	or		ax, cx				; Include the length of the packet
	stosd
								; Memory copy routine
	mov		ax, cx				; Save byte count
	sar		cx, 2				; Convert to a DWORD count
	rep		movsd				; Copy DWORDS
	mov		cx, ax				; Recover byte count
	and		cx, 0003h			; Obtain count mod 4
	jz		short no_more
	rep		movsb				; Copy remaining bytes

no_more:
	mov		di, bx				; Recover the start of the buffer
	call	issue_cmd
	jc		send_problem
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	  ds:nothing
	call	set_ether
	jnc		short exit_set_address
	mov		dh, CANT_SET
exit_set_address:
	ret

	assume	ds:cgroup
if	CHIP EQ INTEL_82596
rcv_mode_2:
	and		byte ptr config_start[02h], NOT CB_CFIG_SAVE_BAD_FRAMES
	and		byte ptr config_start[08h], NOT CB_CFIG_PROMISCUOUS
	or		byte ptr config_start[08h], CB_CFIG_BROADCAST_DIS
	or		byte ptr config_start[0Bh], CB_CFIG_MCAST_DISABLE
	and		byte ptr config_start[0Dh], NOT CB_CFIG_MULTIIA_ENABLE
	mov		al, MATCH_IA
	jmp	short set_rcv_mode
rcv_mode_3:
	and		byte ptr config_start[02h], NOT CB_CFIG_SAVE_BAD_FRAMES
	and		byte ptr config_start[08h], NOT CB_CFIG_PROMISCUOUS
	and		byte ptr config_start[08h], NOT CB_CFIG_BROADCAST_DIS
	or		byte ptr config_start[0Bh], CB_CFIG_MCAST_DISABLE
	and		byte ptr config_start[0Dh], NOT CB_CFIG_MULTIIA_ENABLE
	mov		al, MATCH_BRDCAST
	jmp	short set_rcv_mode
rcv_mode_4:
	and		byte ptr config_start[02h], NOT CB_CFIG_SAVE_BAD_FRAMES
	and		byte ptr config_start[08h], NOT CB_CFIG_PROMISCUOUS
	and		byte ptr config_start[08h], NOT CB_CFIG_BROADCAST_DIS
	or		byte ptr config_start[0Bh], CB_CFIG_MCAST_DISABLE
	or		byte ptr config_start[0Dh], CB_CFIG_MULTIIA_ENABLE
	mov		al, MATCH_SOME_MULTICAST
	jmp	short set_rcv_mode
rcv_mode_5:
	and		byte ptr config_start[02h], NOT CB_CFIG_SAVE_BAD_FRAMES
	and		byte ptr config_start[08h], NOT CB_CFIG_PROMISCUOUS
	and		byte ptr config_start[08h], NOT CB_CFIG_BROADCAST_DIS
	and		byte ptr config_start[0Bh], NOT CB_CFIG_MCAST_DISABLE
	and		byte ptr config_start[0Dh], NOT CB_CFIG_MULTIIA_ENABLE
	mov		al, MATCH_ALL_MULTICAST
	jmp	short set_rcv_mode
rcv_mode_6:
	or		byte ptr config_start[02h], CB_CFIG_SAVE_BAD_FRAMES
	or		byte ptr config_start[08h], CB_CFIG_PROMISCUOUS
	and		byte ptr config_start[08h], NOT CB_CFIG_BROADCAST_DIS
	and		byte ptr config_start[0Bh], NOT CB_CFIG_MCAST_DISABLE
	and		byte ptr config_start[0Dh], NOT CB_CFIG_MULTIIA_ENABLE
	mov		al, MATCH_EVERYTHING
else
rcv_mode_2:
	and		byte ptr config_start[06h], NOT SAVE_BF
	or		byte ptr config_start[07h], DISC_SHORT
	and		byte ptr config_start[0Fh], NOT PROMISC_MODE
	or		byte ptr config_start[0Fh], BROADCAST_DIS
	and		byte ptr config_start[14h], NOT MULTI_IA_ENBL
	and		byte ptr config_start[15h], NOT MULTICAST_ALL
	mov		al, MATCH_IA
	jmp		set_rcv_mode
rcv_mode_3:
	and		byte ptr config_start[06h], NOT SAVE_BF
	or		byte ptr config_start[07h], DISC_SHORT
	and		byte ptr config_start[0fh], NOT PROMISC_MODE
	and		byte ptr config_start[0fh], NOT BROADCAST_DIS
	and		byte ptr config_start[14h], NOT MULTI_IA_ENBL
	and		byte ptr config_start[15h], NOT MULTICAST_ALL
	mov		al, MATCH_BRDCAST
	jmp		short set_rcv_mode
rcv_mode_4:
	and		byte ptr config_start[06h], NOT SAVE_BF
	or		byte ptr config_start[07h], DISC_SHORT
	and		byte ptr config_start[0fh], NOT PROMISC_MODE
	and		byte ptr config_start[0fh], NOT BROADCAST_DIS
	or		byte ptr config_start[14h], MULTI_IA_ENBL
	and		byte ptr config_start[15h], NOT MULTICAST_ALL
	mov		al, MATCH_SOME_MULTICAST
	jmp		short set_rcv_mode
rcv_mode_5:
	and		byte ptr config_start[06h], NOT SAVE_BF
	or		byte ptr config_start[07h], DISC_SHORT
	and		byte ptr config_start[0fh], NOT PROMISC_MODE
	and		byte ptr config_start[0fh], NOT BROADCAST_DIS
	and		byte ptr config_start[14h], NOT MULTI_IA_ENBL
	or		byte ptr config_start[15h], MULTICAST_ALL
	mov		al, MATCH_ALL_MULTICAST
	jmp		short set_rcv_mode
rcv_mode_6:
	or		byte ptr config_start[06h], SAVE_BF
	and		byte ptr config_start[07h], NOT DISC_SHORT
	or		byte ptr config_start[0fh], PROMISC_MODE
	and		byte ptr config_start[0fh], NOT BROADCAST_DIS
	and		byte ptr config_start[14h], NOT MULTI_IA_ENBL
	or		byte ptr config_start[15h], MULTICAST_ALL
	mov		al, MATCH_EVERYTHING
endif
set_rcv_mode:
	mov		curr_rcv_mode, al
	call	do_config
	ret

	public	set_multicast_list
	assume	ds:nothing
set_multicast_list:
	to_scrn	2,0,'M'
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
; wait until the previous command has finished executing

set_multicast_list_1:
	cmp		cx, MAX_MULTICAST * EADDR_LEN	; Max size of multicast data
	stc
	ja		short error_set_multicast_list
if	CHIP EQ INTEL_82557
	mov		ax, cs
	mov		es, ax
	push	cx					; Copy for the multicast fix
	push	si
	mov		di, offset cgroup:our_multicast_list
	mov		ax, cx				; Copy byte count
	sar		cx, 2				; Convert to a DWORD count
	rep		movsd				; Copy DWORDS
	mov		cx, ax				; Recover byte count
	and		cx, 0003h			; Obtain count mod 4
	jz		short copied_all_bytes
	rep		movsb				; Copy remaining bytes
copied_all_bytes:
	pop		si
	pop		ax					; Recover size of the multicast data
	push	ax					; Store again for later
	mov		cx, MAX_MULTICAST * EADDR_LEN	; Max size of multicast data
	sub		cx, ax				; cx = size of filler data
	je		short no_filler
	mov		ax, 81h				; Default multicast data
	rep		stosb
no_filler:
	pop		cx
endif
	call	get_buffer
	jc		short error_set_multicast_list
	mov		bx, di				; Save the start of the buffer
	mov		eax, (EL_BIT + S_BIT + MULTI_ADD)*10000h
	stosd						; Store the action command word + status word
if	CHIP EQ INTEL_82596
	mov		ax, -1
	stosw						; Write the address of the next command
else
	mov		eax, -1				; Write the address of the next command
	stosd						; Store the link address - next command
endif
	mov		ax, cx				; Write byte count
	stosw
								; Memory copy of the MC/IA data
	sar		cx, 2				; Convert to a DWORD count
	rep		movsd				; Copy DWORDS
	mov		cx, ax				; Recover byte count
	and		cx, 0003h			; Obtain count mod 4
	jz		short done_all
	rep		movsb				; Copy remaining bytes

done_all:
	mov		di, bx				; Recover the start of the buffer
	call	issue_cmd
error_set_multicast_list:
	jnc		short exit_set_multicast_list
	mov		dh, CANT_SET
exit_set_multicast_list:
	ret

	public	terminate
terminate:
	call	reset_chip
	ret


	public	set_ether
set_ether	PROC NEAR
; Set the Individual address registers with the Ethernet address => si
	mov		ax, cs					; Get correct segment into es
	mov		es, ax
	mov		cx, 4					; Get buffer will wait for 27ms each call
try_for_ether_buffer:
	call	get_buffer
	jnc		short got_ether_buffer
	loop	try_for_ether_buffer
	mov		dx, offset cgroup:ether_add_msg1
	stc
	jmp		short exit_set_ether	; Exit if buffer not available
got_ether_buffer:
	mov		cx, EADDR_LEN
	mov		bx, di				; Save the start of the buffer
	mov		eax, (EL_BIT + IA_SETUP)*10000h
	stosd						; Store the action command word + status word
if	CHIP EQ INTEL_82596
	mov		ax, -1				; Get the address (16 bit) of next command
	stosw						; Store the link address - next command
else
	mov		eax, -1				; Get the address (32 bit) of the next command
	stosd						; Store the link address - next command
endif
	mov		cx, EADDR_LEN/2		; Now copy over the ethernet address
	rep		movsw
if	CHIP EQ INTEL_82557
	add		di, 02h				; Increase to the address of the next command
endif
	mov		di, bx				; Recover the start of the buffer
	call	issue_cmd
	mov		dx, offset cgroup:ether_add_msg2
exit_set_ether:
	ret
set_ether	ENDP

	public	do_config
do_config	PROC NEAR
; Set the configuration information
	mov		cx, 4					; Get buffer will wait for 27ms each call
try_for_config_buffer:
	call	get_buffer
	jnc		short got_config_buffer
	loop	try_for_config_buffer
	stc
	jmp		short exit_do_config	; Exit if buffer not available

got_config_buffer:
	mov		cx, offset cgroup:config_end - offset cgroup:config_start
	mov		bx, di				; Save the start of the buffer
	mov		si, offset cgroup:config_start
	mov		eax, (EL_BIT + S_BIT + CONFIG_CMD)*10000h
	stosd						; Store the action command word + status word
if	CHIP EQ INTEL_82596
	mov		ax, -1				; Set the address (16 bits) of next command
	stosw						; Store the link address - next command
else
	mov		eax, -1				; Set the address (32 bits) of next command
	stosd						; Store the link address - next command
endif
	sar		cx, 2h				; Convert to a DWORD count
	rep		movsd
	mov		di, bx				; Recover the start of the buffer
	call	issue_cmd
exit_do_config:
; debug - No documentation on the correct delay for the config command
	mov		ax, 10h				; Wait for the command
	call	wait
	clc
	ret
do_config	ENDP

	public	reset_chip
reset_chip	PROC	NEAR
if	CHIP EQ INTEL_82596
    xor     ax, ax
	LOAD_PORT  PLXP_CA_OFFSET	; Writing a 0 here will reset the chip
    out     dx, ax
    STALL
	call	wait_27ms			; Only really need a 5ms delay
	call	clear_interrupt_latch
else
	call	disable_board_int
	LOAD_PORT	PORT				; Issue a selective reset before full reset
	mov		eax, SELECTIVE_RESET
	out		dx, eax
    STALL							; Cannot acces chip for 10 micro seconds
	mov		ax, 4					; Wait, if necessary, for about
	call	set_timeout				;    100 mili-seconds
check_test_buff:
	in		eax, dx					; Has selective reset completed
	or		eax, 0h
	je		short done_selective_reset	; Jump if so
	call	do_timeout				; Any more time left ?
	jnz		check_test_buff			; Continue to wait if so
done_selective_reset:
	mov		eax, SOFTWARE_RESET		; Now issue full software reset
	out		dx, eax
endif
	mov		ax,02h					; Wait about 50ms
	call	wait
	ret
reset_chip	ENDP

	public	wait_27ms, wait
wait_27ms:
	mov	ax, 1
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
	assume	ds:cgroup
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


start_receive_unit    PROC	NEAR
										; First check if reciever is ready
if	CHIP EQ INTEL_82596
	mov		ax, scb_buff.scb_status		; Get the status bits
else
	LOAD_PORT	SCB_STATUS
	in		ax, dx			; Get the status bits
endif
	and		ax, RU_STATUS_BITS	; Mask non receive status bits
	cmp		ax, RU_READY		; Is the receiver ready
	jne		short do_restart	; No - restart the receiver

	cmp		rbd_counter, GIANT / SIZE_ONE_DATA_BUFF	; Gone too far ?
	jbe		short ru_is_ready	; Yes - restart
	mov		rbd_counter, 0

do_restart:
	to_scrn	2,0,'@'

if	CHIP EQ INTEL_82557
	add		dx,	SCB_CMD - SCB_STATUS	; Get to the command register
	mov		al, RU_ABORT
	out		dx, al
	STALL
	STALL
	add		dx,	SCB_STATUS - SCB_CMD	; Get back to the status register
	mov     ax, SCB_STATUS_MASK
	out     dx, ax 						; ACK the interrupts
endif

if 1				
	; Code to reset the rbd and rfd descriptors
	mov		cx, RBD_COUNT 			; Setup the receive buffer descriptors
	mov		si, first_rbd
next_rbd:
	mov		[si].rbd_status, 0
	mov		si, WORD PTR [si].rbd_link
	loop	next_rbd

	mov		cx, RFD_COUNT 			; Setup the receive buffer descriptors
	mov		di, first_rfd

if	CHIP EQ INTEL_82596
	mov		[di].rfd_ptr, si ; Setup the start rfd to point to the start rbd
else
	movzx	esi, si
	mov		[di].rfd_ptr, esi ; Setup the start rfd to point to the start rbd
endif

next_rfd:
	mov		[di].rfd_status, 0h
	mov		di, WORD PTR [di].rfd_link
	loop	next_rfd
endif

	; re-start receive unit and setup the intial RFD

if	CHIP EQ INTEL_82596
	mov		scb_buff.scb_rfa_add, di	; Set SCB for the START RU command
	mov		scb_buff.scb_command, RU_START
	STALL
	C_ATTENTION
	STALL
else
	add		dx,	SCB_GEN_PTR - SCB_STATUS; Get back to the general pointer
	movzx	eax, di
	out		dx, eax						; Issue the address - upper word is low
	add		dx, SCB_CMD - SCB_GEN_PTR	; Get back to cmd port
	mov		al, RU_START
	out		dx, al						; Issue the command
endif

ru_is_ready:
    ret
start_receive_unit    ENDP

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:cgroup

if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_INTERRUPT_CONTROL
    in		al, dx
    test	al, BIT_4
    jz		short check_receiver_status
endif
	to_scrn	2,0,'I'

look_again:
 	WAIT_CMD_ACCEPTED

get_status_again:
if	CHIP EQ INTEL_82596
    mov     ax, scb_buff.scb_status
else
	LOAD_PORT	SCB_STATUS
	in		ax, dx
endif
    and     ax, SCB_STATUS_MASK
	jz		short check_receiver_status
	mov		temp_ru_status, ax			; Save for later
if	CHIP EQ INTEL_82596
    mov     scb_buff.scb_command, ax 	; ACK the interrupts
	STALL
    C_ATTENTION
	STALL
else
    out     dx, ax 						; ACK the interrupts
endif

	test	temp_ru_status, FR_ST_BIT	; A receive interrupt ?
	jz		short try_no_resources_int	
	to_scrn	2,0,'R'
if	CHIP EQ INTEL_82557
	mov		timer_count, 0				; Receever is not dead - clear watchdog
endif
	call	receive_int
	cmp		rbd_counter, GIANT / SIZE_ONE_DATA_BUFF	; Gone too far ?
	ja		short check_receiver_status	; Yes - restart

try_no_resources_int:	
	test	temp_ru_status, RNR_ST_BIT	; An out of resources interrupt ?
	jz		short get_status_again

check_receiver_status:
	call	start_receive_unit			; This also handles out of resources 
if	CHIP EQ INTEL_82596
	STALL
	call	clear_interrupt_latch
	STALL
endif

	to_scrn	2,0,'i'
	ret


receive_int	PROC NEAR
	to_scrn	2,0,'{'
another_frame:
	mov		ax, cs
	mov		es, ax
	mov		bx, first_rfd			; bx => first RFD

	test	[bx].rfd_status, RFD_DONE_BIT	; Has RFD been used
	jnz		short rfd_used			; Yes - read frame data
	to_scrn	2,0,'}'
	ret								; No - exit

rfd_used:								; First find length of the frame
	test	[bx].rfd_status, RESOURCES_BIT
	jz		short enough_resources
	call	count_in_err
	to_scrn	2,0,'B'
	ret

enough_resources:
	mov		si, first_rbd			; si => buffer descriptor
	xor		dx, dx					; dx holds byte count
	mov		di, [si].rbd_voffset	; Save pointer to data

	mov		rbd_counter, 0			; Guard against no EOF set
continue_count:
	mov		ax, [si].rbd_status		; Status and count word for RBD
	test	ax, EOF_BIT				; Last RBD for this frame
	jne		short got_count
valid_count:
	add		dx, SIZE_ONE_DATA_BUFF	; Add full buffer to count
	mov		si, WORD PTR [si].rbd_link	; Advance to next RBD

	inc		rbd_counter 			; Should eventually find an EOF
	cmp		rbd_counter, GIANT / SIZE_ONE_DATA_BUFF	; Gone too far
	jle		continue_count			; Continue if not
	call	count_in_err
	to_scrn	2,0,'*'
	ret

got_count:
	test	ax, COUNT_VALID			; Is the count valid
	jz		ptrupdate				; No - exit with cleanup
	and		ax, 3FFFh				; Clear status bits in the count
	add		dx, ax					; Add partial buffer to count

; Did we receive our own broadcast?
	add		di, EADDR_LEN			; Point to the source address
	mov		ax, di					; Save pointer to received data
	mov		si, offset cgroup:my_address
	mov		cx, EADDR_LEN/2
	repe	cmpsw
	jne		short not_our_own		; Jump if not

	to_scrn	23,79,'O'
	inc		received_ours			; Remember that we received it.
	jmp		ptrupdate				; Exit with cleanup

not_our_own:
	mov		di, ax					; Recover pointer to received data
	add		di, EADDR_LEN			; Now point to the type/length bytes
; Check to make sure that frame has been received with no errors.
; If errors are found then only return frame if in promiscuous mode.
; In promiscuous mode the frame status is assembled and placed in save_err.
	mov		save_err, 1				; Set default value of no error
	mov		ax, [bx].rfd_status		; Get status of frame
	test	ax, RX_OK				; Check if received without errors
	jnz		short no_frame_errs		; Jump if ok

	call	count_in_err
	to_scrn	23,72,'E'

	cmp	curr_rcv_mode, MATCH_EVERYTHING	; Currently in promiscuous mode ?
	jne		short cleanup_exit		; No - discard bad frame

; Find the error bits in the status of the current frame and save in save_err
	mov		ch, 0
	test	ax, SHORT_FRAME_BIT
	je		short RX_not_short
	or		ch, 02h
RX_not_short:
	test	ax, CRC_BIT
	je		short RX_crc_ok
	or		ch, 04h
RX_crc_ok:
	test	ax, ALIGN_BIT
	je		short RX_align_ok
	or		ch, 08h
RX_align_ok:
	test	ax, OVER_RUN_BIT
	je		short RX_no_over_run
	or		ch, 10h
RX_no_over_run:
	mov		save_err, ch

cleanup_exit:
	jmp		short ptrupdate		; Exit with cleanup

no_frame_errs:
	to_scrn	2,0,'R'
	mov		cx, dx			; Get length of packet in cx
	push	bx
	push	cx
	mov		dl, BLUEBOOK		;assume bluebook Ethernet.
	mov		ax, [di]		; Get the packet type
	xchg	ah, al
	cmp 	ax, 1500
	ja		short BlueBookPacket
	inc		di					;set di to 802.2 header
	inc		di
	mov		dl, IEEE8023
BlueBookPacket:
	mov		dh,	save_err		; Get the error status into dh for Intel
	call	recv_find			; See if type and size are wanted
	pop		cx
	pop		bx
	mov		ax, es				; Did recv_find give us a null pointer?
	or		ax, di				; ..
	je		short ptrupdate		; If null, don't copy the data

	push	cx					; We will want the count and pointer
	push	es					;  to hand to client after copying,
	push	di					;  so save them at this point

	mov		si, first_rbd			; si => buffer descriptor
copybuf:
	mov		dx, si				; Save a copy of the RBD
	mov		cx, [si].rbd_status ; Get count word for RBD
	test	cx, EOF_BIT				; Last RBD for this frame
	jne 	short use_actual_count
	mov		cx, SIZE_ONE_DATA_BUFF	; Add full buffer to count
use_actual_count:
	and		ch, 3Fh				; Clear any status bits in count
	mov		si, [si].rbd_voffset	; Get a pointer to data buffer
								; Memory copy routine
	mov		ax, cx				; Save byte count
	sar		cx, 1				; Convert to a DWORD count
	sar		cx, 1				; Convert to a DWORD count
	rep		movsd				; Copy DWORDS
	mov		cx, ax				; Recover byte count
	and		cx, 0003h			; Obtain count mod 4
	jz		short no_more_1
	rep		movsb				; Copy remaining bytes
no_more_1:

	mov		si, dx				; Recover copy of the RBD
	test	[si].rbd_status, EOF_BIT	; Check EOF bit
	mov		si, WORD PTR [si].rbd_link	; Advance to the next RBD
	jz		copybuf				; If not EOF the contine the copy
	pop		si					; Recover pointer to destination
	pop		ds					; Tell client it's his source
	pop		cx					; And it's this long
	assume	ds:nothing
	call	recv_copy			; Give it to him
	assume	ds:cgroup
	mov		ax, cs				; Recover our DS
	mov		ds, ax

ptrupdate:
	to_scrn	2,0,'-'
	; First update the RBD list
	mov		si, first_rbd			; si => buffer descriptor
do_next_rbd:
	test	[si].rbd_status, EOF_BIT	; Check EOF bit
	mov		[si].rbd_status, 0			; Clear status word
	jnz		short do_last_rbd
	cmp		si, last_rbd				; At the end of list ?
	jz		short do_last_rbd			; Jump if so
	mov		si, WORD PTR [si].rbd_link	; Get to the next rbd
	jmp		do_next_rbd
do_last_rbd:

	mov		di, last_rbd				; Current end of RBD list
	mov		last_rbd, si				; Update with the new end of RBD list
	mov		[si].rbd_size, EL_BIT+SIZE_ONE_DATA_BUFF	; Mark end of the list
	mov		[di].rbd_size, SIZE_ONE_DATA_BUFF	; Remove old end-of-list
	mov		ax, WORD PTR [si].rbd_link	; Get to the next rbd
	mov		first_rbd, ax				; Store as the first rbd for next time

	; Now update the RFD list
	mov		di, last_rfd			; Current end of RFD list
	mov		bx, first_rfd				; bx => first RFD
	mov		last_rfd, bx			; Update with the new end of RFD list
	mov		[bx].rfd_eol, EL_BIT+FLEXIBLE_MODE	; Set new end of RFD list
	mov		[bx].rfd_status, 0		; Clear status word for frame
	mov		[di].rfd_eol, FLEXIBLE_MODE	; Remove old end of RFD list
	mov		si, WORD PTR [bx].rfd_link	; Get address of next RFD
	mov		first_rfd, si			; Store first RFD for next time

	jmp		another_frame
receive_int	ENDP


if	CHIP EQ INTEL_82596
do_tdr	PROC NEAR
; enter with es:di pointing to time int
	push	es
	push	di
	mov		ax, cs					; Get correct segment into es
	mov		es, ax
	mov		cx, 8					; Get buffer will wait for 27ms each call
try_for_tdr_buffer:
	call	get_buffer
	jnc		short got_tdr_buffer
	loop	try_for_tdr_buffer
tdr_problem_exit:
	stc
	pop		di
	pop		es
	ret
	
got_tdr_buffer:
	mov		bx, di				; Save the start of the buffer
	mov		eax, (EL_BIT + S_BIT + TDR_CMD)*10000h
	stosd						; Store the action command word + status word
	mov		ax, -1
	stosw						; Write the address of the next command
	xor		ax, ax
	stosw						; Clear the tdr result
	mov		di, bx				; Recover the start of the buffer
	call	issue_cmd
	
	mov		ax, 40h
	call	set_timeout
wait_tdr_to_complete:
	test	cs:[di], word ptr C_DONE_BIT
	jnz		short tdr_done
	call	do_timeout			; Any more time left ?
	jnz		short wait_tdr_to_complete
	jmp		short tdr_problem_exit

tdr_done:
	pop		di
	pop		es
	test	ax, LNK_OK
	jz		short tdr_bad_cable
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
do_tdr	ENDP
endif

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
if	CHIP EQ INTEL_82596
	iret
else
	; 82557 has a receiver lockup problem
	; requires a multicast setup command to 'unlock' it
	; issued every 2 seconds if necessary
	inc		cs:timer_count
	cmp		cs:timer_count, 25h
	jb		short no_receiver_wakeup
	PUSH_16_32	ax			; save lots of registers
	PUSH_16_32	bx
	PUSH_16_32	cx
	PUSH_16_32	dx
	PUSH_16_32	si
	PUSH_16_32	di
	PUSH_16_32	bp
	push	ds
	push	es
	cld
	assume	ds:cgroup, es:cgroup
	mov		ax, cs
	mov		ds, ax
	mov		es, ax
	mov		timer_count, 0
	mov		si, offset cgroup:our_multicast_list
	mov		ax, MAX_MULTICAST				; Max addresses in multicast data
	mov		cx, MAX_MULTICAST * EADDR_LEN	; Max size of multicast data
	call	set_multicast_list
	to_scrn	2,0,'!'
	assume	ds:nothing, es:nothing
	pop		es			; restore lots of registers
	pop		ds
	POP_16_32	bp
	POP_16_32	di
	POP_16_32	si
	POP_16_32	dx
	POP_16_32	cx
	POP_16_32	bx
	POP_16_32	ax
no_receiver_wakeup:
	jmp		cs:their_timer
endif

	public	enable_board_int
enable_board_int	PROC	NEAR
if	CHIP EQ INTEL_82596
	LOAD_PORT	PLXP_INTERRUPT_CONTROL
    mov     al, LATCHED_INTWRITE_BIT
    out     dx, al
else
	LOAD_PORT	SCB_CMD_INT
	xor		al, al
	out		dx, al
endif
	ret
enable_board_int	ENDP
	
if	CHIP EQ INTEL_82557
	public	disable_board_int
disable_board_int	PROC	NEAR
	LOAD_PORT	SCB_CMD_INT
	mov		al, MASK_INT_BIT
	out		dx, al
	ret
disable_board_int	ENDP
endif

if	CHIP EQ INTEL_82596
	public	clear_interrupt_latch
clear_interrupt_latch	PROC	NEAR
	LOAD_PORT	PLXP_INTERRUPT_CONTROL	; Clear int latch
    in		al, dx
    or		al, BIT_4
	out		dx, al
	ret
clear_interrupt_latch	ENDP
endif

if	CHIP EQ INTEL_82557
our_multicast_list	db	(MAX_MULTICAST * EADDR_LEN) dup (81h)
endif

if	CHIP EQ INTEL_82596
	ALIGN	16
	public	scb_buff
scb_buff	db	size SCB_STRUC dup (0)
endif

	public	first_rfd, last_rfd, first_rbd, last_rbd
first_rfd		dw	?
last_rfd		dw	?
first_rbd		dw	?
last_rbd		dw	?

	public	start_rfd, start_rbd, start_rx_buff
	align	4
start_rfd		db RFD_COUNT * (size RFD_STRUCT) dup (?)
	align	4
start_rbd		db RBD_COUNT * (size RBD_STRUCT) dup (?)
	align	4
start_rx_buff	db RBD_COUNT * SIZE_ONE_DATA_BUFF dup (?)

code	ends

_text	segment para public 'code'
_text	ends

init	segment para public 'code'
init	ends

	END
