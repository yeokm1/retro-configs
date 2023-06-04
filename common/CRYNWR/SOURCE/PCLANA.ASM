	Title	pclana -- IBM PC LAN or SYTEK 6120 Packet Driver Interface
	Page	,132
version	equ	5

;
;       COPYRIGHT (c) 1989, Kevin J. Rowett -- N6RCE
;          Cupertino, CA
;

;
;   implements the body of a packet driver supporting the 
;   IBM PC network LAN adapter (LANA), also known as a SYTEK 6120
;   card.
;
;   These cards have an on-board (now known as version 1) NETBIOS
;   interface, accessed via INT 5C.
;
;   The cards implement networking with their own OSI style session
;   and transport protocols. The MAC layer is almost raw 802.3
;
;   While the card has a connected mode session protocol available,
;   our implementation uses the DATAGRAM mode.  Packets are sent and
;   received as datagrams using the PROM supplied MAC address. 
;   Broadcast packets are send/received using the DATAGRAM BROADCAST
;   mode.
;
;   The card is not nice enough to interrupt us when a frame has
;   arrived.  We must supply it a buffer to put the frame into
;   as it arrives.  Therefore, we have one DATAGRAM and DATAGRAM
;   BROADCAST buffer defined here.  Of course, if we don't empty
;   it fast enough, the next arriving frame will go into the bit 
;   bucket :-).  Some might view this as a performance problem.
;   So does the author :-(.
;
;   We reserve another NCB for control.
;
;   Why bother you ask? So, N3EUA can demo N6GN's uwv talents.
;

	Page
	include	defs.asm	;SEE ENCLOSED COPYRIGHT MESSAGE

	Page
code	segment	byte public
	assume	cs:code, ds:code

	public	int_no
int_no		db	3,0,0,0		;we don't use it, but tail.asm wants to
							;fix it if this is an AT

	public	lana_num
lana_num	db	0,0,0,0

	public	mac_addr
mac_addr		db	6 dup (0)
ether_broadcast	db	6 dup (0FFh)

	public	driver_class, driver_type, driver_name
driver_class	db	1		;from the packet spec
driver_type	db	16		;from the packet spec
driver_name	db	'pclana',0	;name of the driver.

savess		Dw	?
savesp		Dw	?

;
;  Struct defining a std NCB layout
;
NCB	Struc


NCB_COMMAND	Db	?  				;NCB command field
NCB_RETCODE	Db	?  	
NCB_LSN		Db	?  				;local session number
NCB_NUM		Db	?				;NCB number of your name
NCB_BUFFER	Dd	?				;FAR ptr to buffer
NCB_LENGTH	Dw	?				;bufer length
NCB_CALLNAME	Db	16 dup (?)	;name on local or remote adapter
NCB_NAME	Db	16 dup (?)		;name on local adapter
NCB_RTO		Db	?				;receive timeout value
NCB_STO		Db	?				;send timeout value
NCB_POST		Dd	?			;far ptr to post completion rtn
NCB_LANA_NUM	Db	?			;adapter number 0 or 1
NCB_CMD_CPLT	Db	?			;cmd status flag
NCB_RESERVE 	Db	14 dup (?)	;reserved work area

previous_error	Db	?
immediate_error	Db	?
active_flag		Db	?	;have we done an INT on this NCB?
NCB_link		Dw	?			;offset to next NCB

NCB_data_buffer	Db	512 dup (0)

NCB			ends

NETBIOS		Equ		5CH

MAX_LANA_BUF_LEN	Equ	512
ncb_count		Equ	5
NCB_in_use	Equ	0FFH
NCB_unused	Equ	00H

CTL_NCB	Db	(size NCB) dup (0)

RCV_NCB	Db	ncb_count*(size NCB) dup (0)

RCV_BDCST_NCB	Db	ncb_count*(size NCB) dup (0)

SEND_NCB	Db	(size NCB) dup (0)

SEND_BDCST_NCB	Db	(size NCB) dup (0)

send_in_use	Db	00H
recv_in_use	Db	00H

stack		Dw	100 dup (?)

;
;   cmd codes for the LANA
;
LANA_RESET	Equ	32H				;RESET, waited mode
LANA_ADPTS	Equ	33H				;Adapter status, waited mode
LANA_SENDDG	Equ	0A0H			;SEND DATAGRAM, nowait mode
LANA_SENDDG_BDCST	Equ	0A2H	;SEND BROADCAST DATAGRAM, nowait 
LANA_RCVDG	equ	0A1H			;RCV DATAGRAM, nowait
LANA_RCVDG_BDCST	Equ	0A3H	;RCV BROADCAST DATAGRAM, nowait
LANA_TEST_PRES		Equ	7FH		;TEST IF LANA Present (inv cmd)

    Subttl	send_pkt
	Page
	public	send_pkt
send_pkt:
;enter with ds:si -> packet, cx = packet length.
;exit with nc if ok, or else cy if error, dh set to error number.

	
	assume	ds:nothing
;  better protect our selves
	Pushf
	Cli
	Nop 	;03H
	Cmp	CS:send_in_use,NCB_in_use
	Jne	not_reentered_s
	Int	03H

not_reentered_s:
	Mov	send_in_use,NCB_in_use

;  check to see if the recv routine is active
	Cmp	CS:recv_in_use,NCB_in_use
	Jne	not_reentered_r_wins
	Int	03H

not_reentered_r_wins:

	Popf
	Pushf

;  check the length
	Cmp		CX,MAX_LANA_BUF_LEN
	Jb		ok_send_len
	Mov		CX,MAX_LANA_BUF_LEN
ok_send_len:

;
;  Determine if the destination is broadcast
;   real ethernet uses the DMAC of all FFh for broadcast
;   The LANA does as well, but it wants us to use a different
;	NCB type.
;
	Push	SI						;save ptr to start of buffer
	Push	CX						;and original length of packet
	Mov		CX,6
	Mov		DI,offset ether_broadcast
	Push	CS
	Pop		ES
	Cld
	Repe	Cmpsb
	Pop		CX
	Pop		SI
	Jz		send_bdcst
	Jmp		send_dgram
;
send_bdcst:
;
;  send in broadcast mode
;
	Mov		BX,offset  SEND_BDCST_NCB
	Jmp		send_ncb_prep
	
send_dgram:
;
;  send in datagram mode
;
	Mov		BX,offset  SEND_NCB
	Jmp		send_ncb_prep


send_ncb_prep:

; check previous send operation completed. Note, we prime the value of
; this field during etopen ( retcode = 00H, cmd_cplt = 00H )
sendb_cplt_loop:
	Cmp		[BX].NCB_CMD_CPLT,0FFh
  	Je		sendb_cplt_loop
	Jne		sendb_cplt
	Int	03H
	Popf
	Stc
	Ret

sendb_cplt:
;
	Push	CS
	Pop	ES
	Mov		AL,ES:[BX].NCB_RETCODE
	Mov		ES:[BX].previous_error,AL
;  the NCB is ours. Initialize it.
	Call	init_ncb
;
;	setup the length field
;
	Mov		ES:[BX].NCB_LENGTH,CX
;
;	Move the destination address into CALLNAME
;
	Lea		DI,ES:[BX].NCB_CALLNAME+10
	Push	CX
	Mov		CX,6
	Push	SI
	Rep		Movsb
	Pop		SI
	Pop		CX
;
;	Move the data to the buffer
;
	Lea		DI, ES:[BX].NCB_data_buffer
	Rep	Movsb
;
;	NCB is prepared and ready to go
;
;	note, we don't load the cmd field, since init will do this
;   for us, and the LANA never alters it
;
	Int		NETBIOS
	Mov		ES:[BX].immediate_error,AL
	Cmp		AL,00H
	Je		okay_send_ret
	Mov		DH,CANT_SEND
	Mov	CS:send_in_use,NCB_unused
	Int 	03H
	Popf
	Stc
	Ret

okay_send_ret:
	Mov		DH,00H
	Mov	CS:send_in_use,NCB_unused
	Popf
	Clc
	Ret
	


    Subttl	get_address
	Page
	public	get_address
get_address:
;get the address of the interface.
;enter with es:di -> place to get the address, cx = size of address buffer.
;exit with nc, cx = actual size of address, or cy if buffer not big enough.

	assume	ds:code
	Cmp		CX,6
	Jb		get_address_2
	Mov		CX,6						;count of bytes to copy
	Cld									;increment addr index
	Mov		si,OFFSET mac_addr
;       dest is a callng parameter
	Rep		Movsb
	Mov		CX,6
	Clc
	Ret
get_address_2:
	Stc
	Ret

    Subttl	set_address
	Page
;Set Ethernet address on controller
	public	set_address
set_address:
	assume	ds:nothing
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
;
	stc
set_address_done:
	push	cs
	pop	ds
	assume	ds:code
	ret


    Subttl	reset_interface
	Page
	public	reset_interface
reset_interface:
;reset the interface.
;    RESET the LANA
;
	Mov		BX,offset CTL_NCB
	Call	init_ncb
	Mov		[BX].NCB_COMMAND,LANA_RESET
	Mov		[BX].NCB_LSN,01H			;number of sessions to support
	Mov		[BX].NCB_NUM,06H			;number of commands to support
	Int		NETBIOS
;
	Ret


    Subttl	
	Page
;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type.
	extrn	recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn	recv_copy: near

	extrn	count_in_err: near
	extrn	count_out_err: near

    Subttl	recv
	Page
	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code

	Mov		AL,ES:[BX].NCB_RETCODE
	Mov		ES:[BX].previous_error,AL
	Les		DI,ES:[BX].NCB_BUFFER
;
;  Check if it is from ourselves ( we hear our own broadcasts), if
;  so, then ignore it.
;
	Add		DI,6					;point to SMAC
	Mov		CX,6
	Mov		SI,offset mac_addr
	Cld
	Repe	Cmpsb
	Jz		drop_frame				;it's from ourselves
	
;  after the above, we have no idea where DI is pointing

	Les		DI,ES:[BX].NCB_BUFFER
	Add		DI,12				;point to frame type field
	Mov		CX,ES:[BX].NCB_LENGTH
	Push	BX
	Nop	;03H
	Call	recv_find
; returns with buffer ptr in ES:DI, or null if not buffer allocated

	Pop		BX
	Mov		AX,ES					;did we get a buffer ptr back?
	Or		AX,DI
	Je		drop_frame

	Push	ES						;remember ptr to appl's buffer
	Push	DI

	Mov		CX,DS:[BX].NCB_LENGTH
	Lds		SI,DS:[BX].NCB_BUFFER

	Cld
	Rep		Movsb
	
	Mov		CX,DS:[BX].NCB_LENGTH
	Pop		SI
	Pop		DS
	Call	recv_copy

drop_frame:

;
;   to keep receiving of frames, we need to put another NCB
;   to the LANA.  The NCB's are chained in a single forward linked
;   list.  We loop thru it looking for one to use.

	Push	CS
	Pop	DS
	Push	BX		;we'll need to get back to the one
				;we started with
	Mov	CX,ncb_count	;loop counter
	Dec	CX		;since at least one is in use!
src_free_recv_NCB:
	Mov	BX,[BX].NCB_link	;link to the next NCB
	Cmp	[BX].active_flag,NCB_unused  ;this guy free?
	Je	fnd_free_recv_NCB	;yea! use him
	Loop	src_free_recv_NCB	;no, keep looking
	Pop	BX			;didn't find a free NCB
	Jmp	no_free_recv_NCB	;but that is okay

fnd_free_recv_NCB:

	Push	CS
	Pop	ES
	Call	init_ncb
	Mov	AX,offset lana_post_recv
	Mov	word ptr  ES:[BX].NCB_POST,AX
	Mov	AX,ES
	Mov	word ptr  ES:[BX].NCB_POST+2,AX
	Mov	[BX].NCB_LENGTH,MAX_LANA_BUF_LEN
	Mov	[BX].active_flag,NCB_in_use

	Int	NETBIOS
	Mov	[BX].immediate_error,AL
	Pop	BX

no_free_recv_NCB:
	Mov	[BX].active_flag,NCB_unused

	Ret

	Subttl	lana_post_recv
	Page
lana_post_recv:
;
;  come here when the LANA posts open of the RECV NCB's as complete
;
;  AL = RetCode
;  CS = set to this code segment
;  ES = of the NCB
;  BX = offset of the NCB
;  we don't need to preserve any of the registers, since the LANA
;  BIOS has already done that.

	
;  check to see if this is a recursive reenter
	Cmp	CS:recv_in_use,NCB_in_use
	Jne	not_reentered_r
	Int	03H

not_reentered_r:
	Mov	recv_in_use,NCB_in_use

;  check to see if the send routine is active
	Cmp	CS:send_in_use,NCB_in_use
	Jne	not_reentered_s_winr
	Int	03H

not_reentered_s_winr:

	Mov		AX,CS
	Mov		DS,AX

	Mov		savesp,SP
	Mov		savess,SS

	Mov		SS,AX
	Mov		SP,offset stack

	Call	Recv

	Mov	recv_in_use,NCB_unused
	Push	CS
	Pop		DS
	Mov		SS,savess
	Mov		SP,savesp
	
	Iret
	
    Subttl	init_ncb
	Page
init_ncb:
;  bx -> NCB to clear and init

;			Mov		[BX].NCB_COMMAND,00H
; note, we don't init NCB_COMMAND Field, as it's value, once set is
; never changed
;
	Mov		ES:[BX].NCB_RETCODE,00H
	Mov		ES:[BX].NCB_LSN,00H
	Mov		ES:[BX].NCB_NUM,01H		;01H says use the PROM MAC address
	Mov		AX,0000H
	Mov		word ptr  ES:[BX].NCB_LENGTH,AX
	Lea		AX,       ES:[BX].NCB_data_buffer
	Mov		word ptr  ES:[BX].NCB_BUFFER,AX
    Mov		AX,ES
	Mov		word ptr  ES:[BX].NCB_BUFFER+2,AX
;
	Push	SI
;
	Mov		SI,0000H
init_ncb_1:
	Mov		AX,0000H
	Mov		word ptr ES:[BX][SI].NCB_CALLNAME,AX
	Inc		SI
	Inc		SI
	Cmp		SI,8
	Jl		init_ncb_1
;
	Mov		SI,0000H
	Mov		AX,0000H
init_ncb_2:
	Mov		word ptr ES:[BX][SI].NCB_NAME,AX
	Inc		SI
	Inc		SI
	Cmp		SI,5					;this sets first ten bytes to zero
	Jl		init_ncb_2
	Mov		AX,word ptr CS:mac_addr
	Mov		word ptr ES:[BX].NCB_NAME+10,AX
	Mov		AX,word ptr CS:mac_addr+2
	Mov		word ptr ES:[BX].NCB_NAME+12,AX
	Mov		AX,word ptr CS:mac_addr+4
	Mov		word ptr ES:[BX].NCB_NAME+14,AX
;
	Mov		ES:[BX].NCB_RTO,00H
	Mov		ES:[BX].NCB_STO,00H
	Mov		AX,0000H
	Mov		word ptr ES:[BX].NCB_POST,AX
	Mov		word ptr ES:[BX].NCB_POST+2,AX
	Mov		AL,ES:lana_num
	Mov		ES:[BX].NCB_LANA_NUM,AL
	Mov		ES:[BX].NCB_CMD_CPLT,00H
;
	Mov		SI,0000H
	Mov		AX,0000H
init_ncb_3:
	Mov		word ptr ES:[BX][SI].NCB_RESERVE,AX
	Inc		SI
	Inc		SI
	Cmp		SI,7
	Jl		init_ncb_3
;
	Pop 	SI
	Ret


	
;any code after this will not be kept after initialization.
end_resident	label	byte


    Subttl	
	Page
	public	usage_msg
usage_msg	db	"usage: pclana <packet_int_no> <LANA # -- 1 | 2>",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for IBM PC LAN card or SYTEK 6120, version ",'0'+majver,".",'0'+version,CR,LF
		db	"Portions Copyright 1989, Kevin J. Rowett - N6RCE",CR,LF,'$'

no_lana_msg	db	"NETBIOS (LANA) not present",CR,LF,'$'

inv_lana_num_msg	db	"No LANA with that number found",CR,LF,'$'

lana_err_msg	db	"LANA  returned error",CR,LF,'$'

lana_num_name	db	"LANA number = ",'$'

	extrn	set_recv_isr: near

    Subttl	parse_args
	Page
;enter with si -> argument string, di -> word to store.
;if there is no number, don't change the number.
	extrn	get_number: near

	public	parse_args
parse_args:

	Mov		di,offset lana_num			;save the LANA or NCB
	Mov		bx,offset lana_num_name		;and name for get num to print
	Call	get_number
	Dec		lana_num					;user supplies 1 or 2, card want
										; 0 or 1
	
	Ret


lana_not_present:

	Mov		dx,offset no_lana_msg
	Mov		ah,9
	Int		21H							;DOS FN Call
	Stc
	Ret


invalid_lana_num:

	Mov		dx,offset inv_lana_num_msg
	Mov		ah,9
	Int		21H							;DOS FN Call
	Stc
	Ret


lana_error_rpt:
	
	Mov		dx,offset lana_err_msg
	Mov		ah,9
	Int		21H							;DOS FN Call
	Stc
	Ret
	

    Subttl	etopen
	Page
	public	etopen
etopen:
;if all is okay,

;
;  check to see if the LANA is present.  Right out of book, page 2-88.
;
;  version two learned something.  Also must check the vector is not pointing
;  into ROM above 0D000h.
;   
;
;   1. check that INT 5C is not zero's
;
;   1A check segment < 0D000h
;
;	2. issue a cmd 7fH
;
;	3. see that the cmd comes back 03H (invalid cmd)
;
;	if so, we have an adapter present
;

	Mov		send_in_use,NCB_unused
	Mov		recv_in_use,NCB_unused
	Mov		ah,35H						;DOS FN get vector
	Mov		al,NETBIOS
	Int		21H							;Hello DOS
	Cmp		bx,0000H				;vector other than zero?
	Jne		lana_pres_test2
	Jmp		lana_not_present
lana_pres_test2:
	Mov		BX,ES
; get our ES back
	Push	DS
	Pop		ES
	Cmp		BX,0000H
	Jne		lana_pres_test3
	Jmp		lana_not_present
lana_pres_test3:
	Cmp		BX,0D000H
	Jb		lana_present
	Jmp		lana_not_present
lana_present:

;   vector not zero


	Mov		BX,offset CTL_NCB
;
	Call	init_ncb
	Mov		[BX].NCB_COMMAND,LANA_TEST_PRES
	Int		NETBIOS
	Cmp		[BX].NCB_RETCODE,03H
	Je		lana_test_ret_ok
	Cmp		[BX].NCB_RETCODE,23H
	Je 		invalid_lana_num_s
	Jmp		lana_not_present
invalid_lana_num_s:
	Jmp		invalid_lana_num


lana_test_ret_ok:

;   good chance we have a LANA present
;
;    Now, RESET the bastard, and get the MAC address
;
	Call	init_ncb
	Mov		[BX].NCB_COMMAND,LANA_RESET
	Mov		[BX].NCB_LSN,01H			;number of sessions to support
	Mov		[BX].NCB_NUM,0cH			;number of commands to support
	Int		NETBIOS
	Cmp		[BX].NCB_RETCODE,00H
	Je		lana_reset_okay
	Jmp		lana_error_rpt
lana_reset_okay:
;
;    adapter status please
;
	Call	init_ncb
	Mov		[BX].NCB_COMMAND,LANA_ADPTS
	Mov		[BX].NCB_CALLNAME,'*'		;get status of local adapter
	Mov		[BX].NCB_LENGTH,MAX_LANA_BUF_LEN
	Int		NETBIOS
	Cmp		[BX].NCB_RETCODE,00H
	Je		lana_adpts_okay
	Jmp		lana_error_rpt
lana_adpts_okay:
;
;	save the mac address
;
	Mov		AX,word ptr [BX].NCB_data_buffer
	Mov		word ptr mac_addr,AX
	Mov		AX,word ptr [BX].NCB_data_buffer+2
	Mov		word ptr mac_addr+2,AX
	Mov		AX,word ptr [BX].NCB_data_buffer+4
	Mov		word ptr mac_addr+4,AX

;
;   set the NCB_COMMAND fields for the various static NCB's
;
	Mov		BX,offset SEND_NCB
	Mov		[BX].NCB_COMMAND,LANA_SENDDG
	
	Mov		BX,offset SEND_BDCST_NCB
	Mov		[BX].NCB_COMMAND,LANA_SENDDG_BDCST

;
;	loop thru the string of receive style NCB's
;
	Mov		BX,offset RCV_NCB
	Mov		CX,ncb_count

recv_ncb_loop:
	Call	init_ncb
	Mov		AX,offset lana_post_recv
	Mov		word ptr  ES:[BX].NCB_POST,AX
	Mov		AX,ES
	Mov		word ptr  ES:[BX].NCB_POST+2,AX
	Mov		[BX].NCB_COMMAND,LANA_RCVDG
	Mov		[BX].NCB_LENGTH,MAX_LANA_BUF_LEN
	Mov		[BX].active_flag,NCB_in_use

	Mov		DX,BX
	Add		DX,size NCB
	Mov		[BX].NCB_link,DX
	Mov		BX,DX

	Loop	recv_ncb_loop
;
;  fix up the last one
;
	Sub		BX,size NCB
	Mov		Dx,offset RCV_NCB
	Mov		[BX].NCB_link,DX

;
;	post a chain of rcv datagram NCBs
;
	Mov		BX,offset RCV_NCB
	Mov		CX,ncb_count

rcv_ncb_post_loop:
 	Int		NETBIOS
 	Mov		[BX].immediate_error,AL
 	Cmp		AL,00H
 	Je		ok_post_rcvdg
	Jmp		lana_error_rpt
ok_post_rcvdg:
	Add		BX,size NCB
	Loop	rcv_ncb_post_loop
	
	
;
;	now the same for rcv broadcast ncb's
;
	Mov		BX,offset RCV_BDCST_NCB
	Mov		CX,ncb_count

recv_bdcst_ncb_loop:
	Call	init_ncb
	Mov		AX,offset lana_post_recv
	Mov		word ptr  ES:[BX].NCB_POST,AX
	Mov		AX,ES
	Mov		word ptr  ES:[BX].NCB_POST+2,AX
	Mov		[BX].NCB_COMMAND,LANA_RCVDG_BDCST
	Mov		[BX].NCB_LENGTH,MAX_LANA_BUF_LEN
	Mov		[BX].active_flag,NCB_unused
;		We marked the BDCST as unused initially, since we only 
;		post one of them

	Mov		DX,BX
	Add		DX,size NCB
	Mov		[BX].NCB_link,DX
	Mov		BX,DX

	Loop	recv_bdcst_ncb_loop
;
;  fix up the last one
;
	Sub		BX,size NCB
	Mov		Dx,offset RCV_BDCST_NCB
	Mov		[BX].NCB_link,DX

;
;	post only one RECV BDCST DATAGRAM NCB, as they all complete
;   at once.
;
	Mov		BX,offset RCV_BDCST_NCB
	Mov		[BX].active_flag,NCB_in_use ;mark as in_use
  	Int		NETBIOS
  	Mov		[BX].immediate_error,AL
  	Cmp		AL,00H
  	Je		ok_post_rcvdg_bdcst
;  	Jmp		ok_post_rcvdg_bdcst
	Jmp		lana_error_rpt
ok_post_rcvdg_bdcst:

	
	mov	dx,offset end_resident
	clc
	ret
;if we got an error,
	stc
	ret

code	ends

	end
