;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         ETH_386.ASM
;
; Description:  LMI lower routine assembly source file for all SMC 
;		ISA/MCA Cards.
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lmeth386\vcs\eth_386.avm  $
;  
;     Rev 1.72   08 Sep 1994 15:09:24   WOOD_R
;  
;     Rev 1.71   08 Sep 1994 11:19:36   WOOD_R
;
; LM_8416_s2.1_v2.02
; Bug Fix:	The server driver, set to I/O mapped mode, running under
;		Netware for OS/2 was causing the system to hang at load
;		time.  The function InitAdapter was not clearing the upper
;		part of the ECX register.  Changed the MOV instruction to a
;		MOVZX which fixes the problem.
;
;		QA PTR info:	Project #164	Problem #3
;
;  
;     Rev 1.70   07 Jul 1994 17:28:06   wood_r
;  
;     Rev 1.69   07 Jul 1994 16:44:58   wood_r
;  
;     Rev 1.68   07 Jul 1994 14:24:24   wood_r
;
; LM_8416_s2.1_v2.01
; Change:	Added the Auto Media Detect feature to the ETH_COM.ASM
;		area of the code.  The routine LM_Initializr_Adapter is
;		used as the control shell for the feature.
;
;  
;     Rev 1.67   12 May 1994 14:50:08   wood_r
;  Dual Mode Driver
;
; LM_8416_s2.1_v2.00b
;
; Change:	This revision of the file will be the start of the next
;		generation of the Ethernet LMACs.  The version level will
;		be bumped from 1.xxx to 2.xxx.  The 1.xxx source code 
;		history was designed and developed by Mike Steiger.
;
;		This version level will support "Dual Mode" (I/O and MMIO)
;		for the 8416 (795 chip). This is implemented by using a 
;		flag bit in the adapter structure variable "adapter_flags".
;		The equate used for this is IO_MAPPED.  This variable is
;		also available to the UMAC to query the type of driver.
;		
;		The Ring Empty feature on the 795 was added to the code
;		base.  To implement this feature, a flag bit is used in the
;		adapter structure variable "lmac_flags".  The equate used
;		with this flag is USE_RE_BIT.  It is used in the functions:
;		LM_Service_Events, Init_Nic, and UpdateBoundary.
;
;		Added the Keyword "Revision" to the GetVER Revision string.
;		This will alleviate having to update it everytime the file
;		is checked into PVCS.
;
;
; Change:	Changes from previous 1.xxx code base.
;
; Revision History (Implemented in v1.65)
;
; Ref #		Date		Who
; [1]		03/15/94	M. Steiger
; 
; Description:
;	Added capability of LM_Receive_Copy to poll for RX status on early
;	RX frames. The UMAC now indicates the copy mode in EBX:
;
;		0 = lookahead copy (no rx status check)
;		1 = final copy. RX status is polled if not immediately
;		    available. If no RX status is available after FFFFh
;		    polls, HARDWARE_FAILED is returned.
;		2 = final copy. If no RX status is available after copy is
;		    complete, LM_Receive_Copy returns HARDWARE_FAILED. This
;		    method is used in previous versions of this source file
;		    when BX != 0.
;
; Ref #		Date		Who
; [2]		03/31/94	M. Steiger
;
; Description:
;    1.	Changed test of servicing_ints flag at top of LM_Service_Events to
;	jump to NotMyInt instead of ServEvDone. Moved line that clears
;	servicing_ints flag from just above IsHardwareInt to just below
;	ServEvDone. This ensures that the servicing_ints flag gets cleared
;	upon exit from LM_Service_Events except when LM_Service_Events is
;	re-entered. The fix was not in response to a reported problem, it
;	was noticed as part of troubleshooting the problem listed in the
;	next paragraph. The only case in which it would have been a problem
;	is if the UMAC returned EVENTS_DISABLED, which the NetWare UMAC
;	never does.
;
;    2. Changed LM_Send so that it does not enable the interrupt line on
;	790's if the adapter was disabled by LM_Disable_Adapter. This is
;	accomplished by checking the state of adapter_flags bit
;	ADAPTER_DISABLED, which is set by LM_Disable_Adapter and
;	cleared by LM_Enable_Adapter. The NetWare UMAC sometimes calls
;	LM_Send before LM_Service_Events has returned. This was causing
;	LM_Service_Events to be reentered. The UMAC driver ISR calls
;	LM_Disable_Adapter before calling LM_Service_Events, and calls
;	LM_Enable_Adapter when LM_Service_Events returns. Since the first
;	call to LM_Service_Events had not returned, the second call to
;	LM_Service_Events returned directly back to the UMAC. The UMAC
;	then calls LM_Enable_Adapter, which generates an interrupt.
;	This endless loop continues and never allows the original
;	LM_Service_Events call to complete. Preventing LM_Send from
;	enabling the interrupt line when the adapter has been disabled
;	prevents the endless loop from ever getting started.
;
;
;+!/? ***********************************************************************

; Local conditional equates - do not change unless you know what you are doing.

FIXED_SLOPE		equ	1

;;; Version string visible in executable using GETVER.EXE utility ...

db	'@(#) LM_8416_s2.1_v2.02',0,'$'

db	'SMC Ethernet 386 Lower Driver ETH_386.ASM $Revision:   1.72  $',0,'$'

ERX_BLOCK_SIZE		equ	64



;****************************************************************************
;
; Function:	LM_Service_Events
;
; Synopis:	Interrupt event handling routine.
;
; Input:	None
;
; Output:	None
;
; Modified:	None
;
; Notes:	None
;
;****************************************************************************

PUBLIC	LM_Service_Events
ifdef	LARGE
LM_Service_Events	proc	far
else
LM_Service_Events	proc	near	
endif
			push	ebx
			push	ecx
			push	edx
			push	edi
			push	esi
			pushfd

			test	[ebp].servicing_ints, 0FFh
			jz	CheckNextInt
			jmp	NotMyInt	; [2] Changed. Used jump to 'ServEvDone'

CheckNextInt:		mov	dx, [ebp].io_base
			add	dx, REG_ISR	 ; Get interrupt status
			in	al, dx
			or	al, al
			jnz	StartIntCheck
			jmp	NotNICInterrupt ; If no NIC int, check hw int

StartIntCheck:		mov	[ebp].servicing_ints, 1

CheckPTX:		test	al, ISR_PTX		; Was packet xmitted?
			jz	CheckTxErr		; If not, check Tx error
			jmp	HandlePTX

CheckTxErr:		test	al, ISR_TXE		; Is there a transmit error?
			jz	CheckRxOvw		; If not, check Rx overwrite
			jmp	HandleTXE 	

CheckRxOvw:		test	al, ISR_OVW		; Is ring overflowing?
			jz	CheckPktRec		; If not, check packet received
			jmp	HandleOVW

CheckPktRec:		test	al, ISR_PRX		; Was packet received?
			jz	CheckRxErr		; If not, check receive error
			jmp	HandlePRX

CheckRxErr:		test	al, ISR_RXE		; Is there a receive error?
			jz	CheckErlyRec		; If not, check early Rx.
			jmp	HandleRXE

CheckErlyRec:		test	al, ISR_ERW		; Packet in process?
			jz	CheckCntrs		; If not, check counter overflow.
			jmp	HandleERW

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
PUBLIC	HandleERW
HandleERW:
;
;	First check for the SECOND early receive interrupt.  If it is, then
;	process the rest of the frame.
;
			test	[ebp].adapter_flags, EARLY_RX_FRAME
			jz	CheckErxState
			jmp	FrameReady

CheckErxState:
			test	[ebp].adapter_flags, ERX_DISABLED
			jz	SetNextERWint

ErxDisabled:
			mov	al, ISR_ERW
			out	dx, al
			jmp	CheckNextInt

SetNextERWint:
			xor	eax, eax
			mov	ah, [ebp].local_nxtpkt_ptr
			mov	esi, [ebp].ram_access
			add	esi, eax		; Get ptr to frame.
;
;	Check for I/O or Memory Mapped driver
;
			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_FrameInfo			; JIF not

			mov	dx, [ebp].io_base
			add	dx, REG_IOPA
			lea	eax, [esi].EthDestAdd
			out	dx, al
			mov	al, ah
			out	dx, al			; Set IO pipe address

			add	dx, REG_IOPD - REG_IOPA
			in	al, dx
			mov	bh, al			; Get MS byte of dest address.
			lea	eax, [esi].Eth8023Size
			add	dx, REG_IOPA - REG_IOPD
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			in	ax, dx

			xchg	ah, al
			movzx	ecx, ax		; Get Ether 802.3 size from header

			jmp	CheckFrameSize	; End of I/O section
		       
MM_FrameInfo:
ifndef	NT_CODE
			pushf				; Save flags
			cli				; Disable ints
endif

			call	AccessSharedRam
			movzx	ecx, [esi].Eth8023Size	; Get size of frame.
			xchg	cl, ch			; Put in Intel format . . .
			mov	bh, [esi].EthDestAdd	; Check this frame for MC or BC

			call	DeAccessSharedRam
ifndef	NT_CODE
			popf				; Restore flags.
endif

CheckFrameSize:
			cmp	cx, MAX_8023_SIZE
			jna	ValidRxSize		; If size is > MAX_8023_SIZE,

			mov	dx, [ebp].io_base	; we can't determine size, so
			add	dx, REG_ISR		; bail on early rcv.
			mov	al, ISR_ERW
			out	dx, al
			jmp	CheckNextInt
ValidRxSize:
			add	cx, 18			; Add 802.3 header size + CRC
			cmp	cx, 64
			jae	FrameSizeOk
			mov	cx, 64			; Pad up short frames.
FrameSizeOk:
			mov	[ebp].erx_frame_size, cx
			mov	[ebp].erx_addr_type, bh
			xor	eax, eax
			mov	ax, cx
			add	ax, 15			; Round up frame size.
ifdef	FIXED_SLOPE
			shr	ax, 2			; Divide frame size by 4.
			sub	cx, ax			; Subtract that difference from the frame size
			mov	ax, cx			; Put result in AX. (AX = frame size * 0.75)
else
			mov	cx, 4			; Divide frame size by 16.
			shr	ax, cl
			mov	bx, [ebp].early_rx_slope
			mul	bx			; Multiply frame size by ERX
			mov	al, ah			; slope value, then divide by 512.
			xor	ah, ah			; Moving AH to AL divides by 256.
			shr	ax, 1			; Shift rt. makes total divisor 512.
			mov	ah, al			; Save new threshold in AH.
endif
			cmp	ah, [ebp].rx_lookahead_size
			jae	NewThresholdOk
			mov	ah, [ebp].rx_lookahead_size
NewThresholdOk:
; Clear any ERW ints before we update the ERW threshold.

			mov	dx, [ebp].io_base
			add	dx, REG_ISR
			mov	al, ISR_ERW
			out	dx, al

			add	dx, REG_ERWCNT - REG_ISR
			mov	al, ah			; Get new threshold
			out	dx, al			; Write new threshold

			mov	dx, [ebp].io_base
			add	dx, REG_ISR
			in	al, dx

			test	al, ISR_PRX
			jz	CheckRXE
			jmp	HandlePRX	; If PRX int occurred, process as normal PRX.

CheckRXE:		test	al, ISR_RXE
			jz	ContinueERW
			jmp	HandleRXE	; If RXE int occurred, process as normal RXE.
ContinueERW:
			or	[ebp].adapter_flags, EARLY_RX_FRAME
			jmp	CheckNextInt

; 2nd ERW int gets us here.

FrameReady:
			mov	ebx, 0
			xor	eax, eax
			mov	ah, [ebp].local_nxtpkt_ptr
			mov	esi, [ebp].ram_access
			add	esi, eax

			test	[ebp].erx_addr_type, 1			; Check MSB of dest addr for br/mu/cast.
			jz	PassItUpstairs
			test	[ebp].receive_mask, ACCEPT_MULTI_PROM
			jnz	PassItUpstairs	; If Promiscuous multicast
			call	CheckMultiAdd	; mode, skip address check.
			cmp	ax, SUCCESS
			jne	DumpThisFrame
PassItUpstairs:
			movzx	ecx, [ebp].erx_frame_size
			sub	ecx, CRC_SIZE
			add	esi, NIC_HEADER_SIZE
			call	UM_Receive_Packet			
			mov	bx, ax

DumpThisFrame:
			mov	dx, [ebp].io_base
			add	dx, REG_ERWCNT
			mov	al, [ebp].rx_lookahead_size
			out	dx, al			; Reset ERX threshold

			add	dx, REG_ISR - REG_ERWCNT
			in	al, dx
			test	al, ISR_PRX + ISR_RXE

;			jz	WaitToUpdatePtrs
;
;;;;;;;;;;;;;;;;;;;;;;;; FIX FOR NOVELL IPXLOAD ROUTER PERFORMANCE 

                        jnz	StatusIsValid

                        mov	al, ISR_ERW     	; Clear any ERW ints
                        out	dx, al
                        mov	dx, [ebp].io_base
                        add	dx, REG_ERWCNT
                        mov	al, 128                 ; set ERWCNT to large size
                        out	dx, al
                        jmp	WaitToUpdatePtrs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    

StatusIsValid:
			mov	al, ISR_ERW		; Clear any ERW ints
			out	dx, al

			xor	eax, eax
			mov	ah, [ebp].local_nxtpkt_ptr
			mov	esi, [ebp].ram_access
			add	esi, eax		; ESI -> packet

			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_FrameInfo2			; JIF not

			mov	dx, [ebp].io_base
			add	dx, REG_IOPA
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			in	ax, dx
ifndef	NT_CODE
			pushf				; Save flags
			cli				; Disable ints
endif
			jmp	AlreadyGotValue	; End of I/O section

MM_FrameInfo2:
ifndef	NT_CODE
			pushf				; Save flags
			cli				; Disable ints
endif
			call	AccessSharedRam
			mov	ax, [esi]		; Get next pkt ptr in BH.
			call	DeAccessSharedRam

AlreadyGotValue:
			mov	[ebp].local_nxtpkt_ptr, ah
			call	UpdateBoundary
ifndef	NT_CODE
			popf
endif

WaitToUpdatePtrs:
			and	[ebp].adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY

			cmp	bx, EVENTS_DISABLED
			je	BailOutDude
			jmp	CheckNextInt
BailOutDude:
			jmp	ServEvDone
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Handle Packet Received
PUBLIC	HandlePRX
HandlePRX:
			and	[ebp].adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
			mov	dx, [ebp].io_base
			add	dx, REG_ERWCNT
			mov	al, [ebp].rx_lookahead_size
			out	dx, al			; Reset ERX threshold

			add	dx, REG_ISR - REG_ERWCNT
			mov	al, ISR_PRX + ISR_ERW	; Clear this int + ERW int (if any)
			out	dx, al
;
; Check the Ring to see if it is empty.  The Ring empty bit can be used
; on 795 chips only.
;
			test	[ebp].lmac_flags, USE_RE_BIT	; 795?
			jz	No_795_RE_Bit			; JIF not

			add	dx, REG_UBRCV - REG_ISR
			in	al, dx
			test	al, UBRCV_RE
			jz	Check_IO_Mode
			jmp	ReceiveDone

Check_IO_Mode:		
			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jz	EmptyTheRing			; JIF not
			jmp	GetFrameInfo

No_795_RE_Bit:

; Check ring to see if it is empty...

			add	dx, REG_BNRY - REG_ISR
			in	al, dx
			mov	bl, al
			add	dx, REG_CMD - REG_BNRY
RingCheck:
			pushf
			cli
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
			popf

			cmp	[ebp].pstop_hold, bl
			jne	not_at_end_of_buf
			mov	bl, [ebp].pstart_hold
not_at_end_of_buf:
			cmp	bl, ah			; If BNRY+1 == CURR,
			jne	EmptyTheRing		; ring is empty
			jmp	ReceiveDone

EmptyTheRing:
GetFrameInfo:
			xor	eax, eax
			mov	ah, [ebp].local_nxtpkt_ptr
			mov	esi, [ebp].ram_access
			add	esi, eax		; ESI -> packet


			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_Pkt_Info			; JIF not

			mov	dx, [ebp].io_base
			add	dx, REG_IOPA
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			in	ax, dx

			mov	bx, ax
			in	ax, dx
			movzx	ecx, ax

			jmp	GotPktInfo

MM_Pkt_Info:
ifndef	NT_CODE
			pushf				; Save flags
			cli				; Disable ints
endif
			call	AccessSharedRam

			movzx	ecx, word ptr [esi+2]	; Get packet length
			mov	bx, [esi]		; Get rx stat in BL,
							; next pkt in BH.

			call	DeAccessSharedRam
ifndef	NT_CODE
			popf				; Restore flags.
endif
GotPktInfo:
			mov	dx, [ebp].io_base	

;;;			test	[ebp].adapter_flags, RX_STATUS_PENDING
;;;			jz	ContinuePRX02
;;;			mov	eax, SUCCESS
;;;			and	[ebp].adapter_flags, not RX_STATUS_PENDING
;;;			jmp	DumpPacket
;;;ContinuePRX02:

			test	bl, RSR_PRX
			jnz	GoodFrame
			test	[ebp].receive_mask, ACCEPT_ERR_PACKETS
			jz	DumpPacket

GoodFrame:		test	bl, RSR_PHY
			jz	PhysicalFrame
			test	[ebp].receive_mask, ACCEPT_MULTI_PROM
			jnz	PhysicalFrame	; If Promiscuous multicast
			call	CheckMultiAdd	; mode, skip address check.
			cmp	ax, SUCCESS
			jne	DumpPacket

;---------------------- Process packet
PhysicalFrame:
			add	esi, NIC_HEADER_SIZE
			sub	ecx, CRC_SIZE
			call	UM_Receive_Packet
DumpPacket:
			mov	[ebp].local_nxtpkt_ptr, bh
			call	UpdateBoundary		; This call preserves AX.

			cmp	ax, EVENTS_DISABLED	; This ret code set
							; only by
			jne	CheckRing		; UM_Receive_Packet.
			jmp	ServEvDone

CheckRing:
			jmp	HandlePRX

PUBLIC	ReceiveDone
ReceiveDone:
			cmp	[ebp].ring_ovw, 1
			jnz	NearCheckNextInt

			mov	dx, [ebp].io_base
			add	dx, REG_ISR
			mov	al, ISR_OVW+ISR_ERW
			out	dx, al
			mov	[ebp].ring_ovw, 0

			test	[ebp].extra_info, NIC_690_BIT + NIC_790_BIT
			jnz	OVW_690
			mov	dx, [ebp].io_base
			add	dx, REG_TCR
			mov	al, 0			; Take NIC out of
			out	dx, al			; loopback by writing
			add	dx, REG_CMD - REG_TCR		; 0 to TCR
			mov	al, CMD_STA
			or	al, [ebp].ovw_tx_pending
			out	dx, al
			jmp	NearCheckNextInt

OVW_690:		mov	dx, [ebp].io_base
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
			mov	eax, MAX_COLLISIONS ; UM_Send_Complete status

;---------------------- Update MAX_COLLISIONS counter

			mov	ebx, [ebp].ptr_tx_max_collisions
			inc	dword ptr [ebx]

;---------------------- Check FIFO underrun
CheckUnderrun:		test	al, TSR_FU
			jz	CheckTxRetry
			mov	eax, FIFO_UNDERRUN

;---------------------- Update FIFO_UNDERRUN counter

			mov	ebx, [ebp].ptr_tx_underruns
			inc	dword ptr [ebx]
;
;	Auto-adjust transmit threshhold if underruns occur.  
;
;;;			cmp	[ebp].xmit_threshold, 384
;;;			jae	CheckTxRetry
;;;			add	[ebp].xmit_threshold, 8

CheckTxRetry:
			dec	[ebp].tx_retry
			jz	ResetTxRetryCount

			call	SendPacket
			jmp	CheckNextInt
ResetTxRetryCount:
			mov	[ebp].tx_retry, DEFAULT_TX_RETRIES
			jmp	TransmitErrorDone

;---------------------- Handle Successful Packet Transmit
PUBLIC	HandlePTX
HandlePTX:
			mov	[ebp].tx_retry, DEFAULT_TX_RETRIES
			mov	al, ISR_PTX	 ; Write ISR
			out	dx, al

			add	dx, REG_TSR - REG_ISR
			in	al, dx

			test	[ebp].extra_info, NIC_690_BIT + NIC_790_BIT
			jz	SkipDeferringCnt

			test	al, TSR_NDT
			jnz	SkipDeferringCnt

			push	ebx
			mov	ebx, [ebp].ptr_tx_deferred
			inc	dword ptr [ebx]
			pop	ebx
			
SkipDeferringCnt:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			test	al, TSR_COL
ifdef	SNAAP
			jnz	GetCollisionCount
			push	eax
			mov	al, 0
			call	UpdateCollisionTable
			pop	eax
			jmp	CheckCRS
else
			jz	CheckCRS
endif
GetCollisionCount:
			push	eax
			add	dx, REG_NCR - REG_TSR
			xor	eax, eax
			in	al, dx
ifdef	SNAAP
			call	UpdateCollisionTable
endif
			mov	ebx, [ebp].ptr_tx_total_collisions
			add	[ebx], eax
			cmp	al, 1
			pop	eax

			jg	IncMultCollisions	
			mov	ebx, [ebp].ptr_tx_one_collision
			inc	dword ptr [ebx]
			jmp	CheckCRS
IncMultCollisions:
			mov	ebx, [ebp].ptr_tx_mult_collisions
			inc	word ptr [ebx]
CheckCRS:
			test	al, TSR_CRS
			jz	CheckOWC
			mov	ebx, [ebp].ptr_tx_carrier_lost
			inc	dword ptr [ebx]
CheckCDH:
			test	al, TSR_CDH
			jz	CheckOWC
			mov	ebx, [ebp].ptr_tx_CD_heartbeat
			inc	dword ptr [ebx]
CheckOWC:
			test	al, TSR_OWC
			jz	XmitErrorCheckDone
			mov	ebx, [ebp].ptr_tx_ow_collision
			inc	dword ptr [ebx]
XmitErrorCheckDone:
			mov	eax, SUCCESS	; Set UM_Send_Complete status

;---------------------- Call upper MAC layer
PUBLIC	TransmitErrorDone
TransmitErrorDone:
			push	eax		; Save status.
			xor	eax, eax
			mov	al, [ebp].tx_head
			inc	al
			cmp	al, byte ptr [ebp].num_of_tx_buffs
			jne	tx_head_ok
			xor	al, al
tx_head_ok:
			mov	[ebp].tx_head, al
			dec	[ebp].tx_count
			je	NoXmitsPending

			call	SendPacket
NoXmitsPending:
			pop	eax			; Restore status
			call	UM_Send_Complete
			cmp	eax, EVENTS_DISABLED	; If events dis.,
			jne	PTXCheckNextInt	 ; Stop all processing
							; and return.
			jmp	ServEvDone
PTXCheckNextInt:	jmp	CheckNextInt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Handle Receive Error
HandleRXE:		
			and	[ebp].adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY
			mov	dx, [ebp].io_base
			add	dx, REG_ERWCNT
			mov	al, [ebp].rx_lookahead_size
			out	dx, al			; Reset ERX threshold

			add	dx, REG_ISR - REG_ERWCNT
			mov	al, ISR_RXE + ISR_ERW	; Clear this int + ERW int (if any)
			out	dx, al

			add	dx, REG_RSR - REG_ISR
			in	al, dx
			test	al, RSR_FO
			jz	UpdateOthers

;---------------------- Update Rx Overrrun Error Counter

			mov	edi, [ebp].ptr_rx_overruns
			inc	dword ptr [edi]
UpdateOthers:
			call	UpdateCounters

RXErrorDone:		test	[ebp].adapter_flags, EARLY_RX_FRAME
			jz	ContinueRXE
			jmp	FrameReady

ContinueRXE:
			cmp	[ebp].nic_type, NIC_790_CHIP	; 790 accepts bad frames for ERX to work, so pass it up.
			je	ProcessAsPRX
			test	[ebp].receive_mask, ACCEPT_ERR_PACKETS
			jz	DontGetBadPackets
ProcessAsPRX:
			jmp	HandlePRX

DontGetBadPackets:
			jmp	CheckNextInt

;---------------------- Handle Ring Overwrite
PUBLIC	HandleOVW
HandleOVW:
			mov	ebx, [ebp].ptr_ring_OVW
			inc	dword ptr [ebx]

OvwCntrPtrZero:		mov	[ebp].ring_ovw, 1


			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_Ring_Ovw			; JIF not

			jmp	HandlePRX

MM_Ring_Ovw:
			test	[ebp].extra_info, NIC_690_BIT + NIC_790_BIT
			jz	Handle8390OVW
			jmp	HandlePRX
Handle8390OVW:
			mov	dx, [ebp].io_base
			mov	bx, dx			; Save IO addr in BX

			add	dx, REG_CMD
			in	al, dx
			and	al, CMD_TXP 
						; Save any TX pending
			mov	[ebp].ovw_tx_pending, al

			mov	al, CMD_STP
			out	dx, al			; Reset the NIC

			mov	dx, bx
			mov	al, 0			;
			add	dx, REG_RBCR0		; Clear RBCR0
			out	dx, al			;
			jmp	$+2
			inc	dx			; Clear RBCR1
IFDEF NEC
			inc	dx
ENDIF
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
ifndef	NT_CODE
			cli
endif
			mov	eax, NOT_MY_INTERRUPT
			cmp	[ebp].hdw_int, 0
			jne	IsHardwareInt
			cmp	[ebp].servicing_ints, 0
			je	NotMyInt
;;;			mov	[ebp].servicing_ints, 0	; [2] Moved down just below ServEvDone.
			jmp	ServEvDone

IsHardwareInt:		mov	[ebp].hdw_int, 0
			mov	dx, [ebp].int_port
			in	al, dx
			mov	ah, [ebp].int_bit
			not	ah
			and	al, ah
			out	dx, al
			call	UM_Interrupt

ServEvDone:		mov	eax, SUCCESS
			mov	[ebp].servicing_ints, 0	; [2] Moved from above.

NotMyInt:
			popfd
			pop	esi
			pop	edi
			pop	edx
			pop	ecx
			pop	ebx
			ret

LM_Service_Events	endp

;****************************************************************************
;
; Function:	LM_Receive_Copy
;
; Synopis:	Copies data from the adapter Shared RAM to a Data buffer
;		structure.
;
;		This function is the entry point for both the I/O and the
;		Memory Mapped modes.  The body of the code will handle
;		dispatching to the memory mapeed function or fall through
;		to execute the I/O mode.  Both processes will exit from
;		here also.  There are too many differences to use conditional
;		jumps for the two modes, so it was easier to write two
;		functions at this time.
;
; Input:	ECX	== bytes to move
;		EBX	== Lookahead flag,
;				0 = Lookahead copy.
;				1 = Final copy, poll rx status      [1]	
;				2 = Final copy, don't poll rx stat. [1]
;		EAX	== Offset in shared RAM
;		ESI	== Pointer to data buffer structure
;		EBP	== Pointer to adapter structure
;
; Output:	EAX	== Return code. HARDWARE_FAILED if early Rx frame had
;			   errors, otherwise SUCCESS.
;
; Modified:	None
;
; Notes:	None
;
;****************************************************************************

PUBLIC	LM_Receive_Copy

ifdef	LARGE
LM_Receive_Copy proc	far
else
LM_Receive_Copy proc	near	
endif
	push	ebp			; 1+ Save regs
	push	esi			; 2+
	push	edi			; 3+
	push	ebx			; 4+
	push	ecx			; 5+
	push	edx			; 6+
;
;	[1]: Reset the RX status polling flag
;
	and	[ebp].lmac_flags, not RX_STATUS_POLL

	or	ebx, ebx		; Do look ahead copy?
	jz	CheckWhichMode		; JIF yes
;
;	[1]: Init LMAC flag to indicate whether the RX status should be 
;	polled at the end of the copy or not.
;
	cmp	ebx, 2			; Final copy, don't poll?
	je	DontPollRxStatus	; JIF NO POLL

	or	[ebp].lmac_flags, RX_STATUS_POLL	; Else POLL, End [1]

DontPollRxStatus:
	or	[ebp].adapter_flags, EARLY_RX_COPY	; Set early recv flag


CheckWhichMode:				; Test for I/O or Memory mapped modes
	test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
	jnz	IO_Receive_Copy			; JIF yes

	call	MM_LM_Receive_Copy	; Else execute the Memory Mapped fn
	jmp	LM_Rcv_Copy_Exit	; Clean up stack and exit


IO_Receive_Copy:			;I/O mapped mode path
;
;	Save the shared RAM address offset in "packet_offset".
;	This value is equal to:
;
;	(ring buffer offset) + (packet offset into the ring buffer, EAX)
;
	xor	ebx, ebx		; Clear work register
	mov	bh, [ebp].local_nxtpkt_ptr
	mov	bl, NIC_HEADER_SIZE
	add	ebx, eax		; EBX = Ring buffer ptr+header+offset

	cmp	bh, [ebp].pstop_hold	; Frame base + offset > pstop?
	jb	PktOffsetOk		; JIF no

	sub	bh, [ebp].pstop_hold	; It wraps, so adjust the pointer to 
	xor	edx, edx		;  the packet offset that is at the
	mov	dh, [ebp].pstart_hold	;   beginning of the ring.
	add	ebx, edx		;

PktOffsetOk:
	mov	[ebp].packet_offset, ebx	; Store pointer to offset
;
;	Turn on Wrap Enable and set the I/O pipe address
;
	mov	dx, [ebp].io_base
	add	dx, REG_UBRCV		; Ultra board receive reg
	in	al, dx
	or	al, UBRCV_WREN
	out	dx, al			; Enable ring wrap logic

	add	dx, REG_IOPA - REG_UBRCV	; Set offset in the IO pipe
	mov	ax, bx				; EBX = offset
	out	dx, al				; Write the low byte first
	mov	al, ah				; 
	out	dx, al				; Follow with high byte

ifndef	NT_CODE
	pushf
endif
	cld					; Make sure we increment

	mov	edx, [esi].fragment_count	; EDX = # of frags
	lea	ebx, [esi].fragment_list	; EBX -> 1st fragment

	xor	ah, ah				; Clear leftover flag

	mov	[ebp].byte_cnt, ecx		; Save total byte cnt.

;
;	Main loop to copy fragments.  The following registers have been set
;	for the loop:
;
;			EDX = Main Loop controller = # of frags to copy
;			EBX = pointer to the first fragment
;			byte_cnt = total number of bytes to copy
;
fragment_loop2:
	cmp	[ebp].byte_cnt, 0	; If zero, all bytes have been copied
	jg	move_more		; Else continue

	jmp	no_more_frags2		; Exit Main Loop

move_more:	
	push	ebx				; 7+
	mov	ecx, [ebx].fragment_length	; Length of current fragment

	or	cx, cx				; Any data to copy?
	jnz	HaveFragData			; JIF yes
	jmp	ZeroLenFrag			; JIF no data to copy

HaveFragData:
;
; 	Subtract this fragment's count from the total count to copy and
;	update the count to copy.
;
;	If (remaining byte count (last fragment) > fragment byte count)
;	   Subtract the fragment count,
;	else
;	   Use the remaining byte count.
;
	cmp	[ebp].byte_cnt, ecx	; Remaining count > frag count?
	ja	count_ok		; JIF yes
	mov	ecx, [ebp].byte_cnt	;

count_ok:
	sub	[ebp].byte_cnt, ecx	; Update the remaining count

;
;	Get pointer to fragment and check for an early receive copy.
;
	mov	edi, [ebx].fragment_ptr	; EDI -> fragment

	test	[ebp].adapter_flags, EARLY_RX_FRAME
	jnz	EarlyMove
	jmp	StandardMove


EarlyMove:				; ECX = size, EDI -> Destination ptr
	push	eax			; 1a+ Save some essentials
	push	ebx			; 2a+
	push	edx			; 3a+

	mov	dx, [ebp].io_base	; Set DX for the following inner loop
	add	dx, REG_IOPD		

	mov	ebx, ecx		; Save byte cnt in BX

EarlyStringIoLoop:			; Outer early receive loop
	add	dx, REG_ISR - REG_IOPD
	in	al, dx
	add	dx, REG_IOPD - REG_ISR	; Reset I/O register
	test	al, ISR_PRX+ISR_RXE	; Packet received or error?
	jz	MoveNextBlock		; JIF no, do early receive
	jmp	MoveAllTheRest		; Else no early recv, count not valid

MoveNextBlock:
	mov	ecx, ERX_BLOCK_SIZE	; Assume early receive size
	cmp	ebx, ERX_BLOCK_SIZE	; check byte count to ERX max size
	jae	UseFixedCnt		; JIF ok
	mov	ecx, ebx		; Else adjust to smaller size

UseFixedCnt:
	sub	ebx, ecx		; Update fragment byte count
	push	ecx			; 4a+

RepeatErxIoMove:			; Inner early receive loop
	shr	ecx, 1			; Adjust for word move
	rep	insw			; Get the data

	jnc	NoOddIoByte1		; JIF no odd byte in carry flag
	insb				; Get the lonely oddball

NoOddIoByte1:
;
;	***This pop is used for each 4a+ in this Early Receive inner loop.
;
	pop	ecx				; 4a- 

	add	dx, REG_UBRCV - REG_IOPD	; Receive register
	in	al, dx			
	mov	ah, al				; Save value
	out	dx, al
	add	dx, REG_IOPD - REG_UBRCV	; Reset register for next I/O
	test	ah, UBRCV_URUN			; Underrun occur?
	jz	MoveNextChunk			; JIF no
;
;	Underrun has occurred, reset packet offset and the I/O pipe address.
;
	push	ecx				; 4a+

	sub	edi, ecx			; Reset dest address
	mov	eax, [ebp].packet_offset	; EAX = Last source address

	cmp	ah, [ebp].pstop_hold		; Test for wrap again
	jb	NewAddrInRange			; JIF if it doesn't

	sub	ah, [ebp].pstop_hold		; Packet offset wrapped, so
	add	ah, [ebp].pstart_hold		;  set offset at first buffer
	mov	[ebp].packet_offset, eax	;  in the ring.

NewAddrInRange:
	add	dx, REG_IOPA - REG_IOPD		; Set starting address
	out	dx, al
	mov	al, ah
	out	dx, al
	add	dx, REG_IOPD - REG_IOPA		; Reset register for next I/O
	jmp	RepeatErxIoMove			; Try early receive again


MoveNextChunk:
	add	[ebp].packet_offset, ecx	; Update source address
	or	ebx, ebx			; Early receive done?
	jz	AllErxDataMoved			; JIF yes
	jmp	EarlyStringIoLoop		; Else get remaining bytes

AllErxDataMoved:			
	pop	edx			; 3a-
	pop	ebx			; 2a-
	pop	eax			; 1a-
	jmp	ZeroLenFrag		; Go check for next fragment to move

MoveAllTheRest:
	mov	ecx, ebx		; Update loop byte count
	pop	edx			; 3a-
	pop	ebx			; 2a-
	pop	eax			; 1a-
;
;
;
StandardMove:
	push	edx			; 8+
	mov	dx, [ebp].io_base	;
	add	dx, REG_IOPD		; Set the I/O pipe for data read

	shr	ecx, 1			; Read words
	rep	insw			; Get the data
	jnc	EvenAmount		; JIF all data moved
	insb				; get oddball

EvenAmount:
	pop	edx			; 8- Get fragment (loop) count back

ZeroLenFrag:
	pop	ebx			; 7- Get fragment pointer back
	add	ebx, size FragmentStructure	; Update to next
	dec	edx			; Decrement fragment count
	jz	no_more_frags2		; JIF no more fragments

	jmp	fragment_loop2		; Get more data
;
;
;
no_more_frags2:
	mov	ebx, SUCCESS		; Assume no errors

	cmp	[ebp].byte_cnt, 0	; All data moved?
	je	byte_count_ok		; JIF yes

	mov	ebx, OUT_OF_RESOURCES	; ELse we ran out of userdata buffers

byte_count_ok:
;
;	Test for errors on Early Receive only; otherwise, the errors
;	would already have been caught and this routine would not have
;	been entered.
;
	test	[ebp].adapter_flags, EARLY_RX_FRAME	; Early receive?
	jnz	CheckRxStatus				; JIF yes

LM_RxCopyExit:
ifndef	NT_CODE
	popf
endif
	and	[ebp].adapter_flags, not EARLY_RX_COPY

	mov	dx, [ebp].io_base
	add	dx, REG_UBRCV
	in	al, dx
	and	al, not UBRCV_WREN
	out	dx, al			; Disable ring wrap logic

LM_Rcv_Copy_Exit:
	mov	eax, ebx		; EAX = return code
	pop	edx			; 6-
	pop	ecx			; 5-
	pop	ebx			; 4-
	pop	edi			; 3-
	pop	esi			; 2-
	pop	ebp			; 1-
	ret				; Exit


CheckRxStatus:
	mov	dx, [ebp].io_base	; AL = interrupt status
	add	dx, REG_ISR
	in	al, dx
;
;	If no Rx interrupt occurred, the status is not valid.
;
	test	al, ISR_PRX + ISR_RXE
	jz	StatusNotAvailable

StatusReEntry:					; [1] Label added
	xor	eax, eax
	mov	ah, [ebp].local_nxtpkt_ptr	; AX packet offset

	mov	dx, [ebp].io_base
	add	dx, REG_IOPA
	out	dx, al
	mov	al, ah
	out	dx, al
	add	dx, REG_IOPD - REG_IOPA
	in	ax, dx				; Read packet status

	mov	[ebp].packet_ptr, ax		; Save for later.
	and	[ebp].packet_ptr, 0FF00h	; Mask off lo byte.

	and	[ebp].adapter_flags, not EARLY_RX_FRAME
	and	al, 1Fh
	cmp	al, RSR_PRX			; Packet received?
	je	LM_RxCopyExit			; JIF yes, exit

	mov	ebx, HARDWARE_FAILED		; Early Receive failure
	jmp	LM_RxCopyExit

StatusNotAvailable:
	test	[ebp].adapter_flags, EARLY_RX_COPY
	jnz	RxFrameTooBig
;
;	If this is the lookahead copy, do not indicate a failure. The status
;	is usually not available on the lookahead copy.
;
	jmp	LM_RxCopyExit	

;
;	If the packet is much larger than indicated in the 802.3 header, we
;	could end up here.
;
RxFrameTooBig:
					; [1] Support Rx status polling
	test	[ebp].lmac_flags, RX_STATUS_POLL
	jz	RxFailedExit
	mov	cx, 0FFFFh		; Loop count for Rx status polling

PollForRxStatus:				
	in	al, dx
	test	al, ISR_PRX + ISR_RXE
	jnz	StatusReEntry
	loop	PollForRxStatus

RxFailedExit:				; End [1]
	mov	ebx, HARDWARE_FAILED
	or	[ebp].adapter_flags, RX_STATUS_PENDING
	and	[ebp].adapter_flags, not EARLY_RX_FRAME + EARLY_RX_COPY

	jmp	LM_RxCopyExit

LM_Receive_Copy	endp


;****************************************************************************
;
; Function:	MM_LM_Receive_Copy
;
; Synopis:	The is the Memory Mapped function for copying data from the
;		adapter Shared RAM to a Data buffer structure.
;
; Input:	ECX	== bytes to move
;		EBX	== Lookahead flag,
;				0 = Lookahead copy.
;				1 = Final copy, poll rx status      [1]	
;				2 = Final copy, don't poll rx stat. [1]
;		EAX	== Offset in shared RAM
;		ESI	== Pointer to data buffer structure
;		EBP	== Pointer to adapter structure
;
; Output:	EAX	== Return code. HARDWARE_FAILED if early Rx frame had
;			   errors, otherwise SUCCESS.
;
; Modified:	None
;
; Notes:	None
;
;****************************************************************************

PUBLIC	MM_LM_Receive_Copy

ifdef	LARGE
MM_LM_Receive_Copy proc	far
else
MM_LM_Receive_Copy proc	near	
endif
;
; Save offset of pkt in shared memory.
;
		xor	ebx, ebx
		mov	bh, [ebp].local_nxtpkt_ptr
		mov	bl, NIC_HEADER_SIZE
		add	ebx, eax		; Add in offset in AX.

		cmp	bh, [ebp].pstop_hold
		jb	MM_PktOffsetOk
		sub	ebx, [ebp].pstop_32
		xor	edx, edx
		mov	dh, [ebp].pstart_hold
		add	ebx, edx

MM_PktOffsetOk:
		add	ebx, [ebp].ram_access	; EBX = Address of packet.
						; ECX = # of bytes to move.
ifndef	NT_CODE
		pushf
		cli				; Disable ints
endif
		cld				;make sure we increment

		call	AccessSharedRam

; Save address of pkt in shared memory.
		mov	[ebp].packet_offset, ebx

		mov	edx, [esi].fragment_count	; Get # of frags in DX
		lea	ebx, [esi].fragment_list	; EBX = 1st frag str.
		xor	ah, ah				; Clear leftover flag

		mov	[ebp].byte_cnt, ecx		; Save total byte cnt.

MM_Fragment_Loop2:
		cmp	[ebp].byte_cnt, 0
		jg	MM_Move_More
		jmp	MM_No_More_Frags2

MM_Move_More:	
		push	ebx				; Save ptr to frag.
		mov	ecx, [ebx].fragment_length	; Get frag length
		jecxz	MM_NearZeroLenFrag
		cmp	[ebp].byte_cnt, ecx
						; Subtract this fragment's
						; count from total count.
		ja	MM_Count_Ok		; If fragment byte count is >
		mov	ecx, [ebp].byte_cnt	; remaining byte count (last
						; fragment) use byte count,
						; else use fragment count.

MM_Count_Ok:	sub	[ebp].byte_cnt, ecx
		push	eax			; save AX for later
						; Subtract
						; this count from pstop
						; If current ptr is >=, ring is
						; wrapped.
		mov	eax, [ebp].pstop_32
		add	eax, [ebp].ram_access	; EAX=Address of end of ShMem
		sub	eax, ecx	   	; ECX=bytes to move.
		cmp	[ebp].packet_offset, eax

		jna	no_ring_wrap		;
		mov	[ebp].wr_frag_cnt, ecx	; save fragment count
		mov	ecx, [ebp].pstop_32
; calculate wrapped leftover count
		mov	eax, [ebp].packet_offset
		sub	eax, [ebp].ram_access
		sub	ecx, eax
		sub	[ebp].wr_frag_cnt, ecx	; Save for later.

no_ring_wrap:
		pop	eax
		mov	edi, [ebx].fragment_ptr ; Far ptr to fragment.

continue_copy:	   
		or	ah, ah
	 	jz	no_leftover2
		mov	bx, [ebp].leftover_data
		mov	byte ptr [edi], bh
		inc	edi
		jecxz	DecWrFragCnt1
		dec     ecx	
		jmp	no_leftover2

MM_NearZeroLenFrag:
		jmp	MM_ZeroLenFrag

DecWrFragCnt1:	
		dec	[ebp].wr_frag_cnt

no_leftover2:
		push	esi
		mov	esi, [ebp].packet_offset

		test	esi, 1
		jz	EvenPtr
		push	eax
		mov	ax, [esi-1]
		mov	[edi], ah
		inc	esi
		inc	edi
		mov	eax, [ebp].ram_access
		add	eax, [ebp].pstop_32
		cmp	eax, esi
		jne	PtrOK

		mov	esi, [ebp].ram_access
		xor	eax, eax
		mov	ah, [ebp].pstart_hold
		add	esi, eax

PtrOK:		pop	eax
		jecxz	DecWrFragCnt2
		dec     ecx	     
		jmp	EvenPtr
DecWrFragCnt2:	dec	[ebp].wr_frag_cnt
	     
EvenPtr:
		test	[ebp].adapter_flags, EARLY_RX_FRAME
		jnz	MM_EarlyMove
		jmp	MM_StandardMove
MM_EarlyMove:
		push	ax
		push	bx
		push	dx
PollForMore:
		mov	dx, [ebp].io_base
		add	dx, REG_RCNTH
		in	al, dx
RepeatRcnt:
		mov	ah, al
		dec	dx
IFDEF NEC
		dec	dx
ENDIF
		in	al, dx
		mov	bx, ax
		inc	dx
IFDEF NEC
		inc	dx
ENDIF
		in	al, dx
		cmp	ah, al
		jne	RepeatRcnt

		mov	dx, [ebp].io_base
		add	dx, REG_ISR
		in	al, dx
		test	al, ISR_PRX+ISR_RXE
		jnz	WeGotThatMany

		xor	eax, eax
		mov	ah, [ebp].local_nxtpkt_ptr
		mov	al, NIC_HEADER_SIZE
		add	eax, [ebp].ram_access
		cmp	esi, eax	; EAX = Base offset of this frame.
		jae	FrameNoWrappy	; If current ptr is less than packet base ptr,
					; the packet wraps the ring.
		push	ebx
		mov	ebx, [ebp].pstop_32
		add	ebx, [ebp].ram_access
		sub	ebx, eax		; EBX = number of bytes moved prior to reaching PSTOP.

		xor	eax, eax
		mov	ah, [ebp].pstart_hold
		mov	al, 0
		add	eax, [ebp].ram_access	; EAX = Address of Rx space in shared ram.

		sub	eax, esi
		neg	eax			; EAX = number of bytes moved after reaching PSTART.
		add	eax, ebx		; The sum of the number of bytes moved prior to reaching PSTOP
		pop	ebx			; and the number of bytes moved after PSTART is the total bytes moved
		jmp	FrameWrappyEntry	; in this frame.
FrameNoWrappy:
		sub	eax, esi
		neg	eax
FrameWrappyEntry:
		add	ax, cx

; AX = Number of bytes into packet that is the end of this copy. (End Copy Target)
; BX = Receive Count so far.

		cmp	bx, ax
		jae	WeGotThatMany

		sub	ax, bx		; Get # of bytes not yet rx'd in AX
		mov	bx, cx		; Get copy of total byte count in BX.
		sub	bx, ax		; Subtract count of bytes not rx'd from total count.
		cmp	bx, 40h		; Do not bother to move less than 64 bytes.
		jl	PollForMore

		push	cx

		and	bx, 0FFFCh		; Evenize count in BX.

		mov	cx, bx			; Get count into CX.
		shr	cx, 2

		rep	movsd

		pop	cx

		sub	cx, bx
		cmp	cx, 4
		jle	WeGotThatMany
		jmp	PollForMore
WeGotThatMany:
		pop	dx
		pop	bx
		pop	ax
MM_StandardMove:

		shr	ecx, 1		; Convert byte count to word count.
		jz	short_frag2	; only one byte in frag.
		pushf			; Save carry flag from 1st shr ECX.
		shr	ecx, 1		; Convert word count to dword count.
		rep	movsd
		jnc	NoOddWord1
		movsw
NoOddWord1:	popf
short_frag2:
		jnc	show_no_leftover2
		mov	bx, [esi]
		inc	esi 	     
		inc	esi    	
		mov	[edi], bl
		inc	edi
		mov	ah, 0ffh
		mov	[ebp].leftover_data, bx	; Save leftover data
		jmp	short check_for_more_frags2

show_no_leftover2:
		xor	ah, ah

check_for_more_frags2:
		mov	[ebp].packet_offset, esi
		pop	esi
		cmp	[ebp].wr_frag_cnt, 0
		je	ring_not_wrapped
		mov	ecx, [ebp].wr_frag_cnt	; Get byte count of wrapped
		mov	[ebp].wr_frag_cnt, 0	; data starting at pstart and
						; clear wrapped frag count.
		push	eax			; save EAX . . .
		xor	eax, eax
		mov	ah, [ebp].pstart_hold	;
		add	eax, [ebp].ram_access
		mov	[ebp].packet_offset, eax
		pop	eax
		jmp	continue_copy		; Finish copying to this frag.

ring_not_wrapped:
;		mov	[ebp].leftover_data, bx	; Moved this line up

MM_ZeroLenFrag:					  	; near label
							; show_no_leftover2:
		pop	ebx					   
		add	ebx, size FragmentStructure
		dec	edx			; Decrement fragment count.
		jz	MM_No_More_Frags2
		jmp	MM_Fragment_Loop2

MM_No_More_Frags2:
		mov	ebx, SUCCESS
		cmp	[ebp].byte_cnt, 0
		je	MM_Byte_Count_Ok

		mov	ebx, OUT_OF_RESOURCES

MM_Byte_Count_Ok:
		test	[ebp].adapter_flags, EARLY_RX_FRAME
		jnz	MM_CheckRxStatus

MM_LM_RxCopyExit:
		and	[ebp].adapter_flags, not EARLY_RX_COPY
		call	DeAccessSharedRam
ifndef	NT_CODE
		popf
endif
		ret			; Exit


MM_CheckRxStatus:
		mov	dx, [ebp].io_base
		add	dx, REG_ISR
		in	al, dx

; If no Rx interrupt occurred, the status is not valid.

		test	al, ISR_PRX + ISR_RXE
		jz	MM_StatusNotAvailable

MM_StatusReEntry:					; [1] Label added
		xor	eax, eax
		mov	ah, [ebp].local_nxtpkt_ptr
		mov	esi, [ebp].ram_access
		add	esi, eax
		mov	ax, [esi]		; Access word
		and	al, 1Fh
		cmp	al, RSR_PRX
		je	MM_LM_RxCopyExit
		mov	ebx, HARDWARE_FAILED
		jmp	MM_LM_RxCopyExit

MM_StatusNotAvailable:
		test	[ebp].adapter_flags, EARLY_RX_COPY
		jz	MM_LM_RxCopyExit	; If this is the lookahead copy, do not indicate
						; a failure. The status is usually not available
						; on the lookahead copy.

; If packet is much larger than indicated in 802.3 header, we could end up here.

;;; [1] Change made to support Rx status polling.
		test	[ebp].lmac_flags, RX_STATUS_POLL
		jz	MM_RxFailedExit
		mov	ecx, 0FFFFh		; Set loop count for Rx status polling

MM_PollForRxStatus:				
		in	al, dx
		test	al, ISR_PRX + ISR_RXE
		jnz	MM_StatusReEntry	; If any RX int occurs, go back to 
		loop	MM_PollForRxStatus	; status re-entry point.

MM_RxFailedExit:
;;; End [1]

		mov	ebx, HARDWARE_FAILED
		jmp	MM_LM_RxCopyExit

MM_LM_Receive_Copy endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Close_Adapter	Closes adapter whose adapter structure is
;				indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Close_Adapter
ifdef	LARGE
LM_Close_Adapter	proc	far
else
LM_Close_Adapter	proc	near	
endif
			push	ecx
			push	edx
			cmp	[ebp].adapter_status, NOT_INITIALIZED
			jne	StatusOK
			mov	eax, ADAPTER_NOT_INITIALIZED
			jmp	NoStatusChange
						
StatusOK: 		mov	dx, [ebp].io_base
			add	dx, REG_CMD
			mov	al, CMD_STP
			out	dx, al
			jmp	$+2
			add	dx, REG_ISR - REG_CMD
			mov	ecx, 1600		; Each iteration of the following
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

LM_CA_NIC_Reset:	mov	[ebp].adapter_status, CLOSED
			call	UM_Status_Change
			mov	eax, SUCCESS		; Set return code
NoStatusChange:
			pop	edx
			pop	ecx
			ret
LM_Close_Adapter	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Open_Adapter		Opens adapter whose adapter structure is
;				indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Open_Adapter
ifdef	LARGE
LM_Open_Adapter proc	far
else
LM_Open_Adapter proc	near	
endif
			push	ecx
			push	edx
			push	esi
			cmp	[ebp].adapter_status, NOT_INITIALIZED
			jne	CheckStat01
			mov	eax, ADAPTER_NOT_INITIALIZED
			jmp	LM_OADone
CheckStat01:		cmp	[ebp].adapter_status, INITIALIZED
			je	OKToOpen
			cmp	[ebp].adapter_status, OPEN
			je	AlreadyOpen
DoInit:
			xor	esi, esi
ifdef LARGE
			call	far ptr LM_Initialize_Adapter
else
			call	LM_Initialize_Adapter
endif
			cmp	eax, SUCCESS
			je	OKToOpen
			mov	eax, OPEN_FAILED
			mov	[ebp].adapter_status, FAILED
			jmp	LM_OADone
OKToOpen:		mov	dx, [ebp].io_base
			add	dx, REG_CMD
			mov	al, CMD_STA
			out	dx, al
			jmp	$+2
			mov	dx, [ebp].io_base
			add	dx, REG_TCR
			mov	al, 0
			mov	cx, [ebp].mode_bits
			test	cx, MANUAL_CRC
			jz	OpenAdap01
			mov	al, TCR_CRC
OpenAdap01:		out	dx, al
			jmp	$+2
			mov	[ebp].adapter_status, OPEN
			call	UM_Status_Change
AlreadyOpen:		mov	eax, SUCCESS		; Set return code

LM_OADone:		pop	esi
			pop	edx
			pop	ecx
			ret
LM_Open_Adapter endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Interrupt_Req	Generates a hardware interrupt from the
;				adapter indicated by EBP.
;
;	Entry:	EBP	Pointer to adapter structure
;
;	Exit:	EAX	SUCCESS
;			INVALID_FUNCTION if hardware interrupts are not
;					supported by the adapter.
;			OUT_OF_RESOURCES if adapter has been disabled
;					 by LM_Disable_Adapter.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUBLIC	LM_Interrupt_Req
ifdef	LARGE
LM_Interrupt_Req	proc	far
else
LM_Interrupt_Req	proc	near	
endif
		push	edx
ifndef	NT_CODE
		pushf
		cli			; Disable ints
endif
		test	[ebp].adapter_flags, ADAPTER_DISABLED
		jz	LM_Int_Enabled
		jmp	LM_Int_Disabled

LM_Int_Enabled:
		mov	dx, [ebp].io_base

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetIntVals			; JIF yes

		test	word ptr [ebp].board_id, MICROCHANNEL
		jz	IntReqNotMCA
		mov	ax, [ebp].board_id
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_594_CHIP
		jne	IntReqNotSupported
		add	dx, REG_CR
		mov	[ebp].int_port, dx
		mov	[ebp].int_bit, CR_SINT
		jmp	IntReqGotParms
IntReqNotMCA:
		cmp	[ebp].pc_bus, PCMCIA_BUS
		jne	CheckIntChip
		mov	[ebp].int_port, dx
		mov	[ebp].int_bit, 01h
		jmp	IntReqGotParms

CheckIntChip:
		mov	ax, [ebp].board_id
		test	ax, INTERFACE_CHIP
		jz	IntReqNotSupported

		cmp	[ebp].bic_type, BIC_585_CHIP
		jne	IntReq584

SetIntVals:
		add	dx, REG_INTCR
		mov	[ebp].int_port, dx
		mov	[ebp].int_bit, INTCR_SINT
		jmp	IntReqGotParms

IntReq584:
		add	dx, REG_ICR
		in	al, dx
		jmp	$+2
		and	al, NOT ICR_OTH
		out	dx, al			; Make sure BIO reg is accessed
		add	dx, REG_BIO-REG_ICR
		mov	[ebp].int_port, dx
		mov	[ebp].int_bit, 01h
IntReqGotParms:
		in	al, dx
		or	al, [ebp].int_bit
		mov	[ebp].hdw_int, 1
		out	dx, al
		mov	eax, SUCCESS
		jmp	IntReqDone
LM_Int_Disabled:
		mov	eax, OUT_OF_RESOURCES
		jmp	IntReqDone
IntReqNotSupported:
		mov	[ebp].int_bit, 0
		mov	[ebp].int_port, 0
		mov	[ebp].hdw_int, 0
		mov	eax, INVALID_FUNCTION

IntReqDone:
ifndef	NT_CODE
		popf
endif
		pop	edx
		ret

LM_Interrupt_Req	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	UpdateCounters	Updates error counters to reflect current
;				NIC stats.
;
;	Entry:	EBP	Pointer to Adapter Structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateCounters	proc	near
		push	edx
		push	ebx
		xor	eax, eax
		mov	dx, [ebp].io_base

		add	dx, REG_CNTR0		; CNTR0 = Frame Align Errors
		in	al, dx
		mov	ebx, [ebp].ptr_rx_align_errors
		add	[ebx], eax
		inc	dx			; REG_CNTR0+1= REG_CNTR1
IFDEF NEC
		inc	dx
ENDIF
		in	al, dx			; CNTR1 = CRC Errors
		mov	ebx, [ebp].ptr_rx_CRC_errors
		add	[ebx], eax

		inc	dx			; REG_CNTR1+1= REG_CNTR2
IFDEF NEC
		inc	dx
ENDIF
		in	al, dx			; CNTR2 = Missed Pkt Errors
		mov	ebx, [ebp].ptr_rx_lost_pkts
		add	[ebx], eax

		mov	eax, SUCCESS
		pop	ebx
		pop	edx
		ret
UpdateCounters	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	load_node_address	Loads node address into adapter structure
;				indicated by EBP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	load_node_address
load_node_address	proc	near	

			push	ecx
			push	edx
			push	ebp
			push	edi
			push	esi
ifndef	NT_CODE
			pushf
			cli
endif
			mov	al, 0
			mov	ecx, 6
			add	ebp, 6
LoadNodeLoop:		dec	ebp
			or	al, [ebp].node_address
			loop	LoadNodeLoop
			mov	ecx, 6
			mov	dx, [ebp].io_base
			add	dx, REG_LAR0
			or	al, al
			jz	GetNodeAddFromBIC

			mov	dx, [ebp].io_base
			add	dx, REG_CMD
			mov	al, CMD_STP+CMD_PAGE1
			out	dx, al
			add	dx, REG_PAR0 - REG_CMD						
			push	ebp
NodeAddrToNIC:
			mov	al, [ebp].node_address
			out	dx, al
			inc	dx
IFDEF NEC
			inc	dx
ENDIF
			inc	ebp
			loop	NodeAddrToNIC
			pop	ebp

			mov	dx, [ebp].io_base
			add	dx, REG_CMD
			mov	al, CMD_STP+CMD_PAGE0
			out	dx, al
			jmp	NodeAddDone
GetNodeAddFromBIC:
			in	al, dx
			mov	[ebp].node_address, al
			inc	dx 
IFDEF NEC
			inc	dx
ENDIF
			inc	ebp
			loop	GetNodeAddFromBIC
NodeAddDone:
ifndef	NT_CODE
			popf
endif
			pop	esi
			pop	edi
			pop	ebp
			pop	edx
			pop	ecx
			mov	eax, SUCCESS
			ret
load_node_address	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	enable_59x_irq enables IRQ on 59x-based adapter whose adapter structure
;	is indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_59x_irq	proc	near
			push	edx
			mov	dx, [ebp].io_base
			add	dx, REG_CR
			in	al, dx
			jmp	$+2
			or	al, CR_EIL
			out	dx, al
			mov	[ebp].laar_enter, al
			mov	[ebp].laar_exit, al
			mov	eax, SUCCESS
			pop	edx
			ret
enable_59x_irq	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	disable_59x_irq disables IRQ on 59x-based adapter whose adapter structure
;	is indicated by EBP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disable_59x_irq proc	near
			push	edx
			mov	dx, [ebp].io_base
			add	dx, REG_CR
			in	al, dx
			jmp	$+2
			and	al, NOT CR_EIL
			out	dx, al
			mov	[ebp].laar_enter, al
			mov	[ebp].laar_exit, al
			mov	eax, SUCCESS
			pop	edx
			ret
disable_59x_irq endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       enable_585_irq enables IRQ on 585-based adapter whose adapter structure
;       is indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_585_irq  proc    near
			push    edx
			mov     dx, [ebp].io_base
			add	dx, REG_INTCR
			in	al, dx
			or	al, INTCR_EIL
			out	dx, al
			mov     eax, SUCCESS
			pop     edx
			ret
enable_585_irq  endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       disable_585_irq disables IRQ on 585-based adapter whose adapter structure
;       is indicated by EBP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disable_585_irq proc    near
			push    edx
			mov     dx, [ebp].io_base
			add	dx, REG_INTCR
			in	al, dx
			and	al, not INTCR_EIL+INTCR_SINT
			out     dx, al
			mov     eax, SUCCESS
			pop     edx
			ret
disable_585_irq endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	enable_NIC_irq	Enables irq on 583 or 584-based adapter whose adapter
;			structure is indicated by EBP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_NIC_irq	proc	near
		push	edx
		mov	dx, [ebp].io_base
		add	dx, REG_CMD
		mov	al, CMD_PAGE0
		out	dx, al		; Select page 0
		jmp	$+2
		add	dx, REG_IMR - REG_CMD
		mov	al, [ebp].imr_hold
		out	dx, al
		mov	eax, SUCCESS			; return SUCCESS
		pop	edx				; Restore regs
		ret

enable_NIC_irq	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	disable_NIC_irq Disables IRQ on 58x-based adapter whose adapter
;			structure is indicated by EBP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disable_NIC_irq proc	near
		push	edx
		mov	dx, [ebp].io_base
		add	dx, REG_CMD
		mov	al, CMD_PAGE0		 ; Select page 0
		out	dx, al
		jmp	$+2
		add	dx, REG_IMR - REG_CMD
		mov	al, 0
		out	dx, al
		mov	eax, SUCCESS			; return SUCCESS
		pop	edx				; Restore regs
		ret

disable_NIC_irq endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	init_nic	Initializes NIC on adapter whose adapter
;			structure is indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_nic	proc	near
		push	ebx
		push	ecx
		push	edx
		push	esi			; Save regs used
ifndef	NT_CODE
		pushf
		cli
endif
		mov	bx, [ebp].io_base	; BX = io_base
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
		mov	ecx, 1600		; Each iteration of the following
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
		test	[ebp].board_id, MICROCHANNEL
		jnz	SetWordMode
		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	CheckSlot
		test	[ebp].board_id, BOARD_16BIT
		jnz	SetWordMode
		jmp	SetByteMode
CheckSlot:	test	[ebp].extra_info, SLOT_16BIT
		jz	SetByteMode	; If 16 bit card or microchannel,

SetWordMode:	or	al, DCR_WTS	; Set word transfer select bit
SetByteMode:	mov	dx, bx
		add	dx, REG_DCR	; Get io_base + DCR into DX
		out	dx, al		; Write DCR
ifdef LARGE
		call	far ptr LM_Change_Receive_Mask
else
		call	LM_Change_Receive_Mask
endif
		mov	dx, bx		; Get IO base
		add	dx, REG_TCR
		mov	al, TCR_LB1	; Place in mode 2 loopback.
		out	dx, al
		jmp	$+2
		
		mov	dx, bx
		add	dx, REG_PSTART


		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_GetPstop			; JIF not

		mov	al, 0
		jmp	StorePstartHold

MM_GetPstop:
		mov	al, [ebp].tx_pstop

StorePstartHold:
		mov	[ebp].pstart_hold, al
		out	dx, al
		jmp	$+2

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_ChkRamUsable			; JIF not

		mov	al, [ebp].pstop_hold
		jmp	ContInitNic

MM_ChkRamUsable:
;		mov	ax, [ebp].ram_size
		mov	ax, [ebp].ram_usable
		shl	al, 1
		shl	al, 1		; Multiply by 4 to get pstop_hold
		or	al, al
		jnz	LessThan64k
		dec	al
LessThan64k:
@@:		mov	[ebp].pstop_hold, al

ContInitNic:
		mov	dx, bx
		add	dx, REG_PSTOP
		out	dx, al
		jmp	$+2

		xor	eax, eax
		mov	ah, [ebp].pstop_hold
		mov	[ebp].pstop_32, eax	; Calculate and store 32-bit
						; PSTOP value.

		mov	dx, bx			; Boundary = pstart_hold
		add	dx, REG_BNRY
		mov	al, [ebp].pstart_hold
		out	dx, al
		jmp	$+2

		mov	dx, bx			; Set ISR
		add	dx, REG_ISR
		mov	al, 0ffh
		out	dx, al
		jmp	$+2
		
		mov	dx, bx			; Set IMR
		add	dx, REG_IMR
		mov	al, [ebp].imr_hold
		out	dx, al
		jmp	$+2

		mov	dx, bx			; Select Page 1
		add	dx, REG_CMD
		mov	al, CMD_STP+CMD_PAGE1
		out	dx, al
		jmp	$+2
		
		push	ebp		; Load Physical Address regs
		mov	ecx, 6
		mov	dx, bx
		add	dx, REG_PAR0

GetNodeAddress:
		mov	al, [ebp].node_address
		out	dx, al
		jmp	$+2
		inc	ebp
		inc	dx
IFDEF NEC
		inc	dx
ENDIF
		loop	GetNodeAddress
		pop	ebp

		mov	al, [ebp].pstart_hold
;
; If (795), make CURR = BOUND = local_nxtpkt_ptr.
;
		test	[ebp].lmac_flags, USE_RE_BIT	; 795?
		jnz	InitLocalNxtPktPtr		; JIF yes

		inc	al		; Else Bound = local_nxtpkt_ptr+1

InitLocalNxtPktPtr:
		mov	[ebp].local_nxtpkt_ptr, al

		mov	dx, bx			; Get io_base
		add	dx, REG_CURR		; Point to CURR reg.
		out	dx, al			; AL = local_nxtpkt_ptr
		jmp	$+2

		mov	dx, bx
		add	dx, REG_CMD
		mov	al, CMD_STP+CMD_PAGE0
		out	dx, al
		jmp	$+2			; Init REG_CMD again
		
		mov	[ebp].tx_pend, 0
ifndef	NT_CODE
		popf
endif
		pop	esi			; Restore regs used
		pop	edx
		pop	ecx
		pop	ebx
		mov	eax, SUCCESS
		ret			; Return to caller
init_nic	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	reset_nic	Resets the NIC on the adapter whose adapter structure
;			is indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
reset_nic	proc	near
		push	ebx
		push	edx
		mov	dx, [ebp].io_base
		add	dx, REG_MSR
		mov	al, 0
		cmp	[ebp].board_id, WD8003ETA
		je	SkipIO
		in	al, dx
		jmp	$+2
SkipIO:		mov	bl, al			; Save REG_MSR contents in BL
		or	al, MSR_RST		 ; Set reset bit
		out	dx, al
		jmp	$+2
;Delay for 1 uS . . .
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
		in	al, dx
		in	al, dx

		mov	al, bl			; Get original contents into AL
		and	al, not MSR_RST
		out	dx, al			; Reset reset bit
		jmp	$+2
		pop	edx
		pop	ebx
		mov	eax, SUCCESS
		ret
reset_nic	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	enable_ram	enables RAM on adapter whose adapter structure is
;			indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_ram	proc	near
		push	ebx
		push	ecx
		push	edx
		mov	dx, [ebp].io_base

		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	SkipDconInit
		add	dx, REG_DCR
		mov	al, DCR_FT1 + DCR_WTS
		out	dx, al
		sub	dx, REG_DCR
SkipDconInit:
		add	dx, REG_MSR
		test	[ebp].board_id, MICROCHANNEL+INTERFACE_CHIP
		jnz	NoInit
		mov	cx, 3
		mov	ax, word ptr [ebp].ram_base+2
		shl	ax, cl
		mov	bl, al
		mov	ax, word ptr [ebp].ram_base
		mov	cx, 13
		shr	ax, cl
		or	al, bl
		jmp	EnableDeRam
NoInit: 
		mov	al, 0
		test	[ebp].board_id, INTERFACE_CHIP
		jz	EnableDeRam
		in	al, dx
EnableDeRam:
		or	al, MSR_MENB
		out	dx, al
		jmp	$+2
		in	al, dx
		pop	edx
		pop	ecx
		pop	ebx
		mov	eax, SUCCESS
		ret
enable_ram	endp
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	disable_ram	disables RAM on adapter whose adapter structure is
;			indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
disable_ram	proc	near
		push	edx
		mov	dx, [ebp].io_base
		add	dx, REG_MSR
		mov	al, 0
		test	[ebp].board_id, MICROCHANNEL
		jnz	DontReadPort
		in	al, dx
		jmp	$+2
DontReadPort:
		and	al, not MSR_MENB
		out	dx, al
		jmp	$+2
		in	al, dx
		pop	edx
		mov	eax, SUCCESS
		ret
disable_ram		endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	set_MARs	Sets all 8 NIC Multicast Address Registers (REG_MAR0-7)
;			to value in BL. All regs preserved, no return code.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	set_MARs
set_MARs	proc	near
		push	eax
		push	ecx
		push	edx

		mov	dx, [ebp].io_base
		add	dx, REG_CMD
		in	al, dx
		jmp	$+2
		and	al, CMD_PS0+CMD_PS1
		mov	bh, al			; Save original page in BH
		mov	al, CMD_PAGE1		; Select page 1
		out	dx, al
		jmp	$+2
		add	dx, REG_MAR0 - REG_CMD
		mov	ecx, 8
		mov	al, bl			; Get value to write into AL
SetMARLoop:
		out	dx, al			; Write 8 bytes to MAR0-7
		jmp	$+2
		inc	dx
IFDEF NEC
		inc	dx
ENDIF
		loop	SetMARLoop

		mov	dx, [ebp].io_base
		add	dx, REG_CMD			; Restore original page.
		mov	al, bh
		out	dx, al

		pop	edx
		pop	ecx
		pop	eax
		ret

set_MARs	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SendPacket	Sends packet of at offset 
;			[ebp].tx_buffer in shared memory.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	SendPacket
SendPacket	proc	near
			push	eax
			push	ecx
			push	edx
			push	esi

			mov	dx, [ebp].io_base

			add	dx, REG_CMD
			in	al, dx
			test	al, CMD_TXP
			jnz	NicPending

			xor	eax, eax		; get tx_buffer offset
			mov	al, [ebp].tx_head
			shl	ax, 1
			shl	ax, 1
			mov	esi, eax
			mov	cx, word ptr [ebp+esi].tx_buffer+2				
			mov	ax, word ptr [ebp+esi].tx_buffer				
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

			mov	al, CMD_TXP
			out	dx, al			; Send packet.
			clc
SendPacketDone:
			pop	esi
			pop	edx
			pop	ecx
			pop	eax
			ret

NicPending:		stc
			jmp	SendPacketDone

SendPacket	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	UpdateBoundary	Updates NIC Boundary register to 
;			[EBP].local_nxtpkt_ptr - 1.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateBoundary	proc	near
	push	eax

	mov	al, [ebp].local_nxtpkt_ptr	; Get local_nxtpkt_ptr into AL
;
;	if (USE_RE_BIT)
;	   bound = local next packet ptr;
;	else 
;	   bound = local next packet ptr - 1;
;
	test	[ebp].lmac_flags, USE_RE_BIT	; Using RE bit on 795?
	jnz	bnry_ok				; JIF yes, i.e. Don't dec

	dec	al

	cmp	al, [ebp].pstart_hold
	jnb	bnry_ok

	mov	al, [ebp].pstop_hold
	dec	al

bnry_ok:
	mov	dx, [ebp].io_base
	add	dx, REG_BNRY
	out	dx, al

	pop	eax
	ret
UpdateBoundary	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The following routines comprise the modular equivalent of ETH_COM.ASM.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Enable_Adapter	Enables adapter whose adapter structure is
;				indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Enable_Adapter
ifdef	LARGE
LM_Enable_Adapter	proc	far
else
LM_Enable_Adapter	proc	near	
endif
		push	edx

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	En_585_Irq			; JIF yes

		mov	ax, [ebp].extra_info
		and	ax, INTERFACE_CHIP_MASK

EnAdap01:	cmp	ax, INTERFACE_594_CHIP
		jne	EnAdap02
		call	enable_59x_irq
		mov	eax, SUCCESS
		jmp	LM_EnAdp_done

EnAdap02:	cmp	ax, INTERFACE_5X3_CHIP
		jne	EnAdap03
		mov	ax, [ebp].board_id
		test	ax, MICROCHANNEL
		jz	EnAdap04
		test	ax, INTERFACE_CHIP	; If no interface chip, adapter is 8003ET/A
		jz	EnAdap04

		call	enable_59x_irq
		mov	eax, SUCCESS
		jmp	LM_EnAdp_done

EnAdap03:	
		cmp	ax, INTERFACE_585_CHIP
		jne	EnAdap04

En_585_Irq:
		call	enable_585_irq
		mov	eax, SUCCESS
		jmp	LM_EnAdp_done

EnAdap04:	
		call	enable_NIC_irq
		mov	eax, SUCCESS

LM_EnAdp_done:
		and	[ebp].adapter_flags, not ADAPTER_DISABLED
		pop	edx
		ret
LM_Enable_Adapter	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Disable_Adapter	Disables adapter whose adapter structure is
;				indicated by EBP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Disable_Adapter
ifdef	LARGE
LM_Disable_Adapter	proc	far
else
LM_Disable_Adapter	proc	near	
endif
		push	edx

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Dis_585_Irq			; JIF yes

		mov	ax, [ebp].extra_info
		and	ax, INTERFACE_CHIP_MASK

DisAdap01:	cmp	ax, INTERFACE_594_CHIP
		jne	DisAdap02
		call	disable_59x_irq
		mov	eax, SUCCESS
		jmp	DisAdap_done

DisAdap02:	cmp	ax, INTERFACE_5X3_CHIP
		jne	DisAdap03
		mov	ax, [ebp].board_id
		test	ax, MICROCHANNEL
		jz	DisAdap04
		test	ax, INTERFACE_CHIP	; If no interface chip, adapter is 8003ET/A
		jz	DisAdap04

		call	disable_59x_irq
		mov	eax, SUCCESS
		jmp	DisAdap_done

DisAdap03:	
		cmp	ax, INTERFACE_585_CHIP
		jne	DisAdap04

Dis_585_Irq:
		call	disable_585_irq
		mov	eax, SUCCESS
		jmp	DisAdap_done

DisAdap04:	call	disable_NIC_irq
		mov	eax, SUCCESS

DisAdap_done:
		or	[ebp].adapter_flags, ADAPTER_DISABLED
		pop	edx
		ret
LM_Disable_Adapter	endp


;****************************************************************************
;
; Function:	LM_Initialize_Adapter
;
; Synopis:	Entry point and control shell for initialization of the
;		adapter.
;
; Input:        EBP --> Adapter Structure
;
; Output:       EAX = Initialization return code
;
; Modified:     None
;
; Notes:	None
;
;****************************************************************************

PUBLIC	LM_Initialize_Adapter
ifdef	LARGE
LM_Initialize_Adapter	proc	far
else
LM_Initialize_Adapter	proc	near	
endif
	push	ebx			; 1+ Save registers
	push	ecx			; 2+
	push	edx			; 3+

	call	InitAdapter		; Get adapter ready for AMD

	call	AutoMediaDetect		; Sense which connector is present

	call	InitAdapter		; Completely re-init adapter

	push	eax			; 4a+
	call	UM_Status_Change	; Notify UMAC
	pop	eax			; 4a-

	pop	edx			; 3- Restore registers
	pop	ecx			; 2-
	pop	ebx			; 1-
	ret				; Exit
LM_Initialize_Adapter	endp


;****************************************************************************
;
; Function:	InitAdapter
;
; Synopis:	Initialize the adapter to a known startup state.
;
; Input:        EBP --> Adapter Structure
;
; Output:       None
;
; Modified:     None
;
; Notes:	None
;
;****************************************************************************

InitAdapter	proc	near
;
;	Initialize the internal LMAC flag register.
;
		mov	[ebp].lmac_flags, 0	; Clear all flags.
;
;	If 795 chip is present then use the Ring Empty logic available.
;
		test	[ebp].board_id, NIC_SUPERSET
		jz	GetTxBufferCnt

		or	[ebp].lmac_flags, USE_RE_BIT	; 795s use RE bit
;
;	Set the number of transmit buffers.  8k = 1, 16k = 2, 32k = 3
;
GetTxBufferCnt:
		cmp	[ebp].ram_usable, 8
		ja	CheckRam16Size
		mov	[ebp].num_of_tx_buffs, 1
		jmp	GotTxBufferCnt

CheckRam16Size:		
		cmp	[ebp].ram_usable, 16
		ja	SetRam32Size
		mov	[ebp].num_of_tx_buffs, 2
		jmp	GotTxBufferCnt

SetRam32Size:		
		mov	[ebp].num_of_tx_buffs, 3

GotTxBufferCnt:
		mov	bx, [ebp].max_packet_size
		add	bx, 0ffh
		xor	bl, bl

		xor	eax, eax		; Assume offset 0

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	ChkOffsetPcmcia			; JIF not

		mov	ax, [ebp].ram_usable
		mov	cl, 10
		shl	ax, cl
		movzx	ecx, [ebp].num_of_tx_buffs

FigureInitialOffset:
		sub	ax, bx
		loop	FigureInitialOffset
		mov	[ebp].pstop_hold, ah

ChkOffsetPcmcia:
		cmp	[ebp].pc_bus, PCMCIA_BUS
		jne	DontChangeOffset
		mov	ax, SHMEM_NIC_OFFSET

DontChangeOffset:
		movzx	ecx, [ebp].num_of_tx_buffs
		push	edi
		lea	edi, [ebp].tx_buffer
AddTXBufSize:
		mov	word ptr [edi], ax
		add	ax, bx
		add	edi, 4
		loop	AddTXBufSize

		mov	[ebp].tx_pstop, ah
		mov	[ebp].tx_head, 0
		mov	[ebp].tx_tail, 0
		mov	[ebp].tx_count, 0
		mov	[ebp].tx_retry, DEFAULT_TX_RETRIES
		mov	[ebp].xmit_threshold, DEFAULT_ETX_VALUE


		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	LeaveETXEnabled			; JIF yes
;
; Disable ETX if adapter is in an 8 bit slot.
;
		test	[ebp].extra_info, SLOT_16BIT
		jnz	LeaveETXEnabled
		mov	[ebp].xmit_threshold, 700h		; Disable ETX if adapter is in an 8 bit slot.

LeaveETXEnabled:
		lea	edi, [ebp].bc_add
		mov	ax, 0FFFFh
		stosw
		stosw
		stosw
		mov	al, 01
		stosb
		pop	edi

		call	reset_nic
		call	load_node_address

;-------------- Initialize LAAR register and associated vars...

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Init_Laar			; JIF not

		mov	dx, [ebp].io_base
		add	dx, REG_BPR
		in	al, dx
		and	al, not BPR_M16EN

		test    [ebp].extra_info, SLOT_16BIT
		jz      UseIo8Mode
		or	al, BPR_M16EN
UseIo8Mode:
 		out	dx, al
		jmp	DoRamTest


MM_Init_Laar:
		test	[ebp].extra_info, NIC_790_BIT
		jz	SkipIoPipeDisable
;
; Indicate to LMAC that memory is to disabled when not in 16 bit mode.
; Required for 790 device. Not required for 795. 
;
		or	[ebp].lmac_flags, MEM_DISABLE

		test	[ebp].board_id, NIC_SUPERSET
		jz	SkipIoPipeDisable
;
; Mem disable patch is not required for 795.
;
		and	[ebp].lmac_flags, not MEM_DISABLE

		mov     dx, [ebp].io_base
		add	dx, REG_INTCR
		in	al, dx
		and	al, not INTCR_IOPE
		out	dx, al		; Disable IO pipe on 795s

SkipIoPipeDisable:
		movzx	edx, [ebp].io_base
		add	dx, REG_LAAR
		mov	al, INIT_LAAR_VALUE
		mov	[ebp].laar_enter, al
		mov	[ebp].laar_exit, al

		test	[ebp].board_id, BOARD_16BIT
		jnz	CheckPCMCIA
		test	[ebp].board_id, INTERFACE_CHIP
		jnz	LM_InitGotLaar
		mov	ecx, 3
		mov	ax, word ptr [ebp].ram_base+2
		shl	ax, cl
		mov	bl, al
		mov	ax, word ptr [ebp].ram_base
		mov	ecx, 13
		shr	ax, cl
		or	al, bl
		or	al, MSR_MENB
		mov	[ebp].laar_enter, al
		mov	[ebp].laar_exit, al
		jmp	DoRamTest

CheckPCMCIA:
		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	DoRamTest

		test	[ebp].board_id, MICROCHANNEL
		jz	CheckInterfaceChip
		mov	al, 0
		jmp	LM_InitGotLaar

CheckInterfaceChip:
		test	[ebp].board_id, INTERFACE_CHIP
		jz	LM_InitComputeLaar

		in	al, dx
		jmp	CheckSlot16

LM_InitComputeLaar:
		mov	ax, word ptr [ebp].ram_base+2
		mov	ecx, 3
		shr	ax, cl
		or	al, INIT_LAAR_VALUE
CheckSlot16:
		test	[ebp].extra_info, NIC_790_BIT
		jnz	SkipLan16
		or	al, LAAR_L16E
SkipLan16:
		test	[ebp].extra_info, SLOT_16BIT
		jz	LM_InitNot16Slot
		or	al, LAAR_M16E
		jmp	LM_InitGotLaar
LM_InitNot16Slot:
		cmp	[ebp].irq_value, 8
		jl	LM_InitGotLaar
		mov	eax, SELF_TEST_FAILED
		jmp	LM_Init_Return
LM_InitGotLaar:		
		mov	[ebp].laar_enter, al
		and	al, not LAAR_M16E
		mov	[ebp].laar_exit, al
		out	dx, al
DoRamTest:
		call	TestAdapterRam
		cmp	eax, SUCCESS
		je	LM_Init_RAM_OK

		mov	[ebp].adapter_status, FAILED
		jmp	LM_Init_Return
LM_Init_RAM_OK:
		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Erx_Init			; JIF yes

		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	SkipEarlyRxInit

Erx_Init:
		mov	dx, [ebp].io_base
		add	dx, REG_ERWCNT
		mov	al, DEFAULT_ERX_VALUE
		mov	[ebp].rx_lookahead_size, al
		out	dx, al				; 
		mov	[ebp].early_rx_slope, 255
;;;####		call	InitEarlyRx			; Calibrate Erx slope.

SkipEarlyRxInit:

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Init_Nic			; JIF not

		call    init_nic
		and	[ebp].adapter_flags, not RX_VALID_LOOKAHEAD + FORCED_16BIT_MODE
		jmp	SkipForcedInit

MM_Init_Nic:
		call	init_nic
		call	SetLookAheadMode
		test	[ebp].adapter_flags, FORCED_16BIT_MODE
		jz	SkipForcedInit
		or	[ebp].laar_exit, LAAR_M16E
SkipForcedInit:
		call	InitErrorCounters

		mov	[ebp].adapter_status, INITIALIZED
		call	LM_Enable_Adapter

LM_Init_Return:
		ret
InitAdapter	endp


;****************************************************************************
;
; Function:	AutoMediaDetect
;
; Synopis:	The purpose of this function is to sense which type
;		of media connector is active and disable or enable the
;		DC/DC power supply accordingly.
;
;		The variable media_set is updated to reflect media
;		detection.  The EEPROM is not updated.  This is a temporary
;		runtime feature only.
;
; Input:	None
;
; Output:	media_set = Type of media that is active.
;
; Modified:	media_set
;
; Notes:	Starlan-10 is not supported with the Auto Media Detect
;		feature.  If Starlan-10 is desired then select it with EZ.
;
;		This feature is for the 790/795 or later boards.  The 690
;		board was inconsistent with its interrupt and transmit
;		status reporting.  There was no way to be 100% sure of
;		a correct media detection.
;
;****************************************************************************

public	AutoMediaDetect

AutoMediaDetect	proc	near
	push	ax			; 1+ Save Registers
	push	bx			; 2+
	push	cx			; 3+
	push	dx			; 4+

	mov	ax, [ebp].mode_bits	; AX = mode_bits
	test	ax, AUTO_MEDIA_DETECT	; Do Auto Detect?
	jz	AMD_Exit		; JIF no

	test	[ebp].extra_info, NIC_790_BIT	; 790/795?
	jz	AMD_Exit			; JIF yes
;
;	Check the "media_opts" for the factory installed board media
;	options.  This are valid only for 795 boards or later.  If the
;	media_opts field is not used, check the board_id media type.
;
	mov	ax, [ebp].media_opts	;
	or	ax, ax			; Any Media Options?
	jz	Chk_BoardId		; JIF none

	test	ax, MED_OPT_BNC		; BNC Connector?
	jz	AMD_Exit		; JIF none, power is already off

	test	ax, MED_OPT_AUI		; BNC and AUI?
	jnz	Chk_Combo		; JIF yes, see if combo card

	test	ax, MED_OPT_UTP		; BNC and UTP?
	jnz	Chk_LinkStatus		; JIF yes

	jmp	AMD_Exit		; BNC only, power is already on

Chk_Combo:
	test	ax, MED_OPT_UTP		; BNC, UTP, and AUI?
	jnz	Chk_LinkStatus_Xmit	; JIF yes, test combo card

	jmp	Chk_Xmit		; BNC and AUI card


Chk_BoardId:
;
;	No media options available, so check the board ID.
;
	mov	ax, [ebp].board_id	; Check Board ID Media types
	and	ax, MEDIA_MASK		; Isolate media info

	cmp	ax, TWISTED_PAIR_MEDIA	; AUI and UPT?
	je	AMD_Exit		; JIF yes, BNC is off

	cmp	ax, ETHERNET_MEDIA	; BNC and AUI?
	je	Chk_Xmit		; JIF yes

	cmp	ax, EW_MEDIA		; BNC, AUI, and UTP?
	je	Chk_LinkStatus_Xmit	; JIF yes

	jmp	AMD_Exit		; All have failed, no change


Chk_LinkStatus:
	call	GetLinkStatus		; Check for link integrity on UTP
	jmp	short AMD_Exit		; Exit, BNC set up in function


Chk_LinkStatus_Xmit:
	call	GetLinkStatus			; Check for Link Integrity
	test	[ebp].media_set, MED_OPT_UTP	; on UTP.
	jnz	AMD_Exit			; JIF UTP active
					; Else fall thru for Combo board test

Chk_Xmit:				; BNC and AUI on Combo
	call	XmitTest		; Transmit dummy frame for BNC test


AMD_Exit:
	pop	dx			; 4- Restore registers
	pop	cx			; 3-
	pop	bx			; 2-
	pop	ax			; 1-
	ret				; Exit
AutoMediaDetect	endp


;****************************************************************************
;
; Function:	GetLinkStatus
;
; Synopis:	The purpose of this function is to test the Link
;		Integrity status on a UTP connection.
;
;		If the UTP connection is active, the BNC will be turned off;
;		Otherwise, the BNC will be turned on.
;
;		If an AUI is also present and the link status is not
;		active, the other media types will be tested in the
;		"Chk_Xmit" function.
;
; Input:	None
;
; Output:	If Link Status is high, UTP is active, BNC = OFF.
;		If Link Status is low, UTP is not active, BNC = ON.
;
;		The variable media_set will reflect the UTP status and be
;		set accordingly.
;
;			If (UTP active)
;				media_set = MED_OPT_UTP
;			else
;				media_set = MED_OPT_BNC
;
; Modified:	AX,BX,DX
;
; Notes:	None
;
;****************************************************************************

GetLinkStatus	proc	near
ifndef	NT_CODE
	pushf				; Save flags
	cli				; Disable ints
endif

	call	DisableLoopback		; Disable the loopback bit in TCR reg
	push	bx			; 2a+  Save original TCR state

	call	LM_Disable_Adapter	; Disable int from NIC

	call	LinkStatus_585		; 790/795 boards, 585

	and	[ebp].media_set, not (MED_OPT_BNC+MED_OPT_UTP+MED_OPT_AUI)
	or	[ebp].media_set, bx

	call	LM_Enable_Adapter	; Enable int from NIC

	pop	bx			; 2a-  BL = Initial TCR state
	call	RestoreTcrReg		; Restore TCR state

ifndef	NT_CODE
	popf
endif
	ret				; Exit
GetLinkStatus	endp


;****************************************************************************
;
; Function:	LinkStatus_585
;
; Synopis:	Test the Link Integrity Status on the 585 chip.
;
; Input:	None
;
; Output:	If Link Status is high, UTP is active, BNC = OFF.
;		If Link Status is low, UTP is not active, BNC = ON.
;
;		BX = media_set bit values for BNC and UTP only.
;
; Modified:	AX,BX,DX
;
; Notes:	None
;
;****************************************************************************

LinkStatus_585	proc	near

	mov	bx, MED_OPT_UTP		; Init media_set = UTP

	mov	ah, BNC_585_OFF		; Turn off BNC to test Link Status
	call	BNC_585_On_Off		;

	mov	dx, [ebp].io_base	; Select I/O base
	add	dx, REG_CMD		; Select Command register
	mov	al, CMD_PAGE3		; Select page 3
	out	dx, al			; Set new page

	add	dx, REG_MANCH - REG_CMD	; 10BaseT status register
	in	al, dx			; Get Link Integrity Status
	push	ax			; 1a+  Save Link Status

	add	dx, REG_CMD - REG_MANCH	; Select Command register
	mov	al, CMD_PAGE0		; Select page 0
	out	dx, al			; Set new page

	pop	ax			; 1a-  Restore Link Status
	test	al, MANCH_LLED		; Link (status) Integrity present?
	jnz	LS_Exit			; JIF yes, UTP active, leave BNC OFF

	mov	ah, BNC_585_ON		; UTP NOT active, so enable BNC power
	call	BNC_585_On_Off		;

	mov	bx, MED_OPT_BNC		; Adjust media_set = BNC

LS_Exit:
	ret				; Exit
LinkStatus_585	endp


;****************************************************************************
;
; Function:	BNC_585_On_Off
;
; Synopis:	Turn On/Off the power for the BNC connector.
;
; Input:	AH = BNC power enable/disable bit set/reset.
;
; Output:	BNC power set accordingly.
;
; Modified:	AX,DX
;
; Notes:	None
;
;****************************************************************************

BNC_585_On_Off	proc	near
	push	dx			; 1+

	mov	dx, [ebp].io_base		; Select I/O base
	add	dx, REG_HWR		; Hardware Support Register

	in	al, dx			;
	and	al, 0C3h		; Write mask
	or	al, HWR_SWH		; Config Registers bit
	out	dx, al			;

	add	dx, REG_GCR - REG_HWR	; General Control Register
	in	al, dx			; Get current state
	and	al, not GCR_GPOUT	; Mask the BNC power bit
	or	al, ah			; Set desired state
	out	dx, al			; Enable new state

	add	dx, REG_HWR-REG_GCR	; Hardware Support Register
	xor	al, al			; AL = Reset
	out	dx, al			; Restore original REG_HWR

	pop	dx			; 1-
	ret
BNC_585_On_Off	endp


;****************************************************************************
;
; Function:	XmitTest
;
; Synopis:	The purpose of this function is to transmit data using
;		the BNC port and determine if the BNC, AUI, or (UTP for
;		Starlan 10) is active.
;
; Input:	None
;
; Output:	BNC is turned on if the BNC link is active.
;		BNC is turned off if the BNC link is not active.
;
; Modified:	AX,BX,CX,DX,DI
;
; Notes:
;
;****************************************************************************

dummy_frame	label	word
		db	00h,00h,0C0h,00h,00h,00h		;  6
		db	00h,00h,0C0h,00h,00h,00h		;  6
		db	'SMC Auto Media Detect Test Frame.'		; 33
		db	' Thank you for using SMC products.'		; 34
		db	' -WSKRTDDZPMBGSFMTJGVP-'			; 23
DUMMY_LEN	equ	$ - dummy_frame



XmitTest	proc	near
	push	ecx			; 1+
	push	esi			; 2+
	push	edi			; 3+

ifndef	NT_CODE
	pushf				; 4+ Save flags
	cli				; Disable ints
endif

	call	DisableLoopback		; Disable Loopback setting
	push	bx			; 5a+ Save TCR state

	call	LM_Disable_Adapter	; Disable int from NIC

	mov	ah, BNC_585_OFF		; Disable power to 585 BNC
	call	BNC_585_On_Off

	mov	ecx, DUMMY_LEN		; Transmit 32 words of data
	shr	cx, 1

	test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
	jz	MM_Build			; JIF not

	mov	dx, [ebp].io_base		; Set I/O base address
	add	dx, REG_IOPA			; I/O pipe offset address

	mov	ax, word ptr [ebp].tx_buffer	; EDI -> Shared RAM Dest
	out	dx, al				; LSB
	xchg	al, ah				; MSB
	out	dx, al				; Set the frame RAM offset

	add	dx, REG_IOPD-REG_IOPA	; Select the data pipe I/O register

	mov	esi, offset dummy_frame	; DS:SI -> Dummy frame to xmit

	rep	outsw			; Word I/O move

	jmp	XmitBuiltFrame		; Go transmit the frame


MM_Build:
;
;	Memory mapped portion to build the frame in shared RAM.
;
	mov	eax, [ebp].ram_access		; EAX -> Shared RAM Dest addr
	xor	edi, edi
	mov	di, word ptr [ebp].tx_buffer	; EDI -> Shared RAM Dest
	add	edi, eax

	call	AccessSharedRam		; Turn on the RAM if 790 chip

	mov	esi, offset dummy_frame	; ESI -> Dummy frame to xmit

	rep	movsw			; Word move

	call	DeAccessSharedRam	; Turn off the RAM if 790 chip


XmitBuiltFrame:
	call	XmitDummy		; Transmit the dummy frame with
					; max collisions timeout (300ms)
	mov	cx, MED_OPT_AUI		; Assume media_set = AUI

	test	al, TSR_CRS		; Carrier sense lost?
	jz	XmitTestExit		; JIF no, AUI active, Turn BNC ON

	mov	ah, BNC_585_ON		; Select BNC ON
	call	BNC_585_On_Off		; Disable BNC power
	mov	cx, MED_OPT_BNC		; media_set = BNC active

XmitTestExit:
	and	[ebp].media_set, not (MED_OPT_BNC+MED_OPT_UTP+MED_OPT_AUI)
	or	[ebp].media_set, cx

	call	LM_Enable_Adapter	; Enable int from NIC

	pop	bx			; 5a-  BL = Initial TCR state
	call	RestoreTcrReg		; Restore TCR state

ifndef	NT_CODE
	popf				; 4-
endif

	pop	edi			; 3-
	pop	esi			; 2-
	pop	ecx			; 1-
	ret				; Exit
XmitTest	endp


;****************************************************************************
;
; Function:	XmitDummy
;
; Synopis:	Transmit the dummy frame once and check status
;
; Input:	None
;
; Output:	AL = interrupt status state
;
; Modified:	AX,CX,DX
;
; Notes:	None
;
;****************************************************************************

XmitDummy	proc	near
	push	bx			; 1+ Save iteration flag
	push	cx			; 2+ Save media type

	mov	cx, 400h		; Dummy frame length must be this
					; for accurate results.
	mov	dx, [ebp].io_base	; Seclect the base I/O address
	add	dx, REG_ISR		; Set to Transmit status register
	mov	al, 0FFh		; Clear interrupt status register
	out	dx, al			;

	add	dx, REG_TPSR - REG_ISR		; Select xmit Page Start Reg
	mov	ax, word ptr [ebp].tx_buffer	; AX = offset of xmit buffer
	xchg	al, ah				; Get 256 boundary offset
	out	dx, al				; Set buffer offset

	add	dx, REG_TBCR0 - REG_TPSR	; CX = Frame size to write
	mov	al, cl				; Low byte to TBCR0
	out	dx, al				;

	add	dx, REG_TBCR1 - REG_TBCR0	; CX = Frame size to write
	mov	al, ch				; High byte to TBCR1
	out	dx, al				;

	add	dx, REG_CMD - REG_TBCR1		; Select Command register
	mov	al, CMD_STA+CMD_TXP		; Initiate transmit
	out	dx, al				; Send the frame
;
;	Check transmission status of the frame.
;
	add	dx, REG_ISR - REG_CMD	; Select interrupt status reg
	mov	bx, 3			; Outer loop = 300ms total

SetupLoopCnt:				; Pseudo deadman floating face down
	mov	cx, 0FFFFh		; Loop count = 64k

TestLoop:
	in	al, dx			; Get interrupt status
	or	al, al
	loopz	TestLoop		; Loop if nothing

	or	al, al			; Status yet? 
	jnz	XmitDummyExit		; JIF yes

	dec	bx			; Next timeout iteration
	jnz	SetupLoopCnt		;


XmitDummyExit:
	mov	ah, al			; AH = Interrupt status
	add	dx, REG_TSR - REG_ISR	;
	in	al, dx			; AL = Transmit status

	pop	cx			; 2- Restore media type
	pop	bx			; 1- Restore iteration flag
	ret				; Exit
XmitDummy	endp


;****************************************************************************
;
; Function:	DisableLoopback
;
; Synopis:	Disable loopback mode so a dummy packet can be transmitted.
;		The loopback mode normally does not get disabled until
;		LM_Open_Adapter is called.
;
; Input:	None
;
; Output:	Bl = current TCR register state.
;
; Modified:	AX,BX,DX
;
; Notes:	None
;
;****************************************************************************

DisableLoopback	proc	near

	mov	dx, [ebp].io_base		; Select I/O base
	add	dx, REG_CMD		; Select Command register
	mov	al, CMD_PAGE2		; Select page 2 to read TCR reg
	out	dx, al			; Set new page

	add	dx, REG_TCR - REG_CMD	; Get TCR register contents
	in	al, dx			; 
	mov	bl, al			; BL = TCR current state

	add	dx, REG_CMD - REG_TCR	; Select Command register
	mov	al, CMD_PAGE0		; Select page 3 for Manchester Reg
	out	dx, al			; Set new page

	add	dx, REG_TCR - REG_CMD	; Disable loopback mode
	xor	al, al			; Normal mode (no loopback)
	out	dx, al			; Set mode

	ret				; Exit
DisableLoopback	endp


;****************************************************************************
;
; Function:	RestoreTcrReg
;
; Synopis:	Restore TCR register back to its original state.
;
; Input:	BL = TCR register state.
;
; Output:	None
;
; Modified:	AX,DX
;
; Notes:	None
;
;****************************************************************************

RestoreTcrReg	proc	near

	mov	dx, [ebp].io_base	; Select I/O base
	add	dx, REG_TCR		; Select TCR register
	mov	al, bl			; Get original state
	out	dx, al			; Set state

	ret				; Exit
RestoreTcrReg	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Set_Funct_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Set_Funct_Address
ifdef	LARGE
LM_Set_Funct_Address	proc	far
else
LM_Set_Funct_Address	proc	near	
endif
		mov	eax, INVALID_FUNCTION
		ret
LM_Set_Funct_Address	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Delete_Group_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Delete_Group_Address
ifdef	LARGE
LM_Delete_Group_Address	proc	far
else
LM_Delete_Group_Address	proc	near	
endif
		mov	eax, INVALID_FUNCTION
		ret
LM_Delete_Group_Address	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Set_Group_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Set_Group_Address
ifdef	LARGE
LM_Set_Group_Address	proc	far
else
LM_Set_Group_Address	proc	near	
endif
		mov	eax, INVALID_FUNCTION
		ret
LM_Set_Group_Address	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Change_Receive_Mask
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Change_Receive_Mask
ifdef	LARGE
LM_Change_Receive_Mask	proc	far
else
LM_Change_Receive_Mask	proc	near	
endif
		push	ebx
		push	edx
		push	edi
ifndef	NT_CODE
		pushf
		cli
endif
		mov	edi, [ebp].ram_access
		cmp	[ebp].adapter_status, NOT_INITIALIZED
		jne	LM_Ch_Stat_ok
		mov	eax, ADAPTER_NOT_INITIALIZED
		jmp	LM_Ch_Msk_Done
LM_Ch_Stat_ok:
		cmp	[ebp].pc_bus, PCMCIA_BUS
		jne	SetRecMask99
		mov	byte ptr [edi+REG_OFFSET+REG_CMD], CMD_PAGE0
		jmp	SetRecMask98
SetRecMask99:
		mov	dx, [ebp].io_base
		add	dx, REG_CMD
		mov	al, CMD_PAGE0
		out	dx, al		; Select page 0
		jmp	$+2
		add	dx, REG_RCR - REG_CMD
SetRecMask98:
		mov	al, 0

		test	[ebp].receive_mask, TRANSMIT_ONLY	; Frank H. 09-28-92
		jz	SetRecMask00				; Frank H. 09-28-92
		or	al, RCR_MON				; Frank H. 09-28-92

SetRecMask00:	test	[ebp].receive_mask, ACCEPT_MULTICAST
		jz	SetRecMask01
		or	al, RCR_AM

SetRecMask01:	test	[ebp].receive_mask, ACCEPT_BROADCAST
		jz	SetRecMask02
		or	al, RCR_AB

SetRecMask02:	test	[ebp].receive_mask, PROMISCUOUS_MODE
		jz	SetRecMask03
		or	al, RCR_PRO+RCR_AM+RCR_AB

SetRecMask03:	test	[ebp].receive_mask, ACCEPT_ERR_PACKETS
		jz	SetRecMask13
		or	al, RCR_AR+RCR_SEP

SetRecMask13:	test	[ebp].receive_mask, ACCEPT_MULTI_PROM
		jz	SetRecMask04
		or	al, RCR_AM+RCR_AB

SetRecMask04:	
		mov	bl, 0			; Set initial MAR value to 0
		test	al, RCR_AM
		jz	SetRecMask05
		mov	bl, 0ffh
SetRecMask05:	
		call	set_MARs

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetRcrValue			; JIF yes

		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	SaveRcrValue

SetRcrValue:
		or	al, RCR_SEP		; We must save errored frames for early Rx.
SaveRcrValue:
		mov	[ebp].rcr_hold, al ; Save result as rcr_hold

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetRecMask97			; JIF yes

		cmp	[ebp].pc_bus, PCMCIA_BUS
		jne	SetRecMask97
		mov	[edi+REG_OFFSET+REG_RCR], al
		jmp	SetRecMaskSuccess

SetRecMask97:
		out	dx, al			; Write REG_RCR

SetIntMaskRegister:
		or	[ebp].adapter_flags, ERX_DISABLED
		mov	al, IMR_PRXE+IMR_PTXE+IMR_RXEE+IMR_TXEE+IMR_OVWE

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Check_Erx			; JIF yes

		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	NoERXE

Check_Erx:
		test	[ebp].receive_mask, EARLY_RX_ENABLE
		jz	NoERXE
		or	al, IMR_ERWE
		and	[ebp].adapter_flags, not ERX_DISABLED
NoERXE:
		mov	[ebp].imr_hold, al

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Store_Rec_Mask			; JIF yes

		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	SetPcmIMR

Store_Rec_Mask:
		mov	dx, [ebp].io_base
		add	dx, REG_IMR
		out	dx, al
		jmp	SetRecMaskSuccess

SetPcmIMR:
		mov	[edi+REG_OFFSET+REG_IMR], al

SetRecMaskSuccess:
		mov	eax, SUCCESS

LM_Ch_Msk_Done:
ifndef	NT_CODE
		popf
endif
		pop	edi
		pop	edx
		pop	ebx
		ret

LM_Change_Receive_Mask	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Send	ESI	ptr to data buffer structure
;		EBP	ptr to adapter structure
;		ECX	Transmit byte count
;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUBLIC	LM_Send
ifdef	LARGE
LM_Send proc	far
else
LM_Send proc	near	
endif
		push	ebx
		push	ecx
		push	edx
		push	edi
		push	esi
ifndef	NT_CODE
		pushf
		cli
endif
		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	DoNotDisableAdapter
		mov	dx, [ebp].io_base
		add	dx, REG_INTCR
		in	al, dx
		and	al, not INTCR_EIL
		out	dx, al
DoNotDisableAdapter:
		mov	al, [ebp].tx_count
		cmp	al, byte ptr [ebp].num_of_tx_buffs
		mov	eax, OUT_OF_RESOURCES
		jne	ContinueLM_Send
		jmp	LM_Send_done
ContinueLM_Send:
; update the pointer

		push	esi
		xor	eax, eax
		mov	al, [ebp].tx_tail
		push	eax
		inc	al
		cmp	al, byte ptr [ebp].num_of_tx_buffs
		jne	tx_tail_ok
		xor	al, al
tx_tail_ok:
		mov	[ebp].tx_tail, al
		inc	[ebp].tx_count
		pop	esi
		
; point ax to correct buffer offset in adapterstructure
		shl	esi, 1
		shl	esi, 1
		mov	word ptr [ebp+esi].tx_buffer+2, cx
		movzx	ebx, word ptr [ebp+esi].tx_buffer

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	DontAdjustOffset		; JIF yes
;
; Put adapter in 16 bit mode . . .
;
		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	SkipMem16Enable

		call	AccessSharedRam

		jmp	DontAdjustOffset
SkipMem16Enable:
		sub	ebx, SHMEM_NIC_OFFSET

DontAdjustOffset:
		mov	eax, ebx
		pop	esi

		call	buff_struct_to_ram

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SkipLaarExit			; JIF yes

		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	SkipLaarExit

		call	DeAccessSharedRam

SkipLaarExit:
; if this is the only queued packet, send it
		cmp	[ebp].tx_count, 1
		jne	skip_send

		test	[ebp].adapter_flags, EARLY_TX		; Do not send frame if it
		jnz	skip_send				; was already sent in
		call	SendPacket
skip_send:
		mov	eax, SUCCESS
		and	[ebp].adapter_flags, not EARLY_TX

LM_Send_done:
		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	DontEnable790IntLine
		test	[ebp].adapter_flags, ADAPTER_DISABLED	; [2] If the adapter was disabled by a call
		jnz	DontEnable790IntLine			; to LM_Disable_Adapter, don't enable int line on 790.
		push	ax
		mov	dx, [ebp].io_base
		add	dx, REG_INTCR
		in	al, dx
		or	al, INTCR_EIL
		out	dx, al
		pop	ax

DontEnable790IntLine:

ifndef	NT_CODE
		popf
endif
		pop	esi
		pop	edi
		pop	edx
		pop	ecx
		pop	ebx
		ret
LM_Send endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Add_Multi_Address	Adds Multicast address in adapter structure to
;				Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Add_Multi_Address
ifdef	LARGE
LM_Add_Multi_Address	proc	far
else
LM_Add_Multi_Address	proc	near	
endif
		push	ebx
		push	ecx
		push	edi
		push	esi
		cld

		xor	ecx, ecx		; Clear ECX
		mov	eax, SUCCESS		; Preset return code
		lea	edi, [ebp].mc_table
		mov	ecx, MC_TABLE_ENTRIES	; CL == max number of
						; entries in table
AroundTheWorld:
		lea	esi, [ebp].multi_address
		push	edi
		push	ecx
		mov	ecx, 6
		repz	cmpsb
		pop	ecx
		pop	edi
		jnz	DoYerNeighbor
		cmp	byte ptr [edi+6], 0ffh	; If instance count >= 0ffh,
						; entry is maxed out.
		je	McTableFull
		inc	byte ptr [edi+6]	; Increment instance_count
		jmp	AddMultiDone		; All Done

DoYerNeighbor:	add	edi, 7			; Point to next address
		loop	AroundTheWorld		; Check all addresses.
						; No match found, find
						; first empty table entry
		mov	ecx, MC_TABLE_ENTRIES	; and insert address there
		lea	edi, [ebp].mc_table

CheckForEmpty:	mov	bl, [edi+6]		; Check instance count for
		cmp	bl, 0			; this address.
		je	add_address		; If instance count == 0
						; copy address to this space.
		add	edi, 7			; Point to next address
		loop	CheckForEmpty		; Loop for all entries.
		jmp	McTableFull		; If no empty entries, bail out

add_address:	lea	esi, [ebp].multi_address
		mov	ecx, 6
		rep	movsb
		inc	byte ptr [di]		; Increment instance_count
		jmp	AddMultiDone

McTableFull:	mov	eax, OUT_OF_RESOURCES

AddMultiDone:
		pop	esi
		pop	edi
		pop	ecx
		pop	ebx

		ret
LM_Add_Multi_Address	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Delete_Multi_Address Removes Multicast address in adapter
;					structure from Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Delete_Multi_Address
ifdef	LARGE
LM_Delete_Multi_Address proc	far
else
LM_Delete_Multi_Address proc	near	
endif
		push	ecx
		push	edi
		push	esi
		cld

		mov	eax, SUCCESS		; Preset return code
		lea	edi, [ebp].mc_table
		mov	ecx, MC_TABLE_ENTRIES

FrootLoop:	lea	esi, [ebp].multi_address
		push	edi
		push	ecx
		mov	ecx, 6
		repz	cmpsb
		pop	ecx
		pop	edi
		jnz	TryNextDoor
		cmp	byte ptr [edi+6], 0h	; If instance count = 0h,
						; entry is alrady gone.
		je	McTableEmpty
		dec	byte ptr [edi+6]	 ; Decrement instance_count
		jmp	DeleteMultiDone	 ; All Done

TryNextDoor:	add	edi, 7			; Point to next address
		loop	FrootLoop		; Check all addresses
						; If all entries checked and
						; no matches, bail out.

McTableEmpty:	mov	eax, OUT_OF_RESOURCES

DeleteMultiDone:
		pop	esi
		pop	edi
		pop	ecx

		ret
LM_Delete_Multi_Address endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;		buff_struct_to_ram (With Early Transmit)
;
;		EAX	Offset in physical shared RAM address
;		ESI	Pointer to buffer structure
;		EBP	Pointer to adapter structure
;		ECX	Transmit frame size
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


PUBLIC	buff_struct_to_ram
buff_struct_to_ram	proc	near

		push	ebx
		push	ecx
		push	ebp

		cld				; Make sure we increment
ifndef	NT_CODE
		cli				; Make sure ints are disabled.
endif
		mov	edi, [ebp].ram_access
		add	edi, eax		; EDI is offset

		mov	[ebp].leftover_count, 0
		mov	[ebp].split_word, 0
		mov	[ebp].early_xmit_flags, 0


		test	[ebp].adapter_flags, IO_MAPPED	; I/O?
		jz	MM_Check790			; JIF not

		mov	dx, [ebp].io_base
		add	dx, REG_IOPA		; EAX has the offset
		out	dx, al
		mov	al, ah
		out	dx, al			; Write packet ram offset to 795.
		jmp	CheckXmitBuffers

MM_Check790:
		cmp	[ebp].nic_type, NIC_790_CHIP
		jne	XmitterBusy		; Do not do Early Tx on other than 790s

CheckXmitBuffers:
		cmp	[ebp].tx_count, 1
		jne	XmitterBusy		; Do not do Early Tx if other buffers are
						; allocated.
		mov	dx, [ebp].io_base
		add	dx, REG_CMD
		in	al, dx
		test	al, CMD_TXP
		jnz	XmitterBusy

		mov	al, CMD_ENETCH		; Enable early xmit check so that
		out	dx, al			; the addresses of the writes to memory
						; that follow will get latched in the chip.

		or	[ebp].early_xmit_flags, 1	; Indicates that xmitter is not busy.
		jmp	GetFragCount
XmitterBusy:
		mov	[ebp].early_xmit_flags, 04h
GetFragCount:
		xor	eax, eax			; AX used for total byte count
		mov	edx, [esi].fragment_count
		lea	ebx, [esi].fragment_list
fragment_loop:
		test	word ptr [ebp].adapter_flags, IO_MAPPED	; I/O?
		jz	GetFragLen				; JIF not

		push	edx
		mov	dx, [ebp].io_base
		add	dx, REG_IOPD

GetFragLen:
		mov	ecx, [ebx].fragment_length
		or	ecx, ecx
		jnz	DoThisFrag
		jmp	check_for_more_frags

DoThisFrag:
		mov	esi, [ebx].fragment_ptr
		add	eax, ecx		; 
		test	[ebp].early_xmit_flags, 04h
		jnz	CopyData		; We have already passed the threshold once.
		cmp	eax, [ebp].xmit_threshold
		jbe	CopyData
		push	eax
		sub	eax, [ebp].xmit_threshold
		sub	ecx, eax
		mov	[ebp].leftover_count, eax
		pop	eax
		or	word ptr [ebp].early_xmit_flags, 2

CopyData:
		test	word ptr [ebp].split_word, 0FF00h
		jz	NoLeftover
		push	eax
		mov	ax, [ebp].split_word
		mov	ah, byte ptr [esi]
		inc	esi

		test	[ebp].adapter_flags, IO_MAPPED  ; I/O?
		jz	MM_StoreWord				  ; JIF not

		out	dx, ax
		jmp	AdjustCount

MM_StoreWord:
		stosw

AdjustCount:
		dec	ecx
		pop	eax
NoLeftover:
		test	[ebp].adapter_flags, IO_MAPPED	; I/O?
		jz	MM_MoveWord			; JIF not

		shr	ecx, 1
		jz	short_fragment
		rep	outsw
		jmp	short_fragment

MM_MoveWord:
		test	edi, 1
		jz	EvenBoundary

		push	eax
		dec	edi			; Point back to last even boundary.
		mov	ax, [edi]		; Read back word containing lo byte.
		mov	ah, [esi]		; Fill hi byte with next data byte.
		stosw				; Write word back to shared memory.
		inc	esi			; Keep pointers in sync.
		dec	ecx			; Decrement byte count.
		pop	eax
EvenBoundary:
		shr	ecx, 1			;and divide in half for WORDS
		jz	short_fragment

		pushf				; Save carry flag from 1st shr ECX.

		test	edi, 2			; Make sure were on dword boundary before movsd.
		jz	DoubleEvenBoundary
		movsw				; Move one WORD.
		dec	ecx			; Decrement WORD count
DoubleEvenBoundary:

		shr	ecx, 1			; Convert word count to dword count.
		rep	movsd
		jnc	NoOddWord2
		movsw
NoOddWord2:	
		popf

short_fragment:
		jnc	ShowNoLeftover
		push	eax
		mov	al, byte ptr [esi]
		mov	ah, 0FFh
		mov	[ebp].split_word, ax
		pop	eax
		jmp	check_for_more_frags
ShowNoLeftover:
		and	word ptr [ebp].split_word, 0FFh
check_for_more_frags:
		cmp	word ptr [ebp].early_xmit_flags, 3
		jne	BypassEarlyXmit
		or	[ebp].adapter_flags, EARLY_TX
		call	SendPacket
		mov	[ebp].early_xmit_flags, 04h

BypassEarlyXmit:
		mov	ecx, [ebp].leftover_count
		or	ecx, ecx
		je	NoPartialFragment
		mov	[ebp].leftover_count, 0
		jmp	CopyData

NoPartialFragment:
		test	[ebp].adapter_flags, IO_MAPPED	; I/O?
		jz	MM_SkipPop			; JIF not

		pop	edx

MM_SkipPop:
		add	ebx, size FragmentStructure
		dec	edx
		jz	CheckStrayByte
		jmp	fragment_loop

CheckStrayByte:
		mov	ax, [ebp].split_word
		test	ah, 0FFh
		jz	NoStrayByte

		test	[ebp].adapter_flags, IO_MAPPED ; I/O?
		jz	MM_SaveStray				 ; JIF not

		mov	dx, [ebp].io_base
		add	dx, REG_IOPD
		out	dx, ax
		jmp	NoStrayByte		; Done with I/O section

MM_SaveStray:
		stosw

NoStrayByte:
		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	BuffStructExit

		mov	dx, [ebp].io_base
		add	dx, REG_CMD
		mov	al, CMD_DISETCH
		out	dx, al

BuffStructExit:
		pop	ebp
		pop	ecx
		pop	ebx
		ret
buff_struct_to_ram	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	CheckMultiAdd	Compares the address indicated by ES:SI to
;			all addresses in the adapter structure multicast
;			table, and the braodcast address located at BC_ADD
;			in the adapter structure.
;
;	RETURN:	EAX == SUCCESS if a match was found,
;		EAX == OUT_OF_RESOURCES if no match was found.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CheckMultiAdd	proc	near
			push	esi
			push	edi
			push	edx
			push	ecx
			push	ebx
			pushf

			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_CheckMemEnable		; JIF not

			mov	dx, [ebp].io_base
			add	dx, REG_IOPA
			mov	ax, si
			add	ax, NIC_HEADER_SIZE
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA

			mov	cx, 6
			lea	edi, [ebp].temp_addr

			push	edi
			rep	insb
			pop	edi

			jmp	MemsNotDisabled99	;

MM_CheckMemEnable:

ifndef	NT_CODE
			cli
endif
			call	AccessSharedRam

MemsNotDisabled99:
			mov	ecx, MC_TABLE_ENTRIES+1	; # of MC table entries
							; + broadcast address
							; entry.

			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jnz	CheckBroadcast			; JIF yes

			mov	edi, esi
			add	edi, NIC_HEADER_SIZE ; ESI->dest. add.

CheckBroadcast:
			lea	esi, [ebp].bc_add	; Start with b'cast
			test	[ebp].receive_mask, ACCEPT_BROADCAST
			jnz	DontSkipBCAdd
			dec	ecx			; Decrement entry cnt
			lea	esi, [ebp].mc_table	; Skip b'cast entry
DontSkipBCAdd:
			cld

GoopLoop:		push	esi
			push	edi
			push	ecx
			mov	ecx, 6
			repz	cmpsb
			pop	ecx
			pop	edi
			pop	esi
			jnz	TryNextAdd
			cmp	byte ptr [esi+6], 0h	; If inst. count = 0,
							; entry is invalid.
			je	AddHas0Cnt
			mov	ebx, SUCCESS
			jmp	CheckMADone	; All Done

TryNextAdd:		add	esi, 7		; Point to next address
			loop	GoopLoop	; Check all addresses
						; If all entries checked and
						; no matches, bail out.

AddHas0Cnt:		mov	ebx, OUT_OF_RESOURCES

CheckMADone:
			test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
			jnz	CMA_Exit			; JIF yes

			call	DeAccessSharedRam

CMA_Exit:
			popf				; Restore flags.
			mov	eax, ebx		; Get return code into AX
			pop	ebx		
			pop	ecx
			pop	edx
			pop	edi
			pop	esi
			ret
CheckMultiAdd		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; TestAdapterRam	Performs two tests:
;			1) Tests RAM space for RAM and ROM
;			2) If test #1 passes, enables RAM and tests
;				RAM integrity.
;
;	On Call:	EBP -> to Adapter Structure
;
;	Return:		AX = Return Code
;
;				Return Codes:
;				SUCCESS
;				RAM_TEST_FAILED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	TestAdapterRam
TestAdapterRam	proc	near

ifndef	NT_CODE
		pushf				; 1+
		cli
endif
		push	ebx			; 2+
		push	ecx			; 3+
		push	edx			; 4+
		push	edi			; 5+

		mov	edi, [ebp].ram_access
		movzx	ebx, [ebp].ram_usable
		mov	ecx, 10
		shl	ebx, cl
		mov	ecx, ebx

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	InitTestPattern			; JIF yes

		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	InitTestPattern
		call	disable_ram

TestROMSignature:
		mov	ax, [edi]
		cmp	ax, ROM_SIGNATURE
		jne	NotARom
		jmp	GotROMSignature
NotARom:
		sub	ecx, MIN_ROM_SIZE
		jecxz	PassedROMTest
		add	edi, MIN_ROM_SIZE
		jmp	TestROMSignature
PassedROMTest:
		mov	ax, RAM_PATTERN_1
StartSpaceTest:
		mov	edi, [ebp].ram_access
		mov	ecx, ebx	; Get RAM window size in CX
		shr	ecx, 1		; Divide by two for words.
VerifySpace:
		mov	dx, [edi]	; Save original word
					; in case of failure
		stosw						
		cmp	ax, [edi-2]
		je	FailedSpaceVerify
		loop	VerifySpace

		cmp	ax, RAM_PATTERN_1
		jne	SpacePatternTwo
		mov	ax, RAM_PATTERN_2
		jmp	StartSpaceTest
SpacePatternTwo:
		cmp	ax, RAM_PATTERN_2
		jne	TestRAM
		mov	ax, RAM_PATTERN_3
		jmp	StartSpaceTest
TestRAM:		
		mov	dx, [ebp].io_base
		add	dx, REG_LAAR
		mov	al, [ebp].laar_enter
		out	dx, al
		jmp	$+2			; Delay needed for 790 XB to ensure
		in	al, dx			; that adapter is in 16 bit mode.

		call	enable_ram

InitTestPattern:
		mov	ax, RAM_PATTERN_1

RamTestLoop:
		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_StartRamTest			; JIF no

		push	ecx		; 6+ Save RAM Size

		mov	bx, ax		; Get test pattern in BX.
		mov	di, 0		; Start with offset 0.
		mov	dx, [ebp].io_base
		add	dx, REG_INTCR
		in	al, dx
		or	al, INTCR_IOPE
		out	dx, al		; Enable IO pipe

		add	dx, REG_UBRCV - REG_INTCR
		in	al, dx
		and	al, not UBRCV_WREN
		out	dx, al		; Disable ring-wrap stuff

		add	dx, REG_IOPA - REG_UBRCV
		mov	ax, di
		out	dx, al
		mov	al, ah
		out	dx, al		; Set up IO pipe address
		add	dx, REG_IOPD - REG_IOPA
		mov	ax, bx		; Get test pattern back into AX.
;
;	Main test loop.
;
VerifyRAM:
		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_CmpValue			; JIF not

		out	dx, ax
		add	dx, REG_IOPA - REG_IOPD
		mov	ax, di
		inc	di
		inc	di		; Set up new address
		out	dx, al

		mov	al, ah
		out	dx, al

		add	dx, REG_IOPD - REG_IOPA
		in	ax, dx		; Read back what was written previously
		push	ax		; 7+ Save read value
		add	dx, REG_IOPA - REG_IOPD
		mov	ax, di		; Get new address
		out	dx, al
		mov	al, ah
		out	dx, al
		add	dx, REG_IOPD - REG_IOPA
		pop	ax		; 7-

		cmp	ax, bx
		jmp	ChkRamTestError

MM_StartRamTest:
		mov	edi, [ebp].ram_access
		mov	ecx, ebx		; Get RAM window size in CX
		shr	ecx, 1			; Divide by two for words.

MM_CmpValue:
		stosw
		cmp	ax, [edi-2]

ChkRamTestError:
		jne	FailedRAMVerify
		loop	VerifyRAM

		cmp	ax, RAM_PATTERN_1
		jne	RamPatternTwo
		mov	ax, RAM_PATTERN_2

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_StartRamTest			; JIF no to MM test

		pop	ecx			; Restore loop counter

		jmp	RamTestLoop		; Back to top of the loop

RamPatternTwo:			 
		cmp	ax, RAM_PATTERN_2
		jne	RamTestSuccess

		mov	ax, RAM_PATTERN_3

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_StartRamTest			; JIF no to MM test

		pop	ecx			; Restore loop counter
		jmp	RamTestLoop		; Back to top of the loop

RamTestSuccess:			 
		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	SetReturnCode			; JIF no

		pop	ecx			; 6- Balance the stack

SetReturnCode:
		mov	eax, SUCCESS
		jmp	RAMTestDone


FailedSpaceVerify:
		mov	[edi-2], dx
		mov	eax, RAM_CONFLICT
		jmp	RAMTestDone

FailedRAMVerify:
		mov	eax, RAM_TEST_FAILED

		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jz	RAMTestDone			; JIF no

		pop	ecx			; 6- Balance the stack
		jmp	RAMTestDone

GotROMSignature:
		mov	eax, ROM_CONFLICT

RAMTestDone:
		test	[ebp].adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	PopNGo				; JIF yes

		push	eax
		cmp	[ebp].pc_bus, PCMCIA_BUS
		je	ExitRAMTest

		call	DeAccessSharedRam

ExitRAMTest:
		pop	eax

PopNGo:
		pop	edi
		pop	edx
		pop	ecx
		pop	ebx
ifndef	NT_CODE
		popf
endif
		ret	
TestAdapterRam	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AccessSharedRam		proc	near

			push	ax
			push	dx

			mov	dx, [ebp].io_base
			add	dx, REG_LAAR
			mov	al, [ebp].laar_enter
			out	dx, al
			jmp	$+2
			in	al, dx			; Read back REG_LAAR because
							; 790 cant get into 16 bit mode
							; in time.
			test	[ebp].lmac_flags, MEM_DISABLE
;;;			test	[ebp].extra_info, NIC_790_BIT
			jz	SkipMemSwitch30

			mov	dx, [ebp].io_base
			mov	al, MSR_MENB
			out	dx, al
			in	al, dx
SkipMemSwitch30:
			pop	dx
			pop	ax
			ret

AccessSharedRam		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DeAccessSharedRam		proc	near

			push	ax
			push	dx

			mov	dx, [ebp].io_base
			test	[ebp].lmac_flags, MEM_DISABLE
;;;			test	[ebp].extra_info, NIC_790_BIT
			jz	SkipMemSwitch40
			mov	al, 0
			out	dx, al
			in	al, dx			; Disable RAM if 790.
SkipMemSwitch40:
			add	dx, REG_LAAR
			mov	al, [ebp].laar_exit
			out	dx, al
			jmp	$+2
			in	al, dx			; Read back REG_LAAR because
							; 790 cant get into 16 bit mode
							; in time.
			pop	dx
			pop	ax
			ret

DeAccessSharedRam		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	InitErrorCounters	Initializes error counters to point to
;				[ebp].dummy_vector if they are not
;				initialized by UMAC.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

InitErrorCounters	proc	near
		push	eax
		push	ebx
		push	ecx
		push	esi

		lea	ebx, [ebp].ptr_rx_CRC_errors	; Get address of first counter.
		lea	ecx, [ebp].ptr_ring_OVW		; Get address of last counter.
		sub	ecx, ebx			; Subtract to get difference.
		shr	ecx, 1				; Divide by 4.
		shr	ecx, 1				; CX = # of counters.
		inc	ecx

		mov	esi, ebx
		lea	ebx, [ebp].dummy_vector		; EBX = offset of dummy vector.
							; ESI = offset of first counter.
CheckVectors:
		cmp	dword ptr [esi], 0
		jnz	SkipThisVector			; If null, fill with dummy vector.
		mov	[esi], ebx
SkipThisVector:
		add	si, 4
		loop	CheckVectors

		pop	esi
		pop	ecx
		pop	ebx
		pop	eax

		ret
InitErrorCounters	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;	InitEarlyRx	Initializes and calibrates Early Receive slope value.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PUBLIC	InitEarlyRx
;InitEarlyRx	proc	near
;
;		push	ebx
;		push	ecx
;		push	edx
;		push	edi
;		push	esi
;
;		cmp	esi, 0
;		jnz	ValidScratchPad
;		mov	ax, cs:MaxErxValue
;		mov	[ebp].early_rx_slope, ax
;		jmp	EarlyRxExit
;ValidScratchPad:
;		mov	ecx, 3			; Repeat test 3 times.
;		mov	[ebp].early_rx_slope, 0
;TestErxSlope:
;		push	esi
;		push	ecx			; Save loop count.
;		pushf
;
;		cld				; Clear direction flag.
;ifndef	NT_CODE
;		cli				; Disable CPU ints
;endif
;		mov	bx, LPBK_FRAME_SIZE	; Keep frame size in BX
;		mov	edi, esi		; Save ptr to scratch pad in DI.
;
;		call	reset_nic
;		call	init_nic
;
;		mov	dx, [ebp].io_base
;		add	dx, REG_BPR
;		mov	al, [ebp].laar_enter
;		out	dx, al
;		jmp	$+2
;		in	al, dx
;
;		mov	dx, [ebp].io_base
;RestartTest:
;		mov	esi, [ebp].ram_access
;		add	dx, REG_TCR
;
;		mov	al, TCR_LB0		; Place NIC in mode 1 loopback
;		out	dx, al
;		add	dx, REG_TBCR0 - REG_TCR	; Initialize xmt byte count & page start regs.
;		mov	ax, bx			; Get size of frame in AX.
;		out	dx, al
;		add	dx, REG_TBCR1 - REG_TBCR0
;		mov	al, ah
;		out	dx, al
;		add	dx, REG_TPSR - REG_TBCR1
;		mov	al, 0
;		out	dx, al
;
;		add	dx, REG_ISR - REG_TPSR
;		mov	al, 0FFh
;		out	dx, al
;		add	dx, REG_CMD - REG_ISR	; Xmit loopback packet
;		mov	al, CMD_STA + CMD_TXP + CMD_DISETCH
;
;		push	edi
;		push	ebx
;		pushf
;		cli				; Disable CPU ints.
;		mov	ebx, 5			; Do 5 iterations of 100 words each.
;		out	dx, al			; Initiate transmit.
;		add	dx, REG_ISR - REG_CMD
;ContinueLoop:
;		mov	ecx, 50				; Move 100 16-bit words.
;		rep	movsd				; Each move is 2 words.
;		sub	edi, 200			; Reset ptr. to start of scratch pad.
;		dec	ebx
;		jnz	ContinueLoop
;
;		in	al, dx
;		mov	ah, al
;		popf
;		pop	ebx
;		pop	edi
;
;		test	ah, ISR_PTX
;		jnz	ERX_TestDone
;WaitForXmitCompletion:
;		in	al, dx
;		test	al, ISR_PTX
;		jz	WaitForXmitCompletion
;		sub	ebx, 8
;		sub	dx, REG_ISR
;		jmp	RestartTest
;ERX_TestDone:
;		mov	al, 0FFh
;		out	dx, al			; Clear any ints.
;
;		mov	edx, 0
;		mov	eax, 12500
;		div	bx			; AX = Bus speed in MB/s * 10
;		xor	ebx, ebx
;		mov	bx, ax			;
;		sub	bx, 13			; First entry in table is for 1.3 MBPS.
;		jns	WithinRange
;		mov	bx, 0			; Stay within range of table.
;WithinRange:
;		inc	bx			; Add 4 for safety.
;		inc	bx			;
;		inc	bx			;
;		inc	bx			;
;		cmp	bx, 28h
;		jbe	WithinRange2
;		mov	bx, 28h			; Stay within upper limit of table.
;WithinRange2:
;		shl	bx, 1			; Table is in words.
;		lea	esi, ErxSlopeTable
;		mov	ax, [ebx+esi]
;
;PUBLIC	CheckThisSlope
;CheckThisSlope:
;		cmp	ax, [ebp].early_rx_slope
;		jl	ThisPassWasSlower
;		mov	[ebp].early_rx_slope, ax
;ThisPassWasSlower:
;		mov	dx, [ebp].io_base
;		add	dx, REG_BPR
;		mov	al, [ebp].laar_exit
;		out	dx, al
;		jmp	$+2
;		in	al, dx
;
;		popf
;		pop	ecx
;		pop	esi
;		dec	ecx
;		jz	EarlyRxExit
;		jmp	TestErxSlope
;EarlyRxExit:
;		pop	esi
;		pop	edi
;		pop	edx
;		pop	ecx
;		pop	ebx
;		ret
;InitEarlyRx	endp
;
;; These values are derived from Dave Fischer's white paper dated 23 March 1993.
;ErxSlopeTable:
;	dw	19, 54,	85, 112, 135, 156, 175, 192, 207, 221, 233, 245, 255
;	dw	265, 274, 283, 291, 298, 305, 311, 318, 323, 329, 334, 339
;	dw	343, 347, 351, 355, 359, 363, 366, 369, 372, 375, 378, 381
;	dw	383, 386, 388
;; Last value in table must be accessed as separate variable.
;MaxErxValue	dw	391
;





































