;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         PUTCNFG.ASM
;
; Description:	Routines for updating the configuration information for
;		Ethernet and Token Ring adapters.
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lmcom\vcs\putcnfg.avm  $
;  
;     Rev 1.27   07 Jul 1994 14:35:16   wood_r
;
; LM_8416_s2.1_v2.01
; Change:	Added code to save the Auto Media Detect feature bit.
;
; Bug Fix:	Changed a test for IO_MAPPED from using the mode_bits flag
;		to use the adapter_flags.
;
;+!/? ***********************************************************************


;**********************************************************
; PutCnfg    Put all configuration Information for 
;            the Interface chips -- 583,584,593 and 594
;
;
; Return: 
;      Ax -- 0, put configuration successfully.
;         -- 01, board_found but didn't put any information.
;         -- ffff, didn't find the board.
;      All registers except ax will be preserved.
;
;      All configuration information is put into
;      the configuration structure. 
;
;************************************************************
include	popff.mac
IFDEF	CODE386
lm_pc_base_ptr		equ	EBP
lm_pc_struc_ptr		equ	[EBP]
DataPtr			equ	[EBX]
DataIndex		equ	EBX
ELSE
lm_pc_base_ptr		equ	BP
lm_pc_struc_ptr		equ	DS:[BP]
DataPtr			equ	ES:[BX]
DataIndex		equ	BX
ENDIF
BANK_EIGHT		equ	EAR_EA6
BANK_B			equ	EAR_EA6+EAR_EA4+EAR_EA3
;
; Adapter POS ID's
;

CNFG_CDEN		equ	01h
CNFG_PME		equ	02h


ifdef	ETHERNET
db		'SMC Ethernet PutCnfg $Revision:   1.27  $',0,'$'
endif
ifdef	TOKEN_RING
db		'SMC Token Ring PutCnfg $Revision:   1.27  $',0,'$'
endif

;******************************************************************************
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public LM_PutCnfg
ENDIF
ifdef	LARGE
LM_PutCnfg	proc	far
else
LM_PutCnfg	proc	near
endif
IFNDEF	CODE386
	push	ds
	push	es
ENDIF
	push	lm_pc_base_ptr
	push	bx
	push	cx
	push	dx

	cmp	lm_pc_struc_ptr.pc_bus,MCA_BUS
	jz	lm_pc_mca_type
	call	lm_pc_put_at_config
	jmp	lm_pc_at_exit
lm_pc_mca_type:
	call	lm_pc_put_mca_config
lm_pc_at_exit:

	pop	dx
	pop	cx
	pop	bx
	pop	lm_pc_base_ptr
IFNDEF	CODE386
	pop	es
	pop	ds
ENDIF
	ret

LM_PutCnfg	endp

;********************************************************************************
;****************************************************************************** *
;*									      * *
;*	LM_PutLanAddr	Writes Lan Address to Bank 9 and Bank B of 584-based  * *
;*			Adapter.					      * *
;*									      * *
;*	Entry:		lm_pc_struc_ptr	(ds:[bp]) = Ptr to Adapter Structure  * *
;*			DataPtr (es:[bx]) = Ptr to 8-byte Lan Addr/ID/Cksum   * *
;*									      * *
;****************************************************************************** *
;********************************************************************************

ifdef	LM_GC_DEBUG
PUBLIC	LM_PutLanAddr
endif
ifdef	LARGE
LM_PutLanAddr	proc	far
else
LM_PutLanAddr	proc	near
endif

	push	bx
	push	cx
	push	dx
	pushf
	cli
	cld
	cmp	lm_pc_struc_ptr.bic_type, BIC_584_CHIP
	jne	PutLanAddrError
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_LAR0
	mov	cx, 8
WriteLanAddrLoop:
	mov	al, DataPtr
	out	dx, al
	inc	DataIndex
	inc	dx
	loop	WriteLanAddrLoop
;;; LAR0-8 now contain the LAN address to be written to banks 8 and B . . .
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_ICR
	in	al, dx
	and 	al, ICR_IR2
	or	al, ICR_OTH
	mov	ah, al
	out	dx, al		; Select "OTHER" register
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_EAR
	mov	al, BANK_EIGHT
SetEeromPage:
	out	dx, al
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_ICR
	mov	al, ah
	or	al, ICR_STO
	out	dx, al
PutLanAddrPoll:
	jmp	$+2
	in	al, dx
	test	al, ICR_STO
	jnz	PutLanAddrPoll
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_EAR
	in	al, dx
	cmp	al, BANK_B
	je	PutLanAddrSuccess
	mov	al, BANK_B
	jmp	SetEeromPage
PutLanAddrSuccess:
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_ICR
	mov	al, ah
	and	al, ICR_IR2
	out	dx, al
	mov	ax, SUCCESS
LanAddrExit:
	$POPFF
	pop	dx
	pop	cx
	pop	bx
	ret
PutLanAddrError:
	mov	ax, INVALID_FUNCTION
	jmp	LanAddrExit
LM_PutLanAddr	endp
;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_disable_slot
ENDIF
lm_pc_disable_slot	proc	near

	push	ax
	mov	al,0
	out	CNFG_POS_CONTROL_REG, al
	jmp	$+2
	pop	ax
	ret

lm_pc_disable_slot	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_enable_slot
ENDIF
lm_pc_enable_slot	proc	near

	push	ax
	mov	al, lm_pc_struc_ptr.slot_num
	or	al, al
	jz	lm_pc_protect_slot
	dec	al
lm_pc_protect_slot:
	or	al, CNFG_SLOT_ENABLE_BIT
	out	CNFG_POS_CONTROL_REG,al
	jmp	$+2
	pop	ax
	ret

lm_pc_enable_slot	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;	Returns: AX = POS ID
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_get_pos_id
ENDIF
lm_pc_get_pos_id	proc	near

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

lm_pc_get_pos_id	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_put_mca_config
ENDIF
lm_pc_put_mca_config	proc	near

	call	lm_pc_enable_slot
	call	lm_pc_get_pos_id	; returns AX = POS ID
	call	lm_pc_check_594_group
	jz	lm_pc_594_card
	call	lm_pc_check_593_group
	jz	lm_pc_593_card
	mov	ax, 0ffffh
	jmp	short lm_pc_bad_exit
lm_pc_593_card:
	call	lm_pc_put_593_cnfg
	jmp	short lm_pc_good_exit
lm_pc_594_card:
	call	lm_pc_put_594_cnfg
lm_pc_good_exit:
lm_pc_bad_exit:
	call	lm_pc_disable_slot
	or	ax, ax
	ret

lm_pc_put_mca_config	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_put_594_cnfg
ENDIF
lm_pc_put_594_cnfg	proc	near

	call	lm_pc_594_io
	call	lm_pc_594_irq
	call	lm_pc_594_ram_base
	call	lm_pc_594_ram_size
	call	lm_pc_594_rom_base
	call	lm_pc_594_rom_size
ifdef	TOKEN_RING
	mov	ax, lm_pc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, TOKEN_MEDIA
	jne	SkipTokenMedia
	call	lm_pc_tok_media
SkipTokenMedia:
endif
	xor	ax,ax
	ret

lm_pc_put_594_cnfg	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_put_593_cnfg
ENDIF
lm_pc_put_593_cnfg	proc	near

	call	lm_pc_593_io
	call	lm_pc_593_irq
	call	lm_pc_593_ram_base
	call	lm_pc_593_ram_size
	call	lm_pc_593_rom_base
	call	lm_pc_593_rom_size
	xor	ax,ax
	ret

lm_pc_put_593_cnfg	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_593_io
ENDIF
lm_pc_593_io	proc	near

	mov	ax, lm_pc_struc_ptr.io_base
	and	ax, 0FE0h
	mov	cl, 4
	shr	ax, cl
	or	al, CNFG_CDEN
	mov	dx, CNFG_POS_REG2
	out	dx, al
	jmp	$+2
	ret

lm_pc_593_io	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_593_irq
ENDIF
lm_pc_593_irq	proc	near

	mov	ax, lm_pc_struc_ptr.irq_value
	xchg	ah, al
	cmp	ah, 3
	je	lm_pc_593_irq_out
	inc	al
	cmp	ah, 4
	je	lm_pc_593_irq_out
	inc	al
	cmp	ah, 10
	je	lm_pc_593_irq_out
	inc	al
	cmp	ah, 15
lm_pc_593_irq_out:
	xchg	ah, al
	mov	dx, CNFG_POS_REG5
	in	al, dx
	and	al, 0FCh
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_593_irq	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_593_ram_base
ENDIF
lm_pc_593_ram_base	proc	near

	mov	ax, word ptr lm_pc_struc_ptr.ram_base
	mov	dx, word ptr lm_pc_struc_ptr.ram_base+2
	and	dx, 0Fh
	mov	cl, 4
	shl	dl, cl
	and	ax, 0C000h
	mov	cl, 12
	shr	ax, cl
	or	al, dl
	or	al, CNFG_PME
	mov	dx, CNFG_POS_REG3
	out	dx, al
	jmp	$+2
	ret

lm_pc_593_ram_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_593_ram_size
ENDIF
lm_pc_593_ram_size	proc	near

	ret

lm_pc_593_ram_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_593_rom_base
ENDIF
lm_pc_593_rom_base	proc	near

	mov	ax, word ptr lm_pc_struc_ptr.rom_base
	mov	dx, word ptr lm_pc_struc_ptr.rom_base+2
	and	dx, 0Fh
	mov	cl, 4
	shl	dl, cl
	and	ax, 0C000h
	mov	cl, 12
	shr	ax, cl
	or	al, dl
	xchg	ah, al
	mov	dx, CNFG_POS_REG4
	in	al, dx
	and	al, 03h
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_593_rom_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_593_rom_size
ENDIF
lm_pc_593_rom_size	proc	near

	mov	ax, lm_pc_struc_ptr.rom_size
	xchg	ah, al
	cmp	ah, CNFG_SIZE_16kb
	je	lm_pc_593_roms_out
	inc	al
	cmp	ah, CNFG_SIZE_32kb
	je	lm_pc_593_roms_out
	inc	al
	cmp	ah, ROM_DISABLE
	je	lm_pc_593_roms_out
	inc	al
	cmp	ah, CNFG_SIZE_64kb
lm_pc_593_roms_out:
	xchg	ah, al
	mov	dx, CNFG_POS_REG4
	in	al, dx
	and	al, 0FCh
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_593_rom_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_594_io
ENDIF
lm_pc_594_io	proc	near

	mov	ax, lm_pc_struc_ptr.io_base
	and	ax, 0F000h
	mov	cl, 8
	shr	ax, cl
	xchg	ah, al
	mov	dx, CNFG_POS_REG2
	in	al, dx
	and	al, 0Eh
	or	al, ah
	or	al, CNFG_CDEN
	out	dx, al
	jmp	$+2
	ret

lm_pc_594_io	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_594_irq
ENDIF
lm_pc_594_irq	proc	near

	mov	ax, lm_pc_struc_ptr.irq_value
	xchg	al, ah
	cmp	ah, 3
	je	lm_pc_594_irq_out
	inc	al
	cmp	ah, 4
	je	lm_pc_594_irq_out
	inc	al
	cmp	ah, 10
	je	lm_pc_594_irq_out
	inc	al
	cmp	ah, 14
lm_pc_594_irq_out:
	shl	al, 1
	shl	al, 1
	xchg	ah, al
	mov	dx, CNFG_POS_REG5
	in	al, dx
	and	al, 033h
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_594_irq	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_594_ram_base
ENDIF
lm_pc_594_ram_base	proc	near

	mov	ax, word ptr lm_pc_struc_ptr.ram_base
	mov	dx, word ptr lm_pc_struc_ptr.ram_base+2
	mov	cl, 13
	shr	ax, cl
	test	dx, 0001h
	jz	under_dseg
	or	al, 08h
under_dseg:
	and	dx, 0F0h
	jz	lm_pc_below_1MB
	or	al, 80h
lm_pc_below_1MB:
	xchg	ah, al
	mov	dx, CNFG_POS_REG3
	in	al, dx
	and	al, 070h
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_594_ram_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_594_ram_size
ENDIF
lm_pc_594_ram_size	proc	near

	mov	ax, lm_pc_struc_ptr.ram_usable
	xchg	ah, al
	cmp	ah, CNFG_SIZE_8kb
	je	lm_pc_594_rams_out
	inc	al
	cmp	ah, CNFG_SIZE_16kb
	je	lm_pc_594_rams_out
	inc	al
	cmp	ah, CNFG_SIZE_32kb
	je	lm_pc_594_rams_out
	inc	al
	cmp	ah, CNFG_SIZE_64kb
lm_pc_594_rams_out:
	mov	cl, 4
	shl	al, cl
	xchg	ah, al
	mov	dx, CNFG_POS_REG3
	in	al, dx
	and	al, 0CFh
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_594_ram_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_594_rom_base
ENDIF
lm_pc_594_rom_base	proc	near

	mov	ax, word ptr lm_pc_struc_ptr.rom_base
	mov	dx, word ptr lm_pc_struc_ptr.rom_base+2
	mov	cl, 13
	shr	ax, cl
	test	dx, 01h
	jz	rom_below_dseg
	or	al, 08h
rom_below_dseg:
	xchg	ah, al
	mov	dx, CNFG_POS_REG4
	in	al, dx
	and	al, 0F0h
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_594_rom_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_594_rom_size
ENDIF
lm_pc_594_rom_size	proc	near

	mov	ax, lm_pc_struc_ptr.rom_size
	xchg	ah, al
	cmp	ah, CNFG_SIZE_8kb
	je	lm_pc_594_roms_out
	inc	al
	cmp	ah, CNFG_SIZE_16kb
	je	lm_pc_594_roms_out
	inc	al
	cmp	ah, CNFG_SIZE_32kb
	je	lm_pc_594_roms_out
	inc	al
	cmp	ah, ROM_DISABLE
lm_pc_594_roms_out:
	mov	cl, 4
	shl	al, cl
	xchg	ah, al
	mov	dx, CNFG_POS_REG4
	in	al, dx
	and	al, 0CFh
	or	al, ah
	out	dx, al
	jmp	$+2
	ret

lm_pc_594_rom_size	endp

;**************************************
;	on entry ax: POSID
;
;	return:	zero flag is set if the
;	ID is in the group
;***************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_check_593_group
ENDIF
lm_pc_check_593_group	proc	near

IFNDEF	BISTRO
	cmp	ax, CNFG_ID_8003E
	jz	lm_pc_Checked_593_out
	cmp	ax, CNFG_ID_8003S
	jz	lm_pc_Checked_593_out
	cmp	ax, CNFG_ID_8003W
	jz	lm_pc_Checked_593_out
ENDIF
	cmp	ax, CNFG_ID_BISTRO03E
	jz	lm_pc_Checked_593_out
lm_pc_Checked_593_out:
	ret

lm_pc_check_593_group	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_check_594_group
ENDIF
lm_pc_check_594_group	proc	near

IFNDEF	BISTRO
	cmp	ax, CNFG_ID_8013E
	jz	lm_pc_Checked_594_out
	cmp	ax, CNFG_ID_8013W
	jz	lm_pc_Checked_594_out
	cmp	ax, CNFG_ID_8115TRA
	jz	lm_pc_Checked_594_out
ENDIF
	cmp	ax, CNFG_ID_BISTRO13E
	jz	lm_pc_Checked_594_out
	cmp	ax, CNFG_ID_BISTRO13W
lm_pc_Checked_594_out:
	ret

lm_pc_check_594_group	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_put_at_config
ENDIF
lm_pc_put_at_config	proc	near

	mov	dx, lm_pc_struc_ptr.io_base
	call	lm_pc_is_board_there
	jz	lm_pc_at_yes_board
	jmp	lm_pc_at_no_board
lm_pc_at_yes_board:
	test	lm_pc_struc_ptr.board_id, INTERFACE_CHIP
	jnz	lm_pc_at_yes_chip
	jmp	lm_pc_at_no_chip
lm_pc_at_yes_chip:
	cmp	lm_pc_struc_ptr.bic_type, BIC_585_CHIP
	jne	PutAtCfgNot585

; Chip is 585/790, check to see if config should be written to register set.

 	test	lm_pc_struc_ptr.config_mode, STORE_REGS
	jz	lm_pc_at_check_store_mode

	push	dx
	add	dx, REG_HWR
	in	al, dx
	and	al, 0C3h
	or	al, HWR_SWH
	out	dx, al
	pop	dx			; Select config register set.

	call	Write585Config		; Write adapter structure config to register set.

	push	dx
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_HWR
	in	al, dx
	jmp	$+2
	and	al, not HWR_SWH		; Select LAN address regs.
	out	dx, al
	pop	dx
	jmp	lm_pc_at_check_store_mode

PutAtCfgNot585:
 	test	lm_pc_struc_ptr.config_mode, STORE_REGS
	jz	lm_pc_at_check_store_mode
	call	Write584Config

lm_pc_at_check_store_mode:
	test	lm_pc_struc_ptr.config_mode, STORE_EEROM
	jz	put_at_exit
	mov	ax, lm_pc_struc_ptr.extra_info
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_5X3_CHIP
	je	Skip584Store
	cmp	ax, INTERFACE_584_CHIP
	je	Store584Data
	cmp	ax, INTERFACE_585_CHIP
	jne	lm_pc_at_no_chip
	call	lm_pc_585_store
	jmp	put_at_exit
Store584Data:
	call	lm_pc_584_store
	jmp	put_at_exit
Skip584Store:
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, CNFG_ICR_583
	in	al, dx
	jmp	$+2
	and	al, 0fh
	or	al, CNFG_ICR_STO
	out	dx, al
	jmp	$+2

Poll583Store:
	in	al, dx
	test	al, CNFG_ICR_STO
	jnz	Poll583Store

	jmp	put_at_exit
lm_pc_at_no_chip:
	mov	ax, 01h
	ret
lm_pc_at_no_board:
	mov	ax, 0ffffh
	ret
put_at_exit:
;	test	lm_pc_struc_ptr.config_mode, RECALL_CFG
;	jz	SkipRecall
;	call	RecallConfig
;SkipRecall:
	xor	ax, ax
	ret

lm_pc_put_at_config	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IFDEF	LM_GC_DEBUG
public	lm_pc_token_mode
ENDIF

lm_pc_token_mode	proc	near
	push	dx
	push	ax

	cmp	lm_pc_struc_ptr.bic_type, BIC_584_CHIP
	je	Do584TokenMode
	cmp	lm_pc_struc_ptr.bic_type, BIC_585_CHIP
	jne	LmPcTmUnsupportedBIC
	add	dx, REG_DCFG
	in	al, dx
	and	al, not DCFG_ETRD
	test	lm_pc_struc_ptr.mode_bits, EARLY_TOKEN_REL
	jnz	LmPcTmGotValue
	or	al, DCFG_ETRD
	jmp	LmPcTmGotValue
Do584TokenMode:
	add	dx, REG_GP2
	in	al, dx
	and	al, not GP2_ETRD
	test	lm_pc_struc_ptr.mode_bits, EARLY_TOKEN_REL
	jnz	LmPcTmGotValue
	or	al, GP2_ETRD
LmPcTmGotValue:
	out	dx, al
LmPcTmUnsupportedBIC:
	pop	ax
	pop	dx
	ret
lm_pc_token_mode	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public	lm_pc_58x_io
ENDIF
lm_pc_58x_io	proc	near
;	mov	dx, lm_pc_struc_ptr.io_base
	push	bx
	push	cx
	add	dx, CNFG_IAR_583
	mov	ax, lm_pc_struc_ptr.io_base_new
	mov	bx, ax
	and	bx, 0E0h
	and	ax, 03E0h
	mov	cl, 5
	shr	ax, cl
	or	al, bh
	out	dx, al
	jmp	$+2
	mov	dx, lm_pc_struc_ptr.io_base_new
	test	lm_pc_struc_ptr.config_mode, STORE_REGS
	jz	LeaveIoBaseAlone
	mov	lm_pc_struc_ptr.io_base, dx
LeaveIoBaseAlone:
	pop	cx
	pop	bx
	ret

lm_pc_58x_io	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_irq
ENDIF
lm_pc_58x_irq	proc	near
	push	bx
	push	cx
	push	dx
;	mov	dx, lm_pc_struc_ptr.io_base
	mov	ax, lm_pc_struc_ptr.extra_info
	mov	cx, 0
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_5X3_CHIP
	je	lm_pc_not_584_chip1
	mov	ch, 1				; Set 584 present flag
	push	dx
	add	dx, CNFG_ICR_583
	in	al, dx
	jmp	$+2
	pop	dx
	and	al, CNFG_ICR_MASK
	mov	cl, al
lm_pc_not_584_chip1:
	push	dx
	add	dx, CNFG_IRR_583
	in	al, dx
	jmp	$+2
	pop	dx
	and	al, NOT CNFG_IRR_IRQS
	mov	bl, al
; at this point, CH = 584 flag   CL = ICR value if 584   BL = IRR value
	mov	ax, lm_pc_struc_ptr.irq_value
	cmp	al, 9
	jne	lm_pc_58x_irq0
	mov	al, 2
lm_pc_58x_irq0:
	cmp	al, 2
	jne	lm_pc_58x_irq1
	mov	ah, 0
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq1:
	cmp	al, 3
	jne	lm_pc_58x_irq2
	mov	ah, 020h
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq2:
	cmp	al, 4
	jne	lm_pc_58x_irq3
	mov	ah, 040h
	test	lm_pc_struc_ptr.extra_info, ALTERNATE_IRQ_BIT
	jz	lm_pc_load_58x_irq
	or	cl, CNFG_ICR_IR2_584
	mov	ah, 060h
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq3:
	cmp	al, 5
	jne	lm_pc_58x_irq4
	mov	ah, 040h
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq4:
	cmp	al, 7
	jne	lm_pc_58x_irq5
	mov	ah, 060h
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq5:
	or	cl, CNFG_ICR_IR2_584
	cmp	al, 10
	jne	lm_pc_58x_irq6
	mov	ah, 0
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq6:
	cmp	al, 11
	jne	lm_pc_58x_irq7
	mov	ah, 020h
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq7:
	cmp	al, 15
	jne	lm_pc_58x_irq8
	mov	ah, 040h
	jmp	lm_pc_load_58x_irq
lm_pc_58x_irq8:
	mov	ah, 020h
	and	cl, CNFG_ICR_MASK
lm_pc_load_58x_irq:
;	mov	dx, lm_pc_struc_ptr.io_base
	or	ch, ch
	jz	lm_pc_not_584_chip2
	mov	al, cl
	push	dx
	add	dx, CNFG_ICR_583
	out	dx, al
	jmp	$+2
	pop	dx
lm_pc_not_584_chip2:
	add	dx, CNFG_IRR_583
	in	al, dx
	jmp	$+2
	and	al, 09fh
	or	al, ah
	out	dx, al
	jmp	$+2
	pop	dx
	pop	cx
	pop	bx
	ret

lm_pc_58x_irq	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public	lm_pc_58x_irq_status
ENDIF
lm_pc_58x_irq_status	proc	near
;	mov	dx, lm_pc_struc_ptr.io_base
	push	dx
	add	dx, CNFG_IRR_583
	in	al, dx
	jmp	$+2
	and	al, NOT CNFG_IRR_IEN
	test	lm_pc_struc_ptr.mode_bits, INTERRUPT_STATUS_BIT
	jz	lm_pc_58x_is_disabled
	or	al, CNFG_IRR_IEN
lm_pc_58x_is_disabled:
	out	dx, al
	jmp	$+2
	pop	dx
	ret

lm_pc_58x_irq_status	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public	lm_pc_58x_boot_status
ENDIF
lm_pc_58x_boot_status	proc	near
;	mov	dx, lm_pc_struc_ptr.io_base
	push	dx
	add	dx, CNFG_GP2
	in	al, dx
	jmp	$+2
	and	al, NOT CNFG_GP2_BOOT_NIBBLE
	test	lm_pc_struc_ptr.mode_bits, BOOT_STATUS_MASK
	jnz	lm_pc_58x_bs_enabled
	or	al, 1
lm_pc_58x_bs_enabled:
	out	dx, al
	jmp	$+2
	pop	dx
	ret

lm_pc_58x_boot_status	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_zero_wait_state
ENDIF
lm_pc_58x_zero_wait_state	proc	near
;	mov	dx, lm_pc_struc_ptr.io_base
	push	bx
	push	dx
	mov	bx, dx			; Save base I/O address in BX
	add	dx, CNFG_IRR_583
	in	al, dx
	jmp	$+2
	and	al, NOT CNFG_IRR_ZWS
	test	lm_pc_struc_ptr.mode_bits, ZERO_WAIT_STATE_8_BIT
	jz	lm_pc_58x_zws8_disabled
	or	al, CNFG_IRR_ZWS
lm_pc_58x_zws8_disabled:
	out	dx, al
	jmp	$+2
	test	lm_pc_struc_ptr.board_id, BOARD_16BIT
	jz	lm_pc_58x_not_16bit
;	mov	dx, lm_pc_struc_ptr.io_base
	mov	dx, bx
	add	dx, CNFG_LAAR_584
	in	al, dx
	jmp	$+2
	and	al, NOT CNFG_LAAR_ZWS
	test	lm_pc_struc_ptr.mode_bits, ZERO_WAIT_STATE_16_BIT
	jz	lm_pc_58x_zws16_disabled
;	or	al, CNFG_LAAR_ZWS
lm_pc_58x_zws16_disabled:
	out	dx, al
	jmp	$+2
lm_pc_58x_not_16bit:
	pop	dx
	pop	bx
	ret

lm_pc_58x_zero_wait_state	endp


;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_net_interface
ENDIF
lm_pc_58x_net_interface	proc	near

	push	bx
	push	dx
	add	dx, CNFG_IRR_583
	in	al, dx
	jmp	$+2
	and	al, 0F9h
ifdef	ETHERNET
	mov	bx, lm_pc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	je	TokenNetInterface
	test	lm_pc_struc_ptr.mode_bits, BNC_INTERFACE
	jz	@F
	or	al, 06h
	jmp	lm_pc_net_interface_done
@@:	test	lm_pc_struc_ptr.mode_bits, AUI_10BT_INTERFACE
	jz	@F
	or	al, 02h
	jmp	lm_pc_net_interface_done
@@:	test	lm_pc_struc_ptr.mode_bits, STARLAN_10_INTERFACE
	jz	no_adv_features
	jmp	lm_pc_net_interface_done
endif
TokenNetInterface:
ifdef	TOKEN_RING
	cmp	lm_pc_struc_ptr.media_type, MEDIA_STP_16
	jne	@F
	or	al, 04
	jmp	lm_pc_net_interface_done
@@:	cmp	lm_pc_struc_ptr.media_type, MEDIA_STP_4
	jne	@F
	or	al, 00
	jmp	lm_pc_net_interface_done
@@:	cmp	lm_pc_struc_ptr.media_type, MEDIA_UTP_16
	jne	@F
	or	al, 06
	jmp	lm_pc_net_interface_done
@@:	cmp	lm_pc_struc_ptr.media_type, MEDIA_UTP_4
	jne	no_adv_features
	or	al, 02
endif
lm_pc_net_interface_done:
ifdef	ETHERNET
	mov	bx, lm_pc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	je	@F
	test	lm_pc_struc_ptr.board_id, ADVANCED_FEATURES
	jnz	@F
	xor	al, 02h			; If not advanced feature adapter,
					; invert Link Integrity Test bit.
@@:
endif
	out	dx, al
	jmp	$+2
no_adv_features:
	pop	dx
	pop	bx	
	ret

lm_pc_58x_net_interface	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_ram_base
ENDIF
lm_pc_58x_ram_base	proc	near

	push	bx
	push	cx
 	push	dx

	mov	cx, lm_pc_struc_ptr.extra_info
	and	cx, INTERFACE_CHIP_MASK
	cmp	cx, INTERFACE_5X3_CHIP
	je	lm_pc_no_laar
	mov	ax, word ptr lm_pc_struc_ptr.ram_base+2
	and	ax, 00F8h
	mov	cl, 3
	shr	ax, cl
	xchg	ah, al
	add	dx, CNFG_LAAR_584
	in	al, dx
	jmp	$+2
	and	al, CNFG_LAAR_MASK
	or	al, ah
	test	word ptr lm_pc_struc_ptr.board_id, BOARD_16BIT
	jnz	lm_pc_is_16bit
	mov	al, 01h
lm_pc_is_16bit:
ifdef	TOKEN_RING
	mov	bx, lm_pc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	jne	@F
	or	al, CNFG_LAAR_L16E
@@:
endif
	out	dx, al
	jmp	$+2
lm_pc_no_laar:
	mov	ax, word ptr lm_pc_struc_ptr.ram_base
	mov	dx, word ptr lm_pc_struc_ptr.ram_base+2
	mov	cl, 13
	shr	ax, cl
	and	dx, 07h
	mov	cl, 3
	shl	dl, cl
	or	al, dl
	and	al, 03Fh

	pop	dx
	out	dx, al

	pop	cx
	pop	bx
	ret

lm_pc_58x_ram_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_ram_size
ENDIF
lm_pc_58x_ram_size	proc	near

;	mov	dx, lm_pc_struc_ptr.io_base
	push	bx
	push	dx
	mov	bx, lm_pc_struc_ptr.ram_size
	push	dx
	add	dx, CNFG_ICR_583
	in	al, dx
	jmp	$+2
	and	al, NOT CNFG_ICR_MSZ
	cmp	bx, CNFG_SIZE_8kb
	je	lm_pc_8k_ram1
	cmp	bx, CNFG_SIZE_16kb
	je	lm_pc_8k_ram1
;	or	al, CNFG_ICR_MSZ
lm_pc_8k_ram1:
	out	dx, al
	jmp	$+2
	pop	dx
;	add	dx, CNFG_IRR_583		; What ???
;	in	al, dx
;	jmp	$+2
;	and	al, NOT CNFG_IRR_IEN
;	cmp	bx, CNFG_SIZE_8kb
;	je	lm_pc_8k_ram2
;	or	al, CNFG_IRR_IEN
;lm_pc_8k_ram2:
;	out	dx, al
;	jmp	$+2

	pop	dx
	pop	bx
	ret

lm_pc_58x_ram_size	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_rom_base
ENDIF
lm_pc_58x_rom_base	proc	near

	push	bx
	push	cx
	push	dx
	mov	ax, word ptr lm_pc_struc_ptr.rom_base
	mov	bx, word ptr lm_pc_struc_ptr.rom_base+2
	and	bx, 07h
	mov	cl, 3
	shl	bl, cl
	mov	cl, 13
	shr	ax, cl
	or	al, bl
	xchg	ah, al
;	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, CNFG_BIO_583
	in	al, dx
	jmp	$+2
	and	al, 0C0h
	or	al, ah
	and	al, 0FEh
	out	dx, al
	jmp	$+2
	pop	dx
	pop	cx
	pop	bx
	ret

lm_pc_58x_rom_base	endp

;******************************************************************************
;
;	Assumes: DS:BP -> CNFG_Structure
;
;******************************************************************************
IFDEF	LM_GC_DEBUG
	public lm_pc_58x_rom_size
ENDIF
lm_pc_58x_rom_size	proc	near

	push	bx
	push	dx
	mov	bx, lm_pc_struc_ptr.rom_size
	mov	ah, 0C0h
	cmp	bx, CNFG_SIZE_64kb
	je	lm_pc_58x_rs_out
	mov	ah, 080h
	cmp	bx, CNFG_SIZE_32kb
	je	lm_pc_58x_rs_out
	mov	ah, 040h
	cmp	bx, CNFG_SIZE_16kb
	je	lm_pc_58x_rs_out
	mov	ah, 00h
;	cmp	bx, ROM_DISABLE
;	je	lm_pc_58x_rs_out
lm_pc_58x_rs_out:
;	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, CNFG_BIO_583
	in	al, dx
	and	al, 03Eh
	jmp	$+2
	or	al, ah
	out	dx, al
	jmp	$+2
	pop	dx
	pop	bx
	ret

lm_pc_58x_rom_size	endp

;*************************************************************************
;
;	lm_pc_is_board_there
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
	public lm_pc_is_board_there
ENDIF
lm_pc_is_board_there	proc	near
	push	dx
	push	cx
	push	bx
	push	ax
	xor	ah,ah		;zero counter
	add	dx,08h		;LANAddressZero
	mov	cx, 8		; loop count
lm_pc_ibt_loop:
	in	al,dx
	add	ah,al		; compute checksum
	inc	dx		;bump i/o pointer
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	jmp	$+2
	loop	lm_pc_ibt_loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	TOKEN_RING			; DO NOT CHANGE THIS CODE!!!!
	cmp	ah,0eeH			; DO NOT CHANGE THIS CODE!!!!
	je	GotChkSum		; DO NOT CHANGE THIS CODE!!!!
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

lm_pc_is_board_there	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF LM_GC_DEBUG
public	lm_pc_584_store
ENDIF
lm_pc_584_store	proc	near
	push	bx     
	push	cx
	push	dx
	push	di

	mov	cx, 8		; Use CX as config index:
				;	ROM	IRQ-IO-RAM	EEROM PG.
				;	===	==========	========
				; 1 =	soft	soft	  	0
				; 2 =	D800	soft		1
				; 3 =	soft	3-280-D000	2
				; 4 =	D800	3-280-D000	3
				; 5 =	soft	5-300-CC00	4
				; 6 =	D800	5-300-CC00	5
				; 7 =	(Hardware Initialized)	6
				; 8 =	D800	7-280-D000	7
				; only soft configs are changed.
	mov	dx, lm_pc_struc_ptr.io_base
	mov	di, dx			; Save base address in DI for later.
	add	dx, CNFG_ICR_583
	in	al, dx
	and	al, CNFG_ICR_IR2_584
	or	al, BID_OTHER_BIT
	out	dx, al
	mov	dx, di
	add	dx, CNFG_EAR_583
	in	al, dx
	jmp	$+2
	and	al, 0fh			; Set EEROM page = 7
	or	al, 70h
	out	dx, al
	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, CNFG_ICR_583
	in	al, dx
	and	al, 0eh
	or	al, CNFG_ICR_RLA
	out	dx, al
	jmp	$+2
FirstRecallWait:	
	in	al, dx
	jmp	$+2
	test	al, CNFG_ICR_RLA
	jnz	FirstRecallWait

	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, BID_LAR_0

WriteEEROM:
	cmp	cx, 6
	jge	ContinueLoop
	cmp	cx, 3			; If soft/3-280-D000, write boot ROM
	je	ROMOnly			; config only.
	cmp	cx, 4			; If D800/3-280-D000, do Net Interface
	je	ContinueLoop		; only.
	cmp	cx, 5
	je	ROMOnly

	call	lm_pc_58x_irq
	call	lm_pc_58x_irq_status
	call	lm_pc_58x_ram_base
	call	lm_pc_58x_ram_size
	cmp	cx, 2  			; If D800/soft, skip boot ROM config.
	je	SkipROM
ROMOnly:	
	call	lm_pc_58x_rom_base
	call	lm_pc_58x_rom_size
SkipROM:
	cmp	cx, 3			; If soft/3-280-D000, write boot ROM
	je	ContinueLoop		; config only.
	cmp	cx, 5
	je	ContinueLoop
	
	push	dx
	call	lm_pc_58x_io
	pop	dx
ContinueLoop:	
	call	lm_pc_58x_boot_status
	call	lm_pc_58x_zero_wait_state
	call	lm_pc_58x_net_interface

ifdef	TOKEN_RING
	mov	ax, lm_pc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, TOKEN_MEDIA
	jne	SkipTokenMode
	call	lm_pc_token_mode
SkipTokenMode:
endif
	push	dx
	mov	dx, di

	add	dx, CNFG_ICR_583
	in	al, dx
	jmp	$+2
	and	al, CNFG_ICR_IR2_584
	or	al, BID_OTHER_BIT+CNFG_ICR_STO
	out	dx, al			; Store config in EEROM.
	jmp	$+2
StoreWait:
	in	al, dx
	jmp	$+2
	test	al, CNFG_ICR_STO
	jnz	StoreWait		; Poll STO bit until clear.

	mov	dx, di
	add	dx, CNFG_EAR_583
	in	al, dx
	jmp	$+2
	sub	al, 10h			; Decrement EEROM page
	out	dx, al

	mov	dx, di
	add	dx, CNFG_ICR_583
	in	al, dx
	jmp	$+2
	and	al, CNFG_ICR_IR2_584
	or	al, CNFG_ICR_RLA+BID_OTHER_BIT
	out	dx, al			; Recall next config set into LAN
	jmp	$+2			; Address regs
RecallWait:
	in	al, dx
	jmp	$+2
	test	al, CNFG_ICR_RLA
	jnz	RecallWait

	pop	dx
	dec	cx
	cmp	cx, 0
	je	WriteEEROMLoopDone
	jmp	WriteEEROM		; Loop until EEROM pgs 0-7 are done.
WriteEEROMLoopDone:
	mov	dx, di
	add	dx, CNFG_ICR_583
	in	al, dx
	and	al, CNFG_ICR_IR2_584
	out	dx, al			; Restore BIO register
	or	al, CNFG_ICR_RLA	; Recall the actual LAN address
	out	dx, al
LANAddrWait:
	in	al, dx
	test	al, CNFG_ICR_RLA
	jnz	LANAddrWait

	mov	ax, lm_pc_struc_ptr.extra_info
	and	ax, INTERFACE_CHIP_MASK
	cmp	ax, INTERFACE_584_CHIP
	jne	SkipChecksum

ifdef	LARGE
	call	far ptr Write584Checksum
else
	call	Write584Checksum
endif

SkipChecksum:
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret	
lm_pc_584_store	endp

ifdef	TOKEN_RING

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LM_PC_TOK_MEDIA sets token media bits in 594 based on data in 
; Adapter Structure field MEDIA_TYPE.
;

IFDEF	LM_GC_DEBUG
public	lm_pc_tok_media
ENDIF

lm_pc_tok_media		proc	near
	push	ax
	push	dx
     	mov	ax, lm_pc_struc_ptr.io_base
	mov	dx, CNFG_POS_REG5
	in	al, dx
	and	al, 0FCh

	cmp	lm_pc_struc_ptr.media_type, MEDIA_STP_16
	jne	@F
	or	al, 01
	jmp	lm_pc_tok_media_done
@@:	cmp	lm_pc_struc_ptr.media_type, MEDIA_STP_4
	jne	@F
	or	al, 00
	jmp	lm_pc_tok_media_done
@@:	cmp	lm_pc_struc_ptr.media_type, MEDIA_UTP_16
	jne	@F
	or	al, 03
	jmp	lm_pc_tok_media_done
@@:	cmp	lm_pc_struc_ptr.media_type, MEDIA_UTP_4
	jne	unknown_features
	or	al, 02

lm_pc_tok_media_done:
	out	dx, al
unknown_features:
	pop	dx
	pop	ax
	ret

lm_pc_tok_media		endp
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	lm_pc_585_store		Stores config info on 585/790-based
;				adapters.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_store
ENDIF
lm_pc_585_store		proc	near

	push	bx
	push	cx
	push	dx
	push	si
	push	ds
	pushf
	cli
	cld
	
	mov	cx, 5			; Loop count
	mov	bx, 8			; BX = EEROM bank.
	mov	si, lm_pc_struc_ptr.io_base
Write790Configs:

	mov	dx, si
	add	dx, REG_EER
	mov	al, bl
	or	al, EER_RC
	out	dx, al

PollConfigRecall:
	in	al, dx
	test	al, EER_RC
	jnz	PollConfigRecall	; Recall Config into LAN address regs.

	mov	dx, si
	add	dx, REG_HWR
	in	al, dx
	mov	ah, al			; Save original REG_HWR contents in AH.
	and	al, 43h			; Mask off unwanted bits; clear SWH.
	out	dx, al

	cmp	bx, 0
	jne	Write585NetStuff
	call	Write585Config		; Store config zero in LAN addr regs.
	jmp	Config585Written
Write585NetStuff:
	call	lm_pc_585_boot_status
	call	lm_pc_585_zero_wait_state
	call	lm_pc_585_net_interface

; Perform Unlock sequence and write data in LAN address registers to bank 0.
Config585Written:
	mov	dx, si
	add	dx, REG_EER
	mov	al, 0Ch
	out	dx, al		; First step of unlock sequence
	jmp	$+2
	mov	al, 0Ah
	or	al, EER_UNLCK
	out	dx, al		; Second step of unlock sequence
	jmp	$+2
	mov	al, bl		; Select appropriate bank
	or	al, EER_STO	; Set Store bit
	out	dx, al		; Store data and poll EER_STO until clear.
Poll585Store:
	jmp	$+2
	in	al, dx
	test	al, EER_STO
	jnz	Poll585Store
	shr	bx, 1		; Do next EEROM bank, we're doing banks 8,4,2,1, and 0.
	loop	Write790Configs
;
;	Set the Auto Media detect feature bit as selected
;
	call	lm_pc_585_AMD

CheckSuperset:
	test	lm_pc_struc_ptr.board_id, NIC_SUPERSET
	jz	NoSupersetOptions
	call	lm_pc_585_superset_options
	jmp	lm_pc_585_store_exit

NoSupersetOptions:
	mov	al, 06h		; Recall Lan Address
	or	al, EER_RC
	out	dx, al

Poll585Recall:
	jmp	$+2
	in	al, dx
	test	al, EER_RC
	jnz	Poll585Recall

lm_pc_585_store_exit:
	mov	dx, si
	add	dx, REG_HWR
	mov	al, ah
	out	dx, al		; Restore REG_HWR.

	$POPFF
	pop	ds
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret

lm_pc_585_store		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_irq
ENDIF
lm_pc_585_irq	proc	near
		push	bx
		push	dx
		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_GCR
		mov	ax, lm_pc_struc_ptr.irq_value

		cmp	ax, 2
		jne	Check585IrqThree
		mov	ah, GCR_IR0
		jmp	Got585Irq
Check585IrqThree:
		cmp	ax, 3
		jne	Check585IrqFour
		mov	ah, GCR_IR1
		jmp	Got585Irq
Check585IrqFour:
		cmp	ax, 4
		jne	Check585IrqFive
		test	lm_pc_struc_ptr.board_id, BOARD_16BIT
		jz	Set585Irq4
		jmp	Error585Irq
Set585Irq4:	mov	ah, GCR_IR0+GCR_IR1
		jmp	Got585Irq
Check585IrqFive:
		cmp	ax, 5
		jne	Check585IrqSeven
		test	lm_pc_struc_ptr.board_id, BOARD_16BIT
		jnz	SixteenBitIrqFive
		mov	ah, GCR_IR2
		jmp	Got585Irq
SixteenBitIrqFive:
		mov	ah, GCR_IR0+GCR_IR1
		jmp	Got585Irq
Check585IrqSeven:
		cmp	ax, 7
		jne	Check585IrqTen
		test	lm_pc_struc_ptr.board_id, BOARD_16BIT
		jnz	SixteenBitIrqSeven
		mov	ah, GCR_IR0+GCR_IR2
		jmp	Got585Irq
SixteenBitIrqSeven:
		mov	ah, GCR_IR2
		jmp	Got585Irq
Check585IrqTen:
		cmp	ax, 10
		jne	Check585IrqEleven
		test	lm_pc_struc_ptr.board_id, BOARD_16BIT
		jnz	SixteenBitIrqTen
		jmp	Error585Irq
SixteenBitIrqTen:
		mov	ah, GCR_IR0+GCR_IR2
		jmp	Got585Irq
Check585IrqEleven:
		cmp	ax, 11
		jne	Check585IrqFifteen
		test	lm_pc_struc_ptr.board_id, BOARD_16BIT
		jnz	SixteenBitIrqEleven
		jmp	Error585Irq
SixteenBitIrqEleven:
		mov	ah, GCR_IR1+GCR_IR2
		jmp	Got585Irq
Check585IrqFifteen:
		cmp	ax, 15
		jne	Error585Irq
		test	lm_pc_struc_ptr.board_id, BOARD_16BIT
		jnz	SixteenBitIrqFifteen
		jmp	Error585Irq
SixteenBitIrqFifteen:
		mov	ah, GCR_IR0+GCR_IR1+GCR_IR2
Got585Irq:
		in	al, dx
		and	al, not GCR_IR0+GCR_IR1+GCR_IR2+GCR_EUTP
		or	al, ah
		out	dx, al

		pop	dx
		pop	bx
		ret

Error585Irq:	mov	ax, 0
		jmp	Got585Irq

lm_pc_585_irq	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_irq_status
ENDIF
lm_pc_585_irq_status	proc	near

		push	dx

		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_BPR
		in	al, dx
		and	al, 0F3h
		test	lm_pc_struc_ptr.mode_bits, INTERRUPT_STATUS_BIT
		jz	Irq585Disabled
		or	al, BPR_EIL
Irq585Disabled:
		out	dx, al
		pop	dx
		ret
lm_pc_585_irq_status	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_ram_base
ENDIF
lm_pc_585_ram_base	proc	near
		push	bx
		push	cx
		push	dx

		xor	ax, ax
		mov	bx, word ptr lm_pc_struc_ptr.ram_base	; Get RAM base Lo word.
		mov	cx, 13
		shr	bx, cl
		or	ah, bl		; AH now contains RAR_RA15:13
		mov	bx, word ptr lm_pc_struc_ptr.ram_base+2	; Get RAM base Hi word.
		and	bx, 01h		; Mask all but RA16.
		mov	cx, 3
		shl	bx, cl		; Align RA16
		or	ah, bl		; AH now contains RAR_RA16:13
		mov	bx, word ptr lm_pc_struc_ptr.ram_base+2	; Get RAM base Hi word.
		and	bx, 02h		; Mask all but RA17.
		mov	cx, 5
		shl	bx, cl		; Align RA17
		or	ah, bl
		mov	bx, word ptr lm_pc_struc_ptr.ram_base+2	; Get RAM base Hi word.
		test	bx, 0F0h
		jz	Ram585BaseLow
		or	ah, RAR_HRAM	; Ram base is > 1 MB.
Ram585BaseLow:
		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_RAR
		in	al, dx
		jmp	$+2
		and	al, RAR_RWS0+RAR_RWS1
		or	al, ah
		out	dx, al

		pop	dx
		pop	cx
		pop	bx
		ret
lm_pc_585_ram_base	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_ram_size
ENDIF
lm_pc_585_ram_size	proc	near
		push	bx
		push	cx
		push	dx
		xor	ax, ax
		mov	bx, lm_pc_struc_ptr.ram_usable
		mov	cx, 4
		shr	bx, cl
Ram585SizeLoop:
		jz	GotRam585SizeIndex
		inc	ax
		shr	bx, 1
		jmp	Ram585SizeLoop

GotRam585SizeIndex:
		and	al, 03h
		mov	cx, 4
		shl	al, cl
		mov	ah, al
		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_RAR
		in	al, dx
		and	al, not RAR_RWS0+RAR_RWS1
		or	al, ah
		out	dx, al

		pop	dx
		pop	cx
		pop	bx
		ret
lm_pc_585_ram_size	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_rom_base
ENDIF
lm_pc_585_rom_base	proc	near
		push	bx
		push	cx
		push	dx

		xor	ax, ax
		mov	bx, word ptr lm_pc_struc_ptr.rom_base	; Get Rom base Lo word.
		mov	cx, 13
		shr	bx, cl
		or	ah, bl		; AH now contains BAR_BA15:13
		mov	bx, word ptr lm_pc_struc_ptr.rom_base+2	; Get Rom base Hi word.
		and	bx, 01h		; Mask all but RA16.
		mov	cx, 3
		shl	bx, cl		; Align BA16
		or	ah, bl		; AH now contains BAR_BA16:13
		mov	bx, word ptr lm_pc_struc_ptr.rom_base+2	; Get Rom base Hi word.
		and	bx, 02h		; Mask all but BA17.
		mov	cx, 5
		shl	bx, cl		; Align BA17
		or	ah, bl

		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_BAR
		in	al, dx
		jmp	$+2
		and	al, BAR_BWS0+BAR_BWS1
		or	al, ah
		out	dx, al

		pop	dx
		pop	cx
		pop	bx
		ret
lm_pc_585_rom_base	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_rom_size
ENDIF
lm_pc_585_rom_size	proc	near
		push	bx
		push	cx
		push	dx
		xor	ax, ax
		mov	bx, lm_pc_struc_ptr.rom_size
		or	bx, bx
		jz	Rom585SizeDisabled
		mov	cx, 4
		shr	bx, cl
Rom585SizeLoop:
		jz	GotRom585SizeIndex
		inc	ax
		shr	bx, 1
		jmp	Rom585SizeLoop

GotRom585SizeIndex:
		and	al, 03h
		mov	cx, 4
		shl	al, cl
		mov	ah, al
		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_BAR
		in	al, dx
		and	al, not BAR_BWS0+BAR_BWS1
		or	al, ah
		out	dx, al

		pop	dx
		pop	cx
		pop	bx
		ret
Rom585SizeDisabled:
		mov	ax, 03h
		jmp	GotRom585SizeIndex
lm_pc_585_rom_size	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_boot_status
ENDIF
lm_pc_585_boot_status	proc	near
		push	bx
		push	cx
		push	dx

		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_GCR
		in	al, dx
		and	al, not GCR_RIPL
		test	lm_pc_struc_ptr.mode_bits, BOOT_STATUS_MASK
		jnz	Boot585StatusEnabled
		or	al, GCR_RIPL
Boot585StatusEnabled:
		out	dx, al
		pop	dx
		pop	cx
		pop	bx
		ret
lm_pc_585_boot_status	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_zero_wait_state
ENDIF
lm_pc_585_zero_wait_state	proc	near
		push	dx
		mov	dx, lm_pc_struc_ptr.io_base
		add	dx, REG_GCR
		in	al, dx
		and	al, not GCR_0WS
		test	lm_pc_struc_ptr.mode_bits, ZERO_WAIT_STATE_MASK
		jz	No585WaitState
		or	al, GCR_0WS
No585WaitState:
		out	dx, al
		pop	dx
		ret
lm_pc_585_zero_wait_state	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_net_interface
ENDIF
lm_pc_585_net_interface		proc	near
	push	bx
	push	cx
	push	dx

	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_GCR
	in	al, dx
	jmp	$+2
	and	al, not GCR_GPOUT+GCR_LITE

	mov	bx, lm_pc_struc_ptr.board_id
	and	bx, MEDIA_MASK
	cmp	bx, TOKEN_MEDIA
	je	DoTokenNetInterface

ifdef	ETHERNET
	mov	cx, lm_pc_struc_ptr.mode_bits
	and	cx, INTERFACE_TYPE_MASK

	cmp	cx, BNC_INTERFACE
	je	Set585BNC

	cmp	cx, UTP_INTERFACE
	jne	Check585AUI

	test	lm_pc_struc_ptr.mode_bits, UTP2_PORT
	jnz	Set585BNC
	jmp	Set585LITE

Check585AUI:
	cmp	cx, AUI_10BT_INTERFACE
	je	Set585LITE

	cmp	cx, AUI_INTERFACE
	je	Set585LITE
	
	cmp	cx, STARLAN_10_INTERFACE
	je	Set585S10
	jmp	Unknown585NetInterface

Set585BNC:
	or	al, GCR_GPOUT

Set585LITE:
	or	al, GCR_LITE

Set585S10:
	jmp	lm_pc_585_net_interface_done
endif

DoTokenNetInterface:

ifdef	TOKEN_RING
;	jmp	Unknown585NetInterface	; Stub out TR for now because net
;					; interface bits are not yet defined.
	cmp	lm_pc_struc_ptr.media_type, MEDIA_STP_16
	jne	Check585StpFour
	or	al, 02h
	jmp	lm_pc_585_net_interface_done
Check585StpFour:
	cmp	lm_pc_struc_ptr.media_type, MEDIA_STP_4
	jne	Check585UtpSixteen
	or	al, 00h
	jmp	lm_pc_585_net_interface_done
Check585UtpSixteen:
	cmp	lm_pc_struc_ptr.media_type, MEDIA_UTP_16
	jne	Check585UtpFour
	or	al, 03h
	jmp	lm_pc_585_net_interface_done
Check585UtpFour:
	cmp	lm_pc_struc_ptr.media_type, MEDIA_UTP_4
	jne	Unknown585NetInterface
	or	al, 01h
endif
lm_pc_585_net_interface_done:
	out	dx, al
	jmp	$+2
Unknown585NetInterface:
	pop	dx
	pop	cx
	pop	bx	
	ret
lm_pc_585_net_interface		endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	lm_pc_585_superset_options	Stores config options associated
;					with 790 superset.
;
;					DS:BP -> Adapter Structure
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lm_pc_585_superset_options	proc	near
	
	push	ax
	push	dx

	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_EER
	mov	al, 0Ah		; Recall bank A into lan addr regs.
	or	al, EER_RC
	out	dx, al

PollSupersetRecall:
	in	al, dx
	test	al, EER_RC
	jnz	PollSupersetRecall	; Recall data into LAN address regs.
	
	push	dx			; Save address of REG_EER.
	add	dx, BID_REG_3 + BID_LAR_0 - REG_EER
	in	al, dx
	and	al, not BID_EEPROM_IO_MAPPED
	test	lm_pc_struc_ptr.adapter_flags, IO_MAPPED
	jz	StoreSupersetData
	or	al, BID_EEPROM_IO_MAPPED

StoreSupersetData:
	out	dx, al
	pop	dx		; Restore address of REG_EER.

	mov	al, 0Ch
	out	dx, al		; First step of unlock sequence
	jmp	$+2
	mov	al, 0Ah
	or	al, EER_UNLCK
	out	dx, al		; Second step of unlock sequence
	jmp	$+2
	mov	al, 0Ah		; Select appropriate bank
	or	al, EER_STO	; Set Store bit
	out	dx, al		; Store data and poll EER_STO until clear.

PollSupersetStore:
	jmp	$+2
	in	al, dx
	test	al, EER_STO
	jnz	PollSupersetStore

	mov	al, 06h		; Recall Lan Address
	or	al, EER_RC
	out	dx, al

PollSupersetFinalRecall:
	jmp	$+2
	in	al, dx
	test	al, EER_RC
	jnz	PollSupersetFinalRecall

	pop	dx
	pop	ax
	ret
lm_pc_585_superset_options	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	lm_pc_585_AMD		Stores Auto Media Detect feature bit in 
;				EEPROM at byte 6 in bank A.
;
;				DS:BP -> Adapter Structure
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lm_pc_585_AMD	proc	near
	push	ax
	push	dx

	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_EER
	mov	al, 0Ah			; Recall bank A into lan addr regs.
	or	al, EER_RC
	out	dx, al

PollAMDRecall:
	in	al, dx
	test	al, EER_RC
	jnz	PollAMDRecall		; Recall data into LAN address regs.
	
	push	dx			; Save address of REG_EER.
	add	dx, BID_REG_6 + BID_LAR_0 - REG_EER
	in	al, dx
	and	al, not BID_EEPROM_AUTO_MEDIA_DETECT

	test	lm_pc_struc_ptr.mode_bits, AUTO_MEDIA_DETECT
	jz	Set_AMD

	or	al, BID_EEPROM_AUTO_MEDIA_DETECT

Set_AMD:
	out	dx, al

	pop	dx		; Restore address of REG_EER.
	mov	al, 0Ch
	out	dx, al		; First step of unlock sequence
	jmp	$+2
	mov	al, 0Ah
	or	al, EER_UNLCK
	out	dx, al		; Second step of unlock sequence
	jmp	$+2
	mov	al, 0Ah		; Select appropriate bank
	or	al, EER_STO	; Set Store bit
	out	dx, al		; Store data and poll EER_STO until clear.

PollAMDStore:
	jmp	$+2
	in	al, dx
	test	al, EER_STO
	jnz	PollAMDStore

	mov	al, 06h		; Recall Lan Address
	or	al, EER_RC
	out	dx, al

PollAMDFinalRecall:
	jmp	$+2
	in	al, dx
	test	al, EER_RC
	jnz	PollAMDFinalRecall

	pop	dx
	pop	ax
	ret
lm_pc_585_AMD	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;	Assumes REG_HWR:HWR_SWH is set.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IFDEF	LM_GC_DEBUG
public	lm_pc_585_io
ENDIF
lm_pc_585_io		proc	near
	
	push	bx
	push	cx
	push	dx

	mov	ax, lm_pc_struc_ptr.io_base_new
	and	ax, 01E0h		; Isolate bits 8:5
	mov	cx, 4
	shr	ax, cl			; Align IA5 with bit 1.
	mov	bx, ax			; Save in BX.
	mov	ax, lm_pc_struc_ptr.io_base_new
	and	ax, 0E000h		; Isolate bits 15:13
	mov	cx, 8
	shr	ax, cl			; Align IA13 with bit 5.
	or	ax, bx			; OR with IA8:5 (aligned in BX)

	mov	dx, lm_pc_struc_ptr.io_base
	add	dx, REG_IAR7
	out	dx, al
	mov	ax, lm_pc_struc_ptr.io_base_new

	test	lm_pc_struc_ptr.config_mode, STORE_REGS
	jz	DontChangeIoBase
	mov	lm_pc_struc_ptr.io_base, ax
DontChangeIoBase:

	pop	dx
	pop	cx
	pop	bx
	ret
lm_pc_585_io		endp

;*************************************************************************
;*************************************************************************
;*									**
;*	Write585Config	Stores config in adapter structure into 585	**
;*			register set. If HWR:SWH is set, config is	**
;*			written to config regs, otherwise config is	**
;*			written to LAN addr regs.		 	**
;*									**
;*************************************************************************
;*************************************************************************
Write585Config	proc	near

	call	lm_pc_585_irq
;	call	lm_pc_585_irq_status
	call	lm_pc_585_ram_base
	call	lm_pc_585_ram_size
	call	lm_pc_585_rom_base
	call	lm_pc_585_rom_size
	call	lm_pc_585_boot_status
	call	lm_pc_585_zero_wait_state
	call	lm_pc_585_net_interface
ifdef	TOKEN_RING
	mov	ax, lm_pc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, TOKEN_MEDIA
	jne	Skip585TokenMode
	call	lm_pc_token_mode
Skip585TokenMode:
endif
	call	lm_pc_585_io
	ret
Write585Config	endp

;*************************************************************************
;*************************************************************************
;*									**
;*	Write584Config	Stores config in adapter structure into 584	**
;*			register indicated by DX.			**
;*									**
;*************************************************************************
;*************************************************************************
Write584Config	proc	near

	call	lm_pc_58x_irq
	call	lm_pc_58x_irq_status
	call	lm_pc_58x_ram_base
	call	lm_pc_58x_ram_size
	call	lm_pc_58x_rom_base
	call	lm_pc_58x_rom_size
	call	lm_pc_58x_boot_status
	call	lm_pc_58x_zero_wait_state
	call	lm_pc_58x_net_interface
ifdef	TOKEN_RING
	mov	ax, lm_pc_struc_ptr.board_id
	and	ax, MEDIA_MASK
	cmp	ax, TOKEN_MEDIA
	jne	Skip584TokenMode
	call	lm_pc_token_mode
Skip584TokenMode:
endif
	call	lm_pc_58x_io
	ret
Write584Config	endp

;;******************************************************************************
;;******************************************************************************
;;*									      *
;;*	RecallConfig	Recalls all config data from EEROM - same as	      *
;;*			power up. Routine includes delay to ensure	      *	
;;*			data is stable upon exit. LM_GetCnfg is called	      *
;;*			before exit.					      *
;;*									      *
;;*	Entry:	lm_pc_struc_ptr		Ptr to adapter struc.		      *
;;*									      *
;;*	Exit:	AX	Return code from LM_Getcnfg after recall.	      *
;;*			All other regs preserved.			      *
;;*									      *
;;******************************************************************************
;;******************************************************************************
;
;RecallConfig	proc	near
;	push	bx
;	push	cx
;	push	dx
;
;	cmp	lm_pc_struc_ptr.bic_type, BIC_585_CHIP
;	je	Recall585Config
;	cmp	lm_pc_struc_ptr.bic_type, BIC_584_CHIP
;	je	Recall584Config
;	jmp	ExitRecallConfig
;Recall585Config:
;	mov	dx, lm_pc_struc_ptr.io_base
;	add	dx, REG_EER
;	in	al, dx
;	and	al, 0Fh				; Lo nibble of AL contains jumper index.
;	cmp	al, 0Fh				; If all 1's adapter is set for soft cfg,
;	je	ExitRecallConfig		; no recall is necessary.
;	mov	bx, 300h			; Pre-load BX with fixed config I/O base.
;	not	al				; Invert so 1 = jumper in place.
;	test	al, 0Ah				; If either config 1 or 3, IO is 280, else 300.
;	jz	DefaultFixedIO
;	mov	bx, 280h
;DefaultFixedIO:				; BX = IO base after recall.
;	add	dx, REG_HWR - REG_EER
;	mov	al, HWR_NUKE			; Setting NUKE bit is the same as
;	out	dx, al				; a power-up reset.
;	jmp	DelayedExit
;
;Recall584Config:
;	mov	dx, lm_pc_struc_ptr.io_base
;	add	dx, REG_IJR
;	in	al, dx
;	and	al, 07h
;	cmp	al, 07h
;	je	ExitRecallConfig		; If soft/soft, no recall is necessary.
;	test	al, 02h
;	jnz	CheckPin3
;	mov	bx, 280h
;	jmp	Recall584Config
;CheckPin3:
;	test	al, 04h
;	jnz	UseCurrentIOBase
;	mov	bx, 300h
;	jmp	Recall584Config
;	
;UseCurrentIOBase:
;	mov	bx, lm_pc_struc_ptr.io_base
;
;Recall584Config:
;	add	dx, REG_ICR - REG_IJR
;	mov	al, ICR_RX7
;	out	dx, al				; For 584, first recall all but I/O
;PollRX7:					; addr and LAN addr.
;	jmp	$+2
;	in	al, dx
;	test	al, ICR_RX7
;	jnz	PollRX7				; Poll until complete.
;
;	mov	al, ICR_RIO
;	out	dx, al				; Recall I/O addr
;	
;DelayedExit:					; Delayed exit ensures recall/reset
;	mov	dx, 21h				; is complete. Loop reading IRQ mask
;	mov	cx, 0FFFFh			; register.
;	in	al, dx
;	jmp	$+2
;	loop	DelayedExit
;	mov	lm_pc_struc_ptr.io_base, bx
;	call	LM_GetCnfg
;
;ExitRecallConfig:
;	pop	dx
;	pop	cx
;	pop	bx
;	ret
;RecallConfig	endp


