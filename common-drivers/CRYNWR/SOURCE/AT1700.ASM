;History:14,1

DR_TYPE	equ	99
DR_NAME equ	'Allied Telesis 1700'

	include	ecoupler.asm

	public	usage_msg
;    we don't support -d (delay init till first open)
;    since several of the config parameters come from the device's EEPROM
usage_msg	db	"usage: at1700 [options] <packet_int_no> [io_addr]",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for Allied-Telesis AT-1700, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1993, RF Nets,Cupertino,CA",CR,LF
		db	"Portions Copyright 1993, Crynwr Software",CR,LF,'$'
;---------------------------------------------------------------------------
; Ethercoupler specific data items - not needed after driver goes resident
;---------------------------------------------------------------------------

	extrn	flagbyte: byte

no_dopt_msg	db	"Error: -d option invalid for AT1700",CR,LF,'$'
no_ec_msg	db	"No AT1700 found",CR,LF,'$'

	public	parse_args
parse_args:
;
;  Only argument needed is the packet interrupt number.
;  tail.asm routines took care of that one.  Just need to check that
;  -d option wasn't specified.
;
; exit with nc if all went well, cy otherwise.
;
	assume	ds:code
	test	flagbyte,D_OPTION	;delayed init option(-d) present?
	Jz	PA_01
	Mov	DX,offset no_dopt_msg
	Mov	AH,9		;DOS FC print $ term string
	Int	21h		;DOS Funct Call
	Stc			;error!
	Ret

PA_01:		;-d option not found...we're okay
	mov	di,offset io_addr
	call	get_number
	clc
	ret

iobtbl	dw	260h,280h,2A0h,240h,340h,320h,380h,300h,0

get_board_parameters:
;   find the ethercoupler adapter
	assume	ds:code
	cmp	io_addr,-1		;Did they ask for auto-detect?
	je	find_board

	mov	di,io_addr
	call	verifyboard
	cmp	ax,0ffffh
	jne	find_board_found

	mov	dx,offset no_ec_msg
	stc
	ret

find_board:
	mov	si,offset iobtbl	;Search for the Ethernet address.
	mov	io_addr+2,0
find_board_0:
	lodsw
	mov	io_addr,ax

	push	si			;is it here?
	mov	di,io_addr
	call	verifyboard
	pop	si

	cmp	ax,0ffffh		;did we find it?
	jne	find_board_found	;yes.

	cmp	word ptr [si],0		;are there any more to look at?
	jne	find_board_0		;yes.

	mov	dx,offset no_ec_msg	;no, return error.
	stc
	ret

find_board_found:
	mov	bmpr13_val,al
	mov	int_no,ah
	clc
	ret

code	ends

CODESEG		EQU	<code>
DATASEG		EQU	<code>
DATAGROUP	EQU	<code>
	include	eep17.inc

	end

; $Log: ecoupler.s%v $
;Revision 1.3  1993/02/10  06:30:26  N6RCE
;banner additions
;
;Revision 1.2  1993/01/18  03:49:10  N6RCE
;new recv ISR logic.
;
;Revision 1.1  1993/01/17  20:29:38  N6RCE
;Initial revision
;
