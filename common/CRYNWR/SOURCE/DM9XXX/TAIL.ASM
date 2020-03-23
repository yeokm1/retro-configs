;*****************************************************************************
;* Name : TAIL.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description : Process DOS & hardware interface, include:
;*	. Hardware resource decide.(IRQ, I/O)
;*	. Initializes DM9100 ethernet card.
;*	. Parsing parameters & options.
;*	. Setup interrupt vector.
;*	. Resident code in the memory.
;*
;* Functions :
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96'
;*
;* Change Notes :
;* Date - Modifier
;*     Cause :
;*  Modified :
;*    Result :
;*
; Maintainers:
;
; John H.T. Ho		htho
;
;
; Revision History:
;
; Date	     Modfier.	Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.6.21	htho	set speed/power for HOMEPNA
;
; 2000.6.27	htho	set ignore/send remote command for HOMEPNA
;
; 2000.8.24	htho	support DM9009(DM9102 without 100M PHY capability)
;			support VLAN & Tx/Rx flow control
;
; 2001.3.30	htho	support HPNA speed setting
;
; 2001.6.12	htho	command line option bug -x
;
; 2001.6.21	htho	revise phy duplex mode display while force mode
;
;*****************************************************************************
.model	tiny
.386
	include defs.asm
code	segment para public
	assume	cs:code, ds:code

;;++
;;++, 2000.1.31, hu-tiong
;IFDEF	 DEBUGDOS
;extrn	 init_debug: near
include debug.inc
;ENDIF
;;++
extrn	initpci: near
extrn	io_addr: word
EXTRN	InitPIDataRate : WORD
EXTRN	SROMPortFlag : BYTE
EXTRN	p_CR0 : WORD
	extrn	int_no: byte		;the board's interrupt level.
	extrn	driver_class: byte	;the class of this driver, per the spec.
	extrn	rcv_modes: word 	;count of modes followed by mode handles.
	EXTRN	rcv_mode_num : WORD

;-> last byte of static memory used by driver-dependent code.
	extrn	end_resident: byte
	extrn	end_free_mem: byte

;-> the fixed address of the card.
	extrn	rom_address: byte

;-> the current address of the card.
	extrn	my_address: byte

	extrn	phd_dioa: byte
	extrn	phd_environ: word
	extrn	flagword: WORD
;;++, 2000.6.21, htho, set speed/power for HOMEPNA
ifdef HOMEPNA
	extrn	pna_cr16: word
endif
;;++
;;;;++, 2000.6.27, htho, support tx remote command
	extrn	pna_power_cmd: word
	extrn	pna_speed_cmd: word
;;;;++
;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
	extrn	vlan: byte
	extrn	fctx: byte
	extrn	fcrx: byte
;;;;++

;;++, 2001.3.30, htho, support HPNA speed setting
	extrn	LSpeedNum: word
;;++

	PUBLIC	free_mem
free_mem	dw	end_resident	;allocate memory from here.
;also see memory_to_keep.

	include pktutil.asm		;; Parsing & print parameters

	public	malloc
malloc:
;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
	add	dx,free_mem		;make a pointer after that much memory.
	cmp	dx,offset end_free_mem	;is it still in the free area?
	ja	malloc_1		;no, we're in trouble.
	xchg	dx,free_mem		;get the pointer back, store ptr->end.
	clc
	ret
malloc_1:
	stc
	ret


end_tail_1	label	byte		; end of the delayed init driver

;usage_msg is of the form "usage: driver [options] <packet_int_no> <args>"
	extrn	usage_msg: byte

options_i_msg	label	byte
;;--, 980303, Hu-Tiong
;;db"   -i -- Force driver to report itself as IEEE 802.3 instead of Ethernet II.",CR,LF
;;--

options_msg	label	byte
db"  -d           -- Delayed initialization.  Used for diskless booting",CR,LF
db"  -n           -- NetWare conversion. Converts 802.3 packets into 8137 packets",CR,LF
db"  -w           -- Windows hack, obsoleted by winpkt",CR,LF
;;--, 980303, Hu-Tiong
;;db"   -p -- Promiscuous mode disable",CR,LF
;;--
db"  -u           -- Uninstall",CR,LF
;;-+, 980303, Hu-Tiong
;;db"   -a -- Auto-Negotiation Full-Duplex",CR,LF
;;db"   -s -- Force to 10 Mb Speed (default: Half-Duplex)",CR,LF
;;db"   -x -- Force to 100 Mb Speed (default: Half-Duplex)",CR,LF
;;db"   -f -- Force to Full Duplex (default: Half-Duplex)",CR,LF
;;db"   -b -- Force to BNC media", CR, LF
;;db"   PKT9100 is auto-negotiation and half-duplex if there are not options",CR,LF
;;db"   PKT9100 auto-search I/O and IRQ if they are not specified.",CR,LF
db"  -a           -- Auto-Negotiation for both speed and duplex mode",CR,LF
db"  -xf          -- Forced 100Mb/s Full Duplex mode",CR,LF
db"  -xh          -- Forced 100Mb/s Half Duplex mode",CR,LF
db"  -f           -- Forced 10Mb/s Full Duplex mode",CR,LF
db"  -h           -- Forced 10Mb/s Half Duplex mode",CR,LF
ifdef HOMEPNA
db"  -t           -- Forced 1Mb/s HomePNA",CR,LF
db"  -pXsX        -- set power/speed for HOMEPNA to high/low, X = h or l",CR,LF
db"  -ignore=<0~1>-- 1 = ignore remote command (default), 0 = accept",CR,LF
db"  -remcmd=<0~1>-- 0 = disable Tx remote command (default), 1 = enable",CR,LF
endif
db"  -vlan=<0~1>  -- 0 = disable VLAN (default), 1 = enable",CR,LF
db"  -fcrx=<0~1>  -- 0 = disable Rx flow control (default), 1 = enable",CR,LF
db"  -fctx=<0~1>  -- 0 = disable Tx flow control (default), 1 = enable",CR,LF
db"  -lspeed=<1000|500|1400|1600> -- HPNA line speed (default 1000KBps)",CR,LF
db"  -slot=<1~15> -- Select the slot to work with",CR,LF
ifdef HOMEPNA
db"  Adapter is in auto mode if none of [a|xf|xh|f|h|t] option is specified",CR,LF
else
db"  Adapter is in auto mode if none of [a|xf|xh|f|h] option is specified",CR,LF
endif
;;-+
db '$'

extrn	copyright_msg: byte
extrn	branding_msg : byte

;; Orignal source from message
copyleft_msg	label	byte
 db "Packet driver skeleton copyright 1988-93, Crynwr Software.",CR,LF,'$'

;db "This program is freely copyable; source must be available; NO WARRANTY.",CR,LF
;db "See the file COPYING.DOC for details; send FAX to +1-315-268-9201 for a copy.",CR,LF
; db CR,LF,'$'

no_resident_msg label	byte
 db CR,LF,"*** Packet driver failed to initialize the board ***",CR,LF,'$'

;parse_args should parse the arguments.
;called with ds:si -> immediately after the entry_point.
	extrn	parse_args: near

;print_parameters should print the arguments.
	extrn	print_parameters: near

	extrn	our_isr: near, their_isr: dword
	extrn	entry_point: byte

eisa_signature	db	"EISA"

;;++, 2000.6.27, htho, switching adapter support
media_home_sw_msg    db      "Media Type is switching adapter", '$'
;;++
;;;;++, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
	PUBLIC	dm9009_chip_msg, dm9009_warning_msg
dm9009_chip_msg db	CR,LF,"Adapter Type : <<<DAVICOM 10-BaseT PCI Ethernet Adapter>>>", '$'
dm9009_warning_msg db	"WARNING: This adapter supports only -a(auto), -f(10M full), -h(10M half)", '$'
;;;;++

;;++, 2000.1.31, hu-tiong
ifdef HOMEPNA
media_home_pna_msg   db      "Media Type is HOME PNA", '$'
datarate_1_msg	     db      "Data Rate is 1 Mb", '$'
endif
;;++
media_tp_msg	db	"Media Type is TP", '$'
datarate_10_msg db	"Data Rate is 10 Mb",'$'
datarate_100_msg db	 "Data Rate is 100 Mb",'$'
half_duplex_msg db	"Interactive mode is Half-Duplex",'$'
full_duplex_msg db	"Interactive mode is Full-Duplex",'$'
entry_point_name	db	"Packet driver software interrupt is ",'$'
eaddr_msg	db	"My Ethernet address is ",'$'
aaddr_msg	db	"My ARCnet address is ",'$'

already_msg	db	CR,LF,"Error: there is already a packet driver (you may uninstall it using -u) at ",'$'
no_pkint_msg	db	CR,LF,"Error: there is no packet driver at ",'$'
no_pkt_msg	db	CR,LF,"Error: no packet driver found between 0x60 and 0x80",CR,LF,'$'
two_pkts_msg	db	CR,LF,"Error: there are two packets drivers (specify the desired one after -u).",CR,LF,'$'
int_msg 	db	CR,LF
		db	"Error: <hardware_irq> should be between 0 and "
int_msg_num	label	word
		db	"15 inclusive", '$'
io_invalid_msg	db	CR,LF, "Error : no adapter found in I/O ",'$'
xt_hd_warn_msg	db	CR,LF,"Warning: the hard disk on an XT usually uses IRQ 5.  Use a different interrupt",CR,LF,'$'
no_ieee_msg	db	CR,LF,"Error: this driver doesn't implement both IEEE 802.3 and Ethernet II",CR,LF,'$'
terminated_msg	db	"Uninstall completed",'$'

handle		dw	?

entry_point_fnd db	0
bogus_type	db	0,0		;totally bogus type code.

;;++, 980311, Hu-Tiong
	PUBLIC	SlotNum
SlotNum 	dw	0
LotStr		db	"lot"
LOT_STR_LEN	EQU	$-LotStr
SlotNumError	db	CR, LF, "Slot number must be in the range 1..15", CR, LF, '$'
;;++
;;;;++, 2000.6.27, htho
ifdef HOMEPNA
IgnoreStr	db	"gnore"
IGNORE_STR_LEN	EQU	$-IgnoreStr

RemoteStr	db	"emcmd"
REMOTE_STR_LEN	EQU	$-RemoteStr
endif
;;;;++
;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
VlanStr 	db	"lan"
VLAN_STR_LEN	EQU	$-VlanStr
FctxStr 	db	"ctx"
FCTX_STR_LEN	EQU	$-FctxStr
;;;;++
;;++, 2001.3.30, htho, support HPNA speed setting
SpeedStr	db	"speed"
SPEED_STR_LEN	EQU	$-SpeedStr
LSpeedNumError	db	CR, LF, "HPNA LineSpeed number must be one of {1000,500,1400,1600}", CR, LF, '$'
;;++

our_recv:
	xor	di,di
	mov	es,di
	retf

	public	etopen_diagn
etopen_diagn	db	0		; errorlevel from etopen if set

;etopen should initialize the device.  If it needs to give an error, it
;can issue the error message and quit to dos.
	extrn	etopen: near

memory_to_keep	dw	end_resident	;keep at least this much memory.
;also see free_mem.
;;-------------------------------------------------------------------------

already_error:
	mov	dx,offset already_msg
already_error_1:
	mov	di,offset entry_point
	call	print_number
	mov	ax,4c05h		; give errorlevel 5
	int	21h

usage_error:
;;--- Print usage option
	mov	dx,offset usage_msg
	mov	ah,9
	int	21h

	mov	dx,offset options_msg
	cmp	word ptr driver_class,BLUEBOOK + IEEE8023*256	;both present?
	jne	error
	mov	dx,offset options_i_msg

	public	error
error:
	mov	ah,9
	int	21h
error1:
	mov	ax,4c0ah		; give errorlevel 10
	int	21h		;; Terminate Precess

;;*************************************************************
;;--- Start jump here
;;*************************************************************
	public	start_1
start_1:
	cld
;;--- Print title when loading time
	mov	dx,offset copyright_msg 	;;Show Version
	mov	ah,9
	int	21h

	mov	dx,offset copyleft_msg		;;Show Crynwr Software message
	mov	ah,9
	int	21h

	mov	dx,offset branding_msg		;;Vendor message(DAVICOM.ASM)
	mov	ah,9
	int	21h

;;--- Parser parameters
processor_identified:
	mov	si,offset phd_dioa+1	;; Point to DTA(Disk Transfer Area)
	call	skip_blanks		;end of line?
	cmp	al,CR
	je	usage_error_j_1 	;; Show usage if have not paramteters.

chk_options:
	call	skip_blanks
	cmp	al,'-'                  ; any options?
	jne	no_more_opt
	inc	si			; skip past option char
	lodsb				; read next char
	or	al,20h			; convert to lower case
;;++, 2000.6.21, htho, set speed/power for HOMEPNA
ifdef HOMEPNA
	cmp	al, 'p'
	jne	not_p_opt
	lodsb
	or	al, 20h
	cmp	al, 'h'
	jne	not_ph_option

	or	pna_cr16, 0002h 	; high power
	mov	pna_power_cmd, 0400h
	jmp	check_speed_opt
not_ph_option:
	cmp	al, 'l'
	jne	usage_error

	and	pna_cr16, NOT 0002h	; low power
	mov	pna_power_cmd, 0800h

check_speed_opt:
	lodsb
	or	al, 20h
	cmp	al, 's'
	jne	usage_error

	lodsb
	or	al, 20h

	cmp	al, 'h'
	jne	not_sh_option

	or	pna_cr16, 0004h 	; high speed
	mov	pna_speed_cmd, 0100h
	jmp	chk_options
not_sh_option:
	cmp	al, 'l'
	jne	usage_error

	and	pna_cr16, NOT 0004h	; low speed
	mov	pna_speed_cmd, 0200h
	jmp	chk_options

not_p_opt:
endif
;;++
;;;;++, 2000.6.27, htho
ifdef HOMEPNA
	cmp	al, 'i'
	jne	not_ignore_opt

	call	check_ignore_option
	jc	usage_error
	jmp	chk_options

not_ignore_opt:
	cmp	al, 'r'
	jne	not_remote_opt

	call	check_remote_option
	jc	usage_error
	jmp	chk_options

not_remote_opt:
endif
;;;;++
;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
	cmp	al, 'v'
	jne	not_vlan_opt

	call	check_vlan_option
	jc	usage_error
	jmp	chk_options

not_vlan_opt:
;;--, 2001.6.5, confused with "-f" force full duplex
if 0
	cmp	al, 'f'
	jne	not_flowctl_opt

	call	check_fc_option
	jc	usage_error
	jmp	chk_options

not_flowctl_opt:
endif
;;--
;;;;++

	cmp	al,'d'
	jne	not_d_opt
	or	flagword,D_OPTION
	jmp	chk_options
not_d_opt:
	cmp	al,'n'
	jne	not_n_opt
	or	flagword,N_OPTION
	jmp	chk_options
not_n_opt:
	cmp	al,'w'
	jne	not_w_opt
	or	flagword,W_OPTION
	jmp	chk_options
not_w_opt:
;;--, 2000.6.21, htho, set speed/power for HOMEPNA
COMMENT %
	cmp	al,'p'
	jne	not_p_opt
	cmp	rcv_modes,6		;do they even *have* a promiscuous mode?
	jbe	chk_options		;no.
	mov	rcv_modes+2[6*2],0	;yes, nuke it.
	jmp	chk_options
not_p_opt:
%
;;--
	cmp	al,'u'
	jne	not_u_opt
	or	flagword,U_OPTION
	jmp	chk_options

not_u_opt:
COMMENT %, --, 980303, Hu-Tiong
	cmp	al, 's'
	jne	not_s_opt
	or	flagword, S_OPTION
	jmp	chk_options

not_s_opt:
%
	cmp	al, 'x'
	jne	not_xs_opt
;;++, 980303, Hu-Tiong
	lodsb
	or	al, 20h
	cmp	al, 'f'
	jne	not_xf_opt
	or	flagword, XF_OPTION	; -xf, 100M full duplex
	jmp	chk_options

not_xf_opt:
	cmp	al, 'h'
;;-+, 2001.6.12, htho, command line option bug -x
;;	jne	not_xs_opt
	jne	usage_error
;;-+
	or	flagword, XH_OPTION	; -xh, 100M half duplex
	jmp	chk_options
;;++
;;--
;;	or	flagword, XS_OPTION
;;	jmp	chk_options
;;--

not_xs_opt:
	cmp	al, 'a'
	jne	not_a_opt
	or	flagword, A_OPTION
	jmp	chk_options

not_a_opt:
	cmp	al, 'f'                         ; -f, 10M full duplex
	jne	not_f_opt

;;++, 2001.6.5, confused with "-f" force full duplex
	call	check_fc_option
	jnc	chk_options

	cmp	al, ' '
	jne	usage_error
;;++
	or	flagword, F_OPTION
	jmp	chk_options

not_f_opt:
;;++, 980303, Hu-Tiong
	cmp	al, 'h'
	jne	not_h_opt
	or	flagword, H_OPTION		; -h, 10M half duplex
	jmp	chk_options

not_h_opt:
;;++
;;++2000.1.31, Hu-Tiong
ifdef HOMEPNA
	cmp	al, 't'
	jne	not_t_opt
	or	flagword, T_OPTION
	jmp	chk_options
not_t_opt:
endif
;;++
	cmp	al,'i'
	jne	not_i_opt
	mov	dx,offset no_ieee_msg
	cmp	word ptr driver_class,BLUEBOOK + IEEE8023*256	;both present?
;;	  mov	  dx,offset no_ieee_msg
	jne	usage_error_j_1 	;no - give error
	mov	word ptr driver_class,IEEE8023 + BLUEBOOK*256	;yes, swap them.
	jmp	chk_options
not_i_opt:
;;-+, 980311, Hu-Tiong
COMMENT %
	cmp	al, 'b'
	jne	not_b_opt
	mov	flagword, B_OPTION	   ;; BNC media
	jmp	chk_options

not_b_opt:
%
	cmp	al, 's'
	jne	not_slot_opt

	mov	bx, offset LotStr	; check following parameter is "lot"
	mov	cx, LOT_STR_LEN
CheckNextLotChar:
	lodsb				; read next parameter character
	or	al, 20h 		; convert to lower case
	cmp	al, [bx]		; check if it's "lot"
	jne	not_slot_opt
	inc	bx			; advance to next char in "lot"
	loop	CheckNextLotChar

	call	skip_blanks
	cmp	al, '='
	jne	not_slot_opt
	inc	si			; skip to next char following '='

	call	skip_blanks

	mov	di, offset SlotNum
	call	get_number		; get the value of slot# in [SlotNum]

	cmp	SlotNum, 1		; check if slot# in the rage 1~15
	jl	error_slot_num
	cmp	SlotNum, 15
	jg	error_slot_num
	jmp	chk_options

error_slot_num:
	mov	dx, offset SlotNumError
	jmp	error
not_slot_opt:
;;-+
;;++, 2001.3.30, htho, support HPNA speed setting
	cmp	al, 'l'
	jne	not_slot_opt

	mov	bx, offset SpeedStr	; check following parameter is "speed"
	mov	cx, SPEED_STR_LEN
CheckNextSpeedChar:
	lodsb				; read next parameter character
	or	al, 20h 		; convert to lower case
	cmp	al, [bx]		; check if it's "lot"
	jne	not_lspeed_opt
	inc	bx			; advance to next char in "lot"
	loop	CheckNextSpeedChar

	call	skip_blanks
	cmp	al, '='
	jne	not_slot_opt
	inc	si			; skip to next char following '='

	call	skip_blanks

	mov	di, offset LSpeedNum
	call	get_number		; get the value of slot# in [SlotNum]

	cmp	LSpeedNum, 1000 	 ; check if speed in {1000, 500, 1400, 1600}
	je	lspeed_got
	cmp	LSpeedNum, 500
	je	lspeed_got
	cmp	LSpeedNum, 1400
	je	lspeed_got
	cmp	LSpeedNum, 1600
	jne	error_lspeed_num
lspeed_got:
	jmp	chk_options

error_lspeed_num:
	mov	dx, offset LSpeedNumError
	jmp	error
not_lspeed_opt:
;;-+
usage_error_j_1:
	jmp	usage_error

no_more_opt:
	mov	di,offset entry_point	;parse the packet interrupt number
	call	get_number		;  for them. Return to DI.(PKTUTIL.ASM)
	test	flagword,U_OPTION	;should we terminate the driver?
	jz	not_terminate		;; go to hardware initialize.

terminate:		;; U_OPTION
;; Unload one if assign vector, otherwise unload all vector.
	cmp	entry_point,0		;did they ask for the default?
	jne	terminate_int_ok	;no, run with it.
	mov	entry_point,60h

terminate_check_int:
	call	verify_packet_int
	jc	terminate_check_int_1	;; cy, INT No. is incorrect.
	jne	terminate_check_int_1	;; nc, nz, INT No. there is no packet driver
	cmp	entry_point_fnd,0	;did we already find one?
	jne	terminate_check_int_2	;yes, it's ambiguous - give error.
	mov	al,entry_point		;no, remember it.
	mov	entry_point_fnd,al
terminate_check_int_1:
	inc	entry_point		;go look at the next one
	cmp	entry_point,80h
	jbe	terminate_check_int	;keep going to the end.

	mov	al,entry_point_fnd	;restore the last one found.
	mov	entry_point,al
	cmp	entry_point_fnd,0	;did we find one?
	jne	terminate_int_ok	;yes.
	mov	dx,offset no_pkt_msg	;no packet drivers installed!
	jmp	error
terminate_check_int_2:
	mov	dx,offset two_pkts_msg	;two packet drivers - which one??
	jmp	error

terminate_int_ok:
	call	verify_packet_int	;is the one they specified acceptable?
	jnc	terminate_1		;no, it's not in range.
	jmp	error
terminate_1:
	je	terminate_2		;go if we found a signature.
	mov	dx,offset no_pkint_msg	;no packet driver there.
	jmp	already_error_1

terminate_2:
	mov	their_isr.offs,bx	;;
	mov	their_isr.segm,es

	mov	ax,1ffh 		;driver_info
	pushf
	cli
	call	their_isr
	call	fatal_error
	movseg	ds,cs

	mov	ah,2			;access_type
	mov	al,ch			;their class from driver_info().
	mov	bx,dx			;their type from driver_info().
	mov	dl,cl			;their number from driver_info().
	mov	cx,2			;use type length 2.
	mov	si,offset bogus_type
	movseg	es,cs
	mov	di,offset our_recv
	pushf
	cli
	call	their_isr
	call	fatal_error
	mov	handle,ax

	mov	ah,5			;terminate the driver.
	mov	bx,handle
	pushf
	cli
	call	their_isr
	jnc	now_close
	call	print_error
	mov	ah,3			;release_type
	mov	bx,handle
	pushf
	cli
	call	their_isr
	int	20h
now_close:
;;--, 980615, Hu-Tiong, System hangs while releasing packet driver
;;    with command option -u if EMM386 installed
COMMENT %
;;--- Reset DM9X to avoid hang.
	mov	dx, p_CR0
	mov	eax, 1
	out	dx, eax
%
;;--

	mov	dx,offset terminated_msg
	mov	ah,9
	int	21h
	int	20h

usage_error_j_2:
	jmp	usage_error

not_terminate:
	call	parse_args		;;Saved int_no & io_addr from arguments.
	jc	usage_error_j_2

	call	skip_blanks		;end of line?
	cmp	al,CR
	jne	usage_error_j_2

	call	initpci 		;; Get io_addr & int_no
	cmp	ax, 0
	jne	error1

pciok:
	call	verify_packet_int	;;Return: nc,zr -> There is packet driver
	jnc	packet_int_ok		;;	  nc,nz -> There is no packet driver
	jmp	error
packet_int_ok:
	jne	packet_int_unused	;; nz
	jmp	already_error		;give an error if there's one there.

packet_int_unused:
no_mapping_needed:

; If they chose the -d option, don't call etopen when we are loaded,
; but when we are called for the first time
;
; Save part of the tail, needed by delayed etopen
	test	flagword,D_OPTION
	jz	open_now
	mov	memory_to_keep,offset end_tail_1	; save first part of tail
	jmp	delayed_open_1
open_now:
;;++, 2000.1.31, hu-tiong
IFDEF	DEBUGDOS
	call	init_debug
ENDIF	;-- DEBUGDOS
;;++
	call	etopen			;init the driver.  If any errors,
					;this routine returns cy.

	jnc	yes_resident
	jmp	no_resident

yes_resident:

	call	crlf
;;--- print media type for autodetect
;;++, 2000.6.27, htho, switching adapter support
	extrn	switch_adapter: byte
	cmp	switch_adapter, 0
	jne	media_not_sw_adapt
	mov	dx, OFFSET media_home_sw_msg
media_not_sw_adapt:
;;++
ifdef HOMEPNA
	cmp	SROMPortFlag, 4
	jne	printtp
;;-+, 2000.1.31, hu-tiong
;;	mov	dx, OFFSET media_bnc_msg
	mov	dx, OFFSET media_home_pna_msg
;;-+
	jmp	print_media
printtp:
endif
	mov	dx, OFFSET media_tp_msg
print_media:
	call	printmsg		;; print msg with CR/LF

;;--- print data rate
printspeed:
	cmp	InitPIDataRate, 100
	je	print100Mb
;;++, 2000.1.31, hu-tiong
ifdef HOMEPNA
	cmp	InitPIDataRate, 10
	je	print10Mb
	mov	dx, OFFSET datarate_1_msg
	jmp	print_datarate
print10Mb:
endif
;;++
	mov	dx, OFFSET datarate_10_msg
	jmp	print_datarate
print100Mb:
	mov	dx, OFFSET datarate_100_msg
print_datarate:
	call	printmsg

;; --- print interactive mode
;;-+, 2001.6.21, htho, revise phy duplex mode display while force mode
	test	flagword, A_OPTION
	jnz	print_auto_result
	test	flagword, XF_OPTION OR F_OPTION
	jnz	print_fd
	jmp	print_hd
print_auto_result:
	cmp	SROMPortFlag, 1
	je	print_fd
print_hd:
;;-+
	mov	dx, OFFSET half_duplex_msg
	jmp	print_duplex
print_fd:
	mov	dx, OFFSET full_duplex_msg
print_duplex:
	call	printmsg

	mov	di,offset entry_point
	mov	dx,offset entry_point_name
	call	print_number

	call	print_parameters	;echo our parameters.
	or	flagword,CALLED_ETOPEN	;; or 01h

	cmp	driver_class,BLUEBOOK	;Blue Book Ethernet?
	je	print_eaddr		;yes.
	cmp	driver_class,IEEE8023	;IEEE 802.3 Ethernet?
	jne	print_addr_2		;no, don't print what we don't have.

print_eaddr:
	mov	dx,offset eaddr_msg
	mov	ah,9
	int	21h

	mov	si,offset rom_address
	call	print_ether_addr

	call	crlf

print_addr_2:

	cmp	driver_class,8		;ARCnet?
	jne	print_addr_3		;no, don't print what we don't have.

	mov	dx,offset aaddr_msg
	mov	ah,9
	int	21h

	mov	al,rom_address
	mov	cl,' '                  ;Don't eliminate leading zeroes.
	call	byteout

	call	crlf

print_addr_3:
delayed_open_1:
	mov	ah,35h			;remember their packet interrupt.
	mov	al,entry_point
	int	21h
	mov	their_isr.offs,bx
	mov	their_isr.segm,es

	mov	ah,25h			;install our packet interrupt
	mov	dx,offset our_isr
	int	21h

	mov	ah,49h			;free our environment, because
	mov	es,phd_environ		;  we won't need it.
	int	21h

	mov	bx,1			;get the stdout handle.
	mov	ah,3eh			;close it in case they redirected it.
	int	21h

	test	flagword,D_OPTION
	jne	f_release_type_1	;no.
	cmp	rcv_modes+2[3*2],0	;does mode 3 exist?
	je	f_release_type_1	;no.
	call	rcv_modes+2[3*2]	;  call it.

f_release_type_1:
	mov	dx,memory_to_keep	;keep the greater of this and
	cmp	dx,free_mem		;  free_mem.
	jae	go_resident
	mov	dx,free_mem

go_resident:
	add	dx,0fh			;round up to next highest paragraph.
	mov	cl,4
	shr	dx,cl
	mov	ah,31h			;terminate, stay resident.
	mov	al,etopen_diagn 	; errorlevel (0 - 9, just diagnostics)
	int	21h

no_resident:
;;	  mov	  ah,9			  ;print their error message.
;;	  int	  21h

	mov	dx,offset no_resident_msg
	mov	ah,9
	int	21h

	mov	ax,4c00h + 32		; give errorlevel 32
	cmp	al,etopen_diagn
	ja	no_et_diagn		; etopen gave specific reason?
	mov	al,etopen_diagn 	; yes, use that for error level
no_et_diagn:
	int	21h

;			Suggested errorlevels:
;
; _____________________  0 = normal
;			 1 = unsuitable memory address given; corrected
; In most cases every-	 2 = unsuitable IRQ level given; corrected
; thing should work as	 3 = unsuitable DMA channel given; corrected
; expected for lev 1-5	 4 = unsuitable IO addr given; corrected (only 1 card)
; _____________________  5 = packet driver for this int # already loaded
; External errors, when 20 = general cable failure (but pkt driver is loaded)
; corrected normal	21 = network cable is open	       -"-
; operation starts	22 = network cable is shorted	       -"-
; _____________________ 23 =
; Packet driver not	30 = usage message
; loaded. A new load	31 = arguments out of range
; attempt must be done	32 = unspecified device initialization error
;			33 =
;			34 = suggested memory already occupied
;			35 = suggested IRQ already occupied
;			36 = suggested DMA channel already occupied
;			37 = could not find the network card at this IO address

;;;;++, 2000.6.27, htho
ifdef HOMEPNA
check_ignore_option proc
	mov	bx, offset IgnoreStr	; check following parameter is "lot"
	mov	cx, IGNORE_STR_LEN
CheckNextIgnoreChar:
	lodsb				; read next parameter character
	or	al, 20h 		; convert to lower case
	cmp	al, [bx]		; check if it's "lot"
	jne	err_ignore_opt
	inc	bx			; advance to next char in "lot"
	loop	CheckNextIgnoreChar

	call	skip_blanks
	cmp	al, '='
	jne	err_ignore_opt
	inc	si			; skip to next char following '='

	call	skip_blanks
	inc	si

	cmp	al, '0'
	jne	chk_ignore
	and	pna_cr16, NOT 8000h
	clc
	ret
chk_ignore:
	cmp	al, '1'
	jne	err_ignore_opt
	or	pna_cr16, 8000h
	clc
	ret

err_ignore_opt:
	stc
	ret
check_ignore_option endp

	extrn	send_remote_cmd: byte
check_remote_option proc
	mov	bx, offset RemoteStr	; check following parameter is "lot"
	mov	cx, REMOTE_STR_LEN
CheckNextRemoteChar:
	lodsb				; read next parameter character
	or	al, 20h 		; convert to lower case
	cmp	al, [bx]		; check if it's "lot"
	jne	err_remote_opt
	inc	bx			; advance to next char in "lot"
	loop	CheckNextRemoteChar

	call	skip_blanks
	cmp	al, '='
	jne	err_remote_opt
	inc	si			; skip to next char following '='

	call	skip_blanks
	inc	si

	cmp	al, '0'
	jb	err_remote_opt
	cmp	al, '1'
	ja	err_remote_opt

	sub	al, '0'
	mov	send_remote_cmd, al
	clc
	ret

err_remote_opt:
	stc
	ret
check_remote_option endp
endif
;;;;++
;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
check_vlan_option proc
	mov	bx, offset VlanStr	; check following parameter is "lan"
	mov	cx, VLAN_STR_LEN
CheckNextVlanChar:
	lodsb				; read next parameter character
	or	al, 20h 		; convert to lower case
	cmp	al, [bx]		; check if it's "lan"
	jne	err_vlan_opt
	inc	bx			; advance to next char in "lot"
	loop	CheckNextVlanChar

	call	skip_blanks
	cmp	al, '='
	jne	err_ignore_opt
	inc	si			; skip to next char following '='

	call	skip_blanks
	inc	si

	cmp	al, '0'
	jne	chk_vlan
	mov	vlan, 0 		; disable VLAN
	clc
	ret
chk_vlan:
	cmp	al, '1'
	jne	err_vlan_opt
	mov	vlan, 1 		; enable VLAN
	clc
	ret

err_vlan_opt:
	stc
	ret
check_vlan_option endp

check_fc_option proc
	xor	ah, ah			; ah = 0 (assume its tx flow control)
	mov	bx, offset FctxStr	; check following parameter is "ctx"
	mov	cx, FCTX_STR_LEN
CheckNextFctxChar:
	lodsb				; read next parameter character
	or	al, 20h 		; convert to lower case
	cmp	al, [bx]		; check if it's "lan"
	je	@F
	cmp	al, 'r'
	jne	err_fc_opt
	mov	ah, 1
@@:
	inc	bx			; advance to next char in "lot"
	loop	CheckNextFctxChar

get_fc_value:
	call	skip_blanks
	cmp	al, '='
	jne	err_ignore_opt
	inc	si			; skip to next char following '='

	call	skip_blanks
	inc	si

	cmp	al, '0'
	jne	chk_fc
	cmp	ah, 0
	jne	disable_fcrx
disable_fctx:
	mov	fctx, 0
	jmp	@F
disable_fcrx:
	mov	fcrx, 0
@@:
	clc
	ret
chk_fc:
	cmp	al, '1'
	jne	err_fc_opt
	cmp	ah, 0
	jne	enable_fcrx
enable_fctx:
	mov	fctx, 1
	jmp	@F
enable_fcrx:
	mov	fcrx, 1
@@:
	clc
	ret

err_fc_opt:
	stc
	ret
check_fc_option endp
;;;;++

	include verifypi.asm
	include printea.asm
	include pkterr.asm

code	ends

	end
