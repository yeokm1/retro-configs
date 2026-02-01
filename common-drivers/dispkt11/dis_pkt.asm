	TITLE	DIS_PKT

; DIS_PKT.ASM - Adapter provides Packet Driver v1.11 interface over NDIS.
; Version 1.07  18 May 1991  by Joe R. Doupnik, Utah State Univ.
; Version 1.08  9 Aug 1991 by Dan Lanciani, ddl@danlan.com
; Version 1.09  3 Nov 1991 by Joe R. Doupnik, Utah State Univ.
; Version X.10  6 Nov 1991 by Dan Lanciani, ddl@danlan.com
; Version 1.10  5 Feb 1992 by Dan Lanciani, ddl@danlan.com
; Version 1.11  31 Dec 1992 by Dan Lanciani, ddl@danlan.com
; Copyright (C) 1988 - 1991 FTP Software, Inc.
;
; This unmodified source file and it's executable form may be used and
; redistributed freely.  The source may be modified, and the source or
; executable versions built from the modified source may be used and
; redistributed, provided that this notice and the copyright displayed by
; the exectuable remain intact, and provided that the executable displays
; an additional message indicating that it has been modified, and by whom.
;
; FTP Software Inc. releases this software "as is", with no express or
; implied warranty, including, but not limited to, the implied warranties
; of merchantability and fitness for a particular purpose.
;
; USE AT YOUR OWN RISK.
;
; Please send bug reports to ddl@danlan.com or
;
; Dan Lanciani
; 185 Atlantic Road
; Gloucester, MA 01930
;
;
; To build, using Microsoft MASM 5 or later, LINK 3.64 or later, and EXE2BIN:
;
; masm dis_pkt;
; link dis_pkt;
; exe2bin dis_pkt.exe dis_pkt.dos
; del dis_pkt.exe
; del dis_pkt.obj
;
;
;What DIS_PKT.DOS does: It provides a Packet Driver
;interface to programs built to operate over Packet Drivers.  It talks
;to NDIS (3Com/Microsoft) instead of to a lan board directly.  It shares
;the board with NDIS users.  We call this a "shim", sitting between the
;normal applications program (NetWare shells, TCP/IP, etc) and the more
;hardware specific portions (NDIS in this case).
;
;    Packet Driver flavored applications	NDIS flavored applications
;		||					||
;	    -------------				||
;	    |  DIS_PKT  |				||
;	    -------------				||
;		||					||
;		------------------------------------------
;		|           main module			  |
;		|   NDIS    ........................      |
;		|	    board specific driver(s)	  |
;		-------------------------------------------
;				  ||
;			-------------------------
;			|    Ethernet board(s)	|
;			-------------------------
;				  ||
;		=========================================== Ethernet wire
;
;
;First sample PROTOCOL.INI file:
;
;[protocol manager]
;    drivername = PROTMAN$
;
;[pktdrv]			<-- name of this driver entry
;  drivername = pktdrv$		<-- formal driver name
;  bindings = wd8003xmac	<-- use your board's NDIS driver here
;  intvec = 0x60		<-- Packet Driver Int, 60h..7fh
;  chainvec = 0x66		<-- post-EOI processing interrupt
;  novell = y			<-- Optional, if present and y(es) then
;				    convert between old Novell 802.3 pkts
;				    on the wire and Type 8137 for the app.
;				    Omitting this line or using any other
;				    response turns off the conversion;
;				    default is no conversion.
;
;[attiso]
;  drivername = ATTISO$		<-- Another NDIS client
;  bindings = wd8003xmac	<-- bound to the same harware driver
;  nsess = 5
;  ncmds = 14
;  use_emm = n
;
;Western Digital EtherCard PLUS Family Adapter	<-- Ethernet board
;[wd8003xmac]					<-- its ndis driver
;    drivername = MACWD$
;    irq = 7
;    ramaddress = 0xCA00
;    iobase = 0x280
;    receivebufsize = 1536	<-- make this a full Ethernet pkt
;
;
;
;
;Sample section of CONFIG.SYS (StarGROUP material is not required):
;
;device=c:\lanman\protman.sys /i:c:\lanman	<-- must be first
;device=c:\lanman\macwd.dos			<-- WD8003E driver
;device=c:\lanman\dis_pkt.dos			<-- Pkt Driver (this program)
;device=c:\lanman.dos\drivers\attload.dos /Y	<-- StarGROUP NDIS
;device=c:\lanman.dos\drivers\attiso\attiso.dos	<-- StarGROUP NDIS
;device=c:\qemm\loadhi.sys /r:1 e:\pctcp\ifcust.sys  <-- PC/TCP stuff
;device=c:\qemm\loadhi.sys /r:4 e:\pctcp\ipcust.sys  <-- etc
;
;
; A second, more elaborate example, with names easier to type.  We start with
;file PROTOCOL.INI.  Note that semicolons start comment lines.
;
;; This is a sample protocol.ini file listing three Ethernet boards:
;;	attcsma.dos is an AT&T StarLAN 10 EN100
;;	elnkii.dos  is a 3Com 3C503
;;	wd8003.dos  is a Western Digital WD8003E
;; Only one board will be selected but the other two are present.
;
;[protocol manager]
;    drivername = PROTMAN$
;
;; Packet Driver protocol users tie in here
;[pktdrv]
;	drivername = pktdrv$
;	bindings = attcsma
;;	bindings= elnkii
;;	bindings = wd8003
;	intvec = 0x60
;;	chainvec = 0x66
;	novell = no		; do not convert packet types this time
;
;; AT&T StarGROUP protocol stack ties in here via name ATTISO$
;[attiso]
;	drivername = ATTISO$
;	bindings = attcsma
;;	bindings = elnkii
;;	bindings = wd8003
;	nsess = 5
;	ncmds = 14
;	use_emm = n
;
;;Western Digital EtherCard PLUS Family Adapter, WD8003E in this case
;[wd8003]
;	drivername = MACWD$
;	irq = 7
;	ramaddress = 0xCA00
;	iobase = 0x280
;	receivebufsize = 1536
;;	maxtransmits = 6
;;	receivebuffers = 6
;;	receivechains = 6
;
;; 3Com Etherlink II, 3C503
;[elnkii]
;	drivername = ELNKII$
;	ioaddress = 0x350
;	interrupt = 5
;	transceiver = onboard
;	maxtransmits = 12
;	xmitbufs = 1
;
;; AT&T StarLAN 10 EN100
;[attcsma]
;	drivername = ATTCSMA$
;	board_type = 2
;	irq = 2
;	ioaddr = 0x360
;	daram = 0xD000
;
;; End of file protocol.ini
;
;Fragment of config.sys for the second example.  Note three .dos board drivers.
;
;device=c:\system\ramdrive.sys 1024 512 128 /E
;device=c:\lanman\protman.sys /i:c:\lanman.dos\drivers\star10en
;device=c:\lanman\attcsma.dos
;device=c:\lanman\elnkii.sys
;device=c:\lanman\macwd.dos
;device=c:\lanman\dis_pkt.dos
;device=c:\lanman.dos\drivers\attload.dos /Y
;device=c:\lanman.dos\drivers\attiso\attiso.dos
;device=c:\qemm\loadhi.sys /r:1 e:\pctcp\ifcust.sys
;device=c:\qemm\loadhi.sys /r:4 e:\pctcp\ipcust.sys
;device=c:\qemm\loadhi.sys /r:4 c:\netdev.sys
;shell=c:\command.com  /p /e:800
;
;It is necessary to run NETBIND.EXE to get all this to be active.
;

;
; Edit History
; 06-Jul-89	WJR	Changed interface flags in LDT to 2 per Norsk Data
;			 (may make vector binding work).  Changed receive to
;			 allocate buffer for frame size instead of lookahead
;			 value.  (This will fail miserably if the frame size
;			 is unknown at upcall time; such is life.) Changed
;			 SetPacketFilter to use module ID instead of dummy.
; 11-Sep-89	jbvb	Clean up, add 1.09 functionality.
; 12-Sep-89	jbvb	Don't do interrupt if vector contents are 0.
; 14-Sep-89     wjr	Changed frame_rejected to frame_not_recognized to make
;			 vectored operation work.  Changed send_pkt to use
;			 drv_cct.mod_id.  Tried using 0 as protocol id in open
;			 adapter call.  Changed device name to pktdrv$,
;			 flushed open adapter not supported message.
; 15-Sep-89	wjr	Changed open adapter back to CS since 0 broke it.
; 24-Oct-89	wjr	Changed FRAME_NOT_RECOGNIZED from 4 to 3
; 07-Feb-90	wjr	Added push and pop SI to rcv_chn & rcv_lah.
; 02-Apr-90	wjr	Fixed xmt_chn to properly check for request queued
; 03-Apr-90	wjr	Given changed TCP, treat REQUEST_QUEUED as success.
; 06-Apr-90	jbvb	Update patch level to 2.
; 23-Apr-90	jbvb	Don't trash BP, free init code, fix comments.
; 25-Apr-90	jbvb	Support "extended" calls: get/set_rcv_mode,
;			 get_statistics will suffice for LW.
; 26-Apr-90	jbvb	Support "match all" on typelen == 0.
; 05-Jun-90	jbvb	Fix stack bug in "match all" handling in access_type,
;			 pass valid CX on 2nd receiver() upcall, version 5.
; 13-Jun-90	jbvb	Write basic set_address() code, but comment it out
;			 because NDIS may require a CloseAdapter first in
;			 order for it to work.  Not worth it to me.
; 27-Jul-90	jbvb	Copyright, build instructions, release v1.05.
; 24-Mar-91	jrd	Rewrite great chunks to straighen out stack and DS
;			addressing.  This now works with Novell IPX/NETn
;			and Netwatch (together as a matter of fact) and
;			with PC/TCP from FTP Inc. Version to 1.06.
;			Joe R. Doupnik, jrd@cc.usu.edu, Utah State Univ.
; 30-Mar-91	jrd	Allow 10 byte TYPE idents to pick out packets,
;			more cleanups, more needed.  Promiscuous mode put last.
;			Allow 20 handles.  Works fine with (NetWare+PC/TCP+
;			Netwatch) Pkt Drvr + Lan Man going simulanteously.
;			Works with Clarkson issued Packet Driver utilities.
; 18-May-91	jrd	Add filtering of packet addresses if running in
;			promiscuous mode, add get current Ethernet address
;			function to aid filtering, add receive mode indicator
;			for each handle, correct error in snd_def initing.
;			Correct problem with receive lookahead addressing.
;			Compensate for 3Com drivers not preserving regs.
;			Bump up NDIS tables to v2.  Dis_pkt version to 1.07.
; 09-Aug-91	ddl	802.5, 802.3 support; default binding; overwrite fix
; 03-Nov-91	jrd	Add keyword NOVELL to PROTOCOL.INI to convert between
;			old Novell 802.3 packets on the wire to 8137 for the
;			applications program.  Convert if the line is present
;			and the value is y(es).  Small cleanups.
; 06-Nov-91	ddl	Add general macro/routine in support of correct sync
;			calls to MAC.  Make send_pkt wait for completion.
;			Eliminate extra cs: prefixes and consolidate various
;			register/register and register/stack operations.  Use
;			mac_ds for all downcalls.  Add MAC open/close routines
;			for set_address and Token Ring all-frames mode.  Enable
;			PD set_address API.
; 08-Nov-91	ddl	Eliminate extra register saves and compares.  Absorb
;			set_packet_filter errors for Token Ring drivers in
;			all-frames mode.  Allow multiple handles with the
;			same type.  More cleanup.
; 09-Nov-91	ddl	Add deliver routine to handle multiple upcalls per
;			packet.  Replace broken packet filter code.  Various
;			code rewrites.  Punt blocking send_pkt for WD driver.
;			(The WD driver does not generate TransmitConfirms
;			within IndicationCompletes and will therefore cause
;			deadlock if a blocking send_pkt is attempted.)  This
;			is a real problem since PD semantics require that
;			buffer use is finished when send_pkt completes and
;			we cannot guarantee such.
; 10-Nov-91	ddl	Remove more unnecessary push/pop code.  Assume max
;			frame size on ReceiveLookahead with zero length.
;			Take advantage of SUCCESS = 0.
; 11-Nov-91	ddl	Move Novell code from pktfilter to deliver to avoid
;			overwriting card's buffers.
; 12-Nov-91	ddl	Simplify packet filter.
; 05-Feb-92	ddl	Fix the Novell bug I introduced...
; 31-Dec-92	ddl	Another try at sync sends & remove restrictions
;			on non-zero vector pointer.  The new scheme allows
;			you to specify the true hardware interrupt as
;			``chainvec'' in which case dis_pkt does not (of
;			course) perform the int.  Someday we can get the
;			info from NDIS v2 MAC drivers but until then...

	PAGE ,80

EOL	equ	<13, 10, '$'>
LF	=	10
CR	=	13
EOS	=	'$'
DOS	equ	21h
prstr	equ	9
fopen	equ	3dh
fclose	equ	3eh
ioctl	equ	44h

MSG	MACRO	TEXT
	push	dx			;; save DX across call
	push	ax
	push	ds
	mov	ax, cs
	mov	ds, ax
	mov	dx, offset TEXT		;; point to message
	mov	ah, prstr		; display dollar terinated string
	int	dos
	pop	ds
	pop	ax
	pop	dx
	ENDM

; Issue a request to the MAC and wait for the result
;
SYNCREQUEST MACRO
	mov	req_con_flg, REQUEST_QUEUED
	call	Request
	call	req_wt
	ENDM

; DOS request header offsets

command	=	2
status	=	3
bpb	=	18
end_off	=	14
end_seg =	16

; NDIS General Request codes

INIT_DIAG	equ	1
READ_ERR_LOG	equ	2
SET_STA_ADDR	equ	3
OPEN_ADAPTER	equ	4
CLOSE_ADAPTER	equ	5
RESET_MAC	equ	6
SET_PKT_FLT	equ	7
ADD_MULT_ADDR	equ	8
DEL_MULT_ADDR	equ	9
UPDATE_STATS	equ	10
CLEAR_STATS	equ	11
INTERRUPT_ME	equ	12
SET_FUNC_ADDR	equ	13
SET_LOOKAHEAD	equ	14

ADDR_NONE	equ	0	; NDIS Receiver modes: disabled
ADDR_MULT	equ	1	; Receive packets for my address & multicast
ADDR_BRD	equ	2	; Receive broadcast packets
ADDR_PROM	equ	4	; Receive all packets (promiscuous mode)
ADDR_SRCRT	equ	8	; Receive all source-routed packets

; Protocol to MAC return codes

SUCCESS			equ	0
REQUEST_QUEUED		equ	2
FRAME_NOT_RECOGNIZED	equ	3
INVALID_PARAMETER	equ	7
NOT_SUPPORTED		equ	9
GENERAL_FAILURE		equ	0FFH

; NDIS-related structure definitions

cct_def	struc
	dw	64		; Size of common characteristics table (cct)
	dw	0		; Level of cct (zero this version)
	dw	0		; Level of service-specific subtables
	db	2		; Major module version (2 BCD digits)
	db	0		; Minor module version (2 BCD digits)
	dd	2		; Module function flags
	db	'PKTDRV$', 9 dup (0) ; Module name, 16 byte ASCIIZ format
	db	4		; Protocol level at upper boundary of module
	db	0		; type of interface at upper module boundary
	db	1		; protocol level at lower boundary of module
	db	1		; type of interface at lower module boundary
mod_id	dw	-1		; module ID filled in by Protocol Manager
mod_ds	dw	0		; module DS
system	dd	0		; system request dispatch entry point
sscp	dd	0		; pointer to service-specific characteristics
sssp	dd	0		; pointer to service-specific status
udtp	dd	0		; pointer to upper dispatch table
ldtp	dd	0		; pointer to lower dispatch table
	dd	0		; reserved (must be NULL)
	dd	0		; reserved (must be NULL)
cct_def	ends

ssc_def	struc
	dw	96		; length of MAC service-specific
				; characteristics table (ssc)
mtype	db	16 dup (0)	; type name of MAC, ASCIIZ format
	dw	0		; length of station addresses in bytes
	db	16 dup (0)	; permanent station address
cur_add	db	16 dup (0)	; current station address
	dd	0		; current functional address of adapter
	dd	0		; multicast address list
	dd	0		; link speed
svc_1	dw	0		; service flags
svc_2	dw	0		; service flags
maxfram	dw	0		; max frame size both sent and recv
	dd	0		; total transmission buffer cap in driver
	dw	0		; transmission buffer allocation block size
	dd	0		; total reception buffer cap in driver
	dw	0		; reception buffer allocation block size
	db	3 dup (0)	; IEEE vendor code (OUI)
	db	0		; vendor adapter code
	dd	0		; vendor adapter description pointer
mirq	dw	0		; IRQ of adapter (NDIS v2)
	dw	0		; transmit queue depth (NDIS v2)
	dw	0		; number of data blocks in buffer desc
ssc_def	ends

sss_def	struc
	dw	0		; length of status table
	dd	0		; date/time of last diagnostics
lstatus	dd	0		; MAC status
	dw	0		; current packet filter
	dd	0		; pointer to media specific statistics table
	dd	0		; date/time of last ClearStatistics call
r_tot	dd	0		; total frames received
r_crc	dd	0		; frames with CRC error
rb_tot	dd	0		; total bytes received
r_drop	dd	0		; frames discarded - no buffer space
r_mult	dd	0		; multicast frames received
r_bro	dd	0		; broadcast frames received
r_err	dd	0		; frames received with errors
r_big	dd	0		; frames exceeding maximum size
r_runt	dd	0		; frames smaller than minimum size
rb_mul	dd	0		; multicast bytes received
rb_bro	dd	0		; broadcast bytes received
r_hwer	dd	0		; frames discarded - hardware error
x_tot	dd	0		; total frames transmitted
xb_tot	dd	0		; total bytes transmitted
x_mul	dd	0		; multicast frames transmitted
x_bro	dd	0		; broadcast frames transmitted
xb_bro	dd	0		; broadcast bytes transmitted
xb_mul	dd	0		; multicast bytes transmitted
x_tmo	dd	0		; frames not transmitted - time-out
x_hwer	dd	0		; frames not transmitted - hardware error
sss_def	ends

udt_def	struc			; upper dispatch table
	dd	0		; back pointer to cct
reqadd	dd	0		; request address
xchain	dd	0		; TransmitChain address
	dd	0		; TransferData address
	dd	0		; ReceiveRelease address
indon	dd	0		; IndicationOn address
indoff	dd	0		; IndicationOff address
udt_def	ends

ldt_def	struc			; lower dispatch table
	dd	0		; back pointer to cct
	dd	2		; interface flags (2 means something)
	dd	0		; RequestConfirm address
        dd	0		; TransmitConfirm address
   	dd	0		; ReceiveLookahead indication address
	dd	0		; IndicationComplete address
	dd	0		; ReceiveChain indication address
	dd	0		; status indication address
ldt_def	ends

snd_def	struc			; transmit buffer descriptor
	dw	0		; byte count of immediate data (always 0)
	dd	0		; address of immediate data
	dw	1		; count of data blocks (always 1)
	db	0		; pointer type (0 == physical)
	db	0		; reserved
snd_len	dw	0		; number of bytes to send
snd_off	dw	0		; offset of data to send
snd_seg	dw	0		; segment of data to send
snd_def	ends

rcv_def	struc			; receive buffer descriptor
	dw	1		; count of data blocks (always 1)
	db	0		; pointer type (0 == physical)
	db	0		; reserved
rcv_len	dw	0		; number of bytes to get
rcv_off	dw	0		; offset of data to get
rcv_seg	dw	0		; segment of data to get
rcv_def	ends

req_def	struc			; Request block - Protocol Manager primitives
req_opc	dw	0		; opcode for PM request
req_sta	dw	0		; status returned from request
req_of1	dw	0		; first parameter pointer
req_sg1	dw	0
req_of2	dw	0		; second parameter pointer
req_sg2	dw	0
req_prm	dw	0		; parameter word
req_def	ends

bnd_def	struc			; binding list
bnd_cnt	dw	1		; number of MACs to bind to -- 0 or 1
bnd_nam	db	16 dup (0)	; name of module to bind to
bnd_def	ends


	SUBTTL	Resident Data Area
	PAGE

CSEG	SEGMENT PARA PUBLIC 'CODE'
	assume	cs:CSEG, ds:CSEG, es:nothing

; DEVICE HEADER - must be at offset zero within device driver
	dd	-1		; becomes pointer to next device header
	dw	8000H		; attribute (char device)
	dw	offset strat	; pointer to device strategy routine
	dw	offset intr	; pointer to device interrupt handler
	db	"PKTDRV$ "	; device driver name
; END OF DEVICE HEADER

mac_cctp	dd	0	; address of MAC's cct table
mac_ds		dw	0	; DS register for MAC

drv_cct		cct_def	<>	; Common Characteristics Table
drv_ldt		ldt_def	<>	; Lower Dispatch Table
drv_snd		snd_def	<>	; Argument blocks for NDIS TransmitChain,
drv_rcv		rcv_def	<>	;  TransferData,
drv_bnd		bnd_def	<>	;  and Bind (via DOS IOCTL)
drv_req		req_def	<>	; Argument block for general NDIS requests
TransmitChain	dd	0		; MAC entry point to send packet
TransferData	dd	0		; MAC entry point for data copy
Request		dd	0		; MAC entry point for requests
;ReceiveRelease	dd	0		; MAC entry point (???not used???)
IndicationOn	dd	0		; MAC entries to control Indications
IndicationOff	dd	0		;  (upcalls) from NDIS

req_con_flg	dw	0		; Completion status from NDIS upcall
xmt_cmp		dw	0		; TransmitChain result

init_flg	db	0		; Non-zero if we've been initialized
address		db	6 dup (0)	; Current address from MAC
novell		db	0		; if non-zero convert between old
					; Novell 802.3 interior to Type 8137
					; Caller used 8137, wire gets 802.3
nd_mode		dw	3		; Current NDIS packet filter

; Request Header (RH) address, saved here by "strategy" routine

req_hdr		label	dword
req_off		dw	0
req_seg		dw	0

; Save the request header for use by the interrupt routine

strat	PROC	FAR
	mov	word ptr cs:req_off, bx	; offset
	mov	word ptr cs:req_seg, es	; segment
	ret
strat	ENDP

	EVEN					; Get into word alignment

;;
;; Data for Packet Driver
;;
BAD_HANDLE	equ 1	; invalid handle number
NO_CLASS	equ 2	; no interfaces of this class found
NO_TYPE		equ 3	; no interfaces of specified type found
NO_NUMBER	equ 4	; no interfaces of specified number found
BAD_TYPE	equ 5	; bad packet type specified
NO_MULTICAST	equ 6	; this interface does not support multicast
CANT_TERMINATE	equ 7	; this packet driver cannot terminate
BAD_MODE	equ 8	; an invalid receiver mode was specified
NO_SPACE	equ 9	; operation failed because of insufficient space
TYPE_INUSE	equ 10	; type had previously been accessed and not released
BAD_COMMAND	equ 11	; the command was out of range or not implemented
CANT_SEND	equ 12	; the packet couldn't be sent (usually hardware error)
CANT_SET	equ 13	; The hardware address couldn't be changed
BAD_ADDRESS	equ 14	; Hardware address has bad length or format
CANT_RESET	equ 15	; Couldn't reset interface (more than 1 handle open)

PD_LEVEL	equ	6	; Implementation level (basic, high perf, ext)
ANY_TYPE	equ	0ffffh	; Matches any if_type
ETHERADDR_LEN	equ	6	; Length of an Ethernet address

; The connection arrays: types, and corresponding upcalls

PD_MAX_CONNS	equ	20	; The maximum number of handles/Types that can
				;  be registered at one time
MAX_P_LEN	equ	10	; max length of TYPE matching field, bytes

per_handle	struc			; Packet Driver HANDLE structure
pd_conn_used	db	0		; non-zero if this handle is in use
pd_conn_type	db	MAX_P_LEN dup(0) ; associated packet type
pd_conn_type_len dw	0		; associated packet type length
pd_conn_rmode	dw	3		; receive mode for this handle
pd_conn_rcvr	dd	0		; receiver handler address
pd_conn_class	db	0		; interface class
per_handle	ends

handles		per_handle PD_MAX_CONNS dup(<>)
end_handles	label	byte

if_class	db	1	; Class 1 is Ethernet
if_type		equ	57	; NDIS to Packet Driver adapter
pd_version	equ	11	; Version
pd_vector	dw	-1	; Packet Driver vector to serve on
pd_rcv_mode	dw	3	; Default to rcv mode 3 (normal/bcast)
pd_name		db	"MAC/DIS converter", 0
matchoff	dw	12	; offset to match bytes
addroff		dw	0	; offset to addresses
multimask	db	1	; multicast

; Table re-maps (badly) NDIS modes to Packet Driver modes (in parentheses)
ndis_mode	db  0	; No packets (0 == illegal)
		db  0	; No packets (1 == receiver off)
		db  1	; Directed | Multicast (2 should be directed only)
		db  3	; Directed | Multicast | Broadcast
			; (3 should be directed | broadcast)
		db  3	; Directed | limited Multicast | Broadcast
			; (4 == directed | broadcast | limited multicast)
		db  3	; Directed | limited Multicast | Broadcast
			; (5 should be directed | broadcast | all multicast)
		db  4	; Promiscuous (6 == match all)

EVEN	; Get into word alignment

; struct param; Pointer to this returned by get_parameters()

pd_param  db	1		; Major revision = 1
	  db	9		; Minor revision = 9
	  db	14		; Length of this structure = 14
	  db	ETHERADDR_LEN	; MAC addr length
mtu	  dw	1514		; MAC packet length
	  dw	0		; No multicast support
	  dw	0		; No promises re: back-to-back receives
	  dw	0		; No promises re: back-to-back transmits
param_int dw	0		; Default to no interrupt on EOI

; Pointer to this returned by get_statistics

pd_statistics struc
pkt_in		dd	0	; Total packets in
pkt_out		dd	0	; Total packets out
bytes_in	dd	0	; Total bytes received
bytes_out	dd	0	; Total bytes sent
errs_in		dd	0	; Total transmit errors
errs_out	dd	0	; Total receive errors
pkts_lost	dd	0	; Packets dropped - no buffer, out of resc
pd_statistics ends

pd_stat		pd_statistics <>	; An instance of the above

PUBLIC	driver_info, access_type, release_type, send_pkt, terminate
PUBLIC	get_address, reset_interface, get_parameters, set_rcv_mode
PUBLIC	get_rcv_mode, get_statistics, set_address

; Normal (basic Packet Driver functions) Jump Table

pd_table dw	pd_none		; No handler
	dw	driver_info	; 1
	dw	access_type	; 2
	dw	release_type	; 3
	dw	send_pkt	; 4
	dw	terminate	; 5
	dw	get_address	; 6
	dw	reset_interface	; 7
pd_table_size	equ	($-pd_table)/2

; High Performance functions Jump Table

hp_table dw	get_parameters	; 10
	dw	pd_none		; 11 (as_send_pkt not implemented)
hp_table_size	equ	($-hp_table)/2

; Extended functions Jump Table

ext_table dw	set_rcv_mode	; 20
	dw	get_rcv_mode	; 21
	dw	pd_none		; 22 (set_multicast_list not implemented)
	dw	pd_none		; 23 (get_multicast_list not implemented)
	dw	get_statistics	; 24
	dw	set_address	; 25
ext_table_size	equ	($-ext_table)/2

;
; rcv_lah is the proc that handles ReceiveLookAhead upcalls from the MAC
;
; First, it determines if the packet is one that is wanted.  If so, it asks
; the appropriate application for a buffer.  If it gets one, it copies the
; data and makes the 2nd call to the application to post it complete.  If
; not, it returns SUCCESS to the DIS driver anyway.  It returns SUCCESS if
; if the packet was copied or FRAME_NOT_RECOGNIZED if it is not in the list
; of desired types.
;
;The stack coming into this call is:
;	dw	bp[20]		MACID
;	dw	bp[18]		framesize
;	dw	bp[16]		bytes available in buffer
;	dw	bp[14]		lookahead data address seg
;	dw	bp[12]		lookahead data address off
;	dd	bp[10]		indicate flag
;	dw	bp[6]		ds of called protocol mode (ME)
;

rcv_lah	PROC	FAR
	push	bp
	mov	bp, sp
	push	si			; -2[bp]
	push	di			; -4[bp]
	push	ds			; -6[bp]
	sub	sp, 2			; -8[bp] return count
	mov	ax, cs			; setup data segment
	mov	ds, ax
	cld

	cmp	word ptr 18[bp], 0	; unknown frame size
	jnz	lah_have_size
	mov	ax, mtu
	mov	18[bp], ax		; try for max
lah_have_size:
	les	dx, 12[bp]
	mov	bx, offset handles - size per_handle
	call	pktfilter		; apply packet filter
	jnc	lah_have_buf		; nc = we want this packet
	mov	ax, FRAME_NOT_RECOGNIZED ; packet not accepted
	jmp	lah_don

lah_have_buf:
	push	bx
	lea	ax, -8[bp]		; get scratch location
	push	ss			;  to put bytes copied into
	push	ax			;  and push it
	xor	ax, ax			; Starting offset in frame
	push	ax			;  is always zero
;
; Set up recv table description
;
	mov	ax, 18[bp]		; Len of recv data
	mov	drv_rcv.rcv_len, ax	;  goes in argument descriptor
	mov	drv_rcv.rcv_seg, es	;  as does far address of
	mov	drv_rcv.rcv_off, di	;  receive buffer
	push	ds			; Push far pointer to
	mov	ax, offset drv_rcv	;  descriptor
	push	ax
	push	mac_ds			; Push MAC's DS value
	call	TransferData		; Copy pkt to buf (pops args)
;
; Call Packet Driver receive routine again (AX = 1) to finish up
;
	pop	bx			; recover handle
	lds	si, dword ptr drv_rcv.rcv_off
	call	deliver			; run all the upcalls
	xor	ax, ax
lah_don:add	sp, 2			; local material
	pop	ds
	pop	di
	pop	si
	pop	bp
	ret	16			; Pop MAC's params off stack
rcv_lah	ENDP

;
; rcv_chn is the proc that handles ReceiveChain upcalls from the MAC
;
; First, it determines if the packet is one that is wanted.
; It returns success if the packet is ok or FRAME_NOT_RECOGNIZED if it is not
; in the list of currently open types.
;
; The stack coming into this call is:
;	dw	bp[20]		MACID
;	dw	bp[18]		framesize
;	dw	bp[16]		request handle
;	dw	bp[14]		receive-chain buf descriptor address seg
;	dw	bp[12]		receive-chain buf descriptor address off
;	dd	bp[8]		indicate flag addr
;	dw	bp[6]		DS of called protocol mode (ME)
;
; where receive-chain buffer descriptor format is
;	dw	rxdatacount	count of received data blocks, max of 8
;	dw	rxdatalen	length of a data block
;	dd	rxdataptr	seg:offset of a data block

rcv_chn	PROC	FAR
	push	bp
	mov	bp, sp
	push	si			; -2[bp]
	push	di			; -4[bp]
	push	ds			; -6[bp]

	mov	ax, cs			; setup data segment (== CS)
	mov	ds, ax
	cld

	les	di, 12[bp]
	les	dx, es:[di+4]		; es:di is now the buffer pointer
	mov	bx, offset handles - size per_handle
	call	pktfilter		; apply packet filter, return handle
	jnc	chn_have_buf		; nc = we want this packet
	mov	ax, FRAME_NOT_RECOGNIZED ; packet not accepted
	jmp	chn_don

chn_have_buf:
	push	es			; Save ES:DI (pointer) to pass
	push	di			;  back to receiver later
	lds	si, 12[bp]		; Addr of rcv descriptor
	mov	cx, [si]		; Get number of data blocks
	add	si, 2			;  & move to top of list

chn_dat:		; Move data from next block into stack's buffer
	push	cx
	push	ds
	push	si
	mov	cx, [si]		; Get byte count of block
	add	si, 2
	lds	si, [si]		; Get far pointer to data
	shr	cx, 1
	jnc	rcvchn5			; nc = even already
	movsb				; Move 1 byte if count is odd
rcvchn5:rep	movsw			; Use word mov for efficiency
	pop	si			; Go through rest of chain
	add	si, 6
	pop	ds
	pop	cx
	loop	chn_dat			; For all blocks
;
; Call Packet Driver receive routine again to finish up
;
	pop	si			; DS:SI = buffer pointer
	pop	ds
	call	deliver			; run all the upcalls
	xor	ax, ax
chn_don:pop	ds
	pop	di
	pop	si
	pop	bp
	ret	16			; pop params off stack
rcv_chn	ENDP

; Worker for lookahead and receive_chain procedures above.  Checks PD handles
; for wanting this kind of packet.  Returns carry clear, BX = handle,
; and ES:DI = buffer if packet is wanted, else carry set to reject the packet.
; If the adapter is in promiscuous mode (and the handle is not) we make an
; attempt at software filtering.  This is intentionally incomplete:  clients
; will be subjected to multicast packets that they may not want if any
; other client asks the adapter to accept multicast packets.  Therefore,
; there is no point in trying to avoid this situation in promiscuous mode.
; Later might want to add full filtering for all modes.
;
; Note that search starts at the handle *following* BX.  Expects lookahead
; pointer in ES:DX and packet length in 18[bp].
;
pktfproc proc	near
nohnd:	stc
	ret

pktfilter:add	bx, size per_handle	; next entry
	cmp	bx, offset end_handles
	jnc	nohnd
	cmp	[bx].pd_conn_used, 0	; is handle in use?
	jz	pktfilter
	mov	cx, [bx].pd_conn_type_len ; number of bytes to match
	jcxz	foundhnd
	lea	si, [bx].pd_conn_type	; TYPE wanted by this handle
	mov	di, dx			; es:di is lookahead data ptr
	cmp	if_class, 3
	jnz	norif
	test	byte ptr es:8[di], 80h
	jz	norif
	mov 	al, es:14[di]
	and	ax, 1fh
	add	di, ax
norif:	add	di, matchoff
	cmp	novell, 0
	jz	compare
	cmp	word ptr es:2[di], 0ffffh
	jnz	compare
	cmp	word ptr [si], 3781h
	jnz	compare
	cmp	cx, 2			; paranoia
	jnz	compare
	mov	ax, es:[di]
	xchg	ah, al
	cmp	ax, 1501
	jc	foundhnd
compare:repz	cmpsb
	jnz	pktfilter

foundhnd:cmp	pd_rcv_mode, 6		; board in promiscuous mode
	jnz	nofil
	cmp	[bx].pd_conn_rmode, 6	; but handle is not--filter
	jz	nofil
	mov	cx, ETHERADDR_LEN
	mov	si, offset address	; our address
	mov	di, dx
	add	di, addroff
	mov	al, multimask		; multicast/broadcast bit
	test	es:[di], al
	jnz	nofil
	repe	cmpsb
	jz	nofil
	jmp	pktfilter

nofil:	mov	cx, 18[bp]		; recover length
	xor	ax, ax
	push	es
	push	dx
	push	bp
	push	bx
	call	[bx].pd_conn_rcvr	; ask for a buffer
	cli
	cld
	pop	bx
	pop	bp
	pop	dx
	mov	ax, es
	or	ax, di
	jnz	havebuf
	pop	es
	jmp	pktfilter		; no luck--continue search
havebuf:pop	ax
	clc
	ret
pktfproc endp

; Deliver data to all interested handles following BX, then to BX itself.
; Data to be delivered in DS:SI, length in 18[bp].
;
deliver	proc	near
	push	bx
					; do old Novell 802.3 to Type 8137
	cmp	cs:novell, 0		; doing old Novell conversion?
	je	deliver0		; e = no
	push	si
	add	si, cs:matchoff
	cmp	word ptr [si+2], 0ffffh ; have the bad DSAP/SSAP signature?
	jne	noconv			; ne = no
	mov	ax, [si]		; get length/Type field value
	xchg	ah, al			; low endian form
	cmp	ax, 1501		; size is larger than length?
	jnc	noconv
	mov	word ptr [si], 3781h	; force in Novell Type 8137
noconv:	pop	si
					; end of Novell section
deliver0:push	ds
	push	si
	mov	ax, ds
	mov	es, ax
	mov	dx, si
	mov	ax, cs
	mov	ds, ax
	call	pktfilter		; find next potential client
	pop	si
	pop	ds
	mov	ax, 1
	mov	cx, 18[bp]
	jc	deliver2
	push	ds
	push	si
	push	es
	push	di
	push	cx
	shr	cx, 1
	jnc	deliver1
	movsb
deliver1:rep	movsw			; copy between clients
	pop	cx
	pop	si
	pop	ds
	push	bx
	push	bp
	call	cs:[bx].pd_conn_rcvr	; "secondary" client
	cli
	cld
	pop	bp
	pop	bx
	pop	si
	pop	ds
	jmp	short deliver0
deliver2:pop	bx
	call	cs:[bx].pd_conn_rcvr	; run the final upcall
	cld
	ret
deliver	endp

;
; Services indication complete upcall
;
; Executes interrupt (returned by get_parameters()) to pass control to
; an application which wants to run after the EOI.
;
; NOTE: Interrupt number at label ind_int is over-written if a different
;	interrupt is configured in protocols.ini.
;
ind_com	PROC	FAR			; Indication_complete upcall
	push	es
	push	bx
	mov	bx, cs:param_int	; Get offset of vector
	cmp	bx, 16
	jc	ind_no_int
    	xor	ax, ax
	mov	es, ax			; Point ES at interrupt segment
	shl	bx, 1			; Multiply by 4 for memory offset
	shl	bx, 1
	cmp	word ptr es:[bx]+2, 0	; Is there a segment there?
	jne	ind_int			; ne = yes
	cmp	word ptr es:[bx], 0	; Is there an offset there?
	je	ind_no_int		; no, no interrupt
ind_int:				; INT 65 overwritten if selected
	INT	65h			; Pass control to the application

ind_no_int:
	pop	bx			; Restore registers
	pop	es
	xor	ax, ax
	ret	4
ind_com	ENDP

;;;;;;;;;;;;;;;;;;;;;;;;; Packet Driver section
regs	struc				; stack offsets of incoming regs
	_ES	dw	?
	_DS	dw	?
	_BP	dw	?
	_DI	dw	?
	_SI	dw	?
	_DX	dw	?
	_CX	dw	?
	_BX	dw	?
	_AX	dw	?
	_IP	dw	?
	_CS	dw	?
	_F	dw	?		; flags, Carry flag is bit 0
regs	ends
bytes	struc				; stack offsets of incoming regs
		dw	?		; es, ds, bp, di, si are 16 bits
		dw	?
		dw	?
		dw	?
		dw	?
	_DL	db	?
	_DH	db	?
	_CL	db	?
	_CH	db	?
	_BL	db	?
	_BH	db	?
	_AL	db	?
	_AH	db	?
bytes	ends

CY	equ	0001h			; to set caller's carry bit

;
; Interrupt handler for the Packet Driver interface (protocol stack downcalls)
;
; NOTE: Leaves interrupts disabled on entry - code in access_type and
;	release_type depends on this.  send_pkt enables interrupts for MAC.
;
	PUBLIC	pd_isr
pd_isr	PROC	FAR
	jmp	short over	; skip the string (this MUST be a 3 byte jmp)
	nop			; make three bytes
      	db	"PKT DRVR", 0	; string to identify a packet driver
over:
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es
	cld
	push	cs			;set up ds to this code segment
	pop	ds

	mov	bp, sp			;we use bp to access the original regs
	and	_F[bp], not CY		;start by clearing the carry flag
	mov	_DH[bp], 0		; put no-error code in caller's DH

	cmp	ah, pd_table_size	; AH too large?
	jae	highperf_table		; ae = yes, try next set
					; Dispatch on AH using normal table
	mov	bl, ah			; Get function code
	xor	bh, bh			;  into a word register
	shl	bx, 1			; index by words
	jmp	pd_table[bx]		; and go

highperf_table:
	sub	ah, 10		; Offset of 1st high-performance function
	jl	pd_none			; l = ah is out of range
	cmp	ah, hp_table_size	; is AH still in range?
	jae	xtend_table		; ae = no, try next set
				; Dispatch on AH using high-performance table
	mov	bl, ah			; Get function code
	xor	bh, bh			;  into a word register
	shl	bx, 1			; index by words
	jmp	hp_table[bx]		; and go

xtend_table:
	sub	ah, 10			; Offset of 1st extended function
	jl	pd_none			; l = AH is not in range
	cmp	ah, ext_table_size 	; still in range?
	jae	pd_none			; ae = no
					; Dispatch on AH using extended table
	mov	bl, ah			; Get function code
	xor	bh, bh			;  into a word register
	shl	bx, 1			; index by words
	jmp	ext_table[bx]		; and go

pd_none:
	mov	dh, BAD_COMMAND		; set error code
err_ret:
	mov	_DH[bp], dh		; put error code in caller's DH
	or	_F[bp], CY		; set caller's carry flag
good_ret:				; good return (carry clear)
	pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	iret

;
; Checks the handle in BX.  If out of range or not valid cleans up the
; stack and jumps directly to err_ret with a BAD_HANDLE error.  Assumes
; called with DS pushed and a near call.  If handle is good, just returns.
; BX is shifted one bit to the left.
;

; Bounds check on handle
chk_hdl	PROC	 NEAR
	mov	bx, _BX[BP]		; Handle
	cmp	bx, offset handles	; start of handles area
	jb	chkhdl1			; b = out of range
	cmp	bx, offset end_handles	; end of handles area
	jae	chkhdl1			; ae = above max table size
	cmp	[bx].pd_conn_used, 0	; is handle used?
	je	chkhdl1			; e = no, go bomb out
	ret				; return BX as handle
chkhdl1:
	pop	ds			;clear stack (was the return address)
	mov	dh, BAD_HANDLE		;return BAD_HANDLE error
	jmp	err_ret
chk_hdl	ENDP

; The following implement the individual Packet Driver commands, basic
; functions first.
;
; Send a packet.
; If Novell mode is active, user's buffer may be altered.  XXX
;
send_pkt:mov	es, _DS[bp]		; get ds of data block to es
	mov	ax, _CX[bp]
	mov	drv_snd.snd_len, ax
	mov	si, _SI[bp]
	push	drv_cct.mod_id		; put our module id
	mov	ax, 1
	push	ax
			; do conversion of Type 8137 to old Novell 802.3
	cmp	novell, 0		; doing Novell packet conversion?
	je	send_pkt3		; e = no
	cmp	word ptr es:[si+12], 3781h ; outgoing Novell Type 8137?
	jne	send_pkt3		; ne = no
	mov	ax, es:[si+12+4]	; get internal length indicator
	xchg	ah, al
	inc	ax			; round up to an even length
	and	al, not 1
	xchg	ah, al
	mov	es:[si+12], ax		; change packet Type field to length

send_pkt3:mov	drv_snd.snd_off, si	; store offset of pkt buffer
	mov	drv_snd.snd_seg, es	; store segment of pkt buffer
	mov	bx, offset drv_snd	; get addr of xmit buff desc
	push	ds			; store on stack
	push	bx
	push	mac_ds			; MACID
	mov	xmt_cmp, REQUEST_QUEUED	; set up for queued data
	call	TransmitChain		; do downcall to NDIS
	sti				; enable ints just to be sure
	xor	cx, cx
send_pkt6:or	ax, ax
	jz	send_pkt4
	cmp	ax, REQUEST_QUEUED	; queued?
	jne	send_pkt5		; ne = no
	mov	ax, xmt_cmp
	loop	send_pkt6		; XXX waiting breaks WD driver
send_pkt4:jmp	good_ret

send_pkt5:mov	dh, CANT_SEND		; trouble, fail
	jmp	err_ret


;
; Handle driver_info() downcall - return driver information.
;
driver_info:
	mov	ch, if_class		; CH is class
	xor	cl, cl			; CL is interface number (always 0)
	mov	_BX[bp], pd_version
	mov	_CX[bp], cx
	mov	_DX[bp], if_type
	mov	_SI[bp], offset pd_name	; ds:si is ptr to name
	mov	_DS[bp], ds
	mov	_AX[bp], PD_LEVEL
	jmp	good_ret

;
; Handle access_type() - sets up to handle an Ethernet packet type.
;
; NOTE:	Depends on entry with interrupts disabled for shared data locking.
;
access_type_class:
	mov	dh, NO_CLASS
	jmp	err_ret


access_type_number:
	mov	dh, NO_NUMBER
	jmp	err_ret

access_type_bad:
	mov	dh, BAD_TYPE
	jmp	err_ret

access_type:
	mov	al, if_class
	cmp	_AL[bp], al		; our class?
	jne	access_type_class	; ne = no, fail
;	cmp	_BX[bp], ANY_TYPE	; generic type?
;	je	access_type_1		; e = yes
;	cmp	_BX[bp], if_type	; our type?
;	je	access_type_1		; e = yes
;	mov	dh, NO_TYPE
;	jmp	err_ret
;access_type_1:
	cmp	_DL[bp], 0		; our number?
	jne	access_type_number	; ne = no
	cmp	_CX[bp], MAX_P_LEN	; is the type length too long?
	ja	access_type_bad		; a = yes, this can't be ours

; look for a free handle

	mov	bx, offset handles	; first handle
access_type_2:
	cmp	[bx].pd_conn_used, 0	; is this handle in use?
	jz	access_type_3
	add	bx, (size per_handle)	; go to the next handle
	cmp	bx, offset end_handles	; examined all handles?
	jb	access_type_2		; b = no, continue
	mov	dh, NO_SPACE
	jmp	err_ret

access_type_3:
	mov	[bx].pd_conn_used, 1	; remember that we're using it
	mov	ax, _DI[bp]		; get receiver address from ES:DI
	mov	word ptr [bx].pd_conn_rcvr, ax	; offset part
	mov	ax, _ES[bp]
	mov	word ptr [bx].pd_conn_rcvr+2, ax ; segment part

	push	ds
	mov	ax, ds
	mov	es, ax
	mov	ds, _DS[bp]		; remember their type
	mov	si, _SI[bp]
	mov	cx, _CX[bp]
	mov	es:[bx].pd_conn_type_len, cx	; remember the TYPE length
	lea	di, [bx].pd_conn_type
	rep	movsb			; copy TYPE field to match
	pop	ds
	mov	al, _AL[bp]		; remember Class
	mov	[bx].pd_conn_class, al
	mov	[bx].pd_conn_rmode, 3
	mov	_AX[bp], bx		; return handle in caller's AX
	jmp	good_ret
;
; Perform release_type() - forget the packet type/upcall/handle
;
; NOTE:	Depends on entry with interrupts disabled for shared data locking.
;
release_type:
	call	chk_hdl			; get handle, return here if ok
					; This is a critical region!!
	mov	[bx].pd_conn_used, 0	; free handle-used indicator
	jmp	good_ret
;
; Perform terminate() - never actually do it.
;
terminate:
	call	chk_hdl			; check handle
	mov	dh, CANT_TERMINATE	; Return error
	jmp	err_ret

;
; Perform get_address() - get the current Ethernet address of the interface
;
get_address:
	cmp	_CX[bp], ETHERADDR_LEN	; Make sure it's an ethernet address
	jc	get_address_err
	call	get_eaddr
	mov	di, _DI[bp]
	mov	es, _ES[bp]
	mov	si, offset address
	mov	cx, ETHERADDR_LEN
	rep	movsb
	mov	_CX[bp], ETHERADDR_LEN
	jmp	good_ret

get_address_err:
	mov	dh, NO_SPACE		; hmmm, I suppose it's close enough
	jmp	err_ret

; Return board's current Ethernet address in address (ETHERADDR_LEN bytes)
; via NDIS information.
get_eaddr proc	near
	push	ds
	mov	di, cs
	mov	es, di
	mov	di, offset address
	lds	si, mac_cctp		; get address of mac cct
	lds	si, sscp[si]		; get address of mac ssc
	add	si, cur_add		; mov to offset in structure
	mov	cx, ETHERADDR_LEN	; get length
	cld
	rep 	movsb			; copy address
	pop	ds
	ret
get_eaddr endp

;
; Perform reset_interface() - this is ignored.
;
reset_interface:
	call	chk_hdl			; check handle
	jmp	good_ret		; if the handle was good, call is good

;
; The following implement the High Performance functions
;
; get_parameters() - Return pointer to parameters structure in ES:DI
;
get_parameters:
	mov	_ES[bp], cs		; return struct adr in caller's ES:DI
	mov	_DI[bp], offset pd_param
	jmp	good_ret		;  & pass it to caller

;
; as_send_pkt() - Not implemented.
;
;as_send_pkt:
;	mov	dh, BAD_COMMAND
;	jmp	err_ret

;
; The following implement the Extended functions
;
; set_rcv_mode translates the PDS mode to an NDIS Packet Filter.
;
set_rcv_mode:
	call	chk_hdl			; get handle, return here if ok
	mov	cx, _CX[bp]
	jcxz	set_rcv_mode_err	; z = illegal receive mode, quit
	cmp	cx, 6			; is mode legal?
	ja	set_rcv_mode_err	; a = no, quit
	mov	bx, cx			; Put it in an index register
	mov	bl, ndis_mode[bx]	; and translate it for NDIS
	xor	bh, bh
	call	set_ndis_mode		; Try to set it
	jz	set_rcv_mode_ok
set_rcv_mode_err:
	mov	dh, BAD_MODE		; no, return error
	jmp	err_ret

set_rcv_mode_ok:
	mov	bx, _BX[bp]		; get handle again
	mov	cx, _CX[bp]
	mov	[bx].pd_conn_rmode, cx	; set receive mode in handle's struct
	mov	pd_rcv_mode, cx		; save the mode we just set
	jmp	good_ret		;  and return ok

;
; Return the current Packet Driver receive mode.
;
get_rcv_mode:
	call	chk_hdl			; get handle, return here if ok
	mov	ax, [bx].pd_conn_rmode	; get mode for this handle
	mov	_AX[bp], ax
	jmp	good_ret		; return it


get_statistics:
	les	si, mac_cctp		; ES:SI == address of NDIS cct
	les	si, es:sssp[si]		; ES:SI == address of NDIS sss
	mov	ax, es
	or	ax, ax			; Is the segment non-zero?
	jnz	getsta1			; nz = yes, accept it
	or	si, si			; how about offset?
	jnz	getsta1			; nz = ok
	mov	dh, BAD_COMMAND		; If they don't implement it,
	jmp	err_ret			;  neither do we

getsta1:mov	ax, cs
	mov	ds, ax
	mov	di, offset pd_stat	; Get start of PD stats table
	cli					; Don't allow updates just now
	mov	ax, word ptr es:r_tot[si]	; Copy total received frames
	mov	dx, word ptr es:r_tot+2[si]
	call	valchk
	mov	ax, word ptr es:x_tot[si]	; Copy total xmitted frames
	mov	dx, word ptr es:x_tot+2[si]
	call	valchk
	mov	ax, word ptr es:rb_tot[si]	; Copy total received bytes
	mov	dx, word ptr es:rb_tot+2[si]
	call	valchk
	mov	ax, word ptr es:xb_tot[si]	; Copy total transmitted bytes
	mov	dx, word ptr es:xb_tot+2[si]
	call	valchk
	mov	ax, word ptr es:r_err[si]	; Copy total receive errors
	mov	dx, word ptr es:r_err+2[si]
	call	valchk
	mov	ax, word ptr es:x_hwer[si]	; Copy total transmit errors
	mov	dx, word ptr es:x_hwer+2[si]
	call	valchk
	mov	ax, word ptr es:r_drop[si]	; Copy total receives dropped
	mov	dx, word ptr es:r_drop+2[si]
	call	valchk
	sti					; All done with shared data
	mov	_SI[bp], offset pd_stat  	; set caller's DS:SI to the
	mov	ax, cs			; address of Packet Driver stats
	mov	_DS[bp], ax
	jmp	good_ret

; Convert double word dx:ax from NDIS unknown value of (long) -1 to (long) 0,
; store results in ds:[di, di+2], move di forward two words.
valchk	proc	near
	cmp	ax, -1			; starting at -1 (NDIS, for unknown)?
	jne	valchkx			; ne = no
	cmp	dx, -1			; this part too
	jne	valchkx			; ne = no
	xor	ax, ax			; zero counters for zero based counts
	xor	dx, dx
valchkx:mov	[di], ax		; store results locally
	mov	[di+2], dx
	add	di, 4			; step to next storage double word
	ret
valchk	endp

;
; Perform set_address() - change physical address of the interface.
;
set_address:
	cmp	_CX[bp], ETHERADDR_LEN	; Make sure it's an ethernet address
	jne	set_address_err		; Jump if bad length
	call	close_m
	push	drv_cct.mod_id		; Make set station address call
	mov	ax, 1
	push	ax			; Push request ID (0 to not conf)
	xor	ax, ax
	push	ax			; Must be 0
	push	_ES[bp]			; Push pointer to address to set
	push	_DI[bp]
	mov	ax, SET_STA_ADDR	; SetStationAddress function code
	push	ax
	push	mac_ds
	SYNCREQUEST
	jnz	set_err
	call	open_m
	call	get_eaddr
	jmp	good_ret

set_err:
	call	open_m
	call	get_eaddr		; just in case
	mov	dh, CANT_SET
	jmp	err_ret

set_address_err:
	mov	dh, BAD_ADDRESS		; We didn't like the address
	jmp	err_ret

pd_isr	ENDP
;;;;;; end of Packet Driver direct support procedures

;
; The following are upcalls from DIS:

; RequestConfirm enters with stack of (after our push bp)
;	dw	[BP+16]		ProtID
;	dw	[BP+14]		MACID
;	dw	[BP+12]		ReqHandle
;	dw	[BP+10]		Status
;	dw	[BP+8]		Request
;	dw	[BP+6]		ProtDS (our DS)

req_con	PROC	FAR			; Request Confirm
	push	bp
	mov	bp, sp
	mov	ax, [bp+10]		; get NDIS status response
	mov	cs:req_con_flg, ax	; store in local area
	pop	bp
	xor	ax, ax
	ret	12
req_con	ENDP

; Wait for a (possibly) queued request to complete & return result.
; Z flag is set if success.

req_wt	PROC	NEAR
	sti
req_wt1:cmp	ax, REQUEST_QUEUED
	jnz	req_wt2
	mov	ax, req_con_flg
	jmp	short req_wt1
req_wt2:or	ax, ax
	ret
req_wt	ENDP


; TransmitConfirm enters with stack of (after our push bp)
;	dw	[BP+14]		ProtID
;	dw	[BP+12]		MACID
;	dw	[BP+10]		ReqHandle
;	dw	[BP+8]		Status
;	dw	[BP+6]		ProtDS (our DS)

xmt_con	PROC	FAR			; Transmit Confirm
	push	bp
	mov	bp, sp
	mov	ax, 8[bp]
	mov	cs:xmt_cmp, ax		; moves the return code into static
	pop	bp
	xor	ax, ax
	ret	10
xmt_con	ENDP


sta_ind	PROC	FAR			; Status handled, not used
	xor	ax, ax
	ret	12
sta_ind	ENDP


dis_pat	PROC	FAR			; System entry point for pkt driver
	push	bp			; Used only by initiate bind request
	mov	bp, sp
	cmp	word ptr 8[bp], 1	; Is it initiate_bind?
	je	dispat1			; e = yes
	mov	ax, GENERAL_FAILURE	; NO: fail
	pop	bp
	ret	14

dispat1:push	ds			; save stuff
	push	es
	push	bx
	push	cx
	push	si
	push	di

	mov	ax, cs			; set up DS == CS
	mov	ds, ax
	les	bx, 12[bp]
	mov	word ptr mac_cctp, bx
	mov	word ptr mac_cctp + 2, es

	mov	ax, offset drv_cct	; push pkt drv cct (our cct)
	push	ds
	push	ax
	mov	ax, offset mac_cctp	; push addr for MAC's cct
	push	ds
	push	ax
	xor	ax, ax			; pad parameter
	push	ax
	mov	ax, 2			; Load Bind command code
	push	ax
	push	es:[bx].mod_ds
	call	dword ptr es:[bx].system ; call MAC's system entry point
	or	ax, ax
	jz	dispat2			; z = Bind succeeded
	MSG	bad_bind		; tell the user the bad news
	jmp	rtn_dis			; Bind failed, fatal error

dispat2:
	call	sav_mac			; Save MAC entry point addresses
	les	bx, mac_cctp		; Check if OpenAdapter needed
	les	bx, es:[bx].sscp

	lea	di, [bx].mtype
	mov	si, offset t8023
	mov	cx, offset t8023e - offset t8023
	cld
	repe	cmpsb
	jz	is8023
	lea	di, [bx].mtype
	mov	si, offset t8025
	mov	cx, offset t8025e - offset t8025
	repe	cmpsb
	jz	is8025
	jmp	short gottype
is8023:	mov	if_class, 11
	mov	matchoff, 14
	jmp	short gottype
is8025:	mov	if_class, 3
	mov	matchoff, 14
	mov	addroff, 2
	mov	multimask, 80h
	mov	ax, es:[bx].maxfram
	mov	mtu, ax
;	jmp	short gottype

gottype:call	open_m
	jz	open_ok1		; skip to setting packet filter

	MSG	bad_open_adpt		; Fatal error: open adapter failed
	jmp	rtn_dis

open_ok1:
	push	mac_ds
	call	IndicationOff
	push	mac_ds
	call	IndicationOn
	sti

	call	get_eaddr
	mov	bx, 3			; Set default filter: Directed,
	call	set_ndis_mode		;  Multicast & Broadcast (3)
	jz	set_vec
	MSG	bad_set_pkt		; show an error and fail
	jmp	rtn_dis

; Give warning if the Packet Driver vector is already in use but use anyway

set_vec:
	xor	ax, ax			; Set ES to 0 to look in int tab
	mov	es, ax
	mov	bx, cs:pd_vector	; Get vector and multiply by 4
	shl	bx, 1
	shl	bx, 1
	mov	es:[bx], offset pd_isr
	mov	es:2[bx], cs
	xor	ax, ax
rtn_dis:
	pop	di			; all done
	pop	si
	pop	cx
	pop	bx
	pop	es
	pop	ds
	pop	bp
	ret	14
dis_pat	ENDP

; Make the NDIS SetPktFilter call (both at bind and from set_rcv_mode)
;
; Arguments:
;	BX	NDIS Packet filter to set (see DIS p 45 for bits)
;		 * 0 - directed and multicast
;		 * 1 - broadcast
;		   2 - promiscuous
;		   3 - any source routing packet
;
; Some Token Rind drivers work in all-frames mode (even though they reject
; the set_packet_filter call) as long as the appropriate argument is passed
; to open_adapter.  The set_packet_filter error is ignored here for such
; cases.
;
set_ndis_mode PROC NEAR
	mov	ax, nd_mode
	xor	ax, bx
	and	ax, 4			; changing to/from promiscuous mode
	jz	set_ndis_mode1
	push	bx
	call	close_m
	pop	bx
set_ndis_mode1:
	mov	nd_mode, bx
	push	drv_cct.mod_id		; make set packet filter call
	mov	ax, 1
	push	ax			; unique handle (0 to not conf)
	push	bx			; Push packet filter value
	xor	ax, ax
	push	ax			; dd pad
	push	ax
	mov	ax, SET_PKT_FLT		; SetPacketFilter command
	push	ax
	push	mac_ds
	SYNCREQUEST
	push	ax
	call	open_m
	pop	ax
	cmp	ax, INVALID_PARAMETER	; Absorb error...
	jnz	set_ndis_mode2
	cmp	if_class, 3		; for Token Ring...
	jnz	set_ndis_mode2
	test	nd_mode, 4		; in promiscuous mode only.
	jz	set_ndis_mode2
	xor	ax, ax
set_ndis_mode2:
	or	ax, ax
	ret				; NDIS return code is in AX
set_ndis_mode ENDP

; Open the MAC if appropriate.  Pass flags for Token Ring all-frames
; mode as necessary.
;
open_m	PROC NEAR
	les	bx, mac_cctp
	les	bx, es:[bx].sscp
	test	es:[bx].svc_1, 0800h			; supports open
	jz	open_m1
	les	bx, mac_cctp
	les	bx, es:[bx].sssp
	test	word ptr es:[bx].lstatus, 010h		; already open
	jnz	open_m1
	push	drv_cct.mod_id
	mov	ax, 1
	push	ax
	xor	ax, ax
	cmp	if_class, 3				; for Token Ring
	jnz	open_m2
	test	nd_mode, 4				; in promiscuous mode
	jz	open_m2
	mov	ax, 6
open_m2:push	ax
	xor	ax, ax
	push	ax
	push	ax
	mov	ax, OPEN_ADAPTER
	push	ax
	push	mac_ds
	SYNCREQUEST
	ret
open_m1:xor	ax, ax
	ret
open_m	ENDP

; Close the MAC if appropriate.
;
close_m	PROC NEAR
	les	bx, mac_cctp
	les	bx, es:[bx].sscp
	test	es:[bx].svc_1, 0800h			; supports open
	jz	close_m1
	les	bx, mac_cctp
	les	bx, es:[bx].sssp
	test	word ptr es:[bx].lstatus, 010h		; not open
	jz	open_m1

	push	drv_cct.mod_id
	mov	ax, 1
	push	ax
	xor	ax, ax
	push	ax
	push	ax
	push	ax
	mov	ax, CLOSE_ADAPTER
	push	ax
	push	mac_ds
	SYNCREQUEST
	ret
close_m1:xor	ax, ax
	ret
close_m	ENDP

;
; Put MAC entry points into static locations - called at bind time.
;
sav_mac	PROC	NEAR
	les	si, mac_cctp
	mov	ax, es:[si].mod_ds	; save MAC ds
	mov	mac_ds, ax
	les	si, es:[si].udtp

	mov	bx, offset Request	; save request entry point
	mov	ax, es:4[si]
	mov	[bx], ax
	mov	ax, es:6[si]
	mov	2[bx], ax

	mov	bx, offset TransmitChain ; save xmt block entry point
	mov	ax, es:8[si]
	mov	[bx], ax
	mov	ax, es:10[si]
	mov	2[bx], ax

	mov	bx, offset TransferData	; save xfer data entry point
	mov	ax, es:12[si]
	mov	[bx], ax
	mov	ax, es:14[si]
	mov	2[bx], ax

;	mov	bx, offset ReceiveRelease ; save recv rel entry point
;	mov	ax, es:16[si]
;	mov	[bx], ax
;	mov	ax, es:18[si]
;	mov	2[bx], ax

	mov	bx, offset IndicationOn	; save ind on entry point
	mov	ax, es:20[si]
	mov	[bx], ax
	mov	ax, es:22[si]
	mov	2[bx], ax

	mov	bx, offset IndicationOff ; save ind off entry point
	mov	ax, es:24[si]
	mov	[bx], ax
	mov	ax, es:26[si]
	mov	2[bx], ax
	ret
sav_mac	ENDP

; Message strings needed at bind time.

bad_open_adpt	db	"Adapter did not open", EOL
bad_set_pkt	db	"Set packet filter failed", EOL
bad_bind	db	7, "BIND failed", EOL
t8023		db	'802.3', 0
t8023e:
t8025		db	'802.5', 0
t8025e:

end_res:	;;;; Currently not keeping init code in memory

;
; DOS device driver interrupt entry point.
;
; This is used to initialize module and read parameters from PROTOCOLS.INI
; only, and frees itself after startup.  The NDIS bind takes place later,
; via dis_pat and its friends above.
;
intr	PROC	FAR
	push	es			; save all registers
	push	ds
	push	si
	push	di
	push	dx
	push	cx
	push	bx
	push	ax

	mov	ax, cs			; check to see if already initialized
	mov	ds, ax
	mov	al, init_flg		; our init flag
	or	al, al			; not inited yet (0)?
	jz	intr1			; z = yes, init now

	mov	bx, req_off		; already initialized - return
	mov	ds, req_seg		;  with error
	mov	[bx].status, 810Ch
	jmp	rtn

intr1:	cli				; not initialized - switch to new
	mov	si, ss			;  stack and init
	mov	dx, sp
	mov	ax, cs
	mov	ss, ax
	mov	sp, offset new_stk	; Need a big stack for this call
	sti				; Critical region
	push	si			; Save old SS
	push	dx			;  and SP
	MSG	msg_copyright		; Display copyright notice
	call	init			; Init this driver

	mov	ax, cs			; Set DS == CS
	mov	ds, ax
	mov	bx, req_off		; Get request header ptr
	mov	es, req_seg
	mov	word ptr es:[bx].status, 0100h	; Set return status ok
	mov	init_flg, 1		; Note that we've initialized
	mov	ax, offset end_res	; Set end of resident code
	mov	word ptr es:[bx].end_off, ax
	mov	ax, cs
	mov	es:[bx].end_seg, ax

	pop	di			; Old SP
	pop	si			;  and old SS
	cli				; Critical region
	mov	ss, si			; Change back to old stack
	mov	sp, di
	sti				; End critical region
rtn:	pop	ax			; All done
	pop	bx
	pop	cx
	pop	dx
	pop	di
	pop	si
	pop	ds
	pop	es
	ret
intr	ENDP

	db	512 dup (0)
new_stk	label	word		; A stack for init to use
	db	4 dup (0)
fil_han	dw	0		; File handle for init

;
; Initialize the converter module - read parameters from PROTOCOLS.INI.
;
init	PROC	NEAR
	mov	ax, cs			; open the Protocol Manager driver
	mov	ds, ax
	mov	ah, fopen          	; open file
	mov	al, 0C2h
	mov	dx, offset pm__nam	; device name
	int	dos
	jnc	init1              	; nc = success
	MSG	pro_no_open		; error
	jmp	init_err

init1:	mov	fil_han, ax		; file handle
	mov	bx, ax
	mov	ax, cs
	mov	ds, ax
	mov	drv_req.req_opc, 1	; make GetProtocolManagerInfo call
	mov	drv_req.req_sta, -1	; zero out return status
	mov	drv_req.req_of1, -1	; NULL out pointers
	mov	drv_req.req_sg1, -1
	mov	drv_req.req_of2, -1	; NULL out pointer 2
	mov	drv_req.req_sg2, -1
	mov	drv_req.req_prm, -1	; zero out parameter word

	mov	ah, ioctl		; IOCTL req
	mov	al, 02h			; device input
	mov	dx, offset drv_req	; pointer to buffer
	mov	cx, 14			; size of buffer
	int	dos			; call DOS
	jnc  	init2			; nc = success
	MSG	pro_bad_gpm		; Error: print msg & bomb
	jmp	init_err

init2:	mov	ax, cs			; restore ds
	mov	ds, ax

	mov	ax, offset pro_nam	; Get name of module to bind to,
	push	ax			;  returned by get_pro in ES:DI
	mov	ax, pro_nam_len
	push	ax
	mov	ax, offset pro_bnd_to
	push	ax
	mov	ax, pro_bnd_to_len
	push	ax
	xor	ax, ax
	push	ax
	call	get_pro			; Try to find the token we want
	or	di, di			; Was it there?
	jnz	init4			; nz = yes, parse it
	mov	drv_bnd.bnd_cnt, 0	; else say nothing bound
	jmp	short init45

init4:	push	ds			; Save name in bindings structure
	push	ds			; currently allowed to bind to only
	push	es			;  one MAC
	pop	ds
	pop	es
	mov	si, di
	mov	di, offset drv_bnd.bnd_nam
	mov	cx, -2[si]
	cld
	rep	movsb
	pop	ds

init45:	mov	ax, offset pro_nam	; Get Packet Driver vector to use
	push	ax
	mov	ax, pro_nam_len
	push	ax
	mov	ax, offset pro_prm_vec	; "INTVEC" keyword
	push	ax
	mov	ax, pro_prm_vec_len
	push	ax
	xor	ax, ax
	push	ax
	call	get_pro			; Go look for the token
	or	di, di			; Was the token found?
	jnz	init5			; nz = yes
	MSG	vec_not_spc		; abort if not found
	jmp	init_err

init5:	mov	dx, es:[di]		; check that vector is in range
	cmp	dx, 80h			; 0x80 is high limit
	jge	bad_vec2
	cmp	dx, 60h			; 0x60 is low limit
	jl	bad_vec2
	mov	pd_vector, dx		; Save value for bind time
	jmp	short init6		; Go on to EOI interrupt

bad_vec2:
	MSG	msg_bad_vec		; Abort if out of range
	jmp	init_err

init6:	mov	ax, offset pro_nam	; Get EOI interrupt (if any)
	push	ax
	mov	ax, pro_nam_len
	push	ax
	mov	ax, offset pro_daisy_vec ; "CHAINVEC" key word
	push	ax
	mov	ax, pro_daisy_len
	push	ax
	xor	ax, ax
	push	ax
	call	get_pro			; Try to find the token
	or	di, di
	jz	init7			; z = no interrupt

	mov	dx, es:[di]		; Check that interrupt is ok
	mov	byte ptr ind_int+1, dl	; Modify the code
	mov	param_int, dx		; Save interrupt number

init7:	mov	ax, offset pro_nam	; Get old Novell 802.3 keyword
	push	ax
	mov	ax, pro_nam_len
	push	ax
	mov	ax, offset pro_novell	; "NOVELL" key word
	push	ax
	mov	ax, pro_nov_len
	push	ax
	xor	ax, ax
	push	ax
	mov	novell, 0		; assume no token
	call	get_pro			; Try to find the token
	or	di, di
	jz	init8			; z = no token
	mov	dx, es:[di]		; get the token's value
	and	dl, not 20h		; to upper case
	cmp	dl, 'Y'			; "yes"?
	jne	init8			; ne = no conversion
	mov	novell, 1		; set flag
	MSG	novmsg			; tell the user about conversion

init8:	call	pkt_ptr			; Initialize the LDT and CCT pointers
	mov	ax, cs
	mov	ds, ax
	mov	drv_req.req_opc, 2	; RegisterModule call
	mov	drv_req.req_sta, 0	; zero out return status
	mov	drv_req.req_of1, offset drv_cct ; cct pointer
	mov	drv_req.req_sg1, ax
	mov	drv_req.req_of2, offset drv_bnd
	mov	drv_req.req_sg2, ax
	mov	drv_req.req_prm, 0	; zero out parameter word
	mov	ah, ioctl		; IOCTL call
	mov	al, 2
	mov	dx, offset drv_req
	mov	cx, 14
	mov	bx, fil_han
	int	dos
	cmp	drv_req.req_sta, SUCCESS
	je	init9			; e = success
	MSG	reg_mod_nok
	jmp	init_err

init9:	mov	bx, fil_han		; Close protman device
	mov	ah, fclose
	int	dos
	jc	init10			; c = failure
	xor	ax, ax			; Indicate success
	ret				;  & do normal return

init10:	MSG	msg_err_clo		; close failed, quite unlikely
	jmp	init_err

init_err:mov	ax, 1			; error return
	ret
init	ENDP

; get_pro returns a pointer to the keyword entry from GPMI call
;	12[bp] is a pointer to module name
;	10[bp] is length of module name
;	8[bp] is a pointer to keyword name
;	6[bp] is length of keyword name
;	4[bp] is number of parameter wanted from specified keyword
;
; returns
;	es:bx is pointer to param
;	ax zero for ok and !0 for not found
;
get_pro	PROC	NEAR
	push	bp
	mov	bp, sp
	push	ds
	push	bx
	push	si
	lds	bx, dword ptr drv_req.req_of1	; ConMemIma pointer

	mov	ax, cs				; find module name
	mov	es, ax
getpro1:mov	ax, ds				; quit if pointer NULL (eol)
	or	ax, ax
	jz	err_get_pro			; z = error
	mov	di, 12[bp]			; module name
	mov	si, bx				; set up to point name
	add	si, 8
	mov	cx, 10[bp]			; module name length
	cld
	repe	cmpsb				; right module name?
	je	pro_fnd				; e = module name found
	lds	bx, dword ptr [bx]		; not found-load next in chain
	jmp	short getpro1

pro_fnd:
	add	bx, 24				; offset of parameter pointers
getpro2:
	mov	ax, ds
	or	ax, ax
	jz	err_get_pro
	mov	di, 8[bp]			; parameter name
	mov	cx, 6[bp]			; parameter name length
	mov	si, bx
	add	si, 8
	cld
	repe	cmpsb
	je	key_fnd				; e = parameter found
	lds	bx, dword ptr [bx]		; not found-load next in chain
	jmp	short getpro2
key_fnd:
	add	bx, 24				; offset of values
	mov	cx, 4[bp]			; check if enough values are
	cmp	cx, [bx]			; here
	jge	err_get_pro
	add	bx, 2				; position to the value
	jcxz	prm_fnd				; may be either char string
getpro3:					;  or number depending on type
	add	bx, 2
	add	bx, [bx]
	add	bx, 2
	loop	getpro3
prm_fnd:
	mov	si, bx				; set es:di to point to value
	add	si, 4
	mov	cx, 2[bx]
	mov	ax, ds
	mov	es, ax
	mov	di, si
	jmp	short getpro4
err_get_pro:
;	MSG	pro_not_fnd			; error return
	xor	ax, ax
	mov	es, ax
	mov	di, ax
getpro4:
	pop	si				; common return
	pop	bx
	pop	ds
	pop	bp
	ret	10
get_pro	ENDP


pkt_ptr	PROC	NEAR				; Set up pointers in Packet
	mov	ax, cs				; Driver ldt and cct
	mov	ds, ax				;  Note:most of this could
	mov	bx, offset drv_ldt		;  (should) be done statically
	mov	word ptr [bx], offset drv_cct	; driver's cct back pointer
	mov	2[bx], ax
	add	bx, 8				; skip int flgs
	mov	[bx], offset req_con		; RequestConfirm address
	mov	2[bx], ax
	mov	4[bx], offset xmt_con		; TransmitConfirm address
	mov	6[bx], ax
	mov	8[bx], offset rcv_lah		; ReceiveLookahead indication
	mov	10[bx], ax
	mov	12[bx], offset ind_com		; IndicationComplete address
	mov	14[bx], ax
	mov	16[bx], offset rcv_chn		; ReceiveChain indication add
	mov	18[bx], ax
	mov	20[bx], offset sta_ind		; status indication address
	mov	22[bx], ax

	mov	bx, offset drv_cct.ldtp		; set up point to drv ldt
	mov	word ptr [bx], offset drv_ldt
	mov	2[bx], ax
;
;set up pointers in pkt driver cct
;	only doing lower dispatch table, all other left NULL
;	hopefully this will work
;
	mov	drv_cct.mod_id, -1
	mov	drv_cct.mod_ds, ax
	mov	bx, offset drv_cct.system
	mov	[bx], offset dis_pat		; drv system func entry point
	mov	2[bx], ax			; drv ds
	mov	word ptr 16[bx], offset drv_ldt	; ptr to ldt
	mov	18[bx], ax
	ret
pkt_ptr	ENDP

; Text messages that can be flushed after startup but before bind.

msg_no_vect	db	"Vector not specified", EOL
msg_bad_vec	db	"Invalid vector (must be 60h-7Fh)", EOL
msg_err_clo	db	"Error closing MAC driver", EOL
msg_copyright	db 	"MAC/DIS to Packet Driver converter loaded."
		db	" Version 1.11", CR, LF
		db 	"Copyright 1991 FTP Software, Inc.  All rights "
		db	"reserved.", cr, lf
		db	" v1.07 by Joe R. Doupnik, jrd@cc.usu.edu, "
		db	"Utah State Univ, 18 May 1991", cr, lf
		db	" v1.09 by Joe R. Doupnik, jrd@cc.usu.edu, "
		db	"Utah State Univ, 3 Nov 1991", cr, lf
		db	" v1.08, v1.10, v1.11 by"
		db	" Dan Lanciani, ddl@danlan.com", EOL
pm__nam		db	"protman$", 0
pro_no_open	db	"Protocol Manager not present", EOL
pro_bad_gpm	db	"GetProtocolManagerInfo call failed", EOL
pro_nam		db	"PKTDRV", 0
pro_nam_len	equ	$ - pro_nam
pro_prm_vec	db	"INTVEC", 0
pro_prm_vec_len	equ	$ - pro_prm_vec
pro_daisy_vec	db	"CHAINVEC", 0
pro_daisy_len	equ	$ - pro_daisy_vec
pro_prm_nok	db	"SINTVECXX", 0
pro_prm_nok_len	equ	$ - pro_prm_nok
pro_bnd_to	db	"BINDINGS", 0
pro_bnd_to_len	equ	$ - pro_bnd_to
pro_novell	db	"NOVELL", 0
pro_nov_len	equ	$ - pro_novell
novmsg		db	"Using OLD NOVELL 802.3 packets on the wire", EOL
vec_not_spc	db	"Interrupt vector for Packet Driver not specifed"
		db	" in PROTOCOL.INI", EOL
reg_mod_nok	db	"Register module call failed", EOL
CSEG	ends
	end
