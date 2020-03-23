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
; This module contains equates and structure definitions specific to handling
; the driver interface to the operating system.
;
; Maintainers:
;	eg	Eric Goldstein
;       rv	Rivka Vizen
;       ymf	Yishai Fraenkel
;   	as	Adi Shaliv
;       de      Dror Efraty
;
; Revision History:
;
; 11-May-1994	eg	Syntax changes for MASM 6.1.
;
; 23-May-1994	eg	Add PCI BIOS entry point for OS/2.
;
; 20-Jun-1994	eg	Add EISA BIOS definitions.
;
; 12-sep-1994   rv  	Add support to DC21140
;
; 14-Feb-1995   ymf   	Add data describing features of several PCI devices.
;
; 21-Mar-1995   ymf     Additional data describing PCI bridges
;
; 10-Dec-1995   as	Remove EISA support from driver.
;
; 25-Nov-1996   de      change in AWK convention.
;                       module name changed from driver.ash to driver.inc
IF OS EQ DOS
DEV_CHR EQU 8000h ; this is a charcter device
DEV_OCR EQU 0800h ; supports MS-DOS 3.X open/close/rm
ENDIF

IF OS EQ OS2
;
;	The ATTRIBUTE field in the OS/2 device driver header is bit-mapped
;	as follows:
;
;  [ 15! 14! 13! 12! 11! 10! 9 ! 8 ! 7 ! 6 ! 5 ! 4 ! 3 ! 2 ! 1 ! 0 ]
;    |   |   |   |   |   |   \   |   /   |   |   |   |   |   |   |
;    |   |   |   |   |   |    \__ __/    |   |   |   |   |   |   +-- std input dev
;    |   |   |   |   |   |       |       |   |   |   |   |   +-- std output dev
;    |   |   |   |   |   |       |       |   |   |   |   +-- current NUL device
;    |   |   |   |   |   |       |       |   |   |   +-- current clock device
;    |   |   |   |   |   |       |       |   |   +-- reserved = 0
;    |   |   |   |   |   |       |       |   +-- reserved = 0
;    |   |   |   |   |   |       |       +-- set if device accepts Generic IOCtl commands
;    |   |   |   |   |   |       +-- function level, where 001 = MS OS/2 device driver
;    |   |   |   |   |   +-- reserved = 0
;    |   |   |   |   +-- support removable media (block device) or OPEN/CLOSE (char. device)
;    |   |   |   +-- reserved = 0
;    |   |   +-- set if non-IBM block format (block device only)
;    |   +-- reserved = 0
;    +-- character device = 1, block device = 0
;
;
; Attribute Word Constants for OS/2 Device Driver Device Header. These
; constants are used in DRVHDR.ASM to form the ATTRIBUTE field of the
; device driver header in DRVHDR.ASM
;
DEV_KBD 		equ	0001h		; standard input device (stdin)
DEV_SCR			equ	0002h		; standard output device (stdout)
DEV_NUL			equ	0004h		; NUL device
DEV_CLK			equ	0008h		; CLOCK$ device
DEV_GIO			equ	0040h		; device accepts Generic IOCtl commands
DEV_LEVEL1		equ	0080h		; device function level MS OS/2 driver
DEV_OPN			equ	0800h		; device supports open/close (char), removable (block)
DEV_IBM			equ	2000h		; device is a non-IBM block format (block only)
DEV_CHR			equ	8000h		; character device (if set), block device (if clear)
DEV_BLK			equ	0000h		; block device (if clear)

;   +-------------------------------------------------------------------+
;   |		O S / 2   D E V H E L P   S E R V I C E S		|
;   +-------------------------------------------------------------------+
;
; The devhlp services are the 'kernel' driver support functions in OS/2. These
; constants define the function codes used to invoke these services.
;

DEVHLP_SCHEDCLOCK	equ	00h
DEVHLP_DEVDONE		equ	01h
DEVHLP_YIELD		equ	02h
DEVHLP_TCYIELD		equ	03h
DEVHLP_BLOCK		equ	04h
DEVHLP_RUN		equ	05h
DEVHLP_SEMREQUEST	equ	06h
DEVHLP_SEMCLEAR		equ	07h
DEVHLP_SEMHANDLE	equ	08h
DEVHLP_PUSHREQPACKET	equ	09h
DEVHLP_PULLREQPACKET	equ	0Ah
DEVHLP_PULLPARTICULAR	equ	0Bh
DEVHLP_SORTREQPACKET	equ	0Ch
DEVHLP_ALLOCREQPACKET	equ	0Dh
DEVHLP_FREEREQPACKET	equ	0Eh
DEVHLP_QUEUEINIT	equ	0Fh
DEVHLP_QUEUEFLUSH	equ	10h
DEVHLP_QUEUEWRITE	equ	11h
DEVHLP_QUEUEREAD	equ	12h
DEVHLP_LOCK		equ	13h
DEVHLP_UNLOCK		equ	14h
DEVHLP_PHYSTOVIRT	equ	15h
DEVHLP_VIRTTOPHYS	equ	16h
DEVHLP_PHYSTOUVIRT	equ	17h
DEVHLP_ALLOCPHYS	equ	18h
DEVHLP_FREEPHYS		equ	19h
DEVHLP_SETROMVECTOR	equ	1Ah
DEVHLP_SETIRQ		equ	1Bh
DEVHLP_UNSETIRQ		equ	1Ch
DEVHLP_SETTIMER		equ	1Dh
DEVHLP_RESETTIMER	equ	1Eh
DEVHLP_MONITORCREATE	equ	1Fh
DEVHLP_REGISTER		equ	20h
DEVHLP_DEREGISTER	equ	21h
DEVHLP_MONWRITE		equ	22h
DEVHLP_MONFLUSH		equ	23h
DEVHLP_GETDOSVAR	equ	24h
DEVHLP_SENDEVENT	equ	25h
DEVHLP_ROMCRITSECTION	equ	26h
DEVHLP_VERIFYACCESS	equ	27h
DEVHLP_ALLOCGDTSELECTOR equ     2Dh
DEVHLP_PHYSTOGDTSELECTOR equ    2Eh
DEVHLP_REALTOPROT       equ     2Fh
DEVHLP_PROTTOREAL       equ     30h
DEVHLP_EOI		equ	31h
DEVHLP_UNPHYSTOVIRT	equ	32h
DEVHLP_TICKCOUNT	equ	33H
DEVHLP_FREEGDTSELECTOR	equ	53h
DEVHLP_PHYSTOGDTSEL     equ     54h

; Additional constants for OS/2 Device Helper Services
; for DevHlp_SchedClock
;
CLOCK_PRIOR_EOI 	equ	0
CLOCK_AFTER_EOI		equ	1

; for DevHlp_Block
;
BLOCK_SLEEP_INT 	equ	0
BLOCK_SLEEP_NON_INT	equ	1

; for DevHlp_SemHandle
;
SEMHDL_NOT_IN_USE	equ	0
SEMHDL_IN_USE		equ	1

; for DevHlp_SemRequest
;
SEMREQ_WAIT_FOREVER	equ	-1
SEMREQ_NO_WAIT		equ	0
SEMREQ_TIMEOUT		equ	0

; for DevHlp_AllocReqPacket
;
ALLREQ_WAIT		equ	0
ALLREQ_NOWAIT		equ	1

; for DevHlp_AllocPhys
;
ALLPHY_MEM_HI		equ	0
ALLPHY_MEM_LO		equ	1

; for DevHlp_Lock
;
LOCK_SHORT_TERM 	equ	0
LOCK_LONG_TERM		equ	1
LOCK_WAIT		equ	0
LOCK_NO_WAIT		equ	1

; for DevHlp_PhysToUVirt
;
UVIRT_RE		equ	0
UVIRT_RW		equ	1
UVIRT_FREE		equ	2

;for DevHlp_PhysToGDTSel
;
RING0_EXEC_READ_16	equ	5

; for DevHlp_PhysToVirt
;
VIRT_DS_SI		equ	0
VIRT_ES_DI		equ	1

; for DevHlp_VerifyAccess
;
VERIFY_READ		equ	0
VERIFY_RW		equ	1

; for DevHlp_SetIRQ
;
SETIRQ_NOT_SHARED	equ	0
SETIRQ_SHARED		equ	1

; for DevHlp_GetDosVar
;
DOSVAR_SYSINFO		equ	1
DOSVAR_LOCINFO		equ	2
DOSVAR_COM		equ	3
DOSVAR_VECTOR_S		equ	4
DOSVAR_REBOOT		equ	5
DOSVAR_VECTOR_M		equ	6
DOSVAR_YIELDFLAG	equ	7
DOSVAR_TCYIELDFLAG	equ	8

; for DevHlp_SendEvent
;
EVENT_MOUSE		equ	0
EVENT_CTRL_BREAK	equ	1
EVENT_CTRL_C		equ	2
EVENT_CTRL_SCRLCK	equ	3
EVENT_CTRL_PRTSCR	equ	4
EVENT_SHIFT_PRTSCR	equ	5
EVENT_KEYBOARD		equ	6

; for DevHlp_ROMCritSection
;
ROM_EXIT_CRITICAL	equ	0
ROM_ENTER_CRITICAL	equ	1

ENDIF

;
; Driver return status codes. These codes are returned in the rh_status
; field in the REQUEST_HEADER of a driver request frame, and indicate the
; status of the command to the operating system.
;
DRIVER_K_DONE            EQU 0100h	; Success
DRIVER_K_UNKNOWN_COMMAND EQU 8103h	; Unrecognized command requested
DRIVER_K_GENERAL_FAILURE EQU 810Ch	; Recognized request failed

;
; Driver command codes. These codes appear in the rh_command field of
; in the REQUEST_HEADER of a driver request frame.
;
CMD_K_INIT	EQU 00h	; Driver INIT
CMD_K_OPEN	EQU 0Dh ; Device Open
CMD_K_CLOSE	EQU 0Eh ; Device Close

;
; The REQUEST_HEADER is the same for both DOS and OS/2. This structure
; defines the first 13 bytes of any driver request frame. This structure
; is used by the functions in DRVHDR.ASM to interpret driver requests.
; This driver supports only INIT, OPEN, and CLOSE.
;
REQUEST_HEADER	STRUC
   rh_length    DB ?	; BYTE  PTR +0
   rh_unit      DB ?	; BYTE  PTR +1
   rh_command   DB ?	; BYTE  PTR +2
   rh_status    DW ?	; WORD  PTR +3
   rh_reserved  DD ?	; DWORD PTR +5
   rh_linkage   DD ?	; DWORD PTR +9
   rh_data      DB ?	; BYTE  PTR +13
REQUEST_HEADER  ENDS


;
; The following structures are used all over the place when splitting up
; DWORD accesses into two WORD accesses. They are functionally identical,
; however, the two sets of names make more sense in context when dealing
; with FAR pointers and DWORD variables.
;
LONG_PTR  STRUC
_off      DW ?  ; offset of FAR pointer
_seg      DW ?  ; segment of FAR pointer
LONG_PTR  ENDS

DWORD_PTR  STRUC
_loword   DW ?  ; low order word of a DWORD type
_hiword   DW ?  ; high order word of a DWORD type
DWORD_PTR  ENDS

;
; The INIT_HEADER structure defines the operating system specific method
; of interpreting the driver init request frame. There is functionally no
; difference, except the use and naming of the first DWORD field. The
; different naming makes the operating system specific use of the field
; easier to follow.
;

IF OS EQ OS2

INIT_HEADER     STRUC
   init_pad       DB 13 DUP (?)   ; Skip past the Request Header
   init_num_units DB ?            ; Number of Units
   init_devhlp    LONG_PTR {?, ?} ; devhlp on entry - driver end on return
   init_bpb       LONG_PTR {?, ?} ; init args on enter - BPB on return
   init_drive     DB ?            ; Drive number on entry
INIT_HEADER     ENDS

ELSEIF OS EQ DOS

INIT_HEADER    STRUC
   init_pad       DB 13 DUP (?)   ; Skip past the Request Header
   init_num_units DB ?            ; Number of Units
   init_eod       LONG_PTR {?, ?} ; Pointer to end of driver on return
   init_bpb       LONG_PTR {?, ?} ; init args on enter - BPB on return
   init_drive     DB ?            ; Drive number on entry
INIT_HEADER    ENDS

ENDIF

;
; The following constants define the size of the frame, and the frame type
; offered by the driver.
;
FRAME_MTU         EQU  1514
FRAME_TYPE        EQU  <'DIX+802.3',0,0,0,0,0,0,0>


;   +-------------------------------------------------------------------+
;   |                 P C I   B I O S   S E R V I C E S                 |
;   +-------------------------------------------------------------------+
;
; The following constants define the PCI BIOS calling interface
;

IF OS EQ OS2					; industry-standard entry point
PCI_BIOS_INT_ADDR		EQU  0FFE6Eh	; for "call" to int 1Ah
ENDIF

