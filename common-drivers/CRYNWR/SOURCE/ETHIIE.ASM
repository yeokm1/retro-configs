version	equ	0
;History:254,1

;  The following people have contributed to this code: David Horne, Eric
;  Henderson, and Bob Clements.
;
;  This packet driver for Nokia Data Ethernet IIe adapter is based
;  on the NE2000 driver.  Adaptation was made by Markku Toijala and
;  Markku Viima, Nokia Data Systems Oy, Helsinki, Finland.

;  Copyright, 1988-1992, Russell Nelson, Crynwr Software

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
;

	include	defs.asm

code	segment	word public
	assume	cs:code, ds:code

;*****************************************************************************
;
;	Nokia Data Ethernet IIe controller board offsets
;	IO port definition (BASE in io_addr)
;*****************************************************************************

ND_DATAPORT	EQU	400h		; ETHIIE Port Window.
ND_INTF_REG	EQU	402h		; ETHIIE Status Setup Register
EN_OFF		equ	0h

ND_SOFT_RESET	equ	20h		; bitmask for RESET bit
ND_INTF_BNC	equ	00h		; BNC (or TP) interface used
ND_INTF_DIX	equ	40h		; DIX interface used
ND_INTF_ROM	equ	80h		; ROM disable.


	include	8390.inc

;*****************************************************************************
;
;	Nokia Data EtherNet IIe controller RAM (16 kbytes) is 
;	organized into Transmit and Receive areas as:
;*****************************************************************************

SM_TSTART_PG	equ	00h	; First page of TX buffer
SM_RSTART_PG	equ	06h	; Starting page of RX ring
SM_RSTOP_PG	equ	40h	; Last page +1 of RX ring

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
	setport	ND_INTF_REG
	in	al,dx			; read current value
	or	al,ND_SOFT_RESET 	; set RESET bit in reg.
	out	dx,al			; And write register
	longpause
	xor	al,ND_SOFT_RESET 	; Reset RESET bit in reg.
	out	dx,al			; Write back
	longpause

;-----
; Set IRQ Selection according to Interrupt Number.
;-----
		loadport
		setport ND_INTF_REG
		mov	al,int_no
		mov	ah,01h				; Suppose IRQ5.
		cmp	al,05				; But is really?
		je	int_ok				; Yes, skip over.
		mov	ah,02				; Suppose IRQ2/9.
		cmp	al,09				; But is really?
		je	int_ok				; Yes, skip over.
		mov	ah,04				; Suppose IRQ12.
		cmp	al,12				; But is really?
		je	int_ok				; Yes, skip over. 
		mov	ah,08h				; Suppose IRQ15.
int_ok:
;-----
; Add Transceiver Bit and write interface register.
;-----
	cmp	byte ptr thin_not_thick,00 ; Now set the interface
	jz	set_dix			   ; Jump if thick
	mov	al,ND_INTF_BNC		   ; Select BNC interface.
	jmp	short addxcv		   ;
set_dix:
	mov	al,ND_INTF_DIX		   ; Select DIX interface.
addxcv:	
	add	al,ah			   ; combine with interrupt
	out	dx,al			   ; and write to the card
	endm

terminate_board	macro
	endm

	public	int_no, io_addr,thin_not_thick
int_no		db	2,0,0,0		;must be four bytes long for get_number.
io_addr		dw	0300h,0		; I/O address for card (jumpers)
thin_not_thick	dw	1,0		; Non-zero means thin net

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	dw	86		;from the packet spec
driver_name	db	'ETHIIE',0	;name of the driver.
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

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[123]86.

;
;	Block input routine
;	CX = byte count, es:di = buffer location, ax = buffer address

	public	block_input
block_input:
	push	ax		; save buffer address
	loadport
	setport EN_CCMD
	pause_
	mov	al,ENC_NODMA+ENC_PAGE0+ENC_START
	out	dx,al
	setport	EN0_RCNTLO	; remote byte count 0
	pause_
	mov	al,cl
	out	dx,al
	setport	EN0_RCNTHI
	pause_
	mov	al,ch
	out	dx,al
	pop	ax		; get our page back
	setport	EN0_RSARLO
	pause_
	out	dx,al		; set as hi address
	setport	EN0_RSARHI
	pause_
	mov	al,ah
	out	dx,al
	setport EN_CCMD
	pause_
	mov	al,ENC_RREAD+ENC_START	; read and start
	out	dx,al
	setport	ND_DATAPORT
	pause_
	cmp	is_186,0
	jnz	read_186
read_loop:
	in	al,dx		; get a byte
	stosb			; save it
	loop	read_loop
	ret
read_186:
	shr	cx,1		; word count
	.286
	rep	insw
	.8086
	jnc	read_186_1
	in	ax,dx		; get the remaining byte.
	stosb
read_186_1:
	ret
;
;	Block output routine
;	CX = byte count, ds:si = buffer location, ax = buffer address

block_output:
	assume	ds:nothing
	push	ax		; save buffer address
	loadport
	setport EN_CCMD
	pause_
	mov	al,ENC_NODMA+ENC_START
	out	dx,al		; stop & clear the chip
	setport	EN0_RCNTLO	; remote byte count 0
	pause_
	mov	al,cl
	out	dx,al
	setport	EN0_RCNTHI
	pause_
	mov	al,ch
	out	dx,al
	pop	ax		; get our page back
	setport	EN0_RSARLO
	pause_
	out	dx,al		; set as lo address
	setport	EN0_RSARHI
	pause_
	mov	al,ah
	out	dx,al
	setport EN_CCMD
	pause_
	mov	al,ENC_RWRITE+ENC_START	; write and start
	out	dx,al
	setport	ND_DATAPORT
	pause_
	cmp	is_186,0
	jnz	write_186
write_loop:
	lodsb			; get a byte
	out	dx,al		; save it
	loop	write_loop
	jmp	short block_output_1
write_186:
	inc	cx		; round up
	shr	cx,1		; word count
	.286
	rep	outsw
	.8086
block_output_1:
	mov	cx,0
	setport	EN0_ISR
tx_check_rdc:
	in	al,dx
	test	al,ENISR_RDC	; dma done ???
	jnz	tx_start
	loop	tx_check_rdc
	stc
	ret
tx_start:
	clc
	ret

	include	8390.asm
	.LIST

	public	usage_msg
usage_msg	db	"usage: ETHIIE [options] <packet_int_no> <hardware_irq> <io_addr> <thin_net>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for ICL EtherTeam16, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+dp8390_version,CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

thin_msg	db	"Using the built-in transceiver (thinwire)",CR,LF,'$'
thick_msg	db	"Using the external transceiver (thickwire)",CR,LF,'$'

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	mov	di,offset thin_not_thick	; May override thick/thin cable flag
	call	get_number
	clc
	ret

	extrn	etopen_diagn: byte

init_card:
;get the board data. This is (16) bytes starting at remote
;dma address 8000h. Put it in a buffer called board_data.
	assume	ds:code

	or	endcfg,ENDCFG_WTS

	loadport
	mov	al,endcfg
	setport	EN0_DCFG
	pause_
	out	dx,al

	mov	cx,10h		; get 16 bytes,
	movseg	es,ds
	mov	di,offset board_data

	setport EN_CCMD
	pause_
	mov	al,ENC_NODMA+ENC_PAGE0+ENC_START
	out	dx,al
	setport	EN0_RCNTLO	; remote byte count 0
	pause_
	mov	al,20h		; count is actually doubled.
	out	dx,al
	setport	EN0_RCNTHI
	pause_
	xor	al,al		; high byte of count is zero.
	out	dx,al

	mov	ax,8000h	; from address 0

	setport	EN0_RSARLO
	pause_
	out	dx,al		; set as hi address
	setport	EN0_RSARHI
	pause_
	mov	al,ah
	out	dx,al
	setport EN_CCMD
	pause_
	mov	al,ENC_RREAD+ENC_START	; read and start
	out	dx,al
	loadport
	setport	ND_DATAPORT
	pause_
sp_read_loop:
	in	ax,dx		; get a byte
	stosb			; save it
	loop	sp_read_loop

	push    ds              ; Copy from card's address to current address
	pop     es

	mov si, offset board_data	; address is at start
	mov di, offset rom_address
	mov cx, EADDR_LEN       ; Copy one address length
	rep     movsb           ; ..

	clc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	mov	dx,offset thin_msg
	cmp	thin_not_thick,0	; May override thick/thin cable flag
	jne	print_parameters_1
	mov	dx,offset thick_msg
print_parameters_1:
	mov	ah,9
	int	21h
	ret

code	ends

	end
