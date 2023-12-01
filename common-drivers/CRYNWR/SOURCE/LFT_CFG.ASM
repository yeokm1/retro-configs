;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
;	(c) COPYRIGHT 1995 Standard Microsystems Corporation,
;	ALL RIGHTS RESERVED.
;
; File:         lft_cfg.asm
;
; Description:  9232 LMAC function - LM_GetCnfg for 574(EFI- EISA FEAST interface)
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lft_cfg.avm  $
;
;   Rev 1.4   10 Feb 1995 11:45:10   WATANABE
;1. Fixed loopback test in lft_ext.asm.  Software appended CRC bit is not set
;   properly in the control byte of the packet data area.
;   
;2. Added copyright banner to all files.   
;
;   
;
;   Rev 1.3   02 Feb 1995 10:19:00   WATANABE
;1. Added code to save and restore node address in LM_Loopback_test for
;   EZStart, so when EZStart gets executed again without reboot, the 
;   node address will be correct.
;
;   
;
;   Rev 1.2   25 Jan 1995 17:52:28   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.1   11 Jan 1995 10:15:54   WATANABE
;1. Fixed a problem in TxIntr when restoring pointer register.  
;2. Enabled strip CRC bit in Receive Control Register.  Disable strip
;   CRC was a workaround for Rev. C and prior FEAST chip when there
;   were data corruption at the end of the frame.
;3. Added workaround for Rev. D FEAST chip.  For maximum Ethernet
;   frame size 1514 bytes, the TooLong bit in Receive Status word will
;   be set incorrectly.  LMAC will ignore that status.
;4. Fixed LM_Loopback_Test by adding delay after setting the transmit
;   control register.
;   
;
;   Rev 1.0   02 Dec 1994 19:03:16   WATANABE
;Initial Release.
;
;
;+!/? ***********************************************************************



;*-------------------------------------------------------------------*
;*        GetLANAddress: read the scec register and get the 6 byte   *
;*                  	ethernet address                             *
;*                                                                   *
;*     Input:  nothing                                               *
;*     output: fill in the adapter structure 6 byte physical 	     *
;*		ethernet address (msb first)			     *
;*     Assume: registers are preserved                               *
;*-------------------------------------------------------------------*
GetLANAddress  proc    near

	push	ax
	push	dx

	SelectBank 010h

;       read the one on the SCEC and copy it to the adapter structure
;       Setup to read the SCEC's node address.  

	mov     dx, pAS.IA0_1
	in      ax, dx
	mov	word ptr pAS.node_address+0, ax
	add     dx, 2
	in      ax, dx
	mov	word ptr pAS.node_address+2, ax
	add     dx, 2
	in      ax, dx
	mov	word ptr pAS.node_address+4, ax


	pop	dx
	pop	ax
	ret

GetLANAddress  endp


;---------------------------------
; LM Get Cnfg(for FEAST/EFI - 574)
;---------------------------------
; 
; 
; on entry :  ds:[bp] = pointer to adapter structure
;             slot_num field has to be initialized
;
; exit :      ax = completion code
;             dx = supplement code
;
;



ASM_FST_PROCDEF	LM_GetCnfg
; int 3
	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP

        ; find eisa io base
        mov     dl, pAS.slot_num
        mov     cl, 12
        shl     dx, cl
        add     dx, 0c80h
        mov     pAS.io_base, dx


        ; read manufacturing Id at IO address (0zc80 - 0zc83)
        in      al, dx                
        mov     ah, al
        inc     dx     
        in      al, dx
        cmp     ax, EISA_MANUF_ID                       ; encoded SMC ID
        je      lm_get_eisa_rev
        jmp     lm_gc_no_adptr

lm_get_eisa_rev:
        inc     dx                                      ; check board rev
        in      al, dx
        mov     ah, al
        inc     dx
        in      al, dx
        cmp     ax, EISA_BRD_9232                       ; use rev # as dummy id
        je      lm_chk_eisa_enb
        jmp     lm_gc_no_adptr
           
lm_chk_eisa_enb:              
        ; read EPROM/ENABLE FLASH at IO address (0zc84)
        inc     dx
        in      al, dx
        test    al, B574_EBC_ENB
        jne     lm_get_eisa_ram
        jmp     lm_gc_config_err


lm_get_eisa_ram:
        ; set ram size, since this is an I/O based card :
        ; ram_usable and ram_base field are not initialized
        ;
        mov     pAS.ram_size, CNFG_SIZE_128kb
        mov     word ptr pAS.ram_base, 0
        mov     word ptr pAS.ram_base+2, 0
        mov     pAS.ram_usable, 0


        ;
        ; get dma channel selection
        ;
        mov     dx, pAS.io_base
        add     dx, B574_DMA
        xor     ax, ax
        in      al, dx
        mov     bx, ax                          ; save reg. val. in bx
        and     ax, 07h                         ; get dma selection
        mov     pAS.dma_channel, ax
	;Initialize DMA IO address lookup tables

	push	rBX		;save EFI_DMA

	lea     rSI, pAS.base_addr_dat
	mov     byte ptr [rSI]+0  , DMA_BASE0
	mov     byte ptr [rSI]+1  , DMA_BASE1
	mov     byte ptr [rSI]+2  , DMA_BASE2
	mov     byte ptr [rSI]+3  , DMA_BASE3
	mov     byte ptr [rSI]+4  , DMA_DUMMY
	mov     byte ptr [rSI]+5  , DMA_BASE5
	mov     byte ptr [rSI]+6  , DMA_BASE6
	mov     byte ptr [rSI]+7  , DMA_BASE7
	
	add	rSI,rAX			;add DMA channel offset
	mov	bl,byte ptr [rSI]
	mov	pAS.DMA_base_addr_dat,bl	

	lea     rSI, pAS.base_addr_dat_L
	mov     byte ptr [rSI]+0  , DMA_LP0
	mov     byte ptr [rSI]+1  , DMA_LP1
	mov     byte ptr [rSI]+2  , DMA_LP2
	mov     byte ptr [rSI]+3  , DMA_LP3
	mov     byte ptr [rSI]+4  , DMA_DUMMY
	mov     byte ptr [rSI]+5  , DMA_LP5
	mov     byte ptr [rSI]+6  , DMA_LP6
	mov     byte ptr [rSI]+7  , DMA_LP7

	add	rSI,rAX			;add DMA channel offset
	mov	bl,byte ptr [rSI]
	mov	pAS.DMA_base_addr_dat_L,bl	

	lea     rSI, pAS.byte_count_dat
	mov     byte ptr [rSI]+0  , DMA_CNT0
	mov     byte ptr [rSI]+1  , DMA_CNT1
	mov     byte ptr [rSI]+2  , DMA_CNT2
	mov     byte ptr [rSI]+3  , DMA_CNT3
	mov     byte ptr [rSI]+4  , DMA_DUMMY
	mov     byte ptr [rSI]+5  , DMA_CNT5
	mov     byte ptr [rSI]+6  , DMA_CNT6
	mov     byte ptr [rSI]+7  , DMA_CNT7

	add	rSI,rAX			;add DMA channel offset
	mov	bl,byte ptr [rSI]
	mov	pAS.DMA_byte_count_dat,bl	

	pop	rBX		;restore EFI_DMA

        cmp     al, 4                           ; if disable
        jne     lm_gc_get_irq
        mov     pAS.dma_channel, 0ffh

lm_gc_get_irq:
        mov     ax, bx
        and     ax, 038h                                ; ax = index into IRQ table
        mov     cl, 3
        shr     ax, cl                                  ; irq sel at bit 0-2
        mov     bx, 5320h                               ; bx = IRQ table
        cmp     ax, 3
        jbe     lm_get_irq_val
        mov     bx, 0FBA7h
        sub     ax, 4

lm_get_irq_val:
        mov     cx, ax
        shl     cl, 1                                   ; *4
        shl     cl, 1
        shr     bx, cl
        and     bx, 0fh                                 ; bx = IRQ val
        mov     pAS.irq_value, bx


        ;
        ; get rom base, size
        ;
lm_gc_get_rom:
        inc     dx                                      ; EFI_ROM register
        xor     ax, ax
        in      al, dx
        mov     bx, ax                                  ; bx = reg. value

        and     al, 070h                                ; get bit 13 - 15
        mov     cl, 9
        shl     ax, cl
        mov     word ptr pAS.rom_base, ax

        and     bx, 080h                                ; get bit 16
        mov     cl, 7
        shr     bx, cl
        or      bx, 0ch
        mov     word ptr pAS.rom_base+2, bx

        dec     dx                                      ; EFI_DMA register
        in      al, dx
        test    al, B574_DMA_ROMEN                  ; see if ROM is enable        
        mov     pAS.rom_size, 0
        je      lm_gc_get_media

        mov     pAS.rom_size, CNFG_SIZE_64kb

	
lm_gc_get_media:

	mov     rCX, NumIOPorts
	lea     rSI, pAS.TCR
	mov	ax, pAS.io_base
	add	ax, 10h				;add offset from EISA BASE of
						;Feast IO space

LMGETPortLoop2:
	mov     word ptr [rSI]+0  , ax             ;Add in base I/O port bank1
	mov     word ptr [rSI]+16 , ax             ;Add in base I/O port bank2
	mov     word ptr [rSI]+32 , ax             ;Add in base I/O port bank3
	mov     word ptr [rSI]+48 , ax             ;Add in base I/O port bank4
	add     rSI, 2
	add     ax, 2
	loop    LMGETPortLoop2

        ;
        ; get media type at bank 1 reg 0
        ;
	SelectBank 010h

       mov     pAS.media_type, MEDIA_STP100_UTP100     ; 100 base X
	mov     dx, pAS.Configuration
       in      ax, dx                                  ; get FEAST config. reg.
;paul
;	and	ax, 07fffh		;set to 10baset for now
;	out	dx, ax

       test    ax, 08000h
       jnz     lm_gc_bk0                               ; if set, 100Mbps
       mov     pAS.media_type, MEDIA_UTP               ; default to 10Mbps UTP

       or      ax, 0400h                               ; req'd by board design
       out     dx, ax                                  ; set FULL-STEP bit to 1 for 10Mbps

lm_gc_bk0:     
        ;
        ; switch back to original bank
        ;
	SelectBank 0

        ;
        ; set adapter_bus = SLAVE mode
        ;     adapter_flags ...
        ;
        mov     pAS.adapter_bus, BUS_EISA32S_TYPE
        or      pAS.adapter_flags, IO_MAPPED
        cmp     pAS.dma_channel, 0ffh
        je      lm_gc_ok
        or      pAS.adapter_flags, USES_PHYSICAL_ADDR

lm_gc_ok:               

       ; 
       ; set board_id, board_id2, extra_info, extra_info2
       ;     media_menu(EZSTART).
       ; 
       ; Currently, hardcoded it.  
       ; In the future could change to reading from EEROM.
       ; 
       mov     pAS.board_id, 0C133h
       mov     pAS.board_id2, 01230h
       mov     pAS.extra_info, 08006h
       mov     pAS.extra_info2, 00h

       mov     pAS.media_menu, 06h     

        ;
        ; load name	
        ;
        mov     word ptr pAS.adapter_name,    '29'     ; 9232 reversed
        mov     word ptr pAS.adapter_name+2,  '23' 
        mov     word ptr pAS.adapter_name+4,  'SD'
        mov     word ptr pAS.adapter_name+6,  ' T'
        mov     word ptr pAS.adapter_name+8,  0
        mov     word ptr pAS.adapter_name+10, '$'


        ; set up board info
        mov     pAS.nic_type, NIC_C100_CHIP
        mov     pAS.bic_type, BIC_574_CHIP
        

IFDEF CODE_386
        xor     eax, eax                                ; zero it out first
ENDIF

        call    GetLANAddress
        mov     ax, ADAPTER_AND_CONFIG
        jmp     short lm_gc_eisa_exit

lm_gc_config_err:
IFDEF CODE_386
        xor     eax, eax                                ; zero it out first
ENDIF
        mov     ax, CONFIG_ERROR                        ; return code
        mov     dx, ADAPTER_NOT_FOUND                   ; supplement code
        jmp     short lm_gc_eisa_exit

lm_gc_no_adptr:
IFDEF CODE_386
        xor     eax, eax                                ; zero it out first
ENDIF
        mov     ax, ADAPTER_NOT_FOUND

lm_gc_eisa_exit:
	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
       ret
       

ASM_FST_PROCEND	LM_GetCnfg

