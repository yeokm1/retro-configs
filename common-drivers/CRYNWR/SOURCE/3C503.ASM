;History:2,18
version	equ	6

	include	defs.asm

;/* PC/FTP Packet Driver source, conforming to version 1.05 of the spec,
;*  for the 3-Com 3C503 interface card.
;*  Robert C Clements, K1BC, 14 February, 1989
;*  Portions (C) Copyright 1988, 1989 Robert C Clements
;*
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

code	segment	word public
	assume	cs:code, ds:code

; Stuff specific to the 3-Com 3C503 Ethernet controller board
; WD version in C by Bob Clements, K1BC, May 1988 for the KA9Q TCP/IP package
; 3Com version based on WD8003E version in .ASM, also by Bob Clements, dated
;  19 August 1988.  The WD and 3Com cards both use the National DS8390.

; Symbol prefix "EN" is for Ethernet, National chip
; Symbol prefix "E33" is for _E_thernet, _3_Com 50_3_
; Symbol prefix "E33G" is for registers in the Gate array ASIC.

; The E33 registers - For the ASIC on the 3C503 card:
; Offsets from the board's base address, which can be set by
; jumpers to be one of the following 8 values (hex):
;  350, 330, 310, 300, 2E0, 2A0, 280, 250
; Factory default address is 300H.
; The card occupies a block of 16 I/O addresses.
; It also occupies 16 addresses at base+400 through base+40F.
; These high-addressed registers are in the ASIC.
; Recall that the normal PC I/O decoding is only 10 bits. The 11'th
; bit (400H) can be used on the same card for additional registers.
; This offset requires word, not byte, arithmetic
; on the DX register for the setport macro. Current SETPORT is OK.

; The card can also be jumpered to have the shared memory disabled
; or enabled at one of four addresses: C8000, CC000, D8000 or DC000.

; The card can be operated using direct I/O instructions or by
; using the PC's DMA channels instead of the shared memory.  We don't
; use DMA because it's slow on an AT.

; Blocks of I/O addresses:

E33GA		equ	400h	; Registers in the gate array.
E33_SAPROM	equ	000h	; Window on station addr prom (if
				; E33G_CNTRL bits 3,2 = 0,1

; These appear at Base+0 through Base+0F when bits 3,2 of
; E33G_CNTRL are 0,0.

EN_OFF		equ	0h

ENDCFG_BM8	equ	48h

	include	8390.inc

; Registers in the 3-Com custom Gate Array

E33G_STARTPG	equ E33GA+00h	; Start page, must match EN0_STARTPG
E33G_STOPPG	equ E33GA+01h	; Stop  page, must match EN0_STOPPG
E33G_NBURST	equ E33GA+02h	; Size of DMA burst before relinquishing bus
E33G_IOBASE	equ E33GA+03h	; Bit coded: where I/O regs are jumpered.
				; (Which you have to know already to read it)
E33G_ROMBASE	equ E33GA+04h	; Bit coded: Where/whether EEPROM&DPRAM exist
E33G_GACFR	equ E33GA+05h	; Config/setup bits for the ASIC GA
E33G_CNTRL	equ E33GA+06h	; Board's main control register
E33G_STATUS	equ E33GA+07h	; Status on completions.
E33G_IDCFR	equ E33GA+08h	; Interrupt/DMA config register
				; (Which IRQ to assert, DMA chan to use)
E33G_DMAAH	equ E33GA+09h	; High byte of DMA address reg
E33G_DMAAL	equ E33GA+0ah	; Low byte of DMA address reg
E33G_VP2	equ E33GA+0bh	; Vector pointer - for clearing RAM select
E33G_VP1	equ E33GA+0ch	;  on a system reset, to re-enable EPROM.
E33G_VP0	equ E33GA+0dh	;  3Com says set this to Ctrl-Alt-Del handler
E33G_FIFOH	equ E33GA+0eh	; FIFO for programmed I/O data moves ...
E33G_FIFOL	equ E33GA+0fh	; .. low byte of above.

; Bits in E33G_CNTRL register:

ECNTRL_RESET	equ	001h	; Software reset of the ASIC and 8390
ECNTRL_THIN	equ	002h	; Onboard thin-net xcvr enable
ECNTRL_SAPROM	equ	004h	; Map the station address prom
ECNTRL_DBLBFR	equ	020h	; FIFO configuration bit
ECNTRL_OUTPUT	equ	040h	; PC-to-3C503 direction if 1
ECNTRL_INPUT	equ	000h	; PC-to-3C503 direction if 0
ECNTRL_START	equ	080h	; Start the DMA logic

; Bits in E33G_STATUS register:

ESTAT_DPRDY	equ	080h	; Data port (of FIFO) ready
ESTAT_UFLW	equ	040h	; Tried to read FIFO when it was empty
ESTAT_OFLW	equ	020h	; Tried to write FIFO when it was full
ESTAT_DTC	equ	010h	; Terminal Count from PC bus DMA logic
ESTAT_DIP	equ	008h	; DMA In Progress

; Bits in E33G_GACFR register:

EGACFR_NORM	equ	049h	; Enable 8K shared mem, no DMA TC int
EGACFR_EPROM	equ	041h	; Disable 8K shared mem.
EGACFR_IRQOFF	equ	0c9h	; Above, and disable 8390 IRQ line

; Shared memory management parameters

SM_TSTART_PG	equ	020h	; First page of TX buffer
SM_RSTART_PG	equ	026h	; Starting page of RX ring
SM_RSTOP_PG	equ	040h	; Last page +1 of RX ring

; End of 3C503 parameter definitions

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

ram_enable	macro
	setport	E33G_GACFR	; Make sure gate array is set up and
	mov al,	EGACFR_NORM	;  the RAM is enabled (not EPROM)
	out dx,	al		; ..
	endm

rom_enable	macro
	setport	E33G_GACFR	; Make sure gate array is set up and
	mov al,	EGACFR_EPROM	;  the EPROM is enabled (not RAM)
	out dx,	al		; ..
	endm

reset_8390	macro
	loadport		; First, pulse the board reset
	setport	E33G_CNTRL
	mov	al,thin_bit		; Thick or thin cable bit
	or	al,ECNTRL_RESET
	out	dx,al			; Turn on board reset bit
	mov	al,thin_bit		; Thick or thin cable bit
	out	dx,al			; Turn off board reset bit
	call	do_reset
	loadport
	endm

terminate_board	macro
	endm

; The following three values may be overridden from the command line.
; If they are omitted from the command line, these defaults are used.
; The shared memory base is set by a jumper.  We read it from the
; card and set up accordingly.

	public	int_no, io_addr, thin_not_thick
int_no		db	2,0,0,0		; Interrupt level
io_addr		dw	0300h,0		; I/O address for card (jumpers)
thin_not_thick	dw	-1,-1		; -1 means auto, non-zero means thin net
	public	mem_base
mem_base	dw	00000h,0	; Shared memory addr (jumpers)
; (Not changeable by software in 3C503)	; (0 if disabled by jumpers)
thin_bit	db	0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	12		;from the packet spec
driver_name	db	'3C503',0	;name of the driver.
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

	extrn	is_186: byte		;=0 if 808[68], =1 if 80[1234]86.
	extrn	is_286: byte		;=0 if 808[68], =1 if 80[234]86.

	include	popf.asm
	include	movemem.asm

block_output:
;enter with cx = byte count, ds:si = buffer location, ax = buffer address
	assume	ds:nothing
	cmp	mem_base,0		;memory or I/O?
	je	block_o			;I/O.
	mov	es,mem_base		; Set up ES:DI at the shared RAM
	mov	di,ax			; ..
	loadport			; Set up for address of TX buffer.
	ram_enable			; Make sure the RAM is actually there.
	call	movemem
	loadport
	rom_enable
	clc
	ret

block_o:
	loadport
	setport	E33G_DMAAL
	out	dx,al
	setport	E33G_DMAAH
        mov     al,ah
        out     dx,al

	setport	E33G_CNTRL
	mov	al,thin_bit
	or	al,ECNTRL_OUTPUT or ECNTRL_START ;start dma, write to board.
	out	dx,al

	cmp	is_186,0
	je	block_o_88

	.286
	setport	E33G_STATUS
block_o_186_0:
	jcxz	block_o_2		;if there is none, exit.
	in	al,dx			;wait for the FIFO to be ready.
	test	al,ESTAT_DPRDY
	je	block_o_186_0
	setport	E33G_FIFOH		;now get ready to read data.
	cmp	cx,8			;do we have eight more to do?
	jb	block_o_186_1		;no, do them one by one.
	outsw				;yes, output eight all at once.
	outsw
	outsw
	outsw
	sub	cx,8			;reduce the count by what we write.
	setport	E33G_STATUS		;go back to the status bit.
	jmp	block_o_186_0
block_o_186_1:
	rep	outsb			;output less than 8 bytes.
	jmp	short block_o_2
	.8086


block_o_88:
	loadport
	setport	E33G_STATUS
block_o_88_0:
	jcxz	block_o_2		;if there is none, exit.
	in	al,dx			;wait for the FIFO to be ready.
	test	al,ESTAT_DPRDY
	je	block_o_88_0
	setport	E33G_FIFOH		;now get ready to read data.
	cmp	cx,8			;do we have eight more to do?
	jb	block_o_88_1		;no, do them one by one.
	lodsw				;yes, output eight all at once.
	out	dx,ax
	lodsw
	out	dx,ax
	lodsw
	out	dx,ax
	lodsw
	out	dx,ax
	sub	cx,8			;reduce the count by what we write.
	setport	E33G_STATUS		;go back to the status bit.
	jmp	block_o_88_0
block_o_88_1:
	lodsb				;output less than 8 bytes.
	out	dx,al
	loop	block_o_88_1
block_o_2:
	loadport
	setport	E33G_CNTRL
	mov	al,thin_bit		;stop dma.
	out	dx,al
	ret


block_input:
;enter with cx = byte count, es:di = buffer location, ax = board address.
	cmp	mem_base,0		; memory or I/O
	je	block_i			; I/O
	push	ax
	loadport
	ram_enable
	pop	ax
	push	ds
	assume	ds:nothing
	mov	ds,mem_base		; ds:si points at first byte to move
	mov	si,ax

	add	ax,cx			; Find the end of this frame.
	cmp	ah,byte ptr cs:sm_rstop_ptr ; Over the top of the ring?
	jb	rcopy_one_piece		; Go move it

rcopy_wrap:
; Copy in two pieces due to buffer wraparound.
	mov	ah,byte ptr cs:sm_rstop_ptr ; Compute length of first part
	xor	al,al
	sub	ax,si			;  as all of the pages up to wrap point
	sub	cx,ax			; Move the rest in second part
	push	cx			; Save count of second part
	mov	cx,ax			; Count for first move
	call	rcopy_subr
	mov	si,SM_RSTART_PG*256	; Offset to start of first receive page
	pop	cx			; Bytes left to move
rcopy_one_piece:
	call	rcopy_subr
	pop	ds
	loadport
	rom_enable
	ret


rcopy_subr:
	shr	cx,1			; convert byte count to word count
	rep	movsw
	jnc	rcv_wrap_even		; odd byte left over?
	lodsw				;   yes, word fetch
	stosb				;   and byte store
rcv_wrap_even:
	ret

block_i:
	assume	ds:code
	loadport
	setport	E33G_DMAAL
	out	dx,al
	setport	E33G_DMAAH
        mov     al,ah
        out     dx,al

	setport	E33G_CNTRL
	mov	al,thin_bit
	or	al,ECNTRL_INPUT or ECNTRL_START ;start dma, read from board.
	out	dx,al

	cmp	is_186,0
	je	block_i_88

	.286
	setport	E33G_STATUS
block_i_186_0:
	jcxz	block_i_2		;if there is none, exit.
	in	al,dx			;wait for the FIFO to be ready.
	test	al,ESTAT_DPRDY
	je	block_i_186_0
	setport	E33G_FIFOH		;now get ready to read data.
	cmp	cx,8			;do we have eight more to do?
	jb	block_i_186_1		;no, do them one by one.
	insw				;yes, input eight all at once.
	insw
	insw
	insw
	sub	cx,8			;reduce the count by what we read.
	setport	E33G_STATUS		;go back to the status bit.
	jmp	block_i_186_0
block_i_186_1:
	rep	insb			;input less than 8 bytes.
	jmp	short block_i_2
	.8086


block_i_88:
	loadport
	setport	E33G_STATUS
block_i_88_0:
	jcxz	block_i_2		;if there is none, exit.
	in	al,dx			;wait for the FIFO to be ready.
	test	al,ESTAT_DPRDY
	je	block_i_88_0
	setport	E33G_FIFOH		;now get ready to read data.
	cmp	cx,8			;do we have eight more to do?
	jb	block_i_88_1		;no, do them one by one.
	in	ax,dx			;yes, input eight all at once.
	stosw
	in	ax,dx
	stosw
	in	ax,dx
	stosw
	in	ax,dx
	stosw
	sub	cx,8			;reduce the count by what we write.
	setport	E33G_STATUS		;go back to the status bit.
	jmp	block_i_88_0
block_i_88_1:
	in	al,dx			;input less than 8 bytes.
	stosb
	loop	block_i_88_1
block_i_2:
	loadport
	setport	E33G_CNTRL
	mov	al,thin_bit		;stop dma.
	out	dx,al
	ret



	include	8390.asm

	public	usage_msg
usage_msg	label	byte
db "usage: 3C503 [options] <packet_int_no> <hardware_irq> <io_addr> <cable_type>",CR,LF
db "Default for <cable_type> is automatic detection.  Use 0 to force AUI,",CR,LF
db "1 to force on-board transceiver.",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for 3-Com 3C503, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+dp8390_version,CR,LF
		db	"Portions Copyright 1989, Robert C. Clements, K1BC",CR,LF,'$'

cfg_err_msg	db	"The int_no parameter must be between 2 and 5.",CR,LF,'$'
mem_busted_msg	db	"Shared RAM on 3C503 card is defective or there is an address conflict.",CR,LF,'$'
no_network_msg	db	"Check network connector - no network connection detected.",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
mem_base_name	db	"Memory address ",'$'

thin_msg	db	"Using the built-in transceiver (thinwire)",CR,LF,'$'
thick_msg	db	"Using the external transceiver (thickwire)",CR,LF,'$'


	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	mov	di,offset int_no	; May override interrupt channel
	call	get_number
	mov	di,offset io_addr	; May override I/O address
	call	get_number
	mov	di,offset thin_not_thick	; May override thick/thin cable flag
	call	get_number
	mov	ax,thin_not_thick	; Now make the right bit
	cmp	ax,0
	je	parse_thin1		; If zero, leave bit off
	mov	al,ECNTRL_THIN		; Else the bit for the card
parse_thin1:
	mov	thin_bit,al		; Save for setting up the card

	clc
	ret

do_reset:
	assume	ds:code
	loadport			; Re-establish I/O base after dx mods
	setport E33G_CNTRL		; Switch control bits to turn off SA PROM
	mov al,	thin_bit
	out dx,	al			; Turn off SA PROM windowing
	ret

init_card:
; Now get the board's physical address from on-board PROM into rom_address
;exit with cy, dx -> error if something went wrong.
	assume	ds:code
	loadport

	cli				; Protect the E33G_CNTRL contents
	setport E33G_CNTRL		; Switch control bits to enable SA PROM
	mov al,	thin_bit
	or al,	ECNTRL_SAPROM
	out dx,	al			; ..
	setport	E33_SAPROM		; Where the address prom is

	movseg	es,cs
	mov di,	offset rom_address
	mov cx,	EADDR_LEN		; Set count for loop
ini_addr_loop:
	in al,	dx			; Get a byte of address
	stosb				; Feed it to caller
	inc	dx			; Next byte at next I/O port
	loop	ini_addr_loop		; Loop over six bytes

	loadport			; Re-establish I/O base after dx mods
	setport E33G_CNTRL		; Switch control bits to turn off SA PROM
	mov al,	thin_bit
	out dx,	al			; Turn off SA PROM windowing
	sti				; Ok for E33G_CNTRL to change now
; Point the "Vector Pointer" registers off into the boonies so we
; don't get the shared RAM disabled on us while we're using it.
; Ideally a warm boot should reset this too, to get to ROM on this card,
; but I don't know a guaranteed way to determine that value.
	setport	E33G_VP2
	mov al,	0ffh			; Point this at the ROM restart location
	out dx,	al			;  of ffff0h.
	setport E33G_VP1
	out dx,	al
	xor al,	al
	setport E33G_VP0
	out dx,	al
;Make sure shared memory is jumpered on. Find its address.
	setport E33G_ROMBASE		; Point at rom/ram cfg reg
	xor	bx,bx
	in al,	dx			; Read it
	test al,0f0h			; Any bits on?
	je	memcfg_3		; no - using I/O.
memcfg_1:
	mov bx,	0c800h-16*SM_TSTART_PG	; Build mem segment here
	test al,0c0h			; DC00 or D800?
	je	memcfg_2		; No
	add bx,	01000h			; Yes, make Dx00
memcfg_2:
	test al,0a0h			; DC00 or CC00?
	je	memcfg_3
	add bx,	00400h			; Yes, make xC00
memcfg_3:
	mov mem_base,bx			; Remember segment addr of memory
	or	bx,bx
	je	mem_works		; don't test the memory if we use I/O.
; Set up Gate Array's Config Reg to enable and size the RAM.
	setport	E33G_GACFR		; Make sure gate array is set up and
	mov al,	EGACFR_IRQOFF		;  the RAM is enabled (not EPROM)
	out dx,	al			; ..
; Check the card's memory
	mov ax,	mem_base		; Set segment of the shared memory
	add ax,	16*SM_TSTART_PG		;  which starts 2000h up from "base"
	mov cx,	2000h			; Length of RAM to test
	call	memory_test		; Check it out
	jz	mem_works		; Go if it's OK
	mov dx,	offset mem_busted_msg
	stc				; Go report failure if it's bad
	ret
mem_works:
; Set up control of shared memory, buffer ring, etc.
	loadport
	setport	E33G_STARTPG		; Set ASIC copy of rx's first buffer page
	mov al,	SM_RSTART_PG
	out dx,	al
	setport	E33G_STOPPG		;  and ASIC copy of rx's last buffer page + 1
	mov al,SM_RSTOP_PG
;	mov al,	byte ptr sm_rstop_ptr
	out dx,	al
; Set up interrupt/DMA control register in ASIC.
; For now, we won't use the DMA, so B0-B3 are zero.
	xor ah,	ah			; Get the interrupt level from arg line
	mov al,	int_no			; ..
	cmp al,	9			; If converted to 9, make back into 2
	jne	get_irq1		; Not 9
	mov al,	2			; Card thinks it's IRQ2
get_irq1:				; Now should have level in range 2-5
	sub ax,	2			; Make 0-3 for tables
	cmp ax,	5-2			; In range?
	jna	get_irq2
	mov	dx,offset cfg_err_msg	; If not, can't configure.
	stc
	ret
get_irq2:
	xor cx,	cx			; Make the bit for the ASIC
	mov cl,	al			; Shift count
	mov al,	10h			; Bit for irq2
	shl al,	cl			; Shift over as needed.
	setport	E33G_IDCFR		; Point at ASIC reg for IRQ level
	out dx,	al			; Set the bit
	setport	E33G_NBURST		; Set burst size to 8
	mov al,	8
	out dx,	al			; ..
	setport	E33G_DMAAH		; Set up transmit bfr in DMA addr
	mov al,	SM_TSTART_PG
	out dx,	al
	xor ax,	ax
	setport E33G_DMAAL
	out dx,	al
	clc
	ret


test_packet	label	byte
	db	EADDR_LEN dup(?)
	db	EADDR_LEN dup(?)
	db	00h,2eh			;A 46 in network order
	db	0,0			;DSAP=0 & SSAP=0 fields
	db	0f3h,0			;Control (Test Req + P bit set)

	public	print_parameters
print_parameters:
	assume	ds:code

	cmp	thin_not_thick,-1
	je	autosense
	jmp	send_test_exit

autosense:
;but on *this* adapter, try sending a test packet.

;first try with the AUI port.
	mov	thin_bit,0

	mov	si,offset rom_address	;set the destination address.
	movseg	es,cs
	mov	di,offset test_packet
	repmov	EADDR_LEN
	mov	si,offset rom_address	;set the source address.
	repmov	EADDR_LEN

send_test:
	loadport			;store the current thin_bit to the board.
	setport	E33G_CNTRL
	mov	al,thin_bit
	out	dx,al

	mov	ax,18			;wait a little while for the powerdown/up to take effect.
	call	set_timeout
send_test_power:
	call	do_timeout
	jne	send_test_power

	mov	cx,6			;try six times
send_test_again:
	push	cx
	mov	cx,60
	mov	si,offset test_packet
	call	send_pkt
	pop	cx

	mov	ax,3
	call	set_timeout

	loadport
	setport	EN0_ISR
send_test_wait:
	in	al,dx
	test	al,ENISR_TX or ENISR_TX_ERR	;did it finish?
	jne	send_test_done

	call	do_timeout
	jnz	send_test_wait
	jmp	short send_test_loop

send_test_done:
	mov	al,0ffh			;clear all interrupts.
	out	dx,al

	loadport
	setport	EN0_TSR
	in	al,dx			;get the transmit status
	test	al,ENTSR_COLL16 or ENTSR_CRS or ENTSR_FU	;any problems?
	je	send_test_exit		;no, it worked.

send_test_loop:
	loop	send_test_again

;it failed all six times.  Try again on a different interface.
	cmp	thin_bit,0		;did we already try internal xcvr?
	jne	send_test_fail		;yes, we can't send any packets!

	mov	thin_bit,ECNTRL_THIN
	jmp	send_test

send_test_fail:
	mov	dx,offset no_network_msg
	mov	ah,9
	int	21h

send_test_exit:
	mov di,	offset int_no		; May override interrupt channel
	mov dx,	offset int_no_name	; Message for it
	call	print_number
	mov di,	offset io_addr		; May override I/O address
	mov dx,	offset io_addr_name	; Message for it
	call	print_number
	add	mem_base,16*SM_TSTART_PG
	mov di,	offset mem_base		; Read off the card.
	mov dx,	offset mem_base_name	; Message for it
	call	print_number
	sub	mem_base,16*SM_TSTART_PG
	mov	dx,offset thin_msg
	cmp	thin_bit,0		; May override thick/thin cable flag
	jne	print_parameters_1
	mov	dx,offset thick_msg
print_parameters_1:
	mov	ah,9
	int	21h
	ret

	include memtest.asm

code	ends

	end
