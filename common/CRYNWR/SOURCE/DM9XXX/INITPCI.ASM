;*****************************************************************************
;* Name : INITPCI.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description :
;*	. Calls the PCI BIOS to find DM9100 handle & configure information.
;*	. Store io_addr, int_no & ChipRev.
;*
;* Functions :
;*	. initpci
;*	. InitAdapterProbe
;*	. InitPCICheckBIOS
;*	. InitPCIFindDevice
;*	. InitPCIGetPCIID
;*	. InitPCIGetBase
;*	. InitDM9100RegOffsets
;*	. PCIResourceCheck
;*	. InitConfigRegRead
;*	. InitConfigRegWrite
;*	. GetAdapterConfig
;*	. InitPrintMessage
;*	. InitPrintHexByte
;*	. InitScanPCIBus
;*	. AllocatePhysicalBlock
;*
;* Author : Spenser Tsai
;*
;* Date : 05/17/96'
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
; 2000.7.18	htho	enable PnP OS in BIOS will disable I/O Space Access
;
;*
;*****************************************************************************
	.Model	TINY
	.386

;   +-------------------------------------------------------------------+
;   |		      P C I   B I O S	S E R V I C E S 		|
;   +-------------------------------------------------------------------+
;
; The following constants define the PCI BIOS calling interface
;

PCI_BIOS_INT			EQU  1Ah	; "int" interface to PCI BIOS

PCI_FUNCTION_ID 		EQU  0B1h
PCI_BIOS_PRESENT		EQU  001h
PCI_FIND_PCI_DEVICE		EQU  002h
PCI_FIND_PCI_CLASS_CODE 	EQU  003h
PCI_GENERATE_SPECIAL_CYCLE	EQU  006h
PCI_READ_CONFIG_BYTE		EQU  008h
PCI_READ_CONFIG_WORD		EQU  009h
PCI_READ_CONFIG_DWORD		EQU  00Ah
PCI_WRITE_CONFIG_BYTE		EQU  00Bh
PCI_WRITE_CONFIG_WORD		EQU  00Ch
PCI_WRITE_CONFIG_DWORD		EQU  00Dh

PCI_CLASS_CODE_ETHER_CTRL   EQU  000020000h

;   +-------------------------------------------------------------------+
;   |		P C I	 D E V I C E S	   I N F O R M A T I O N	|
;   +-------------------------------------------------------------------+
;
; The following defines attributes and data regarding several PCI devices.
;

; Two Intel Host-to-PCI bridges' (PCI) device ID
iCDC_82424_ID			EQU  0483h
iPCMC_82434_ID			EQU  04A3h

;;include hw.inc
include hardware.asd
include rtdata.inc

;---------------------------------------------------------------------------

code	segment para public
	assume	cs:code, ds:code

extern	io_addr : word
extern	int_no	: byte
EXTRN	free_mem : WORD

PCIIDVal		 DD 0  ; The value that was read from PCIID


	PUBLIC PCIHandle
PCIHandle DW 0	       ; This word is a catenation of the PCI bus number and
		       ; PCI device number. These two bytes are passed to
		       ; each PCI BIOS call, and uniquely identify the adapter.
		       ; This value is determined at init time when probing
		       ; for the adapter, or verifying a user specified
		       ; devlice number.

;
; The PIC variables control access to the PIC chip. The PIC chip handles the
; delivery of hardware interrupts to the CUP in an Intel based PC AT/XT. The
; IRQ of the adapter is determined at init time, in the GetAdapterConfig
; function in the module MACINIT.ASM

		PUBLIC ChipRev
ChipRev 	DB ?	; chip revision, read from PCIRV register at init time
InitConfigCR6Dummy     DD ?    ; CR6  value from EISA BIOS

InitHexByteTable   DB "0123456789ABCDEF" ; Translation table for InitPrintHexByte

;
; Driver Messages
;

CR EQU 0Dh	; ASCII Carriage Return
LF EQU 0Ah	; ASCII Line Feed
InitMsg_no_adap     DB 'DM9 - Could not locate adapter, please insert DM9 card.',CR,LF
InitMsg_no_adap_len EQU $ - InitMsg_no_adap
InitMsg_bad_slot_id	DB 'Could not locate adapter at specified SLOT.',CR,LF
InitMsg_bad_slot_id_len EQU $ - InitMsg_bad_slot_id
InitMsg_error	    DB 'MAC Init Error: '
InitMsg_error_len   EQU $ - InitMsg_error
InitMsg_PCI_PCIINT   DB 'PCI BIOS configured IRQ illegal for Intel platform.',CR,LF
InitMsg_PCI_PCIINT_len	EQU $ - InitMsg_PCI_PCIINT
InitMsg_PCI_PCIIO   DB 'PCI BIOS configured I/O base illegal for Intel platform.',CR,LF
InitMsg_PCI_PCIIO_len  EQU $ - InitMsg_PCI_PCIIO
InitMsg_PCI_PCICS   DB 'PCI BIOS failed to enable I/O operation.',CR,LF
InitMsg_PCI_PCICS_len  EQU $ - InitMsg_PCI_PCICS
;;----------------------------------------------------------------------------

;--------------------------------------------------------------------+
; Name : initpci
;
; Description:
; Call the Probe function, which probes PCI space looking for the adapter,
; and returns the IO base address in AX.
;
;
; Enter :
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC initpci
initpci PROC
	push	es
	push	si
	push	bx
	push	cx
idi_probe_for_adapter:

	call InitAdapterProbe		;; Get PCIhandle & io_addr
	cmp  ax, 0			;; If ax=1 is not found, exit with error
	jz   idi_adapter_found
	mov  ax, OFFSET InitMsg_no_adap
	mov  bx, InitMsg_no_adap_len
	jmp  idi_error

idi_adapter_found:
	call InitDM9100RegOffsets      ;;Initialize DM9 register offsets

	call PCIResourceCheck	      ;    Check PCI configuration
	jc  idi_error		      ;    If carry set, AX and BX are set
				      ;    with appropriate error message.
				      ;    Abort Init, perint error.

idi_get_info:
;;	  call GetAdapterConfig       ;    Get Adapter Configuration
					;; Get int_no & ChipRev
;;	  or   ax, ax			  ;    was it successful?
;;	  jne  idi_slot_bad		  ;    branch if not

	mov	ax, 0
	jmp  idi_exit

;;idi_slot_bad:
;;	  mov  ax, OFFSET InitMsg_bad_slot_id
;;	  mov  bx, InitMsg_bad_slot_id_len

idi_error:
	mov  si, OFFSET InitMsg_error
	mov  cx, InitMsg_error_len
	call InitPrintMessage
	mov  si, ax
	mov  cx, bx
	call InitPrintMessage
	mov	ax, 0ffffh
idi_exit:
	pop cx
	pop bx
	pop si
	pop es
	ret
initpci ENDP


;--------------------------------------------------------------------+
; Name : InitAdapterProbe
;
; Description: Get the PCI handle & I/O Base address of device.
;
; Enter :
; Return :
;	Success  - AX=0.
;	Failure  - AX=1.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
	PUBLIC InitAdapterProbe
InitAdapterProbe  PROC	NEAR

	push cx

	call InitPCICheckBIOS	;;PCI BIOS is present?
	jc   iap_error_exit	;;Not present
	mov  ax, 0		;
	call InitPCIFindDevice	;;Is DM9 Device ID ? return AX = PCI Handle
	jc   iap_error_exit	;;Not found DM9
	mov  PCIHandle, ax	;;Save PCI Handle
	call InitPCIGetBase	;;Get IO base address  ;;Reurn IO Base in AX
	jc   iap_error_exit
	mov	io_addr, ax
	mov  ax, 0		;; Return value
	jmp  SHORT iap_exit
iap_error_exit:
	mov  ax, 1		;    return(AX==1)
iap_exit:
	pop cx
	ret
InitAdapterProbe  ENDP


;--------------------------------------------------------------------+
; Name : InitPCICheckBIOS
;
; Description: Checks for the existance of the PCI BIOS.
;
; Enter : None
;
; Return :
;	Carry flag clear - PCI BIOS present.
;	Carry flag set	 - PCI BIOS not present
;
; Destroied registers :
;
;---------------------------------------------------------------------+
InitPCICheckBIOS  PROC	NEAR
	push ax
	push bx
	push cx
	push edx
	push es

	mov  ah, PCI_FUNCTION_ID	;; 0B1h
	mov  al, PCI_BIOS_PRESENT	;; 01h
	int  PCI_BIOS_INT

	jc   ipcb_exit					;;PCI BIOS is't present

	or   ah, ah		   ; AH should be 0
	jnz  ipcb_error_exit

	cmp  edx, ' ICP'           ; Check for 'PCI ' string in EDX
	jne  ipcb_error_exit

	clc			   ; Signal success
	jmp  ipcb_exit

ipcb_error_exit:
	stc

ipcb_exit:
	pop  es
	pop  edx
	pop  cx
	pop  bx
	pop  ax
	ret
InitPCICheckBIOS  ENDP

;--------------------------------------------------------------------+
; Name : InitPCIFindDevice
;
; Description: Calls the PCI BIOS routin to get the board PCI index in AX.
;
; Enter :
;
; Return :
;	Carry flag clear - Device found, handle is in AX.
;	Carry flag set	 - Device not found.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
InitPCIFindDevice  PROC  NEAR

	push bx
	push ecx
	push dx
	push si
	push di

;;-+, 980311, Hu-Tiong
;;	mov  dx, ax	; dx will keep the DM9100 board PCI
;;			; index
	extrn	SlotNum: word

	cmp	SlotNum, 0
	je	UserNotSpecifySlot

	dec	SlotNum
UserNotSpecifySlot:
;;-+
	mov  si,  0	; SI = PCI Device Index (include other
			; vendors card)
	mov  di,  0	; DI = Current DM9100 board
			; existance index

ipfd_find_dev_loop:
	mov  ecx, PCI_CLASS_CODE_ETHER_CTRL	; ECX = Class code of ethernet
						; controller (000020000h)
	mov  ah, PCI_FUNCTION_ID
	mov  al, PCI_FIND_PCI_CLASS_CODE	;; 03h
	int  PCI_BIOS_INT

	jc   ipfd_exit

	mov  ax, bx		   ; BX holds PCI handle on successful exit

	call InitPCIGetPCIID	    ; Check if DM9100, Return ECX = PCIID

	mov  PCIIDVal, ecx	    ; Get PCIIDVal
;;cmp	  cx, 1011h
;;je	  ipfd_check_dev_id
	cmp  cx, PCIID_VENDOR_ID  ; Not DEC vendor ID (1011h)
	je   ipfd_check_dev_id
	inc  si
	jmp  ipfd_find_dev_loop

ipfd_check_dev_id:
	and  ecx, PCIID_M_DEVICE_ID	   ; Check device ID (0FFFF0000h)
	shr  ecx, PCIID_V_DEVICE_ID	 ;; 16

;;cmp	  cx, 0009h
;;jne	  ipfd_check_DM9102_id
;;mov	  ChipType, DC21X4_CHIP
;;jmp	  pfd_find

ipfd_check_DM9102_id:
	cmp	cx, PCIID_DM9102_DEVICE_ID
	jne	ipfd_check_UM9100_id
	mov	ChipType, DM9102_CHIP
	jmp	pfd_find

ipfd_check_UM9100_id:
	cmp  cx,  PCIID_DM9100_DEVICE_ID ; Check 90100 device ID (00009h)
	jne   pfd_not_find_DM9100
	mov	ChipType, DM9100_CHIP
	jmp	pfd_find

pfd_not_find_DM9100:
	cmp	cx, PCIID_DM9009_DEVICE_ID
	jne	 pfd_not_find_DM9009
	mov	ChipType, DM9009_CHIP
	jmp	pfd_find

pfd_not_find_DM9009:
	inc  si
	jmp  ipfd_find_dev_loop

pfd_find:
;;-+, 980311, Hu-Tiong
;;	cmp	di, dx			;;Check device slot if multi-adapters
	cmp	di, SlotNum
;;-+
	je	ipfd_signal_success
	inc	di
	inc	si
	jmp	ipfd_find_dev_loop


ipfd_signal_success:
;;;;++, 2000.7.18, htho, enable PnP OS in BIOS will disable I/O Space Access
	push	ax			; preserve the PCI handle

	mov	bx, ax
	mov	ah, PCI_FUNCTION_ID
	mov	al, PCI_READ_CONFIG_DWORD
	mov	di, 4			; PCI Command & Status Register */
	int	PCI_BIOS_INT

;	or	ecx, (PCICS_M_BUS_MASTER OR PCICS_M_MEMORY_ACCESS OR PCICS_M_IO_ACCESS)
	or	ecx, 7
	pop	bx
	push	bx
	mov	ah, PCI_FUNCTION_ID
	mov	al, PCI_WRITE_CONFIG_DWORD
	mov	di, 4			; PCI Command & Status Register */
	int	PCI_BIOS_INT

	pop	ax			; restore the PCI handle
;;;;++
	clc			   ; Signal success

	jmp  ipfd_exit

ipfd_error_exit:
	stc

ipfd_exit:
	pop  di
	pop  si
	pop  dx
	pop  ecx
	pop  bx
	ret
InitPCIFindDevice  ENDP

;--------------------------------------------------------------------+
; Name : InitPCIGetPCIID
;
; Description: Get the PCIID value of the device.
;
; Enter : AX = Handle of device.
;
; Return :
;	Carry flag clear - Success, PCIID in ECX.
;	Carry flag set	 - Failure.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
InitPCIGetPCIID  PROC  NEAR
	push eax
	push bx
	push di

	mov  bx, ax			;; PCI Handler
	mov  di, HW_K_REG_PCIID      ;; 00h
	mov  ah, PCI_FUNCTION_ID	;; 0B1h
	mov  al, PCI_READ_CONFIG_DWORD	;; 0Ah
	int  PCI_BIOS_INT		;; 1Ah

	jc   ipgc_exit

	clc			   ; Signal success

	jmp  ipgc_exit

ipgc_error_exit:
	stc

ipgc_exit:
	pop  di
	pop  bx
    pop eax
	ret
InitPCIGetPCIID  ENDP

;--------------------------------------------------------------------+
; Name : InitPCIGetBase
;
; Description: Calls the PCI BIOS to get IO base address.
;
; Enter : AX = Handle of device.
;
; Return :
;	Carry flag clear - Success, IO Base is in AX.
;	Carry flag set	 - Failure.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
InitPCIGetBase	PROC  NEAR
	push bx
	push ecx
	push di

	mov  bx, ax			;; Handle
	mov  di, HW_K_REG_PCIIO      ;; 10h
	mov  ah, PCI_FUNCTION_ID
	mov  al, PCI_READ_CONFIG_DWORD
	int  PCI_BIOS_INT

	jc   ipgb_exit

	and  ecx, PCIIO_M_PCI_IO_BASE_ADDRESS	     ;;(0FFFFFF80h)

	mov  ax, cx

	clc			   ; Signal success

	jmp  ipgb_exit

ipgb_error_exit:
	stc

ipgb_exit:
	pop  di
	pop  ecx
	pop  bx
	ret
InitPCIGetBase	ENDP

;--------------------------------------------------------------------+
; Name : InitDM9100RegOffsets
;
; Description: Sets up pointers to DM9100's registers.
;
; Enter : io_addr
;
; Return :
; Destroied registers :
;
;---------------------------------------------------------------------+
InitDM9100RegOffsets  PROC NEAR
	push  ax
	mov	ax, io_addr

itro_pci_init:
	mov   p_CR0, ax
	add   p_CR0, HW_K_REG_CR0
	mov   p_CR1, ax
	add   p_CR1, HW_K_REG_CR1
	mov   p_CR2, ax
	add   p_CR2, HW_K_REG_CR2
	mov   p_CR3, ax
	add   p_CR3, HW_K_REG_CR3
	mov   p_CR4, ax
	add   p_CR4, HW_K_REG_CR4
	mov   p_CR5, ax
	add   p_CR5, HW_K_REG_CR5
	mov   p_CR6, ax
	add   p_CR6, HW_K_REG_CR6
	mov   p_CR7, ax
	add   p_CR7, HW_K_REG_CR7
	mov   p_CR8, ax
	add   p_CR8, HW_K_REG_CR8
	mov   p_CR9, ax
	add   p_CR9, HW_K_REG_CR9
	mov   p_CR10, ax
	add   p_CR10, HW_K_REG_CR10
	mov   p_CR11, ax
	add   p_CR11, HW_K_REG_CR11
	mov   p_CR12, ax
	add   p_CR12, HW_K_REG_CR12
	mov   p_CR13, ax
	add   p_CR13, HW_K_REG_CR13
	mov   p_CR14, ax
	add   p_CR14, HW_K_REG_CR14
	mov   p_CR15, ax
	add   p_CR15, HW_K_REG_CR15

	mov   p_PCIID, HW_K_REG_PCIID
	mov   p_PCICS, HW_K_REG_PCICS
	mov   p_PCIRV, HW_K_REG_PCIRV
	mov   p_PCILT, HW_K_REG_PCILT
	mov   p_PCIIO, HW_K_REG_PCIIO

itro_exit:
	pop   ax
	ret
InitDM9100RegOffsets  ENDP

;--------------------------------------------------------------------+
; Name : PCIResourceCheck
;
; Description:
; This routine checks the following:
;
; 1) Configured interrupt level is between 0 and 15. The PCI PCIINT register
;    allows 8 bits to encode the interrupt level. On an Intel platform, we
;    should never see a value larger than 15. Should a larger value be
;    programmed, driver init is aborted, and the user notified.
;
; 2) Base I/O address is no larger than 0FFFFh. The PCI PCIIO register allows
;    for a 32 bit I/O base address. On an Intel platform, the I/O address space
;    is limited to 16 bits. Should PCI BIOS neglect to initialize the upper
;    sixteen bits <31:16> to zero, the card would be unaccessible, since the
;    IO address decoding would be screwed up. If this error occurrs, init is
;    aborted, and the user notified.
;
; 3) Bus Master operation and I/O space access should be enabled. The PCI
;    PCICS register has two fields of interest here. The DM9100 adapter
;    requires the Bus Master Operation bit to be asserted, as well as the
;    I/O Space Access bit. Should either of these bits be deasserted, driver
;    init is aborted, and the user notified.
;
; Enter : None
;
; Return :
;	Success - Carry Clear.
;	Failure - Carry Set, AX points to error message, BX is length.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
PCIResourceCheck  PROC	NEAR
	;; Save Interrupt level in AL
	mov  dx, HW_K_REG_PCIINT
	call InitConfigRegRead		   ; Read PCIINT, return in EAX
	and  eax, PCIINT_M_INTERRUPT_LINE    ;; (0000000FFh)
	cmp  al, 0fh			   ; Is interrupt out of range?
	jbe  set_pic		      ; No.
	mov  ax, OFFSET InitMsg_PCI_PCIINT   ; Yes. Get ptr to error message
	mov  bx, InitMsg_PCI_PCIINT_len
	stc				   ; signal error...
	jmp  ipsc_exit			   ; ...and exit

set_pic:
	mov	int_no, al		;; Store IRQ
	cmp  ax, 5		       ; Are we at IRQ5?
	jne  slave_int		   ; Nope, then we have a slave interrupt
	mov  PICIntOff,   020h	       ; For IRQ5, set the OFF mask...
	mov  PICIntOn,	  0DFh	       ; ...and the ON mask
	mov  PICIntMask,  021h	       ; The mask register is in the MASTER PIC
	mov  PICAckSlave, 000h	       ; And we don't have to ACK the slave
	jmp  pic_done

slave_int:
	sub  ax, 8		       ; For slave convert 8->15 to 0->7
	mov  cx, ax		       ; load the 0->7 value into CX as a count
	mov  ax, 1		       ; Init AL to 00000001
	shl  ax, cl		       ; and shift AL CL times
	mov  PICIntOff,   al	       ; AL now holds OFF mask
	not  al 		       ; complement AL to make ON mask
	mov  PICIntOn,	  al	       ; and save it
	mov  PICIntMask,  0A1h	       ; The mask register is in the SLAVE PIC
	mov  PICAckSlave, 001h	       ; And we DO name to ACK the slave

pic_done:
	mov  dx, p_PCIRV		; -> chip revision register
	call InitConfigRegRead	       ; read it
	mov  ChipRev, al	       ; save chip revision level

ipsc_PCIINT_ok:
	mov  dx, HW_K_REG_PCIIO
	call InitConfigRegRead		   ; Read PCIIO ;;return in EAX
	test eax, 0FFFF0000h		   ; Is IO Base address out of range?
	jz   ipsc_PCIIO_ok		    ; No.
	mov  ax, OFFSET InitMsg_PCI_PCIIO   ; Yes. Get ptr to error message
	mov  bx, InitMsg_PCI_PCIIO_len
	stc				   ; signal error...
	jmp  ipsc_exit			   ; ...and exit

ipsc_PCIIO_ok:
	mov  dx, HW_K_REG_PCICS
	call InitConfigRegRead		   ; Read PCICS
	or   eax, PCICS_M_BUS_MASTER  ; Turn on bus master bit (000000004h)
	call InitConfigRegWrite 	   ; Write it to configuration space

	test eax, PCICS_M_IO_ACCESS	    ; Is IO Access bit clear?(00000001h)
	jz   ipsc_PCICS_error		    ; Yes, signal error
	clc				   ; Both bits set, signal success...
	jmp  ipsc_exit			   ; ...and exit
ipsc_PCICS_error:
	mov  ax, OFFSET InitMsg_PCI_PCICS   ; Error(s). Get ptr to error message
	mov  bx, InitMsg_PCI_PCICS_len
	stc				   ; signal error and exit
ipsc_exit:
	ret
PCIResourceCheck  ENDP

;*********************
;* InitConfigRegRead *
;*********************
;
; This function determines the bus in use, and takes the appropriate action
; for reading the configuration register pointed to by DX. The retults are
; returned in EAX. All other registers preserved.
;
; Algorithm:
; BEGIN
;    if (PCIBus flag set)
;	Make PCI BIOS call
;    else
;	Issue IN instruction
;    return (EAX)
; END

		   PUBLIC InitConfigRegRead
InitConfigRegRead  PROC  NEAR
icrr_pci_read:
	push ecx			      ; For PCI bus, issue BIOS call
	push bx
	push di

	mov  ah, PCI_FUNCTION_ID
	mov  al, PCI_READ_CONFIG_DWORD
	mov  bx, PCIHandle
	mov  di, dx
	and  di, 0FFh			      ; PCI Offset = DX and 00FF
	int  PCI_BIOS_INT

	mov  eax, ecx
	pop  di
	pop  bx
	pop  ecx
	jmp  icrr_exit
icrr_exit:
	ret
InitConfigRegRead  ENDP

;**********************
;* InitConfigRegWrite *
;**********************
;
; This function writes to the device's configuration space.
; It writes the contents of EAX into register pointed to by DX.
; All other registers are preserved.
;
; Algorithm:
; BEGIN
;     if (PCIBus flag set)
;	 make PCI Bios call
;     else
;	 Issue OUT instruction
; END

		PUBLIC InitConfigRegWrite
InitConfigRegWrite  PROC  NEAR
icrw_pci_write:
	push ecx
	push bx
	push di
	mov  ecx, eax
	mov  ah, PCI_FUNCTION_ID
	mov  al, PCI_WRITE_CONFIG_DWORD
	mov  bx, PCIHandle
	mov  di, dx
	and  di, 0FFh			      ; PCI Offset = DX and 00FF

	int  PCI_BIOS_INT

	pop  di
	pop  bx
	pop  ecx
	jmp  icrw_exit

icrw_eisa_write:
	out   dx, eax			       ; For EISA bus, just do an OUT

icrw_exit:
	ret
InitConfigRegWrite  ENDP


;--------------------------------------------------------------------+
; Name : GetAdapterConfig
;
; Description: Extract the configuration information for the DM9100.
;
; Enter :
;
; Return :
;	Success - AX=0.
;	Failure - AX = None-Zero.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
GetAdapterConfig  PROC NEAR
	push bx
	push cx
	push di
	push si
	push eax

;
; For PCI Bus, read the PCIINT register, and verify that the configured interrupt
; is in the range of 0-15. The interrupt read from the register is the actual
; interrupt level, and needs no decoding. There is no sanity check on the
; value done here. PCI values are sanity checked in a separate routine.
; InitPCISanityCheck
;
	mov  dx, HW_K_REG_PCIINT	 ; Read PCI PCIINT to get int level
	call InitConfigRegRead
	and  eax, PCIINT_M_INTERRUPT_LINE    ; Mask off int level(000000FFh)

;
; At this point, AL holds the configured interrupt level.
;
igc_stash_irq:
	mov	int_no, al		;; Store IRQ

	cmp  ax, 5		       ; Are we at IRQ5?
	jne  igc_slave_int	       ; Nope, then we have a slave interrupt
	mov  PICIntOff,   020h	       ; For IRQ5, set the OFF mask...
	mov  PICIntOn,	  0DFh	       ; ...and the ON mask
	mov  PICIntMask,  021h	       ; The mask register is in the MASTER PIC
	mov  PICAckSlave, 000h	       ; And we don't have to ACK the slave
	jmp  igc_pic_done

igc_slave_int:
	sub  ax, 8		       ; For slave convert 8->15 to 0->7
	mov  cx, ax		       ; load the 0->7 value into CX as a count
	mov  ax, 1		       ; Init AL to 00000001
	shl  ax, cl		       ; and shift AL CL times
	mov  PICIntOff,   al	       ; AL now holds OFF mask
	not  al 		       ; complement AL to make ON mask
	mov  PICIntOn,	  al	       ; and save it
	mov  PICIntMask,  0A1h	       ; The mask register is in the SLAVE PIC
	mov  PICAckSlave, 001h	       ; And we DO name to ACK the slave

igc_pic_done:

	mov  dx, p_PCIRV		; -> chip revision register
	call InitConfigRegRead	       ; read it
	mov  ChipRev, al	       ; save chip revision level
	mov  ax, 0		       ; return SUCCESS

igc_exit:
	mov  cx, ax
	pop  eax
	mov  ax, cx
	pop si
	pop di
	pop cx
	pop bx
	ret
GetAdapterConfig  ENDP

;********************
;* InitPrintMessage *
;********************
;
; This function prints a message pointed to by DS:SI, that is CX bytes long.
; This function uses the BIOS video service at INT 10 to provide an OS
; independent method for displaying messages to the console during driver
; init.
;
; All registers and flags are saved.
;
; Arguments:  DS:SI - Far pointer to message to print
;		 CX - Message length in bytes
;
; Algorithm:
;
; BEGIN
;    save flags
;    clear direction flag
;    do {
;      get char at DS:(SI++)
;      call INT 10 to print to console
;      CX--
;    while (CX != 0)
;    restore flags
; END
;
		  PUBLIC InitPrintMessage
InitPrintMessage  PROC NEAR

	push si
	push ax
	push bx
	push cx
	pushf		;    save flags
	cld		;    clear direction flag
	mov  bx,0Fh	;    Set video attributes for INT 10 call ;;Bright white
pm_loop:		;    do {
	lodsb		;      get char at DS:(SI++)
	mov  ah,0EH
	int  10H	;      call BIOS INT 10 to print to console
	loop pm_loop	;      CX--
			;    while (CX != 0)
	popf		;    restore flags
	pop cx
	pop bx
	pop ax
	pop si
	ret

InitPrintMessage  ENDP

;********************
;* InitPrintHexByte *
;********************
;
; This function simply prints the hex byte in AL at the console. All
; registers are preserved.
;
		  PUBLIC InitPrintHexByte
InitPrintHexByte  PROC	NEAR
	push ax
	push bx
	push cx

	mov  cx,ax		      ; Save AX in CX momentarily
	mov  bx,OFFSET InitHexByteTable   ; Place offset of translation table in BX
	and  al,0F0H		      ; Get AL upper nibble
	shr  al,4		      ; Shift it into place
	xlat			      ; Convert AL to ASCII equivalent
	mov  ah,0EH		      ; Load 'Teletype' function code in AH
	mov  bx,0FH		      ; Set video attribute for INT 10 call
	int  10H		      ; Call BIOS video service

	mov  ax,cx		      ; Restore AX
	mov  bx,OFFSET InitHexByteTable   ; Place offset of translation table in BX
	and  al,0FH		      ; Get AL lower nibble
	xlat			      ; Convert AL to ASCII equivalent
	mov  ah,0EH		      ; Load 'Teletype' function code in AH
	mov  bx,0FH		      ; Set video attribute for INT 10 call
	int  10H		      ; Call BIOS video service

	pop  cx
	pop  bx
	pop  ax
	ret

InitPrintHexByte  ENDP


include dm9100.mac
include xmt.inc
include rcv.inc

;
; DOS EMM Virtual DMA Services structures and constants
;

DDSStruc  STRUC
   DDSSize	DD ?
   DDSOffset	DD ?
   DDSSegment	DW ?
   DDSID	DW ?
   DDSPhysical	DD ?
DDSStruc  ENDS

EMMMagicSegment  EQU  0040h   ; Location 0040:007B is the magic EMM active
EMMMagicOffset	 EQU  007Bh   ; byte in DOS. If bit <5> is set in this location
EMMMagicMask	 EQU  20h     ; then the driver is being loaded high.

EMMActiveFlag	DB  0		; Flag indicating that EMM386 or other VDS
				; Memory Manager is active in DOS.

DDSBlock	DDSStruc<>	; Structure for accessing VDS services in DOS.

p_EndVirt      DW 0
p_EndPhys      DD 0

;*****************************
;* AllocatePhysicalBlock *
;*****************************
;
; This function allocates and initializes the physical block of memory used
; for Transmit and Receive DMA operations.
;
; Returns: Carry set if error, clear if success. All registers preserved.
;
; Algorithm:
; BEGIN
;    Call XmtInit with null arg to size Xmt block
;    Call RcvInit with null arg to size Rcv block
;    Calculate physical address of block starting at EndOfDataSegment
;    Call XmtInit with actual args to init Xmt module
;    Update physical and virtual pointers with byte count returned by XmtInit
;    Call RcvInit with actual args to init Rcv module
;    Update physical and virtual pointers with byte count returned by RcvInit
;
;
	PUBLIC AllocatePhysicalBlock
AllocatePhysicalBlock PROC NEAR
	pushad

				    ; Call XmtInit with null address args
	push   DWORD PTR 0	    ; to get block size in AX
	push   WORD PTR 0
	call   XmtInit		;; Return Bytes used in AX (XMT.ASM)
	add    sp, 6		;; Pop Stack
	mov    PhysBlockSize, AX    ; Init PhysBlockSize with AX

				    ; Call RcvInit with null address args
	push   DWORD PTR 0	    ; to get block size in AX
	push   WORD PTR 0
	call   RcvInit		;; Return Bytes used in AX (RCV.ASM)
	add    sp, 6		;; Pop Stack
	add    PhysBlockSize, AX    ; Add AX to running total in PhysBlockSize
;				;; PhysBlockSize = Total number of bytes for Xmt/Rcv.
; At this point, PhysBlockSize contiains the size, in bytes, of the combined
; requrements of the transmit and receive modules.
;

;
; In DOS, first check to see if a memory manager with virtual DMA services
; is active. This is done by checking the 'magic' memory location 0040:007B
; bit<5>. If this bit is set, the virtual DMA serices package is available
; in software INT 4Bh. If it is not set, we can assume that linear=physical
; (physical = (SEG*16) + OFFSET).
;
	push es
	push si
	mov  ax, EMMMagicSegment	;; 0040h
	mov  es, ax
	mov  ax, EMMMagicOffset 	;; 007Bh
	mov  si, ax
	mov  al, BYTE PTR ES:[SI]
	and  al, EMMMagicMask
	mov  EMMActiveFlag, al
iapb_no_emm:
	pop  si
	pop  es

	mov si, free_mem	   ;  DS:SI Points to EODS

	test EMMActiveFlag, 0FFh
	jnz  iapb_emm_active

	DSSI_TO_PHYSICAL		   ;  DS:SI to physical in EAX

	jmp iapb_continue

iapb_emm_active:			   ;   EMM is active, so...
	mov   ax, ds
	mov   es, ax		;; ES = DS
	mov   di, OFFSET DDSBlock
	xor   ebx, ebx
	mov   bx, PhysBlockSize
	mov   ES:[di].DDSStruc.DDSSize, ebx ;	Lock down a block of memory
	movzx ebx, si			    ;; EndOfDataSegment
	mov   ES:[di].DDSStruc.DDSOffset, ebx ;   Starting at EndOfDataSegment
	mov   ES:[di].DDSStruc.DDSSegment, ax
	mov   ah, 81h			;; LOCK DMA REGION
	mov   al, 03h
	mov   dx, 0
	int   4Bh			   ;   Call DMA Lock Service
	jc    iapb_error_exit		   ;   Any errors, abort init
	mov   eax, ES:[di].DDSStruc.DDSPhysical

iapb_continue:

;
; At this point, DS:SI points to the end of the data segment, and EAX
; holds the physical address of DS:SI. Now call the transmit and receive
; init functions with real parameters.
;

	mov    p_EndVirt, si
	mov    p_PhysBlockVirt, si
	mov    p_EndPhys, eax
	mov    p_PhysBlockPhys, eax

	jmp    iapb_done	    ; Return success


iapb_error_exit:
	stc				  ; Indicate Failure
	jmp  iapb_exit			  ; Exit

iapb_done:
	mov ax, p_EndVirt
	add ax, PhysBlockSize		;; Init. Ds + (Xmt/Rcv buffer)
	mov free_mem, ax	  ; Update EndOfDataSegment(Physical)
	clc				  ; Indicate Success

iapb_exit:
	popad
	ret
AllocatePhysicalBlock ENDP
code		ends

		end
