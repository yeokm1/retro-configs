; ETH_CFG.ASM
; This file contains everything needed to obtain configuration information
; from the 82M32 adapter.
; $Log:   G:\lmebm\vcs\eth_cfg.avm  $
;
;   Rev 1.3   06 Mar 1995 11:27:34   LOWE_G
;
;   Rev 1.2   20 Dec 1994 10:53:50   LOWE_G
;Fixed bug in LM_RAM_Test that would cause system lockups.
;
;   Rev 1.1   01 Dec 1994 10:53:38   LOWE_G
;
;   Rev 1.0   30 Nov 1994 10:52:04   LOWE_G
;Initial revision.

ifdef CODE_386
pAS     equ     <[ebp]>
pSI     equ     <[esi]>
pESI    equ     <[esi]>
pDI     equ     <[edi]>
pEDI    equ     <[edi]>
rDX     equ     <edx>
rAX     equ     <eax>
rBX     equ     <ebx>
else
pAS     equ     <ds:[bp]>
pSI     equ     <[si]>
pESI    equ     <es:[si]>
pDI     equ     <[di]>
pEDI    equ     <es:[di]>
rDX     equ     <dx>
rAX     equ     <ax>
rBX     equ     <bx>
endif

;
; Important! Before the EISA card is found, no 386 instructions can be used
;
IFNDEF ETHERNET
db              '@(#) LM_8232_s2.1_v1.39',0,'$'
ENDIF

ASM_EBM_PROC    LM_GetCnfg

		push	cx
		cmp     pAS.pc_bus, EISA_BUS
		je	short lm_gc_eisa_io
		jmp	lm_gc_no_adptr

; find eisa io base
lm_gc_eisa_io:
		mov     dl, pAS.slot_num
		mov	cl, 12
		shl     dx, cl
		add     dx, 0c80h
		mov     pAS.io_base, dx

; needs rewrite to differentiate adapters
		in      al, dx                
		mov     ah, al
		inc     dx
		in      al, dx
		cmp     ax, MANUF_ID                    ; smc encoded
		je	short lm_gc_eisa_rev
		jmp	lm_gc_no_adptr

lm_gc_eisa_rev:
		inc     dx                              ; check board rev
		in      al, dx
		mov     ah, al
		inc     dx
		in      al, dx
		mov     pAS.board_id, ax
		cmp     ax, EISA_BRD_ID                 ; dummy id
		jne     lm_gc_no_adptr

		inc     dx
		in      al, dx
		test    al, EISA_ENB
		je      lm_gc_config_err

; load name
		mov     dword ptr pAS.adapter_name, '3M28' ; 82M32 reversed
		mov     dword ptr pAS.adapter_name+4, '   2'
		mov	byte ptr pAS.adapter_name+5, 0

; get adapter irq
		push    eax
		push	ebx
		xor     eax, eax
		mov     dx, pAS.io_base
		add     dx, EISA_INT
		in      al, dx
		and     ax, EISA_IRQ_MASK               ; irq val
		mov     ebx, 0FBA75320h

		mov     cx, ax
		shl     cl, 2                           ; *4
		shr     ebx, cl

		and     bx, 0fh                          ; mask off int                
		mov     pAS.irq_value, bx

; get rom size
		xor     eax, eax
		in      al, dx
		and     ax, EISA_ROMEN
		mov     pAS.rom_size, 0
		je      lm_gc_rom_disabled

		mov     pAS.rom_size, 8

lm_gc_rom_disabled:
; get rom base
		add     dx, EISA_ROM - EISA_INT
		xor     eax, eax
		in      al, dx
		and     al, EISA_ROM_MASK
		shl     eax, 9
		or      eax, 000c0000h
		mov     pAS.rom_base, eax

; get ram base
		add     dx, EISA_RAM - EISA_ROM
		xor     eax, eax                        ; map to 
		in      al, dx
		and     al, EISA_RAM_MASK
		shl     eax, 11
		or      eax, 00080000h
		mov     pAS.ram_base, eax
		pop	ebx
		pop     eax

; get ram size
		mov     pAS.ram_size, 32

; get usable ram
; get adapter bus type 
		add     dx, EISA_INT - EISA_RAM
		in      al, dx
		test    al, EISA_MENB
;                mov     pAS.ram_usable, 0
;                mov     pAS.adapter_bus, BUS_EISA32M_TYPE
;                je      eisa_master_mode
		je      lm_gc_no_adptr

lm_gc_mem_ok:
		mov     pAS.ram_usable, 8                   ; 8K
		mov     pAS.page_offset_mask, 1fffh         ; 8Kb - 1
		mov     pAS.adapter_bus, BUS_EISA32S_TYPE
;                mov     pAS.adapter_flags, 0;
		mov     pAS.adapter_flags, USES_PHYSICAL_ADDR

eisa_master_mode:
; get media type
		add     dx, (EISA_790 + REG_HWR) - EISA_INT
		in      al, dx
		or      al, HWR_SWH
		out     dx, al

		add     dx, REG_GCR - REG_HWR
		in      al, dx
		and     ax, CNFG_MEDIA_TYPE_MASK
		cmp     al, 3
		jne     not_bnc
		mov     al, MEDIA_BNC_UTP
not_bnc:
		mov     pAS.media_type, ax

; set up board info
		mov     pAS.nic_type, NIC_790_CHIP
		mov     pAS.bic_type, BIC_571_CHIP
		mov     pAS.board_id, WD8216C
		mov     pAS.extra_info, RAM_SIZE_32K+INTERFACE_585_CHIP+NIC_790_BIT

		mov     rAX, ADAPTER_AND_CONFIG
		call	Check790
		jmp     short lm_gc_exit

lm_gc_config_err:
		mov     rAX, CONFIG_ERROR
		mov     rDX, ADAPTER_NOT_FOUND
		jmp     short lm_gc_exit

lm_gc_no_adptr:
		mov     rAX, ADAPTER_NOT_FOUND

lm_gc_exit:
		pop	cx
		ret

ASM_EBM_PROC_END        LM_GetCnfg

;****************************************************************************
;
; Function:	Check790
;
; Synopis:	Checks to see if the 790 got hosed and resets it if it is.
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


PUBLIC	Check790
Check790	proc	near
		push	ax
		push	ecx
		push	dx

		mov	dx, pAS.io_base
		add	dx, EISA_790 + REG_REV	; Read revision register
		in	al, dx
;		cmp	al, 0ffh		; This should never happen
;		jne	The790IsOK
		cmp	al, 21h
		je	The790IsOK
The790IsDead:
		add	dx, EISA_STAT - (EISA_790 + REG_REV)
		in	al, dx
		or	al, EISA_RNIC	; Tell 571 to reset the 790
		out	dx, al
IFDEF CODE_386
		mov	ecx, 0a000h
ELSE
		mov	cx, 0a000h
ENDIF
Check790DelayLoop:
		jmp	$+2
		in	al, dx
		loop	Check790DelayLoop	; Delay long time

		and	al, NOT EISA_RNIC	; DeAssert RNIC
		out	dx, al

		add	dx, (EISA_790+REG_EER)-EISA_STAT
PollOnRC:					; Wait for EEROM retrieval is complete
		in	al, dx
		test	al, EER_RC
		jnz	PollOnRC

IFDEF CODE_386
		mov	ecx, 0a000h
ELSE
		mov	cx, 0a000h
ENDIF
WaitForEEDelayLoop:				; Delay long time
		jmp	$+2
		loop	WaitForEEDelayLoop

; Reset EISA config defaults
; Very Important, otherwise you will see very strange behavior.
; Like tx_underruns, inconsistant AutoMediaDectect results,
; poor performance, etc.

		mov	dx, pAS.io_base		; Don't delete the next 2 in instructions
		in	al, dx			; I makes the 790 think it's on
		jmp	$+2			; a 16 bit host.
		inc	dx
		in	al, dx
		mov	dx, pAS.io_base
		add	dx, EISA_790+REG_BPR	; Force slave mode also.
		mov	al, BPR_M16EN+BPR_BMSTR	; NOTE: BusMaster bit was lost by 790.
		out	dx, al			; We can't be sure of anything so we just slave.

		add	dx, REG_HWR - REG_BPR	; page 1
		mov	al, HWR_SWH + HWR_ETHER	; HWR_ETHER shouldn't do anything
		out	dx, al			; but the EISA config file does it.
						; So I'll do it just to be consistant
		add	dx, REG_GCR - REG_HWR
		mov	al, GCR_IR2 + GCR_0WS + GCR_IR1 + GCR_IR0 + GCR_LITE
		out	dx, al

The790IsOK:
		pop	dx
		pop	ecx
		pop	ax
		ret
Check790	endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       load_node_address       Loads node address into adapter structure
;                               indicated by DS:BP
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_EBM_PROC            load_node_address
			push    ecx
			push    edi
			push    esi
			push    dx

			mov     dx, pAS.io_base
			add     dx, EISA_790+REG_HWR
			in      al, dx
			push    dx
			push    ax
			and     al, NOT HWR_SWH
			out     dx, al                  ; set lan registers

			mov     al, 0
			mov     ecx, 6
			add     ebp, 6
LoadNodeLoop:           dec     ebp
			or      al, pAS.node_address
			loop    LoadNodeLoop

			mov     ecx, 6
			mov     dx, pAS.io_base
			add     dx, REG_LAR0+EISA_790
			or      al, al
			jz      GetNodeAddFromBIC

			mov     dx, pAS.io_base
			add     dx, REG_CMD+EISA_790
			mov     al, CMD_STP+CMD_RD2+CMD_PAGE1
			out     dx, al
			add     dx, REG_PAR0 - REG_CMD                                         
			mov     esi, ebp
			add     esi, node_address
NodeAddrToNIC:
			lodsb
			out     dx, al
			inc     dx
			loop    NodeAddrToNIC

			add     dx, REG_CMD - (REG_PAR0 + 6)
			mov     al, CMD_STP+CMD_RD2+CMD_PAGE0
			out     dx, al
			jmp     NodeAddDone

GetNodeAddFromBIC:
			add     dx, REG_EER - REG_LAR0  ; recall address
			mov     al, EER_RC + 06h
			out     dx, al

wait_for_recall:
			in      al, dx
			test    al, EER_RC
			jne     wait_for_recall

			add     dx, REG_LAR0 - REG_EER

			mov     edi, ebp
			add     edi, node_address

ifndef CODE_386
			push    es
			push    ds
			pop     es
endif

GetNodeAddFromBIC1:
			in      al, dx
			stosb
			inc     dx 
			loop    GetNodeAddFromBIC1

ifndef CODE_386
			pop     es
endif

NodeAddDone:
			pop     ax
			pop     dx
			out     dx, al                  ; restore hwr reg

			pop     dx
			pop     esi
			pop     edi
			pop     ecx
			mov     rAX, SUCCESS
			ret

ASM_EBM_PROC_END        load_node_address
