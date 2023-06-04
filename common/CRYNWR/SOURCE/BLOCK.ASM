;***************************************************************************
; File BLOCK.ASM
IFDEF HP_PROD
;   Contains block input and output routines for the hpfepkt packet driver
;
;
; Unpublished Confidential Information of Hewlett-Packard Company.
; Do not disclose.
; Copyright (c) 1994 Hewlett-Packard Company.  All Rights Reserved.
;
; The contents of this software are proprietary and confidential to the
; Hewlett-Packard Company, and are limited in distribution to those with
; a direct need to know.  Individuals having access to this software are
; responsible for maintaining the confidentiality of the content and for
; keeping the software secure when not in use.  Transfer to any party is
; strictly forbidden other than as expressly permitted in writing by
; Hewlett-Packard Company.
ENDIF ;HP_PROD
;
; Revision 0: I/O Mode only.
;
;***************************************************************************

block_input_ptr		dw	?
block_output_ptr	dw	?

;	Block input routine
;	CX = byte count, es:di = buffer location

	public	block_input
block_input:
	jmp	block_input_ptr

;
;	Block output routine
;	CX = byte count, ds:si = buffer location


	public	block_output
block_output:
	assume	ds:nothing
	jmp	block_output_ptr

io_output_286:
	inc	cx			;round up.
	shr	cx,1
	rep	outsw
	clc
	ret

io_output_386:
	.386
	loadport
	setport	DataReg
	add	cx,3			;round up
	shr	cx,2
	rep	outsd
	clc
	ret
	.286

io_input_286:
	loadport
	setport	DataRegWord
	shr	cx,1
	rep	insw
	jnc	read_done	; cf has the original cx bit 0
	inc	dx		; dx = DataReg+3
	insb
read_done:
	ret

io_input_386:
	.386
	loadport
	setport	DataReg
	push	cx
	shr	cx, 2
	rep	insd
	jnc	chk_1_byte	; cf has the original cx bit 1
	inc	dx
	inc	dx		; dx = DataRegWord
	insw
	inc	dx		; dx = DataReg+3
chk_1_byte:
	pop	cx
	test	cx, 1
	jz	io_in_done
	insb
io_in_done:
	ret
	.286

mem_input_286:
mem_output_286:
mem_input_386:
mem_output_386:
bm_input:
bm_output:
	stc
	ret
