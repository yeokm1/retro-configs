PAGE    ,132
NAME    MACINIT
TITLE   MACINIT  --  Digital Internal Use Only

;***************************************************************************
;*
;*    Copyright (c) 1993, 1994
;*    by Digital Equipment Corporation, Maynard, Mass.
;*    All Rights Reserved.
;*
;*    This software is furnished under a license and may be used and  copied
;*    only  in  accordance  with  the  terms  of  such  license and with the
;*    inclusion of the above copyright notice.  This software or  any  other
;*    copies  thereof may not be provided or otherwise made available to any
;*    other person.  No title to and ownership of  the  software  is  hereby
;*    transferred.
;*
;*    The information in this software is subject to change  without  notice
;*    and  should  not  be  construed  as  a commitment by Digital Equipment
;*    Corporation.
;*
;*    Digital assumes no responsibility for the use or  reliability  of  its
;*    software on equipment which is not supplied by Digital.
;*
;***************************************************************************
;
; This file contains all of the code and data which is involved with driver
; initialization. All of the code and data in this module are gone after
; initialization. This module must come LAST in link ordering.
;
; Maintainers:
;       eg      Eric Goldstein
;       mf      Maurene fritz
;       ymf     Yishai Fraenkel
;       rv      Rivki Vizen
;       as      Adi   Shaliv
;       gk      Gal Kaplan
;	de	Dror Efraty
;
; Revision History:
;
; 11-May-1994   eg      Syntax changes for MASM 6.1.
;
; 23-May-1994   eg      Changes for PCI support under OS/2:
;                           1)  Call PCI BIOS, via new PCIBIOSService (set by
;                               InitPCICheckBIOS), instead of int to it.
;                           2)  Moved PortConfigRegRead to here, renaming it to
;                               InitConfigRegRead and making it local.  This
;                               driver supports PCI BIOS calls under OS/2 only
;                               at init time!
;                           3)  InitGetAdapterConfig sets Nic.Rev (in MACDATA),
;                               so no one else has to read revision register.
;
; 24-May-1994   eg      Changes for SIA_Mode keyword:
;                           1)  Define new stringtrans structure, for
;                               translating string parameters to numbers.
;                           2)  Define TP and AUI as valid SIA_Mode parameters,
;                               with CSR13 equivalent for each.
;                           3)  InitProcessKeyword optionally checks and
;                               translates string parameters.
;                           4)  InitDriverInit uses InitPISIA if set.
;                           5)  AutoInit call removed:  No autosensing support!
;
;  1-Jun-1994   eg      1)  Include idmsg.ash, and use SIGNON_MESSAGE from it.
;                       2)  Change PROTOCOL.INI SLOT_ID to SLOT.
;                       3)  Temporarily restrict slot number to PCI range,
;                           EISA support is added.  Temporary changes are
;                           marked *****.
;
;  6-Jun-1994   eg      1)  SIAparams' stringtrans contain pointers to
;                           SIA_CONFIG structures, rather than CSR13
;                           autoconfiguration values.
;                       2)  Initialize PCI p_CBIO to correct value.
;
;  9-Jun-1994   mf      Increase the max number of boards to 8,
;                       by modifying the assembled value in InitSetDriverNameRetry
;
; 14-Jun-1994   eg      1)  Support SIA_Mode = TP_FULL_DUPLEX.
;                       2)  InitMsg_bad_slot_id correctly describes error.
;
; 20-Jun-1994   eg      Changes to add EISA support:
;                       1)  Remove ***** changes from 1-Jun-1994.
;                       2)  Bug fix: InitDriverInit loads parameter to pass to
;                           InitCheckEISAID.
;                       3)  Add routine InitGetEISAConfigData and data it uses.
;                       4)  InitGetAdapterConfig calls InitGetEISAConfigData,
;                           inits more Tulip registers.
;                       5)  Change PCIBIOSService to BIOSServiceEntry, since
;                           used for EISA, too.
;                       6)  Use Filler as temporary stack for DOS, since BIOS
;                           calls need more than normal stack allocation.
;
; 21-Jun-1994   eg      1)  Add PROTOCOL.INI keyword SOFTWARE_CRC.  Values
;                           ENABLED and DISABLED set XmtCRCThreshold.
;                       2)  Add InitPrintKeyword and InitPrintMessageZ.
;                           InitDriverInit calls InitPrintKeyword to print
;                           SIA_MODE.
;
; 31-jul-1994  mf       Add AUTODETECT feature
;
; 15-Aug-1994  ymf      Change DEC drivers name to D21040 and switch to enable
;                       naming SMC drivers.
;                       Change naming algorithm for multiple adapter cards in
;                       InitSetDriverName
;
; 12-Sep-1994  rv       Add support to DC21140
;
; 04-Oct-1994  ymf      Add to sanity_check routine a write to make TULIP a
;                       busmaster. Includes adding routine "InitConfigRegWrite"
;                       to the code.
;
; 09-Oct-1994  rv       Change DC21x40 and D21x40 to DC21x4, and support
;                       DC21140 pass 2
;
; 24-Nov-1994  ymf      Add two keywords to PROTOCOL.INI regarding DC21140 CSR12
;                       These are: DC21140_GPR_CTRL  and  DC21140_GPR_DATA .
;
; 19-Dec-1994  ymf      Change num of XmtBuffers to 8, RcvBuffers to 12 as
;                       default. Provide PROTOCOL.INI keywords:
;                       NUM_TX_BUFFERS and NUM_RX_BUFFERS  for user to set.
;                       Range of both parameters: 4 -> 16 .
;
; 12-Feb-1995  ymf      Change to accomodate DC21041 (TULIP3)
;
; 14-Feb-1994  ymf      Add parsing of TURBO kwd in PROTOCOL.INI relating
;                       to HPPE bit in intel Host-to-PCI bridge.
;
; 22-Feb-1994  ymf      Change drivername back to DC21X4$
;
; 21-Mar-1995  ymf      Add additional bridge-specific checks
;
; 23-Mar-1995  ymf      Major driver-init restructuring:
;                       1. Modify code in InitDriverInit.
;                       2. Change values for SIA_mode internal translation.
;                       3. Modify InitGetAdapterConfig.
;                       4. Turn InitPIGPRData/Ctrl into irrelevant parameters.
;                       5. Change IntPrintKeyword.
;                       6. Added TP_LINK_DISABLE as an SIA_Mode  parameter.
;
; 20-Apr-1995  ymf      TULIP3 autosense: Add AUTOSENSE keyword.
;
; 02-May-1995  ymf      Add TX_THRESHOLD keyword and associated variables
;                       for enabling user to set transmit threshold values.
;
; 11-Jun-1995   ymf     Fix in routine InitPCIFindDevice. Add line "inc si",
;                       so that routine be effective in multiple DEC NICs .
;
; 31-Jul-1995   ymf     Small bug fix in InitScanPCIBus: In 04A3h PCI bridge
;                       rev 1, Cache write-back mode bitology is 11 (=3).
;
; 15-Aug-1995   ymf     Add user-defined IEEE ethernet address to be set in
;                       PROTOCOL.INI.
;
; 03-Sep-1995   as      Xmt+Rcv Buffers: 1. Change defaults to 8 and 8.
;                       2. Add check if sum of both excceeds allowed value.
;                       3. user can input to SIA_MODE keyword AUTOSENSE not
;                          AUTODETECTE but for rev backcomptabilty the driver
;                          will act as AUTODETECT=AUTOSENSE.
;
; 24-Sep-1995  as       Add parsing of 'Multia' Keyword of PROTOCOL.INI
;                       That indicate use of MULTIA board.
;
; 22-Oct-1995  as       Add Parsing of 'SNOOZE' keyword of PROTOCOL.INI
;                       That enable the user to Enable or Disable the activate
;                       of the Chip power saving snooze mode.
;
; 31-Oct-1995  as       Add Support for MiiPhy - Start the Phy chip, and
;                       get the Phy Capabilities. Chose the driver
;                       operational mode that including MiiPhy Option.
;
; 11-Nov-1995  as       Add The KeyWord Value 'T4' for the keyword SIA_MODE list
; 13-Nov-1995  as       Initialize PCI p_CFDA to correct value.
;
; 11-Dec-1995  as       Remove EISA support from driver.
;
; 04-Feb-1996  as       Add to InitScanPCIBus the check if it is OPTI PCI bridge
;                       chipset (Dev Id: C832h, Ven Id:1045)
;                       If it is set the IsOptiC832 flag and print informative
;                       message.
;
; 06-Feb-1996  as       Add support to DC21142 (Twinet)
;
; 21-Apr-1996  as       Change the IRQ support off the Adapter in
;                       InitGetAdapterConfig now support IRQ 3-15.
;
; 30-Apr-1996   as      Add Mac2Phy Error Message Strings.
;                       Add updating Nic.PowerMode according to PROTOCOL.INI
;                       power mode keyword (SNOOZE=).
;
; 09-May-1996   as      Add Init to the CSR8_overflow_mask variable acording to chip.
;
; 06-Jun-1996   as 2.40 Add call to PortSetSNOOZEMode in InitDriverInit
;                       to set the chip for RUN Mode befor reading the SROM.
; 15-Aug-1996   gk      Add OEM support for Microdyne, fix typo in chipset msg.
;
; 25-Nov-1996	de	Changes in include file names, and in AWK conventions.
;
; 06-Feb-1996	de	move keywords treatment to dc_kwds module.
;
; 16-Feb-1997	de	make buffers and descriptors 32 Bytes aligned.
;
;*************************************************************************

.xlist                                  ; disable listing the include file
include seg_defs.inc
include macro.inc
include dc_regs.inc
include nic.inc
include driver.inc
include ndis.inc
include sss.inc
include dc_kwds.inc
include syssrvcs.inc
include macinit.ash
include version.inc
include idmsg.inc
.list                                   ; enable listing
.386

MaxBuffersNum      EQU  22     ; Maximum total number of Rcv and Xmt buffers

START_DATA_SEGMENT_INIT

IF OS EQ OS2
BIOSServiceEntry        LONG_PTR {?, ?} ; entry point to PCI BIOS
ENDIF

p_EndVirt      DW 0


;---------------------------------------------------------------------------
; General driver parameters, Self Explanatory ...
;---------------------------------------------------------------------------
IOAddress1         DW ?                  ; IO Base address of adapter
IORange1           DW ?                  ; Range in Bytes of CSRs space

IntLine1	   DB ?                  ; Adapter IRQ Level

CurrVal DB '1'           ; Indicator variable for multiple adapter card names

;----------------------------------------------------------------------------
;
; Driver Messages Printed During Init stage
;
;----------------------------------------------------------------------------
CR EQU 0Dh      ; ASCII Carriage Return
LF EQU 0Ah      ; ASCII Line Feed

InitMsg_signon  DB CR,LF
                SIGNON_MESSAGE
                DB CR,LF,0

InitMsg_pci_slot     DB 'PCI SLOT: ',0

InitMsg_irq         DB '     IRQ: ',0

InitMsg_OpMode          DB CR,LF,'Operation Mode: ',0

InitMsg_crlf        DB CR,LF,0

InitMsg_error       DB 'MAC Init Error: ',0

InitMsg_bad_buffers_sum  DB 'Number of Rx/Tx Buffers too large - using defaults.',CR,LF,0

InitMsg_bad_instance     DB 'Driver Instance Limit Exceeded.',CR,LF,0

InitMsg_alloc_failed       DB 'Could not allocate physical blocks.',CR,LF,0

IF OS EQ OS2
InitMsg_gdt_failed      DB 'Could not allocate GDTs.',CR,LF,0

ddtmp   DW ?  ; For OS2 only. Dummy variable to hold DOSWRITE return code.

ENDIF


DMA_Block	DMA_DESCRIPTOR<> ; Structure for allocating memory (espacially for VMS services)

END_DATA_SEGMENT_INIT


        PAGE

START_CODE_SEGMENT_INIT

;EndOfCodeSegment        LABEL   BYTE    ; Mark end of CODE segment. All code
                                        ; defined after this symbol is lost
                                        ; after driver INIT.

;******************
;* InitDriverInit *
;******************
;
; This function is the handler for a driver INIT command. This is the first
; code that is executed when a driver is loaded. This function prints the
; sign-on banner, opens and parses PROTOCOL.INI, registers the driver
; with PROTMAN.
;
; On entry, ES:BX contains a pointer to the Request Header.
;
; According to the NDIS 2.01 spec (see the specification of the 'Bind' system
; request) the driver INIT function should NOT manipulate the network adapter.
; This is to maintain compatibility with remote program load. In order to make
; the driver's run-time small, a seperate INIT module (SROM.ASM) does manipulate
; the adapter in order to obtain its ROM/SROM information. However, the hardware
; isn't set with any values.
;
;
; ALGORITHM OF THE INIT PROCESS (and outline of InitDriverInit Routine):
;------------------------------------------------------------------------
;
; BEGIN
;    1. Miscellaneous technical stuff:
;       - if DOS, then switch to larger private stack
;       - Print Sign On Banner
;       - Get OS2 DevHlp Entry Point
;    2. Resolve driver name (relevant when several NICs are in the system):
;       - Resolve driver name conflicts
;       - if (driver name can't be resolved)
;           abort driver init
;    3. Protocol manager dealings:
;       - Open PROTMAN
;       - if (error opening PROTMAN)
;           abort driver init
;       - Parse contents of PROTOCOL.INI
;    4. Find location of adapter, and get information relating to it:
;       - if (user specified SLOT)
;         {
;           validate user specified SLOT
;           if (user SLOT is bad)
;             abort driver init
;         }
;         else
;         {
;           Probe for Adapter
;           if (no adapter found)
;             abort driver init
;         }
;       - Get Adapter Configuration
;    5. System verification:
;       - Check for special versions of our device.
;       - PCI sanity check.
;       - if (PCI bus)
;           Scan PCIbus, implement TURBO kwd, and look for problematic devices.
;    6. Process ROM information (in module SROM.ASM):
;       - Read IEEE address.
;       - Read additional info (new SROM format).
;       - Decide driver final values considering also PROTOCOL.INI values.
;    7. Init Mii_Phy and get his capabilities
;           Update The driver Data Structurs with ConnectionType it
;           will start on PortInit
;    8. Informative INIT message, informing of system settings.
;    9. Miscellaneous technical stuff:
;       - Reserve OS2 GDTs
;       - if (GDTs can't be gotten)
;           abort driver init
;       - Call NdisInitRegisterModule with pointer to common characteristics table
;       - Close PROTMAN$
;       - Mark end of driver for TSR
;       - Indicate MAC operational in Service Specific Stats table
;       - if DOS, then switch back to caller's stack
; END
InitDriverInit  PROC NEAR
        push es
        push si
        push bx
        push cx

        DataAddress  dx, InitMsg_signon	; Print Sign On Banner
        call DisplayMessage

IF OS EQ OS2                               ; Get OS2 DevHlp Entry Point
        mov  ax, es:[bx].INIT_HEADER.init_devhlp._off
        mov  devhlp._off, ax
        mov  ax, es:[bx].INIT_HEADER.init_devhlp._seg
        mov  devhlp._seg, ax
ENDIF

	call DcInit			; Perform all nic initializations.
	jc   idi_error

	call DisplaySelectedChip
	jc   idi_error

	call InitPrintMiscStuff

IF OS EQ OS2                            ; Reserve OS2 GDTs
        mov  cx, 2                      ; Get 2 (Rcv, Xmt)
        mov  ax, ds
        mov  es, ax
        lea  di, RxGDTSelector
        mov  dl, DEVHLP_ALLOCGDTSELECTOR
        call ds:[devhlp]                ;    Allocate GDTs
        jnc  idi_alloc_gdt_ok
        mov  dx, OFFSET InitMsg_gdt_failed
        jmp  idi_error
idi_alloc_gdt_ok:

ENDIF

idi_alloc_phys_blk:
;
;    Call InitAllocatePhysicalBlock to map out the memory starting at
;    ImageEnd, and to adjust the driver end pointer.
;
        call InitAllocatePhysicalBlock
;
;    Call InitRegisterModule with pointer to common characteristics table
;
        call InitMarkEndOfDriver        ;    Mark end of driver for TSR

                                        ;    Indicate MAC operational
        mov  NDISServiceStatus.sss_macstat._loword, SSS_OPERATIONAL
        mov  NDISServiceStatus.sss_macstat._hiword, 0

	call SYSSRVCS_InitDone

	clc
idi_error:
        pop cx
        pop bx
        pop si
        pop es
        ret
InitDriverInit  ENDP


;**************************
;* InitPrintMiscellaneous *
;**************************
;
; This routine prints the selected slot, IRQ and operation mode.
;
; Preconditions: Nic data structure is initialized
;
; All registers are destroyed.
;
InitPrintMiscStuff PROC
ipms_print_slot:
	DataAddress  dx, InitMsg_pci_slot        ; Print PCI Slot Number
        call DisplayMessage
        mov  al, Nic.SlotNum
        call PrintHexByte

ipms_print_irq:
        DataAddress  dx, InitMsg_irq             ; Print IRQ
        call DisplayMessage
	mov  al, IntLine1
        mov  BYTE PTR NDISServiceSpecificChar.ssc_interrupt, al
        call PrintHexByte

ipms_msg_crlf:
        DataAddress  dx, NewLineLineFeedMessage    ; Print the trailing CR,LF
        call DisplayMessage

IF OS EQ OS2
ipms_print_opmode:                            ; Print Operation Mode of NIC
	call DisplaySelectedMedia
ENDIF
	ret
InitPrintMiscStuff ENDP


;*********************
;* InitSetBuffersNum *
;*********************
;
; This function puts the final number of Rx/Tx buffers in their run-time
; variables
;
InitSetBuffersNum PROC NEAR
   push	ax

; check that the sum number of transmit and recieve buffers will not
; requier more memory space then the 32K the driver allocate for that
;
isbn_check_sum:
   mov  ax, XmtNumBuffers
   add  ax, RcvNumBuffers         ; the total number of buffers
   cmp  ax, MaxBuffersNum         ; if over max buffer alowed , return to default
   jbe  isbn_exit

   mov  XmtNumBuffers, DefXmtBuffersNum   ; use the default Xmt buffers number
   mov  RcvNumBuffers, DefRcvBuffersNum   ; use the default Rcv buffers number
   push dx
   DataAddress  dx, InitMsg_bad_buffers_sum    ; print message that number of Rx/Tx
   call DisplayMessage                      ; buffers return to the default number.
   pop  dx

isbn_exit:
   pop	ax
   ret
InitSetBuffersNum ENDP



        PAGE
;*****************************
;* InitAllocatePhysicalBlock *
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
;    Calculate physical address of block starting at ImageEnd
;    Call XmtInit with actual args to init Xmt module
;    Update physical and virtual pointers with byte count returned by XmtInit
;    Call RcvInit with actual args to init Rcv module
;    Update physical and virtual pointers with byte count returned by RcvInit
;
;
InitAllocatePhysicalBlock PROC NEAR
        pushad

; Call XmtInit with null address args
        push   DWORD PTR 0          ; to get block size in AX
        push   WORD PTR 0
        call   XmtInit
        add    sp, 6
        mov    PhysBlockSize, AX    ; Init PhysBlockSize with AX

                                    ; Call RcvInit with null address args
        push   DWORD PTR 0          ; to get block size in AX
        push   WORD PTR 0

        call   RcvInit
        add    sp, 6
        add    PhysBlockSize, AX    ; Add AX to running total in PhysBlockSize
;
; At this point, PhysBlockSize contiains the size, in bytes, of the combined
; requrements of the transmit and receive modules.
;

        mov   ax, ds
        mov   es, ax
        mov   di, OFFSET DMA_Block
        xor   ebx, ebx
        mov   bx, PhysBlockSize
        mov   ES:[di].DMA_DESCRIPTOR.RegionSize, ebx ;   Lock down a block of memory
        movzx ebx, si
        mov   ES:[di].DMA_DESCRIPTOR.RegionOffset, ebx ;   Starting at ImageEnd
        mov   ES:[di].DMA_DESCRIPTOR.RegionSegment, ax

	call  VirtualToPhysical
	jnc   iapb_continue

	mov   dx, OFFSET InitMsg_alloc_failed
	jmp   iapb_exit
iapb_continue:
	mov   eax, ES:[di].DMA_DESCRIPTOR.PhysicalAddress

;
; At this point, DS:SI points to the end of the data segment, and EAX
; holds the physical address of DS:SI. Now, align eax in cache line
; alignment (32 Bytes), and keep the corresponding virtual si updated.
;

	mov	bx, ax 		; copy value of ax
	dec	bx
	and	bx, 1Fh		; find offset from 32B alignment - 1
	mov	edx, 1Fh
	sub	dx, bx		; find number of bytes to add,
				; to acheive 32 bytes alignment

	add	eax, edx	; align physical address.
	add	si, dx		; align virtual address.

        mov    p_PhysBlockVirt, si
        mov    p_PhysBlockPhys, eax

        add si, PhysBlockSize
        mov ImageEnd, si 	          ; Update ImageEnd
        clc                               ; Indicate Success

iapb_exit:
        popad
        ret
InitAllocatePhysicalBlock ENDP


        PAGE
;***********************
;* InitMarkEndOfDriver *
;***********************
;
; This function is called as the LAST step of driver init. Both DOS and OS2
; return pointers to the end of the driver on return from handling an INIT
; request. This allows the operating system to deallocate any memory that
; is needed ONLY for initialization processing. Cool, huh?
;
; DOS: A single pointer to ImageEnd is returned. The DOS driver may
;      only occupy a single segment, so only one pointer is needed.
;
; OS2: Two pointers, ImageEnd and CodeImageEnd are returned. The
;      OS2 driver has a separate CODE and DATA segment, and the OS needs to
;      know what can be chopped from each segment.
;
; Returns:
;
;   Nothing, actually. The Request Header data structure is modified, but no
;   status is returned.
;
InitMarkEndOfDriver  PROC NEAR

;        les  bx,[RHPtr]                 ;    Refresh ES:BX pointer to Req Header

IF OS EQ DOS
        push ax
        mov  ax, ImageEnd
        mov  es:[bx].INIT_HEADER.init_eod._off, ax  ; Mark end of driver
        mov  es:[bx].INIT_HEADER.init_eod._seg, ds
        pop  ax
        ret

ELSEIF OS EQ OS2
        push ax
        xor  ax,ax
        mov  es:[bx].INIT_HEADER.init_num_units, al     ; Clear # of units
        mov  es:[bx].INIT_HEADER.init_bpb._off, ax      ; Clear BPB pointer
        mov  es:[bx].INIT_HEADER.init_bpb._seg, ax
        mov  es:[bx].INIT_HEADER.init_devhlp._off, OFFSET CodeImageEnd
                                                        ; Mark end of CS
        mov  ax, ImageEnd
        mov  es:[bx].INIT_HEADER.init_devhlp._seg, ax   ; Mark end of DS
        pop  ax
        ret
ENDIF

InitMarkEndOfDriver  ENDP

	PAGE

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Name:     SetEthernetAddressVariable   proc
;
; Description:
;	This routine copy the SROM  ethernet address variabel
;	to the NDIS2 tables.
;
; On Entry:
;	DS:SI  - points to the starting address of the Ethernet address variable
; On Return:
;
;		Flags:
;
;		Note:
;
; Remarks:	This routine is called by SROM parsing routines.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SetEthernetAddressVariable proc near
	push es
	push di
	push si
	push cx	

;
;    Initialize permanent station address in NDISServiceSpecificChar
;    First - point to relevant location
;
	mov  ax, cs ;SEG NDISServiceSpecificChar       ; ES:DI points
	mov  es, ax                                    ; to Permanent
						       ; adapter address

	cld

; Copy IEEE address
;--------------------
	push	si
	mov     cx, 6                  			;CX - number of bytes to transfer.
	mov     di, OFFSET rom_address

    rep movsb


; Copy IEEE address
	pop	si
	mov     cx, 6                  			;CX - number of bytes to transfer.
	mov     di, OFFSET NDISServiceSpecificChar.ssc_curraddr

    rep movsb

	pop	cx
	pop     si
	pop     di
	pop     es
	ret

SetEthernetAddressVariable endp

END_CODE_SEGMENT_INIT
END

