version	equ	0

;History:23,1

	include	defs.asm

code	segment	word public
	assume	cs:code, ds:code

;This source code is for both 8-bit and 16-bit boards.  The 8-bit boards
;must be accessed 8 bits at a time, and the 16-bit boards must be accessed
;16 bits at a time.  Since the 16-bit access is a one-byte instruction
;(out dx,ax), it seems too wasteful to use a subroutine.  Therefore, we
;compile two different drivers.  Modify the following equate for the
;current driver:

	include	io8.asm
repouts	equ	repoutsb
repins	equ	repinsb

	include	kodiak.inc

	include	kodiak.asm

code	ends

	end

