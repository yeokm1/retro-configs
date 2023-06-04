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
; File:         lft_ext.asm
;
; Description:  9232 Extended LMAC functions to support EZStart
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lft_ext.avm  $
;
;   Rev 1.4   10 Feb 1995 11:45:12   WATANABE
;1. Fixed loopback test in lft_ext.asm.  Software appended CRC bit is not set
;   properly in the control byte of the packet data area.
;   
;2. Added copyright banner to all files.   
;
;   
;
;   Rev 1.3   02 Feb 1995 10:19:24   WATANABE
;1. Added code to save and restore node address in LM_Loopback_test for
;   EZStart, so when EZStart gets executed again without reboot, the 
;   node address will be correct.
;
;   
;
;   Rev 1.2   25 Jan 1995 17:52:26   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.1   11 Jan 1995 10:15:52   WATANABE
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


DELAY_LPBK      macro
        LOCAL   delay_loop

        push    ax
        push    cx
        push    dx

        mov     cx, 01000h
delay_loop:
        mov     dx, 061h
        in      ax, dx
        loop    delay_loop

        pop     dx
        pop     cx
        pop     ax

        endm


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Bic_Test     Tests EISA Bus Interface controller chips 574.
;
;               Entry:  pAS     Ptr to adapter structure
;               Exit:   AX      Ret code
;                                 = SUCCESS
;                                 = BIC_REG_ERROR
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_FST_PROCDEF    LM_Bic_Test
; find eisa io base
		mov     dl, pAS.slot_num
	       mov     cl, 12
		shl     dx, cl
		add     dx, 0c80h
		mov     pAS.io_base, dx

; needs rewrite to differentiate adapters
		in      al, dx                
		mov     ah, al
		inc     dx
		in      al, dx
		cmp     ax, EISA_MANUF_ID               ; smc encoded
		je      lm_good_id
	       jmp     short lm_bad_bic
lm_good_id:
	       inc     dx
	       in      al, dx
	       mov     ah, al
	       inc     dx
	       in      al, dx
	       cmp     ax, EISA_BRD_9232               ; FEAST brd ID
	       je      lm_good_id1
	       jmp     short lm_bad_bic
lm_good_id1:
	       inc     dx
	       in      al, dx
	       test    al, B574_EBC_ENB                ; test if BRD enable bit is on
	       jnz     lm_good_bic

lm_bad_bic:
		mov     ax, BIC_REG_ERROR
	       ret
	       
lm_good_bic:
	       mov     ax, SUCCESS
		ret
ASM_FST_PROCEND    LM_Bic_Test



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Check_LAN_Addr_ROM
;
;               Entry:  pAS     Ptr to adapter structure
;               Exit:   AX      Ret code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_FST_PROCDEF    LM_Check_LAN_Addr_ROM

		mov     rAX, SUCCESS
		ret

ASM_FST_PROCEND    LM_Check_LAN_Addr_ROM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Rom_Test     Tests ROM space and ROM conflict.
;                      Not applicable to EISA
;
;               Entry:  DS:BP   Ptr to adapter Structure
;               Exit:   AX      SUCCESS
;                               ROM_CONFLICT
;                               RAM_CONFLICT
;                               ROM_SIGNATURE_ERROR
;                               ROM_CHECKSUM_ERROR
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_FST_PROCDEF    LM_Rom_Test

	       mov     ax, SUCCESS
	       ret

ASM_FST_PROCEND    LM_Rom_Test




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       testram         Write and Read test pattern to RAM
;
;               Entry:  DS:BP   Ptr to adapter Structure
;                      AX      TEST pattern
;                      CX      number of bytes to write to RAM
;               Exit:   BX      SUCCESS
;                               RAM_TEST_FAILED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
testram         proc    near

       push    cx
       push    ax                              ; save test pattern        
	mov     dx, pAS.Pointer                 ;Set address=0, auto inc, Tx 
	mov     ax, AutoIncrement               ; area, Wr
	out     dx, ax          
					       ;     be written
       pop     ax

	mov     dx, pAS.Data0_1                 ;Fill RAM with countdown
ramWriteLoop:
	out     dx, ax  
	loop    ramWriteLoop                       

       mov     bx, ax                          ; bx = test pattern
ramReadAndCmp:      
	mov     dx, pAS.Pointer                 ;Set address=0,auto inc, Tx 

	PreventViolatingHardwareTimings

	mov     ax, AutoIncrement OR ReadMode   ; area, Read
	out     dx, ax

       pop     cx                              ; restore number of bytes
       push    cx
	mov     dx, pAS.Data0_1                 ;Read from Data01 register
ramReadLoop:         
	in      ax, dx
	cmp     ax, bx
	jnz     testMemoryFail
	loop    ramReadLoop

       mov     bx, SUCCESS
       pop     cx
       ret

testMemoryFail:
       mov     bx, RAM_TEST_FAILED
       pop     cx
       ret

testram         endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_IO_Transfer_Test     Tests RAM
;
;               Entry:  DS:BP   Ptr to adapter Structure
;               Exit:   AX      SUCCESS
;                               RAM_TEST_FAILED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_FST_PROCDEF LM_IO_Transfer_Test
       push    bx
       push    cx
       push    dx
       push    es
       push    ds
       push    si
       push    di

	SelectBank 0
	mov     dx, pAS.MIR                 
	in      ax, dx                          ; al = total memory, ah = free memory

       cmp     al, 0                           ; any memory at all
       jnz     RamAvail                
       jmp     RamTestFail
RamAvail:
	cmp     ah, 0                           ; any free memory
	jnz     AllocRequest1
	jmp     RamTestFail

AllocRequest1:
	SelectBank 0
	mov     dx, pAS.MIR                     ;Read the Memory size
	in      ax, dx                          ;ah = Num of free pages
	cmp     ah, 0                           ;Is there any memory left ?
	mov     bx, SUCCESS
	jnz     AllocOK
	jmp     RamTestExit                     ; if not, RAM OK

AllocOK:
	xor     al, al
	cmp     ah, 4                           ; each unit in MIR is 512 bytes
	jb      IssueAllocate1                  ; 2K = 4 * 512
	mov     ah, 4                           ;Request 2k 

IssueAllocate1:
	SelectBank 2
	mov     dx, pAS.MMUCommand
	xchg    al, ah                          ; ax = x number of 512 bytes

       shl     ax, 1                           ; ax = x number of 256 bytes
	mov     bx, ax                          ; Save # of pages requested
       dec     ax                              ; MMU command use x-1 

	or      al, AllocateTx
	out     dx, ax

	mov     dx, pAS.Interrupt
	mov     cx, 15  
AllocaValidLoop1:                        
	in      ax, dx                          ;Test if allocation
	test    al, AllocInt                    ; passes (Alloc Int = 1)
	jnz     AllocPassed1
	loop    AllocaValidLoop1
	jmp     RamTestFail
	
AllocPassed1:
	mov     dx, pAS.PNR_ARR
	in      ax, dx
	mov     al, ah                          ;Copy allocated packet Num.
	out     dx, al                          ; to PNR

	mov     dx, pAS.Pointer                 ;Set address=0, auto inc, Tx 
	mov     ax, AutoIncrement               ; area, Wr
	out     dx, ax          
	mov     cx, 7                           ;cx = multiplier
	shl     bx, 7                           ;bx = bx*128, Num of WORDS to
					       ;     be written

	mov     cx, bx                          ;set up cx as loop counter       
	mov     dx, pAS.Data0_1                 ;Fill RAM with countdown
WriteLoop1:
	mov     ax, cx                          ; test pattern.
	out     dx, ax  
	loop    WriteLoop1                       

; Read And Compare:      
	mov     dx, pAS.Pointer                 ;Set address=0,auto inc, Tx 

	PreventViolatingHardwareTimings

	mov     ax, AutoIncrement OR ReadMode   ; area, Read
	out     dx, ax

	mov     dx, pAS.Data0_1                 ;Read from Data01 register
	mov     cx, bx                          ;Restore total # of words to 

ReadLoop1:                                      ; read
	in      ax, dx
	cmp     ax, cx
	jnz     RamTestFail
	loop    ReadLoop1

       mov     cx, bx                          ; restore total # of words
       mov     ax, RAM_PATTERN_1
       call    testram
       cmp     bx, RAM_TEST_FAILED
       jz      RamTestExit
       mov     ax, RAM_PATTERN_2
       call    testram
       cmp     bx, RAM_TEST_FAILED
       jz      RamTestExit
       mov     ax, RAM_PATTERN_3
       call    testram
       cmp     bx, RAM_TEST_FAILED
       jz      RamTestExit
       
	jmp     AllocRequest1                   ;Loop until no more memory is 
						; available
RamTestFail:
       mov     bx, RAM_TEST_FAILED

RamTestExit:
	SelectBank 2
	mov     dx, pAS.MMUCommand              ;Free the allocated Memory
	mov     ax, ResetMMU                    
	out     dx, ax
	WaitForMMUReady

       mov     ax, bx                          ; set ax = return code        
	
       pop     di
       pop     si
       pop     ds
       pop     es
       pop     dx
       pop     cx
       pop     bx

	ret

ASM_FST_PROCEND LM_IO_Transfer_Test




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
;      LM_Dma_Test     
;      
;      Description:    Test DMA channel
;      Entry :         ds:bp  Ptr to adapter structure
;                      dx:ax  32 bits physical address of a 200 bytes
;                             scratch pad area
;
;      Exit:           ax = return code
;                              SUCCESS
;                              HARDWARE_FAILED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IFNDEF CODE_386
.386
ENDIF

ASM_FST_PROCDEF        LM_Dma_Test
       push    es
       push    ds
       push    ebx
       push    ecx
       push    edx
       push    esi
       push    edi
       pushf

       cld

       mov     bx, dx                                  ; save scratch pad pointer
       shl     ebx, 16                                 ; ebx = scratch pad pointer
       mov     bx, ax
       mov     esi, ebx                                ; esi = scratch pad pointer
       
       mov     dx, pAS.BankSelect                      ; save bank sel value
       in      ax, dx
       push    ax

       ;
       ; check ram space
       ;

       SelectBank 0
       mov     dx, pAS.MIR
       in      ax, dx
       cmp     al, 0                                   ; al = total mem size
       jnz     RamAvailDMA
       jmp     DMATestFail
RamAvailDMA:
       cmp     ah, 0                                   ; ah = free mem
       jnz     DMATestCont
       jmp     DMATestFail


       ;
       ; allocate one buffer(default to 2048 bytes for FEAST)
       ;
DMATestCont:
       SelectBank 2
       mov     dx, pAS.MMUCommand
       xor     al, al
       or      al, AllocateTx
       out     dx, al

       mov     dx, pAS.Interrupt                       ; wait for alloc operation
       mov     cx, 15
DMARamLoop:
       in      ax, dx
       test    al, AllocInt
       jnz     DMARamOK
       loop    DMARamLoop
       jmp     DMATestFail

DMARamOK:
       mov     dx, pAS.PNR_ARR                         ; Copy allocated packet #
       in      ax, dx
       mov     al, ah                                  ; al = allocated pkt #
       out     dx, al          

       ;
       ; initialize offset 0 to 199(200 bytes total)
       ; to a test pattern
       ;
       mov     dx, pAS.Pointer                         ; set alloc 
       mov     ax, AutoIncrement
       out     dx, ax
  
       mov     cx, 200                                 ; cx = byte count
       mov     dx, pAS.Data0_1
DMASetData:
       mov     al, cl
       out     dx, al
       loop    DMASetData

       ;
       ; move data by DMA write
       ; from on board RAM @ offset 0
       ; to host-scratch pad buffer
       ;
       mov     dx, pAS.Pointer                         ; reset pointer
       mov     ax, AutoIncrement or ReadMode           ; set it up for read
       out     dx, ax

       ; reset DMA
       ; ?? al value need to verify with EISA spec
	mov	dx,DMA_B_CLEAR0   ; byte pointer clear reg.
	out	dx,al             ; reset DMA 0-3
	mov	dx,DMA_B_CLEAR1   ; byte pointer clear 5-7
	out	dx,al             ; reset DMA 4-7
	mov	dx,DMA_MODE1      ; mode reg. 4-7
	mov	al,0c0h           ; place channel 4 to cascade mode
	out	dx,al

	; Enable DMA chips
	mov	al,10h            ; use rotating priority
;	xor	al,al             ; enables all DMA and DRQ sense high DAK assert low
	mov	dx,DMA_COMM0      ; command reg.
	out	dx,al
	mov	dx,DMA_COMM1      ;
	out	dx,al

	; Init base address
	mov	dl,pAS.DMA_base_addr_dat
	xor	dh,dh
	mov	al,bl             ; base address bit 0-7
	out	dx,al
	mov	al,bh             ; base address bit 8-15
	out	dx,al
	mov	dl,pAS.DMA_base_addr_dat_L
	shr	ebx,16            ; get base address 16-23 to bl
	mov	al,bl
	out	dx,al             ; base address bit 16-23
	add	dx,0400h	; Point to high page Register
	mov	al,bh		; base address bit 24-31
	out	dx,al

	; init byte count
       mov     cx, 200           ; cx = byte count
	dec	cx                ; count = actual count - 1
	xor	dx,dx		; clear high reg bits
	mov	dl,pAS.DMA_byte_count_dat
	mov	al,cl
	out	dx,al             ; write byte counter bit0-7
	mov	al,ch
	out	dx,al             ; write byte counter bit8-15, counter 16-31 is auto. cleared

	mov	ah,DMA_BLOCK+DMA_INCREMENT+DMA_DISABLE_AUTO+DMA_WRITE_TRANSFER

	;
	; ah - mode content
	;
	mov	al,byte ptr pAS.dma_channel
	xchg	ah,al             ; al = content, ah = channel
	mov	dx,DMA_MODE0      ; default channel 0-3
	test	ah,4              ; is channel 5-7?
	je	setDMAMode1
	mov	dx,DMA_MODE1      ; use channel 4-7 mode
	and	ah,3              ; ah = channel# for the chip
setDMAMode1:
	or	al,ah             ; assign channel
	out	dx,al             ; write mode register
	add	dx,DMA_EXTEND     ; change to extended mode
	mov	al,DMA_32_BY_BYTE+DMA_TYPE_C ;
	add	al,ah             ; assign channel
	out	dx,al

;
;	CHECK_DMA
;	checks to see if the DMA process is done or not
;
; in al - channel#
; out eq - time out
; neq - terminal count set
;
        
	mov     al,byte ptr pAS.dma_channel
	mov     dx,DMA_REQ0
	mov     bx,DMA_STAT0
	test    al,4                          ; channel 0-3
	je      is_req3          ; yes
	mov     dx,DMA_REQ1
	mov     bx,DMA_STAT1
is_req3:
	or      al,4            ; request service
	out     dx,al           ; dma should start now
	mov     dx,bx           ; dx = status
	mov     cl,al
	and     cl,3            ; cl = channel# in the chip
	mov     ah,1            ;
	shl     ah,cl           ; ah = terminal count position
	xor     rCX,rCX         ; set time out counter
check_tc3:
	in      al,dx           ; wait until terminal count
	test    al,ah           ; is set yet?
	loope   check_tc3




       ;
       ; set pointer to on-board RAM to 200
       ;
       mov     dx, pAS.Pointer                         ; reset pointer
       mov     ax, AutoIncrement                       ; set it up for write
       or      ax, 200
       out     dx, ax

       mov     ebx, esi                                ; ebx = scratch pad pointer


       ;
       ; move data by DMA read
       ; from host-scratch pad buffer 
       ; to on board RAM @ offset 200
       ;
       ; reset DMA
	mov	dx,DMA_B_CLEAR0   ; byte pointer clear reg.
	out	dx,al             ; reset DMA 0-3
	mov	dx,DMA_B_CLEAR1   ; byte pointer clear 5-7
	out	dx,al             ; reset DMA 4-7
	mov	dx,DMA_MODE1      ; mode reg. 4-7
	mov	al,0c0h           ; place channel 4 to cascade mode
	out	dx,al

	; Enable DMA chips
	mov	al,10h            ; use rotating priority
;	xor	al,al             ; enables all DMA and DRQ sense high DAK assert low
	mov	dx,DMA_COMM0      ; command reg.
	out	dx,al
	mov	dx,DMA_COMM1      ;
	out	dx,al

	; Init base address
	mov	dl,pAS.DMA_base_addr_dat
	xor	dh,dh
	mov	al,bl             ; base address bit 0-7
	out	dx,al
	mov	al,bh             ; base address bit 8-15
	out	dx,al
	mov	dl,pAS.DMA_base_addr_dat_L
	shr	ebx,16            ; get base address 16-23 to bl
	mov	al,bl
	out	dx,al             ; base address bit 16-23
	add	dx,0400h	; Point to high page Register
	mov	al,bh		; base address bit 24-31
	out	dx,al

	; init byte count
       mov     cx, 200
	dec	cx                ; count = actual count - 1
	xor	dx,dx		; clear high reg bits
	mov	dl,pAS.DMA_byte_count_dat
	mov	al,cl
	out	dx,al             ; write byte counter bit0-7
	mov	al,ch
	out	dx,al             ; write byte counter bit8-15, counter 16-31 is auto. cleared

	mov	ah,DMA_BLOCK+DMA_INCREMENT+DMA_DISABLE_AUTO+DMA_READ_TRANSFER

	;
	; ah - mode content
	;
	mov	al,byte ptr pAS.dma_channel
	xchg	ah,al             ; al = content, ah = channel
	mov	dx,DMA_MODE0      ; default channel 0-3
	test	ah,4              ; is channel 5-7?
	je	setDMAMode2
	mov	dx,DMA_MODE1      ; use channel 4-7 mode
	and	ah,3              ; ah = channel# for the chip
setDMAMode2:
	or	al,ah             ; assign channel
	out	dx,al             ; write mode register
	add	dx,DMA_EXTEND     ; change to extended mode
	mov	al,DMA_32_BY_BYTE+DMA_TYPE_C ;
	add	al,ah             ; assign channel
	out	dx,al

;
;	CHECK_DMA
;	checks to see if the DMA process is done or not
;
; in al - channel#
; out eq - time out
; neq - terminal count set
;
        
	mov     al,byte ptr pAS.dma_channel
	mov     dx,DMA_REQ0
	mov     bx,DMA_STAT0
	test    al,4                          ; channel 0-3
	je      is_req4          ; yes
	mov     dx,DMA_REQ1
	mov     bx,DMA_STAT1
is_req4:
	or      al,4            ; request service
	out     dx,al           ; dma should start now
	mov     dx,bx           ; dx = status
	mov     cl,al
	and     cl,3            ; cl = channel# in the chip
	mov     ah,1            ;
	shl     ah,cl           ; ah = terminal count position
	xor     rCX,rCX         ; set time out counter
check_tc4:
	in      al,dx           ; wait until terminal count
	test    al,ah           ; is set yet?
	loope   check_tc4




       ;
       ; data compare 
       ;
       mov     cx, 200                                 ; byte count
       mov     si, 0                                   ; offset of the 1st 200 bytes buf
       or      si, ReadMode
       mov     di, 200                                 ; offset of the 2nd 200 bytes buf
       or      di, ReadMode
       mov     bx, HARDWARE_FAILED                     ; preset test return code

ChkDMAData:
       mov     dx, pAS.Pointer
       mov     ax, si
       out     dx, ax
       mov     dx, pAS.Data0_1
       in      al, dx
       mov     ah, al
       mov     dx, pAS.Pointer
       push    ax
       mov     ax, di
       out     dx, ax
       pop     ax
       mov     dx, pAS.Data0_1
       in      al, dx
       cmp     al, ah
       jnz     DMATestDone
       inc     si
       inc     di
       loop    ChkDMAData

       ; set up return code
       mov     bx, SUCCESS                             ; bx = return code

DMATestDone:
       mov     dx, pAS.MMUCommand                      ; deallocate mem        
       mov     al, ReleaseSpecificPacket
       out     dx, al

       jmp     DMATestX

DMATestFail:
       mov     bx, HARDWARE_FAILED                     ; bx = return code
       
DMATestX:
       pop     ax                                      ; restore bank sel value
       mov     dx, pAS.BankSelect
       out     dx, al

       mov     ax, bx                                  ; ax = return code

       popf
       pop     edi
       pop     esi
       pop     edx
       pop     ecx
       pop     ebx
       pop     ds
       pop     es

       ret

ASM_FST_PROCEND        LM_Dma_Test


IFNDEF CODE_386
.286
ENDIF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Nic_Test     Tests FEAST registers and bank select
;
;               Entry:  pAS     Ptr to adapter structure
;               Exit:   AX      Ret code
;                                 = SUCCESS
;                                 = NIC_REG_ERROR
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ASM_FST_PROCDEF    LM_Nic_Test
       push    bx
       push    dx

       mov     dx, pAS.BankSelect
       in      ax, dx
       push    ax                              ; save current bank

       ;
       ; switch to bank 0, 1 and 3
       ; save registers at offset 0 and 4
       ;
       
       SelectBank 0
       mov     dx, pAS.TCR
       in      ax, dx       
       push    ax
       mov     dx, pAS.RCRRegister
       in      ax, dx       
       push    ax

       SelectBank 1
       mov     dx, pAS.Configuration
       in      ax, dx       
       push    ax
       mov     dx, pAS.IA0_1
       in      ax, dx       
       push    ax

       SelectBank 3
       mov     dx, pAS.MT0_1
       in      ax, dx       
       push    ax
       mov     dx, pAS.MT4_5
       in      ax, dx       
       push    ax

       ;
       ; switch to bank 0, 1 and 3
       ; write to offset 0 and 4 register
       ;
       SelectBank 0
       mov     dx, pAS.TCR
       mov     ax, 03180h
       out     dx, ax
       mov     dx, pAS.RCRRegister
       mov     ax, 04303h
       out     dx, ax

       SelectBank 1
       mov     dx, pAS.Configuration
       mov     ax, 091b6h
       out     dx, ax
       mov     dx, pAS.IA0_1
       mov     ax, 0ba5ah
       out     dx, ax

       SelectBank 3
       mov     dx, pAS.MT0_1
       mov     ax, 0a5a5h
       out     dx, ax
       mov     dx, pAS.MT4_5
       out     dx, ax


       ;
       ; switch back to bank 0, 1 and 3
       ; read registers @ offset 0 and 4
       ; to verify contents are intact
       ;
       SelectBank 0
       mov     dx, pAS.TCR
       in      ax, dx
       cmp     ax, 03180h
       jne     NICFailed
       mov     dx, pAS.RCRRegister
       in      ax, dx
       cmp     ax, 04303h
       jne     NICFailed

       SelectBank 1
       mov     dx, pAS.Configuration
       in      ax, dx
       and     ax, 095b6h
       cmp     ax, 091b6h
       jne     NICFailed
       mov     dx, pAS.IA0_1
       in      ax, dx
       cmp     ax, 0ba5ah
       jne     NICFailed

       SelectBank 3
       mov     dx, pAS.MT0_1
       in      ax, dx
       cmp     ax, 0a5a5h
       jne     NICFailed
       mov     dx, pAS.MT4_5
       in      ax, dx
       cmp     ax, 0a5a5h
       jne     NICFailed

       mov     bx, SUCCESS
       jmp     NICTestDone


NICFailed:
       mov     bx, NIC_REG_ERROR


NICTestDone:

       ;
       ; switch to bank 0, 1 and 3
       ; save registers at offset 0 and 4
       ;
       
       SelectBank 3
       pop     ax
       mov     dx, pAS.MT4_5
       out     dx, ax
       pop     ax
       mov     dx, pAS.MT0_1
       out     dx, ax

       SelectBank 1
       pop     ax
       mov     dx, pAS.IA0_1
       out     dx, ax
       pop     ax
       mov     dx, pAS.Configuration
       out     dx, ax

       SelectBank 0
       pop     ax
       mov     dx, pAS.RCRRegister
       out     dx, ax
       pop     ax
       mov     dx, pAS.TCR
       out     dx, ax

       ; 
       ; reset the NIC
       ;
;       mov     dx, pAS.io_base
;       add     dx, 5                           
;       in      al, dx
;       or      al, 080h
;       out     dx, al


       ;
       ; restore bank select
       ;
       pop     ax
       mov     dx, pAS.BankSelect
       out     dx, al

       mov     ax, bx                          ; ax = return code

       pop     dx
       pop     bx
       ret

ASM_FST_PROCEND    LM_Nic_Test



;****************************************************************************
;
; Function:     LM_Loopback_Test
;
; Synopis:      
;
; Input:        None
;
; Output:       ax = return code
;
; Modified:     None
;
; Notes:	 None
;
;****************************************************************************
ASM_FST_PROCDEF        LM_Loopback_Test

       push    bx
       push    cx
       push    dx

       ; save current page bank #
       ;
       mov     dx, pAS.BankSelect
       in      ax, dx
       push    ax                              ; ax = current page


       ; 
       ; save current node address
       ;
       SelectBank 010h
       mov     dx, pAS.IA0_1
       in      ax, dx
       push    ax
       add     dx, 2
       in      ax, dx
       push    ax
       add     dx, 2
       in      ax, dx
       push    ax         

       ;
       ; disable interrupt to host, use polling 
       ; 
	SelectBank 020h
	mov     dx, pAS.Interrupt                   
	inc     dx                              ;Point to Mask Register
       in      al, dx
       push    ax
	mov     al, SCECMaskAllByte             ;Disable all interrupts
	out     dx, al

       ;
       ; set up the transmit buffer with
       ;     dest addr = 00 00 c0 00 00 00
       ;     src addr = 00 00 c0 00 00 00
       ;     data = 0 (60 - 6) bytes
       ;

       mov     dx, pAS.MMUCommand              ; issue allocate cmd
       mov     al, AllocateTx
       out     dx, al  

       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 15
waitAlloc:
       in      ax, dx
       and     al, AllocInt
       jnz     AllocDone
       loop    waitAlloc
       mov     bx, HARDWARE_FAILED
       jmp     lpbkerr

AllocDone:
       out     dx, al                          ; clear Alloc Int

	mov     dx, pAS.PNR_ARR
	in      ax, dx
	mov     al, ah                          ;Copy allocated packet Num.
	out     dx, al                          ; to PNR

	mov     dx, pAS.Pointer                 ;Set address=4, auto inc, Tx 
	mov     ax, AutoIncrement               ; area, Wr
       or      ax, 4
	out     dx, ax          

       mov     cx, 60                          ; byte count = 60
       shr     cx, 1                           ; word count = byte count / 2
       mov     ax, 0
       mov     dx, pAS.Data0_1
wrLpbk_data:
       out     dx, ax
       loop    wrLpbk_data

       mov     dx, pAS.Pointer
       mov     ax, 6                           ; set the destination addr to   
       out     dx, al                          ; 00 00 C0 00 00 00

       mov     dx, pAS.Data0_1
       mov     ax, 00c0h
       out     dx, ax

       mov     dx, pAS.Pointer
       mov     ax, 0ch
       out     dx, al

       mov     dx, pAS.Data0_1
       mov     ax, 00c0h
       out     dx, ax

       ;
       ; loopback test with mode set to Internal loopback mode.
       ; Only loopback within the FEAST- EPH_Loop bit in TCR set.
       ;
       ;
       mov     cx, 02000h                       ; cx = loopback mode        
       call    FST_loop_test
       cmp     bx, SUCCESS
       jne     ltestexit


       ;
       ; loopback test with mode set to Transceiver Loopback.
       ; Only loopback within the FEAST- Loop bit in TCR set.
       ;
       ;
       mov     cx, 0002h                       ; cx = loopback mode        
       call    FST_loop_test


ltestexit:
       ;
       ; deallocate TX memory
       ;
       SelectBank      020h                    ; bank 2
       mov     dx, pAS.MMUCommand
       mov     al, ReleaseSpecificPacket       ; de-allocate mem
       out     dx, al

lpbkerr:
       ;
       ; restore interrupt mask register
       ; 
	SelectBank 020h
	mov     dx, pAS.Interrupt                   
	inc     dx                              ;Point to Mask Register
       pop     ax
	out     dx, al

       ; 
       ; restore current node address
       ;
       SelectBank 010h
       mov     dx, pAS.IA4_5
       pop     ax
       out     dx, ax
       pop     ax
       sub     dx, 2
       out     dx, ax
       pop     ax
       sub     dx, 2
       out     dx, ax

       ;
       ; restore page register
       ;
       pop     ax
       mov     dx, pAS.BankSelect
       out     dx, al

       mov     rAX, rBX                        ; set up return code

       pop     dx
       pop     cx
       pop     bx

       ret


ASM_FST_PROCEND        LM_Loopback_Test




;****************************************************************************
;
; Function:     FST_loop_test
;
; Synopis:      
;
; Input:        cx = loopback mode
;
; Output:       bx = return code
;
; Modified:     None
;
; Notes:	 Test the integrity of the data path & CRC generation logic.
;               Use HW append CRC option and RX with CRC in memory, check
;               CRC bytes received match what are expected.
;
;****************************************************************************
FST_loop_test  proc    near



       ;
       ; loopback test 1
       ;    bx = return code
       ;
       ;
       ;
       
       ;
       ;  TX control = HW append CRC + TXENA + loopback mode(in CX)
       ;
       SelectBank      0                       ; bank 0
       push    cx
       mov     dx, pAS.TCR
       or      cx, 0801h                       ; set TXENA
       mov     ax, cx
       out     dx, ax

       DELAY_LPBK

       call    FST_loopback1
       pop     cx
       cmp     bx, SUCCESS
       jne     lpbkexit

       ;
       ; loopback test 2.1 & 2.2
       ;    bx = return code
       ;
       ;
       ; TX control = SW manual CRC + TXENA + loopback mode(in CX)
       ;
       SelectBank      0                       ; bank 0
       push    cx
       mov     dx, pAS.TCR
       or      cx, 0901h                       ; SW manual CRC + TXENA
       mov     ax, cx
       out     dx, ax

       DELAY_LPBK

       call    FST_loopback2_1
       pop     cx
       cmp     bx, SUCCESS
       jne     lpbkexit


       push    cx
       call    FST_loopback2_2
       pop     cx
       cmp     bx, SUCCESS
       jne     lpbkexit

       ;
       ; loopback test 3
       ;    bx = return code
       ;
       ;
       ; TX control = SW manual CRC + TXENA + loopback mode(in CX)
       ;
       SelectBank      0                       ; bank 0
       mov     dx, pAS.TCR
       or      cx, 0901h                       ; SW manual CRC + TXENA
       mov     ax, cx
       out     dx, ax

       DELAY_LPBK

       push    cx
       call    FST_loopback3
       pop     cx


lpbkexit:
       ret

FST_loop_test  endp



;****************************************************************************
;
; Function:     FST_loopback1
;
; Synopis:      
;
; Input:        None
;
; Output:       bx = return code
;
; Modified:     None
;
; Notes:	 Test the integrity of the data path & CRC generation logic.
;               Use HW append CRC option and RX with CRC in memory, check
;               CRC bytes received match what are expected.
;
;****************************************************************************
FST_loopback1      proc    near


       SelectBank 020h                         ; Bank 2

       ;
       ; byte count = 60
       ; 
       mov     dx, pAS.Pointer
       mov     ax, AutoIncrement
       or      ax, 2
       out     dx, ax
       mov     dx, pAS.Data0_1                 ; set up byte count 
       mov     ax, 66
       out     dx, ax                          ; 60+status word+byte count wd+control wd

       mov     dx, pAS.Pointer                 ; set up the control byte @ the end of the pkt
;       mov     ax, 64
       mov     ax, 65
       out     dx, al

       mov     dx, pAS.Data0_1
       mov     al, 0                           ; auto CRC
       out     dx, al



       ;
       ; Set up Receive Mask & Node Address
       ; 
       SelectBank 010h                         ; set up node address for Rcv
       mov     dx, pAS.IA0_1                   ; 00 00 c0 00 00 00
       mov     ax, 0
       out     dx, ax
       mov     dx, pAS.IA2_3
       mov     ax, 00c0h
       out     dx, ax
       mov     dx, pAS.IA4_5
       mov     ax, 0
       out     dx, ax

       SelectBank 0
       mov     dx, pAS.RCRRegister
       mov     ax, 0100h                       ; Rx Enable & Rcv CRC in memory
       out     dx, ax


       ;
       ; enqueue packet for transmit
       ;
       SelectBank 020h
	mov     dx, pAS.MMUCommand                  
	mov     al, EnqueueIntoTXFifo
	out     dx, al

       ;
       ; check for transmit status
       ;
       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 300
waitTx:
       in      ax, dx
       and     al, TransmissionInt
       jnz     TxDone
       loop    waitTx
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk1exit

       ;
       ; check for receive status
       ;
TxDone:
       out     dx, al                          ; clear the interrupt

       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 200
waitRec:
       in      ax, dx
       and     al, ReceiveInt
       jnz     RecDone
       loop    waitRec
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk1exit


       ; 
       ; check data
       ;
RecDone:
       out     dx, al                          ; clear the interrupt

       mov     dx, pAS.Pointer
       mov     ax, ReceiveArea OR AutoIncrement OR ReadMode
       out     dx, ax

       PreventViolatingHardwareTimings
       mov     dx, pAS.Data0_1
       in      ax, dx                          ; ax = status

       test    ax, 0FC01h                      ; test status for any errors
       jz      RecLpbkOK
       mov     bx, BAD_PKT_ERR
       jmp     lpbk1err

       mov     bx, BAD_PKT_ERR                 ; setup possible error code

RecLpbkOK:
       in      ax, dx                          ; al = byte count =
       cmp     al, 70                          ;      Tx byte count(66) + CRC(4)
       jne     lpbk1err


       in      ax, dx                          ; first dest. addr word
       cmp     ax, 0
       jne     lpbk1err

       in      ax, dx                          ; second dest. addr word
       cmp     ax, 00c0h
       jne     lpbk1err

       in      ax, dx                          ; third dest. addr word
       cmp     ax, 0
       jne     lpbk1err

       in      ax, dx                          ; first src. addr word
       cmp     ax, 0
       jne     lpbk1err

       in      ax, dx                          ; second src. addr word
       cmp     ax, 00c0h
       jne     lpbk1err

       mov     cx, 50                          ; total len(60) - 10 bytes = 50
       shr     cx, 1                           ; divide by 2 = # of words
lpbkNextWord:
       in      ax, dx
       cmp     ax, 0
       jne     lpbk1err
       loop    lpbkNextWord


       ;
       ; check the AUTO generated CRC = 1E D0 21 2F
       ;
       in      ax, dx
       cmp     ax, 0D01eh
       jne     lpbk1err

       in      ax, dx
       cmp     ax, 02f21h
       jne     lpbk1err

       mov     bx, SUCCESS                     ; everything OK

lpbk1err:
       ;
       ; release RX buffer
       ;
	SelectBank 020h
	mov     dx, pAS.MMUCommand              ;Issue Remove&Release Command
	mov     ax, RemoveReleaseTopRXFifo
	out     dx, ax
	WaitForMMUReady

lpbk1exit:
       ret

FST_loopback1      endp



;****************************************************************************
;
; Function:     FST_loopback2_1
;
; Synopis:      
;
; Input:        None
;
; Output:       bx = return code
;
; Modified:     None
;
; Notes:	 Send SW manual good CRC and expect received packet with no CRC
;               error.  good CRC = 1E D0 21 2F
;
;****************************************************************************
FST_loopback2_1        proc    near

       SelectBank 020h                         ; Bank 2

       ;
       ; byte count = 64 (60 bytes of data + 4 bytes of CRC)
       ; 
       mov     dx, pAS.Pointer
       mov     ax, AutoIncrement               ; area, Wr
       or      ax, 2
       out     dx, ax
       mov     dx, pAS.Data0_1
       mov     ax, 70
       out     dx, ax                          ; 64+status word+byte count wd+control wd

       mov     dx, pAS.Pointer                 ; put in good CRC(1E D0 21 2F)
       mov     ax, 64
       out     dx, al

       mov     dx, pAS.Data0_1
       mov     ax, 0D01Eh
       out     dx, ax
       mov     ax, 02F21h
       out     dx, ax

       mov     dx, pAS.Pointer                 ; set up the control byte @ the end of the pkt
       mov     ax, 69
       out     dx, al

       mov     dx, pAS.Data0_1                 ; Manual CRC
       mov     al, 0h
       out     dx, al



       ;
       ; Set up Receive Mask & Node Address
       ; 
       SelectBank 010h                         ; set up node address for Rcv
       mov     dx, pAS.IA0_1                   ; 00 00 c0 00 00 00
       mov     ax, 0
       out     dx, ax
       mov     dx, pAS.IA2_3
       mov     ax, 00c0h
       out     dx, ax
       mov     dx, pAS.IA4_5
       mov     ax, 0
       out     dx, ax

       SelectBank 0
       mov     dx, pAS.RCRRegister
       mov     ax, 0300h                       ; Rx Enable + strip CRC
       out     dx, ax


       ;
       ; enqueue packet for transmit
       ;
       SelectBank 020h
	mov     dx, pAS.MMUCommand                  
	mov     al, EnqueueIntoTXFifo
	out     dx, al

       ;
       ; check for transmit status
       ;
       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 300
waitTx21:
       in      ax, dx
       and     al, TransmissionInt
       jnz     TxDone21
       loop    waitTx21
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk21err

       ;
       ; check for receive status
       ;
TxDone21:
       out     dx, al                          ; clear the interrupt

       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 200
waitRec21:
       in      ax, dx
       and     al, ReceiveInt
       jnz     RecDone21
       loop    waitRec21
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk21err


       ; 
       ; check data
       ;
RecDone21:
       out     dx, al                          ; clear the interrupt

       mov     dx, pAS.Pointer
       mov     ax, ReceiveArea OR AutoIncrement OR ReadMode
       out     dx, ax

       PreventViolatingHardwareTimings
       mov     dx, pAS.Data0_1
       in      ax, dx                          ; ax = status

       mov     bx, SUCCESS
       test    ax, 02000h                      ; test status for CRC error
       jz      lpbk21exit
       mov     bx, ACPT_MANUAL_ERR

lpbk21exit:
       ;
       ; release RX buffer
       ;
	SelectBank 020h
	mov     dx, pAS.MMUCommand              ;Issue Remove&Release Command
	mov     ax, RemoveReleaseTopRXFifo
	out     dx, ax
	WaitForMMUReady


lpbk21err:
       ret

FST_loopback2_1        endp


;****************************************************************************
;
; Function:     FST_loopback2_2
;
; Synopis:      
;
; Input:        None
;
; Output:       bx = return code
;
; Modified:     None
;
; Notes:	 Send SW manual bad CRC and expect received packet with CRC
;               error.  bad CRC = 1F D1 21 2F
;
;
;****************************************************************************
FST_loopback2_2        proc    near


       SelectBank 010h                         ; set up control CTR register
       mov     dx, pAS.Control
       in      ax, dx
       push    ax
       or      ax, RcvBadSetBit                ; received bad packets
       out     dx, ax


       SelectBank 020h                         ; Bank 2

       ;
       ; byte count = 64 (60 bytes of data + 4 bytes of CRC)
       ; 
       mov     dx, pAS.Pointer
       mov     ax, AutoIncrement               ; area, Wr
       or      ax, 2
       out     dx, ax
       mov     dx, pAS.Data0_1                 ; set up byte count 
       mov     ax, 70
       out     dx, ax                          ; 64+status word+byte count wd+control wd

       mov     dx, pAS.Pointer                 ; put in good CRC(1E D0 21 2F)
       mov     ax, 64
       out     dx, al

       mov     dx, pAS.Data0_1
       mov     ax, 0D11Fh
       out     dx, ax
       mov     ax, 02F21h
       out     dx, ax

       mov     dx, pAS.Pointer                 ; set up the control byte @ the end of the pkt
;       mov     ax, 68
       mov     ax, 69
       out     dx, al

       mov     dx, pAS.Data0_1                 ; Manual CRC
;       mov     al, 010h
       mov     al, 0
       out     dx, al



       ;
       ; Set up Receive Mask & Node Address
       ; 
       SelectBank 010h                         ; set up node address for Rcv
       mov     dx, pAS.IA0_1                   ; 00 00 c0 00 00 00
       mov     ax, 0
       out     dx, ax
       mov     dx, pAS.IA2_3
       mov     ax, 00c0h
       out     dx, ax
       mov     dx, pAS.IA4_5
       mov     ax, 0
       out     dx, ax

       SelectBank 0
       mov     dx, pAS.RCRRegister
       mov     ax, 0300h                       ; Rx Enable + strip CRC
       out     dx, ax


       ;
       ; enqueue packet for transmit
       ;
       SelectBank 020h
	mov     dx, pAS.MMUCommand                  
	mov     al, EnqueueIntoTXFifo
	out     dx, al

       ;
       ; check for transmit status
       ;
       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 300
waitTx22:
       in      ax, dx
       and     al, TransmissionInt
       jnz     TxDone22
       loop    waitTx22
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk22err

       ;
       ; check for receive status
       ;
TxDone22:
       out     dx, al                          ; clear the interrupt

       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 200
waitRec22:
       in      ax, dx
       and     al, ReceiveInt
       jnz     RecDone22
       loop    waitRec22
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk22err


       ; 
       ; check data
       ;
RecDone22:
       out     dx, al                          ; clear the interrupt

       mov     dx, pAS.Pointer
       mov     ax, ReceiveArea OR AutoIncrement OR ReadMode
       out     dx, ax

       PreventViolatingHardwareTimings
       mov     dx, pAS.Data0_1
       in      ax, dx                          ; ax = status

       mov     bx, SUCCESS
       test    ax, 02000h                      ; test status for CRC error
       jnz     lpbk22exit                       ; CRC error set as expected
       mov     bx, EXPECTED_CRC_ERR

lpbk22exit:
       ;
       ; release RX buffer
       ;
	SelectBank 020h
	mov     dx, pAS.MMUCommand              ;Issue Remove&Release Command
	mov     ax, RemoveReleaseTopRXFifo
	out     dx, ax
	WaitForMMUReady


lpbk22err:
      
       pop      ax                             ; restore CTR
       SelectBank 010h
       mov      dx, pAS.Control
       out      dx, ax
       SelectBank 020h

       ret

FST_loopback2_2        endp




;****************************************************************************
;
; Function:     FST_loopback3
;
; Synopis:      
;
; Input:        None
;
; Output:       bx = return code
;
; Modified:     None
;
; Notes:	 Set node address to NOT match the dest addr in TX frame
;               and send bad manual CRC.  
;
;               Expect No CRC error set because of addr mismatch.
;
;****************************************************************************
FST_loopback3      proc    near


       SelectBank 020h                         ; Bank 2

       ;
       ; byte count = 64 (60 bytes of data + 4 bytes of CRC)
       ; 
       mov     dx, pAS.Pointer
       mov     ax, AutoIncrement               ; area, Wr
       or      ax, 2
       out     dx, ax
       mov     dx, pAS.Data0_1                 ; set up byte count 
       mov     ax, 70
       out     dx, ax                          ; 64+status word+byte count wd+control wd

       mov     dx, pAS.Pointer                 ; put in good CRC(1E D0 21 2F)
       mov     ax, 64
       out     dx, al

       mov     dx, pAS.Data0_1
       mov     ax, 0D11Fh
       out     dx, ax
       mov     ax, 02F21h
       out     dx, ax

       mov     dx, pAS.Pointer                 ; set up the control byte @ the end of the pkt
;       mov     ax, 68
       mov     ax, 69
       out     dx, al

       mov     dx, pAS.Data0_1                 ; Manual CRC
       mov     al, 0h
       out     dx, al



       ;
       ; Set up Receive Mask & Node Address
       ; 
       SelectBank 010h                         ; set up node address for Rcv
       mov     dx, pAS.IA0_1                   ; 00 00 c0 00 00 01
       mov     ax, 0
       out     dx, ax
       mov     dx, pAS.IA2_3
       mov     ax, 00c0h
       out     dx, ax
       mov     dx, pAS.IA4_5
       mov     ax, 01
       out     dx, ax

       SelectBank 0
       mov     dx, pAS.RCRRegister
       mov     ax, 0300h                       ; Rx Enable + strip CRC
       out     dx, ax


       ;
       ; enqueue packet for transmit
       ;
       SelectBank 020h
	mov     dx, pAS.MMUCommand                  
	mov     al, EnqueueIntoTXFifo
	out     dx, al

       ;
       ; check for transmit status
       ;
       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 100
waitTx3:
       in      ax, dx
       and     al, TransmissionInt
       jnz     TxDone3
       loop    waitTx3
       mov     bx, NO_XMIT_RESPONSE            ; time out
       jmp     lpbk3err

       ;
       ; check for receive status
       ;
TxDone3:
       out     dx, al                          ; clear the interrupt

       mov     bx, ACPT_BAD_ADDR_ERR
       mov     dx, pAS.Interrupt               ; wait for allocate 
       mov     cx, 300
waitRec3:
       in      ax, dx
       and     al, ReceiveInt
       jnz     lpbk3exit
       loop    waitRec3
       mov     bx, SUCCESS                     ; time out on rec'd as expected
       jmp     lpbk3err


       ;
       ; received bad address
       ;

lpbk3exit:
       ;
       ; release RX buffer
       ;
	SelectBank 020h
	mov     dx, pAS.MMUCommand              ;Issue Remove&Release Command
	mov     ax, RemoveReleaseTopRXFifo
	out     dx, ax
	WaitForMMUReady

lpbk3err:
       ret

FST_loopback3      endp



