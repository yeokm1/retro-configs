;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; (C) Copyright 1991 Standard Microsystems Corp. All rights reserved.
;
; PCMCNFG.ASM	Routines for reading configuration information from SMC
;		PCM Ethernet cards.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GetCnfg    Get all configuration Information for PCM adapters
;
;
; Return: 
;      Ax -- SUCCESS, Got configuration successfully.
;         -- ADAPTER_NOT_FOUND,  Didn't find any PCM cards.
;
;      All registers except AX will be preserved.
;
;      All configuration information is put into
;      the configuration structure. 
;
;************************************************************
.xlist
include	popff.mac
include	pcmcia.inc

include	getcnfg.inc
include	ezstart.inc
.list

;;; Version string visible in executable using GETVER.EXE utility ...

;ifdef	ETHERNET
;db		'@(#) SMC PCMCIA GetCnfg v1.23',0,'$'
;endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Revision History (Implemented in v1.23)
;
; Ref #		Date		Who
; [1]		03/17/94	M. Steiger
; 
; Description:
;	Added routine GetCfgInfo which calls PCMCIA card services and checks each socket for the first SMC PCMCIA card. Upon
;	finding one, it checks the GCIAssignedIRQ field in the GetConfigurationInfo structure to determine if the card has
;	already been configured. If the GCIAssignedIRQ field contains a value between 2 and 15, it is assumed that the
;	card has already been configured, the adapter structure is initialized with known info, and LM_GetCnfg returns
;	CARD_CONFIGURED. If the value in GCIAssignedIRQ is not between 2 and 15, it is assumed that the card has not been
;	configured, and the routine RegPcmClient proceeds to register as a client and configure the card. The field
;	GCIAssignedIRQ is initialized before each call to card services in GetCfgInfo. This is done to prevent leftover data
;	in the GetConfigurationInfo structure from being misinterpreted.
;
; Ref #		Date		Who
; [2]		XX/XX/XX	XXX
; 
; Description:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;******************************************************************************
;
;******************************************************************************



ASM_PCM_PROC    LM_GetCnfg

IFNDEF	CODE386
	push	ds
	push	es
ENDIF
	push	bp
	push	bx
	push	cx
	call	GetPcmConfig
	jmp	lm_gc_exit
lm_gc_exit:			      		 
	push	ax		; Save return code
	call	GetAdapterNamePtr
	pop	ax		; Restore return code

	xor	dx, dx
	pop	cx
	pop	bx
	pop	bp
IFNDEF	CODE386
	pop	es
	pop	ds
ENDIF
	ret

ASM_PCM_PROC_END    LM_GetCnfg


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


IFDEF EZSTART
PUBLIC        _PCM_LM_GetCnfg

_PCM_LM_GetCnfg proc	far
		push	bp
		mov	bp, sp
                push    ds
                mov     cx, [bp+14]             ;length of vendor string area
                les     si, [bp+10]             ;pointer to vendor string
		lds	bp, [bp+6]		;adapter_ptr

		call	PCM_LM_GetCnfg

		pop	ds
		pop	bp
		ret

_PCM_LM_GetCnfg	endp
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	GetPcmConfig	Configures PCM adapter in first PCMCIA socket to
;			parameters indicated in adapter structure indicated
;			by ds:[bp]. Sets appropriate bits in board_id
;			& extra_info. This procedure writes directly to the
;			Intel 365 chip. Do not use with Socket Services or
;			Card Services software.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetPcmConfig
GetPcmConfig	proc	near
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	pushf

	sti
	mov	ds:[bp].callback_handler_status, ADAPTER_NOT_FOUND	; Pre-load return code.
	call	CheckForCardServices
	jc	PcmCfgExit

	call	GetCfgInfo			; [1] Call new routine to see if there are SMC cards that have already been
	jc	NoUnconfiguredCards		; configured.

	call	RegPcmClient			; Find SMC cards and attempt to register ourselves as a client and configure
	jc	AdapterNotPresent		; the card.
	mov	cx, -1

PollPcmFlags:
	test	ds:[bp].pcm_card_flags, REG_COMPLETE
	in	al, 21h		; Read IRQ Mask register for delay.
	in	al, 21h		; Read IRQ Mask register for delay.
	in	al, 21h		; Read IRQ Mask register for delay.
	loopz	PollPcmFlags

	test	ds:[bp].pcm_card_flags, INSERTED
	jz	ErrorRegClient
	mov	ds:[bp].board_id, PCM10BT
	mov	ds:[bp].extra_info, RAM_SIZE_16K+NIC_690_BIT+ALTERNATE_IRQ_BIT
	mov	ds:[bp].bic_type, BIC_564_CHIP
	mov	ds:[bp].adapter_bus, BUS_PCMCIA_TYPE
	mov	ds:[bp].ram_usable, 16
	mov	ds:[bp].ram_size, 16
	mov	ax, ADAPTER_AND_CONFIG

PcmCfgExit:
	popf
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret

ErrorRegClient:

ifdef LARGE
	call	far ptr DeRegPcmClient
else
	call	DeRegPcmClient
endif
	mov	ax, ds:[bp].callback_handler_status
	jmp	PcmCfgExit

AdapterNotPresent:
	mov	ax, ADAPTER_NOT_FOUND
	jmp	PcmCfgExit

NoUnconfiguredCards:			; [1] Return CARD_CONFIGURED if card has already been configured.
	mov	ax, CARD_CONFIGURED
	jmp	PcmCfgExit

GetPcmConfig	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	(Added in revision change [1])
;
;	GetCfgInfo	Checks each socket for SMC PCMCIA card and if unable to find an unconfigured card, fills adapter struc
;			with data and returns with carry set. If an unconfigured SMC PCMCIA card is found, or no card is found,
;			carry is clear.	This routine is not intended to search for SMC cards, but rather searches for SMC cards
;			that are already configured.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetCfgInfo
GetCfgInfo	proc	near

	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	bp
	push	ds
	push	es		; Save regs

	push	ds
	pop	es		; Make ES = DS.

	lea	bx, ds:[bp].get_cfg_info_struct	; Get address of config info struct in adapter structure.
	mov	es:[bx].GCISocket, 0		; Start with first socket. (Systemsoft starts with 0, others
						; may start with 1.
GCISocketLoop:
	cmp	es:[bx].GCISocket, 5		; If were up to socket #5, bail out.
	jne	CheckNextSocket
	jmp	CardNotConfigured

CheckNextSocket:
	mov	al, GetConfigurationInfo	; PCMCIA card services routine
	mov	ah, 0AFh			; 0AFh indicates card services call.
	mov	cx, size GetCfgInfoStruct	; Get size of structure indicated by ES:BX
	mov	es:[bx].GCIAssignedIRQ, 0FFh	; Init IRQ field in case GetConfigurationInfo does not update.

	call	UM_Card_Services
	jnc	GCIGotOne			; If carry is not set, we got us a live one, Clem!

SkipThisSocket:
	inc	es:[bx].GCISocket		; If carry is set, either the socket does not exist, or there is no card in the
	jmp	GCISocketLoop			; socket. We need not find out why, just try the next socket.

GCIGotOne:
	cmp	es:[bx].GCIManufCode, SMC_PCMCIA_ID	; Is the card in the socket an SMC card?
	jne	SkipThisSocket				; If not, try next socket.

	mov	al, es:[bx].GCIAssignedIRQ		; Check to see if an IRQ has been assigned. If so, the card has already
	cmp	al, 2					; been configured. We do this by range checking the value.
	jb	CardNotConfigured
	cmp	al, 15
	ja	CardNotConfigured

	mov	ds:[bp].pcm_client_handle, dx		; The card has already been configured, get the client handle just in
	mov	ds:[bp].board_id, 0			; case we need it later. Zero out the pertinent adapter structure stuff.
	mov	ds:[bp].extra_info, 0			; A subsequent call to GetAdapterNamePtr will indicate an unknown adapter.
	mov	ds:[bp].bic_type, 0
	mov	ds:[bp].adapter_bus, 0
	mov	ds:[bp].ram_usable, 0
	mov	ds:[bp].ram_size, 0

	mov	ax, es:[bx].GCIManufInfo
	cmp	ah, 01h
	jne	UnknownAdapterRev

	mov	ds:[bp].board_id, PCM10BT		; Init adapter structure stuff for major rev 1 card. At this time, we do
	mov	ds:[bp].extra_info, RAM_SIZE_16K+NIC_690_BIT+ALTERNATE_IRQ_BIT ;not have info on other major rev cards. 
	mov	ds:[bp].bic_type, BIC_564_CHIP
	mov	ds:[bp].adapter_bus, BUS_PCMCIA_TYPE
	mov	ds:[bp].ram_usable, 16
	mov	ds:[bp].ram_size, 16

UnknownAdapterRev:
	stc

GetCfgInfoExit:
	pop	es
	pop	ds
	pop	bp
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

CardNotConfigured:
	clc
	jmp	GetCfgInfoExit

GetCfgInfo	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	CheckForCardServices
CheckForCardServices	proc	near

	push	bx
	push	cx
	push	dx
	push	di
	push	si

	mov	al, GetCardServicesInfo
	mov	ah, 0AFh
	lea	bx, ds:[bp].info_struct

	push	es
	push	cx

	push	ds
	pop	es

	mov	cx, size InfoStruct
	call	UM_Card_Services

	pop	cx
	pop	es

	mov	ax, [bx].InfoSignature
	cmp	ax, CS_SIG
	je	CheckCSRevision

	xchg	ah, al
	cmp	ax, CS_SIG
	jne	NoCardServices

CheckCSRevision:
	cmp	[bx].InfoCSLevel, MIN_CS_VERSION
	jb	UnsupportedCSRev

	mov	ax, es
	or	ax, si
	jnz	FormatAndCopyString
	jmp	NoStringPtr

FormatAndCopyString:
	mov	di, si
	sub	cx, 12			; Compensate for version string added at end.
	cmp	[bx].InfoVStrLen, cx
	ja	TruncateString
	mov	cx, [bx].InfoVStrLen

TruncateString:
	mov	si, [bx].InfoVStrOff
	add	si, bx

CopyStrngLoop:
	lodsb
	cmp	al, '$'
	je	WriteCRLF
	stosb
	cmp	al, 0
	je	WriteCRLF
	loop	CopyStrngLoop
	
WriteCRLF:
	mov	al, 13
	stosb
	mov	al, 10
	stosb
	mov	al, 'V'
	stosb
	mov	cx, 4
	mov	dx, [bx].InfoRevision

FormatCSRevString:
	push	cx
	mov	cx, 4
	mov	al, dh
	shr	al, cl
	shl	dx, cl
	pop	cx

	and	al, 0Fh
	cmp	al, 0
	jne	PrintChar
	cmp	cx, 4
	je	SkipLeadingZeroChar

PrintChar:
	add	al, 30h
	stosb

SkipLeadingZeroChar:
	cmp	cx, 3
	jne	SkipDP
	mov	al, '.'
	stosb
SkipDP:
	loop	FormatCSRevString
	mov	al, 13
	stosb
	mov	al, 10
	stosb
	mov	al, 13
	stosb
	mov	al, 10
	stosb
	mov	al, 0
	stosb

NoStringPtr:
	clc

ChCardServExit:
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret

NoCardServices:
	stc
	mov	ax, CS_NOT_PRESENT
	jmp	ChCardServExit

UnsupportedCSRev:
	stc
	mov	ax, CS_UNSUPPORTED_REV
	jmp	ChCardServExit

CheckForCardServices	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	RegPcmClient

RegPcmClient	proc	near

	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es
	
	mov	al, RegisterClient
	mov	ah, 0AFh
	mov	di, cs
	mov	si, offset cs:CSCallbackHandler
	mov	cx, size RegisterClientStruct
	lea	bx, ds:[bp].register_client_struct
	push	ds
	pop	es
	mov	word ptr es:[bx].RegCliEventMask, EVENT_MASK
	mov	word ptr es:[bx].RegCliCSVersion, CS_VERSION
	mov	word ptr es:[bx].RegCliAttributes, ATTR_MASK
	mov	word ptr es:[bx].RegCliClientData.2, ds
	mov	word ptr es:[bx].RegCliClientData.4, bp
	call	UM_Card_Services
	cmp	ax, SUCCESS
	jne	RegClientFailure
	mov	ds:[bp].pcm_client_handle, dx
	clc

RegClientExit:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

RegClientFailure:
	stc
	mov	ax, REG_CLIENT_ERR
	jmp	RegClientExit

RegPcmClient	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	DeRegPcmClient

ifdef LARGE
DeRegPcmClient	proc	far
else
DeRegPcmClient	proc	near
endif

	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es
	
	mov	al, DeRegisterClient
	mov	ah, 0AFh
	mov	cx, 0
	mov	dx, ds:[bp].pcm_client_handle
	call	UM_Card_Services
	cmp	ax, SUCCESS
	jne	RegClientFailure
	clc
DeRegClientExit:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
DeRegClientFailure:
	stc
	jmp	RegClientExit

DeRegPcmClient	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	ES:SI -> Adapter structure
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	ReqPcmCfg
ReqPcmCfg	proc	near

	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	push	es
	pop	ds
	mov	bp, si

	mov	dx, es:[si].pcm_client_handle
	mov	cx, size ReqCfgStruct
	lea	bx, es:[si].req_cfg_struct

	mov	ax, es:[si].pcm_socket
	mov	es:[bx].ReqCfgSocket, ax
	mov	es:[bx].ReqCfgAttributes, ENABLE_IRQ_STEER
	mov	es:[bx].ReqCfgVcc, FIVE_VOLTS
	mov	es:[bx].ReqCfgVpp1, FIVE_VOLTS
	mov	es:[bx].ReqCfgVpp2, FIVE_VOLTS
	mov	es:[bx].ReqCfgIntType, MEM_AND_IO
	mov	word ptr es:[bx].ReqCfgConfigBase.2, ATTRIBUTE_REG_OFFSET
	mov	word ptr es:[bx].ReqCfgConfigBase, 0
	mov	es:[bx].ReqCfgStatus, 0
	mov	es:[bx].ReqCfgPin, 0
	mov	es:[bx].ReqCfgCopy, 0
	mov	es:[bx].ReqCfgConfigIndex, REG_COR_VALUE
	mov	es:[bx].ReqCfgPresent, REGS_PRESENT_VALUE
	mov	al, RequestConfiguration
	mov	ah, 0AFh
	call	UM_Card_Services

	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

ReqPcmCfg	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	DS:SI -> adapter structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetPcmCardInfo
GetPcmCardInfo	proc	near

	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	mov	bp, si
	mov	di, 0

	lea	bx, [si].tuple_data
	push	ds
	pop	es
	mov	es:[bx].TpStSocket, cx
	mov	es:[bx].TpStAttributes, 0
	mov	es:[bx].TpStDesiredTuple, CISTPL_MANFID
;	mov	es:[bx].TpStReserved, 0

	mov	ax, GetFirstTuple + 0AF00H
	mov	cx, size TupleStruct
	call	UM_Card_Services
	jnc	GotFirstTuple
	jmp	TupleError

GotFirstTuple:
	mov	ax, GetTupleData + 0AF00H
	mov	cx, size TupleData - size TpDtTupleData
	mov	es:[bx].TpDtTupleDataMax, size TpDtTupleData
	call	UM_Card_Services

	mov	di, 0
	cmp	es:[bx].TpDtTupleData.MfgTplId, SMC_PCMCIA_ID
	je	IsSmcCard
	cmp	[si].info_struct.InfoCSLevel, MIN_CS_VERSION
	je	CheckAltOffset
	jmp	NotOurCard

CheckAltOffset:
	mov	di, 2
	cmp	es:[bx+di].TpDtTupleData.MfgTplId, SMC_PCMCIA_ID
	jne	NotOurCard

IsSmcCard:
	mov	ax, es:[bx+di].TpDtTupleData.MfgTplInfo
	cmp	ah, 01h
	jne	UnsupportedCard		; This code only supports PCM major rev 1.

FindLanTuple:
	mov	ax, GetNextTuple + 0AF00H
	mov	cx, size TupleStruct
	mov	es:[bx].TpStDesiredTuple, CISTPL_FUNCE
	push	di
	call	UM_Card_Services
	pop	di
	jc	TupleError

	mov	ax, GetTupleData + 0AF00H
	mov	cx, size TupleData - size TpDtTupleData
	push	di
	call	UM_Card_Services
	pop	di

	cmp	es:[bx+di].TpDtTupleData.LTpType, LAN_TECH
	jne	CheckTuple01
	cmp	es:[bx+di].TpDtTupleData.LTpLanTech, LAN_ETHERNET
	jne	TupleError

CheckTuple01:
	cmp	es:[bx+di].TpDtTupleData.LanNidType, LAN_NID
	jne	FindLanTuple

	mov	[si].nic_type, NIC_690_CHIP
	mov	[si].media_type, MEDIA_BNC_UTP

	test	es:[si].pcm_card_flags, INSERTED	; If card was already inserted, do not reload LAN addr.
	jnz	OurCardExit

	push	ds			; Change ptrs from es:[bx] -> ds:[si] to
	push	es			; ds:[si] -> es:[di]
	pop	ds
	pop	es

	add	bx, di
	lea	di, es:[si].node_address
	lea	si, [bx].TpDtTupleData.LTpLanId

	xor	cx, cx
	mov	cl, [bx].TpDtTupleData.LTpLanIdSz
	rep	movsb			; Load node address into adapter struc.
	clc

OurCardExit:
	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

UnsupportedCard:
	stc
	mov	[si].callback_handler_status, UNSUPPORTED_CARD
	jmp	OurCardExit

NotOurCard:
	stc
	mov	[si].callback_handler_status, NOT_OUR_CARD
	jmp	OurCardExit

TupleError:
	stc
	mov	[si].callback_handler_status, TUPLE_ERROR
	jmp	OurCardExit

GetPcmCardInfo	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	CSCallbackHandler

CSCallbackHandler	proc	far
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	push	ds
	pop	es

	cmp	al, REGISTRATION_COMPLETE
	jne	CallBack01
	or	es:[si].pcm_card_flags, REG_COMPLETE
	jmp	CallBackSuccess

CallBack01:
	test	es:[si].pcm_card_flags, INSERTED
	jz	CheckEventCode

	cmp	es:[si].adapter_status, CARD_REMOVED
	je	CheckEventCode

	cmp	es:[si].pcm_socket, cx
	je	CheckEventCode
	jmp	CallBackSuccess

CheckEventCode:
	cmp	al, RESET_REQUEST
	je	RequestNotSupported

CheckExclusive:
	cmp	al, EXCLUSIVE_REQUEST
	je	RequestNotSupported

CheckInsertion:
	cmp	al, CARD_INSERTION
	jne	CallBack02
	call	GetPcmCardInfo
	jnc	ConfigCard
	jmp	CallBackExit

RequestNotSupported:
	mov	ax, UNSUPPORTED_FUNCTION
	or	ax, ax
	jmp	CallBackExit

ConfigCard:
	test	es:[si].pcm_card_flags, INSERTED
	jz	FirstInsertion01
	mov	al, ADD_RESOURCE
	call	AdjustResInfo
	jnc	FirstInsertion01
	jmp	ErrorConfiguringCard

FirstInsertion01:
	mov	es:[si].pcm_socket, cx
	call	ReqPcmIrq
	jnc	GotDeIrq
	jmp	ErrorConfiguringCard

GotDeIrq:
	mov	cx, 8

RequestMemoryLoop:
	call	ReqPcmShMem
	jnc	GotRamWindows
	loop	RequestMemoryLoop
	jmp	ErrorConfiguringCard

GotRamWindows:
	call	ReqPcmCfg
	jc	ErrorConfiguringCard

	test	es:[si].pcm_card_flags, INSERTED
	jz	FirstInsertion02

	mov	es:[si].adapter_status, CARD_INSERTED
	push	bp
	mov	bp, si
	call	UM_Status_Change
	pop	bp

	jmp	CallBackSuccess

FirstInsertion02:
	or	es:[si].pcm_card_flags, INSERTED
	jmp	CallBackSuccess

CallBack02:
	cmp	al, CARD_REMOVAL
	jne	CallBack03

	cmp	es:[si].adapter_status, CARD_REMOVED
	je	CallBackSuccess
	test	es:[si].pcm_card_flags, INSERTED
	jz	CallBackSuccess
	cmp	es:[si].pcm_socket, cx
	jne	CallBackSuccess
	mov	es:[si].adapter_status, CARD_REMOVED
	push	bp
	mov	bp, si
	call	UM_Status_Change
	pop	bp

	call	RelPcmCfg
	call	RelPcmIrq
	call	RelPcmShMem

	mov	al, REMOVE_RESOURCE
	call	AdjustResInfo
	jc	ErrorConfiguringCard

	jmp	CallBackSuccess

CallBack03:	; Unrecognized code, return success. 

CallBackSuccess:
	clc

CallBackExit:
	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

ErrorCardInit:
	pop	bp

ErrorConfiguringCard:
	call	RelPcmCfg
	call	RelPcmIrq
	call	RelPcmShMem
	mov	[si].callback_handler_status, PCM_CONFIG_ERR
	stc
	jmp	CallBackExit

CSCallbackHandler	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	AdjustResInfo	AL = ADD_RESOURCE or REMOVE_RESOURCE
;
;			ES:SI -> Adapter struct.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUBLIC	AdjustResInfo

AdjustResInfo	proc	near

; Adjust resource info so the IRQ that we originally used will be available.
	push	si
	push	bx
	push	cx
	push	ds
	push	bp

	push	es
	pop	ds
	mov	bp, si
	push	ax
	lea	bx, es:[si].adj_res_info_struct

	mov	es:[bx].ARIActionI, al
	mov	es:[bx].ARIResourceI, IRQ_RESOURCE
	mov	es:[bx].ARIAttributesI, IRQ_EXCLUSIVE
	mov	cx, es:[si].irq_value
	mov	es:[bx].ARIIrq, cl
	mov	cx, size AdjResInfoStructIrq
	mov	ah, 0AFh
	mov	al, AdjustResourceInfo
	call	UM_Card_Services
	pop	ax

	jc	ErrorAdjustingResource


; Adjust resource info so the Ram Base Address that we originally used will be available.

	mov	es:[bx].ARIActionM, al
	mov	es:[bx].ARIResourceM, MEM_RESOURCE
	mov	es:[bx].ARIAttributesM, 0

	mov	ax, word ptr es:[si].ram_base.sgmt
	mov	word ptr es:[bx].ARIBase.sgmt, ax

	mov	ax, word ptr es:[si].ram_base.ofst
	mov	word ptr es:[bx].ARIBase.ofst, ax

	mov	ax, es:[si].ram_usable
	mov	cx, 10
	shl	ax, cl

	mov	word ptr es:[bx].ARISize.sgmt, 0
	mov	word ptr es:[bx].ARISize.ofst, ax

	mov	cx, size AdjResInfoStructMem
	mov	ah, 0AFh
	mov	al, AdjustResourceInfo
	call	UM_Card_Services
	jc	ErrorAdjustingResource
	clc

ExitAdjustResource:
	pop	bp
	pop	ds
	pop	cx
	pop	bx
	pop	si
	ret

ErrorAdjustingResource:
	stc
	jmp	ExitAdjustResource

AdjustResInfo	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PUBLIC	ReqPcmIo
;ReqPcmIo	proc	near
;	push	ax
;	push	bx
;	push	cx
;	push	dx
;	push	bp
;	push	di
;	push	si
;	push	ds
;	push	es
;	push	ds
;	pop	es
;	mov	bp, si
;	lea	bx, [si].req_io_struct
;	mov	dx, [si].pcm_client_handle
;	mov	cx, size ReqIOStruct
;	mov	ax, [si].pcm_socket
;	mov	es:[bx].ReqIOSocket, ax
;	mov	es:[bx].ReqIOBasePort1, 0
;	mov	es:[bx].ReqIONumPorts1, 32
;	mov	es:[bx].ReqIOAttributes1, 0
;	mov	es:[bx].ReqIOBasePort2, 0
;	mov	es:[bx].ReqIONumPorts2, 0
;	mov	es:[bx].ReqIOAttributes2, 0
;	mov	es:[bx].ReqIOIOAddrLines, 5
;	mov	ah, 0AFh
;	mov	al, RequestIO
;	call	UM_Card_Services
;	jc	ReqIOError
;	mov	ax, es:[bx].ReqIOBasePort1
;	mov	[si].io_base, ax
;	clc
;ReqIOExit:	
;	pop	es
;	pop	ds
;	pop	si
;	pop	di
;	pop	bp
;	pop	dx
;	pop	cx
;	pop	bx
;	pop	ax
;	ret
;ReqIOError:
;	jmp	ReqIOExit
;ReqPcmIo	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUBLIC	RelPcmCfg
RelPcmCfg	proc	near

	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	mov	bp, si
	mov	dx, [si].pcm_client_handle
	mov	cx, 2
	lea	bx, [si].req_cfg_struct
	mov	ax, [si].pcm_socket
	mov	[bx].ReqCfgSocket, ax
	push	ds
	pop	es
		
	mov	al, ReleaseConfiguration
	mov	ah, 0AFh
	call	UM_Card_Services

	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

RelPcmCfg	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	RelPcmIrq
RelPcmIrq	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	mov	bp, si
	mov	dx, [si].pcm_client_handle
	lea	bx, [si].req_irq_struct
	push	ds
	pop	es
	mov	ax, [si].pcm_socket
	mov	es:[bx].ReqIrqSocket, ax
	mov	es:[bx].ReqIrqAttributes, IRQ_EXCLUSIVE
	mov	cx, 5
	mov	al, ReleaseIrq
	mov	ah, 0AFh
	call	UM_Card_Services
	clc

	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
RelPcmIrq	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	RelPcmShMem
RelPcmShMem	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	mov	bp, si
	mov	dx, [si].pcm_ram_win_handle
	mov	cx, 0
	mov	al, ReleaseWindow
	mov	ah, 0AFh
	call	UM_Card_Services
	clc

	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
RelPcmShMem	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	ReqPcmIrq
ReqPcmIrq	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	mov	bp, si
	mov	dx, [si].pcm_client_handle
	lea	bx, [si].req_irq_struct
	push	ds
	pop	es
	mov	ax, [si].pcm_socket
	mov	es:[bx].ReqIrqSocket, ax
	mov	es:[bx].ReqIrqAttributes, IRQ_EXCLUSIVE
	mov	es:[bx].ReqIrqIRQInfo1, LEVEL_IRQ + IRQ_INFO2_VALID

	test	[si].pcm_card_flags, INSERTED
	jz	UseDefaultIrqMask
	mov	cx, [si].irq_value
	mov	ax, 1
	shl	ax, cl
	mov	es:[bx].ReqIrqIRQInfo2, ax
	jmp	GotIrqMask

UseDefaultIrqMask:

	mov	es:[bx].ReqIrqIRQInfo2, VALID_IRQS

GotIrqMask:
	mov	cx, size ReqIrqStruct
	mov	ax, RequestIrq + 0AF00h
	call	UM_Card_Services
	jc	ReqIrqError
	mov	al, es:[bx].ReqIrqAssignedIrq
	xor	ah, ah
	mov	[si].irq_value, ax
	clc
ReqIrqExit:
	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
ReqIrqError:
	mov	[si].irq_value, 0
	jmp	ReqIrqExit
ReqPcmIrq	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	ReqPcmShMem
ReqPcmShMem	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	di
	push	si
	push	ds
	push	es

	push	ds
	pop	es
	mov	bp, si
	lea	bx, [si].req_mem_struct
	mov	es:[bx].ReqMemAccessSpeed, SPEED_100nS OR 80h	; 80h is USE_WAIT.

TryShMemAgain:
	mov	ax, [si].pcm_socket
	mov	dx, [si].pcm_client_handle
	mov	es:[bx].ReqMemSocket, ax
	mov	es:[bx].ReqMemAttributes, REQ_MEM_DEFAULT
	mov	word ptr es:[bx].ReqMemBase, 0
 	mov	word ptr es:[bx].ReqMemBase.2, 0
	mov	word ptr es:[bx].ReqMemSize, SHMEM_SIZE
	mov	word ptr es:[bx].ReqMemSize.2, 0
	mov	cx, size ReqMemStruct

	mov	ax, RequestWindow + 0AF00h
	call	UM_Card_Services

; If CS doesn't like speed with USE_WAIT set, try it without.

	jnc	GotDeWindow
	cmp	ax, BAD_SPEED
	jne	ReqMemWinError
	cmp	es:[bx].ReqMemAccessSpeed, SPEED_100nS
	je	ReqMemWinError
	mov	es:[bx].ReqMemAccessSpeed, SPEED_100nS
	jmp	TryShMemAgain

GotDeWindow:
	mov	[si].pcm_ram_win_handle, dx
	lea	bx, [si].map_mem_page_struct
	mov	word ptr es:[bx].MapMemCardOffset, OFFSET_SHMEM_LO
	mov	word ptr es:[bx].MapMemCardOffset.2, OFFSET_SHMEM_HI
	mov	es:[bx].MapMemPageNum, 0
	mov	cx, size MapMemPageStruct

	mov	ax, MapMemPage + 0AF00h
	call	UM_Card_Services
	jc	ReqMemWinError

	push	ds			; Change ptrs from es:[bx] -> ds:[si] to
	push	es			; ds:[si] -> es:[di]
	pop	ds
	pop	es
	lea	di, es:[si].ram_base
	lea	si, [si].req_mem_struct.ReqMemBase
	movsw
	movsw				; Copy RAM base address to adapter structure

ReqMemWinExit:
	pop	es
	pop	ds
	pop	si
	pop	di
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
ReqMemWinError:
	mov	word ptr [si].ram_base.2, 0
	mov	word ptr [si].ram_base, 0
	jmp	ReqMemWinExit
ReqPcmShMem	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PUBLIC	ReqPcmRegMem
;ReqPcmRegMem	proc	near
;	push	ax
;	push	bx
;	push	cx
;	push	dx
;	push	bp
;	push	di
;	push	si
;	push	ds
;	push	es
;
;	mov	bp, si
;	mov	ax, [si].pcm_socket
;	mov	dx, [si].pcm_client_handle
;	lea	bx, [si].req_mem_struct
;	push	ds
;	pop	es
;
;	mov	es:[bx].ReqMemSocket, ax
;	mov	es:[bx].ReqMemAttributes, REQ_MEM_DEFAULT
;	mov	ax, word ptr [si].ram_base
;	mov	word ptr es:[bx].ReqMemBase, ax
;	mov	ax, REG_OFFSET
;	mov	cl, 4
;	shr	ax, cl
;	add	ax, word ptr [si].ram_base.2
;	mov	word ptr es:[bx].ReqMemBase.2, ax
;	mov	word ptr es:[bx].ReqMemSize, 1000h
;	mov	word ptr es:[bx].ReqMemSize.2, 0
;	mov	es:[bx].ReqMemAccessSpeed, 4
;	mov	cx, size ReqMemStruct
;	mov	ah, 0AFh
;	mov	al, RequestWindow
;	call	UM_Card_Services
;	jc	ReqMemWinError
;
;	mov	[si].pcm_reg_win_handle, dx
;	lea	bx, [si].map_mem_page_struct
;	mov	word ptr es:[bx].MapMemCardOffset, 0
;	mov	word ptr es:[bx].MapMemCardOffset.2, OFFSET_REGISTER_MEM
;	mov	es:[bx].MapMemPageNum, 0
;	mov	cx, size MapMemPageStruct
;	mov	ah, 0AFh
;	mov	al, MapMemPage
;	call	UM_Card_Services
;	jc	ReqMemWinError
;
;ReqRegMemWinExit:
;	pop	es
;	pop	ds
;	pop	si
;	pop	di
;	pop	bp
;	pop	dx
;	pop	cx
;	pop	bx
;	pop	ax
;	ret
;ReqRegMemWinError:
;	mov	word ptr [si].ram_base.2, 0
;	mov	word ptr [si].ram_base, 0
;	jmp	ReqMemWinExit
;ReqPcmRegMem	endp
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GetAdapterNamePtr	Initializes pointer to adapter name.
;
; Entry:	DS:BP	Ptr to Adapter Structure
;
; Exit:		If AX == SUCCESS, ds:[bp].adapter_name_ptr initialized to
;			 valid adapter name.
;
;		If AX == UNKNOWN_ADAPTER, ds:[bp].adapter_name_ptr
;			 initialized to string 'StringAdapUnknown'			  
;			      	  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetAdapterNamePtr	proc	near

		push	si
		push	di
ifndef	CODE386
		push	es
		push	ds
endif
		mov	ax, ds:[bp].board_id
		cmp	ax, PCM10BT
		jne	$10
		mov	si, offset cs:StringPCM10BT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$10:
		mov	si, offset cs:StringAdapUnknown
		mov	ax, UNKNOWN_ADAPTER
AdapNamePtrDone:
ifdef	CODE386
		lea	edi, [ebp].adapter_name
else
		push	ds
		push	cs
		pop	ds
		pop	es

		lea	di, ds:[bp].adapter_name
endif
StoreNameLoop:
		lodsb
		stosb
		or	al, al
		jnz	StoreNameLoop
ifndef	CODE386
		pop	ds
		pop	es
endif
		pop	di
		pop	si
		ret

;;;;;;;;;;;;;;;; Adapter name strings located in CODE.
StringPCM10BT		db	'SMC8016C/PC',0,'$'
StringAdapUnknown	db	'Unknown',0,'$'
GetAdapterNamePtr	endp

