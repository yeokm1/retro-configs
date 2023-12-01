;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         ETHEREST.ASM
;
; Description:  LMI lower routine assembly source file for all SMC 
;		ISA/MCA Cards.
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lmetha\vcs\etherest.avm  $
;  
;     Rev 1.55   07 Sep 1995 13:31:28   NAJARIAN
;  added dword ptr keywords to all error counter pointers to make the
;  code compatible with the new lmac.
;  
;     Rev 1.54   04 May 1995 10:56:06   STEIGER
;  Added conditional assembly directives that enable destination address
;  verification on all physically-addressed frames. If ADD_CHK is defined
;  when the file is assembled, this feature will be enabled.
;  
;     Rev 1.53   26 Apr 1995 15:31:24   STEIGER
;  Fixed endianess problem in MC_FIX code that was added in r1.52.
;  
;     Rev 1.52   26 Apr 1995 14:06:18   STEIGER
;  Commented out conditionals around MC_FIX. The 790 is exhibiting
;  multicast bugs.
;  Added additional code to check frames whose status indicates
;  multicast/broadcast but are physical against the node_address field
;  in the adapter structure.
;  
;     Rev 1.50   07 Jul 1994 14:31:10   wood_r
;  
; LM_8416_s2.1_v2.01
; Change:	Removed the control key for the GETVER utility.  The 
;		revision is in the file ETH_COM.ASM only.
;
; Change:	Modified the code to save on code space requirements for
;     Rev 1.49   12 May 1994 14:45:10   wood_r
;  Code reduction and RAM test bug
;
; LM_8416_s2.1_v2.00b
;
; Change:	Modified the code to save on code space requirements for
;		the 8416 "Dual Mode" driver.  The code to enable and disable
;		memory for the 790 chip was placed into two subroutines:
;		AccessSharedRam and DeAccessSharedRam.  This is similar to
;		the Flat Model code base.
;		
;  
;     Rev 1.48   28 Apr 1994 15:22:44   wood_r
;  Changed MM_LM_Receive_Copy to a local function
;  
;     Rev 1.47   25 Apr 1994 08:44:02   wood_r
;  Case sensitive problems for NDIS2 were resolved
;  
;     Rev 1.46   21 Apr 1994 16:05:34   wood_r
;  Banner problems
;  
;     Rev 1.45   21 Apr 1994 15:15:28   wood_r
; LM_8416_s2.1_v2.00a
;
; Change:	This revision of the file will be the start of the next
;		generation of the Ethernet LMACs.  The version level will
;		be bumped from 1.xxx to 2.xxx.  The 1.xxx source code 
;		history was designed and developed by Mike Steiger.
;
;		The Ring Empty feature on the 795 was added to the code
;		base.  To implement this feature, a flag bit is used in the
;		adapter structure variable "lmac_flags".  The equate used
;		with this flag is USE_RE_BIT.  It is used in the functions:
;		LM_Service_Events, Init_Nic, and UpdateBoundary.
;
;		The file was modified to remove all IFxDEFS for I/O mapping
;		(UBIO).  The driver now supports a dual mode of operation.
;		This is implemented by using a flag bit in the adapter
;		structure variable "adapter_flags".  The equate used for this
;		is IO_MAPPED.  This variable is available to the UMAC to
;		query the type of driver.
;
;		The Multicast bug on the XA was tested on the XB, and the
;		declaration MC_FIX removed from the make file once the
;		fix was verified.  The code still remains intact in case
;		there are any problems at a later date.
;
;
; Change:	Revision History (Implemented in v1.42)
;
;		Ref #		Date		Who
;		[1]		03/14/94	M. Steiger
; 
;		Added capability of LM_Receive_Copy to poll for RX status
;		on early RX frames. The UMAC now indicates the copy mode
;		in BX:
;
;		0 = lookahead copy (no rx status check)
;
;		1 = final copy. RX status is polled if not immediately
;		    available. If no RX status is available after FFFFh
;		    polls, HARDWARE_FAILED is returned.
;
;		2 = final copy. If no RX status is available after copy is
;		    complete, LM_Receive_Copy returns HARDWARE_FAILED. This
;		    method is used in previous versions of this source file
;		    when BX != 0.
;
;+!/? ***********************************************************************

;;; Version string visible in executable using GETVER.EXE utility ...

db	'SMC Ethernet Lower Driver ETHEREST.ASM $Revision:   1.55  $',0,'$'


SINGLE_ERW_INT		equ	1	; Prevents two IRQs per ERX frame.
ERX_BLOCK_SIZE		equ	64


IFNDEF  EZSTART
include	ETH_RTNS.INC
ENDIF

include	bicnic.inc
include	LMSTRUCT.INC
include	GETCNFG.INC
include	ezstart.inc

pAS	equ	ds:[bp]
pDS	equ	es:[si]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Service_Events	Interrupt event handling routine.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Service_Events

			push	bx
			push	cx
			push	dx
			push	di
			push	si
			push	ds
			push	es
			pushf

CheckNextInt:		mov	dx, pAS.io_base
			add	dx, REG_ISR	 ; Get interrupt status
			in	al, dx
			or	al, al
			jnz	StartIntCheck
			jmp	NotNICInterrupt ; If no NIC int, check hw int

StartIntCheck:		mov	pAS.servicing_ints, 1

			test	al, ISR_OVW		; Is ring overflowing?
			jz	CheckPktRec		; If not, check packet received
			jmp	HandleOVW

CheckPktRec:		test	al, ISR_PRX		; Was packet received?
			jz	CheckRxErr		; If not, check receive error
			jmp	HandlePRX

CheckRxErr:		test	al, ISR_RXE		; Is there a receive error?
			jz	CheckErlyRec		; If not, check early Rx.
			jmp	HandleRXE

CheckErlyRec:		test	al, ISR_ERW		; Packet in process?
			jz	CheckPTX		; If not, check pkt transmitted
			jmp	HandleERW

CheckPTX:		test	al, ISR_PTX		; Was packet xmitted?
			jz	CheckTxErr		; If not, check ring overflow
			jmp	HandlePTX

CheckTxErr:		test	al, ISR_TXE		; Is there a transmit error?
			jz	CheckCntrs 		; If not, update counters.
			jmp	HandleTXE 	

CheckCntrs:		test	al, ISR_CNT
			jnz	DoCounters
			jmp	NotNICInterrupt		; If no NIC int, check hw int

DoCounters:		mov	al, ISR_CNT
			out	dx, al
			call	UpdateCounters
			jmp	CheckNextInt
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Handle Early Receive Event ;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifndef	EZSTART
PUBLIC	HandleERW
endif
HandleERW:
			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jnz	ChkErxDisabled			; JIF yes

			mov	es, word ptr pAS.ram_access.2

ChkErxDisabled:
			test	pAS.adapter_flags, ERX_DISABLED
			jz	SetNextERWint
			mov	al, ISR_ERW
			out	dx, al			; If ERX is disabled, clear int
			jmp	CheckNextInt		; and bail.

SetNextERWint:
			mov	ah, pAS.local_nxtpkt_ptr
			xor	al, al
			mov	si, ax			; Get ptr to frame.

ifndef	SINGLE_ERW_INT
			test	pAS.adapter_flags, EARLY_RX_FRAME
			jz	GetDataFromFrame
			mov	bh, pAS.erx_addr_type	; Get Address type from first call.
			mov	cx, pAS.erx_size		; Get size from first call.
			jmp	FrameReady
GetDataFromFrame:
endif

			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_FrameInfo			; JIF not

			mov	dx, pAS.io_base
			add	dx, REG_IOPA
			lea	ax, [si].EthDestAdd
			out	dx, al
			mov	al, ah
			out	dx, al			; Set IO pipe address.
			add	dx, REG_IOPD - REG_IOPA
			in	al, dx
			mov	bh, al			; Get MS byte of dest address.
			lea	ax, [si].Eth8023Size
			add	dx, REG_IOPA - REG_IOPD
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			in	ax, dx

			xchg	ah, al
			mov	cx, ax		; Get Ether 802.3 size from header

	      		jmp	CheckFrameSize	; End of I/O section

MM_FrameInfo:
			pushf				; Save flags
ifndef	NC
			cli				; Disable ints
endif

			call	AccessSharedRam

			mov	cx, es:[si].Eth8023Size	; Get size of frame.
			xchg	cl, ch			; Put in Intel format . . .
			mov	bh, es:[si].EthDestAdd	; Check this frame for MC or BC
			
			call	DeAccessSharedRam

			$POPFF				; Restore flags.

CheckFrameSize:
			cmp	cx, MAX_8023_SIZE
			jna	ValidRxSize		; If size is > MAX_8023_SIZE,
							; wait for PRX if UMAC needs
							; packet size.
			test	pAS.receive_mask, PKT_SIZE_NOT_NEEDED
			jz	BailOnThisFrame
			mov	cx, CRC_SIZE		; This will be subtracted so CX will =
			jmp	FrameSizeOk		; zero on call to UM_Receive_Packet
BailOnThisFrame:
			mov	dx, pAS.io_base	; UMAC needs size, and since we can't
			add	dx, REG_ISR		; determine size, we bail on early rcv.
			mov	al, ISR_ERW
			out	dx, al
			jmp	CheckNextInt
ValidRxSize:
			add	cx, 18			; Add 802.3 header size + CRC
			cmp	cx, 64
			jae	FrameSizeOk
			mov	cx, 64			; Pad up short frames.
FrameSizeOk:
			mov	dx, pAS.io_base
			add	dx, REG_ISR
			mov	al, ISR_ERW
			out	dx, al

			in	al, dx

			test	al, ISR_PRX
			jz	CheckRXE
			jmp	HandlePRX	; If PRX int occurred, process as normal PRX.

CheckRXE:		test	al, ISR_RXE
			jz	ContinueERW
			jmp	HandleRXE	; If RXE int occurred, process as normal RXE.
ContinueERW:
			test	bh, 1			; Check MSB of dest addr for br/mu/cast.
			jz	PassItUpstairs
			test	pAS.receive_mask, ACCEPT_MULTI_PROM
			jnz	PassItUpstairs	; If Promiscuous multicast
			push	ax		; mode, skip address check.
ifdef   LARGE
			call	FAR PTR CheckMultiAdd
else
			call	CheckMultiAdd
endif
			cmp	ax, SUCCESS
			pop	ax
			je	PassItUpstairs
			jmp	CheckNextInt
PassItUpstairs:
			or	pAS.adapter_flags, EARLY_RX_FRAME
ifndef	SINGLE_ERW_INT
			cmp	cx, 64
			jb	FrameReady

			mov	pAS.erx_addr_type, bh	; Save address type for next interrupt.
			mov	pAS.erx_size, cx		; Save size for next interrupt.

			mov	dx, pAS.io_base
			add	dx, REG_ISR
			mov	al, ISR_ERW
			out	dx, al
			mov	ax, cx			; Get packet size into AX.

			shr	ax, 1			; Multiply by 0.5 by shifting right.

			add	ax, 15			; Round up value and align for NIC's ERWCNT register.
			mov	cx, 4
			shr	ax, cl

			add	dx, REG_ERWCNT - REG_ISR
			out	dx, al			; Write new threshold
			jmp	CheckNextInt
FrameReady:
endif
			mov	bx, 0
			add	si, NIC_HEADER_SIZE
			sub	cx, CRC_SIZE
			call	UM_Receive_Packet			
			and	pAS.adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
			mov	bx, ax			; Save ret code in BX.

			mov	dx, pAS.io_base
			add	dx, REG_ISR
			in	al, dx

; If no Rx interrupt occurred, the status is not valid.

			test	al, ISR_PRX + ISR_RXE
			jnz	RxComplete
			jmp	RxNotComplete
RxComplete:
			mov	ax, pAS.packet_ptr	; If lo byte of packet_ptr is 0, the value in AH is valid.
			or	al, al
			jz	AlreadyGotValue

			mov	ah, pAS.local_nxtpkt_ptr
			xor	al, al


			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_FrameInfo2			; JIF not

			mov	dx, pAS.io_base
			add	dx, REG_IOPA
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			in	ax, dx
			jmp	AlreadyGotValue	; End of I/O section

MM_FrameInfo2:
			mov	si, ax
			pushf				; Save flags
ifndef	NC
			cli				; Disable ints
endif
			call	AccessSharedRam

			mov	es, pAS.ram_access.sgmt
			mov	ax, es:[si]		; Access word

			call	DeAccessSharedRam

			$POPFF				; Restore flags.

; Update BNRY & next packet pointers . . .
AlreadyGotValue:
			mov	pAS.local_nxtpkt_ptr, ah
			call	UpdateBoundary
SkipBoundUpdate:
			mov	pAS.packet_ptr, 0FFFFh	; Invalidate temp ptr.
			mov	dx, pAS.io_base
			add	dx, REG_ISR
			mov	al, ISR_ERW
			out	dx, al

			cmp	bx, EVENTS_DISABLED
			je	ChuckThisInt
			jmp	CheckNextInt
ChuckThisInt:
			jmp	ServEvDone
RxNotComplete:
			or	pAS.adapter_flags, RX_STATUS_PENDING
			jmp	SkipBoundUpdate

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;---------------------- Handle Packet Received
ifndef	EZSTART
PUBLIC	HandlePRX
endif
HandlePRX:
			mov	dx, pAS.io_base
			add	dx, REG_ERWCNT
			mov	al, DEFAULT_ERX_VALUE
			out	dx, al			; Reset ERX threshold

			and	pAS.adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
;			mov	pAS.packet_ptr, 0FFFFh	; Invalidate temp ptr.
			add	dx, REG_ISR - REG_ERWCNT
			mov	al, ISR_PRX + ISR_ERW	; Clear this int + ERW int (if any)
			out	dx, al
;
; Check the ring to see if it is empty.  The Ring empty bit can be checked
; on 795 XBs (or later.)  The 795 XA RE bit indicated the ring was not empty 
; when a frame was being ERX'ed.
;
			test	pAS.lmac_flags, USE_RE_BIT	; 795?
			jz	No_795_RE_Bit			; JIF not

			add	dx, REG_UBRCV - REG_ISR
			in	al, dx
			test	al, UBRCV_RE
			jz	Check_IO_Mode
			jmp	ReceiveDone

Check_IO_Mode:		
			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jz	EmptyTheRing			; JIF not
			jmp	GetFrameInfo

No_795_RE_Bit:
			add	dx, REG_BNRY - REG_ISR
			in	al, dx
			mov	bl, al
			add	dx, REG_CMD - REG_BNRY

RingCheck:
			pushf
ifndef	NC
			cli
endif
			mov	al, CMD_PAGE1		
			out	dx, al
			jmp	$+2			; Select page 1

			add	dx, REG_CURR - REG_CMD
			in	al, dx			; Get Curr page ptr
			mov	ah, al			; AH == CURR

			add	dx, REG_CMD - REG_CURR
			mov	al, CMD_PAGE0
			out	dx, al
			inc	bl			; BL == BNRY+1
			$POPFF

			cmp	pAS.pstop_hold, bl
			jne	not_at_end_of_buf
			mov	bl, pAS.pstart_hold
not_at_end_of_buf:
			cmp	bl, ah			; If BNRY+1 == CURR,
			jne	EmptyTheRing		; ring is empty
			jmp	ReceiveDone
EmptyTheRing:
			pushf				; Save flags
ifndef	NC
			cli				; Disable ints
endif
			mov	es, word ptr pAS.ram_access.2

			call	AccessSharedRam

GetFrameInfo:
			mov	ah, pAS.local_nxtpkt_ptr
			xor	al, al
			mov	si, ax			; SI == ptr to packet


			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_Pkt_Info			; JIF not

			mov	dx, pAS.io_base
			add	dx, REG_IOPA
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			in	ax, dx

			mov	bx, ax
			in	ax, dx
			mov	cx, ax

;;; New fix for 790 (NOT 795XA) multicast bug... 
;ifdef	MC_FIX
			in	ax, dx
			mov	di, ax			; Get MSB of dest. addr. to qualify address later.
;endif
			jmp	GotPktInfo

MM_Pkt_Info:
			mov	cx, es:[si+2]		; Get packet length
			mov	bx, es:[si]		; Get rx stat in BL, nxtpkt in BH.

;;; New fix for 790 (NOT 795XA) multicast bug... 
;ifdef	MC_FIX
			mov	di, es:[si+4]		; Get MSB of dest. addr. to qualify address later.
;endif
			call	DeAccessSharedRam

			$POPFF				; Restore flags.

GotPktInfo:
			test	pAS.adapter_flags, RX_STATUS_PENDING
			jz	ContinuePRX02
			mov	ax, SUCCESS
			and	pAS.adapter_flags, not RX_STATUS_PENDING
			jmp	DumpPacket

ContinuePRX02:

			test	bl, RSR_PRX
			jnz	GoodFrame
			test	pAS.receive_mask, ACCEPT_ERR_PACKETS
			jz	DumpPacket

GoodFrame:
ifndef  ADD_CHK
        		test	bl, RSR_PHY
			jz	PhysicalFrame
endif

;;; New fix for 790 (NOT 795XA) multicast bug... 
;ifdef	MC_FIX
PUBLIC  MulticastCheck
MulticastCheck:
			test	di, 0001h
                        jz      NotMultiBroad
;			jz	PhysicalFrame
;endif

			test	pAS.receive_mask, ACCEPT_MULTI_PROM
			jnz	PhysicalFrame	; If Promiscuous multicast
ifdef LARGE					; mode, skip address check.
			call	FAR PTR CheckMultiAdd
else
			call	CheckMultiAdd
endif
			cmp	ax, SUCCESS
			jne	DumpPacket

;---------------------- Process packet
PhysicalFrame:
			add	si, NIC_HEADER_SIZE
			sub	cx, CRC_SIZE
			call	UM_Receive_Packet
DumpPacket:
			mov	pAS.local_nxtpkt_ptr, bh
			call	UpdateBoundary		; This call preserves AX.
			mov	pAS.packet_ptr, 0FFFFh	; Invalidate temp ptr.

			cmp	ax, EVENTS_DISABLED	; This ret code set
							; only by
			jne	CheckRing		; UM_Receive_Packet.
			jmp	ServEvDone

CheckRing:		jmp	HandlePRX

;;; New fix for 790 (NOT 795XA) multicast bug... 
NotMultiBroad:
                        pushf
                        push    es
                        push    di
                        push    si
                        push    cx
ifndef  NC
                        cli
endif

                        mov     ax, di
                        mov     word ptr pAS.temp_addr, ax    ; Save MSB of dest addr on stack...

			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
                        jz      ReadDestAddrFromShMem
                        in      ax, dx
                        mov     word ptr pAS.temp_addr.2, ax     ; Save next word of dest addr...
                        in      ax, dx
                        mov     word ptr pAS.temp_addr.4, ax      ; Save lo word of dest addr...
                        jmp     GotDestAddrOnStack                        

ReadDestAddrFromShMem:
                        call    AccessSharedRam
                        mov     ax, es:[si+6]
                        mov     word ptr pAS.temp_addr.2, ax     ; Save next word of dest addr...
                        mov     ax, es:[si+8]
                        mov     word ptr pAS.temp_addr.4, ax      ; Save lo word of dest addr...
                        call    DeAccessSharedRam
GotDestAddrOnStack:

                        cld
                        push    ds
                        pop     es
                        lea     di, pAS.temp_addr
                        mov     cx, 3
                        lea     si, pAS.node_address
                        rep     cmpsw

                        pop     cx      ; Restore regs ....
                        pop     si
                        pop     di
                        pop     es
                        jz      MyPhysicalFrame

                        $POPFF
                        jmp     DumpPacket

MyPhysicalFrame:
                        $POPFF
                        jmp     PhysicalFrame

;;; End new fix for 790 multicast bug...


ifndef	EZSTART
PUBLIC	ReceiveDone
endif
ReceiveDone:
			cmp	pAS.ring_ovw, 1
			jnz	NearCheckNextInt

			mov	dx, pAS.io_base
			add	dx, REG_ISR
			mov	al, ISR_OVW+ISR_ERW
			out	dx, al
			mov	pAS.ring_ovw, 0

			test	pAS.extra_info, NIC_690_BIT + NIC_790_BIT
			jnz	OVW_690
			mov	dx, pAS.io_base
			add	dx, REG_TCR
			mov	al, 0			; Take NIC out of
			out	dx, al			; loopback by writing
			add	dx, REG_CMD - REG_TCR		; 0 to TCR
			mov	al, CMD_STA
			or	al, pAS.ovw_tx_pending
			out	dx, al
			jmp	NearCheckNextInt

OVW_690:		mov	dx, pAS.io_base
			add	dx, REG_BNRY		; Read then write BNRY
			in	al, dx			; if there was OVW.
			jmp	$+2
			jmp	$+2
			out	dx, al

NearCheckNextInt:	jmp	CheckNextInt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Handle Transmit Error
HandleTXE:
			mov	al, ISR_TXE
			out	dx, al
			add	dx, REG_TSR - REG_ISR
			in	al, dx		; Get transmit status 
			test	al, TSR_ABT	 ; Check max collisions
			jz	CheckUnderrun	; 
			mov	ax, MAX_COLLISIONS ; UM_Send_Complete status


;---------------------- Update MAX_COLLISIONS counter

			push	es
			les	bx, dword ptr pAS.ptr_tx_max_collisions
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
			pop	es
			jmp	CheckTxRetry

;---------------------- Check FIFO underrun
CheckUnderrun:		test	al, TSR_FU
			jz	CheckTxRetry
			mov	ax, FIFO_UNDERRUN

;---------------------- Update FIFO_UNDERRUN counter

			push	es
			les	bx, dword ptr pAS.ptr_tx_underruns
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
			pop	es
			cmp	pAS.xmit_threshold, 1536
			jae	CheckTxRetry
			add	pAS.xmit_threshold, 8
CheckTxRetry:
			dec	pAS.tx_retry
			jz	ResetTxRetryCount
			call	SendPacket
			jmp	CheckNextInt
ResetTxRetryCount:
			mov	pAS.tx_retry, DEFAULT_TX_RETRIES
			jmp	TransmitErrorDone

;---------------------- Handle Successful Packet Transmit
HandlePTX:
			mov	pAS.tx_retry, DEFAULT_TX_RETRIES
			push	es
			mov	al, ISR_PTX	 ; Write ISR
			out	dx, al

			add	dx, REG_TSR - REG_ISR
			in	al, dx

			test	pAS.extra_info, NIC_690_BIT + NIC_790_BIT
			jz	SkipDeferringCnt

			test	al, TSR_NDT
			jnz	SkipDeferringCnt

			push	bx
			les	bx, dword ptr pAS.ptr_tx_deferred
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
			pop	bx
SkipDeferringCnt:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			test	al, TSR_COL
ifdef	EZSTART
			jnz	GetCollisionCount
			push	ax
			mov	al, 0
			call	UpdateCollisionTable
			pop	ax
			jmp	CheckCRS
else
			jz	CheckCRS
endif
GetCollisionCount:
			add	dx, REG_NCR - REG_TSR
			push	ax
			xor	ax, ax
			in	al, dx
ifdef	EZSTART
			call	UpdateCollisionTable
endif
;;;;;;;;;;;;;;;;;;;;;;;;
			les	bx, dword ptr pAS.ptr_tx_total_collisions
			add	word ptr es:[bx], ax
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
			cmp	al, 1
			pop	ax

			jg	IncMultCollisions	
			les	bx, dword ptr pAS.ptr_tx_one_collision
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
			jmp	CheckCRS
IncMultCollisions:
			les	bx, dword ptr pAS.ptr_tx_mult_collisions
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
CheckCRS:
			test	al, TSR_CRS
			jz	CheckOWC
			les	bx, dword ptr pAS.ptr_tx_carrier_lost
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
CheckCDH:
			test	al, TSR_CDH
			jz	CheckOWC
			les	bx, dword ptr pAS.ptr_tx_CD_heartbeat
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
CheckOWC:
			test	al, TSR_OWC
			jz	XmitErrorCheckDone
			les	bx, dword ptr pAS.ptr_tx_ow_collision
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
XmitErrorCheckDone:
			pop	es
			mov	ax, SUCCESS	; Set UM_Send_Complete status
;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Call upper MAC layer
ifndef	EZSTART
PUBLIC	TransmitErrorDone
endif
TransmitErrorDone:
			push	ax		; Save status.
			xor	ax, ax
			mov	al, pAS.tx_head
			inc	al
			cmp	al, byte ptr pAS.num_of_tx_buffs
			jne	tx_head_ok
			xor	al, al
tx_head_ok:
			mov	pAS.tx_head, al
			dec	pAS.tx_count
			je	NoXmitsPending

			call	SendPacket
NoXmitsPending:
			pop	ax			; Restore status
			call	UM_Send_Complete
			cmp	ax, EVENTS_DISABLED	; If events dis.,
			jne	PTXCheckNextInt	 ; Stop all processing
							; and return.
			jmp	ServEvDone
PTXCheckNextInt:	jmp	CheckNextInt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Handle Receive Error
HandleRXE:		
			mov	dx, pAS.io_base
			add	dx, REG_ERWCNT
			mov	al, DEFAULT_ERX_VALUE
			out	dx, al			; Reset ERX threshold

			and	pAS.adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
			mov	pAS.packet_ptr, 0FFFFh	; Invalidate temp ptr.

			add	dx, REG_ISR - REG_ERWCNT
			mov	al, ISR_RXE + ISR_ERW	; Clear this int + ERW int (if any)
			out	dx, al

			add	dx, REG_RSR - REG_ISR
			in	al, dx
			test	al, RSR_FO
			jz	UpdateOthers

;---------------------- Update Rx Overrrun Error Counter

			les	di, dword ptr pAS.ptr_rx_overruns
			add	word ptr es:[di], 1
ifndef	COUNTER16
			adc	word ptr es:[di+2], 0
endif
UpdateOthers:
			call	UpdateCounters

RXErrorDone:
			cmp	pAS.nic_type, NIC_790_CHIP	; 790 accepts bad frames for ERX to work, so pass it up.
			je	ProcessAsPRX
			test	pAS.receive_mask, ACCEPT_ERR_PACKETS
			jz	DontGetBadPackets
ProcessAsPRX:
			jmp	HandlePRX
DontGetBadPackets:
			jmp	CheckNextInt

;---------------------- Handle Ring Overwrite
ifndef	EZSTART
PUBLIC	HandleOVW
endif
HandleOVW:
			push	es
			les	bx, dword ptr pAS.ptr_ring_OVW
			add	word ptr es:[bx], 1
ifndef	COUNTER16
			adc	word ptr es:[bx+2], 0
endif
			pop	es
OvwCntrPtrZero:		mov	pAS.ring_ovw, 1


			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_Ring_Ovw			; JIF not

			jmp	HandlePRX

MM_Ring_Ovw:
			test	pAS.extra_info, NIC_690_BIT + NIC_790_BIT
			jz	Handle8390OVW
			jmp	HandlePRX
Handle8390OVW:
			mov	dx, pAS.io_base
			mov	bx, dx			; Save IO addr in BX

			add	dx, REG_CMD
			in	al, dx
			and	al, CMD_TXP 
						; Save any TX pending
			mov	pAS.ovw_tx_pending, al

			mov	al, CMD_STP
			out	dx, al			; Reset the NIC

			mov	dx, bx
			mov	al, 0			;
			add	dx, REG_RBCR0		; Clear RBCR0
			out	dx, al			;
			jmp	$+2
			inc	dx			; Clear RBCR1
ifdef	NEC
			inc	dx
endif
			out	dx, al
			jmp	$+2			;
			mov	dx, bx
			add	dx, REG_ISR
			mov	cx, 1600		; Each iteration of the following
wait_for_timeout:					; loop is 1.0 uS minimum. We
			in	al, dx			; need 1.6 mS delay, so set up
			in	al, dx			; a loop count of 1600.
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			test	al, ISR_RST
			jnz	reset_wait_complete
			loop	wait_for_timeout

reset_wait_complete:					; Check for reset complete
			mov	al, TCR_LB0		; Put NIC in loopback mode
			mov	dx, bx			;	
			add	dx, REG_TCR		; Xmit config. reg
			out	dx, al
			jmp	$+2
			mov	dx, bx
			add	dx, REG_CMD
			mov	al, CMD_STA		; re-start NIC
			out	dx, al
			jmp	$+2

			add	dx, REG_BNRY - REG_CMD
			in	al, dx
			mov	bl, al			; Get Boundary in BL.
			add	dx, REG_CMD - REG_BNRY	; Make DX point to REG_CMD . . .
			jmp	RingCheck		; Check for any received frames.

NotNICInterrupt:
ifndef	NC
			cli
endif
			mov	ax, NOT_MY_INTERRUPT
			cmp	pAS.hdw_int, 0
			jne	IsHardwareInt
			cmp	pAS.servicing_ints, 0
			je	NotMyInt
			mov	pAS.servicing_ints, 0
			jmp	ServEvDone

IsHardwareInt:		mov	pAS.hdw_int, 0
			mov	dx, pAS.int_port
			in	al, dx
			mov	ah, pAS.int_bit
			not	ah
			and	al, ah
			out	dx, al
			call	UM_Interrupt

ServEvDone:
			mov	ax, SUCCESS
NotMyInt:
			$POPFF
			pop	es
			pop	ds
			pop	si
			pop	di
			pop	dx
			pop	cx
			pop	bx
			ret

ASM_ETH_PROC_END	LM_Service_Events


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	*** 795 I/O pipe mode ***
;
;	LM_Receive_Copy Copies data from adapter shared RAM to
;				a Data buffer structure.
;
;	Entry:	CX	== bytes to move
;		BX	== Lookahead flag, 0 = Lookahead copy.
;					   1 = Final copy, poll rx status      [1]	
;					   2 = Final copy, don't poll rx stat. [1]
;		AX	== Offset in shared RAM
;		ES:SI	== Pointer to data buffer structure
;		DS:BP	== Pointer to adapter structure
;
;	Return:	AX	== Return code. HARDWARE_FAILED if early Rx frame had
;			   errors, otherwise SUCCESS.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_ETH_PROC	LM_Receive_Copy
		push	bp			; Save regs
		push	ds
		push	es
		push	si
		push	di
		push	bx
		push	cx
		push	dx

; [1] Reset polling flag
		and	ds:[bp].lmac_flags, not RX_STATUS_POLL
; End [1]

		or	bx, bx
		jz	LookAheadCopy
;;; [1] Init LMAC flag to indicate whether RX status should be polled at end
;;; of copy or not.
		cmp	bx, 2
		je	DontPollRxStatus
		or	ds:[bp].lmac_flags, RX_STATUS_POLL

DontPollRxStatus:
;;; End [1]
		or	pAS.adapter_flags, EARLY_RX_COPY

LookAheadCopy:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	IO_Rcv_Copy			; JIF yes

		call	MM_LM_Receive_Copy	; Memory Mapped version
		jmp	LM_Rcv_Copy_Exit

IO_Rcv_Copy:					; I/O Mapped version

; Save offset of pkt in shared memory.

		mov	bh, pAS.local_nxtpkt_ptr
		mov	bl, NIC_HEADER_SIZE
		add	bx, ax		; Add in offset in AX.

		cmp	bh, pAS.pstop_hold
		jb	PktOffsetOk
		sub	bh, pAS.pstop_hold
		add	bh, pAS.pstart_hold
PktOffsetOk:
		mov	pAS.packet_offset, bx
		mov	dx, pAS.io_base
		add	dx, REG_UBRCV
		in	al, dx
		or	al, UBRCV_WREN
		out	dx, al			; Enable ring wrap logic

		add	dx, REG_IOPA - REG_UBRCV
		mov	ax, bx

		out	dx, al
		mov	al, ah
		out	dx, al			; Set up IO pipe

		pushf
		cld				; Make sure we increment

		mov	dx, pDS.fragment_count	; Get # of frags in DX
		lea	bx, pDS.fragment_list	; ES:BX = 1st frag str.

		xor	ah, ah

		mov	pAS.byte_cnt, cx		; Save total byte cnt.
fragment_loop2:
		cmp	pAS.byte_cnt, 0
		jg	move_more
		jmp	no_more_frags2

move_more:	push	es
		push	bx
		mov	cx, es:[bx].fragment_length
		jcxz	NearZeroLenFrag
		cmp	pAS.byte_cnt, cx
						; Subtract this fragment's
						; count from total count.
		ja	count_ok		; If fragment byte count is >
		mov	cx, pAS.byte_cnt	; remaining byte count (last
						; fragment) use byte count,
						; else use fragment count.
count_ok:
		sub	pAS.byte_cnt, cx
		les	di, es:[bx].fragment_ptr ; ES == far ptr to fragment.

		test	pAS.adapter_flags, EARLY_RX_FRAME
		jnz	EarlyMove
		jmp	StandardMove
NearZeroLenFrag:
		jmp	ZeroLenFrag

EarlyMove:

;;;;; CX = size, ES:DI -> Destination ptr

		push	ax
		push	bx
		push	dx

		mov	dx, pAS.io_base
		add	dx, REG_IOPD		; Add offset so following loop will
						; have the correct offset upon re-entry.
		mov	bx, cx			; Save byte cnt in BX

EarlyStringIoLoop:
		add	dx, REG_ISR - REG_IOPD
		in	al, dx
		add	dx, REG_IOPD - REG_ISR
		test	al, ISR_PRX+ISR_RXE
		jz	MoveNextBlock
		jmp	MoveAllTheRest
MoveNextBlock:
		mov	cx, ERX_BLOCK_SIZE
		cmp	bx, ERX_BLOCK_SIZE
		jae	UseFixedCnt
		mov	cx, bx
UseFixedCnt:
		sub	bx, cx
		push	cx

RepeatErxIoMove:

		shr	cx, 1
		rep	insw

		jnc	NoOddIoByte1
		insb
NoOddIoByte1:

		pop	cx

		add	dx, REG_UBRCV - REG_IOPD
		in	al, dx
		mov	ah, al
		out	dx, al
		add	dx, REG_IOPD - REG_UBRCV
		test	ah, UBRCV_URUN
		jz	MoveNextChunk

; Reset pipe address
		push	cx
		sub	di, cx		; Reset dest addr.
		mov	ax, pAS.packet_offset	; Get last source addr.
		cmp	ah, pAS.pstop_hold
		jb	NewAddrInRange
		sub	ah, pAS.pstop_hold
		add	ah, pAS.pstart_hold
		mov	pAS.packet_offset, ax	; Update source address.
NewAddrInRange:
		add	dx, REG_IOPA - REG_IOPD
		out	dx, al
		mov	al, ah
		out	dx, al
		add	dx, REG_IOPD - REG_IOPA
		jmp	RepeatErxIoMove

MoveNextChunk:
		add	pAS.packet_offset, cx		; Update source address.
		or	bx, bx
		jz	AllErxDataMoved
		jmp	EarlyStringIoLoop
AllErxDataMoved:
		pop	dx
		pop	bx
		pop	ax
		jmp	ZeroLenFrag

MoveAllTheRest:
		mov	cx, bx
		pop	dx
		pop	bx
		pop	ax

StandardMove:
		push	dx
		mov	dx, pAS.io_base
		add	dx, REG_IOPD

		shr	cx, 1
		rep	insw
		jnc	EvenAmount
		insb
EvenAmount:
		pop	dx
ZeroLenFrag:
		pop	bx
		pop	es
		add	bx, size FragmentStructure
		dec	dx			; Decrement fragment count.
		jz	no_more_frags2
		jmp	fragment_loop2
no_more_frags2:
		mov	bx, SUCCESS
		cmp	pAS.byte_cnt, 0
		je	byte_count_ok
		mov	bx, OUT_OF_RESOURCES
byte_count_ok:
		test	pAS.adapter_flags, EARLY_RX_FRAME
		jnz	CheckRxStatus
LM_RxCopyExit:
		and	pAS.adapter_flags, not EARLY_RX_COPY
		mov	dx, pAS.io_base

		$POPFF
M16ENotSetExit:
		mov	dx, pAS.io_base
		add	dx, REG_UBRCV
		in	al, dx
		and	al, not UBRCV_WREN
		out	dx, al			; Disable ring wrap logic

LM_Rcv_Copy_Exit:
		mov	ax, bx			; Get ret code into AX,
		pop	dx			; restore regs.
		pop	cx
		pop	bx
		pop	di
		pop	si
		pop	es
		pop	ds
		pop	bp
		ret
CheckRxStatus:

		mov	dx, pAS.io_base
		add	dx, REG_ISR
		in	al, dx

; If no Rx interrupt occurred, the status is not valid.

		test	al, ISR_PRX + ISR_RXE
		jz	StatusNotAvailable

StatusReEntry:					; [1] Label added
		mov	ah, pAS.local_nxtpkt_ptr
		xor	al, al
		mov	dx, pAS.io_base
		add	dx, REG_IOPA
		out	dx, al
		mov	al, ah
		out	dx, al
		add	dx, REG_IOPD - REG_IOPA
		in	ax, dx

		mov	pAS.packet_ptr, ax		; Save for later.
		and	pAS.packet_ptr, 0FF00h	; Mask off lo byte.

		and	pAS.adapter_flags, not EARLY_RX_FRAME
		and	al, 1Fh
		cmp	al, RSR_PRX
		je	LM_RxCopyExit
		mov	bx, HARDWARE_FAILED
		jmp	LM_RxCopyExit

StatusNotAvailable:
		test	pAS.adapter_flags, EARLY_RX_COPY
		jnz	RxFrameTooBig
		jmp	LM_RxCopyExit		; If this is the lookahead copy, do not indicate
						; a failure. The status is usually not available
						; on the lookahead copy.

; If packet is much larger than indicated in 802.3 header, we could end up here.
RxFrameTooBig:
;;; [1] Change made to support Rx status polling.
		test	ds:[bp].lmac_flags, RX_STATUS_POLL
		jz	RxFailedExit
		mov	cx, 0FFFFh		; Set loop count for Rx status polling
PollForRxStatus:				
		in	al, dx
		test	al, ISR_PRX + ISR_RXE
		jnz	StatusReEntry
		loop	PollForRxStatus

RxFailedExit:
;;; End [1]
		mov	bx, HARDWARE_FAILED
		or	pAS.adapter_flags, RX_STATUS_PENDING
		and	pAS.adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
		jmp	LM_RxCopyExit

ASM_ETH_PROC_END	LM_Receive_Copy


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Memory-mapped mode (690,790, etc.)
;
;	LM_Receive_Copy Copies data from adapter shared RAM to
;				a Data buffer structure.
;
;	Entry:	CX	== bytes to move
;		BX	== Lookahead flag, 0 = Lookahead copy.
;					   1 = Final copy, poll rx status      [1]	
;					   2 = Final copy, don't poll rx stat. [1]
;		AX	== Offset in shared RAM
;		ES:SI	== Pointer to data buffer structure
;		DS:BP	== Pointer to adapter structure
;
;	Return:	AX	== Return code. HARDWARE_FAILED if early Rx frame had
;			   errors, otherwise SUCCESS.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MM_LM_Receive_Copy	proc	near

;
; Save offset of pkt in shared memory.
;

		mov	bh, pAS.local_nxtpkt_ptr
		mov	bl, NIC_HEADER_SIZE
		add	bx, ax		; Add in offset in AX.

		cmp	bh, pAS.pstop_hold
		jb	MM_PktOffsetOk
		sub	bh, pAS.pstop_hold
		add	bh, pAS.pstart_hold
MM_PktOffsetOk:
		mov	pAS.packet_offset, bx

		pushf
ifndef	NC
		cli				; Disable ints
endif
		cld				; Make sure we increment

		call	AccessSharedRam

		mov	dx, es:[si].fragment_count	; Get # of frags in DX
		lea	bx, es:[si].fragment_list	; ES:BX = 1st frag str.

		xor	ah, ah

		mov	pAS.byte_cnt, cx		; Save total byte cnt.
MM_fragment_loop2:
		cmp	pAS.byte_cnt, 0
		jg	MM_Move_More
		jmp	MM_no_more_frags2

MM_Move_More:	push	es
		push	bx
		mov	cx, es:[bx].fragment_length
		jcxz	MM_NearZeroLenFrag
		cmp	pAS.byte_cnt, cx
						; Subtract this fragment's
						; count from total count.
		ja	MM_Count_Ok		; If fragment byte count is >
		mov	cx, pAS.byte_cnt	; remaining byte count (last
						; fragment) use byte count,
						; else use fragment count.
MM_Count_Ok:
		sub	pAS.byte_cnt, cx
		push	ax			; save AX for later
		mov	ah, pAS.pstop_hold
		xor	al, al			; Subtract
		sub	ax, cx			; this count from pstop
						; If current ptr is >=, ring is
						; wrapped.
		cmp	pAS.packet_offset, ax
		jna	no_ring_wrap		;
		mov	pAS.wr_frag_cnt, cx ; save fragment count
		mov	ch, pAS.pstop_hold
		xor	cl, cl
; calculate leftover count
		sub	cx, pAS.packet_offset
		sub	pAS.wr_frag_cnt, cx ; Save for later.
no_ring_wrap:
		pop	ax
		les	di, es:[bx].fragment_ptr ; ES == far ptr to fragment.
continue_copy:

		or	ah, ah
		jz	no_leftover2
		mov	bx, pAS.leftover_data
		mov	byte ptr es:[di], bh

		inc	di
		jcxz	DecWrFragCnt1
		dec	cx	
		jmp	no_leftover2

MM_NearZeroLenFrag:
		jmp	MM_ZeroLenFrag

DecWrFragCnt1:	dec	pAS.wr_frag_cnt
no_leftover2:
		push	si
		push	ds
		mov	si, pAS.packet_offset
		test	si, 1
		jz	EvenPtr

		mov	bx, word ptr pAS.ram_access.2
		mov	ds, bx
		mov	bx, ds:[si-1]
		mov	es:[di], bh
		pop	ds			; Restore DS:BP ptr to adap struc
		push	ds		; Push back on stack
		inc	si
		inc	di
		mov	bx, si
		cmp	bh, pAS.pstop_hold
		jne	PtrOK
		xor	bx, bx
		mov	bh, pAS.pstart_hold
		mov	si, bx
PtrOK:		jcxz	DecWrFragCnt2
		dec	cx		
		jmp	EvenPtr
DecWrFragCnt2:	dec	pAS.wr_frag_cnt
			
ifndef	EZSTART
PUBLIC	EvenPtr
endif
EvenPtr:
		test	pAS.adapter_flags, EARLY_RX_FRAME
		jnz	MM_EarlyMove
		jmp	MM_StandardMove

MM_EarlyMove:

;;;;; CX = size, ES:DI -> Destination ptr, DS:SI -> Source ptr.

		push	ax
		push	bx
		push	dx

PollForMore:
		mov	dx, pAS.io_base
		add	dx, REG_RCNTH
		in	al, dx
RepeatRcnt:
		mov	ah, al
ifdef	NEC
		dec	dx
endif
		dec	dx
		in	al, dx
		mov	bx, ax
		inc	dx
ifdef	NEC
		inc	dx
endif

		in	al, dx
		cmp	ah, al
		jne	RepeatRcnt

		mov	dx, pAS.io_base
		add	dx, REG_ISR
		in	al, dx
		test	al, ISR_PRX+ISR_RXE
		jnz	WeGotThatMany

		mov	ah, pAS.local_nxtpkt_ptr
		mov	al, NIC_HEADER_SIZE
		cmp	si, ax		; AX = Base offset of this frame.
		jae	FrameNoWrappy	; If current ptr is less than packet base ptr,
					; the packet wraps the ring.
		push	bx
		mov	bh, pAS.pstop_hold
		mov	bl, 0
		sub	bx, ax		; BX = number of bytes moved prior to reaching PSTOP.

		mov	ah, pAS.pstart_hold
		mov	al, 0
		sub	ax, si
		neg	ax
		add	ax, bx
		pop	bx
		jmp	FrameWrappyEntry
FrameNoWrappy:
		sub	ax, si
		neg	ax
FrameWrappyEntry:
		add	ax, cx

; AX = Number of bytes into packet that is the end of this copy. (End Copy Target)
; BX = Receive Count so far.

		cmp	bx, ax
		jae	WeGotThatMany

		sub	ax, bx		; Get # of bytes not yet rx'd in AX
		mov	bx, cx		; Get copy of total byte count in BX.
		sub	bx, ax		; Subtract count of bytes not rx'd from total count.
		cmp	bx, ERX_BLOCK_SIZE ; Do not bother to move less than ERX_BLOCK_SIZE bytes.
		jl	PollForMore

		push	cx
		push	ds

		and	bx, 0FFFEh		; Evenize count in BX.

		mov	ds, word ptr pAS.ram_access.2
		mov	cx, bx			; Get count into CX.
		shr	cx, 1

		rep	movsw

		pop	ds
		pop	cx

		sub	cx, bx
;		cmp	cx, 2
;		jle	WeGotThatMany
		jmp	PollForMore
WeGotThatMany:
		pop	dx
		pop	bx
		pop	ax
MM_StandardMove:

		mov	ds, word ptr pAS.ram_access.2
		shr	cx, 1
		jz	short_frag2
		rep	movsw
short_frag2:
		jnc	show_no_leftover2
		mov	bx, word ptr ds:[si]
		inc	si
		inc	si
		mov	byte ptr es:[di], bl
		inc	di
		mov	ah, 0ffh
		jmp	short check_for_more_frags2
show_no_leftover2:
		xor	ah, ah
check_for_more_frags2:
		pop	ds
		mov	pAS.leftover_data, bx
		mov	pAS.packet_offset, si
		pop	si
		cmp	pAS.wr_frag_cnt, 0
		je	ring_not_wrapped
		mov	cx, pAS.wr_frag_cnt ; Get byte count of wrapped
		mov	pAS.wr_frag_cnt, 0	; data starting at pstart and
						; clear wrapped frag count.
		push	ax			; save AX
		mov	ah, pAS.pstart_hold
		xor	al, al			; Get pstart in SI. Pstart_hold
		mov	pAS.packet_offset, ax	; is bits 8-15. 
		pop	ax
		jmp	continue_copy		; Finish copying to this frag.
ring_not_wrapped:
;		mov	pAS.leftover_data, bx
;endif
MM_ZeroLenFrag:
		pop	bx
		pop	es
		add	bx, size FragmentStructure
		dec	dx			; Decrement fragment count.
		jz	MM_no_more_frags2
		jmp	MM_fragment_loop2
MM_no_more_frags2:
		mov	bx, SUCCESS
		cmp	pAS.byte_cnt, 0
		je	MM_Byte_Count_Ok
		mov	bx, OUT_OF_RESOURCES
MM_Byte_Count_Ok:
		test	pAS.adapter_flags, EARLY_RX_FRAME
		jnz	MM_CheckRxStatus

MM_LM_RxCopyExit:
		and	pAS.adapter_flags, not EARLY_RX_COPY
		mov	dx, pAS.io_base

		call	DeAccessSharedRam

		$POPFF
		ret


MM_CheckRxStatus:
		mov	dx, pAS.io_base
		add	dx, REG_ISR
		in	al, dx

; If no Rx interrupt occurred, the status is not valid.

		test	al, ISR_PRX + ISR_RXE
		jz	MM_StatusNotAvailable

MM_StatusReEntry:					; [1] Label added
		mov	ah, pAS.local_nxtpkt_ptr
		xor	al, al
		mov	si, ax
		mov	es, pAS.ram_access.sgmt
		mov	ax, es:[si]		; Access word
; Update BNRY & next packet pointers . . .

		mov	pAS.packet_ptr, ax		; Save for later.
		and	pAS.packet_ptr, 0FF00h	; Mask off lo byte.

		and	pAS.adapter_flags, not EARLY_RX_FRAME
		and	al, 1Fh
		cmp	al, RSR_PRX
		je	MM_LM_RxCopyExit
		mov	bx, HARDWARE_FAILED
		jmp	MM_LM_RxCopyExit

MM_StatusNotAvailable:
		test	pAS.adapter_flags, EARLY_RX_COPY
		jz	MM_LM_RxCopyExit		; If this is the lookahead copy, do not indicate
						; a failure. The status is usually not available
						; on the lookahead copy.

;;; [1] Change made to support Rx status polling.
		test	ds:[bp].lmac_flags, RX_STATUS_POLL
		jz	MM_RxFailedExit
		mov	cx, 0FFFFh		; Set loop count for Rx status polling
MM_PollForRxStatus:				
		in	al, dx
		test	al, ISR_PRX + ISR_RXE
		jnz	MM_StatusReEntry
		loop	MM_PollForRxStatus

MM_RxFailedExit:
;;; End [1]

; If packet is much larger than indicated in 802.3 header, we could end up here.

		mov	bx, HARDWARE_FAILED
		or	pAS.adapter_flags, RX_STATUS_PENDING
		and	pAS.adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
		jmp	MM_LM_RxCopyExit

MM_LM_Receive_Copy	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Close_Adapter	Closes adapter whose adapter structure is
;				indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Close_Adapter

			push	cx
			push	dx
			cmp	pAS.adapter_status, NOT_INITIALIZED
			jne	StatusOK
			mov	ax, ADAPTER_NOT_INITIALIZED
			jmp	NoStatusChange
						
StatusOK: 		mov	dx, pAS.io_base
			add	dx, REG_CMD
			mov	al, CMD_STP
			out	dx, al
			jmp	$+2
			add	dx, REG_ISR - REG_CMD
			mov	cx, 1600		; Each iteration of the following
LM_CA_wait:						; loop is 1.0 uS minimum. We
			in	al, dx			; need 1.6 mS delay, so set up
			in	al, dx			; a loop count of 1600.
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			test	al, ISR_RST
			jnz	LM_CA_NIC_Reset
			loop	LM_CA_wait

LM_CA_NIC_Reset:	mov	pAS.adapter_status, CLOSED
			call	UM_Status_Change
			mov	ax, SUCCESS		; Set return code
NoStatusChange:
			pop	dx
			pop	cx
			ret
ASM_ETH_PROC_END	LM_Close_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Open_Adapter		Opens adapter whose adapter structure is
;				indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Open_Adapter

			push	cx
			push	dx
			cmp	pAS.adapter_status, NOT_INITIALIZED
			jne	CheckStat01
			mov	ax, ADAPTER_NOT_INITIALIZED
			jmp	LM_OADone
CheckStat01:		cmp	pAS.adapter_status, INITIALIZED
				je	OKToOpen
			cmp	pAS.adapter_status, OPEN
			je	AlreadyOpen
DoInit:
IFDEF EZSTART
ifdef LARGE
			call	far ptr ETH_LM_Initialize_Adapter
else
			call	ETH_LM_Initialize_Adapter
endif
ELSE
ifdef LARGE
			call	far ptr LM_Initialize_Adapter
else
			call	LM_Initialize_Adapter
endif
ENDIF
			cmp	ax, SUCCESS
			je	OKToOpen
			mov	ax, OPEN_FAILED
			mov	pAS.adapter_status, FAILED
			jmp	LM_OADone
OKToOpen:		mov	dx, pAS.io_base
			add	dx, REG_CMD
			mov	al, CMD_STA
			out	dx, al
			jmp	$+2
			mov	dx, pAS.io_base
			add	dx, REG_TCR
			mov	al, 0
			mov	cx, pAS.mode_bits
			test	cx, MANUAL_CRC
			jz	OpenAdap01
			mov	al, TCR_CRC
OpenAdap01:		out	dx, al
			jmp	$+2
			mov	pAS.adapter_status, OPEN
			call	UM_Status_Change
AlreadyOpen:		mov	ax, SUCCESS		; Set return code

LM_OADone:		pop	dx
			pop	cx
			ret
ASM_ETH_PROC_END	LM_Open_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Interrupt_Req	Generates a hardware interrupt from the
;				adapter indicated by DS:BP.
;
;	Entry:	DS:BP	Pointer to adapter structure
;
;	Exit:	AX	SUCCESS
;			INVALID_FUNCTION if hardware interrupts are not
;					supported by the adapter.
;			OUT_OF_RESOURCES if adapter has been disabled
;					 by LM_Disable_Adapter.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_ETH_PROC	LM_Interrupt_Req

		push	dx
		pushf
ifndef	NC
		cli			; Disable ints
endif
		test	pAS.adapter_flags, ADAPTER_DISABLED
		jz	LM_Int_Enabled
		jmp	LM_Int_Disabled
LM_Int_Enabled:
		mov	dx, pAS.io_base


		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetIntVals			; JIF yes

		test	word ptr pAS.board_id, MICROCHANNEL
		jz	IntReqNotMCA
		mov	ax, pAS.board_id
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_594_CHIP
		je	Short_Irq_Supported
		jmp	IntReqNotSupported

Short_Irq_Supported:
		add	dx, REG_CR
		mov	pAS.int_port, dx
		mov	pAS.int_bit, CR_SINT
		jmp	IntReqGotParms
IntReqNotMCA:
		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	CheckIntChip
		mov	pAS.int_port, dx
		mov	pAS.int_bit, 01h
		jmp	IntReqGotParms
CheckIntChip:
		mov	ax, pAS.board_id
		test	ax, INTERFACE_CHIP
		jz	IntReqNotSupported
		cmp	pAS.bic_type, BIC_585_CHIP
		jne	IntReq584

SetIntVals:
		add	dx, REG_INTCR
		mov	pAS.int_port, dx
		mov	pAS.int_bit, INTCR_SINT
		jmp	IntReqGotParms

IntReq584:
		add	dx, REG_ICR
		in	al, dx
		jmp	$+2
		and	al, NOT ICR_OTH
		out	dx, al			; Make sure BIO reg is accessed
		add	dx, REG_BIO-REG_ICR
		mov	pAS.int_port, dx
		mov	pAS.int_bit, 01h

IntReqGotParms:
		in	al, dx
		or	al, pAS.int_bit
		mov	pAS.hdw_int, 1
		out	dx, al
		mov	ax, SUCCESS
		jmp	IntReqDone

LM_Int_Disabled:
		mov	ax, OUT_OF_RESOURCES
		jmp	IntReqDone

IntReqNotSupported:
		mov	pAS.int_bit, 0
		mov	pAS.int_port, 0
		mov	pAS.hdw_int, 0
		mov	ax, INVALID_FUNCTION

IntReqDone:	
		$POPFF
		pop	dx
		ret
ASM_ETH_PROC_END	LM_Interrupt_Req


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	UpdateCounters	Updates error counters to reflect current
;				NIC stats.
;
;	Entry:	DS:BP	Pointer to Adapter Structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateCounters	proc	near
		push	dx
		push	es
		push	bx

		xor	ax, ax
		mov	dx, pAS.io_base

		add	dx, REG_CNTR0		; CNTR0 = Frame Align Errors
		in	al, dx
		les	bx, dword ptr pAS.ptr_rx_align_errors
		add	es:[bx], ax
ifndef	COUNTER16
		adc	word ptr es:[bx+2], 0
endif

		inc	dx			; REG_CNTR0+1= REG_CNTR1
ifdef	NEC
		inc	dx
endif
		in	al, dx			; CNTR1 = CRC Errors
		les	bx, dword ptr pAS.ptr_rx_CRC_errors
		add	es:[bx], ax
ifndef	COUNTER16
		adc	word ptr es:[bx+2], 0
endif

		inc	dx			; REG_CNTR1+1= REG_CNTR2
ifdef	NEC
		inc	dx
endif
		in	al, dx			; CNTR2 = Missed Pkt Errors
		les	bx, dword ptr pAS.ptr_rx_lost_pkts
		add	es:[bx], ax
ifndef	COUNTER16
		adc	word ptr es:[bx+2], 0
endif

		mov	ax, SUCCESS

		pop	bx
		pop	es
		pop	dx
		ret
UpdateCounters	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	load_node_address	Loads node address into adapter structure
;				indicated by DS:BP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifndef	EZSTART
PUBLIC	load_node_address
endif
load_node_address	proc	near	

			push	cx
			push	dx
			push	bp
			push	di
			push	si
			pushf
ifndef	NC
			cli
endif
			mov	al, 0
			mov	cx, 6
			add	bp, 6
LoadNodeLoop:		dec	bp
			or	al, pAS.node_address
			loop	LoadNodeLoop
			mov	cx, 6
			mov	dx, pAS.io_base
			add	dx, REG_LAR0
			or	al, al
			jz	GetNodeAddFromBIC

			mov	dx, pAS.io_base
			add	dx, REG_CMD
			mov	al, CMD_STP+CMD_PAGE1
			out	dx, al
			add	dx, REG_PAR0 - REG_CMD						
			push	bp
NodeAddrToNIC:
			mov	al, pAS.node_address
			out	dx, al
			inc	dx
ifdef	NEC
			inc	dx
endif
			inc	bp
			loop	NodeAddrToNIC
			pop	bp

			mov	dx, pAS.io_base
			add	dx, REG_CMD
			mov	al, CMD_STP+CMD_PAGE0
			out	dx, al
			jmp	NodeAddDone
GetNodeAddFromBIC:
			in	al, dx
			mov	pAS.node_address, al
			inc	dx 
ifdef	NEC
			inc	dx
endif
			inc	bp
			loop	GetNodeAddFromBIC
NodeAddDone:
			$POPFF
			pop	si
			pop	di
			pop	bp
			pop	dx
			pop	cx
			mov	ax, SUCCESS
			ret
load_node_address	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	enable_59x_irq enables IRQ on 59x-based adapter whose adapter structure
;	is indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_59x_irq	proc	near
			push	dx
			mov	dx, pAS.io_base
			add	dx, REG_CR
			in	al, dx
			jmp	$+2
			or	al, CR_EIL
			out	dx, al
			mov	pAS.laar_enter, al
			mov	pAS.laar_exit, al
			jmp	$+2
			mov	ax, SUCCESS
			pop	dx
			ret
enable_59x_irq	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	disable_59x_irq disables IRQ on 59x-based adapter whose adapter structure
;	is indicated by DS:BP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disable_59x_irq proc	near
			push	dx
			mov	dx, pAS.io_base
			add	dx, REG_CR
			in	al, dx
			jmp	$+2
			and	al, NOT CR_EIL
			out	dx, al
			mov	pAS.laar_enter, al
			mov	pAS.laar_exit, al
			jmp	$+2
			mov	ax, SUCCESS
			pop	dx
			ret
disable_59x_irq endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	enable_NIC_irq	Enables irq on 583 or 584-based adapter whose adapter
;			structure is indicated by DS:BP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_NIC_irq	proc	near
		push	dx
		mov	dx, pAS.io_base
		add	dx, REG_CMD
		mov	al, CMD_PAGE0
		out	dx, al		; Select page 0
		jmp	$+2
		add	dx, REG_IMR - REG_CMD
		mov	al, pAS.imr_hold
		out	dx, al
		jmp	$+2
		mov	ax, SUCCESS			; return SUCCESS
		pop	dx				; Restore regs
		ret

enable_NIC_irq	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	disable_NIC_irq Disables IRQ on 58x-based adapter whose adapter
;			structure is indicated by DS:BP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disable_NIC_irq proc	near
		push	dx
		mov	dx, pAS.io_base
		add	dx, REG_CMD
		mov	al, CMD_PAGE0		 ; Select page 0
		out	dx, al
		jmp	$+2
		add	dx, REG_IMR - REG_CMD
		mov	al, 0
		out	dx, al
		jmp	$+2
		mov	ax, SUCCESS			; return SUCCESS
		pop	dx				; Restore regs
		ret

disable_NIC_irq endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       enable_585_irq enables IRQ on 585-based adapter whose adapter structure
;       is indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_585_irq  proc    near
			push    dx
			mov     dx, pAS.io_base
			add	dx, REG_INTCR
			in	al, dx
			or	al, INTCR_EIL
			out	dx, al
			mov     ax, SUCCESS
			pop     dx
			ret
enable_585_irq  endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       disable_585_irq disables IRQ on 585-based adapter whose adapter structure
;       is indicated by DS:BP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disable_585_irq proc    near
			push    dx
			mov     dx, pAS.io_base
			add	dx, REG_INTCR
			in	al, dx
			and	al, not INTCR_EIL+INTCR_SINT
			out     dx, al
			mov     ax, SUCCESS
			pop     dx
			ret
disable_585_irq endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	init_nic	Initializes NIC on adapter whose adapter
;			structure is indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_nic	proc	near
		push	bx
		push	cx
		push	dx
		push	si			; Save regs used
		pushf

ifndef	NC
		cli
endif

		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	DontSetSleepMode
		mov	dx, pAS.io_base
		in	al, dx
		and	al, 0FCh
		out	dx, al			; Make sure NIC is "sleeping" on PCMCIA adapters.
DontSetSleepMode:
		mov	bx, pAS.io_base	; BX = io_base
		mov	dx, bx
		add	dx, REG_CMD
		mov	al, CMD_STP+CMD_PAGE0
		out	dx, al
		jmp	$+2			; Init CR

		mov	dx, bx
		add	dx, REG_RBCR0
		mov	al, 0
		out	dx, al
		jmp	$+2			; Clear RBCR0, RBCR1

		mov	dx, bx
		add	dx, REG_RBCR1
		out	dx, al
		jmp	$+2

		mov	dx, bx
		add	dx, REG_ISR
		mov	cx, 1600		; Each iteration of the following
init_nic_wait:					; loop is 1.0 uS minimum. We
		in	al, dx			; need 1.6 mS delay, so set up
		in	al, dx			; a loop count of 1600.
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		test	al, ISR_RST
		jnz	init_NIC_Reset
		loop	init_nic_wait
init_NIC_Reset:
		mov	al, DCR_FT1	 ; FIFO threshhold = 8 bytes
		or	al, DCR_LS	 ; Set Normal Oper.
		test	pAS.board_id, MICROCHANNEL
		jnz	SetWordMode
		cmp	pAS.nic_type, NIC_790_CHIP
		jne	CheckSlot
		test	pAS.board_id, BOARD_16BIT
		jnz	SetWordMode
		jmp	SetByteMode

CheckSlot:	
		test	pAS.extra_info, SLOT_16BIT
		jz	SetByteMode	; If 16 bit card or microchannel,

SetWordMode:	
		or	al, DCR_WTS	; Set word transfer select bit

SetByteMode:	
		mov	dx, bx
		add	dx, REG_DCR	; Get io_base + DCR into DX
		out	dx, al		; Write DCR
		jmp	$+2
IFDEF EZSTART
ifdef LARGE
		call	far ptr ETH_LM_Change_Receive_Mask
else
		call	ETH_LM_Change_Receive_Mask
endif
ELSE
ifdef LARGE
		call	far ptr LM_Change_Receive_Mask
else
		call	LM_Change_Receive_Mask
endif
ENDIF
		mov	dx, bx		; Get IO base
		add	dx, REG_TCR
		mov	al, TCR_LB1	; Place in mode 2 loopback.
		out	dx, al
		jmp	$+2
		
		mov	dx, bx
		add	dx, REG_PSTART


		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_GetPstop			; JIF not

		mov	al, 0
		jmp	StorePstartHold

MM_GetPstop:
		mov	al, pAS.tx_pstop

StorePstartHold:
		mov	pAS.pstart_hold, al
		out	dx, al
		jmp	$+2
		

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_ChkRamUsable			; JIF not

		mov	al, pAS.pstop_hold
		jmp	ContInitNic

MM_ChkRamUsable:
		mov	ax, pAS.ram_usable
		shl	al, 1
		shl	al, 1		; Multiply by 4 to get pstop_hold
		or	al, al
		jnz	LessThan64k
		dec	al

LessThan64k:
		mov	pAS.pstop_hold, al

ContInitNic:
		mov	dx, bx
		add	dx, REG_PSTOP
		out	dx, al
		jmp	$+2

		mov	dx, bx			; Boundary = pstart_hold
		add	dx, REG_BNRY
		mov	al, pAS.pstart_hold
		out	dx, al
		jmp	$+2

		mov	dx, bx			; Set ISR
		add	dx, REG_ISR
		mov	al, 0ffh
		out	dx, al
		jmp	$+2
		
		mov	dx, bx			; Set IMR
		add	dx, REG_IMR
		mov	al, pAS.imr_hold
		out	dx, al
		jmp	$+2

		mov	dx, bx			; Select Page 1
		add	dx, REG_CMD
		mov	al, CMD_STP+CMD_PAGE1
		out	dx, al
		jmp	$+2
		
		push	bp		; Load Physical Address regs
		mov	cx, 6
		mov	dx, bx
		add	dx, REG_PAR0

GetNodeAddress:
		mov	al, pAS.node_address
		out	dx, al
		jmp	$+2
		inc	bp
		inc	dx
ifdef	NEC
		inc	dx
endif
		loop	GetNodeAddress
		pop	bp

		mov	al, pAS.pstart_hold
;
; If (795), make CURR = BOUND = local_nxtpkt_ptr.
;
		test	pAS.lmac_flags, USE_RE_BIT	; 795?
		jnz	InitLocalNxtPktPtr		; JIF yes

		inc	al		; Else Bound = local_nxtpkt_ptr+1

InitLocalNxtPktPtr:
		mov	pAS.local_nxtpkt_ptr, al
		mov	dx, bx			; Get io_base
		add	dx, REG_CURR		; Point to CURR reg.
		out	dx, al			; AL = local_nxtpkt_ptr
		jmp	$+2

		mov	dx, bx
		add	dx, REG_CMD
		mov	al, CMD_STP+CMD_PAGE0
		out	dx, al
		jmp	$+2			; Init REG_CMD again
		
		mov	pAS.tx_pend, 0

		$POPFF
		pop	si			; Restore regs used
		pop	dx
		pop	cx
		pop	bx
		mov	ax, SUCCESS
		ret			; Return to caller
init_nic	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	reset_nic	Resets the NIC on the adapter whose adapter structure
;			is indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
reset_nic	proc	near
		push	bx
		push	dx
		mov	dx, pAS.io_base
		add	dx, REG_MSR
		mov	al, 0
		cmp	pAS.board_id, WD8003ETA
		je	SkipIO
		in	al, dx
		jmp	$+2
SkipIO:		mov	bl, al			; Save REG_MSR contents in BL
		or	al, MSR_RST		 ; Set reset bit
		out	dx, al
		jmp	$+2
						; Each iteration of the following
						; loop is 1.0 uS minimum. We
		in	al, dx			; need 1.6 mS delay, so set up
		in	al, dx			; a loop count of 1600.
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx
		in	al, dx

		mov	al, bl			; Get original contents into AL
		and	al, not MSR_RST
		out	dx, al			; Reset reset bit
		jmp	$+2
		pop	dx
		pop	bx
		mov	ax, SUCCESS
		ret
reset_nic	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	enable_ram	enables RAM on adapter whose adapter structure is
;			indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_ram	proc	near
		push	bx
		push	cx
		push	dx
		mov	dx, pAS.io_base

		cmp	pAS.nic_type, NIC_790_CHIP
		jne	SkipDconInit
		add	dx, REG_DCR
		mov	al, DCR_FT1 + DCR_WTS
		out	dx, al
		sub	dx, REG_DCR
SkipDconInit:
		add	dx, REG_MSR
		test	pAS.board_id, MICROCHANNEL+INTERFACE_CHIP
		jnz	NoInit
		mov	cx, 3
		mov	ax, word ptr pAS.ram_base+2
		shl	ax, cl
		mov	bl, al
		mov	ax, word ptr pAS.ram_base
		mov	cx, 13
		shr	ax, cl
		or	al, bl
		jmp	EnableDeRam
NoInit: 
		mov	al, 0
		test	pAS.board_id, INTERFACE_CHIP
		jz	EnableDeRam
		in	al, dx
EnableDeRam:
		or	al, MSR_MENB
		out	dx, al
		jmp	$+2
		in	al, dx
		pop	dx
		pop	cx
		pop	bx
		mov	ax, SUCCESS
		ret
enable_ram	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	disable_ram	disables RAM on adapter whose adapter structure is
;			indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
disable_ram	proc	near
		push	dx
		mov	dx, pAS.io_base
		add	dx, REG_MSR
		mov	al, 0
		test	pAS.board_id, MICROCHANNEL
		jnz	DontReadPort
		in	al, dx
		jmp	$+2

DontReadPort:
		and	al, not MSR_MENB
		out	dx, al
		jmp	$+2
		in	al, dx
		pop	dx
		mov	ax, SUCCESS
		ret
disable_ram		endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	set_MARs	Sets all 8 NIC Multicast Address Registers (REG_MAR0-7)
;			to value in BL. All regs preserved, no return code.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifndef	EZSTART
PUBLIC	set_MARs
endif
set_MARs	proc	near
		push	ax
		push	cx
		push	dx
		mov	dx, pAS.io_base
		add	dx, REG_CMD
		in	al, dx
		jmp	$+2
		and	al, CMD_PS0+CMD_PS1
		mov	bh, al			; Save original page in BH
		mov	al, CMD_PAGE1		; Select page 1
		out	dx, al
		jmp	$+2
		add	dx, REG_MAR0 - REG_CMD
		mov	cx, 8
		mov	al, bl			; Get value to write into AL
SetMARLoop:
		out	dx, al			; Write 8 bytes to MAR0-7
		jmp	$+2
		inc	dx
ifdef	NEC
		inc	dx
endif
		loop	SetMARLoop

		mov	dx, pAS.io_base
		add	dx, REG_CMD			; Restore original page.
		mov	al, bh
		out	dx, al
		jmp	$+2

		pop	dx
		pop	cx
		pop	ax
		ret

set_MARs	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SendPacket	Sends packet of at offset 
;			pAS.tx_buffer in shared memory.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifndef	EZSTART
PUBLIC	SendPacket
endif
SendPacket	proc	near
			push	ax
			push	cx
			push	dx
			push	si

			mov	dx, pAS.io_base

			add	dx, REG_CMD
			in	al, dx
			test	al, CMD_TXP
			jnz	NicPending

			xor	ax, ax			; get tx_buffer offset
			mov	al, pAS.tx_head
			shl	ax, 1
			shl	ax, 1
			mov	si, ax
			mov	cx, word ptr ds:[bp+si].tx_buffer+2
			mov	ax, word ptr ds:[bp+si].tx_buffer				
			mov	al, ah
			add	dx, REG_TPSR - REG_CMD
			out	dx, al
			add	dx, REG_TBCR0 - REG_TPSR
			mov	al, cl			; CX = size; write size
			out	dx, al			; to TBCR0 and TBCR1.
			add	dx, REG_TBCR1 - REG_TBCR0
			mov	al, ch
			out	dx, al
			add	dx, REG_CMD - REG_TBCR1

			mov	al, CMD_STA+CMD_TXP
			out	dx, al			; Send packet.
			clc
SendPacketDone:
			pop	si
			pop	dx
			pop	cx
			pop	ax
			ret

NicPending:		stc
			jmp	SendPacketDone
SendPacket	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	UpdateBoundary	Updates NIC Boundary register
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UpdateBoundary	proc	near
	push	ax			; 1+ 

	mov	al, pAS.local_nxtpkt_ptr	; AL = local_nxtpkt_ptr
;
;	if (USE_RE_BIT)
;	   bound = local next packet ptr;
;	else 
;	   bound = local next packet ptr - 1;
;
	test	pAS.lmac_flags, USE_RE_BIT	; Using RE bit on 795?
	jnz	bnry_ok				; JIF yes, i.e. Don't dec

	dec	al				; --local_nxtpkt_ptr

	cmp	al, pAS.pstart_hold		;
	jnb	bnry_ok				;

	mov	al, pAS.pstop_hold		;
	dec	al				;

bnry_ok:
	mov	dx, pAS.io_base
	add	dx, REG_BNRY
	out	dx, al				; Update boundary register

	pop	ax				; 1-
	ret					; Exit
UpdateBoundary	endp

