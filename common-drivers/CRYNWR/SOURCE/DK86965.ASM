;History:14,1

DR_TYPE	equ	100
DR_NAME equ	'DK86965'

	include	ecoupler.asm

	public	usage_msg
;    we don't support -d (delay init till first open)
;    since several of the config parameters come from the device's EEPROM
usage_msg	db	"usage: dk86965 [options] <packet_int_no>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for Fujitsu EtherCoupler (86965) device, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1993, RF Nets,Cupertino,CA",CR,LF,'$'
;---------------------------------------------------------------------------
; Ethercoupler specific data items - not needed after driver goes resident
;---------------------------------------------------------------------------
iobtbl	Dw	260h,280h,2A0h,240h,340h,320h,380h,300h 
		;table of all I/O base addresses to try. Count is 8.
IRQ_table Db	3,4,5,9		;INTSEL to real IRQ (for FM DK86965 kit)

	extrn	flagbyte: byte

no_dopt_msg	db	"Error: -d option invalid for dk86965",CR,LF,'$'
no_ec_msg	db	"No dk86965 found",CR,LF,'$'
ec_problem_msg	db	"dk86965 and EEPROM don't agree",CR,LF,'$'


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
	clc
	ret

get_board_parameters:
;   find the ethercoupler adapter
	mov	io_addr+2,0		;always search.
	Call	SearchforEC
		;search for EC signature, filling in io_addr variable
		;if not found then, io_addr is set to zero.
	Mov	DX,io_addr	;get EC base addres
	Or	DX,DX		;EC found?
	Jnz	ETO_01		;make into long jump
	mov	dx,offset no_ec_msg
	Jmp	noEC		;Nyet..gripe and exit
ETO_01:
	Mov	AL,EEP_CONFIG_R0	;read EEPROM config reg 0 (H/W setup)
	Call	read_EEPROM_reg
	Mov	BX,AX		;save - we'll cmpare to BMPR19 (J'less config)
	Mov	DX,io_addr
	Add	DX,BMPR19
	Xor	AX,AX		;clear upper byte
	In	AL,DX		;read EC's idea of J'less config
	Cmp	BH,AL		;how can they differ?
	Jz	ETC_02
	mov	dx,offset ec_problem_msg
	Jmp	EC_problem
ETC_02:
	Shr	AX,6		;move INTSEL bits to lower byte
	Mov	SI,AX
	Mov	AL,IRQ_table[SI] ;get real IRQ number
	Mov	int_no,AL	

	ret

read_mac_addr:
;enter with si -> place to store Ethernet address
	Mov	AX,4		;addr of word ot get
	Call	read_EEPROM_reg	;read the word
	mov	[si+0],ax

	Mov	AX,5		;addr of word ot get
	Call	read_EEPROM_reg	;read the word
	mov	[si+2],ax

	Mov	AX,6		;addr of word ot get
	Call	read_EEPROM_reg	;read the word
	mov	[si+4],ax
	ret

;-------------------------------------------------------------------
; SearchforEC
;-------------------------------------------------------------------
SearchforEC	Proc

	Push	SI
	Push	CX
	Push	AX
	
	Mov	CX,8		;count of tbale entries
	Mov	SI,0 		;index into I/O base addr table

SEC_01:
	Mov	DX,iobtbl[SI]	;get table entry

	Add	DX,2		;check DLCR2 first
	In	AL,DX		;get DLCR2
	And	AL,DLCR2_sig_mask ;0x71
	Jnz	sig_fail	;if any bits left on, then not valid sig
	Add	DX,2		;DLCR4
	In	AL,DX
	And	AL,DLCR4_sig_mask  ;0x08
	Jnz	sig_fail
	Inc	DX		;DLCR5
	In	AL,DX
	And	AL,DLCR5_sig_mask ;0x80
	Jnz	sig_fail
	Add	DX,2		;DLCR7
	In	AL,DX
	And	AL,DLCR7_sig_mask ;0x10
	Jnz	sig_fail
;
;  valid EC signature found
;
	Mov	DX,iobtbl[SI]	;get the base address back
	Jmp	SEC_02		;return to caller

sig_fail:	;come here when one of the signature checks fails
	Inc	SI
	Inc	SI
	Loop	SEC_01
;
;  didn't find the EC signature..maybe a conflict exists, or it's dead!
;	
	Mov	DX,0		;return base address, none
SEC_02:
	Mov	io_addr,DX	;save for future use
	Pop	AX
	Pop	CX
	Pop	SI
	Ret

DLCR2_sig_mask	Equ	71h
DLCR4_sig_mask	Equ	08h
DLCR5_sig_mask	Equ	80h
DLCR7_sig_mask	Equ	10h

SearchforEC	endp

;--------------------------------------------------------------------
;
; read_EEPROM_reg - read one of 16 registers in the EEPROM
;
;    input - register address in AL
;   output - register value in AX
;
;--------------------------------------------------------------------
read_EEPROM_reg:

	Push	DX
	Push	CX
	Push	BX
	Push	AX		;used to save data value

	Mov	DX,io_addr
	Add	DX,BMPR16	;get offset to EEPROM ctl reg
	Xor	AX,AX		;clear CS and SK
	Out	DX,AL		;
	Inc	DX		;BMPR17
	Out	DX,AL		;clear EDIO bit
	Dec	DX		;BMPR16
	Mov	AL,EEP_ECS	;set chip select
	Out	DX,AL
	Mov	AL,80h		;set data start bit
	Inc	DX		;set DX to address of BMPR17
	Out	DX,AL
	Mov	AL,EEP_ECS+EEP_ESK ;set CS and clock high
	Dec	DX		;back to addr of BMPR16 (EEPROM CTL Reg)
	Out	DX,AL
	Pop	AX		;get desired address back
	Or	AX,EEP_CMD_READ	;combine reg addr and EEPROM opcode

	Mov	CX,8		;# of bits in data byte
RRE_01:		;top of serial shift out data to EEPROM loop
	Inc	DX		;EEPROM Data register addr
	Out	DX,AL		;set upper bit into serial data register
	Dec	Dx
	Mov	BX,AX		;save AL
	Mov	AL,EEP_ECS	;clock low
	Out	DX,AL
	Or	AL,EEP_ESK	;clock high
	Out	DX,AL
;  bit clocked out, now shift in next bit
	Mov	AX,BX		;get data byte back
	Shl	AL,1		;shift left
	Loop	RRE_01		;

; command byte clocked out, now clock in data bits.  
;   Note: the initial zero bit for data read overlaps the last bit of
;   command byte, and hence is lost.
	Mov	CX,16		;16 bits
	Xor	BX,BX		;need lower byte cleared

rre_02:		;top of loop for shifting in data bits (17 total)
	Mov	AL,EEP_ECS	;clock low
	Out	DX,AL
	Or	AL,EEP_ESK	;clock high
	Out	DX,AL
	Inc	DX		;addr to BMPR17 (EEPROM data reg)
	In	AL,DX		;get a data bit
	shr	al,8		;get into cy
	rcl	bx,1			;move into LSB of bx.
	dec	dx		;back to BMPR16 (EEPROM ctl)
	loop	rre_02

; done, put output data into AX, pop stack, and disappear
	Mov	AX,BX
	Pop	BX
	Pop	CX
	Pop	DX
	Ret

code	ends

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
