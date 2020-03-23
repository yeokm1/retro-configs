;;*******************************************************
;* Program name : DEFS.ASM
;* Modified By : Spenser Tsai
;* Date : 10/04/97' (DAVICOM)
;********************************************************
majver		equ	MAJ_VER 	;version number of the infrastructure.

version 	equ	MIN_VER 	;Major Version number of the program

dm9100_version	equ	GEN_VER 	;version number of the generic 9100 driver.

MAX_ADDR_LEN	equ	16		;maximum number of bytes in our address.

MAX_HANDLE	equ	10		;maximum number of handles.

MAX_P_LEN	equ	8		;maximum type length

;;MAX_MULTICAST   equ	  8		  ;maximum number of multicast addresses.
MAX_MULTICAST	equ	14		 ;maximum number of multicast addresses.

;  Copyright, 1988-1992, Russell Nelson, Crynwr Software

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

HT	equ	09h
CR	equ	0dh
LF	equ	0ah

;
;  Packet Driver Error numbers
NO_ERROR	equ	0		;no error at all.
  ifndef SMCINC
BAD_HANDLE	equ	1		;invalid handle number
  endif
NO_CLASS	equ	2		;no interfaces of specified class found
NO_TYPE 	equ	3		;no interfaces of specified type found
NO_NUMBER	equ	4		;no interfaces of specified number found
  ifndef SMCINC
BAD_TYPE	equ	5		;bad packet type specified
  endif
NO_MULTICAST	equ	6		;this interface does not support
					;multicast
CANT_TERMINATE	equ	7		;this packet driver cannot terminate
BAD_MODE	equ	8		;an invalid receiver mode was specified
NO_SPACE	equ	9		;operation failed because of
					;insufficient space
TYPE_INUSE	equ	10		;the type had previously been accessed,
					;and not released.
BAD_COMMAND	equ	11		;the command was out of range, or not
					;implemented
CANT_SEND	equ	12		;the packet couldn't be sent (usually
					;hardware error)
CANT_SET	equ	13		;hardware address couldn't be changed
					;(more than 1 handle open)
BAD_ADDRESS	equ	14		;hardware address has bad length or
					;format
CANT_RESET	equ	15		;Couldn't reset interface (more than
					;1 handle open).
BAD_IOCB	equ	16		;an invalid iocb was specified

;a few useful Ethernet definitions.
RUNT		equ	60		;smallest legal size packet, no fcs
GIANT		equ	1514		;largest legal size packet, no fcs
EADDR_LEN	equ	6		;Ethernet address length.
ARCADDR_LEN	equ	1

BLUEBOOK	equ	1
IEEE8023	equ	11


;this macro does a "rep movsb" with a static count.
repmov	macro	count
	rept	(count) / 2
	movsw
	endm
	rept	(count) MOD 2
	movsb
	endm
	endm

;moves a segment register into another segment register.
movseg	macro	to, from
	push	from
	pop	to
	endm

;add a word to a dword.
add2	macro	n,a			; inc a 32 bit integer
	add	n.offs,a		;increment the low word
	adc	n.segm,0		;increment the high word
	endm

;this macro writes the given character to the given row and column on
;  an CGA.
to_scrn macro	r, c, ch
	local	again
	push	bx
	push	es
	mov	bx,0b800h
	mov	es,bx
	mov	bx,es:[r*160+c*2]
again:
	inc	bh
	and	bh,07h
	je	again			;; don't use black.
	mov	bl,ch
	mov	es:[r*160+c*2],bx
	pop	es
	pop	bx
	endm



segmoffs	struc			; defines offs as 0, segm as 2
offs		dw	?
segm		dw	?
segmoffs	ends

CY	equ	0001h
EI	equ	0200h

iocb		struc			; as_send_pkt structure
  buffer	  dd	  ?		  ; Pointer to the buffer
  len		  dw	  ?		  ; Its length
  flags 	  db	  ?		  ; Some flags
  ret_code	  db	  ?		  ; Completion code
  upcall	  dd	  ?		  ; I/O completion upcall
  next		  dd	  ?		  ; Private next pointer (queue)
  resv		  db	  4 dup (?)	  ; Unused private data
iocb		ends

DONE	equ	1		; I/O complete flag
CALLME	equ	2		; Please upcall me flag


send_queueempty macro
; Check if send queue is empty.
; Enter with interrupts disabled.
; Exit with zr (zero) if empty, nz (not zero) if not.
; Destroys ax.
	mov ax, word ptr send_head	; Queue empty?
	or ax,	word ptr send_head+2
	endm

send_peekqueue	macro
; Peek into the queue and get the next entry.
; Enter with interrupts disabled.
; Exit with es:di -> iocb.
	les di, send_head	; Get head segment:offset
	endm

; Bits in sys_features
SYS_MCA equ	02		; a micro channel computer
TWO_8259	equ	40h		; 2nd 8259 exists

; Bits in flagbyte
CALLED_ETOPEN	equ	1		; have called etopen
D_OPTION	equ	2		; delayed initialization
N_OPTION	equ	4		; Novell protocol conversion
W_OPTION	equ	8		; Windows upcall checking.
U_OPTION	equ	10h		; Terminate the driver.
;;-+
;;S_OPTION	  EQU	  20h		  ; 10Mb Speed
;;F_OPTION	  EQU	  40h		  ; Full Duplex
;;SF_OPTION	  EQU	  60h		  ; Selected speed & mode
;;XS_OPTION	  EQU	  80h		  ; 100Mb Speed
;;A_OPTION	  EQU	  100h		  ; Auto-Negotination & Full-Duplex
;;AF_OPTION	  EQU	  140h		  ; Full Duplex
H_OPTION	EQU	20h		; 10Mb Half Duplex
F_OPTION	EQU	40h		; 10Mb Full Duplex
XH_OPTION	EQU	80h		; 100Mb Half Duplex
XF_OPTION	EQU	100h		; 100Mb Full Duplex
A_OPTION	EQU	200h		; Auto-Negotiation
T_OPTION	EQU	400h		; HomePNA
;;-+
B_OPTION	EQU	200h		; BNC

table_multicast       struc
  table_maxnum	    dw	    0	    ; max number of multicast addresses
  table_current     dw	    0	    ; current number of multicast addresses
  table_multiaddr   db	    0	    ; 16 byte sets of multicast addresses
table_multicast       ends
