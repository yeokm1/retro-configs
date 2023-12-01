;*****************************************************************************
;* Name : DAVICOM.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description :
;*
;* Functions :
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96'
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
; 2000.1.31	htho	background debug
;*
;*****************************************************************************
.model tiny
.386

	include defs.asm

code	segment para public
	assume	cs:code, ds:code
;;++, 2000.1.31, hu-tiong
;IFDEF	 DEBUGDOS
include debug.inc
;ENDIF	 ;-- DEBUGDOS
;;++

;*****************************************************************************
;
;	UM9008 controller board offsets
;	IO port definition (BASE in io_addr)
;*****************************************************************************
NE_DATAPORT	EQU	10h		; UM9008 Port Window.
NE_RESET	EQU	1fh		; Issue a read for reset
EN_OFF		equ	0h

;;	  include 9100.inc

; Shared memory management parameters

SM_TSTART_PG	equ	040h	; First page of TX buffer
SM_RSTART_PG	equ	046h	; Starting page of RX ring
SM_RSTOP_PG	equ	080h	; Last page +1 of RX ring

pause_	macro
;	jmp	$+2
;
; The reason for the pause_ macro is to establish a minimum time between
; accesses to the card hardware. The assumption is that the fetch and execution
; of the jmp $+2 instruction will provide this time. In a fast cache machine
; this may be a false assumption. In a fast cache machine, there may be
; NO REAL TIME DIFFERENCE between the two I/O instruction streams below:
;
;	in	al,dx		in	al,dx
;	jmp	$+2
;	in	al,dx		in	al,dx
;
; To establish a minimum delay, an I/O instruction must be used. A good rule of
; thumb is that ISA I/O instructions take ~1.0 microseconds and MCA I/O
; instructions take ~0.5 microseconds. Reading the NMI Status Register (0x61)
; is a good way to pause on all machines.
;
; The National 8390 Chip (NIC) requires 4 bus clocks between successive
; chip selects (National DP8390 Data Sheet Addendum, June 1990 -- it took them
; long enough to figure this out and tell everyone) or the NIC behaves badly.
; Therefor one I/O instruction should be inserted between each successive
; NIC I/O instruction that could occur 'back - to - back' on a fast cache
; machine.
;   - gft - 910529
;
	push	ax
	in	al, 61h
	pop	ax
;
endm

reset_8390	macro
	loadport
	setport NE_RESET
	in	al,dx
	longpause
	out	dx,al		; should set command 21, 80

	endm

terminate_board macro
	endm

	public	int_no, io_addr
int_no		db	2,0,0,0 	;must be four bytes long for get_number.
io_addr 	dw	6100h,0 	; I/O address for card (jumpers)

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	dw	0FFFFh		    ;from the packet spec
driver_name	db	'DM9PKT$',0      ;name of the driver.
driver_function db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

;
;	Block input routine
;	CX = byte count, es:di = buffer location, ax = buffer address

	public	block_input
block_input:
.386
	push	eax
	push	bx
	push	dx		;; test

	mov	bx, cx
	push	cs
	pop	ds
	mov	si, ax
	shr	cx, 2
blockin_loop:
	movsd
	loop	blockin_loop
	and	bx, 03h
	cmp    bx, 0
	je	blockin_exit
	mov	cx, bx
blockin_ext_loop:
	movsb
	loop	blockin_ext_loop
blockin_exit:
;;	  mov	  dl, 0 	 ;; test
;;	  mov	  bx, ax
;;	  mov	  eax, [bx+38]
;;	  cli
;;	  call	  printcur
;;	  sti
	pop	dx
	pop	bx
	pop	eax
	ret

	include Printcur.asm
	include Printdig.asm
	include 9100.asm

;;--- Loading time messages
	public	copyright_msg
copyright_msg	db	"Packet driver for DAVICOM DM9PCI Series Ethernet Adapter, version "
		db	'0'+majver,".",'0'+version,".",'0'+dm9100_version,CR,LF,'$'

	public	branding_msg
branding_msg	db	'$'

	public	usage_msg
;; -+, 980303, Hu-Tiong
;;usage_msg	  db	  "usage: DM9PCIPD [options] <packet_int_no> [<int_level> <io_addr>]",CR,LF,'$'
usage_msg	db	"usage: DM9PCIPD [options] <packet_int_no>",CR,LF,'$'
;;-+

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

;-------------------------------------------------------------
; parse_args
;	Save the number of interrupt to "int_no" &
;	save the base of I/O address to "io_addr".
;-------------------------------------------------------------
	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no
	call	get_number		;; Return DI
	mov	di,offset io_addr
	call	get_number
	clc
	ret

	extrn	etopen_diagn: byte

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

code	ends

	end
