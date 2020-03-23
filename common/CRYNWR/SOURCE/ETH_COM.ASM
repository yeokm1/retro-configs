;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         ETH_COM.ASM
;
; Description:  LMI lower routine assembly source file for all SMC 
;		PCM/(E)ISA/MCA Cards.
;
;********************
;* Revision History *
;********************
;
;  $Log:   G:\sweng\src\lmetha\vcs\eth_com.avm  $
;  
;     Rev 1.65   05 May 1995 11:14:14   COOKE_J
;  Changed version label to v2.03.
;  
;     Rev 1.64   01 May 1995 11:35:06   SOMALWAR
;  Changed version label only.
;  
;     Rev 1.63   10 Feb 1995 15:54:58   CHAN_M
;  Added minor changes for the 8416 hi performance driver
;  
;     Rev 1.62   28 Jan 1995 18:38:32   CHAN_M
;  Added extra code to support 2 transmit buffers for the 8416 turbo driver
;  
;     Rev 1.61   07 Jul 1994 16:43:02   wood_r
;  
;     Rev 1.60   07 Jul 1994 14:28:54   wood_r
;
; LM_8416_s2.1_v2.01
; Change:	Added the new Auto Media Detect feature.  The function
;		LM_Initialize_Adapter has been modified to be the control
;		shell for this new feature.
;		
;  
;     Rev 1.59   07 Jun 1994 13:58:56   WOOD_R
;  
;     Rev 1.58   07 Jun 1994 11:46:36   WOOD_R
;  
; LM_8016_s2.1_v2.02
;
; Bug Fix:	The TestAdpaterRam function was adjusting the start of
;		shared RAM (subtracting the 256 byte area) for a PCMCIA
;		adapter on each iteration of the test loop.  It should
;		have adjusted it only once before the test loop started.
;		It is now done outside the loop at TestPCMRam
;
;     Rev 1.57   16 May 1994 11:05:26   WOOD_R
;  case errors
;  
;     Rev 1.56   13 May 1994 13:22:00   WOOD_R
;  
;     Rev 1.55   12 May 1994 14:43:26   wood_r
;
; LM_8416_s2.1_v2.00b
;
; Change:	Modified the code to reduce the code space size for the
;		8416 "Dual Mode" driver.  The code to enable and disable
;		memory exclisively for the 790 chip was placed into two
;		subroutines: AccessSharedRam and DeAccessSharedRam.  This
;		is similar to the Flat Model code base.
;
; Bug Fix:	The TestAdpaterRam function was not saving the memory size
;		counter, cx, for the loop count. The loop was testing 64k
;		for all sizes of RAM after the first pattern is completed.
;		This was resolved by pushing and popping cx.
;
;     Rev 1.54   25 Apr 1994 17:09:34   wood_r
;  More case sensitive issues for NDIS2
;  
;     Rev 1.53   25 Apr 1994 08:44:20   wood_r
;  Case sensitive problems for NDIS2 were resolved
;  
;     Rev 1.52   21 Apr 1994 16:05:24   wood_r
;  Banner problems
;  
;     Rev 1.51   21 Apr 1994 15:04:12   wood_r
;  LM_8416_s2.1_v2.00a
;  
;     Rev 1.50   21 Apr 1994 14:59:28   wood_r
;
; Change:	This revision of the file will be the start of the next
;		generation of the Ethernet LMACs.  The version level will
;		be bumped from 1.xxx to 2.xxx.  The 1.xxx source code 
;		history was designed and developed by Mike Steiger.
;
;		The Ring Empty feature on the 795 was added to the code
;		base.  To implement this feature, a flag bit is used in the
;		adapter structure variable "lmac_flags".  The equate used
;		with this flag is USE_RE_BIT.  It is used in the function
;		LM_Initialize_Adapter to initialize the variable "lmac_flag".
;
;		The "Dual Mode" feature was added to the code base. The file
;		was modified to remove all IFxDEFS for I/O mapping (UBIO).
;		The driver now supports a dual mode of operation.  This is
;		implemented by using a flag bit in the adapter structure
;		variable "adapter_flags".  The equate used for this is
;		IO_MAPPED.
;
;		The Multicast 795 XB fix was tested and it seemed to be
;		functioning correctly.  Refer to the notes below for an
;		explanation and also in the file banner of etherest.asm.
;
;+!/? ***********************************************************************

;
;	Ethernet LMAC version label
;

db	'@(#) LM_8416_s2.1_v2.03',0,'$'

db	'SMC Ethernet Lower Driver ETH_COM.ASM $Revision:   1.65  $',0,'$'



ifndef	pAS
pAS	equ	ds:[bp]
endif

ifndef	pDS
pDS	equ	es:[si]
endif

IFDEF TURBO
TxDesc  struc
tx_offset       dw      ?
tx_size         dw      ?
tx_next         dw      ?
TxDesc  ends
extern	TxHead: word
extern	TxTail: word
extern	TxStart: word
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Enable_Adapter       Enables adapter whose adapter structure is
;                               indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Enable_Adapter
		push    dx

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	en_585_irq			; JIF yes

		mov     ax, pAS.extra_info
		and     ax, INTERFACE_CHIP_MASK

EnAdap01:       cmp     ax, INTERFACE_594_CHIP
		jne     EnAdap02
		call    enable_59x_irq
		mov     ax, SUCCESS
		jmp     LM_EnAdp_done

EnAdap02:       cmp     ax, INTERFACE_5X3_CHIP
		jne	EnAdap03
		mov     ax, pAS.board_id
		test    ax, MICROCHANNEL
		jz      EnAdap04
		test	ax, INTERFACE_CHIP	; If no interface chip, adapter is 8003ET/A
		jz	EnAdap04

		call    enable_59x_irq
		mov     ax, SUCCESS
		jmp     LM_EnAdp_done

EnAdap03:       
		cmp     ax, INTERFACE_585_CHIP
		jne     EnAdap04

en_585_irq:
		call    enable_585_irq
		mov     ax, SUCCESS
		jmp     LM_EnAdp_done

EnAdap04:       
IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     enableNonPCM
                call    PCM_enable_NIC_irq
                jmp     enableDone
enableNonPCM:
ENDIF
                call    enable_NIC_irq
enableDone:
		mov     ax, SUCCESS
		jmp     LM_EnAdp_done

LM_EnAdp_done:
		and	pAS.adapter_flags, not ADAPTER_DISABLED
		pop     dx
		ret

ASM_ETH_PROC_END	LM_Enable_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Disable_Adapter      Disables adapter whose adapter structure is
;                               indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Disable_Adapter

		push    dx

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	dis_585_irq			; JIF yes

		mov     ax, pAS.extra_info
		and     ax, INTERFACE_CHIP_MASK

DisAdap01:	cmp     ax, INTERFACE_594_CHIP
		jne     DisAdap02
		call    disable_59x_irq
		jmp	DisableDone

DisAdap02:      cmp     ax, INTERFACE_5X3_CHIP
		jne	DisAdap03
		mov     ax, pAS.board_id
		test    ax, MICROCHANNEL
		jz      DisAdap04
		test	ax, INTERFACE_CHIP	; If no interface chip, adapter is 8003ET/A
		jz	DisAdap04

		call    disable_59x_irq
		jmp	DisableDone

DisAdap03:	
		cmp     ax, INTERFACE_585_CHIP
		jne     DisAdap04

dis_585_irq:
		call    disable_585_irq
		jmp	DisableDone

DisAdap04:      
IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     DisableNonPCM
                call    PCM_disable_NIC_irq
                jmp     DisableDone
DisableNonPCM:
ENDIF
                call    disable_NIC_irq

DisableDone:
		mov     ax, SUCCESS
		or	pAS.adapter_flags, ADAPTER_DISABLED
		pop     dx
		ret

ASM_ETH_PROC_END	LM_Disable_Adapter


;****************************************************************************
;
; Function:	LM_Initialize_Adapter
;
; Synopis:	Entry point and control shell for initialization of the
;		adapter.
;
; Input:        DS:BP --> Adapter Structure
;
; Output:       AX = Initialization return code
;
; Modified:     None
;
; Notes:	None
;
;****************************************************************************

ASM_ETH_PROC	LM_Initialize_Adapter
	push    bx			; 1+ Save registers
	push    cx			; 2+
	push    dx			; 3+
	push    es			; 4+
	pushf				; 5+

ifndef	NC
	cli
endif

	call	InitAdapter		; Get adapter ready for AMD

	call	AutoMediaDetect		; Sense which connector is present

	call	InitAdapter		; Completely re-init the adapter

	push	ax			; 6a+
	call    UM_Status_Change	; Notify UMAC
	pop	ax			; 6a-
	
	$POPFF				; 5-
	pop     es			; 4-
	pop     dx			; 3-
	pop     cx			; 2-
	pop     bx			; 1-
	ret				; Exit
ASM_ETH_PROC_END	LM_Initialize_Adapter


;****************************************************************************
;
; Function:	InitAdapter
;
; Synopis:	Initialize the adapter to a known startup state.
;
; Input:        DS:BP --> Adapter Structure
;
; Output:       None
;
; Modified:     None
;
; Notes:	None
;
;****************************************************************************

InitAdapter	proc	near

		mov	pAS.packet_ptr, 0FFFFh	; Invalidate temp ptr.
		mov	pAS.lmac_flags, 0	; Clear all flags.

		test	pAS.board_id, NIC_SUPERSET
		jz	LmacFlagsSet

		or	pAS.lmac_flags, USE_RE_BIT	; 795s use RE bit
LmacFlagsSet:

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	resetNonPCM			; JIF yes, Skip PCM

IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     resetNonPCM
		call    PCM_reset_nic
		call    PCM_load_node_address
                jmp     GetTxBufferCount
ENDIF

resetNonPCM:
		call    reset_nic
		call    load_node_address

GetTxBufferCount:
		cmp	pAS.ram_usable, 8
		ja	CheckRam16Size
IFDEF TURBO
		mov	pAS.num_of_tx_buffs, 2
ELSE
		mov	pAS.num_of_tx_buffs, 1
ENDIF
		jmp	GotTxBufferCnt

CheckRam16Size:		
		cmp	pAS.ram_usable, 16
		ja	SetRam32Size
		mov	pAS.num_of_tx_buffs, 2
		jmp	GotTxBufferCnt

SetRam32Size:		
		mov	pAS.num_of_tx_buffs, 3

GotTxBufferCnt:
		mov     bx, pAS.max_packet_size
		add     bx, 0ffh
                xor     bl, bl

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	SetOffset0			; JIF not

		mov	ax, pAS.ram_usable
		mov	cl, 10
		shl	ax, cl
		mov     cx, pAS.num_of_tx_buffs

FigureInitialOffset:
		sub	ax, bx
		loop	FigureInitialOffset
		mov	pAS.pstop_hold, ah
IFDEF TURBO
		mov	cx, pAS.num_of_tx_buffs
		push	si
		push	ax
		mov	si, offset TxStart - SIZE TxDesc
		SetupTxDesc:
		add	si, SIZE TxDesc
		mov	byte ptr [si].tx_offset, ah
		mov	[si].tx_next, si
		add	[si].tx_next, SIZE TxDesc
		add	ah, 6
		loop	SetupTxDesc
		mov	[si].tx_next, offset TxStart
		mov	TxHead, offset TxStart
		mov	TxTail, offset TxStart
		pop	ax
		pop	si
ENDIF
		jmp	ChkOffsetPcmcia

SetOffset0:
	  	xor     ax, ax

ChkOffsetPcmcia:
		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	DontChangeOffset
		mov	ax, SHMEM_NIC_OFFSET

DontChangeOffset:
		mov     cx, pAS.num_of_tx_buffs
		push	es
                push    di
		lea	di, pAS.tx_buffer
AddTXBufSize:
		mov	word ptr [di], ax
                add     ax, bx
                add     di, 4
		loop    AddTXBufSize

		mov	pAS.tx_pstop, ah
		mov	pAS.tx_head, 0
		mov	pAS.tx_tail, 0
		mov	pAS.tx_count, 0
		mov	pAS.tx_retry, DEFAULT_TX_RETRIES
		mov	pAS.xmit_threshold, DEFAULT_ETX_VALUE


		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	LeaveETXEnabled			; JIF yes
;
; Disable ETX if adapter is in an 8 bit slot.
;
		test	pAS.extra_info, SLOT_16BIT
		jnz	LeaveETXEnabled
		mov	pAS.xmit_threshold, 700h	

LeaveETXEnabled:
		push	ds
		pop	es
		lea	di, pAS.bc_add
		mov	ax, 0FFFFh
		stosw
		stosw
		stosw
		mov	al, 01
		stosb
                pop     di
		pop	es


;-------------- Initialize LAAR register and associated vars...

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Init_Laar			; JIF not

		mov	dx, pAS.io_base
		add	dx, REG_BPR
		in	al, dx
		and	al, not BPR_M16EN

		test    pAS.extra_info, SLOT_16BIT
		jz      UseIo8Mode
		or	al, BPR_M16EN
UseIo8Mode:
 		out	dx, al
		in	al, dx
		test	pAS.extra_info, SLOT_16BIT
		jnz	Short_LM_InitGotLaar	; Kludge for long jump

		jmp	LM_InitNot16Slot

Short_LM_InitGotLaar:
		jmp	LM_InitGotLaar


MM_Init_Laar:
		test	pAS.extra_info, NIC_790_BIT
		jz	SkipIoPipeDisable
;
; Indicate to LMAC that memory is to disabled when not in 16 bit mode.
; Required for 790 device. Not required for 795. 
;
		or	pAS.lmac_flags, MEM_DISABLE

		test	pAS.board_id, NIC_SUPERSET
		jz	SkipIoPipeDisable
;
; Mem disable patch is not required for 795.
;
		and	pAS.lmac_flags, not MEM_DISABLE

		mov     dx, pAS.io_base
		add	dx, REG_INTCR
		in	al, dx
		and	al, not INTCR_IOPE
		out	dx, al		; Disable IO pipe on 795s

SkipIoPipeDisable:
		mov     dx, pAS.io_base
		add     dx, REG_LAAR
		mov	al, INIT_LAAR_VALUE
		mov	pAS.laar_enter, al
		mov	pAS.laar_exit, al

		test    pAS.board_id, BOARD_16BIT
		jnz	CheckPCMCIA
		test    pAS.board_id, INTERFACE_CHIP
		jnz	LM_InitGotLaar
		mov	cx, 3
		mov	ax, word ptr pAS.ram_base+2
		shl	ax, cl
		mov	bl, al
		mov	ax, word ptr pAS.ram_base
		mov	cx, 13
		shr	ax, cl
		or	al, bl
		or	al, MSR_MENB
		mov     pAS.laar_enter, al
		mov     pAS.laar_exit, al
		jmp	DoRamTest

CheckPCMCIA:
		cmp	pAS.pc_bus, PCMCIA_BUS
		je	DoRamTest

		test    pAS.board_id, MICROCHANNEL
		jz	CheckInterfaceChip
		mov	al, 0
		jmp	LM_InitGotLaar

CheckInterfaceChip:
		test    pAS.board_id, INTERFACE_CHIP
		jz	LM_InitComputeLaar

		in      al, dx
		jmp	CheckSlot16

LM_InitComputeLaar:
		mov	ax, word ptr pAS.ram_base+2
		mov     cx, 3
		shr     ax, cl
		or      al, INIT_LAAR_VALUE
CheckSlot16:
		test    pAS.extra_info, SLOT_16BIT
		jz      LM_InitNot16Slot
		or      al, LAAR_M16E
		test	pAS.extra_info, NIC_790_BIT
		jnz	LM_InitGotLaar
		or	al, LAAR_L16E
		jmp	LM_InitGotLaar

LM_InitNot16Slot:
		cmp	pAS.irq_value, 8
		jl	LM_InitGotLaar
		mov	ax, SELF_TEST_FAILED
		jmp	LM_Init_Return

LM_InitGotLaar:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	DoRamTest			; JIF yes

		mov     pAS.laar_enter, al
		and	al, not LAAR_M16E
		mov     pAS.laar_exit, al
		out     dx, al

DoRamTest:

ifndef	EZSTART
		call	TestAdapterRam
		cmp	ax, SUCCESS
		je	LM_Init_RAM_OK

		mov     pAS.adapter_status, FAILED
		jmp	LM_Init_Return
endif

LM_Init_RAM_OK:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Erx_Init			; JIF yes

		cmp	pAS.nic_type, NIC_790_CHIP
		jne	SkipEarlyRxInit

Erx_Init:
		mov	dx, pAS.io_base
		add	dx, REG_ERWCNT

		mov	al, DEFAULT_ERX_VALUE
		out	dx, al				; 

SkipEarlyRxInit:

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Init_Nic			; JIF not

		call    init_nic
		and	pAS.adapter_flags, not RX_VALID_LOOKAHEAD + FORCED_16BIT_MODE
		jmp	SkipForcedInit

MM_Init_Nic:

IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     initNonPCM
                call    PCM_init_nic
                jmp     initDone
initNonPCM:
ENDIF
		call    init_nic
initDone:
		call	SetLookAheadMode
		test	pAS.adapter_flags, FORCED_16BIT_MODE
		jz	SkipForcedInit
		or	pAS.laar_exit, LAAR_M16E

SkipForcedInit:
		call	InitErrorCounters
		mov     pAS.adapter_status, INITIALIZED

IFDEF   EZSTART
		call	ETH_LM_Enable_Adapter
ELSE
		call	LM_Enable_Adapter
ENDIF

LM_Init_Return:
		ret
InitAdapter	endp


;****************************************************************************
;
; Function:	AutoMediaDetect
;
; Synopis:	The purpose of this function is to sense which type
;		of media connector is active and disable or enable the
;		BNC DC/DC power supply accordingly.
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

	mov	ax, pAS.mode_bits	; AX = mode_bits
	test	ax, AUTO_MEDIA_DETECT	; Do Auto Detect?
	jz	AMD_Exit		; JIF no

	test	pAS.extra_info, NIC_790_BIT	; 790/795?
	jz	AMD_Exit			; JIF yes
;
;	Check the "media_opts" for the factory installed board media
;	options.  This are valid only for 795 boards or later.  If the
;	media_opts field is not used, check the board_id media type.
;
	mov	ax, pAS.media_opts	;
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
	mov	ax, pAS.board_id	; Check Board ID Media types
	and	ax, MEDIA_MASK		; Isolate media info

	cmp	ax, TWISTED_PAIR_MEDIA	; AUI and UTP?
	je	AMD_Exit		; JIF yes (BNC is off)

	cmp	ax, ETHERNET_MEDIA	; BNC and AUI?
	je	Chk_Xmit		; JIF yes

	cmp	ax, EW_MEDIA		; BNC, AUI, and UTP?
	je	Chk_LinkStatus_Xmit	; JIF yes

	jmp	AMD_Exit		; All have failed, no change


Chk_LinkStatus:				; This entry point is for UTP and BNC
	call	GetLinkStatus		; Check for link integrity on UTP
	jmp	short AMD_Exit		; BNC power is set in the function
					; Exit

Chk_LinkStatus_Xmit:			; This entry point is for a tri-con
	call	GetLinkStatus			; Check for Link Integrity
	test	pAS.media_set, MED_OPT_UTP	; on UTP.
	jnz	AMD_Exit			; JIF UTP active, else
					; Fall thru to distinguish AUI/BNC

Chk_Xmit:				; BNC/AUI/UTP combo type boards
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
; Output:	If Link Status is high, UTP is active, BNC power = OFF.
;		If Link Status is low, UTP is not active, BNC power = ON.
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
	pushf				; 1+ Save int flag and clear ints
ifndef	NC
	cli
endif
	call	DisableLoopback		; Disable the loopback bit in TCR reg
	push	bx			; 2a+  BX = original TCR state

	call	LM_Disable_Adapter	; Disable int from NIC

	call	LinkStatus_585		; 790/795 boards, 585

	and	pAS.media_set, not (MED_OPT_BNC+MED_OPT_UTP+MED_OPT_AUI)
	or	pAS.media_set, bx

	call	LM_Enable_Adapter	; Enable int from NIC

	pop	bx			; 2a-  BL = Initial TCR state
	call	RestoreTcrReg		; Restore TCR state

	$POPFF				; 1- Restore flags
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

	mov	ah, BNC_585_OFF		; Disable BNC power
	call	BNC_585_On_Off		;

	mov	dx, pAS.io_base		; Select I/O base
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
; Notes:	Starlan-10 is not supported with Auto Media Detect;
;		therefore, the link integrity bit will always be enabled
;		to guarantee correct functionality.
;
;****************************************************************************

BNC_585_On_Off	proc	near

	mov	dx, pAS.io_base		; Select I/O base
	add	dx, REG_HWR		; Hardware Support Register

	in	al, dx			;
	and	al, 0C3h		; Write mask
	or	al, HWR_SWH		; Config Registers bit
	out	dx, al			;

	add	dx, REG_GCR - REG_HWR	; General Control Register
	in	al, dx			; Get current state
	and	al, not GCR_GPOUT	; Disable BNC power
	or	ah, GCR_LITE		; Make sure S10 is OFF!
	or	al, ah			; Set new state
	out	dx, al			; Enable state

	add	dx, REG_HWR-REG_GCR	; Hardware Support Register
	xor	al, al			; AL = Reset
	out	dx, al			; Restore original REG_HWR

	ret				; Exit
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
		db	00h,00h,0C0h,00h,00h,00h			; 6
		db	00h,00h,0C0h,00h,00h,00h			; 6
		db	'SMC Auto Media Detect Test Frame.'		; 33
		db	' Thank you for using SMC products.'		; 34
		db	' -WSKRTDDZPMBGSFMTJGVP-'			; 23
DUMMY_LEN	equ	$ - dummy_frame



XmitTest	proc	near
	push	di			; 1+
	pushf				; 2+ Save int flag and clear ints
ifndef	NC
	cli
endif

	call	DisableLoopback		; Disable Loopback setting
	push	bx			; 3a+ Save TCR state

	call	LM_Disable_Adapter	; Disable int from NIC

	mov	ah, BNC_585_OFF		; Disable power to 585 BNC
	call	BNC_585_On_Off

	mov	cx, DUMMY_LEN		; Transmit 32 words of data
	shr	cx, 1

	test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
	jz	MM_Build			; JIF not

	mov	dx, pAS.io_base		; Set I/O base address
	add	dx, REG_IOPA		; I/O pipe offset address
	mov	di, word ptr ds:[bp].tx_buffer

	mov	ax, di			; AX = offset of frame
	out	dx, al			; LSB
	mov	al, ah			; MSB
	out	dx, al			; Set the frame RAM offset

	add	dx, REG_IOPD-REG_IOPA	; Select the data pipe I/O register

	push	ds			; 4a+

	mov	ax, cs			;
	mov	ds, ax			; Frame in code segment
	mov	si, offset dummy_frame	; DS:SI -> Dummy frame to xmit

	rep	outsw			; Word I/O move

	pop	ds			; 4a-

	jmp	XmitBuiltFrame		; Go transmit the frame


MM_Build:
;
;	Memory mapped portion to build the frame in shared RAM.
;
	mov	ax, pAS.ram_access.sgmt	; ES:DI -> Shared RAM Dest address
	mov	es, ax
	mov	di, word ptr ds:[bp].tx_buffer	; ES:DI -> Shared RAM Dest

	call	AccessSharedRam		; Turn on the RAM if 790 chip

	push	ds			; 4a+

	mov	ax, cs			;
	mov	ds, ax			; Frame in code segment
	mov	si, offset dummy_frame	; DS:SI -> Dummy frame to xmit

	rep	movsw			; Word move

	pop	ds			; 4a-

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
	and	pAS.media_set, not (MED_OPT_BNC+MED_OPT_UTP+MED_OPT_AUI)
	or	pAS.media_set, cx

	call	LM_Enable_Adapter	; Enable int from NIC

	pop	bx			; 3a-  BL = Initial TCR state
	call	RestoreTcrReg		; Restore TCR state

	$POPFF				; 2- Restore flags
	pop	di			; 1-
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
; Output:	AH = Interrupt status state
;		AL = Transmit status state
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
					; long for accurate results.
	mov	dx, pAS.io_base		; Seclect the base I/O address
	add	dx, REG_ISR		; Set to Transmit Status register
	mov	al, 0FFh		; Clear Interrupt Status register
	out	dx, al

	add	dx, REG_TPSR - REG_ISR		; Select xmit Page Start Reg
	mov	ax, word ptr ds:[bp].tx_buffer	; AX = offset of xmit buffer
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
	xor	cx, cx			; Loop count = 64k

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

	mov	dx, pAS.io_base		; Select I/O base
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

	mov	dx, pAS.io_base		; Select I/O base
	add	dx, REG_TCR		; Select TCR register
	mov	al, bl			; Get original state
	out	dx, al			; Set state

	ret				; Exit
RestoreTcrReg	endp




IFNDEF  EZSTART
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Set_Funct_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC  LM_Set_Funct_Address
ifdef   LARGE
LM_Set_Funct_Address    proc    far
else
LM_Set_Funct_Address    proc    near    
endif
		mov     ax, INVALID_FUNCTION
		ret
LM_Set_Funct_Address    endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Delete_Group_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC  LM_Delete_Group_Address
ifdef   LARGE
LM_Delete_Group_Address    proc    far
else
LM_Delete_Group_Address    proc    near    
endif
		mov     ax, INVALID_FUNCTION
		ret
LM_Delete_Group_Address    endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Set_Group_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC  LM_Set_Group_Address
ifdef   LARGE
LM_Set_Group_Address    proc    far
else
LM_Set_Group_Address    proc    near    
endif
		mov     ax, INVALID_FUNCTION
		ret
LM_Set_Group_Address    endp

ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Change_Receive_Mask
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Change_Receive_Mask

		push    bx
		push    dx
		push	es
		pushf
ifndef	NC
		cli
endif
		mov	es, word ptr pAS.ram_access+2
		cmp	pAS.adapter_status, NOT_INITIALIZED
		jne	LM_Ch_Stat_ok
		mov	ax, ADAPTER_NOT_INITIALIZED
		jmp	LM_Ch_Msk_Done
LM_Ch_Stat_ok:

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetRecMask99			; JIF yes

		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	SetRecMask99
		or	byte ptr es:[REG_OFFSET+REG_MSR], 02h		; Wake up NIC.
		mov	byte ptr es:[REG_OFFSET+REG_CMD], CMD_PAGE0
		jmp	SetRecMask98

SetRecMask99:
		mov     dx, pAS.io_base
		add     dx, REG_CMD
		mov     al, CMD_PAGE0
		out     dx, al          ; Select page 0
		jmp     $+2
		add     dx, REG_RCR - REG_CMD
SetRecMask98:
		mov     al, 0

		test    pAS.receive_mask, TRANSMIT_ONLY	; Frank H. 09-28-92
		jz      SetRecMask00				; Frank H. 09-28-92
		or      al, RCR_MON				; Frank H. 09-28-92

SetRecMask00:	test    pAS.receive_mask, ACCEPT_MULTICAST
		jz      SetRecMask01
		or      al, RCR_AM

SetRecMask01:   test    pAS.receive_mask, ACCEPT_BROADCAST
		jz      SetRecMask02
		or      al, RCR_AB

SetRecMask02:   test    pAS.receive_mask, PROMISCUOUS_MODE
		jz      SetRecMask03
		or      al, RCR_PRO+RCR_AM+RCR_AB

SetRecMask03:   test    pAS.receive_mask, ACCEPT_ERR_PACKETS
		jz      SetRecMask13
		or      al, RCR_AR+RCR_SEP

SetRecMask13:   test    pAS.receive_mask, ACCEPT_MULTI_PROM
		jz      SetRecMask04
		or      al, RCR_AM+RCR_AB
SetRecMask04:
;
;		On the 795 XA part the physical frame was recorded as a
;		multicast and the frame was being dropped.  This code
;		was awork around until the XB part was fixed.  Since the
;		code is innocuous, it has been decided to leave it as is for
;		now.
;
ifdef	MC_FIX

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Set_Mar			; JIF not

		or      al, RCR_AM
		jmp	FillErUp


MM_Set_Mar:
		mov     bl, 0                   ; Set initial MAR value to 0
		cmp	pAS.nic_type, NIC_790_CHIP
		jne	TestRxMaskBit
		test	pAS.board_id, NIC_SUPERSET
		jz	TestRxMaskBit
		or      al, RCR_AM
		jmp	FillErUp	; Always fill hash table with 1s on 795s due to bug
TestRxMaskBit:
		test    al, RCR_AM
		jz      SetRecMask05

FillErUp:

else						; MC_FIX
		mov     bl, 0                   ; Set initial MAR value to 0
		test    al, RCR_AM
		jz      SetRecMask05

endif						; MC_FIX


		mov     bl, 0ffh
SetRecMask05:   

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetMaskNonPCM			; JIF yes

IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     SetMaskNonPCM
                call    PCM_set_MARs
                jmp     SetRecMask06
ENDIF
SetMaskNonPCM:

                call    set_MARs

SetRecMask06:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetRcrValue			; JIF yes

		cmp	pAS.nic_type, NIC_790_CHIP
		jne	SaveRcrValue

SetRcrValue:
		or	al, RCR_SEP		; We must save errored frames for early Rx.

SaveRcrValue:
		mov     pAS.rcr_hold, al ; Save result as rcr_hold

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetRecMask97			; JIF yes

		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	SetRecMask97
		mov	es:[REG_OFFSET+REG_RCR], al
		jmp	SetIntMaskRegister

SetRecMask97:
		out     dx, al                  ; Write REG_RCR

SetIntMaskRegister:
		or	pAS.adapter_flags, ERX_DISABLED
		mov	al, IMR_PRXE+IMR_PTXE+IMR_RXEE+IMR_TXEE+IMR_OVWE

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Check_Erx			; JIF yes

		cmp	pAS.nic_type, NIC_790_CHIP
		jne	NoERXE

Check_Erx:
		test	pAS.receive_mask, EARLY_RX_ENABLE
		jz	NoERXE
		or	al, IMR_ERWE
		and	pAS.adapter_flags, not ERX_DISABLED
NoERXE:
		mov	pAS.imr_hold, al

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	Store_Rec_Mask			; JIF yes

		cmp	pAS.pc_bus, PCMCIA_BUS
		je	SetPcmIMR

Store_Rec_Mask:
		mov	dx, pAS.io_base
		add	dx, REG_IMR
		out	dx, al

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SetRecMaskSuccess		; JIF yes

		jmp	SetRecMaskSuccess
SetPcmIMR:
		mov	es:[REG_OFFSET+REG_IMR], al
;		and	byte ptr es:[REG_OFFSET+REG_MSR], 0FCh		; Put NIC to sleep.

SetRecMaskSuccess:
		mov     ax, SUCCESS
LM_Ch_Msk_Done:

		$POPFF
		pop	es
		pop     dx
		pop     bx
		ret

ASM_ETH_PROC_END	LM_Change_Receive_Mask

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Send         ES:SI	ptr to data buffer structure
;                       DS:BP	ptr to adapter structure
;			CX   	Transmit byte count
;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_ETH_PROC	LM_Send
IFNDEF TURBO
		push    bx
		push    cx
		push    dx
		push    di
		push    si
		push    ds
		push    es
		pushf
ifndef	NC
		cli
endif
		mov	al, pAS.tx_count
		cmp	al, byte ptr pAS.num_of_tx_buffs
		mov	ax, OUT_OF_RESOURCES
		jne	ContinueLM_Send
		jmp	LM_Send_done
ContinueLM_Send:
; update the pointer

                push    si
                xor     ax, ax
		mov	al, pAS.tx_tail
		push	ax
		inc	al
		cmp	al, byte ptr pAS.num_of_tx_buffs
		jne	tx_tail_ok
		xor     al, al
tx_tail_ok:
		mov	pAS.tx_tail, al
		inc	pAS.tx_count
		pop	si
;		
; AX -> to correct buffer offset in adapterstructure
;
                shl     si, 1
                shl     si, 1
		mov	word ptr ds:[bp+si].tx_buffer+2, cx
       		mov	bx, word ptr ds:[bp+si].tx_buffer


		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	DontAdjustOffset		; JIF yes
;
; Put adapter in 16 bit mode . . .
;
		cmp	pAS.pc_bus, PCMCIA_BUS
		je	SkipMem16Enable

		call	AccessSharedRam
		jmp	DontAdjustOffset

SkipMem16Enable:
;		sub	bx, SHMEM_NIC_OFFSET

DontAdjustOffset:
		mov	ax, bx
                pop     si

		call	buff_struct_to_ram

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	SkipLaarExit			; JIF yes

		cmp	pAS.pc_bus, PCMCIA_BUS
		je	SkipLaarExit

		call	DeAccessSharedRam

SkipLaarExit:

; if this is the only queued packet, send it
                cmp     pAS.tx_count, 1
                jne     skip_send
		test	pAS.adapter_flags, EARLY_TX		; Do not send frame if it
		jnz	skip_send				; was already sent in
								; buff_struct_to_ram.

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	sendNonPCM			; JIF yes

IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     sendNonPCM
                call    PCM_SendPacket
                jmp     skip_send
ENDIF

sendNonPCM:
                call	SendPacket

skip_send:
		mov	ax, SUCCESS
		and	pAS.adapter_flags, not EARLY_TX

LM_Send_done:
		$POPFF
		pop     es
		pop     ds
		pop     si
		pop     di
		pop     dx
		pop     cx
		pop     bx
		ret

ENDIF	; TURBO
ASM_ETH_PROC_END	LM_Send

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Add_Multi_Address    Adds Multicast address in adapter structure to
;                               Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC  LM_Add_Multi_Address
ifdef   LARGE
LM_Add_Multi_Address    proc    far
else
LM_Add_Multi_Address    proc    near    
endif
		push    bx
		push    cx
		push    di
		push    si
		push    es
		cld

		xor     cx, cx                  ; Clear CX
		mov     ax, SUCCESS             ; Preset return code
		push    ds
		pop     es                      ; ES = DS
		lea     di, pAS.mc_table
		mov     cx, MC_TABLE_ENTRIES    ; CL == max number of
						; entries in table
AroundTheWorld:
		lea     si, pAS.multi_address
		push    di
		push    cx
		mov     cx, 6
		repz    cmpsb
		pop     cx
		pop     di
		jnz     DoYerNeighbor
		cmp     byte ptr [di+6], 0ffh   ; If instance count >= 0ffh,
						; entry is maxed out.
		je      McTableFull
		inc     byte ptr [di+6]         ; Increment instance_count
		jmp     AddMultiDone            ; All Done

DoYerNeighbor:  add     di, 7                   ; Point to next address
		loop    AroundTheWorld          ; Check all addresses.
						; No match found, find
						; first empty table entry
		mov     cx, MC_TABLE_ENTRIES    ; and insert address there
		lea     di, pAS.mc_table

CheckForEmpty:  mov     bl, [di+6]              ; Check instance count for
		cmp     bl, 0                   ; this address.
		je      add_address             ; If instance count == 0
						; copy address to this space.
		add     di, 7                   ; Point to next address
		loop    CheckForEmpty           ; Loop for all entries.
		jmp     McTableFull             ; If no empty entries, bail out

add_address:    lea     si, pAS.multi_address
		mov     cx, 6
		rep     movsb
		inc     byte ptr [di]           ; Increment instance_count
		jmp     AddMultiDone

McTableFull:    mov     ax, OUT_OF_RESOURCES

AddMultiDone:
		pop     es
		pop     si
		pop     di
		pop     cx
		pop     bx

		ret
LM_Add_Multi_Address    endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Delete_Multi_Address Removes Multicast address in adapter
;                                       structure from Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC  LM_Delete_Multi_Address
ifdef   LARGE
LM_Delete_Multi_Address proc    far
else
LM_Delete_Multi_Address proc    near    
endif
		push    cx
		push    di
		push    si
		push    es
		cld

		mov     ax, SUCCESS             ; Preset return code
		push    ds
		pop     es                      ; ES = DS
		lea     di, pAS.mc_table
		mov     cx, MC_TABLE_ENTRIES

FrootLoop:      lea     si, pAS.multi_address
		push    di
		push    cx
		mov     cx, 6
		repz    cmpsb
		pop     cx
		pop     di
		jnz     TryNextDoor
		cmp     byte ptr [di+6], 0h     ; If instance count = 0h,
						; entry is alrady gone.
		je      McTableEmpty
		dec     byte ptr [di+6]         ; Decrement instance_count
		jmp     DeleteMultiDone         ; All Done

TryNextDoor:    add     di, 7                   ; Point to next address
		loop    FrootLoop               ; Check all addresses
						; If all entries checked and
						; no matches, bail out.

McTableEmpty:   mov     ax, OUT_OF_RESOURCES

DeleteMultiDone:
		pop     es
		pop     si
		pop     di
		pop     cx

		ret
LM_Delete_Multi_Address endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;		buff_struct_to_ram (With Early Transmit)
;
;		AX	Offset in physical shared RAM address
;		ES:SI	Pointer to buffer structure
;		DS:BP	Pointer to adapter structure
;		CX	Transmit frame size
;
; Equates for stack frame variable offsets used in buff_struct_to_ram.
; When adding stack vars, be sure to compensate for additional offset
; by adding additional offset to SP at the end of this routine. The
; amount added to SP should be 2 more than the highest offset listed below.

Base			equ	0
Threshold		equ	2
Leftover		equ	4
EarlyXmitFlag		equ	6
RamSeg			equ	8
TxCount			equ	10
SplitWord		equ	12
AdStrOff		equ	14
AdStrSeg		equ	16
t_adapter_flags		equ	18

StackFixOfst		equ	20	; Added to SP to flush stack vars.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


ifndef	EZSTART
PUBLIC	buff_struct_to_ram
endif
buff_struct_to_ram	proc	near

		push	ds
		push	bx
		push	cx
		push	bp

		cld				; Make sure we increment
ifndef	NC
		cli				; Make sure ints are disabled.
endif
		mov	di, ax			; di is offset

; Stash needed variables on stack because we cannot access them when src & dest ptrs are
; initialized.
		mov	ax, pAS.adapter_flags	; Save mode bits on stk. Use
		push	ax			; instead of pAS within fn.


		push	ds			; Save ptr to adapter structure
		push	bp
		xor	ax, ax
		push	ax			; SplitWord
		mov	al, pAS.tx_count
		push	ax
		mov	ax, pAS.ram_access.sgmt
		push	ax
		mov	ax, 0
		push	ax			; Space for EarlyXmitFlag
		push	ax			; Space for Leftover flag
		mov	ax, pAS.xmit_threshold

		push	ax			; Save xmit threshold
		mov	ax, pAS.io_base
		push	ax			; Save IO base
		mov	ax, pAS.nic_type	; Save for compare below.
		mov	bp, sp			; All vars are on stack now.

		test	word ptr [bp+t_adapter_flags], IO_MAPPED ; I/O?
		jz	MM_Check790				 ; JIF not

		mov	dx, [bp+Base]
		add	dx, REG_IOPA
		mov	ax, di
		out	dx, al
		mov	al, ah
		out	dx, al			; Write packet ram offset to 795.
		jmp	CheckXmitBuffers

MM_Check790:

		cmp	ax, NIC_790_CHIP
		jne	XmitterBusy		; Do not do Early Tx on other than 790s

CheckXmitBuffers:
		cmp	word ptr [bp+TxCount], 1
		jne	XmitterBusy		; Do not do Early Tx if other buffers are
						; allocated.
		mov	dx, [bp+Base]
		add	dx, REG_CMD
		in	al, dx
		test	al, CMD_TXP
		jnz	XmitterBusy

		mov	al, CMD_ENETCH		; Enable early xmit check so that
		out	dx, al			; the addresses of the writes to memory
						; that follow will get latched in the chip.

		or	word ptr [bp+EarlyXmitFlag], 1	; Indicates that xmitter is not busy.
		jmp	GetFragCount
XmitterBusy:
		mov	word ptr [bp+Threshold], -1	; Prevents count from ever reaching
GetFragCount:						; threshold.
		xor	ax, ax				; AX used for total byte count
		push	es
		pop	ds		; ES:DI ptr to shared ram
					; DS:SI ptr to data buffer structure
		mov	es, [bp+RamSeg]
		mov	dx, ds:[si].fragment_count
		lea	bx, ds:[si].fragment_list
fragment_loop:
		push	ds

		test	word ptr [bp+t_adapter_flags], IO_MAPPED ; I/O?
		jz	GetFragLen				 ; JIF not

		push	dx
		mov	dx, [bp+Base]
		add	dx, REG_IOPD

GetFragLen:
		mov	cx, ds:[bx].fragment_length
		jcxz	check_for_more_frags
		lds	si, ds:[bx].fragment_ptr

		add	ax, cx
		cmp	ax, [bp+Threshold]
		jbe	CopyData
		push	ax
		sub	ax, [bp+Threshold]
		sub	cx, ax
		mov	[bp+Leftover], ax
		pop	ax
		or	word ptr [bp+EarlyXmitFlag], 2
CopyData:
		test	word ptr [bp+SplitWord], 0FF00h
		jz	NoLeftover
		push	ax
		mov	ax, [bp+SplitWord]
		mov	ah, byte ptr [si]
		inc	si

		test	word ptr [bp+t_adapter_flags], IO_MAPPED  ; I/O?
		jz	MM_StoreWord				  ; JIF not

		out	dx, ax
		jmp	AdjustCount

MM_StoreWord:
		stosw

AdjustCount:
		dec	cx
		pop	ax
NoLeftover:
		shr	cx, 1			;and divide in half for words
		jz	ShortFragment

		pushf				; Flags saved from SHR
		test	word ptr [bp+t_adapter_flags], IO_MAPPED ; I/O?
		jz	MM_MoveWord				 ; JIF not

		rep	outsw
		$POPFF
		jmp	ShortFragment

MM_MoveWord:
		rep     movsw
		$POPFF

ShortFragment:
		jnc	ShowNoLeftover
		push	ax
		mov	al, byte ptr [si]
		mov	ah, 0FFh
		mov	[bp+SplitWord], ax
		pop	ax
		jmp	check_for_more_frags

ShowNoLeftover:
		and	word ptr [bp+SplitWord], 0FFh

check_for_more_frags:
		cmp	word ptr [bp+EarlyXmitFlag], 3
		jne	BypassEarlyXmit

		push	ds
		push	bp

		mov	ds, [bp+AdStrSeg]
		mov	bp, [bp+AdStrOff]
		or	pAS.adapter_flags, EARLY_TX

IFDEF   EZSTART
		cmp	pAS.pc_bus, PCMCIA_BUS
                jne     SendNonPCM
                call    PCM_SendPacket
                jmp     sendDone
SendNonPCM:
ENDIF

		call	SendPacket
sendDone:
		pop	bp
		pop	ds

		mov	word ptr [bp+EarlyXmitFlag], 0
		mov	word ptr [bp+Threshold], -1
BypassEarlyXmit:
		mov	cx, [bp+Leftover]
		or	cx, cx
		je	NoPartialFragment
		mov	word ptr [bp+Leftover], 0
		jmp	CopyData

NoPartialFragment:

		test	word ptr [bp+t_adapter_flags], IO_MAPPED ; I/O?
		jz	MM_SkipPop				 ; JIF not

		pop	dx

MM_SkipPop:
		pop	ds
		add	bx, size FragmentStructure
		dec	dx
		jz	CheckStrayByte
		jmp	fragment_loop

CheckStrayByte:
		mov	ax, [bp+SplitWord]
		test	ah, 0FFh
		jz	NoStrayByte

		test	word ptr [bp+t_adapter_flags], IO_MAPPED ; I/O?
		jz	MM_SaveStray				 ; JIF not

		mov	dx, [bp+Base]
		add	dx, REG_IOPD
		out	dx, ax
		jmp	NoStrayByte		; Done with I/O section

MM_SaveStray:
		stosw

NoStrayByte:
		mov	ds, [bp+AdStrSeg]
		mov	bp, [bp+AdStrOff]
		cmp	pAS.pc_bus, PCMCIA_BUS
		je	BuffStructExit

		mov	dx, pAS.io_base
		add	dx, REG_CMD
		mov	al, CMD_DISETCH
		out	dx, al

BuffStructExit:

		add	sp, StackFixOfst	; Flush stack vars.
		pop	bp
		pop	cx
		pop	bx
		pop	ds
		ret
buff_struct_to_ram	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       CheckMultiAdd   Compares the address indicated by ES:SI to
;                       all addresses in the adapter structure multicast
;                       table, and the braodcast address located at BC_ADD
;                       in the adapter structure.
;
;       RETURN:         AX == SUCCESS if a match was found,
;                       AX == OUT_OF_RESOURCES if no match was found.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
public CheckMultiAdd
ifdef   LARGE
CheckMultiAdd	proc    far
else
CheckMultiAdd	proc    near
endif

			push    si
			push    di
			push    ds
			push    es
			push    dx
			push    cx
			push    bx

			pushf				; Save flags


			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jz	MM_CheckMemEnable		; JIF not

			mov	dx, pAS.io_base
			add	dx, REG_IOPA
			mov	ax, si
			add	ax, NIC_HEADER_SIZE
			out	dx, al
			mov	al, ah
			out	dx, al
			add	dx, REG_IOPD - REG_IOPA
			mov	cx, 6
			lea	di, pAS.temp_addr
			push	ds
			pop	es
			push	di
			rep	insb
			pop	di
			jmp	MemsNotDisabled99	;

MM_CheckMemEnable:

ifndef	NC
			cli				; Disable ints
endif

			cmp	pAS.pc_bus, PCMCIA_BUS
			je	MemsNotDisabled99

			call	AccessSharedRam

MemsNotDisabled99:

			mov     cx, MC_TABLE_ENTRIES+1  ; # of MC table entries
							; + broadcast address
							; entry.

			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jnz	CheckBroadcast			; JIF yes

			mov     di, si
			add     di, NIC_HEADER_SIZE ;ES:SI->dest. add.

CheckBroadcast:
			lea     si, pAS.bc_add  ; Start with b'cast
			test    pAS.receive_mask, ACCEPT_BROADCAST
			jnz	DontSkipBCAdd
			dec	cx			; Decrement entry cnt
			lea     si, pAS.mc_table  ; Skip b'cast entry
DontSkipBCAdd:
			cld

GoopLoop:               push    si
			push    di
			push    cx
			mov     cx, 6
			repz    cmpsb
			pop     cx
			pop     di
			pop     si
			jnz     TryNextAdd
			cmp     byte ptr [si+6], 0h     ; If inst. count = 0,
							; entry is invalid.
			je      AddHas0Cnt
			mov     bx, SUCCESS
			jmp     CheckMADone     ; All Done

TryNextAdd:             add     si, 7           ; Point to next address
			loop    GoopLoop        ; Check all addresses
						; If all entries checked and
						; no matches, bail out.

AddHas0Cnt:             mov     bx, OUT_OF_RESOURCES

CheckMADone:
			test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
			jnz	BailCheckMultiAdd		; JIF yes
	
			cmp	pAS.pc_bus, PCMCIA_BUS
			je	BailCheckMultiAdd

			call	DeAccessSharedRam

BailCheckMultiAdd:
			$POPFF				; Restore flags.
			mov     ax, bx          	; Get return code into AX

			pop     bx              
			pop     cx
			pop     dx
			pop     es
			pop     ds
			pop     di
			pop     si
			ret
CheckMultiAdd           endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; TestAdapterRam	Performs two tests:
;			1) Tests RAM space for RAM and ROM
;			2) If test #1 passes, enables RAM and tests
;			   RAM integrity.
;
;	On Call:	DS:BP -> to Adapter Structure
;
;	Return:		AX = Return Code
;
;				Return Codes:
;				SUCCESS
;				RAM_TEST_FAILED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifndef	EZSTART
PUBLIC	TestAdapterRam
endif
TestAdapterRam	proc	near
		pushf 	    
ifndef	NC
		cli	    
endif
		push	bx
		push	cx
		push	dx
		push	di
		push	es

		mov	bx, pAS.ram_usable
		mov	cx, 10
		shl	bx, cl
		mov	cx, bx

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	TestPCMRam			; JIF yes

		mov	es, word ptr pAS.ram_access+2
		mov	di, word ptr pAS.ram_access
		cmp	pAS.pc_bus, PCMCIA_BUS
		je	TestPCMRam
		call	disable_ram
TestROMSignature:
       		mov	ax, es:[di]
		cmp	ax, ROM_SIGNATURE
		jne	NotARom
		jmp	GotROMSignature
NotARom:
		sub	cx, MIN_ROM_SIZE
		jcxz	PassedROMTest
		add	di, MIN_ROM_SIZE
		jmp	TestROMSignature
PassedROMTest:
		mov	ax, RAM_PATTERN_1

StartSpaceTest:
		mov	di, word ptr pAS.ram_access
		mov	cx, bx		; Get RAM window size in CX
		shr	cx, 1		; Divide by two for words.

VerifySpace:
		mov	dx, es:[di]	; Save original word
					; in case of failure
		stosw					    
		cmp	ax, es:[di-2]
;;;		je	FailedSpaceVerify
		jne	cont_loop
		jmp	FailedSpaceVerify

cont_loop:
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
		mov     dx, pAS.io_base
		add     dx, REG_LAAR
		mov     al, pAS.laar_enter
		out     dx, al
		jmp	$+2		; Read back value to ensure
		in	al, dx		; that adapter is in 16 bit mode (790).
		call	enable_ram

TestPCMRam:
		mov	ax, RAM_PATTERN_1

		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	StartRamTest

		sub	bx, SHMEM_NIC_OFFSET

StartRamTest:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Start_RAM_Test		; JIF not

		push	cx		; Save RAM size

		mov	bx, ax		; Get test pattern in BX.
		mov	di, 0		; Start with offset 0.
		mov	dx, pAS.io_base
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
		jmp	VerifyRAM	;;;

MM_Start_RAM_Test:
		mov	di, word ptr pAS.ram_access

		cmp	pAS.pc_bus, PCMCIA_BUS
		jne	LeaveOffsetAlone

		add	di, SHMEM_NIC_OFFSET

LeaveOffsetAlone:
		mov	cx, bx		; Get RAM window size in CX
		shr	cx, 1		; Divide by two for words.

VerifyRAM:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
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
		push	ax		; Save read value
		add	dx, REG_IOPA - REG_IOPD

		mov	ax, di		; Get new address
		out	dx, al
		mov	al, ah
		out	dx, al
		add	dx, REG_IOPD - REG_IOPA
		pop	ax

		cmp	ax, bx
		jmp	ChkRamTestError

MM_CmpValue:
		stosw
		cmp	ax, es:[di-2]

ChkRamTestError:
		jne	FailedRAMVerify
		loop	VerifyRAM

		cmp	ax, RAM_PATTERN_1
		jne	RamPatternTwo
		mov	ax, RAM_PATTERN_2

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Start_RAM_Test		; JIF no to MM test

		pop	cx			; Restore loop counter
		jmp	StartRamTest

RamPatternTwo:			 
		cmp	ax, RAM_PATTERN_2
		jne	RamTestSuccess
		mov	ax, RAM_PATTERN_3

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	MM_Start_RAM_Test		; JIF no to MM test

		pop	cx			; Restore loop counter
		jmp	StartRamTest

RamTestSuccess:			 
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	SetReturnCode		; JIF no to MM test

		pop	cx			; Restore loop counter

SetReturnCode:
		mov	ax, SUCCESS
		jmp	RAMTestDone


FailedSpaceVerify:
		mov	es:[di-2], dx
		mov	ax, RAM_CONFLICT

		jmp	RAMTestDone

FailedRAMVerify:
		mov	ax, RAM_TEST_FAILED

		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jz	RAMTestDone			; JIF no

		pop	cx			; Balance the stack
		jmp	RAMTestDone

GotROMSignature:
		mov	ax, ROM_CONFLICT

RAMTestDone:
		test	pAS.adapter_flags, IO_MAPPED	; I/O mapped?
		jnz	ExitRAMTest			; JIF yes

		cmp	pAS.pc_bus, PCMCIA_BUS
		je	ExitRAMTest

		call	DeAccessSharedRam

ExitRAMTest:
		pop	es
		pop	di
		pop	dx
		pop	cx
		pop	bx
		$POPFF
		ret	
TestAdapterRam	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	InitErrorCounters	Initializes error counters to point to
;				pAS.dummy_vector if they are not
;				initialized by UMAC.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

InitErrorCounters	proc	near
		push	ax
		push	bx
		push	cx
		push	si

		lea	bx, pAS.ptr_rx_CRC_errors	; Get address of first counter.
		lea	cx, pAS.ptr_ring_OVW	; Get address of last counter.
		sub	cx, bx				; Subtract to get difference.
		shr	cx, 1				; Divide by 4.
		shr	cx, 1				; CX = # of counters.
		inc	cx

		mov	si, bx
		lea	bx, pAS.dummy_vector	; BX = offset of dummy vector.
							; DS:SI = offset of first counter.
CheckVectors:
		lodsw
		or	ax, ds:[si]			; Get pointer
		jnz	SkipThisVector			; If null, fill with dummy vector.
		mov	ds:[si-2].ofst, bx
		mov	ds:[si-2].sgmt, ds
SkipThisVector:
		add	si, 2
		loop	CheckVectors

		pop	si
		pop	cx
		pop	bx
		pop	ax

		ret
InitErrorCounters	endp


;****************************************************************************
;
; Function:	AccessSharedRam
;
; Synopis:	
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

AccessSharedRam	proc	near
	push	ax
	push	dx

	mov	dx, pAS.io_base

	add	dx, REG_LAAR		; Disable 16 bit host access
	mov	al, pAS.laar_enter
	out	dx, al
	jmp	$+2
	in	al, dx			; Read back REG_LAAR because 790
					; can't get into 16 bit mode in time.

	test	pAS.lmac_flags, MEM_DISABLE	; 790, Memory enable?
	jz	ASR_exit			; JIF no

	add	dx, REG_MSR - REG_LAAR		; Enable memory access
	mov	al, MSR_MENB
	out	dx, al
	in	al, dx

ASR_exit:
	pop	dx
	pop	ax
	ret				; Exit
AccessSharedRam	endp


;****************************************************************************
;
; Function:	DeAccessSharedRam
;
; Synopis:	
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

DeAccessSharedRam	proc	near
	push	ax
	push	dx

	mov     dx, pAS.io_base

	test	pAS.lmac_flags, MEM_DISABLE	; 790, memory disable?
	jz	NoMemDisable			; JIF no

	xor	al, al				; Else disable the memory
	out	dx, al				; Turn off shared RAM access
	in	al, dx				;  when not needed by 790.

NoMemDisable:
	add     dx, REG_LAAR			; Set 16 bit memory access
	mov     al, pAS.laar_exit		; for the Host.
	out     dx, al

	pop	dx
	pop	ax
	ret					; Exit
DeAccessSharedRam	endp



ifdef	EZSTART
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	UpdateCollisionTable	Updates Collision Table indicated by
;				easp.CollTable
;
;	Entry:	AL	Number of collisions for this transmit.
;			if greater than 15, it will be set to 15.
;		DS:BP	Ptr to adapter structure. pAS.EASP must be valid.
;
;	Exit:	All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
public UpdateCollisionTable
ifdef LARGE
UpdateCollisionTable	proc	far
else
UpdateCollisionTable	proc	near
endif
		push	ax
		push	bx
		push	es

		cmp	al, 0Fh
		jbe	NoCountAdjust
		mov	al, 0Fh
NoCountAdjust:
		xor	ah, ah
		shl	ax, 1
		shl	ax, 1
		les	bx, pAS.easp
		lea	bx, es:[bx].CollTable
		add	bx, ax
		add	word ptr es:[bx], 1
		adc	word ptr es:[bx+2], 0

		pop	es
		pop	bx
		pop	ax
		ret
UpdateCollisionTable	endp
endif
