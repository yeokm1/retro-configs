;****************************************************************************
;
;       The information contained in this file is confidential and 
;       proprietary to Standard Microsystems Corporation.  No part
;       of this file may be reproduced or distributed, in any form
;       or by any means for any purpose, without the express written
;       permission of Standard Microsystems Corporation.
;
; File:         xlmstrct.inc
;
; Description:  This file contains equates for extended LMAC.
;              
;               Any changes to this file have to be propagated to int_loop.h.
;
;
;********************
;* Revision History *
;********************
;
; $Log:   G:\sweng\src\lmcom\vcs\xlmstrct.ivc  $
   
      Rev 1.6   12 Jan 1995 18:19:26   WATANABE
   1. Added vcs header.
   2. Added NO_CABLE_ATTACH return code for Loopback test.
   3. The above changes had ONLY been added to xlmstrct.inc first. 
      Corresponding changes should be made to xlmstrct.h later when EZStart
      cleans up.
      
;
;
;+!/? ***********************************************************************
Lan_Addr_Rom	struc

lan_addr	db	6 dup (0)
id_byte		db	0
la_checksum	db	0
la_sum		db	0
la_pad_byte	db	0

Lan_Addr_Rom	ends

Test_Mode	struc

test_type	dw	0
test_flags	dw	0
access_size	dw	0
not_used	dw	0

Test_Mode	ends

Statix		struc

tx_aborts	dd	0
tx_overlapped	dd	0
deferring	dd	0
rx_disabled	dd	0
runt_pkts	dd	0
bad_next_pp	dd	0

Statix		ends

ExtAdapterStructure	struc

ram_offset	dw	0	; RAM offset address
ram_length	dw	0	; RAM length to be tested
w_pattern	dw	0	; Write pattern for RAM test
r_pattern	dw	0	; Read pattern for RAM test.
ram_test_mode	db	size Test_Mode	dup (0)
				; 
count		dd	0	; Ram test iterations.
LANAd_instance	dw	0
LANAd_register	db	size Lan_Addr_Rom dup (0)
LANAd_eerom0	db	size Lan_Addr_Rom dup (0)
LANAd_eerom1	db	size Lan_Addr_Rom dup (0)
micro_code_rev	dw	0
statistics	db	size Statix dup (0)
brom_hold	db	0FFh
bic_test_array	db	8	dup (0)
loopback_mode	db	0
CollTable	db	64	dup (0)
ExtAdapterStructure	ends

;;;;; General Equates . . .
MAX_LPBK_TX_RETRY	equ     5
MAX_TRY_AGAIN_COUNT	equ     10

MODE_NOT_SUPPORTED	equ	100h
EXPECTED_CRC_ERR	equ	101h	; Loopback test expected CRC error, did not occur.
ACPT_MANUAL_ERR		equ	102h	; Manual CRC test failed.	
ACPT_BAD_ADDR_ERR	equ	103h	; Loopback test accepted a bad address?
DISABLED_RAM_ERR	equ	104h	; Ram was supposed to be enabled for a given test,
NO_XMIT_RESPONSE	equ	105h	; No response from transmitter.
FIFO_ERR		equ	106h	; Error in FIFO data.
REJ_MANUAL_ERR		equ	107h	; ?
BAD_PKT_ERR		equ	108h	; ?
NO_CABLE_ATTACH        equ     109h    ; No cable attached
INT_LOOP_DELAY		equ     36	; 2 seconds ÷ 36 ticks.

TRUE			equ	1
FALSE			equ	0

XASP			equ	DS:[BP]		; Pointer to Adapter Structure
sgmnt			equ	2		; Equates to simplify access of
;ofst			equ	0		; far pointers.

SELECT			equ	1
DESELECT		equ	0
NIC_TEST_PATTERN	equ	05Ah
TEST_BYTE_NUL		equ	000h	; If this val is used for BIC register test, 
					; the reg is not tested.
;;; Equates for loopback_mode
LPBK_MODE0		equ	000h
LPBK_MODE1		equ	002h
LPBK_MODE2		equ	004h
LPBK_MODE3		equ	006h

;;; Equates for test_mode.test_type
ROM_SIGNATURE_TEST	equ	001h
SPACE_TEST		equ	002h
READ_WRITE_TEST		equ	004h
RW_IO_TEST		equ	008h

;;; Equates for test_mode.test_flags
NO_LOOP			equ	001h
LOOP_FOR_COUNT		equ	002h
CUSTOM_PATTERN		equ	004h

;;; Equates for test_mode.access_size
BYTE_ACCESS		equ	001h	; Do not use values above FFh (255),
WORD_ACCESS		equ	002h	; even though the variable is a word.
					; LM_Ram_Test converts value to a byte
					; variable.
;;;
LAN_ADDR_BANK_585	equ	006h	; EEROM bank that contains LAN address bank 585/790.

;;; Test Patterns for 583/584
TEST_BYTE_MSR		equ	02Ah
TEST_BYTE_BIO		equ	014h
TEST_BYTE_IRR		equ	025h
TEST_BYTE_GP1		equ	05Ah
TEST_BYTE_GP2		equ	0A5h

;;; Test Patterns for 585
TEST_BYTE_CR		equ	015h
TEST_BYTE_BPR		equ	066h

;;; Test Patterns for 593
TEST_BYTE_MER		equ	015h
TEST_BYTE_GPR		equ	0A5h

;;; Test Patterns for 594
TEST_BYTE_CNT		equ	0A5h
TEST_BYTE_REV		equ	066h

;;;;; Equates for Micro Channel POS Registers

;;; Register 102, 594
POS_IA15		equ	080h
POS_IA14		equ	040h
POS_IA13		equ	020h
POS_IA12		equ	010h

;;; Register 102, 593
POS_IA11		equ	080h
POS_IA10		equ	040h
POS_IA09		equ	020h
POS_IA08		equ	010h
POS_IA07		equ	010h
POS_IA06		equ	010h
POS_IA05		equ	010h

;;; Register 102, Common.
POS_CDEN		equ	001h

;;; Register 103, 594

POS_RAP			equ	080h
POS_RAMS1		equ	020h
POS_RAMS0		equ	010h
POS_RAD3		equ	008h
POS_RAD2		equ	004h
POS_RAD1		equ	002h
POS_RAD0		equ	001h

;;; Register 103, 593

POS_RA19		equ	080h
POS_RA18		equ	040h
POS_RA17		equ	020h
POS_RA16		equ	010h
POS_RA15		equ	008h
POS_RA14		equ	004h
POS_PME			equ	002h
POS_CLAIM		equ	001h

;;; Register 104, 594

POS_ROMS1		equ	020h
POS_ROMS0		equ	010h
POS_RMA3		equ	008h
POS_RMA2		equ	004h
POS_RMA1		equ	002h
POS_RMA0		equ	001h

;;; Register 104, 593

POS_RO19		equ	080h
POS_RO18		equ	040h
POS_RO17		equ	020h
POS_RO16		equ	010h
POS_RO15		equ	008h
POS_RO14		equ	004h
POS_BE1			equ	002h
POS_BE0			equ	001h

;;; Register 105, 594

POS_CHCHK		equ	080h
;POS_			equ	040h
POS_MCFG		equ	020h
POS_RIPL		equ	010h
POS_ISEL1		equ	008h
POS_ISEL0		equ	004h
POS_MEDIA1		equ	002h
POS_MEDIA0		equ	001h

;;; Register 105, 593

;POS_			equ	080h
;POS_			equ	040h
;POS_			equ	020h
;POS_			equ	010h
POS_MSE			equ	008h
POS_CDIV		equ	004h
POS_IEN1		equ	002h
POS_IEN0		equ	001h


