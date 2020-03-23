;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       ETH_EISA.ASM    (C) Copyright 1992 Standard Microsystems Corp.
;                       All rights reserved.
;
;       LMI lower routine assembly source file for 
;       Ethernet EISA adapter.
;
;       Author: najay
;
; Revision Log:
; $Log:   G:\sweng\src\lmebm\vcs\eth_eisa.avm  $
;
;   Rev 1.47   06 Mar 1995 13:30:00   CHAN_M
;
;   Rev 1.46   06 Mar 1995 11:25:56   LOWE_G
;Cleared EARLY_RX_COPY if bx <> 0 in LM_Receive_Copy.
;
;   Rev 1.45   20 Dec 1994 10:57:34   LOWE_G
;Fixed bug in LM_RAM_Test that would cause system lockups.
;
;   Rev 1.44   01 Dec 1994 10:53:02   LOWE_G
;
;   Rev 1.43   30 Nov 1994 10:58:30   LOWE_G
;Broke out LM_GetCnfg, Check790 and load_node_address into a seperate
;file. (ETH_CFG.ASM)
;
;   Rev 1.42   10 Nov 1994 14:21:06   LOWE_G
;
;   Rev 1.41   01 Nov 1994 09:12:52   LOWE_G
;Fixed problem with handling of broadcast frames during early receive.
;
;   Rev 1.40   12 Oct 1994 14:25:24   LOWE_G
;
;   Rev 1.39   12 Oct 1994 10:59:10   LOWE_G
;Fixed bug in receive logic that would cause LM_Receive_Copy to
;write past the end of the buffer when receiving a frame with a
;bad CRC.
;
;   Rev 1.38   26 Sep 1994 14:01:28   LOWE_G
;Added Dell Omniplex and Compaq Deskpro XL motherboard IDs
;
; 08-17-94 M Chan Added 5 mother boards to the list
; 06-27-94 M Chan Fixed a bug in init_nic where the SWH bit in the HWR
;                 register wasn't explicitly set before the RAR register was
;                 programmed to 0. This problem was discovered
;                 by the boot rom. This has never caused any problems in
;                 regular drivers because LM_GetCnfg sets SWH and we always
;                 call LM_GetCnfg before calling init_nic. In the boot rom
;                 the SWH bit was changed between LM_GetCnfg and
;                 LM_Initialize_Adapter.
; 05-24-94 M Chan Changed getver string.
; 05-12-94 M Chan Fixed a boundary condition bug during slave copy
;                 in routine receive_copy
; 04-14-94 M Chan Increased duration of DMA test to 1000 loops and added
;                 check for the 2 bytes of memory before the start
;                 of DMA to make sure they are not overwritten by DMA.
; 03-25-94 najay  Fixed bug in LM_Service_Events that allowed a push without
;                 a pop at GoodFrame
; 03-18-94 M Chan Fixed bug in LM_Ram_Test that caused machines to hang
;                 if they do not pass DMA test.
; 03-15-94 M Chan changed physical addr scratch pad ptr to eax for CODE_386
; 03-14-94 najay  changed lm_initialize_adapter to use dx:ax as the
;                 physical addr pointer instead of esi
;                 Updated the LM_Receive_Copy to spin on rx_stat if 
;                 bx = 1
;
; 03-10-94 M Chan Fixed promiscuous mode problem by passing error status
;                 to UM_Receive_Packet.
;                 Added optimized early receive for slave mode.
;                 Added 790 loop back during DMA test and increased the
;                 number of DMA test loops to 100.
;                 Deleted 32-bit and 386 instructions in LM_GetCnfg before
;                 card is found.
; 02-28-94 M Chan Use the FS segment to get host address for DMA for
;                 non-CODE_386 environments.
; 02-18-94 M Chan Added mother board ID check to detect Intel mother board
;                 and fall back to slave mode
; 02-14-94 M Chan Software workaround is now implemented in UMAC known as
;                 Wayne's Fix. LMAC workaround has been eliminated by
;                 not defining ONE_K
;
;                 Also added adaptive early tx and more checking to combat
;                 FIFO underrun.
;
; 02-09-94 M Chan Added a software fix for an EBM hardware problem:
;                       - If the transmit buffer crosses a IK boundary in host
;                       address then
;                               - If starting address is between 16 bytes
;                               and 8 bytes before 1K then do nothing
;                               - If starting address is more than 16 bytes
;                               before 1K, stop DMA 10 bytes before 1K and
;                               start again at 9 bytes before 1K
;                               - UMAC will not transmit by DMA buffers
;                               that start 8 bytes or less before 1K
;                 Added some logic to turn off early tx underrun detection
;                 when not necessary to avoid tx abort
;
; 02-01-94 M Chan Added the following bug fixes:
;                       - Update page after DMA in case the next fragment is
;                       to be copied by string move
;                       - Wrap the ring or page if we reach exactly the end
;                       of ring or page
;                       - push 32-bit registers in ISR for DOS environment
;                       - fixed bug in early receive to take care of error
;                       frames
; 01-04-94 M Chan Added check for end of page after ring wrap
;                 Improved early receive logic
;                    - schedule early receive 3/4 into the packet (7/8 for
;                      386 server)
;                    - poll if less than 128 bytes to receive (64 bytes for
;                      386 server)
;                 Added check for small size dma after ring wrap
;                 Changed early tx threshold back to default
;
; 12-14-93 M Chan Fixed ezstart two node test bug in UpdateCollisionTable
;                 Removed public for procedures declared by the ezstart macro
;                 Clears recv int. AFTER the last check for ring empty
;
; 12-09-93 M Chan Increased the possible number of transmit buffers
;                 Added checking in ISR to not process ERW when not enabled
;
; 11-04-93 M Chan Scratchpad ptr is passed in esi to lm_initialize_adapter
;                 for all operating environments.
;
; 11-02-93 M Chan Changed early tx threshold to 256 to reduce excessive
;                 FIFO underrun.
;
; 10-22-93 M Chan Fixed the enabling and clearing of dma interrupts
;                 Check fragment size before doing early transmit
;                 Fixed the handling of dma complete interrupt
;
; 10-21-93 M Chan Fixed the 32 byte dma threshold bug
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;include        ETH_EISA.INC
;include        bicnic.inc
;include        LMSTRUCT.INC
;include        GETCNFG.INC


db              '@(#) LM_8232_s2.1_v1.39',0,'$'

ifdef   COUNTER16
errptr  equ     <word ptr>
errAX   equ     <ax>
else
errptr  equ     <dword ptr>
errAX   equ     <eax>
endif

DEBUG_ADDR      equ     0ec99h

MotherBoardID	dd	0f130d425h
		dd	00911a310h
		dd	005002335h	; Micronics Pentium EISA/PCI
		dd	004002335h	; Micronics 486 EISA/PCI
		dd	0c1aac94dh	; Siemens
		dd	00170335fh	; Wyse 7000i
		dd	04200ac10h	; Dell PowerEdge SP/466
		dd	081c0f022h	; HP Netserver LC
		dd	071c0f022h	; HP Netserver LF
		dd	01915110eh	; Compaq ProLiant
		dd	04800ac10h	; Dell Omniplex
		dd	02105110eh	; Compaq Deskpro XL
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
		dd	0h
MotherBoardTableSize	equ	$ - MotherBoardID


public Debug_call
Debug_call      proc    far
		push    dx
		push    ax
		mov     dx, DEBUG_ADDR
		in      al, dx
		pop     ax
		pop     dx
		int 3
		iret
Debug_call      endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Enable_Adapter      Enables adapter whose adapter structure is
;                               indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Enable_Adapter

		push    dx
		mov     dx, pAS.io_base
		add     dx, EISA_STAT

		in      al, dx
		or      al, EISA_EIL
		out     dx, al

		mov     rAX, SUCCESS
		and     pAS.adapter_flags, not ADAPTER_DISABLED
		pop     dx
		ret

ASM_EBM_PROC_END        LM_Enable_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Disable_Adapter      Disables adapter whose adapter structure is
;                               indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Disable_Adapter

		push    dx
		mov     dx, pAS.io_base
		add     dx, EISA_STAT

		in      al, dx
		and     al, NOT EISA_EIL
		out     dx, al

		mov     rAX, SUCCESS
		or      pAS.adapter_flags, ADAPTER_DISABLED
		pop     dx
		ret

ASM_EBM_PROC_END        LM_Disable_Adapter


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Initialize_Adapter   Initializes the adapter whose structure is 
;                               indicated by DS:BP
;
;       on call es:si (esi) points to a 200 byte scratchpad memory, or NULL
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Initialize_Adapter

; pma 02 9/3/93 debug break point
;               int     3

IFDEF CODE_386
		push    ecx
		push    bx
		push    dx
ELSE
		push    ebx
		push    ecx
		push    edx
		push    esi
		push    edi
		push    eax
ENDIF
IFDEF CODE_386
		mov	esi, eax
ELSE
		movzx   esi, dx                 ; najay 3/14/94
		shl     esi, 16
		mov     si, ax
ENDIF

		call    reset_nic
IFDEF   EZSTART
		call    FAR PTR EBM_load_node_address
ELSE
IFDEF   LARGE
		call    FAR PTR load_node_address
ELSE
		call    load_node_address
ENDIF
ENDIF

		cmp     pAS.num_of_tx_buffs, 0
		je      BadTxValue

;		cmp     pAS.num_of_tx_buffs, 15
		cmp	pAS.num_of_tx_buffs, 3	; LMSTRUCT.INC only has room for 3!
		jbe     TxbuffsOk
BadTxValue:
		mov     pAS.num_of_tx_buffs, 2

TxbuffsOk:      movzx   ecx, pAS.num_of_tx_buffs
		xor     ax, ax
		mov     bx, pAS.max_packet_size
		add     bx, 0ffh
		xor     bl, bl
		push    edi

		lea     edi, pAS.tx_buffer

AddTXBufSize:
		mov     word ptr [edi], ax
		add     ax, bx

		push    bx
		cmp     ecx, 1  ; no need to bump to next page in last loop
		je      same_page
		mov     dx, ax  ; enough room for another in this page ?
		and     dx, pAS.page_offset_mask
		mov     bx, pAS.page_offset_mask
		add     bx, 1
		sub     bx, dx
		cmp     bx, pAS.max_packet_size
		jae     same_page
		add     ax, bx
same_page:
		pop     bx
		add     edi, 4
		loop    AddTXBufSize

		pop     edi
		mov     pAS.tx_pstop, ah
		mov     pAS.tx_head, 0
		mov     pAS.tx_tail, 0
		mov     pAS.tx_count, 0
		mov     pAS.tx_retry, DEFAULT_TX_RETRIES
		mov     pAS.xmit_threshold, DEFAULT_ETX_VALUE
;                mov     pAS.xmit_threshold, 128
;                mov     pAS.xmit_threshold, 02FFFh
		mov     ax, pAS.ram_size
		shr     ax, 3
		dec     al
		mov     pAS.max_page_num, al

ifndef CODE_386
		push    es
		push    ds
		pop     es
endif
		push    edi
		lea     edi, pAS.bc_add
		mov     ax, 0FFFFh
		stosw
		stosw
		stosw
		mov     al, 01
		stosb
		pop     edi
ifndef CODE_386
		pop     es
endif
		call    init_nic
IFDEF LARGE
IFDEF EZSTART
		call    FAR PTR EBM_LM_Ram_Test
ELSE
		call    FAR PTR LM_Ram_Test
ENDIF
ELSE
		call    LM_Ram_Test
ENDIF

		cmp     rAX, SUCCESS
		je      LM_Init_RAM_OK
		mov     pAS.adapter_status, FAILED
		jmp     LM_Init_Return

LM_Init_RAM_OK:
IFDEF EZSTART
		call	EBM_AutoMediaDetect
ELSE
		call	AutoMediaDetect
ENDIF
		call	reset_nic
		call	init_nic
;               call    SetLookAheadMode
		call    InitErrorCounters
		mov     pAS.adapter_status, INITIALIZED
IFDEF EZSTART
		call    EBM_LM_Enable_Adapter
ELSE
		call    LM_Enable_Adapter
ENDIF

LM_Init_Return:
		push    ax
		call    UM_Status_Change
		pop     ax
IFDEF CODE_386
		pop     dx
		pop     bx
		pop     ecx
ELSE
		mov     bx, ax
		pop     eax
		mov     ax, bx
		pop     edi
		pop     esi
		pop     edx
		pop     ecx
		pop     ebx
ENDIF
		ret

ASM_EBM_PROC_END        LM_Initialize_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       init_nic        Initializes NIC on adapter whose adapter
;                       structure is indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_nic        proc    near
		push    ecx
		push    dx

		mov     dx, pAS.io_base     ; DX = io_base
		add     dx, EISA_790+REG_CMD
		mov     al, CMD_STP+CMD_RD2
		out     dx, al

		add     dx, REG_ISR - REG_CMD
		mov     ecx, 1600               ; Each iteration of the following
init_nic_wait:                                  ; loop is 1.0 uS minimum. We
		in      al, dx                  ; need 1.6 mS delay, so set up
		in      al, dx                  ; a loop count of 1600.
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		test    al, ISR_RST
		jnz     init_NIC_Reset
		loop    init_nic_wait

init_NIC_Reset:
		mov     al, DCR_FT1+DCR_LS+DCR_WTS ; FIFO threshhold = 8 bytes
						; Set Normal Oper.
						; Set word transfer select bit
		add     dx, REG_DCR - REG_ISR   ; Get io_base + DCR into DX
		out     dx, al                  ; Write DCR

IFDEF LARGE
IFDEF EZSTART
		call    FAR PTR EBM_LM_Change_Receive_Mask
ELSE
		call    FAR PTR LM_Change_Receive_Mask
ENDIF
ELSE
		call    LM_Change_Receive_Mask
ENDIF
		add     dx, REG_TCR - REG_DCR
		mov     al, TCR_LB1
		out     dx, al
		
		add     dx, REG_PSTART - REG_TCR
		mov     al, pAS.tx_pstop
		mov     pAS.pstart_hold, al
		out     dx, al
		
		mov     ax, pAS.ram_size
		shl     al, 2                      ; Multiply by 4 to get pstop_hold
		mov     pAS.pstop_hold, al
		add     dx, REG_PSTOP - REG_PSTART
		out     dx, al

		add     dx, REG_BNRY - REG_PSTOP   ; Boundary = pstart_hold
		mov     al, pAS.pstart_hold
		out     dx, al

		add     dx, REG_ISR - REG_BNRY     ; Set ISR
		mov     al, 0ffh
		out     dx, al
		
		add     dx, REG_IMR - REG_ISR   ; Set IMR
		mov     al, IMR_PRXE+IMR_PTXE+IMR_RXEE+IMR_TXEE+IMR_OVWE
		test    pAS.receive_mask, EARLY_RX_ENABLE
		jz      init_NoERXE
		or      al, IMR_ERWE
init_NoERXE:
		mov     pAS.imr_hold, al
		out     dx, al

		add     dx, REG_CMD - REG_IMR   ; Select Page 1
		mov     al, CMD_STP+CMD_RD2+CMD_PAGE1
		out     dx, al
		
		push    esi
		mov     esi, ebp                ; Load Physical Address regs
		add     esi, node_address
		mov     ecx, 6
		add     dx, REG_PAR0 - REG_CMD

init_lan_addr:  lodsb                           ; get byte
		out     dx, al                                          
		inc     dx
		loop    init_lan_addr

		pop     esi

		mov     al, pAS.pstart_hold
		inc     al
		mov     pAS.local_nxtpkt_ptr, al

		add     dx, REG_CURR - (REG_PAR0 + 6) ; Point to CURR reg.
		out     dx, al                  ; AL = local_nxtpkt_ptr

		add	dx, REG_HWR-REG_CURR
		in	al, dx
		or	al, HWR_SWH
		out	dx, al

		add     dx, REG_RAR - REG_HWR
		xor     al, al
		out     dx, al

		mov     pAS.tx_pend, 0
		mov     pAS.rx_pend, 0

;		add     dx, REG_HWR-REG_RAR
;		in      al, dx
;		or      al, HWR_SWH
;		out     dx, al                  ; set config registers

		add     dx, REG_GCR - REG_RAR
		in      al, dx
		or      al, GCR_IR2+GCR_IR1+GCR_IR0
		out     dx, al                  ; set card for IRQ 7

		add     dx, REG_BPR - REG_GCR   ; 16bit mem access
		in      al, dx
		or      al, BPR_M16EN
		out     dx, al

		add     dx, REG_INTCR - REG_BPR ; enable 790 interrupts
		mov     al, INTCR_EIL
		out     dx, al

		add     dx, REG_CMD - REG_INTCR   ; Select Page 0
		mov     al, CMD_STP+CMD_RD2
		out     dx, al
		
		add     dx, REG_MSR - REG_CMD     ; enable 790 memory
		mov     al, MSR_MENB
		out     dx, al

		add     dx, REG_ERWCNT - REG_MSR
;               cmp     pAS.rx_lookahead_size, DEFAULT_ERX_VALUE
;               jae     ErxThresholdOk
;               mov     pAS.rx_lookahead_size, DEFAULT_ERX_VALUE

ErxThresholdOk:
		mov     al, DEFAULT_ERX_VALUE
		out     dx, al                          ; 

		pop     dx
		pop     ecx
		mov     rAX, SUCCESS
		ret                     ; Return to caller

init_nic        endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       reset_nic       Resets the NIC on the adapter whose adapter structure
;                       is indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
reset_nic       proc    near
		push    bx
		push    dx

		mov     dx, pAS.io_base
		add     dx, REG_MSR+EISA_790

		mov     al, MSR_RST                 ; Set reset bit
		out     dx, al
						; Each iteration of the following
						; loop is 1.0 uS minimum. We
		in      al, dx                  ; need 1.6 mS delay, so set up
		in      al, dx                  ; a loop count of 1600.
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx
		in      al, dx

		xor     al, al
		out     dx, al                  ; Reset reset bit

		pop     dx
		pop     bx
		mov     rAX, SUCCESS
		ret
reset_nic       endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       InitErrorCounters       Initializes error counters to point to
;                               ds:[bp].dummy_vector if they are not
;                               initialized by UMAC.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

InitErrorCounters       proc    near
		push    ax
		push    ebx
		push    ecx
		push    esi

		mov     ecx, (ptr_ring_OVW - ptr_rx_CRC_errors) / 4 + 1
		lea     esi, pAS.ptr_rx_CRC_errors      ; Get address of first counter
		lea     ebx, pAS.dummy_vector           ; BX = offset of dummy vector.
							; DS:SI = offset of first counter.
ifndef CODE_386
		ror     ebx, 16
		mov     bx, ds
		ror     ebx, 16
endif

CheckVectors:
		cmp     dword ptr pSI, 0
		jnz     SkipThisVector                  ; If null, fill with dummy vector.
		mov     pSI, ebx

SkipThisVector:
		add     esi, 4
		loop    CheckVectors

		pop     esi
		pop     ecx
		pop     ebx
		pop     ax

		ret
InitErrorCounters       endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Set_Funct_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Set_Funct_Address

		mov     rAX, INVALID_FUNCTION
		ret
ASM_EBM_PROC_END        LM_Set_Funct_Address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Delete_Group_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Delete_Group_Address

		mov     rAX, INVALID_FUNCTION
		ret
ASM_EBM_PROC_END        LM_Delete_Group_Address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Set_Group_Address returns INVALID_FUNCTION for Ethernet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Set_Group_Address

		mov     rAX, INVALID_FUNCTION
		ret
ASM_EBM_PROC_END        LM_Set_Group_Address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Change_Receive_Mask
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Change_Receive_Mask

		push    bx
		push    dx
		cmp     pAS.adapter_status, NOT_INITIALIZED
		jne     LM_Ch_Stat_ok
		mov     rAX, ADAPTER_NOT_INITIALIZED
		jmp     LM_Ch_Msk_Done
LM_Ch_Stat_ok:
		mov     dx, pAS.io_base
		add     dx, REG_CMD+EISA_790
		mov     al, CMD_RD2+CMD_PAGE0
		out     dx, al          ; Select page 0
		add     dx, REG_RCR - REG_CMD
		mov     al, 0

		test    pAS.receive_mask, TRANSMIT_ONLY ; Frank H. 09-28-92
		jz      SetRecMask00                            ; Frank H. 09-28-92
		or      al, RCR_MON                             ; Frank H. 09-28-92

SetRecMask00:   test    pAS.receive_mask, ACCEPT_MULTICAST
		jz      SetRecMask01
		or      al, RCR_AM

SetRecMask01:   test    pAS.receive_mask, ACCEPT_BROADCAST
		jz      SetRecMask02
		or      al, RCR_AB

SetRecMask02:   test    pAS.receive_mask, PROMISCUOUS_MODE
		jz      SetRecMask03
		or      al, RCR_PRO+RCR_AM+RCR_AB

SetRecMask03:   test    pAS.receive_mask, ACCEPT_ERR_PACKETS+EARLY_RX_ENABLE
		jz      SetRecMask13
		or      al, RCR_AR+RCR_SEP

SetRecMask13:   test    pAS.receive_mask, ACCEPT_MULTI_PROM
		jz      SetRecMask04
		or      al, RCR_AM+RCR_AB

SetRecMask04:   mov     bl, 0                   ; Set initial MAR value to 0
		test    al, RCR_AM
		jz      SetRecMask05
		mov     bl, 0ffh
IFDEF EZSTART
SetRecMask05:   call    FAR PTR EBM_set_MARs
ELSE
 IFDEF LARGE
SetRecMask05:   call    FAR PTR set_MARs
 ELSE
SetRecMask05:   call    set_MARs
 ENDIF
ENDIF

		mov     pAS.rcr_hold, al ; Save result as rcr_hold
		out     dx, al                  ; Write REG_RCR

		or      pAS.adapter_flags, ERX_DISABLED
		mov     al, IMR_PRXE+IMR_PTXE+IMR_RXEE+IMR_TXEE+IMR_OVWE
		test    pAS.receive_mask, EARLY_RX_ENABLE
		jz      NoERXE
		or      al, IMR_ERWE
		and     pAS.adapter_flags, not ERX_DISABLED
NoERXE:
		mov     pAS.imr_hold, al

		mov     rAX, SUCCESS
LM_Ch_Msk_Done:
		pop     dx
		pop     bx
		ret

ASM_EBM_PROC_END        LM_Change_Receive_Mask

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       set_MARs        Sets all 8 NIC Multicast Address Registers (REG_MAR0-7)
;                       to value in BL. All regs preserved, no return code.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_EBM_PROC    set_MARs
		push    ecx
		push    ax
		push    dx

		mov     dx, pAS.io_base
		add     dx, REG_CMD+EISA_790
		in      al, dx

		and     al, CMD_PS0+CMD_PS1
		mov     bh, al                  ; Save original page in BH
		mov     al, CMD_RD2+CMD_PAGE1             ; Select page 1
		out     dx, al

		add     dx, REG_MAR0 - REG_CMD
		mov     ecx, 8
		mov     al, bl                  ; Get value to write into AL

SetMARLoop:
		out     dx, al                  ; Write 8 bytes to MAR0-7
		inc     dx
		loop    SetMARLoop

		mov     dx, pAS.io_base
		add     dx, REG_CMD+EISA_790  ; Restore original page.
		mov     al, bh
		out     dx, al

		pop     dx
		pop     ax
		pop     ecx
		ret

ASM_EBM_PROC_END        set_MARs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Send         ES:SI   ptr to data buffer structure
;                       DS:BP   ptr to adapter structure
;                       DX:DI  (edx) transmit handle
;                       CX      Transmit byte count
;       
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Send

IFDEF CODE_386
		push    edi
		push    edx
ELSE
		push    ebx
		push    ecx
		push    edx
		push    esi
		push    edi
		push    eax
ENDIF

		mov     al, pAS.tx_count
		cmp     al, byte ptr pAS.num_of_tx_buffs
		mov     rAX, OUT_OF_RESOURCES
		je      LM_Send_done

		cmp     cx, pAS.max_packet_size
		ja      LM_Send_done

		cmp     pAS.early_tx_pend, 1
		jne     LM_Send_skip_etx

		mov     pAS.early_tx_pend, 0
		mov     dx, pAS.io_base          ; turn off early tx checking
		add     dx, EISA_790+REG_CMD
		mov     al, CMD_DISETCH
		out     dx, al            

LM_Send_skip_etx:
		push    esi
		xor     eax, eax
		mov     al, pAS.tx_tail
		push    eax
		inc     al
		cmp     al, byte ptr pAS.num_of_tx_buffs
		jne     tx_tail_ok
		xor     al, al
tx_tail_ok:
		mov     pAS.tx_tail, al
		inc     pAS.tx_count
		pop     esi

; point ax to correct buffer offset in adapterstructure
		shl     esi, 2
		mov     word ptr pAS.pSI.tx_buffer+2, cx
		movzx   edi, word ptr pAS.pSI.tx_buffer
		pop     esi
		mov     ax, di
		shr     ax, 5           ; set up page bits

		
		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		push    dx
		push    ax                              ; save page
		and     al, NOT EISA_RAM_PAGE_MASK
		or      al, ah                          ; set up correct page
		mov     pAS.curr_page_num, ah
		out     dx, al
		and     di, pAS.page_offset_mask        ; offset only

; disable adapter interrupts
		add     dx, EISA_STAT-EISA_RAM

		in      al, dx
		and     al, NOT EISA_EIL
		out     dx, al

IFDEF EZSTART
		call    FAR PTR EBM_buff_struct_to_ram
ELSE
 IFDEF LARGE
		call    FAR PTR buff_struct_to_ram
 ELSE
		call    buff_struct_to_ram
 ENDIF
ENDIF

		cmp     pAS.early_tx_pend, 2   ; early_tx_pending flag
		jnz     no_tx_needed

		mov     pAS.early_tx_pend, 1
		mov     dx, pAS.io_base
		add     dx, EISA_STAT
wait_before_tx:
		in      al, dx
		test    al, EISA_SDMA
		jnz     wait_before_tx
IFDEF EZSTART
		call    FAR PTR EBM_SendPacket
ELSE
 IFDEF LARGE
		call    FAR PTR SendPacket
 ELSE
		call    SendPacket
 ENDIF
ENDIF

no_tx_needed:
		pop     ax
		pop     dx
		out     dx, al                          ; restore page

; enable adapter interrupts
		test    pAS.adapter_flags, ADAPTER_DISABLED
		jne     no_tx_int_en

		add     dx, EISA_STAT-EISA_RAM

		in      al, dx
		or      al, EISA_EIL
		out     dx, al

no_tx_int_en:
		cmp     pAS.tx_pend, 1                  ; check for tx pending
		jne     LM_Send_success


; check for dma finish
		mov     dx, pAS.io_base
		add     dx, EISA_STAT
		in      al, dx
		test    al, EISA_SDMA
		jz      LM_Send_success

		test    pAS.adapter_flags, ENABLE_TX_PENDING                
		je      tx_dma_done

		and     al, not EISA_DIEN
		out     dx, al                          ; enable tx dma int
		mov     rAX, PENDING
		jmp     short LM_Send_done

tx_dma_done:
		in      al, dx
		test    al, EISA_SDMA
		jne     tx_dma_done

LM_Send_success:
		mov     pAS.tx_pend, 0
		mov     rAX, SUCCESS

		cmp     pAS.early_tx_pend, 1
		jne     LM_Send_done

		push    ax
		mov     pAS.early_tx_pend, 0
		mov     dx, pAS.io_base          ; turn off early tx checking
		add     dx, EISA_790+REG_CMD
		mov     al, CMD_DISETCH
		out     dx, al            
		pop     ax

LM_Send_done:
IFDEF CODE_386
		pop     edx
		pop     edi
ELSE
		mov     bx, ax
		pop     eax
		mov     ax, bx
		pop     edi
		pop     esi
		pop     edx
		pop     ecx
		pop     ebx
ENDIF
		ret

ASM_EBM_PROC_END        LM_Send

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;               buff_struct_to_ram
;
;               AX     offset in physical shared RAM address
;               ES:SI  Pointer to buffer structure
;               ds:bp  adapterstructure
;
;               dx is destroyed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    buff_struct_to_ram

ifndef CODE_386
		push    es
ifndef NW_286
		push    fs
endif
endif
		push    esi
		push    edi
		push    ecx
		push    ebx

		and     ecx, 0ffffh

		cmp     pAS.tx_count, 1
		jne     GetFragCount            ; Do not do Early Tx if other buffers are
						; allocated.
		mov     dx, pAS.io_base
		add     dx, EISA_790+REG_CMD
		in      al, dx
		test    al, CMD_TXP
		jnz     GetFragCount


		push    esi
		xor     rAX, rAX
IFDEF CODE_386
		mov     edx, [esi].fragment_count
ELSE
		mov     dx, es:[si].fragment_count
ENDIF
		add     esi, fragment_list
AddFragmentLoop:
IFDEF CODE_386
		add     eax, [esi].fragment_length
ELSE
		add     ax, es:[si].fragment_length
ENDIF
		and     rAX, NOT PHYSICAL_ADDR
		dec     rDX
		jz      CheckFragSum
		add     esi, size FragmentStructure
		jmp     AddFragmentLoop

CheckFragSum:
		pop     esi
		cmp     ax, cx
		jae     DoEarlyTx
		mov     pAS.early_tx_threshold, 2fffh
		mov     pAS.early_tx_pend, 2
		mov     dx, pAS.io_base
		add     dx, EISA_790+REG_CMD
		mov     al, CMD_DISETCH
		out     dx, al
		jmp     GetFragCount

DoEarlyTx:
		mov     dx, pAS.io_base
		add     dx, EISA_790+REG_CMD
		mov     al, CMD_ENETCH          ; Enable early xmit check so that
		out     dx, al                  ; the addresses of the writes to memory
						; that follow will get latched in the chip.

		mov     rAX, pAS.xmit_threshold
		mov     pAS.early_tx_threshold, ax
		mov     pAS.early_tx_pend, 2

GetFragCount:                                           ; threshold.
ifdef CODE_386
		mov     eax, pAS.ram_access
		add     edi, eax
		mov     rDX, [esi].fragment_count
		lea     ebx, [esi].fragment_list
else
		mov     ax, word ptr pAS.ram_access+2
		push    es
		pop     fs              ; DS:SI ptr to data buffer structure
		mov     es, ax          ; ES:DI ptr to shared ram
		mov     rDX, fs:[si].fragment_count
		lea     ebx, fs:[si].fragment_list
endif

		cld                             ;make sure we increment

fragment_loop:
ifdef CODE_386
		mov     ecx, [ebx].fragment_length
		test    ecx, PHYSICAL_ADDR
else
		push    ds
		mov     cx, fs:[ebx].fragment_length
		test    cx, PHYSICAL_ADDR
endif
		jnz     send_dma_fragment

		jecxz   check_for_more_frags

		cmp     pAS.early_tx_pend, 2   ; early_tx_pending flag
		jne     early_tx_count_ok

		sub     pAS.early_tx_threshold, cx
		jnc     early_tx_count_ok

		add     cx, pAS.early_tx_threshold                

early_tx_count_ok:
ifdef CODE_386
		mov     esi, [ebx].fragment_ptr
else
		xor     esi, esi
		lds     si, fs:[ebx].fragment_ptr
endif

early_tx_count_ok1:
		cmp     ecx, 3
		jbe     buff_move_small

		test	di, 3
		jz	tx_dword
		
		test    di, 1                   ; for maximum throughput
		jz      tx_word                 ; 
		dec     ecx                     ; 
		movsb                           ; 

tx_word:
		test    di, 2                   ; for maximum throughput
		jz      tx_dword                ; 
		sub     ecx, 2                  ; 
		movsw                           ; 

tx_dword:
		push    ecx
		shr     ecx, 2
		jecxz   buff_no_dword_move
		rep     movsd

buff_no_dword_move:
		pop     ecx

buff_move_small:
		and     ecx, 03h
		jecxz    check_for_more_frags
		rep     movsb

check_for_more_frags:
ifndef CODE_386
		mov     ax, ds                  ; ax wont change
		pop     ds
endif
		cmp     pAS.early_tx_pend, 2 ; is this a early tx?
		jne     no_early_tx                
		
		cmp     pAS.early_tx_threshold, 0
		jg      no_early_tx
     
IFDEF EZSTART
		call    FAR PTR EBM_SendPacket
ELSE
 IFDEF LARGE
		call    FAR PTR SendPacket
 ELSE
		call    SendPacket
 ENDIF
ENDIF

		mov     cx, pAS.early_tx_threshold
		neg     cx

		mov     pAS.early_tx_threshold, 0
		mov     pAS.early_tx_pend, 1

ifndef CODE_386
		push    ds
		mov     ds, ax
endif
		test    cx, cx                 ; if cx = 0 go on
		jne     early_tx_count_ok1
ifndef CODE_386
		pop     ds
endif

no_early_tx:
		add     ebx, size FragmentStructure
		dec     dx
		jnz     fragment_loop

		pop     ebx
		pop     ecx
		pop     edi
		pop     esi
ifndef CODE_386
ifndef NW_286
		pop     fs
endif
		pop     es
endif
		ret

public send_dma_fragment
send_dma_fragment:
		and     ecx, NOT PHYSICAL_ADDR
		jecxz    check_for_more_frags

		push    esi
		xor     esi, esi                   ; offset for split frag
		
		cmp     pAS.early_tx_pend, 2   ; early_tx_pending flag
		jne     early_dma_tx_count_ok

		sub     pAS.early_tx_threshold, cx
		jnc     early_dma_tx_count_ok

		push    eax
		mov     ax, pAS.early_tx_threshold
		neg     ax
		cmp     ax, DEFAULT_ETX_VALUE
		ja      split_dma_send
		mov     pAS.early_tx_threshold, 0
		pop     eax
		jmp     early_dma_tx_count_ok

		
split_dma_send:
		pop     eax
		add     cx, pAS.early_tx_threshold ; cx = # of bytes to send

early_dma_tx_count_ok:
		push    dx
		push    eax

; wait for dma to finish
		mov     dx, pAS.io_base
		add     dx, EISA_STAT

wait_for_tx_done_dma:
		in      al, dx
		test    al, EISA_SDMA
		jnz     wait_for_tx_done_dma                                
		
		cmp     pAS.rx_pend, 1
		jne     no_rx_pending_on_tx

; process a rx_complete
		mov     pAS.rx_pend, 0
		dec     dx
		and     al, NOT EISA_CLRD
		out     dx, al                  ; clear ints

		mov     al, pAS.local_nxtpkt_ptr ; Get local_nxtpkt_ptr into AL
		dec     al
		cmp     al, pAS.pstart_hold
		jnb     tx_bnry1_ok
		mov     al, pAS.pstop_hold
		dec     al
tx_bnry1_ok:
		mov     rAX, SUCCESS
		call    UM_Receive_Copy_Complete

		cmp     rAX, PENDING
		jne     no_tx_bnry_update
		mov     dx, pAS.io_base
		add     dx, REG_BNRY+EISA_790
		out     dx, al

no_tx_bnry_update:
; unmask receive interrupts
		mov     dx, pAS.io_base
		add     dx, REG_IMR + EISA_790
		mov     al, pAS.imr_hold
		out     dx, al          

no_rx_pending_on_tx:
		mov     pAS.tx_pend, 1

		mov     dx, pAS.io_base
		add     dx, EISA_AA
IFDEF CODE_386
		mov     eax, [ebx].fragment_ptr
ELSE
		mov	eax, fs:[ebx].fragment_ptr
ENDIF
		add     eax, esi
IFDEF ONE_K
		push    ebx
		push    edi
		push    ecx
one_K_loop:
		push    ecx
		push    edx
		push    eax
		mov     ebx, eax
		and     ebx, 3ffh

;cmp    ebx, 3f0h
;jb     k1

;mov    edx, ebx
;add    bx, cx
;shr    bx, 11
;cmp    ebx, 0
;jz     no_1K

;mov    eax, 7f7h
;sub    eax, edx
;movzx  ecx, ax
;jmp    no_1K

;k1:
		mov     edx, ebx
		add     bx, cx
		shr     bx, 10
		cmp     ebx, 0
		jz      no_1K

		mov     eax, 400h
		sub     eax, edx
		movzx   ecx, ax
no_1K:
		pop     eax
		pop     edx

ENDIF
		out     dx, eax                 ; set up host addr

IFDEF ONE_K
		push    eax
ENDIF
		add     dx, EISA_AS-EISA_AA

		xor     eax, eax                ; add page base to offset
		mov     ah, pAS.curr_page_num
		shl     ah, 5
		add     eax, edi

;                mov     eax, edi                  ; adapter mem addr
		sub     eax, pAS.ram_access
		sal     eax, 16                 ; move to top 16 bits
		mov     ax, cx                  ; size
;cmp    ax, 8
;jae    abc
;mov    ax, 8
;abc:
		or      eax, EISA_SZ_SDMA
		out     dx, eax                 ; start dma

IFDEF ONE_K
		pop     eax
		cmp     ebx, 0
		jz      no_1K_loop

		add     eax, ecx
		add     edi, ecx
		mov     bx, cx
		pop     ecx
		sub     cx, bx
		or      cx, cx
		jz      no_1K_loop1

		mov     dx, pAS.io_base
		add     dx, EISA_STAT
		push    ax
wait_1K_dma:
		in      al, dx
		test    al, EISA_SDMA
		jnz     wait_1K_dma
		pop     ax
		mov     dx, pAS.io_base
		add     dx, EISA_AA
		jmp     one_K_loop
no_1K_loop:
		pop     ecx
no_1K_loop1:
		pop     ecx
		pop     edi
		pop     ebx
ENDIF
		pop     eax
		pop     dx              

		sub     ax, cx                  ; adjust total frame size
ifdef CODE_386
		add     edi, ecx                ; adjust adapter memory 
else
		add     di, cx                  ; adjust adapter memory 
endif
		cmp     pAS.early_tx_pend, 2 ; is this a early tx?
		jne     no_dma_early_tx                
		
		cmp     pAS.early_tx_threshold, 0
		jg      no_dma_early_tx

		movzx   esi, cx                 ; bug fix, cx = # of bytes
						; dma'ed so far
		push    dx
		push    ax
		mov     dx, pAS.io_base
		add     dx, EISA_STAT
wait_before_early_tx:
		in      al, dx
		test    al, EISA_SDMA
		jnz     wait_before_early_tx
		pop     ax
		pop     dx
IFDEF EZSTART
		call    FAR PTR EBM_SendPacket
ELSE
 IFDEF LARGE
		call    FAR PTR SendPacket
 ELSE
		call    SendPacket
 ENDIF
ENDIF

		mov     cx, pAS.early_tx_threshold
		neg     cx
;                movzx   esi, cx

		mov     pAS.early_tx_threshold, 0
		mov     pAS.early_tx_pend, 1

		test    cx, cx                  ; if cx = 0 go on
;                jne     wait_for_tx_done_dma
		jne     early_dma_tx_count_ok

no_dma_early_tx:
		pop     esi
ifndef CODE_386
		pop     ds
endif
		jmp     no_early_tx
;               add     ebx, size FragmentStructure
;                jmp     check_for_more_frags

ASM_EBM_PROC_END        buff_struct_to_ram 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       SendPacket      Sends packet of at offset 
;                       pAS.tx_buffer in shared memory.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_EBM_PROC    SendPacket
			push    ax
			push    dx
			push    esi

			mov     dx, pAS.io_base
			add     dx, REG_CMD+EISA_790
			in      al, dx
			test    al, CMD_TXP
			stc
			jnz     NicPending

			xor     ax, ax                  ; get tx_buffer offset
			mov     al, pAS.tx_head
			shl     ax, 2
			movzx   esi, ax
			mov     cx, word ptr pAS.pSI.tx_buffer+2
			mov     ax, word ptr pAS.pSI.tx_buffer

			add     dx, REG_TPSRL - REG_CMD
			out     dx, al
			mov     al, ah
			add     dx, REG_TPSR - REG_TPSRL
			out     dx, al
			add     dx, REG_TBCR0 - REG_TPSR
			mov     al, cl                  ; BX = size; write size
			out     dx, al                  ; to TBCR0 and TBCR1.
			add     dx, REG_TBCR1 - REG_TBCR0
			mov     al, ch
			out     dx, al
			add     dx, REG_CMD - REG_TBCR1

			mov     al, CMD_STA+CMD_TXP
			out     dx, al                  ; Send packet.
			clc

NicPending:
			pop     esi
			pop     dx
			pop     ax
			ret
ASM_EBM_PROC_END        SendPacket

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Receive_Copy Copies data from adapter shared RAM to
;                               a Data buffer structure.
;
;       Entry:  CX  == bytes to move
;               AX  == Offset in shared RAM
;               BX      == Lookahead flag, 0 = Lookahead copy.
;               ES:SI  == Pointer to data buffer structure
;               DS:BP  == Pointer to adapter structure
;
;       Return:             AX == Return code. High 16 bits of EAX
;                                 altered if CODE386 is defined.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Receive_Copy

		push    ecx
		push    edx
		push    esi
		push    edi

ifndef  CODE_386
		push    es
		push    ds
endif

		push	ebx
; Assume this is a final copy.
		and	pAS.adapter_flags, NOT EARLY_RX_COPY
; pma 09 9/10/93 set EARLY_RX_COPY here
		test    bx, bx
		jz      LookAheadCopy
		or      pAS.adapter_flags, EARLY_RX_COPY
LookAheadCopy:
		mov     pAS.erx_frame_size, ax
		mov     bh, pAS.local_nxtpkt_ptr
		mov     bl, NIC_HEADER_SIZE
		mov	di, ax		; Offset from UMAC in ax
		add     di, bx		
		
		xor     bl, bl
		mov     bh, pAS.pstop_hold
		cmp     di, bx
		jb      large_offset
		sub     di, bx
		mov     bh, pAS.pstart_hold
		add     di, bx

large_offset:
;		pop     ebx
;		push    ebx                             ; check for lookahead

		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		push    dx
		push    ax                              ; save page

		call    receive_packet
		
		pop     ax
		pop     dx
		out     dx, al                          ; restore page
		
; check for dma finish
		test    pAS.adapter_flags, EARLY_RX_COPY
		mov     rAX, PENDING
		jne     LM_RC_DMA_pending

		cmp     pAS.rx_pend, 1
		jne     LM_RC_DMA_success

rx_test_dma_done:
		mov     dx, pAS.io_base
		add     dx, EISA_STAT
		in      al, dx
		test    al, EISA_SDMA
		je      LM_RC_DMA_success

		test    pAS.adapter_flags, ENABLE_RX_PENDING
		je      rx_dma_done

		and     al, not EISA_DIEN
		out     dx, al                          ; enable rx dma int

		mov     rAX, PENDING
		jmp     short LM_RC_DMA_done

rx_dma_done:
		in      al, dx
		test    al, EISA_SDMA
		jne     rx_dma_done

LM_RC_DMA_success:
		mov     pAS.rx_pend, 0
		mov     rAX, SUCCESS

LM_RC_DMA_done:
		pop	ebx

ifndef  CODE_386
		pop     ds
		pop     es
endif
		pop     edi
		pop     esi
		pop     edx
		pop     ecx

		ret
		
LM_RC_DMA_pending:
; reinitialize the lookahead flag (this is stack sensitive!)
		pop	ebx
		push	ebx

		test    pAS.adapter_flags, ENABLE_RX_PENDING
		jne     LM_RC_DMA_done

; pma 07 9/10/93 let HandlePRX clear COPY
;                and     pAS.adapter_flags, NOT EARLY_RX_COPY

; wait for packet to finish
		mov     dx, pAS.io_base
		add     dx, REG_ISR+EISA_790 ; Get interrupt status

                cmp     bx, 1                   ; do we wait for rxstat?
                jne     LM_RC_no_wait           ; guess not

                mov     ecx, 01ffffh            ; resonable wait time

wait_for_rx_fini:
		in      al, dx
		test    al, ISR_PRX+ISR_RXE
		loopz	wait_for_rx_fini

; pma 13 9/14/93 let HandlePRX or HandleERW clear the ISR
;                and     al, ISR_PRX+ISR_RXE
;                out     dx, al

; pma 14 9/14/93 check status in packet header
LM_RC_no_wait:
		mov     ah, pAS.local_nxtpkt_ptr
		xor     al,al
		movzx   esi, ax
		shr     ax, 5
		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		push    ax
		push    dx
		and     al, NOT EISA_RAM_PAGE_MASK
		or      al, ah
		out     dx, al
		and     si, pAS.page_offset_mask
ifdef CODE_386
		add     esi, pAS.ram_access
else
		mov     ax, word ptr pAS.ram_access+2
		mov     es, ax
endif
		mov     al, pESI.EthRStat
		test    al, RSR_PRX
		pop     dx
		pop     ax
		out     dx, al
		mov     rAX, HARDWARE_FAILED
		jz      LM_RC_DMA_done

;                add     dx, REG_RSR-REG_ISR
;                in      al, dx
;                test    al, RSR_PRX
;                mov     rAX, HARDWARE_FAILED
;                jne     LM_RC_DMA_done

; wait for transmit to finish
		mov     dx, pAS.io_base
		add     dx, EISA_STAT

erx_dma_done:
		in      al, dx
		test    al, EISA_SDMA
		jne     erx_dma_done

		mov     pAS.tx_pend, 0
		jmp     LM_RC_DMA_success

;                cmp     pAS.rx_pend, 0
;                je     LM_RC_DMA_success

;                add     dx, EISA_AA - EISA_STAT
;                mov     eax, pAS.rx_frag
;                out     dx, eax
;                add     dx, EISA_AS - EISA_AA
;                mov     eax, dword ptr pAS.erx_offset
;                out     dx, eax                        

;                add     dx, EISA_STAT - EISA_AS

erx_dma_done1:
;                in      al, dx
;                test    al, EISA_SDMA
;                jne     erx_dma_done1

; pma 12 9/14/93 let HandleERW or HandlePRX update BNRY
; clean up receive
;               mov     al, pAS.local_nxtpkt_ptr ; Get local_nxtpkt_ptr into AL
;               dec     al
;               cmp     al, pAS.pstart_hold
;               jnb     tx_bnry2_ok
;               mov     al, pAS.pstop_hold
;               dec     al
;
;tx_bnry2_ok:
;               add     dx, (REG_BNRY+EISA_790) - EISA_STAT
;               out     dx, al
;		jmp     LM_RC_DMA_success

ASM_EBM_PROC_END        LM_Receive_Copy


;--------------------------
; Move Rx Frame fm Adapter
;--------------------------
;
; enter w.      pAS -> adapter structure
;               [di] -> adapter buffer
;               es:[si] -> frag desc list
;               cx      =  total frame size
;
; exit  w.      ax = completion code
;               all other registers preserved
;

public receive_packet
receive_packet  proc    near    
		shl     pAS.ram_usable, 10d     ; find page boundary

ifndef CODE_386
		push    es
endif
		push    esi
		push    edi
		push    edx
		push    ecx
		push    ebx

		cld                             ;make sure we increment


; page wrap - set new page
		mov     ax, di
		shr     ax, 5                           ; set up page bits

		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		and     al, NOT EISA_RAM_PAGE_MASK
		or      al, ah                          ; set page                                
		out     dx, al
		mov     pAS.curr_page_num, ah
		and     di, pAS.page_offset_mask

; Save offset of pkt in shared memory.
		mov     word ptr pAS.packet_offset, di

		mov     rDX, pESI.fragment_count      ; Get # of frags in DX
		lea     ebx, pESI.fragment_list       ; ES:BX = 1st frag str.

		mov     word ptr pAS.byte_cnt, cx     ; Save total byte cnt.

fragment_loop2:
		cmp     pAS.byte_cnt, 0
		ja      move_more
		jmp     no_more_frags2

move_more:
		push    ebx
ifdef CODE_386
		mov     ecx, [ebx].fragment_length
		test    ecx, PHYSICAL_ADDR
else
		push    es
		movzx   ecx, es:[bx].fragment_length
		test    cx, PHYSICAL_ADDR
endif
		je      receive_shmem_frag
		jmp     receive_dma_frag

	Public receive_shmem_frag
receive_shmem_frag:
		test    cx, cx
		jnz     good_fragment
		jmp     ZeroLenFrag

good_fragment:
		cmp     word ptr pAS.byte_cnt, cx
						; Subtract this fragment's
						; count from total count.
		jae     count_ok                ; If fragment byte count is >
		mov     cx, word ptr pAS.byte_cnt ; remaining byte count (last
						; fragment) use byte count,
						; else use fragment count.

count_ok:       sub     word ptr pAS.byte_cnt, cx

ifdef CODE_386
		mov     edi, [ebx].fragment_ptr ; ES == far ptr to fragment.
else
		les     di, es:[ebx].fragment_ptr ; ES == far ptr to fragment.
endif

continue_copy:
		push    ax                     ; save AX for later
		xor	ax, ax
		mov	pAS.erx_offset, ax	; fragment offset
		mov	pAS.erx_size, ax

; see if at page end
		mov     ax, pAS.ram_usable
		sub     ax, cx
		cmp     word ptr pAS.packet_offset, ax
		jna     no_page_wrap

		mov     word ptr pAS.wr_frag_cnt, cx ; save fragment count
		mov     cx, pAS.ram_usable

; calculate leftover count
		sub     cx, word ptr pAS.packet_offset
		sub     word ptr pAS.wr_frag_cnt, cx ; Save for later.

no_page_wrap:                
		pop     ax
IFDEF CODE_386
		push	esi
ELSE
		push	si
		push	ds
ENDIF
		add     pAS.erx_frame_size, cx
		test    pAS.adapter_flags, EARLY_RX_FRAME
		je      rx_packet_good

; pma 05 9/10/93 get stable count first, then check receive done
EarlyMove:
		push    dx                              ; wait for frame to
		push    bx
		push    ax
		
StartRchk:
		mov     dx, pAS.io_base
		add     dx, REG_RCNTH+EISA_790
		in      al, dx

RepeatRcnt:
		mov     ah, al
		dec     dx
		in      al, dx
		mov     bx, ax
		inc     dx
		in      al, dx
		cmp     ah, al
		jne     RepeatRcnt

		add     dx, REG_ISR-REG_RCNTH
		in      al, dx
		test    al, ISR_PRX
		jnz     rx_packet_good_0
		test    al, ISR_RXE
		jz      packet_not_received
		mov	pAS.wr_frag_cnt, 0	; clear wrap counter
						; on receive error
		pop     ax
		pop     bx
		pop     dx
ifdef CODE_386
		pop	esi
ELSE
		pop	ds
		pop	si
		pop     es
endif
		pop     ebx
		mov	rBX, HARDWARE_FAILED
		jmp     byte_count_ok

packet_not_received:
		cmp     pAS.erx_frame_size, bx
		ja      SlaveChkHowMany
		jmp	rx_packet_good_0

SlaveChkHowMany:
		mov     ax, pAS.erx_frame_size
		sub     ax, cx          ; minus # of bytes copied so far
		sub     bx, ax          ; # of bytes received since last copy
		cmp     bx, 64          ; wait for at least 64 bytes
		jl      StartRchk
		mov     dx, bx          ; save bx
		add     bx, ax          ; restore total # of bytes received
		add     ax, cx          ; restore total # of bytes to copy
		sub     ax, bx          ; how many more until receive complete
		cmp     ax, 16          ; if < 16, wait for completion
		jl      StartRchk
		sub     cx, dx          ; subtract # of bytes about to copy
		mov     pAS.erx_size, cx        ; remaining count
		mov     cx, dx

rx_packet_good_0:
		pop     ax
		pop     bx
		pop     dx

rx_packet_good:
ifdef CODE_386
		movzx   esi, word ptr pAS.packet_offset
		add     esi, pAS.ram_access
		push	eax
		movzx	eax, pAS.erx_offset
		add	esi, eax
		pop	eax
else
		mov     si, pAS.packet_offset

		push    eax
		movzx	eax, pAS.erx_offset
		add	esi, eax
		mov     ax, word ptr pAS.ram_access.2
		mov     ds, ax
		pop     eax
endif
		push	cx

		cmp     cx, 3
		jbe     rx_move_small
		
		test    si, 1                   ; for maximum throughput
		jz      Rx_Adjust_Count_word    ; 
		
		dec     cx                      ; 
		movsb                           ; 
		
Rx_Adjust_Count_word:
		test    si, 2                   ; for maximum throughput
		jz      Rx_Adjust_Count_dword           ; 
		
		sub     cx, 2                   ; 
		movsw                           ; 

Rx_Adjust_Count_dword:
		push    cx
		shr     cx, 2
		jecxz   no_rx_dword_move
		rep     movsd

no_rx_dword_move:
		pop     cx

rx_move_small:
		and     cx, 03h
		jcxz    rx_frag_end
		rep     movsb
rx_frag_end:
		pop	cx
IFNDEF CODE_386
		pop	ds
ENDIF
		cmp	pAS.erx_size, 0
		je	SlaveChk4Wrap
		add	pAS.erx_offset, cx
		mov	cx, pAS.erx_size
		mov	pAS.erx_size, 0
IFNDEF CODE_386
		push	ds
ENDIF
		jmp	EarlyMove
SlaveChk4Wrap:
		xor	cx, cx
ifdef CODE_386
		sub     esi, pAS.ram_access
		mov     word ptr pAS.packet_offset, si
		pop     esi
else
		mov     pAS.packet_offset, si
		pop     si
endif
		cmp     pAS.wr_frag_cnt, 0
		jne     SwitchPage

		push    ax
		mov     ax, word ptr pAS.packet_offset
		cmp     ax, pAS.ram_usable
		je      FixPage
NotPageEnd:
		pop     ax
		jmp     ZeroLenFrag

SwitchPage:
		mov     cx, word ptr pAS.wr_frag_cnt ; Get byte count of wrapped
		mov     pAS.wr_frag_cnt, 0  ; data starting at pstart and
						; clear wrapped frag count.

; see if ring or page wrap
		push    ax
FixPage:
		mov     al, pAS.curr_page_num
		cmp     al, pAS.max_page_num
		jne     fix_page_wrap

; must be ring wrap
		mov     ah, pAS.pstart_hold
		xor     al, al                  ; Get pstart in SI. Pstart_hold
		mov     word ptr pAS.packet_offset, ax       ; is bits 8-15. 
		shr     ax, 5
		dec     ah
		mov     pAS.curr_page_num, ah

fix_page_wrap:
; page wrap - set new page
		push    dx
		inc     pAS.curr_page_num
		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		and     al, NOT EISA_RAM_PAGE_MASK
		or      al, pAS.curr_page_num   ; set page
		out     dx, al
		mov     ax, pAS.page_offset_mask;
		and     word ptr pAS.packet_offset, ax
		pop     dx
		pop     ax
		or      cx, cx
		jnz     continue_copy           ; Finish copying to this frag.

ZeroLenFrag:
ifndef CODE_386
		pop     es
endif
		pop     ebx
		add     ebx, size FragmentStructure
		dec     dx                      ; Decrement fragment count.
		jz      no_more_frags2
		jmp     fragment_loop2

no_more_frags2:
		mov     rBX, SUCCESS
		cmp     pAS.byte_cnt, 0
		je      byte_count_ok
		mov     rBX, OUT_OF_RESOURCES

byte_count_ok:
		shr     pAS.ram_usable, 10d     ; restore page size

		mov     rAX, rBX                ; Get ret code into AX,
		pop     ebx
		pop     ecx
		pop     edx
		pop     edi
		pop     esi
ifndef CODE_386
		pop     es
endif

		ret

public receive_dma_frag
receive_dma_frag:
		and     ecx, NOT PHYSICAL_ADDR
		jecxz    ZeroLenFrag

		mov     pAS.erx_offset, 0       ; fragment offset
		mov	pAS.erx_size, 0
		
; pms 17 9/21/93 check for small dma fragments
		cmp     ecx, 3
		jle     small_dma_frag

; fix packet_offset to real offset
		mov     al, pAS.curr_page_num
		shl     ax, 13
		or      ax, word ptr pAS.packet_offset
		mov     si, ax

		cmp     word ptr pAS.byte_cnt, cx
						; Subtract this fragment's
						; count from total count.
		jae     dma_count_ok            ; If fragment byte count is >
		mov     cx, word ptr pAS.byte_cnt    ; remaining byte count (last
						; fragment) use byte count,
						; else use fragment count.
dma_count_ok:
		sub     word ptr pAS.byte_cnt, cx

		push    eax
		push    dx

		mov     ah, pAS.pstop_hold
		xor     al, al
		sub     ax, cx
		cmp     ax, si
		jae     next_dma_frag

		add     ax, cx
		sub     ax, si                  ; get num of bytes left
		mov     word ptr pAS.wr_frag_cnt, cx
		sub     word ptr pAS.wr_frag_cnt, ax
		mov     cx, ax
			 
next_dma_frag:
		add     pAS.erx_frame_size, cx
		test    pAS.adapter_flags, EARLY_RX_FRAME
		je      dma_rx_packet_good

; pma temp 9/21/93 never say last frag
		jmp     dma_not_last_frag

		pop     dx
		push    dx
		cmp     dx, 1                   ; is this the last frag
		jne     dma_not_last_frag

		cmp     pAS.wr_frag_cnt, 0
		jne     dma_not_last_frag

		movzx   eax, pAS.leftover_data
ifdef CODE_386
		add     eax, [ebx].fragment_ptr ; ES == far ptr to fragment.
else
		add     eax, es:[ebx].fragment_ptr ; ES == far ptr to fragment.
endif
		mov     pAS.rx_frag, eax
		mov     ax, si                  ; adapter mem addr
		sal     eax, 16                 ; move to top 16 bits
		mov     ax, cx                  ; size
		or      eax, EISA_SZ_SDMA+EISA_SZ_DIR
		mov     dword ptr pAS.erx_offset, eax   ; start dma

; pma 08 9/10/93 set COPY at start of LM_Receive_Copy
;                or      pAS.adapter_flags, EARLY_RX_COPY

		add     si, cx
		jmp     dma_rx_pending

dma_not_last_frag:
		push    bx

DMAStartRchk:
		mov     dx, pAS.io_base

		add     dx, REG_ISR+EISA_790
		in      al, dx
		test    al, ISR_PRX
		jnz     dma_rx_packet_good_0
		test    al, ISR_RXE
		jz      dma_packet_not_received
		mov	pAS.wr_frag_cnt, 0	; clear wrap count on
						; receive error
		pop     bx
		pop     dx
		pop     eax
ifndef CODE_386
		pop     es
endif
		pop     ebx
		mov	rBX, HARDWARE_FAILED
		jmp     byte_count_ok

dma_packet_not_received:

		add     dx, REG_RCNTH-REG_ISR
		in      al, dx

DMARepeatRcnt:
		mov     ah, al
		dec     dx
		in      al, dx
		mov     bx, ax
		inc     dx
		in      al, dx
		cmp     ah, al
		jne     DMARepeatRcnt

		cmp     pAS.erx_frame_size, bx
		ja      CheckHowMany
		jmp     dma_rx_packet_good_0

CheckHowMany:
		mov     ax, pAS.erx_frame_size
		sub     ax, cx          ; minus # of bytes copied so far
		sub     bx, ax          ; # of bytes received since last copy
		cmp     bx, 64          ; wait for at least 64 bytes
		jl      DMAStartRchk
		mov     dx, bx          ; save bx
		add     bx, ax          ; restore total # of bytes received
		add     ax, cx          ; restore total # of bytes to copy
		sub     ax, bx          ; how many more until receive complete
		cmp     ax, 16          ; if < 16, wait for completion
		jl      DMAStartRchk
		sub     cx, dx          ; subtract # of bytes about to copy
		mov     pAS.erx_size, cx        ; remaining count
		mov     cx, dx

dma_rx_packet_good_0:
		pop     bx

dma_rx_packet_good:
; wait for dma to finish
		mov     dx, pAS.io_base
		add     dx, EISA_STAT

wait_for_rx_done_dma:
		in      al, dx
		test    al, EISA_SDMA
		jnz     wait_for_rx_done_dma                                

		mov     pAS.tx_pend, 0
		mov     pAS.rx_pend, 1

		mov     dx, pAS.io_base
		add     dx, EISA_AA
		movzx   eax, pAS.leftover_data
		add     ax, pAS.erx_offset      ; chunks of early rx
ifdef CODE_386
		add     eax, [ebx].fragment_ptr ; ES == far ptr to fragment.
else
		add     eax, es:[ebx].fragment_ptr ; ES == far ptr to fragment.
endif
		out     dx, eax                 ; set up host addr

		add     dx, EISA_AS-EISA_AA
		mov     ax, si                  ; adapter mem addr
		sal     eax, 16                 ; move to top 16 bits
		mov     ax, cx                  ; size
		or      eax, EISA_SZ_SDMA+EISA_SZ_DIR
		out     dx, eax                 ; start dma

		add     si, cx

		cmp     pAS.erx_size, 0         ; more early rx chunks ?
		je      Check4RingWrap

		add     pAS.erx_offset, cx

		shr     cx, 3                   ; delay loop proportional to
		loop    $                       ; # of bytes just dma'd

		mov     cx, pAS.erx_size
		mov     pAS.erx_size, 0
		push    bx
		jmp     DMAStartRchk

Check4RingWrap:
		cmp     pAS.wr_frag_cnt, 0
		jne     rx_dma_frag_split
		mov     pAS.erx_offset, 0
dma_rx_pending:
		mov     pAS.leftover_data, 0

		mov     ax, pAS.ram_size
		shl     ax, 10                  ; x 1024
		cmp     si, ax
		jb      no_wrap
;		je      wrap
;		int     3
wrap:
		mov     ah, pAS.pstart_hold
		xor     al, al
		mov     si, ax
no_wrap:
		mov     ax, si                  ; change si to page/off
		and     si, pAS.page_offset_mask
		mov     word ptr pAS.packet_offset, si
		shr     ax, 13
;                and     al, not EISA_RAM_PAGE_MASK
		and     al, EISA_RAM_PAGE_MASK          ; bug fix
		mov     pAS.curr_page_num, al   ; set page
		mov     ah, al
		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		and     al, NOT EISA_RAM_PAGE_MASK
		or      al, ah                          ; set page
		out     dx, al          
				
		pop     dx              
		pop     eax
		jmp     ZeroLenFrag

rx_dma_frag_split:
; readjust to pstart
		mov     pAS.leftover_data, cx
		mov     cx, word ptr pAS.wr_frag_cnt
		cmp     cx, 3
		jg      dma_large_chunk

		movzx   esi, pAS.ram_usable             
IFDEF CODE_386
		add     esi, pAS.ram_access
ELSE
		push    es
		mov     ax, word ptr pAS.ram_access+2
		mov     es, ax
ENDIF
		sub     esi, 4
IFDEF CODE_386
		mov     eax, dword ptr [esi]            ; already in last page
ELSE
		mov     eax, dword ptr es:[si]
ENDIF
		push    eax

		mov     ah, pAS.pstart_hold
		xor     al, al
		shr     ax, 5
		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		in      al, dx
		and     al, NOT EISA_RAM_PAGE_MASK
		or      al, ah                          ; set page
		out     dx, al

		mov     ah, pAS.pstart_hold
		xor     al, al
		and     ax, pAS.page_offset_mask
		movzx   esi, ax
IFDEF CODE_386
		add     esi, pAS.ram_access
ENDIF
		sub     esi, 4
		pop     eax
IFDEF CODE_386
		mov     dword ptr [esi], eax
ELSE
		mov     dword ptr es:[si], eax
		pop     es
ENDIF

		sub     pAS.leftover_data, 4
		mov     ah, pAS.pstart_hold
		xor     al, al
		sub     ax, 4
		mov     si, ax
		add     cx, 4
		mov     pAS.wr_frag_cnt, 0
		jmp     next_dma_frag

dma_large_chunk:
		mov     pAS.wr_frag_cnt, 0
	       
		mov     ah, pAS.pstart_hold
		xor     al, al
		mov     si, ax
		jmp     next_dma_frag

; pma 18 9/21/93 handle small dma fragments later
small_dma_frag:
		int     3

receive_packet endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Add_Multi_Address    Adds Multicast address in adapter structure to
;                               Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Add_Multi_Address

		push    edi
		push    esi
		push    ecx
		push    bx
ifndef CODE_386
		push    es
endif
		cld

		mov     rAX, SUCCESS             ; Preset return code
ifndef CODE_386
		push    ds
		pop     es                      ; ES = DS
endif
		lea     edi, pAS.mc_table
		mov     ecx, MC_TABLE_ENTRIES    ; CL == max number of
						; entries in table

AroundTheWorld:
		lea     esi, pAS.multi_address
		push    edi
		push    ecx
		mov     ecx, 6
		repz    cmpsb
		pop     ecx
		pop     edi
		jnz     DoYerNeighbor
		cmp     byte ptr [edi+6], 0ffh  ; If instance count >= 0ffh,
						; entry is maxed out.
		je      McTableFull
		inc     byte ptr [edi+6]        ; Increment instance_count
		jmp     AddMultiDone            ; All Done

DoYerNeighbor:  add     edi, 7                   ; Point to next address
		loop    AroundTheWorld          ; Check all addresses.
						; No match found, find
						; first empty table entry
		mov     ecx, MC_TABLE_ENTRIES    ; and insert address there
		lea     edi, pAS.mc_table

CheckForEmpty:  mov     bl, [edi+6]              ; Check instance count for
		cmp     bl, 0                   ; this address.
		je      add_address             ; If instance count == 0
						; copy address to this space.
		add     edi, 7                   ; Point to next address
		loop    CheckForEmpty           ; Loop for all entries.
		jmp     McTableFull             ; If no empty entries, bail out

add_address:    lea     esi, pAS.multi_address
		mov     ecx, 6
		rep     movsb
		inc     byte ptr [edi]           ; Increment instance_count
		jmp     AddMultiDone

McTableFull:    mov     rAX, OUT_OF_RESOURCES

AddMultiDone:
ifndef CODE_386
		pop     es
endif
		pop     bx
		pop     ecx
		pop     esi
		pop     edi

		ret
ASM_EBM_PROC_END        LM_Add_Multi_Address


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Delete_Multi_Address Removes Multicast address in adapter
;                                       structure from Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Delete_Multi_Address

		push    ecx
		push    edi
		push    esi
ifndef CODE_386
		push    es
endif
		cld

		mov     rAX, SUCCESS             ; Preset return code
ifndef CODE_386
		push    ds
		pop     es                      ; ES = DS
endif
		lea     edi, pAS.mc_table
		mov     ecx, MC_TABLE_ENTRIES

FrootLoop:      lea     esi, pAS.multi_address
		push    edi
		push    ecx
		mov     ecx, 6
		repz    cmpsb
		pop     ecx
		pop     edi
		jnz     TryNextDoor
		cmp     byte ptr [edi+6], 0h    ; If instance count = 0h,
						; entry is alrady gone.
		je      McTableEmpty
		dec     byte ptr [edi+6]        ; Decrement instance_count
		jmp     DeleteMultiDone         ; All Done

TryNextDoor:    add     edi, 7                   ; Point to next address
		loop    FrootLoop               ; Check all addresses
						; If all entries checked and
						; no matches, bail out.

McTableEmpty:   mov     rAX, OUT_OF_RESOURCES

DeleteMultiDone:
ifndef CODE_386
		pop     es
endif

		pop     esi
		pop     edi
		pop     ecx

		ret

ASM_EBM_PROC_END        LM_Delete_Multi_Address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Service_Events       Interrupt event handling routine.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Service_Events

IFDEF CODE_386
			push    ebx
			push    ecx
			push    edx
ELSE
			push    ebx
			push    ecx
			push    edx
			push    esi
			push    edi
			push    eax
ENDIF
ifndef CODE_386
			push    ds
			push    es
endif

CheckNextInt:           mov     dx, pAS.io_base
			add     dx, EISA_STAT
			in      al, dx
;                        and     al, EISA_DIEN + EISA_STATD
;                        cmp     al, EISA_DIEN + EISA_STATD
;                        jne     Start790Check
			test    al, EISA_STATD
			jz      Start790Check
			mov     pAS.servicing_ints, 1
			jmp     HandleDMA

Start790Check:          add     dx, (REG_ISR+EISA_790) - EISA_STAT ; Get interrupt status
			in      al, dx
			test    al, al
			jnz     StartIntCheck
			jmp     NotNICInterrupt ; If no NIC int, check hw int

StartIntCheck:          mov     pAS.servicing_ints, 1
			test    al, ISR_OVW             ; Is ring overflowing?
			jz      CheckPktRec             ; If not, check packet received
			jmp     HandleOVW

CheckPktRec:            test    al, ISR_PRX             ; Was packet received?
			jz      CheckRxErr              ; If not, check receive error
			jmp     HandlePRX

CheckRxErr:             test    al, ISR_RXE             ; Is there a receive error?
			jz      CheckErlyRec            ; If not, check early Rx.
			jmp     HandleRXE

CheckErlyRec:           test    al, ISR_ERW             ; Packet in process?
			jz      CheckPTX                ; If not, check pkt transmitted
			jmp     HandleERW

CheckPTX:               test    al, ISR_PTX             ; Was packet xmitted?
			jz      CheckTxErr              ; If not, check ring overflow
			jmp     HandlePTX

CheckTxErr:             test    al, ISR_TXE             ; Is there a transmit error?
			jz      CheckCntrs              ; If not, update counters.
			jmp     HandleTXE       

CheckCntrs:             test    al, ISR_CNT
			jnz     DoCounters
			jmp     NotNICInterrupt ; If no NIC int, check hw int

DoCounters:             mov     al, ISR_CNT
			out     dx, al
			call    UpdateCounters
			jmp     CheckNextInt
	   
;---------------------- Handle Packet Received
ifndef  EZSTART
	PUBLIC  HandlePRX
endif
HandlePRX:              
ifndef CODE_386
			mov     ax, word ptr pAS.ram_access+2
			mov     es, ax
endif
; pma 06 9/10/93 clear both FRAME and COPY on receive complete
			and	pAS.adapter_flags, not (EARLY_RX_FRAME + EARLY_RX_COPY)

; pma 03 9/10/93 remove pending support - re-enabled 9/13/93
			test    pAS.imr_hold, IMR_ERWE
			jz      CheckForReceive
;
; Reset Early Receive Threshold
;
			mov     dx, pAS.io_base
			add     dx, REG_ERWCNT+EISA_790
			mov     al, DEFAULT_ERX_VALUE
			out     dx, al                          ; 

CheckForReceive:
			mov     dx, pAS.io_base
			add     dx, REG_CMD+EISA_790
			mov     al, CMD_RD2+CMD_PAGE1             ;
			out     dx, al                  ; Select page 1

			add     dx, REG_CURR - REG_CMD
			in      al, dx                  ; Get Curr page ptr
			mov     ah, al                  ; AH == CURR

			add     dx, REG_CMD - REG_CURR
			mov     al, CMD_RD2+CMD_PAGE0
			out     dx, al                  ; Select page 0

			add     dx, REG_BNRY - REG_CMD
			in      al, dx
			inc     al                      ; AL == BNRY+1

			cmp     pAS.pstop_hold, al
			jne     not_end_of_buf
			mov     al, pAS.pstart_hold

not_end_of_buf:         cmp     al, ah                  ; If BNRY+1 == CURR,
			jne     RingNotEmpty            ; ring is empty
			jmp     ReceiveDone
RingNotEmpty:
			mov     ah, pAS.local_nxtpkt_ptr
			xor     al, al

			movzx   esi, ax
			shr     ax, 5                   ; set up page bits
			mov     dx, pAS.io_base
			add     dx, EISA_RAM
			in      al, dx
			push    dx
			push    ax
			and     al, NOT EISA_RAM_PAGE_MASK
			or      al, ah                  ; set page
			out     dx, al
			and     si, pAS.page_offset_mask

ifdef CODE_386
			add     esi, pAS.ram_access
			movzx   ecx, word ptr [esi+2]
			movzx   ebx, word ptr [esi]
else
			mov     cx, es:[si+2]           ; Get packet length
			mov     bx, es:[si]             ; Get rx stat in BL,
endif
							; next pkt in BH.
PUBLIC  LM_ServEv02
LM_ServEv02:
			cmp     bh, pAS.pstop_hold
			jb      ptr_ok
			sub     bh, pAS.pstop_hold
			add     bh, pAS.pstart_hold

ptr_ok:

; pma 04 9/10/93 remove pending support - added 9/13/93
;                        test    pAS.adapter_flags, EARLY_RX_COPY
;                        je      LMSE_Rx_Ok
;
;                        and     pAS.adapter_flags, NOT EARLY_RX_COPY
;                        test    bl, RSR_PRX
;                        jne     LMSE_ERW_Ok
;
;                        mov     rAX, HARDWARE_FAILED
;                        call    UM_Receive_Copy_Complete
;                        jmp     DumpPacket
;
;LMSE_ERW_Ok:
;                        mov     dx, pAS.io_base
;                        add     dx, EISA_STAT
;
;erw_dma_wait:
;                        in      al, dx
;                        test    al, EISA_SDMA
;                        jnz     erw_dma_wait
;
;                        mov     pAS.tx_pend, 0
;                        mov     pAS.rx_pend, 1
;
;                        add     dx, EISA_AA - EISA_STAT
;                        mov     eax, pAS.rx_frag
;                        out     dx, eax
;                        add     dx, EISA_AS - EISA_AA
;                        mov     eax, dword ptr pAS.erx_offset
;                        out     dx, eax                        
;
;; mask nic interrupts
;                        add     dx, EISA_STAT - EISA_AS
;                        in      al, dx
;                        or      al, EISA_DIEN
;                        out     dx, al               ; enable rx dma int
;                       jmp     rx_pending
;
LMSE_Rx_Ok:
			push    ebx
			test    bl, RSR_DFR
			jz      SkipDeferringCnt
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_deferred
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_deferred
			add     errptr es:[bx], 1
			pop     es
endif
SkipDeferringCnt:       pop     ebx


; pma 10 9/10/93 avoid calling UM_Receive_Packet twice for early receive frames
			test    pAS.adapter_flags, RX_STATUS_PENDING
			jz      ContinuePRX02

			and     pAS.adapter_flags, not RX_STATUS_PENDING
			mov     eax, SUCCESS
			jmp     DumpPacket
ContinuePRX02:

			test    bl, RSR_PRX
			jnz     GoodFrame

			test	pAS.receive_mask, ACCEPT_ERR_PACKETS
			jz      DumpPacket

GoodFrame:
;			push	bx
			test    bl, RSR_PHY
			jz      PhysicalAdd
			test    pAS.receive_mask, ACCEPT_MULTI_PROM
			jnz     PhysicalAdd     ; If Promiscuous multicast
			call    CheckMultiAdd   ; mode, skip address check.
			cmp     rAX, SUCCESS
			jne     DumpPacket
;			mov	bx, SUCCESS

;---------------------- Process packet
PhysicalAdd:
			add     esi, NIC_HEADER_SIZE
			sub     ecx, CRC_SIZE

			call    UM_Receive_Packet

;			pop     bx
			cmp     ax, PENDING
			je      rx_pending

;                        mov     dx, pAS.io_base
;                        add     dx, EISA_STAT
;                        in      al, dx
;                        and     al, NOT EISA_DIEN        ; disable DMA ints
;                        out     dx, al

DumpPacket:
			push    eax              ; Save ret code from
						; UM_Receive_Packet
						; (packet accepted) or
						; CheckMultiAdd (packet dumped)

			mov     pAS.local_nxtpkt_ptr, bh

;---------------------- Update BNRY
			mov     al, bh          ; Get local_nxtpkt_ptr into AL
			dec     al
			cmp     al, pAS.pstart_hold
			jnb     bnry_ok
			mov     al, pAS.pstop_hold
			dec     al
bnry_ok:
			mov     dx, pAS.io_base
			add     dx, REG_BNRY+EISA_790
			out     dx, al

			pop     eax                      ; Restore ret code...
			cmp     ax, EVENTS_DISABLED     ; This ret code set
							; only by
							; UM_Receive_Packet.

			pop     ax
			pop     dx
			out     dx, al                  ; restore page                        

			jne     NearCheckForReceive
			jmp     ServEvDone
NearCheckForReceive:    jmp     CheckForReceive

public rx_pending
rx_pending:
			mov     pAS.local_nxtpkt_ptr, bh

; mask nic interrupts
			mov     dx, pAS.io_base
			add     dx, REG_IMR + EISA_790
			mov     al, IMR_PTXE+IMR_TXEE
			out     dx, al          

			pop     ax
			pop     dx
			out     dx, al                  ; restore page                        
			jmp     ServEvDone

;PUBLIC ReceiveDone
ReceiveDone:

;---------------------- Check ring to see if it is still empty...
			mov     dx, pAS.io_base
			add     dx, REG_CMD+EISA_790
			mov     al, CMD_RD2+CMD_PAGE1             
			out     dx, al                  ; Select page 1

			add     dx, REG_CURR - REG_CMD
			in      al, dx                  ; Get Curr page ptr
			mov     ah, al                  ; AH == CURR

			add     dx, REG_CMD - REG_CURR
			mov     al, CMD_RD2+CMD_PAGE0
			out     dx, al                  ; Select page 0

			add     dx, REG_BNRY - REG_CMD
			in      al, dx
			inc     al                      ; AL == BNRY+1

			cmp     pAS.pstop_hold, al
			jne     not_at_end_of_buf
			mov     al, pAS.pstart_hold

not_at_end_of_buf:      cmp     al, ah                  ; If BNRY+1 == CURR,
			je      RingEmpty               ; ring is empty
			jmp     RingNotEmpty

RingEmpty:              mov     dx, pAS.io_base
			add     dx, REG_ISR+EISA_790
			mov     al, ISR_PRX+ISR_ERW     ; Clear ISR int
			out     dx, al

			cmp     pAS.ring_ovw, 1
			jnz     NearCheckNextInt

			mov     dx, pAS.io_base
			add     dx, REG_ISR+EISA_790
			mov     al, ISR_OVW
			out     dx, al
			mov     pAS.ring_ovw, 0

			mov     dx, pAS.io_base
			add     dx, REG_BNRY+EISA_790   ; Read then write BNRY
			in      al, dx                  ; if there was OVW.
			out     dx, al

NearCheckNextInt:       jmp     CheckNextInt

;---------------------- Handle Early Packet Receive
ifndef  EZSTART
	Public  HandleERW
endif
HandleERW:
			mov     al, ISR_ERW             ; Write ISR
			out     dx, al

			test    pAS.receive_mask, EARLY_RX_ENABLE
			je      NearCheckNextInt

			mov     ah, pAS.local_nxtpkt_ptr
			xor     al, al

			movzx   esi, ax
			shr     ax, 5                   ; set up page bits
			mov     dx, pAS.io_base
			add     dx, EISA_RAM
			in      al, dx
			push    dx
			push    ax
			and     al, NOT EISA_RAM_PAGE_MASK
			or      al, ah                  ; set page
			out     dx, al
			and     si, pAS.page_offset_mask
ifdef CODE_386
			add     esi, pAS.ram_access
else
			mov     ax, word ptr pAS.ram_access+2
			mov     es, ax
endif

			test    pAS.adapter_flags, EARLY_RX_FRAME
			jz      CheckErxState
			movzx   ecx, pAS.erx_frame_size
			and     pAS.adapter_flags, NOT EARLY_RX_COPY
			jmp     ERWPhysicalAdd
CheckErxState:
			mov     ah, pAS.local_nxtpkt_ptr
			mov     cx, pESI.Eth8023Size    ; Get size of frame.
			xchg    cl, ch                  ; Put in Intel format . . .
			mov     bh, pESI.EthDestAdd     ; Check this frame for MC or BC

			cmp     cx, MAX_8023_SIZE
			jbe     GotFrameSize            ; If size is > MAX_8023_SIZE,

			test    pAS.receive_mask, PKT_SIZE_NOT_NEEDED
			jz      ERWCheckNextInt
			mov     cx, CRC_SIZE            ; will subtract later
			jmp     FrameSizeOk             ; prior to UMReceivePkt

GotFrameSize:
			add     cx, 18                  ; Add 802.3 header size + CRC
			cmp     cx, 64
			jae     FrameSizeOk
			mov     cx, 64                  ; Pad up short frames.

FrameSizeOk:
			test    bh, 1                   ; Check MSB of dest addr for br/mu/cast.
			jz      CheckSize
			test    pAS.receive_mask, ACCEPT_MULTI_PROM
			jnz     CheckSize       ; If Promiscuous multicast
			call    CheckMultiAdd   ; mode, skip address check.
			cmp     rAX, SUCCESS
			jne     ERWCheckNextInt
CheckSize:
			or      pAS.adapter_flags, EARLY_RX_FRAME
			mov     dx, pAS.io_base
			add     dx, REG_RCNTH+EISA_790
			in      al, dx
			mov     ah, al
			dec     dx
			in      al, dx
			mov     dx, cx
			sub     dx, ax
IFDEF CODE_386
			cmp     dx, 64
ELSE
			cmp     dx, 128
ENDIF
			jb      ERWPhysicalAdd

			mov     pAS.erx_frame_size, cx
			mov     ax, cx
			shr     ax, 2           ; divide by 4

			mov     dx, cx
			shr     dx, 1           ; divide by 2
			add     ax, dx          ; 3/4 count
IFDEF CODE_386
			mov     dx, cx
			shr     dx, 3           ; divide by 8
			add     ax, dx          ; 7/8 count
ENDIF

			shr     ax, 4
			mov     dx, pAS.io_base
			add     dx, REG_ERWCNT+EISA_790
			out     dx, al          ; reprogram ERW count
			jmp     ERWCheckNextInt

;---------------------- Process packet
ERWPhysicalAdd:

;                       mov     dx, pAS.io_base
;                       add     dx, REG_ERWCNT+EISA_790
;                       mov     al, DEFAULT_ERX_VALUE
;                       out     dx, al

;                       mov     dx, pAS.io_base
;                       add     dx, REG_ISR+EISA_790
;                       mov     al, ISR_ERW
;                       out     dx, al          ; clear ERW int.

			xor     bx, bx
			add     esi, NIC_HEADER_SIZE
			sub     cx, CRC_SIZE
			call    UM_Receive_Packet                       

; wait for packet to finish
			push    ax
			mov     dx, pAS.io_base
			add     dx, REG_ISR+EISA_790 ; Get interrupt status
erw_wait_for_rx_fini:
			in      al, dx
			test    al, ISR_PRX+ISR_RXE
			je      erw_wait_for_rx_fini
			pop     ax

			cmp     ax, SUCCESS
			jne     ERW_errors

;---------------------- Update BNRY
			mov     ah, pAS.local_nxtpkt_ptr
			xor     al, al
			movzx   esi, ax
			shr     ax, 5                   ; set up page bits
			mov     dx, pAS.io_base
			add     dx, EISA_RAM
			in      al, dx
			and     al, NOT EISA_RAM_PAGE_MASK
			or      al, ah                  ; set page
			out     dx, al
			and     si, pAS.page_offset_mask
ifdef CODE_386
			add     esi, pAS.ram_access
else
			mov     ax, word ptr pAS.ram_access+2
			mov     es, ax
endif
			mov     al, pESI.EthRStat
			test    al, RSR_PRX
			jz      ERWCheckNextInt         ; receive error

			mov     al, pESI.EthNxtPkt
			mov     pAS.local_nxtpkt_ptr, al

			dec     al
			cmp     al, pAS.pstart_hold
			jnb     erw_bnry_ok
			mov     al, pAS.pstop_hold
			dec     al
erw_bnry_ok:
			mov     dx, pAS.io_base
			add     dx, REG_BNRY+EISA_790
			out     dx, al
ERWCheckNextInt:
			pop     ax
			pop     dx
			out     dx, al                  ; restore page
			jmp     CheckNextInt

ERW_errors:
			cmp     ax, PENDING
			jne     ERW_events_disabled
			or      pAS.adapter_flags, RX_STATUS_PENDING
			jmp     ERWCheckNextInt
ERW_events_disabled:
			pop     ax
			pop     dx
			out     dx, al                  ; restore page
			jmp     ServEvDone

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Handle Transmit Error
	Public  HandleTXE
HandleTXE:
			mov     al, ISR_TXE
			out     dx, al
			add     dx, REG_TSR - REG_ISR
			in      al, dx          ; Get transmit status 
			test    al, TSR_ABT         ; Check max collisions
			jz      CheckUnderrun  ; 
			mov     rAX, MAX_COLLISIONS ; UM_Send_Complete status

;---------------------- Update MAX_COLLISIONS counter
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_max_collisions
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_max_collisions
			add     errptr es:[bx], 1
			pop     es
endif
			jmp     TransmitErrorDone

;---------------------- Check FIFO underrun
CheckUnderrun:          test    al, TSR_FU
			jz      CheckTxRetry
			mov     rAX, FIFO_UNDERRUN

;---------------------- Update FIFO_UNDERRUN counter
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_underruns
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_underruns
			add     errptr es:[bx], 1
			pop     es
endif
			xor     ebx, ebx
			mov     bx, pAS.max_packet_size
			cmp     pAS.xmit_threshold, rBX
			jae     CheckTxRetry
			add     pAS.xmit_threshold, DEFAULT_ETX_VALUE

CheckTxRetry:
			dec     pAS.tx_retry
			jz      ResetTxRetryCount
IFDEF EZSTART
			call    EBM_SendPacket
ELSE
			call    SendPacket
ENDIF
			jmp     CheckNextInt
ResetTxRetryCount:
			mov     pAS.tx_retry, DEFAULT_TX_RETRIES
			jmp     TransmitErrorDone

;---------------------- Handle Successful Packet Transmit
	Public HandlePTX
HandlePTX:
			mov     pAS.tx_retry, DEFAULT_TX_RETRIES
			mov     al, ISR_PTX         ; Write ISR
			out     dx, al

			add     dx, REG_TSR - REG_ISR
			in      al, dx
			test    al, TSR_COL
ifdef   EZSTART
			jnz     GetCollisionCount
			push    ax
			mov     al, 0
			call    UpdateCollisionTable
			pop     ax
			jmp     CheckCRS
else
			jz      CheckCRS
endif
GetCollisionCount:
			push    ax
			add     dx, REG_NCR - REG_TSR
			xor     ax, ax
			in      al, dx
ifdef   EZSTART
;                       call    UpdateCollisionTable
endif
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_total_collisions
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_total_collisions
			add     errptr es:[bx], 1
			pop     es
endif
ContinueCollisionCount:
			cmp     al, 1
			pop     ax
			ja      IncMultCollisions
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_one_collision
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_one_collision
			add     errptr es:[bx], 1
			pop     es
endif
			jmp     CheckCRS

IncMultCollisions:
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_mult_collisions
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_mult_collisions
			add     errptr es:[bx], 1
			pop     es
endif

CheckCRS:
			test    al, TSR_CRS
			jz      CheckOWC
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_carrier_lost
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_carrier_lost
			add     errptr es:[bx], 1
			pop     es
endif

CheckCDH:
			test    al, TSR_CDH
			jz      CheckOWC
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_CD_heartbeat
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_CD_heartbeat
			add     errptr es:[bx], 1
			pop     es
endif

CheckOWC:
			test    al, TSR_OWC
			jz      XmitErrorCheckDone
ifdef   CODE_386
			mov     ebx, pAS.ptr_tx_ow_collision
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_tx_ow_collision
			add     errptr es:[bx], 1
			pop     es
endif

XmitErrorCheckDone:
			mov     rAX, SUCCESS     ; Set UM_Send_Complete status

;---------------------- Call upper MAC layer
;PUBLIC  TransmitErrorDone
TransmitErrorDone:
			push    eax
			movzx   eax, pAS.tx_head
			inc     al
			cmp     al, byte ptr pAS.num_of_tx_buffs
			jne     tx_head_ok
			xor     al, al

tx_head_ok:
			mov     pAS.tx_head, al
			dec     pAS.tx_count
			je      NoXmitsPending
IFDEF EZSTART
			call    EBM_SendPacket
ELSE
			call    SendPacket
ENDIF

NoXmitsPending:         
			pop     eax                      ; Restore status
			call    UM_Send_Complete
			cmp     ax, EVENTS_DISABLED     ; If events dis.,
			jne     PTXCheckNextInt         ; Stop all processing
							; and return.
			jmp     ServEvDone
PTXCheckNextInt:        jmp     CheckNextInt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;---------------------- Handle Receive Error
	Public  HandleRXE
HandleRXE:              
			mov     al, ISR_RXE + ISR_ERW
			out     dx, al
			add     dx, REG_RSR - REG_ISR
			in      al, dx          ; Get receive status 
			test    al, RSR_CRC
			jz      CheckFAE

;---------------------- Update CRC Error Counter
			push    eax
			add     dx, REG_CNTR1 - REG_RSR
			xor     eax, eax
			in      al, dx
ifdef   CODE_386
			mov     ebx, pAS.ptr_rx_CRC_errors
			add     errptr [ebx], errAX
else
			push    es
			les     bx, pAS.ptr_rx_CRC_errors
			add     errptr es:[bx], errAX
			pop     es
endif
			pop     eax

CheckFAE:               test    al, RSR_FAE
			jz      CheckFO

;---------------------- Update Frame Alignment Error Counter
			push    eax
			mov     dx, pAS.io_base
			add     dx, REG_CNTR0+EISA_790
			xor     eax, eax
			in      al, dx
ifdef   CODE_386
			mov     ebx, pAS.ptr_rx_align_errors
			add     errptr [ebx], errAX
else
			push    es
			les     bx, pAS.ptr_rx_align_errors
			add     errptr es:[bx], errAX
			pop     es
endif
			pop     eax

CheckFO:                test    al, RSR_FO
			jz      CheckMPA

;---------------------- Update Rx Overrrun Error Counter
ifdef   CODE_386
			mov     ebx, pAS.ptr_rx_overruns
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_rx_overruns
			add     errptr es:[bx], 1
			pop     es
endif

CheckMPA:               test    al, RSR_MPA
			jz      RXErrorDone

;---------------------- Update Lost Packets Counter
			push    eax
			mov     dx, pAS.io_base
			add     dx, REG_CNTR2+EISA_790
			xor     eax, eax
			in      al, dx
ifdef   CODE_386
			mov     ebx, pAS.ptr_rx_lost_pkts
			add     errptr [ebx], errAX
else
			push    es
			les     bx, pAS.ptr_rx_lost_pkts
			add     errptr es:[bx], errAX
			pop     es
endif
			pop     eax

RXErrorDone:            test    pAS.receive_mask, ACCEPT_ERR_PACKETS
			jz      DontGetBadPackets
			jmp     HandlePRX
DontGetBadPackets:      jmp     HandlePRX

;---------------------- Handle Ring Overwrite
ifndef  EZSTART
	Public  HandleOVW
endif
HandleOVW:
ifdef   CODE_386
			mov     ebx, pAS.ptr_ring_OVW
			add     errptr [ebx], 1
else
			push    es
			les     bx, pAS.ptr_ring_OVW
			add     errptr es:[bx], 1
			pop     es
endif

OvwCntrPtrZero:         mov     pAS.ring_ovw, 1
			jmp     HandlePRX

;---------------------- Handle Pending DMA Requests
	Public  HandleDMA
HandleDMA:                                             ; dx points to int
			push    edx
			dec     dx
			in      al, dx
			and     al, NOT EISA_CLRD
			out     dx, al                  ; clear ints

			mov     rAX, SUCCESS
			cmp     pAS.rx_pend, 1
			jne     no_rx_dma

			mov     pAS.rx_pend, 0

;---------------------- Update BNRY
			mov     al, pAS.local_nxtpkt_ptr ; Get local_nxtpkt_ptr into AL
			dec     al
			cmp     al, pAS.pstart_hold
			jnb     bnry1_ok
			mov     al, pAS.pstop_hold
			dec     al
bnry1_ok:
			push    dx
			mov     dx, pAS.io_base
			add     dx, REG_BNRY+EISA_790
			out     dx, al
			pop     dx

			mov     rAX, SUCCESS
			call    UM_Receive_Copy_Complete

; unmask receive interrupts
			push    ax
			mov     dx, pAS.io_base
			add     dx, REG_IMR + EISA_790
			mov     al, pAS.imr_hold
			out     dx, al          
			pop     ax

no_rx_dma:
			cmp     pAS.tx_pend, 1
			jne     no_tx_dma

			cmp     pAS.early_tx_pend, 1
			jne     no_tx_dma

			mov     pAS.early_tx_pend, 0
			mov     dx, pAS.io_base          ; turn off early tx checking
			add     dx, EISA_790+REG_CMD
			mov     al, CMD_DISETCH
			out     dx, al            

no_tx_dma:
			pop     edx
			cmp     rAX, EVENTS_DISABLED
			je      ServEvDone
			jmp     CheckNextInt

IsHardwareInt:
			in      al, dx
			and     al, NOT INTCR_SINT
			out     dx, al
			call    UM_Interrupt
			jmp     ServEvDone

	Public  NotNICInterrupt
NotNICInterrupt:
			mov     dx, pAS.io_base
			add     dx, REG_INTCR+EISA_790
			in      al, dx
			test    al, INTCR_SINT
			mov     ax, NOT_MY_INTERRUPT
			jne     IsHardwareInt

; pma 16 9/20/93 return success sometimes
			cmp     pAS.servicing_ints, 0
			je      NotMyInt
			mov     pAS.servicing_ints, 0

ServEvDone:             mov     rAX, SUCCESS

NotMyInt:
ifndef CODE_386
			pop     es
			pop     ds
endif
IFDEF CODE_386
			pop     edx
			pop     ecx
			pop     ebx
ELSE
			mov     bx, ax
			pop     eax
			mov     ax, bx
			pop     edi
			pop     esi
			pop     edx
			pop     ecx
			pop     ebx
ENDIF
			ret

ASM_EBM_PROC_END        LM_Service_Events

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Close_Adapter        Closes adapter whose adapter structure is
;                               indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Close_Adapter

			push    ecx
			push    dx
			cmp     pAS.adapter_status, NOT_INITIALIZED
			jne     StatusOK
			mov     ax, ADAPTER_NOT_INITIALIZED
			jmp     NoStatusChange
					
StatusOK:               mov     dx, pAS.io_base
			add     dx, REG_CMD+EISA_790
			mov     al, CMD_STP+CMD_RD2
			out     dx, al
			add     dx, REG_ISR - REG_CMD
			mov     ecx, 1600               ; Each iteration of the following
LM_CA_wait:                                             ; loop is 1.0 uS minimum. We
			in      al, dx                  ; need 1.6 mS delay, so set up
			in      al, dx                  ; a loop count of 1600.
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			in      al, dx
			test    al, ISR_RST
			jnz     LM_CA_NIC_Reset
			loop    LM_CA_wait

LM_CA_NIC_Reset:        mov     pAS.adapter_status, CLOSED
			call    UM_Status_Change
			mov     rAX, SUCCESS             ; Set return code
NoStatusChange:
			pop     dx
			pop     ecx
			ret
ASM_EBM_PROC_END        LM_Close_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Open_Adapter         Opens adapter whose adapter structure is
;                               indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Open_Adapter

			push    cx
			push    dx
			cmp     pAS.adapter_status, NOT_INITIALIZED
			jne     CheckStat01
			mov     ax, ADAPTER_NOT_INITIALIZED
			jmp     LM_OADone
CheckStat01:            cmp     pAS.adapter_status, INITIALIZED
			je      OKToOpen
			cmp     pAS.adapter_status, OPEN
			je      AlreadyOpen
DoInit:
IFDEF EZSTART
			call    EBM_LM_Initialize_Adapter
ELSE
			call    LM_Initialize_Adapter
ENDIF
			cmp     rAX, SUCCESS
			je      OKToOpen
			mov     ax, OPEN_FAILED
			mov     pAS.adapter_status, FAILED
			jmp     LM_OADone
OKToOpen:               mov     dx, pAS.io_base
			add     dx, REG_CMD+EISA_790
			mov     al, CMD_STA+CMD_RD2
			out     dx, al

			mov     dx, pAS.io_base
			add     dx, REG_TCR+EISA_790
			mov     al, 0
			mov     cx, pAS.mode_bits
			test    cx, MANUAL_CRC
			jz      OpenAdap01
			mov     al, TCR_CRC
OpenAdap01:             out     dx, al

			mov     pAS.adapter_status, OPEN
			call    UM_Status_Change

AlreadyOpen:            mov     rAX, SUCCESS             ; Set return code
LM_OADone:              pop     dx
			pop     cx
			ret

ASM_EBM_PROC_END        LM_Open_Adapter

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Interrupt_Req        Generates a hardware interrupt from the
;                               adapter indicated by DS:BP.
;
;       Entry:  DS:BP   Pointer to adapter structure
;
;       Exit:   AX      SUCCESS
;                       INVALID_FUNCTION if hardware interrupts are not
;                                        supported by the adapter.
;                       OUT_OF_RESOURCES if adapter has been disabled
;                                        by LM_Disable_Adapter.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_EBM_PROC    LM_Interrupt_Req

		push    dx
		test    pAS.adapter_flags, ADAPTER_DISABLED
		mov     ax, OUT_OF_RESOURCES
		jnz     IntReqDone

		mov     dx, pAS.io_base
		add     dx, REG_INTCR+EISA_790
		in      al, dx
		or      al, INTCR_SINT
		out     dx, al
		mov     rAX, SUCCESS

IntReqDone:
		pop     dx
		ret

ASM_EBM_PROC_END        LM_Interrupt_Req

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
ifndef  EZSTART
public  CheckMultiAdd
endif
CheckMultiAdd   proc    near
			push    esi
			push    edi
			push    edx
			push    ecx
			push    ebx
ifndef CODE_386
			push    ds
			push    es
endif

			mov     ecx, MC_TABLE_ENTRIES+1  ; # of MC table entries
							; + broadcast address
							; entry.
			mov     edi, esi
			add     edi, NIC_HEADER_SIZE ;ES:SI->dest. add.
			lea     esi, pAS.bc_add  ; Start with b'cast
			test    pAS.receive_mask, ACCEPT_BROADCAST
			jnz     DontSkipBCAdd
			dec     ecx                     ; Decrement entry cnt
			lea     esi, pAS.mc_table  ; Skip b'cast entry
DontSkipBCAdd:
			cld

GoopLoop:               push    esi
			push    edi
			push    ecx
			mov     ecx, 6
			repz    cmpsb
			pop     ecx
			pop     edi
			pop     esi
			jnz     TryNextAdd
			cmp     byte ptr [esi+6], 0h     ; If inst. count = 0,
							; entry is invalid.
			je      AddHas0Cnt
			mov     rBX, SUCCESS
			jmp     CheckMADone     ; All Done

TryNextAdd:             add     esi, 7           ; Point to next address
			loop    GoopLoop        ; Check all addresses
						; If all entries checked and
						; no matches, bail out.

AddHas0Cnt:             mov     rBX, OUT_OF_RESOURCES

CheckMADone:
			mov     rAX, rBX        ; Get return code into AX
ifndef CODE_386
			pop     es
			pop     ds
endif
			pop     ebx              
			pop     ecx
			pop     edx
			pop     edi
			pop     esi
			ret
CheckMultiAdd           endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; LM_Ram_Test           Performs two tests:
;                       1) Tests RAM space for RAM and ROM
;                       2) If test #1 passes, enables RAM and tests
;                          RAM integrity.
;
;       On Call:        DS:BP -> to Adapter Structure
;
;       Return:         AX = Return Code
;
;                               Return Codes:
;                               SUCCESS
;                               RAM_TEST_FAILED

ASM_EBM_PROC    LM_Ram_Test

		push    ebx
		push    ecx
		push    edx
		push    edi
		push    esi     ; Watch Out for Stack Order when making changes!
ifdef CODE_386
		mov     edi, pAS.ram_access
else
		push    es
		mov     es, word ptr pAS.ram_access+2
		movzx   edi, word ptr pAS.ram_access
endif

		movzx   ecx, pAS.ram_usable
		shl     ecx, 10d
		call    disable_ram

TestROMSignature:
		mov     ax, pEDI
		cmp     ax, ROM_SIGNATURE
		jne     NotARom
		jmp     GotROMSignature
NotARom:
		sub     cx, MIN_ROM_SIZE
		jcxz    PassedROMTest
		add     edi, MIN_ROM_SIZE
		jmp     TestROMSignature
PassedROMTest:
		mov     ax, RAM_PATTERN_1
StartSpaceTest:
ifdef CODE_386
		mov     edi, pAS.ram_access
else
		mov     di, word ptr pAS.ram_access
endif
		mov	bx, 8192
		movzx   ecx, bx         ; Get RAM window size in CX
		shr     cx, 1           ; Divide by two for words.
VerifySpace:
		mov     dx, pEDI        ; Save original word
					; in case of failure
		stosw                                       
		cmp     ax, pEDI-2
		je      FailedSpaceVerify
		loop    VerifySpace

		cmp     ax, RAM_PATTERN_1
		jne     SpacePatternTwo
		mov     ax, RAM_PATTERN_2
		jmp     StartSpaceTest
SpacePatternTwo:
		cmp     ax, RAM_PATTERN_2
		jne     TestRAM
		mov     ax, RAM_PATTERN_3
		jmp     StartSpaceTest
TestRAM:                
		call    enable_ram
		mov     dx, pAS.io_base
		add     dx, EISA_RAM
		mov     si, 0

TestNextBank:
		cmp     si, 4
		mov     rAX, SUCCESS
		jae     RamTestPages

		in      al, dx           ; set page
		and     ax, NOT EISA_RAM_PAGE_MASK
		or      ax, si
		out     dx, al
		inc     si
		mov     eax, RAM_PATTERN_1 SHL 16 + RAM_PATTERN_1

StartRamTest:
ifdef CODE_386
		mov     edi, pAS.ram_access
else
		mov     di, word ptr pAS.ram_access
endif
		movzx   ecx, bx         ; Get RAM window size in CX
		shr     ecx, 2          ; Divide by four for dwords.
VerifyRAM:
		stosd
		cmp     eax, pEDI-4
		jne     FailedRAMVerify
		loop    VerifyRAM

		cmp     eax, RAM_PATTERN_1 SHL 16 + RAM_PATTERN_1
		jne     RamPatternTwo
		mov     eax, RAM_PATTERN_2 SHL 16 + RAM_PATTERN_2
		jmp     StartRamTest
RamPatternTwo:                   
		cmp     eax, RAM_PATTERN_2 SHL 16 + RAM_PATTERN_2
		jne     TestNextBank
		mov     eax, RAM_PATTERN_3 SHL 16 + RAM_PATTERN_3
		jmp     StartRamTest

RamTestPages:
		mov     si, 0

FillNextBank:
		cmp     si, 4
		jae     VerifyRamPages                                                               

		in      al, dx           ; set page
		and     ax, NOT EISA_RAM_PAGE_MASK
		or      ax, si
		out     dx, al
		inc     si

ifdef CODE_386
		mov     edi, pAS.ram_access
else
		mov     di, word ptr pAS.ram_access
endif
		movzx   ecx, bx         ; Get RAM window size in CX
		shr     cx, 1           ; Divide by two for words.
		mov     ax, si

		rep     stosw
		jmp     FillNextBank

VerifyRamPages:
		mov     si, 0

CheckNextBank:
		cmp     si, 4
		jae     RamTestSuccess

		in      al, dx           ; set page
		and     ax, NOT EISA_RAM_PAGE_MASK
		or      ax, si
		out     dx, al
		inc     si

ifdef CODE_386
		mov     edi, pAS.ram_access
else
		mov     di, word ptr pAS.ram_access
endif
		movzx   ecx, bx         ; Get RAM window size in CX
		shr     cx, 1           ; Divide by two for words.
		mov     ax, si

		repe    scasw
		jcxz   CheckNextBank
		jmp    FailedRAMVerify

RamTestSuccess:                  
; get parameters
ifndef  CODE_386
		pop     es
endif
		pop     esi
		push    esi
ifndef  CODE_386
		push    es
endif
		
;
; Check Bus Master Enable bit
;
		mov     dx, pAS.io_base
		add     dx, REG_BPR+EISA_790
		in      al, dx
		test    al, BPR_BMSTR
		jnz     dma_not_working

		or      esi, esi
		jz      dma_not_working ; check for NULL scratchpad pointer

		push	esi
IFDEF CODE_386
		mov	esi, offset MotherBoardID
ELSE
		mov	si, offset MotherBoardID
ENDIF
		mov	dx, 0c80h
		in	eax, dx
		mov	cx, MotherBoardTableSize
		shr	cx, 2

MotherBoardChk:
IFDEF CODE_386
		cmp	dword ptr [esi], 0
		jz	DMATest
		cmp	[esi], eax
ELSE
		cmp	dword ptr cs:[si], 0
		jz	DMATest
		cmp	cs:[si], eax
ENDIF
		jz	NoDMATest
		dec	cx
		jz	DMATest
		add	esi, 4
		jmp	MotherBoardChk

NoDMATest:
		pop	esi
		jmp	dma_not_working
DMATest:
		pop	esi
		mov	dx, pAS.io_base		
; set page 0
		add     dx, EISA_RAM
		in      al, dx
		and     ax, NOT EISA_RAM_PAGE_MASK
		out     dx, al

		mov     dx, pAS.io_base
		add     dx, EISA_790+REG_TCR
		mov     al, 4
		out     dx, al          ; internal loop back
IFDEF EZSTART
		call	EBM_LM_Disable_Adapter
ELSE
		call	LM_Disable_Adapter
ENDIF

		mov     ebx, RAM_PATTERN_1 SHL 16 + RAM_PATTERN_1
		mov	cx, 1000		; counter for DMA test loop
		push	cx
StartDMATest:
; copy pattern to shared ram
		push    es
ifdef CODE_386
		mov     edi, pAS.ram_access
else
		les     di, pAS.ram_access
endif
		mov     eax, ebx        ; get test pattern
		mov     ecx, 50         ; Scratchpad size in dwords
		rep     stosd
IFDEF CODE_386
		mov	word ptr [edi], 0	; 2 bytes of zero at 200
ELSE						; DMA test starts at 202
		mov	word ptr es:[di], 0	; Check the 2-byte zero after
ENDIF						; DMA test to make sure DMA
		pop     es			; does not overwrite them

		call	LoopBackRcv
		call	LoopBackSend

; dma data to scratchpad
		mov     dx, pAS.io_base
		add     dx, EISA_AA
		mov     eax, esi

		out     dx, eax         ; set scratchpad address

		add     dx, EISA_AS-EISA_AA
		mov     eax, 200        ; Scratchpad size in bytes
		or      eax, EISA_SZ_SDMA+EISA_SZ_DIR
		out     dx, eax         ; set size and start dma

		add     dx, EISA_STAT-EISA_AS
		mov     ecx, 2000       ; assume in is 500ns -> 1ms wait
wait_cpy_scrpd:
		in      al, dx
		test    al, EISA_SDMA
		loopnz  wait_cpy_scrpd
		jecxz   near_dma_not_working

; dma data back to shared ram
		add     dx, EISA_AA-EISA_STAT

		mov     eax, esi

		out     dx, eax         ; set scratchpad address

		add     dx, EISA_AS-EISA_AA
		mov     eax, 202
		shl     eax, 16         ; point to page start + 202
		or      eax, 200        ; Scratchpad size in bytes
		or      eax, EISA_SZ_SDMA
		out     dx, eax         ; set size and start dma

		add     dx, EISA_STAT-EISA_AS
		mov     ecx, 2000       ; assume in is 500ns -> 1ms wait
wait_cpy_shram:
		in      al, dx
		test    al, EISA_SDMA
		loopnz  wait_cpy_shram
		jecxz   near_dma_not_working

; verify pattern in shared ram
		push    es
ifdef CODE_386
		mov     edi, pAS.ram_access
		add     edi, 200
		cmp	word ptr [edi], 0
else
		les     di, pAS.ram_access
		add     di, 200
		cmp	word ptr es:[di], 0
endif
		je	compare_data
		pop	es
		jmp	near_dma_not_working

compare_data:
		add	di, 2
		mov     eax, ebx        ; get test pattern
		mov     ecx, 50         ; Scratchpad size in dwords
		repe    scasd
		pop     es
		jne     near_dma_not_working

		cmp     ebx, RAM_PATTERN_1 SHL 16 + RAM_PATTERN_1
		jne     DMAPatternTwo
		mov     ebx, RAM_PATTERN_2 SHL 16 + RAM_PATTERN_2
		jmp     StartDMATest

near_dma_not_working:
		pop	cx
		jmp     dma_not_working

DMAPatternTwo:                   
		cmp     ebx, RAM_PATTERN_2 SHL 16 + RAM_PATTERN_2
		jne     DMATestLoop
		mov     ebx, RAM_PATTERN_3 SHL 16 + RAM_PATTERN_3
		jmp     StartDMATest

DMATestLoop:
		pop	cx
		dec	cx
		jz	dma_working
		push	cx
		mov     ebx, RAM_PATTERN_1 SHL 16 + RAM_PATTERN_1
		jmp	StartDMATest
		
dma_working:
		or      pAS.adapter_flags, USES_PHYSICAL_ADDR   ; enable BM
DMA_Success:
		mov     dx, pAS.io_base
		add	dx, EISA_790+REG_CMD
wait_tx:
		in	al, dx
		test    al, CMD_TXP
		jnz     wait_tx		; wait for tx to complete

		add	dx, REG_ISR - REG_CMD
		in	al, dx
		test	al, ISR_PTX
		jz	no_tx_int
		and	al, ISR_PTX+ISR_TXE
		out	dx, al		; clear tx complete interrupt
no_tx_int:
		call	LoopBackRcv	; receive the last loop back pkt
		in	al, dx
		and	al, ISR_ERW	; clear early receive
		out	dx, al

		add     dx, REG_TCR - REG_ISR
		xor	ax, ax
		out     dx, al          ; normal (no loop back)

		mov     rAX, SUCCESS
		jmp     RAMTestDone

dma_not_working:
		and     pAS.adapter_flags, NOT USES_PHYSICAL_ADDR; disable BM
		jmp     DMA_Success

FailedSpaceVerify:
		mov     pEDI-2, dx
		mov     ax, RAM_CONFLICT
		jmp     RAMTestDone

FailedRAMVerify:
		mov     ax, RAM_TEST_FAILED
		jmp     RAMTestDone

GotROMSignature:
		mov     ax, ROM_CONFLICT

RAMTestDone:
		push    ax
		mov	dx, pAS.io_base
		add	dx, EISA_RAM
		in      al, dx           ; set page 0
		and     ax, NOT EISA_RAM_PAGE_MASK
		out     dx, al
		pop     ax

ifndef CODE_386
		pop     es
endif
		pop     esi
		pop     edi
		pop     edx
		pop     ecx
		pop     ebx
		ret     

ASM_EBM_PROC_END        LM_Ram_Test


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LoopBackSend  Sends a broadcast packet in internal loop back mode
;
;
;       Entry:  DS:BP   Pointer to Adapter Structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoopBackSend	proc	near

	push	ax
	push	dx
	push	edi
	mov     dx, pAS.io_base
	add     dx, EISA_790+REG_CMD

	in      al, dx
	test    al, CMD_TXP
	jnz     lb_send_exit			; exit if still transmitting
IFDEF CODE_386
	mov     edi, pAS.ram_access
	add     edi, 700h			; transmit from offset 700h
	mov     dword ptr [edi], 0ffffffffh	; needs a bcast addr
	mov     word ptr [edi+4], 0ffffh
ELSE
	mov	ax, word ptr pAS.ram_access+2
	push	es
	mov	es, ax
	mov	di, 700h			; transmit from offset 700h
	mov     dword ptr es:[di], 0ffffffffh	; needs a bcast addr
	mov     word ptr es:[di+4], 0ffffh
	pop	es
ENDIF

	add     dx, REG_TPSRL - REG_CMD
	mov     al, 0
	out     dx, al
	add     dx, REG_TPSR - REG_TPSRL
	mov     al, 7
	out     dx, al  		; start transmit at offset 700h
	add     dx, REG_TBCR0 - REG_TPSR
	mov     al, 00h
	out     dx, al
	add     dx, REG_TBCR1 - REG_TBCR0
	mov     al, 3
	out     dx, al  		; transmit 300h bytes
	add     dx, REG_CMD - REG_TBCR1
	mov     al, CMD_STA+CMD_TXP
	out     dx, al

lb_send_exit:
	pop	edi
	pop	dx
	pop	ax
	ret

LoopBackSend	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LoopBackRcv  Update receiver ring ptrs during loop back test
;
;
;       Entry:  DS:BP   Pointer to Adapter Structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoopBackRcv	proc	near
	push	eax
	push	ebx
	push	edx
	push	esi

	mov	dx, pAS.io_base
	add	dx, EISA_790+REG_ISR
	in	al, dx
	and	al, ISR_PRX+ISR_RXE
	jz	lb_ReceiveDone
	out	dx, al		; clear int.

lb_ChkReceive:
	mov	dx, pAS.io_base
	add     dx, EISA_790+REG_CMD
	mov     al, CMD_RD2+CMD_PAGE1             ;
	out     dx, al                  ; Select page 1

	add     dx, REG_CURR - REG_CMD
	in      al, dx                  ; Get Curr page ptr
	mov     ah, al                  ; AH == CURR

	add     dx, REG_CMD - REG_CURR
	mov     al, CMD_RD2+CMD_PAGE0
	out     dx, al                  ; Select page 0

	add     dx, REG_BNRY - REG_CMD
	in      al, dx
	inc     al                      ; AL == BNRY+1

	cmp     pAS.pstop_hold, al
	jne     lb_not_end_of_buf
	mov     al, pAS.pstart_hold

lb_not_end_of_buf:
	cmp     al, ah                  ; If BNRY+1 == CURR,
	jne     lb_RingNotEmpty            ; ring is empty
	jmp     lb_ReceiveDone

lb_RingNotEmpty:
	mov     ah, pAS.local_nxtpkt_ptr
	xor     al, al

	movzx   esi, ax
	shr     ax, 5                   ; set up page bits
	mov     dx, pAS.io_base
	add     dx, EISA_RAM
	in      al, dx
	push    dx			; save page
	push    ax
	and     al, NOT EISA_RAM_PAGE_MASK
	or      al, ah                  ; set page
	out     dx, al
	and     si, pAS.page_offset_mask

ifdef CODE_386
	add     esi, pAS.ram_access
	movzx   ebx, word ptr [esi]
else
	push	es
	mov	ax, word ptr pAS.ram_access+2
	mov	es, ax
	mov     bx, es:[si]             ; Get rx stat in BL,
	pop	es
endif
					; next pkt in BH.
	cmp     bh, pAS.pstop_hold
	jb      lb_ptr_ok
	sub     bh, pAS.pstop_hold
	add     bh, pAS.pstart_hold

lb_ptr_ok:
	mov     pAS.local_nxtpkt_ptr, bh

;---------------------- Update BNRY
	mov     al, bh          ; Get local_nxtpkt_ptr into AL
	dec     al
	cmp     al, pAS.pstart_hold
	jnb     lb_bnry_ok
	mov     al, pAS.pstop_hold
	dec     al
lb_bnry_ok:
	mov     dx, pAS.io_base
	add     dx, REG_BNRY+EISA_790
	out     dx, al

	pop	ax
	pop	dx
	out	dx, ax			; restore page
	jmp	lb_ChkReceive

lb_ReceiveDone:
	pop	esi
	pop	edx
	pop	ebx
	pop	eax
	ret

LoopBackRcv	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       UpdateCounters  Updates error counters to reflect current
;                               NIC stats.
;
;       Entry:  DS:BP   Pointer to Adapter Structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateCounters  proc    near
		push    edx
		push    ebx

		xor     eax, eax
		mov     dx, pAS.io_base
		add     dx, REG_CNTR0+EISA_790          ; CNTR0 = Frame Align Errors
		in      al, dx
ifdef   CODE_386
		mov     ebx, pAS.ptr_rx_align_errors
		add     errptr [ebx], errAX
else
		push    es
		les     bx, pAS.ptr_rx_align_errors
		add     errptr es:[bx], errAX
		pop     es
endif

		inc     dx                      ; REG_CNTR0+1= REG_CNTR1
		in      al, dx                  ; CNTR1 = CRC Errors

RXA0:
ifdef   CODE_386
		mov     ebx, pAS.ptr_rx_CRC_errors
		add     errptr [ebx], errAX
else
		push    es
		les     bx, pAS.ptr_rx_CRC_errors
		add     errptr es:[bx], errAX
		pop     es
endif

		inc     dx                      ; REG_CNTR1+1= REG_CNTR2
		in      al, dx                  ; CNTR2 = Missed Pkt Errors
CRC0:
ifdef   CODE_386
		mov     ebx, pAS.ptr_rx_lost_pkts
		add     errptr [ebx], errAX
else
		push    es
		les     bx, pAS.ptr_rx_lost_pkts
		add     errptr es:[bx], errAX
		pop     es
endif
RxLP:
		mov     rAX, SUCCESS
		pop     ebx
		pop     edx
		ret
UpdateCounters  endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       enable_ram      enables RAM on adapter whose adapter structure is
;                       indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
enable_ram      proc    near
		push    dx
		mov     dx, pAS.io_base
		add     dx, EISA_INT

		in      al, dx
		or      al, EISA_MENB
		out     dx, al

		pop     dx
		mov     rAX, SUCCESS
		ret
enable_ram      endp
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       disable_ram     disables RAM on adapter whose adapter structure is
;                       indicated by DS:BP.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
disable_ram     proc    near
		push    dx

		mov     dx, pAS.io_base
		add     dx, EISA_INT

		in      al, dx
		and     al, NOT EISA_MENB
		out     dx, al

		pop     dx
		mov     rAX, SUCCESS
		ret
disable_ram             endp

ifdef   EZSTART
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       UpdateCollisionTable    Updates Collision Table indicated by
;                               easp.CollTable
;
;       Entry:  AL      Number of collisions for this transmit.
;                       if greater than 15, it will be set to 15.
;               DS:BP   Ptr to adapter structure. pAS.EASP must be valid.
;
;       Exit:   All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateCollisionTable    proc    near
		push    eax
		push    ebx

		cmp     al, 0Fh
		jbe     NoCountAdjust
		mov     al, 0Fh
NoCountAdjust:
		xor     ah, ah
		shl     ax, 2

		push    es
		les     bx, pAS.easp
		add     bx, offset CollTable
		add     bx, ax
		add     dword ptr es:[bx], 1
		pop     es

		pop     ebx
		pop     eax
		ret

UpdateCollisionTable    endp

ASM_EBM_PROC    LM_Put_Config
		mov     rAX, ADAPTER_NO_CONFIG
		ret
ASM_EBM_PROC_END        LM_Put_Config

ASM_EBM_PROC    LM_Microcode_Test
		mov     rAX, SUCCESS
		ret
ASM_EBM_PROC_END        LM_Microcode_Test


ASM_EBM_PROC    LM_Rom_Test
		mov     rAX, SUCCESS
		ret
ASM_EBM_PROC_END        LM_Rom_Test


ASM_EBM_PROC    LM_Get_Soft_Config
;               mov     ax, NO_FIXED_CONFIG
		ret
ASM_EBM_PROC_END        LM_Get_Soft_Config


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Bic_Test     Tests EISA Bus Interface controller chips
;                       571.
;
;               Entry:  pAS     Ptr to adapter structure
;               Exit:   AX      Ret code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_EBM_PROC    LM_Bic_Test
; find eisa io base
		mov     dl, pAS.slot_num
		shl     dx, 12
		add     dx, 0c80h
		mov     pAS.io_base, dx

; needs rewrite to differentiate adapters
		in      al, dx                
		mov     ah, al
		inc     dx
		in      al, dx
		cmp     ax, MANUF_ID                    ; smc encoded
		mov     rAX, SUCCESS
		je      lm_good_bic
		mov     rAX, BIC_REG_ERROR

lm_good_bic:
		ret
ASM_EBM_PROC_END        LM_Bic_Test

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Check_LAN_Addr_ROM
;
;               Entry:  pAS     Ptr to adapter structure
;               Exit:   AX      Ret code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_EBM_PROC    LM_Check_LAN_Addr_ROM

		mov     rAX, SUCCESS
		ret

ASM_EBM_PROC_END LM_Check_LAN_Addr_ROM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Nic_Test     Tests Ethernet Network Interface controller chips
;                       790.
;
;               Entry:  pAS     Ptr to adapter structure
;               Exit:   AX      Ret code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_EBM_PROC    LM_Nic_Test

		push    bx
		push    cx
		push    dx

		mov     al, CMD_PAGE2
		call    Select690Page
		mov     dx, pAS.io_base
		add     dx, REG_ENH+EISA_790
		mov     al, 0
		out     dx, al
		
Test690Nic:

;;; The first test writes a test pattern to the PhysAddrRegs (page 1), then
;;; writes the data pattern inverted to the same regs on page 0. The data
;;; written to the page 1 regs is then compared against the original data
;;; pattern. This test verifies that there is a NIC out there. The offsets
;;; tested are 11h thru 17h.

		mov     al, CMD_PAGE1+CMD_STP
		call    Select690Page
		mov     al, NIC_TEST_PATTERN    ; Get test value
		mov     ah, al                  ; Save test value in AH for comparison.
		mov     bx, REG_PAR0            ; Fill pg 1 regs with test pattern
		mov     cx, 1                   ; 
		call    Fill690Regs
		mov     al, 0FFh                ; Set compare mask.
		call    Comp690RegData
		jc      Nic690RegisterError

		mov     al, CMD_PAGE0+CMD_STP   ; Select page 0
		call    Select690Page
		mov     al, ah                  ; Get test pattern in AL
		not     al                      ; Invert test pattern
		call    Fill690Regs             ; Fill pg 0 regs with inverted pattern
		mov     al, CMD_PAGE1+CMD_STP
		call    Select690Page           ; Switch back to page 1
		mov     al, 0FFh                ; Set compare mask.
		call    Comp690RegData          ; Previous data written to page
		jc      Nic690RegisterError     ; 1 registers should be intact.

;;; The second test verifies data that is read and written on different pages. This
;;; test verifies page 2 access, as well as access to the one of the remaining registers
;;; that were not covered in the first test.

;               mov     al, CMD_PAGE0+CMD_STP
;               call    Select690Page
;               mov     dx, pAS.io_base
;               add     dx, REG_CNTR2
;               in      al, dx                  ; Clear MP count (if any).
;               mov     dx, pAS.io_base
;               mov     ah, 01Fh
;               mov     al, ah                  ; 
;               mov     bx, REG_IMR
;               mov     cx, 1                   ; Fill the IMR with test
;               call    Fill690Regs             ; pattern.
;               mov     al, 01Fh                ; Set compare mask.
;               call    Comp690RegData          ; This data should not compare ok.
;               jnc     Nic690RegisterError
;               mov     al, CMD_PAGE2+CMD_STP
;               call    Select690Page
;               mov     al, 01Fh                ; Set compare mask.
;               call    Comp690RegData
;               jc      Nic690RegisterError     ; The register written on page 0
						; is read accessed on page 2.
		mov     al, CMD_PAGE0+CMD_STP   ; Restore NIC to Page 0.
		call    Select690Page
		mov     rAX, SUCCESS

LmNicTestExit:
		pop     dx
		pop     cx
		pop     bx
		ret

Nic690RegisterError:
		mov     ax, NIC_REG_ERROR
		jmp     LmNicTestExit

ASM_EBM_PROC_END        LM_Nic_Test

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       Select690Page   Selects 8390/690 register page
;
;               Entry:  AL =    CMD_PAGE0
;                               CMD_PAGE1
;                               CMD_PAGE2
;
;               Exit:   All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef   XLM_DEBUG
PUBLIC  Select690Page
endif
Select690Page   proc    near

		push    ax
		push    dx
		mov     dx, pAS.io_base 
		add     dx, REG_CMD+EISA_790
		or      al, CMD_RD2
		out     dx, al
		pop     dx
		pop     ax
		ret

Select690Page   endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       Fill690Regs     Fills 690 regs with single byte pattern
;
;       Entry:  pAS     Ptr to Adapter structure
;               AL      Data pattern
;               CX      Count of registers to fill
;               BX      Starting offset from I/O base address
;
;       Exit:   All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef   XLM_DEBUG
PUBLIC  Fill690Regs
endif
Fill690Regs     proc    near

		push    cx
		push    dx

		mov     dx, pAS.io_base
		add     dx, EISA_790
		add     dx, bx
FillLoop:
		out     dx, al
		inc     dx
		loop    FillLoop

		pop     dx
		pop     cx
		ret

Fill690Regs     endp            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       Comp690RegData  Compares data in 690 regs with single byte pattern
;                       in AH.
;
;       Entry:  pAS     Ptr to Adapter structure
;               AL      Bitwise Mask, 0 = mask all, FFh = mask none.
;               AH      Data pattern
;               CX      Count of registers to Comp
;               BX      Starting offset from I/O base address
;
;       Exit:   CARRY   Set if miscompare occurred.
;                       All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef   XLM_DEBUG
PUBLIC  Comp690RegData
endif
Comp690RegData  proc    near

		push    ax
		push    bx
		push    cx
		push    dx

		mov     dx, pAS.io_base
		add     dx, EISA_790
		add     dx, bx          ; Add offset to I/O base
		mov     bx, ax          ; Save mask in BL
CompLoop:
		in      al, dx
		and     al, bl          ; Mask off unwanted bits.
		inc     dx
		cmp     al, ah
		jne     CompDataError
		loop    CompLoop
		clc
Comp690DataExit:
		pop     dx
		pop     cx
		pop     bx
		pop     ax
		ret
CompDataError:
		stc
		jmp     Comp690DataExit
Comp690RegData  endp

endif

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
IFDEF EZSTART
public	EBM_AutoMediaDetect
EBM_AutoMediaDetect proc near
ELSE
public AutoMediaDetect
AutoMediaDetect	proc	near
ENDIF
IFDEF CODE_386
	push	eax
ELSE
	push	ax			; 1+ Save Registers
ENDIF
	push	bx			; 2+
	push	cx			; 3+
	push	dx			; 4+

IFDEF EZSTART
	call	EBM_LM_Disable_Adapter
ELSE
	call	LM_Disable_Adapter
ENDIF
	mov	dx, pAS.io_base		; Unused bit in EISA_ROM register
	add	dx, EISA_ROM		; 0 = AutoMediaDetect
	in	al, dx			; 1 = StarLan
	test	al, 08h
	jz	ContinueAutoMediaDetect
	; If we get here we are on StarLan
	add	dx, EISA_790 + REG_HWR - EISA_ROM	; Select HWR
	in	al, dx
	or	al, HWR_SWH
	out	dx, al					; Select page 1
	add	dx, REG_GCR - REG_HWR
	in	al, dx
	and	al, NOT (GCR_LITE + GCR_GPOUT)		; Force GCR_GPOUT and GCR_LITE to zero
	out	dx, al
;	add	dx, REG_HWR - REG_GCR			; Select HWR
;	in	al ,dx
;	and	al, NOT (HWR_SWH)			; Back to page 0
;	out	dx, al
	jmp	AMD_Exit				; Done


ContinueAutoMediaDetect:
Chk_LinkStatus_Xmit:			; This entry point is for a tri-con
	call	DisableLoopback		; Disable the loopback bit in TCR reg
	push	bx			; 2a+  BX = original TCR state
	call	LinkStatus_585		; 790/795 boards, 585
	pop	bx			; 2a-  BL = Initial TCR state
	call	RestoreTcrReg		; Restore TCR state

AMD_Exit:				; Reset media_type again
	mov	dx, pAS.io_base
	add     dx, EISA_790 + REG_HWR
	in      al, dx
	or      al, HWR_SWH
	out     dx, al

	add     dx, REG_GCR - REG_HWR
	in      al, dx
	and     ax, CNFG_MEDIA_TYPE_MASK
	cmp     al, 3
	jne     not_bnc1
	mov     al, MEDIA_BNC_UTP
not_bnc1:
	mov     pAS.media_type, ax

	pop	dx			; 4- Restore registers
	pop	cx			; 3-
	pop	bx			; 2-
IFDEF CODE_386
	pop	eax
ELSE
	pop	ax			; 1-
ENDIF
	ret				; Exit
IFDEF EZSTART
EBM_AutoMediaDetect	endp
ELSE
AutoMediaDetect		endp
ENDIF

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
	mov	ah, BNC_585_OFF
	call	BNC_585_On_Off

	mov	dx, pAS.io_base		; Select I/O base
	add	dx, EISA_790+REG_CMD	; Select Command register
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
	jz	DoTxTest		; If no link to Tx test for AUI
	mov	ah, BNC_585_ON		; UTP doesn't need BNC, but we turn it on anyway
	call	BNC_585_On_Off		; in case the user switches to BNC
	jmp	LS_Exit
DoTxTest:
	; try to xmit a frame here.
	; if Carrier Sense Lost, then BNC else AUI
	call XmitTest

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
	add	dx, EISA_790+REG_HWR	; Hardware Support Register

	in	al, dx			;
	or	al, HWR_SWH		; Config Registers bit
	out	dx, al			;

	add	dx, REG_GCR - REG_HWR	; General Control Register
	in	al, dx			; Get current state
	and	al, not GCR_GPOUT	; Disable BNC power
	or	al, GCR_LITE		; Make sure S10 is OFF!
	or	al, ah			; Set new state
	out	dx, al			; Enable state

	add	dx, REG_HWR-REG_GCR	; Hardware Support Register
	in	al, dx
	and	al, NOT HWR_SWH
	out	dx, al			; Restore original REG_HWR
IFDEF CODE_386
	push	ecx
	mov	ecx, 1000h
ELSE
	mov	cx, 1000h
ENDIF
BNC_585_Loop:
	in	al, dx
	loop	BNC_585_Loop
IFDEF CODE_386
	pop	ecx
ENDIF
	ret				; Exit
BNC_585_On_Off	endp

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
	add	dx, EISA_790+REG_CMD	; Select Command register
	mov	al, CMD_PAGE2		; Select page 2 to read TCR reg
	out	dx, al			; Set new page

	add	dx, REG_TCR - REG_CMD	; Get TCR register contents
	in	al, dx			; 
	mov	bl, al			; BL = TCR current state

	add	dx, REG_CMD - REG_TCR	; Select Command register
	mov	al, CMD_PAGE0		; Select page 3 for Manchester Reg
	out	dx, al			; Set new page

	add	dx, REG_TCR - REG_CMD	; Disable loopback mode
;	xor	al, al			; Normal mode (no loopback)
	and	al, NOT (TCR_LB1 + TCR_LB0)
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
	add	dx, EISA_790+REG_TCR	; Select TCR register
	mov	al, bl			; Get original state
	out	dx, al			; Set state

	ret				; Exit
RestoreTcrReg	endp

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
		db	' -WSKRTDDZPMBGSFMTJGVPGHLGHL-'			; 29
DUMMY_LEN	equ	$ - dummy_frame


PUBLIC XmitTest
XmitTest	proc	near
IFDEF CODE_386
	push	esi
	push	edi
ELSE
	push	si
	push	di			; 1+
ENDIF

IFDEF CODE_386
	mov	ecx, DUMMY_LEN
	shr	ecx, 1	
	mov	edi, pAS.ram_access
	mov	esi, offset dummy_frame
	rep	movsw
ELSE
	mov	cx, DUMMY_LEN		; Transmit 32 words of data
	shr	cx, 1
	mov	ax, word ptr pAS.ram_access+2	; ES:DI -> Shared RAM Dest address
	mov	es, ax
	xor	di, di

	push	ds			; 4a+

	mov	ax, cs			;
	mov	ds, ax			; Frame in code segment
	mov	si, offset dummy_frame	; DS:SI -> Dummy frame to xmit

	rep	movsw			; Word move

	pop	ds			; 4a-
ENDIF
XmitBuiltFrame:
	call	XmitDummy		; Transmit the dummy frame with
					; max collisions timeout (300ms)

	test	al, TSR_CRS		; Carrier sense lost?
	jz	XmitTestExit		; JIF no, AUI active, Turn BNC ON

	mov	ah, BNC_585_ON		; Select BNC ON
	call	BNC_585_On_Off		; Enable BNC power

XmitTestExit:
IFDEF CODE_386
	pop	edi
	pop	esi
ELSE
	pop	di			; 1-
	pop	si
ENDIF
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
	push	ecx			; 2+ Save media type

	mov	cx, 400h		; Dummy frame length must be this
					; long for accurate results.
	mov	dx, pAS.io_base		; Seclect the base I/O address
	add	dx, EISA_790 + REG_ISR	; Set to Transmit Status register
	mov	al, 0FFh		; Clear Interrupt Status register
	out	dx, al

	add	dx, REG_TPSR - REG_ISR		; Select xmit Page Start Reg
	xor	ax, ax				; Use the first tx buffer
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
	mov	bx, 50			; Outer loop = 300ms total

SetupLoopCnt:				; Pseudo deadman floating face down
	mov	ecx, 0ffffh		; Loop count = 64k

TestLoop:
	in	al, dx			; Get interrupt status
	test	al, ISR_TXE+ISR_PTX
	loopz	TestLoop		; Loop if nothing

	test	al, ISR_TXE+ISR_PTX	; Status yet? 
	jnz	XmitDummyExit		; JIF yes

	dec	bx			; Next timeout iteration
	jnz	SetupLoopCnt		;

XmitDummyExit:
	mov	ah, al			; AH = Interrupt status
	add	dx, REG_TSR - REG_ISR	;
	in	al, dx			; AL = Transmit status

	mov	bx, ax			; Save return code
	mov	dx, REG_CMD-REG_TSR
	mov	al, CMD_STP+CMD_RD2
	out	dx, al

	add     dx, REG_ISR - REG_CMD
	mov     ecx, 1600               ; Each iteration of the following
XD_STP_wait:                            ; loop is 1.0 uS minimum. We
	in      al, dx                  ; need 1.6 mS delay, so set up
	in      al, dx                  ; a loop count of 1600.
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	in      al, dx
	test    al, ISR_RST
	jnz     XD_STP_Reset
	loop    XD_STP_wait

XD_STP_Reset:
	mov	al, 0ffh
	out	dx, al
	mov	ax, bx
	pop	ecx			; 2- Restore media type
	pop	bx			; 1- Restore iteration flag
	ret				; Exit
XmitDummy	endp
