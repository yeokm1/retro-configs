	COM EQU 1
	EXE EQU 2
	FILE_TYPE EQU COM

TP_LINK_BIT		 	EQU	4h		; TP heartbeat bit
COAX_TYPE			EQU 1000h	; Turns on the COAX part of the interface
TP_MAX_TICKS		EQU	0Ah		; How long to wait for a TP heartbeat
	
	include	defs.asm
	include kodiak.inc


	extrn	phd_dioa : byte

	extrn	get_ticks : near
	extrn	ticks : word
	extrn	inw_proc : near
	extrn	outw_proc : near
	extrn	get_pea_status : near
	extrn	Nibble_Read : byte
    extrn	Input_Byte : byte
	extrn	sel_rd_8005_reg : byte
	extrn	readbyte_routine : word
	LPT_struct STRUC
        datareg			dw	?
        statusreg		dw	?
        controlreg		dw	?
	LPT_struct ENDS
	extrn	LPT_Address : LPT_struct

SET_COAX	MACRO
; Code to set the cable type to be coax 
		SETPORT	CONFIG2
		call	inw_proc
		or		ax, COAX_TYPE
		call	outw_proc
		ENDM

SET_TWISTED_PAIR	MACRO
; Code to set the cable type to be twisted_pair 
		SETPORT	CONFIG2
		call	inw_proc
		and		ax, NOT COAX_TYPE
		call	outw_proc
		ENDM

code	segment word public
	assume	cs:code, ds:code

cmd_string	db "100",CR,LF,0,0,0,0,0,0,0

coax_msg	db	"Configured to use a coax cable",CR,LF,'$'
tp_msg		db	"Twisted pair cable found",CR,LF,'$'

	public setup
setup PROC	NEAR
if FILE_TYPE EQ EXE
; #### Temp fix to make the EXE file look like a COM file
	mov ax,cs
	mov ds,ax
	mov es,ax
; Set what masks are currently set
	mov	cx,04
	mov	di,offset phd_dioa+1
	mov	si,offset cmd_string
	rep movsb
endif
	ret
setup	ENDP


		public get_cable_type
get_cable_type PROC NEAR
; Find what type of cable is connected by first assuming that we have
; a twisted pair and then listening a 'while' for the heart beat.
; If no beat is found within the limit then assume the cable is coax.
		SET_TWISTED_PAIR			; Initially assume twisted pair cable
		call	get_ticks			; Record start of listening period
		mov		cs:ticks, cx
check_beat:
		call	get_pea_status		; Get status of the PEA
		test	al, TP_LINK_BIT		; Check the Beat Bit
		jnz		no_beat				; Ative low logic - jump if not present
		mov		dx, offset tp_msg
		jz		found_twisted_pair	; Ative low logic
no_beat:
		call	get_ticks			; Not found so find the time
		sub		cx, cs:ticks		; Find difference since start of routine
 		cmp		cx, TP_MAX_TICKS	; Being doing this for long enough?
									; (jl will be out of range)
		jge		must_be_coax		; Jump is yes
		jmp		check_beat			; Listen some more
must_be_coax:						; Nothing found in time limit
		SET_COAX					; so set the cable type to coax.
		mov		dx, offset coax_msg
found_twisted_pair:
		mov		ah, 9				; Announce what has been found
		int		21h
		ret
get_cable_type ENDP



		public	test_it
test_it	PROC	NEAR
ret
	extrn	let_in_ether : near
	call	let_in_ether
		mov		al,LF
		call	print_it
;	call	let_in_ether
dummy:	push	ax
		pop		ax
		jmp		dummy
		ret
test_it	ENDP

print_it	PROC NEAR
	mov		dx, 00h
	mov		ah, 00
	int	17h
	ret
	mov		dx, 037Ah
	in 		al, dx	; control
	and		al, 0EFh	; disable interruptds
	out		dx, al
	mov		dx, 0378h
	out		dx, al
	inc		dx
	in		al, dx
	inc		dx
	mov		al, 0Dh
	out		dx, al
	mov		al, 0Ch
	out		dx, al
	mov		dx, 0379h
	in		al, dx
; Added the following
	CLEAR_WFI
	call	let_in_ether
	ret

	mov		dx, 037Ah
	in 		al, dx	; control
	or		al, 10h
	out		dx, al
	ret
print_it	ENDP

code	ENDS

		END
