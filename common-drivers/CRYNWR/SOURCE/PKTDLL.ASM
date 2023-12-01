	page 66, 132
; PKTDLL.ASM Version 1.2 - provides Packet Driver interface over Digital's DLL.
;
; (c) Copyright Brian F. Angus 1993.  All rights reserved.
;
; PKTDLL was renamed from DLLPKT to fit with Digital Equipment Corporation's
; naming conventions and the left to right reading habits of the western
; world
;
; Big credits to: Harry P.E. Stox for the "c" version of DLLPKT (v0.1)
;		  Daniel D. Lanciani for code chunks from ODIPKT and DIS_PKT
;		  Joe R. Doupnik for code chunks from DIS_PKT
;		  Chris Lord and Mitch Lichtenberg - they know who they are
;
; This unmodified source file and its executable form may be used and
; redistributed freely.  The source may be modified, and the source or
; executable versions built from the modified source may be used and
; redistributed, provided that this notice and the copyright displayed by
; the exectuable remain intact, and provided that the executable displays
; an additional message indicating that it has been modified, and by whom.
;
; Brian F. Angus releases this software "as is", with no express or
; implied warranty, including, but not limited to, the implied warranties
; of merchantability and fitness for a particular purpose.
;
; Please send bug reports to angus@trcoa.enet.dec.com or
;
; Brian Angus
; Digital Equipment of Canada
; 505 University Avenue
; Toronto, Ontario M5G 2H2
; CANADA

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Equates			      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Miscellaneous Stuff
carry			equ 0001h	; carry bit in flag register
cr			equ 13		; carriage return
tab			equ 9		; tab
eol			equ <13,10>	; end of line
eos			equ <13,10,'$'>	; end of string
hd1Int			equ 08h		; 1st bank of IRQ vectors
hd2Int			equ 70h		; 2nd bank of IRQ vectors

; DIX Ethernet Specific
ethMaxFrame		equ 1514	; maximum frame size
ethMinFrame		equ 60		; minimum frame size
ethAddrLen		equ 6		; length of ethernet address
ethTypeLen		equ 2		; length of ethernet type field
ethHeadLen		equ 14		; lenfth of ethernet header
ethDataLen		equ 1500	; length of ethernet data field

; Packet Driver Specific
pktFunction		equ 5		; basic and high performance functions
pktClass		equ 1		; driver class (DIX ethernet)
pktType			equ -1		; driver type (match any)
pktNumber		equ 0		; driver number
pktVersion		equ 10		; driver version number
pktInt			equ 61h		; driver interrupt (default)
maxHandles		equ 8		; max active handles
txBufCount		equ 8		; back to back transmits
rxBufCount		equ 8		; back to back receives

; Packet Driver Function Calls
pktNotImplemented	equ 0		; function not implemented
pktDriverInfo		equ 1		; get driver information
pktAccessType		equ 2		; open handle for protocol
pktReleaseType		equ 3		; close handle for protocol
pktSendPkt		equ 4		; transmit a packet
pktTerminate		equ 5		; unload driver if possible
pktGetAddress		equ 6		; get ethernet address
pktResetInterface	equ 7		; reset ethernet card and driver
pktStopUpcalls		equ 8		; stop upcalls to applications
pktGetParameters	equ 10		; get extended driver information
pktAsSendPkt		equ 11		; high performance transmit
pktSetRcvMode		equ 20		; set receive mode
pktGetRcvMode		equ 21		; get receive mode
pktSetMulticastList	equ 22		; set multicast list
pktGetMulticastList	equ 23		; get multicast list
pktGetStatistics	equ 24		; get statistics
pktSetAddress		equ 25		; set ethernet address

; Packet Driver Return Codes
pkterrBadHandle		equ 1		; invalid handle number
pkterrNoClass		equ 2		; no interfaces of this class found
pkterrNoType		equ 3		; no interfaces of this type found
pkterrNoNumber		equ 4		; no interfaces of this number found
pkterrBadType		equ 5		; bad packet type specified
pkterrNoMulticast	equ 6		; multicasts not supported
pkterrCantTerminate	equ 7		; packet driver cannot terminate
pkterrBadMode		equ 8		; invalid receiver mode specified
pkterrNoSpace		equ 9		; insufficient space for operation
pkterrTypeInuse		equ 10		; type is currently in use
pkterrBadCommand	equ 11		; command is not implemented
pkterrCantSend		equ 12		; packet couldn't be sent
pkterrCantSet		equ 13		; hardware address couldn't be changed
pkterrBadAddress	equ 14		; invalid hardware address
pkterrCantReset		equ 15		; couldn't reset interface

; DLL Specific
schInt			equ 6ch		; interrupt for scheduler
dllInt			equ 69h		; interrupt for datalink
dllNoPad		equ 0		; don't pad ethernet message
dllPadMessage		equ 1		; pad message to minimum size
dllMode802		equ 0		; 802.3 compatibility mode for Novell
dllModeDIX		equ 1		; DIX frame formats
dllModePromis		equ 2		; promiscuous mode (all frames)

; DLL Function Calls - (the 0a00h is the DLL module id for the AH register)
dllInit			equ 0a00h+0	; initialize datalink functions
dllOpen			equ 0a00h+1	; open a portal
dllClose		equ 0a00h+2	; close a portal
dllEnbMulti		equ 0a00h+3	; enable a multicast address
dllDisMulti		equ 0a00h+4	; disable a multicast address
dllTransmit		equ 0a00h+5	; transmit a message
dllRequestXmit		equ 0a00h+6	; request a transmit buffer
dllDeallocate		equ 0a00h+7	; free a buffer
dllReadChan		equ 0a00h+8	; read channel status
dllReadPlist		equ 0a00h+9	; read portal list
dllReadPortal		equ 0a00h+10	; read portal status
dllReadCount		equ 0a00h+11	; read/zero counters
dllNetworkBoot		equ 0a00h+12	; remote boot (not implemented)
dllEnableChan		equ 0a00h+13	; emable channel
dllDisabChan		equ 0a00h+14	; disable channel
dllStartMOP		equ 0a00h+15	; enable MOP portals
dllStopMOP		equ 0a00h+16	; disable MOP portals
dllReaDecparm		equ 0a00h+17	; read DECPARM.DAT address
dllSetDecparm		equ 0a00h+18	; set DECPARM.DAT address
dllExtLoopback		equ 0a00h+19	; do external loopback
dllGetPDB		equ 0a00h+20	; get portal database pointer
dllGetPrivInfo		equ 0a00h+25	; get private information
dllGetRemBoot		equ 0a00h+26	; get remote boot information
dllDisMOPmulti		equ 0a00h+29	; disable MOP multicast
dllEnaMOPmulti		equ 0a00h+30	; enable MOP multicast
dllInsCheck		equ 0a00h+31	; installation check
dllReqSized		equ 0a00h+33	; request sized transmit buffer
dllExtCount		equ 0a00h+40	; extended counters
dllReadChar		equ 0a00h+41	; read characteristics

; DLL Return Codes
dllerrNotImpl		equ -1		; not implemented
dllerrSuccess		equ 0		; function call succeeded
dllerrInitFail		equ 1		; initialization failed
dllerrChNotOff		equ 2		; channel not off
dllerrStateOff		equ 3		; channel is off
dllerrNoAddr		equ 4		; address has not been set
dllerrNoHW		equ 5		; hardware is broken
dllerrBuf2Smal		equ 6		; buffer is too small
dllerrNoneAvl		equ 7		; no more buffers available
dllerrNoResrc		equ 8		; no resources available
dllerrPromAct		equ 9		; promiscuous receiver is active
dllerrNonExcl		equ 10		; promiscuous receiver already active
dllerrUnRec		equ 11		; unrecognised portal
dllerrPTinuse		equ 12		; protocol type in use
dllerrNotMulti		equ 13		; address is not a multicast address
dllerrOutStand		equ 14		; portal has outstanding calls active
dllerrNoRXbad		equ 15		; hardware does not support bad frames
dllerrNoneOut		equ 16		; no receive buffers to be cancelled
dllerrNoEvents		equ 17		; no events in queue
dllerrBroken		equ 18		; port driver is broken
dllerrExQuota		equ 19		; exceeded quota
dllerrAlInit		equ 20		; already initialized
dllerrLBfail		equ 21		; loopback failure
dllerrIllBuf		equ 22		; illegal buffer freed
dllerrInvCmd		equ 23		; invalid command

; DOS Errorlevel Codes
doserrSuccess		equ 0		; normal completion
doserrFixMEM		equ 1		; wrong memory address	- fixed
doserrFixIRQ		equ 2		; wrong IRQ level	- fixed
doserrFixDMA		equ 3		; wrong DMA channel	- fixed
doserrFixIO		equ 4		; wrong IO address	- fixed
doserrExists		equ 5		; packet driver already loaded
doserrCableFail		equ 20		; general cable failure
doserrCableOpen		equ 21		; network cable is open
doserrCableShort	equ 22		; network cable is shorted
doserrUsage		equ 30		; usage message
doserrRange		equ 31		; arguments out of range
doserrError		equ 32		; unspecified initialization error
doserrBadMEM		equ 34		; wrong memory address
doserrBadIRQ		equ 35		; wrong IRQ level
doserrBadDMA		equ 36		; wrong DMA channel
doserrNoCard		equ 37		; wrong IO address or no network card

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Structures Definitions	      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ETH	struc				; structure of DIX ethernet packet
	ethDestAddr	db ethAddrLen dup(?) ; destination address
	ethSourceAddr	db ethAddrLen dup(?) ; source address
	ethType		db ethTypeLen dup(?) ; protocol type
	ethData		db ethDataLen dup(?) ; data
ETH	ends

HND	struc				; structure of handle block
	hndInUse	db ?		; handle in use flag
	hndPerm		db ?		; permanent handle for Windows
	hndPortalID	dw ?		; portal id
	hndType		db ethTypeLen dup(?) ; protocol type
	hndReceive	dd ?		; receive packet routine
HND	ends

PRM	struc				; structure of parameter block
	prmMajorRev	db 1		; major revision = 1
	prmMinorRev	db 9		; minor revision = 9
	prmParamLen	db 14		; length of this structure = 14
	prmAddrLen	db ethAddrLen	; MAC addr length
	prmMTU		dw ethMaxFrame	; MAC packet length
	prmMulticastAval dw 0		; no multicast support
	prmRcvBuffs	dw rxBufCount - 1 ; back-to-back RX -1
	prmXmtBufs	dw txBufCount - 1 ; back-to-back TX -1
	prmIntNum	dw 0		; EOI interrupt
PRM	ends

DCB	struc				; structure of DLL control block
	dcbPortalID	dw ?		; portal ID
	dcbSaddr	db ethAddrLen dup(?) ; ethernet source address
	dcbDaddr	db ethAddrLen dup(?) ; ethernet destination address
	dcbBufferPtr	dd ?		; buffer address
	dcbBufferLen	dw ?		; buffer length
	dcbOperation	dw ?		; DCB operation
	dcbPad		db ?		; pad mode (open)
	dcbMode		db ?		; mode (open)
	dcbLScallback	dd ?		; line state callback
	dcbRXcallback	dd ?		; receive callback
	dcbTXcallback	dd ?		; transmit callback
	dcbMaxOut	db ?		; maximum outstanding
	dcbPtype	db ethTypeLen dup(?) ; protocol type
	dcbTXhandle	dw ?		; transmit handle
DCB	ends

UCB	struc				; structure of user callback block
	ucbPortalID	dw ?		; portal ID
	ucbDaddr	db ethAddrLen dup(?) ; destination address
	ucbSaddr	db ethAddrLen dup(?) ; source address
	ucbBufferPtr	dd ?		; buffer address
	ucbBufferLen	dw ?		; buffer length
	ucbBufStatus	db ?		; buffer status
	ucbBufReason	db ?		; buffer reason
	ucbTXhandle	dw ?		; transmit handle
UCB	ends

PSB	struc				; structure of portal status block
	psbBufLost	dw ?		; number of lost buffers
	psbPtype	db ethTypeLen dup(?) ; protocol type
PSB	ends

DWP	struc				; structure of double word pointer
	offs		dw ?		; define as 0
	segm		dw ?		; define as 2
DWP	ends

R16	struc				; stack offsets of 16 bit registers
	_es		dw ?		; es register
	_ds		dw ?		; ds register
	_bp		dw ?		; bp register
	_di		dw ?		; di register
	_si		dw ?		; si register
	_dx		dw ?		; dx register
	_cx		dw ?		; cx register
	_bx		dw ?		; bx register
	_ax		dw ?		; ax register
	_ip		dw ?		; ip register
	_cs		dw ?		; cs register
	_flags		dw ?		; flag register
R16	ends

R08	struc				; stack offsets of 8 bit registers
			dw 5 dup(?)	; es, ds, bp, di, si registers
	_dl		db ?		; dl register
	_dh		db ?		; dh register
	_cl		db ?		; cl register
	_ch		db ?		; ch register
	_bl		db ?		; bl register
	_bh		db ?		; bh register
	_al		db ?		; al register
	_ah		db ?		; ah register
R08	ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main Code Segment		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CODE	segment word public 'CODE'
	assume cs:CODE, ds:CODE, es:nothing, ss:CODE

	org	2ch
envSeg	label	word
	org	80h
cmdBuf	label	byte
	org	100h
at100h:	jmp	start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Driver Data			      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pktName	db	'PKTDLL', 0		; driver name used by driver_info
ether	db	ethAddrLen dup(?)	; ethernet address
pktVec	dw	pktInt * 4		; default driver vector address

param	PRM	<>			; parameter block

hndTab	HND	maxHandles dup(<>)	; the handle table
hndEnd	label	byte

pList	dw	maxHandles dup(?)	; active portal list
pStat	PSB	<>			; portal status block (partial)

flag802	db	0			; novell 802.3 flag

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check for Windows or Task Switcher ;;
;;  regs inp: none		      ;;
;;  regs out: flags		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

safe:	mov	cx, 'DE'		; check for DESQview
	mov	dx, 'SQ'
	mov	ax, 2b01h
	int	21h
	cmp	al, -1
	mov	ax, 1
	jne	safe1

	mov	ax, 4680h		; check for DOS 5.0 shell
	int	2fh
	cmp	ax, 0
	mov	ax, 2
	jz	safe1

	mov	ax, 1600h		; check for MS-Windows
	int	2fh
	mov	ah, 0
	cmp	al, 0
	jz	safe1
	cmp	al, 80h
	mov	al, 0
	jz	safe1
	mov	ax, 3
safe1:	cmp	ax, 0
	ret				; "z" bit is clear if ok

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Send Packet Common Subroutine      ;;
;;  regs inp: ds,si,cx		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

send:	cmp	cx, ethMaxFrame		; check packet size
	ja	send4
	cmp	cx, ethMinFrame
	jnb	send1
	mov	cx, ethMinFrame
send1:	sub	cx, ethHeadLen		; adjust packet size

	mov	ax, word ptr [si].ethType ; get protocol type

	mov	di, offset hndTab	; address handle table
send2:	cmp	cs:[di].hndInUse, 1	; find matching handle
	jne	send3
	cmp	word ptr cs:[di].hndType, ax
	je	send5
send3:	add	di, size HND
	cmp	di, offset hndEnd
	jb	send2

send4:	add	sp, 2			; pop off our return address
	mov	dh, pkterrCantSend	; return can't send error
	jmp	bad

send5:	push	bp			; save register pointer
	sub	sp, size DCB		; allocate DCB on stack
	mov	ax, ss
	mov	es, ax
	mov	bx, sp
	mov	bp, sp

	mov	ax, cs:[di].hndPortalID ; store portal ID
	mov	[bp].dcbPortalID, ax

	mov	ax, dllRequestXmit	; allocate buffer
	int	dllInt
	cmp	ax, dllerrSuccess
	jne	send6

	mov	[bp].dcbBufferLen, cx	; store more DCB info
	mov	ax, word ptr cs:[di].hndType
	mov	word ptr [bp].dcbPType, ax

	push	si			; store destination address
	push	cx
	lea	di, [bp].dcbDaddr
	lea	si, [si].ethDestAddr
	mov	cx, ethAddrLen / 2
	rep	movsw
	pop	cx
	pop	si

	push	es			; store packet buffer
	les	di, [bp].dcbBufferPtr
	lea	si, [si].ethData
	clc
	rcr	cx, 1
	rep	movsw
	rcl	cx, 1
	rep	movsb
	pop	es

	mov	ax, dllTransmit		; transmit buffer
	int	dllInt

send6:	add	sp, size DCB		; deallocate DCB
	pop	bp			; restore register pointer

	cmp	ax, dllerrSuccess
	jne	send4
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DLL RX and TX Upcalls	      ;;
;;  regs inp: es,bx		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

rx_upc:	push	es			; save UCB pointer
	push	bx

	mov	dx, es:[bx].ucbPortalID	; get portal ID
	mov	cx, es:[bx].ucbBufferLen; get buffer length
	add	cx, ethHeadLen

	mov	ax, cs			; address data segment
	mov	ds, ax

	mov	bx, offset hndTab	; address handle table
rx1:	cmp	[bx].hndInUse, 1	; find matching handle
	jne	rx2
	cmp	[bx].hndPortalID, dx
	je	rx3
rx2:	add	bx, size HND
	cmp	bx, offset hndEnd
	jb	rx1
	jmp	short rx5

rx3:	push	bx			; request application buffer
	push	cx
	push	word ptr [bx].hndType
	xor	ax, ax
	call	[bx].hndReceive
	pop	ax
	pop	cx
	pop	dx

	mov	bx, es			; check for null pointer
	cmp	bx, 0
	jne	rx4
	cmp	di, 0
	je	rx5

rx4:	mov	bp, sp			; address UCB
	lds	bx, [bp]

	push	cx			; save buffer length
	push	es			; save buffer pointer
	push	di

	cld				; copy buffer to application
	lea	si, [bx].ucbDaddr	;  destination
	mov	cx, ethAddrLen / 2
	rep	movsw
	lea	si, [bx].ucbSaddr	;  source
	mov	cx, ethAddrLen / 2
	rep	movsw
	stosw				;  protocol type
	mov	cx, [bx].ucbBufferLen	;  ethernet data
	lds	si, [bx].ucbBufferPtr
	clc
	rcr	cx, 1
	rep	movsw
	rcl	cx, 1
	rep	movsb

	pop	si			; restore buffer pointer
	pop	ds
	pop	cx			; restore buffer length
	mov	bx, dx			; restore handle

	mov	ax, 1			; tell application copy completed
	call	cs:[bx].hndReceive

rx5:	pop	bx			; restore ucb pointer
	pop	es

tx_upc:	mov	ax, dllDeallocate	; free portal's RX buffer
	int	dllInt
	retf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  not_implemented     ;;
;;  regs inp: none		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

not_implemented:
	mov	dh, pkterrBadCommand	; return bad command error
	jmp	bad

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  driver_info	      ;;
;;  regs inp: none		      ;;
;;  regs out: bx,ch,dx,cl,ds,si,al    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

driver_info:
	mov	[bp]._al, pktFunction	; return information in registers
	mov	[bp]._ch, pktClass
	mov	[bp]._dx, pktType
	mov	[bp]._cl, pktNumber
	mov	[bp]._bx, pktVersion
	mov	[bp]._ds, cs
	mov	[bp]._si, offset pktName
	jmp	good

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  access_type	      ;;
;;  regs inp: al,bx,dl,ds,si,cx,es,di ;;
;;  regs out: ax		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

access_type:
	cmp	al, pktClass		; verify class
	je	acc1
	mov	dh, pkterrNoClass
	jmp	bad

acc1:	cmp	dl, pktNumber		; verify number
	je	acc2
	mov	dh, pkterrNoNumber
	jmp	bad

acc2:	cmp	cx, ethTypeLen		; verify protocol type
	je	acc3
	mov	dh, pkterrBadType
	jmp	bad

acc3:	mov	dx, [si]		; save protocol type
	cmp	dx, 0
	je	acc8

	mov	ax, cs			; address data segment
	mov	ds, ax

	mov	si, offset hndTab	; address handle table
acc4:	cmp	word ptr [si].hndType, dx ; find matching handle
	jne	acc5
	cmp	[si].hndInUse, 1
	je	acc7
	jmp	short acc9
acc5:	add	si, size HND
	cmp	si, offset hndEnd
	jb	acc4

	mov	si, offset hndTab	; address handle table
acc6:	cmp	word ptr [si].hndInUse, 0 ; find non-inuse non-perm handle
	je	acc9
	add	si, size HND
	cmp	si, offset hndEnd
	jb	acc6
	mov	dh, pkterrNoSpace
	jmp	bad
acc7:	mov	dh, pkterrTypeInuse
	jmp	bad
acc8:	jmp	good

acc9:	mov	word ptr [si].hndType, dx ; store some handle data
	mov	word ptr [si].hndReceive.segm, es
	mov	word ptr [si].hndReceive.offs, di

	push	bp			; save register pointer
	sub	sp, size DCB		; allocate DCB on stack
	mov	ax, ss
	mov	es, ax
	mov	bx, sp
	mov	bp, sp

	mov	ax, [si].hndPortalID	; store handle and skip if open
	mov	[bp].dcbPortalID, ax
	cmp	[si].hndPerm, 1
	jne	acc10
	jmp	acc13

acc10:	mov	[bp].dcbBufferPtr.segm, cs ; get active portal list - C'mon Guys
	mov	[bp].dcbBufferPtr.offs, offset pList
	mov	[bp].dcbBufferLen, maxHandles * 2
	mov	ax, dllReadPlist
	int	dllInt

	mov	cx, [bp].dcbBufferLen	; scan for match
	mov	[bp].dcbBufferPtr.segm, cs
	mov	[bp].dcbBufferPtr.offs, offset pStat
	mov	[bp].dcbBufferLen, size PSB
	mov	di, offset pList
acc11:	mov	ax, [di]
	add	di, 2
	mov	word ptr [bp].dcbPortalID, ax
	mov	ax, dllReadPortal
	int	dllInt
	mov	ax, dllerrPTinuse
	cmp	dx, word ptr pStat.psbPtype
	je	acc15
	loop	acc11

	mov	[bp].dcbPad, dllNoPad	; open portal
	mov	[bp].dcbMode, dllModeDIX
	cmp	dx, 3781h
	jne	acc12
	cmp	flag802, 1
	jne	acc12
	mov	[bp].dcbMode, dllMode802
	mov	dx, -1
acc12:	mov	word ptr [bp].dcbLScallback.segm, 0
	mov	word ptr [bp].dcbLScallback.offs, 0
	mov	word ptr [bp].dcbRXcallback.segm, cs
	mov	word ptr [bp].dcbRXcallback.offs, offset rx_upc
	mov	word ptr [bp].dcbTXcallback.segm, cs
	mov	word ptr [bp].dcbTXcallback.offs, offset tx_upc
	mov	word ptr [bp].dcbPType, dx
	mov	ax, dllOpen
	int	dllInt

	cmp	ax, dllerrSuccess	; check for success
	jne	acc15

	mov	ax, [bp].dcbPortalID	; store portal ID
	mov	[si].hndPortalID, ax

acc13:	cmp	word ptr [si].hndReceive.segm, 0 ; check for permanent flag
	jne	acc14				 ; where es:bx = 0:0
	cmp	word ptr [si].hndReceive.offs, 0
	jne	acc14

	add	sp, size DCB		; deallocate DCB
	pop	bp			; restore register pointer
	mov	[si].hndPerm, 1		; set permanent flag
	jmp	good			; done

acc14:	lea	di, [bp].dcbSaddr	; enable broadcasts
	mov	cx, ethAddrLen / 2
	mov	ax, -1
	rep	stosw
	mov	ax, dllEnbMulti
	int	dllInt

	add	sp, size DCB		; deallocate DCB
	pop	bp			; restore register pointer

	mov	[si].hndInUse, 1	; set in use flag
	mov	[bp]._ax, si		; return handle
	jmp	good			; done

acc15:	add	sp, size DCB		; deallocate DCB
	pop	bp			; restore register pointer

	mov	dh, pkterrTypeInuse	; protocol in use error
	cmp	ax, dllerrPTinuse
	je	acc16
	mov	dh, pkterrNoSpace	; all other errors
acc16:	jmp	bad			; done

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  release_type	      ;;
;;  regs inp: bx		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

release_type:
	mov	ax, cs			; address handle table
	mov	ds, ax
	mov	si, [bp]._bx		; BX trashed by dispatcher

	cmp	si, offset hndTab	; skip if too small
	jb	rel2
	cmp	si, offset hndEnd	; skip if too large
	jae	rel2
	cmp	[si].hndInUse, 1	; skip if not in use
	jne	rel2

	sub	sp, size DCB		; allocate DCB on stack
	mov	ax, ss
	mov	es, ax
	mov	bx, sp

	mov	ax, [si].hndPortalID	; store portal ID
	mov	es:[bx].dcbPortalID, ax

	lea	di, [bx].dcbSaddr	; disable broadcasts
	mov	cx, ethAddrLen / 2
	mov	ax, -1
	rep	stosw
	mov	ax, dllDisMulti
	int	dllInt

	cmp	[si].hndPerm, 1		; check for permanent handle
	je	rel1

	mov	ax, dllClose		; close portal
	int	dllInt

rel1:	add	sp, size DCB		; deallocate DCB

	cmp	ax, dllerrSuccess	; check for success
	jne	rel2

	mov	[si].hndInUse, 0	; clear in use flag
	jmp	good

rel2:	mov	dh, pkterrBadHandle	; return bad handle error
	jmp	bad

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  send_pkt	      ;;
;;  regs inp: ds,si,cx		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

send_pkt:
	call	send			; call send packet routine
	jmp	good

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  terminate	      ;;
;;  regs inp: bx		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

terminate:
	call	safe			; check for windows or task switcher
	jnz	term5

	mov	si, offset hndTab	; address handle table
term1:	cmp	cs:[si].hndInUse, 1	; check for handles in use
	je	term5
	add	si, size HND
	cmp	si, offset hndEnd
	jb	term1

	xor	ax, ax			; check for hooked vector
	mov	ds, ax
	mov	dx, cs
	mov	bx, cs:pktVec
	cmp	[bx].segm, dx
	jne	term5
	cmp	[bx].offs, offset intpkt
	jne	term5

	sub	sp, size DCB		; allocate DCB on stack
	mov	ax, ss
	mov	es, ax
	mov	bx, sp

	mov	si, offset hndTab	; address handle table
term2:	cmp	cs:[si].hndPerm, 1	; check for permanent handles
	jne	term3
	mov	ax, cs:[si].hndPortalID	; free portal
	mov	es:[bx].dcbPortalID, ax
	mov	ax, dllClose
	int	dllInt
term3:	add	si, size HND
	cmp	si, offset hndEnd
	jb	term2

	mov	ax, dllStartMOP		; re-enable MOP
	int	dllInt
	mov	ax, dllEnaMOPmulti
	int	dllInt

	add	sp, size DCB		; deallocate DCB

	mov	bx, cs:pktVec		; restore vector
	xor	ax, ax
	cli
	mov	[bx].segm, ax
	mov	[bx].offs, ax
	sti

	mov	ax, cs			; address TSR memory
	mov	es, ax

	cmp	ax, [bp]._cs		; avoid releasing memory twice
	je	term4			; when calling itself

	mov	ah, 49h			; release TSR memory
	int	21h
term4:	jmp	good

term5:	mov	dh, pkterrCantTerminate	; return can't terminate error
	jmp	bad

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  get_address	      ;;
;;  regs inp: bx,es,di,cx	      ;;
;;  regs out: cx		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

get_address:
	cmp	cx, ethAddrLen		; check buffer length
	jnb	get1
	mov	dh, pkterrNoSpace
	jmp	bad

get1:	mov	ax, cs			; copy ethernet address
	mov	ds, ax
	mov	si, offset ether
	mov	cx, ethAddrLen / 2
	rep	movsw
	mov	[bp]._cx, ethAddrLen
	jmp	good

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  reset_interface     ;;
;;  regs inp: bx		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

reset_interface:
	mov	dh, pkterrCantReset	; return can't reset error
	jmp	bad

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  stop_upcalls	      ;;
;;  regs inp: none		      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

stop_upcalls:
	mov	ax, cs			; address handle table
	mov	ds, ax

	sub	sp, size DCB		; allocate DCB on stack
	mov	ax, ss
	mov	es, ax
	mov	bx, sp

	mov	si, offset hndTab	; address handle table
stop1:	cmp	[si].hndInUse, 1	; check for handle in use
	jne	stop2

	mov	ax, [si].hndPortalID	; store portal id
	mov	es:[bx].dcbPortalID, ax

	lea	di, [bx].dcbSaddr	; disable broadcasts
	mov	cx, ethAddrLen / 2
	mov	ax, -1
	rep	stosw
	mov	ax, dllDisMulti
	int	dllInt

	cmp	[si].hndPerm, 1		; check for permanent handle
	je	stop2

	mov	ax, dllClose		; close portal
	int	dllInt

stop2:	mov	[si].hndInUse, 0	; clear in use flag
	add	si, size HND
	cmp	si, offset hndEnd
	jb	stop1

	add	sp, size DCB		; deallocate DCB
	jmp	good

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  get_parameters      ;;
;;  regs inp: none		      ;;
;;  regs out: es,di		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

get_parameters:
	mov	[bp]._es, cs		; return parameter block address
	mov	[bp]._di, offset param
	jmp	good

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PKT Function:  as_send_pkt	      ;;
;;  regs inp: ds,si,cx,es,di	      ;;
;;  regs out: none		      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

as_send_pkt:
	call	send			; call send packet routine

	mov	ds, [bp]._es		; call application upcall
	mov	si, [bp]._di
	mov	es, [bp]._ds
	mov	di, [bp]._si
	xor	ax, ax
	call	dword ptr [si]

	jmp	good

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Packet Driver Function Table	      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

funTab	dw	not_implemented		; 0
	dw	driver_info		; 1
	dw	access_type		; 2
	dw	release_type		; 3
	dw	send_pkt		; 4
	dw	terminate		; 5
	dw	get_address		; 6
	dw	reset_interface		; 7
	dw	stop_upcalls		; 8
	dw	not_implemented		; 9
	dw	get_parameters		; 10
	dw	as_send_pkt		; 11
maxFun	equ	($ - offset funTab) / 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Packet Driver Interrupt Routine    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

intpkt: jmp	short int1		; skip signature
	nop

sig	db	'PKT DRVR', 0

int1:	sti				; enable interrupts
	cld				; set forward direction

	push	ax			; save all registers - hmmph!
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es
	
	mov	bp, sp			; address registers with BP

	and	[bp]._flags, not carry	; set success status

	cmp	ah, maxFun		; validate function request
	jb	int2
	xor	ah, ah

int2:	mov	bl, ah			; call function
	xor	bh, bh			;  note that BP must be preserved
	shl	bx, 1			;  within the functions
	jmp	cs:funTab[bx]

bad:	or	[bp]._flags, carry	; set error status
	mov	[bp]._dh, dh

good:	pop	es			; restore registers - hmmph!
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Discardable PKT and DLL Init Code  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:	cld

	mov	dx, offset message	; print copyright message
	mov	ah, 9
	int	21h

	call	safe			; check for windows or task switcher
	jz	parse
	mov	dx, offset unsafe	; print unsafe error and exit
	mov	al, doserrError
	jmp	exit

; Parse Command Line
; 
parse:	mov	bp, offset cmdBuf + 1	; address command line buffer
	mov	si, offset proto	; address protocol type list

parse1:	call	space			; parse command line
	call	number
	jc	parse4

	cmp	ax, 60h			; check if driver vector
	jb	parse2
	cmp	ax, 7fh
	ja	parse2

	add	ax, ax			; store driver vector
	add	ax, ax
	mov	pktVec, ax
	jmp	parse1

parse2:	cmp	ax, 00000h		; check if protocol type
	je	parse3
	cmp	ax, 005efh
	jb	parse6
	cmp	ax, 0fffeh
	ja	parse6

parse3:	xchg	al, ah			; store protocol type
	mov	[si], ax
	add	si, 2
	mov	word ptr [si], 0
	jmp	parse1

parse4:	call	space			; check for switches
	cmp	al, cr
	je	check
	mov	bx, ax			; save switch

	add	bp, 2			; check end of line
	call	space
	cmp	al, cr
	jne	parse5

	or	ah, 20h			; validate switches
	cmp	bx, "n/"
	je	novell
	cmp	bx, "s/"
	je	stop
	cmp	bx, "u/"
	je	term

parse5:	mov	dx, offset usage	; print usage error and exit
	mov	al, doserrUsage
	jmp	exit

parse6:	mov	dx, offset range	; print range error and exit
	mov	al, doserrRange
	jmp	exit

; Terminate Packet Driver
; 
term:	call	exist			; check for existing driver
	mov	dx, offset missing
	mov	al, doserrError
	jne	trm1

	mov	ah, pktTerminate	; call packet driver to terminate
	pushf
	call	dword ptr es:[bx]

	mov	dx, offset termin	; print success and exit
	mov	al, doserrSuccess
	jnc	trm1

	mov	dx, offset active	; print fail and exit
	mov	al, doserrError

trm1:	jmp	exit

; Stop Packet Driver Upcalls
; 
stop:	call	exist			; check for existing driver
	mov	dx, offset missing
	mov	al, doserrError
	jne	stp1

	mov	ah, pktStopUpcalls	; call packet driver to terminate
	pushf
	call	dword ptr es:[bx]

	mov	dx, offset stopped	; print success and exit
	mov	al, doserrSuccess

stp1:	jmp	exit

; Set Novell Netware 802.3 Flag
; 
novell:	mov	flag802, 1

; Perform Pre-Install Checks
; 
check:	call	exist			; check for existing driver
	mov	dx, offset already
	mov	al, doserrExists
	je	check1

	mov	dx, offset inuse	; check for null vectors
	mov	al, doserrError
	cmp	es:[bx].segm, 0
	jne	check1
	cmp	es:[bx].offs, 0
	jne	check1

	mov	bx, schInt * 4		; check for DLL
	les	bx, es:[bx]
	mov	dx, offset no_dll
	mov	al, doserrError
	cmp	byte ptr es:[bx]-3, 'S'
	jne	check1
	cmp	byte ptr es:[bx]-2, 'C'
	jne	check1
	cmp	byte ptr es:[bx]-1, 'H'
	jne	check1

	mov	ax, dllInsCheck
	int	dllInt
	cmp	ax, dllerrNotImpl
	mov	al, doserrError
	je	setup

check1:	jmp	exit			; print error and exit

; Setup and Start Packet Driver
; 
setup:	push	ds			; save data segment
	sub	sp, size DCB		; allocate DCB on stack
	mov	ax, ss
	mov	es, ax
	mov	bx, sp

	mov	ds, ax			; address ethernet address buffer
	lea	si, [bx].dcbSaddr

	mov	ax, dllReadChan		; get ethernet address
	int	dllInt

	mov	ax, cs			; copy ethernet address
	mov	es, ax
	mov	di, offset ether
	mov	cx, ethAddrLen / 2
	rep	movsw

	mov	ax, dllStopMOP		; disable MOP
	int	dllInt

	add	sp, size DCB		; deallocate DCB
	pop	ds			; restore data segment

	xor	ax, ax			; get hardware interrupt vector
	mov	es, ax
	mov	bx, schInt * 4
	mov	ax, es:[bx].segm

	mov	bx, hd1Int * 4 + 4	; scan 1st bank skipping the timer
	mov	cx, 7
setup1:	cmp	ax, es:[bx].segm
	je	setup3
	add	bx, 4
	loop	setup1

	mov	bx, hd2Int * 4		; scan 2nd bank
	mov	cx, 8
setup2:	cmp	ax, es:[bx].segm
	je	setup3
	add	bx, 4
	loop	setup2

	mov	bx, 0			; clear if no match
setup3:	shr	bx, 1			; store interrupt vector
	shr	bx, 1
	mov	param.prmIntNum, bx

	mov	bx, pktVec		; setup up interrupt vectors
	cli
	mov	es:[bx].segm, cs
	mov	es:[bx].offs, offset intpkt
	sti

	push	es:[bx].segm		; hold open protocol types for Windows
	push	es:[bx].offs		; special permanent flag: es:di = 0:0
	mov	bp, sp

	xor	di, di			; initialize registers
	mov	si, offset proto
	mov	cx, ethTypeLen
	mov	dl, pktNumber
	mov	bx, pktType
	mov	al, pktClass
	mov	ah, pktAccessType

setup4:	cmp	word ptr [si], 0	; address protocol types
	je	setup6

	pushf				; call packet driver to open
	call	dword ptr [bp]
	inc	si
	inc	si
	jnc	setup4

	mov	ah, pktTerminate	; call packet driver to terminate
	mov	al, dh
	pushf
	call	dword ptr [bp]
	add	sp, 4			; clean up stack

	mov	dx, offset ptinuse	; print failure message and exit
	cmp	al, pkterrTypeInuse
	je	setup5
	mov	dx, offset nospace
setup5:	mov	al, doserrError
	jmp	short exit

setup6:	add	sp, 4			; clean up stack

; Print Message and Become Resident
;
tsr:	mov	dx, offset install	; print success message
	mov	ah, 9
	int	21h

	mov	es, envSeg		; free environment space
	mov	ah, 49h
	int	21h
	mov	envSeg, 0

	mov	cx, 5			; close all standard file handles
	xor	bx, bx
tsr1:	mov	ah, 3eh
	int	21h
	inc	bx
	loop	tsr1

	mov	dx, offset start	; terminate and stay resident
	add	dx, 0fh
	mov	cl, 4
	shr	dx, cl
	mov	ax, 3100h
	int	21h

; Print Message and Terminate
;
exit:	push	ax			; print message
	mov	ah, 9
	int	21h
	pop	ax

	mov	ah, 4ch			; terminate with status
	int	21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Discardable Init Code Subroutines  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

space:	cmp	byte ptr [bp], ' '	; skip spaces and tabs
	je	space1
	cmp	byte ptr [bp], tab
	je	space1
	mov	ax, word ptr [bp]
	ret
space1:	inc	bp
	jmp	short space

number:	xor	ax, ax			; clear number
	mov	cx, -1

	cmp	word ptr [bp], 'x0'	; remove prefix if any
	je	num1
	cmp	word ptr [bp], 'X0'
	je	num1
	jmp	short num2
num1:	xor	cx, cx
	add	bp, 2

num2:	mov	bl, byte ptr [bp]	; validate digit
	cmp	bl, '0'
	jb	num5
	cmp	bl, '9'
	ja	num4

num3:	xor	cx, cx			; add digit
	mov	dx, 10h
	mul	dx
	cmp	dx, 0
	jnz	num6
	sub	bl, '0'
	xor	bh, bh
	add	ax, bx
	inc	bp
	jmp	num2

num4:	or	bl, 20h			; check for hex
	cmp	bl, 'a'
	jb	num5
	cmp	bl, 'f'
	ja	num5
	sub	bl, 'a' - '9' - 1
	jmp	num3

num5:	cmp	cx, 0			; skip if no number entered
	jnz	num7

	mov	bl, byte ptr [bp]	; ok if space, tab, switch or return
	cmp	bl, ' '
	je	num7
	cmp	bl, tab
	je	num7
	cmp	bl, '/'
	je	num7
	cmp	bl, cr
	je	num7

	mov	dx, offset usage	; print usage error and exit
	mov	al, doserrUsage
	jmp	exit

num6:	mov	dx, offset range	; number out of range
	mov	al, doserrRange
	jmp	exit

num7:	add	cx, 1
	ret

exist:	xor	ax, ax			; check for existing driver
	mov	es, ax
	mov	bx, pktVec

	push	es
	les	di, es:[bx]
	add	di, 3
	mov	si, offset sig
	mov	cx, 9
	rep	cmpsb
	pop	es
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Discardable Init Code Data	      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

message	db	'PKTDLL 1.2'						    ,eol
	db	'(c) Copyright Brian Angus 1993.  All rights reserved.'	    ,eol
	db	'This software is provided with NO WARRANTY.'		,eol,eos
install	db	'PKTDLL is installed and ready.'			    ,eos
termin	db	'PKTDLL successfully unloaded.'				    ,eos
stopped	db	'PKTDLL upcalls stopped.'				    ,eos
usage	db	'Usage: PKTDLL [packet_int] [proto_type...] [/n] [/s] [/u].',eos
range	db	'Specified values are out of range (0, 60-7F, 05EF-FFFE).'  ,eos
no_dll	db	'Please start the DLL driver first.'			    ,eos
already	db	'A driver is already installed at this vector.'		    ,eos
inuse	db	'Specified interrupt is already in use.'		    ,eos
nospace	db	'Not enough portals for requested protocols.'		    ,eol
	db	'Unload some protocols (ie. LAT, LAST, etc.)'		    ,eos
ptinuse	db	'Protocol type(s) are already in use.'			    ,eol
	db	'Check specified and/or default protocols.'		    ,eos
missing	db	'PKTDLL is not loaded at specified vector.'		    ,eos
active	db	'Cannot unload PKTDLL - protocols still active.'	    ,eos
unsafe	db	'Cannot load or unload PKTDLL in this environment.'	    ,eos
proto	dw	0008h, 0608h, 3580h, 0000h

CODE	ends
	end	at100h
