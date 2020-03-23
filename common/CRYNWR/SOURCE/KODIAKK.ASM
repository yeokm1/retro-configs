version	equ	2
;History:37,1

	include	defs.asm

code	segment	word public
	assume	cs:code, ds:code

KOMBO	equ	1

;This source code is for both 8-bit and 16-bit boards.  The 8-bit boards
;must be accessed 8 bits at a time, and the 16-bit boards must be accessed
;16 bits at a time.  Since the 16-bit access is a one-byte instruction
;(out dx,ax), it seems too wasteful to use a subroutine.  Therefore, we
;compile two different drivers.  Modify the following equate for the
;current driver:

BIT_8_NOT_16	equ	0		;=1 for 8-bit, =0 for 16-bit.

  if BIT_8_NOT_16
	include	io8.asm
repouts	equ	repoutsb
repins	equ	repinsb
  else
	include	io16.asm
repouts	equ	obufeven
repins	equ	ibufeven
  endif

TP_XCVR		equ	0
BNC_XCVR	equ	1
AUI_XCVR	equ	2
AUTO_XCVR	equ	3

current_xcvr	db	?

; Registers

K2WR	equ	07h			;ksetup 2 write
KSTAT	equ	07h			;kombo status

; Status Register (STAT, read only)
;
C04_SQE		equ	0800h		;only on 80c04
C04_COLL16	equ	1000h		;only on 80c04

;
; on the Kombo, the following bits have the following definitions
UTPDIS		equ     0800h
SELECT_16_BIT	equ	1000h
;
; Kombo Setup 1 (K1RD)
;
BASEBIT1	equ	1h		; First I/O bit
BASEBIT2	equ	2h		; Second I/O bit
BASEBIT3	equ	4h		; Third I/O bit
ROMBIT1		equ	10h		; First rom bit
ROMBIT2		equ	20h		; Second rom bit
ROMBIT3		equ	40h		; Third rom bit
;
; Kombo Setup 2 (K2RD & K2WR)
;
MODESELECT		equ	01h	;=0 for PROM, =1 for RUN.
INTBIT1			equ	02h	;First IRQ bit
INTBIT2			equ	04h	;Second IRQ bit
INTBIT3			equ	08h	;Third IRQ bit
COMPATIBILITY		equ	10h	;bus compatibility select mode
EEPROMWRITEENABLE	equ	20h	;enable eeprom for writing
ADDRESSBUMP		equ	40h	;enable snoop
COAXDIS			equ	80h	;disable coax
;
; Kombo Setup 3 (K3RD)
;
AUIEN			equ	1h	; aui is selected
;
; Kombo Status 1 (KSTAT)
;
LINKDETECT		equ	1	; Link detect for 10baseT

	include	kodiak.inc

	even
test_packet	label	byte
	db	EADDR_LEN dup(?)
	db	EADDR_LEN dup(?)
	db	00h,2eh			;A 46 in network order
	db	0,0			;DSAP=0 & SSAP=0 fields
	db	0f3h,0			;Control (Test Req + P bit set)

autosense:
	cmp	bx,-1
	jne	autosense_2
	mov	bl,current_xcvr
	xor	bh,bh
	ret
autosense_2:
	cmp	bl,AUTO_XCVR
	je	autosense_1
	call	set_transceiver
	clc
	ret
autosense_1:
	and	setup2_reg,not COAXDIS	;turn on TW transceiver
	and	config2_reg,not (UTPDIS or SELECT_16_BIT)
					;turn on TP transceiver, use 8 bits.
	call	set_hardware
	or	config2_reg,SELECT_16_BIT	;go back to 16 bits next time.

	call	delay_150ms		;wait for them to power up.

	loadport
	setport	KSTAT			;look for link beat.
	mov	ax,1			;(27.5 ms per increment).
	call	set_timeout
wait_for_TW:
	in	al, dx
	test	al, LINKDETECT		;Do we have link detect?
	jnz	cable_type_not_TP	;yes, it must be TP.
	mov	bl,TP_XCVR
	call	set_transceiver
	clc
	ret
cable_type_not_TP:

	call	do_timeout
	jnz	wait_for_TW

	mov	bl,AUI_XCVR		;Try this one first.
;
; Try sending a packet on each interface.  Configure ourselves to one that it
; works on.
;
send_test_start:
;here with bl = transceiver
	call	set_transceiver
	mov	ax,(20000+274)/275	;compute count (27.5 ms per increment).
	call	delay_while

	mov	received_ours,0
	mov	si,offset my_address	;set the destination address.
	movseg	es,cs
	mov	di,offset test_packet
	repmov	EADDR_LEN
	mov	si,offset my_address	;set the source address.
	repmov	EADDR_LEN
	mov	cx,6			;try six times.
send_test_again:
	push	cx
	mov	cx,60
	mov	si,offset test_packet
	call	send_pkt
	pop	cx

	mov	ax,2			;wait 27.5ms
	call	set_timeout
send_test_wait:
	push	cx
	call	recv
	pop	cx
	cmp	received_ours,0		;did we get it?
	jne	send_test_exit		;yes, it worked.
	loadport			;get the status and see if it's COLL16.
	setport	STAT
	inw
	test	ax,C04_COLL16		;if this bit is a zero, we failed this
	je	send_test_failed1	;  test.
	call	do_timeout
	jnz	send_test_wait
send_test_failed1:
	to_scrn	23,78,'T'
	loop	send_test_again

;it failed multiple times.  Try again on a different interface.
	cmp	current_xcvr,BNC_XCVR	;did we just try this one?
	je	send_test_fail		;yes, no more to try, give up.

	mov	bl,BNC_XCVR
	jmp	send_test_start

send_test_fail:
	to_scrn	23,77,'F'
	mov	bl,AUI_XCVR		;turn off both power supplies.
	call	set_transceiver
	mov	dh,CANT_SET
	mov	bl,AUTO_XCVR
	stc
	ret

send_test_exit:
	mov	bl,current_xcvr
	xor	bh,bh
	clc
	ret


delay_150ms:
	mov	ax,(1500+274)/275	;compute count (27.5 ms per increment).
delay_while:
	call	set_timeout
delay_150ms_1:
	call	do_timeout
	jnz	delay_150ms_1
	ret


set_transceiver:
;enter with bl = desired transceiver type.
	assume	ds:code
	cmp	bl,BNC_XCVR
	jne	set_transceiver_TP
	and	setup2_reg,not COAXDIS	;turn on the TW transceiver
	or	config2_reg,UTPDIS	;turn off TP transceiver
	jmp	short set_transceiver_done

set_transceiver_TP:
	cmp	bl,TP_XCVR
	jne	set_transceiver_AUI
	or	setup2_reg,COAXDIS	;turn off the TW transceiver
	and	config2_reg,not UTPDIS	;turn on TP transceiver
	jmp	short set_transceiver_done

set_transceiver_AUI:
	or	setup2_reg,COAXDIS	;turn off the TW transceiver
	or	config2_reg,UTPDIS	;turn off TP transceiver

set_transceiver_done:
	mov	current_xcvr,bl		;remember which one we're using.

set_hardware:
	loadport			;inform the hardware of our decision.
	setport	K2WR
	mov	al,setup2_reg
	out	dx,al

	setport	CONFIG2
	mov	ax,config2_reg
	outw
	ret

	include	kodiak.asm

code	ends

	end
