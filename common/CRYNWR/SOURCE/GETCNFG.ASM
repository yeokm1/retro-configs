;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         GETCNFG.ASM
;
; Description:	Routines for reading configuration information from 80X3
;		Ethernet and 8115 Token Ring adapters.
;
;********************
;* Revision History *
;********************
;
; $Log:   O:\sweng\src\lmcom\vcs\getcnfg.avm  $
;  
;     Rev 1.91   28 Oct 1994 10:37:28   STEIGER
;  Moved bid_get_engr_eeprom, bid_wait_for_recall, and bid_recall_lan_address
;  outside of the ETHERNET conditional block.
;  Changed BID_LAR0 in GetTokenInfo to BID_LAR_0.
;  (The 3 routines were moved so they could be accessed by GetTokenInfo.)
;  
;     Rev 1.90   17 Oct 1994 11:26:08   WOOD_R
;
; Changes:	Added code inside GetTokenInfo to recall Chip revision type
;		from the EEPROM data bank.
;  
;     Rev 1.89   04 Aug 1994 16:48:24   WOOD_R
;  
;  
; Change:	Modified lm_gc_advanced_features and lm_gc_extended_media
;		to support the 8416BT and correctly identify the
;		8416BTA.
;
;  
;     Rev 1.88   26 Jul 1994 14:17:46   wood_r
;
; Bug Fix:	Modified the routine "lm_gc_extended_media" to have
;		Starlan-10 set correctly for "media_set".  It was 
;		reporting S-10 with BNC and 10baseT.  It will now
;		only report S-10.
;  
;     Rev 1.87   07 Jul 1994 14:35:36   wood_r
;
; LM_8416_s2.1_v2.01
; Changes:	Added code to support the Auto Media Detect feature and
;		the 8416 naming conventions.
;
; LM_8416_s2.1_v2.00b
;
; Bug Fix:	Changed a test for IO_MAPPED from using the mode_bits flag
;		to use adapter_flags.
;
; Change:	Added the Keyword "Revision" to the GetVER Revision string.
;		This will alleviate having to update it everytime the file
;		is checked into PVCS.
;  
;     Rev 1.85   10 May 1994 16:55:32   STEIGER
;
; Bug Fix:	Fixed mode_bits and media_type field - Ethernet AUI media
;		was misidentified as Ethernet UTP media.
;		Fixed media_set to reflect the speed of Ethernet interface,
;		i.e. 10/100 Mb.
;  
;     Rev 1.84   04 May 1994 13:12:24   STEIGER
;
; Change:	Added routine lm_gc_extended_media.
;		Added support for adap struc field media_opts.
;  
;     Rev 1.83   21 Apr 1994 16:02:52   wood_r
;
;  Banner problems
;  
;     Rev 1.82   21 Apr 1994 15:11:52   wood_r
; LM_8416_s2.1_v2.00a
;
; Change:	This revision of the file will be the start of the next
;		generation of the Ethernet LMACs.  The version level will
;		be bumped from 1.xxx to 2.xxx.
;
;		The Ethernet LMAC driver now supports "Dual Mode" operation.
;		This is implemented by using a flag bit in the adapter
;		structure variable "adapter_flags".  The equate used for this
;		is IO_MAPPED.  This variable is available to the UMAC to
;		query for the type of driver.  The variable is now also
;		initialized in LM_GetCnfg.
;
;		The "Bus Mode Mismatch" warning has been changed to only
;		return a warning if the driver is built for I/O mode only,
;		and the driver is not in I/O mode.  The default driver
;		for the LMCOM files, "getcnfg", is Memory Mapped.  This
;		will work for both setups.  If the driver is configured
;		for I/O mode, the main driver area outside of the "getcnfg"
;		area will run in I/O mode.
;
;+!/? ***********************************************************************


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GetCnfg    Get all configuration Information for 
;            the Interface chips -- 583,584,593,594 and 571/572
;
;
; Return: 
;      Ax -- 0, get configuration successfully.
;         -- 01, board found but didn't get any information.
;         -- ffff, didn't find any boards.
;
;      All registers except ax will be preserved.
;
;      All configuration information is put into
;      the configuration structure. 
;
;************************************************************

include	popff.mac
IFDEF	CODE386
lm_gc_base_ptr		equ	EBP
lm_gc_struc_ptr		equ	[EBP]
BASE_PTR		equ	EBP
STACK_PTR		equ	ESP
SRC_INDEX		equ	ESI
DEST_INDEX		equ	EDI
ELSE
lm_gc_base_ptr		equ	BP
lm_gc_struc_ptr	equ	DS:[BP]	  
BASE_PTR		equ   	BP
STACK_PTR		equ	SP
SRC_INDEX		equ	SI
DEST_INDEX		equ	DI
ENDIF				  
include	getcnfg.inc

ifndef	UBIO	; #0

ifdef	TOKEN_RING
ifdef	SETUP_MODE
include	eerom.inc
include	reerom.asm
endif
endif

ifndef	SETUP_MODE
ifdef	TOKEN_RING
include	eerom.inc
include	reerom.asm
endif
endif

ifndef	TOKEN_RING
ifdef	SETUP_MODE
include	eerom.inc
include	reerom.asm
endif
endif

endif		; #0

;;;ifdef	ETHERNET
;;;db		'@(#) SMC Ethernet GetCnfg $Revision:   1.91  $',0,'$'
;;;endif
;;;ifdef	TOKEN_RING
;;;db		'@(#) SMC Token Ring GetCnfg $Revision:   1.91  $',0,'$'
;;;endif

;******************************************************************************
;
;******************************************************************************

	public LM_GetCnfg
ifdef	LARGE
LM_GetCnfg	proc	far
else
LM_GetCnfg	proc	near
endif
IFNDEF	CODE386
	push	ds
	push	es
ENDIF
	push	lm_gc_base_ptr
	push	bx
	push	cx

	mov	lm_gc_struc_ptr.adapter_flags, 0	; Init flag bits

ifndef	UBIO	; #1
	cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
	je	lm_gc_mca_type

endif		; #1

	call	lm_gc_get_at_config

ifndef	UBIO	; #2
	jmp	lm_gc_at_exit


lm_gc_mca_type:
	call	lm_gc_get_mca_config
endif		; #2

lm_gc_at_exit:
	cmp	ax, ADAPTER_NOT_FOUND
	je	lm_gc_error_exit   			     

ifndef	UBIO	; #2a

	cmp	ax, ADAPTER_AND_CONFIG
	je	lm_gc_exit
	cmp	ax, EEROM_CKSUM_ERROR
	je	lm_gc_exit

; Return code in AX is CONFIG_WARNING or ADAPTER_NO_CONFIG at this point.

	push	ax
	push	dx
	call	VerifyParams
	cmp	ax, SUCCESS
	jne	CombineRetCodes
	pop	dx
	pop	ax
	jmp	lm_gc_exit
CombineRetCodes:
	mov	bx, dx		; Get DX ret code from VerifyParams in BX
	pop	dx		; Restore AX & DX ret code from
	pop	cx		; lm_gc_get_???_config to BX & DX.
		 		; (We are flushing the AX ret code by
				; popping it to CX.)
	or	dx, bx		; OR in DX ret code from VerifyParams

else		; #2a
	test	lm_gc_struc_ptr.extra_info, SLOT_16BIT
	jnz	lm_gc_exit
	cmp	lm_gc_struc_ptr.irq_value, 7
	jbe	lm_gc_exit
	mov	ax, CONFIG_ERROR
	or	dx, IRQ_INVALID
endif		; #2a

lm_gc_exit:			      		 
	push	ax		; Save return code
	call	GetAdapterNamePtr

ifndef	UBIO	; #3

	mov	lm_gc_struc_ptr.nic_type, NIC_8390_CHIP	; Start with 8390 as default.

	test	lm_gc_struc_ptr.extra_info, NIC_690_BIT
	jz	CheckFor790Nic
	mov	lm_gc_struc_ptr.nic_type, NIC_690_CHIP
	jmp	GotNicType
CheckFor790Nic:
	test	lm_gc_struc_ptr.extra_info, NIC_790_BIT
	jz	CheckFor825Nic
endif		; #3
	mov	lm_gc_struc_ptr.nic_type, NIC_790_CHIP
	jmp	GotNicType

ifndef	UBIO	; #4
CheckFor825Nic:
	test	lm_gc_struc_ptr.extra_info, NIC_825_BIT
	jz	GotNicType	; The only one left is 8390.
	mov	lm_gc_struc_ptr.nic_type, NIC_825_CHIP
endif		; #4

GotNicType:
	pop	ax		; Restore return code

ifndef	SETUP_MODE

	test	lm_gc_struc_ptr.board_id, NIC_SUPERSET
	jz	BusModeOk

	test	lm_gc_struc_ptr.adapter_flags, IO_MAPPED
ifdef	UBIO
	jnz	BusModeOk		; Report error if I/O mismatch
else
	jmp	BusModeOk		; Don't report error on MM mode
endif

	or	dx, BUS_MODE_MISMATCH
	mov	ax, CONFIG_WARNING
BusModeOk:

endif

lm_gc_error_exit:
       	pop	cx
	pop	bx
	pop	lm_gc_base_ptr
IFNDEF	CODE386
	pop	es
	pop	ds
ENDIF
	ret

LM_GetCnfg	endp


ifndef	UBIO	; #5
;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_disable_slot
ENDIF
lm_gc_disable_slot	proc	near

	push	ax
	mov	al,0
	out	CNFG_POS_CONTROL_REG, al
	jmp	$+2
	pop	ax
	ret

lm_gc_disable_slot	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_enable_slot
ENDIF
lm_gc_enable_slot	proc	near

	push	ax
	mov	al, lm_gc_struc_ptr.slot_num
	or	al, al
	jz	lm_gc_protect_slot
	dec	al
lm_gc_protect_slot:
	or	al, CNFG_SLOT_ENABLE_BIT
	out	CNFG_POS_CONTROL_REG,al
	jmp	$+2
	pop	ax
	ret

lm_gc_enable_slot	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;	Returns: AX = POS ID
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_get_pos_id
ENDIF
lm_gc_get_pos_id	proc	near

	push	dx
	mov	dx, CNFG_POS_REG1
	in	al, dx
	jmp	$+2
	mov	ah, al
	mov	dx, CNFG_POS_REG0
	in	al, dx
	jmp	$+2
	pop	dx
	ret

lm_gc_get_pos_id	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_get_mca_config
ENDIF
lm_gc_get_mca_config	proc	near

	call	lm_gc_enable_slot
	call	lm_gc_get_pos_id	; returns AX = POS ID
	mov	lm_gc_struc_ptr.pos_id, ax
	call	lm_gc_check_594_group
	jz	lm_gc_594_card
ifdef	ETHERNET
	call	lm_gc_check_593_group
	jz	lm_gc_593_card
endif
	mov	ax, ADAPTER_NOT_FOUND
	jmp	short lm_gc_bad_exit
lm_gc_593_card:
	call	lm_gc_get_593_cnfg
	jmp	short lm_gc_good_exit
lm_gc_594_card:
	call	lm_gc_get_594_cnfg
lm_gc_good_exit:
	or	lm_gc_struc_ptr.mode_bits, INTERRUPT_STATUS_BIT
	push	ax
	mov	ax, 1
	call	lm_gc_get_bid
	call	lm_gc_adap_type
	pop	ax
lm_gc_bad_exit:
	call	lm_gc_disable_slot
	or	ax, ax
	ret

lm_gc_get_mca_config	endp
endif		; #5
;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_get_bid
ENDIF
lm_gc_get_bid	proc	near

	push	ax
	push	dx

	push	SRC_INDEX

	mov	dx, lm_gc_struc_ptr.io_base
	mov	SRC_INDEX, BASE_PTR
	call	GetBoardID
	mov	lm_gc_struc_ptr.board_id, ax
	mov	lm_gc_struc_ptr.extra_info, dx

	pop	SRC_INDEX
	pop	dx
	pop	ax
	ret

lm_gc_get_bid	endp

ifndef	UBIO	; #6
;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_get_594_cnfg
ENDIF
lm_gc_get_594_cnfg	proc	near

	xor	dx, dx
	mov	lm_gc_struc_ptr.bic_type, BIC_594_CHIP
	call	lm_gc_594_io
	call	lm_gc_594_irq
	call	lm_gc_594_ram_base
	call	lm_gc_594_ram_size
	call	lm_gc_594_rom_base
	call	lm_gc_594_rom_size
	call	lm_gc_594_media_type
ifdef	TOKEN_RING
	mov	ax, lm_gc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, TOKEN_MEDIA
	jne	SkipTokenMode
	call	lm_gc_token_mode
SkipTokenMode:
endif
	or	dx, dx
	jnz	lm_gc_get_594_cnfg_warning_exit
	mov	ax, ADAPTER_AND_CONFIG
	ret
lm_gc_get_594_cnfg_warning_exit:
	mov	ax, CONFIG_WARNING
	ret
lm_gc_get_594_cnfg	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_get_593_cnfg
ENDIF
lm_gc_get_593_cnfg	proc	near
	
	xor	dx, dx
	mov	lm_gc_struc_ptr.bic_type, BIC_593_CHIP
	call	lm_gc_593_io
	call	lm_gc_593_irq
	call	lm_gc_593_ram_base
	call	lm_gc_593_ram_size
	call	lm_gc_593_rom_base
	call	lm_gc_593_rom_size
	mov	lm_gc_struc_ptr.media_type, MEDIA_UNKNOWN
	or	dx, dx
	jnz	lm_gc_get_593_cnfg_warning_exit
	mov	ax, ADAPTER_AND_CONFIG
	ret
lm_gc_get_593_cnfg_warning_exit:
	mov	ax, CONFIG_WARNING
	ret
lm_gc_get_593_cnfg	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_593_io
ENDIF
lm_gc_593_io	proc	near

	push	dx
	mov	dx, CNFG_POS_REG2
	in	al, dx
	jmp	$+2
	and	al, 0FEh
	xor	ah, ah
	mov	cl, 4
	shl	ax, cl
	mov	lm_gc_struc_ptr.io_base, ax
	pop	dx
	ret

lm_gc_593_io	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_593_irq
ENDIF
lm_gc_593_irq	proc	near

	push	dx
	mov	dx, CNFG_POS_REG5
	in	al, dx
	pop	dx
	jmp	$+2
	mov	ah, 3
	and	al, 03h
	jz	lm_gc_593_irq_out
	mov	ah, 4
	dec	al
	jz	lm_gc_593_irq_out
	mov	ah, 10
	dec	al
	jz	lm_gc_593_irq_out
	mov	ah, 15
	dec	al
lm_gc_593_irq_out:
	xchg	ah, al
	cmp	lm_gc_struc_ptr.irq_value, ax
	mov	lm_gc_struc_ptr.irq_value, ax
	mov	ax, SUCCESS
	je	lm_gc_593_irq_match
	or	dx, IRQ_MISMATCH
;	mov	ax, CONFIG_WARNING
lm_gc_593_irq_match:
	ret

lm_gc_593_irq	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_593_ram_base
ENDIF
lm_gc_593_ram_base	proc	near

	push	dx
	mov	dx, CNFG_POS_REG3
	in	al, dx
	jmp	$+2
	and	al, 0FCh
	xor	ah, ah
	mov	cl, 4
	shl	ax, cl
	xor	dx, dx
	xchg	dl, ah
	mov	cl, 8
	shl	ax, cl
	cmp	word ptr lm_gc_struc_ptr.ram_base, ax
	jne	lm_gc_593_ram_base_mismatch
	cmp	word ptr lm_gc_struc_ptr.ram_base+2, dx
	jne	lm_gc_593_ram_base_mismatch
	mov	word ptr lm_gc_struc_ptr.ram_base+2, dx
	mov	word ptr lm_gc_struc_ptr.ram_base, ax
	pop	dx
	ret
lm_gc_593_ram_base_mismatch:
	mov	word ptr lm_gc_struc_ptr.ram_base+2, dx
	mov	word ptr lm_gc_struc_ptr.ram_base, ax
	pop	dx
	or	dx, RAM_BASE_MISMATCH
	ret
		 
lm_gc_593_ram_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_593_ram_size
ENDIF
lm_gc_593_ram_size	proc	near

	cmp	lm_gc_struc_ptr.ram_usable, CNFG_SIZE_16kb
	mov	lm_gc_struc_ptr.ram_size, CNFG_SIZE_16kb
	mov	lm_gc_struc_ptr.ram_usable, CNFG_SIZE_16kb
	jne	lm_gc_593_ram_size_mismatch
      	ret
lm_gc_593_ram_size_mismatch:
	or	dx, RAM_SIZE_MISMATCH
	ret
lm_gc_593_ram_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_593_rom_base
ENDIF
lm_gc_593_rom_base	proc	near

	push	dx
	mov	dx, CNFG_POS_REG4
	in	al, dx
	jmp	$+2
	and	al, 0FCh
	xor	ah, ah
	mov	cl, 4
	shl	ax, cl
	xor	dx, dx
	xchg	dl, ah
	mov	cl, 8
	shl	ax, cl
	mov	word ptr lm_gc_struc_ptr.rom_base, ax
	mov	word ptr lm_gc_struc_ptr.rom_base+2, dx
	pop	dx
	ret

lm_gc_593_rom_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_593_rom_size
ENDIF
lm_gc_593_rom_size	proc	near

	push	dx
	mov	dx, CNFG_POS_REG4
	in	al, dx
	jmp	$+2
	mov	ah, CNFG_SIZE_16kb
	and	al, 03h
	jz	lm_gc_593_rs_out
	mov	ah, CNFG_SIZE_32kb
	dec	al
	jz	lm_gc_593_rs_out
	mov	ah, ROM_DISABLE
	dec	al
	jz	lm_gc_593_rs_out
	mov	ah, CNFG_SIZE_64kb
	dec	al
lm_gc_593_rs_out:
	xchg	ah, al
	mov	lm_gc_struc_ptr.rom_size, ax
	pop	dx
	ret

lm_gc_593_rom_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_594_io
ENDIF
lm_gc_594_io	proc	near

	push	dx
	mov	dx, CNFG_POS_REG2
	in	al, dx
	jmp	$+2
	and	al, 0F0h
	mov	ah, al
	xor	al, al
	add	ax, 0800h
	mov	lm_gc_struc_ptr.io_base, ax
	pop	dx
	ret
lm_gc_594_io	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_594_irq
ENDIF
lm_gc_594_irq	proc	near

	push	bx
	push	dx
	mov	dx, CNFG_POS_REG5
	in	al,dx
	pop	dx
	and	al, 0Ch
	shr	al, 1
	shr	al, 1
	mov	ah, 3
	or	al, al
	jz	lm_gc_594_irq_out
	mov	ah, 4
	dec	al
	jz	lm_gc_594_irq_out
	mov	ah, 10
	dec	al
	jz	lm_gc_594_irq_out
	mov	ah, 14
	mov	bx, lm_gc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	jne	SkipIrqAdjust
	mov	ah, 15
SkipIrqAdjust:
	dec	al
lm_gc_594_irq_out:
	xchg	al, ah
	cmp	lm_gc_struc_ptr.irq_value, ax
	mov	lm_gc_struc_ptr.irq_value, ax
	je	lm_gc_594_irq_match
	or    	dx, IRQ_MISMATCH
lm_gc_594_irq_match:
	pop	bx
	ret
lm_gc_594_irq	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_594_ram_base
ENDIF
lm_gc_594_ram_base	proc	near

	push	dx
	mov	dx, CNFG_POS_REG3
	in	al, dx
	jmp	$+2
	mov	dx, 000Dh
	test	al, 08h
	jnz	above_cseg
	mov	dx, 000Ch
above_cseg:
	test	al, 080h
	jz	lm_gc_below_1MB
	or	dx, 00F0h
lm_gc_below_1MB:
	xor	ah, ah
	and	al, 07h
	mov	cl, 13
	shl	ax, cl
	cmp	word ptr lm_gc_struc_ptr.ram_base, ax
	jne	lm_gc_594_ram_base_mismatch
	cmp	word ptr lm_gc_struc_ptr.ram_base+2, dx
	jne	lm_gc_594_ram_base_mismatch
	mov	word ptr lm_gc_struc_ptr.ram_base+2, dx
	mov	word ptr lm_gc_struc_ptr.ram_base, ax
	pop	dx
	ret
lm_gc_594_ram_base_mismatch:
	mov	word ptr lm_gc_struc_ptr.ram_base+2, dx
	mov	word ptr lm_gc_struc_ptr.ram_base, ax
	pop	dx
	or	dx, RAM_BASE_MISMATCH
	ret
lm_gc_594_ram_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_594_ram_size
ENDIF
lm_gc_594_ram_size	proc	near

	push	dx
	mov	dx, CNFG_POS_REG3
	in	al, dx
	jmp	$+2
	pop	dx
	and	al, 030h
	mov	cl, 4
	shr	al, cl
	mov	cl, al
	mov	ax, CNFG_SIZE_8kb
	shl	ax, cl
	mov	lm_gc_struc_ptr.ram_usable, ax

	cmp	lm_gc_struc_ptr.pos_id, CNFG_ID_8115TRA
	jne	NoRamPaging
        mov     ax, CNFG_SIZE_64kb
NoRamPaging:
	cmp	lm_gc_struc_ptr.ram_size, ax
	mov	lm_gc_struc_ptr.ram_size, ax
	jne	lm_gc_594_ram_size_mismatch
	mov	ax, SUCCESS
	ret
lm_gc_594_ram_size_mismatch:
;	mov	ax, CONFIG_WARNING
	or	dx, RAM_SIZE_MISMATCH
	ret
lm_gc_594_ram_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_594_rom_base
ENDIF
lm_gc_594_rom_base	proc	near

	push	dx
	mov	dx, CNFG_POS_REG4
	in	al, dx
	jmp	$+2
	mov	dx, 0Dh
	test	al, 08h
	jnz	rom_above_cseg
	mov	dx, 0Ch
rom_above_cseg:
	xor	ah, ah
	and	al, 07h
	mov	cl, 13
	shl	ax, cl
	mov	word ptr lm_gc_struc_ptr.rom_base, ax
	mov	word ptr lm_gc_struc_ptr.rom_base+2, dx
	pop	dx
	ret

lm_gc_594_rom_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_594_rom_size
ENDIF
lm_gc_594_rom_size	proc	near

	push	dx
	mov	dx, CNFG_POS_REG4
	in	al, dx
	jmp	$+2
	mov	cl, 4
	shr	al, cl
	mov	ah, CNFG_SIZE_8kb
	or	al, al
	jz	lm_gc_594_rs_out
	mov	ah, CNFG_SIZE_16kb
	dec	al
	jz	lm_gc_594_rs_out
	mov	ah, CNFG_SIZE_32kb
	dec	al
	jz	lm_gc_594_rs_out
	mov	ah, ROM_DISABLE
	dec	al
lm_gc_594_rs_out:
	xchg	ah, al
	mov	lm_gc_struc_ptr.rom_size, ax
	pop	dx
	ret

lm_gc_594_rom_size	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
	public	lm_gc_594_media_type
ENDIF
lm_gc_594_media_type	proc	near

	push	bx
	push	dx
	mov	dx, CNFG_POS_REG5
 	in	al, dx
	and	al, CNFG_MEDIA_TYPE_MASK

ifdef	ETHERNET
ifdef	TOKEN_RING
	mov	bx, lm_gc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	jne	Get594TokenMedia
endif
	xor	bx, bx
	or	bl, al
	cmp	bl, MEDIA_AUI_UTP
	jne	Media594NoAdjust
	mov	ax, lm_gc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, ETHERNET_MEDIA
	jne	Media594NoAdjust
	mov	bx, MEDIA_AUI
Media594NoAdjust:
endif
ifdef	TOKEN_RING

Get594TokenMedia:
	cmp	al, 01h
	jne	$1
	mov	bx, MEDIA_STP_16
	jmp	lm_gc_594_mt_done

$1:	cmp	al, 00h
  	jne	$2
	mov	bx, MEDIA_STP_4
	jmp	lm_gc_594_mt_done

$2:	cmp	al, 03h
  	jne	$3
	mov	bx, MEDIA_UTP_16
	jmp	lm_gc_594_mt_done

$3:	mov	bx, MEDIA_UTP_4		; AL Must be 02h, so UTP_4 it!
endif
lm_gc_594_mt_done:
	mov	lm_gc_struc_ptr.media_type, bx
	pop	dx
	pop	bx
	ret
lm_gc_594_media_type	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_gc_token_mode
ENDIF
lm_gc_token_mode	proc	near

	push	dx
	mov	dx, CNFG_POS_REG2
 	in	al, dx
	test	al, DCFG_ETRD
	jnz	lm_gc_no_etr
	or	lm_gc_struc_ptr.mode_bits, EARLY_TOKEN_REL
lm_gc_no_etr:
	pop	dx
	ret
lm_gc_token_mode	endp
;**************************************
;	on entry ax: POSID
;
;	return:	zero flag is set if the
;	ID is in the group
;***************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_check_593_group
ENDIF
lm_gc_check_593_group	proc	near
IFNDEF	BISTRO
	cmp	ax, CNFG_ID_8003E
	jz	lm_gc_Checked_593_out
	cmp	ax, CNFG_ID_8003S
	jz	lm_gc_Checked_593_out
	cmp	ax, CNFG_ID_8003W
	jz	lm_gc_Checked_593_out
ENDIF
	cmp	ax, CNFG_ID_BISTRO03E
	jz	lm_gc_Checked_593_out
lm_gc_Checked_593_out:
	ret

lm_gc_check_593_group	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_check_594_group
ENDIF
lm_gc_check_594_group	proc	near

ifdef	ETHERNET
IFNDEF	BISTRO
	cmp	ax, CNFG_ID_8013E
	jz	lm_gc_Checked_594_out
	cmp	ax, CNFG_ID_8013W
	jz	lm_gc_Checked_594_out
ENDIF
	cmp	ax, CNFG_ID_BISTRO13E
	jz	lm_gc_Checked_594_out
	cmp	ax, CNFG_ID_BISTRO13W
	jz	lm_gc_Checked_594_out		; In case both ETHERNET and
endif						; TOKEN_RING are defined.
ifdef	TOKEN_RING
	cmp	ax, CNFG_ID_8115TRA
	jnz	lm_gc_Checked_594_out
	or	lm_gc_struc_ptr.board_id, TOKEN_MEDIA
	xor	ax, ax
endif
lm_gc_Checked_594_out:
	ret

lm_gc_check_594_group	endp

endif ; #6
;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_get_at_config
ENDIF
lm_gc_get_at_config	proc	near

	mov	dx, lm_gc_struc_ptr.io_base
	call	lm_gc_is_board_there
	jz	lm_gc_at_got_board
	jmp	lm_gc_at_no_board
lm_gc_at_got_board:
	mov	lm_gc_struc_ptr.media_opts, 0	; Init media fields.
	mov	lm_gc_struc_ptr.media_set, 0
	mov	ax, 0
	mov	dx, 0
	call	lm_gc_get_bid
	call	lm_gc_copy_bid_ram_size

ifdef	UBIO	; #7
	test	lm_gc_struc_ptr.extra_info, NIC_790_BIT
	jnz	Test795Bit
	jmp	lm_gc_at_no_board
Test795Bit:
	test	lm_gc_struc_ptr.board_id, NIC_SUPERSET
	jnz	Entry795Point
	jmp	lm_gc_at_no_board
else		; #7
	test	lm_gc_struc_ptr.board_id, INTERFACE_CHIP
        jz	lm_gc_at_no_chip

        mov     lm_gc_struc_ptr.bic_type, BIC_583_CHIP
	mov	ax, lm_gc_struc_ptr.extra_info
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_5X3_CHIP
        je      lm_gc_set_583
	cmp	ax, INTERFACE_585_CHIP
	jne	lm_gc_set_584
endif		; #7
Entry795Point:
	mov     lm_gc_struc_ptr.bic_type, BIC_585_CHIP
	jmp	lm_gc_set_583
lm_gc_set_584:
        mov     lm_gc_struc_ptr.bic_type, BIC_584_CHIP

lm_gc_set_583:
       	call	lm_gc_58x_irq
	call	lm_gc_58x_irq_status
	call	lm_gc_58x_ram_base
	call	lm_gc_58x_rom_base
	call	lm_gc_58x_rom_size
	call	lm_gc_58x_boot_status
	call	lm_gc_58x_zero_wait_state
	call	lm_gc_adv_features
	call	lm_gc_adap_type
	call	lm_gc_extended_media

ifndef	UBIO	; #8
	cmp	lm_gc_struc_ptr.bic_type, BIC_584_CHIP
	jne	ChecksumOk
	
ifdef	TOKEN_RING
	call	Read584Checksum
	cmp	ax, SUCCESS
	je	ChecksumOk
	ret
endif
ifndef	LANWORKS
ifdef	SETUP_MODE
	call	Read584Checksum
	cmp	ax, SUCCESS
	je	ChecksumOk
	ret
endif
endif
endif		; #8
ChecksumOk:
	or	dx, dx
	jnz	lm_gc_at_warning_exit
	mov	ax, ADAPTER_AND_CONFIG
	ret
lm_gc_at_warning_exit:
	mov	ax, CONFIG_WARNING
	ret
ifndef	UBIO	; #9
lm_gc_at_no_chip:
	or	lm_gc_struc_ptr.mode_bits, INTERRUPT_STATUS_BIT
	mov	lm_gc_struc_ptr.media_type, MEDIA_UNKNOWN
        mov     lm_gc_struc_ptr.bic_type, BIC_NO_CHIP
	call	lm_verify_nadd			; If not INTERFACE_CHIP type
	ret					; adapter, verify that LAN
						; address prefix is 00 00 C0.
endif		; #9
lm_gc_at_no_board:
	mov	ax, ADAPTER_NOT_FOUND
	ret

lm_gc_get_at_config	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_copy_bid_ram_size
ENDIF
lm_gc_copy_bid_ram_size	proc	near

	mov	ax, lm_gc_struc_ptr.extra_info
	and	ax, RAM_SIZE_MASK
	cmp	ax, RAM_SIZE_8K
	jb	lm_gc_cbidrs_exit
	cmp	ax, RAM_SIZE_64K
	ja	lm_gc_cbidrs_exit
	mov	cl, al
	dec	cl
	dec	cl
	mov	ax, CNFG_SIZE_8kb
	shl	ax, cl
	cmp	lm_gc_struc_ptr.ram_size, ax	; Save RAM physical size
	mov	lm_gc_struc_ptr.ram_size, ax
	je	PhysRamSizeOk
	or	dx, RAM_SIZE_MISMATCH
PhysRamSizeOk:
	test	lm_gc_struc_ptr.board_id, PAGED_RAM
	jz	NotPagedRam
	mov	ax, CNFG_SIZE_16kb
NotPagedRam:
	cmp	lm_gc_struc_ptr.ram_usable, ax	; Save RAM window size
	mov	lm_gc_struc_ptr.ram_usable, ax	; Save RAM window size
	je	lm_gc_cbidrs_exit
	or	dx, RAM_SIZE_MISMATCH
lm_gc_cbidrs_exit:
	ret

lm_gc_copy_bid_ram_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_58x_irq
ENDIF
lm_gc_58x_irq	proc	near
	push	dx
	mov	dx, lm_gc_struc_ptr.io_base

ifndef	UBIO	; #10

	mov	ax, lm_gc_struc_ptr.extra_info
	mov	ch, 0
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_5X3_CHIP
	jne	lm_gc_check_584_chip
	jmp	lm_gc_not_584_chip
lm_gc_check_584_chip:
	cmp	ax, INTERFACE_584_CHIP
	jne	Assume585Chip
	jmp	lm_gc_584_chip

endif		; #10

Assume585Chip:
	push	bx
	push	dx			; Save I/O Base address
	add	dx, REG_HWR
	in	al, dx
	and	al, 0C3h
	mov	ah, al			; Save REG_HWR original value in AH.
	or	al, HWR_SWH
	out	dx, al
	add	dx, REG_GCR - REG_HWR	; Subtract REG_HWR, add REG_GCR.

	jmp	Continue585Irq

Internal585Irq:				; Called from somewhere else.
	push	dx
	push	bx
	push	dx			; World's finest Spaghetti coding.

Continue585Irq:
	in	al, dx			; Get REG_GCR Contents
	mov	bl, al
	mov	cl, 2			; Shift count for IR0 & IR1.
	and	al, GCR_IR0+GCR_IR1	; Mask all but IR0 and IR1
	shr	al, cl			; Shift IR0 & IR1 to bits 0 & 1.
	mov	cl, 4			; Shift count for IR2.
	and	bl, GCR_IR2		; Mask all but IR2
	shr	bl, cl			; Shift IR2 to bit 2.
	or	bl, al			; Final index is in BL
	add	dx, REG_HWR - REG_GCR	; Subtract REG_GCR, add REG_HWR
	mov	al, ah			; Get orig REG_HWR into AL.
	out	dx, al			; Restore original REG_HWR
	mov	al, bl			; Get indexed IRQ in al.
	pop	dx			; Restore orig I/O Base add. to DX
	pop	bx
	cmp	al, 0
	jne	lm_gc_585_int01
	mov	ax, 0			; Index 0 = IRQ (None)
	jmp	lm_gc_58x_irq_done
lm_gc_585_int01:			; 
	cmp	al, 1			; Index 1 = IRQ 2/9
	jne	lm_gc_585_int02
ifdef	NEC
	mov	ax, 3
else
	mov	ax, 2
endif
	jmp	lm_gc_58x_irq_done	
lm_gc_585_int02:
	cmp	al, 2
	jne	lm_gc_585_int03
ifdef	NEC
	mov	ax, 5
else
	mov	ax, 3	       		; Index 2 = IRQ 3
endif
	jmp	lm_gc_58x_irq_done	
lm_gc_585_int03:
	cmp	al, 3
	jne	lm_gc_585_int04
	test	lm_gc_struc_ptr.board_id, BOARD_16BIT
	jnz	IsIrq5
	mov	ax, 4			; Index 3 = IRQ 4 for 8 bit
	jmp	lm_gc_58x_irq_done			      
IsIrq5:
ifdef	NEC
	mov	ax, 6
else
	mov	ax, 5	       		; Index 3 = IRQ 5 for 16 bit
endif
	jmp	lm_gc_58x_irq_done	
lm_gc_585_int04:
	cmp	al, 4
	jne	lm_gc_585_int05
	test	lm_gc_struc_ptr.board_id, BOARD_16BIT
	jnz	IsIrq7
	mov	ax, 5			; Index 4 = IRQ 5 for 8 bit
	jmp	lm_gc_58x_irq_done	
IsIrq7:
ifdef	NEC
	mov	ax, 0
else
	mov	ax, 7
endif
      	jmp	lm_gc_58x_irq_done	
lm_gc_585_int05:
	cmp	al, 5
	jne	lm_gc_585_int06
	test	lm_gc_struc_ptr.board_id, BOARD_16BIT
	jnz	IsIrq10
	mov	ax, 7  			; Index 5 = IRQ 7 for 8 bit
	jmp	lm_gc_58x_irq_done		 	 
IsIrq10:
ifdef	NEC
	mov	ax, 9
else
	mov	ax, 10	       		; Index 5 = IRQ 10 for 16 bit
endif
       	jmp	lm_gc_58x_irq_done				     
lm_gc_585_int06:
	cmp	al, 6
	jne	lm_gc_585_int07
	test	lm_gc_struc_ptr.board_id, BOARD_16BIT
	jnz	IsIrq11
	mov	ax, 0  			; Index 6 = Not valid for 8 bit
	jmp	lm_gc_58x_irq_done		 	     
IsIrq11:
ifdef	NEC
	mov	ax, 12
else
       	mov	ax, 11	       		; Index 6 = IRQ 11 for 16 bit
endif
	jmp	lm_gc_58x_irq_done	
lm_gc_585_int07:			; Index must be 7, which = IRQ 15
	test	lm_gc_struc_ptr.board_id, BOARD_16BIT
	jnz	IsIrq15
	mov	ax, 0  			; Index 7 = Not valid for 8 bit
	jmp	lm_gc_58x_irq_done		 	     
IsIrq15:
ifdef	NEC
	mov	ax, 13
else
       	mov	ax, 15			; 
endif
	jmp	lm_gc_58x_irq_done	; 
ifndef	UBIO	; #11
Internal584Irq:
	push	dx
lm_gc_584_chip:				; 
	push	dx
	add	dx, REG_ICR
	in	al, dx
	jmp	$+2
	pop	dx
	and	al, ICR_IR2
	mov	ch, al
lm_gc_not_584_chip:
	add	dx, REG_IRR
	in	al,dx
	jmp	$+2
	and	al, IRR_IR0+IRR_IR1	; Mask all but IR1 & IR0
	mov	cl, 5
	shr	al, cl
	cmp	al, 0
	jne	lm_not_irq_0
	or	ch, ch
	jz	lm_gc_no_adjust_1
	mov	ah, 10
	jmp	short lm_gc_load_58x_irq
lm_gc_no_adjust_1:
	mov	ah, 2
	jmp	short lm_gc_load_58x_irq
lm_not_irq_0:
	cmp	al, 1
	jne	lm_gc_not_irq1
	or	ch, ch
	jz	lm_gc_no_adjust_2
	mov	ah, 11
	jmp	short lm_gc_load_58x_irq
lm_gc_no_adjust_2:
	mov	ah, 3
	jmp	short lm_gc_load_58x_irq
lm_gc_not_irq1:
	cmp	al, 2
	jne	lm_gc_not_irq_2
	or	ch, ch
	jz	lm_gc_no_adjust_3
	mov	ah, 15
	jmp	short lm_gc_load_58x_irq
lm_gc_no_adjust_3:
	mov	ah, 4
	test	lm_gc_struc_ptr.extra_info, ALTERNATE_IRQ_BIT
	jz	lm_gc_load_58x_irq
	mov	ah, 5
	jmp	short lm_gc_load_58x_irq
lm_gc_not_irq_2:
	cmp	al, 3
	jne	lm_gc_irq_error
	or	ch, ch
	jz	lm_gc_no_adjust_4
	mov	ah, 4
	jmp	short lm_gc_load_58x_irq
lm_gc_no_adjust_4:
	mov	ah, 7
	jmp	short lm_gc_load_58x_irq
lm_gc_irq_error:
	mov	ah, 03h
lm_gc_load_58x_irq:
	xor	al, al
	xchg	ah, al

endif		; #11

lm_gc_58x_irq_done:
	cmp	lm_gc_struc_ptr.irq_value, ax
	mov	lm_gc_struc_ptr.irq_value, ax
	pop	dx
	jne	lm_gc_58x_irq_mismatch
	ret
lm_gc_58x_irq_mismatch:
	or	dx, IRQ_MISMATCH
	ret
lm_gc_58x_irq	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public	lm_gc_58x_irq_status
ENDIF
lm_gc_58x_irq_status	proc	near
	push	bx
	push	dx
	mov	dx, lm_gc_struc_ptr.io_base
	mov	bx, lm_gc_struc_ptr.mode_bits
	and	bx, NOT INTERRUPT_STATUS_BIT
	mov	ax, lm_gc_struc_ptr.extra_info
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_585_CHIP
	jne	irq_stat_584
	cmp	lm_gc_struc_ptr.irq_value, 0
	je	lm_gc_58x_is_disabled
	jmp	lm_gc_58x_is_enabled

irq_stat_584:
	add	dx, REG_IRR
	in	al,dx
	jmp	$+2
	and	al, IRR_IEN
	jz	lm_gc_58x_is_disabled
lm_gc_58x_is_enabled:
	or	bx, INTERRUPT_STATUS_BIT
lm_gc_58x_is_disabled:
	mov	lm_gc_struc_ptr.mode_bits, bx
	pop	dx
	pop	bx
	ret

lm_gc_58x_irq_status	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public	lm_gc_58x_boot_status
ENDIF
lm_gc_58x_boot_status	proc	near
	push	bx
	push	dx
	mov	bx, lm_gc_struc_ptr.mode_bits
	and	bx, NOT BOOT_STATUS_MASK
	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, CNFG_GP2
	in	al,dx
	jmp	$+2
	and	al, CNFG_GP2_BOOT_NIBBLE
	jnz	lm_gc_58x_bs_disabled
	or	bx, BOOT_TYPE_1
lm_gc_58x_bs_disabled:
	mov	lm_gc_struc_ptr.mode_bits, bx
	pop	dx
	pop	bx
	ret

lm_gc_58x_boot_status	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_58x_zero_wait_state
ENDIF
lm_gc_58x_zero_wait_state	proc	near
	push	bx
	push	dx
ifndef NT_CODE
	pushf
	cli
endif
	mov	bx, lm_gc_struc_ptr.mode_bits
	and	bx, NOT ZERO_WAIT_STATE_MASK
	mov	dx, lm_gc_struc_ptr.io_base

ifndef	UBIO	; #12
	cmp	lm_gc_struc_ptr.bic_type, BIC_585_CHIP
	jne	Do58xZws

endif		; #12
	add	dx, REG_HWR
	mov	al, HWR_SWH
	out	dx, al
	add	dx, REG_GCR - REG_HWR
	in	al, dx
	test	al, GCR_0WS
	jz	Zws790Disabled
	or	bx, ZERO_WAIT_STATE_8_BIT + ZERO_WAIT_STATE_16_BIT
Zws790Disabled:
	add	dx, REG_HWR - REG_GCR
	mov	al, 0
	out	dx, al
	jmp	lm_gc_58x_zws16_disabled
ifndef	UBIO	; #13
Do58xZws:
	push	dx
	add	dx, REG_IRR
	in	al, dx
	jmp	$+2
	pop	dx
	and	al, IRR_0WS8
	jz	lm_gc_58x_zws8_disabled
	or	bx, ZERO_WAIT_STATE_8_BIT
lm_gc_58x_zws8_disabled:
	test	lm_gc_struc_ptr.board_id, BOARD_16BIT
	jz	lm_gc_58x_zws16_disabled
	add	dx, REG_LAAR
	in	al, dx
	and	al, LAAR_0WS16
	jz	lm_gc_58x_zws16_disabled
	or	bx, ZERO_WAIT_STATE_16_BIT

endif		; #13	

lm_gc_58x_zws16_disabled:
	mov	lm_gc_struc_ptr.mode_bits, bx

ifndef	NT_CODE
	$POPFF
endif
	pop	dx
	pop	bx
	ret

lm_gc_58x_zero_wait_state	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
; lm_gc_extended_media
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lm_gc_extended_media	proc	near

	push	ax
	push	bx
	push	cx
	push	dx

	test	lm_gc_struc_ptr.media_opts, 0FFh
	jnz	check_ext_media
	jmp	lm_gc_ext_media_exit

check_ext_media:
	cmp	lm_gc_struc_ptr.bic_type, BIC_585_CHIP
	je	get_585_ex_media
	cmp	lm_gc_struc_ptr.bic_type, BIC_584_CHIP
	je	get_584_ex_media
	jmp	lm_gc_ext_media_exit

get_585_ex_media:
	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_HWR
	mov	al, HWR_SWH
	out	dx, al
	add	dx, REG_GCR - REG_HWR
	in	al, dx
	mov	ah, al
	mov	al, 0
	add	dx, REG_HWR - REG_GCR
	out	dx, al
	mov	al, ah
	shl	al, 1				; Align bits to match 584 definition ...
	jmp	eth_585_entry			; cut in ahead of 584 specific stuff

get_584_ex_media:
	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_IRR
	in	al, dx

	mov	bx, lm_gc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	je	ex_media_584_token

	test	lm_gc_struc_ptr.board_id, ADVANCED_FEATURES
	jnz	no_LITE_invert
	xor	al, IRR_LITE			; Pre-ADVANCED_FEATURE Ethernet
						; adapter has inverted IRR_LITE bit ...
no_LITE_invert:
	test	lm_gc_struc_ptr.board_id, ADVANCED_FEATURES
	jz	assume_BNC_set

eth_585_entry:
	mov	bx, lm_gc_struc_ptr.media_opts
	and	bx, MED_OPT_10MB+MED_OPT_100MB
	or	lm_gc_struc_ptr.media_set, bx

	test	al, IRR_BNC
	jz	test_eth_AUI

assume_BNC_set:
	test	lm_gc_struc_ptr.media_opts, MED_OPT_BNC
	jz	test_eth_AUI

	test	al, IRR_LITE
	jnz	set_584_BNC_only
	or	lm_gc_struc_ptr.media_set, MED_OPT_S10
	jmp	lm_gc_ext_media_exit	

set_584_BNC_only:
	or	lm_gc_struc_ptr.media_set, MED_OPT_BNC
	test	lm_gc_struc_ptr.board_id, ADVANCED_FEATURES
	jz	test_eth_AUI

	jmp	test_eth_utp

test_eth_AUI:
	test	lm_gc_struc_ptr.media_opts, MED_OPT_AUI
	jz	test_eth_utp

	test	al, IRR_LITE
	jnz	set_eth_AUI

	or	lm_gc_struc_ptr.media_set, MED_OPT_S10
	jmp	lm_gc_ext_media_exit

set_eth_AUI:
	or	lm_gc_struc_ptr.media_set, MED_OPT_AUI
	
test_eth_utp:
	test	lm_gc_struc_ptr.media_opts, MED_OPT_UTP
	jz	eth_no_utp

	test	al, IRR_LITE
	jnz	set_eth_utp

	or	lm_gc_struc_ptr.media_set, MED_OPT_S10
	jmp	lm_gc_ext_media_exit

set_eth_utp:
	or	lm_gc_struc_ptr.media_set, MED_OPT_UTP

eth_no_utp:
	jmp	lm_gc_ext_media_exit

ex_media_584_token:
	test	al, IRR_UTP
	jz	test_tok_stp
	test	lm_gc_struc_ptr.media_opts, MED_OPT_UTP
	jz	test_tok_stp
	or	lm_gc_struc_ptr.media_set, MED_OPT_UTP
	jmp	test_tok_16mb

test_tok_stp:
	test	al, IRR_UTP
	jnz	test_tok_16mb
	test	lm_gc_struc_ptr.media_opts, MED_OPT_STP
	jz	test_tok_16mb
	or	lm_gc_struc_ptr.media_set, MED_OPT_STP

test_tok_16mb:
	test	al, IRR_16MBPS
	jz	test_tok_4mb
	test	lm_gc_struc_ptr.media_opts, MED_OPT_16MB
	jz	test_tok_4mb
	or	lm_gc_struc_ptr.media_set, MED_OPT_16MB

test_tok_4mb:
	test	al, IRR_16MBPS
	jnz	lm_gc_ext_media_exit
	test	lm_gc_struc_ptr.media_opts, MED_OPT_4MB
	jz	lm_gc_ext_media_exit
	or	lm_gc_struc_ptr.media_set, MED_OPT_4MB

lm_gc_ext_media_exit:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
lm_gc_extended_media	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Assumes: DS:BP -> CNFG_Structure
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IFDEF	LM_GC_DEBUG
	public lm_gc_adv_features
ENDIF

lm_gc_adv_features	proc	near
	push	bx
	push	cx
	push	dx
	mov	bx, lm_gc_struc_ptr.mode_bits
	and	bx, NOT INTERFACE_TYPE_MASK

ifndef	UBIO	; #14
	push	dx
	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_IRR
	in	al, dx
	jmp	$+2
	pop	dx
ifdef	TOKEN_RING
ifdef	ETHERNET
	mov	cx, lm_gc_struc_ptr.board_id
	and	cx, MEDIA_MASK
	cmp	cx, TOKEN_MEDIA
	je	GetTokenFeatures
	jmp	GetEnetFeatures
GetTokenFeatures:
endif	; (ETHERNET)
	cmp	lm_gc_struc_ptr.bic_type, BIC_584_CHIP
	je	TokenBic584
	cmp	lm_gc_struc_ptr.bic_type, BIC_585_CHIP
	je	TokenBic585
	mov	bx, MEDIA_UNKNOWN
	jmp	lm_gc_adv_done
TokenBic585:
	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_HWR
	in	al, dx
	and 	al, 0C3h
	or	al, HWR_SWH
	out	dx, al
	add	dx, REG_GCR - REG_HWR
	in	al, dx
	and	al, 03h
	mov	ah, al
	add	dx, REG_HWR - REG_GCR
	in	al, dx
	and	al, 043h
	out	dx, al
	mov	al, ah
	jmp	Continue585AdvFeat
TokenBic584:
	and	al, 06h
	xor	ah, ah
	shr	ax, 1
Continue585AdvFeat:
	cmp	al, 3
	jne	adv_01
	mov     bx, MEDIA_UTP_16
	jmp	lm_gc_adv_done
adv_01:	cmp	al, 2
	jne	adv_02
	mov	bx, MEDIA_STP_16
	jmp	lm_gc_adv_done
adv_02:	cmp	al, 1
	jne	adv_03
	mov	bx, MEDIA_UTP_4
	jmp	lm_gc_adv_done
adv_03:	mov	bx, MEDIA_STP_4
lm_gc_adv_done:	
	mov	lm_gc_struc_ptr.media_type, bx

; Check for Early Token Release Mode . . .
	mov	dx, lm_gc_struc_ptr.io_base
	cmp	lm_gc_struc_ptr.bic_type, BIC_584_CHIP
	je	Check584ETR
; Assume 585/790
	mov	bx, dx		; Save I/O Addr in BX
	add	dx, REG_HWR
	in	al, dx
	and	al, 043h
	jmp	$+2
	or	al, HWR_SWH
	out	dx, al		; Select Config register set
	mov	dx, bx		; Get I/O Addr again
	add	dx, REG_DCFG	; Get contents of DCFG
	in	al, dx
	mov	ah, al		; Save DCFG contents in AH
	mov	dx, bx		; Get I/O Addr again
	add	dx, REG_HWR
	in	al, dx
	jmp	$+2
	and	al, 43h		; Deselect Config register set
	out	dx, al		; 
	test	ah, DCFG_ETRD	; If bit is set, Early Token Release is disabled.
	jnz	NoETR
	jmp	SetETR
Check584ETR:
	add	dx, REG_GP2
	in	al, dx
	test	al, GP2_ETRD	; If bit is set, Early Token Release is disabled.
	jnz	NoETR
SetETR:
	or	lm_gc_struc_ptr.mode_bits, EARLY_TOKEN_REL
NoETR:
	pop	dx
	pop	cx
	pop	bx
	ret
endif	; (TOKEN RING)
;;;;;;;;;;;;;;;;
ifdef	ETHERNET
GetEnetFeatures:
	cmp	lm_gc_struc_ptr.bic_type, BIC_584_CHIP
	jne	Check585Chip
	test	lm_gc_struc_ptr.board_id, ADVANCED_FEATURES
	jz	AdvFeaturesDone

	test 	al, 02h				; If link test is disabled,
	jnz	lm_01				; I/F is STARLAN 10 always.
	or	bx, STARLAN_10_INTERFACE
	mov	lm_gc_struc_ptr.media_type, MEDIA_S10
	jmp	NoOtherInfo

lm_01:	test 	al, 04h
	jz	lm_02
	or	bx, BNC_INTERFACE		; If OUT2 is set, BNC DC-DC is
	mov	lm_gc_struc_ptr.media_type, MEDIA_BNC
	jmp	NoOtherInfo			; on.

lm_02:	mov	ax, lm_gc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, ETHERNET_MEDIA
	jne	Set584AUIMode
	or	bx, AUI_INTERFACE
	mov	lm_gc_struc_ptr.media_type, MEDIA_AUI
	jmp	NoOtherInfo

Set584AUIMode:
	or	bx, AUI_10BT_INTERFACE
	mov	lm_gc_struc_ptr.media_type, MEDIA_AUI_UTP
	jmp	NoOtherInfo
AdvFeaturesDone:
	test	al, 02h
	jnz	SetStarTenInterface
	jmp	UnknownNetInterface
SetStarTenInterface:
	or	bx, STARLAN_10_INTERFACE
	mov	lm_gc_struc_ptr.media_type, MEDIA_S10
	jmp	NoOtherInfo

Check585Chip:
	cmp	lm_gc_struc_ptr.bic_type, BIC_585_CHIP
	je	Ja585Chip
	jmp	UnknownNetInterface

Ja585Chip:
endif		; (ETHERNET)
endif		; #14

ifdef	ETHERNET

;
;	Check the BNC media first to see if it is active.
;
	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_HWR
	in	al, dx
	and	al, 043h
	jmp	$+2
	or	al, HWR_SWH
	out	dx, al		; Select Config register set

	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_GCR
	in	al, dx
	and	al, GCR_GPOUT+GCR_LITE
	mov	ah, al				; AH = BNC and link integrity

	mov	dx, lm_gc_struc_ptr.io_base
	add	dx, REG_HWR
	in	al, dx
	jmp	$+2
	and	al, 43h
	out	dx, al		; Deselect Config register set
	mov	al, ah

	cmp	lm_gc_struc_ptr.board_id, WD8216T2
	jne	CheckOtherUtps

	and	bx, not UTP2_PORT
	test	al, GCR_GPOUT
	jz	T2PortA

	or	bx, UTP2_PORT

T2PortA:
	jmp	MediaUTP_Type

CheckOtherUtps:
	cmp	al, GCR_LITE			; Link Integrity only?
	jne	Check585Bnc			; JIF BNC active
;
;	BNC is off so check the "COMBO" and "T" cards for UTP and/or AUI
;	media types.
;
	mov	ax, lm_gc_struc_ptr.board_id

	test	ax, LITE_VERSION		; Tiger board?
	jnz	MediaUTP_Type			; JIF yes, use UTP, NO AUI

	and	ax, MEDIA_MASK			; Isolate media types

	cmp	ax, TWISTED_PAIR_MEDIA		; "T" card?
	je	MediaUTP_Type			; JIF yes, NO AUI

	cmp	ax, EW_MEDIA			; "C" card?
	je	MediaComboType			; JIF yes, AUI
						; Else 
	or	bx, AUI_INTERFACE		;       ETHERNET_MEDIA type
	mov	lm_gc_struc_ptr.media_type, MEDIA_AUI ; AUI only (BNC is off)

	jmp	NoOtherInfo
	
MediaComboType:
	mov	lm_gc_struc_ptr.media_type, MEDIA_AUI_UTP
	or	bx, AUI_10BT_INTERFACE
	jmp	NoOtherInfo

MediaUTP_Type:
	test	lm_gc_struc_ptr.media_opts, MED_OPT_AUI
	jz	SetUTPOnly

	mov	lm_gc_struc_ptr.media_type, MEDIA_AUI_UTP
	or	bx, AUI_10BT_INTERFACE
	jmp	NoOtherInfo
	
SetUTPOnly:
	mov	lm_gc_struc_ptr.media_type, MEDIA_UTP
	or	bx, UTP_INTERFACE
	jmp	NoOtherInfo
	
Check585Bnc:
	cmp	al, GCR_GPOUT+GCR_LITE
	jne	Starlan585Ten

	test	lm_gc_struc_ptr.media_opts, MED_OPT_UTP
	jz	SetBNCOnly

	mov	lm_gc_struc_ptr.media_type, MEDIA_BNC_UTP
	or	bx, BNC_10BT_INTERFACE
	jmp	NoOtherInfo

SetBNCOnly:
	mov	lm_gc_struc_ptr.media_type, MEDIA_BNC
	or	bx, BNC_INTERFACE
	jmp	NoOtherInfo

Starlan585Ten:
	mov	lm_gc_struc_ptr.media_type, MEDIA_S10
	or	bx, STARLAN_10_INTERFACE
NoOtherInfo:
	mov	lm_gc_struc_ptr.mode_bits, bx
	pop	dx
	pop	cx
	pop	bx
	ret

UnknownNetInterface:
	mov	lm_gc_struc_ptr.media_type, MEDIA_UNKNOWN
	jmp	NoOtherInfo
endif
lm_gc_adv_features	endp


;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_58x_ram_base
ENDIF
lm_gc_58x_ram_base	proc	near
	push	dx
	push	si
	mov	dx, lm_gc_struc_ptr.io_base

ifndef	UBIO	; #15

	in	al, dx
	jmp	$+2
	and	al, 03Fh
	mov	cx, lm_gc_struc_ptr.extra_info
	and	cx, INTERFACE_CHIP_MASK
	cmp	cx, INTERFACE_5X3_CHIP
	jne	lm_gc_yes_laar
	jmp	lm_gc_no_laar
lm_gc_yes_laar:
	cmp	cx, INTERFACE_585_CHIP
	jne	ram_base_584

endif		; #15

	add	dx, REG_HWR
	in	al, dx
	and	al, 0C3h
	mov	ah, al			; Save REG_HWR contents in AH
	or	al, HWR_SWH		; Select Config register set
	out	dx, al
	add	dx, REG_RAR - REG_HWR	; Subtract REG_HWR, add REG_RAR
	jmp	Continue585RamBase

Internal585RamBase:
	push	dx
	push	si
Continue585RamBase:
	in	al, dx			; Get REG_RAR (RAM Address) reg
					; contents
	and	al, RAR_RWS0+RAR_RWS1
	mov	cl, 4
	shr	al, cl
	mov	cl, al
	mov	ch, 8
	shl	ch, cl
	mov	cl, ch
	mov	ch, 0
	mov	lm_gc_struc_ptr.ram_usable, cx
	in	al, dx
	and	al, 07h			; Isolate bits 15-13
	xor	bx, bx			; Clear BX
	mov	cl, 5			; Shift count for bits 15-13
	mov	bh, al			; BX now contains low word of RAM
	shl	bx, cl			; address.
	mov	si, bx			; Save low word in SI.
	xor	bx, bx			; Clear BX again
	in	al, dx
	mov	ch, al			; Copy to CH
	and	al, RAR_RA16		; Isolate bit 16
	mov	cl, 3
	shr	al, cl			; Get bit 16 into position (bit 0)
	and	ch, RAR_RA17		; Isolate bit 17 in CH
	mov	cl, 5
	shr	ch, cl			; Get bit 17 into position (bit 1)
	or	al, ch			; Combine in AL.
	or	al, 0Ch			; Set bits 18 & 19 (LA19:18 assumed
					; to be 1's)
	mov	bl, al			; BX now contains high word of RAM
					; address.
	in	al, dx			; Get RAR contents again
	test	al, RAR_HRAM		; Check if RAM MS Nibble is 0 or Fh
	jz	ram_base_low
	or	bx, 00F0h		; If RAR_HRAM is set, add 0F00000 to
					; physical RAM address.
ram_base_low:
	mov	al, ah
	add	dx, REG_HWR - REG_RAR	; Subtract REG_RAR, add REG_HWR
	out	dx, al			; Restore REG_HWR
	mov	dx, bx
	mov	ax, si			; Get RAM address in DX AX

ifndef	UBIO	; #16

	jmp	lm_gc_load_base

Internal584RamBase:
	push	dx
	push	si
ram_base_584:
	mov	ah, al
	add	dx, REG_LAAR
	in	al, dx
	jmp	$+2
	and	al, LAAR_MASK
	mov	cl, 3
	shl	al, cl
	mov	dl, al
	xor	dh, dh
	mov	bl, ah
	and	bl, 038h
	mov	cl, 3
	shr	bl, cl
	or	dl, bl
	and	ah, 07h
	mov	cl, 5
	shl	ah, cl
	xor	al, al
	jmp	short lm_gc_load_base
lm_gc_no_laar:
	or	al, 040h
	mov	cl, 5
	shl	ax, cl
	xor	dx, dx
	xchg	dl, ah
	mov	cl, 8
	shl	ax, cl

endif		; #16

lm_gc_load_base:
	pop	si
	cmp	word ptr lm_gc_struc_ptr.ram_base, ax
	jne	lm_gc_58x_ram_base_mismatch
	cmp	word ptr lm_gc_struc_ptr.ram_base+2, dx
	jne	lm_gc_58x_ram_base_mismatch
	mov	word ptr lm_gc_struc_ptr.ram_base, ax
	mov	word ptr lm_gc_struc_ptr.ram_base+2, dx
	pop	dx
	ret

lm_gc_58x_ram_base_mismatch:
	mov	word ptr lm_gc_struc_ptr.ram_base, ax
	mov	word ptr lm_gc_struc_ptr.ram_base+2, dx
	pop	dx
	or	dx, RAM_BASE_MISMATCH
	ret

lm_gc_58x_ram_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_58x_rom_base
ENDIF
lm_gc_58x_rom_base	proc	near ;
	push	si
	push	dx
	mov	dx, lm_gc_struc_ptr.io_base
ifndef	UBIO	; #17
	jmp	Continue584RomBase
Internal584RomBase:
	push	si
	push	dx
Continue584RomBase:
	add	dx, REG_BIO
	in	al, dx

	mov	cx, lm_gc_struc_ptr.extra_info
	and	cx, INTERFACE_CHIP_MASK
	cmp	cx, INTERFACE_585_CHIP
	jne	rom_base_not_585
	add	dx, REG_HWR - REG_BIO
else		; #17
	add	dx, REG_HWR
endif		; #17

	in	al, dx
	and	al, 0C3h
	mov	ah, al			; Save REG_HWR contents in AH
	or	al, HWR_SWH		; Select Config register set
	out	dx, al
	add	dx, REG_BAR - REG_HWR	; Subtract REG_HWR, add REG_BAR
	jmp	Continue585RomBase
Internal585RomBase:
	push	si
	push	dx
Continue585RomBase:
	in	al, dx			; Get REG_BAR (ROM Address) reg
					; contents
	and	al, 07h			; Isolate bits 15-13
	xor	bx, bx			; Clear BX
	mov	cl, 5			; Shift count for bits 15-13
	mov	bh, al			; BX now contains low word of ROM
	shl	bx, cl			; address.
	mov	si, bx			; Save low word in SI.
	xor	bx, bx			; Clear BX again
	in	al, dx
	mov	ch, al			; Copy to CH
	and	al, BAR_BA16		; Isolate bit 16
	mov	cl, 3	 
	shr	al, cl			; Get bit 16 into position (bit 0)
	and	ch, BAR_BA17		; Isolate bit 17 in CH
	mov	cl, 5	 
	shr	ch, cl			; Get bit 17 into position (bit 1)
	or	al, ch			; Combine in AL.
	or	al, 0Ch			; Set bits 18 & 19 (LA19:18 assumed
					; to be 1's)
	mov	bl, al			; BX now contains high word of ROM
					; address.
	mov	al, ah
	add	dx, REG_HWR - REG_BAR	; Subtract REG_BAR, add REG_HWR
	out	dx, al			; Restore REG_HWR
	mov	dx, bx
	mov	ax, si			; Get ROM address in DX AX
	jmp	lm_gc_load_rom_base

ifndef	UBIO	; #18

rom_base_not_585:

	xor	ah, ah
	and	al, 03eh
	or	al, 040h
	mov	cl, 5
	shl	ax, cl
	xor	dx, dx
	xchg	dl, ah
	mov	cl, 8
	shl	ax, cl

endif		; #18	

lm_gc_load_rom_base:
	mov	word ptr lm_gc_struc_ptr.rom_base, ax
	mov	word ptr lm_gc_struc_ptr.rom_base+2, dx
	pop	dx
	pop	si
	ret

lm_gc_58x_rom_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_58x_rom_size
ENDIF
lm_gc_58x_rom_size	proc	near
	push	dx
	mov	dx, lm_gc_struc_ptr.io_base

ifndef	UBIO	; #19

	mov	ax, lm_gc_struc_ptr.extra_info
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_585_CHIP
	jne	Rom584Size

endif		; #19

	add	dx, REG_HWR
	in	al, dx
	and	al, 0C3h
	or	al, HWR_SWH		; Select Config register set
	out	dx, al
	jmp	$+2
	add	dx, REG_BAR - REG_HWR	; Subtract REG_HWR, add REG_BAR
	jmp	Continue585RomSize
Internal585RomSize:
	push	dx
Continue585RomSize:
	in	al, dx
	and	al, BAR_BWS0+BAR_BWS1
	mov	cl, 4
	shr	al, cl
	mov	ah, al

	add	dx, REG_HWR - REG_BAR
	in	al, dx
	and	al, 043h		; Deselect Config register set
	out	dx, al
	jmp	$+2

	cmp	ah, 3
	je	lm_gc_inv_rom_size
	mov	al, ah

ifndef	UBIO	; #20

	jmp	FigureRomWindowSize

Internal584RomSize:
	push	dx
Rom584Size:	
	xor	ax, ax
	add	dx, REG_BIO
	in	al, dx
	jmp	$+2
	and	al, 0C0h
	jz	lm_gc_inv_rom_size
	mov	cl, 6
	shr	al, cl
FigureRomWindowSize:

endif		; #20

	mov	cl, al
	mov	ax, CNFG_SIZE_8kb
	shl	ax, cl
	mov	lm_gc_struc_ptr.rom_size, ax
	pop	dx
	ret
lm_gc_inv_rom_size:
	mov	lm_gc_struc_ptr.rom_size, ROM_DISABLE
	pop	dx
	ret

lm_gc_58x_rom_size	endp

;*************************************************************************
;
;	lm_gc_is_board_there
;
;	Given the I/O Base IsBoardThere checks for an adapter 
;	by computing a checksum on the LAN address bytes .
;	The eight bytes starting at offset 8 should total FFh.
;
;	assumes: dx has the I/O Base Address
;
;	returns: flag = zero if our board
;
;*************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_gc_is_board_there
ENDIF
lm_gc_is_board_there	proc	near
	push	dx
	push	cx
	push	bx
	push	ax

ifdef	NEC
        test    dx, 40h - 1     ; io base must be a multiple of 40h (NEC bus)
else
        test    dx, 20h - 1     ; io base must be a multiple of 20h
endif
        jne     GotChkSum

	xor	ah, ah		; Zero counter
	add	dx, REG_LAR0	; LANAddressZero
	mov	cx, 8		; loop count
lm_gc_ibt_loop:
	in	al,dx
	add	ah,al		; compute checksum
	inc	dx		;bump i/o pointer
ifdef	NEC
	inc	dx
endif
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	loop	lm_gc_ibt_loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	TOKEN_RING			; DO NOT CHANGE THIS CODE!!!!
	cmp	ah,0eeH			; DO NOT CHANGE THIS CODE!!!!
	jne	ChkEtherSum		; DO NOT CHANGE THIS CODE!!!!
	and	lm_gc_struc_ptr.board_id, not MEDIA_MASK
	or	lm_gc_struc_ptr.board_id, TOKEN_MEDIA
	xor	al, al			; Set Z flag
	jmp	GotChkSum

ChkEtherSum:
endif					; DO NOT CHANGE THIS CODE!!!!
ifdef	ETHERNET			; DO NOT CHANGE THIS CODE!!!!
	cmp	ah,0ffH			; DO NOT CHANGE THIS CODE!!!!
endif		      			; DO NOT CHANGE THIS CODE!!!!
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GotChkSum:
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret

lm_gc_is_board_there	endp
ifndef	UBIO	; #21
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_VERIFY_NADD	Compares LAN Address prefix with 00 00 C0. If no match,
;			returns AX = FFFFh, else AX = 0001h. Used to weed out
;			clone WD adapters that do not have a bus interface
;			chip.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	WD_GC_DEBUG
PUBLIC	lm_verify_nadd
ENDIF
lm_verify_nadd		proc	near

		push	dx
		mov	dx, lm_gc_struc_ptr.io_base
		add	dx, REG_LAR0
		in	al, dx	    	; Get 1st byte of LAN address in AL.
		jmp	$+2
		cmp	al, 0		; If WD, should be 00.
		jne	NotWDBoard
		inc	dx
ifdef	NEC
		inc	dx
endif
		in	al, dx		; Get 2nd byte of LAN address.
		jmp	$+2
		cmp	al, 0		; This byte should also be 00.
		jne	NotWDBoard
		inc	dx
ifdef	NEC
		inc	dx
endif
		in	al, dx		; Get 3rd byte of LAN address.
		jmp	$+2
		shr	al, 1		; Shift right by 1 so "C0" is not detectable
					; in executable file.
		cmp	al, 60h		; C0h >> 1 should equal 60h.
		jne	NotWDBoard
		mov	ax, ADAPTER_NO_CONFIG
		jmp	VerifyNaddExit

NotWDBoard:	mov	ax, ADAPTER_NOT_FOUND

VerifyNaddExit:
		pop	dx
		ret

lm_verify_nadd		endp

endif		; #21
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lm_gc_adap_type	proc	near

	cmp	lm_gc_struc_ptr.pc_bus, AT_BUS
	je	adap_type_not_MCA
	mov	lm_gc_struc_ptr.adapter_bus, BUS_MCA_TYPE
	jmp	lm_gc_adap_type_done
adap_type_not_MCA:	
	test	lm_gc_struc_ptr.extra_info, SLOT_16BIT
	jz	adap_type_notS16
       	mov	lm_gc_struc_ptr.adapter_bus, BUS_ISA16_TYPE
	jmp	lm_gc_adap_type_done

adap_type_notS16:
	mov	lm_gc_struc_ptr.adapter_bus, BUS_ISA8_TYPE

lm_gc_adap_type_done:
	ret
lm_gc_adap_type	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Check_For_585 routine checks for presence of 585/790 interface.
;	The routine BID_INTERFACE_CHIP will not recognize a 585 or 790
;	interface chip. This is accomplished by comparing data in the
;	LAN Address registers 0-5 while toggling the HWR_SWH bit. If
;	there is a 585 or 790 interface chip present, the value in a
;	given LAN Address register be different if read with SWH = 0
;	and compared to a read at the same offset with SWH = 1.
;	
;	Entry:	BX = I/O Base Address
;	      
;	Exit:	AX = -1 if Chip is 585 or 790.
;		      0 if Chip is not 585 or 790.
;		       
;
;****************************************************************************


ifdef	LM_GC_DEBUG
PUBLIC	check_for_585
endif

check_for_585	proc	near
	push	bx
	push	cx
	push	dx
	push	di
	push	si
ifndef NT_CODE
	pushf
	cli
endif
	mov	dx, bx
	mov	cx, 6			; Check LAR0-LAR5	
	add	dx, REG_HWR
	in	al, dx
	push	ax			; Save original reg value.
	and	al, 0C3h
	or	al, HWR_SWH
	out	dx, al			; Select Config registers
	mov	si, dx			; SI = HWR register
	mov	di, bx			; Get I/O Base into DI.
	add	di, REG_LAR0		; DI = LAR0 register.
LARLoop:
	mov	dx, di			; Get LARx register offset in DX.
	in	al, dx			; 
	mov	ah, al			; AH = LAR value
	mov	dx, si			; DX = HWR Register
	in	al, dx
	and	al, 0C3h
	xor	al, HWR_SWH
	jmp	$+2			; Give chip time to recover...
	out	dx, al			; Toggle Switch Register (SWH) bit.
	mov	dx, di			; Get LARx reg offset in DX again.
	in	al, dx			; At this point AL = LARx value
					; with SWH = 0, and AH = LARx value
					; with SWH = 1.
	cmp	ah, al			; If AH != AL, there must be a 585
	jne	Is585Chip		; or 790 bus interface chip.
	inc	di
ifdef NEC
	inc	di
endif
	loop	LARLoop

	pop	ax			; Restore stack pointer
	mov	dx, si
	out	dx, al
	xor	ax, ax			; Set return code.
	jmp	CheckFor585Done		; 	
Is585Chip:
	pop	ax			; Restore original value to
	and	al, 0C3h
	mov	dx, si			; HWR register.
	out	dx, al			; Do it.
	mov	ax, 0			; Set return code & flags.
	dec	ax
CheckFor585Done:

ifndef	NT_CODE
	$POPFF
endif
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	or	ax, ax
	ret
check_for_585	endp

;******************************************************************************
;
;******************************************************************************
; BOARD ID USAGE
;
;	GetBoardID
;
;	Near CALL
;
;		ON ENTRY:	DX = Base I/O Address of Board in Question
;				AX = 1 if the machine is Micro Channel
;				     0 if the machine is AT
;
;		On EXIT:	AX = Board ID Feature Bits
;				DX = Extra Info Bits
;
;				All Registers are preserved except:
;				BX and CX
;
;******************************************************************************
;
;******************************************************************************
; BOARD ID DEFINITIONS
;
; Two 16 bit values will be returned 
;
;	The first word (in AX) contains Feature Bits which make up a boards
;	unique ID.
;
;		e.g. STARLAN MEDIA, INTERFACE_CHIP, MICROCHANNEL
;
;	The next word (in DX) contains Extra Bits which do not change the
;	boards ID.
;
;		e.g. RAM SIZE, 16 BIT SLOT, ALTERNATE IRQ
;
;******************************************************************************
;
;******************************************************************************
;	GetBoardID
;
;	Purpose: To identify which WD80XX board is being used 
;
;	Entry:	DX	= Base I/O address of the board
;		AX	= 1 if the machine is Micro Channel
;		     	  0 if the machine is AT
;		DS:SI	= Ptr to adapter structure
;
;	Exit:	AX = Board ID Feature Bits
;		DX = Extra Bits
;		CX = Corrupted
;
;		All registers are preserved except BX and CX
;******************************************************************************
ifdef	LM_GC_DEBUG
PUBLIC	GetBoardID
endif
GetBoardID	proc	near

	mov	cx, lm_gc_struc_ptr.board_id
	and	cx, MEDIA_MASK

	push	BASE_PTR
	mov	BASE_PTR,STACK_PTR		;space for local variables
	sub	STACK_PTR,4
ifdef	TOKEN_RING
	cmp	cx, TOKEN_MEDIA
	jne	GetEnetCnfg
	call	GetTokenInfo
	jmp	bid_exit
GetEnetCnfg:
endif

ifdef	ETHERNET
	mov	bx,dx				;save a copy of base i/o address
	mov	dx,ax				;save MC flag
	xor	ax,ax				;init return values
	mov	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax
	mov	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],ax
	push	dx				;MC flag
	call	bid_get_board_rev_number
	pop	dx
	or	ax,ax				;is the rev number zero
	jnz	good_rev_num
	xor	dx,dx				;show nothing found
	xor	ax,ax
	jmp	bid_exit
good_rev_num:

ifdef	UBIO	; #22
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], INTERFACE_CHIP+ADVANCED_FEATURES
else		; #22

	mov	cx,ax				;save rev number
	or	dx,dx				;MC flag
	jz	bid_not_micro_channel
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],MICROCHANNEL ;add feature bit
bid_not_micro_channel:
	mov	ax,[BASE_PTR-BID_LOCAL_BID]	;needed for 'bid_get_base_info'
	call	bid_get_base_info		;AX=current ID, BX=base I/O
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax	;or in new feature bits
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],dx	;or in new extra bits
	call	bid_get_media_type		;get the media type
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax	;or in feature bits
	mov	ax,[BASE_PTR-BID_LOCAL_BID]
	cmp	cx,2				;is rev num >= 2?
	jl	bid_got_all_info		;no so skip extra info
	call	bid_get_id_byte_info	;AX=curr ID, CX=rev num, BX=base I/O
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax	;or in new feature bits
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],dx	;or in new extra bits
bid_no_id_byte_info:
	cmp	cx,3				;is rev num >= 3?
	jl	bid_got_all_info
	test	WORD PTR [BASE_PTR-BID_LOCAL_BID],MICROCHANNEL
	jz	bid_has_eeprom_info
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],INTERFACE_594_CHIP
	jmp	short bid_got_all_info
bid_has_eeprom_info:

endif		; #22

	and	WORD PTR [BASE_PTR-BID_LOCAL_BID],BID_BID_EEPROM_OVERRIDE
	and	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],BID_EXTRA_EEPROM_OVERRIDE

ifndef	UBIO	; #23

	call	check_for_585
	jnz	bid_set_585_chip
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],INTERFACE_584_CHIP
	jmp	bid_got_interface_chip
bid_set_585_chip:

endif		; #23

	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],INTERFACE_585_CHIP
bid_got_interface_chip:
	mov	ax,[BASE_PTR-BID_LOCAL_BID]
	call	bid_get_eeprom_info
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax	;or in new feature bits
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],dx	;or in new extra bits
	jmp	bid_check_rev_4
bid_got_all_info:
	mov	ax,[BASE_PTR-BID_LOCAL_BID]	;needed for 'bid_get_ram_size'
	mov	dx,[BASE_PTR-BID_LOCAL_EXTRA]
	call	bid_get_ram_size ;AX=curr ID, DX=extra, CX=rev num, BX=base I/O
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],ax ;or in new extra bits
bid_check_rev_4:

ifndef	UBIO	; #24

	cmp	cx, 4				;is rev num >= 4?
	jl	bid_do_690_check
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ADVANCED_FEATURES ;or in new feature bits

endif		; #24

	call	bid_check_bic_type		; Check for 790/585 BIC chips

ifndef	UBIO	; #25

	jz	bid_do_690_check

endif		; #25

	and	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA], not INTERFACE_CHIP_MASK ; Clear existing interface chip defs.
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA], dx	; OR in new feature bits

ifndef	UBIO	; #26

	jmp	bid_no_690

bid_do_690_check:
	call	bid_check_for_690		;BX=base I/O
	jz	bid_no_690			;no 690 present
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],NIC_690_BIT
bid_no_690:

endif		; #26

	mov	ax,[BASE_PTR-BID_LOCAL_BID]		;get feature bits
	mov	dx,[BASE_PTR-BID_LOCAL_EXTRA]		;get extra bits
	or	ax,ax				;clear carry flag
endif
bid_exit:
	mov	STACK_PTR,BASE_PTR
	pop	BASE_PTR
	ret

GetBoardID	endp
ifdef	ETHERNET
;******************************************************************************
;	bid_get_board_rev_number
;
;	Purpose: To find the board revision number from the hardware ID byte
;
;	Entry:	BX = Base I/O address of the board
;
;	Exit:	AX = Board Revision Number
;******************************************************************************
bid_get_board_rev_number	proc	near

	push	dx
	mov	dx,bx
	add	dx,BID_BOARD_ID_BYTE
	in	al,dx
	and	al,BID_BOARD_REV_MASK
	shr	al,1				;right justify result
	xor	ah,ah				;clear hob and ccf
	pop	dx
	ret

bid_get_board_rev_number	endp

ifndef	UBIO	; #27

;******************************************************************************
;	bid_get_base_info
;
;	Purpose: To identify which WD80XX board is being used 
;
;	Entry:	AX = Current Board ID
;		BX = Base I/O address of the board
;
;	Exit:	AX = Board ID Feature Bits
;		DX = Extra Bits
;******************************************************************************
bid_get_base_info	proc	near

	push	cx
	xor	cx,cx			;zero out Board ID
	xor	dx,dx			;zero out Extra Bits

	test	ax,MICROCHANNEL		;is this a micro channel?
	jz	check_aliasing		;no so continue
	call	bid_interface_chip	;check for interface chip
	jz	bid_exit_base_info
	or	cx,INTERFACE_CHIP	;add feature to type
	jmp	bid_exit_base_info
check_aliasing:
	call	bid_check_aliasing	;check for register aliasing
	jnz	bid_exit_base_info	;aliasing is true, so exit
	call	bid_interface_chip	;does it have an interface chip???
	jz	not_interface_chip	; no
	or	cx,INTERFACE_CHIP	; yes, so add in feature
	jmp	bid_exit_base_info
not_interface_chip:
	call	bid_board_16bit		;is the board an 8013ebt???
	jz	bid_exit_base_info	; no, exit
	or	cx,BOARD_16BIT		; yes, so add in feature
	call	bid_slot_16bit		;is 16 bit board in 16 bit slot???
	jz	bid_exit_base_info	; no, so we are done
	or	dx,SLOT_16BIT		; yes, so add in extra bit
	jmp	bid_exit_base_info

bid_exit_base_info: 
	mov	ax,cx
	pop	cx
	ret

bid_get_base_info	endp

;******************************************************************************
;	bid_check_aliasing
;
;	Purpose:  checks for register aliasing
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	AX = -1 if aliasing
;		AX = 0 if not
;******************************************************************************
bid_check_aliasing	proc	near

	push	cx
	push	dx
	mov	dx,bx			;get input of reg 1
	add	dx, REG_ICR
	mov	cx,4	   		;do next 5 registers (1 - 5)
bid_alias_loop:
	in	al,dx
	mov	ah,al
	push	dx
	add	dx, REG_LAR0
	in	al,dx	   
	cmp	al,ah			;if reg 1 != lan addr 1
	pop	dx
	jne	no_aliasing		; then there is no aliasing
	inc	dx
ifdef	NEC
	inc	dx
endif
	loop	bid_alias_loop

	mov	dx,bx			;get input of reg 7
	add	dx, REG_GP2
	in	al,dx
	mov	ah,al
	add	dx, REG_LAR0
	in	al,dx
	cmp	al,ah			;if reg 7 != lan addr 7
	jne	no_aliasing		; then there is no aliasing

	xor	ax,ax			;aliasing is true,
	dec	ax
	jmp	bid_exit_aliasing
no_aliasing:
	xor	ax,ax
bid_exit_aliasing:
	pop	dx
	pop	cx
	ret
					; so exit now with enough info 
bid_check_aliasing	endp

;******************************************************************************
;	bid_interface_chip
;
;	Purpose:  checks for the presence of an interface chip
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	AX = -1 if interface chip is present
;		AX = 0 if not 
;******************************************************************************
bid_interface_chip	proc	near

	push	cx
	push	dx
	mov	dx,bx			;write and read register 7 (GP2)
	add	dx, REG_GP2
	in	al,dx			;save original value
	mov	cl,al
	mov	al,35h
	out	dx,al
	jmp	$+2
	push	dx			;put something else on bus
	mov	dx,bx
	in	al,dx
	pop	dx
	jmp	$+2
	in	al,dx
	cmp	al,35h			;did it write???
	jne	no_interface_chip
	mov	al,3Ah			;try another value to make sure
	out	dx,al
	jmp	$+2
	push	dx			;put something else on bus
	mov	dx,bx
	in	al,dx
	pop	dx
	jmp	$+2
	in	al,dx
	cmp	al,3Ah			;did it write???
	jne	no_interface_chip
	mov	al,cl			;restore original value
	out	dx,al
	xor	ax,ax
	dec	ax
	jmp	bid_exit_intrfc_chip
no_interface_chip:
	call	check_for_585		; Returns -1 if 585/790 is present,
					; else 0.
bid_exit_intrfc_chip:
	pop	dx
	pop	cx
	ret

bid_interface_chip	endp

;******************************************************************************
;	bid_board_16bit
;
;	Purpose:  To sense if this board has 16 bit capability
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	AX = -1 if 16 bit capability
;		AX = 0 if not
;******************************************************************************
bid_board_16bit	proc	near

	push	bx			; preserve all registers
	push	cx
	push	dx
	mov	dx,bx			; register 1 has bit to test
	add	dx, REG_ICR
	in	al,dx			; save previous value
	mov	cl,al			;  into cl
	mov	bl,al			; want only to compare with lob
	and	bl,BID_SIXTEEN_BIT_BIT	;  so mask it out
	xor	al,BID_SIXTEEN_BIT_BIT	; flip bit in question
	out	dx,al			; write new value
	jmp	$+2
	push	dx			;put something else on bus
	mov	dx,bx
	in	al,dx
	pop	dx
	in	al,dx			; read it back
	and	al,BID_SIXTEEN_BIT_BIT	; only care about lob
	cmp	al,bl			; did it stick???
	je	is_16bit_board		;   no, so show 16 bit board
	mov	al,cl			;   yes, so put back original value
	out	dx,al
	xor	ax,ax			; and show not 16 bit board
	jmp	bid_exit_board_16bit
is_16bit_board:
	and	cl,0FEh			;mask bit one if 16 bit board
	mov	al,cl			; put back original value just in case
	out	dx,al
	xor	ax,ax
	dec	ax
bid_exit_board_16bit:
	pop	dx
	pop	cx
	pop	bx
	ret

bid_board_16bit	endp

;******************************************************************************
;	bid_get_media_type
;
;	Purpose:  To find the media type of the board
;
;	Entry:  BX = Base I/O Address
;		CX = Board Revision Number
;
;	Exit:	AX = Media Type Bits
;******************************************************************************
bid_get_media_type	proc	near

	push	dx
	mov	dx,bx
	add	dx,BID_BOARD_ID_BYTE		;get the hardware ID byte
	in	al,dx
	test	al,BID_MEDIA_TYPE_BIT		;is it set?
	jz	bid_star_twisted		;no
	mov	ax,ETHERNET_MEDIA		;yes, show ethernet media
	jmp	bid_exit_media_type
bid_star_twisted:
	cmp	cx,1				;is it an old rev board?
	je	bid_show_starlan		;yes, must be starlan
	mov	ax,TWISTED_PAIR_MEDIA		;no, must be twisted pair
	jmp	bid_exit_media_type
bid_show_starlan:
	mov	ax,STARLAN_MEDIA		;show starlan
bid_exit_media_type:
	pop	dx
	ret

bid_get_media_type	endp

;******************************************************************************
;	bid_get_id_byte_info
;
;	Purpose: To extract information about the board using the
;		 hardware ID byte in the boards LAN address ROM
;
;	Entry:  AX = Current Board ID
;		BX = Base I/O Address
;
;	Exit:	AX = New Board ID Bits
;		DX = New Extra Bits
;******************************************************************************
bid_get_id_byte_info	proc	near

	push	BASE_PTR
	mov	BASE_PTR,STACK_PTR		;space for local vars
	sub	STACK_PTR,4

	xor	dx,dx				;init return values
	mov	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax	;use current board ID
	mov	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],dx ;start new for extra
	mov	dx,bx				;get base I/O address
	add	dx,BID_BOARD_ID_BYTE		;read hardware board ID byte
	in	al,dx
	test	al,BID_BUS_TYPE_BIT		;is it a MCA adapter?
	jz	bid_not_mca_bus
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],MICROCHANNEL
bid_not_mca_bus:
	test	al,BID_SOFT_CONFIG_BIT		;is the soft config bit set?
	jz	bid_get_extra_exit		;no
						;yes, so interpret soft cfg bit
	cmp	WORD PTR [BASE_PTR-BID_LOCAL_BID],WD8003EB	;EB board?
	jz	bid_show_alt_irq			;yes, show alt irq
	cmp	WORD PTR [BASE_PTR-BID_LOCAL_BID],WD8003W	;W board?
	jz	bid_show_alt_irq			;yes, show alt irq
	jmp	bid_get_extra_exit
bid_show_alt_irq:
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],ALTERNATE_IRQ_BIT
bid_get_extra_exit:
	mov	ax,WORD PTR [BASE_PTR-BID_LOCAL_BID]	;use current board ID
	mov	dx,WORD PTR [BASE_PTR-BID_LOCAL_EXTRA] ;start new

	mov	STACK_PTR,BASE_PTR
	pop	BASE_PTR
	ret

bid_get_id_byte_info	endp

endif		; #27

;******************************************************************************
;	bid_get_eeprom_info
;
;	Purpose: To extract information about the board using the
;		 ID bytes in the EEPROM
;
;	Entry:  AX	= Current Board ID
;		BX	= Base I/O Address
;		DS:SI	= Ptr to adapter structure.
;
;	Exit:	AX = New Board ID Bits
;		DX = New Extra Bits
;******************************************************************************
bid_get_eeprom_info	proc	near

	push	BASE_PTR
	mov	BASE_PTR,STACK_PTR		;space for local vars
	sub	STACK_PTR,4

	xor	dx,dx				;init return values
	mov	WORD PTR [BASE_PTR-BID_LOCAL_BID],ax	;use current board ID
	mov	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],dx ;start new for extra
	call	bid_recall_engr_eeprom
	mov	dx,bx				;get base io address
	add	dx,BID_EEPROM_1
	in	al,dx
	mov	ah,al
	and	al,BID_EEPROM_BUS_TYPE_MASK
	cmp	al,BID_EEPROM_BUS_TYPE_MCA
	jne	bid_not_mca
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],MICROCHANNEL
	jmp	bid_got_the_bus_type
bid_not_mca:
	cmp	al,BID_EEPROM_BUS_TYPE_NEC
	jne	bid_set_default_bus_type
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], NEC_BUS
	jmp	bid_got_the_bus_type

bid_set_default_bus_type:
bid_got_the_bus_type:
	mov	al, ah
	and	al, BID_EEPROM_PAGING_MASK
	or	al, al
	jz	bid_no_paging
	test	al, BID_EEPROM_RAM_PAGING
	jz	bid_test_rom_paging
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], PAGED_RAM
bid_test_rom_paging:
	test	al, BID_EEPROM_ROM_PAGING
	jz	bid_got_paging_info
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], PAGED_ROM
bid_got_paging_info:
bid_no_paging:
	mov	al,ah				;get io value back
	and	al,BID_EEPROM_BUS_SIZE_MASK
	cmp	al,BID_EEPROM_BUS_SIZE_16BIT
	jne	bid_not_16bit_bus
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],BOARD_16BIT
	call	bid_slot_16bit		;is 16 bit board in 16 bit slot???
	jz	bid_got_the_bus_size	; no
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],SLOT_16BIT
	jmp	bid_got_the_bus_size

bid_not_16bit_bus:
bid_set_default_bus_size:
bid_got_the_bus_size:
	mov	dx,bx				;get base io address
	add	dx,BID_EEPROM_0
	in	al,dx
	mov	ah,al
	and	al,BID_EEPROM_MEDIA_MASK
	cmp	al,BID_STARLAN_TYPE
	jne	bid_not_starlan
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],STARLAN_MEDIA
	jmp	bid_got_the_media

bid_not_starlan:
	cmp	al,BID_TP_TYPE
	jne	bid_not_tp
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],TWISTED_PAIR_MEDIA
	jmp	bid_got_the_media

bid_not_tp:
	cmp	al,BID_EW_TYPE
	jne	bid_not_ew
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],EW_MEDIA
	jmp	bid_got_the_media

bid_not_ew:
	cmp	al,BID_UTP2_TYPE
	jne	bid_not_utp2
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],UTP2_MEDIA
	jmp	bid_got_the_media

bid_not_utp2:
	cmp	al,BID_ETHERNET_TYPE
	jne	bid_not_ethernet_media
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ETHERNET_MEDIA
	jmp	bid_got_the_media

bid_not_ethernet_media:
bid_set_default_media:
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID],ETHERNET_MEDIA

bid_got_the_media:
	call	bid_get_extended_media		;Check for add'l media info
;
;	This code is required for the 8416 to determine its type.  The
;	8416 uses a new naming convention that isolates all media connectors.
;	To do this, we must use the media_opts field  in the EEPROM.
;
	cmp	[SRC_INDEX].media_opts, 0	; Media opts used?
	jz	bid_get_irq			; JIF no

	test	[SRC_INDEX].media_opts, MED_OPT_AUI	; AUI media?
	jnz	bid_get_irq				; JIF yes
							; Else set 
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], NO_AUI_MEDIA

bid_get_irq:
	mov	al,ah				;get io value back
	and	al,BID_EEPROM_IRQ_MASK
	cmp	al,BID_ALTERNATE_IRQ_1
	jne	bid_set_default_irq
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],ALTERNATE_IRQ_BIT
;	jmp	bid_got_the_irq
bid_set_default_irq:
bid_got_the_irq:
	mov	al,ah				;get io value back
	and	al,BID_EEPROM_RAM_SIZE_MASK
	cmp	al,BID_EEPROM_RAM_SIZE_8K
	jne	bid_not_8k_ram
bid_set_8k_ram:
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],RAM_SIZE_8K
	jmp	bid_got_the_ram
bid_not_8k_ram:
	cmp	al,BID_EEPROM_RAM_SIZE_16K
	jne	bid_eeprom_not_16k_ram
	test	WORD PTR [BASE_PTR-BID_LOCAL_BID],BOARD_16BIT
	jz	bid_just_set_16k
	test	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],SLOT_16BIT
	jz	bid_set_8k_ram
bid_just_set_16k:
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],RAM_SIZE_16K
	jmp	bid_got_the_ram
bid_eeprom_not_16k_ram:
	cmp	al,BID_EEPROM_RAM_SIZE_32K
	jne	bid_not_32k_ram
bid_set_32k_ram:
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],RAM_SIZE_32K
	jmp	bid_got_the_ram
bid_not_32k_ram:
	cmp	al,BID_EEPROM_RAM_SIZE_64K
	jne	bid_not_64k_ram
	test	WORD PTR [BASE_PTR-BID_LOCAL_BID],BOARD_16BIT
	jz	bid_just_set_64k
	test	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],SLOT_16BIT
	jz	bid_set_32k_ram
bid_just_set_64k:
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],RAM_SIZE_64K
	jmp	bid_got_the_ram
bid_not_64k_ram:
bid_set_default_ram:
	or	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA],RAM_SIZE_UNKNOWN
bid_got_the_ram:
	mov	dx,bx				;get base io address
	add	dx,BID_EEPROM_3
	in	al, dx
	test	al, BID_EEPROM_LOW_COST
	jz	StandardAdapter
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], LITE_VERSION

StandardAdapter:
	test	al, BID_EEPROM_HMI
	jz	NotHmiAdapter
	or	WORD PTR [BASE_PTR-BID_LOCAL_BID], HMI_ADAPTER

NotHmiAdapter:
;
;	Set the adapter mode type bit in adapter_flags.
;
	and	[SRC_INDEX].adapter_flags, not IO_MAPPED	; Clear bit
	test	al, BID_EEPROM_IO_MAPPED
	jz	GetAutoMediaDetect

	or	[SRC_INDEX].adapter_flags, IO_MAPPED		; Set bit

GetAutoMediaDetect:
	mov	dx,bx				;get base io address
	add	dx,BID_EEPROM_6
	in	al, dx

	and	[SRC_INDEX].mode_bits, not AUTO_MEDIA_DETECT	; Clear bit
	test	al, BID_EEPROM_AUTO_MEDIA_DETECT
	jz	RestoreLanAddress

	or	[SRC_INDEX].mode_bits, AUTO_MEDIA_DETECT	; Set bit

RestoreLanAddress:
	call	bid_recall_lan_address
	mov	ax,WORD PTR [BASE_PTR-BID_LOCAL_BID]	;use current board ID
	mov	dx,WORD PTR [BASE_PTR-BID_LOCAL_EXTRA] ;start new

	mov	STACK_PTR,BASE_PTR
	pop	BASE_PTR
	ret

bid_get_eeprom_info	endp

;******************************************************************************
;
;	bid_get_extended_media
;
;	Purpose: To read bit-mapped media field stored in EEPROM
;
;	Entry:	BX		I/O base address.
;		SRC_INDEX	Ptr to adapter structure.
;		LAR0-7		Contains EEROM bank 0Ah data.
;
;	Exit:	[SRC_INDEX].media_opts Initialized.
;		All regs preserved.
;
;******************************************************************************

bid_get_extended_media	proc	near

	push	ax
	push	dx

	mov	dx, bx
	add	dx, BID_EEPROM_4
	in	al, dx
	mov	ah, 0			; No data in hi byte for now ...
	mov	[SRC_INDEX].media_opts, ax

	pop	dx
	pop	ax
	ret
bid_get_extended_media	endp

;******************************************************************************
;	bid_get_ram_size
;
;	Purpose: To figure out, if possible, the size of the RAM 
;		 available on this board
;
;	Entry:  AX = Current Board ID
;		BX = Base I/O Address
;		CX = Board Revision Number
;		DX = Extra Info
;
;	Exit:	AX = RAM Size Code
;******************************************************************************
bid_get_ram_size	proc	near

	push	cx			;preserve registers
	push	dx
	cmp	cx,2			;is the rev number less than 2?
	jge	bid_ram_new_rev		;no, so use RAM_SIZE_BIT in hardware
	test	ax,MICROCHANNEL		;is it a microchannel board?
	jnz	bid_show_16k_ram
	test	ax,BOARD_16BIT		;is it our 16 bit board?
	jz	bid_not_16k_ram
	test	dx,SLOT_16BIT		;is it in a 16 bit slot?
	jz	bid_show_8k_ram
bid_show_16k_ram:
	mov	ax,RAM_SIZE_16K		;yes, show 16K RAM
	jmp	bid_ram_size_exit
bid_show_8k_ram:
	mov	ax,RAM_SIZE_8K
	jmp	bid_ram_size_exit
bid_not_16k_ram:
	test	ax,INTERFACE_CHIP	;is this an EB board?
	jnz	bid_get_ifchp_ram_size	;yes
	mov	ax,RAM_SIZE_UNKNOWN	;no, so I cant tell the RAM size
	jmp	bid_ram_size_exit
bid_get_ifchp_ram_size:
	mov	dx,bx			;get base I/O address
	add	dx,REG_ICR		;look at memory size bit in reg 1
	in	al,dx			;get register value
	test	al,BID_MSZ_583_BIT	;is the MSZ bit set?
	mov	ax,RAM_SIZE_8K		;pre-load return value
	jz	bid_ram_size_exit	;no, so show 8k RAM
	mov	ax,RAM_SIZE_32K		;yes, so show 32k RAM
	jmp	bid_ram_size_exit
bid_ram_new_rev:
	push	dx
	mov	cx,ax			;put current board ID into cx
	mov	dx,bx			;get base I/O address
	add	dx,BID_BOARD_ID_BYTE	;read hardware ID byte
	in	al,dx
	pop	dx
	cmp	cx,WD8003E		;is it a simple E board?
	je	bid_ram_8k_32k		;yes, so make the choice
	cmp	cx,WD8003S		;is it a simple S board?
	je	bid_ram_8k_32k		;yes, so make choice
	cmp	cx,WD8003WT
	je	bid_ram_8k_32k
	cmp	cx,WD8003W
	je	bid_ram_8k_32k
	cmp	cx,WD8003EB
	je	bid_ram_8k_32k
	test	cx,MICROCHANNEL		;is it a micro channel board
	jnz	bid_ram_16k_64k		;yes, so show 16k
	cmp	cx,WD8013EBT		;is it a 16 bit board?
	je	bid_ram_8k_64k		;yes
	mov	ax,RAM_SIZE_UNKNOWN	;default to unknown
	jmp	bid_ram_size_exit
bid_ram_8k_32k:
	test	al,BID_RAM_SIZE_BIT	;does the hardware say large RAM?
	mov	ax,RAM_SIZE_8K		;pre-load return value
	jz	bid_ram_size_exit
	mov	ax,RAM_SIZE_32K		;show large ram
	jmp	bid_ram_size_exit
bid_ram_8k_64k:
	test	dx,SLOT_16BIT
	jz	bid_ram_8k_32k
bid_ram_16k_64k:
	test	al,BID_RAM_SIZE_BIT	;does the hardware say large RAM?
	mov	ax,RAM_SIZE_16K		;show 16k RAM
	jz	bid_ram_size_exit
	mov	ax,RAM_SIZE_64K		;show 64k RAM
	jmp	bid_ram_size_exit
bid_ram_size_exit:
	pop	dx			;restore registers
	pop	cx
	ret

bid_get_ram_size	endp

ifndef	UBIO	; #28

;******************************************************************************
;	bid_check_for_690
;
;	Purpose: To identify the NIC as a 690 or an 8390
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	AX = -1 if 690
;		     0 if 8390
;******************************************************************************
bid_check_for_690	proc	near

	push	BASE_PTR
	mov	BASE_PTR,STACK_PTR	;space for local variables
	sub	STACK_PTR,4

	push	bx			;preserve registers
	push	cx
	push	dx
	mov	dx,bx			;get copy of base I/O address
	add	dx,BID_CR		;ready for NIC command register
	in	al,dx			;get current register contents
	mov	cl,BID_TXP		;need to mask CR with ~BID_TXP
	xor	cl,0FFh			;invert CL contents
	and	cl,al			;CR without BID_TXP bit
	mov	WORD PTR [BASE_PTR-BID_LOCAL_CR],cx	;save this value
	and	cl,BID_PS_MASK		;CR without PS bits
	mov	al,cl
	or	al,BID_PS2		;switch to page 2 registers
	out	dx,al
	add	dx,BID_TCR_DIFF		;address TCR
	in	al,dx
	mov	WORD PTR [BASE_PTR-BID_LOCAL_TCR],ax	;save this value
	sub	dx,BID_TCR_DIFF		;address CR
	mov	al,cl			;get CR without TXP or PS bits
	out	dx,al			;now at page 0 registers
	add	dx,BID_TCR_DIFF		;address TCR
	mov	al,BID_TCR_VAL		;test value
	out	dx,al
	sub	dx,BID_TCR_DIFF		;address CR
	mov	al,cl			;get CR without TXP or PS bits
	or	al,BID_PS2		;or in Page Select 2 bits
	out	dx,al
	add	dx,BID_TCR_DIFF		;address TCR
	in	al,dx
	and	al,BID_TCR_VAL		;only use the test bits
	cmp	al,BID_TCR_VAL		;does it equal the test value???
	mov	bx,0			;pre-load 8390 answer
	je	bid_chck_690_exit	;yes, must be 8390
	mov	bx,0FFFFh		;load 690 answer
bid_chck_690_exit:
	mov	al,cl			;get CR without TXP or PS bits
	sub	dx,BID_TCR_DIFF		;address CR
	out	dx,al			;select page 0
	add	dx,BID_TCR_DIFF		;address TCR
	mov	ax,WORD PTR [BASE_PTR-BID_LOCAL_TCR]	;get saved value
	out	dx,al			;restore TCR
	sub	dx,BID_TCR_DIFF		;address CR
	mov	ax,WORD PTR [BASE_PTR-BID_LOCAL_CR]	;get saved value
	out	dx,al			;restore CR

	mov	ax,bx			;put return code in AX
	or	ax,ax			;set flags
	pop	dx			;restore registers
	pop	cx
	pop	bx
	mov	STACK_PTR,BASE_PTR	;restore stack
	pop	BASE_PTR
	ret

bid_check_for_690	endp

endif		; #28

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;	SetPcmConfig	Configures PCM adapter in first PCMCIA socket to
;;			parameters indicated in adapter structure indicated
;;			by lm_gc_struc_ptr. Sets appropriate bits in board_id
;;			& extra_info. This procedure writes directly to the
;;			Intel 365 chip. Do not use with Socket Services or
;;			Card Services software.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PUBLIC	SetPcmConfig
;SetPcmConfig	proc	near
;	push	bx
;	push	cx
;	push	dx
;	push	di
;	push	si
;	jmp	Skip365Program
;
;	mov	al, REG_PCM_RESETDRV
;	mov	ah, 90h
;	call	Outp365
;
;	mov	ax, lm_gc_struc_ptr.irq_value
;	mov	ah, al
;	mov	al, REG_PCM_GEN_CTRL
;	or	ah, GEN_CTRL_INTR + GEN_CTRL_RST + GEN_CTRL_IO_CARD
;	call	Outp365				; Selected IRQ is now enabled.
;	mov	cx, -1
;	mov	dx, 3e2h
;SetPcmLoop:
;	in	al, dx
;	in	al, dx
;	in	al, dx
;	in	al, dx
;	in	al, dx
;	loop	SetPcmLoop
;;	mov	ax, lm_gc_struc_ptr.io_base
;;	mov	al, REG_PCM_IO_START_HI
;;	call	Outp365
;;
;;	mov	ax, lm_gc_struc_ptr.io_base
;;	mov	ah, al
;;	mov	al, REG_PCM_IO_START_LO
;;	call	Outp365
;;
;;	mov	ax, lm_gc_struc_ptr.io_base
;;	mov	al, REG_PCM_IO_STOP_HI
;;	call	Outp365
;;
;;	mov	ax, lm_gc_struc_ptr.io_base
;;	add	al, 1Fh
;;	mov	ah, al
;;	mov	al, REG_PCM_IO_STOP_LO
;;	call	Outp365				; IO Window is now set up, but not enabled.
;
;	mov	ax, word ptr lm_gc_struc_ptr.ram_base+2
;	mov	cx, 4
;	shl	ax, cl
;	mov	bx, word ptr lm_gc_struc_ptr.ram_base
;	mov	cx, 12
;	shr	bx, cl
;	or	ax, bx
;	mov	ah, al
;	mov	al, REG_PCM_MEM_START_LO
;	call	Outp365
;
;	mov	bx, lm_gc_struc_ptr.ram_usable
;	shr	bx, 1
;	shr	bx, 1
;	add	ah, bl
;	dec	ah
;	mov	al, REG_PCM_MEM_STOP_LO
;	call	Outp365
;
;	mov	ax, word ptr lm_gc_struc_ptr.ram_base+2
;	mov	cl, 4
;	shl	ax, cl
;	or	ah, PCM_MEM_16BIT
;	mov	al, REG_PCM_MEM_START_HI
;	call	Outp365
;	and	ah, not PCM_MEM_16BIT
;	or	ah, PCM_MEM_WAIT_STATE
;	mov	al, REG_PCM_MEM_STOP_HI
;	call	Outp365
;	
;	mov	ax, word ptr ds:[bp].ram_access+2
;	neg	ah
;	add	ah, 10h
;	mov	al, REG_PCM_MEM_OFST_LO
;	call	Outp365
;
;	mov	al, REG_PCM_MEM_OFST_HI
;	mov	ah, 40h				; 40h is Reg Active bit.
;	call	Outp365				; Attribute memory is now mapped to
;						; Ram base address.
;	mov	al, REG_PCM_WIN_ENABLE
;	call	Inp365
;;	or	ah, PCM_IOWIN_EN0+PCM_MEMWIN_EN0
;	or	ah, PCM_MEMWIN_EN0
;	call	Outp365				; Mem Window is now enabled.
;
;	mov	ax, word ptr ds:[bp].ram_access+2
;	mov	es, ax
;	mov	di, word ptr ds:[bp].ram_access
;	mov	byte ptr es:[di], 40h			; Set level mode interrupts.
;
;	neg	ah
;	add	ah, 2Dh
;	mov	al, REG_PCM_MEM_OFST_LO		; Switch shared memory into page frame.
;	call	Outp365
;
;	mov	al, REG_PCM_MEM_OFST_HI
;	mov	ah, 00h
;	call	Outp365
;Skip365Program:
;	mov	lm_gc_struc_ptr.board_id, PCM10BT
;	mov	lm_gc_struc_ptr.extra_info, RAM_SIZE_16K+NIC_690_BIT+ALTERNATE_IRQ_BIT
;	mov	lm_gc_struc_ptr.nic_type, NIC_690_CHIP
;	mov	lm_gc_struc_ptr.bic_type, BIC_564_CHIP
;	mov	lm_gc_struc_ptr.adapter_bus, BUS_PCMCIA_TYPE
;	mov	lm_gc_struc_ptr.media_type, MEDIA_AUI_UTP
;	mov	ax, ADAPTER_AND_CONFIG
;
;	pop	si
;	pop	di
;	pop	dx
;	pop	cx
;	pop	bx
;	ret
;SetPcmConfig	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;	Outp365 Writes data in AH to Intel 82365 register in AL.
;;
;;	Return:
;;		All regs preserved.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PUBLIC	Outp365
;Outp365	proc	near
;	push	ax
;	push	dx
;	mov	dx, 3e0h
;	out	dx, al
;	mov	al, ah
;	inc	dx
;	out	dx, al
;	pop	dx
;	pop	ax
;	ret
;Outp365	endp
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;	Inp365 Reads data from Intel 82365 register in AL.
;;
;;	Return:
;;		AH = Byte Data read from 365.
;;		All other regs preserved.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PUBLIC	Inp365
;Inp365	proc	near
;	push	dx
;	mov	ah, al		; AH = AL = register.
;	mov	dx, 3E0h
;	out	dx, al
;	inc	dx
;	in	al, dx
;	xchg	ah, al		; AL = register, AH = data.
;	pop	dx
;	ret
;Inp365	endp
;
endif
;******************************************************************************
;	bid_recall_engr_eeprom
;
;	Purpose: To recall the reserved Engineering bytes from the EEPROM
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	All registers preserved
;
;******************************************************************************
ifdef	LM_GC_DEBUG
PUBLIC	bid_recall_engr_eeprom
endif
bid_recall_engr_eeprom	proc	near

	push	ax
	push	dx
	call	check_for_585
	jz	Recall584Data

	mov	dx, bx
	add	dx, REG_EER
	mov	al, OFFSET_585_ENGR_DATA
	or	al, EER_RC
	out	dx, al
Poll585Recall:
	jmp	$+2
	in	al, dx
	test	al, EER_RC
	jnz	Poll585Recall
	jmp	recall_engr_eeprom_exit
Recall584Data:
	mov	dx, bx
	add	dx, REG_ICR
	in	al, dx
	and	al, BID_ICR_MASK
	or	al, BID_OTHER_BIT
	out	dx, al
	mov	dx, bx
	add	dx, BID_REG_3
	in	al, dx
	and	al, BID_EAR_MASK
	or	al, BID_ENGR_PAGE
	out	dx, al
	mov	dx, bx
	add	dx, REG_ICR
	in	al, dx
	and	al, BID_ICR_MASK
	or	al, (BID_RLA OR BID_OTHER_BIT)
	out	dx, al
	call	bid_wait_for_recall
recall_engr_eeprom_exit:
	pop	dx
	pop	ax
	ret

bid_recall_engr_eeprom	endp

;******************************************************************************
;	bid_recall_lan_address
;
;	Purpose: To recall the LAN Address bytes from the EEPROM
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	All registers preserved
;
;******************************************************************************
ifdef	LM_GC_DEBUG
PUBLIC	bid_recall_lan_address
endif
bid_recall_lan_address	proc	near

	push	ax
	push	dx
	call	check_for_585
;	mov	ax, WORD PTR [BASE_PTR-BID_LOCAL_BID]
;	test	ax, INTERFACE_585_CHIP
	jz	Recall58xData

	mov	dx, bx
	add	dx, REG_HWR
	in	al, dx
	and	al, 43h
	out	dx, al

	mov	dx, bx
	add	dx, REG_EER
	mov	al, OFFSET_585_LAN_ADDR
	or	al, EER_RC
	out	dx, al
Poll585LanAddrRecall:
	jmp	$+2
	in	al, dx
	test	al, EER_RC
	jnz	Poll585LanAddrRecall
	jmp	bid_recall_lan_addr_exit
Recall58xData:
	mov	dx, bx
	add	dx, REG_ICR
	in	al, dx
	and	al, BID_ICR_MASK
	or	al, BID_OTHER_BIT
	out	dx, al
	mov	dx, bx
	add	dx, BID_REG_3
	in	al, dx
	and	al, BID_EAR_MASK
	or	al, BID_EA6
	out	dx, al
	mov	dx, bx
	add	dx, REG_ICR
	in	al, dx
	and	al, BID_ICR_MASK
	or	al, BID_RLA
	out	dx, al
	call	bid_wait_for_recall
bid_recall_lan_addr_exit:
	pop	dx
	pop	ax
	ret

bid_recall_lan_address	endp

;******************************************************************************
;	bid_wait_for_recall
;
;	Purpose: To wait for the recall operation to complete
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	All registers preserved
;
;******************************************************************************
bid_wait_for_recall	proc	near

	push	ax
	push	dx
	mov	dx, bx
	add	dx, REG_ICR
bid_recall_loop:
	in	al, dx
	and	al, BID_RECALL_DONE_MASK
	jnz	bid_recall_loop
	pop	dx
	pop	ax
	ret

bid_wait_for_recall	endp

;******************************************************************************
;	bid_slot_16bit
;
;	Purpose:  To sense if this 16 bit board is in a 16 bit slot
;
;	Entry:  BX = Base I/O Address
;
;	Exit:	AX = -1 if 16 bit board is in a 16 bit slot
;		AX = 0 if not
;******************************************************************************
bid_slot_16bit	proc	near

	push	dx
;	mov	ax, WORD PTR [BASE_PTR-BID_LOCAL_EXTRA]
;	test	ax, INTERFACE_585_CHIP
	call	check_for_585
	jz	bid_slot_16_bit_not_585
	mov	dx, bx
	add	dx, REG_HWR
	in	al, dx
	test	al, HWR_HOST16
	jnz	is_16bit_slot
	jmp	not_16bit_slot
bid_slot_16_bit_not_585:
	mov	dx, bx			; register 1 has bit to test
	add	dx, REG_ICR
	in	al, dx
	and	al, 0ch
	out	dx, al
	in	al, dx
	test	al, BID_SIXTEEN_BIT_BIT	; is it in a 16 bit slot???
	jz	not_16bit_slot
is_16bit_slot:
	xor	ax, ax
	dec	ax
	jmp	bid_exit_slot_16bit
not_16bit_slot:
	xor	ax, ax
bid_exit_slot_16bit:
	pop	dx
	ret

bid_slot_16bit	endp
;****************************************************************************
;	BID_CHECK_BIC_TYPE checks for presence of 585/790 chip.
;	Entry:	BX = I/O base address
;	Return:	AX = 0 Not 585/790
;****************************************************************************
PUBLIC bid_check_bic_type
bid_check_bic_type	proc	near
	push	cx
	xor	dx, dx
	call	check_for_585
	jz	bic_not_585
	   
	xor	ax, ax
	mov	dx, bx
	add	dx, REG_REV
	in	al, dx
	xor	dx, dx
	mov	cl, 4
	shr	ax, cl
	cmp	al, 3
	je	bic_is_585
	cmp	al, 2
	je	bic_is_790
	cmp	al, 4
	je	bic_is_795
	mov	ax, 0
	or	ax, ax
	jmp	bic_unknown		; BIC is neither a 790 or a 585
bic_is_795:
	or	word ptr [BASE_PTR-BID_LOCAL_BID], NIC_SUPERSET
bic_is_790:
	or	dx, NIC_790_BIT		; BIC (& NIC) is 790.
bic_is_585:
	or	dx, INTERFACE_585_CHIP
	mov	ax, 0
	dec	ax    			; Set flags
bic_unknown:
bic_not_585:
	pop	cx
	ret
bid_check_bic_type	endp

ifdef	TOKEN_RING
;******************************************************************************
;	GetTokenInfo
;
;	Purpose: To identify which WD8XX5 board is being used 
;
;	Entry:	DX = Base I/O address of the board
;		AX = 1 if the machine is Micro Channel
;		     0 if the machine is AT
;
;	Exit:	AX = Board ID Feature Bits
;		DX = Extra Bits
;
;		All registers are preserved except BX and CX
;******************************************************************************
ifdef	LM_GC_DEBUG
PUBLIC	GetTokenInfo
endif
GetTokenInfo	proc	near

	mov	WORD PTR [BASE_PTR-BID_LOCAL_BID], 0
	mov	WORD PTR [BASE_PTR-BID_LOCAL_EXTRA], 0
	mov	bx, dx				; Save IO base in BX
	or	ax, ax
	jz	GTINotMCA
	or	word ptr [BASE_PTR-BID_LOCAL_BID], MICROCHANNEL
GTINotMCA:
	mov	dx, bx
	add	dx, BID_BOARD_ID_BYTE
	in	al, dx
	mov	ah, al
	and	al, 03h				; Mask off major ID
	shr	ah, 1
	shr	ah, 1				; AH=major ID, AL=minor ID.
	cmp	ah, 1				; Major ID 1?
	jg	CheckMajorID2
;	cmp	al, 0
;	jg	CheckMinorID1
	or	word ptr [BASE_PTR-BID_LOCAL_BID], INTERFACE_CHIP
	or	word ptr [BASE_PTR-BID_LOCAL_BID], TOKEN_MEDIA
	or	word ptr [BASE_PTR-BID_LOCAL_BID], PAGED_RAM
	test	word ptr [BASE_PTR-BID_LOCAL_BID], MICROCHANNEL
	jz	GTI58x
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], INTERFACE_594_CHIP
	jmp	GTIRamSize
GTI58x:	
	cmp	al, 1
	jl	Token584Chip
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], INTERFACE_585_CHIP
	jmp	GTIBoardType
Token584Chip:
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], INTERFACE_584_CHIP
GTIBoardType:
	or	word ptr [BASE_PTR-BID_LOCAL_BID], BOARD_16BIT
GTIRamSize:
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], RAM_SIZE_64K
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], NIC_825_BIT
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], ALTERNATE_IRQ_BIT

; Get the chip rev info from eeprom bank A, byte 6, align, and write to
; local extra info.

	call	bid_recall_engr_eeprom
	and	word ptr [BASE_PTR-BID_LOCAL_EXTRA], not CHIP_REV_MASK
	mov	dx, bx
	add	dx, BID_LAR_0+BID_REG_6
	in	al, dx
	and	al, BID_EEPROM_CHIP_REV_MASK
	mov	ah, al
	mov	al, 0
	shl	ax, 1
	shl	ax, 1
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], ax
	call	bid_recall_lan_address

	call	bid_slot_16bit		;is 16 bit board in 16 bit slot???
	or	ax, ax
	jz	CheckMinorID1
	or	word ptr [BASE_PTR-BID_LOCAL_EXTRA], SLOT_16BIT
CheckMinorID1:
CheckMajorID2:
	mov	dx, [BASE_PTR-BID_LOCAL_EXTRA]
	mov	ax, [BASE_PTR-BID_LOCAL_BID]
	clc
	ret
GetTokenInfo	endp
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GetAdapterNamePtr	Initializes pointer to adapter name.
;
; Entry:	DS:BP	Ptr to Adapter Structure
;
; Exit:		If AX == SUCCESS, lm_gc_struc_ptr.adapter_name_ptr initialized to
;			 valid adapter name.
;
;		If AX == UNKNOWN_ADAPTER, lm_gc_struc_ptr.adapter_name_ptr
;			 initialized to string 'StringAdapUnknown'			  
;			      	  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetAdapterNamePtr
GetAdapterNamePtr	proc	near

		push	SRC_INDEX
		push	DEST_INDEX
ifndef	CODE386
		push	es
		push	ds
endif
		mov	ax, lm_gc_struc_ptr.board_id

ifndef	UBIO	; #29

		cmp	ax, WD8003E
		jne	$10
		mov	SRC_INDEX, offset cs:StringEthernet
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$10:
   		cmp	ax, WD8003WT
		jne	$11
		mov	SRC_INDEX, offset cs:String8003WT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$11:
		cmp	ax, WD8003W
		jne	$12
		mov	SRC_INDEX, offset cs:String8003W
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$12:
		cmp	ax, WD8003EB
		jne	$13
		mov	SRC_INDEX, offset cs:String8003EB
		mov	ax, lm_gc_struc_ptr.extra_info 
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_584_CHIP
		jne	Adap8003EB
		mov	SRC_INDEX, offset cs:String8003EP
Adap8003EB:
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$13:
   		cmp	ax, WD8003EW
		jne	$14
		mov	SRC_INDEX, offset cs:String8003EW
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$14:
     		cmp	ax, WD8003ETA
		jne	$15
		mov	SRC_INDEX, offset cs:String8003ETA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$15:
		cmp	ax, WD8003EA
		jne	$16
		mov	SRC_INDEX, offset cs:String8003EA
		mov	ax, lm_gc_struc_ptr.extra_info 
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_594_CHIP
		jne	Adap8003EA
		mov	SRC_INDEX, offset cs:String8003EPA
Adap8003EA:	mov	ax, SUCCESS
	   	jmp	AdapNamePtrDone
$16:
   		cmp	ax, WD8003WA
		jne	$17
		mov	SRC_INDEX, offset cs:String8003WA
		mov	ax, lm_gc_struc_ptr.extra_info 
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_594_CHIP
		jne	Adap8003WA
		mov	SRC_INDEX, offset cs:String8003WPA
Adap8003WA:	mov	ax, SUCCESS    
	   	jmp	AdapNamePtrDone
$17:
   		cmp	ax, WD8013EBT
		jne	$18	 
		mov	SRC_INDEX, offset cs:String8013EBT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$18:
		cmp	ax, WD8013EB
		jne	$19
		mov	SRC_INDEX, offset cs:String8013EB
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$19:
   		cmp	ax, WD8013W
		jne	$20
		mov	SRC_INDEX, offset cs:String8013W
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$20:
   		cmp	ax, WD8013EW
		jne	$21
		mov	SRC_INDEX, offset cs:String8013EW
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$21:
		cmp	ax, WD8013EWC
		jne	$22
		mov	SRC_INDEX, offset cs:String8013EWC
Adap8013EWC:	mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$22:
		cmp	ax, WD8013WC
		jne	$23
		mov	SRC_INDEX, offset cs:String8013WC
Adap8013WC:	mov	ax, SUCCESS
		jmp	AdapNamePtrDone
$23:
		cmp	ax, WD8013EPC
		jne	$24
		mov	SRC_INDEX, offset cs:String8013EPC
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$24:		cmp	ax, WD8003EPC
		jne	$25
		mov	SRC_INDEX, offset cs:String8003EPC
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$25:		cmp	ax, WD8115T
		jne	$26
		mov	SRC_INDEX, offset cs:String8115T
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$26:		cmp	ax, WD8115TA
		jne	$27
		mov	SRC_INDEX, offset cs:String8115TA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$27:		cmp	ax, WD8003WC
		jne	$28
		mov	SRC_INDEX, offset cs:String8003WC
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$28:		cmp	ax, PCM10BT
		jne	$29
		mov	SRC_INDEX, offset cs:StringPCM10BT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$29:		cmp	ax, WD8208
		jne	$30
		mov	SRC_INDEX, offset cs:String8208
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$30:		cmp	ax, WD8208T
		jne	$30a
		mov	SRC_INDEX, offset cs:String8208T
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$30a:		cmp	ax, WD8208C
		jne	$31
		mov	SRC_INDEX, offset cs:String8208C
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$31:		cmp	ax, WD8216
		jne	$32
		mov	SRC_INDEX, offset cs:String8216
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$32:		cmp	ax, WD8216T
		jne	$33
		mov	SRC_INDEX, offset cs:String8216T
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$33:		cmp	ax, WD8216C
		jne	$34
		mov	SRC_INDEX, offset cs:String8216C
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$34:		cmp	ax, WD8216L
		jne	$35
		mov	SRC_INDEX, offset cs:String8216L
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$35:		cmp	ax, WD8216LC
		jne	$36
		mov	SRC_INDEX, offset cs:String8216LC
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$36:		cmp	ax, WD8216LT
		jne	$37
		mov	SRC_INDEX, offset cs:String8216LT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$37:		cmp	ax, WD8216N
		jne	$38
		mov	SRC_INDEX, offset cs:String8216N
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$38:		cmp	ax, WD8216TN
		jne	$39
		mov	SRC_INDEX, offset cs:String8216TN
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$39:		cmp	ax, WD8216CN
		jne	$40
		mov	SRC_INDEX, offset cs:String8216CN
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$40:		cmp	ax, WD8216TH
		jne	$41
		mov	SRC_INDEX, offset cs:String8216TH
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

endif		; #29

$41:		cmp	ax, WD8416T
		jne	$42
		mov	SRC_INDEX, offset cs:String8416T
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$42:		cmp	ax, WD8416BT
		jne	$43
		mov	SRC_INDEX, offset cs:String8416BT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$43:		cmp	ax, WD8416B
		jne	$44
		mov	SRC_INDEX, offset cs:String8416B
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$44:		cmp	ax, WD8416BTA
		jne	$45
		mov	SRC_INDEX, offset cs:String8416BTA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$45:		cmp	ax, WD8416TA
		jne	$46
		mov	SRC_INDEX, offset cs:String8416TA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$46:		
		cmp	ax, WD8416BA
		jne	$47
		mov	SRC_INDEX, offset cs:String8416BA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$47:						; 8414 = 8416 Tiger cards
		cmp	ax, WD8414T
		jne	$48
		mov	SRC_INDEX, offset cs:String8414T
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$48:		
		cmp	ax, WD8414BT
		jne	$49
		mov	SRC_INDEX, offset cs:String8414BT
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$49:		cmp	ax, WD8414B
		jne	$50
		mov	SRC_INDEX, offset cs:String8414B
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$50:		cmp	ax, WD8414BTA
		jne	$51
		mov	SRC_INDEX, offset cs:String8414BTA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$51:		cmp	ax, WD8414TA
		jne	$52
		mov	SRC_INDEX, offset cs:String8414TA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$52:		cmp	ax, WD8414BA
		jne	$53
		mov	SRC_INDEX, offset cs:String8414BA
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$53:

ifndef	UBIO	; #30

		cmp	ax, WD8216LTH
		jne	$54
		mov	SRC_INDEX, offset cs:String8216LTH
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

$54:		cmp	ax, WD8216T2
		jne	$55
		mov	SRC_INDEX, offset cs:String8216T2
		mov	ax, SUCCESS
		jmp	AdapNamePtrDone

endif		; #30

$55:		mov	SRC_INDEX, offset cs:StringAdapUnknown
		mov	ax, UNKNOWN_ADAPTER
AdapNamePtrDone:
ifdef	CODE386
		lea	edi, [ebp].adapter_name
else
		push	ds
		push	es
		pop	ds
		pop	es

		push	cs
		pop	ds
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
		pop	DEST_INDEX
		pop	SRC_INDEX
		ret

;;;;;;;;;;;;;;;; Adapter name strings located in CODE.

ifndef	UBIO	; #31

StringEthernet		db	'8003 Family',0,'$'
String8003WT		db	'8003WT',0,'$'
String8003W		db	'8003W',0,'$'
String8003EB		db	'8003EB',0,'$'
String8003EP		db	'8003EP',0,'$'
String8003EW		db	'8003EW',0,'$'
String8003ETA		db	'8003ET/A',0,'$'
String8003EA		db	'8003E/A',0,'$'
String8003EPA		db	'8013EP/A',0,'$'
String8003WA		db	'8003W/A',0,'$'
String8003WPA		db	'8013WP/A',0,'$'
String8003WC		db	'8003WC',0,'$'
String8003EPC		db	'8003EPC',0,'$'
String8013EBT		db	'8013EBT',0,'$'
String8013EB		db	'8013EP',0,'$'	; Adapter name changed to 8013EP.
String8013W		db	'8013W',0,'$'
String8013EW		db	'8013EW',0,'$'
String8013EWC		db	'8013EWC',0,'$'
String8013WC		db	'8013WC',0,'$'
String8013EPC		db	'8013EPC',0,'$'
String8115TA		db	'8115T/A',0,'$'
String8115T		db	'8115T',0,'$'
String8208		db	'8208',0,'$'
String8208C		db	'8208C',0,'$'
String8208T		db	'8208T',0,'$'

String8216		db	'8216',0,'$'
String8216T		db	'8216T',0,'$'
String8216C		db	'8216C',0,'$'
StringPCM10BT		db	'PCM10BT',0,'$'
String8216L		db	'8216L',0,'$'
String8216LT		db	'8216LT',0,'$'
String8216LC		db	'8216LC',0,'$'
String8216N		db	'8216/N',0,'$'
String8216TN		db	'8216T/N',0,'$'
String8216CN		db	'8216C/N',0,'$'
String8216TH		db	'8216TH',0,'$'
String8216LTH		db	'8216LTH',0,'$'
String8216T2		db	'8216T2',0,'$'

endif		; #31

String8416T		db	'8416T',0,'$'
String8416BT		db	'8416BT',0,'$'
String8416B		db	'8416B',0,'$'
String8416BTA		db	'8416BTA',0,'$'
String8416TA		db	'8416TA',0,'$'
String8416BA		db	'8416BA',0,'$'

String8414T		db	'8414T',0,'$'
String8414BT		db	'8414BT',0,'$'
String8414B		db	'8414B',0,'$'
String8414BTA		db	'8414BTA',0,'$'
String8414TA		db	'8414TA',0,'$'
String8414BA		db	'8414BA',0,'$'

StringAdapUnknown	db	'Unknown',0,'$'
GetAdapterNamePtr	endp

ifndef	UBIO	; #31a

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; VerifyParams	Verifies configuration parameters for the adapter indicated
;		by DS:BP. Verifies:
;				IRQ Range
;				IRQ Validity (IRQ>7 in 8 bit slot is invalid)
;				RAM Base Boundary
;				RAM Base Range
;				RAM Size Range
;				IO Base Range
;				IO Base Boundary
;
;		Return Codes:
;			SUCCESS
;			IRQ_RANGE
;			IRQ_INVALID
;			RAM_BASE_INVALID
;			RAM_BASE_RANGE
;			RAM_SIZE_RANGE
;			IO_BASE_RANGE
;			IO_BASE_INVALID
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	VerifyParams
VerifyParams	proc	near
		push	bx
		push	cx
		xor	dx, dx
		mov	ax, lm_gc_struc_ptr.irq_value
		cmp	ax, 2
		jne	CheckThree
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	NearIrqInvalid
IFDEF NEC
		jmp	IrqInvalid
ELSE
		jmp	IrqDone
ENDIF
CheckThree:	cmp	ax, 3
	  	jne	CheckFour
		jmp	IrqDone	 
CheckFour:	cmp	ax, 4
	  	jne	CheckFive
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		jne	ContinueFour1
		jmp	IrqDone	     
IFDEF NEC
ContinueFour1:	jmp	IrqInvalid
ELSE
ContinueFour1:	mov	bx, lm_gc_struc_ptr.extra_info
ENDIF
	      	test	bx, ALTERNATE_IRQ_BIT
		jnz	ContinueFour2
		jmp	IrqDone
ContinueFour2:	and	bx, INTERFACE_CHIP_MASK
	    	cmp	bx, INTERFACE_5X3_CHIP
		je	NearIrqInvalid
		jmp	IrqDone
CheckFive:	cmp	ax, 5
	  	jne	CheckSix
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	NearIrqInvalid
		test	lm_gc_struc_ptr.board_id, INTERFACE_CHIP
		jnz	ContinueFive
		jmp	IrqDone
ContinueFive:	mov	bx, lm_gc_struc_ptr.extra_info
	     	test	bx, ALTERNATE_IRQ_BIT
		jz	NearIrqInvalid
		jmp	IrqDone
NearIrqInvalid:	jmp	IrqInvalid
CheckSix:      	cmp	ax, 6
	 	jne	CheckSeven
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	NearIrqInvalid
		test	lm_gc_struc_ptr.board_id, BOARD_16BIT
		je	NearIrqInvalid
IFDEF NEC
		jmp	IrqDone
ENDIF
		test	lm_gc_struc_ptr.board_id, INTERFACE_CHIP
		jnz	NearIrqInvalid	  
		jmp	IrqDone
CheckSeven:	cmp	ax, 7
		jne	CheckEight
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	NearIrqInvalid
IFDEF NEC
		jmp	IrqInvalid
ELSE
		jmp	IrqDone
ENDIF
CheckEight:	cmp	ax, 8
IFDEF NEC
		jne	CheckNine
		jmp	IrqInvalid
ELSE
		je	HiInvalidIrq
ENDIF
CheckNine:	cmp	ax, 9
		jne	CheckTen
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	IrqInvalid
IFDEF NEC
		jmp	IrqDone
ELSE
		jmp	TestHiGroup
ENDIF
CheckTen:	cmp	ax, 10
	 	jne	CheckEleven
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	IrqDone
IFDEF NEC
		jmp	IrqInvalid
ELSE
		jmp	TestHiGroup
ENDIF
CheckEleven:	cmp	ax, 11
		jne	CheckTwelve
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	IrqInvalid
IFDEF NEC
		jmp	IrqInvalid
ELSE
		jmp	TestHiGroup
ENDIF
CheckTwelve:	cmp	ax, 12
IFDEF NEC
		jne	CheckThirteen
		jmp	IrqDone
CheckThirteen:
ELSE
		je	HiInvalidIrq
ENDIF
		cmp	ax, 13
IFDEF NEC
		jne	IrqOutOfRange
		jmp	IrqDone
ELSE
		jne	CheckFourteen
ENDIF
HiInvalidIrq:			     
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	IrqInvalid
		test	lm_gc_struc_ptr.board_id, BOARD_16BIT
		jz	IrqOutOfRange
		jmp	IrqInvalid
CheckFourteen:	cmp 	ax, 14
	      	jne	CheckFifteen
		mov	bx, lm_gc_struc_ptr.extra_info
		and	bx, INTERFACE_CHIP_MASK
		cmp	bx, INTERFACE_594_CHIP
		jne	IrqInvalid
		jmp	IrqDone
TestHiGroup:
		test	lm_gc_struc_ptr.board_id, BOARD_16BIT
		jz	IrqOutOfRange	
		test	lm_gc_struc_ptr.extra_info, SLOT_16BIT
		jz	IrqInvalid
		jmp	IrqDone

CheckFifteen:	cmp	ax, 15
		jne	IrqOutOfRange
;		mov	bx, lm_gc_struc_ptr.extra_info
;		and	bx, INTERFACE_CHIP_MASK
;		cmp	bx, INTERFACE_594_CHIP
;		je	IrqInvalid
		jmp	IrqDone
IrqInvalid:
		or	dx, IRQ_INVALID
		jmp	IrqDone
IrqOutOfRange:
		or	dx, IRQ_RANGE
		jmp	IrqDone
IrqDone:
;;;;;;; Check RAM Size
		mov   	bx, lm_gc_struc_ptr.ram_usable
		cmp	bx, 64
		je	RamSizeDone
		cmp	bx, 32
		je	RamSizeDone
		cmp	bx, 16
		je	RamSizeDone
		cmp	bx, 8
		je	RamSizeDone
		or	dx, RAM_SIZE_RANGE
RamSizeDone:
;;;;;;; Check RAM Base Boundary
		mov	bx, lm_gc_struc_ptr.extra_info
      		and	bx, INTERFACE_CHIP_MASK
		cmp	bx, INTERFACE_594_CHIP
		je	Check8kBound
		cmp	bx, INTERFACE_584_CHIP
		jne	Check5X3Group
		test	lm_gc_struc_ptr.extra_info, SLOT_16BIT
		jz	Check8kBound
		cmp	lm_gc_struc_ptr.ram_usable, 64
		je	Check64kBound
		cmp	lm_gc_struc_ptr.ram_usable, 32
		je	Check32kBound
		jmp	Check16kBound
Check5X3Group:
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	Check16kBound
		jmp	Check8kBound
Check64kBound:
		mov	bx, word ptr lm_gc_struc_ptr.ram_base
		test	bx, 0FFFFh
		jmp	BoundCheck
Check32kBound:
		mov	bx, word ptr lm_gc_struc_ptr.ram_base
		test	bx, 7FFFh
		jmp	BoundCheck
Check16kBound:
		mov	bx, word ptr lm_gc_struc_ptr.ram_base
		test	bx, 3FFFh
		jmp 	BoundCheck
Check8kBound:
		mov	bx, word ptr lm_gc_struc_ptr.ram_base
		test	bx, 1FFFh
		jmp 	BoundCheck
BoundCheck:
		jz	RamBaseBoundDone
		or	dx, RAM_BASE_INVALID
		jmp	RamBaseBoundDone
RamBaseBoundDone:
;;;;;;; Verify RAM Base Address
		mov	bx, word ptr lm_gc_struc_ptr.ram_base+2	; BX is Physical
						       	; RAM Address Hi Word
		test	lm_gc_struc_ptr.extra_info, SLOT_16BIT
		jnz	CheckHiBase
		cmp	lm_gc_struc_ptr.pc_bus, MCA_BUS
		je	CheckHiBase
		cmp	bx, 000Fh
		ja	RamBaseOutOfRange
CheckLoLimit:
		cmp	bx, 0008h
		jb	RamBaseOutOfRange
		jmp	RamBaseOk
CheckHiBase:	cmp	bx, 00FFh
		ja	RamBaseOutOfRange
		jmp	CheckLoLimit
RamBaseOutOfRange:
		or	dx, RAM_BASE_RANGE
RamBaseOk:
;;;;;;;;; Check I/O Base Address validity
		mov	ax, lm_gc_struc_ptr.io_base
		mov	bx, lm_gc_struc_ptr.extra_info
		and	bx, INTERFACE_CHIP_MASK
		cmp	bx, INTERFACE_594_CHIP
		je	CheckHiPort
IFDEF NEC
		cmp	ax, 1C00h
		jb	IoBaseOutOfRange
		cmp	ax, 1FC0h
		ja	IoBaseOutOfRange
		test	ax, 003Fh
		jnz	IoBaseInvalid
		jmp	IoAddrDone
ELSE
		cmp	ax, 200h
		jb	IoBaseOutOfRange
		cmp	ax, 3E0h
		ja	IoBaseOutOfRange
		test	ax, 001Fh
		jnz	IoBaseInvalid
		jmp	IoAddrDone
ENDIF
CheckHiPort:
		cmp	ax, 0800h
		jb	IoBaseOutOfRange
		cmp	ax, 0F800h
		ja	IoBaseOutOfRange
		test	ax, 07FFh
		jnz	IoBaseInvalid
		jmp	IoAddrDone
IoBaseOutOfRange:	
		or	dx, IO_BASE_RANGE
		jmp	IoAddrDone
IoBaseInvalid:
		or	dx, IO_BASE_INVALID
IoAddrDone:
		mov	ax, SUCCESS
		or	dx, dx
		jz	VerifyParamsExit
		mov	ax, CONFIG_ERROR
VerifyParamsExit:	      
	     	pop	cx    
		pop	bx
		ret
VerifyParams	endp

endif		; #31a

ifdef	SETUP_MODE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Get_SoftCnfg
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	LM_Get_SoftCnfg
ifdef	LARGE
LM_Get_SoftCnfg		proc	far
else
LM_Get_SoftCnfg		proc	near
endif
ifndef NT_CODE
	        pushf
	        cli
endif
		cmp	lm_gc_struc_ptr.pc_bus, AT_BUS
		jne	NoSoftConfig
		mov	ax, lm_gc_struc_ptr.extra_info
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_584_CHIP
		je	GetSoftConfig
		cmp	ax, INTERFACE_585_CHIP
		je	GetSoftConfig
		cmp	ax, INTERFACE_5X3_CHIP
		jmp	NoSoftConfig
GetSoftConfig:
		mov	dx, lm_gc_struc_ptr.io_base
		push	ax
		call	GetJumperStatus
		pop	ax
		jz	NoSoftConfig
		call	RecallConfigZero
		call	GetSoftIrq
		call	GetSoftIO
		call	GetSoftMemParams
		call	GetSoftRomParams
		call	RecallLanAddress
       		mov	ax, SUCCESS

GotCfg:
ifndef NT_CODE
		$POPFF
endif
		or	ax, ax
		ret

NoSoftConfig:	mov	ax, NO_FIXED_CNFG
		jmp	GotCfg
	   
LM_Get_SoftCnfg		endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetSoftIrq
GetSoftIrq		proc	near
		
		push	ax
		push	dx
		mov	bx, dx

ifndef	UBIO	; #32

		cmp	ax, INTERFACE_585_CHIP
		je	Get585SoftIrq
		add	dx, REG_LAR0+REG_IRR
		in	al, dx
		test	al, IRR_IEN
		jz	Irq584Disabled

		mov	dx, bx
		add	dx, REG_LAR0
		call	Internal584Irq
		jmp	SoftIrqDone
Get585SoftIrq:

endif		; #32

		add	dx, REG_HWR
		in	al, dx
		and	al, 0C3h
		mov	ah, al			; Save REG_HWR original value in AH.
		mov	dx, bx
		add	dx, REG_GCR
		call	Internal585Irq		; This call pops DX, BX & DX.
		jmp	SoftIrqDone
Irq584Disabled:
		mov	ax, 0
		mov	lm_gc_struc_ptr.irq_value, ax
SoftIrqDone:
		pop	dx
		pop	ax
		ret
GetSoftIrq		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetSoftIO
GetSoftIO		proc	near

		push	ax
		push	dx
		push	si
		mov	dx, bx

ifndef	UBIO	; #33
		cmp	ax, INTERFACE_585_CHIP
		je	Get585SoftIO
		add	dx, REG_LAR0+REG_IAR		; Get Soft IO address
		xor	ax, ax
		in	al, dx
		and	al, 0E0h
		mov	ah, al
		mov	al, 0
		mov	si, ax
		xor	ax, ax
		in	al, dx
		and	al, 1Fh
		mov	cx, 5
		shl	ax, cl
		or	si, ax
		jmp	SaveIoAndExit
Get585SoftIO:
endif		; #33
		add	dx, REG_IAR7
		xor	ax, ax
		in	al, dx
		and	al, 1Eh
		mov	cl, 4
		shl	ax, cl
		or	ax, 0200h
		mov	si, ax
		xor	ax, ax
		in	al, dx
		and	al, 0E0h
		mov	ah, al
		mov	al, 0
		or	si, ax
SaveIoAndExit:
		mov	lm_gc_struc_ptr.io_base, si
		pop	si
		pop	dx
		pop	ax
		ret
GetSoftIO		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetSoftMemParams
GetSoftMemParams		proc	near
		push	ax
		push	bx
		push	dx
		mov	bx, dx

ifndef	UBIO	; #34

		cmp	ax, INTERFACE_584_CHIP
		je	Get584SoftRamBase

endif		; #34

		add	dx, REG_HWR
		in	al, dx
		and	al, 0C3h
		mov	ah, al
		mov	dx, bx
		add	dx, REG_RAR
		call	Internal585RamBase

ifndef	UBIO	; #35

		jmp	SoftMemParamsExit		
Get584SoftRamBase:
		add	dx, REG_LAR0
		in	al, dx
		jmp	$+2
		and	al, 03Fh
		call	Internal584RamBase
SoftMemParamsExit:

endif		; #35

		pop	dx
		pop	bx
		pop	ax
		ret
GetSoftMemParams		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetSoftRomParams
GetSoftRomParams		proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		mov	bx, dx

ifndef	UBIO	; #36

		cmp	ax, INTERFACE_585_CHIP
		je	Get585RomParams
		add	dx, REG_LAR0
		call	Internal584RomBase
		call	Internal584RomSize
		jmp	SoftRomParamsExit
Get585RomParams:

endif		; #36

		add	dx, REG_HWR
		in	al, dx
		and	al, 0C3h
		mov	ah, al
		mov	dx, bx
		add	dx, REG_BAR
		push	ax
		call	Internal585RomBase
		pop	ax
		call	Internal585RomSize

SoftRomParamsExit:
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
GetSoftRomParams		endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RecallConfigZero		AX =	INTERFACE_585_CHIP or
;						INTERFACE_584_CHIP
;
;			   lm_gc_struc_ptr =	Pointer to adapter
;						structure
;			Return:	8 regs at offset REG_LAR0 contain Soft config.
;

PUBLIC	RecallConfigZero
RecallConfigZero	proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
ifndef NT_CODE
	        pushf
endif
		mov	dx, lm_gc_struc_ptr.io_base 	; Get IO base address
		mov	bx, dx				; Save in BX

ifndef	UBIO	; #37

		cmp	ax, INTERFACE_585_CHIP
		je	Recall585Data
		call	SelectOtherRegister
		add	dx, REG_EAR
		in	al, dx
		jmp	$+2
		and	al, 0Fh
		out	dx, al				; Select EEROM pg 0.

		mov	dx, bx
		mov	al, RECALL_DATA
		call	RecallEERomData
		jmp	RecallConfigZeroComplete
Recall585Data:

endif		; #37

		add	dx, REG_HWR
		in	al, dx
		jmp	$+2
		and	al, 43h
		out	dx, al		; Deselect Config register set

		add	dx, REG_EER - REG_HWR
		mov	al, 0				; Bank 0 is soft config
		or	al, EER_RC
		out	dx, al
Recall585Poll:
		jmp	$+2
		in	al, dx
		test	al, EER_RC
		jnz	Recall585Poll

RecallConfigZeroComplete:		
;----- 8 regs at offset REG_LAR0 now contain Soft config.

ifndef NT_CODE
		$POPFF
endif
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
RecallConfigZero	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	GetJumperStatus		Returns Z flag set if adapter is SOFT/SOFT
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	GetJumperStatus
GetJumperStatus		proc	near

		push	dx
		mov	dx, lm_gc_struc_ptr.io_base

ifndef	UBIO	; #38

		cmp	ax, INTERFACE_585_CHIP
		je	Get585JumperStatus
		add	dx, REG_IJR
		in	al, dx			; Get contents of IJR
		not	al			; Invert contents
		test	al, 07h			; Test low 3 bits - if
		jmp	JumperStatusExit	; all are zero, adapter is
						; soft/soft.
Get585JumperStatus:

endif		; #38

		add	dx, REG_EER
		in	al, dx
		not	al
		test	al, 0Fh
JumperStatusExit:
		pop	dx
		ret
GetJumperStatus		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RecallLanAddress
;
;	DX = IO base address
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	RecallLanAddress
RecallLanAddress	proc	near

		push	ax
		push	dx

ifndef	UBIO ; #39

		mov	ax, ds:[bp].extra_info
		and	ax, INTERFACE_CHIP_MASK
		cmp	ax, INTERFACE_585_CHIP
		je	Recall585LanAddr
		mov	al, RECALL_LANADDR
		call	RecallEERomData
		jmp	RecallLanAddrComplete
Recall585LanAddr:

endif		; #39

		add	dx, REG_HWR
		in	al, dx
		and	al, 43h
		out	dx, al
		
		add	dx, REG_EER - REG_HWR
		mov	al, 06h				; Bank 6 is LAN Addr
		or	al, EER_RC
		out	dx, al
Recall585LanAddrPoll:
		jmp	$+2
		in	al, dx
		test	al, EER_RC
		jnz	Recall585LanAddrPoll
RecallLanAddrComplete:
		pop	dx
		pop	ax
		ret
RecallLanAddress	endp

endif





