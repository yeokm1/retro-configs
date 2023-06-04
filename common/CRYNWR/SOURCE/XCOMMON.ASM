;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; (C) Copyright 1992 Standard Microsystems Corp. All rights reserved.
;
; XCOMMON.ASM	Extended LMAC Routines for Ethernet/Token Ring adapters
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
db		'@(#) SMC Extended LMAC Module XCOMMON.ASM v1.12',0,'$'
.xlist
include	POPFF.MAC
.list

PUBLIC	LM_Rom_Test
PUBLIC	LM_Bic_Test
PUBLIC	LM_Check_LAN_Addr_ROM
PUBLIC	LM_Ram_Test

;extrn	RecallEERomData:	near
;extrn	SelectOtherRegister:	near

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Rom_Test	Tests ROM space and ROM checksum on SMC LAN adapters
;
;		Entry:	DS:BP	Ptr to adapter Structure
;		Exit:	AX	SUCCESS
;				ROM_CONFLICT
;				RAM_CONFLICT
;				ROM_SIGNATURE_ERROR
;				ROM_CHECKSUM_ERROR
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
LM_Rom_Test	proc	far
else
LM_Rom_Test	proc	near
endif
		push	bx
		push	cx
		push	dx
		push	di
		push	es
		pushf
		cli

		mov	bx, ds:[bp].rom_size
		or	bx, bx
		jz	RomTestSuccess		; If no ROM, exit SUCCESS.

		les	di, ds:[bp].easp	; ES:DI now points to Extended Adapter Structure

		mov	es:[di].brom_hold, 0FFh
		mov	es, word ptr ds:[bp].rom_access.sgmnt
		mov	ax, DESELECT		; Disable ROM so address space can
		call	SelectRom		; be verified.
		jc	SkipRomSpaceTests	; If CARRY is set, it is not possible
		mov	cx, 10			; to disable the ROM. Space tests will
		shl	bx, cl			; be skipped in those cases.
		mov	cx, bx			; BX = CX = rom size in bytes.
		call	RomSignatureTest	; Test for presence of some other ROM
		jc	RomTestRomConflict	

RomSignatureTestPassed:
		mov	di, word ptr ds:[bp].rom_access.ofst
		call	RamSpaceTest	;
		jc	RomTestRamConflict
		mov	ax, SELECT
		call	SelectRom	; Re-enable Rom

SkipRomSpaceTests:
		mov	di, word ptr ds:[bp].rom_access.ofst
		mov	ax, es:[di]
		cmp	ax, ROM_SIGNATURE
		jne	RomTestRomSignature
		mov	al, es:[di+2]
		mov	ah, byte ptr ds:[bp].rom_size
		shl	ah, 1			; ROM size in adapter struc is in KB, Intel header is in 0.5KB units.
		cmp	ah, al			; If ROM window is smaller than the logical ROM size, bail out with error code.
		jb	RomTestRomSizeMismatch
		je	OneRomInstance		; If they match, there is one logical ROM in the ROM window.

; At this point, either there are two logical ROMs in the ROM window, or the window is too big.
; Test for two ROMs in the wondow. AL = logical ROM size, AH = ROM window size, both in 512-byte chunks.

		shl	al, 1			; Double logical ROM size. If not equal to ROM window size, bail.
		cmp	ah, al
		jne	RomTestRomSizeMismatch

		xor	bl, bl			; Calculate 2nd ROM offset by adding size of first ROM, and save in BX.
                mov     bh, al

		call	ChecksumBootRom
		jnz	RomTestRomChecksum	; If the first ROM does not checksum, indicate checksum failure.

		add	word ptr ds:[bp].rom_access.ofst, bx
		mov	ax, es:[bx]

; If the second ROM signature is not there, we return a size error, not a signature error. This is because the first logical
; ROM checked out OK. We are assuming that the ROM required a window size that matches the first logical ROM. There may be a
; second logical ROM here, but we have no way of discerning a conflict from random data. 

		cmp	ax, ROM_SIGNATURE
		jne	RomTestRomSizeMismatch

; If the second ROM does not checksum, either there is only one logical ROM at offset 0, or the second ROM is
; corrupt/conflicting. Since we found a ROM signature, we will assume that there is a 2nd logical ROM.

OneRomInstance:
		call	ChecksumBootRom
		jnz	RomTestRomChecksum

RomTestSuccess:
		mov	ax, SUCCESS

RomTestExit:
		mov	word ptr ds:[bp].rom_access.ofst, 0
		push	ax
		mov	ax, SELECT	; Re-enable ROM ???
		call	SelectRom	; 
		pop	ax		; 

		$POPFF
		pop	es
		pop	di
		pop	dx
		pop	cx
		pop	bx
		ret

RomTestRomConflict:
		mov	ax, ROM_CONFLICT
		jmp	RomTestExit

RomTestRamConflict:
		mov	ax, RAM_CONFLICT
		jmp	RomTestExit

RomTestRomSignature:
		mov	ax, ROM_SIGNATURE_ERROR
		jmp	RomTestExit

RomTestRomChecksum:
		mov	ax, ROM_CHECKSUM_ERROR
		jmp	RomTestExit

RomTestRomSizeMismatch:
		mov	ax, ROM_SIZE_ERROR
		jmp	RomTestExit

LM_Rom_Test	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Bic_Test	Tests register access to bus interface chips
;			583, 584, 585/790, 593, 594
;
;		Entry:	DS:BP	Ptr to adapter structure
;		Exit:	AX	Ret code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
LM_Bic_Test	proc	far
else
LM_Bic_Test	proc	near
endif
		push	di
		push	si
		push	bx
		push	cx
		push	dx
		pushf
		push	ds
		cli
		cld
		
		cmp	ds:[bp].bic_type, BIC_NO_CHIP
		jne	TestBicChip
		jmp	NoBicChip
TestBicChip:
		les	di, ds:[bp].easp		; ES:DI now points to Extended Adapter Structure
		lea	di, es:[di].bic_test_array ; ES:DI now points to the bic_test_array member. 
		mov	si, di			; Save ptr in SI
		mov	ax, ds:[bp].bic_type
		cmp	ax, BIC_583_CHIP
		je	Test583Bic
		cmp	ax, BIC_584_CHIP
		je	Test584Bic
		cmp	ax, BIC_585_CHIP
		je	Test585Bic
		cmp	ax, BIC_593_CHIP
		je	Test593Bic
		cmp	ax, BIC_594_CHIP
		je	Test594Bic
		jmp	NoBicChip
Test583Bic:
Test584Bic:
		mov	al, TEST_BYTE_MSR
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_BIO
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_GP1
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_GP2
		stosb
		jmp	GotTestPattern

Test585Bic:
		mov	al, TEST_BYTE_CR
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_BPR
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		jmp	GotTestPattern

Test593Bic:
		mov	al, TEST_BYTE_MER
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_GPR
		stosb
		jmp	GotTestPattern

Test594Bic:
		mov	al, TEST_BYTE_MSR
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_CNT
		stosb
		mov	al, TEST_BYTE_NUL
		stosb
		mov	al, TEST_BYTE_REV
		stosb
GotTestPattern:
		mov	di, si		; Save pointer in DI this time
		mov	dx, ds:[bp].io_base
		mov	cx, 8
		push	es
		pop	ds
BicTestLoop:
		lodsb
		cmp	al, TEST_BYTE_NUL
		je	SkipThisByte
		out	dx, al
		jmp	$+2
		jmp	$+2
		mov	ah, al
		in	al, dx
		cmp	ah, al
		jne	BicTestError
SkipThisByte:	inc	dx
		loop	BicTestLoop
NoBicChip:
		mov	ax, SUCCESS
BicTestExit:
		pop	ds
		call	ResetBicChip
		$POPFF
		pop	dx
		pop	cx
		pop	bx
		pop	si
		pop	di
		ret
BicTestError:
		mov	ax, BIC_REG_ERROR
		jmp	BicTestExit
LM_Bic_Test	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Check_LAN_Addr_ROM
;
;		Entry:	DS:BP	Ptr to adapter structure
;		Exit:	AX	Ret code
;				If 585/790, HWR_SWH is 0.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
LM_Check_LAN_Addr_ROM	proc	far
else
LM_Check_LAN_Addr_ROM	proc	near
endif
		push	dx
		push	es
		push	di
		push	si

		cmp	ds:[bp].bic_type, BIC_585_CHIP
		jne	LanAddrRomNot585
		mov	ax, SELECT
		call	Select585ConfigRegs
LanAddrRomNot585:
		mov	dx, ds:[bp].io_base
		les	si, ds:[bp].easp	; ES:DI points to extended adapter struc
		mov	es:[si].LANAd_instance, 0	; Set LAN address instance count to 0.

		lea	di, es:[si].LANAd_register
		call	Fill_LAN_Addr_Entry

		cmp	ds:[bp].pc_bus, MCA_BUS
		je	CheckLanAddrRomSuccess
		test	ds:[bp].board_id, INTERFACE_CHIP
		jz	CheckLanAddrRomSuccess
		call	RecallLanAddress

		lea	di, es:[si].LANAd_eerom0
		call	Fill_LAN_Addr_Entry
		cmp	ds:[bp].bic_type, BIC_584_CHIP
		jne	CheckLanAddrRomSuccess

		mov	dx, ds:[bp].io_base
		call	SelectOtherRegister
		add	dx, REG_EAR
		in	al, dx
		jmp	$+2
		and	al, 0Fh
		or	al, 0B0h
		out	dx, al				; Select EEROM bank 0Bh

		mov	dx, ds:[bp].io_base
		mov	al, RECALL_DATA
		call	RecallEERomData
		lea	di, es:[si].LANAd_eerom1
		call	Fill_LAN_Addr_Entry
		mov	dx, ds:[bp].io_base
		mov	al, RECALL_LANADDR
		call	RecallEERomData

CheckLanAddrRomSuccess:
;		cmp	ds:[bp].bic_type, BIC_585_CHIP
;		jne	CheckLanAddrRomExit
;		mov	ax, DESELECT
;		call	Select585ConfigRegs
		mov	ax, SUCCESS
CheckLanAddrRomExit:
		pop	si
		pop	di
		pop	es		
		pop	dx
		ret
LM_Check_LAN_Addr_ROM	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	LM_Ram_Test	Tests Adapter Shared Ram.
;
;	Entry:	DS:BP	Ptr to adapter structure.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	LARGE
LM_Ram_Test	proc	far
else
LM_Ram_Test	proc	near
endif

		push	bx
		push	cx
		push	dx
		push	di
		push	si
		push	ds
		push	es
		pushf
		cli
		cld

		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		jne	NotPcmcia
		jmp	SkipDataWidthCheck
NotPcmcia:
		cmp	ds:[bp].nic_type, NIC_790_CHIP
		jne	SkipDataWidthCheck
		mov	dx, ds:[bp].io_base
		add	dx, REG_CMD
		mov	al, CMD_PAGE2
		out	dx, al
		add	dx, REG_DCR - REG_CMD
		in	al, dx
		and	al, not DCR_WTS
		test	ds:[bp].board_id, BOARD_16BIT
		jz	Set790ByteMode
		or	al, DCR_WTS
Set790ByteMode:
		mov	ah, al
		add	dx, REG_CMD - REG_DCR
		mov	al, CMD_PAGE0
		out	dx, al
		add	dx, REG_DCR - REG_CMD
		mov	al, ah
		out	dx, al
SkipDataWidthCheck:
		les	si, ds:[bp].easp
		mov	dx, word ptr es:[si].count.ofst
		or	dx, word ptr es:[si].count.sgmnt	; Use DX as flag:
RestartRamTest:							; if zero, loop forever.
		mov	di, es:[si].ram_offset
		mov	cx, es:[si].ram_length
		mov	bx, es:[si].ram_test_mode.test_type

		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		je	CheckPatternTest
		test	bx, ROM_SIGNATURE_TEST
		jz	CheckSpaceTest
		mov	ax, DESELECT
		call	SelectRam
		mov	es, word ptr ds:[bp].ram_access.sgmnt
		call	RomSignatureTest
		jnc	CheckSpaceTest
		jmp	RamTestRomConflict
CheckSpaceTest:
		test	bx, SPACE_TEST
		jz	CheckPatternTest
		mov	ax, DESELECT
		call	SelectRam
		mov	es, word ptr ds:[bp].ram_access.sgmnt
		call	RamSpaceTest
		jnc	CheckPatternTest
		jmp	RamTestRamConflict
CheckPatternTest:
		test	bx, READ_WRITE_TEST
		jz	CheckIoPipeTest
		mov	ax, SELECT
		call	SelectRam
		mov	es, word ptr ds:[bp].ram_access.sgmnt
		call	RamPatternTest
		jnc	RamTestSuccess
		jmp	RamTestFailed

CheckIoPipeTest:
		test	bx, RW_IO_TEST
		jz	RamTestSuccess
		mov	ax, DESELECT
		call	SelectRam
		mov	ax, 0
		mov	es, ax
		call	RamPatternTest
		jnc	RamTestSuccess
		jmp	RamTestFailed

RamTestSuccess:
		mov	ax, SUCCESS
		les	si, ds:[bp].easp
		test	es:[si].ram_test_mode.test_flags, LOOP_FOR_COUNT
		jz	RamTestExit
		or	dx, dx
		jnz	RamTestComplete
		jmp	RestartRamTest
RamTestComplete:
		mov	bx, word ptr es:[si].count.ofst
		or	bx, word ptr es:[si].count.sgmnt
		jz	RamTestExit
		sub	word ptr es:[si].count.ofst, 1
		sbb	word ptr es:[si].count.sgmnt, 0
		jmp	RestartRamTest

RamTestExit:
		push	ax
		mov	ax, DESELECT
		call	SelectRam
		pop	ax
		$POPFF
		pop	es
		pop	ds
		pop	si
		pop	di
		pop	dx
		pop	cx
		pop	bx
		ret

RamTestRomConflict:
		mov	es:[si].ram_test_mode.test_type, ROM_SIGNATURE_TEST
		mov	ax, ROM_CONFLICT
		jmp	RamTestExit
RamTestRamConflict:
		mov	es:[si].ram_test_mode.test_type, SPACE_TEST
		mov	ax, RAM_CONFLICT
		jmp	RamTestExit
RamTestFailed:
		mov	es:[si].ram_test_mode.test_type, READ_WRITE_TEST
		mov	ax, RAM_TEST_FAILED
		jmp	RamTestExit

LM_Ram_Test	endp

;;;; End of "LM_" calls . . .
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Fill_LAN_Addr_Entry	Fills memory indicated by ES:[DI]
;				with LAN Address, ID Byte, Checksum, and Sum.
;				(9 bytes total). Increments LANAdInstance.
;
;	Entry:	DS:BP	Ptr to adapter structure
;		ES:DI	Ptr to LAN Address entry.
;
;	Exit:		All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	Fill_LAN_Addr_Entry
endif
Fill_LAN_Addr_Entry	proc	near

		push	ax
		push	cx
		push	dx
		push	di

		xor	ax, ax
		mov	dx, ds:[bp].io_base
		add	dx, REG_LAR0 
		mov	cx, 8

LANAdLoop:	in	al, dx
		add	ah, al
		stosb
		inc	dx
		loop	LANAdLoop
		mov	al, ah
		stosb
		inc	es:[si].LANAd_instance

		pop	di
		pop	dx
		pop	cx
		pop	ax
		ret
Fill_LAN_Addr_Entry	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SelectRom	Enables/Disables Boot ROM on adapter indicated by DS:BP.
;			This routine must be called to DESELECT the ROM before
;			SELECTing the ROM because DESELECT saves the original
;			port value that is needed by SELECT to enable the ROM.
;
;	Entry:	DS:BP	Ptr to adapter structure.
;		AX =	DESELECT to disable ROM
;			SELECT to enable ROM.
;
;	Exit:	CARRY	If unable to enable/disable ROM. All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	SelectRom
SelectRom	proc	near
		push	ax
		push	bx
		push	cx
		push	dx
                push    es
                push    di
		pushf
		cli
		les	di, ds:[bp].easp	; ES:DI now points to Extended Adapter Structure

		mov	bx, ax			; Save mode in BX.
		cmp	ax, DESELECT
		je	BromHoldTestOk		; If selecting ROM, make sure that

		mov	al, es:[di].brom_hold	; If brom_hold is 0FFh, it is
		inc	al			; assumed that it has not been
		jnz	BromHoldTestOk
		jmp	UnableToSelectRom	; initialized, thus ROM was never deselected.
BromHoldTestOk:
		mov	dx, ds:[bp].io_base
		mov	ax, ds:[bp].bic_type	; Get I/O base and BIC type

		cmp	ax, BIC_584_CHIP	; Determine bus interface chip type
		je	Select58xRom
		cmp	ax, BIC_583_CHIP
		je	Select58xRom
		cmp	ax, BIC_585_CHIP
		je	Select585Rom
		cmp	ax, BIC_593_CHIP
		je	Select593Rom
		cmp	ax, BIC_594_CHIP
		je	Select594Rom
		test	ds:[bp].board_id, MICROCHANNEL	; If micro channel w/o interface
							; chip, handle as 593.
		jnz	Select593Rom
; The remaining cases are Adapters with no interface chip . . .
		jmp	UnableToSelectRom

Select58xRom:
		mov	al, es:[di].brom_hold		; Restore original value if any.
		add	dx, REG_BIO
		cmp	bx, DESELECT
		jne	Write58xRomPort
		in	al, dx
		mov	es:[di].brom_hold, al		; Save original value
		and	al, not BIO_RS1+BIO_RS0		; Clear ROM size bits
Write58xRomPort:
		out	dx, al				; Write value
		jmp	SelectRomSuccess
Select585Rom:
		mov	ax, SELECT
		call	Select585ConfigRegs
		mov	al, es:[di].brom_hold
		add	dx, REG_BAR
		cmp	bx, DESELECT
		jne	Write585RomPort
		in	al, dx
		mov	es:[di].brom_hold, al
		or	al, BAR_BWS0+BAR_BWS1
Write585RomPort:
		out	dx, al
		mov	ax, DESELECT
		call	Select585ConfigRegs
		jmp	SelectRomSuccess

Select594Rom:	mov	dx, 104h
		mov	ax, SELECT
		call	SelectMcaSlot
		mov	al, es:[di].brom_hold
		cmp	bx, DESELECT
		jne	Write594RomPort
		in	al, dx
		mov	es:[di].brom_hold, al
		or	al, POS_ROMS1+POS_ROMS0
Write594RomPort:
		out	dx, al
		mov	ax, DESELECT
		call	SelectMcaSlot
		jmp	SelectRomSuccess

Select593Rom:	mov	dx, 104h
		mov	ax, SELECT
		call	SelectMcaSlot
		mov	al, es:[di].brom_hold
		cmp	bx, DESELECT
		jne	Write593RomPort
		in	al, dx
		mov	es:[di].brom_hold, al
		and	al, not POS_BE1+POS_BE0
		or	al, POS_BE1
Write593RomPort:
		out	dx, al
		mov	ax, DESELECT
		call	SelectMcaSlot
;		jmp	SelectRomSuccess
SelectRomSuccess:
		$POPFF
		clc
SelectRomExit:
                pop     di
                pop     es
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
UnableToSelectRom:
		$POPFF
		stc
		jmp	SelectRomExit
SelectRom	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SelectRam	Enables/Disables Ram on adapter indicated by DS:BP.
;
;	Entry:	DS:BP	Ptr to adapter structure.
;		AX =	DESELECT to disable Ram
;			SELECT to enable Ram.
;
;	Exit:		All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PUBLIC	SelectRam
SelectRam	proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		mov	bx, ax			; Save mode in BX.
		xor	ax, ax

		cmp	ds:[bp].pc_bus, PCMCIA_BUS
		jne	ContinueRamSelect
		jmp	SelectRamExit
ContinueRamSelect:
		mov	dx, ds:[bp].io_base
		add	dx, REG_MSR
		cmp	ds:[bp].pc_bus, MCA_BUS
		je	SelectMcaRam
		cmp	ds:[bp].bic_type, BIC_585_CHIP	; Get I/O base and BIC type
		je	Select585Ram
		mov	ax, word ptr ds:[bp].ram_base.sgmnt
		mov	cl, 3
		shl	al, cl
		mov	ch, al
		mov	ax, word ptr ds:[bp].ram_base.ofst
		mov	al, ah
		mov	cl, 5
		shr	al, cl
		or	al, ch
		and	al, not MSR_MENB
SelectMcaRam:
Select585Ram:
		cmp	bx, DESELECT
		je	Deselect58xRam
		or	al, MSR_MENB
Deselect58xRam:
		out	dx, al
		test	ds:[bp].extra_info, SLOT_16BIT
		jnz	Select16BitAtRam
		cmp	ds:[bp].bic_type, BIC_584_CHIP
		je	Fix8BitLaarReg
		jmp	SelectRamExit
Fix8BitLaarReg:
		mov	dx, ds:[bp].io_base
		add	dx, REG_LAAR
		mov	al, 01h
		out	dx, al
		jmp	SelectRamExit
Select16BitAtRam:
		mov	dx, ds:[bp].io_base
		add	dx, REG_LAAR
		in	al, dx
		jmp	$+2
		cmp	ds:[bp].bic_type, BIC_585_CHIP
		je	SkipLan16Init
		test	ds:[bp].board_id, INTERFACE_CHIP
		jnz	ReadWriteRegisters
		mov	al, 0
ReadWriteRegisters:
		and	al, not LAAR_MASK
		mov	si, word ptr ds:[bp].ram_base.sgmnt
		mov	cx, 3
		shr	si, cl
		or	ax, si
		or	al, LAAR_L16E
SkipLan16Init:
		and	al, not LAAR_M16E
		cmp	bx, DESELECT
		je	Disable58xRam
		or	al, LAAR_M16E
Disable58xRam:
		out	dx, al
		jmp	SelectRamExit
SelectRamExit:
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret

SelectRam	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RamSpaceTest	Tests a window in system memory for the presence
;			of RAM.
;	Entry:	ES:DI	Base address of window to test
;		CX	Size of window in bytes
;
;	Exit:	CARRY	If space contains RAM. If RAM is detected, any data
;			that is to be overwritten is saved and restored before
;			exiting. All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	RamSpaceTest
endif
RamSpaceTest	proc	near

		push	ax
		push	bx
		push	cx
		push	dx
		push	di
		push	si
		pushf
		cli
		cld
		shr	cx, 1		; Divide by two for words.
		mov	bx, cx		; Save word count
		mov	ax, RAM_PATTERN_1
		mov	si, di
StartSpaceTest:
		mov	cx, bx		; Restore word count
		mov	di, si		; Restore offset
VerifySpace:
		mov	dx, es:[di]	; Save original word
					; in case of failure
		stosw					    
		cmp	ax, es:[di-2]
		je	FailedSpaceVerify
		loop	VerifySpace

		cmp	ax, RAM_PATTERN_1
		jne	SpacePatternTwo
		mov	ax, RAM_PATTERN_2
		jmp	StartSpaceTest
SpacePatternTwo:
     		cmp	ax, RAM_PATTERN_2
		jne	SpaceTestSuccess
		mov	ax, RAM_PATTERN_3
		jmp	StartSpaceTest
SpaceTestSuccess:
		$POPFF
		clc
SpaceTestExit:
		pop	si
		pop	di
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
FailedSpaceVerify:
		mov	cx, es:[di-2]
		mov	es:[di-2], dx		; Restore original data
		les	si, ds:[bp].easp
		mov	es:[si].w_pattern, ax
		mov	es:[si].r_pattern, cx
		sub	di, 2
		mov	es:[si].ram_offset, di
		$POPFF
		stc
		jmp	SpaceTestExit

RamSpaceTest	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RamPatternTest	Tests integrity of adapter RAM.
;
;	Entry:	ES:DI	Base address of window to test
;
;		CX	Size of window in bytes
;
;	Exit:	CARRY	If RAM pattern read does not match what was written.
;			All regs preserved.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	RamPatternTest
endif
RamPatternTest	proc	near

		push	ax
		push	bx
		push	cx
		push	dx
		push	di
		push	si
		push	es
		pushf
		cli
		cld

		mov	ax, RAM_PATTERN_1	; Set default RAM pattern.
		push	es
		les	si, ds:[bp].easp
		test	es:[si].ram_test_mode.test_flags, CUSTOM_PATTERN
		jz	InitPatternTest
		mov	ax, es:[si].w_pattern	; Use custom pattern.
InitPatternTest:
		mov	dx, es:[si].ram_test_mode.access_size
		pop	es		; Restore Ram segment value.
		mov	bx, es
		or	bx, bx		; If ES == 0, do IO pipe test.
		jnz	DoMemAccessTest
		mov	dh, 1
DoMemAccessTest:
		mov	si, di		; SI now contains Ram offset.
		shr	cx, 1		; Divide by two for words.
		mov	bx, cx		; Save loop count

; At this point . . .
; AX	= Test pattern.
; BX	= Saved Loop count.
; CX	= Loop count.
; DL	= ram_test_mode.access_size (lo byte)
; DH	= Access mode. 0 = shared memory, !0 = IO pipe access (795 only)
; ES:DI	= Ram offset to start with
; SI	= Saved Ram offset.

StartPatternTest:
		mov	cx, bx		; Restore word count
		mov	di, si		; Restore offset
		or	dh, dh		; 
		jz	VerifyMemoryPattern

		test	di, 1		; Synchronize odd/even bytes
		jz	EvenIoPipeOffset
		xchg	ah, al
EvenIoPipeOffset:
		call	InitIoPipe

		cmp	dl, WORD_ACCESS
		je	VerifyIoWordPattern

VerifyIoBytePattern:
		push	ax		; Save Write pattern
		call	RWIoPipeByte	; Write, read and compare one byte...
		jz	ContinueIoByteTest
		mov	cx, ax		; Save read value
		pop	ax		; Restore write pattern
		jmp	DataSaved	; Save values in Xadap struct, then exit.

ContinueIoByteTest:
		pop	ax		; Restore write pattern
		xchg	ah, al		; Use correct hi/lo byte
		inc	di		; increment pointer
		loop	VerifyIoBytePattern
		jmp	RamDataWritten

;;;;;;;;;;;;;;;;;;;;;;; IO Pipe Word Pattern Test ...

VerifyIoWordPattern:
		push	ax		; Save Write pattern
		call	RWIoPipeWord	; Write, read and compare one byte...
		jz	ContinueIoWordTest
		mov	cx, ax		; Save read value
		pop	ax		; Restore write pattern
		jmp	DataSaved	; Save values in Xadap struct, then exit.

ContinueIoWordTest:
		pop	ax		; Restore write pattern
		inc	di		; increment pointer
		inc	di		; increment pointer
		loop	VerifyIoWordPattern
		jmp	RamDataWritten

;;;;;;;;;;;;;;;;;;;;;;; Memory Pattern Test ...

VerifyMemoryPattern:
		cmp	dl, WORD_ACCESS
		je	VerifyMemWords

;;;;;;;;;;;;;;;;;;;;;;; Memory Byte Access Test ...

VerifyMemBytes:
		test	di, 1
		jnz	UseOddByteBoundary
		stosb			; For byte accesses, do two write/compares
		cmp	al, es:[di-1]	; for each loop iteration.
		jne	FailedBytePatternVerify
UseOddByteBoundary:
		mov	es:[di], ah	; Equivalent to STOSB, except AH is used. 
		inc	di		; 
		cmp	ah, es:[di-1]	; 
		jne	FailedBytePatternVerify
		loop	VerifyMemBytes
		jmp	RamDataWritten

;;;;;;;;;;;;;;;;;;;;;;; Memory Word Access Test ...

VerifyMemWords:
		stosw
		cmp	ax, es:[di-2]
		jne	FailedWordPatternVerify
		loop	VerifyMemWords
RamDataWritten:
		cmp	ax, RAM_PATTERN_1
		jne	RamPatternTwo
		mov	ax, RAM_PATTERN_2
		jmp	StartPatternTest
RamPatternTwo:
     		cmp	ax, RAM_PATTERN_2
		jne	PatternTestSuccess
		mov	ax, RAM_PATTERN_3
		jmp	StartPatternTest
PatternTestSuccess:
		$POPFF
		clc
PatternTestExit:
		pop	es
		pop	si
		pop	di
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
FailedBytePatternVerify:
		mov	cl, es:[di-1]		; Save read data.
		dec	di
		jmp	DataSaved
FailedWordPatternVerify:
		mov	cx, es:[di-2]		; Save read data
		dec	di
		dec	di
DataSaved:
		les	si, ds:[bp].easp
		mov	es:[si].w_pattern, ax
		mov	es:[si].r_pattern, cx
		mov	es:[si].ram_offset, di
		$POPFF
		stc
		jmp	PatternTestExit

RamPatternTest	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RWIoPipeByte	Writes then reads data in the IO pipe (795 only)
;
;	Entry:		DS:BP	= Pointer to Adapter Structure.
;			AL	= Data pattern to use for test
;			DI	= Offset in ram to be accessed via IO pipe.
;
;	Exit:		AL	= Value read back from pipe.
;			FLAGS	= Z set if read value equals write value.
;			All other regs preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RWIoPipeByte	proc	near

		push	bx
		push	dx
		mov	bx, ax
		mov	dx, ds:[bp].io_base
		add	dx, REG_IOPA
		mov	ax, di
		out	dx, al		; Write ram address to pipe addr reg.
		mov	al, ah
		out	dx, al

		mov	ax, bx		; Get data pattern again.
		add	dx, REG_IOPDL - REG_IOPA
		out	dx, al		; Write data

		add	dx, REG_IOPA - REG_IOPDL
		mov	ax, di		; Reset ram address
		out	dx, al
		mov	al, ah
		out	dx, al

		in	al, dx		; Read back data
		cmp	bl, al		; Set flags
		pop	dx
		pop	bx
		ret

RWIoPipeByte	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RWIoPipeWord	Writes then reads data in the IO pipe (795 only)
;
;	Entry:		DS:BP	= Pointer to Adapter Structure.
;			AX	= Data pattern to use for test
;			DI	= Offset in ram to be accessed via IO pipe.
;
;	Exit:		AX	= Value read back from pipe.
;			FLAGS	= Z set if read value equals write value.
;			All other regs preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RWIoPipeWord	proc	near

		push	bx
		push	dx
		mov	bx, ax

		mov	dx, ds:[bp].io_base
		add	dx, REG_IOPA
		mov	ax, di
		out	dx, al		; Write ram address to pipe addr reg.
		mov	al, ah
		out	dx, al
		mov	ax, bx		; Get data pattern back.

		add	dx, REG_IOPD - REG_IOPA
		out	dx, ax		; Write data to pipe

		add	dx, REG_IOPA - REG_IOPDL
		mov	ax, di
		out	dx, al
		mov	al, ah
		out	dx, al		; Write ram address to pipe addr reg.

		in	ax, dx		; Read back data
		cmp	bx, ax		; Set flags
		pop	dx
		pop	bx
		ret

RWIoPipeWord	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	InitIoPipe	Initializes IO pipe on 795 based adapters.
;
;	Entry:		DS:BP	= Pointer to Adapter Structure.
;			DI	= Offset in ram to be accessed via IO pipe.
;
;	Exit:		All regs preserved except flags.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

InitIoPipe	proc	near

		push	ax
		push	dx
		mov	dx, ds:[bp].io_base
		add	dx, REG_INTCR
		in	al, dx
		and	al, 0Fh
		or	al, INTCR_IOPE
		out	dx, al		; Enable IO pipe

		add	dx, REG_UBRCV - REG_INTCR
		mov	al, 0
		out	dx, al		; Disable ring-wrap stuff

		add	dx, REG_IOPA - REG_UBRCV
		mov	ax, di
		out	dx, al
		mov	al, ah
		out	dx, al		; Set up IO pipe address
		pop	dx
		pop	ax
		ret
InitIoPipe	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Select585ConfigRegs	Selects or Deselects 585 Config register set
;
;	Entry:	DS:BP		Ptr to adapter structure
;		AX = DESELECT	Deselect config register set
;		else		Select config register set
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	Select585ConfigRegs
endif
Select585ConfigRegs	proc	near

		push	ax
		push	bx
		push	dx

		mov	bx, ax
		mov	dx, ds:[bp].io_base
		add	dx, REG_HWR
		in	al, dx
		and	al, not HWR_SWH
		cmp	bx, DESELECT
		je	DeselectConfigRegs
		or	al, HWR_SWH
DeselectConfigRegs:
		out	dx, al

		pop	dx
		pop	bx
		pop	ax
		ret

Select585ConfigRegs	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	SelectMcaSlot		Selects or Deselects MCA slot based on
;				slot_num field in adapter structure.
;
;	Entry:	DS:BP		Ptr to adapter structure
;		AX = DESELECT	Deselect MCA slot
;		else		Enable MCA slot indicated by slot_num.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	SelectMcaSlot
endif
SelectMcaSlot	proc	near
		push	ax
		cmp	ax, DESELECT
		jne	EnableMcaSlot
		mov	al, 0
		jmp	SelectMcaSlotExit
EnableMcaSlot:
		mov	al, 8
		mov	ah, ds:[bp].slot_num
		dec	ah
		or	al, ah
SelectMcaSlotExit:
		out	96h, al
		pop	ax
		ret

SelectMcaSlot	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	ChecksumBootRom		Calculates Boot Rom Checksum
;
;		Entry:	DS:BP	Ptr to adpater structure
;
;		Exit:	AX =	Zero - Checksum OK
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	ChecksumBootRom
endif
ChecksumBootRom		proc	near

	push	si
	push	ds
	push	cx

	mov	si, word ptr ds:[bp].rom_access.ofst
	mov	ds, word ptr ds:[bp].rom_access.sgmnt

;;; DS:SI now points to Bios Rom base addr.

	mov	al, [si+2]	; Get Rom size
	cbw			; Make word
	mov	cl, 9
	shl	ax, cl		; Convert to byte count
	mov	cx, ax		; Put into CX
	xor	ax, ax		; Clear AX

ChkSumLoop:
	add	al,[si]		; Add up contents of Boot ROM
	inc	si
	loop	ChkSumLoop	; Zero means Rom is OK
	or	ax, ax		; Set Flags

	pop	cx
	pop	ds
	pop	si
	ret
ChecksumBootRom	ENDP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	RomSignatureTest	Tests memory space on MIN_ROM_SIZE boundaries
;				for presence of ROM signature.
;
;	Entry:	ES		Segment/Selector of window.
;		CX		Size of window in bytes. Must be an even
;				multiple of MIN_ROM_SIZE.
;
;	Exit:	CARRY		Set if window contains ROM signature on a
;				MIN_ROM_SIZE boundary.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ifdef	XLM_DEBUG
PUBLIC	RomSignatureTest
endif
RomSignatureTest	proc	near

		push	ax
		push	di
		pushf
		cli
		mov	di, 0
		and	cx, not MIN_ROM_SIZE-1	; Make sure CX is on correct
RomTestSigLoop:					; boundary.
		mov	ax, es:[di]
		cmp	ax, ROM_SIGNATURE
		je	SignatureTestFailed
		add	di, MIN_ROM_SIZE
		cmp	di, cx
		jne	RomTestSigLoop
		$POPFF
		clc
SignatureTestExit:
		pop	di
		pop	ax
		ret
SignatureTestFailed:
		$POPFF
		stc
		jmp	SignatureTestExit
RomSignatureTest	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	ResetBicChip	Performs recall of EEROM data into config regs
;			to simulate BIC reset.
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ResetBicChip	proc	near
		push	ax
		push	dx
		mov	ax, ds:[bp].bic_type
		cmp	ax, BIC_583_CHIP
		je	Reset583Bic
		cmp	ax, BIC_584_CHIP
		je	Reset584Bic
		cmp	ax, BIC_585_CHIP
		je	Reset585Bic
		cmp	ax, BIC_593_CHIP
		je	Reset593Bic
		cmp	ax, BIC_594_CHIP
		je	Reset594Bic
		jmp	ResetBicChipExit
Reset583Bic:
		mov	dx, ds:[bp].io_base
		add	dx, REG_ICR
		in	al, dx
		and	al, ICR_IO+ICR_WTS
		js	Data58xPoll
Reset584Bic:
		mov	dx, ds:[bp].io_base
		add	dx, REG_ICR
		in	al, dx
		and	al, ICR_IR2
Data58xPoll:
		or	al, ICR_RX7+ICR_RLA
		out	dx, al
Poll584BicReset:
		jmp	$+2
		in	al, dx
		test	al, ICR_RX7+ICR_RLA
		jnz	Poll584BicReset
		jmp	ResetBicChipExit
Reset585Bic:
		mov	dx, ds:[bp].io_base
		add	dx, REG_EER
		mov	al, EER_RC
		out	dx, al
PollBic585Recall:
		jmp	$+2
		in	al, dx
		test	al, EER_RC
		jnz	PollBic585Recall
		jmp	ResetBicChipExit
Reset593Bic:
		jmp	ResetBicChipExit
Reset594Bic:
		jmp	ResetBicChipExit

ResetBicChipExit:
		pop	dx
		pop	ax
		ret
ResetBicChip	endp

