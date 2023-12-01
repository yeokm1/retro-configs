;-----------------------------------------------------------------------
;Copyright (c) 1993 ADVANCED MICRO DEVICES, INC. All Rights Reserved.
;This software is unpblished and contains the trade secrets and 
;confidential proprietary information of AMD. Unless otherwise provided
;in the Software Agreement associated herewith, it is licensed in confidence
;"AS IS" and is not to be reproduced in whole or part by any means except
;for backup. Use, duplication, or disclosure by the Government is subject
;to the restrictions in paragraph (b) (3) (B) of the Rights in Technical
;Data and Computer Software clause in DFAR 52.227-7013 (a) (Oct 1988).
;Software owned by Advanced Micro Devices, Inc., 901 Thompson Place,
;Sunnyvale, CA 94088.
;-----------------------------------------------------------------------
;  Copyright, 1990, Russell Nelson, Crynwr Software
;
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
;
;   Adapted for NE2100/AM1500T by Mike Ching, ching@angelo.amd.com
;   Modified 11/16/92 to preallocate buffers for -d operation.
;-----------------------------------------------------------------------
;
;   10.3 - Changed the version to 10.3 and deleted the write to base + 14 to
;   reset the board (reset should be read only to base + 14h) - Sanjay D 3/30
;
;   10.4 - Changed the receive path so that CRC is subtracted from the
;   count which is passed to the protocol stack	- Sanjay D 4/29/93
;
;   10.5 - Document driver portion code.
;	   move hardware initialize code portion forward within etopen
;	   to solve warm boot problem.
;   
;   0.10 - updated for alpha release
;
; 12-16-93 D.T.	swap the default value between the DEF_LED1 and DEF_LED2
; 01-26-94 D.T.	don't increase si during input parsing in compare_str
;		to fix tp input error
; 01-31-94 D.T.	save es,di and don't transfer physical address again while
;		VDS complete in segmoffs_to_phys, save physical address of
;		xmit & rcv buffser starting pt. in etopen, set proper
;		phys_buf_addr & logic_buf addr before call phys_to_segmoffs
;		in send_pkt & recv, and add VDS check in phys_to_segmoffs
; 02-17-94 D.T.	software patch for PCI stop/reset. add dw_pci_bdfnum,
;		dw_pci_m1_cad, w_m2_fwd_reg, w_m2_cfg_reg, b_1st_reset,
;		pci_stop_pcnet, pci_reset_pcnet, pci_m1_disable_dma,
;		pci_m1_enable_dma, pci_m2_disable_dma, pci_m2_enable_dma.
;		modify initialize, terminate, recv, etopen
; 06-14-94 D.T.	1. add full duplex support
;		   add get_fullduplex_string, FDUP structure
;		   modify get_string to get_bustype_string
;		2. modify run-time reset to use stop-start instead of read reset port
;		   modify complete_reset, device_reset, pci_reset_pcnet
;		3. modify program-led for isa & isa+ case
; 07-28-94 D.T.	1. check full duplex & TP conflict case
; 08-04-94 D.T.	1. add force auto selection code
; 08-17-94 D.T.	1. delete check full duplex & TP conflict case in program_tp
; 08-31-94 D.T.	1. modify all conditional jump instructions to short format
;		   for 286 compatible
; 09-08-94 D.T.	1. add device stop before DMA controller mask in etopen
; 11-16-94 D.T.	1. add program_dmatimer, modify parse_args, related equates
;		   for "BUSTIMER" keyword
;		2. modify pci_m1_en/disable_dma, pci_m2_en/disable_dma
;		   for P1 glitch patch
;-----------------------------------------------------------------------

.386					; the NE2100 requires a 286.

INCLUDE	defs.asm			;

;
;----------------------------------------
; Hardware patch equates
;----------------------------------------
;
;PH_HLA0		equ	1	; patch for HILANCE A0 16 bit mode
PH_HLA1		equ	1		; patch for HILANCE A0 16 bit mode
;PH_GGA1		equ	1		; patch for Golden Gate A1 16 bit mode
SHARE_IRQ	equ	1		; share IRQ enable

;
;----------------------------------------
; PCnet device driver version equates
;----------------------------------------
;
version		equ	20		; device driver version number

;
;----------------------------------------
; Control Register equates
;----------------------------------------
;
	;
	;--------------------------------
	; I/O resources
	;--------------------------------
	;
DATA_REG	equ	10h		; PCnet-ISA RDP offset address
ADDR_REG	equ	DATA_REG+2	; PCnet-ISA RAP offset address
RESET_REG	equ	DATA_REG+4	; PCnet-ISA RST offset address
BDAT_REG	equ	DATA_REG+6h	; BCR data register
NODE_REG	equ	DATA_REG-10h	; PCnet-ISA PROM offset address

	;
	;--------------------------------
	; ethernet controller registers(PCNET compatible)
	;--------------------------------
	;
CSR0		equ	0		; PCnet-ISA status register
CSR1		equ	1		; PCnet-ISA IADRL[15:0] register
CSR2		equ	2		; PCnet-ISA IADRH[23:16] register
CSR3		equ	3		; PCnet-ISA INT mask & Deferal cntl reg

CSR4		equ	4		; PCnet Test and feature control
CSR80		equ	80		; PCnet Burst & threshold control
CSR82		equ	82		; PCnet Bus activity control

CSR88		equ	88		; PCnet version ID low reg
CSR89		equ	89		; PCnet version ID high reg
	;
	;--------------------------------
	; bus controller registers(PCNET compatible)
	;--------------------------------
	;
BCR2		equ	2		; PCnet MAC configuration register
BCR4		equ	4		; PCnet LED 0 configuration register
BCR5		equ	5		; PCnet LED 1 configuration register
BCR6		equ	6		; PCnet LED 2 configuration register
BCR7		equ	7		; PCnet LED 3 configuration register
BCR9		equ	9		; PCnet FDUP configuration register

;
;----------------------------------------
; Control and Status Register 0 (CSR0) bit definitions
;----------------------------------------
;
CSR0_ERR	equ 	8000h		; Error summary
CSR0_BABL	equ 	4000h		; Babble transmitter timeout error
CSR0_CERR	equ	2000h		; Collision Error
CSR0_MISS	equ	1000h		; Missed packet
CSR0_MERR	equ	0800h		; Memory Error
CSR0_RINT	equ	0400h		; Reciever Interrupt
CSR0_TINT       equ	0200h		; Transmit Interrupt
CSR0_IDON	equ	0100h		; Initialization Done
CSR0_INTR	equ	0080h		; Interrupt Flag
CSR0_INEA	equ	0040h		; Interrupt Enable
CSR0_RXON	equ	0020h		; Receiver on
CSR0_TXON	equ	0010h   	; Transmitter on
CSR0_TDMD	equ	0008h		; Transmit Demand
CSR0_STOP	equ	0004h 		; Stop
CSR0_STRT	equ	0002h		; Start
CSR0_INIT	equ	0001h		; Initialize

CSR88_ID_MASK	equ	0F000h		; version ID low mask of CSR88
CSR89_ID_MASK	equ	0FFFh		; version ID high mask of CSR89

PCNET_ISA_FDUP	equ	2261h		; current PCnet ISA II version ID
;
;----------------------------------------
; Bus Control Register 2 (BCR2) bit definitions
;----------------------------------------
;
BCR2_XMAUSEL	equ	0001h		; external MAU selection
BCR2_ASEL	equ	0002h		; automatic MAC selection

;
;----------------------------------------
; Initialization Block  Mode operation Bit Definitions.
;----------------------------------------
;
M_PROM		equ	8000h		; Promiscuous Mode
M_INTL		equ	0040h   	; Internal Loopback
M_DRTY		equ	0020h   	; Disable Retry
M_COLL		equ	0010h		; Force Collision
M_DTCR		equ	0008h		; Disable Transmit CRC)
M_LOOP		equ	0004h		; Loopback
M_DTX		equ	0002h		; Disable the Transmitter
M_DRX		equ	0001h   	; Disable the Reciever

DEF_MODE_REG	equ	0000h		; default AUI mode
CSR15_10BT_SEL	equ	0080h		; 10 Base-T in CSR15[8:7]=PORTSEL
CSR15_DLNKTST	equ	1000h		; dis_link_status in CSR15[12]=DLNKTST
;
;----------------------------------------
; Receive message descriptor bit definitions.
;----------------------------------------
;
RCV_OWN		equ	8000h		; owner bit 0 = host, 1 = pcnet
RCV_ERR		equ	4000h		; Error Summary
RCV_FRAM	equ 	2000h		; Framing Error
RCV_OFLO	equ	1000h		; Overflow Error
RCV_CRC		equ	0800h		; CRC Error
RCV_BUF_ERR	equ 	0400h		; Buffer Error
RCV_START	equ	0200h		; Start of Packet
RCV_END		equ	0100h		; End of Packet

;
;----------------------------------------
; Transmit  message descriptor bit definitions.
;----------------------------------------
;
XMIT_OWN	equ	8000h		; owner bit 0 = host, 1 = pcnet
XMIT_ERR	equ	4000h		; Error Summary
XMIT_RETRY	equ	1000h		; more the 1 retry needed to Xmit
XMIT_1_RETRY	equ	0800h		; one retry needed to Xmit
XMIT_DEF	equ	0400h		; Deferred
XMIT_START	equ	0200h		; Start of Packet
XMIT_END	equ	0100h		; End of Packet

;
;----------------------------------------
; Miscellaneous Equates
;----------------------------------------
;

XMIT_BUF_COUNT	equ	1		; xmit buffer count
					; maxi. xmit buffer size
XMIT_BUF_SIZE	equ	EADDR_LEN * 2 + ETD_LEN + MAXI_DLEN + FCS

RCV_BUF_COUNT	equ	8		; recv buffer count
					; maxi. recv buffer size
RCV_BUF_SIZE	equ	EADDR_LEN * 2 + ETD_LEN + MAXI_DLEN + FCS

INIT_FILTER_LN	equ	8		; length of init filter

DUMMY_LOOP	equ	10		; dummy read RAP loop count
;
;----------------------------------------
; PC/AT system DMA register equates
;----------------------------------------
;

DMA_8MASK_REG	equ	0Ah		; system 2nd dma cntler mask reg
DMA_16MASK_REG	equ	0D4h		; system 1st dma cntler mask reg

DMA_8MODE_REG	equ	0Bh		; system 2nd dma cntler mode reg
DMA_16MODE_REG	equ	0D6h		; system 1st dma cntler mode reg

DMA_8CMD_REG	equ	008h		; system 2nd dma cntler cmd reg
DMA_16CMD_REG	equ	0D0h		; system 1st dma cntler cmd reg

SINGLE_MODE	equ	040h		; mode reg,bit 7,6: 01 single mode
CASCADE_MODE    equ	0C0h		; mode reg,bit 7,6: 11 cascade mode
SET_DMA_MASK    equ	4		; mask reg,bit 2: 0,clear/1,set
DMA_CHL_FIELD	equ	3		; dma channel fields bit 1:0
DMA_ROTATE_PRI	equ	10h		; dma rotate priority

BIOS_DATA_SEG	equ	40h		; BIOS data segment
VDS_BYTE_OFF	equ	7Bh		; VDS enable status byte[5]
VDS_ENABLE	equ	20h		; VDS enable statue bit

LOCK_DMA_REGION	equ	8103h		; lock DMA region
LOCK_CONTIGUOUS	equ	04h		; contiguous region
;
;----------------------------------------
; additional keyword equates
;----------------------------------------
;
DEF_BUSTYPE	equ	0FFh		; default BUS type
ISA_BUSTYPE	equ	00h		; ISA BUS type
PNP_BUSTYPE	equ	01h		; PNP BUS type
VLISA_BUSTYPE	equ	10h		; VL ISA BUS type
PCI_BUSTYPE	equ	11h		; PCI BUS type

DEF_CPU_TYPE	equ	0		; 286
CPU_TYPE_386	equ	1		; 386

DEF_OEM		equ	0		; no OEM manufacturer or disable check
OEM_1		equ	1		; first OEM manufacturer

DEF_DMAROTATE	equ	0		; no DMA rotate occur
EN_DMAROTATE	equ	1		;

DEF_TP		equ	0		; no TP(Twisted Pair interface enfore)
EN_TP		equ	1		;

DEF_LED0	equ	00C0h		; no user input LED 0 value

DEF_LED1	equ	00B0h		; no user input LED 1 value

DEF_LED2	equ	4088h		; no user input LED 2 value

DEF_LED3	equ	0081h		; no user input LED 3 value

DEF_FDUP	equ	00h		; no user input FDUP value

DEF_DMATIMER	equ	06h		; default BUS(DMA)TIMER keyword CSR82
MIN_DMATIMER	equ	05h		; mini input BUS(DMA)TIMER keyword CSR82
MAX_DMATIMER	equ	0Dh		; maxi input BUS(DMA)TIMER keyword CSR82
MUL_CSR82	equ	10		; CSR82 multiple number(100ns to 1us)
EN_CSR82	equ	2000h		; CSR4 bit for CSR82

FDUP_AUI	equ	03h		; full duplex use AUI port

DEF_PCI_METHOD	equ	0		; default PCI method
PCI_METHOD_1	equ	1		; PCI mechanism 1
PCI_METHOD_2	equ	2		; PCI mechanism 2

DEF_1ST_RESET	equ	0		; default PCnet 1st reset
DEF_PCI_BDFNUM	equ	0		; default PCI bus/dev/function #
DEF_PCI_CFGADDR	equ	0		; default PCI m1 config addr reg
DEF_PCI_FWDREG	equ	0		; default PCI m2 forward reg
DEF_PCI_CFGREG	equ	0		; default PCI m2 config reg
PCI_STPRST_CNT	equ	10		; PCI bus stop/reset count

PCI_VENID_OFF	equ	0		; vendor ID 00h
PCI_DEVID_OFF	equ	2		; device ID 02h
PCI_STACMD_OFF	equ	4 * 4		; status/command 04h shift left 2 bits
PCI_CMD_DMA	equ	4		; DMA bit 2, enable DMA

PCI_CAD_REG	equ	0CF8h		; PCI M1 config. addr register
PCI_CDA_REG	equ	0CFCh		; PCI M1 config. data register
PCI_CSE_REG	equ	0CF8h		; PCI M2 config. space enable register
PCI_CFW_REG	equ	0CFAh		; PCI M2 config. forward register

PCI_M2_ENABLE	equ	80h		; PCI M2 enable bit
PCI_M2_DISABLE	equ	0Fh		; PCI M2 disable mask

;
;----------------------------------------
; Macro
;----------------------------------------
;
INPORT	macro	reg			;
	mov	dx,io_addr		; DX = PCnet-ISA/ET base address
	add	dx,ADDR_REG		; DX = PCnet-ET address register
	mov	ax,reg			; AX = index to register address
	out	dx,ax			; set register index

	dec	dx			;
	dec	dx			; DX = PCnet-ISA data register
	in	ax,dx			; read indexed register content

	endm				;

OUTPORT	macro	reg			;
	push	ax			; save register content
	mov	dx,io_addr		; DX = PCnet-ISA base address
	add	dx,ADDR_REG		; DX = PCnet-ISA address register
	mov	ax,reg			; AX = index to register address
	out	dx,ax			; set register index

	dec	dx			; 
	dec	dx			; DX = PCnet-ISA data register
	pop	ax			; restore register content
	out	dx,ax			; write indexed register content

	endm				;

IFDEF	PH_GGA1

INPORTG	macro	reg			;
	LOCAL	master_iwait		;

	mov	dx,io_addr		; DX = PCnet-ISA/ET base address
	add	dx,ADDR_REG		; DX = PCnet-ET address register
	mov	ax,reg			; AX = index to register address
	out	dx,ax			; set register index

	dec	dx			;
	dec	dx			; DX = PCnet-ISA data register

master_iwait:
	jmp	short $+2
	in	ax,dx			; read indexed register content
	cmp	ax,0FFFFH		; check for master mode in operation
	je	short master_iwait	;

	endm				;

OUTPORTS	macro	reg		;
	LOCAL	master_oswait		;

	push	bx			; save register content
	mov	bx,ax			; BX = input AX

	mov	dx,io_addr		; DX = PCnet-ISA base address
	add	dx,ADDR_REG		; DX = PCnet-ISA address register
	mov	ax,reg			; AX = index to register address
	out	dx,ax			; set register index

	dec	dx			; 
	dec	dx			; DX = PCnet-ISA data register
master_oswait:
	mov	ax,bx			; AX = input value
	out	dx,ax			; write indexed register content
	in	ax,dx			; read indexed register content
	cmp	ax,0FFFFH		; check for master mode in operation
	je	short master_oswait	;
					; assume no infinite loop
					; and no synchronize between master
					; mode and loop operation happened

	and	ax,bx			; mask off other bits
	cmp	ax,bx			;
	jne	short master_oswait	; check setting take effect		
					; assume no infinite loop 

	pop	bx			; restore BX

	endm				;

OUTPORTCI	macro	reg		;
	LOCAL	master_ocwait		;

	push	bx			; save register content
	mov	bx,ax			; BX = input AX

	mov	dx,io_addr		; DX = PCnet-ISA base address
	add	dx,ADDR_REG		; DX = PCnet-ISA address register
	mov	ax,reg			; AX = index to register address
	out	dx,ax			; set register index

	dec	dx			; 
	dec	dx			; DX = PCnet-ISA data register
master_ocwait:
	mov	ax,bx			; AX = input value
	out	dx,ax			; write indexed register content
	in	ax,dx			; read indexed register content
	cmp	ax,0FFFFH		; check for master mode in operation
	je	short master_ocwait	;
					; assume no infinite loop
					; and no synchronize between master
					; mode and loop operation happened

	test	ax,CSR0_INEA 		; check setting take effect		
	jnz	short master_ocwait	;
					; assume no infinite loop

	pop	bx			; restore BX

	endm				;

ENDIF

;
;----------------------------------------
; Receive Message Descriptor
;----------------------------------------
;
RCV_MSG_DSCP	struc			;
	rmd0	dw	?		; Rec. Buffer Lo-Address
	rmd1	dw	?		; Status bits / Lo-Address
	rmd2	dw	?		; Buff Byte-length (2's Comp)
	rmd3	dw	?		; Receive message length
IFDEF	PH_HLA0			;
	rmd0h	dw	?		; Rec. Buffer Hi-Address
	rmd1h	dw	?		; Status bits / Hi-Address
	rmd2h	dw	?		; Buff Byte-length (2's Comp)
	rmd3h	dw	?		; Receive message length
ENDIF
RCV_MSG_DSCP	ends			;


;
;----------------------------------------
; Transmit Message Descriptor
;----------------------------------------
;
XMIT_MSG_DSCP	struc			;
	tmd0	dw	?		; Xmit Buffer Lo-Address
	tmd1	dw	?		; Status bits / Lo-Address
	tmd2 	dw	?		; Buff Byte-length (2's Comp)
	tmd3	dw	?		; Buffer Status bits & TDR value
IFDEF	PH_HLA0			;
	tmd0h	dw	?		; Xmit Buffer Hi-Address
	tmd1h	dw	?		; Status bits / Hi-Address
	tmd2h 	dw	?		; Buff Byte-length (2's Comp)
	tmd3h	dw	?		; Buffer Status bits & TDR value
ENDIF
XMIT_MSG_DSCP	ends			;

;
;----------------------------------------
;
;----------------------------------------
;

dma_descriptor	struc			; define structure for VDS
region_size	dd	0		;
dma_offset	dd	0		;
dma_segment	dd	0		;
dma_phys_addr	dd	0		; 
dma_descriptor	ends			;

;
;----------------------------------------
;
;----------------------------------------
;
code	segment	para public use16	;
	assume	cs:code, ds:code	;

EXTRN	start_1: near			; jump to init. routine
EXTRN	recv_find: near			; ptr to process rcv pkt with user
					; options and infom appl routine
EXTRN	recv_copy: near			; ptr to copy data from drv to appl
					; buffer routine
EXTRN	count_in_err: near		; ptr to count rcv error routine
EXTRN	count_out_err: near		; ptr to count xmit error routine
EXTRN	set_recv_isr: near		; ptr to set rcv ISR routine
EXTRN	maskint: near			; ptr to mask 8259 int mask reg routine
EXTRN	get_number: near		; ptr to get number from ascii string
EXTRN	print_number: near		; ptr to print char str & hex/dec #
EXTRN	skip_blanks: near		; ptr to skip blanks in string

EXTRN	display_error_message:near	; ptr to display error message routine

EXTRN	packet_int_no: byte		; ptr to pkt drv int # bytes(4)

EXTRN	keyword_string_table: byte	; ptr to keyword string table
EXTRN	b_kint_no: byte			; ptr to keyword string INT #
EXTRN	b_kirq_no: byte			; ptr to keyword string IRQ #
EXTRN	b_kdma_no: byte			; ptr to keyword string DMA #
EXTRN	b_kioaddr_no: byte		; ptr to keyword string IO addr
EXTRN	b_ktp_en: byte			; ptr to keyword string TP
EXTRN	b_kdmarotate: byte		; ptr to keyword string DMA ROTATE
EXTRN	b_kbustype: byte		; ptr to keyword string BUS TYPE
EXTRN	b_kled0: byte			; ptr to keyword string LED 0
EXTRN	b_kled1: byte			; ptr to keyword string LED 1
EXTRN	b_kled2: byte			; ptr to keyword string LED 2
EXTRN	b_kled3: byte			; ptr to keyword string LED 3
EXTRN	b_kfdup: byte			; ptr to keyword string FUDUP
EXTRN	b_kdmatimer: byte		; ptr to keyword string BUS(DMA)TIMER
EXTRN	bustype_table: byte		; ptr to bustype string table
EXTRN	b_pci_bus: byte			; ptr to pci bustype string
EXTRN	b_vesa_bus: byte		; ptr to vesa bustype string
EXTRN	b_pnp_bus: byte			; ptr to pnp bustype string
EXTRN	b_isa_bus: byte			; ptr to isa bustype string
EXTRN	b_pci1_bus: byte		; ptr to pci bustype string mechanism1
EXTRN	b_pci2_bus: byte		; ptr to pci bustype string mechanism2
EXTRN	bustype_para_table: byte	; ptr to bustype parameter table
EXTRN	fullduplex_table:byte		; ptr to full duplex string table
EXTRN	b_10baseT:byte			; ptr to fdup 10baseT string
EXTRN	b_AUI:byte     			; ptr to fdup AUI string
EXTRN	b_fdup_off:byte			; ptr to fdup disable string
EXTRN	fullduplex_para_table:byte	; ptr to full duplex parameter table

PUBLIC	int_no				; ptr to IRQ info bytes
PUBLIC	io_addr				; ptr to I/O addr bytes
PUBLIC	dma_no				; ptr to DMA info bytes
PUBLIC	driver_class			; ptr to class bytes(Bluebook/IEEE802.3..etc)
PUBLIC	driver_type			; ptr to type byte(card/class specific)
PUBLIC	driver_name			; ptr to drv name byte(eg. NE2100)
PUBLIC	driver_function			; ptr to drv function byte(1,2,5,6,255)
PUBLIC	parameter_list			; ptr to pkt drv parameter list bytes
PUBLIC	rcv_modes			; ptr to receive mode data structure

PUBLIC	usage_msg			; PCnet-ISA pkt drv useage msg bytes
PUBLIC	copyright_msg			; PCnet-ISA driver copyright msg bytes

PUBLIC	as_send_pkt			; ptr to asynchronize send pkt routine
PUBLIC	drop_pkt			; ptr to drop packet from queue routine
PUBLIC	xmit				; ptr to process xmit int routine
PUBLIC	send_pkt			; ptr to send pkt routine
PUBLIC	get_address			; ptr to get interface addr routine
PUBLIC	set_address			; ptr to set interface addr routine
PUBLIC	set_multicast_list		; ptr to set multicast list routine
PUBLIC	terminate			; ptr to terminate pkt drv routine
PUBLIC	reset_interface			; ptr to reset interface routine
PUBLIC	recv				; ptr to process receive pkt routine
PUBLIC	recv_exiting			; ptr to exit receive routine
PUBLIC	parse_args			; ptr to parse IRQ,I/O addr,DMA info routine
PUBLIC	etopen				; ptr to init. card & cascade DMA routine 
PUBLIC	print_parameters		; ptr to print cmd line para routine

PUBLIC	b_bustype			; bus type(default 0ffh)
					; 00h ISA, 01h PnP, 10h VL, 11h PCI
PUBLIC	b_cpuflag			; processor type flag
PUBLIC	b_oem1				; OEM1 manufacturer byte(default 00h)
PUBLIC	b_oem2				; OEM2 manufacturer byte(default 00h)
PUBLIC	b_oem2_enable			; OEM2 manufacturer checking enable
PUBLIC	b_pci_method			; PCI mechanism
PUBLIC	dw_pci_bdfnum			; PCI bus/dev/function #
PUBLIC	eisa_sign_str			; EISA signiture string

PUBLIC	copyleft_msg			; original copyright message
PUBLIC	location_msg			; packet driver location message
PUBLIC	packet_int_num			; packet driver IRQ number message
PUBLIC	eaddr_msg			; packet driver ethernet address message
PUBLIC	aaddr_msg			; packet driver ARCnet address message
PUBLIC	crlf_msg			; carriage return & line feed message

PUBLIC	error_header			; packet drv error message header
PUBLIC	already_msg			; packet drv already exist error message
PUBLIC	int_msg				; packet drv IRQ range error message
PUBLIC	int_msg_num			; packet drv IRQ upper limit error message
PUBLIC	no_resident_msg			; packet drv init board failed error message
PUBLIC	packet_int_msg			; packet drv software int # error message

PUBLIC	init_err0_msg			; init error message 0 address
PUBLIC	init_err1_msg			; init error message 1 address
PUBLIC	init_err2_msg			; init error message 2 address
PUBLIC	init_err3_msg			; init error message 3 address
PUBLIC	init_err4_msg			; init error message 4 address
PUBLIC	init_err5_msg			; init error message 5 address
PUBLIC	init_err6_msg			; init error message 6 address
PUBLIC	init_err7_msg			; init error message 7 address
PUBLIC	init_err8_msg			; init error message 8 address
PUBLIC	init_err9_msg			; init error message 9 address
PUBLIC	init_err10_msg			; init error message 10 address
PUBLIC	init_err11_msg			; init error message 11 address
PUBLIC	init_err12_msg			; init error message 12 address
PUBLIC	init_err13_msg			; init error message 13 address
PUBLIC	init_err14_msg			; init error message 14 address
PUBLIC	init_err15_msg			; init error message 15 address
PUBLIC	init_err16_msg			; init error message 16 address
PUBLIC	init_err17_msg			; init error message 17 address
PUBLIC	init_err18_msg			; init error message 18 address
PUBLIC	init_err19_msg			; init error message 19 address

IFDEF	SHARE_IRQ
PUBLIC	share_isr			; check our interrupt condition
ENDIF
;
;----------------------------------------
; PCnet devices data area
;----------------------------------------
;					; PCnet
eisa_sign_str	db	'EISA'		; EISA signiture string

b_cpuflag	db	DEF_CPU_TYPE	; processor type flag byte

b_bustype	db	DEF_BUSTYPE	; bus type flag byte
					; 00 ISA, 01h PnP, 10h VL, 11h PCI
b_oem1		db	DEF_OEM		; OEM1 manufacturer byte
b_oem2		db	DEF_OEM		; OEM2 manufacturer byte
b_oem2_enable	db	DEF_OEM		; OEM2 manufacturer enable byte
b_dmarotate	db	DEF_DMAROTATE	; DMA priority rotate

b_tp		db	DEF_TP		; Twisted Pair interface enforce
					; must be 4 bytes for get/print_number.
w_led0		dw	DEF_LED0,0	; LED 0 display control
w_led1		dw	DEF_LED1,0	; LED 1 display control
w_led2		dw	DEF_LED2,0	; LED 2 display control
w_led3		dw	DEF_LED3,0	; LED 3 display control

b_fdup		db	DEF_FDUP,0	; full duplex control(disable, default)
b_dmatimer	db	DEF_DMATIMER, 0	; DMA timer

b_pci_method	db	DEF_PCI_METHOD	; PCI method used
b_1st_reset	db	DEF_1ST_RESET	; PCnet 1st reset flag
b_pci_m2_fwd	db	DEF_PCI_FWDREG	; PCI M2 config forward reg
b_pci_m2_cfg	db	DEF_PCI_CFGREG	; PCI M2 config enable reg
dw_pci_bdfnum	dd	DEF_PCI_BDFNUM	; PCI bus/dev/function #
dw_pci_m1_cad	dd	DEF_PCI_CFGADDR	; PCI config addr reg content


dma_desc	dma_descriptor <>	; VDS data structure

ipara_addr_table	label	word
	
		dw	offset packet_int_no; software interrupt number
		dw	offset int_no	; IRQ number
		dw	offset dma_no	; DMA number
		dw	offset io_addr	; IO address
KEYW_TP		equ	($ - ipara_addr_table)
		dw	offset b_tp	; twisted pair
KEYW_DMAROTATE	equ	($ - ipara_addr_table)
		dw	offset b_dmarotate; DMA rotate
KEYW_BUSTYPE	equ	($ - ipara_addr_table)
		dw	offset b_bustype; scan bus type
		dw	offset w_led0	; LED 0
		dw	offset w_led1	; LED 1
		dw	offset w_led2	; LED 2
		dw	offset w_led3	; LED 3
KEYW_FULLDUPLEX	equ	($ - ipara_addr_table)
		dw	offset b_fdup	; full duplex
KEYW_DMATIMER	equ	($ - ipara_addr_table)
		dw	offset b_dmatimer; DMA timer

KEYWORD_COUNT	equ	($ - ipara_addr_table)/2

keyword_addr_table	label	word
	
		dw	offset b_kint_no; software interrupt number
		dw	offset b_kirq_no; IRQ number
		dw	offset b_kdma_no; DMA number
		dw	offset b_kioaddr_no; IO address
		dw	offset b_ktp_en	; twisted pair(no input value)
		dw	offset b_kdmarotate; DMA rotate(no input value)
		dw	offset b_kbustype; scan bus type(text string)
		dw	offset b_kled0	; LED 0
		dw	offset b_kled1	; LED 1
		dw	offset b_kled2	; LED 2
		dw	offset b_kled3	; LED 3
		dw	offset b_kfdup	; full duplex
		dw	offset b_kdmatimer; DMA timer

bustype_addr_table	label	word

		dw	offset b_pci_bus; pci bustype string
		dw	offset b_vesa_bus; vesa bustype string
		dw	offset b_pnp_bus; pnp bustype string
		dw	offset b_isa_bus; isa bustype string
PCI_MECH_COUNT	equ	($ - bustype_addr_table)/2
		dw	offset b_pci1_bus; pci bustype string mechanism 1
		dw	offset b_pci2_bus; pci bustype string mechanism 2

BUSTYPE_COUNT	equ	($ - bustype_addr_table)/2

fullduplex_addr_table	label	word

		dw	offset b_10baseT; fdup 10baseT string
		dw	offset b_AUI	; fdup AUI string
		dw	offset b_fdup_off;fdup disable string 

FULLDUPLEX_COUNT	equ	($ - fullduplex_addr_table)/2

;
;----------------------------------------
; driver's IRQ, I/O address, DMA information data area
;----------------------------------------
;					; PCnet, set to NULL 
					; must be 4 bytes for get/print_number.
int_no		db	0,0,0,0		; default IRQ 3
io_addr		dw	0,0		; default I/O address 300H
dma_no		db	0,0,0,0		; default DMA channel 5

;
;----------------------------------------
; driver's class, type, name, function
;----------------------------------------
;

driver_class	db BLUEBOOK, IEEE8023, 0; from the packet spec
driver_type	db	99	 ; unused in the packet spec
driver_name	db	'NE2100',0	; name of the driver.
driver_function	db	2		; basic, extended

;
;----------------------------------------
; driver's parameter's list
;----------------------------------------
;
parameter_list	LABEL	byte
		db	1		; major rev of packet driver
		db	9		; minor rev of packet driver
		db	14		; length of parameter list
		db	EADDR_LEN	; length of MAC-layer address
		dw	GIANT		; MTU, including MAC headers
		dw	MAX_MULTICAST*EADDR_LEN	; buffer size of multicast addrs
		dw	RCV_BUF_COUNT-1	; (# of back-to-back MTU rcvs) - 1
		dw	XMIT_BUF_COUNT-1; (# of successive xmits) - 1


int_num		dw	0		; Interrupt # to hook for post-EOI
					; processing, 0 == none,
;
;----------------------------------------
;
;----------------------------------------
;

rcv_modes	dw	7		; number of receive modes in our table.
		dw	0		; no such mode
		dw	rcv_mode_1	; 1. turn off receiver
		dw	0		; 2. receive only pkts sent to this interface(deafult)
		dw	rcv_mode_3	; 3. mode 2 plus broadcast
		dw	0		; 4. mode 3 plus some multicasts
		dw	rcv_mode_5	; 5. mode 3 plus all multicasts
		dw	rcv_mode_6	; 6. all packets

;
;----------------------------------------
; PCNET descriptor pointers on a qword boundary.
;----------------------------------------
;
IFDEF	PH_HLA0			;
ALIGN	16				; must be on paragraph boundary
ELSE
ALIGN	8				; must be on 8 bytes boundary
ENDIF

xmit_dscps	XMIT_MSG_DSCP XMIT_BUF_COUNT dup(<>);
rcv_dscps	RCV_MSG_DSCP  RCV_BUF_COUNT dup(<>) ;

xmit_head	dw	xmit_dscps	; cur xmit dscps addr (host filled).
rcv_head	dw	rcv_dscps	; cur recv dscps addr (PCnet/LANCE filled)

xmit_buf_addr	dw	0,0		;low word, high word
rcv_buf_addr	dw	0,0		;low word, high word

phys_buf_addr	dw	0,0		;low word, high word	
logic_buf_addr	dw	0,0		;offset, segment

;
;----------------------------------------
;  PCNET Initialization Block
;----------------------------------------
;
IFDEF	PH_HLA1			;
ALIGN	4				; must be on double word boundary
ELSE
ALIGN	2				; must be on word boundary
ENDIF

init_block	LABEL	byte		; initialize block data structure

init_mode	dw	DEF_MODE_REG	; init mode -> CSR15
init_addr	db	EADDR_LEN dup(?); our ethernet addr(PADR[47:0])
init_filter	db	INIT_FILTER_LN dup(0); Multicast filter(LADRF[63:0])
init_receive	dw	?,?		; Receive Ring Pointer(RDRA[23:0],RLEN)
init_transmit	dw	?,?		; Transmit Ring Pointer(TDRA[23:0],TLEN)

INIT_BLOCK_SIZE	equ	$ - init_block	; init block size

init_blk_high	dw	?		;
init_blk_low	dw	?		;
;
;----------------------------------------
; The Asynchronous Transmit Packet routine.
; Enter with
;   es:di -> i/o control block,
;   ds:si -> packet,
;   cx = packet length,
;   interrupts possibly enabled.
; Exit with
;   nc if ok, or else cy if error, dh set to error number.
;   es:di and interrupt enable flag preserved on exit.
;----------------------------------------
;
as_send_pkt:				; asynchronize send packet(empty)
	ret				; return to caller

;
;----------------------------------------
; Drop a packet from the queue.
; Enter with
;   es:di -> iocb.
;----------------------------------------
;
drop_pkt:				; drop a pocket from the queue(empty)
	assume	ds:nothing		;
	ret				; return to caller

;
;----------------------------------------
; Process a transmit interrupt with the least possible latency to achieve
;   back-to-back packet transmissions.
; May only use ax and dx.
;----------------------------------------
;
xmit:					; xmit int(empty)
	assume	ds:nothing		;
	ret				; return to caller


;
;----------------------------------------
; enter with
;   ds:si -> packet,
;   cx = packet length.
; exit with
;   nc if ok, or else cy if error, dh set to error number.
;----------------------------------------
;
send_pkt:				; entry of send_packet
	assume	ds:nothing		;

;
;----------------------------------------
; check device STOP case
;----------------------------------------
;
	push	ds			; save caller's DS
	mov	ax,cs			;
	mov	ds,ax			; DS = CS
IFDEF	PH_GGA1
	INPORTG	CSR0			; read CSR 0
ELSE
	INPORT	CSR0			; read CSR 0
ENDIF
	test	ax,CSR0_STOP		; check device STOP bit set
	pop	ds			; restore caller's DS
	jnz	short send_pkt_2_1	; jump, if stop bit set
					;
	cmp	cx,cs:XMIT_BUF_SIZE	; check CX > XMIT_BUF_SIZE
	ja	short send_err		; jump, if CX > XMIT_BUF_SIZE
	xor	bx,bx			; BX = 0

	mov	ax,18			; AX = time count 18(476.4ms)
	call	set_timeout		; set timer counter
send_pkt_1:				
					; Did the pcnet chip give it back?
	test	cs:xmit_dscps[bx].tmd1,XMIT_OWN; check xmit descps own by PCNET
	je	short send_pkt_2	; jump, if not own by PCNET
	call	do_timeout		; check time out counter
	jne	short send_pkt_1	; loop, if timer not exhausted
send_err:
	mov	dh,CANT_SEND		; DH = return error code
	stc				; return set carry flag indicate error
	ret				; return to caller
send_pkt_2:
	push	ds			; save caller's DS
	mov	ax,cs			;
	mov	ds,ax			; DS = CS
IFDEF	PH_GGA1
	INPORTG	CSR0			; read CSR 0
ELSE
	INPORT	CSR0			; read CSR 0
ENDIF
	test	ax,CSR0_TXON		; check xmt on
	pop	ds			; restore caller's DS
	jnz	short send_pkt_3   	; jump, if xmt on
send_pkt_2_1:
	push	ds			; save DS
	push	cs			; save CS
	pop	ds			; set DS = CS
	call	complete_reset		; complete reset to patch under flow
	pop	ds			; restore DS
	jmp	short send_err		; set send error
send_pkt_3:
;
;----------------------------------------
; reset error indications.
; xmit descriptors must own by system(host)
;----------------------------------------
					; Did the pcnet chip give it back?
					; clear TMD1 & TMD3 error bits
					; clear deferred, retry bits
	and	cs:xmit_dscps[bx].tmd1,not (XMIT_ERR or XMIT_DEF or XMIT_1_RETRY or XMIT_RETRY);
	mov	cs:xmit_dscps[bx].tmd3,0; clear all error bits.

	mov	ax,cx			; CX = input packet length
	cmp	ax,RUNT			; check input pkt len > mini Ether len
	ja	short oklen		; jump, if pkt len > mini ether len
	mov	ax,RUNT			; AX = mini ether len at least
oklen:
	neg	ax			; AX = two's complemete input pkt len
	mov	cs:xmit_dscps[bx].tmd2,ax; store two's complemete input pkt len

	mov	ax,cs:xmit_buf_addr	; AX = xmit physical addr low word
	mov	dx,cs:xmit_buf_addr+2	; DX = xmit physical addr high word
	mov	cs:phys_buf_addr,ax	; AX = xmit physical addr low word
	mov	cs:phys_buf_addr+2,dx 	; DX = xmit physical addr high word
	mov	ax,offset cs:transmit_bufs; AX = xmit buff logical addr offset
	mov	cs:logic_buf_addr,ax	; xmit logical addr offset
	mov	ax,cs			; AX = CS
	mov	cs:logic_buf_addr+2,ax	; xmit logical addr segment

	mov	ax,cs:xmit_dscps[bx].tmd0; AX = LADRL[15:0]
	mov	dx,cs:xmit_dscps[bx].tmd1; DH = LADRH[15:8], DL = LADRH[7:0]
					; convert 20(24) bits to seg:off format
	call	phys_to_segmoffs	; DL:AX -> ES:DI
	shr	cx,1			; CX = input packet length(word)
	rep	movsw			; Move input pkt to xmit buffer
	jnc	short xmit_cnte		; jump, if even count
	movsb				; Move last byte(odd number)
xmit_cnte:
					; give it to the PCnet chip.
					; setup owner, start & end bits
	or	cs:xmit_dscps[bx].tmd1,XMIT_OWN or XMIT_START or XMIT_END;
;
;----------------------------------------
; Inform PCNET that it should poll for a packet.
;----------------------------------------
;
IFDEF	PH_GGA1
	mov	ax,CSR0_INEA or CSR0_TDMD; enable int & demand xmit
	OUTPORTS	CSR0		; write to PCnet-ISA status register
ELSE
	mov	ax,CSR0_INEA or CSR0_TDMD; enable int & demand xmit
	OUTPORT	CSR0			; write to PCnet-ISA status register
ENDIF
	clc				; return clear carry flag indicate ok.
	ret				; return to caller


;
;----------------------------------------
; get the address of the interface.
; enter with 
;   es:di -> place to get the address,
;   cx = size of address buffer.
; exit with
;   nc, cx = actual size of address,
;   or cy if buffer not big enough.
;----------------------------------------
;
					; set & get address different
					; get read PCNET NODE REG
					; set doesn't write PCNET NODE REG
					; set reset PCNET for 10 sec ???

get_address:				; get ethernet address from device
	assume	ds:code			;
	cmp	cx,EADDR_LEN		; check addr len vs. ethernet addr len
	jb	short get_address_2 	; jump, if current address short
	mov	cx,EADDR_LEN		; CX = ethernet addr length
	mov	dx,io_addr		; DX = Ethernet address base.
	add	dx,NODE_REG		; DX = Node register addr
	cld				; set increment direction flag
get_address_1:
	insb				; ES:DI = i/o read DX, inc DI by one
	inc	dx			; index to next address
	loop	get_address_1		; loop until CX exhaust(ethernet add end)

	mov	cx,EADDR_LEN		; CX = ethernet address length
	clc				; return clear carry flag indicate ok
	ret				; return to caller
get_address_2:
	stc				; return set carry flag indicate error
	ret				; return to caller


;
;----------------------------------------
; enter with 
;   ds:si -> Ethernet address,
;   cx = length of address.
; exit with
;   nc if okay,
;   or cy, dh=error if any errors.
;----------------------------------------
;
set_address:
	assume	ds:nothing		;
	cmp	cx,EADDR_LEN		; check input addr len vs. ethernet addr len
	je	short set_address_4	; jump, if same size
	mov	dh,BAD_ADDRESS		; return DH = BAD_ADDRESS
	stc				; return set carry flag indicate error
	jmp	short set_address_done	; jump
set_address_4:

	push	cs			; save CS on stack
	pop	es			; ES = CS
	mov	di,offset init_addr	; DI = address of init addr
	rep	movsb			; copy input address to init address
	call	initialize		; initialize with our new address.

set_address_okay:
	mov	cx,EADDR_LEN		; CX = ethernet address length.
	clc				; return clear carry flag indicate ok.
set_address_done:
	push	cs			; save CS on stack
	pop	ds			; DS = CS
	assume	ds:code			;
	ret				; return to caller

;
;----------------------------------------
;
;----------------------------------------
;
rcv_mode_1:				; disable the receiver and transmitter.
	mov	ax,M_DRX or M_DTX	; AX = disable xmit & recv
	jmp	short initialize_nomulti; jump to initialize 
rcv_mode_3:				; don't accept any multicast frames.
	xor	ax,ax			; AX = 0
	call	initialize_multi	; LADRF[63:0] = 0
	mov	ax,0			; AX = 0, non-promiscuous mode
	jmp	short initialize_nomulti; jump to initialize 
rcv_mode_5:				; accept any multicast frames.
	mov	ax,-1			; AX = 0xFFFF
	call	initialize_multi	; LADRF[63:0] = 0xFFFF
	mov	ax,0			; AX = 0, non-promiscuous mode
	jmp	short initialize_nomulti; jump to initialize 
rcv_mode_6:
	mov	ax,M_PROM		; AX = 8000h, promiscuous mode
initialize_nomulti:
initialize:
	cmp	byte ptr cs:b_bustype,PCI_BUSTYPE; check PCI bustype
	jne	short normal_initialize	; jump, if not PCI bus
	push	ds			; save DS
	push	cs			; save CS
	pop	ds			; DS = CS
	call	pci_stop_pcnet		; stop PCnet PCI device
	pop	ds			; restore DS
	jnc	short initialize_start	; jump, if stop PCnet PCI complete
	ret				; return, if error
normal_initialize:
	;
	mov	ax,CSR0_STOP		; AX = set CSR0 stop bit of PCNET
IFDEF	PH_GGA1
	OUTPORTS	CSR0		; Write AX to CSR0 register
ELSE
	OUTPORT	CSR0			; Write AX to CSR0 register
ENDIF
initialize_start:
	mov	ax,CSR0_INIT		; AX = set CSR0 init bit of PCNET
IFDEF	PH_GGA1
	OUTPORT	CSR0			; write AX to CSR0 register
					; assume bus master stop
ELSE
	OUTPORT	CSR0			; write AX to CSR0 register
ENDIF
					; 10 sec to time out ?????
	mov	ax,360			; AX = 360(10 seconds) timeout count
	call	set_timeout		; set time out counter with AX
initialize_1:
IFDEF	PH_GGA1
	INPORTG	CSR0			; read CSR0
ELSE
	INPORT	CSR0			; read CSR0
ENDIF
	test	ax,CSR0_IDON		; check init done bit in CSR0
	jne	short initialize_2	; jump, if init done 
	call	do_timeout		; check time out counter
	jne	short initialize_1	; loop, if counter not exhausted
					; timer expired, init not completed
	stc				; return set carry flag indicate error
	ret				; return to caller
initialize_2:
IFDEF	PH_GGA1
	mov	ax,CSR0_INEA or CSR0_STRT; AX = set CSR0 start & bits of PCNET
	OUTPORT	CSR0			; write to CSR0 register
					; no DMA opration in this period
ELSE
	mov	ax,CSR0_INEA or CSR0_STRT; AX = set CSR0 start & bits of PCNET
	OUTPORT	CSR0			; write to CSR0 register
ENDIF
	clc				; return clear carry flag indicate ok
	ret				; return to caller

initialize_multi:

;----------------------------------------
; enter with
;   ax = value for all multicast hash bits.
;----------------------------------------
;
	push	cs			; save CS
	pop	es			; ES = CS
	mov	di,offset init_filter	; DI = address of init_filter(LADRF)
	mov	cx,INIT_FILTER_LN/2	; CX = length of init filter(LADRF)
	rep	stosw			; store AX into ES:DI (same??)
	ret				; return to caller


;
;----------------------------------------
; enter with ds:si ->list of multicast addresses, cx = number of addresses.
; return nc if we set all of them, or cy,dh=error if we didn't.
;----------------------------------------
;
set_multicast_list:
	mov	dh,NO_MULTICAST		; return DH = NO_MULTICAST(not supported)
	stc				; return set carry flag indicate error
	ret				; return to caller

;
;----------------------------------------
;
;----------------------------------------
;
terminate:				; don't receive any packets.
	call	rcv_mode_1		; disable the xmit & recv
;
;----------------------------------------
; check local bus bus type(VL ISA or PCI) to skip DMA cascade restore
;----------------------------------------
;
	cmp	b_bustype,VLISA_BUSTYPE	; check bustype = VLISA BUS
	je	short terminate_done	; jump, if bustype = VLISA BUS
	cmp	b_bustype,PCI_BUSTYPE	; check bustype = PCI BUS
	je	short terminate_done	; jump, if bustype = PCI BUS
;
;----------------------------------------
; This routine will remove the (host) DMA controller from
; cascade mode of operation.
;----------------------------------------
;
	mov	al,dma_no		; AL = dma #
					; next ln move to 8 & 16 case ????
	or	al,SET_DMA_MASK		; AL = (???)
	cmp	dma_no,4		; check dma # > 4
	ja	short terminate_16 	; jump, If channel 5or6, 16 bit dma.
terminate_8:
	out	DMA_8MASK_REG,al	; write to 8 bit dma mask register
	jmp	short terminate_done	; jump, to write CSR0
terminate_16:
	out	DMA_16MASK_REG,al	; write to 16 bit dma mask register
terminate_done:
	cmp	b_bustype,PCI_BUSTYPE	; check PCI bustype
	jne	short normal_terminate	; jump, if not PCI bus
	call	pci_stop_pcnet		; stop PCnet PCI device
	ret				; return, if error
normal_terminate:
	mov	ax,CSR0_STOP		; AX = stop bit set
IFDEF	PH_GGA1
	OUTPORTS	CSR0		; write to CSR0
ELSE
	OUTPORT	CSR0			; write to CSR0
ENDIF
	ret				; return to caller

;
;----------------------------------------
;reset the interface.
;----------------------------------------
;
reset_interface:			; reset interface(empty)
	assume	ds:code			;
	ret				; return to caller


PCNET_ISR_ACKNOWLEDGE equ (CSR0_INEA or CSR0_TDMD or CSR0_STOP or CSR0_STRT or CSR0_INIT)

;
;----------------------------------------
; called from the recv isr.
; All registers have been saved, and ds=cs.
; Upon exit, the interrupt will be acknowledged.
;----------------------------------------
;
recv:
	assume	ds:code

IFDEF	PH_GGA1
	INPORTG	CSR0			;
ELSE
	INPORT	CSR0			;
ENDIF
	mov	bx,ax			; BX = AX
;
;----------------------------------------
; Acknowledge the Interrupt from the controller,
; but disable further controller Interrupts until
; we service the current interrupt.
;
; (CSR0_INEA or CSR0_TDMD or CSR0_STOP or CSR0_STRT or CSR0_INIT)
;----------------------------------------
;
IFDEF	PH_GGA1
	and	ax,not PCNET_ISR_ACKNOWLEDGE; AX=clear INEA,TDMD,STOP,STRT,INIT
	OUTPORTCI	CSR0		;
ELSE
	and	ax,not PCNET_ISR_ACKNOWLEDGE; AX=clear INEA,TDMD,STOP,STRT,INIT
	out	dx,ax			; DX = CSR0 data
ENDIF
					; Enable forward jump directive for tasm
	test	bx,CSR0_RINT		; check BX = receive interrupt set
	je	short recv_test		; jump, if recv int not occur
recv_int_occur:
	mov	bx,rcv_head		; bx = current recv dscps addr
recv_search:
	test	code:[bx].rmd1,RCV_OWN	; check ownership of this buffer
	je	short recv_own		; jump, if own bit clear(host own)
	call	inc_recv_ring		; check next recv ring dscps
	cmp	bx,rcv_head		; check current dscps = started dscps
	jne	short recv_search	; jump, if current dscps != started one
recv_noint:				; search entire dscps(wrap around)
	jmp	recv_done		; jump to exit(yes spurious interrupt!)
recv_test:
	jmp	recv_test_stop		;
recv_own:
	test	code:[bx].rmd1,RCV_ERR	; check any errors in current dscps
	jne	short recv_err		; jump, if error occured(ignore pkt)
					; fetch the packet.

	mov	ax,rcv_buf_addr		; AX = rcv physical addr low word
	mov	dx,rcv_buf_addr+2	; DX = rcv physical addr high word
	mov	phys_buf_addr,ax	; AX = rcv physical addr low word
	mov	phys_buf_addr+2,dx 	; DX = rcv physical addr high word
	mov	logic_buf_addr,offset receive_bufs; rcv logical addr offset
	mov	ax,cs			; AX = CS
	mov	logic_buf_addr+2,ax	; rcv logical addr segment

	mov	ax,code:[bx].rmd0	; ax = low 16 bit addr
	mov	dx,code:[bx].rmd1	; dx = status & high 8(4/DOS) bit addr
	call	phys_to_segmoffs	; convert DL[4-0]:AX[15-0] -> ES:DI

	push	es			; save ES = input seg for type
	push	di			; save DI = input off for type
	push	bx			; save BX = current recv dscps addr

	mov	cx,code:[bx].rmd3	; CX = message byte count
	sub	cx,FCS			; CX = message byte count(w/o FCS)10.4
	and	cx,0fffh		; CX = strip off the res bits[15-12]
	add	di,EADDR_LEN+EADDR_LEN	; DI = skip (dest,sour)ethernet addr
					;      and pt to the packet type.10.4
	mov	dl, BLUEBOOK		; DL = assume bluebook Ethernet.
	mov	ax, es:[di]		; AX = (low,high) length
	xchg	ah, al			; AH = high, AL = low
	cmp 	ax, MAXI_DLEN		; check AX vs. MAXI_DLEN
	ja	short BlueBookPacket	; jump, if AX > MAXI_DLEN
	inc	di			; 
	inc	di			; DI = point to 802.2 header
	mov	dl, IEEE8023		; DL = IEEE8023
BlueBookPacket:
	push	cx			; save CX = message byte count
;
;----------------------------------------
; called when we want to determine what to do with a received packet.
; enter with
;   cx = packet length,
;   dl = packet class,
;   es:di -> packet type.
;----------------------------------------
;
	call	recv_find		; return ES:DI -> pkt buf or 0(if err)
	pop	cx			; restore CX = message byte count

	pop	bx			; BX = current recv dscps addr
	pop	si			; SI = DI input off for type
	pop	ds			; DS = ES input seg for type
	assume	ds:nothing		; 
					; check ES:DI null pointer
	mov	ax,es			; AX = ES
	or	ax,di			; AX = ES or DI 
	je	short recv_free		; jump,if ES:DI=null ptr(free the frame)

	push	es			; save ES = seg of buffer
	push	di			; save DI = off of buffer
	push	cx			; save CX = message byte count
	shr	cx,1			; CX = message word count
	rep	movsw			; copy the recv message into buffer
	jnc	short recv_cnte		; jump, if even byte
	movsb				; copy last byte(odd)
recv_cnte:
	pop	cx			; restore CX = message byte count
	pop	si			; restore SI = off of buffer
	pop	ds			; restore DS = seg of buffer
	assume	ds:nothing		;

;
;----------------------------------------
; called after we have copied the packet into the buffer.
; enter with
;   ds:si ->the packet,
;   cx = length of the packet.
;----------------------------------------
;
	call	recv_copy		; call clint to copy received buffer

	jmp	short recv_free		; skip over error statistic

recv_err:
	call	count_in_err		; increment error statistics
recv_free:
	push	cs			; save CS on stack
	pop	ds			; DS = CS
	assume	ds:code			;
;
;----------------------------------------
;clear any error bits.
;----------------------------------------
;
	and	code:[bx].rmd1,not (RCV_ERR or RCV_FRAM or RCV_OFLO or RCV_CRC or RCV_BUF_ERR)
	or	code:[bx].rmd1,RCV_OWN	; set current dscps own bit(PCnet)
IFDEF	PH_HLA1			;
	mov	code:[bx].rmd2,-RCV_BUF_SIZE; recv dscps rmd2[15:0]=-(recv buf size) 
					; (BCNT=2's comp of recv buf size)
ENDIF					;
	call	inc_recv_ring		; check next recv ring dscps
	test	code:[bx].rmd1,RCV_OWN	; check ownership of this buffer
	jne	short recv_next		; jump, if own bit set(device own)
	jmp	recv_own		; jump, if own bit clear(host own)
recv_next:
	mov	rcv_head,bx		; remember where the next one starts.
recv_done:
	mov	ax,CSR0_INEA		; AX = set enable interrupts bit
IFDEF	PH_GGA1
	OUTPORTS	CSR0		; write to CSR0 & enable int
ELSE
	OUTPORT	CSR0			; write to CSR0 & enable int
ENDIF
	ret				; return to caller

;----------------------------------------

recv_test_stop:
	test	bx,CSR0_STOP		; check STOP bit set
	jz	short recv_done		; jump, if STOP bit clear
	call	complete_reset		; reset, if STOP bit set
	jmp	short recv_done		; reset complete
;----------------------------------------

complete_reset:
;
;----------------------------------------
; receive power down happened, xton clear
;----------------------------------------
;
					; STOP bit set, power down happened
	call	device_reset		; reset pcnet device 
	;				; reset xmit & recv ring ptr
	mov	word ptr xmit_head, offset xmit_dscps; reset xmit ring
	mov	word ptr rcv_head, offset rcv_dscps; reset rcv ring
	;				; clear xmit ring entries own bit
	mov	cx,XMIT_BUF_COUNT	; CX = xmit buffer count
	mov	bx,offset xmit_dscps	; BX = start addr of xmit dscps ring
clear_xmit_ownbit:
	and	[bx].tmd1,not(XMIT_OWN)	; xmit dscps tmd1[15] = 0
	add	bx,(size XMIT_MSG_DSCP)	; BX = next xmit dscps start addr
	loop	clear_xmit_ownbit	; loop, until CX exhausted
	;				; set recv ring entries own bit
	mov	cx,RCV_BUF_COUNT	; CX = recv buffer count
	mov	bx,offset rcv_dscps	; BX = start addr of recv dscps ring
set_recv_ownbit:
	or	[bx].rmd1,RCV_OWN	; recv dscps rmd1[15] = 1
	add	bx,(size RCV_MSG_DSCP)	; BX = next recv dscps start addr
	loop	set_recv_ownbit		; loop, until CX exhausted
	;				; set CSR 1, 2 and 3
	mov	ax,0			; AX = 0
IFDEF	PH_GGA1
	OUTPORT	CSR3			; write the bus config register.
					; assume master mode not start yet
ELSE
	OUTPORT	CSR3			; write the bus config register.
ENDIF
	mov	ax,word ptr init_blk_low; restore AX =init block addr low word
	OUTPORT	CSR1			; write CSR1 = init block low word.
	mov	ax,word ptr init_blk_high; restore AX =init block addr high word
	OUTPORT	CSR2			; write CSR2 = init block high word.
	;				;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	mov	ax,BCR2			; AX = index to register address
	out	dx,ax			; set register index
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	in	ax,dx			; AX = register contents of BCR2
	or	ax,BCR2_ASEL		; set auto selection bit
	out	dx,ax			; write to BCR2
	;				; program default/user sepcify LEDs
	call	program_led		;
	;				; program full duplex options
	call	program_fdup		;
	;				; program TP options
	call	program_tp		; (must after fdup to check conflicts)
	;				;
	call	program_dmatimer	; program DMA timer
	;				;
	call	initialize		; initialize pcnet device
	ret				; reset complete
	;
;----------------------------------------

inc_recv_ring:
;
;----------------------------------------
; advance bx to the next receive ring descriptor.
;----------------------------------------
;
	assume	ds:nothing		;
	add	bx,(size RCV_MSG_DSCP)	; BX = next dscps addr
	cmp	bx,offset rcv_dscps + RCV_BUF_COUNT * (size RCV_MSG_DSCP)
	jb	short inc_recv_ring_1	; jump, if bx < last dscps end addr
	mov	bx,offset rcv_dscps	; BX = first dscps add in dscps rings
inc_recv_ring_1:			; 
	ret				; return to caller


;
;----------------------------------------
; called from the recv isr after interrupts have been acknowledged.
; Only ds and ax have been saved.
;----------------------------------------
;
recv_exiting:				; (empty)
	assume	ds:nothing		;
	ret				; return to caller

;
;----------------------------------------
; enter with dx:ax as the physical address of the buffer,
; exit with 
;   es:di -> buffer.
;----------------------------------------
;
phys_to_segmoffs:			;
					; transfer 20 bit address to seg:offs
					; DL:AX -> ES:DI
	push	ds			; save DS
	push	dx			; save upper word of physical addr
	mov	dx,BIOS_DATA_SEG	; DX = BIOS_DATA_SEG
	mov	ds,dx			; DS = BIOS_DATA_SEG
	test	byte ptr ds:VDS_BYTE_OFF,VDS_ENABLE; check VDS enable bit
	pop	dx			; restore upper word of physical addr
	pop	ds			; restore segment register
	jz	short no_vds_support	; jump, if no VDS support
	push	ax			; save AX = physical low word
	sub	ax,cs:phys_buf_addr	; AX = relative value bet. phys offset
same_phys_hbyte:
	mov	di,cs:logic_buf_addr	; DI = logical buf starting offset
	add	di,ax			; DI = cur logical buf offset
	mov	ax,cs:logic_buf_addr+2	; AX = cur logical buf segment
	mov	es,ax			; ES = cur logical buf segment
	pop	ax			; restore AX = physical low word
	jmp	short phys_to_segmoffs_exit;
no_vds_support:
	shl	dx,16-4			; DX=low 4 bit/high word
	mov	di,ax			; DI=AX = low 16 bits/low word
	shr	di,4			; DI=high 12 bit/low word(input,para boundary)
	or	dx,di			; DX=low 4 bit/high & high 12 bit/low
	mov	es,dx			; ES=DX
	mov	di,ax			; DI=low word
	and	di,0fh			; DI=low 4 bit/low word
phys_to_segmoffs_exit:
	ret				; return to caller

INCLUDE	timeout.asm

IFDEF	SHARE_IRQ
share_isr:
	push	ax			; save registers
	push	dx			;
	push	ds			;
					;
	mov	ax,cs			;
	mov	ds,ax			; DS = CS
IFDEF	PH_GGA1
	INPORTG	CSR0			;
ELSE
	INPORT	CSR0			;
ENDIF
	test	ax,CSR0_INTR		; check our interrupt condition
	pop	ds			;
	pop	dx			; restore registers
	pop	ax			;	
	ret
ENDIF
;
;----------------------------------------
; Reset pcnet device by
; 1. read the reset register
; 2. set stop bit in CSR0
;----------------------------------------
;
device_reset:
;
;----------------------------------------
; The PCnet-ISA requires reset
;----------------------------------------
;
	cmp	b_1st_reset,DEF_1ST_RESET; check 1st time reset(installation)
	je	short software_device_rst; jump, if 1st reset

	cmp	b_bustype,PCI_BUSTYPE	; check PCI bustype
	jne	short stop_start_device_rst; jump, if not PCI bus

	pushf				; save flag reg
	cli				; disable interrupt
	call	pci_reset_pcnet		; reset PCnet PCI device
	jc	short pci_device_rst_err; jump, if error
					;
	popf				; restore flag
	clc				; clear carry flag, indicate o.k.
	ret				; return to caller
pci_device_rst_err:
	popf				; restore flag
	stc				; set carry flag, indicate error
	ret				; return to caller if reset fail

stop_start_device_rst:
	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,ADDR_REG		; DX = PCnet addr register
	xor	ax,ax			; AX = index CSR0
	out	dx,ax			; write access CSR0

	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,DATA_REG		; DX = PCnet data register
	in	ax,dx			; read in current CSR0
	or	ax,CSR0_STOP		; set STOP & clear IDON bit
IFDEF	PH_GGA1
	out	dx,ax			; write indexed register content
					; assume no DMA operation
ELSE
	out	dx,ax			; write access CSR0
ENDIF
	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,ADDR_REG		; DX = PCnet addr register
	mov	cx,DUMMY_LOOP		;
dummy_read_rap:
	in	ax,dx			; dummy read RAP
	loop	dummy_read_rap		;
	clc
	ret				; return to caller

software_device_rst:
	mov	dx,io_addr		; DX = PCnet-ISA\ET base address
	add	dx,RESET_REG		; DX = PCnet-ET reset register
	in	ax,dx			; reset the board by reading reset reg.
;
;----------------------------------------
; The PCnet requires 6 test pulse (16ms+8ms) = 150ms 
; or check ISACSR 4(LED 0) bit 15 LEDOUT set under 10 base T mode
; to ensure internal state machine complete after reset by read reset reg.
;
; according to 802.3 spec., the ethernet controller needs 
; 6 pulse connect time after reset.
;----------------------------------------
;
	mov	ax,6			; AX = count 6(167 ms)
	call	set_timeout		; setup timer counter
device_rst:				; 
	call	do_timeout		; check timer counter
	jnz	short device_rst	; loop, if timer not exhaust

	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,ADDR_REG		; DX = PCnet addr register
	xor	ax,ax			; AX = index CSR0
	out	dx,ax			; write access CSR0

device_rest:
	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,DATA_REG		; DX = PCnet data register
	xor	ax,ax			; AX = index CSR0
IFDEF	PH_GGA1
	in	ax,dx			; read indexed register content
					; assume no DMA operation
ELSE
	in	ax,dx			; read access CSR0
ENDIF
	test	ax,CSR0_STOP		; check STOP bit = 1
	jnz	short device_reset_ok	; jump, if STOP bit set

	stc				; set carry, indicate error
	ret
device_reset_ok:
	clc
	ret				; return to caller
;
;----------------------------------------
; check ISA & ISA+ case
; if user didn't specified LEDx, skip LEDx programming
;----------------------------------------
;
program_led:
					; program the LED register
	push	dx			; save register
	push	bx			;
	push	ax			;
	;
	mov	bx,BCR4			; BX = BCR4 register 
	mov	ax,bx			; AX = BCR4 register
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	out	dx,ax			; set register index
	
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	mov	ax,w_led0		; assume LED0
	out	dx,ax			; set LED register to specified
	;
	inc	bx			; BX = BCR5 register
	cmp	byte ptr b_bustype,VLISA_BUSTYPE; check bustype = VLISA BUS
	je	short prog_led1		; jump, if bustype = VLISA BUS
	cmp	byte ptr b_bustype,PCI_BUSTYPE; check bustype = PCI BUS
	je	short prog_led1		; jump, if bustype = PCI BUS
	cmp	word ptr w_led1,DEF_LED1; check user input
	je	short check_led2	; skip led 1 programming
prog_led1:
	mov	ax,bx			; AX = BCR5 register
	sub	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet address register
	out	dx,ax			; set register index
	
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	mov	ax,w_led1		; assume LED1
	out	dx,ax			; set LED register to specified
	;
check_led2:
	inc	bx			; BX = BCR6 register
	cmp	byte ptr b_bustype,VLISA_BUSTYPE; check bustype = VLISA BUS
	je	short prog_led2		; jump, if bustype = VLISA BUS
	cmp	byte ptr b_bustype,PCI_BUSTYPE; check bustype = PCI BUS
	je	short prog_led2		; jump, if bustype = PCI BUS
	cmp	word ptr w_led2,DEF_LED2; check user input
	je	short check_led3	; skip led 2 programming
prog_led2:
	mov	ax,bx			; AX = BCR6 register
	sub	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet address register
	out	dx,ax			; set register index
	
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	mov	ax,w_led2		; assume LED2
	out	dx,ax			; set LED register to specified
	;
check_led3:
	inc	bx			; BX = BCR7 register
	cmp	byte ptr b_bustype,VLISA_BUSTYPE; check bustype = VLISA BUS
	je	short prog_led3		; jump, if bustype = VLISA BUS
	cmp	byte ptr b_bustype,PCI_BUSTYPE; check bustype = PCI BUS
	je	short prog_led3		; jump, if bustype = PCI BUS
	cmp	word ptr w_led3,DEF_LED3; check user input
	je	short skip_led3		; skip led 3 programming
prog_led3:
	mov	ax,bx			; AX = BCR7 register
	sub	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet address register
	out	dx,ax			; set register index
	
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	mov	ax,w_led3		; assume LED3
	out	dx,ax			; set LED register to specified
	;
skip_led3:
	pop	ax			; restore register
	pop	bx			;
	pop	dx			;
	ret				; return to caller
;
;----------------------------------------
; 
;----------------------------------------
;
program_tp:
					; PCnet ISA II checking
;	INPORT	CSR88			; read CSR 88
;	push	ax			; save AX = contents of CSR 88
;	INPORT	CSR89			; read CSR 89
;	and	ax,CSR89_ID_MASK	; mask off unwanted bits
;	shl	ax,4			; shift 4 bits up
;	pop	dx			; DX = contents of CSR 88
;	and	dx,CSR88_ID_MASK	; mask off unwanted bits
;	shr	dx,12			; shift 12 bits down
;	or	ax,dx			; get PCnet version ID
;	cmp	ax,PCNET_ISA_FDUP	; check for PCnet ISA ++(full duplex)
;	mov	ax,DEF_MODE_REG		; AX = DEF_MODE_REG (non-promiscuous mode)
;	jne	short check_tp		; if not, check tp keyw only
;	;
;	mov	dx,io_addr		; DX = PCnet base address
;	add	dx,ADDR_REG		; DX = PCnet address register
;	mov	ax,BCR9			; AX = index to register address
;	out	dx,ax			; set register index
;	;
;	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
;	in	ax,dx			; AX = register contents of BCR9
;	and	al,03h			; mask off unwanted bits
;	cmp	al,FDUP_AUI		; check AL = full duplex AUI
	mov	ax,DEF_MODE_REG		; AX = DEF_MODE_REG (non-promiscuous mode)
;	je	short twisted_pair_notenforce; jump, if full duplex use AUI port
	;
;check_tp:
	cmp	byte ptr b_tp,DEF_TP	; check Twisted Pair keyw setting
	je	short twisted_pair_notenforce; jump, if twisted pair not enforce
	or	ax,(CSR15_10BT_SEL+CSR15_DLNKTST); select 10Base-T & DLNKTST
	push	ax			; save mode register setting
	;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	mov	ax,BCR2			; AX = index to register address
	out	dx,ax			; set register index
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	in	ax,dx			; AX = register contents of BCR2
	and	ax,NOT(BCR2_XMAUSEL+BCR2_ASEL); mask off XMAUSEL&ASEL in BCR2
	out	dx,ax			; set MAC to software select mode
	;	
	pop	ax			; restore mode register setting
twisted_pair_notenforce:
	mov	init_mode,ax		; init mode = AX
	;
	ret

;
;----------------------------------------
; enter with
;----------------------------------------
;
program_fdup:
	
	push	ax			; save registers
	push	dx			;

	cmp	byte ptr b_fdup,DEF_FDUP; check full duplex keyw setting
	je	short program_fdup_exit	; jump, if disable full duplex
	;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	mov	ax,BCR9			; AX = index to register address
	out	dx,ax			; set register index
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	in	ax,dx			; AX = register contents of BCR9
	or	al,byte ptr b_fdup	; set full duplex and correspond cable
	out	dx,ax			; set MAC to software select mode
	;	
program_fdup_exit:
	pop	dx			; restore registers
	pop	ax
	;
	ret

;
;----------------------------------------
; enter with
;----------------------------------------
;
program_dmatimer:
	
	push	ax			; save registers
	push	cx
	push	dx			;

	cmp	byte ptr b_bustype,VLISA_BUSTYPE; check bustype = VLISA BUS
	je	short program_dmatimer_exit	; jump, if bustype = VLISA BUS
	cmp	byte ptr b_bustype,PCI_BUSTYPE	; check bustype = PCI BUS
	je	short program_dmatimer_exit	; jump, if bustype = PCI BUS

	cmp	byte ptr b_dmatimer,MIN_DMATIMER; check DMA timer keyw setting
	jae	short program_dmatimer_check	; jump, if DMA timer in range
	mov	byte ptr b_dmatimer,MIN_DMATIMER; invalid value, set minimun
	jbe	short program_dmatimer_valid	; jump, if DMA timer set
program_dmatimer_check:
	cmp	byte ptr b_dmatimer,MAX_DMATIMER; check DMA timer keyw setting
	jbe	short program_dmatimer_valid	; jump, if DMA timer valid
	mov	byte ptr b_dmatimer,MAX_DMATIMER; invalid value, set maximun
program_dmatimer_valid:
	;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	mov	ax,CSR82		; AX = index to register address
	out	dx,ax			; set register index
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	mov	al,byte ptr b_dmatimer	; set DMA timer
	mov	cx,MUL_CSR82		; CX = MUL_CSR82
	mul	cl			; MUL_CSR82 xlt (100ns) to (1 us)
	out	dx,ax			; set MAC to software select mode
	;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	mov	ax,CSR4			; AX = index to register address
	out	dx,ax			; set register index
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	in	ax,dx			; read CSR4 contents
	or	ax,EN_CSR82		; enable timer bit in CSR4 
	out	dx,ax			; set timer to software select timer
	;	
program_dmatimer_exit:
	pop	dx			; restore registers
	pop	cx
	pop	ax
	;
	ret

;----------------------------------------
;
;
;
;
;----------------------------------------
;
pci_reset_pcnet	proc
	push	cx			; save registers
	push	dx			;
	push	ax			;
	;
	;--------------------------------
	; set retry loop counter
	;--------------------------------
	;
	mov	cx,PCI_STPRST_CNT	; PCnet PCI stop/reset count
	;
	;--------------------------------
	; disable DMA in the PCI config space
	;--------------------------------
	;
pci_rst_pcnet:
	cmp	b_pci_method,PCI_METHOD_1; check PCI 1
	jne	short pci_rst_disdma 	; jump, if PCI 2
	call	pci_m1_disable_dma	; disable PCnet PCI DMA
	jmp	short pci_rst_disdma_done; jump, disable PCI DMA done
pci_rst_disdma:
	call	pci_m2_disable_dma	; disable PCnet PCI DMA
	;
	;--------------------------------
	; set STOP and clear IDON in CSR0
	;--------------------------------
	;
pci_rst_disdma_done:
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet addr register
	xor	ax,ax			; AX = index CSR0
	out	dx,ax			; write access CSR0
	;	
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,DATA_REG		; DX = PCnet data register
	mov	ax,(CSR0_STOP+CSR0_IDON); set stop & clear idon bit in CSR0
	out	dx,ax			; write to CSR0
	;
	;--------------------------------
	; set INIT bit in CSR0
	;--------------------------------
	;
	mov	ax,CSR0_INIT		; AX = set CSR0 init bit of PCNET
	out	dx,ax			; write CSR0
	;
	;--------------------------------
	; enable DMA in the PCI config space
	;--------------------------------
	;
	cmp	b_pci_method,PCI_METHOD_1; check PCI 1
	jne	short pci_rst_endma 	; jump, if PCI 2
	call	pci_m1_enable_dma	; enable PCnet PCI DMA
	jmp	short pci_rst_endma_done; jump, enable PCI DMA done
pci_rst_endma:
	call	pci_m2_enable_dma	; enable PCnet PCI DMA
	;
	;--------------------------------
	; wait for IDON bit in CSR0
	;--------------------------------
	;
pci_rst_endma_done:
	mov	ax,1			; AX = 1 (26.5 ms) timeout count
	call	set_timeout		; set time out counter with AX
pci_rst_init_poll:
	in	ax,dx			; read CSR 0
	test	ax,CSR0_IDON		; check init done bit in CSR0
	jnz	short pci_rst_ok	; jump, if init done 
	call	do_timeout		; check time out counter
	jne	short pci_rst_init_poll	; loop, if timer counter not exhausted
	;
	;--------------------------------
	; if retry counter exhausted
	;--------------------------------
	;
	loop	pci_rst_pcnet		; loop, if counter not exhausted
	stc				; set carry flag
	jmp	short pci_rst_exit	; exit
	;
	;--------------------------------
	; check memory error case
	;--------------------------------
	;
pci_rst_ok:
	test	ax,CSR0_MERR		; check memory error bit
	je	short pci_rst_no_merr	; jump, if not
	or	ax,CSR0_MERR		; set memory error bit
	and	ax,not CSR0_IDON	; mask out init done bit
	out	dx,ax			; clear memory error bit
pci_rst_no_merr:
	clc				; clear carry flag
pci_rst_exit:
	pop	ax			; restore registers
	pop	dx			;
	pop	cx			;
	ret
pci_reset_pcnet	endp

;----------------------------------------
;
;
;
;
;----------------------------------------
;
pci_stop_pcnet	proc
	push	cx			; save registers
	push	dx			;
	push	ax			;
	;
	;--------------------------------
	; set retry loop counter
	;--------------------------------
	;
	mov	cx,PCI_STPRST_CNT	; PCnet PCI stop/reset count
	;
	;--------------------------------
	; disable DMA in the PCI config space
	;--------------------------------
	;
pci_stp_pcnet:
	cmp	b_pci_method,PCI_METHOD_1; check PCI 1
	jne	short pci_stp_disdma	; jump, if PCI 2
	call	pci_m1_disable_dma	; disable PCnet PCI DMA
	jmp	short pci_stp_disdma_done; jump, disable PCI DMA done
pci_stp_disdma:
	call	pci_m2_disable_dma	; disable PCnet PCI DMA
	;
	;--------------------------------
	; stop PCnet PCI device
	;--------------------------------
	;
pci_stp_disdma_done:
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet reset register
	xor	ax,ax			; AX = index CSR0
	out	dx,ax			; write access CSR0
	;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,DATA_REG		; DX = PCnet data register
	mov	ax,CSR0_STOP		; AX = set CSR0 stop bit of PCNET
	out	dx,ax			; write access CSR0
	;
	;--------------------------------
	; set INIT bit in CSR0
	;--------------------------------
	;
	mov	ax,CSR0_INIT		; AX = set CSR0 init bit of PCNET
	out	dx,ax			; write CSR0
	;
	;--------------------------------
	; enable DMA in the PCI config space
	;--------------------------------
	;
	cmp	b_pci_method,PCI_METHOD_1; check PCI 1
	jne	short pci_stp_endma	; jump, if PCI 2
	call	pci_m1_enable_dma	; enable PCnet PCI DMA
	jmp	short pci_stp_endma_done; jump, enable PCI DMA done
pci_stp_endma:
	call	pci_m2_enable_dma	; enable PCnet PCI DMA
	;
	;--------------------------------
	; wait for IDON bit in CSR0
	;--------------------------------
	;
pci_stp_endma_done:
	mov	ax,1			; AX = 1 (26.5 ms) timeout count
	call	set_timeout		; set time out counter with AX
pci_stp_poll:
	in	ax,dx			; read CSR 0
	test	ax,CSR0_IDON		; check init done bit in CSR0
	jnz	short pci_stp_ok	; jump, if init done 
	call	do_timeout		; check time out counter
	jne	short pci_stp_poll	; loop, if timer counter not exhausted
	;
	;--------------------------------
	; if retry counter exhausted
	;--------------------------------
	;
	loop	pci_stp_pcnet		; loop, if counter not exhausted
	stc				; set carry flag
	jmp	short pci_stp_exit	; exit
	;
	;--------------------------------
	; check memory error case
	;--------------------------------
	;
pci_stp_ok:
	test	ax,CSR0_MERR		; check memory error bit
	je	short pci_stp_no_merr	; jump, if not
	or	ax,CSR0_MERR		; set memory error bit
	and	ax,not CSR0_IDON	; mask out init done bit
	out	dx,ax			; clear memory error bit
pci_stp_no_merr:
	clc				; clear carry flag
pci_stp_exit:
	pop	ax			; restore registers
	pop	dx			;
	pop	cx			;
	ret
pci_stop_pcnet	endp

;----------------------------------------
;
;
;
;
;----------------------------------------
;
pci_m1_disable_dma	proc
	push	eax			; save registers
	push	dx			;
	;
	;--------------------------------
	; save config addr register content
	;--------------------------------
	;
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	in	eax,dx			; EAX = content of 0CF8h reg
	mov	dword ptr dw_pci_m1_cad,eax; save PCI config addr
	;
	;--------------------------------
	; get bus/dev/func #
	;--------------------------------
	;
	mov	eax,dword ptr dw_pci_bdfnum; EAX = bus/dev/fun/vid bit pattern
	or	eax,PCI_STACMD_OFF	; EAX = bus/dev/fun/stacmd 
	;
	;--------------------------------
	; get status/command registers
	;--------------------------------
	;
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; EAX = status & command register
	;
	;--------------------------------
	; write status/command registers disable DMA
	;--------------------------------
	;
	and	eax,not PCI_CMD_DMA	; clear DMA bit
	out	dx,eax			; write pattern to PCI config data reg
	;
	;--------------------------------
	; clear hardware latch avoid ground bouncing
	;--------------------------------
	;
	mov	eax,dword ptr dw_pci_bdfnum; EAX = bus/dev/fun/vid bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	;
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	xor	eax,eax			; AX = clear
	out	dx,eax			; write pattern to PCI config data reg
	;
	;--------------------------------
	; restore config addr register content
	;--------------------------------
	;
	mov	eax,dword ptr dw_pci_m1_cad; EAX = content of PCI config addr
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; restore content of 0CF8h reg
	;
	pop	dx			; restore registers
	pop	eax			;
	ret
pci_m1_disable_dma	endp

;----------------------------------------
;
;
;
;
;----------------------------------------
;
pci_m1_enable_dma	proc
	push	eax			; save registers
	push	dx			;
	;
	;--------------------------------
	; save config addr register content
	;--------------------------------
	;
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	in	eax,dx			; EAX = content of 0CF8h reg
	mov	dword ptr dw_pci_m1_cad,eax; save PCI config addr
	;
	;--------------------------------
	; get bus/dev/func #
	;--------------------------------
	;
	mov	eax,dword ptr dw_pci_bdfnum; EAX = bus/dev/fun/vid bit pattern
	or	eax,PCI_STACMD_OFF	; EAX = bus/dev/fun/stacmd 
	;
	;--------------------------------
	; get status/command registers
	;--------------------------------
	;
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; EAX = status & command register
	;
	;--------------------------------
	; write status/command registers enable DMA
	;--------------------------------
	;
	or	eax,PCI_CMD_DMA		; set DMA bit
	out	dx,eax			; write pattern to PCI config addr reg
	;
	;--------------------------------
	; clear hardware latch avoid ground bouncing
	;--------------------------------
	;
	mov	eax,dword ptr dw_pci_bdfnum; EAX = bus/dev/fun/vid bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	;
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	xor	eax,eax			; AX = clear
	out	dx,eax			; write pattern to PCI config data reg
	;
	;--------------------------------
	; restore config addr register content
	;--------------------------------
	;
	mov	eax,dword ptr dw_pci_m1_cad; EAX = content of PCI config addr
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; restore content of 0CF8h reg
	;
	pop	dx			; restore registers
	pop	eax			;
	ret
pci_m1_enable_dma	endp

;----------------------------------------
;
;
;
;
;----------------------------------------
;
pci_m2_disable_dma	proc
	push	ax			;
	push	dx			;
	;
	;--------------------------------
	; save forward & config register content
	;--------------------------------
	;
	mov	dx,PCI_CFW_REG		; DX = PCI config. forward reg(0CFAh)
	in	al,dx			; AL = PCI config forward content
	mov	b_pci_m2_fwd,al		; save PCI config forward content
	;
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	in	al,dx			; AL = PCI cfg space content
	and	al,PCI_M2_DISABLE	; AL = PCI cfg. space disable
	mov	b_pci_m2_cfg,al		; save PCI cfg space content
	;
	;--------------------------------
	; get bus/dev/func #
	; program forward & config register, and open PCI config space
	;--------------------------------
	;
	mov	dx,PCI_CFW_REG		; DX = PCI config. forward reg(0CFAh)
	mov	al,byte ptr dw_pci_bdfnum; AL = PCI bus #(forward reg)
	out	dx,al			; write PCI bus # to forward reg
	;
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	mov	al,byte ptr (dw_pci_bdfnum+1); AL = PCI fun #(cfg reg)
	out	dx,al			; write PCI function # to cfg space reg
	;
	mov	dx,word ptr (dw_pci_bdfnum+2); DX = PCI current dev addr
	add	dx,PCI_STACMD_OFF/4	; DX = PCI cur dev config + cmd offset
	;
	;--------------------------------
	; read, modify, and write command register & disable DMA
	;--------------------------------
	;
	in	ax,dx			; AX = command register content
	and	ax,not PCI_CMD_DMA	; AX = disable DMA in command reg
	out	dx,ax			; write command reg disable DMA	
	;
	;--------------------------------
	; clear hardware latch avoid ground bouncing
	;--------------------------------
	;
	mov	dx,word ptr (dw_pci_bdfnum+2); DX = PCI cur dev addr(vendor ID)
	mov	ax,0			; AX = clear
	out	dx,ax			; clear latch(15-0)
	add	dx,PCI_DEVID_OFF	; DX = PCI dev ID addr
	out	dx,ax			; clear latch(32-16)
	;
	;--------------------------------
	; close PCI config space
	;--------------------------------
	;
	mov	al,byte ptr (dw_pci_bdfnum+1); AL = PCI fun #(cfg reg)
	and	al,PCI_M2_DISABLE	; AL = disable config space
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	out	dx,al			; write cfg space reg
	;
	pop	dx			;
	pop	ax			;
	ret
pci_m2_disable_dma	endp

;----------------------------------------
;
;
;
;
;----------------------------------------
;
pci_m2_enable_dma	proc
	push	ax			; save registers
	push	dx			;
	;
	;--------------------------------
	; get bus/dev/func #
	; program forward & config register, and open PCI config space
	;--------------------------------
	;
	mov	dx,PCI_CFW_REG		; DX = PCI config. forward reg(0CFAh)
	mov	al,byte ptr dw_pci_bdfnum; AL = PCI bus #(forward reg)
	out	dx,al			; write PCI bus # to forward reg
	;
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	mov	al,byte ptr (dw_pci_bdfnum+1); AL = PCI fun #(cfg reg)
	out	dx,al			; write PCI function # to cfg space reg
	;
	mov	dx,word ptr (dw_pci_bdfnum+2); DX = PCI current dev addr
	add	dx,PCI_STACMD_OFF/4	; DX = PCI cur dev config + cmd offset
	;
	;--------------------------------
	; read, modify, and write command register to enable DMA
	;--------------------------------
	;
	in	ax,dx			; AX = command register content
	or	ax,PCI_CMD_DMA		; AX = enable DMA in command reg
	out	dx,ax			; write command reg disable DMA	
	;
	;--------------------------------
	; clear hardware latch avoid ground bouncing
	;--------------------------------
	;
	mov	dx,word ptr (dw_pci_bdfnum+2); DX = PCI cur dev addr(vendor ID)
	mov	ax,0			; AX = clear
	out	dx,ax			; clear latch(15-0)
	add	dx,PCI_DEVID_OFF	; DX = PCI dev ID addr
	out	dx,ax			; clear latch(32-16)
	;
	;--------------------------------
	; close PCI config space
	;--------------------------------
	;
	mov	al,byte ptr (dw_pci_bdfnum+1); AL = PCI fun #(cfg reg)
	and	al,PCI_M2_DISABLE	; AL = disable config space
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	out	dx,al			; write cfg space reg
	;
	;--------------------------------
	; restore forward & config register content & close PCI config space
	;--------------------------------
	;
	mov	dx,PCI_CFW_REG		; DX = PCI config. forward reg(0CFAh)
	mov	al,b_pci_m2_fwd		; AL = PCI config forward content
	out	dx,al			; restore forward register
	;
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	mov	al,b_pci_m2_cfg		; save PCI cfg space content
	out	dx,al			; AL = PCI cfg space content
	;
	pop	dx			; restore registers
	pop	ax
	ret
pci_m2_enable_dma	endp

;
;----------------------------------------
; we use this memory for buffers once we've gone resident.
;----------------------------------------
;
ALIGN	2

transmit_bufs	db	XMIT_BUF_COUNT * XMIT_BUF_SIZE dup (0)
receive_bufs	db	RCV_BUF_COUNT * RCV_BUF_SIZE dup (0)

end_resident	equ	$


INCLUDE	msg.asm

;
;----------------------------------------
; exit with nc if all went well, cy otherwise.
;----------------------------------------
;
parse_args:				; 
	assume	ds:code			;
;
;----------------------------------------
; enter with 
;   si -> argument string,
;   di -> dword to store.
; if there is no number, don't change the number.
; at least INT(one) keyword must exist, otherwise, error.
;----------------------------------------
;
	call	find_strlen		; find INT keyword
	or	cx,cx			; check string length
	stc				; assume string length = 0, error
	jne	short parse_args_tmp1	; jump, continue
	jmp	parse_args_exit		; jump, error and exit
;	je	short parse_args_exit	; jump, error and exit
parse_args_tmp1:	
	call	captialize_str		; convert input string to upper case
	mov	di,offset b_kint_no	; DI = 'INT' keyword string
	call	compare_str		; compare string & get input parameter
	stc				; assume 1st keyword isn't "INT"
	je	short parse_args_tmp2 	; jump, continue
	jmp	parse_args_exit 	; jump, error and exit
;	jne	short parse_args_exit 	; jump, error and exit
parse_args_tmp2:	
	;
	mov	di,offset packet_int_no	; DI = INT # internal storage
	call	get_number		; store input INT # to INT # bytes 
	;
parse_args_loop:	
	call	skip_blanks		; skip blanks between keywords/endline
	cmp	al,CR			; check of end of line(CR)
	je	short parse_args_done	; jump, if end of line(CR) find
	;
	call	find_strlen		; find CX = string length
	inc	si			; assume cx = 0, point to next position
	or	cx,cx			; check string length
	je	short parse_args_loop	; jump, if string length = 0
	;
	dec	si			; cx != 0, point to previous position
	call	captialize_str		; convert input string to upper case
	;
	push	cx			; save CX = input string length
	push	si			; save SI = input string starting addr
	mov	cx,KEYWORD_COUNT	; CX = total keyword number count
parse_args_key:
	pop	si			; SI = input string starting address
	pop	ax			; AX = input string length
	push	ax			; save CX = input string length
	push	si			; save SI = input string starting addr
	push	cx			; save CX = keyword number count
	neg	cx			; CX = keyword number count(2's complete)
	add	cx,KEYWORD_COUNT	; CX = reverse index
	mov	di,offset keyword_addr_table; DS:DI = keyword addr table 
	shl	cx,1			; adjust to word size
	add	di,cx			; point to proper index
	mov	di,word ptr [di]	; DI = keyword string storage 
	mov	cx,ax			; CX = input string length
	call	compare_str		; compare string
	pop	cx			; restore CX = keyword number count
	je	short parse_args_match	; find the match one
	loop	parse_args_key		; inner loop till count exhaust
parse_args_match:
	pop	ax			; balance stack
	pop	ax			; AX = input string length
	jcxz	short parse_args_loop	; jump, not a keyword 
	;
;	inc	cx			; CX = keyword count before loop inst.
	neg	cx			; CX = keyword number count(2's complete)
	add	cx,KEYWORD_COUNT	; CX = reverse index
	mov	di,offset ipara_addr_table; DS:DI = input para addr table 
	shl	cx,1			; adjust to word size
	add	di,cx			; point to proper index
	mov	di,word ptr [di]	; DI = input para internal storage 
	cmp	cx,KEYW_BUSTYPE		; check keyword bus type
	je	short parse_args_bustype; parse string input
	cmp	cx,KEYW_FULLDUPLEX	; check keyword fdup type
	jne	short parse_args_number	; parse number input
	call	get_fullduplex_string	; parse text string
	inc	si			; point to next character
	jmp	short parse_args_loop	; outer loop for next keywords/endline
parse_args_bustype:
	call	get_bustype_string	; parse text string
	inc	si			; point to next character
	jmp	short parse_args_loop	; outer loop for next keywords/endline
parse_args_number:
	cmp	cx,KEYW_TP		; check TP
	jne	short parse_args_num1	; parse number input
	or	byte ptr b_tp,EN_TP	; set TP on
	jmp	short parse_args_loop	; outer loop for next keywords/endline
parse_args_num1:
	cmp	cx,KEYW_DMAROTATE	; check DMAROTATE
	jne	short parse_args_num2	; parse number input
	or	byte ptr b_dmarotate,EN_DMAROTATE; set DMAROTATE on
	jmp	short parse_args_loop	; outer loop for next keywords/endline
parse_args_num2:
	call	get_number		; get value from input parameter
	jmp	parse_args_loop		; outer loop for next keywords/endline
parse_args_done:
	clc				; return clear carry flag indicate ok.
parse_args_exit:
	ret				; return to caller

;
;----------------------------------------
; This routine will put the (host) DMA controller into
; cascade mode of operation.
;----------------------------------------
;
etopen:
	assume	ds:code			;
					; move forward 10.5 (begin 07-12-93)
;
;----------------------------------------
; check local bus bus type(VL ISA or PCI) to skip DMA initialize
;----------------------------------------
;
	cmp	b_bustype,VLISA_BUSTYPE	; check bustype = VLISA BUS
	je	short init_dma_done	; jump, if bustype = VLISA BUS
	cmp	b_bustype,PCI_BUSTYPE	; check bustype = PCI BUS
	je	short init_dma_done	; jump, if bustype = PCI BUS
;
	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,ADDR_REG		; DX = PCnet addr register
	xor	ax,ax			; AX = index CSR0
	out	dx,ax			; write access CSR0

	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,DATA_REG		; DX = PCnet data register
	mov	ax,CSR0_STOP		; set STOP & clear IDON bit
	out	dx,ax			; write indexed register content

	mov	dx,io_addr		; DX = PCnet io base addr
	add	dx,ADDR_REG		; DX = PCnet addr register
	mov	cx,DUMMY_LOOP		;
dummy_read_rapx:
	in	ax,dx			; dummy read RAP
	loop	dummy_read_rapx		;

;
;----------------------------------------
; init DMA channel before PCnet reset
;----------------------------------------
;
	mov	al,dma_no		; AL = dma number
	cmp	al,4			; check dma width = 8 bit(dma # <= 4)
	ja	short init_dma_16	; jump, if dma > 4(dma width = 16 bit)
init_dma_8:				; 8 bit dma
	or	al,SINGLE_MODE		; AL = set single mode bit
	out	DMA_8MODE_REG,al	; write to 8 bit dma mode reg.
	and	al,DMA_CHL_FIELD	; AL = set proper dma channel bit
	out	DMA_8MASK_REG,al	; write to 8 bit dma mask reg.
	jmp	short init_dma_done	;
init_dma_16:				; 16 bit dma
	and	al,DMA_CHL_FIELD	; AL = set proper dma channel bit
	out	DMA_16MASK_REG,al	; write to 16 bit dma mask reg
	or	al,SINGLE_MODE		; AL = set single mode bit
	out	DMA_16MODE_REG,al	; write to 16 bit dma mode reg.
init_dma_done:				; Get board's interrupt vector
;
;----------------------------------------
; disable interrupt before PCnet reset
;----------------------------------------
;
	mov	ax,0			; AX = 0
IFDEF	PH_GGA1
	OUTPORTCI	CSR0		; disable interrupt
ELSE
	OUTPORT	CSR0			; disable interrupt
ENDIF

	call	device_reset		; reset pcnet device by reset register
	jnc	short reset_ok		; if carry flag clear, reset ok

	mov	dx,offset bad_reset_msg	; DX = addr of bad reset message
	mov	ax,RESET_BAD		; AX = reset PCnet error number
	call	display_error_message	; display error message
error_exit:
	stc				; return set carry flag indicate error
	ret				; return to caller
reset_ok:
					; move forward 10.5 (end 07-12-93)
	mov	b_1st_reset,not DEF_1ST_RESET; 
;
;----------------------------------------
; check local bus bus type(VL ISA or PCI) to skip DMA cascade
;----------------------------------------
;
	cmp	b_bustype,VLISA_BUSTYPE	; check bustype = VLISA BUS
	je	short dma_done		; jump, if bustype = VLISA BUS
	cmp	b_bustype,PCI_BUSTYPE	; check bustype = PCI BUS
	je	short dma_done		; jump, if bustype = PCI BUS
;
;----------------------------------------
; cascade DMA channel for PCnet gaining bus control
;----------------------------------------
;
	mov	al,dma_no		; AL = dma number
	cmp	al,4			; check dma width = 8 bit(dma # <= 4)
	ja	short dma_16		; jump, if dma > 4(dma width = 16 bit)
dma_8:					; 8 bit dma
	or	al,CASCADE_MODE		; AL = set cascade mode bit
	out	DMA_8MODE_REG,al	; write to 8 bit dma mode reg.
	and	al,DMA_CHL_FIELD	; AL = set proper dma channel bit
	out	DMA_8MASK_REG,al	; write to 8 bit dma mask reg.
	;
	cmp	b_dmarotate,DEF_DMAROTATE; check user set dma rotate priority
	je	short dma_done		; jump, if user not specified
	mov	al,DMA_ROTATE_PRI	; AL = dma rotate priority setting
	out	DMA_8CMD_REG,al		; write to 8 bit dma command reg.
	jmp	short dma_done		; jump, skip 16 bit settings
dma_16:					; 16 bit dma
	and	al,DMA_CHL_FIELD	; AL = set proper dma channel bit
	out	DMA_16MASK_REG,al	; write to 16 bit dma mask reg
	or	al,CASCADE_MODE		; AL = set cascade mode bit
	out	DMA_16MODE_REG,al	; write to 16 bit dma mode reg.
	;
	cmp	b_dmarotate,DEF_DMAROTATE; check user set dma rotate priority
	je	short dma_done		; jump, if user not specified
	mov	al,DMA_ROTATE_PRI	; AL = dma rotate priority setting
	out	DMA_16CMD_REG,al	; write to 16 bit dma command reg.
dma_done:				; Get board's interrupt vector

	mov	al, int_no		; AL = interrupt #
	add	al, 8			; AL = 1st IRQ byte map to master
					; 8259 DOS int #
					; check 1st IRQ byte with master
	cmp	al, 8+8			; 8259 DOS int # 
	jb	short set_int_num	; jump, if less, master 8259 IRQ
	add	al, 70h - 8 - 8		; slave 8259 IRQ map to DOS int #.
set_int_num:
	xor	ah, ah			; AH = Clear high byte
	mov	int_num, ax		; Set parameter_list int num = AX

	mov	al,int_no		; AL = interrupt #
	call	maskint			; disable ints throgh mask reg.
					;
					; original hardware reset code #####
					;
;
;----------------------------------------
; set up transmit descriptor ring.
;----------------------------------------
;
	push	ds			; save DS
	pop	es			; ES = DS
	mov	cx,XMIT_BUF_COUNT	; CX = xmit buffer count
	mov	bx,offset xmit_dscps	; BX = start addr of xmit dscps ring
	mov	di,offset transmit_bufs	; DI = start addr of xmit buffer
setup_transmit:
	xor	dx,dx			; clear dx
	mov	ax,XMIT_BUF_SIZE	; AX = xmit buffer size
	call	segmoffs_to_phys	; transfer ES:DI -> DL[3:0]:AX
	jnc	short setup_transmit_buff; VDS pass
	jmp	init_fail		; VDS failed and exit init
setup_transmit_buff:
	or	dx,XMIT_START or XMIT_END; DX[9:8] = set STP & ENP bits 
	mov	[bx].tmd0,ax		; xmit dscps tmd0[15:0] = AX
	mov	[bx].tmd1,dx		; xmit dscps tmd1[15:0] = DX

	cmp	cx,XMIT_BUF_COUNT	; check xmit buffer start case
	jne	short not_transmit_buf_start; jump, if not xmit buf start
	mov	xmit_buf_addr,ax	; xmit physical address low word = AX
	and	dx,0FFh			; mask off high byte
	mov	xmit_buf_addr+2,dx	; xmit physical address high word = DX
not_transmit_buf_start:

	add	bx,(size XMIT_MSG_DSCP)	; BX = next xmit dscps start addr
	add	di,XMIT_BUF_SIZE	; DI = next xmit buffer start addr
	loop	setup_transmit		; loop, until CX exhausted
;
;----------------------------------------
; set up receive descriptor ring.
;----------------------------------------
;
	mov	cx,RCV_BUF_COUNT	; CX = recv buffer count
	mov	bx,offset rcv_dscps	; BX = start addr of recv dscps ring
	mov	di,offset receive_bufs	; DI = start addr of recv buffer
setup_receive:				;
	xor	dx,dx			; clear dx
	mov	ax,RCV_BUF_SIZE		; AX = recv buffer size
	call	segmoffs_to_phys	; transfer ES:DI -> DL[3:0]:AX
	jnc	short setup_receive_buff; VDS pass
	jmp	init_fail		; VDS failed and exit init
setup_receive_buff:	 		;
	or	dx,RCV_OWN		; DX[15] = set OWN bit
	mov	[bx].rmd0,ax		; recv dscps rmd0[15:0] = AX
	mov	[bx].rmd1,dx		; recv dscps rmd1[15:0] = DX

	mov	[bx].rmd2,-RCV_BUF_SIZE	; recv dscps rmd2[15:0]=-(recv buf size) 
					; (BCNT=2's comp of recv buf size)
	mov	[bx].rmd3,0		; recv dscps rmd3[15:0]=0
					; (MCNT=0)

	cmp	cx,RCV_BUF_COUNT	; check rcv buffer start case
	jne	short not_receive_buf_start; jump, if not rcv buf start
	mov	rcv_buf_addr,ax		; rcv physical address low word = AX
	and	dx,0FFh			; mask off high byte
	mov	rcv_buf_addr+2,dx	; rcv physical address high word = DX
not_receive_buf_start:

	add	bx,(size RCV_MSG_DSCP)	; BX = next recv dscps start addr
	add	di,RCV_BUF_SIZE		; DI = next recv buffer start addr
	loop	setup_receive		; loop, until CX exhausted
;
;----------------------------------------
; initialize the board.
;----------------------------------------
;					; get our address.
	mov	cx,EADDR_LEN		; CX = ethernet addr length
	mov	di,offset init_addr	; DI = addr of init addr
	call	get_address		; set ES:DI->ET addr, CX = ET length

	mov	cx,RCV_BUF_COUNT	; CX = recv buffer count
	call	compute_log2		; CX[15:13] = RLEN(encoded)

	xor	dx,dx			; clear DX
	mov	ax,RCV_BUF_COUNT*(size RCV_MSG_DSCP); AX = recv desc ring size
	mov	di,offset rcv_dscps	; DI = start addr of recv dscps ring
	call	segmoffs_to_phys	; transfer ES:DI -> DL[3:0]:AX
	jnc	short setup_receive_rings; VDS pass
	jmp	init_fail		; VDS failed and exit init
setup_receive_rings:	 		;
	or	dx,cx			; DX[15:13] = RLEN
	mov	init_receive[0],ax	; setup init block RDRA[15:0]
	mov	init_receive[2],dx	; setup init block RDRA[RLEN,23:16]

	mov	cx,XMIT_BUF_COUNT	; CX = xmit buffer count
	call	compute_log2		; CX[15:13] = TLEN(encoded)

	xor	dx,dx			; clear DX
	mov	ax,XMIT_BUF_COUNT*(size XMIT_MSG_DSCP); AX = xmit descriptor size
	mov	di,offset xmit_dscps	; DI = start addr of xmit dscps ring
	call	segmoffs_to_phys	; transfer ES:DI -> DL[3:0]:AX
	jnc	short setup_transmit_rings; VDS pass
	jmp	init_fail		; VDS failed and exit init
setup_transmit_rings:
	or	dx,cx			; DX[15:13] = TLEN
	mov	init_transmit[0],ax	; setup init block TDRA[15:0]
	mov	init_transmit[2],dx	; setup init block TDRA[TLEN,23:16]
					; init block addr for the board
	xor	dx,dx			; clear dx
	mov	ax,INIT_BLOCK_SIZE	; AX = init block size
	mov	di,offset init_block	; DI = addr of init block
	call	segmoffs_to_phys	; transfer ES:DI -> DL[3:0]:AX
	jnc	short setup_init_block	; VDS pass
	jmp	short init_fail		; VDS failed and exit init
setup_init_block:
	mov	word ptr init_blk_high,dx;save init block addr high word
	mov	word ptr init_blk_low,ax; save init block addr low word

	push	dx			; save DX = init block addr high word
	push	ax			; save AX = init block addr low word
					; 
	mov	ax,0			; AX = 0
IFDEF	PH_GGA1
	OUTPORT	CSR3			; write the bus config register.
					; assume master mode not start yet
ELSE
	OUTPORT	CSR3			; write the bus config register.
ENDIF

	pop	ax			; restore AX =init block addr low word
	OUTPORT	CSR1			; write CSR1 = init block low word.

	pop	ax			; restore DX=init block addr high word
	OUTPORT	CSR2			; write CSR2 = init block high word.
	;
	mov	dx,io_addr		; DX = PCnet base address
	add	dx,ADDR_REG		; DX = PCnet address register
	mov	ax,BCR2			; AX = index to register address
	out	dx,ax			; set register index
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = PCnet Bus Data register
	in	ax,dx			; AX = register contents of BCR2
	or	ax,BCR2_ASEL		; set auto selection bit
	out	dx,ax			; write to BCR2
	;					;
	call	program_led		; program LED's default/user specified
	;				;
	call	program_fdup		; program full duplex options
	;				; (must after fdup to check conflicts)
	call	program_tp		; program twisted pair,if necessary
	;				;
	call	program_dmatimer	; program DMA timer
	;				;
	call	initialize		; write stop bit then init board
	jnc	short init_ok		; jump, if init ok.

	mov	dx,offset bad_init_msg	; DX = addr of bad init message
	mov	ax,INIT_BAD		; AX = init. PCnet error number
	call	display_error_message	; display error message
init_fail:
	stc				; return set carry flag indicate error
	ret				; return to caller

init_ok:
;
;----------------------------------------
; Now hook in our interrupt
;----------------------------------------
;
	call	set_recv_isr		; store old/set new recv isr
					; unmask correspond IRQ to enable int
	mov	dx,offset end_resident	; DX = addr of end resident
	clc				; return clear carry flag indicate ok
	ret				; return to caller

;
;----------------------------------------
; echo our command-line parameters
;----------------------------------------
;
print_parameters:
	mov	dx,offset int_no_msg	; DX = int no name(char string)
	mov	ah,9			; AH = display string
	int	21h			; display string DS:DX
;
;----------------------------------------
; enter with dx -> name of word, di -> dword to print.
;----------------------------------------
;
	mov	di,offset int_no	; DI = addr of int no(binary number)
	call	print_number		; print char str & binary #(hex,dec)
	mov	dx,offset io_addr_msg	; DX = io addr name
	mov	ah,9			; AH = display string
	int	21h			; display string DS:DX

	mov	di,offset io_addr	; DI = addr of io addr
	call	print_number		; print char str & binary #(hex,dec)
;
;----------------------------------------
; check local bus bus type(VL ISA or PCI) to skip DMA message printing
;----------------------------------------
;
	cmp	b_bustype,VLISA_BUSTYPE	; check bustype = VLISA BUS
	je	short print_parameters_done; jump, if bustype = VLISA BUS
	cmp	b_bustype,PCI_BUSTYPE	; check bustype = PCI BUS
	je	short print_parameters_done; jump, if bustype = PCI BUS
	;
	mov	dx,offset dma_no_msg	; DX = dma no name
	mov	ah,9			; AH = display string
	int	21h			; display string DS:DX

	mov	di,offset dma_no	; DI = addr of dma no
	call	print_number		; print char str & binary #(hex,dec)
print_parameters_done:
	ret				; return to caller

;
;----------------------------------------
; enter with
;   cx = number of buffers.
; exit with
;   cx = log2(number of buffers) << 13.
;----------------------------------------
;
compute_log2:				; 
	mov	ax,-1			; AX = 0xFFFF
compute_log2_1:				;
	inc	ax			; increment AX
	shr	cx,1			; CX = CX/2
	jne	short compute_log2_1	; loop, if CX != 0
	shl	ax,13			; AX = AX * 2 ** 13
compute_log2_2:				;
	mov	cx,ax			; CX = AX
	ret				; return to caller

;
;----------------------------------------
; enter with
;   es:di -> buffer.
;   dx:ax -> total buffer size(dx is always zero now)
; return with
;   dx:ax as the physical address of the buffer
;   carry flag clear indicate VDS success(if applicable)
;   carry flag set indicate VDS failure(if applicable)
;----------------------------------------
;
segmoffs_to_phys:
	push	es			; save registers
	push	di			;
	;
	push	ds			; save segment register
	push	dx			; save upper word of buffer size
	mov	dx,BIOS_DATA_SEG	; DX = BIOS_DATA_SEG
	mov	ds,dx			; DS = BIOS_DATA_SEG
	test	byte ptr ds:VDS_BYTE_OFF,VDS_ENABLE; check VDS enable bit
	pop	dx			; restore upper word of buffer size
	pop	ds			; restore segment register
	jz	short vds_done		; jump, if VDS disable
	;
	push	bx			; save register
	mov	bx,offset dma_desc	; BX = addr of dma_desc
	mov	word ptr [bx].region_size,ax; region size low word
	mov	word ptr [bx].dma_offset,di; vds dma offset
	mov	word ptr [bx].dma_segment,es; vds dma segment
	push	ds			; save DS on stack
	pop	es			; ES = DS (restore from stack)
	mov	di,bx			; DI = addr of dma_desc
	mov	ax,LOCK_DMA_REGION	; AX = lock DMA region
	mov	dx,LOCK_CONTIGUOUS	; DX = lock contiguous region
	int	4bh			; VDS interrupt service routine
	;
	les	di,[bx].dma_phys_addr	; set ES:DI from dma_phys_addr
	pop	bx			; restore register
	mov	dx,es			; DX = ES
	mov	ax,di			; AX = DI
	jnc	short segmoffs_to_phys_exit; VDS complete
	;
	mov	dx,offset vds_error_msg	; DX = addr of bad init message
	mov	ax,VDS_BAD		; AX = virtual DMA fail error number
	call	display_error_message	; display error message
	;
	stc				; set carry flag indicate error
	jmp	short segmoffs_to_phys_exit;
vds_done:
					; get the high 4 bits of the segment,
	mov	dx,es			; DX = ES seg
	shr	dx,(16-4)		; DX[3:0] = ES[15:12]
					; and the low 12 bits of the segment.
	mov	ax,es			; AX = ES seg
	shl	ax,4			; AX[15:4] = ES[11:0]
	add	ax,di			; AX = AX + DI
	adc	dx,0			; DX = DX + CARRY FLAG
	;
	clc				; clear flag indicate o.k.
segmoffs_to_phys_exit:
	pop	di			; restore registers
	pop	es			;
	ret				; return to caller

;
;----------------------------------------
; find the string/keyword length
; enter with
;   ds:si --> argument string
; return with
;   cx = string/keyword length
;   al modified
;----------------------------------------
;
find_strlen:
	push	si			; save registers
	xor	cx,cx			; clear CX
find_strlen_loop:
	lodsb				; AL = DS:[SI]
	cmp	al,'='			; check AL = '='
	je	short find_strlen_done	; jump, if AL = '='
	cmp	al,' '			; check AL = ' '(blank)
	je	short find_strlen_done	; jump, if AL = ' '(blank)
	cmp	al,HT			; check AL = HT
	je	short find_strlen_done	; jump, if AL = HT
	cmp	al,CR			; check AL = CR
	je	short find_strlen_done	; jump, if AL = NULL
	cmp	al,0			; check AL = NULL
	je	short find_strlen_done	; jump, if AL = NULL
	inc	cx			; increment input string length
	jmp	short find_strlen_loop	; loop backup, search next char
find_strlen_done:
	pop	si			; restore registers
	ret

;
;----------------------------------------
; compare the input strings with keyword
; enter with
;   ds:si --> input string
;   ds:di --> keyword string
;   cx = input string length
; return with
;   ds:si --> input string next word
;   zero flag clear if successed
;   zero flag set if failed
;----------------------------------------
;
compare_str:
	push	es			; save registers
	push	si			;
	push	cx			;
	;
	push	ds			; save DS on stack
	pop	es			; ES = DS
	;
	repe	cmpsb			; compare two strings
	jne	short compare_str_mismatch; jump, if not equal
	;
;	inc	si			; advance si to skip '=',' ',HT,'0'
	xor	cx,cx			; set zero flag
	pop	cx			; balance stack CX = input string len
	pop	es			; balance stack
	jmp	short compare_str_done	; 
compare_str_mismatch:
	pop	cx			; restore CX = input string length
	pop	si			; restore SI = input string beginning
	add	si,cx			; si = next char addr in argument str
;	inc	si			; advance si to skip '=',' ',HT,'0'
	or	sp,sp			; set nonzero flag
compare_str_done:
	pop	es			; restore register
	ret

;
;----------------------------------------
; captial the input string
; enter with
;   ds:si --> argument string
;   cx = input string length
;----------------------------------------
;
captialize_str:
	push	si			; save registers
	push	cx			;
	push	ax			;

captialize_char:			;
	mov	al,byte ptr [si]	; AL = character
	cmp	al,'a'			; check if lower case
	jb	short captialize_nlow_char; jump, if AL < 'a'
	cmp	al,'z'			; check if lower case
	ja	short captialize_nlow_char; jump, if AL > 'z'
	sub	al,'a'			; AL = offset relative to 'a'
	add	al,'A'			; AL = upper case character
	mov	byte ptr [si],al	; convert lower case to upper case
captialize_nlow_char:			;
	inc	si			; SI = point to next character
	loop	captialize_char		; loop for next char

	pop	ax			; restore registers
	pop	cx			;
	pop	si			; 
	ret
;
;----------------------------------------
; convert the input string to internal format
; and store in the internal store area
; enter with si->string of characters,
; 	     di -> dword to store the number in.
;	     [di] is not modified if no digits are given, it uses the default.
;return cy, input si, if there are match bustype at all.
;return nc, and store bustype internal format at [di].
;----------------------------------------
;
get_bustype_string:
	push	ax			; save registers
	push	cx			; save registers
	push	si			; save string location
	;
	call	skip_blanks		; skip blank, ASCII 9 & '='
	cmp	al,CR			; check end of line(CR) found
	je	short get_bustype_string_error; exit, if end of line
	call	find_strlen		; CX = string length
	or	cx,cx			; check string length
	je	short get_bustype_string_error; exit, if no string at all
	call	captialize_str		; convert input string to upper case
	;
	push	di			; save input parameter internal store
	push	cx			; save CX = input string length
	push	si			; save SI = input string starting addr
	mov	cx,BUSTYPE_COUNT	; CX = total bustype number count
parse_bustype:
	pop	si			; SI = input string starting address
	pop	ax			; AX = input string length
	push	ax			; save CX = input string length
	push	si			; save SI = input string starting addr
	push	cx			; save CX = bustype number count
	neg	cx			; CX = bustype number count(2's compl.)
	add	cx,BUSTYPE_COUNT	; CX = reverse index
	mov	di,offset bustype_addr_table; DS:DI = bustype string addr tbl 
	shl	cx,1			; adjust to word size
	add	di,cx			; point to proper index
	mov	di,word ptr [di]	; DI = bustype string storage 
	mov	cx,ax			; CX = input string length
	call	compare_str		; compare string
	pop	cx			; restore CX = bustype number count
	loopne	parse_bustype		; loop till count exhaust
	pop	ax			; balance stack
	pop	ax			; AX = input string length
	pop	di			; DI = input parameter internal store
	je	short get_bustype_found	;
	jcxz	short get_bustype_string_error; jump, not a bus type
	;
get_bustype_found:
	push	ax			; AX = input string length
	inc	cx			; CX = bustype count before loop inst.
	neg	cx			; CX = bustype count(2's completement)
	add	cx,BUSTYPE_COUNT	; CX = reverse index
	push	di			; save input parameter internal store
	mov	di,offset bustype_para_table; DS:DI = bustype string addr tbl 
	add	di,cx			; point to proper index
	mov	al, byte ptr [di]	; get AL = bustype internal represent
	pop	di			; DI = input parameter internal store
	mov	byte ptr [di],al	; put AL = bustype into internal store
	pop	ax			; AX = input string length
	pop	si			; SI = input string starting address
	add	si,ax			; point to end of current keyword
	;
	cmp	cx,PCI_MECH_COUNT	; check PCI1 & PCI2 case
	jb	short get_bustype_string_exit; if not, exit
	mov	b_pci_method,PCI_METHOD_1; assume PCI mechanism 1
	cmp	cx,PCI_MECH_COUNT	; check PCI1 or PCI2
	je	short get_bustype_string_exit; if PCI1, exit
	mov	b_pci_method,PCI_METHOD_2; PCI mechanism 2
	;
	jmp	short get_bustype_string_exit	; exit
get_bustype_string_error:
	pop	si			; restore input string location
get_bustype_string_exit:
	pop	cx			; restore registers
	pop	ax
	ret

;
;----------------------------------------
; convert the input string to internal format
; and store in the internal store area
; enter with si->string of characters,
; 	     di -> dword to store the number in.
;	     [di] is not modified if no digits are given, it uses the default.
;return cy, input si, if there are no match full duplex at all.
;return nc, and store full duplex internal format at [di].
;----------------------------------------
;
get_fullduplex_string:
	push	ax			; save registers
	push	cx			; save registers
	push	si			; save string location
	;
	call	skip_blanks		; skip blank, ASCII 9 & '='
	cmp	al,CR			; check end of line(CR) found
	je	short get_fullduplex_string_error; exit, if end of line
	call	find_strlen		; CX = string length
	or	cx,cx			; check string length
	je	short get_fullduplex_string_error; exit, if no string at all
	call	captialize_str		; convert input string to upper case
	;
	push	di			; save input parameter internal store
	push	cx			; save CX = input string length
	push	si			; save SI = input string starting addr
	mov	cx,FULLDUPLEX_COUNT	; CX = total full duplex number count
parse_fullduplex:
	pop	si			; SI = input string starting address
	pop	ax			; AX = input string length
	push	ax			; save CX = input string length
	push	si			; save SI = input string starting addr
	push	cx			; save CX = full duplex number count
	neg	cx			; CX = full duplex number count(2's)
	add	cx,FULLDUPLEX_COUNT	; CX = reverse index
	mov	di,offset fullduplex_addr_table; DS:DI = fdup string addr tbl 
	shl	cx,1			; adjust to word size
	add	di,cx			; point to proper index
	mov	di,word ptr [di]	; DI = bustype string storage 
	mov	cx,ax			; CX = input string length
	call	compare_str		; compare string
	pop	cx			; restore CX = bustype number count
	loopne	parse_fullduplex	; loop till count exhaust
	pop	ax			; balance stack
	pop	ax			; AX = input string length
	pop	di			; DI = input parameter internal store
	je	short get_fullduplex_found;
	jcxz	short get_fullduplex_string_error; jump, not a fullduplex type
	;
get_fullduplex_found:
	push	ax			; AX = input string length
	inc	cx			; CX = fdup count before loop inst.
	neg	cx			; CX = fdup count(2's completement)
	add	cx,FULLDUPLEX_COUNT	; CX = reverse index
	push	di			; save input parameter internal store
	mov	di,offset fullduplex_para_table; DS:DI = fdup string addr tbl 
	add	di,cx			; point to proper index
	mov	al, byte ptr [di]	; get AL = fdup internal represent
	pop	di			; DI = input parameter internal store
	mov	byte ptr [di],al	; put AL = fdup into internal store
	pop	ax			; AX = input string length
	pop	si			; SI = input string starting address
	add	si,ax			; point to end of current keyword
	;
	jmp	short get_fullduplex_string_exit	; exit
get_fullduplex_string_error:
	pop	si			; restore input string location
get_fullduplex_string_exit:
	pop	cx			; restore registers
	pop	ax
	ret

code	ends

	end
