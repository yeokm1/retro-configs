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
; File:         lft9232.asm
;
; Description:  9232 LMAC functions
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lm9232\vcs\lft9232.avm  $
;
;   Rev 1.4   10 Feb 1995 11:45:14   WATANABE
;1. Fixed loopback test in lft_ext.asm.  Software appended CRC bit is not set
;   properly in the control byte of the packet data area.
;   
;2. Added copyright banner to all files.   
;
;   
;
;   Rev 1.3   02 Feb 1995 10:19:02   WATANABE
;1. Added code to save and restore node address in LM_Loopback_test for
;   EZStart, so when EZStart gets executed again without reboot, the 
;   node address will be correct.
;
;   
;
;   Rev 1.2   25 Jan 1995 17:55:54   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.3   25 Jan 1995 17:52:30   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.2   25 Jan 1995 17:51:06   WATANABE
;1.  Added "cld" instruction to LM_Receive_Copy and LM_Send.
;   
;
;   Rev 1.1   11 Jan 1995 11:00:22   WATANABE
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
;   Rev 1.0   02 Dec 1994 19:03:14   WATANABE
;Initial Release.
;
;
;+!/? ***********************************************************************

;****************************************************************************
;*                                                                          
;* Pre-release History Log:                                                             
;*
;* Standard Microsystem LMAC interface module. This MLID will function 
;* with the SMC LAN Adapter series.
;*
;* Written by:     Paul Brant
;* Date:           11/23/93
;*
;* By         Date     Ver.   Modification Description
;* ------------------- -----  --------------------------------------
;* TW         01/10/95 1.1    Change LM_Enable_Adapter to include
;*                            check for adapter_status.  Only enable the
;*                            interrupt if the adapter_status NOT equal to
;*                            CLOSED.  This is to fix a problem in Novell
;*                            certification test where after driver shut down
;*                            MSM will call to enable adapter and hence
;*                            causes the card to be on-line again(RX and TX).
;*
;* TW         11/10/94 1.0o   Add the followings for EZStart :
;*                             - defines for rAX should be <xx>
;*                             - Get Node address in LM_GetCnfg
;*                             - Change AllocateRequestedFlag in adapter structure
;*                               to use it for LM_Interrupt_Req.
;*                             - Change ValidInts(equates) in scec_eq to
;*                               include Allocation Int.
;*
;*
;* TW         11/8/94  1.0n   Add EZStart requirement to code :
;*                                     - name tag for all LMAC calls
;*                                     - lmstruct.h
;*                                     - re organize defines
;*                                     - move defines needed in getcnfg.inc
;*                                       to scec_eq.inc
;*                                     - move defines needed in bicnic.inc
;*                                       to bic574.inc               
;*   
;* TW         11/4/94  1.0m   Restructure convert frag: move from LMAC
;*                            to UMAC for Rx ONly.
;*
;* TW         10/1/94  1.0k   Fix bug when merging Paul's DMA code :
;*                            due to change of using "bp" to "si".
;*
;* TW         9/22/94  1.0j   Add CheckMultiAdd() to RXIntr.
;*
;* TW         9/21/94  1.0i   Clean up LMStruct.inc redundant/unused
;*                            variable.
;*                            Remove LM_GetNIC_type() and SCECChipType.
;*                            IFDEF ISA card functions.
;*                            Clean up counters.
;*
;* TW         9/20/94  1.0h   Eliminate defines FEASTEISA.  Replace
;*                            with FEASTISA.
;*                            Define DEBUG in makefile not here.
;* 
;* 
;* 
;* TW         9/14/94  1.0g   Move Get_LAN_Address from LM_GetCnfg to
;*                            LM_Initialize_Adapter.
;*                            Also fix the problem of not able to support
;*                            node address override.
;*                            
;*                            IFDEF out kickstart for back to back send
;*                            as a potential problem area.(switch name is
;*                            BACK2SEND)
;*
;*
;* TW         9/13/94  1.0f   Add and Modify code for LM_Change_Receive_Mask()
;*                            Add Multi cast filter for RxIntr.
;*                            Add LM_Delete_Multi_Address.
;*                            Modify LM_Add_Multi_Address to deal with mc_table only.
;*
;* TW         9/09/94  1.0e   Change LM_Service_Events to add return
;*                            code in AX.
;*                            Eliminate code for masking all interrupts
;*                            on entry to LM_Service_Events.  LM_Disable_Adapter
;*                            should have done that.
;*
;* TW         9/09/94  1.0d   Change statistics counter in TxIntr &
;*                            EPHIntr
;*                            TxIntr - change return code for EVENTS_DISABLED
;*
;* TW         9/09/94  1.0c   Change RxIntr
;*                            Add status for UM_Receive_Copy
;*                            Eliminate pAS.RxErrorBits
;*         
;* TW         9/07/94  1.0b   Add send status for UM_Send_Complete
;*                            in TxIntr
;* Paul_b     1/26/93  1.0    First working ethernet version
;*                                 
;*                                       
;****************************************************************************

;
; LMAC version tag string
; needs to be updated for each revision
;
       db              '@(#) LM_9232_s2.1_v1.02',0,'$'




IFDEF DEBUG

OutDebugChar	macro char
IF DEBUG
	push	ax
	mov	al, char
	call	dbg_ascii
	pop	ax
ENDIF
	endm

setprn macro bitno
        push    dx
        push    ax
        pushf
        mov     dx, 378h
        in      al, dx
        or      al, (1 shl bitno)
        out     dx, al
        popf
        pop     ax
        pop     dx
        endm

clrprn macro bitno
        push    dx
        push    ax
        pushf
        mov     dx, 378h
        in      al, dx
        and     al, NOT (1 shl bitno)
        out     dx, al
        popf
        pop     ax
        pop     dx
        endm

resetprn macro
        push    dx
        push    ax
        mov     ax,0
        mov     dx, 378h
        out     dx,al
        pop     ax
        pop     dx
        endm

ENDIF


IFDEF DEBUG


;	/*************************************************************\
;	* NOTE: This file, debug.inc, is for non-protected mode.      *
;	*       Another file, debugpm.inc, is for protected mode.     *
;	*                                                             *
;	* These are subroutines which can be used to display via VRAM *
;	* either ascii characters or hexidecimal representations of   *
;	* binary values.  The first display begins in the upper left  *
;	* corner of the screen.  At the right edge of line 24 it will *
;	* wrap around to the first character of the first line again. *
;	* Sending an ascii character 0Dh = <CR> will blank the        *
;	* remainder of the current line and cause the next character  *
;	* to be displayed on the first character of the next line.    *
;	* a bright character is always displayed on the screen after  *
;	* the last character written so it is easy to see at any time *
;	* where the display cursor is.                                *
;	*                                                             *
;	* Calling syntax to display a character:                      *
;	*    mov al,ascii_code                                        *
;	*    call dbg_ascii                                           *
;	*                                                             *
;	* Calling syntax to display a 4 bit nibble in hex             *
;	*                                                             *
;	*    mov al,nibble_value                                      *
;	*    call dbg_nibble                                          *
;	*                                                             *
;	* Calling syntax to display an 8 bit byte in hex              *
;	*                                                             *
;	*    mov al,byte_value                                        *
;	*    call dbg_byte                                            *
;	*                                                             *
;	* Calling syntax to display a 16 bit word in hex              *
;	*                                                             *
;	*    mov ax,word_value                                        *
;	*    call dbg_word                                            *
;	*                                                             *
;	* NOTE: All registers and flags are preserved in these calls  *
;	\*************************************************************/




dbg_		proc	near

scnseg	equ 0B800h		;set to 0B000h for mono, 0B800h for color
;scnseg	equ 0B000h		;set to 0B000h for mono, 0B800h for color

dspsol	equ 0h			;50h ofst of start of dsp line in VRAM
dsbase	dw 0
dsofst	dw dspsol
dsp_stop db 0

dbg_word:	pushf
		push ax
		mov al,ah
		cli
		call near ptr dbg_byte
		pop ax
		push ax
		jmp dbg_byte00

dbg_byte:	pushf
		push ax			;dsp al in hex
dbg_byte00:	shr al,1
		shr al,1
		shr al,1
		shr al,1
		and al,0Fh
		add al,30h
		cmp al,3Ah
		jb dbg_byte10
		add al,7
dbg_byte10:	cli
		call near ptr dbg_ascii
		pop ax
		push ax
		jmp dbg_nibble10

dbg_nibble:	pushf
		push ax
		cli
dbg_nibble10:	and al,0Fh
		add al,30h
		cmp al,3Ah
		jb dbg_nibble20
		add al,7
dbg_nibble20:	call near ptr dbg_ascii
		pop ax
		popf
		ret

dbg_ascii:	pushf
		cmp cs:dsp_stop,0
		jne dbg_ret		;dont display after key is hit
		push es
		push di
		push bx
		mov ah,7
		mov di,scnseg		;point es to VRAM segment
		mov es,di
		mov bx,cs:dsbase
		mov di,cs:dsofst
		cmp al,0Ah
		je dbg_ascii20		;ignore line feeds
		cmp al,0Dh
		jne dbg_ascii06		;jmp if not car ret
		mov al,' '		;blank remainder of line
dbg_ascii04:	mov es:[bx+di],al
		mov byte ptr es:[bx+di+1],ah
		inc di
		inc di
		cmp di,0A0h
		jb dbg_ascii04
		mov al,0Dh		;restore al
		jmp dbg_ascii10		;advance to nxt line
dbg_ascii06:	mov es:[bx+di],al
		mov byte ptr es:[bx+di+1],ah
		inc di
		inc di
		cmp di,0A0h
		jb dbg_ascii20
dbg_ascii10:	mov di,dspsol
		add bx,0A0h
		cmp bx,0F00h-0A0h	;only 23 lines down
		jb dbg_ascii20
		xor bx,bx
dbg_ascii20:	mov cs:dsbase,bx
		mov cs:dsofst,di
		mov byte ptr es:[bx+di],8
		mov byte ptr es:[bx+di+1],ah
		pop bx
		pop di
		pop es
dbg_ret:
		popf
		ret
       	
dbg_		endp


ENDIF

;
;       ResetSCEC
;
;       Routine to totally reinitialize the SCEC.
;
;       assumes:        ds      is set to CGroup
;                       Interrupts are disabled
;
;       returns:        Interrupts are disabled
;

ResetSCEC      proc    near

InternalResetSCEC:

IF K9DEBUG
	OutDebugChar 'R', 0
ENDIF

	mov     pAS.TxPacketsInsideSCEC, 0      ;No Tx Pckts inside after RST
	mov     ax, pAS.SCECNumberOfPages       ;Set max Tx mem to default
	sub     ax, pAS.SCEC1518InSCECPages     ; (won't be NET.CFG value if
	mov     pAS.SCECMaxPagesForTx, ax       ;  there was any)

	mov     ax, 100                         ;Set stats table var
	mul     pAS.SCECMaxPagesForTx           ;DX:AX = 100 * MaxPages
	div     pAS.SCECNumberOfPages           ;AX = int (100 * " /NumOfP)
	mov     word ptr pAS.MaxPercentageOnTx, ax

;	mov     pAS.AllocationRequestedFlag, 0      ;Clear flag.

;       Memory Configuration Register defaults to zero upon reset (total
;       dynamic allocation)

;       Set the Control Register

	SelectBank 010h

	mov     dx, pAS.Control                     ;We do not change the state 
	in      ax, dx                          ; of RcvBad
	and     ax, RcvBadMask
;	or      ax, RcvBadSetBit                - cx = 0 -> Turn On RcvBad
						;
	or      ax, ControlResetValue
	out     dx, ax

	SelectBank 020h
	EnableSCECInterrupts

;       Copy node address from config table into the SCEC
;       Valid when node address override was done, non-destructive otherwise.

;       Update the SCEC's multicast table

;	call    MSMUpdateMulticast

;	SetMaxMSMTxFreeCount                    ;Tell MSM we have space

IF TESTING_PARSER
	call    ReduceAvailableMemory
ENDIF

	call	EPHIntr                  ;Update of AUI bit in Config. 
							; Reg. 

;       Set the Transmit Configuration & enable transmissions

	SelectBank 0

	mov     dx, pAS.TCR
	mov     ax, TCRResetValue
	out     dx, ax

;       Set the Receive Configuration & enable receptions

	mov     dx, pAS.RCRRegister
	in	ax, dx
	and	ax, PRMSBitMask
	or	ax, RCRResetValue
	out     dx, ax           

IF K9DEBUG
	OutDebugChar 'r', 0
ENDIF

	ret

ResetSCEC      endp


;
;       DoRAMTest
;
;       Routine to test out the SCECs RAM.
;
;       assumes:        ds      is set to CGroup
;
;       returns:        z flag  if no errors
;                       nz flag if errors
;                       dx      -> error message (only if nz flag)
;                       bx,ds,int preserved.
;

DoRAMTest      proc    near

	SelectBank 0
	mov     dx, pAS.MIR                 
	in      ax, dx                          ;If there is no memory at all
	cmp     ah, 0                           ; report a failure
	jnz     AllocRequest
	jmp     MemoryFail

AllocRequest:
	SelectBank 0
	mov     dx, pAS.MIR                         ;Read the Memory size
	in      ax, dx                          ;ah = Num of free pages
	cmp     ah, 0                           ;Is there any memory left ?
	jnz     GoRamTest
	jmp     RamTestSuccess                  ; if not, RAM OK
	
GoRamTest:
	xor     al, al
	cmp     ah, 8
	jb      LessThan2k
	mov     ah, 8                           ;Request 2k 
LessThan2k:
	dec     ah                              ;Request available Memory
						;MMU cmd requests 1 more page
IssueAllocate:
	SelectBank 020h
	mov     dx, pAS.MMUCommand
	xchg    al, ah

	mov     bx, ax                          ;Save # of pages-1 requested
	inc     bx                              ;Save actual # of pages 
						;requested

	or      al, AllocateTx
	out     dx, ax

	mov     dx, pAS.Interrupt
	mov     cx, 15  
AllocaValidLoop:                        
	in      ax, dx                          ;Test if allocation
	test	al, AllocInt			; passes (Alloc Int = 1)
	jnz     AllocPassed
	loop    AllocaValidLoop
	jmp     MemoryFail
	
AllocPassed:
	mov     dx, pAS.PNR_ARR
	in      ax, dx
	mov     al, ah                          ;Copy allocated packet Num.
	out     dx, al                          ; to PNR

WriteToRam:
	mov     dx, pAS.Pointer                     ;Set address=0, auto inc, Tx 
	mov     ax, AutoIncrement               ; area, Wr
	out     dx, ax          
	mov     cx, bx                          ;cl = Num of pages allocated
	shl     cx, 7                           ;cx = cl*128, Num of words
						; to be written

	mov     bx, cx                          ;Save num of words to be 
						; written

	mov     dx, pAS.Data0_1                     ;Fill RAM with countdown
WriteLoop:
	mov     ax, cx                          ; test pattern.
	out     dx, ax  
	loop    WriteLoop

ReadAndCompare:      
	mov     dx, pAS.Pointer                     ;Set address=0,auto inc, Tx 

	PreventViolatingHardwareTimings

	mov     ax, AutoIncrement OR ReadMode   ; area, Read
	out     dx, ax

	mov     dx, pAS.Data0_1                     ;Read from Data01 register
	mov     cx, bx                          ;Restore total # of words to 

ReadLoop:                                       ; read
	in      ax, dx
	cmp     ax, cx
	jnz     MemoryFail
	loop    ReadLoop

	jmp     AllocRequest                    ;Loop until no more memory is 
						; available
RamTestSuccess:

	SelectBank 020h
	mov     dx, pAS.MMUCommand                  ;Free the allocated Memory
	mov     ax, ResetMMU                    
	out     dx, ax
	WaitForMMUReady
	xor     ax, ax                          ;Set z flag
						;z flag will be set correctly
	ret
	
MemoryFail:
	SelectBank 020h
	mov     dx, pAS.MMUCommand                  ;Free the allocated Memory
	mov     ax, ResetMMU                    
	out     dx, ax
	WaitForMMUReady

	mov     ax, 1                           ;Return error code
	ret

DoRAMTest      endp




;
;       ScecDriverInit
;
;       This routine is called to intialize and bring the SCEC Board
;       into operation.
;
;       assumes:        ds=es=cs CGroup
;                       CLD has been executed
;                       Interrupts are enabled.
;
;       returns:        dx      -> error message if error during init.
;                       ax      =0 if init okay
;                               !=0 if error (dx -> err msg)
;                       All other registers and flags can be destroyed
;

ScecDriverInit proc    near

IF K9DEBUG
	OutDebugChar 'I', 0
ENDIF

;	cli
	mov     pAS.InScecDriverInitFlag, 1         ;Set flag -> inside ScecDriverInit

;       Determine Processor type.

	pushf                                   ;Save flags
	xor     ax, ax
	push    ax
	popf                                    ;Try to set flags 12-15 to 0                                    
	pushf                                   
	pop     ax                              ;Get flags to ax
	and     ax, 0f000h                      
	cmp     ax, 0f000h                      ;Are bits 12-15 equal to 1 ?
	jne     IsAT

	jmp     InitErrorExit

IsAT:
	mov     ax, 07000h
	push    ax
	popf                                    ;Try to set flags 12-14 to 1                                    
	pushf                                   
	pop     ax                              ;Get flags to ax
	and     ax, 07000h                      ;Are bits 12-14 equal to 0 ?
	jz      Is286
	mov     pAS.Is386, 1                    ;Processor is 80386 or up.
	
Is286:  popf

;       Initialize port addresses.
	mov     rCX, NumIOPorts
	lea     rSI, pAS.TCR
	mov	ax, pAS.io_base
        
	cmp     pAS.slot_num,0			;check if EISA
	je	SCEC_no_eisa

	add	ax, 10h				;add offset for EISA
	
SCEC_no_eisa:

LMGETPortLoop:
	mov     word ptr [rSI]+0  , ax          ;Add in base I/O port bank1
	mov     word ptr [rSI]+16 , ax          ;Add in base I/O port bank2
	mov     word ptr [rSI]+32 , ax          ;Add in base I/O port bank3
	mov     word ptr [rSI]+48 , ax          ;Add in base I/O port bank4
	add     rSI, 2
	add     ax, 2
	loop    LMGETPortLoop

;       Check for SMC9000 pattern in BankSelect register

	mov     dx, pAS.BankSelect
	in      ax, dx
	cmp     ah, SMC9000Pattern
	jne     PortIsNotAlive

;       Issue software Reset

	SelectBank 0

	mov     dx, pAS.RCRRegister             ;Reset the SCEC
	mov     ax, IssueResetMask              ;Set EPH_RST
	out     dx, ax
	in      ax, dx                          ;Wait
	in      ax, dx                          ;Wait
	in      ax, dx                          ;Wait
	mov     ax, FlushResetMask              ;Clear EPH_RST
	out     dx, ax                         

;       See if SCEC is alive

	SelectBank 010h

	in      ax, dx                          ;Read Bank Select Register 
	and     ax, SelectBankMask              ; and check the SCEC is in 
	cmp     ax, 0010h                       ; bank 1
	je      PortIsAlive

PortIsNotAlive:
	jmp     InitErrorExit

PortIsAlive:

;       See if EEPROM loaded correctly

	mov     dx, pAS.Control                 ;Wait until Reload and Store 
	mov     cx, 10000                       ; are 0. Try it 10000 times
TestAgain:
	in      ax, dx                         
	and     ax, Reload_StoreMask
	cmp     ax, 0000h
	je      DetermineMIRMultiplier
	loop    TestAgain 

	jmp     InitErrorExit


;       Now get the M (MIR multiplier) from the MCR and set the 
;       MIRShlTo256ByteUnits variable to the proper value (M-1)
DetermineMIRMultiplier:
	SelectBank 0
	mov     dx, pAS.MCR
	in      ax, dx
	and     ah, MIRMultiplierMask
	shr     ah, 1
	dec     ah
	mov     pAS.MIRShlTo256ByteUnits, ah

;       This part of the initialization fills SCECPageSize variable with
;       the SCEC page size in 256 byte units and the SCECShrForPageSize
;       var with the power of 2 which the latter number is, it asumes
;       the page size is always a "power of two" multiple of 256. It
;       also sets the strings that show the page size at load time
;       and in the statistic table for the MEM_UTIL version.

DetermineSCECPageSize:
	SelectBank 020h
	mov     dx, pAS.MMUCommand              ;Free allocated memory if any
	mov     ax, ResetMMU
	out     dx, ax
	WaitForMMUReady

	SelectBank 0                            ;Get mem size
	mov     dx, pAS.MIR
	in      ax, dx
	mov     ah, 0
	cmp     al, 0ffh
	jne     LeaveItAsItIs
	inc     ax
LeaveItAsItIs:
	mov     cl, pAS.MIRShlTo256ByteUnits
	shl     ax, cl

	mov     pAS.SCECRAMSize, ax
	mov     bx, ax  

	SelectBank 020h
	mov     dx, pAS.MMUCommand
	mov     ax, AllocateTx              	;Ask for 256 bytes (minimun)
	out     dx, ax
	WaitForMMUReady

	SelectBank 0                            ;Get free mem
	mov     dx, pAS.MIR
	in      ax, dx
	mov     al, ah                          ;We don't need to check, will
	mov     ah, 0                           ; always be less than 0ffh
	mov     cl, pAS.MIRShlTo256ByteUnits
	shl     ax, cl

	sub     bx, ax                          ;bx = number of 256 byte units
						; in one SCEC page
	mov     ax, bx
	mov     pAS.SCECPageSize, ax

	mov     cx, 0
LoopForShrValue:        
	shr     al, 1
	cmp     al, 0
	je      ExitShrLoop
	inc     cx
	jmp     LoopForShrValue
ExitShrLoop:
	mov     pAS.SCECShrForPageSize, cl


	mov     ax, pAS.SCECRAMSize
	mov     bx, pAS.SCECPageSize
	div     bl                              ;al = number of pages
	mov     ah, 0                           ;ax = number of pages
	mov     pAS.SCECNumberOfPages, ax
	mov     pAS.SCECMaxPagesForTx, ax


	mov     ax, 6                           ;Ceil(1518 in 256 byte units)
	mov     bx, pAS.SCECPageSize
	div     bl
	cmp     ah, 0
	je      RemainderReady
	inc     al                              ;Adjust for ceiling
RemainderReady:
	mov     ah, 0
	mov     pAS.SCEC1518InSCECPages, ax
	sub     pAS.SCECMaxPagesForTx, ax

;       Adjust in case a correct value was parsed in NET.CFG

	cmp     pAS.FoundSCECMaxMemForTx, 2
	jne     CorrectMaxTxPages
	mov     al, pAS.SCECMaxMemForTx
	mul     byte ptr pAS.SCECNumberOfPages  ;AX = NPages * %
	mov     bl, 100
	div     bl                              
	xor     ah, ah                          ;AX = (NPages * %) / 100
	cmp     ax, pAS.SCEC1518InSCECPages
	jae     IsEnoughForTx


	mov     ax, pAS.SCEC1518InSCECPages


	mov     pAS.SCECMaxPagesForTx, ax
	jmp     CorrectMaxTxPages
IsEnoughForTx:
	mov     pAS.SCECMaxPagesForTx, ax

CorrectMaxTxPages:
;       Issue RAM tests.

       call    DoRAMTest                       
	or      ax, ax
	jz      SkipInitErrorExit
						; leaving.
	jmp     InitErrorExit
SkipInitErrorExit:

	call    ResetSCEC               ;Call common init routine

;       media type selection.
	
IF K9DEBUG
	OutDebugChar '+', 0
	OutDebugChar 'i', 0
ENDIF
;paul *************************************************************************	
;	mov     dx, pAS.Control       
;	in      ax, dx
; 	or      ax, RcvBadSetBit                ;cx = 0 -> Turn On RcvBad
;	out     dx, ax

;paul *************************************************************************	

	
	mov     pAS.InScecDriverInitFlag, 0     ;We are leaving
	xor     ax, ax                          ;Return success

	ret

InitErrorExit:
IF K9DEBUG
	OutDebugChar '-', 0
	OutDebugChar 'i', 0
ENDIF
		    
	mov     pAS.InScecDriverInitFlag, 0     ;We are leaving
	or      al, 1                           ;nz condition
	ret
	
ScecDriverInit endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Add_Multi_Address    Adds Multicast address in adapter structure to
;                               Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_FST_PROCDEF    LM_Add_Multi_Address

		push    rDI
		push    rSI
		push    rCX
		push    bx
ifndef CODE_386
		push    es
endif
		cld

		mov     rAX, SUCCESS             ; Preset return code
ifndef CODE_386
		push    ds
		pop     es                       ; ES = DS
endif
		lea     rDI, pAS.mc_table
		mov     rCX, MC_TABLE_ENTRIES    ; CL == max number of
			       			 ; entries in table

AroundTheWorld:
		lea     rSI, pAS.multi_address
		push    rDI
		push    rCX
		mov     rCX, 6
		repz    cmpsb
		pop     rCX
		pop     rDI
		jnz     DoYerNeighbor
		cmp     byte ptr [rDI+6], 0ffh  ; If instance count >= 0ffh,
						; entry is maxed out.
		je      McTableFull
		inc     byte ptr [rDI+6]        ; Increment instance_count
		jmp     AddMultiDone            ; All Done

DoYerNeighbor: add     rDI, 7                  ; Point to next address
		loop    AroundTheWorld          ; Check all addresses.
						; No match found, find
						; first empty table entry
		mov     rCX, MC_TABLE_ENTRIES   ; and insert address there
		lea     rDI, pAS.mc_table

CheckForEmpty: mov     bl, [rDI+6]             ; Check instance count for
		cmp     bl, 0                   ; this address.
		je      add_address             ; If instance count == 0
						; copy address to this space.
		add     rDI, 7                  ; Point to next address
		loop    CheckForEmpty           ; Loop for all entries.
		jmp     McTableFull             ; If no empty entries, bail out

add_address:   lea     rSI, pAS.multi_address
		mov     rCX, 6
		rep     movsb
		inc     byte ptr [rDI]           ; Increment instance_count
		jmp     AddMultiDone

McTableFull:    mov     rAX, OUT_OF_RESOURCES

AddMultiDone:
ifndef CODE_386
		pop     es
endif
		pop     bx
		pop     rCX
		pop     rSI
		pop     rDI

		ret

ASM_FST_PROCEND    LM_Add_Multi_Address


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       LM_Delete_Multi_Address Removes Multicast address in adapter
;                                       structure from Multicast address table.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASM_FST_PROCDEF    LM_Delete_Multi_Address

		push    rCX
		push    rDI
		push    rSI
ifndef CODE_386
		push    es
endif
		cld

		mov     rAX, SUCCESS             ; Preset return code
ifndef CODE_386
		push    ds
		pop     es                      ; ES = DS
endif
		lea     rDI, pAS.mc_table
		mov     rCX, MC_TABLE_ENTRIES

FrootLoop:     lea     rSI, pAS.multi_address
		push    rDI
		push    rCX
		mov     rCX, 6
		repz    cmpsb
		pop     rCX
		pop     rDI
		jnz     TryNextDoor
		cmp     byte ptr [rDI+6], 0h    ; If instance count = 0h,
						; entry is alrady gone.
		je      McTableEmpty
		dec     byte ptr [rDI+6]        ; Decrement instance_count
		jmp     DeleteMultiDone         ; All Done

TryNextDoor:   add     rDI, 7                   ; Point to next address
		loop    FrootLoop               ; Check all addresses
						; If all entries checked and
						; no matches, bail out.

McTableEmpty:  mov     rAX, OUT_OF_RESOURCES

DeleteMultiDone:
ifndef CODE_386
		pop     es
endif

		pop     rSI
		pop     rDI
		pop     rCX

		ret

ASM_FST_PROCEND    LM_Delete_Multi_Address


;
;       SetupMCHashBit
;
;       This routine will take the specified 6-byte address and calculate
;       which bit should be set in the multicast hash table to enable
;       reception of that address. It will then set the appropriate bit
;       in the MCWorkArea. 
;
;                      rSI      -> buffer "multi_address" 
;				    holding the 6-byte address to use.
;			rDI	 -> buffer "mc_table[cx]"
;

SetupMCHashBit  proc    near

	push	rBP			;save bp

IFNDEF   CODE_386
	push    cs			;if 16 bit code setup es for String move
	pop     es
ENDIF
	movsw
	movsw
	movsw

	mov     bp, 0ffffh                      ;BP = crcl
	mov     di, bp                          ;DI = crch

;       for (index=0; index < 6; ++index)

	mov     rCX, 6                           ;Do 6 bytes of address
;	mov     si, offset CGroup:MCAddress
;	rSI pints to the multicast address 6 byte address buffer

FilterOuterLoop:
	push    rCX                              ;Save outer loop counter

;       for (j=0; j<8; ++j)

	mov     cl, 8                           ;Set innerloop count

;       carry = ((crc&0x80000000)?1:0)^(multaddress[i]&01)

FilterInnerLoop:
	mov     ax, 8000h
	and     ax, di

	rcl     ax, 2

	mov     dx, 1
	and     dx, [rSI]                        ;multiaddress[i]&01

	xor     ax, dx

;       crc <<= 1

	shl     bp, 1
	rcl     di, 1

;       multaddress[i] >>= 1

	shr     byte ptr [rSI], 1

;       if (carry)
;        crc = ((crc^POLYNOMIAL) | carry)

	or      ax, ax                          ;AX has carry in it
	jz      FinishInnerFilterPass
	cwd                                     ;DX:AX = sign extended 

;       crc^POLYNOMIAL

	xor     bp, 1db6h                       ;High end of polynomial.
	xor     di, 04c1h                       ;Low end of polynomial.

;       crc^Polynomial | carry
	
	or      bp, ax                          ;Low end of carry
	or      di, dx                          ;High end

FinishInnerFilterPass:
	loop    FilterInnerLoop

	inc     rSI                             ;-> next byte of address
	pop     rCX                             ;Restore outer counter
	loop    FilterOuterLoop

;       crc = crc & 0x0ff00 0000h

	and     di, 0ff00h

;       crc = crc >> 26

	mov     cl, 26
	xor     ax, ax
	mov     dx, di

MultiShiftForFilter:
	shr     dx, 1
	rcr     ax, 1
	loop    MultiShiftForFilter

;       AX has the filter bit index.
;       Calculate the memory address and bit offset for this bit position.

	mov     bx, ax                          ;Save Hash value reg. in BX
	mov     cx, ax
	and     cl, 07h                         ;Mask off all except last 3
						;bits, for bit displacement
	mov     al, 1
	shl     al, cl                          ;Setup bit displacement
	      
	shr     bx, 3                           ;Figure byte to use (/8)
IFDEF CODE_386
       movzx   ebx, bx
	add     ebx, offset MCWorkArea           ;Calculate real Mem. address
ELSE
	add     bx, offset MCWorkArea            ;Calculate real Mem. address
ENDIF

;       Write the value to workarea.

	mov     ah, al                          ;Save AL
	mov     al, [rBX]                       ;Get current bit setting from
						; Work Area.
	or      al, ah                          ;Mask in our bit
	mov     [rBX], al

	pop	rBP
	ret

SetupMCHashBit  endp


;*****************************************************************************
;
;       LM_Change_Receive_Mask
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Change_Receive_Mask

	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP
	
        cmp     pAS.adapter_status, NOT_INITIALIZED
        jne     LM_Ch_Stat_ok
	
	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
        
	mov     rAX, ADAPTER_NOT_INITIALIZED
        
	ret

LM_Ch_Stat_ok:
	mov     dx, pAS.BankSelect              ;Save BankSelect register
	in      ax, dx          
	and     ax, SelectBankMask
	push    ax

	SelectBank 0

	mov     dx, pAS.RCRRegister		;get receive control bits
	in      ax, dx

       test    pAS.receive_mask, (ACCEPT_MULTICAST OR ACCEPT_MULTI_PROM OR ACCEPT_BROADCAST )
	jz	disable_mult

	or	ax, RCR_ALMUL			;accept all mult for now... will
				         	;change later... Paul
	jmp	check_pro

disable_mult:
	and	ax, not RCR_ALMUL     		;disable all mult for now... will

check_pro:
       test    pAS.receive_mask, PROMISCUOUS_MODE
       jz      no_pro

	or      ax, PromiscuousSetBit           ;cx != 0 -> Turn On PRMS
	jmp	done_changing_bits
no_pro:
	and     ax, PromiscuousClrBit           ;cx = 0 -> Turn Off PRMS

done_changing_bits:
	out     dx, ax                          ;Set RCR PRMS bit to 
						; appropiate value

       ; 
       ; set receive mask for ACCEPT ERR 
       ;
	SelectBank 010h

	mov     dx, pAS.Control
	in      ax, dx
	and     ax, RcvBadClrBit                

       test    pAS.receive_mask, ACCEPT_ERR_PACKETS
       jz      SkipTurnOnRcvBad
	or      ax, RcvBadSetBit                
SkipTurnOnRcvBad:
	out     dx, ax


LM_Ch_Msk_Done:
	mov     dx, pAS.BankSelect              ;Restore BankSelect register
	pop     ax
	out     dx, al

       mov     rAX, SUCCESS
	
	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
  
       ret

ASM_FST_PROCEND	LM_Change_Receive_Mask



;*****************************************************************************
;
;       LM_Set_Group_Address
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Set_Group_Address

        mov     rAX, INVALID_FUNCTION
        ret

ASM_FST_PROCEND	LM_Set_Group_Address

;*****************************************************************************
;
;       LM_Delete_Group_Address
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Delete_Group_Address

        mov     rAX, INVALID_FUNCTION
        ret

ASM_FST_PROCEND	LM_Delete_Group_Address

;*****************************************************************************
;
;       LM_Interrupt_Req
;              DS:BP   ptr to adapter structure
;
;              Use Allocation Interrupt to generate int for this test.
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Interrupt_Req

       push    dx

       ; save current page bank #
       ;
       mov     dx, pAS.BankSelect
       in      ax, dx
       push    ax                              ; ax = current page

       SelectBank     020h                     ; switch to bank 2

       mov     pAS.AllocationRequestedFlag, 1  ; set int test flag

       mov     dx, pAS.Interrupt
       inc     dx                              ; dx = int mask reg

       in      al, dx                          ; al = current mask
       or      al, AllocationIntEna            ; add Allocation Int

       out     dx, al                          ; set mask again

       mov     dx, pAS.MMUCommand              ; issue allocate cmd
       mov     al, AllocateTx
       out     dx, al  

       pop     ax                              ; restore page
       mov     dx, pAS.BankSelect
       out     dx, al

       pop     dx
       
       mov     rAX, SUCCESS

       ret


ASM_FST_PROCEND	LM_Interrupt_Req

;*****************************************************************************
;
;       LM_Enable_Adapter
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Enable_Adapter
;IF K9DEBUG
;	OutDebugChar 'E', 0
;ENDIF
	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP
	
       cmp     pAS.adapter_status, CLOSED
       je      enable_x
	mov	dx, pAS.BankSelect		;Save Bank Select Register
	in	ax, dx
	push	rAX

	mov	ax, 2				;SelectBank 2
	out	dx, ax

	EnableSCECInterrupts

	pop	rAX				;Restore Bank Select Register
	mov	dx, pAS.BankSelect
	out	dx, ax				

        and     pAS.adapter_flags,  NOT ADAPTER_DISABLED

enable_x:
        mov     rAX, SUCCESS

;IF K9DEBUG
;	OutDebugChar 'e', 0
;ENDIF

	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
  
        ret

ASM_FST_PROCEND	LM_Enable_Adapter

;*****************************************************************************
;
;       LM_Disable_Adapter
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Disable_Adapter

;IF K9DEBUG
;	OutDebugChar 'D', 0
;ENDIF
	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP
	
	mov	dx, pAS.BankSelect		;Save Bank Select Register
	in	ax, dx
	push	rAX

	SelectBank 020h
	mov     dx, pAS.Interrupt                   
	inc     dx                              ;Point to Mask Register
	mov     al, SCECMaskAllByte             ;Disable all interrupts
	out     dx, al

	pop	rAX				;Restore Bank Select Register
	mov	dx, pAS.BankSelect
	out	dx, ax				

       or      pAS.adapter_flags,  ADAPTER_DISABLED
       mov     rAX, SUCCESS

;IF K9DEBUG
;	OutDebugChar 'd', 0
;ENDIF
	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
	
       ret

ASM_FST_PROCEND	LM_Disable_Adapter

;*****************************************************************************
;
;       lm_Set_Funct_Address
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Set_Funct_Address

        mov     rAX, INVALID_FUNCTION
        ret

ASM_FST_PROCEND	LM_Set_Funct_Address


;**********************************************************************
;  check_ram
;
;**********************************************************************
check_ram      proc    near
	; first verify zero length
	mov	ax, pAS.ram_size
	or	ax, ax
	jz	check_ram_base
	mov	dx, RAM_SIZE_RANGE
	jmp	invalid_ram
check_ram_base:
; only zero (0) and minus one (-1) are valid
	mov	ax, WORD PTR pAS.ram_base
	or	ax,  WORD PTR pAS.ram_base+2
	jz	valid_ram			; show valid if it is zero
	inc	ax				; if it was -1 it is 0 now
	or	ax, ax				; well...was it zero???
	jz	valid_ram			; show valid if it is zero
	mov	dx, RAM_BASE_INVALID
;;;		    RAM_BASE_RANGE
invalid_ram:
	mov	ax, CONFIG_ERROR		; show error, but functional
valid_ram:
	ret
check_ram      endp



;******************************************************************************
;       lm_Initialize_Adapter
;                       DS:BP   ptr to adapter structure
;                       ES:SI   ptr to scratch pad area ( 200 bytes)
;                       
;       Routine to totally reinitialize the NIC.
;
;******************************************************************************
ASM_FST_PROCDEF	LM_Initialize_Adapter
	;int 3

;IF K9DEBUG
;
;	OutDebugChar 'I', 0
;	OutDebugChar 'I', 0
;	OutDebugChar 'I', 0
;	OutDebugChar 'I', 0
;
;ENDIF

	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP

IF K9DEBUG
;; vvvvvvvvvvvvv DEBUG ONLY vvvvvvvvvvvvvvvvvv

       test    pAS.KickStartFlag, 04
       jz      KSout


	OutDebugChar '.', 0
	OutDebugChar '.', 0
	OutDebugChar '.', 0
	OutDebugChar '.', 0

       mov     pAS.KickStartFlag, 0


KSout:

;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ENDIF


	cmp	pAS.rx_lookahead_size, 0	;is it not defined yet?
	jne	LmNoInitLook
	mov	pAS.rx_lookahead_size, 4	;init to 64 bytes lookahead
						;4*16 byte paragraphs

LmNoInitLook:
        cmp     pAS.num_of_tx_buffs, 2
        jbe     num_of_buffs_ok
        mov     pAS.num_of_tx_buffs, 2

num_of_buffs_ok:
        or     pAS.adapter_flags, RX_VALID_LOOKAHEAD

	;test the hardware
	call    ScecDriverInit
	jz	DriverOK

        mov     rAX, SELF_TEST_FAILED

	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
	
        ret

DriverOK:

       ;
       ;* Set Node Address in the hardware
       ;
       cmp     word ptr pAS.node_address, 0
       jnz     SetNodeAddress
       cmp     word ptr pAS.node_address[2], 0
       jnz     SetNodeAddress
       cmp     word ptr pAS.node_address[4], 0
       jnz     SetNodeAddress

	call	GetLANAddress
       jmp     LMInitExit


SetNodeAddress:
       SelectBank 010h
       mov     dx, pAS.IA0_1
       mov     ax, word ptr pAS.node_address
       out     dx, ax
       inc     dx
       inc     dx
       mov     ax, word ptr pAS.node_address+2
       out     dx, ax
       inc     dx
       inc     dx
       mov     ax, word ptr pAS.node_address+4
       out     dx, ax


LMInitExit:


;*************************************************************************
;paul change for hardware problem
;	SelectBank 010h

;	mov	dx, pAS.Control
;	in	ax, dx
;	or	ax, RcvBadSetBit		-ecx != 0 -> Turn On RCV Bad
;	out	dx, ax

;*************************************************************************



        mov     pAS.tx_count, 0
        mov     pAS.hdw_int, 0

        call       InitErrorCounters

        mov     pAS.adapter_status, INITIALIZED
	ASM_CALL	UM_Status_Change

        mov     rAX, SUCCESS

	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
  
        ret

ASM_FST_PROCEND	LM_Initialize_Adapter




;*****************************************************************************
;
;       lm_Open_Adapter
;                       DS:BP   ptr to adapter structure
;
;*****************************************************************************
ASM_FST_PROCDEF	LM_Open_Adapter

       mov     pAS.adapter_status, OPEN
	ASM_FST_CALL	LM_Enable_Adapter
	ASM_CALL	UM_Status_Change
       mov     rAX, SUCCESS
       ret

ASM_FST_PROCEND	LM_Open_Adapter

;******************************************************************************
;
;       lm_Close_Adapter
;                       DS:BP   ptr to adapter structure
;
;******************************************************************************
ASM_FST_PROCDEF	LM_Close_Adapter

       mov     pAS.adapter_status, CLOSED
	ASM_FST_CALL	LM_Disable_Adapter
        
	ASM_CALL	UM_Status_Change
       mov     rAX, SUCCESS
       ret

ASM_FST_PROCEND	LM_Close_Adapter

;******************************************************************************
;
;       lm_Send
;                       DS:BP   ptr to adapter structure
;                       ES:SI   ptr to data buffer structure
;                       CX      Transmit byte count
;       
;       This routine will initiate a packet transmission.
;
;       assumes:        ds      CGroup
;                       si      -> TCB to be transmitted.
;                       cx      hardware frame length
;                       CLD has been executed
;                       
;       Note:           Interrupts are enabled during the routine 
;                       and disabled before returning
;******************************************************************************
ASM_FST_PROCDEF	LM_Send

; IF K9DEBUG
;	OutDebugChar 'S', 0
; ENDIF
	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP

       cld


;
; The following workaround for TX stuck will only work if and if 
; the protocol or application does not do back to back send without
; any receive in between.
;
IFDEF BACK2SEND

	test	pAS.KickStartFlag,1		;if this is not cleared by rxint, 
	jz	drs1
	
	ASM_CALL	KickStart
drs1:

	or	pAS.KickStartFlag,1		;if this is not cleared by rxint, 
       					;next DS will kick

ENDIF
	
	SelectBank 020h
;	mov     dx, pAS.Interrupt               , Disable the physical board's
;	inc     dx                              , interrupt line
;	mov     al, SCECMaskAllByte             
;	out     dx, al
;	sti                             

	call	Allocate                ;Returns system interrupts

;						; disabled
;  DO NOT enable interrupt, let UMAC handle it
;  otherwise ISR will be reentrant.
;	EnableSCECInterrupts
;

;IF K9DEBUG
;	OutDebugChar 's', 0
;ENDIF
SendComplete:

;      return code from Allocate() or CopyTxData()
;      mov     rAX, SUCCESS
;


	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
  
	ret                                     

ASM_FST_PROCEND	LM_Send

;
;       Allocate
;
;       Called by lm_Send, 
;
;       Note:           Returns only if Allocation fails, otherwise it flows
;                       to CopyTxData
;
;       assumes:
;                       DS:BP   ptr to adapter structure
;                       ES:SI   ptr to data buffer structure
;                       CX      Transmit byte count
;        		ds      is set to CGroup
;                       cx      hardware frame length
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       ax      OUT_OF_RESOURCES, if failed
;                       cx      Total space needed in the SCEC for the packet
;                       all other registers may de destroyed
;                       System Interrupts are disabled
;                       AllocationIntMask = Failed Bit 
;                       SCEC in bank 2
;
Allocate       proc    near

IFNDEF CODE_386
IF K9DEBUG
	OutDebugChar 'L', 0
ENDIF
ENDIF

	mov     pAS.HardwareFrameLength, cx     ;Save it for later setting of
						; SCEC's Control byte.

;       Now lets calculate the space needed for the packet in SCEC's RAM

	test    rCX, 1                          ;Add to cx appropiate number 
	jnz     OddNumberOfBytes                ; of bytes
	inc     rCX                             ;Add one more if even # of 
OddNumberOfBytes:                               ; bytes
	add     rCX, 4                           ;Add Space for StatusWord,  
						; Count & Control, minus 1 
						; to adjust to MMUCommand 
						; AllocReq.
	mov     rBX, rCX                          ;Save space - 1

;
; For performance tuning, the following calculation and checking is eliminated.
; Taking advantage of the 91C100 features that N2-N0 bits in MCR will be ignored.
;
IFDEF  LM9000  

;       Calculate number of pages ocupied (256 byte or 2k size pages)
;       from size of pckt.

	inc     rCX                             ;Correct to space (not -1)
	add     rCX, 255
	xor     rAX, rAX
	mov     al, ch                          ;Make it 256 byte units
	add     ax, pAS.SCECPageSize            ;Make it SCEC page units
	dec     ax
	Convert256ByteUnitsToSCECPages

	mov     pAS.CurrentTxPcktSize, al

	xor     ch, ch
	mov     cl, pAS.TxPacketsInsideSCEC
	add     rCX, rAX                        ;rCX = "will be" occupied space

	cmp     pAS.SCECMaxPagesForTx, cx
	jae     GoAhead
		    

; vvvvvvvvvvvv the following flow control mechanism is eliminated vvvvvv
;              return OUT_OF_RESOURCES to UMAC
; 
;	mov     pAS.DBOffsetPointer, si         ,Save pointer to data_buffer
;	mov     pAS.TXPacketRetainedFlag, 1     ,Set Flag for TXIntr
;
;find out how to do this in LMAC
;	mov     MSMTxFreeCount, 0               ,Tell MSM to stop sending
;
;	add     pAS.TxPacketRetainedCount, 1
;	adc     pAS.TxPacketRetainedCount + 2, 0
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	SelectBank 020h
	jmp     ExitAllocate

GoAhead:
	mov     al, bh                          ;al = Number of full 256b pages
						; to Allocate = bx/256

;       Already in bank 2

	mov     dx, pAS.MMUCommand
	or      al, AllocateTx                  ;Issue Allocate command
	xor     ah, ah                          ;High byte of MMUCR=0
	out     dx, ax

ELSE

; For 91C100 specific
;
       SelectBank      020h
       mov     dx, pAS.MMUCommand
       mov     al, AllocateTx
       out     dx, al

ENDIF

;       Now, we will read the Alloc Int bit of Interrupt Register to see the 
;       result of the Allocation Command

	mov     dx, pAS.Interrupt
	mov     rCX, 15
AllocValidLoop:                 
	in      ax, dx                          ;Test if allocation
	test    al, AllocInt                    ; passes (Alloc Int=1)
	jnz     AllocationPassed
	loop    AllocValidLoop

AllocationFailed:

; IF K9DEBUG
;	OutDebugChar '<', 0
;	OutDebugChar 'A', 0
;	OutDebugChar 'F', 0
;	OutDebugChar '>', 0
; ENDIF

; vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
; the following code is eliminated because the register will be 
; restored by the caller
;
;	inc     rBX                             ,Restore(bx=TotalPacketLen-1)
;						,Add one to get exact space.
;	mov     pAS.DBOffsetPointer, si         ,Save pointer to TCB & SCEC's
;	mov     pAS.SCECSpaceForPacket, bx      , space for packet.
;	mov     pAS.AllocationRequestedFlag, 1  ,Turn on flag
;
;find out how to do this in LMAC
;	mov     MSMTxFreeCount, 0               ,Tell MSM to stop sending
;
;	add     pAS.AllocationFailedCount, 1
;	adc     pAS.AllocationFailedCount + 2, 0
;
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


ExitAllocate:
;	cli                                     ;For DriverSend


       mov     rAX, OUT_OF_RESOURCES
	ret

AllocationPassed:
	mov     dx, pAS.PNR_ARR
	in      ax, dx
	mov     cx, bx                          ;Restore(bx=TotalPacketLen-1)
	inc     rCX                             ;Add one to get exact space.
	mov     al, ah                          ;Save allocated packet Num.
	call    CopyTxData                      ;CopyTxData returns
       ret

Allocate       endp

;
;       CopyTxData
;
;       This routine will copy the tx data into the SCEC. Called by Allocate,
;       and AllocIntr.
;
;       assumes:        ds      is set to CGroup
;                       cx      Total space needed in the SCEC for the packet
;                       dx      Points to PNR_ARR Register
;                       al      has the allocated packet number
;                       es:si   -> data_buf_struct to be transmitted.
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       ax      SUCCESS, if success
;                       SCEC in bank 2
;                       System Interrupts are disabled
;

IFNDEF CODE_386
.386
ENDIF
public CopyTxData
CopyTxData     proc    near

IFNDEF CODE_386
IF K9DEBUG
	OutDebugChar 'C', 0
ENDIF
ENDIF

	out     dx, al                          ;Write Alloc. Pckt. Number
						; to PNR

;
; For 91C92 compatibility ONLY
;
IFDEF LM9000
	mov     al, pAS.CurrentTxPcktSize       ;Set Pckt size
	add     pAS.TxPacketsInsideSCEC, al     ;Keep current mem on Tx
ENDIF

;       First we will copy the Control byte (at the end of the packet)
;       to the SCEC

	mov     dx, pAS.Pointer
	mov     rAX, AutoIncrement              ;Set TxArea, write & autoinc
	add     rAX, rCX
	sub     rAX, 2                          ;ax points to Control word
	out     dx, ax

	mov     dx, pAS.Data0_1              
	mov     rAX, SetOddBitControlByte       ;Set Odd bit. 
	test    pAS.HardwareFrameLength, 1      ;Is it an even frame ?
	jnz     SkipEvenSet                     ;Yes. Clr Odd bit 
	mov     rAX, ClrOddBitControlByte        
SkipEvenSet:
	out     dx, ax                          ;al will be rewritten later if 
						; pckt. len is odd.

;       Copy the Status word and byte count

	mov     dx, pAS.Pointer

	PreventViolatingHardwareTimings

	mov     ax, AutoIncrement               ;Set TxArea, write & autoinc
						; modes
	out     dx, ax                                  

	mov     dx, pAS.Data0_1                     
 
;
; For 91C92 compatibility ONLY
;
IFDEF  LM9000
	cmp     pAS.Is386, 1                    ;If >= 386 do dword.
	jne     Is286PC
ENDIF

	push    eax
	mov     ax, cx                          
	shl     eax, 16                         ;Write Byte Count & Status
	out     dx, eax                         ; Word
	pop     eax


;
; For 91C92 compatibility ONLY
;
IFDEF  LM9000
	jmp     DoMediaHeader
Is286PC:
	mov     ax, 0
	out     dx, ax                          ;Write Status Word
	mov     ax, cx
	out     dx, ax                          ;Write Byte Count
ENDIF

DoMediaHeader:


;rem this out since this is part of the LMAC and the Media header is part 
;of the data already... Paul B
;       Write out the Media header
;
;	mov     bx, si                          ;Copy TCB offset to bx
;	mov     cx, [si].TCBMediaHeaderLen
;	add     si, TCBMediaHeader              ;DS:SI -> Media header
;	AlignedOut
			  
;       Write out the data fragments.

	push	esi				;Save data_buf ptr
	push	rBP				;save adapter buf str
	mov	rDI, rSI			;mov Data buf str ptr to rDI
       mov     bh, byte ptr pEDI.fragment_count;Get the number of fragments
						; from Fragment_Count

       add     rDI, size fragment_count


FragOutLoop:
        mov    rCX, pEDI.fragment_length	;Get frag. length (FragLen=4)
        test   rCX, PHYSICAL_ADDR
        jnz    IsDMATx

;
; Slave Tx
;
;    cx(ecx) = fragment length
;    di(edi) = fragment list structure index
;
IFDEF   CODE_386
       mov     rSI, pEDI.fragment_ptr
ELSE
       push    ds
       lds     si, pEDI.fragment_ptr		;DS:SI -> fragment data
ENDIF


       mov     rAX, rCX                          ;Save byte count.

;       First we will align the source address to dword if there are
;       enough bytes to do it.

	mov     rCX, rSI                  
	and     rCX, 3                          ;Save 2 LSBs
	jz      BigXfer
	neg     rCX
	add     rCX, 4                          ;cx = Number of Odd bytes to 
						; do before dword Xfer
	sub     rAX, rCX                        ;ax = Updated byte count
	jns     DoByteAlign                     ;If we need to send more
	add     rAX, rCX                        ; bytes for aligning than
	jmp     LeftBytes                       ; what we have to Xfer 
						; restore eax and abort 
						; dword aligning.

DoByteAlign:                   ;Addr. align. | #bytes to Wr   | Sequence
	test    rCX, 1          ;     01      |        3       | byte - word
	je      DoWord1         ;     02      |        2       | word   
	outsb                   ;     03      |        1       | byte   
DoWord1:
	test    rCX, 2
       jz      BigXfer
       outsw

;       Do big Xfer. 

BigXfer:
	mov     rCX, rAX
	and     rAX, 3                   
	shr	rCX,2           ;Convert count to dwords

       rep outsd                   ;Send out


;       Do last odd bytes if any.

LeftBytes:
;	clrprn 0
   
;	xor	rCX,rCX		; clear high word if necc.
	mov	rCX, rAX        ;Get count of left bytes
       test    cx, 2
       jz      LastOutsb
       outsw
LastOutsb:
       test    cx, 1
       jz      SlaveTxDone
       outsb
SlaveTxDone:
IFNDEF CODE_386
       pop     ds
ENDIF
       jmp     AdvanceToNextFrag


;
; DMA Tx
;
;    cx(ecx) = fragment length
;    di(edi) = fragment list structure index
;
IsDMATx:
       mov     esi, pEDI.fragment_ptr                  ; esi = frag physical addr
       and     rCX, NOT PHYSICAL_ADDR                  ; cx = real frag len

	; Initialize DMA to move data from memory to device (SRAM)
	; in  al - channel number
	;     esi - address to read
	;     cx - byte count
	
	push	rDI		;save for LMAC FRAGMENT loop
	push	ebx
	push	edx		; save IO Ethernet Data port

	xor	ebx,ebx           ; make sure bit 16-31 is clear
	xor	edx,edx           ; make sure bit 16-31 is clear

       mov     ebx, esi        ; ebx = frag phy addr        

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

	; init. base address
	xor   ah,ah             ;  ax = channel#
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
	dec	cx                ; count = actual count - 1
	xor	dx,dx		; set dh = 0 for proper address for counter reg
	mov	dl, pAS.DMA_byte_count_dat
	mov	al,cl
	out	dx,al             ; write byte counter bit0-7
	mov	al,ch
	out	dx,al             ; write byte counter bit8-15, counter 16-31 is auto. cleared

	mov	ah,DMA_BLOCK+DMA_INCREMENT+DMA_DISABLE_AUTO+DMA_READ_TRANSFER

	; ah - mode content
	; al - channel
	mov	al, byte ptr pAS.dma_channel
	xchg	ah,al             ; al = content, ah = channel
	mov	dx,DMA_MODE0      ; default channel 0-3
	test	ah,4              ; is channel 5-7?
	je	twrite_mode
	mov	dx,DMA_MODE1      ; use channel 4-7 mode
	and	ah,3              ; ah = channel# for the chip
twrite_mode:
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
;
; in al - channel#
; out eq - time out
; neq - terminal count set
;
        
	mov     al,byte ptr pAS.dma_channel
	mov     dx,DMA_REQ0
	mov     bx,DMA_STAT0
	test    al,4            ; channel 0-3
	je      is_req2         ; yes
	mov     dx,DMA_REQ1
	mov     bx,DMA_STAT1
is_req2:
	or      al,4            ; request service
	out     dx,al           ; dma should start now

	mov     dx,bx           ; dx = status
	mov     cl,al
	and     cl,3            ; cl = channel# in the chip
	mov     ah,1            ;
	shl     ah,cl           ; ah = terminal count position
	xor     rCX,rCX         ; set time out counter

check_tc2:
	in      al,dx           ; wait until terminal count
	test    al,ah           ; is set yet?

;	push	ax
;	mov	al,'2'
;	call	dbg_ascii
;	pop	ax

	loope   check_tc2

	pop	edx		; restore IO Ethernet Data port
	pop	ebx
	pop	rDI		; restore for LMAC FRAGMENT loop


;
; next fragment
; 
AdvanceToNextFrag:


       add     rDI, size FragmentStructure
	dec     bh                              ;One more fragment done 
	jz      FragOutLoopSkip
	jmp     FragOutLoop
FragOutLoopSkip:
CopyFragDone:       
	pop	rBP				;restore adapter buf str
	pop	esi				;restore data_buf ptr

	mov     dx, pAS.MMUCommand                  
	mov     rAX, EnqueueIntoTXFifo
	out     dx, ax
;	cli

IFNDEF  CODE_386
; IF K9DEBUG
;	OutDebugChar 'c', 0
; ENDIF
ENDIF

       mov     rAX, SUCCESS
	ret

CopyTxData     endp

IFNDEF CODE_386
.286
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       CheckMultiAdd   Compares the address indicated by ES:SI to
;                       all addresses in the adapter structure multicast
;                       table, and the braodcast address located at BC_ADD
;                       in the adapter structure.
;
;       ENTRY:          es:si(esi) = data buffer
;
;       RETURN:         AX == SUCCESS if a match was found,
;                       AX == OUT_OF_RESOURCES if no match was found.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckMultiAdd   proc    near
			push    rSI
			push    rDI
			push    rDX
			push    rCX
			push    rBX
ifndef CODE_386
			push    ds
			push    es
endif

			mov     cx, MC_TABLE_ENTRIES+1  ; # of MC table entries
							; + broadcast address
							; entry.
			mov     rDI, rSI
			lea     rSI, pAS.bc_add         ; Start with b'cast
			test    pAS.receive_mask, ACCEPT_BROADCAST
			jnz     DontSkipBCAdd
			dec     cx                      ; Decrement entry cnt
			lea     rSI, pAS.mc_table       ; Skip b'cast entry
DontSkipBCAdd:
			cld

GoopLoop:              push    rSI
			push    rDI
			push    cx
			mov     cx, 6
			repz    cmpsb
			pop     cx
			pop     rDI
			pop     rSI
			jnz     TryNextAdd
			cmp     byte ptr [rSI+6], 0h    ; If inst. count = 0,
							; entry is invalid.
			je      AddHas0Cnt
			mov     rBX, SUCCESS
			jmp     CheckMADone     ; All Done

TryNextAdd:            add     rSI, 7          ; Point to next address
			loop    GoopLoop        ; Check all addresses
						; If all entries checked and
						; no matches, bail out.

AddHas0Cnt:            mov     rBX, OUT_OF_RESOURCES

CheckMADone:
			mov     rAX, rBX        ; Get return code into AX
ifndef CODE_386
			pop     es
			pop     ds
endif
			pop     rBX
			pop     rCX
			pop     rDX
			pop     rDI
			pop     rSI
			ret
CheckMultiAdd          endp


IFNDEF CODE_386
.386
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; SlaveIn
;
;      rCX = byte count
;      es:di(edi) = pointer to frag buffer
;      dx = FEAST data IO port
;
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SlaveIn        proc    near

       cld

       mov     rAX, rCX                        ; rAX = real byte count(w/o phy addr flag)
       test    di, 03                          ; check addr alignment
       jz      RBigXfer                        ; aligned, go ahead

IFDEF  CODE_386
       movzx   rCX, di                         ; cx = addr offset
ELSE
       mov     rCX, di
ENDIF

       and     rCX, 3                          ; 
       neg     rCX                             ;
       add     rCX, 4                          ; cx = bytes to move to align

       cmp     rAX, rCX                        ; if total byte < alignment
       jbe     RLeftBytes                      
       sub     rAX, rCX                        ; if not, adjust total byte count

       test    rCX, 1                          ; if it is odd bytes alignment
       jz      RDoWord1
       insb
RDoWord1:
       test    rCX, 2                          ; if it is move than 1 byte
       jz      RBigXfer
       insw

RBigXfer:
       mov     rCX, rAX                        ; cx = current byte count
       and     rAX, 03                         ; ax = byte to align at the end
       shr     rCX, 2                          ; move dword

	rep     insd                            ;Read in

RLeftBytes:
       mov     rCX, rAX
       test    rCX, 2                          ; see if it has 2 or 3 bytes
       je      RLastInsb
       insw

RLastInsb:
       test    rCX, 1                          ; see if it has 1 or 3 bytes
       jz      SlaveInX
       insb

SlaveInX:
       ret

SlaveIn        endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; DMA move
; Assume :
;      rCX = byte count
;      edi = pointer to frag buffer
;      dx = FEAST data IO port
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DMAIn          proc    near

       push    rSI
       push    ebx
       push    edx                                     ; save IO data port

       xor     ebx, ebx                                ; make sure bit 16-31 is clear
       xor     edx, edx                                ; make sure bit 16-31 is clear

       mov     ebx, edi                                ; ebx = frag buffer pointer

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
	je	write_mode
	mov	dx,DMA_MODE1      ; use channel 4-7 mode
	and	ah,3              ; ah = channel# for the chip
write_mode:
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
	je      is_req1          ; yes
	mov     dx,DMA_REQ1
	mov     bx,DMA_STAT1
is_req1:
	or      al,4            ; request service
	out     dx,al           ; dma should start now
	mov     dx,bx           ; dx = status
	mov     cl,al
	and     cl,3            ; cl = channel# in the chip
	mov     ah,1            ;
	shl     ah,cl           ; ah = terminal count position
	xor     rCX,rCX         ; set time out counter
check_tc1:
	in      al,dx           ; wait until terminal count
	test    al,ah           ; is set yet?

;	push	ax
;	mov	al,'1'
;	call	dbg_ascii
;	pop	ax

	loope   check_tc1


	pop	edx
	pop	ebx
	pop	rSI

       ret

DMAIn  endp

IFNDEF CODE_386
.286
ENDIF

;******************************************************************************
;
;       lm_Service_Events
;
;       This routine is called when the NIC interrupts the system.
;
;                       DS:BP   ptr to adapter structure
;
;******************************************************************************
ASM_FST_PROCDEF	LM_Service_Events
;IF K9DEBUG
;	OutDebugChar 'T', 0
;ENDIF

        push    bx
        push    dx
        push    rCX
        push    rSI
        push    rDI
ifndef CODE_386
        push    es
endif

        cmp     pAS.hdw_int, 0
        je      ValidInterrupt
        mov     rAX, SUCCESS
        jmp     ISRExit1

ValidInterrupt:
        mov     pAS.hdw_int, 1


IF K9DEBUG
	OutDebugChar 'I', 0
ENDIF

	mov     dx, pAS.BankSelect              ;Save BankSelect Register
	in      ax, dx
	and     ax, SelectBankMask		;4.0 preserve more ?
	push    ax

	SelectBank 0                            ;Clear counters
	mov     dx, pAS.Counter
	in      ax, dx

	SelectBank 020h                         ;Save Pointer Register
	mov     dx, pAS.Pointer
	in      ax, dx
	push    ax

;; vvvvvvvvvvvv comment out vvvvvvvvvvvvvvvvvvvvvvvvvvv
;; LM_Disable_Adapter should be called
;; prior to this LM_Service_Events.
;; The following section is redundant
;;
;;	mov     dx, pAS.Interrupt               ;Disable SCEC's interrupts
;;	inc     dx                              ;Point to Int. Mask Register
;;	mov     al, SCECMaskAllByte
;;	out     dx, al
;;
;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

IF MEM_UTIL
	call    MemoryUtilization
ENDIF   

	mov     dx, pAS.Interrupt               ;Get the status bits
	in      al, dx
	test    al, ValidInts
	jnz     TestRx
IncStats:

IFDEF  DEBUG
	add     pAS.SpuriousEntryToISR, 1
	adc     pAS.SpuriousEntryToISR, 0
ENDIF

       mov     rBX, NOT_MY_INTERRUPT

	jmp     ISRExit

ReadInterruptRegister:
	mov     dx, pAS.Interrupt               ;Get the status bits
	in      al, dx

TestRx:
;	sti                                     ;Must be here 

	test    al, ReceiveInt                  ;Receive Interrupt ?
	jz      TestTx
       call	RxIntr

IFDEF BACK2SEND
       mov     pAS.KickStartFlag, 0
ENDIF

       cmp     rAX, SUCCESS
       jne     ISRExitOK                       ; Rx return EVENTS_DISABLED
	jmp     ReadInterruptRegister

TestTx: 
	test    al, TransmissionInt             ;Tx Interrupt ?
	jz      TestAlloc
	call	TxIntr

       cmp     rAX, SUCCESS
       jne     ISRExitOK                       ; Tx return EVENTS_DISABLED
	jmp     ReadInterruptRegister

TestAlloc:
	test    al, AllocInt                    ;Allocation Interrupt
	jz      TestRxOvrn
	cmp     pAS.AllocationRequestedFlag, 1  ;There is a true allocation
	jne     TestRxOvrn                      ; interrupt ONLY for LM_Interrupt_Req
	call	AllocIntr
	jmp     ReadInterruptRegister

TestRxOvrn:
	test    al, RxOverrunInt                ;Rx Overrun Interrupt ?
	jz      TestEPH
	call	RxOvrnIntr
	jmp     ReadInterruptRegister

TestEPH:
	test    al, EPHInt                      ;EPH Interrupt ?
	jz      ISRExitOK
       call	EPHIntr         
	jmp     ReadInterruptRegister

;       Get here with System interrupts disabled
ISRExitOK:
       xor     rBX, rBX                        ; set up return code -> BX(SUCCESS)

ISRExit:
	SelectBank 020h
	pop	ax
	mov     dx, pAS.Pointer                 ; restore Pointer
	out     dx, ax

;	cli
;	EnableSCECInterrupts

	pop     ax                              ;Restore BankSelect
	mov     dx, pAS.BankSelect
	out     dx, ax

IF K9DEBUG
	OutDebugChar 'i', 0
ENDIF

        mov     rAX, rBX                       ; put return code in AX

        mov     pAS.hdw_int, 0                  ; Reset InISR bit

ISRExit1:
ifndef CODE_386
        pop     es
endif
        pop     rDI
        pop     rSI
        pop     rCX
        pop     dx
        pop     bx
;IF K9DEBUG
;	OutDebugChar 't', 0
;ENDIF

        ret

ASM_FST_PROCEND	LM_Service_Events


ASM_PROCDEF	KickStart
;IF K9DEBUG
;	OutDebugChar 'K', 0
;ENDIF

       push    dx
       push    cx
       push    ax

       ; 
       ; save the current bank value
       ;
       mov     dx, pAS.BankSelect
       in      ax, dx
       push    ax


	SelectBank 020h
	mov	dx, pAS.Interrupt
	inc	dx				;Point to Mask Register
       in      al, dx
       push    ax                              ; save int mask value

       pushf                                   ; save current IFlag value

	cli
	mov	al, SCECMaskAllByte		;Disable all interrupts
	out	dx, al


	mov     dx, pAS.MMUCommand
	mov	ax, 0040h			;reset MMU command
	
	out     dx, ax


; vvvvvvvvvvvvv for Rev. C for FEAST vvvvvvvvvvvvvvvv
; the following EPH loopback is commented out
;
;
;	SelectBank 0
;	mov	dx, pAS.TCR				;enable eph loop
;	in	ax, dx			       
;	or	ax, 02000h
;	out	dx, ax
;
;
;	SelectBank 020h
;
;	mov     dx, pAS.MMUCommand
;	mov	ax, 0021h
;	
;	out     dx, ax
;
;;       Now, we will read the Alloc Int bit of Interrupt Register to see the 
;;       result of the Allocation Command
;
;	mov     dx, pAS.Interrupt
;	mov     cx, 15
;AllocValidLoop1:                 
;	in      ax, dx                          ;Test if allocation
;	test    al, 008h                    ; passes (Alloc Int=1)
;	jnz     AllocationPassed1
;	loop    AllocValidLoop1
;
;
;AllocationPassed1:
;
;	SelectBank	020h
;	mov     dx, pAS.PNR_ARR                     
;	in      ax, dx                          
;	mov     al, ah  
;	push	ax
;	out	dx, ax
;
;	mov	dx, pAS.Pointer
;	mov	ax, 04000h
;	out	dx, ax
;
;	mov     dx, pAS.Data0_1                     ;Set Data Port
;	mov	ax, 0
;	out	dx,ax
;	mov	ax, 42h
;	out	dx,ax
;
;	mov	ax, 0ffffh
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
;
;	mov	dx, pAS.Pointer
;	mov	ax, 04010h
;	out	dx, ax
;	mov     dx, pAS.Data0_1                     ;Set Data Port
;	mov	ax, 0
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
;	out	dx,ax
; 
;
;
;	mov     dx, pAS.MMUCommand                  
;	mov     ax, EnqueueIntoTXFifo
;	out     dx, ax
;
;
;	mov	cx, 1000
;loopwait:
;	mov	dx, pAS.Interrupt
;	in	al, dx 
;	test	al,1
;	jnz	foundit
;	loop	loopwait
;
;
;foundit:
;	mov	dx, pAS.MMUCommand
;	mov	al, 0080h
;	out	dx,al
;
; 	pop	ax
;	mov     dx, pAS.PNR_ARR         ;Already with SelectBank 2
;	out	dx,al			;release thexmit
;	
;
;	mov	dx, pAS.MMUCommand
;
;	mov	ax, 00a0h
;	out	dx, ax
;
;
;	;clear eph loop
;	SelectBank 0
;
;	mov	dx, pAS.TCR	
;	in	ax, dx			       
;	and	ax, 0dfffh
;	out	dx, ax
;	SelectBank 020h
;
;	mov	dx, pAS.Interrupt	;ack int
;	in	al, dx 
;	and	al, 0ffh
;	out	dx, al
;
; ^^^^^^^^^^^^^^^^^ EPH loopback is commented out ^^^^^^^^^^^^^^^^^^^^^^^^^^

       ; 
       ; replace the following 2 lines by popf instead, in case 
       ; IFlag is not set on module entry.
       ; 
	; EnableSCECInterrupts
	; sti
       ;
       popf

       pop     ax                      ; ax = int mask value
       mov     dx, pAS.Interrupt
       inc     dx
       out     dx, al


       ; 
       ; restore bank select value
       ;
       pop     ax
       mov     dx, pAS.BankSelect
       out     dx, ax

       pop     ax
       pop     cx
       pop     dx
	 
	ret

ASM_PROCEND	KickStart


IF MEM_UTIL
                  ;
;       MemoryUtilization
;
;       This routine updates memory utilization statistics variables.
;       This variables may be checked via DOSTEST utility.
;

MemoryUtilization      proc    near
		
	xor     cx, cx

	SelectBank 0
	mov     dx, pAS.MIR
	in      ax, dx                          ;AL = MEM SIZE, AH = FREE MEM
	mov     cl, ah  
	xor     ah, ah                          ; ax = MemSize, cx = FreeMem

	cmp     al, 0FFh                        ;Is it 64kb - 1 byte?
	jne     continue                        
	inc     ax                              ;Adjust mem size to 64kb

	cmp     cl, 0FFh                        ;Is it 64kb - 1 byte?
	jne     continue                        
	inc     cx                              ;Adjust free mem to 64kb
continue:
	push    cx                              ;Save Freemem
	mov     cl, pAS.MIRShlTo256ByteUnits        
	shl     ax, cl                          ;Correct Mem Size
	pop     cx                              ;Restore FreeMem
	push    ax                              ;Save corrected MemSize
	mov     ax, cx
	mov     cl, pAS.MIRShlTo256ByteUnits
	shl     ax, cl                          ;Correct Freemem
	mov     cx, ax                          
	pop     ax                              ;Restore corrected MemSize

IF TESTING_PARSER
	mov     bx, pAS.PreAllocatedMem        	;BX = FIXED PREALLOCATION
	sub     ax, bx                          ;AX = ACTUAL MEM SIZE
ENDIF
	sub     ax, cx                          ;AX = MEMORY USED
	Convert256ByteUnitsToSCECPages          ;Make it SCEC page units
	shl     ax, 2                           ;Adjust entry to table
						;(table is defined by dwords)


IF SPECIAL_VARS OR SHOW_REGS
	mov     pAS.OccupiedPagesOff, ax
ENDIF

	mov     di, ax                          ;di -> MemUtil corresp. var.
	cmp     di, 128                         ;Never have more than 32
	jbe     IsBelow32Pages                  ; mem-utils
	mov     di, 128
IsBelow32Pages:
	add     word ptr MemoryUtil0_2[di], 1   ;Increment it
	adc     word ptr MemoryUtil0_2 + 2[di], 0

	xor     ax, ax
	mov     al, pAS.TxPacketsInsideSCEC
IF SHOW_REGS
	mov     pAS.TxPcktsInSCEC, ax
ENDIF
	shl     ax, 2                           ;Adjust entry to table
						;(table is defined by dwords)
	mov     di, ax                          ;di -> MemUtil corresp. var.
						; for Tx stats
IF SPECIAL_VARS OR SHOW_REGS
	sub     pAS.OccupiedPagesOff, ax        ;Occupied pages = Rx pages
ENDIF

IF SPECIAL_VARS
	cmp     pAS.UseTxStats, 1
	je      SkipSetRxStats
	mov     di, OccupiedPagesOff

SkipSetRxStats:
	cmp     di, 128                         ;Never have more than 32
	jbe     IsBelow32Pages2                 ; mem-utils
	mov     di, 128
IsBelow32Pages2:

	add     word ptr MemoryUtilS0_2[di], 1  ;Increment it
	adc     word ptr MemoryUtilS0_2 + 2[di], 0
ENDIF

IF SHOW_REGS
	mov     ax, pAS.OccupiedPagesOff
	shr     ax, 2
	mov     RxPcktsInSCEC, ax
ENDIF

	SelectBank 020h
	ret

MemoryUtilization      endp

ENDIF   

;
;       RxIntr
;
;       Called by the DriverISR when it finds the RxInt bit in Interrupt
;       register set.
;
;       assumes:        ds      is set to CGroup
;                       CLD has been executed
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       all other registers may de destroyed
;                       SCEC in bank 2
;                       System Interrupts are disabled 
;                       SCEC Interrupts disabled
;                       ax(eax)  SUCCESS or EVENTS_DISABLED
;

RxIntr         proc    near
;IF K9DEBUG
;	OutDebugChar 'R', 0
;	OutDebugChar 'X', 0
;ENDIF

	mov     dx, pAS.Pointer                 ;Write Pointer Register with
						; RCV, READ and Autoinc on
	mov     rAX, ReceiveArea OR AutoIncrement OR ReadMode
	out     dx, ax

	PreventViolatingHardwareTimings

	mov     dx, pAS.Data0_1                 ;Set Data Port

	xor	rAX, rAX       			;clear ax
	mov     al, pAS.rx_lookahead_size       ;Get current look ahead value

        mov     rCX, 4				;Set RX_look to bytes, not 16
        shl     rAX, cl				;byte paragraphs...
	mov	rCX, rAX			;setup cx for byte count

        lea     rDI, pAS.look_ahead_buf

IFNDEF  CODE_386
        mov     ax, ds
        mov     es, ax
ENDIF
       mov     rSI, rDI                        ; save SI for lodsw later

       call    SlaveIn


	lodsw                                   ;Read Status Word [si]->ax

       xor     rBX, rBX                        ; set (bx)status for UM_Receive_Packet = 0        

	test    ax, SCEC_RXErrorBits            ;Is there any error ?
						; AlgnErr, BadCRC, TooShort,
						; TooLong
	jz      StatusWordOK
	
;                                               
;      if receive_mask has ACCEPT_ERR bit set
;       Reception Error Handler. Errors detected by SCEC
;
       
       test    pAS.receive_mask, ACCEPT_ERR_PACKETS
       jnz     ReceiveErrorHandler
       xor     rAX, rAX                        ; set up return code
       jmp     IssueRemoveRelease

ReceiveErrorHandler:
	test    ax, SCEC_BadRxCRC               ;Bad CRC ?
	jz      CheckTooShortFrameError

	IncUMACCounter	 ptr_rx_CRC_errors
	or      bx, CRCErrorBit

CheckTooShortFrameError:

IFDEF  DEBUG
	test    ax, SCEC_TooShortRXFrame        ;TooShort frame ?
	jz      CheckTooLongFrameError
	add     pAS.SCECRxTooShortCount, 1      ;Update statistics
	adc     pAS.SCECRxTooShortCount + 2, 0
ENDIF

CheckTooLongFrameError:
	test    ax, SCEC_TooLongRXFrame         ;TooLong frame ?
	jz      AlignmentError
       IncUMACCounter  ptr_rx_too_big

AlignmentError:
	test    ax, SCEC_AlignmentError         ;Alignment Error ?
	jz      ReceiveBadPacket

	IncUMACCounter	ptr_rx_align_errors	;increment error counter

	or      bx, CRCAlignErrorBit

ReceiveBadPacket:
StatusWordOK:

IFDEF  DEBUG
	test    al, SCEC_RxMulticastBit         ;Mask all except multicast 
	jz      CheckStatusWord                 ; bit
	add     pAS.RxMulticastCount, 1
	adc     pAS.RxMulticastCount + 2, 0

CheckStatusWord:
	test    ax, SCEC_RxBroadcastBit
	jz      CheckStatusOK
	add     pAS.RxBroadcastCount, 1
	adc     pAS.RxBroadcastCount + 2, 0
ENDIF

CheckStatusOK:
       mov     dx, ax                          ;save Rx status -> DX

	lodsw                                   ;Get Byte Count [si]-> AX

	and     ax, ByteCountMask               ;Zero Reserved high bits
;
	sub     ax, 5                           ; status(2) length(2) control(1)
	test    dh, OddFrameBitMask             ;Is it an ODDFRM ?
	jnz     ExactFrameLenght
	dec     ax                              ;Even number of bytes in Data 
						; Area
ExactFrameLenght:                               

       lea     rSI, pAS.look_ahead_buf         ;ES:[E]SI -> look ahead
	add	rSI, 4				;bypass status word 
						;and byte count

IFDEF  CODE_386
        movzx   ecx, ax
ELSE
        mov     cx, ax				;move full packet length in CX
ENDIF


; IF K9DEBUG
;	OutDebugChar 'U', 0
;	OutDebugChar 'R', 0
; ENDIF


;       Here we could place an address filtering routine indexed by the hash
;       value given by the SCEC in the Status Word of the received packet
;       It is not done by now. The address filtering is done by MSMGetRCB
;       in a flat way. 

       test    dl, SCEC_RxMulticastBit
       jz      ProcessPacket
       test    pAS.receive_mask, (PROMISCUOUS_MODE OR ACCEPT_MULTI_PROM)
       jnz     ProcessPacket
       call    CheckMultiAdd                   ; pass thru filter of MCTable
       cmp     rAX, SUCCESS                    ; accept ?
       je      ProcessPacket                   ; yes
       xor     rAX, rAX                        ; no, remove packet
       jmp     IssueRemoveRelease
ProcessPacket:
	ASM_CALL	UM_Receive_Packet
	
IssueRemoveRelease:

; 
; DO NOT SUPPORT PENDING return code
;

       push    rAX

	SelectBank 020h
	mov     dx, pAS.MMUCommand              ;Issue Remove&Release Command
	mov     ax, RemoveReleaseTopRXFifo
	out     dx, ax
	WaitForMMUReady

       pop     rAX

;IF K9DEBUG
;	OutDebugChar 'r', 0
;	OutDebugChar 'x', 0
;ENDIF

	ret

RxIntr endp



;
;       TxIntr
;
;       Called by DriverISR when it finds the TxInt bit in Interrupt
;       register set.
;
;       assumes:        ds      is set to CGroup
;                       CLD has been executed
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       (e)ax   = return code from UM_Send_Complete
;                       all other registers may de destroyed
;                       SCEC in bank 2
;                       SCEC Interrupts disabled
;                       System Interrupts disabled
;

TxIntr proc    near

; IF K9DEBUG
;	OutDebugChar 'T', 0
;	OutDebugChar 'X', 0
; ENDIF

       mov     dx, pAS.PNR_ARR                 ;Already with SelectBank 2
	in      al, dx                          ;Save Pkt Num Register in use 
	push    ax                              ; if any.

	mov     dx, pAS.FifoPorts               ;Read Tx done packet number 
	in      al, dx                          ; from Fifo Ports Register
						
WritePNR:
	mov     dx, pAS.PNR_ARR                 ;Write into Packet Number 
	out     dx, al                          ; Register
	mov     dx, pAS.Pointer                 ;Pointer with Read bit on, 
	mov     ax, ReadMode OR AutoIncrement   ; pointing to Status Word 
	out     dx, ax                          ; of Pkt.

	PreventViolatingHardwareTimings

	mov     dx, pAS.Data0_1
	in      ax, dx                          ;Read Status Word

       push    ax                              ; save status

IF K9DEBUG

       test    ax, SCEC_FatalErrors            ; 
       jz      statok

       test    ax, SCEC_16Collision
       jz      nerr1

	OutDebugChar '?', 0
	OutDebugChar '?', 0
	OutDebugChar '1', 0
	OutDebugChar '?', 0
	OutDebugChar '?', 0

nerr1:
       test    ax, SCEC_SQET
       jz      nerr2

	OutDebugChar '?', 0
	OutDebugChar '?', 0
	OutDebugChar '2', 0
	OutDebugChar '?', 0
	OutDebugChar '?', 0

nerr2:
       test    ax, SCEC_LateCollision
       jz      nerr3

	OutDebugChar '?', 0
	OutDebugChar '?', 0
	OutDebugChar '3', 0
	OutDebugChar '?', 0
	OutDebugChar '?', 0

nerr3:
       test    ax, SCEC_CarrierSenseLost
       jz      nerr4

	OutDebugChar '?', 0
	OutDebugChar '?', 0
	OutDebugChar '4', 0
	OutDebugChar '?', 0
	OutDebugChar '?', 0

nerr4:
       test    ax, SCEC_TxUnderrun
       jz      statok

	OutDebugChar '?', 0
	OutDebugChar '?', 0
	OutDebugChar '5', 0
	OutDebugChar '?', 0
	OutDebugChar '?', 0

statok:

ENDIF

;       Statistics Update

	test    ax, SCEC_StatisticsBits         ;any stat. to update ?
	jnz     DoNotReleaseTransmittedPckt
	jmp	ReleaseTransmittedPckt
	
DoNotReleaseTransmittedPckt:

IFDEF  DEBUG
	test    ax, SCEC_ExcessiveDeferral
	jz      TXDeferred
	add     pAS.ExcessiveDeferralCount, 1
	adc     pAS.ExcessiveDeferralCount + 2, 0

TXDeferred:     
	test    ax, SCEC_TXDeferred
	jz      LastTXMulticast
	add     pAS.TXDeferredCount, 1
	adc     pAS.TXDeferredCount + 2, 0

LastTXMulticast:
	test    ax, SCEC_LastTXMulticast
	jz      LastTXBroadcast
	add     pAS.TXMulticastCount, 1
	adc     pAS.TXMulticastCount + 2, 0

LastTXBroadcast:
	test    ax, SCEC_LastTXBroadcast
	jz      MultipleCollision
	add     pAS.TXBroadcastCount, 1
	adc     pAS.TXBroadcastCount + 2, 0

ENDIF

MultipleCollision:
	test    ax, SCEC_MultipleCollision
	jz      SingleCollision
;	IncUMACCounter	ptr_tx_total_collisions   - comment out, this doesn't look right
	IncUMACCounter	ptr_tx_mult_collisions

;	test	ax, SCEC_SuccessTx
;	jnz	SingleCollision

; vvvvvvvv comment out, this will be done in EPHIntr
;
;	IncUMACCounter	ptr_tx_max_collisions	;inc counter that says that
						;transmit failed due to excess
						;collisions
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
SingleCollision:
	test    ax, SCEC_SingleCollision
	jz      ReleaseTransmittedPckt
;	IncUMACCounter	ptr_tx_total_collisions - this doesn't look accurate
	IncUMACCounter	ptr_tx_one_collision

;       Note: Tx fatal errors could be tested here, statistics updated &
;             Transmitter reenabled. It is done via EPHIntr.
;             It is better to let EPHIntr to do transmitter reenbled(TXENA).

ReleaseTransmittedPckt:

;       See how much we should decrement the number of pckts
;       inside SCEC to update TxPacketsInsideSCEC
	xor	rAX,rAX
	in      ax, dx                          ;Get Byte Count
	and     ax, ByteCountMask
	add     ax, 255                         ;Make it in 256 byte page
	shr     ax, 8                           ; units.
	add     ax, pAS.SCECPageSize            ;Make SCEC page units
	dec     ax
	Convert256ByteUnitsToSCECPages
	sub     pAS.TxPacketsInsideSCEC, al

	mov     dx, pAS.MMUCommand              ;Issue MMU Release Command
	mov     ax, ReleaseSpecificPacket
	out     dx, ax
	WaitForMMUReady


; vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
; The following code is eliminated, its purpose is for flow control.
; The queueing of packets if no memory is available will NOT be done by
; LMAC, UMAC and MSM will handle it.
;
;	cmp     pAS.TXPacketRetainedFlag, 1     , If a packet is retained by
;	jne     TestAllocReqFlag                , software waiting for Tx
;
;check this.......
;	SetMaxMSMTxFreeCount                    , space, try to send it now.
;IFDEF CODE_386
;	movzx   rCX, pAS.HardwareFrameLength
;	movzx   rSI, pAS.DBOffsetPointer
;ELSE
;	mov     rCX, pAS.HardwareFrameLength
;	mov     rSI, pAS.DBOffsetPointer
;ENDIF
;	mov     pAS.TXPacketRetainedFlag, 0
;	call	Allocate
;	jmp     TXIntAcknowledge
;
;TestAllocReqFlag:
;	cmp     pAS.AllocationRequestedFlag, 1  , If no allocation pending tell 
;	je      TXIntAcknowledge                , MSM we have space again
;check this......
;	SetMaxMSMTxFreeCount
;
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

TXIntAcknowledge:
	mov     dx, pAS.Interrupt
	mov     al, TransmissionInt
	out     dx, al

;
;      notify UMAC that a packet has been send
;
       xor     rAX, rAX
       mov     ax, SUCCESS                     ; set up default
       pop     bx                              ; restore send status -> bx

       test    bx, SCEC_16Collision
       jz      SetTxStatus
       mov     ax, MAX_COLLISIONS
SetTxStatus:
       test    bx, SCEC_TxUnderrun
       jz      SetTxStatusDone
       or      ax, FIFO_UNDERRUN
SetTxStatusDone:


;IF K9DEBUG
;	OutDebugChar '<', 0
;	OutDebugChar 'S', 0
;	OutDebugChar 'C', 0
;	OutDebugChar '>', 0
;ENDIF




       ASM_CALL        UM_Send_Complete
       mov     bx, ax                          ; save return status -> bx
       cmp     rAX, EVENTS_DISABLED            ; if events disabled,
       je      SkipJumpWritePNR                ; get out



;       Any more packets in completion fifo ?
							  
	mov     dx, pAS.FifoPorts           
	in      al, dx                          ;Read Fifo Ports Register
	test    al, TEmptyBitMask               ;TEmpty=1 ?
	jnz     SkipJumpWritePNR
	jmp     WritePNR                        ;Do other packets

SkipJumpWritePNR:
	pop     ax                              ;Restore Pkt Num Register
	mov     dx, pAS.PNR_ARR             
	out     dx, al


IF K9DEBUG
	OutDebugChar 't', 0
	OutDebugChar 'x', 0
ENDIF

IFDEF  CODE_386
       movzx    rAX, bx
ELSE
       mov      ax, bx
ENDIF

	ret

TxIntr endp

;
;       AllocIntr
;
;       Called by the DriverISR when it finds the AllocInt bit in Interrupt
;       register set.
;
;       In normal cases, this handler will only be called because of
;       of the LM_Interrupt_Req.  Most allocation process uses polling.
;
;       assumes:        ds      is set to CGroup
;                       CLD has been executed
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       all other registers may de destroyed
;                       System Interrupts are disabled
;                       SCEC Interrupts are disabled
;                       SCEC in bank 2
;

AllocIntr      proc    near

IF K9DEBUG
	OutDebugChar 'A', 0
ENDIF

; Do nothing for this interrupt if issue from Transmit routines;
; the waiting for allocation done will be done by polling.
; 
;       There is no need to save PNR_ARR register 
;
;	mov     dx, PNR_ARR                     
;	in      ax, dx                          
;	mov     al, ah                          , al=PNR for CopyTXData
;
;	mov     cx, pAS.SCECSpaceForPacket      , Restore TotalPacketLength
;	mov     si, pAS.DBOffsetPointer         , Restore Data_buff address
;
;	call	CopyTxData              , Returns with system ints.
;						, disabled
;	
;	mov     pAS.AllocationRequestedFlag, 0  , Turn off flag
;
;verify this is correct!!!!!!!!
;	SetMaxMSMTxFreeCount


       push    dx
       push    ax
       
       ; 
       ; Read the status of the allocation cmd and the packet number assigned
       ; if success.
       ;
       mov     dx, pAS.PNR_ARR                 
       in      ax, dx                          ; al = current pkt #,
                                               ; ah = status & alloc pkt #

       test    ah, 080h                        ; if failed
       jnz     IntReqTestX                     ; exit

       ; 
       ; alloc success
       ;
       xchg    ah, al                          ; al = status & alloc pkt #
                                               ; ah = current pkt #
       out     dx, al                          ; set up tx pkt #
       mov     dx, pAS.MMUCommand
       mov     al, ReleaseSpecificPacket       ; de-allocate mem
       out     dx, al

IntReqPoll:
       in      al, dx                          ; poll for completion
       test    al, 1
       jnz     IntReqPoll

       mov     al, ah                          ; al = previous pkt #
       mov     dx, pAS.PNR_ARR
       out     dx, al                          ; restore it

IntReqTestX:
       ; 
       ; mask off allocation Int
       ;
       mov     dx, pAS.Interrupt
       inc     dx
       in      al, dx
       and     al, AllocationIntDis
       out     dx, al

       mov     pAS.AllocationRequestedFlag, 0  ; clear test flag

       ASM_CALL        UM_Interrupt


IF K9DEBUG
	OutDebugChar 'a', 0
ENDIF

       pop     ax
       pop     dx
	ret

AllocIntr      endp

;
;       RxOvrnIntr
;
;       Called by the DriverISR when it finds the RxOvrnInt bit in Interrupt
;       register set.
;
;       assumes:        ds      is set to CGroup
;                       CLD has been executed
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       all other registers may de destroyed
;                       System Interrupts are disabled
;                       SCEC Interrupts are disabled
;                       SCEC in bank 2
;

RxOvrnIntr     proc    near

; IF K9DEBUG
;	OutDebugChar 'O', 0
; ENDIF

	IncUMACCounter	ptr_rx_lost_pkts	;increment error counter

;	add     pAS.DriverStatRxOverflow, 1     ;Update Statistics
;	adc     pAS.DriverStatRxOverflow + 2, 0

;       ASM_CALL        KickStart

	mov     dx, pAS.Interrupt
	mov     al, RxOverrunInt
	out     dx, al                          ;Acknowledge RxOvrn int.

	xor	rAX,rAX
	mov     ax, pAS.SCECMaxPagesForTx
	sub     ax, pAS.SCEC1518InSCECPages     ;Decrement max pages for Tx
	cmp     ax, pAS.SCEC1518InSCECPages     ; to appropiate value
	jbe     SetMinimun                      
	mov     ax, pAS.SCEC1518InSCECPages
	sub     pAS.SCECMaxPagesForTx, ax
	jmp     SkipSetMinimum
SetMinimun:
	mov     ax, pAS.SCEC1518InSCECPages
	mov     pAS.SCECMaxPagesForTx, ax
SkipSetMinimum:

;       Set statistic table Max Mem occupied on Tx var.

	mov     ax, 100
	mul     pAS.SCECMaxPagesForTx               ;DX:AX = 100 * MaxPages
	div     pAS.SCECNumberOfPages               ;AX = int (100 * " /NumOfP)
	mov     word ptr pAS.MaxPercentageOnTx, ax

;IF K9DEBUG
;	OutDebugChar 'o', 0
;ENDIF

	ret

RxOvrnIntr     endp

;
;       EPHIntr - Called by DriverISR when it finds the EPHInt bit           
;                 in Interrupt register set, or by DriverReset. Sets         
;                 the AUI bit in Configuration Register accordingly.         
;
;       assumes:        ds      is set to CGroup
;                       SCEC is in bank 2
;                       SCEC Interrupts are disabled
;                       System Interrupts are enabled
;
;       returns:        ds      is set to CGroup
;                       ax = SUCCESS
;                       all other registers may de destroyed
;                       SCEC Interrupts are disabled
;                       System Interrupts are disabled
;                       SCEC in bank 2
;

EPHIntr        proc    near

IF K9DEBUG
	OutDebugChar '<', 0
	OutDebugChar 'E', 0
	OutDebugChar 'P', 0
ENDIF

;       First we will determine if there was a fatal error.

	SelectBank 0
	mov     dx, pAS.StatusRegister              
	in      ax, dx

	test    ax, SCEC_FatalErrors    
	jz      EPHExit                         ;No Fatal error. Process media Type.
;
;       Transmission Fatal Error. Update counters & Reenable Tx. 
;       Fatal Error Packet's memory is not released here. It will be in
;       next TxIntr.
;

;	add     pAS.DriverStatTxMisc, 1
;	adc     pAS.DriverStatTxMisc + 2, 0

; IF K9DEBUG
;	OutDebugChar '*', 0
;	OutDebugChar '*', 0
;	OutDebugChar '*', 0
;	OutDebugChar '*', 0
; ENDIF

CheckCarrierSense:
	test    ax, SCEC_CarrierSenseLost       ;Cable was pulled out ?
	jz      short TxUnderrun                ;Jump if not.
       IncUMACCounter  ptr_tx_carrier_lost

TxUnderrun:
	test    ax, SCEC_TxUnderrun             ;Check for Tx Underrun
	jz      short SixteenCollisions
       IncUMACCounter  ptr_tx_underruns

SixteenCollisions:
	test    ax, SCEC_16Collision            ;Check for 16 bit Collision
	jz      LateCollision
       IncUMACCounter  ptr_tx_max_collisions
	
LateCollision:
	test    ax,SCEC_LateCollision
	jz      SQET
       IncUMACCounter  ptr_tx_ow_collision

SQET:

IFDEF  DEBUG
	test    ax, SCEC_SQET
	jz      ReenableTX
	add     pAS.SQETCount, 1
	adc     pAS.SQETCount + 2, 0
ENDIF

ReenableTX:
	mov     dx, pAS.TCR	                 ;Enable Tx & flush error bits
	in      ax, dx
	or      ax, TXENA_SetMask
	out     dx, ax

;
; the following code is added to bypass the auto media detect for 9232 board
;
EPHExit:

       ; has to clear previous link interrupt condition
       ;
       SelectBank 010h
       mov     dx, pAS.Control
       in      ax, dx
       and     ax, ControlClrLEMask
       out     dx, ax
       or      ax, ControlSetLEMask
       out     dx, ax

       SelectBank 020h

       xor     rAX, rAX
       ret



EPHIntr        endp


IFNDEF CODE_386
.386
ENDIF

;******************************************************************************
;
;       lm_Receive_Copy
;                       DS:BP   ptr to adapter structure
;                       ES:SI   ptr to data buffer structure
;                       CX      receive byte count
;                       AX      Offset into the packet
;
;******************************************************************************
FragDoneJmp:                                   ; force a long jump
       jmp     FragDone


ASM_FST_PROCDEF	LM_Receive_Copy

IFNDEF  CODE_386
;IF K9DEBUG
;	OutDebugChar '<', 0
;	OutDebugChar 'R', 0
;	OutDebugChar 'C', 0
;	OutDebugChar '>', 0
;ENDIF
ENDIF

        push    bx
        push    dx
        push    rCX
        push    rSI
        push    edi
        push    rBP
IFNDEF  CODE_386
        push    es
        push	 ds
ENDIF
	
       cld

	SelectBank 020h
	mov     dx, pAS.Pointer                     ;Pointer Register points to 
						; the value returned in AX+4 
	add     ax, ReceiveArea OR AutoIncrement OR ReadMode
	add	ax, 4				;bypass 4 byte SCEC header
	out     dx, ax

	PreventViolatingHardwareTimings

	mov     dx, pAS.Data0_1                 ; dx = data IO port

	mov	rBX, rSI			;es:bx(ebx) -> data buffer structure
	add	rBX, size fragment_count	;es:bx(ebx) -> first first fragment ptr
	mov	rSI, rCX			;setup si to be receive byte 

FillECBLoop:
IFNDEF   CODE_386
	mov     cx, word ptr es:[bx+4]             ;Get this frags length
	jcxz    FragDoneJmp			;Skip this fragment
ELSE
	mov     rCX, dword ptr [rBX+4]          ;Get this frags length
       jecxz   FragDoneJmp
ENDIF

       mov     rAX, rCX                        ; rAX = frag byte count
       and     rCX, NOT PHYSICAL_ADDR          ; rCX = real count w/o flag
       cmp     rCX, rSI                        ; Which one is greater ?
       jb      UseOneFromRCB                   ; jmp is more frags are needed        
       mov     rCX, rSI                        ; Do remainder
UseOneFromRCB:
       sub     rSI, rCX

       test    rAX, PHYSICAL_ADDR
       jnz     IsDMAFrag

;
; non DMA, IO move string
;
       
IFNDEF  CODE_386
       push    es
       les     di, dword ptr es:[bx]           ; es:di(edi) = frag buffer pointer
ELSE
       mov     rDI, dword ptr [rBX]
ENDIF

       call    SlaveIn

IFNDEF CODE_386
       pop     es
ENDIF
       jmp     FragDone

;
; Do DMA move
;
IsDMAFrag:

IFDEF  CODE_386
       mov     edi, dword ptr [rBX]
ELSE
       mov     edi, dword ptr es:[bx]
ENDIF

       call    DMAIn


;
; next fragment
;
FragDone:
	add     rBX, SIZE FragmentStructure             ;Go to next frag. descriptor
	or      rSI, rSI
	jnz     FillECBLoop


        mov     rAX, SUCCESS

IFNDEF  CODE_386
	pop	ds
       pop     es
ENDIF
       pop	rBP
       pop     edi
       pop     rSI
       pop     rCX
       pop     dx
       pop     bx

IFNDEF  CODE_386
;IF K9DEBUG
;	OutDebugChar '<', 0
;	OutDebugChar 'r', 0
;	OutDebugChar 'c', 0
;	OutDebugChar '>', 0
;ENDIF
ENDIF

        ret

ASM_FST_PROCEND	LM_Receive_Copy

IFNDEF CODE_386
.286
ENDIF


;*----------------------------------------------------------------------*
;*	InitErrorCounters : 
;*     Initializes error counters to point to pAS.dummy_vector if they
;*     are not initialized by UMAC.
;*                    
;*	All Registers are preserved					
;*----------------------------------------------------------------------*
InitErrorCounters      proc    near
		push	rAX
		push	rBX
		push	rCX
		push	rSI

		lea	rBX, pAS.ptr_rx_CRC_errors	; Get address of first counter.
		lea	rCX, pAS.ptr_ring_OVW		; Get address of last counter.
		sub	rCX, rBX			; Subtract to get difference.
		shr	rCX, 1				; Divide by 4.
		shr	rCX, 1				; CX = # of counters.
		inc	rCX

		mov	rSI, rBX
		lea	rBX, pAS.dummy_vector		; EBX = offset of dummy vector.
							; ESI = offset of first counter.
CheckVectors:

ifdef  CODE_386
		cmp	dword ptr [esi], 0
else
		lodsw
		or	ax, ds:[si]			; Get pointer
endif
		jnz	SkipThisVector			; If null, fill with dummy vector.


ifdef  CODE_386       
		mov	[esi], ebx
else
		mov	ds:[si-2].ofst, bx
		mov	ds:[si-2].sgmt, ds
endif


SkipThisVector:

ifdef  CODE_386       
		add	rSI, 4
else
		add	rSI, 2
endif
		loop	CheckVectors

		pop	rSI
		pop	rCX
		pop	rBX
		pop	rAX

		ret
InitErrorCounters      endp


; -----------------------------------------------------------------
;  GET configuration routines for ISA board
; -----------------------------------------------------------------

IFDEF   FEASTISA


IO_BASE_MIN	equ	0200h
IO_BASE_MAX	equ	0400h
IO_BASE_STEP	equ	010h
NODE_ADDRESS_1	equ	00h
NODE_ADDRESS_2	equ	80h
NODE_ADDRESS_3	equ	0Fh

; -----------------------------------------------------------------
; check io base
; -----------------------------------------------------------------

ASM_PROCDEF	check_io_base
	mov	ax, IO_BASE_MIN			; initialize temp_io_base
loop_io_base:
	cmp	ax, IO_BASE_MAX			; out of valid range???
	jg	invalid_io_base			; yes, so show error
	cmp	ax, pAS.io_base			; is it the configured value???
	je	valid_io_base			; yes, so show value is valid
	add	ax, IO_BASE_STEP		; go to next possible value
	jmp	loop_io_base
valid_io_base:
	xor	rAX, rAX			; ax = SUCCESS
	ret
invalid_io_base:
	mov	rAX, CONFIG_ERROR		; error
	mov	rDX, IO_BASE_RANGE
	ret
ASM_PROCEND	check_io_base

; -----------------------------------------------------------------
; check lan address
; -----------------------------------------------------------------

ASM_PROCDEF	check_lan_address

	cmp	pAS.node_address+0, NODE_ADDRESS_1
	jne	check_lan_address_err
	cmp	pAS.node_address+1, NODE_ADDRESS_2
	jne	check_lan_address_err
	cmp	pAS.node_address+2, NODE_ADDRESS_3
	jne	check_lan_address_err
	mov	ax, 0
        jmp     short   check_lan_address_ok

check_lan_address_err:
	mov	ax, 1
        mov     word ptr pAS.node_address, 0
        mov     word ptr pAS.node_address+2, 0
        mov     word ptr pAS.node_address+4, 0
check_lan_address_ok:

	ret


ASM_PROCEND	check_lan_address


;*----------------------------------------------------------------------*
;*	set_adapter_name: loads pAS.adapter_name with string    *
;*                                                    			*
;*	Input:  nothing                                              	*
;*	Output: nothing							*
;*	All Registers are preserved					*
;*----------------------------------------------------------------------*
ASM_PROCDEF	set_adapter_name
	mov	pAS.adapter_name+0, 'S'
	mov	pAS.adapter_name+1, 'M'
	mov	pAS.adapter_name+2, 'C'
	mov	pAS.adapter_name+3, '9'
	mov	pAS.adapter_name+4, '0'
	mov	pAS.adapter_name+5, '0'
	mov	pAS.adapter_name+6, '0'
	mov	pAS.adapter_name+7, 0

	ret

ASM_PROCEND	set_adapter_name

;*-------------------------------------------------------------------*
;*     Reg_int_line: 			                             *
;*                                                                   *
;*     Input:  nothing                                               *
;*     output: Sets up pAS.irq_value			 	     *
;*     Assume: registers are preserved                               *
;*-------------------------------------------------------------------*
ASM_PROCDEF	Reg_int_line

;       Register adapters physical interrupt line
	SelectBank 010h
	mov     dx, pAS.Configuration
	in      ax, dx                          ;Save IntSel bits from 
	mov     bx, ax                          ; config reg in bx. 
	and     bx, IntSelectionMask              
;	mov     ax, pAS.irq_value               ;al = Interrupt from UMAC
;	cmp     ax, 0
;	jne     InterruptOverride

	mov     ax, bx
	shr     ax, 1

	cmp	al,0
	jne	NextInt1
	mov	pAS.irq_value,2			;set to irq #
	jmp	short NextInt4

NextInt1:
	cmp	ax,1
	jne	NextInt2
	mov	pAS.irq_value,3			;set to irq #
	jmp	short NextInt4

NextInt2:
	cmp	ax,2
	jne	NextInt3
	mov	pAS.irq_value,10		;set to irq #
	jmp	short NextInt4

NextInt3:
	cmp	ax,3
	jne	NextInt4
     	mov	pAS.irq_value,11		;set to irq #

NextInt4:
InterruptOverride:

	ret

ASM_PROCEND	Reg_int_line

; -------------------------------------------------------------------
;
;	lm_GetCnfg
;
;	assumes:
;
;	returns:
;			All other registers and flags can be destroyed
; -------------------------------------------------------------------

ASM_PROCDEF	LM_GetCnfg
	
;	Check for a NIC in the machine.  If we are given a specific
;	slot then we will check there for a NIC.  If no slot was specified
;	by the user then we will scan the slots for a NIC and use the first
;	one that is found.



;int 3
	push	rBX
	push	rCX
	push	rDX
	push	rDI
	push	rSI
	push	rBP
	
	ASM_CALL	check_io_base
	or	ax, ax
	jz	LMGETok1
	
	jmp	do_the_return		;exit with error
LMGETok1:

	mov     rCX, NumIOPorts
	lea     si, pAS.TCR
	mov	ax, pAS.io_base

LMGETPortLoop2:
	mov     word ptr [si]+0  , ax             ;Add in base I/O port bank1
	mov     word ptr [si]+16 , ax             ;Add in base I/O port bank2
	mov     word ptr [si]+32 , ax             ;Add in base I/O port bank3
	mov     word ptr [si]+48 , ax             ;Add in base I/O port bank4
	add     si, 2
	add     ax, 2
	loop    LMGETPortLoop2

;       Check for SMC9000 pattern in BankSelect register

	mov     dx, pAS.BankSelect
	in      ax, dx
	cmp     ah, SMC9000Pattern
	jne     do_the_return

;	We found the card
	call	GetLANAddress

	ASM_CALL	check_lan_address
	or	ax, ax
	jnz	do_the_return

;       Register adapters physical interrupt line

	ASM_CALL	Reg_int_line

	ASM_CALL	set_adapter_name

isa_ok:
	mov	rAX, ADAPTER_AND_CONFIG		; pre-load a non ISA code
	
	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
	
	ret							     

do_the_return:
	mov	rAX, ADAPTER_NOT_FOUND
	
	pop	rBP
	pop	rSI
	pop	rDI
	pop	rDX
	pop	rCX
	pop	rBX
  
	ret

ASM_PROCEND	LM_GetCnfg


ENDIF







