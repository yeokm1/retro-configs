;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	Equates for ETH_RTNS.ASM
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Misc defs...

CRC_SIZE	equ	4
NIC_HEADER_SIZE	equ	4	; Size of NIC header
TX_BUF_ONE	equ	1
TX_BUF_TWO	equ	2
EOI		EQU	20h

;PUBLIC	enable_ram
;PUBLIC	disable_ram

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