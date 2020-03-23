version	equ	1

	include	defs.asm

; a driver for the EXOS 205 Ethernet controller by Dirk Koeppen (dirk@incom.de)

; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, version 1.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


	public	int_no
	public	driver_class, driver_type, driver_name, driver_function
	public	parameter_list
	public	usage_msg
	public	copyright_msg
	public	parse_args
	public	print_parameters

; inform 82586.asm that we have a larger amount of memory
SEG586	equ	0fh

; equates for controlling EXOS 205 i/o ports
P_INTR		EQU	0		; interrupt EXOS 205
P_CTRL1		EQU	2		; control port 1
	P1_186	EQU 	00000001b	; enable 80186
	P1_586	EQU 	00000010b	; enable 82586
	P1_A12	EQU 	00000100b	; address bit 12 of EXOS memory
	P1_NET	EQU	00001000b	; enable net (disable loopback) 
	P1_A13	EQU	00010000b	; address bit 13 of EXOS memory 
	P1_CA	EQU	00100000b	; do a channel attention by host
	P1_A14	EQU	01000000b	; address bit 14 of EXOS memory
	P1_A15	EQU	10000000b	; address bit 15 of EXOS memory
P_CTRL2		EQU	3		; control port 2
	P2_A16	EQU	00000001b	; address bit 16 of EXOS memory
	P2_SHM	EQU	01111110b	; EXOS shared memory address on host
	P2_ACC	EQU	10000000b	; enable access to EXOS memory
P_ACK		EQU	4		; acknowledge interrupt


; here are some equates to syncronise the i186 and the host via a semaphore
S_INST		EQU	0aah		; a fancy value to flag installed code 
S_EXEC		EQU	0a5h		; .. code is executing
S_FAILED	EQU	05ah		; .. i186 has failed to execute code
S_STOP		EQU	055h		; .. code was successfully executed


code	segment	word public
	assume	cs:code, ds:code

int_no		db	2, 0, 0, 0	; interrupt number
io_addr		dw	310h, 0		; I/O address for card
base_addr	dw  	0cc00h, 0	; base segment for board

ex_eaddr	db  	6 dup (0)	; boards Ethernet address
ex_ctrl1	db	0		; copy of control port 1
ex_ctrl2	db	0		; .. port2

driver_class	db	BLUEBOOK, IEEE8023, 0	; from the packet spec
driver_type	db	13			; from the packet spec
driver_name	db	"EXOS205", 0		; name of the driver
driver_function	db	2
parameter_list	label	byte
	db	1		; major rev of packet driver
	db	9		; minor rev of packet driver
	db	14		; length of parameter list
	db	EADDR_LEN	; length of MAC-layer address
	dw	GIANT		; MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN ; buffer size of multicast addrs
	dw	0		; (# of back-to-back MTU rcvs) - 1
	dw	0		; (# of successive xmits) - 1
int_num	dw	0		; interrupt # to hook for post-EOI
				; processing, 0 == none

usage_msg	db "usage: exos205 [options] <packet_int_no> [int_no] [io_addr] [base_addr]",CR,LF,'$'

copyright_msg	db	"Packet driver for the EXOS 205, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,".",'0'+i82586_version,CR,LF
		db	"Portions Copyright 1988 The Board of Trustees of the University of Illinois.",CR,LF
		db	"Portions Copyright 1992 Dirk Koeppen (dirk@incom.de).",CR,LF,'$'

no_exos205	db	"Unable to initialize the EXOS 205 adapter.",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'
base_addr_name	db	"Shared memory address ",'$'


; ENABLE_NETWORK - switch on the transceiver
enable_network:
	ret		; is on all the time


; RESET_586 - reset the network controller
reset_586:
	push	ds		; could be called from different segment
	push	ax
	mov	ax, cs
	mov	ds, ax

	loadport
	setport P_CTRL1		; load the i/o control register
	mov	al, ex_ctrl1
	or	al, P1_CA	; set CA
	and	al, NOT P1_586	; disable i82586
	out	dx, al		; trigger the port
	jmp	$+2		; let the signal dry
	or	al, NOT P1_586	; enable i82586 
	out	dx, al
	mov	ex_ctrl1, al	; save a copy
	pop	ax
	pop	ds
	ret


; DOCA - do a channel attention
doca:
	push	ds		; could be called from different segment
	push	ax
	mov	ax, cs
	mov	ds, ax

	loadport
	setport P_CTRL1		; load the i/o control register
	mov	al, ex_ctrl1
	and	al, NOT P1_CA	; clear CA
	or	al, P1_586	; enable i82586 if not already enabled
	out	dx, al		; trigger the port
	jmp	$+2		; let the signal dry
 	jmp	$+2
	or	al, P1_CA	; set CA
	out	dx, al
	mov	ex_ctrl1, al	; save a copy

	setport	P_ACK		; acknowledge intr (placed here because 
	out	dx, ax		; .. recv_isr calls doca each time)

	pop	ax
	pop	ds
	ret


; EX_INIT - initialize the EXOS205
ex_init:
	loadport		; base of device
	mov	ex_ctrl1, P1_NET+P1_A12+P1_A13+P1_A14+P1_A15 ; highest mem page

	mov	ax, base_addr	; where the shared memory should get to
	shr	ah, 1 		; shift it to the right place
	and	ah, P2_SHM	; zero all other bits
	or	ah, P2_A16	; set address bit 16
	mov	ex_ctrl2, ah

	setport	P_CTRL1		; set the EXOS memory address
	mov	al, ex_ctrl1
	out	dx, al

	setport	P_CTRL2
	mov	al, ex_ctrl2
	out	dx, al
	jmp	$+2		; let it dry
	jmp	$+2
	or	ex_ctrl2, P2_ACC ; enable the memory
	mov	al, ex_ctrl2
	out	dx, al

init_i186:			
	push	es		; save 'C' register type loop-counters
	push	si
	push	di
	push	ds
	mov	es, base_addr	; ES:DI -> EXOS205 memory (end of last 16K page)
	mov	di, 03fffh
	mov	ax, cs		; DS:SI -> code to be downloaded (end of code)
	mov	ds, ax
	mov	si, offset i186_end
	mov	cx, (offset i186_end-offset i186_code) ; amount to be downloaded
	inc	cx		; one more because loops end at 0
	std			; copy backwards 

	rep	movsb		; copy the code

	cld
	pop	ds		; restore original DS
	mov	di, 03fffh 	; where the semaphore is located
	sub 	di, (offset i186_end-offset i186_sema)
	mov	al, es:[di]	; get semaphore
	cmp	al, S_INST	; check if code is installed
	jne	init_failed	; failed to init board

	setport	P_CTRL1
	mov	al, ex_ctrl1	; release the i186, let it execute the code
	or	al, P1_186
	mov	ex_ctrl1, al	; .. and let it run forever
	out	dx, al

	mov	ax, (36*2)	; give it 2 seconds to start execution
	call	set_timeout

init_loop1:
	mov	al, es:[di]	; get semaphore
	cmp	al, S_EXEC	; does it execute ?
	je	init_i186exec

	call	do_timeout	; loop until timeout
	jne	init_loop1

	jmp	init_failed	; failed to init board

init_i186exec:
	mov	ax, (36*5)	; give it 5 seconds to initialize
	call	set_timeout

init_loop2:
	mov	al, es:[di]	; get semaphore
	cmp	al, S_STOP	; did it stop ?
	je	init_i186stop

	call	do_timeout	; loop until timeout
	jne	init_loop2

	jmp	init_failed	; failed to init board

init_i186stop:
	xor	ax, ax 		; flag that everything worked all right
	push	ax
	mov	di, 03fffh 	; where the Ethernet address is located 
	sub 	di, (offset i186_end-offset i186_addr)
	mov	bx, offset ex_eaddr
	mov	cx, 6		; 6 bytes to move

init_acpy:
	mov	al, es:[di]	; copy address
	mov	ds:[bx], al
	inc	di		; next byte
	inc	bx
	loop	init_acpy	; loop for all byte

init_end:
	pop	ax

	setport	P_ACK		; acknowledge intr to reset hardware logic
	out	dx, ax

	pop	di 		; restore saved registers
	pop	si
	pop	es
	or	ax, ax		; setup zero flag
	ret

init_failed:
	setport	P_CTRL1		; stop the i186
	mov	al, ex_ctrl1
	and	al, NOT P1_186	; .. forever
	mov	ex_ctrl1, al
	out	dx, al
	mov	ax, -1		; failed to init board
	push	ax
	jmp	init_end


; I186_CODE - this code is downloaded to the EXOS205 to be executed by the i186
i186_code:
i186_addr:
	db	08h, 00h, 14h	; unique EXOS Ethernet address (byte 5-3)
	db	0, 0, 0		; .. byte 2-0 of the boards Ethernet address

i186_sema:
	db	S_INST		; semaphore will be S_STOP if code was executed

i186_ipl:			; i186 bootstrap
	cli			; disable interrupts
	xor	ax, ax		; zero relocation register
	mov	dx, 0fffeh
	out	dx, ax
	mov	ax, 0fff8h	; setup UMCS register
	out	0a0h, ax
	mov	ax, 0007ch	; .. PACS register
	out	0a4h, ax
	mov	ax, 080bch	; .. MPCS register
	out	0a8h, ax

	mov	ax, cs		; DS -> CS
	mov	ds, ax
	
	; flag code execution
	mov	bx, 00fffh - (offset i186_end-offset i186_sema)
	mov	byte ptr ds:[bx], S_EXEC
	xor	cx, cx

i186_wait:			; spend some time to let host read the semaphore
	jmp	$+2
	jmp	$+2
	jmp	$+2
	loop	i186_wait

	; where to write the boards Ethernet addr to (starts 3 bytes after code)
	mov	si, 00fffh - (offset i186_end-offset i186_addr) + 3

	mov	dx, 0502h	; low order nibble of byte 2 Ethernet address
	xor	bx, bx		; zero checksum
	mov	cx, 3		; 3 bytes of Ethernet address are to be read

i186_acpy:
	in	al, dx		; read one nibble
	and	al, 00001111b	; .. mask valid bits (just to get shure !)
	mov	ah, al		; .. store it
	add	bl, al		; .. add to checksum
	inc	dx 		; go to high order nibble
	inc	dx
	in	al, dx		; .. read it
	add	bl, al		; .. add to checksum
	shl	al, 1 		; .. shift it to be high order nibble
	shl	al, 1
	shl	al, 1
	shl	al, 1
	or	al, ah		; pack those two nibbles into one byte
	mov	ds:[si], al 	; .. and store the byte

	inc	dx		; go to next nibble of Ethernet address 
	inc	dx
	inc	si	
	loop	i186_acpy	; loop until all 3 bytes are read

	mov	ah, bl		; add bottom to top nibble
	shr	ah, 1		; top nibble
	shr	ah, 1
	shr	ah, 1
	shr	ah, 1
	and	bl, 00001111b	; bottom nibble
	add	ah, bl		; add them
	xor	ah, 5		; is x-ored by 5 to avoid 0x00 or 0xff problem

	in	al, dx		; DX -> checksum
	cmp	ah, al
	je	i186_ok

	mov	byte ptr ds:[si], S_FAILED; flag that checksum failed

	jmp	$		; stop execution (i186 will be stopped by host)

i186_ok:
	mov	byte ptr ds:[si], S_STOP ; flag that we have stopped execution
	xor	ax, ax		; set the interrupt vector
	mov	ds, ax		; .. i82586 is connected to INT2
	mov	si, 4*14	; INT2 has vector type 14
	mov	word ptr ds:[si], 00fffh - (offset i186_end-offset i186_intr)
	inc	si
	inc	si
	mov	word ptr ds:[si], 0ff00h

	sti			; enable interrupts

	mov	dx, 3ch		; INT2 control register
	mov	ax, 3		; level triggered, unmasked and prio 3
	out	dx, ax

	xor	bx, bx		; zero counters
	xor	cx, cx
	mov	bp, 00fffh - (offset i186_end-offset i186_lcnt)

i186_loop:			; endless loop to keep i186 doing something
	nop
	nop
	nop
	nop
	loop	i186_loop

	inc	bx		; count
	mov	cs:[bp], bx	; .. and store for debugging
	jmp	i186_loop	; cycle endless while waiting for interrupts 

i186_intr:			; interrupt routine called by 82586 intr
	push	dx
	mov	dx, 00600h	; interrupt host first
	out	dx, ax		

	push	ax
	push	bx
	push	bp

	mov	bp, 00fffh - (offset i186_end-offset i186_icnt)
	mov	bx, cs:[bp]
	inc	bx		; increment interrupt counter
	mov	cs:[bp], bx	; .. and store for debugging

	mov	dx, 22h		; acknowledge interrupt
	mov	ax, 8000h
	out	dx, ax

	pop	bp
	pop	bx
	pop	ax
	pop	dx
	iret

	db	'INTR cnt->'	; some debugging variables
i186_icnt:
	dw	0		; counts 82586 interrupts
	db	'LOOP cnt->'
i186_lcnt:
	dw	0		; loops to flag execution

i586_reset_vector:
	db	0eah	dup (0)	; reserved for the i82586 reset vector

i186_reset_vector:
	db	0eah		; opcode 'jmp far'
	dw	00fffh - (offset i186_end-offset i186_ipl)
	dw	0ff00h
	db	0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; fill patterns

i186_end:
	db	0		; one more fill pattern	


; here we include the code that is common between 82586 implementations.
; everything above this is resident.
	include	82586.asm
; everything below this is discarded upon installation.

; CHECK_BOARD - check if there really is a EXOS 205 installed
check_board:
	mov	SCP, 0			; 16 bit bus type in scb.

	call	ex_init			; setup the board
	je	check_ok

	mov	dx, offset no_exos205	; failed to init board
	jmp	error

check_ok:
	xor	ax, ax			; have a return value
	ret


; PARSE_ARGS - read the command line option and overwrite defaults
parse_args:
	mov	di, offset int_no
	call	get_number
	mov	di, offset io_addr
	call	get_number
	mov	di, offset base_addr
	call	get_number
	clc
	ret

; PRINT_PARAMETERS - print out the boards configuration parameters
print_parameters:
	mov	di, offset int_no
	mov	dx, offset int_no_name
	call	print_number
	mov	di, offset io_addr
	mov	dx, offset io_addr_name
	call	print_number
	mov	ax, memory_begin
	mov	cl, 4
	shr	ax, cl
	add	base_addr, ax
	push	ax
	mov	di, offset base_addr
	mov	dx, offset base_addr_name
	call	print_number
	pop	ax
	sub	base_addr, ax
	ret

; GET_ADDRESS - get boards Ethernet address
;	enter with es:di -> place to get the address,
;		cx = size of address buffer.
;	exit with nc, cx = actual size of address,
;		 or cy if buffer not big enough.
get_address:
	assume	ds: code
	mov	bx, offset ex_eaddr	; where to copy is located
get_address_1:
	mov	al, ds:[bx]		; copy a byte of the address
	stosb				; put it away
	inc	bx			; next address byte 
	loop	get_address_1		; go back for rest
	ret

	include	memtest.asm

code	ends
	end
