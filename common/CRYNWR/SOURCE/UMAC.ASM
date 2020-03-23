umac_version	equ	3
;History:782,1
VERBOSE_HEXOUT	equ	0

;  Copyright, 1988-1994, Russell Nelson, Crynwr Software.  Licensed to SMC
;  for use with their LMAC libraries.

	include	defs.asm

cgroup	group code,init

	extrn	LM_Send: near
	extrn	LM_Change_Receive_Mask: near
	extrn	LM_Disable_Adapter: near
	extrn	LM_Close_Adapter: near
	extrn	LM_Disable_Adapter: near
	extrn	LM_Service_Events: near
	extrn	LM_Enable_Adapter: near
	extrn	LM_Receive_Copy: near
	extrn	LM_GetCnfg: near
	extrn	LM_Initialize_Adapter: near
	extrn	LM_Open_Adapter: near
	extrn	LM_Load_Microcode: near

code	segment para public 'code'
	assume	cs:cgroup, ds:cgroup

	include	timeout.asm
	include	lmstruct.inc
  ifdef TOKEN_RING
	include	lmt_uc.inc
  endif

	public	int_no, io_addr, mem_base
int_no		db	0,0,0,0		; Interrupt level
io_addr		dw	-1,-1		; I/O address for card (jumpers)
mem_base	dw	0d000h,0	; Shared memory addr (software)

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
  ifdef ETHERNET
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
  endif
  ifdef TOKEN_RING
driver_class	db	3		;from the packet spec
  endif
driver_type	db	DR_TYPE		;per the spec.
driver_name	db	DR_NAME,0	;name of the driver.
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

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0               ;There is no mode zero
		dw	0
		dw	cgroup:rcv_mode_2	;receive individual address
		dw	cgroup:rcv_mode_3
		dw	0		;haven't set up perfect filtering yet.
		dw	cgroup:rcv_mode_5
		dw	cgroup:rcv_mode_6

asinfo	AdapterStructure	<>

scratchpad	db	200 dup(?)

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


ptr_data_buff	label	word
	dw	1
ptr_data_ptr	dd	?
ptr_data_len	dw	?

	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing
  ifdef PCMCIA
	mov	ax,asinfo.adapter_status
	cmp	ax,CARD_REMOVED
	je	send_pkt_3
  endif
	sti
	mov	ptr_data_ptr.segm,ds
	movseg	ds,cs
	assume	ds:cgroup
	mov	ptr_data_ptr.offs,si
	mov	ptr_data_len,cx
	movseg	es,cs
	mov	si,offset cgroup:ptr_data_buff
	mov	bp,offset cgroup:asinfo
  ifdef ETHERNET
	cmp	cx,RUNT
	jae	send_pkt_4
	mov	cx,RUNT
send_pkt_4:
  endif

  if VERBOSE_HEXOUT
	mov	al,'E'
	call	hexout_char
  endif
	mov	ax,36
	call	set_timeout
send_pkt_1:
  if VERBOSE_HEXOUT
	mov	al,'S'
	call	hexout_char
  endif
	call	LM_Send			;we can't wait here too long...
	cld
	cmp	ax,SUCCESS		;if it succeeded, we exit okay.
	je	send_pkt_2
	cmp	ax,OUT_OF_RESOURCES	;if we not out of resources, it's bad.
  if 0
	jmp	send_pkt_3		;go exit with error.
  else
	jne	send_pkt_3		;go exit with error.
  endif
  if VERBOSE_HEXOUT
	mov	al,'T'
	call	hexout_char
  endif
	call	do_timeout
	jne	send_pkt_1
	mov	dh,CANT_SEND		;we timed out.
	stc
	ret
send_pkt_2:
	clc
	ret
send_pkt_3:
	mov	dh,CANT_SEND
	stc
	ret


	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	mov	dh,CANT_SET
	stc
	ret


;skip past the following two bytes while destroying BX.
skip2	macro
	db	0bbh			;opcode of "mov bx,0000"
	endm

rcv_mode_2:
	mov	al,0			;receive individual address
	skip2
rcv_mode_3:
	mov	al,ACCEPT_BROADCAST	;receive individual address+broadcast
	skip2
rcv_mode_5:
	mov	al,ACCEPT_BROADCAST or ACCEPT_MULTI_PROM
					;receive individual address+group addr(multicast)
	skip2
rcv_mode_6:
	mov	al,ACCEPT_BROADCAST or ACCEPT_MULTI_PROM or PROMISCUOUS_MODE
					;receive all packets (and multicast, too).
	xor	ah,ah
	mov	asinfo.receive_mask,ax
	mov	bp,offset cgroup:asinfo
	call	LM_Change_Receive_Mask
	cld
	cmp	ax,SUCCESS
	clc
	je	set_rcv_mode_1
	stc
set_rcv_mode_1:
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	mov	dh,NO_MULTICAST
	stc
	ret

last_status	dw	?

	public	terminate
terminate:
	assume	ds:cgroup
  ifdef TOKEN_RING
	stc
	ret
  else
	mov	bp,offset cgroup:asinfo
  ifdef PCMCIA
	mov	ax,asinfo.adapter_status
	cmp	ax,CARD_REMOVED
	je	terminate_2
  endif
	or	asinfo.adapter_flags,PERM_CLOSE	;close it but good!
  if VERBOSE_HEXOUT
	mov	ax,asinfo.adapter_status
	call	hexout_word
  endif
	mov	ax,asinfo.adapter_status	;if it's not open, we can't
	cmp	ax,OPEN			;  close it.
	jne	terminate_2
	sti
	call	LM_Close_Adapter
	cmp	ax,SUCCESS
	jne	terminate_2
  if VERBOSE_HEXOUT
	mov	ax,asinfo.adapter_status
	call	hexout_word
  endif
	cld
	sti
terminate_1:
  if VERBOSE_HEXOUT
	mov	ax,asinfo.adapter_status
	cmp	ax,last_status
	je	terminate_3
	call	hexout_word
	mov	last_status,ax
terminate_3:
  endif
	cmp	asinfo.adapter_status,FAILED
	je	terminate_2		;but what else can we do??
	cmp	asinfo.adapter_status,CLOSED
	jne	terminate_1
terminate_2:
	ret
  endif

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

	public	recv
recv:
;called from the recv isr.  All registers have been saved, ds=cs,
;our interrupt has been acknowledged, and our interrupts have been
;masked at the interrupt controller.
	assume	ds:cgroup
  ifdef PCMCIA
	mov	ax,asinfo.adapter_status
	cmp	ax,CARD_REMOVED
	je	recv_1
  endif
	mov	bp,offset cgroup:asinfo
	call	LM_Disable_Adapter
	sti
	call	LM_Service_Events
	cli
	call	LM_Enable_Adapter
recv_1:
	ret

	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

lookahead_buffer	db	26 dup(?)

lookahead_data_buff	label	word
	dw	1
lookahead_data_ptr	dw	offset cgroup:lookahead_buffer,?
lookahead_data_len	dw	26

recv_free_j_1:
	jmp	recv_free
	public	um_receive_packet, _um_receive_packet
um_receive_packet:
_um_receive_packet:
;bx = error status, cx = size. ds:bp -> AdapterStructure, es:si -> lookahead.
	cld
        pushf
        sti
        push    es
        push    di
        push    si
        push    dx
        push    cx
        push    bx

        mov     ax, cs
        mov     ds, ax                          ; set up DS

	jcxz	recv_free_j_1

	test	asinfo.adapter_flags,RX_VALID_LOOKAHEAD	;is lookahead cool?
	jne	um_receive_packet_1

	push	bx
	push	cx
	xor	bx,bx			;tell LM_Receive_Copy we're looking ahead.

	mov	lookahead_data_ptr.segm,cs
	movseg	es,cs
	mov	si,offset cgroup:lookahead_data_buff
	mov	bp,offset cgroup:asinfo
	xor	ax,ax			;offset is zero.
	mov	cx,26
	call	LM_Receive_Copy

	pop	cx
	pop	bx

  if VERBOSE_HEXOUT
	push	ax
	mov	al,'L'
	call	hexout_char
	pop	ax
	call	hexout_word
  endif

	cmp	ax,SUCCESS		; Lookahead OK?
	jne	recv_free_j_1

	mov	si,offset cgroup:lookahead_buffer
  if VERBOSE_HEXOUT
	mov	al,'l'
	call	hexout_char
  endif
um_receive_packet_1:
	mov	di,si

	add	di,EADDR_LEN+EADDR_LEN	;skip the ethernet addreses and
					;  point to the packet type.
  ifdef ETHERNET
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
  endif
  ifdef TOKEN_RING
	mov	dl,3			;token ring class.
  endif
  if VERBOSE_HEXOUT
	mov	al,'R'
	call	hexout_char
  endif
	push	cx
	call	recv_find
	pop	cx

  if VERBOSE_HEXOUT
	mov	al,'F'
	call	hexout_char
  endif
	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_discard		;yes - just free the frame.

	push	es
	push	di
	push	cx
        push    bx
        mov     bx, 1			; indicate final copy

	mov	ptr_data_ptr.segm,es
	mov	ptr_data_ptr.offs,di
	mov	ptr_data_ptr.len,cx
	movseg	es,cs
	mov	si,offset cgroup:ptr_data_buff
	mov	bp,offset cgroup:asinfo
  if VERBOSE_HEXOUT
	mov	al,'Z'
	call	hexout_char
  endif

	xor	ax,ax			;offset is zero.
	call	LM_Receive_Copy
  if VERBOSE_HEXOUT
	mov	al,'z'
	call	hexout_char
  endif

	cld
	pop	bx
	pop	cx
	pop	si
	pop	ds
	assume	ds:nothing

	cmp	ax,SUCCESS		;;; but what can we do??

  if VERBOSE_HEXOUT
	mov	al,'C'
	call	hexout_char
	mov	ax,cx
	call	hexout_word
	mov	al,'='
	call	hexout_char
  endif

	push	bp			;pdipx screws BP!  LMAC relies on BP!
	call	recv_copy
	pop	bp

  if VERBOSE_HEXOUT
	mov	al,'c'
	call	hexout_char
  endif
	jmp	short recv_free

recv_err:
	call	count_in_err
recv_discard:
  if VERBOSE_HEXOUT
	mov	al,'d'
	call	hexout_char
  endif
recv_free:
	movseg	ds,cs
	assume	ds:cgroup
  if VERBOSE_HEXOUT
	mov	al,'s'
	call	hexout_char
  endif
	mov	ax,SUCCESS

	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	es
	popf
	ret

	public	um_receive_copy_complete, _um_receive_copy_complete
um_receive_copy_complete:
_um_receive_copy_complete:
	mov	ax,SUCCESS
	ret

	public	um_status_change, _um_status_change
um_status_change:
_um_status_change:
  if VERBOSE_HEXOUT
	mov	al,'S'
	call	hexout_char
	mov	ax,asinfo.adapter_status
	call	hexout_word
  endif
  ifdef PCMCIA
	mov	ax,asinfo.adapter_status
	cmp	ax,CARD_REMOVED
	jne	um_status_change_1
	mov	ax,SUCCESS
	ret
um_status_change_1:
	cmp	ax,CARD_INSERTED
	jne	um_status_change_2
	call	reinitialize
	ret
um_status_change_2:
  endif
	mov	ax,SUCCESS
	ret

	public	um_send_complete, _um_send_complete
um_send_complete:
_um_send_complete:
	mov	ax,SUCCESS
	ret
	public	um_interrupt, _um_interrupt
um_interrupt:
_um_interrupt:
	mov	ax,SUCCESS
	ret
	public	um_ringstatus_change, _um_ringstatus_change
um_ringstatus_change:
_um_ringstatus_change:
	mov	ax,SUCCESS
	ret

  if VERBOSE_HEXOUT
	include	hexout.asm
  endif

  ifdef PCMCIA
	public	UM_Card_Services, _UM_Card_Services
UM_Card_Services:
_UM_Card_Services:
	int	1ah
	ret

  endif

reinitialize:
  ifdef TOKEN_RING
	mov	asinfo.ptr_ucode.offs,offset cgroup:ucode
	mov	asinfo.ptr_ucode.segm,cs
	mov	bp,offset cgroup:asinfo
	call	LM_Load_Microcode
	cmp	ax,SUCCESS
	jne	reinitialize_1
  endif
	mov	bp,offset cgroup:asinfo
	mov	dx,cs
	mov	ax,offset cgroup:scratchpad
	call	LM_Initialize_Adapter
	cld
	cmp	ax,SUCCESS
	jne	reinitialize_1

;;;	call	set_recv_isr		;take over our interrupt and enable it.

	movseg	es,ds			;we've now gotten our Ethernet address.
	mov	di,offset cgroup:rom_address
	mov	si,offset cgroup:asinfo.node_address
	cld
	repmov	EADDR_LEN

	call	LM_Open_Adapter
	cld
	cmp	ax,SUCCESS
	mov	dx,offset cgroup:open_fail_msg
	jne	reinitialize_1
	sti
reinitialize_2:
	cmp	asinfo.adapter_status,OPEN
	jne	reinitialize_2
	clc
	ret
reinitialize_1:
	stc
	ret


code	ends

init	segment para public 'code'
	assume	cs:cgroup, ds:cgroup

;any code after this will not be kept.  Buffers used by the program, if any,
;are allocated from the memory between end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
end_free_mem	label	byte

	public	usage_msg
usage_msg	label	byte
  ifdef PKT8432
db "usage: ",DR_COM," [options] <packet_int_no>",CR,LF,'$'
  else
  ifdef PKT8016
db "usage: ",DR_COM," [options] <packet_int_no>",CR,LF,'$'
  else
  ifdef PKTEISA
db "usage: ",DR_COM," [options] <packet_int_no> [<slot_num>]",CR,LF,'$'
  else
  ifdef PKT8000
db "usage: ",DR_COM," [options] <packet_int_no> [<io_addr> <int_no> <mem_addr>]",CR,LF
db "     or, on Microchannel machines:",CR,LF
db "usage: ",DR_COM," [options] <packet_int_no> [<slot_num>]",CR,LF,'$'
  else
  ifdef PKT8115
db "usage: ",DR_COM," [options] <packet_int_no> [<io_addr> <int_no> <mem_addr>]",CR,LF,'$'
  else
err	missing definition for this driver.
  endif
  endif
  endif
  endif
  endif

	db	"@(#) "		;required for SMC's getver program.
	public	copyright_msg
copyright_msg	db	"Packet driver for ",DR_NAME," adapters, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+umac_version,".",'0'+version,CR,LF
		db	"Portions Copyright 1994, Standard Microsystems Corporation",CR,LF,'$'

slot_no	dw	-1,0

pcmcia_vendor	db	256 dup(?)
pcmcia_vendor_len	equ	$ - pcmcia_vendor

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

	public	parse_args
parse_args:
;parse_args is called with si -> first parameter (CR if none).
;exit with nc if all went well, cy otherwise.
  ifdef PKT8016
  else
  ifdef PKTEISA
	mov	di,offset cgroup:slot_no
	call	get_number
  else
	test	sys_features,SYS_MCA	;if this is MCA, we only need slot #.
	jne	parse_args_1

	mov	di,offset cgroup:io_addr
	call	get_number
	mov	di,offset cgroup:int_no
	call	get_number
	mov	di,offset cgroup:mem_base
	call	get_number
	jmp	short parse_args_2
parse_args_1:
	mov	di,offset cgroup:slot_no
	call	get_number
parse_args_2:
  endif
  endif
	clc
	ret

	extrn	is_eisa: byte		;=0 if ISA, =1 if EISA
	extrn	sys_features: byte
	extrn	wordout: near

	public	etopen
etopen:
;initialize the driver.  Fill in rom_address with the assigned address of
;the board.  Exit with nc if all went well, or cy, dx -> $ terminated error msg.
;if all is okay,
	mov	ax,EISA_BUS
	cmp	is_eisa,0
	jne	etopen_1
	mov	ax,MCA_BUS
	test	sys_features,SYS_MCA
	jne	etopen_1
	mov	ax,AT_BUS
etopen_1:
  ifdef PKT8016
	mov	al,PCMCIA_BUS
  endif
	mov	asinfo.pc_bus,al

	mov	ax,io_addr
	mov	asinfo.io_base,ax

	mov	al,int_no
	xor	ah,ah
	mov	asinfo.irq_value,ax

	mov	ax,mem_base
	xor	dx,dx
	shl	ax,1
	rcl	dx,1
	shl	ax,1
	rcl	dx,1
	shl	ax,1
	rcl	dx,1
	shl	ax,1
	rcl	dx,1
	mov	asinfo.ram_base.offs,ax
	mov	asinfo.ram_base.segm,dx
	mov	asinfo.ram_size,8	;;;default to the minimum we know we have.
	mov	asinfo.ram_usable,8	;;;default to the minimum we know we have.

	mov	ax,slot_no
	mov	asinfo.slot_num,al

  ifdef TOKEN_RING
	mov	asinfo.max_packet_size,4178
	mov	asinfo.num_of_tx_buffs,2
  endif
  ifdef ETHERNET
	mov	asinfo.max_packet_size,GIANT
	mov	asinfo.num_of_tx_buffs,1
  endif

	cmp	asinfo.pc_bus,PCMCIA_BUS
	je	etopen_noscan
  ifdef PKTEISA
	cmp	asinfo.pc_bus,EISA_BUS	;we only look at slots on a board that
	je	etopen_slot		;  knows about slots.
  endif
	cmp	asinfo.pc_bus,MCA_BUS
	je	etopen_slot
etopen_io:
	cmp	asinfo.io_base,-1
	jne	etopen_noscan
	mov	asinfo.io_base,200h	;try the first one.
etopen_io_scan:
	call	detect_smc
	jnc	etopen_found
	add	asinfo.io_base,20h	;try the next one.
	cmp	asinfo.io_base,400h
	jb	etopen_io_scan
	jmp	etopen_failed	;the error message is already correct.

etopen_slot:
	cmp	asinfo.slot_num,-1
	jne	etopen_noscan
	mov	asinfo.slot_num,0	;try the first one.
etopen_slot_scan:
	call	detect_smc
	jnc	etopen_found
	inc	asinfo.slot_num		;try the next one.
	cmp	asinfo.slot_num,16
	jb	etopen_slot_scan
	jmp	short etopen_failed	;the error message is already correct.

etopen_noscan:
	call	detect_smc		;only try the one they named.
	jc	etopen_failed		;if it didn't work, we're dead.

etopen_found:
	mov	al,asinfo.slot_num
	xor	ah,ah
	mov	slot_no,ax
	mov	ax,asinfo.io_base
	mov	io_addr.offs,ax
	mov	io_addr.segm,0
	mov	asinfo.receive_mask,0	;receive mine only (for now).

  if VERBOSE_HEXOUT
	mov	al,'I'
	call	hexout_char
  endif
	call	set_recv_isr		;take over our interrupt and enable it.

  if VERBOSE_HEXOUT
	mov	al,'R'
	call	hexout_char
  endif
	call	reinitialize
	jc	initialize_errors

	ret
etopen_failed:
;exit with dx -> error message.
	stc
	ret

initialize_errors:
  ifdef TOKEN_RING
	cmp	ax, UCODE_NOT_PRESENT
	mov	dx, offset cgroup:MicrocodeMsg
	jz	check_return
  endif
	cmp	ax, SELF_TEST_FAILED
	mov	dx, offset cgroup:SelfTestMsg
	jz	check_return

	cmp	ax, RAM_TEST_FAILED
	mov	dx, offset cgroup:RamFailureMsg
	jz	check_return

	cmp	ax, RAM_CONFLICT
	mov	dx, offset cgroup:RamConflictMsg
	jz	check_return

	cmp	ax, ROM_CONFLICT
	mov	dx, offset cgroup:RomConflictMsg
	jz	check_return

	mov	dx, offset cgroup:AdapterDeadMsg

check_return:
	stc
	ret


detect_smc:
  if VERBOSE_HEXOUT
	mov	al,'G'
	call	hexout_char
  endif
	mov	bp,offset cgroup:asinfo
	movseg	es,ds
	mov	si,offset cgroup:pcmcia_vendor
	mov	cx,pcmcia_vendor_len
	call	LM_GetCnfg
	cld
	cmp	ax,CONFIG_WARNING	;our defaults didn't match (so what??)
	je	etopen_2
	cmp	ax,ADAPTER_AND_CONFIG	;defaults matched -- yay!
	je	etopen_2
	cmp	ax,ADAPTER_NO_CONFIG	;this adapter cannot be software configured,
	je	etopen_2		;  so we'll have to rely on cmdline.
	jmp	getcnfg_errors
etopen_2:
	mov	ax,asinfo.irq_value
	mov	int_no,al
	mov	dx,asinfo.ram_base.segm
	mov	ax,asinfo.ram_base.offs
	shr	dx,1
	rcr	ax,1
	shr	dx,1
	rcr	ax,1
	shr	dx,1
	rcr	ax,1
	shr	dx,1
	rcr	ax,1
	mov	mem_base,ax
	mov	asinfo.ram_access.segm,ax
	clc
	ret

getcnfg_errors:
        cmp     ax, EEROM_CKSUM_ERROR
        jne     check_config
        mov     dx, offset cgroup:EEROMBadMsg
	stc
        ret

check_config:
        cmp     ax, CONFIG_ERROR
	je	list_errors
;must be UNKNOWN_ADAPTER
	mov	dx,offset cgroup:NoBoardFoundMsg
	stc
	ret

list_errors:
        mov     ax, dx
        test    ax, IO_BASE_INVALID
        mov     dx, offset cgroup:IOBaseInvalidMsg
        jnz     list_error_end

        test    ax, IO_BASE_RANGE
        mov     dx, offset cgroup:IOBaseRangeMsg
        jnz     list_error_end

PrtErrBaseRng:
        test    ax, IRQ_INVALID
        mov     dx, offset cgroup:IRQInvalidMsg
        jnz     list_error_end

PrtErrIRQInv:
        test    ax, IRQ_RANGE
        mov     dx, offset cgroup:IRQRangeMsg
        jnz     list_error_end

PrtErrIRQRange:
        test    ax, RAM_BASE_INVALID
        mov     dx, offset cgroup:RamBaseInvalidMsg
        jnz     list_error_end

PrtErrRamBaseInv:
        test    ax, RAM_BASE_RANGE
        mov     dx, offset cgroup:RamBaseRangeMsg
        jnz     list_error_end

PrtErrRamBaseRange:
        test    ax, RAM_SIZE_RANGE
        mov     dx, offset cgroup:RamSizeRangeMsg
        jnz     list_error_end

PrtErrRamBaseSize:
        mov     dx, offset cgroup:AdapterDeadMsg

list_error_end:
	stc
	ret


	public	print_parameters
print_parameters:
	mov	dx,offset cgroup:name_name
	mov	ah,9
	int	21h
	mov	si,offset cgroup:asinfo.adapter_name
print_parameters_0:
	lodsb
	extrn	chrout: near
	call	chrout
	or	al,al
	jne	print_parameters_0
	extrn	crlf: near
	call	crlf
  ifndef PKT8016
	mov	di,offset cgroup:io_addr
	mov	dx,offset cgroup:io_addr_name
	call	print_number
  endif
	mov	di,offset cgroup:int_no
	mov	dx,offset cgroup:int_no_name
	call	print_number
	mov	di,offset cgroup:mem_base
	mov	dx,offset cgroup:mem_base_name
	call	print_number
  ifdef PKTEISA
	cmp	asinfo.pc_bus,EISA_BUS
	je	print_parameters_slot
  endif
	cmp	asinfo.pc_bus,MCA_BUS
	jne	print_parameters_noslot
print_parameters_slot:
	mov	di,offset cgroup:slot_no
	mov	dx,offset cgroup:slot_no_name
	call	print_number
print_parameters_noslot:

  ifdef PKT8016
	mov	dx,offset cgroup:media_bnc_utp_msg
  else
;tell them what connector we're using.
	mov	si,offset cgroup:media_type_names
print_parameters_1:
	lodsw
	cmp	ax,asinfo.media_type	;is this one it?
	je	print_parameters_3	;yes.
	cmp	ax,-1			;is it the end of the list?
	je	print_parameters_3	;yes, match anyway.
print_parameters_2:
	lodsb				;skip to the next media type.
	cmp	al,'$'
	jne	print_parameters_2
	jmp	print_parameters_1
print_parameters_3:
	mov	dx,si			;print the message that si points to.
  endif
	mov	ah,9
	int	21h

	ret

name_name	label	byte
  ifdef TOKEN_RING
		db	"Frame type: Token Ring (class 3)",CR,LF
  endif
  ifdef ETHERNET
		db	"Frame type: Ethernet II (class 1), IEEE 802.3 (class 11)",CR,LF
  endif
		db	"Adapter: ",'$'
slot_no_name	db	"Slot number ",'$'
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
mem_base_name	db	"Memory address ",'$'

  ifdef ETHERNET
media_type_names	label	byte
	dw	MEDIA_S10
	db	"Ethernet adapter, TP.",CR,LF,'$'
	dw	MEDIA_AUI_UTP
	db	"Ethernet adapter, AUI/UTP media.",CR,LF,'$'
	dw	MEDIA_BNC
	db	"Ethernet adapter, BNC media.",CR,LF,'$'
	dw	MEDIA_AUI
	db	"Ethernet adapter, AUI media.",CR,LF,'$'
	dw	MEDIA_UTP
	db	"Ethernet adapter, UTP media (no AUI).",CR,LF,'$'
	dw	MEDIA_BNC_UTP
media_bnc_utp_msg	label	byte
	db	"Ethernet adapter, BNC/UTP media ",CR,LF,'$'
  endif
  ifdef TOKEN_RING
media_type_names	label	byte
	dw	MEDIA_STP_16
	db	"TokenRing adap, 16Mbit STP.",CR,LF,'$'
	dw	MEDIA_STP_4
	db	"TokenRing adap, 4Mbit STP.",CR,LF,'$'
	dw	MEDIA_UTP_16
	db	"TokenRing adap, 16Mbit UTP.",CR,LF,'$'
	dw	MEDIA_UTP_4
	db	"TokenRing adap, 4Mbit UTP.",CR,LF,'$'
  endif
	dw	MEDIA_UNKNOWN
	db	"Unknown adapter/media type",CR,LF,'$'
	dw	-1
	db	"*** can't happen! ***",CR,LF,'$'


  IFDEF ETHERNET
NoBoardFoundMsg		db	"Could not find an Ethernet adapter.", CR,LF, '$'
  ENDIF
  IFDEF TOKEN_RING
NoBoardFoundMsg		db	"Could not find a TokenCard adapter.", CR,LF, '$'
  ENDIF
AdapterDeadMsg		db	"Adapter hardware failure detected (initialization).", CR,LF, '$'
SelfTestMsg		db	"Adapter hardware failure detected (self-test).", CR,LF, '$'
EEROMBadMsg		db	"Configuration corrupted; run software setup.", CR,LF, '$'
  IFDEF TOKEN_RING
InsertFailMsg		db	"Adapter unable to insert into the network.", CR,LF, '$'
MicrocodeMsg		db	"Adapter not initialized by TRINIT utility.", CR,LF, '$'
  ELSE
;InsertFailMsg		db	"Adapter hardware failure detected during initialization.", CR,LF, '$'
  ENDIF
RamConflictMsg		db	"Other system RAM already occupies adapter RAM.", CR,LF, '$'
RomConflictMsg		db	"Other system ROM already occupies adapter RAM.", CR,LF, '$'
IOBaseInvalidMsg	db	"I/O base address chosen for driver not valid (illegal boundary).",CR,LF,'$'
IOBaseRangeMsg		db	"I/O base address chosen for driver not valid (out of range).",CR,LF,'$'
;IRQMismatchMsg		db	"IRQ chosen for driver does not match adapter configuration.",CR,LF,'$'
IRQInvalidMsg		db	"Adapter IRQ higher than 7 not valid in 8-bit slot.",CR,LF,'$'
IRQRangeMsg		db	"IRQ chosen for adapter not valid (out of range).",CR,LF,'$'
RamFailureMsg		db	"Cannot access adapter RAM properly.", CR,LF, '$'
RamBaseInvalidMsg	db	"Adapter RAM base address on illegal boundary.",CR,LF,'$'
RamBaseRangeMsg		db	"RAM base address chosen for driver not valid (out of range).",CR,LF,'$'
RamSizeRangeMsg		db	"RAM size chosen for driver not valid (out of range).",CR,LF,'$'
;RamBaseMismatchMsg	db	"RAM base address chosen for driver does not match adapter configuration.",CR,LF,'$'
;RamSizeMismatchMsg	db	"RAM size chosen for driver does not match adapter configuration.",CR,LF,'$'
open_fail_msg		db	"Failed to successfully open the adapter",CR,LF,'$'

init	ends

	end

