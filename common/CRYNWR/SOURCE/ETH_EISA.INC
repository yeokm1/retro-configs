;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       ETH_EISA.ASM    (C) Copyright 1992 Standard Microsystems Corp.
;                       All rights reserved.
;
;       LMI lower routine includes for
;       Ethernet EISA adapter.
;
;       Author: najay
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EISA_CONFIG     equ     0
EISA_DMA        equ     10h
EISA_790        equ     20h


; eisa config registers
EISA_ID1        equ     EISA_CONFIG+0
EISA_ID2        equ     EISA_CONFIG+1
EISA_ID3        equ     EISA_CONFIG+2
EISA_ID4        equ     EISA_CONFIG+3
EISA_EBC        equ     EISA_CONFIG+4
EISA_RIML       equ     EISA_CONFIG+6
EISA_RIMH       equ     EISA_CONFIG+7
EISA_RAM        equ     EISA_CONFIG+8
EISA_ROM        equ     EISA_CONFIG+9
EISA_INT        equ     EISA_CONFIG+0ah
EISA_STAT       equ     EISA_CONFIG+0bh
EISA_TOUT       equ     EISA_CONFIG+0ch
EISA_TRC        equ     EISA_CONFIG+0dh
EISA_EE         equ     EISA_CONFIG+0eh

; eisa dma registers
EISA_AA         equ     EISA_DMA+0
EISA_AS         equ     EISA_DMA+4

; config register values
EISA_ENB        equ     01h

ifndef EISA_RAM_MASK
EISA_RAM_MASK   equ     0fch
EISA_RAM_PAGE_MASK equ  003h
endif

ifndef EISA_ROM_MASK
EISA_ROM_MASK   equ     0f0h
EISA_ROM_PAGE_MASK equ  007h
endif

; EISA_INT
EISA_CLRD       equ     80h
EISA_MENB       equ     40h
EISA_ROMEN      equ     20h
EISA_G4         equ     10h
EISA_POL        equ     08h
EISA_IRQ_MASK   equ     07h

; EISA_STAT
EISA_EIL        equ     80h
EISA_DIEN       equ     40h
EISA_STATI      equ     20h
EISA_STATD      equ     10h
EISA_RNIC       equ     08h
EISA_SDMA       equ     02h

; EISA_TOUT
EISA_TEISA      equ     10h
EISA_TNIC1      equ     08h
EISA_TNIC0      equ     04h

; EISA_TRC
EISA_RP3        equ     80h
EISA_RP2        equ     40h
EISA_HWCS       equ     08h
; read only
EISA_GIN1       equ     02h
EISA_GIN0       equ     01h
; write only
EISA_CLRI       equ     04h
EISA_CA         equ     01h

; EISA_EE
EISA_SA16       equ     80h
EISA_SZ15       equ     40h
EISA_SZ14       equ     20h
EISA_IM16       equ     10h
EISA_EECS       equ     08h
EISA_EESK       equ     04h
EISA_EEDI       equ     02h
EISA_EEDO       equ     01h

; EISA_DMA
EISA_SZ_SDMA    equ     8000h
EISA_SZ_DIR     equ     4000h

; Misc defs...

CRC_SIZE	equ	4
NIC_HEADER_SIZE	equ	4	; Size of NIC header
TX_BUF_ONE	equ	1
TX_BUF_TWO	equ	2
ifndef CODE_386
EOI		EQU	20h
endif

MANUF_ID        equ     04da3h
EISA_BRD_ID     equ     08010h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Defs for 8013 AT adapters
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIT_LAAR_VALUE		equ	01h	; Initial LAAR vaule for 8013 adapters

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	 MACRO  $POPFF
;	Used for the Intel 286 to mask a design flaw.
;	Use $POPFF instead of POPF - simulate popping flags using IRET instead.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$POPFF	MACRO
		LOCAL	$1, $2
		jmp	$1			; jump around iret
$2:		iret				; Pop CS, IP, flags
$1:		push	cs
		call	$2			; CALL within segment
						; program will continue here
		ENDM

