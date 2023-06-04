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
;
;
; Theory of operation
; 
; IF (I/O address specified)
;    IF (not match with "WW" || checksum || hardware identification)
;       Error_Out;
; ELSE
; {
;    IF (BUS type specified)
;       scan specified bus and get proper I/O address;
;    ELSE
;       scan PCI/PnP/VL/ISA bus and get proper I/O address;
;
;    IF (not match with "WW" || checksum || device identification)
;       Error_Out;
; }
;
; get parameters DMA, IRQ;
;
; IF (parameters conflict with user_provide_infomation if applicable)
;    Error_Out;
;
; initialize adapter/ device driver accordingly.(Done by original driver)
;
;-----------------------------------------------------------------------
;
; Assume the I/O address space use 16 bits only. Since the 80x86 can
; support up to 16 bits.
;
;-----------------------------------------------------------------------
;
; 01-27-94 DT	modify the scan_pci for PCI1 & PCI2 keyword case
; 02-17-94 DT	save bus/dev/func #, for pci bus hang patch
;			modify scan_pci_m1, sacn_pci_m2.
; 05-19-94 DT	use conditional compiler to rule out OEM_1 code
; 06-14-94 D.T.	1. add PCI BIOS API & check for PCI device enable
;			   add pci_bios_api
;			   modify scan_pci, scan_pci_m1, handle_pci_m1_cfg
;			   modify scan_pci_m2
; 07-28-94 D.T.	modify command reg access by using read/modify/write
;
; 08-04-94 D.T.	add pause function in display_error_message
; 08-31-94 D.T.	1. modify all conditional jump instructions to short format
;		   for 286 compatible
; 11-16-94 D.T.	1. modify handle_pci_m1_conf, scan_pci_m2, pci_bios_api
;		   for P1 glitch patch
;
;-----------------------------------------------------------------------
.386

code	segment	para public use16	;
	assume	cs:code, ds:code	;

;
;-----------------------------------------------------------------------
;
PACKET		equ	1		; set packet driver case

;
PH_GGA0		equ	1		; patch for Golden Gate Version A0
					; I/O address last bit stuck high

;OEM1_PRESENT	equ	1		; set OEM1 special code exit

;
;----------------------------------------
; EQUATES
;----------------------------------------
; PCI equates
;----------------------------------------
;
PCI_MAX_BNUM	equ	8		; maxi PCI bus #
PCI_M1MAX_DNUM	equ	32		; maxi. PCI M1 device #
PCI_M2MAX_DNUM	equ	16		; maxi. PCI M2 device #
PCI_MAX_FNUM	equ	8		; maxi. PCI function #

PCI_CAD_REG	equ	0CF8h		; PCI M1 config. addr register
PCI_CDA_REG	equ	0CFCh		; PCI M1 config. data register
PCI_CSE_REG	equ	0CF8h		; PCI M2 config. space enable register
PCI_CFW_REG	equ	0CFAh		; PCI M2 config. forward register

PCI_CBUS_BIT	equ	16		; PCI M1 config. bus # bit position
PCI_CDEV_BIT	equ	11		; PCI M1 config. device # bit position
PCI_CFUN_BIT	equ	 8		; PCI M1 config. function # bit position
PCI_DEVID_BIT	equ	16		; PCI device ID bits

PCI_M1_ENABLE	equ	80000000h	; PCI M1 enable bit

PCI_CSFUN_BIT	equ	1		; PCI M2 cfg. space fun # bit position

PCI_M2_ENABLE	equ	80h		; PCI M2 enable bit
PCI_CFG_ADDR	equ	0C000h		; PCI M2 config. space address
PCI_CFDEV_OFF	equ	100h		; PCI M2 cfg. space device offset

PCI_VENID_OFF	equ	00h		; vendor ID offset in cfg. space
PCI_DEVID_OFF	equ	02h		; device ID offset in cfg. space header
PCI_BAREG_OFF	equ	10h		; PCI base address register offset
PCI_CDREG_OFF	equ	04h		; PCI command register offset
PCI_STREG_OFF	equ	06h		; PCI status register offset
PCI_ITREG_OFF	equ	3Ch		; PCI interrupt register offset
PCI_CFG3C	equ	3Ch		; PCI config register 3Ch

PCI_CREG_DEF	equ	04h		; command def(enable bus msater)
PCI_SREG_DEF	equ	0FFFFh		; status default for PCnet

PCI_NULL_DEV	equ	0FFFFh		; no PCI device exist

PCI_IO_ENABLE	equ	01h		; PCI device IO space enable

GG_IO_BASE_MASK	equ	0FFFEh		; mask off bit 0(stuck high)
PCI_PCNET_MASK	equ	0FFF0h		; mask off last four bits
;
;----------------------------------------
; PnP equates
;----------------------------------------
;

PNP_START_ADDR	equ	0200h		; PnP I/O starting address
PNP_NXDEV_OFF	equ	020h		; PnP next device I/O address offset
PNP_IOADD_CNT	equ	(0400h-PNP_START_ADDR)/PNP_NXDEV_OFF; possible devices

PNPISA_BCR8	equ	8		; PnP ISA software config register
PNPISA_INTSEL_M	equ	0Fh		; PnP ISA interrupt select mask
PNPISA_INTSEL_B	equ	04h		; PnP ISA interrupt select bit position
PNPISA_DMASEL_M	equ	07h		; PnP ISA interrupt select mask

;
;----------------------------------------
; VL ISA equates
;----------------------------------------
;

VLI_START_ADDR	equ	0200h		; VL ISA I/O starting address
VLI_NXDEV_OFF	equ	020h		; VL ISA next device I/O address offt
VLI_IOADD_CNT	equ	(0400h-VLI_START_ADDR)/VLI_NXDEV_OFF; possible devices

VLISA_BCR21	equ	21		; VL ISA interrupt control register
VLISA_INTSEL_M	equ	03h		; VL ISA interrupt select mask

;
;----------------------------------------
; ISA equates
;----------------------------------------
;

ISA_START_ADDR	equ	0300h		; ISA I/O starting address
ISA_NXDEV_OFF	equ	020h		; ISA next device I/O address offset
ISA_IOADD_CNT	equ	(0380h-ISA_START_ADDR)/ISA_NXDEV_OFF; possible devices

DEF_ISA_DMA	equ	05h		; default ISA DMA channel
ISA_DMA_START	equ	03h		; ISA DMA start channel
ISA_DMA_END	equ	07h		; ISA DMA end channel
ISA_DMA_CASCADE	equ	04h		; ISA DMA cascade channel

DEF_ISA_IRQ	equ	03h		; default ISA IRQ number
ISA_IRQ_3	equ	03h		; ISA IRQ 3
ISA_IRQ_4	equ	04h		; ISA IRQ 4
ISA_IRQ_5	equ	05h		; ISA IRQ 5
ISA_IRQ_N6	equ	06h		; ISA IRQ 6 doesn't exist
ISA_IRQ_N7	equ	07h		; ISA IRQ 7 doesn't exist
ISA_IRQ_N8	equ	08h		; ISA IRQ 8 doesn't exist
ISA_IRQ_9	equ	09h		; ISA IRQ 9 
ISA_IRQ_10	equ	10h		; ISA IRQ 10 additional
ISA_IRQ_11	equ	11h		; ISA IRQ 11 additional
ISA_IRQ_12	equ	12h		; ISA IRQ 12 additional
ISA_IRQ_N13	equ	13h		; ISA IRQ 13 doesn't exist
ISA_IRQ_N14	equ	14h		; ISA IRQ 14 doesn't exist
ISA_IRQ_15	equ	15h		; ISA IRQ 15 additional

VL_IRQ_10	equ	10h		; VL IRQ 10
VL_IRQ_5	equ	05h		; VL IRQ 5
VL_IRQ_3	equ	03h		; VL IRQ 3
VL_IRQ_15	equ	15h		; VL IRQ 15

PCI_IRQ_START	equ	00h		; PCI IRQ start number
PCI_IRQ_END	equ	15h		; PCI IRQ end number

PNP_IRQ_3	equ	03h		; PNP IRQ 3
PNP_IRQ_4	equ	04h		; PNP IRQ 4
PNP_IRQ_5	equ	05h		; PNP IRQ 5
PNP_IRQ_N6	equ	06h		; PNP IRQ 6 doesn't exist
PNP_IRQ_N7	equ	07h		; PNP IRQ 7 doesn't exist
PNP_IRQ_N8	equ	08h		; PNP IRQ 8 doesn't exist
PNP_IRQ_9	equ	09h		; PNP IRQ 9
PNP_IRQ_10	equ	10h		; PNP IRQ 10
PNP_IRQ_11	equ	11h		; PNP IRQ 11
PNP_IRQ_12	equ	12h		; PNP IRQ 12
PNP_IRQ_N13	equ	13h		; PNP IRQ 13 doesn't exist
PNP_IRQ_N14	equ	14h		; PNP IRQ 14 doesn't exist
PNP_IRQ_15	equ	15h		; PNP IRQ 15


;
;----------------------------------------
; devices equates
;----------------------------------------
;
AMD_VENDOR_ID	equ	1022h		; AMD vendor ID
PCNET_PCI_ID	equ	2000h		; PCnet PCI device ID

PCNET_HWIRQ_OFF	equ	08h		; PCnet hardware IRQ offset
PCNET_HWID_OFF	equ	09h		; PCnet hardware ID offset
PCNET_SIGN_OFF	equ	0Eh		; PCnet first signature 'W' offset
PCNET_CKSM_OFF	equ	0Ch		; PCnet LSB checksum offset

DEF_BUSTYPE	equ	0FFh		; default BUS type
ISA_BUSTYPE	equ	00h		; ISA BUS type
PNP_BUSTYPE	equ	01h		; PNP BUS type
VLISA_BUSTYPE	equ	10h		; VL ISA BUS type
PCI_BUSTYPE	equ	11h		; PCI BUS type

DEF_CPU_TYPE	equ	0		; 286
CPU_TYPE_386	equ	1		; 386

DEF_OEM		equ	0		; no OEM manufacturer identified

IFDEF	OEM1_PRESENT
OEM_1		equ	1		; first OEM manufacturer
ENDIF

DEF_PCI_METHOD	equ	0		; default PCI method
PCI_METHOD_1	equ	1		; PCI mechanism 1
PCI_METHOD_2	equ	2		; PCI mechanism 2
;
;----------------------------------------
; OEM manufacturer equates
;----------------------------------------
;
IFDEF	OEM1_PRESENT

OEM1_DAT0	equ	08h		; OEM manufacturer data byte 0
OEM1_DAT1	equ	00h		; OEM manufacturer data byte 1
OEM1_DAT2	equ	09h		; OEM manufacturer data byte 2
OEM1_DATB	equ	04h		; OEM manufacturer data byte 0Bh

OEM1_IOADR_MASK	equ	03h		; OEM manufacturer I/O addr mask
OEM1_DMA_MASK	equ	0Ch		; OEM manufacturer DMA mask
OEM1_IRQ_MASK	equ	70h		; OEM manufacturer IRQ mask

OEM1_DAT0_OFT	equ	00h		; OEM manufacturer data 0 offset
OEM1_DAT1_OFT	equ	01h		; OEM manufacturer data 1 offset
OEM1_DAT2_OFT	equ	02h		; OEM manufacturer data 2 offset
OEM1_DATB_OFT	equ	0Bh		; OEM manufacturer data B offset
OEM1_DMAIRQ_OFT	equ	14h		; OEM manufacturer DMA/IRQ offset

OEM1_DMA_BITS	equ	02h		; OEM manufacturer DMA bits positions
OEM1_IRQ_BITS	equ	04h		; OEM manufacturer IRQ bits positions

ENDIF

OEM_2		equ	2		; second OEM manufacturer
OEM_2_VL_PORT	equ	8800h		; second OEM VL port address
OEM_2_S0ID_PORT	equ	0C80h		; second OEM slot 0 EISA ID port addr
OEM_2_EISA_VID	equ	110Eh		; second OEM EISA vendor ID
OEM_2_VL_PID	equ	0107h		; second OEM VL product ID
OEM_2_EN	equ	1		; second OEM manufacturer check enable

EISA_SIGN_LEN	equ	4		; EISA signature length
EISA_SIGN_OFST	equ	0FFD9H		; EISA signature offset in ROM BIOS
BIOS_SEGMENT	equ	0F000H		; ROM BIOS segment

;
;----------------------------------------
; misc equates
;----------------------------------------
;
CR		equ	0dh		;
LF		equ	0ah		;
NULL		equ	00h		; none defined value

;
;----------------------------------------
; PCNET init error message
;----------------------------------------
;
IFDEF	PACKET
NINIT_ERR_CNT	equ	9		; non-init error message count + 1
ELSE
NINIT_ERR_CNT	equ	9		; non-init error message count + 1
ENDIF

WARNING_MSG_END	equ	1+NINIT_ERR_CNT	; warning message only

ERR_PCI_NDMA	equ	0+NINIT_ERR_CNT	; DMA channel is not necessary PCI
ERR_VL_NDMA	equ	1+NINIT_ERR_CNT	; DMA channel is not necessary VL
ERR_PNP_MDMA	equ	2+NINIT_ERR_CNT	; PnP DMA channel mismatched

ERR_PCI_MIRQ	equ	3+NINIT_ERR_CNT	; PCI IRQ # mismatched
ERR_VL_MIRQ	equ	4+NINIT_ERR_CNT	; VL  IRQ # mismatched
ERR_PNP_MIRQ	equ	5+NINIT_ERR_CNT	; PnP IRQ # mismatched

ERR_NO_PCNET	equ	6+NINIT_ERR_CNT	; PCnet not found
ERR_PNT_IOADDR	equ	7+NINIT_ERR_CNT	; PCnet not found at IOADDRESS

ERR_N386_CPU	equ	8+NINIT_ERR_CNT	; not a 386 or higher CPU

ERR_NPCI_DEV	equ	9+NINIT_ERR_CNT	; PCI scan device not found
ERR_NPNP_DEV	equ	10+NINIT_ERR_CNT; PnP scan device not found
ERR_NVLI_DEV	equ	11+NINIT_ERR_CNT; VL  scan device not found
ERR_NISA_DEV	equ	12+NINIT_ERR_CNT; ISA scan device not found

ERR_DMA_RANGE	equ	13+NINIT_ERR_CNT; ISA DMA number out of range
ERR_IRQ_RANGE	equ	14+NINIT_ERR_CNT; ISA IRQ number out of range


;
;----------------------------------------
; BCR equates
;----------------------------------------
;
IFDEF	PACKET				; packet driver
DATA_REG	equ	10h		; CSR data register
ADDR_REG	equ	DATA_REG+2h	; CSR/BCR address register
BDAT_REG	equ	DATA_REG+6h	; BCR data register
ELSE					; artisoft driver
DATA_REG	equ	10h		; CSR data register
ADDR_REG	equ	DATA_REG+2h	; CSR/BCR address register
BDAT_REG	equ	DATA_REG+6h	; BCR data register
ENDIF					; 

;
;----------------------------------------
; DATA AREA
;----------------------------------------
;
IFDEF	PACKET				; packet driver
EXTRN	int_no:byte			; ptr to IRQ info bytes
EXTRN	io_addr:word			; ptr to I/O addr bytes
EXTRN	dma_no:byte 			; ptr to DMA info bytes
ELSE
EXTRN	PCNT_interrupt:byte		; ptr to IRQ info bytes
EXTRN	IO_base:word			; ptr to I/O addr bytes
EXTRN	PCNT_dma:byte 			; ptr to DMA info bytes
ENDIF

EXTRN	b_bustype:byte			; bus type(default 0ffh)
					; 00h ISA, 01h PnP, 10h VL, 11h PCI
EXTRN	b_cpuflag:byte			; processor type flag

IFDEF	OEM1_PRESENT
EXTRN	b_oem1:byte			; OEM1 manufacture(default 0h)
ENDIF

EXTRN	b_oem2:byte			; OEM2 manufacture(default 0h)
EXTRN	b_oem2_enable:byte		; OEM2 manufacture checking enable
EXTRN	b_pci_method:byte		; PCI mechanism
EXTRN	dw_pci_bdfnum:dword		; PCI bus/dev/func #
EXTRN	eisa_sign_str:byte		; EISA signature string

EXTRN	error_header:byte		; error message header
EXTRN	init_err0_msg:byte		; init error message 0 address
EXTRN	init_err1_msg:byte		; init error message 1 address
EXTRN	init_err2_msg:byte		; init error message 2 address
EXTRN	init_err3_msg:byte		; init error message 3 address
EXTRN	init_err4_msg:byte		; init error message 4 address
EXTRN	init_err5_msg:byte		; init error message 5 address
EXTRN	init_err6_msg:byte		; init error message 6 address
EXTRN	init_err7_msg:byte		; init error message 7 address
EXTRN	init_err8_msg:byte		; init error message 8 address
EXTRN	init_err9_msg:byte		; init error message 9 address
EXTRN	init_err10_msg:byte		; init error message 10 address
EXTRN	init_err11_msg:byte		; init error message 11 address
EXTRN	init_err12_msg:byte		; init error message 12 address
EXTRN	init_err13_msg:byte		; init error message 13 address
EXTRN	init_err14_msg:byte		; init error message 14 address
EXTRN	init_err15_msg:byte		; init error message 15 address
EXTRN	init_err16_msg:byte		; init error message 16 address
EXTRN	init_err17_msg:byte		; init error message 17 address
EXTRN	init_err18_msg:byte		; init error message 18 address
EXTRN	init_err19_msg:byte		; init error message 19 address

PUBLIC	devices_init			; PCnet device detect & init. code
PUBLIC	display_error_message		; PCnet error display routine

;
;-----------------------------------------------------------------------
;
;	devices_init
;
;
;	input	: DS = CS
;
;	output	: C  = 1, carry flag set indicate error
;		  C  = 0, carry flag clear indicate OK
;
;	modify	: io_base, interrupt_number, dma_channel(if applicable),
;		  b_cpuflag
;
;	assume	: 
;	1. call	driver_installed	; setup proper environment indicate
;					; driver installed successfully
;	is implemented at other place to match the check_previous_drivers
;	routine call.
;
;-----------------------------------------------------------------------
;
devices_init	proc	near		; device driver init. code
	push	ax			; save registers
	push	bx			;
	push	cx			;
;
;----------------------------------------
; check multiple drivers installed(for multiple devices only)
;----------------------------------------
;
	call	check_previous_drivers	; check previous installed drivers
;
;----------------------------------------
; check processor type 386 or above for PCI bus devices
;----------------------------------------
;
	call	check_processor		; check processor & set b_cpuflag byte
;
;----------------------------------------
; check OEM information( for VL devices now )
;----------------------------------------
;
	call	check_oem2		; check OEM 2 manufacture information
;
;----------------------------------------
; check user specified I/O address of device.
; ISA & VL ISA only, PCI & PnP can't specified I/O addr.
;----------------------------------------
;
IFDEF	PACKET
	cmp	io_addr,NULL		; check user specified I/O address
ELSE
	cmp	IO_base,NULL		; check user specified I/O address
ENDIF
	jne	short io_addr_input_tmp1; jump, user input I/O address
	jmp	no_io_addr_input	; jump, no user input I/O address
;	je	short no_io_addr_input	; jump, no user input I/O address
io_addr_input_tmp1:
;
;----------------------------------------
; check user specified device BUS type(if applicable).
;   ISA I/O addr range 300h - 37fh (offset 20h, ie 300h, 320h, 340h, 360h)
;   VL  I/O addr range 200h - 3ffh (offset 20h, ie 200h, 220h, 240h, ...,3d0h)
;
; if PCI, PnP or unknown bus indicate
;   user parameter(s) error.(ERR_NO_PCNET)
;----------------------------------------
;
IFDEF	PACKET
	mov	ax,io_addr		; set AX = BASE I/O address
ELSE
	mov	ax,IO_base		; set AX = BASE I/O address
ENDIF
	cmp	b_bustype,DEF_BUSTYPE	; check no user input BUS type
	je	short devices_init_bus	; jump, if no BUS type input
	;
	cmp	b_bustype,ISA_BUSTYPE	; check user input BUS type = ISA
	jne	short devices_init_vbus	; jump, if BUS type input != ISA
;	
;----------------------------------------
; check ISA I/O addr range 300h - 37fh (offset 20h, ie 300h, 320h, 340h, 360h)
;----------------------------------------
;
	mov	cx,ISA_IOADD_CNT	; CX = ISA I/O addr count
	mov	bx,(ISA_START_ADDR-ISA_NXDEV_OFF); BX = ISA I/O (start - offset) addr
devices_init_isaiochk:
	add	bx,ISA_NXDEV_OFF	; BX = ISA next device offset
	cmp	ax,bx			; check possible I/O address
	loopne	devices_init_isaiochk	; if not equal, loop til exhaust CX
	;
	je	short devices_init_bus	; jump, if I/O address within range
	jcxz	short devices_init_berr	; jump, if CX = 0, out of range
	;
devices_init_vbus:
	cmp	b_bustype,VLISA_BUSTYPE	; check user input BUS type = VL ISA
	jne	short devices_init_berr	; jump, if BUS type input != VL ISA
;	
;----------------------------------------
; check OEM 2 checking enable
;----------------------------------------
;
	cmp	b_oem2_enable,OEM_2_EN	; check OEM 2 VL device case
	jne	short devices_init_vlbus; jump, if OEM 2 check = disable
	;
IFDEF	PACKET
	cmp	io_addr,OEM_2_VL_PORT	; check user specified I/O address
ELSE
	cmp	IO_base,OEM_2_VL_PORT	; check user specified I/O address
ENDIF
	je	short devices_init_bus	; jump, user input I/O = OEM 2 addr
;	jmp	short devices_init_berr	; jump, if mismatch
	mov	b_oem2_enable,DEF_OEM	; disable OEM 2 VL enable byte
					; if mismatch, treat as normal case
devices_init_vlbus:
;	
;----------------------------------------
; check VL I/O addr range 200h - 3ffh (offset 20h, ie 200h, 220h,...,3d0h)
;----------------------------------------
;
	mov	cx,VLI_IOADD_CNT	; CX = VLI I/O addr count
	mov	bx,(VLI_START_ADDR-VLI_NXDEV_OFF); BX = VLI I/O (start - offset) addr
devices_init_vliochk:
	add	bx,VLI_NXDEV_OFF	; BX = VL ISA next device offset
	cmp	ax,bx			; check possible I/O address
	loopne	devices_init_vliochk	; if not equal, loop til exhaust CX
	;
	je	short devices_init_bus	; jump, if I/O address within range
	jcxz	short devices_init_berr	; jump, if CX = 0, out of range
	;
devices_init_berr:
	mov	ax,ERR_NO_PCNET		; error, input error(no PCnet found)
	jmp	short devices_init_error; exit
devices_init_bus:
;
;----------------------------------------
; 1. ISA/VL bus type with I/O address specified within range
; 2. undefined bus type with I/O address specified(range not check)
;----------------------------------------
; check "WW" signature
;	EEPROM checksum(0h-bh & 0eh-0fh)
; get	hardware ID
;----------------------------------------
;
	call	check_device_info	; check "WW", checksum, get HW ID
	jnc	short devices_init_found; jump, if no error
;
;----------------------------------------
; Error	1. PCnet ISA device not found at I/O address
;	2. PCnet VL device not found at I/O address
; 	3. unknown bus type(user input parameter(s) error)
;----------------------------------------
;
	mov	ax,ERR_PNT_IOADDR	; AX = PCnet ISA not found at IOADDR
	cmp	b_bustype,ISA_BUSTYPE	; check user input BUS type = ISA
	je	short devices_init_err	; jump, if BUS type input = ISA
	;
	mov	ax,ERR_PNT_IOADDR	; AX = PCnet VL not found at IOADDR
	cmp	b_bustype,VLISA_BUSTYPE	; check user input BUS type = VL ISA
	je	short devices_init_err	; jump, if BUS type input = VL ISA
	;
	mov	ax,ERR_NO_PCNET		; user input error(No PCnet found)
devices_init_err:
	jmp	short devices_init_error; jump, if error(error code return)
devices_init_found:
;
;----------------------------------------
; 1. ISA/VL bus type with I/O address specified
; 2. undefined bus type(ISA/VL/PCI/PnP) with I/O address specified
;----------------------------------------
; check the match between user specified 
;   device BUS type(if applicable) and BL
;----------------------------------------
;
	cmp	b_bustype,DEF_BUSTYPE	; check no user input BUS type
	jne	short devices_init_busin; jump, if BUS type specified
	;
	mov	b_bustype, bl		; set b_bustype = BL(ISA/VL/PCI/PnP)
	jmp	short devices_init_para	; jump, continue
devices_init_busin:
	cmp	b_bustype,BL		; check user input BUS type = BL
	je	short devices_init_para	; jump, if BUS type input = ISA/VL
	;
	mov	ax,ERR_NVLI_DEV		; error, input&eeprom bus value conflict
	cmp	b_bustype,VLISA_BUSTYPE	; check user input BUS type = VL ISA
	je	short devices_init_error; exit with error code
	;
	mov	ax,ERR_NISA_DEV		; error, input&eeprom bus value conflict
	jmp	short devices_init_error; exit with error code
no_io_addr_input: 
;
;----------------------------------------
; scan I/O addrees, look for PCnet devices
;----------------------------------------
; error,1. PCnet PCI on a system with 80286 and below processor
;	2. PCnet PCI/PnP/VL/ISA specified but not found
;	3. PCnet device not found
;	4. User input parameter(s) conflict with eeprom value
;----------------------------------------
;
	call	scan_devices		; scan PCnet devices(error code return)
	jc	short devices_init_error; jump, if no devices found
;
;----------------------------------------
; get then set DMA, IRQ info after I/O address determined
; & check conflicts between user specified with detected parameters
;----------------------------------------
; warn, 1. PCI/VL DMA channel not required
; error,1. PCnet PnP DMA channel mismatch
;	2. PCnet PCI/VL/PnP IRQ # mismatch
;	3. PCnet PCI/PnP/VL/ISA IRQ # out of range
;	4. PCnet PCI/PnP/VL/ISA DMA channel out of range
;	5. PCnet device not found or eeprom error
;	6. PCnet eeprom checksum error
;----------------------------------------
;
devices_init_para:
	call	get_parameters		; get&set IO/DMA/IRQ(error code return)
	jnc	short devices_init_done	; jump, if no conflict happened
devices_init_error:
	call	display_error_message	; display proper error message
	cmp	ax,WARNING_MSG_END	; check if warning message only
	jbe	short devices_init_done	; don't set carry flag if warning only
	stc				; set carry flag indicate error
	jmp	short devices_init_exit	; return to caller
devices_init_done:
	clc				; clear carry flag indicate o.k.
devices_init_exit:
	pop	cx			; restore registers
	pop	bx			;
	pop	ax			;
	ret				; return to caller
devices_init	endp			;

;
;-----------------------------------------------------------------------
;
;	check_previous_drivers
;
;	input	:
;
;	output	:
;
;	modify	:
;
;-----------------------------------------------------------------------
;
check_previous_drivers	proc	near	; get user input parameters
IFNDEF	PACKET				; if not packet driver

ENDIF					;
	ret				; return to caller
check_previous_drivers	endp		;

;
;-----------------------------------------------------------------------
;
;	check_processor
;
;	check	NT & IOPL bits of flag register within x86 processor
;		if 286 processor both bits can't change.
;		if 386 and above processor both bits can be altered.
;
;	input	: none
;
;	output	: none
;		 
;	modify	: b_cpuflag data byte
;
;-----------------------------------------------------------------------
;
check_processor	proc	near		; check system processor
	pushf				; save current flag status
	push	dx			; save DX
	;
	mov	dx,7000h		; set NT & IOPL bits
	push	dx			; save DX on stack
	popf				; set new flag status
	pushf				; save flag register on stack
	pop	dx			; DX = new flag status
	;
	mov	b_cpuflag,DEF_CPU_TYPE	; assume 286 & clear CPU flag
	test	dh,70h			; check NT & IOPL bits
	jz	short check_processor_exit; jump, if NT&IOPL bits clear(286 CPU)
	mov	b_cpuflag,CPU_TYPE_386	; otherwise, set 386 CPU flag
check_processor_exit:
	pop	dx			; restore DX
	popf				; restore previous flag status
	ret				; return to caller
check_processor	endp			;

;
;-----------------------------------------------------------------------
;
;	check_device_info
;
;	check 1."WW" signature at BASE+(0Eh - 0Fh)
;	      2.EEPROM checksum = sum of range BASE+(00h-0Bh & 0Eh-0Fh)
;	      & get hardware ID at BASE + 09h
;
;	input	: AX = I/O BASE address
;
;	output	: C  = 1, carry flag set indicate error
;		    AX = error code
;		  C  = 0, carry flag clear indicate OK
;		    BL = hardware ID.
;		 
;	modify	: AX(if error), BL(if no error)
;	assume	: 16 bit address only, BH restore for PCI interrupt line
;
;-----------------------------------------------------------------------
;
check_device_info	proc	near	; check device information
	push	dx			; save registers
	push	cx			;
;
;----------------------------------------
; check AMD PCnet-ISA device signature "WW"
;----------------------------------------
;
	push	ax			; AX = base I/O addr on stack
	mov	dx,ax			; DX = base I/O addr
	add	dx,PCNET_SIGN_OFF	; DX = first signature 'W' offset
	in	al,dx			; AL = contents of 1st signature
	cmp	al,'W'			; check first signature 'W'
	mov	ax,ERR_NO_PCNET		; assume no AMD dev. or checksum error
	jne	short check_device_info_error; jump, if not PCnet device
	inc	dx			; DX = second signature 'W' offset
	in	al,dx			; AL = contents of 2nd signature
	cmp	al,'W'			; check second signature 'W'
	mov	ax,ERR_NO_PCNET		; assume not AMD or checksum error
	jne	short check_device_info_error; jump, if not PCnet device
;
;----------------------------------------
; check AMD PCnet device checksum
;----------------------------------------
;
	pop	ax			; restore AX = base I/O addr
	push	ax			; save AX = base I/O addr on stack
	push	bx			; save BX
	mov	dx,ax			; DX = base I/O addr
	xor	bx,bx			; BX = 0 (accumulate checksum)
	xor	ax,ax			; AX = 0
	mov	cx,PCNET_CKSM_OFF	; CX = number of bytes to sum up
check_device_info_sum:
	in	al,dx			; AL = content of current offset byte
	add	bx,ax			; BX = accumulated checksum
	inc	dx			; DX = next offset addr
	loop	check_device_info_sum	; loop until counter exhaust
	;
	in	al,dx			; AL = content of checksum LSB byte
	mov	cl,al			; CL = checksum LSB byte
	inc	dx			; skip LSB of checksum byte
	in	al,dx			; AL = content of checksum MSB byte
	mov	ch,al			; CH = checksum MSB byte
	inc	dx			; skip MSB of checksum byte
	;
	in	al,dx			; AL = content of 1st signature byte
	add	bx,ax			; BX = accumulated checksum
	inc	dx			; DX = next offset addr
	in	al,dx			; AL = content of 2nd signature byte
	add	bx,ax			; BX = accumulated checksum
;
;----------------------------------------
; check OEM 2 check enable
;----------------------------------------
;
	cmp	b_oem2_enable,OEM_2_EN	; check OEM 2 VL device case
	jne	short check_device_info_noem2; jump, if OEM 2 check = disable
	sub	dx,(PCNET_SIGN_OFF+1)	; adjust DX = base I/O addr
	cmp	dx,OEM_2_VL_PORT	; check current base = OEM 2 I/O addr
	jne	short check_device_info_noem2; jump, if base != OEM 2 I/O addr
	add	dx,PCNET_HWIRQ_OFF	; adjust DX = hardware IRQ offset
	in	al,dx			; read AL = hardware IRQ #
	sub	bx,ax			; subtract HW IRQ # from checksum
check_device_info_noem2:
	;
	cmp	bx,cx			; check calculate = stored checksum
	pop	bx			; restore BX
	mov	ax,ERR_NO_PCNET		; assume checksum error, no PCnet dev
	jne	short check_device_info_error; jump, if checksum not valid
;
;----------------------------------------
; get AMD PCnet-ISA device hardware ID
;----------------------------------------
;
	pop	ax			; restore AX = base I/O addr
	push	ax			; save AX = base I/O addr on stack
	mov	dx,ax			; DX = base I/O addr
	add	dx,PCNET_HWID_OFF	; DX = hardware ID byte offset
	in	al,dx			; read AL = content of hardware ID
	mov	bl,al			; BL = content of hardware ID
	pop	ax			; restore AX = base I/O addr
	clc				; clear carry flag indicate o.k.
	jmp	short check_device_info_exit; exit
check_device_info_error:
	pop	cx			; restore CX = base I/O addr
	stc				; set carry flag indicate error
check_device_info_exit:
	pop	cx			; restore registers
	pop	dx			;
	ret				; return to caller
check_device_info	endp		;

;
;-----------------------------------------------------------------------
;
;	scan_devices
;
;	input	: none
;
;	output	: C  = 1, carry flag set indicate device not found
;		    AX = error code
;		  C  = 0, carry flag clear indicate device found
;		    AX = BASE I/O address of found device
;		    BL = Hardware ID
;
;	modify	: AX(if error), AX, BL(if no error)
;
;-----------------------------------------------------------------------
;
scan_devices	proc	near		; scan PCnet devices

;
;----------------------------------------
; check user specified PCI device type
;----------------------------------------
;
	cmp	b_bustype,PCI_BUSTYPE	; check user specified PCI bus type
	jne	short scan_devices_1	; jump, if not PCI bus type
	cmp	b_cpuflag,CPU_TYPE_386	; check CPU flag for 386
	jae	short scan_devices_0	; jump, if 386 and higher CPU
	mov	ax,ERR_N386_CPU		; error, not a 386 CPU
	jmp	scan_devices_error	; exit, with error code
scan_devices_0:
	call	scan_pci		; scan for PCI devices(no error code)
	jnc	short scan_devices_fpci	; jump, found PCI devices
	mov	ax,ERR_NPCI_DEV		; error, no PCI devices found
	jmp	scan_devices_error	; exit, with error code
scan_devices_fpci:
	cmp	bl,PCI_BUSTYPE		; check BL = PCI bus type
	jne	short scan_devices_tmp1	; jump, if user do not specify
	jmp	scan_devices_exit	; exit, if user specified PCI bus find
;	je	short scan_devices_exit	; exit, if user specified PCI bus find
scan_devices_tmp1:
	mov	ax,ERR_NPCI_DEV		; error, input&device eeprom bus conflict
	jmp	scan_devices_error	; exit, with error code
scan_devices_1:
;
;----------------------------------------
; check user specified PnP device type
;----------------------------------------
;
	cmp	b_bustype,PNP_BUSTYPE	; check user specified PnP type
	jne	short scan_devices_2	; jump, if not PnP type
	call	scan_pnp		; scan for PnP devices(no error code)
	jnc	short scan_devices_fpnp	; jump, found PnP devices
	mov	ax,ERR_NPNP_DEV		; error, no PnP devices found
	jmp	scan_devices_error	; exit, with error code
scan_devices_fpnp:
	cmp	bl,PNP_BUSTYPE		; check BL = PnP bus type
	jne	short scan_devices_tmp2	; jump, if user do not specify
	jmp	scan_devices_exit	; exit, if user specified PnP bus find
;	je	short scan_devices_exit	; exit, if user specified PnP bus find
scan_devices_tmp2:
	mov	ax,ERR_NPNP_DEV		; error, input&device eeprom bus conflict
	jmp	scan_devices_error	; exit, with error code
scan_devices_2:
;
;----------------------------------------
; check user specified VL device type
;----------------------------------------
;
	cmp	b_bustype,VLISA_BUSTYPE	; check user specified VL type
	jne	short scan_devices_3	; jump, if not VL type
	call	scan_vl_isa		; scan for VL devices(no error code)
	jnc	short scan_devices_fvl	; jump, found VL devices
	mov	ax,ERR_NVLI_DEV		; error, no VL ISA devices found
	jmp	short scan_devices_error; exit, with error code
scan_devices_fvl:
	cmp	bl,VLISA_BUSTYPE	; check BL = VL ISA bus type
	je	short scan_devices_exit	; exit, if user specified VL ISA bus find
	mov	ax,ERR_NVLI_DEV		; error, input&device eeprom bus conflict
	jmp	short scan_devices_error; exit, with error code
scan_devices_3:
;
;----------------------------------------
; check user specified ISA device type
;----------------------------------------
;
	cmp	b_bustype,ISA_BUSTYPE	; check user specified ISA type
	jne	short scan_devices_4	; jump, if not ISA type
	call	scan_vl_isa		; scan for ISA devices(no error code)
	jnc	short scan_devices_fisa	; jump, found ISA devices
	mov	ax,ERR_NISA_DEV		; error, no ISA devices found
	jmp	short scan_devices_error; exit, with error code
scan_devices_fisa:
	cmp	bl,ISA_BUSTYPE		; check BL = ISA bus type
	je	short scan_devices_exit	; exit, if user specified ISA bus find
	mov	ax,ERR_NISA_DEV		; error, input&device eeprom bus conflict
	jmp	short scan_devices_error; exit, with error code
scan_devices_4:
;
;----------------------------------------
; no specified device type
; scan PCI & (PnP, VL & ISA) in sequence to find PCnet device
;----------------------------------------
;    assume PCI bus and scan PCI bus 
;----------------------------------------
;
	cmp	b_cpuflag,DEF_CPU_TYPE	; check CPU flag for 286
	je	short scan_devices_5	; jump, if 286 and lower CPU
	mov	b_bustype,PCI_BUSTYPE	; setup BUS type byte = PCI
	call	scan_pci		; scan for PCI devices
	jc	short scan_devices_5	; no PCI devices
	cmp	b_bustype,bl		; check scan BUS type = BL
	je	short scan_devices_exit	; exit
	mov	ax,ERR_NO_PCNET		; error, input&device eeprom bus conflict
	jmp	short scan_devices_error; exit with error code
scan_devices_5:
;
;----------------------------------------
;    check OEM 2 VL checking enable 
;----------------------------------------
;    The OEM 2 VL devices specified I/O address are
;    hardcoded at this moment
;    otherwise, scan will find PnP, VL & ISA devices at one time
;----------------------------------------
;
	cmp	b_oem2_enable,OEM_2_EN	; check OEM 2 VL device case
	jne	short scan_devices_8	; jump, if OEM 2 check = disable
	;
	mov	b_bustype,VLISA_BUSTYPE	; setup BUS type byte = VL(OEM 2)
	call	scan_vl_isa		; scan for vl isa devices
	jnc	short scan_devices_found; OEM 2 VL ISA devices found
	mov	ax,ERR_NVLI_DEV		; error, no VL ISA devices found
	jmp	short scan_devices_error; exit, with error code
scan_devices_8:
;
;----------------------------------------
;    assume PnP bus and scan PnP bus 
;----------------------------------------
;    The PnP(200h-3ffh), VL(200h-3ffh) & ISA(300h-37fh) devices are
;    I/O space overlapped.
;    the scan can find PnP, VL & ISA devices at one time
;----------------------------------------
;
	mov	b_bustype,PNP_BUSTYPE	; setup BUS type byte = PnP
	call	scan_pnp		; scan for PnP devices
	jnc	short scan_devices_found; PnP, VL & ISA devices found
	mov	ax,ERR_NO_PCNET		; error, no PCnet devices found
	jmp	short scan_devices_error; exit with error code
scan_devices_found:
	cmp	b_bustype,bl		; check scan BUS type = BL
	je	short scan_devices_exit	; exit
	mov	b_bustype,bl		; set b_bustype = BL
	cmp	bl,VLISA_BUSTYPE	; check BL = VL ISA BUS type
	je	short scan_devices_exit	; exit
	cmp	bl,ISA_BUSTYPE		; check BL = ISA BUS type
	je	short scan_devices_exit	; exit
	mov	ax,ERR_NO_PCNET		; error, input&device eeprom bus conflict
	jmp	short scan_devices_error; exit with error code
;scan_devices_6:
;
;----------------------------------------
;    assume VL ISA bus and scan VL ISA bus 
;----------------------------------------
;
;	mov	b_bustype,VLISA_BUSTYPE	; setup BUS type byte = VL ISA
;	call	scan_vl_isa		; scan for VL & ISA devices
;	jc	short scan_devices_7	; error, no PCnet devices
;	cmp	b_bustype,bl		; check scan BUS type = BL
;	je	short scan_devices_exit	; exit
;	mov	b_bustype,bl		; set b_bustype = BL
;	cmp	bl,ISA_BUSTYPE		; check BL = ISA BUS type
;	je	short scan_devices_exit	; exit
;	mov				; setup error code
;	jmp	short scan_devices_error; exit with error code
;scan_devices_7:
;
;----------------------------------------
;    assume ISA bus and scan ISA bus 
;----------------------------------------
;
;	mov	b_bustype,ISA_BUSTYPE	; setup BUS type byte = ISA
;	call	scan_vl_isa		; scan for VL & ISA devices
;	jc	short scan_devices_error; error, no PCnet devices
;	cmp	b_bustype,bl		; check scan BUS type = BL
;	je	short scan_devices_exit	; exit
;	mov				; setup error code
scan_devices_error:
	stc				; set carry flag indicate error
	ret				; return to caller
scan_devices_exit:
	clc				; clear carry flag indicate o.k.
	ret				; return to caller
scan_devices	endp			;

;
;-----------------------------------------------------------------------
;
;	scan_pci
;
;	input	: none
;
;	output	: C  = 1, carry flag set indicate PCI device not found
;		  C  = 0, carry flag clear indicate PCI device found
;		    AX = BASE I/O address of found PCI device
;		    BL = Hardware ID
;		    BH = Interrupt line
;
;	modify	: AX,BX(if no error)
;
;-----------------------------------------------------------------------
;
scan_pci	proc	near		; scan the pci bus
	push	dx			; save DX
	push	cx			; save CX
	;
;
;----------------------------------------
; check PCI BIOS API
;----------------------------------------
;
	push	ax			; save AX
	push	bx			; save BX
	call	pci_bios_api		; check PCI BIOS API & find AMD device
	pop	cx			; CX = orignal BX
	pop	dx			; DX = orignal AX
	jc	short scan_pci_tmp1	; AMD PCI device found, exit
	jmp	scan_pci_exit		; AMD PCI device found, exit
;	jnc	short scan_pci_exit	; AMD PCI device found, exit
scan_pci_tmp1:
	;
	or	al,al			; check device not found(BIOS exist)
	mov	ax,dx			; restore orignal AX
	mov	bx,cx			; restore orignal BX
	jz	short scan_pci_exit	; carry flag set, indicate not found
;
;----------------------------------------
; check user specified PCI mechanism
;----------------------------------------
;
	cmp	b_pci_method,PCI_METHOD_1; check user specified PCI mechanism1
	je	short scan_pci_mechanism1;

	cmp	b_pci_method,PCI_METHOD_2; check user specified PCI mechanism2
	je	short scan_pci_mechanism2;
scan_pci_normal:
;
;----------------------------------------
; determine PCI mechanism 1 or 2
;   
;   using mechanism 2 then mechanism 1
;   check ( bus=0, device=0 & function=0's vendor ID != 0FFFFh)
;
;   bus=device=function=0 ie. PCI bridge
;----------------------------------------
;
scan_pci_checkm2:
;----------------------------------------
; scan PCI interface use mechanism 2
;
; WARNING:
;	mechanism 2: PCI_CSE & PCI_CFW registers
;	are byte registers. Don't use word access.
;	PCI 0CF9H is a reset register.
;----------------------------------------
;
	mov	dx,PCI_CFW_REG		; DX = PCI config. forward reg(0CFAh)
	in	al,dx			; read AL = orignal contents of 0CFAH
	mov	ch,al			; CH = orignal content of 0CFAh
	xor	ax,ax			; set AX = bus 0
	out	dx,al			; write PCI bus # to forward reg
	;
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	in	al,dx			; read AL = orignal contents of 0CF8H
	mov	cl,al			; CL = orignal content of 0CF8h
	mov	ax,PCI_M2_ENABLE	; AX = PCI cfg. enbale & fun 0 bit pattern
	out	dx,al			; write PCI function # to cfg space reg
	;
	mov	dx,PCI_CFG_ADDR		; set DX = PCI M2 cfg space begin addr
	in	ax,dx			; read AX = vendor ID word
	cmp	ax,PCI_NULL_DEV		; check PCI device exist
	jne	short scan_pci_mechanism2; jump, if PCI bridge exist
	;
	mov	al,ch			; CH = orignal content of 0CFAh
	mov	dx,PCI_CFW_REG		; DX = PCI cfg. forward reg.
	out	dx,al			; write PCI bus # to forward reg
	;
	mov	al,cl			; CL = orignal content of 0CF8h
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	out	dx,al			; write PCI bus # to forward reg
	;
	cmp	b_pci_method,DEF_PCI_METHOD; check user specified PCI mechanism
	je	short scan_pci_checkm1	;
	;
	stc				; set carry flag indicate no PCI device
	jmp	short scan_pci_exit	; exit
scan_pci_checkm1:
;
;----------------------------------------
; scan PCI interface use mechanism 1
;----------------------------------------
;
	push	eax			; save extended AX
	push	ebx			; save EBX
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	in	eax,dx			; EAX= orignal content of 0CF8h
	mov	ebx,eax			; EBX= orignal content of 0CF8h
	xor	eax,eax			; set EAX = (bus/dev/fun = 0)
	or	eax,PCI_M1_ENABLE	; set config space enable bit
	out	dx,eax			; write pattern to PCI config addr reg
	;
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; read vendor & device ID
	;
	cmp	ax,PCI_NULL_DEV		; check PCI device exist
	jne	short scan_pci_mech1	; jump, if PCI bridge exist
	;
	mov	eax,ebx			; set EAX = orignal content of 0CF8h 
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	pop	ebx			; restore extended BX
	pop	eax			; restore extended AX
	;
	stc				; set carry flag indicate no PCI device
	jmp	short scan_pci_exit	; exit
scan_pci_mech1:
;
;----------------------------------------
; scan PCI bus for installed device use mechanism 1
;----------------------------------------
;
	pop	ebx			; restore extended BX
	pop	eax			; restore extended AX
	;
scan_pci_mechanism1:
	call	scan_pci_m1		; scan PCI bus use mechanism 1
	jmp	short scan_pci_exit	; exit
scan_pci_mechanism2:
;
;----------------------------------------
; scan PCI bus for installed device use mechanism 2
;----------------------------------------
;
	call	scan_pci_m2		; scan PCI bus use mechanism 2
scan_pci_exit:
	pop	cx			; restore CX
	pop	dx			; restore DX
	ret				; return to caller
scan_pci	endp			;

;
;-----------------------------------------------------------------------
;
;	scan_pci_m1
;
;	input	: none
;
;	output	: C  = 1, carry flag set indicate PCI device not found
;		  C  = 0, carry flag clear indicate PCI device found
;		    AX = BASE I/O address of found PCI device
;		    BL = Hardware ID
;		    BH = Interrupt line
;
;	modify	: AX, BL(if no error)
;
;-----------------------------------------------------------------------
;
scan_pci_m1	proc	near		; scan the pci bus use mechanism 1
	push	edx			; save registers
	push	ecx			;
	push	eax			;
;
;----------------------------------------
; WARNING!WARNING!WARNING!WARNING!WARNING!
;
; the following loops has tighted space.
; It needs space for modification.
;----------------------------------------
; loop through every bus
;----------------------------------------
;
	mov	ecx,PCI_MAX_BNUM	; set ECX = max PCI bus #
scan_pci_m1_bus:
	mov	eax,PCI_M1_ENABLE	; set EAX = config space enable bit
	push	ecx			; save ECX = bus # on stack
	neg	cx			; set CX = 2's complement
	add	cx,PCI_MAX_BNUM		; CX = (PCI_MAX_BNUM - CX)
	shl	ecx,PCI_CBUS_BIT	; shift to bus bit position
	or	eax,ecx			; set EAX = bus bit pattern
;
;----------------------------------------
; loop through every device
;----------------------------------------
;
	mov	ecx,PCI_M1MAX_DNUM	; set ECX = max PCI M1 device #
scan_pci_m1_devices:
	push	ecx			; save EXC = devices # on stack
	neg	cx			; set CX = 2's complement
	add	cx,PCI_M1MAX_DNUM	; CX = (PCI_M1MAX_DNUM - CX)
	shl	ecx,PCI_CDEV_BIT	; shift to device bit position
	push	eax			; save EAX = bus bit pattern on satck
	or	eax,ecx			; set EAX = bus&dev bit pattern
;
;----------------------------------------
; loop through every function
;----------------------------------------
;
	mov	ecx,PCI_MAX_FNUM	; set ECX = max PCI function #
scan_pci_m1_functions:
	push	ecx			; save EXC = function # on stack
	neg	cx			; set CX = 2's complement
	add	cx,PCI_MAX_FNUM		; CX = (PCI_MAX_FNUM - CX)
	shl	ecx,PCI_CFUN_BIT	; shift to function bit position
	push	eax			; EAX = bus&dev bit pattern on stack
	or	eax,ecx			; set EAX = bus&dev&fun bit pattern
					; register # 00h(vendor & device ID)
	push	eax			; EAX = bus&dev&fun bit pattern on stack
	;
	call	get_pci_m1_vdid		; get vendor & device ID
	;
	cmp	ax,AMD_VENDOR_ID	; check for AMD vendor ID
	jne	short scan_pci_m1_no_device; jump, if not AMD product
	shr	eax,PCI_DEVID_BIT	; AX = device ID
	and	ax,PCI_PCNET_MASK	; mask off last four digits
	cmp	ax,PCNET_PCI_ID		; check for PCnet device ID
	jne	short scan_pci_m1_no_device; jump, if not PCnet device ID
	;
	pop	eax			; get EAX = bus&dev&fun bit pattern
	mov	dword ptr dw_pci_bdfnum,eax; save bus&dev&fun bit pattern
	;
	call	handle_pci_m1_cfg	; get EAX = base I/O addr
					;      BH = interrupt line register
					; init command/status registers
					; disable configure space
	pop	edx			; restore EDX = bus&dev bit pattern
	jc	short scan_pci_m1_nfound; jump, if a device not enable
;
;----------------------------------------
; check "WW" signature
;	EEPROM checksum(0h - bh & 0eh - 0fh)
; get	hardware ID
;----------------------------------------
;
	call	check_device_info	; check "WW", checksum, HW ID
	jc	short scan_pci_m1_nfound; jump, if a device not found
	jmp	short scan_pci_m1_found	; jump, if a device found
scan_pci_m1_no_device:
	pop	eax			; balance stack,EAX = bus&dev&fun bit
	pop	edx			; balance stack,EDX = bus&dev bit
scan_pci_m1_nfound:
	mov	eax,edx			; EAX = bus&dev bit pattern
	pop	ecx			; restore function number
	loop	scan_pci_m1_functions	; loop, if function # not exhaust
	;
	pop	eax			; restore EAX = bus bit pattern
	pop	ecx			; restore device number
	loop	scan_pci_m1_devices	; loop, if devices # not exhaust
	;
	pop	ecx			; restore bus number
	loop	scan_pci_m1_bus		; loop, if bus # not exhaust
	;
	xor	eax,eax			; set EAX = disable PCI conf. 
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	;
	pop	eax			; restore extended AX
	stc				; set carry flag indicate error
	jmp	short scan_pci_m1_exit	; return to caller
scan_pci_m1_found:			; balance stack
	pop	ecx			; balance stack, ECX = function number
	pop	ecx			; balance stack, ECX = bus bit pattern
	pop	ecx			; balance stack, ECX = device number
	pop	ecx			; balance stack, ECX = bus number
	mov	cx,ax			; set CX = I/O address
	pop	eax			; restore extended AX
	mov	ax,cx			; set AX = I/O address
	clc				; clear carry flag indicate o.k.
scan_pci_m1_exit:
	pop	ecx			; restore registers
	pop	edx			;
	ret				; return to caller
scan_pci_m1	endp			;


;
;-----------------------------------------------------------------------
;
;	get_pci_m1_vdid
;
;	input	: EAX = bus&dev&fun bit pattern
;
;	output	: EAX = vendor & device ID
;
;	modify	: EAX, DX
;
;-----------------------------------------------------------------------
;
get_pci_m1_vdid	proc	near
;
;----------------------------------------
; check vendor ID and device ID
;----------------------------------------
;
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; read vendor & device ID
	ret
get_pci_m1_vdid	endp
;
;-----------------------------------------------------------------------
;
;	handle_pci_m1_cfg
;
;	input	: EAX = bus&dev&fun bit pattern
;
;	output	: carry flag set, PCI device disable
;		  carry flag clear
;		  EAX = BASE I/O address of found PCI device
;		  BH = Interrupt line
;
;	modify	: EAX, ECX, DX, BL
;
;-----------------------------------------------------------------------
;
handle_pci_m1_cfg	proc	near
;
;----------------------------------------
; get base I/O address
;----------------------------------------
;
	push	eax			; save EAX = bus&dev&fun bit pattern
	or	eax,PCI_BAREG_OFF	; EAX = bus&dev&fun&b_addr bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; read base I/O address from data reg
IFDEF	PH_GGA0
	and	ax,GG_IO_BASE_MASK	; mask off bit 0(stuck high)
ENDIF
	pop	ecx			; get ECX = bus&dev&fun bit pattern
	push	eax			; save EAX = base I/O addr on stack
					;
;
;----------------------------------------
; check PCI device enable
; if and only if (IO address != 0) & (command register IO space == 1)
;    then PCI device enable
;----------------------------------------
;
	or	eax,eax			; check IO address != 0
	jnz	short pci_m1_io_address	; jump, if device IO address valid
	stc				; set carry flag, indicate disable dev
	jmp	short handle_pci_m1_cfg_exit; exit
pci_m1_io_address:
;
;----------------------------------------
; read command/status register
;----------------------------------------
;
	mov	eax,ecx			; set EAX = bus&dev&fun bit pattern
	or	eax,PCI_CDREG_OFF	; EAX = bus&dev&fun&cs_addr bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; read from PCI config data reg
					;
	test	ax,PCI_IO_ENABLE	; check PCI command reg IO space enable
	jnz	short pci_m1_io_space	; jump, if PCI IO space enable
	stc				; set carry flag, indicate disable dev
	jmp	short handle_pci_m1_cfg_exit; exit
pci_m1_io_space:
;
;----------------------------------------
; write command/status register
;----------------------------------------
;
	mov	eax,ecx			; set EAX = bus&dev&fun bit pattern
	or	eax,PCI_CDREG_OFF	; EAX = bus&dev&fun&cs_addr bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; EAX = command & status contents
	and	eax,0FFFFh		; clear status word
	or	eax,(PCI_SREG_DEF*10000h+PCI_CREG_DEF); EAX = command & status setting
	out	dx,eax			; write pattern to PCI config data reg
;
;----------------------------------------
; read interrupt register
;----------------------------------------
;
	mov	eax,ecx			; set EAX = bus&dev&fun bit pattern
	or	eax,PCI_ITREG_OFF	; EAX = bus&dev&fun&int_addr bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	in	eax,dx			; read interrupt reg from data reg
	mov	bh,al			; write BH = interrupt line reg
					;
	clc				; clear carry flag
;
;----------------------------------------
; clear hardware latch avoid ground bouncing
;----------------------------------------
;
	mov	eax,ecx			; set EAX = bus&dev&fun bit pattern
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write AMD dev oft 0 to PCI cfg addr reg
	mov	eax,0			; EAX = clear
	mov	dx,PCI_CDA_REG		; DX = PCI config. data reg(0CFCh)
	out	dx,eax			; write 0 to PCI data reg and clear latch
;
;----------------------------------------
; disable PCI configuration space
;----------------------------------------
;
handle_pci_m1_cfg_exit:
	mov	eax,0			; set EAX = disable PCI conf. 
	mov	dx,PCI_CAD_REG		; DX = PCI config. addr reg(0CF8h)
	out	dx,eax			; write pattern to PCI config addr reg
	pop	eax			; restore EAX = base I/O addr
	ret
handle_pci_m1_cfg	endp
;
;-----------------------------------------------------------------------
;
; The routine is created to reduce scan_pci_2 size
;-----------------------------------------------------------------------
;
enable_pci_m2_conf	proc	near
	or	ax,PCI_M2_ENABLE	; AX = PCI cfg. space enbale bit pattern
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	out	dx,al			; write PCI bus # to config reg
	ret
enable_pci_m2_conf	endp

;
;-----------------------------------------------------------------------
;
; The routine is created to reduce scan_pci_2 size
;-----------------------------------------------------------------------
;
m2_glitch_fix	proc	near		;
;
;----------------------------------------
; clear hardware latch avoid ground bouncing
; disable configuration space
;----------------------------------------
;
	pushf				; save flag reg for PCI en/disable
	mov	ax,0			; AX = clear
	out	dx,ax			; clear latch(0-15)
	add	dx,PCI_DEVID_OFF	; DX = offset 2(Vid) in PCI M2 cfg
	out	dx,ax			; clear latch(16-31)
	popf				; restore flag for PCI en/disable
	ret
m2_glitch_fix	endp
;
;-----------------------------------------------------------------------
;
; The routine is created to reduce scan_pci_2 size
;-----------------------------------------------------------------------
;
disable_pci_m2_conf	proc	near
	;
	call	m2_glitch_fix		; fix glitch 
	;
	mov	ax,0			; set AX = disable config space
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	out	dx,al			; write PCI bus # to config reg
	ret
disable_pci_m2_conf	endp

;
;-----------------------------------------------------------------------
;
; The routine is created to reduce scan_pci_2 size
;-----------------------------------------------------------------------
;
set_pci_m2_forward_reg	proc	near
	neg	cx			; set CX = 2's complement
	add	cx,PCI_MAX_BNUM		; CX = (PCI_MAX_BNUM - CX)
	;
	mov	ax,cx			; AX = PCI bus #(0 base)
	mov	dx,PCI_CFW_REG		; DX = PCI config. forward reg(0CFAh)
	out	dx,al			; write PCI bus # to forward reg
	;
	mov	byte ptr dw_pci_bdfnum,al; save PCI bus #(forward reg)
	ret
set_pci_m2_forward_reg	endp

;
;-----------------------------------------------------------------------
;
; The routine is created to reduce scan_pci_2 size
;-----------------------------------------------------------------------
;
adjust_pci_m2_fun_cx	proc	near
	neg	cx			; set CX = 2's complement
	add	cx,PCI_MAX_FNUM		; CX = (PCI_MAX_FNUM - CX)
	shl	cx,PCI_CSFUN_BIT	; CX = PCI function # bit pattern
	ret
adjust_pci_m2_fun_cx	endp

;
;-----------------------------------------------------------------------
;
;	scan_pci_m2
;
;	input	: none
;
;	output	: C  = 1, carry flag set indicate PCI device not found
;		  C  = 0, carry flag clear indicate PCI device found
;		    AX = BASE I/O address of found PCI device
;		    BL = Hardware ID
;		    BH = Interrupt line
;
;	modify	: AX, BL(if no error)
;
;-----------------------------------------------------------------------
;
scan_pci_m2	proc	near		; scan the pci bus use mechanism 2
	push	dx			; save registers
	push	cx			;
;
;----------------------------------------
; loop through every bus
;----------------------------------------
;
	mov	cx,PCI_MAX_BNUM		; set CX = max PCI bus #
scan_pci_m2_bus:
	push	cx			; save CX = PCI bus #
	call	set_pci_m2_forward_reg	; set PCI forward reg for config space
;
;----------------------------------------
; loop through every function
;----------------------------------------
;
	mov	cx,PCI_MAX_FNUM		; set CX = max PCI function #
scan_pci_m2_functions:
	push	cx			; save CX = PCI function #
	call	adjust_pci_m2_fun_cx	; adjust CX for PCI config space
	mov	ax,cx			; AX = PCI cfg. space reg bit pattern
	call	enable_pci_m2_conf	; enable PCI config space
	;
	mov	byte ptr (dw_pci_bdfnum+1),al; save PCI fun #(cfg reg)
;
;----------------------------------------
; loop through every device(C000h - CFFFh)
;----------------------------------------
;
	mov	cx,PCI_M2MAX_DNUM	; set CX = max PCI M2 device #
	mov	dx,PCI_CFG_ADDR		; set DX = PCI M2 cfg space begin addr
scan_pci_m2_devices:
	push	dx			; save DX = PCI M2 cfg last device addr
	;
	mov	word ptr (dw_pci_bdfnum+2),dx; save PCI current dev addr
;
;----------------------------------------
; check vendor ID and device ID
;----------------------------------------
;
	in	ax,dx			; read AX = vendor ID
	cmp	ax,AMD_VENDOR_ID	; check for AMD vendor ID
	jne	short scan_pci_m2_no_device; jump, if not AMD product
	;
	add	dx,PCI_DEVID_OFF	; DX = PCI M2 cfg device ID addr
	in	ax,dx			; read AX = device ID
	and	ax,PCI_PCNET_MASK	; mask off last four digits
	cmp	ax,PCNET_PCI_ID		; check for PCnet device ID
	jne	short scan_pci_m2_no_device; jump, if not PCnet device ID
;
;----------------------------------------
; get base I/O address,
;----------------------------------------
;
	add	dx,(PCI_BAREG_OFF-PCI_DEVID_OFF); DX = PCI M2 cfg base addr
	in	ax,dx			; read AX = base I/O addr
	;
IFDEF	PH_GGA0
	and	ax,GG_IO_BASE_MASK	; mask off bit 0(stuck high)
ENDIF
	push	ax			; save AX = base I/O addr on stack
;
;----------------------------------------
; check PCI device enable
; if and only if (IO address != 0) & (command register IO space == 1)
;    then PCI device enable
;----------------------------------------
;
	or	ax,ax			; check valid IO address
	jz	short pci_m2_dev_disable; jump, if invalid IO address
;
;----------------------------------------
; read command register
;----------------------------------------
;
	sub	dx,(PCI_BAREG_OFF-PCI_CDREG_OFF); DX = PCI M2 cfg cmd addr
	in	ax,dx			; read command reg
					;
	test	ax,PCI_IO_ENABLE	; check IO space enable
	jnz	short pci_m2_io_space	; jump, if IO space enabled
pci_m2_dev_disable:
	;
	sub	dx,PCI_CDREG_OFF	; DX = PCI M2 cfg vendor ID addr
	;
	stc				; set carry flag, PCI dev disable 
	jmp	short pci_m2_dev_check	; jump, continue loop
pci_m2_io_space:
;
;----------------------------------------
; modify, write command register
;----------------------------------------
;
;;;;	in	ax,dx			; AX = current reg content
	or	ax,PCI_CREG_DEF		; AX = cmd reg deft(enable bus master)
	out	dx,ax			; write command reg default
;
;----------------------------------------
; write status register
;----------------------------------------
;
	add	dx,(PCI_STREG_OFF-PCI_CDREG_OFF); DX = PCI M2 cfg status addr
	mov	ax,PCI_SREG_DEF		; AX = status reg default
	out	dx,ax			; write status reg default
;
;----------------------------------------
; read interrupt register
;----------------------------------------
;
	add	dx,(PCI_ITREG_OFF-PCI_STREG_OFF); DX = PCI M2 cfg int addr
	in	ax,dx			; read AX = interrupt reg
	mov	bh,al			; BH = interrupt line register
	;
	sub	dx,PCI_ITREG_OFF	; DX = offset 0(Mid) in PCI M2 cfg
	;
	clc				; indicate PCI device enable
pci_m2_dev_check:
	;
	call	disable_pci_m2_conf	; disable PCI config space
	pop	ax			; restore AX = base I/O addr
					;
	jc	short scan_pci_m2_no_device; jump, PCI device disable
;
;----------------------------------------
; check "WW" signature
;	EEPROM checksum(0h - bh & 0eh - 0fh)
; get	hardware ID
;----------------------------------------
;
	call	check_device_info	; check "WW", checksum, HW ID
	jnc	short scan_pci_m2_found	; jump, if device found
	;
scan_pci_m2_no_device:
;
;----------------------------------------
; enable configuration space
;----------------------------------------
;
	xor	ax,ax			; clear AX
	call	enable_pci_m2_conf	; enable PCI config space
	;
	pop	dx			; restore DX = PCI M2 cfg last dev addr
	add	dx,PCI_CFDEV_OFF	; DX = next PCI M2 cfg dev vendor ID addr
	loop	scan_pci_m2_devices	;
	;
	pop	cx			; restore CX = PCI function #
	loop	scan_pci_m2_functions	;
	;
	pop	cx			; restore CX = PCI bus #
	loop	scan_pci_m2_bus		;
	;
	xor	ax,ax			; set AX = disable config space
	mov	dx,PCI_CSE_REG		; DX = PCI cfg. space reg.
	out	dx,al			; write PCI bus # to config reg
	;
	stc				; set carry flag indicate error
	jmp	short scan_pci_m2_exit	; exit
scan_pci_m2_found:
	pop	dx			; balance stack, DX = PCI M2 cfg last dev addr
	pop	cx			; balance stack, CX = PCI function #
	pop	cx			; balance stack, CX = PCI bus #
	clc				; clear carry flag indicate o.k.
scan_pci_m2_exit:
	pop	cx			; restore registers
	pop	dx			;
	ret				; return to caller
scan_pci_m2	endp			;

;
;-----------------------------------------------------------------------
;
;	scan_pnp
;
;	input	: none
;
;	output	: C  = 1, carry flag set indicate PnP device not found
;		  C  = 0, carry flag clear indicate PnP device found
;		    AX = BASE I/O address of found PnP device
;		    BL = Hardware ID
;
;	modify	: AX, BL(if no error)
;
;-----------------------------------------------------------------------
;
scan_pnp	proc	near		; scan the pnp 
	push	cx			; save registers
	push	dx			; 
;
;----------------------------------------
; scan Plug & Play I/O address space
;----------------------------------------
;
	mov	cx,PNP_IOADD_CNT	; CX = PnP I/O addr count
	mov	ax,PNP_START_ADDR	; AX = PnP I/O start addr
scan_pnp_all:
;
;----------------------------------------
; check "WW" signature
;	EEPROM checksum(0h - bh & 0eh - 0fh)
; get	hardware ID
;----------------------------------------
;
	push	ax			; save AX = PnP I/O address
	call	check_device_info	; check "WW", checksum, HW ID
	jnc	short scan_pnp_found	; jump, if any error happened
	pop	ax			; restore AX = PnP I/O address
	add	ax,PNP_NXDEV_OFF	; next possible I/O addr
	loop	scan_pnp_all		; loop, until counter exhaust
	stc				; set carry flag indicate error
	jmp	short scan_pnp_exit	; exit
scan_pnp_found:
	pop	ax			; restore, AX = PnP I/O address
	clc				; clear carry flag indicate o.k.
scan_pnp_exit:
	pop	dx			; restore registers
	pop	cx			;
	ret				; return to caller
scan_pnp	endp			;

;
;-----------------------------------------------------------------------
;
;	scan_vl_isa
;	the scan routine use bus type byte or hardware identification
;	register to differentiate the VL or ISA case.
;
;	input	: b_bustype = ISA or VL ISA
;
;	output	: C  = 1, carry flag set indicate VL/ISA device not found
;		  C  = 0, carry flag clear indicate VL/ISA device found
;		    AX = BASE I/O address of found VL/ISA device
;		    BL = Hardware ID
;
;	modify	: AX,BL(if no error)
;
;	assume	: VL ISA and ISA bus type is properly programmed
;
;-----------------------------------------------------------------------
;
scan_vl_isa	proc	near		; scan the VL & ISA bus 
	push	cx			; save registers
	push	dx			; 
	push	bx			;
;
;----------------------------------------
; check OEM 2 check enable
;----------------------------------------
;
	cmp	b_oem2_enable,OEM_2_EN	; check OEM 2 VL device case
	jne	short scan_vl_isa_noem2	; jump, if OEM 2 check = disable
	;
	mov	ax,OEM_2_VL_PORT	; set OEM 2 VL I/O port address
	push	ax			; save AX = I/O address	
	call	check_device_info	; check "WW", checksum, HW ID
	jnc	short scan_vl_isa_found	; jump, if no error happened
	pop	ax			; balance stacks
	pop	bx			;	
	stc				; set carry flag indicate error
	jmp	short scan_vl_isa_exit	; exit
scan_vl_isa_noem2:			; bus type byte = default or VL
;
;----------------------------------------
; scan ISA I/O address space
;----------------------------------------
;
	mov	cx,ISA_IOADD_CNT	; CX = ISA I/O addr count
	mov	ax,ISA_START_ADDR	; AX = ISA I/O start addr
	mov	bx,ISA_NXDEV_OFF	; BX = ISA next device offset
	;
	cmp	b_bustype,ISA_BUSTYPE	; check bus type = ISA type
	je	short scan_vl_isa_start	; jump, if bus type != ISA type
;
;----------------------------------------
; scan VL(ISA) I/O address space
;----------------------------------------
;
	mov	cx,VLI_IOADD_CNT	; CX = VLI I/O addr count
	mov	ax,VLI_START_ADDR	; AX = VLI I/O start addr
	mov	bx,VLI_NXDEV_OFF	; BX = VL ISA next device offset
	;
scan_vl_isa_start:			; bus type byte = default or VL
;
;----------------------------------------
; check "WW" signature
;	EEPROM checksum(0h - bh & 0eh - 0fh)
; get	hardware ID
;----------------------------------------
;
	push	ax			; save AX = I/O address	
	call	check_device_info	; check "WW", checksum, HW ID
	jnc	short scan_vl_isa_found	; jump, if any error happened
	pop	ax			; restore AX = I/O address
	add	ax,bx			; next possible I/O addr
	loop	scan_vl_isa_start	; loop, until counter exhaust
	pop	bx			; restore bx
	stc				; set carry flag indicate error
	jmp	short scan_vl_isa_exit	; exit
scan_vl_isa_found:
	pop	ax			; restore AX = I/O address
	pop	dx			; balance stack(old BX)
	clc				; clear carry flag indicate o.k.
scan_vl_isa_exit:
	pop	dx			; restore registers
	pop	cx			;
	ret				; return to caller
scan_vl_isa	endp			;

;
;-----------------------------------------------------------------------
;
;	get_parameters
;
;	input	: AX = BASE I/O address
;		  BL = Hardware ID.
;
;	output	: C  = 1, carry flag set indicate error
;		    AX = error code
;		  C  = 0, carry flag clear indicate ok.
;
;	modify	: AX(if error)
;
;	assume	: bus type detected and bus type byte set
;
;		  DMA/IRQ range check is done within each individual PCnet
;		  devices.
;
;-----------------------------------------------------------------------
;
get_parameters	proc	near		; get device DMA, IRQ parameters
;
;----------------------------------------
; check & set ISA DMA & IRQ
;----------------------------------------
;
	cmp	b_bustype,ISA_BUSTYPE	; check bus type = ISA type
	jne	short get_parameters_1	; jump, if bus type != ISA type
	call	get_isa_dmairq		; get ISA device DMA & IRQ
	jmp	short get_parameters_exit; exit
get_parameters_1:
;
;----------------------------------------
; check & set VL ISA IRQ
;----------------------------------------
;
	cmp	b_bustype,VLISA_BUSTYPE	; check bus type = VL ISA type
	jne	short get_parameters_2	; jump, if bus type != VL ISA type
	call	get_vlisa_irq		; get VL ISA device IRQ
	jmp	short get_parameters_exit; exit
get_parameters_2:
;
;----------------------------------------
; check & set PCI IRQ
;----------------------------------------
;
	cmp	b_bustype,PCI_BUSTYPE	; check bus type = PCI type
	jne	short get_parameters_3	; jump, if bus type != PCI type
	call	get_pci_irq		; get PCI device IRQ
	jmp	short get_parameters_exit; exit
get_parameters_3:
;
;----------------------------------------
; check & set PnP DMA & IRQ
;----------------------------------------
;
	cmp	b_bustype,PNP_BUSTYPE	; check bus type = PnP ISA type
	jne	short get_parameters_error; jump, if bus type != PnP ISA type
	call	get_pnp_dmairq		; get PnP device DMA & IRQ
	jmp	short get_parameters_exit; exit
get_parameters_error:
	mov	ax,ERR_NO_PCNET		; error, user input parameter(s) error
	stc				; set carry flag indicate error
get_parameters_exit:
	ret				; return to caller
get_parameters	endp			;

IFDEF	OEM1_PRESENT
;
;-----------------------------------------------------------------------
;	OEM ISA IRQ translation table
;-----------------------------------------------------------------------
;
OEM_IRQ_TABLE	label	byte
	db	3,4,5,9,10,11,12,15	; OEM ISA IRQ number table
;
;-----------------------------------------------------------------------
;	OEM ISA DMA translation table
;-----------------------------------------------------------------------
;
OEM_DMA_TABLE	label	byte
	db	3,5,6,7			; OEM ISA DMA number table
;
;-----------------------------------------------------------------------
;
;	check_oem1
;
;	input	: AX = BASE I/O address
;
;	output	: AH = OEM IRQ, AL = OEM DMA(if OEM exist)
;		  AX = BASE I/O address
;
;	modify	: b_oem1 & AX (if OEM manufacturer exist)
;
;	assume	: 
;
;-----------------------------------------------------------------------
;
check_oem1	proc	near		; check OEM manufacturer
	push	dx			; save register
	push	bx			;
	push	ax			;
;
;----------------------------------------
; identify OEM manufacturer
;----------------------------------------
;
	mov	dx,ax			; DX = base I/O addr
	add	dx,OEM1_DAT0_OFT	; DX = OEM 1 data 0 offset
	in	al,dx			; get AL = OEM 1 offset data
	cmp	al,OEM1_DAT0		; check OEM 1 data 0 byte = AL
	jne	short check_oem1_notfound; exit, if OEM1 data 0 byte != AL
	;
	add	dx,(OEM1_DAT1_OFT-OEM1_DAT0_OFT); DX = OEM 1 data 1 offset
	in	al,dx			; get AL = OEM 1 offset data
	cmp	al,OEM1_DAT1		; check OEM 1 data 1 byte = AL
	jne	short check_oem1_notfound; exit, if OEM1 data 1 byte != AL
	;
	add	dx,(OEM1_DAT2_OFT-OEM1_DAT1_OFT); DX = OEM 1 data 2 offset
	in	al,dx			; get AL = OEM 1 offset data
	cmp	al,OEM1_DAT2		; check OEM 1 data 2 byte = AL
	jne	short check_oem1_notfound; exit, if OEM1 data 2 byte != AL
	;
	add	dx,(OEM1_DATB_OFT-OEM1_DAT2_OFT); DX = OEM 1 data B offset
	in	al,dx			; get AL = OEM 1 offset data
	cmp	al,OEM1_DATB		; check OEM 1 data B byte = AL
	jne	short check_oem1_notfound; exit, if OEM1 data B byte != AL
;
;----------------------------------------
; get & translate OEM DMA & IRQ configuration
;----------------------------------------
;
	mov	b_oem1,OEM_1		; set oem byte as OEM1 identified
	;
	add	dx,(OEM1_DMAIRQ_OFT-OEM1_DATB_OFT); DX = OEM DMA/IRQ offset
	in	al,dx			; get AL = OEM IRQ/DMA/IOaddr data
	mov	dl,al			; DL = OEM IRQ/DMA/IOaddr data
	pop	ax			; balance stack, AX base I/O address
	;
	xor	bx,bx			; BX = 0
	mov	bl,dl			; BL = OEM IRQ/DMA/IOaddr data
	and	bl,OEM1_DMA_MASK	; BL = OEM DMA bit pattern
	shr	bl,OEM1_DMA_BITS	; BL = OEM DMA offset
	add	bx,offset cs:OEM_DMA_TABLE; BX = OEM DMA number address
	mov	al,byte ptr cs:[bx]	; al = OEM DMA number
	;
	xor	bx,bx			; BX = 0
	mov	bl,dl			; BL = OEM IRQ/DMA/IOaddr data
	and	bl,OEM1_IRQ_MASK	; BL = OEM IRQ bit pattern
	shr	bl,OEM1_IRQ_BITS	; BL = OEM IRQ offset
	add	bx,offset cs:OEM_IRQ_TABLE; BX = OEM IRQ number address
	mov	ah,byte ptr cs:[bx]	; ah = OEM IRQ number
	;
	jmp	short check_oem1_exit	; exit
check_oem1_notfound:
	pop	ax			; restore AX = base I/O addr
check_oem1_exit:
	pop	bx			; restore register
	pop	dx			; 
	ret
check_oem1	endp
ENDIF

;
;-----------------------------------------------------------------------
;
;	get_isa_dmairq
;
;	input	: AX = BASE I/O address
;		  BL = Hardware ID.
;
;	output	: C  = 1, carry flag set indicate error
;		    AX = error code
;		  C  = 0, carry flag clear indicate ok.
;
;	modify	: interrupt_number, dma_channel
;
;	assume	: default DMA & IRQ bytes and user input bytes exist
;
;		  check user specified DMA channel range
;		  check user specified IRQ number range
;
;-----------------------------------------------------------------------
;
get_isa_dmairq	proc	near		; get ISA device DMA, IRQ parameters
	push	ax			; save AX = base I/O address
;
;----------------------------------------
; set detected ISA I/O address
;   specified, io_addr == ax(or IO_base == ax) 
;   non-specified, io_addr(or IO_base) unset
;----------------------------------------
;
IFDEF	PACKET
	mov	io_addr,ax		; set ISA I/O address
ELSE
	mov	IO_base,ax		; set ISA I/O address
ENDIF

IFDEF	OEM1_PRESENT
	call	check_oem1		; get AH = OEM IRQ, AL = OEM DMA
ENDIF
;
;----------------------------------------
; check user specified ISA DMA channel
;----------------------------------------
;
IFDEF	PACKET
	cmp	dma_no,NULL		; check user input DMA
ELSE
	cmp	PCNT_dma,NULL		; check user input DMA
ENDIF
	je	short get_isa_dma_def	; jump, if user isn't input DMA value
;
;----------------------------------------
; check user specified ISA DMA channel range
;   DMA = 3,5,6,7
;----------------------------------------
;
IFDEF	PACKET
	cmp	dma_no,ISA_DMA_START	; check user input DMA < START
	jb	short get_isa_dmairq_derr; jump, if out of lower boundary
	cmp	dma_no,ISA_DMA_END	; check user input DMA > END
	ja	short get_isa_dmairq_derr; jump, if out of higher boundary
	cmp	dma_no,ISA_DMA_CASCADE	; check user input DMA != CASCADE CHL
	jne	short get_isa_dmairq1	; jump, if not equal cascade dma channel
ELSE
	cmp	PCNT_dma,ISA_DMA_START	; check user input DMA < START
	jb	short get_isa_dmairq_derr; jump, if out of lower boundary
	cmp	PCNT_dma,ISA_DMA_END	; check user input DMA > END
	ja	short get_isa_dmairq_derr; jump, if out of higher boundary
	cmp	PCNT_dma,ISA_DMA_CASCADE; check user input DMA != CASCADE CHL
	jne	short get_isa_dmairq1	; jump, if not equal cascade dma channel
ENDIF
get_isa_dmairq_derr:
	pop	ax			; restore AX = base I/O address
	mov	ax,ERR_DMA_RANGE	; error code, DMA out of range
	jmp	short get_isa_error	; jump, if user input DMA value error
get_isa_dma_def:
;
;----------------------------------------
; set default ISA DMA channel
;----------------------------------------
;
IFDEF	OEM1_PRESENT
	cmp	b_oem1,DEF_OEM		; check OEM manufacturer
	je	short get_isa_dma_default; jump, if no OEM manufacturer
IFDEF	PACKET
	mov	dma_no,al		; set OEM ISA DMA value
ELSE
	mov	PCNT_dma,al		; set OEM ISA DMA value
ENDIF
	jmp	short get_isa_dmairq1	; jump, continue
ENDIF
	;
get_isa_dma_default:
IFDEF	PACKET
	mov	dma_no,DEF_ISA_DMA	; set default ISA DMA value
ELSE
	mov	PCNT_dma,DEF_ISA_DMA	; set default ISA DMA value
ENDIF
get_isa_dmairq1:
;
;----------------------------------------
; check user specified ISA IRQ #
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,NULL		; check user input IRQ
ELSE
	cmp	PCNT_interrupt,NULL	; check user input IRQ
ENDIF
	je	short get_isa_irq_def	; jump, if user isn't input IRQ value
;
;----------------------------------------
; check user specified ISA IRQ # range
;   IRQ = 3,4,5,9,10,11,12,15
;   IRQ = 0 - 15
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,ISA_IRQ_15	; check IRQ # > ISA_IRQ_15
	jbe	short get_isa_dmairq2	; jump, if IRQ # <= ISA_IRQ 15
ELSE
	cmp	PCNT_interrupt,ISA_IRQ_15; check IRQ # > ISA_IRQ_15
	jbe	short get_isa_dmairq2	; jump, if IRQ # <= ISA_IRQ 15
ENDIF
get_isa_dmairq_ierr:
	pop	ax			; restore AX = base I/O address
	mov	ax,ERR_IRQ_RANGE	; error code, IRQ out of range
	jmp	short get_isa_error	; jump, if user input DMA value error
get_isa_irq_def:
;
;----------------------------------------
; set default ISA IRQ channel
;----------------------------------------
;
IFDEF	OEM1_PRESENT
	cmp	b_oem1,DEF_OEM		; check OEM manufacturer
	je	short get_isa_irq_default; jump, if no OEM manufacturer
IFDEF	PACKET
	mov	int_no,ah		; set OEM ISA IRQ value
ELSE
	mov	PCNT_interrupt,ah	; set OEM ISA IRQ value
ENDIF
	jmp	short get_isa_dmairq2	; jump, continue
ENDIF
	;
get_isa_irq_default:
IFDEF	PACKET
	mov	int_no,DEF_ISA_IRQ	; set default ISA IRQ value
ELSE
	mov	PCNT_interrupt,DEF_ISA_IRQ; set default ISA IRQ value
ENDIF
get_isa_dmairq2:			; 
	pop	ax			; restore AX = base I/O address
	clc				; clear carry flag indicate o.k.
	jmp	short get_isa_exit	; jump, if no error
get_isa_error:				; 
	stc				; set carry flag indicate error
get_isa_exit:				; 
	ret				; return to caller
get_isa_dmairq	endp			;

;
;-----------------------------------------------------------------------
;	VL ISA interrupt translation table
;-----------------------------------------------------------------------
;
VLISA_INT_TABLE	label	byte
	db	10,5,3,15		; ISA VL int number table

;
;-----------------------------------------------------------------------
;
;	get_vlisa_irq
;
;	input	: AX = BASE I/O address
;		  BL = Hardware ID.
;
;	output	: C  = 1, carry flag set indicate error
;		    AX = error code
;		  C  = 0, carry flag clear indicate ok.
;
;	modify	: AX(if error)
;
;		  check user specified DMA channel
;		  check user specified IRQ number range
;
;-----------------------------------------------------------------------
;
get_vlisa_irq	proc	near		; get VL ISA device IRQ parameters
	push	dx			; save register
	push	bx			;
;
;----------------------------------------
; set detected VL ISA I/O address
;   specified, io_addr == ax(or IO_base == ax) 
;   non-specified, io_addr(or IO_base) unset
;----------------------------------------
;
IFDEF	PACKET
	mov	io_addr,ax		; set VL ISA I/O address
ELSE
	mov	IO_base,ax		; set VL ISA I/O address
ENDIF
;
;----------------------------------------
; read & set VL ISA IRQ #
;----------------------------------------
;
	push	ax			; save AX = base VL ISA I/O address
	mov	dx,ax			; set DX = base I/O addres
	;
	add	dx,PCNET_HWIRQ_OFF	; adjust DX = hardware IRQ offset
	in	al,dx			; read AL = hardware IRQ #
;
;----------------------------------------
; check OEM 2 check enable
;----------------------------------------
;
	cmp	b_oem2_enable,OEM_2_EN	; check OEM 2 VL device case
	je	short get_vlisa_irq_2	; jump, if OEM 2 check = enable
	;
	or	al,al			; check for defined irq
	jz	short get_vlisa_irq_1	; jump, if not define
	cmp	al,VL_IRQ_15		; check IRQ # = 15
	ja	short get_vlisa_irq_1	; jump, if out of range
	jmp	short get_vlisa_irq_2	; exit
get_vlisa_irq_1:			; 
	add	dx,(ADDR_REG-PCNET_HWIRQ_OFF); DX = addr register
	mov	ax,VLISA_BCR21		; AX = index to BCR 21
	out	dx,ax			; write to address register
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = Bus data register
	in	ax,dx			; AX = content of BCR21
	;
	and	ax,VLISA_INTSEL_M	; AX = VL ISA interrupt selection
	mov	bx,offset cs:VLISA_INT_TABLE; bx = offset to VL ISA INT table
	add	bl,al			; index to proper entry
	mov	al,cs:[bx]		; get al = VL ISA INT #
get_vlisa_irq_2:			; 
;
;----------------------------------------
; check specified VL IRQ #
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,NULL		; check IRQ # = NULL
ELSE
	cmp	PCNT_interrupt,NULL	; check IRQ # = NULL
ENDIF
	je	short get_vlisa_irq_assigned; jump, if user isn't specified
;
;----------------------------------------
; check user specified VL ISA IRQ # range
;   IRQ = 3,5,10,15
;   IRQ = 0 - 15
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,VL_IRQ_15	; check IRQ # = 15
	jbe	short get_vlisa_irq_dma	; jump, if IRQ # <= 15
ELSE
	cmp	PCNT_interrupt,VL_IRQ_15; check IRQ # = 15
	jbe	short get_vlisa_irq_dma	; jump, if IRQ # <= 15
ENDIF
	;
	pop	ax			; restore AX = base I/O addr
	mov	ax,ERR_VL_MIRQ		; AX = IRQ out of range(msimatch) error
	jmp	short get_vlisa_irq_error; error, jump exit
get_vlisa_irq_range:
;
;----------------------------------------
; check user specified VL IRQ # = VL setting
;----------------------------------------
;
;IFDEF	PACKET
;	cmp	int_no,al		; check IRQ # = AL
;ELSE
;	cmp	PCNT_interrupt,al	; check IRQ # = AL
;ENDIF
;	je	short get_vlisa_irq_dma	; jump, if user specified = VL setting
;	;
;	pop	ax			; restore AX = base I/O addr
;	mov	ax,ERR_VL_MIRQ		; AX = IRQ input # mismatched
;	jmp	short get_vlisa_irq_error; jump to check input DMA parameter
;	;
get_vlisa_irq_assigned:			;
IFDEF	PACKET
	mov	int_no,al		; set VL ISA interrupt number
ELSE
	mov	PCNT_interrupt,al	; set VL ISA interrupt number
ENDIF
;
;----------------------------------------
; check user specified VL ISA DMA channel
;----------------------------------------
;
get_vlisa_irq_dma:			;
IFDEF	PACKET
	cmp	dma_no,NULL		; check DMA # = NULL
ELSE
	cmp	PCNT_dma,NULL		; check DMA # = NULL
ENDIF
	pop	ax			; restore AX = base I/O addr
	je	short get_vlisa_irq_ok	; jump, if user not specified
	mov	ax,ERR_VL_NDMA		; AX = warning VL no DMA chl required
get_vlisa_irq_error:			;
	stc				; set carry flag indicate error
	jmp	short get_vlisa_irq_exit; exit
get_vlisa_irq_ok:			;
	clc				; clear carry flag indicate ok.
get_vlisa_irq_exit:			;
	pop	bx			; restore registers
	pop	dx			;
	ret				; return to caller
get_vlisa_irq	endp			;
;
;-----------------------------------------------------------------------
;
;	get_pci_irq
;
;	input	: AX = BASE I/O address
;		  BL = Hardware ID.
;		  BH = Interrupt line
;
;	output	: C  = 1, carry flag set indicate error
;		    AX = error code
;		  C  = 0, carry flag clear indicate ok.
;
;	modify	: AX(if error)
;
;		  check user specified DMA channel
;		  check user specified IRQ number range
;
;-----------------------------------------------------------------------
;
get_pci_irq	proc	near		; get PCI ISA device IRQ parameters
;
;----------------------------------------
; set detected PCI I/O address
;----------------------------------------
;
IFDEF	PACKET
	mov	io_addr,ax		; set PCI ISA I/O address
ELSE
	mov	IO_base,ax		; set PCI ISA I/O address
ENDIF
;
;----------------------------------------
; set detected PCI IRQ #
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,NULL		; check IRQ # = NULL
ELSE
	cmp	PCNT_interrupt,NULL	; check IRQ # = NULL
ENDIF
	je	short get_pci_irq_assigned; jump, if user not specified
;
;----------------------------------------
; check user specified PCI IRQ # range
;   IRQ = 0 - 15
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,PCI_IRQ_END	; check IRQ # > PCI_IRQ_END
	ja	short get_pci_irq_ierr	; jump, if user input IRQ # > PCI_IRQ_END
	cmp	int_no,bh		; check IRQ # = BH PCI setting
ELSE
	cmp	PCNT_interrupt,PCI_IRQ_END; check IRQ # > PCI_IRQ_END
	ja	short get_pci_irq_ierr	; jump, if user input IRQ # < PCI_IRQ_END
	cmp	PCNT_interrupt,bh	; check IRQ # = BH PCI setting
ENDIF
	je	short get_pci_irq_dma	; jump, if user specified = BH PCI setting
	mov	ax,ERR_PCI_MIRQ		; AX = specified IRQ # mismatched
	jmp	short get_pci_irq_error	;
get_pci_irq_ierr:			;
	mov	ax,ERR_PCI_MIRQ		; AX = IRQ out of range
	jmp	short get_pci_irq_error	;
	;
get_pci_irq_assigned:			;
IFDEF	PACKET
	mov	int_no,bh		; set PCI interrupt number
ELSE
	mov	PCNT_interrupt,bh	; set PCI interrupt number
ENDIF
;
;----------------------------------------
; check user specified DMA channel
;----------------------------------------
;
get_pci_irq_dma:
IFDEF	PACKET
	cmp	dma_no,NULL		; check DMA # = NULL
ELSE
	cmp	PCNT_dma,NULL		; check DMA # = NULL
ENDIF
	je	short get_pci_irq_2	; jump, if user not specified
	mov	ax,ERR_PCI_NDMA		; AX = warning PCI no DMA chl required
get_pci_irq_error:
	stc				; set carry flag indicate error
	jmp	short get_pci_irq_exit	; exit
get_pci_irq_2:
	clc				; clear carry flag indicate ok.
get_pci_irq_exit:
	ret				; return to caller
get_pci_irq	endp			;

;
;-----------------------------------------------------------------------
;	PnP ISA interrupt translation table
;-----------------------------------------------------------------------
;
PNPISA_INT_TABLE	label	byte
	db	0,0,0,3,4,5,0,0,0,9,10,11,12,0,0,15; PnP ISA INT table

;
;-----------------------------------------------------------------------
;	PnP ISA DMA translation table
;-----------------------------------------------------------------------
;
PNPISA_DMA_TABLE	label	byte
	db	0,0,0,3,0,5,6,7		; PnP ISA DMA table

;
;-----------------------------------------------------------------------
;
;	get_pnp_dmairq
;
;	input	: AX = BASE I/O address
;		  BL = Hardware ID.
;
;	output	: C  = 1, carry flag set indicate error
;		    AX = error code
;		  C  = 0, carry flag clear indicate ok.
;
;	modify	: AX(if error)
;
;		  check user specified DMA channel range
;		  check user specified IRQ number range
;
;-----------------------------------------------------------------------
;
get_pnp_dmairq	proc	near		; get PnP device DMA, IRQ parameters
	push	dx			; save registers
	push	bx			;
;
;----------------------------------------
; set detected PnP I/O address
;----------------------------------------
;
IFDEF	PACKET
	mov	io_addr,ax		; set PCI ISA I/O address
ELSE
	mov	IO_base,ax		; set VL ISA I/O address
ENDIF
;
;----------------------------------------
; read PnP ISA IRQ/DMA & set PnP ISA IRQ #
;----------------------------------------
;
	push	ax			; save AX = base PnP ISA I/O address
	mov	dx,ax			; set DX = base I/O addres
	add	dx,ADDR_REG		; DX = addr register
	mov	ax,PNPISA_BCR8		; AX = index to BCR 8
	out	dx,ax			; write to address register
	;
	add	dx,(BDAT_REG-ADDR_REG)	; DX = Bus data register
	in	ax,dx			; AX = content of BCR 8
	;
	push	ax			; save AX = content of BCR 8
	shr	ax,PNPISA_INTSEL_B	; shift PnP INTSEL to lowest bits
	and	ax,PNPISA_INTSEL_M	; AX = PNP ISA interrupt selection
	mov	bx,offset cs:PNPISA_INT_TABLE; Bx = offset to PnP ISA INT table
	add	bl,al			; index to proper entry
	mov	al,byte ptr cs:[bx]	; get al = PnP ISA INT #
;
;----------------------------------------
; check user specified PnP ISA IRQ #
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,NULL		; check IRQ # = NULL
ELSE
	cmp	PCNT_interrupt,NULL	; check IRQ # = NULL
ENDIF
	je	short get_pnp_irq_def	; jump, if user not specified
;
;----------------------------------------
; check user specified PnP IRQ # range
;   IRQ = 3,4,5,9,10,11,12,15
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,PNP_IRQ_3	; check IRQ # < PNP_IRQ_3
	jb	short get_pnp_dmairq_ierr; jump, if IRQ # < PNP_IRQ 3
	cmp	int_no,PNP_IRQ_N6	; check IRQ # = PNP_IRQ_N6
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ_N6
	cmp	int_no,PNP_IRQ_N7	; check IRQ # = PNP_IRQ_N7
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ_N7
	cmp	int_no,PNP_IRQ_N8	; check IRQ # = PNP_IRQ_N8
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ_N8
	cmp	int_no,PNP_IRQ_N13	; check IRQ # = PNP_IRQ_N13
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ_N13
	cmp	int_no,PNP_IRQ_N14	; check IRQ # = PNP_IRQ_N14
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ_N14
	cmp	int_no,PNP_IRQ_15	; check IRQ # > PNP_IRQ_15
	jbe	short get_pnp_dmairq_1	; jump, if IRQ # <= PNP_IRQ 15
ELSE
	cmp	PCNT_interrupt,PNP_IRQ_3; check IRQ # < PNP_IRQ_3
	jb	short get_pnp_dmairq_ierr; jump, if IRQ # < PNP_IRQ 3
	cmp	PCNT_interrupt,PNP_IRQ_N6; check IRQ # = PNP_IRQ_N6
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ N6
	cmp	PCNT_interrupt,PNP_IRQ_N7; check IRQ # = PNP_IRQ_N7
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ N7
	cmp	PCNT_interrupt,PNP_IRQ_N8; check IRQ # = PNP_IRQ_N8
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ N8
	cmp	PCNT_interrupt,PNP_IRQ_N13; check IRQ # = PNP_IRQ_N13
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ N13
	cmp	PCNT_interrupt,PNP_IRQ_N14; check IRQ # = PNP_IRQ_N14
	je	short get_pnp_dmairq_ierr; jump, if IRQ # = PNP_IRQ N14
	cmp	PCNT_interrupt,PNP_IRQ_15; check IRQ # > PNP_IRQ_15
	jbe	short get_pnp_dmairq_1	; jump, if IRQ # <= PNP_IRQ 15
ENDIF
get_pnp_dmairq_ierr:
	pop	ax			; balance stack, AX=content of BCR 8
	pop	ax			; balance stack, AX=base PnP ISA I/O address
	mov	ax,ERR_PNP_MIRQ		; error, input conflict(mismatch)
	jmp	short get_pnp_dmairq_error;
get_pnp_dmairq_1:
;
;----------------------------------------
; check user specified IRQ # = PnP setting
;----------------------------------------
;
IFDEF	PACKET
	cmp	int_no,al		; check IRQ # = AL PnP setting
ELSE
	cmp	PCNT_interrupt,al	; check IRQ # = AL PnP setting
ENDIF
	je	short get_pnp_dmairq_3	; jump, if user specified = PnP setting
	;
	pop	ax			; balance stack, AX=content of BCR 8
	pop	ax			; balance stack, AX=base PnP ISA I/O address
	mov	ax,ERR_PNP_MIRQ		; error, input conflict
	jmp	short get_pnp_dmairq_error;
get_pnp_irq_def:
IFDEF	PACKET
	mov	int_no,al		; set PnP ISA interrupt number
ELSE
	mov	PCNT_interrupt,al	; set PnP ISA interrupt number
ENDIF
get_pnp_dmairq_3:
;
;----------------------------------------
; get PnP ISA DMA channel
;----------------------------------------
;
	pop	ax			; restore AX = content of BCR 8
	and	ax,PNPISA_DMASEL_M	; AX = PNP ISA DMA selection
	mov	bx,offset cs:PNPISA_DMA_TABLE; bx = offset to PnP ISA DMA table
	add	bl,al			; index to proper entry
	mov	al,byte ptr cs:[bx]	; get al = PnP ISA DMA #
;
;----------------------------------------
; check user specified PnP ISA DMA channel
;----------------------------------------
;
IFDEF	PACKET
	cmp	dma_no,NULL		; check DMA # = NULL
ELSE
	cmp	PCNT_dma,NULL		; check DMA # = NULL
ENDIF
	je	short get_pnp_dma_def	; jump, if user isn't specified
;
;----------------------------------------
; check user specified PnP DMA channel range
;   DMA = 3,5,6,7
;----------------------------------------
;
IFDEF	PACKET
	cmp	dma_no,ISA_DMA_START	; check user input DMA < START
	jb	short get_pnp_dmairq_derr; jump, if out of lower boundary
	cmp	dma_no,ISA_DMA_END	; check user input DMA > END
	ja	short get_pnp_dmairq_derr; jump, if out of higher boundary
	cmp	dma_no,ISA_DMA_CASCADE	; check user input DMA = CASCADE CHL
	jne	short get_pnp_dmairq_2	; jump, if not equal cascade dma channel
ELSE
	cmp	PCNT_dma,ISA_DMA_START	; check user input DMA < START
	jb	short get_pnp_dmairq_derr; jump, if out of lower boundary
	cmp	PCNT_dma,ISA_DMA_END	; check user input DMA > END
	ja	short get_pnp_dmairq_derr; jump, if out of higher boundary
	cmp	PCNT_dma,ISA_DMA_CASCADE; check user input DMA = CASCADE CHL
	jne	short get_pnp_dmairq_2	; jump, if not equal cascade dma channel
ENDIF
get_pnp_dmairq_derr:
	pop	ax			; balance stack, AX=base PnP ISA I/O address
	mov	ax,ERR_PNP_MDMA		; error, DMA out of range(mismatch)
	jmp	short get_pnp_dmairq_error;
;
;----------------------------------------
; check user specified PnP DMA channel = AL PnP setting
;----------------------------------------
;
get_pnp_dmairq_2:
IFDEF	PACKET
	cmp	dma_no,al		; check DMA # = AL PnP setting
ELSE
	cmp	PCNT_dma,al		; check DMA # = AL PnP setting
ENDIF
	je	short get_pnp_dmairq_4	; jump, if user specified DMA # = PnP setting
	;
	pop	ax			; balance stack, AX=base PnP ISA I/O address
	mov	ax,ERR_PNP_MDMA		; error, input conflict(mismatch)
	jmp	short get_pnp_dmairq_error;
get_pnp_dma_def:
;
;----------------------------------------
; set default PnP DMA channel
;----------------------------------------
;
IFDEF	PACKET
	mov	dma_no,al		; set PnP ISA DMA value
ELSE
	mov	PCNT_dma,al		; set PnP ISA DMA value
ENDIF
get_pnp_dmairq_4:
	pop	ax			; restore AX = base PnP ISA I/O address
get_pnp_dmairq_ok:
	clc				; clear carry flag indicate ok.
	jmp	get_vlisa_irq_exit	; exit
get_pnp_dmairq_error:
	stc				; set carry flag indicate error
get_pnp_dmairq_exit:
	pop	bx			; restore registers
	pop	dx			;
	ret				; return to caller
get_pnp_dmairq	endp			;

;
;-----------------------------------------------------------------------

INIT_ERR_MSG_TABLE	label	word
	dw	init_err0_msg		;  zero init_err message
	dw	init_err1_msg		;  1st init_err message
	dw	init_err2_msg		;  2nd init_err message
	dw	init_err3_msg		;  3rd init_err message
	dw	init_err4_msg		;  4rd init_err message
	dw	init_err5_msg		;  5rd init_err message
	dw	init_err6_msg		;  6rd init_err message
	dw	init_err7_msg		;  7rd init_err message
	dw	init_err8_msg		;  8rd init_err message
	dw	init_err9_msg		;  9rd init_err message
	dw	init_err10_msg		; 10rd init_err message
	dw	init_err11_msg		; 11rd init_err message
	dw	init_err12_msg		; 12rd init_err message
	dw	init_err13_msg		; 13rd init_err message
	dw	init_err14_msg		; 14rd init_err message
	dw	init_err15_msg		; 15rd init_err message
	dw	init_err16_msg		; 16rd init_err message
	dw	init_err17_msg		; 17rd init_err message
	dw	init_err18_msg		; 18rd init_err message
	dw	init_err19_msg		; 19rd init_err message

;
;-----------------------------------------------------------------------
;
;	display_error_message
;
;
;	input	: AX = error message number
;		  DX = non-init error message address
;
;	output	: none
;
;	modify	: none
;
;-----------------------------------------------------------------------
;
display_error_message	proc	near	; display error message
	push	bx			; save registers
	push	ax			;
	push	dx			;
	;
	mov	dx,offset error_header	; DX = error header addr
	mov	ah,09h			; AH = subfunction 9, display string
	int	21h			; DOS function call
	;
	pop	dx			; restore DX=non-init error message addr
	pop	ax			; restore AX = error message number
	push	ax			; save AX = error message number
	push	dx			; save DX=non-init error message addr
	;
	cmp	ax,NINIT_ERR_CNT	; check for non-init error message
	jb	short display_ninit_error; jump, if non-init error message
	sub	ax,NINIT_ERR_CNT	; adjust to first init error message
	mov	bx,offset cs:INIT_ERR_MSG_TABLE; BX = offset to ERROR MESSAGE TABLE
	shl	ax,1			; convert err msg index from byte to word
	add	bx,ax			; BX = entry of error message offset
	mov	dx,word ptr cs:[bx]	; DX = starting point of error string
display_ninit_error:
	mov	ah,09h			; AH = subfunction 9, display string
	int	21h			; DOS function call
	;
	mov	ah,08h			; AH = subfunction 9, char in no echo
	int	21h			; DOS function call
	or	al,al			; extended ASCII ?
	jnz	short display_error_mesg_exit; no, jump exit
	;
	mov	ah,08h			; AH = subfunction 9, char in no echo
	int	21h			; DOS function call
	;				; clear extended ASCII char code
display_error_mesg_exit:
	pop	dx			; restore registers
	pop	ax			;
	pop	bx			;
	ret				; return to caller
display_error_message	endp		;


;
;-----------------------------------------------------------------------
;
;	check_oem2
;
;
;	input	: none
;
;	output	: none
;
;	modify	: b_oem2 = OEM_2 if OEM 2 manufacture found
;
;-----------------------------------------------------------------------
;
check_oem2	proc	near		; OEM checking, OEM 2 for now
	push	di			; save registers
	push	si			;
	push	es			;
	push	ax			;
	push	cx			;
	push	dx
;
;----------------------------------------
; check EISA signature
;----------------------------------------
;
	cld				; ensure direction
	mov	di,EISA_SIGN_OFST	; DI = BIOS signature string location
	mov	cx,BIOS_SEGMENT		; CX = BIOS segment
	mov	es,cx			; ES = BIOS segment
	mov	si,offset cs:eisa_sign_str; eisa signature string
	mov	cx,EISA_SIGN_LEN	; CX = EISA signature length
	repe	cmpsb			; check EISA signature string
	jne	short check_oem2_exit	; jump, if no EISA signature
;
;----------------------------------------
; check slot 0 vendor ID
;----------------------------------------
;
	mov	dx,OEM_2_S0ID_PORT	; OEM EISA slot 0 ID PORT
	in	ax,dx			; AX = vender ID
	cmp	ax, OEM_2_EISA_VID	; check OEM 2 vender ID
	jne	short check_oem2_exit	; jump, if not oem
;
;----------------------------------------
; check product ID
;----------------------------------------
;
	inc	dx			; increment DX
	inc	dx			; increment DX
	in	ax,dx			; AX = product ID
	cmp	ax,OEM_2_VL_PID		; check OEM 2 product ID
	jne	short check_oem2_exit	; jump, if not OEM
;
;----------------------------------------
; update OEM information bytes
;----------------------------------------
;
	mov	b_oem2,OEM_2		; set b_oem2 = OEM_2 exist
;
;----------------------------------------
; check for multiple board
;----------------------------------------
;
	mov	b_oem2_enable,OEM_2_EN	; set b_oem2_enable = enable

check_oem2_exit:
	pop	dx
	pop	cx			;
	pop	ax			;
	pop	es			;
	pop	si			; restore registers
	pop	di			;
	ret
check_oem2	endp			; OEM checking


;----------------------------------------
; PCI BIOS equates
;----------------------------------------
;
PCI_FUNCTION_ID_1	equ	0b0h	; PCI BIOS spec version 1
PCI_FUNCTION_ID_2	equ	0b1h	; PCI BIOS spec version 2
PCI_BIOS_PRESENT	equ	01h	; PCI BIOS present
FIND_PCI_DEVICE		equ	02h	; PCI device search
READ_CONFIG_BYTE	equ	08h	; PCI configuration space byte read
READ_CONFIG_WORD	equ	09h	; PCI configuration space word read
READ_CONFIG_DWORD	equ	0ah	; PCI configuration space dword read
WRITE_CONFIG_BYTE	equ	0bh	; PCI configuration space byte write
WRITE_CONFIG_WORD	equ	0ch	; PCI configuration space word write

PCI_BIOS_NOT_SUPPORT	equ	81h	; PCI BIOS not support
;
;----------------------------------------
; data area
;----------------------------------------
;
PCI_BIOS		db	0	; PCI BIOS version
PCI_MECHANISM		db	2	; hardware mechanism of PCI 

;
;-----------------------------------------------------------------------
; PCI_BIOS_API : This routine use PCI BIOS API to detect AMD PCI PCnet device
;
; Input		: None
; Output	: Carry flag set, AL = 81h, no PCI BIOS API interface
;		: Carry flag set, AL = 0h, PCI BIOS exist, no PCI PCnet dev
;		: Carry flag clear, indicate AMD PCI PCnet device found
;		  AH = IO address
;		  BX = IRQ #, hardware ID
;
; Modified	: AX, BX
;
;-----------------------------------------------------------------------
;
pci_bios_api	proc	near		;
	push	cx			; save registers
	push	edx			;
	push	di
	push	si
;
;--------------------------------
; test PCI BIOS spec version 2 interface
;--------------------------------
;
	xor	bx,bx			; cleanr BX
	xor	cx,cx			; cleanr CX
	xor	edx,edx			; clear EDX
	mov	ah,PCI_FUNCTION_ID_2	; assume PCI BIOS spec version 2
	mov	al,PCI_BIOS_PRESENT	; request for PCI BIOS support
	int	1ah			; PCI BIOS interface
;
;--------------------------------
; check return value from PCI BIOS spec version 2
;--------------------------------
;
	jc	short check_PCI_BIOS_ver1; jump, if carry set
					;
	cmp	edx," ICP"		; check for PCI signature
	jne	short check_PCI_BIOS_ver1; jump, if PCI BIOS version is not 2
					;
	or	ah,ah			; check present status
	jnz	short no_PCI_BIOS	; jump, if no PCI BIOS present
					;
	mov	PCI_BIOS,2		; set PCI BIOS version = 2
	jmp	short get_hardware_mechanism; jump, get hardware mechanism
check_PCI_BIOS_ver1:
;
;--------------------------------
; test PCI BIOS spec version 1 interface
;--------------------------------
;
	xor	cx,cx			; cleanr CX
	xor	dx,dx			; clear DX
	mov	ah,PCI_FUNCTION_ID_1	; assume PCI BIOS spec version 2
	mov	al,PCI_BIOS_PRESENT	; request for PCI BIOS support
	int	1ah			; PCI BIOS interface
;
;--------------------------------
; check return value from PCI BIOS spec version 1
;--------------------------------
;
	jc	short no_PCI_BIOS	; jump, if carry set
					;
	cmp	dx,"CP"			; check for PCI signature
	jne	short no_PCI_BIOS	; jump, if no PCI BIOS present
	cmp	cx," I"			; check for PCI signature
	jne	short no_PCI_BIOS	; jump, if no PCI BIOS present
					;
	mov	PCI_BIOS,1		; set PCI BIOS version = 1
	jmp	short get_hardware_mechanism; jump, get hardware mechanism
no_PCI_BIOS:
;
;--------------------------------
; no PCI BIOS exist
; return with carry flag and AL = PCI_BIOS_NOT_SUPPORT
;--------------------------------
;
	mov	al,PCI_BIOS_NOT_SUPPORT	;
	stc				;
	jmp	done			; exit
get_hardware_mechanism:
;
;--------------------------------
; get PCI hardware mechanism(default as mechanism 2)
; (assume mechanism 2 for PCI BIOS ver1)
;--------------------------------
;
	cmp	PCI_BIOS,1		; check PCI BIOS version	1
	jz	short PCI_mechanism_set	; jump, assume PCI mechanism 2
					;
	cmp	al,1			; check PCI mechamism,if PCI BIOS ver2
	jnz	short PCI_mechanism_set	; jump, if mechanism 2(default)
					;
	mov	PCI_MECHANISM,1		; set PCI mechanism as 1
PCI_mechanism_set:
;
;--------------------------------
; search AMD PCI devices
;
;  search AMD PCI PCNet devices 
;  device index(SI)
;--------------------------------
;
	xor	si,si			; SI = 0 (index initialize)
	mov	cx,PCI_PCNET_MASK	; CX = 0FFF0h
	neg	cx			; CX = # of AMD PCnet PCI device ID
search_PCI_device:
	push	cx			; save # of AMD PCnet PCI device ID
	dec	cx			; CX = adjust from largestw value
	mov	dx,AMD_VENDOR_ID	; DX = AMD vender ID
	add	cx,PCNET_PCI_ID		; CX = PCI PCNet device ID
	mov	ah,PCI_FUNCTION_ID_1	; assume BH = PCI BIOS spec version 1
	cmp	PCI_BIOS,1		; check PCI BIOS version = 1
	je	short PCI_BIOS_version_set; jump, if PCI BIOS version determined
	mov	ah,PCI_FUNCTION_ID_2	; BH = PCI BIOS spec version 2
PCI_BIOS_version_set:
;
;--------------------------------
; find AMD PCI device through BIOS API
;--------------------------------
;
	mov	al,FIND_PCI_DEVICE	; request for AMD PCI device
	int	1ah			; PCI BIOS interface
	pop	cx			; restore # of AMD PCnet PCI device ID
	jnc	short PCI_device_found	; find PCI device
	loop	search_PCI_device	; keep on searching
	jmp	search_fail		; jump, if search fail
PCI_device_found:			;
	cmp	PCI_BIOS,1		; check PCI BIOS version = 1
	je	short PCI_BIOS_version1	; jump, if PCI BIOS version 1
					;
	or	ah,ah			; check search successful
	jnz	short search_fail	; jump, if search fail
PCI_BIOS_version1:
;
;--------------------------------
; AMD PCNet PCI device found
;--------------------------------
;
	mov	ah,PCI_FUNCTION_ID_1	; assume BH = PCI BIOS spec version 1
	cmp	PCI_BIOS,1		; check PCI BIOS version = 1
	je	short PCI_BIOS_version_set1; jump, if PCI BIOS version determined
	mov	ah,PCI_FUNCTION_ID_2	; BH = PCI BIOS spec version 2
PCI_BIOS_version_set1:
	mov	dh,ah			; save DH = PCI BIOS spec version
;
;--------------------------------
; read IRQ from PCI config space through BIOS API
;--------------------------------
;
	mov	di,PCI_ITREG_OFF	; DI = IRQ offset in PCI config space
	mov	al,READ_CONFIG_BYTE	; read the config byte
	int	1ah			; PCI BIOS interface
					;
	jc	short search_fail	; can read PCI device
					;
	mov	dl,cl			; save DL = IRQ # 
;
;--------------------------------
; read IO address from PCI config space through BIOS API
;--------------------------------
;
	mov	ah,dh			; AH = PCI BIOS spec version
	mov	di,PCI_BAREG_OFF	; DI = base offset in PCI config space
	mov	al,READ_CONFIG_WORD	; read the config word
	int	1ah			; PCI BIOS interface
					;
	jc	short search_fail	; can read PCI device
;
;--------------------------------
; check PCI device enable
; if and only if (IO address != 0) & (command register IO space == 1)
;    then PCI device enable
;--------------------------------
;
	or	cx,cx			; check IO address != 0
	jz	short search_fail	; jump, if PCI device disable
IFDEF	PH_GGA0
	and	cx,GG_IO_BASE_MASK	; mask off bit 0(stuck high)
ENDIF
	mov	si,cx			; SI = IO address
;
;--------------------------------
; read Command register from PCI config space through BIOS API
;--------------------------------
;
	mov	ah,dh			; AH = PCI BIOS spec version
	mov	di,PCI_CDREG_OFF	; DI = command reg offset in PCI conf
	mov	al,READ_CONFIG_BYTE	; read the config byte
	int	1ah			; PCI BIOS interface
	jc	short search_fail	; can't read PCI device

	test	cl,PCI_IO_ENABLE	; check PCI IO space enable
	jz	short search_fail	; jump, if IO space disable
;
;--------------------------------
; write Command register for PCI config space through BIOS API
;--------------------------------
;
	or	cl,PCI_CREG_DEF		; CL = default(enable bus master)
	mov	ah,dh			; AH = PCI BIOS spec version
	mov	di,PCI_CDREG_OFF	; DI = command reg offset in PCI conf
	mov	al,WRITE_CONFIG_BYTE	; write the config byte
	int	1ah			; PCI BIOS interface
	jc	short search_fail	; can't read PCI device
;
;--------------------------------
; write status register for PCI config space through BIOS API
;--------------------------------
;
	mov	cx,PCI_SREG_DEF		; CL = default command register
	mov	ah,dh			; AH = PCI BIOS spec version
	mov	di,PCI_STREG_OFF	; DI = status reg offset in PCI conf
	mov	al,WRITE_CONFIG_WORD	; write the config word
	int	1ah			; PCI BIOS interface
	jc	short search_fail	; can't read PCI device
;
;----------------------------------------
; clear hardware latch avoid ground bouncing
; (Since we don't have control over BIOS, hopefully, it works)
;----------------------------------------
;
	xor	cx,cx			; CX = clear
	mov	ah,dh			; AH = PCI BIOS spec version
	mov	di,PCI_VENID_OFF	; DI = vendor ID offset in PCI conf
	mov	al,WRITE_CONFIG_WORD	; write the config word
	int	1ah			; PCI BIOS interface
	;
	xor	cx,cx			; CX = clear
	mov	ah,dh			; AH = PCI BIOS spec version
	mov	di,PCI_DEVID_OFF	; DI = device ID offset in PCI conf
	mov	al,WRITE_CONFIG_WORD	; write the config word
	int	1ah			; PCI BIOS interface
;
;----------------------------------------
; check "WW" signature
;	EEPROM checksum(0h - bh & 0eh - 0fh)
; get	hardware ID
;----------------------------------------
;
	mov	ax,si			; AX = IO address
	call	check_device_info	; get BL = hardware ID if no error
	jc	short search_fail	; jump, if search fialed
;
;--------------------------------
; setup return format 
; AX = IO address, BH, BL = IRQ #, hardware ID
;--------------------------------
;
	mov	bh,dl			; BH = IRQ #
	;
	clc				; clear carry flag
	jmp	short done		; complete
search_fail:
;
;--------------------------------
; no AMD PCI device found, through PCI BIOS API
; return with carry flag and AL = 0
;--------------------------------
;
	xor	al,al			; clear AL
	stc				; indicate search fail
done:
;
;--------------------------------
; complete, done
;--------------------------------
;
	pop	si			; restore registers
	pop	di			; 
	pop	edx			;
	pop	cx			;
	ret
pci_bios_api	endp

code	ends

	end
;-----------------------------------------------------------------------

