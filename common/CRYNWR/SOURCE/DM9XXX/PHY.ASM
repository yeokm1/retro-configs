;*****************************************************************************
;* Name : PHY.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description : Setup PHY procedure, include reset, read & write register.
;*
;* Functions :
;*	. MIIDelay
;*	. Syn_PHY
;*	. Read_Register_PHY
;*	. PHY_start_code
;*	. PHY_write_readcode
;*	. PHY_write_Addr
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96
;*
;* Change Notes :
;* Date - Modifier
;*     Cause :
;*  Modified :
;*    Result :
;
; Maintainers:
;
; John H.T. Ho		htho
;
;
; Revision History:
;
; Date	     Modfier.	Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.4.24	htho	fail to detect existance of 9801 if run RPHY.EXE first
;
;*
;*****************************************************************************
.model tiny
.386

code	segment para  public
	assume	cs:code, ds:code

include phy.inc

EXTRN	PortReadTickCounter : NEAR
EXTRN	p_CR9 : WORD
EXTRN	PortPrintMessage : NEAR

PHY_Fail_msg	     DB      'Debug: Can not read the register of PHY.'
		     DB      0Dh,0Ah
PHY_Fail_msg_len     EQU     $ - PHY_Fail_msg

;--------------------------------------------------------------------+
; Name : MIIDelay
;
; Description: MII clock (MDC) has a maximum clock rate of 2.5Mhz(400ns).
;	PortReadTickCounter gives 419 nsec per count.
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC	MIIDelay
MIIDelay  proc	  near
;	cli
	push	ax
	push	bx
	call	PortReadTickCounter	;Get initial value, Return counter value = AX
	mov	bx, ax			;Save start value

MIID_loop:
	call	PortReadTickCounter
	neg	ax
	add	ax, bx			;Get difference
	cmp	ax, 2
	jb	SHORT MIID_loop
	pop	bx
	pop	ax
;	sti
	ret
MIIDelay  endp

;--------------------------------------------------------------------+
; Name : Syn_PHY
;
; Description: Sends a sequence of 32 contiguous 1's on MDIO to provide
;	the PHY with a sequence that can be used to establish synchronization.
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC	Syn_PHY
Syn_PHY 	PROC	NEAR
	mov	eax, PHY_clkL_Write_1	;; clk low
	out	dx, eax
	call	MIIDelay

;;-+, 2000.4.24, htho
;;	mov	cx, 20h
	mov	cx, 22h
;;-+
Syn_seq:
	mov	eax, PHY_clkH_Write_1	;; clk high
	out	dx, eax
	call	MIIDelay		;; Delay 419ns
	mov	eax, PHY_clkL_Write_1	;; clk low
	out	dx, eax
	call	MIIDelay
	loop	Syn_seq
	ret
Syn_PHY 	ENDP


;--------------------------------------------------------------------+
; Name : Read_Register_PHY
;
; Description: Read each of 16 registers of PHY.
;
; Enter : BL = register index.
;	  BH = PHY address.
;
; Return : AX = register data.
;	   carry flag set = PHY fail.
;		    clear = sucessful.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC	Read_Register_PHY
Read_Register_PHY	PROC	NEAR
	mov	dx, p_CR9
;; -- Synchronization
	call	Syn_PHY
;; -- Start state
	call	PHY_start_code		;; Start Code <01>
;; -- Code state (Read)
	call	PHY_write_readcode	;; Read command
;; -- PHY address state
	mov	al, bh			;; PHY address
	call	PHY_write_Addr
;; -- Register address state
	mov	al, bl			;; PHY's register address
	call	PHY_write_Addr
;; -- TurnAround state
	mov	eax, PHY_clkL_Write_1	   ;; clk low & Read
	out	dx, eax
	mov	eax, PHY_clkH_Write_1	   ;; Change to read operation & clk high
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1	   ;; clk low & Read
	out	dx, eax
	call	MIIDelay
;; -- Check turnaround bit
;	 mov	 eax, PHY_clkH_Read	 ;; clk high & Read
;	 out	 dx, eax
;	 in	 eax, dx
;	 test	 eax, CR9_M_MDI 	;; bit19 = 0 ?
;	 jnz	 PHY_fail
;; -- Register Data state
;; -- Read data (MDI)
;	mov	eax, PHY_clkL_Read
;	out	dx, eax
;	call	MIIDelay
;	mov	eax, PHY_clkH_Read
;	out	dx, eax
;	call	MIIDelay
;	mov	eax, PHY_clkL_Read
;	out	dx, eax
;	call	MIIDelay

	push	ebx
	xor	bx, bx		      ;; Clear BX
	mov	cx, 16
PHY_read_cyc:
	mov	eax, PHY_clkH_Read	;; clk high & Read
	out	dx, eax
	call	MIIDelay
	in	eax, dx
	and	eax, CR9_M_MDI		;; mask MDI bit
	shr	eax, CR9_S_MDI
	shl	bx, 1
	or	bx, ax		      ;; save bit

	mov	eax, PHY_clkL_Read	 ;; clk low & Read
	out	dx, eax
	call	MIIDelay
	loop	PHY_read_cyc

;;--- Add clock to release bus
	mov	eax, PHY_clkH_Read	;; clk high & Read
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Read	 ;; clk low & Read
	out	dx, eax
	call	MIIDelay

	mov	ax, bx		      ;; Return register data
	pop	ebx
	clc
	jmp	PHY_read_ok
PHY_fail:

	mov  si, OFFSET PHY_Fail_msg
	mov  cx, PHY_Fail_msg_len
	call PortPrintMessage
	stc

PHY_read_ok:
	ret

Read_Register_PHY	ENDP

;--------------------------------------------------------------------+
; Name : Write_Register_PHY
;
; Description: Write each of 16 registers of PHY.
;
; Enter : BL = register index.
;	  BH = PHY address.
;	  DX = Write Data
;
; Return : None
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC	Write_Register_PHY
Write_Register_PHY	 PROC	 NEAR
	push	dx			;; Push write data

	mov	dx, p_CR9
;; -- Synchronization
	call	Syn_PHY
;; -- Start state
	call	PHY_start_code		;; Start Code <01>
;; -- Code state (Read)
	call	PHY_write_writecode	 ;; Read command
;; -- PHY address state
	mov	al, bh			;; PHY address
	call	PHY_write_Addr
;; -- Register address state
	mov	al, bl			;; PHY's register address
	call	PHY_write_Addr
;; -- TurnAround state
	mov	eax, PHY_clkL_Write_1	   ;; clk low & Read
	out	dx, eax
	mov	eax, PHY_clkH_Write_1	   ;; Change to read operation & clk high
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1	   ;; clk low & Read
	out	dx, eax
	call	MIIDelay

	mov	eax, PHY_clkL_Write_0	   ;; clk low & Read
	out	dx, eax
	mov	eax, PHY_clkH_Write_0	   ;; Change to read operation & clk high
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_0	   ;; clk low & Read
	out	dx, eax
	call	MIIDelay

;; -- Write register data
	pop	bx				;; Pop write data
	mov	cx, 16
Write_loop:
	shl	bx, 1
	jc	Write_pat1
Write_pat0:
	mov	eax, PHY_clkL_Write_0
	out	dx, eax
	mov	eax, PHY_clkH_Write_0
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_0
	out	dx, eax
	call	MIIDelay
	jmp	Write_ret_loop

Write_pat1:
	mov	eax, PHY_clkL_Write_1
	out	dx, eax
	mov	eax, PHY_clkH_Write_1
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1
	out	dx, eax
	call	MIIDelay

Write_ret_loop:
	loop	Write_loop

	ret

Write_Register_PHY	 ENDP

;--------------------------------------------------------------------+
; Name : PHY_start_code
;
; Description: Start code <01> pattern to transition the MDIO from
;		the default idle line state.
;
; Enter : DX = CR9 I/O address.
;
; Return : None
;
; Destroied registers : EAX.
;
;---------------------------------------------------------------------+
	PUBLIC	PHY_start_code
PHY_start_code	PROC	NEAR
;; -- Write 0 pattern
	mov	eax, PHY_clkL_Write_0	;; Stable Data
	out	dx, eax
	mov	eax, PHY_clkH_Write_0	;; clk high, Write & MDO=0.
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_0	;; clk low, Write & MDO=0.
	out	dx, eax
	call	MIIDelay
;; -- Write 1 pattern
	mov	eax, PHY_clkL_Write_1
	out	dx, eax
	mov	eax, PHY_clkH_Write_1	;; clk high, Write & MDO=1.
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1	;; clk high, Write & MDO=1.
	out	dx, eax
	call	MIIDelay
	ret
PHY_start_code	ENDP

;--------------------------------------------------------------------+
; Name : PHY_write_readcode
;
; Description: Read code <10> pattern to execute read command.
;
; Enter : DX = CR9 I/O address.
;
; Return : None
;
; Destroied registers : EAX.
;
;---------------------------------------------------------------------+
	PUBLIC	PHY_write_readcode
PHY_write_readcode	PROC	NEAR
	mov	eax, PHY_clkL_Write_1		;; clk low, Write & MDO=1.
	out	dx, eax
	mov	eax, PHY_clkH_Write_1		;; clk high, Write & MDO=1.
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1		;; clk low, Write & MDO=1.
	out	dx, eax
	call	MIIDelay

	mov	eax, PHY_clkL_Write_0		;; clk low, Write & MDO=0.
	out	dx, eax
	mov	eax, PHY_clkH_Write_0		;; clk high, Write & MDO=0.
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_0		;; clk low, Write & MDO=0.
	out	dx, eax
	call	MIIDelay
	ret
PHY_write_readcode	ENDP

;--------------------------------------------------------------------+
; Name : PHY_write_writecode
;
; Description: Write code <01> pattern to execute read command.
;
; Enter : DX = CR9 I/O address.
;
; Return : None
;
; Destroied registers : EAX.
;
;---------------------------------------------------------------------+
	PUBLIC	PHY_write_writecode
PHY_write_writecode	 PROC	 NEAR
	mov	eax, PHY_clkL_Write_0		;; clk low, Write & MDO=1.
	out	dx, eax
	mov	eax, PHY_clkH_Write_0		;; clk high, Write & MDO=1.
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_0		;; clk low, Write & MDO=1.
	out	dx, eax
	call	MIIDelay

	mov	eax, PHY_clkL_Write_1		;; clk low, Write & MDO=0.
	out	dx, eax
	mov	eax, PHY_clkH_Write_1		;; clk high, Write & MDO=0.
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1		;; clk low, Write & MDO=0.
	out	dx, eax
	call	MIIDelay
	ret
PHY_write_writecode	 ENDP

;--------------------------------------------------------------------+
; Name : PHY_write_Addr
;
; Description:
;		Normal, this address extract from serial ROM.
;
; Enter : DX = CR9 I/O address.
;	  AL = address.
;
; Return : None
;
; Destroied registers : EAX, BH.
;
;---------------------------------------------------------------------+
	PUBLIC	PHY_write_Addr
PHY_write_Addr	     PROC    NEAR
	push	bx
	mov	bh, al
	shl	bh, 3				;; Align to 5 bits.
	mov	cx, 5				;; PHY address are 5 bits.
addr_loop:
	shl	bh, 1
	jc	pattern1
pattern0:
	mov	eax, PHY_clkL_Write_0
	out	dx, eax
	mov	eax, PHY_clkH_Write_0
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_0
	out	dx, eax
	call	MIIDelay
	jmp	addr_ret_loop

pattern1:
	mov	eax, PHY_clkL_Write_1
	out	dx, eax
	mov	eax, PHY_clkH_Write_1
	out	dx, eax
	call	MIIDelay
	mov	eax, PHY_clkL_Write_1
	out	dx, eax
	call	MIIDelay

addr_ret_loop:
	loop	addr_loop

	pop	bx
	ret
PHY_write_Addr	     ENDP

code		ends

		end
