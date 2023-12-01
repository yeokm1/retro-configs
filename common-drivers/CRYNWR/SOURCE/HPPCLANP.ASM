PAGE ,132
version	equ	2
;History:83,1

;  Russell Nelson, Clarkson University.
;  Copyright, 1988-1991, Russell Nelson
;  The following people have contributed to this code: David Horne, Eric
;  Henderson, and Bob Clements.

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

	.286

code	segment	word public
	assume	cs:code, ds:code

;*****************************************************************************
;
;	hppclan controller board offsets
;	IO port definition (BASE in io_addr)
;*****************************************************************************
HP_ID	equ	00h
PAGING	equ	02h
OPTION	equ	04h
PAGE_0	equ	08h
PAGE_2	equ	0ah
PAGE_4	equ	0ch
PAGE_6	equ	0eh
;the following is needed for 8390.
EN_OFF		equ	10h

;OPTION bit definitions from the ERS:
MMap_Dis	equ	1000h
Zero_Wait_En	equ	0080h
Mem_En		equ	0040h
IO_En		equ	0020h
Boot_Rom_En	equ	0010h
Fake_Int	equ	0008h
En_Int		equ	0004h
HW_Rst		equ	0002h
NIC_Rst		equ	0001h

;PAGING definitions from the ERS:
Perf_page	equ	0
MAC_Page	equ	1
HW_page		equ	2
Lan_Page	equ	4
ID_Page		equ	6

	include	8390.inc

; Shared memory management parameters

SM_TSTART_PG	EQU	0h		; First page of TX buffer
SM_RSTART_PG	EQU	6h		; start at page 6
  ifndef debugxx
SM_RSTOP_PG	EQU	080h
  else
;Make problems occur sooner and faster by having a smaller ring
;- gft - 910618
SM_RSTOP_PG	EQU	1fh
  endif

pause_	macro
; The reason for the pause_ macro is to establish a minimum time between
; accesses to the card hardware.  However, the Starfighter hardware inserts
; its own delays, which is much more reliable than any software hack.
	endm

reset_8390	macro
	loadport
	setport	OPTION			;hard reset 8390.
	in	ax,dx
	and	ax,not (NIC_Rst or HW_Rst)	;reset the 8390
	out	dx,ax
	longpause
	or	al,En_Int or NIC_Rst or HW_Rst	;unreset it.
	out	dx,al
	endm

terminate_board	macro
	loadport
	setport	OPTION
	in	ax,dx
	or	ax,MMap_Dis or NIC_Rst or HW_Rst
	and	ax,not En_Int
	out	dx,ax
	endm

	extrn	set_recv_isr: near

;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> name of word, di -> dword to print.
	extrn	print_number: near

;enter with al = single character
	extrn	chrout: near

	extrn	is_386: byte		;=0 if 80[12]8[68], =1 if 80[34]86.

	public	int_no, io_addr
int_no		db	?,0,0,0		;must be four bytes long for print_number.
io_addr		dw	-1,-1		; I/O address for card (jumpers)
mem_addr	dw	?,0
memory_mapped	db	0

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	60		;Wild card matches any type
driver_name	db	"HPPCLANP",0	;name of the driver.
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

block_input_ptr		dw	?
block_output_ptr	dw	?

;	Block input routine
;	CX = byte count, es:si = buffer location, ax = buffer address

	public	block_input
block_input:
	loadport
	setport	PAGE_2		;set the read address.
	out	dx,ax

	setport	PAGE_4
	jmp	block_input_ptr

io_input_286:
	shr	cx,1
	rep	insw
	jnc	read_done
	insb
read_done:
	ret

io_input_386:
	.386
	push	eax
	push	cx			;first, get all the full words.
	shr	cx,2
	rep	insd
	pop	cx
	in	eax,dx			;then, get the partial word.
	test	cx,2
	je	block_input_386_one_word
	stosw
	shr	eax,16
block_input_386_one_word:

	test	cx,1
	je	block_input_386_one_byte
	stosb
block_input_386_one_byte:
	pop	eax
	ret
	.286

mem_input_286:
	loadport
	setport	OPTION
	in	ax,dx
	push	ax			;save original contents.
	and	ax,not (MMap_Dis or Boot_Rom_En)	;turn off boot rom, memory on.
	out	dx,ax

	push	ds
	mov	ds,mem_addr
	mov	si,0
	shr	cx,1
	rep	movsw
	jnc	mem_input_286_1
	movsb
mem_input_286_1:
	pop	ds
	pop	ax			;restore OPTION register.
	out	dx,ax
	ret

mem_input_386:
;transfer all complete dwords.
	.386
	loadport
	setport	OPTION
	in	ax,dx
	push	eax			;save original contents.
	and	ax,not (MMap_Dis or Boot_Rom_En)	;turn off boot rom, memory on.
	out	dx,ax

	push	ds
	mov	ds,mem_addr
	mov	si,0
	push	cx
	shr	cx,2			; convert byte count to dword count
	rep	movsd
	pop	cx

;now take take of any trailing words and/or bytes.
	lodsd

	test	cx,2
	je	movemem_386_one_word
	stosw
	shr	eax,16
movemem_386_one_word:

	test	cx,1
	je	movemem_386_one_byte
	stosb
movemem_386_one_byte:
	pop	ds
	pop	eax			;restore OPTION register.
	out	dx,ax
	ret
	.286


;
;	Block output routine
;	CX = byte count, ds:si = buffer location, ax = buffer address


block_output:
	assume	ds:nothing
	loadport
	setport	PAGE_0		;set the write address.
	out	dx,ax

	setport	PAGE_4
	jmp	block_output_ptr

io_output_286:
	inc	cx			;round up.
	shr	cx,1
	rep	outsw
	clc
	ret

io_output_386:
	.386
	add	cx,3			;round up
	shr	cx,2
	rep	outsd
	clc
	ret
	.286

mem_output_286:
	loadport
	setport	OPTION
	in	ax,dx
	push	ax			;save original contents.
	and	ax,not (MMap_Dis or Boot_Rom_En)	;turn off boot rom, memory on.
	out	dx,ax

	mov	es,mem_addr
	mov	di,0
	inc	cx
	shr	cx,1
	rep	movsw
	pop	ax			;restore OPTION register.
	out	dx,ax
	clc
	ret

mem_output_386:
	.386
	loadport
	setport	OPTION
	in	ax,dx
	push	ax			;save original contents.
	and	ax,not (MMap_Dis or Boot_Rom_En)	;turn off boot rom, memory on.
	out	dx,ax

	mov	es,mem_addr
	mov	di,0
	add	cx,3
	shr	cx,2			; convert byte count to dword count
	rep	movsd
	pop	ax			;restore OPTION register.
	out	dx,ax
	clc
	ret
	.286

	include	8390.asm

	public	usage_msg
usage_msg	db	"usage: hppclanp [options] <packet_int_no> <io_addr>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for HP 27247B/27252A cards, version "
		db	'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+dp8390_version,CR,LF,'$'

no_board_msg	db	"No HP PC LAN detected.",CR,LF,'$'
io_addr_funny_msg	label	byte
		db	"No HP PC LAN detected, continuing anyway.",CR,LF,'$'
no_network_msg	db	"Check network connector - no network connection detected.",CR,LF,'$'
int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
mem_addr_name	db	"Memory address ",'$'

config_flags	db	?
config_aui_bit	db	?		;=01h if TP, =40h if TL

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.

	mov	di,offset io_addr
	call	get_number

	push	si

	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board

	call	detect_board		;no, just verify its existance.
	je	find_board_found

	mov	dx,offset io_addr_funny_msg
	mov	ah,9
	int	21h

	jmp	find_board_found

find_board:
	mov	io_addr,100h		;Search for the Ethernet address.
	mov	io_addr+2,0
find_board_0:
	call	detect_board
	je	find_board_found
find_board_again:
	add	io_addr,20h		;not at this port, try another.
	cmp	io_addr,3ffh
	jb	find_board_0

	mov	dx,offset no_board_msg	;Tell them that we can't find it.
	stc
	ret
find_board_found:
	mov	config_flags,al		;remember the config flags for later.
	and	al,40h			;Twisted Pair or Thin Lan?
	jne	find_board_tl
	mov	al,1
find_board_tl:
	mov	config_aui_bit,al

	loadport
	setport	PAGING			;select swap page 2 (hardware)
	mov	al,HW_page
	out	dx,al

	setport	0dh			;get the IRQ Channel
	in	al,dx
	and	al,0fh
	mov	int_no,al

	setport	09h			;get the low memory map location
	in	ax,dx
	shl	ax,4			;make into a segment address
	mov	mem_addr,ax

	mov	ax,SM_RSTART_PG + (SM_RSTOP_PG-1) * 256
	setport	0eh
	out	dx,ax

  if 0
	setport	PAGING
	mov	al,Lan_Page		;select Lan_Page page.
	out	dx,al

	setport	PAGE_0
	in	ax,dx
	or	al,config_aui_bit	;start with AUI on.
	out	dx,ax
  endif

	setport	PAGING
	mov	al,Perf_page		;select Performance page again.
	out	dx,al

	setport	OPTION			;see if we're memory or I/O mapped.
	in	ax,dx
	mov	bx,offset io_input_286
	mov	cx,offset io_input_386
	mov	si,offset io_output_286
	mov	di,offset io_output_386

	test	ax,Mem_En		;is memory enabled?
	je	io_mapped
;	and	ax,not MMap_Dis		;turn off the memory map disable.
;	out	dx,ax
	inc	memory_mapped
	mov	bx,offset mem_input_286
	mov	cx,offset mem_input_386
	mov	si,offset mem_output_286
	mov	di,offset mem_output_386
io_mapped:
	mov	block_input_ptr,bx	;by default, use 286 transfers.
	mov	block_output_ptr,si
	cmp	is_386,0		;do we have a 386?
	je	use_286_code		;no, use 286 transfers
	test	config_flags,10h	;should we use 16-bit transfers anyway?
	jne	use_286_code		;yes, their motherboard has a problem.
	mov	block_input_ptr,cx
	mov	block_output_ptr,di
use_286_code:

	mov	sm_rstop_ptr,SM_RSTOP_PG

	pop	si
	clc
	ret

	extrn	etopen_diagn: byte

init_card:
;we have nothing left to do here.
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
;echo our command-line parameters
	assume	ds:code

	test	config_flags,80h	;should we auto-sense?
	jne	do_auto_sense
	jmp	send_test_exit		;no.
do_auto_sense:

;but on *this* adapter, try sending a test packet.

	mov	si,offset rom_address	;set the destination address.
	movseg	es,cs
	mov	di,offset test_packet
	repmov	EADDR_LEN
	mov	si,offset rom_address	;set the source address.
	repmov	EADDR_LEN

	loadport
	setport	PAGING
	mov	ax,Lan_Page
	out	dx,ax			;Point at LAN Control page

	setport	PAGE_0
	in	ax,dx			;Get current state of LAN register
	or	al,config_aui_bit	;Turn on AUI select bit
send_test:
	out	dx,ax

	call	delay_150ms

	setport	PAGING			;set back to the expected page
	mov	ax,Perf_page
	out	dx,ax

	mov	cx,6			;try six times
send_test_again:
	push	bx
	push	cx
	mov	cx,60
	mov	si,offset test_packet
	call	send_pkt
	pop	cx
	pop	bx

	mov	ax,18
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

	setport	EN0_TSR
	in	al,dx			;get the transmit status
	test	al,ENTSR_COLL16 or ENTSR_CRS or ENTSR_FU	;any problems?
	je	send_test_exit		;no, it worked.

send_test_loop:
	loop	send_test_again

;it failed all six times.  Try again on a different interface.
	setport	PAGING
	mov	ax,Lan_Page
	out	dx,ax			;Point at LAN Control page

	setport	PAGE_0
	in	ax,dx			;Get current state of LAN register
	test	al,config_aui_bit	;did we already try internal xcvr?
	je	send_test_fail		;yes, we can't send any packets!

	not	al			;Turn off AUI select bit
	or	al,config_aui_bit
	not	al
	jmp	send_test

send_test_fail:
	mov	dx,offset no_network_msg
	mov	ah,9
	int	21h

send_test_exit:
	loadport
	setport	PAGING			;set back to the expected page
	mov	ax,Perf_page
	out	dx,ax

	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	cmp	memory_mapped,0
	je	print_parameters_1
	mov	di,offset mem_addr
	mov	dx,offset mem_addr_name
	call	print_number
print_parameters_1:
	ret


delay_150ms:
	mov	ax,(3000+275)/275	;delay 300 ms (27.5 ms per increment).
	call	set_timeout
delay_150ms_1:
	call	do_timeout
	jnz	delay_150ms_1
	ret


detect_board:
;see if this adapter is the HP Adapter/16+.
;exit with zr if adapter is at io_addr,
;  AL = Driver Configuration Flags	(YOYO page 6 offset 0Ch)
;  AH = Soft model byte			(YOYO page 6 offset 0Dh)
;
;	Check Hardware Family ID bytes
;
	loadport
	setport	HP_ID
	in	al,dx
	cmp	al,50h
	jne	detect_board_1

	setport	HP_ID+1
	in	al,dx
	cmp	al,48h
	jne	detect_board_1
	setport	HP_ID+2
	in	al,dx
	and	al,0f0h			;AND off page select bits
	cmp	al,0
	jne	detect_board_1
	setport	HP_ID+3
	in	al,dx
	cmp	al,53h
	jne	detect_board_1
;
;	Checksum the Station Address to verify this really is an Adapter/16+
;
	setport	PAGING			;Point back at PAGING register
	mov	ax,MAC_Page
	out	dx,ax			;Goto adapter ISA ID page
	xor	bl,bl
	movseg	es,cs
	mov	di,offset rom_address
	mov	cx,7			;6 bytes of address + 1 checksum byte
	setport	PAGE_0			;Point at 1st Station Address byte
detect_board_2:
	in	al,dx
	add	bl,al
	stosb
	inc	dx
	loop	detect_board_2
	cmp	bl,0ffh			;Is checksum good??
	jnz	detect_board_1		;NO, exit
;
;	Check the Software Model number to verify this Adapter/16+ is NIC based.
;
	loadport
	setport	PAGING			;Point back at PAGING register
	mov	ax,ID_Page
	out	dx,ax			;Point at Board ID and SW info page
	setport	PAGE_4			;Point at Software Configuration Flags
	in	ax,dx
	mov	bh,ah
	and	bh,(NOT 3h)		;Mask off revision bits
	cmp	bh,0			;Compare soft model number (0)?
detect_board_1:
	ret


code	ends

	end
