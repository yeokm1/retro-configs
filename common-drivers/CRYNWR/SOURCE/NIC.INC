;*******************************************************************************
;
; Nic.inc
;
; Include file for Dec Tulip and Fast Ethernet boards that holds Nic's Global
; definitons used by the driver for handling the Nic and associated DECchip.
;
;
;Written by:   Moti Haimovsky
; Date:         1-Aug-1996
;
;
; Copyright (C) 1994 by Digital Equipment Corporation 
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
; Moti Haimovsky  12-Nov-1996 2.50  -Added CurrentPowerMode field to Nic.
; 				    -Modified Shadow_CSR7_Final var to Shadow_CSR7_Mask
;				     which reflects its current usage.
; Moti Haimovsky  08-Jan-1997 2.60  -Added DriverMode field to Nic.
; Moti Haimovsky  05-Feb-1997       -Added BUS type Information to Nic.
;*******************************************************************************

;-----------------------------------------------------------------
;TYPE   DriverModeType   IS  ENUM  {POWER-UP, BIND_TIME, RUN_TIME}
;-----------------------------------------------------------------
POWER_UP        equ     0
RUN_TIME        equ     1
IF NOS EQ NDIS2
BIND_TIME	equ	2             ;NDIS2 has a BIND Time state,
ELSE
BIND_TIME	equ	POWER_UP      ;ODI bindings are Done at INIT
ENDIF

;******************************************************************************
;*                         SYSTEM   DEFINITIONS                        	      *
;******************************************************************************
;-------------------
; SYSTEM TYPE FLAGS              
;-------------------
I386_Present		equ	08h		; 386 CPU or greater bit.
PCI_Present		equ	10h		; PCI BIOS bit.
CS_Present		equ	20h		; Card Services is Present.
SUPPORTED_BUSSES_MASK	equ	PCI_Present	;Bus types currently supported by our driver

;--------------------
; BUS TYPE Constants
;--------------------
BUS_TYPE_PCI		equ	04h
BUS_TYPE_CARDBUS	equ	03h
BUS_TYPE_UNDEFINED	equ	0FFh

;--------------------
; Slot Num Constants
;--------------------
UNDEF_SLOT               equ 0

;-------------------
; PC TYPE CONSTANTS
;-------------------
DEFAULT_PC		equ	0
MULTIA_PC		equ 	1


;******************************************************************************
;*                      Auto-Negotiation (NWAY) ENTITY                        *
;******************************************************************************
;-------------------------------------------------------------------------------------------
;TYPE OperationModeStatusType is ENUM {NWAY_UNKNOWN, NWAY_NOT_SUPPORTED, NWAY_SUPPORTED ...}
;-------------------------------------------------------------------------------------------
OM_UNKNOWN              equ     0FFh    ;Initial value before any other knowledge
NWAY_UNKNOWN            equ     0FFh    ;Initial value before any other knowledge
NWAY_NOT_SUPPORTED      equ     0FEh    ;No Nway in This PHY
NWAY_DISABLED           equ     0       ;Nway present but disabled
NWAY_CONFIGURING        equ     3       ;Nway is still configuring - No final results
NWAY_COMPLETE           equ     5       ;Nway process is done.
NWAY_LINK_CHECK         equ     6       ;Nway link-check

;NWAY selector list
;------------------
NWAY_802_3_SELECTOR     equ     1
NwaySelectorMask        equ     1Fh

;----------------------------------------
;TYPE   NwayCapabilitiesType IS BITMAP {}
;----------------------------------------
Nway100BaseT4Capable      equ      200h
Nway100BaseTxFDCapable    equ      100h
Nway100BaseTxCapable      equ       80h
Nway10BaseTFDCapable      equ       40h
Nway10BaseTCapable        equ       20h


Nway100BaseT4             equ     Nway100BaseT4Capable
Nway100BaseTxFD           equ     Nway100BaseTxFDCapable
Nway100BaseTx             equ     Nway100BaseTxCapable
Nway10BaseTFD             equ     Nway10BaseTFDCapable
Nway10BaseT               equ     Nway10BaseTCapable

NwayNextPageAble          equ     8000h
NwayACK                   equ     4000h
NwayRemoteFault           equ     2000h


;******************************************************************************
;*                      MEDIA  ENTITY  CONSTANTS                              *
;******************************************************************************
;--------------------------------------------------------------------------------
;TYPE MediaStatusType is ENUM {MEDIA_STATE_UNKNOWN, MEDIA_LINK_NOT_SUPPORTED ...}
;--------------------------------------------------------------------------------
MEDIA_STATE_UNKNOWN             equ     0FFh
MEDIA_LINK_NOT_SUPPORTED        equ     0
MEDIA_LINK_DISABLED             equ     2
MEDIA_LINK_CONFIGURING          equ     3       ;Link is still configuring - No final results
MEDIA_LINK_FAIL                 equ     5
MEDIA_LINK_PASS                 equ     6
MEDIA_LINK_PASS_WITH_PF         equ     7


;--------------------------------------------------------------
;TYPE   ConnectionStatusType  IS  STRUCTURE DEFINED
;               OMStatus        IS      OperationModeStatusType
;               MediaStatus     IS      MediaStatusType
;END    ConnectionStatusType
;--------------------------------------------------------------
CONNECTION_STATE_UNKNOWN        equ     0FFFFh

ConnectionStatusType    union
	struc
	  OMStatus       db     OM_UNKNOWN
	  MediaStatus    db     MEDIA_STATE_UNKNOWN
	ends
	ConnectionStatus dw     ?
ConnectionStatusType    ends
	
;----------------------------------------------------
;TYPE   CompletionStatusTYPE  IS ENUM {SUCCESS, FAIL}
;----------------------------------------------------
FAIL    equ     0
SUCCESS equ     1

;-----------------------------------------------------------
;TYPE    CompletionStatusType  IS STRUCTURE DEFINED
;               CompletionStatus    IS  CompletionStatusTYPE
;               ErrorMessage        IS  StringPTR
;END     CompletionStatusType;
;-----------------------------------------------------------
CompletionStatusType    struc
	CompletionStatus        dw      ?
	ErrorMessagePTR         dw      ?
CompletionStatusType    ends

;----------------------------------------------------------------------------------
;TYPE   AdminStatusType   IS ENUM {RESET, OPERATIONAL,STANDBY, POWERDOWN, UNKNOWN}
;TYPE   AdminControlType  IS ENUM {RESET, OPERATIONAL,STANDBY, POWERDOWN, BRUT_FORCE_CONNECTION}
;The numbering also defines priority among the types - Do Not change.
;----------------------------------------------------------------------------------
ADMIN_UNKNOWN           equ     0FFh    ;                                (status only)
RESET                   equ     0       ;                                (status & control)
OPERATIONAL             equ     1       ;Powered and connected           (status & control)
STANDBY                 equ     2       ;Inactive but ON  (ISOLATE)      (status & control)
POWERDOWN               equ     3       ;Shut-down                       (status & control)
BRUT_FORCE_CONNECTION   equ     4       ;                                (Control only)
			
;----------------------------------------
;TYPE   OM CapabilitiesType IS BITMAP {}
;----------------------------------------
PhyAsNwayCapable                  equ        8h

;----------------------------------------------
;TYPE   ConnectionCapabilitiesType IS BITMAP {}
;----------------------------------------------
Phy100BaseT4Capable             equ     8000h
Phy100BaseTxFDCapable           equ     4000h
Phy100BaseTxCapable             equ     2000h
Phy10BaseTFDCapable             equ     1000h
Phy10BaseTCapable               equ      800h
Phy100BaseFxFDCapable           equ       40h
Phy100BaseFxCapable             equ       20h
PhyBNCCapable                   equ       10h
PhyAUICapable                   equ        4h


NwayCapableMediaList            equ    (Phy100BaseT4Capable   or \
					Phy100BaseTxFDCapable or \
					Phy100BaseTxCapable   or \
					Phy10BaseTFDCapable   or \
					Phy10BaseTCapable )
;-----------------
; Phy Capabilities
;-----------------
GENERIC_PHY     equ    0FFFFFFFFh

PhyCapabilitiesType     union
      struc
	ConnectionCapabilities  dw      0
	NwayCapabilities        dw      0
      ends
	PhyCapabilities         dd      ?
PhyCapabilitiesType     ends

;-----------------------------------------------------------------
;TYPE   ConnectionType  IS  STRUCTURE DEFINED
;               Medium  IS ENUM {Defined in SROM}
;               OM      IS ENUM {Defined in SROM}
;END    ConnectionType
;-----------------------------------------------------------------
ConnectionType  union
   struc
     Medium     db      ?
     OM         db      ?
   ends
   Connection   dw      ?
ConnectionType  ends

;MAC connection Constants
;------------------------
MAC_CONN_UNKNOWN        equ     0FFFFh

;---------------------------
;Unit Availability constants
;---------------------------
Absent          equ     0
Present         equ     1
Faked		equ	2

;---------------------------
;Media Selection definitions
;---------------------------

; "Pure" Media definitions
;-------------------------
MediaTP                 equ     0
MediaBNC                equ     1
MediaAUI                equ     2
MediaSymScr             equ     3        ;Also called 100BaseTx
MediaTPFD               equ     4
MediaSymScrFD           equ     5        ;Also called 100BaseTxFD
Media100BaseTx          equ     MediaSymScr
Media100BaseTxFD        equ     MediaSymScrFD
Media100BaseT4          equ     6
Media100BaseFx          equ     7
Media100BaseFxFD        equ     8
MAX_MEDIA_TABLE         equ     9        ;Marks End Of Media table
					 ;Notice that Mii media are not kept in Media table
MediaMiiTP              equ     9
MediaMiiTpFD            equ    0Ah
MediaMiiBNC             equ    0Bh
MediaMiiAUI             equ    0Ch
MediaMii100BaseTX       equ    0Dh
MediaMii100BaseTxFD     equ    0Eh
MediaMii100BaseT4       equ    0Fh
MediaMii100BaseFX       equ    10h
MediaMii100BaseFxFD     equ    11h
MAX_MEDIA               equ    MediaMii100BaseFxFD

;"Pure" OperationMode definitions
;--------------------------------
ModeNWAY              equ     1h
ModeFULL_DUPLEX       equ     2h
ModeLINK_DISABLE      equ     4h
ModeAUTODETECT        equ     8h     ;Also called auto-sense
ModeAUTOSENSE         equ     ModeAUTODETECT

;Mixed Media-OperationMode Definitions (Selected Connection type)
;----------------------------------------------------------------
ConnectionTP                  equ      MediaTP                 
ConnectionBNC                 equ      MediaBNC                
ConnectionAUI                 equ      MediaAUI                
ConnectionSymScr              equ      MediaSymScr             
ConnectionTpNway              equ     (MediaTP          or  (ModeNWAY                   SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionTpFD                equ     (MediaTpFD        or  (ModeFULL_DUPLEX            SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionTpLinkDisable       equ     (MediaTp          or  (ModeLINK_DISABLE           SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionSymScrFD            equ     (MediaSymScrFD    or  (ModeFULL_DUPLEX            SHL MEDIA_TYPE_FIELD_SIZE))
Connection100BaseTx           equ      ConnectionSymScr
Connection100BaseTxFD         equ      ConnectionSymScrFD
Connection100BaseT4           equ      Media100BaseT4
Connection100BaseFx           equ      Media100BaseFx
Connection100BaseFxFD         equ     (Media100BaseFxFD or  (ModeFULL_DUPLEX            SHL MEDIA_TYPE_FIELD_SIZE))

ConnectionMiiTP               equ      MediaMiiTP
ConnectionMiiTpFD             equ     (MediaMiiTpFD     or  (ModeFULL_DUPLEX            SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionMiiBNC              equ      MediaMiiBNC
ConnectionMiiAUI              equ      MediaMiiAUI             
ConnectionMii100BaseTX        equ      MediaMii100BaseTX       
ConnectionMii100BaseTxFD      equ     (MediaMii100BaseTxFD or  (ModeFULL_DUPLEX         SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionMii100BaseT4        equ      MediaMii100BaseT4       
ConnectionMii100BaseFX        equ      MediaMii100BaseFX       
ConnectionMii100BaseFxFD      equ     (MediaMii100BaseFxFD or  (ModeFULL_DUPLEX         SHL MEDIA_TYPE_FIELD_SIZE))

ConnectionAutoDetect          equ     (MediaTP          or  (ModeAUTODETECT             SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionAutoSense           equ     (MediaTP          or  (ModeAUTOSENSE              SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionAutoDetectNway      equ     (MediaTP          or ((ModeNWAY or ModeAUTODETECT)SHL MEDIA_TYPE_FIELD_SIZE))
ConnectionAutoSenseNway       equ     (MediaTP          or ((ModeNWAY or ModeAUTOSENSE) SHL MEDIA_TYPE_FIELD_SIZE))

;Usefull constants
;-----------------
NoSelectedMedia          equ    0FFh
NoOperationMode          equ    0FFh
NoSelectedConnection     equ    0FFFFh
NoSpecialOperationMode   equ    0
DC21140_UNDEF_MODE       equ    0FFFFh

MEDIA_TYPE_MASK          equ    0FFh
MEDIA_TYPE_FIELD_SIZE    equ    8
DC21X4_MEDIA_CODE_MASK   equ    3Fh  

AUTOSENSE_CAPABLE        equ    1
FALSE                    equ    0
TRUE                     equ    1

;-------------
; MEDIA  ENTRY
;-------------

;GEP entry proporties
;--------------------
Gep_Control             equ     0
Gep_Data                equ     2
MAX_GPR_SEQUENCE        equ     5

GPR_STRUC       struc
	SequenceCount   dw      0                               ;Legal values are 0 or 2
	SequenceData    dw      MAX_GPR_SEQUENCE dup (0)        ;First word is Control, Second is Data.
GPR_STRUC       ends

;External Link Sense proporties
;------------------------------
ACTIVE_INVALID          equ     1
NOT_ACTIVE_INVALID      equ     0
ACTIVE_VALID            equ     NOT_ACTIVE_INVALID

ExternalLinkSenseSTRUC  struc
	LinkSenseMask   db      ?
	Polarity        db      ?
	ActiveInvalid   dw      ACTIVE_INVALID  ;Its a Word due to alignment considerations.
ExternalLinkSenseSTRUC  ends

;Internal Link Sense proporties
;------------------------------
InternalLinkSenseSTRUC  struc
	InternalLinkSenseRoutine        dw      0
	InternalSensePresence           dw      Absent
InternalLinkSenseSTRUC  ends

;Phy Internal Regs proporties
;----------------------------
MediumInternalRegsSTRUC struc
	CSR13           dw      0
	CSR14           dw      0
	CSR15           dw      0
	RegsPresence    dw      Absent
MediumInternalRegsSTRUC ends

;Medium routines
;---------------
MediumRoutinesType      struc
	MInit                   dw      0    ;Set medium default parameters according to Chip found     (TBD)
	MParse                  dw      0    ;Parse Srom Parameter block according to Block type & Chip (TBD)
	MGetCapabilities        dw      0    ;Get Medium capabilities
	MSelectMedium           dw      0    ;Set chip to work with selected medium
	MGetLinkStatus          dw      0    ;Get Medium Link Status.
MediumRoutinesType      ends                                  

;Media entry proporties
;----------------------
MEDIA_ENTRY     struc
	CSR6_OM                 dd                       0
	Gep                     GPR_STRUC               < >
	MediumInternalRegs      MediumInternalRegsSTRUC < >
	ExternalLinkSense       ExternalLinkSenseSTRUC  < >
	InternalLinkSense       InternalLinkSenseSTRUC  < >
	MediaPresence           dw                       Absent      ;Is the media present in Nic ? (use ONLY 0,1 Values !)
	MediumRoutines          MediumRoutinesType      < >
MEDIA_ENTRY     ends

;Media entries offsets in media table - used by GetMediaEntry Macro
;------------------------------------------------------------------
TP                      equ     (MediaTP          * SIZE MEDIA_ENTRY)
BNC                     equ     (MediaBNC         * SIZE MEDIA_ENTRY)
AUI                     equ     (MediaAUI         * SIZE MEDIA_ENTRY)
SymScr                  equ     (MediaSymScr      * SIZE MEDIA_ENTRY)
TpFD                    equ     (MediaTPFD        * SIZE MEDIA_ENTRY)
SymScrFD                equ     (MediaSymScrFD    * SIZE MEDIA_ENTRY)
BaseT4                  equ     (Media100BaseT4   * SIZE MEDIA_ENTRY)
BaseFx                  equ     (Media100BaseFx   * SIZE MEDIA_ENTRY)
BaseFxFD                equ     (Media100BaseFxFD * SIZE MEDIA_ENTRY)


;Media priority list for DC21140 autosense
;-----------------------------------------
MediaPriorityStruc      struc
	NumMedia                dw      0
	MediaPriorityList       db      MAX_MEDIA_TABLE  dup (NoSelectedMedia)
MediaPriorityStruc      ends

;* *******************************************************************\
; * DC21X4 PHY Table
; *
; Holds the Phy values as defined in SROM spec V3.0
;*********************************************************************/
MEDIA_CAPABILITIES_MASK equ     0f800h
NWAY_ADVERTISEMENT_MASK equ     3e0h
MAX_PHY_TABLE           equ     1
MAX_GPR_SEQUENCE        equ     5


MII_PHY_ENTRY   struc
      MacEntry                     MEDIA_ENTRY  < >
      GepReset                     GPR_STRUC    < >
      MediaCapabilities            dw   0                               ;Phy media capabilities in MiiPhyCapabilities format
      NwayAdvertisement_           dw   0                               ;Phy media advertisement in MiiPhy NWAY format
      FullDuplexBits               dw   0                               ;CSR6 FD Bits for each Mii Phy medium
      TxThresholdModeBits          dw   0                               ;CSR6 TTM Bits for each Mii Phy medium
      MIIConnectorInterrupt        db   0
      MiiPhyPresence               db   Absent    ;Is the phy present in Nic ?
      MiiPhySromID                 dd   GENERIC_PHY
MII_PHY_ENTRY   ends

;-------------------------
;SIA registers definitions
;-------------------------
;CSR15 value
;-----------
CSR15_TYPE      union
     struc
	SIA_    dw      0
	GEP_    dw      0               ;Twinet GEP is part of CSR15.
     ends
     Value      dd      ?
CSR15_TYPE      ends

;-----------------------------
;Nic data structure definition
;-----------------------------
NicType         struc

	;-------
	;Chip ID
	;-------
	union
	   Struc                                   ;To hold device and revision
	     Rev                   db          ?
	     Dev                   db          ?
	   ends
	  DevAndRev                dw          ?
	ends

	;------------------------
	;Driver Mode Information
	;------------------------
	DriverMode		   dw	      POWER_UP

	;------------------------
	;SYSTEM type Information
	; - CPU Type
        ; - BUS Types
	;------------------------
	SystemFlags		dw	0	                ;System indications (CPU type, bus types, etc.)
	BusType      		db      BUS_TYPE_UNDEFINED    	;Returnd from PCI BIOS search for the Device
	SlotNum			db	UNDEF_SLOT
	PCType			db	DEFAULT_PC

	;---------------
	;PCI Information
	;---------------
	PCIDeviceAccessHandle	dw	0    			;Returnd from PCI BIOS search for the Device

	;----------------------------
	;Power Management information
	;----------------------------
	PowerMode               dw	CFDA_RUN_MODE		;Required working mode 
	CurrentPowerMode	dw      CFDA_SLEEP_MODE 	;Device surrent mode (Starts in Sleep mode)

	;-----------------------
	;External reset sequence
	;-----------------------
	ExternalReset		GPR_STRUC < >

	;---------------------
	;Nic Media Information
	;---------------------
	union
	  struc
	    SelectedMedia         db           ?
	    SelectedOperationMode db           ?
	  ends
	  SelectedConnectionType  dw           NoSelectedConnection
	ends
	Media                     MEDIA_ENTRY  MAX_MEDIA_TABLE  dup (<>) ;List of DRIVER/CHIP supported medias and associated values
	DefaultMedia              db           NoSelectedMedia           ;Default media read from SROM(FasterNet only)
	UserSelectedDefaultMedia  db           False                     ;Was default media selected by user or is it driver's default ?
	MediaPrecedence           MediaPriorityStruc <>                  ;Media priorities Read from SROM(FasetrNet AutoSense Only)
	AutoSenseCapable          db           NOT  AUTOSENSE_CAPABLE
	
	;----------------------
	;Nic MiiPhy Information
	;----------------------
	NumMiiPhys      dw      0
	MiiPhysList     MII_PHY_ENTRY    MAX_PHY_TABLE  dup(<>)

	;---------------
	;Registers masks
	;---------------
	CSR8_MaskOFF                    dd      0       ;Masks OFF all unused bits.
	CSR6_OM_MaskOFF                 dd      0       ;Masks OFF all OM bits associated with this chip

	;------------------------------------------
	;Nic/Chip Dependent work-around indications
	;------------------------------------------
	RxFifoHangPresence              dw      Absent

	;---------------------------
	;Nic/Chip Dependent routines
	;---------------------------
	WriteCSR6                       dw      0
	WriteGEPRegister                dw      0
	ReadGEPRegister                 dw      0

	;---------------------
	;Registers Information
	;---------------------

	;Registers addresses
	;-------------------
	CSR0_Address               dw           0
	CSR1_Address               dw           0
	CSR2_Address               dw           0
	CSR3_Address               dw           0
	CSR4_Address               dw           0
	CSR5_Address               dw           0
	CSR6_Address               dw           0
	CSR7_Address               dw           0
	CSR8_Address               dw           0
	CSR9_Address               dw           0
	CSR10_Address              dw           0
	CSR11_Address              dw           0
	CSR12_Address              dw           0
	CSR13_Address              dw           0
	CSR14_Address              dw           0
	CSR15_Address              dw           0

	;Registers Values
	;----------------
	ConfigCFCS                 dw           ConfigCFCS_DEFAULT
	ConfigCFLT                 dw           configCFLT_DEFAULT        ;User CFLT overrides will be placed here.
	CSR0_Value                 dd           CSR0_DEFAULT              ;User PBL or CAL overrides will be placed here.
	CSR5_image                 dd           0                         ;value read from CSR5 (interrupt register)
	Shadow_CSR6                dd           TULIP_CSR6_DEFAULT        ;Contains the last value driver has written to CSR6.
									  ;At init time accumulates the customized keywords
									  ;TX_THRESHOLD value and CARRIER_STOPS_BACKOF_CTR.
	Shadow_CSR7                dd           CSR7_INTERRUPTS_MASK_VAL  ;Interrupt mask register 
	Shadow_CSR7_Mask           dd           0                         ;MASK "flag" used to temporary mask CSR7 interrupts
									  ;(CSR7 real value is (Shadow_CSR7 AND Shadow_CSR7_Mask))

	;SIA registers values
	;--------------------
	CSR13_Value                dd           CSR13_DEFAULT
	CSR14_Value                dd           CSR14_DEFAULT
	CSR15_                     CSR15_TYPE <>


NicType         ends


;******************************************************************************
;                               Usefull Macros 
;******************************************************************************
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       IsLegalMedia    macro
;
;               Checks if Media Code of the Media entry in the SROM is
;               legal or not.
;
;       assumes:
;
;            DC21041 Media Code Format
;            -------------------------
;                 7   6  5            0
;               +---+---+--------------+     
;               |Res|EXT|  Media Code  |
;               +----------------------+          
;
;            DC21140 Media Code Format
;            -------------------------
;                7   6 5              0
;               +--+--+----------------+     
;               | Res |  Media Code    | 
;               +--+--+----------------+
;         
;            DC21142 Media Code Format
;            -------------------------
;                 7   6  5            0
;               +---+---+--------------+     
;               |Res|EXT|  Media Code  |
;               +----------------------+          
;
;       returns:
;               Carry  SET   - Illegal media
;               Carry  RESET - Legal Media
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
IsLegalMedia    macro   MediaCode
	Local   @LegalMedia, @Exit

	push    MediaCode
	and     MediaCode, DC21X4_MEDIA_CODE_MASK
	cmp     MediaCode, MAX_MEDIA_TABLE
	jb      SHORT @LegalMedia
	
	stc                                     ;Illegal Media indication
	jmp     SHORT @Exit

@LegalMedia:
	clc                                     ;Legal Media indication
@Exit:
	pop     MediaCode
endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       IndexToOffset   macro
;
;       Returns the offset (address) of the specified element from the First element
;       in an array of elements
;
;       assumes:
;              AX - Will never be used for passing parameters
;              DX - Will never be used for passing parameters
;       returns:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
IndexToOffset   macro   ElementArray, ElementIndex, FirstElementIndex, ElementOffset

	push    ax
	push    dx
	mov     ax, ElementIndex
	sub     ax, FirstElementIndex
	mov     dx, TYPE ElementArray
	mul     dx                      ;ax = dx * ax
	mov     ElementOffset, ax
	pop     dx
	pop     ax

endm


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       GetMediaEntry        macro
;
;       Returns the offset (address) of the specified media in the Nic
;       Data Structure
;
;       assumes:
;       returns:
;              MediaType     - Destroyed
;              MediaEntruPTR - The desired offset.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GetMediaEntry   macro   MediaEntryPtr, MediaType

	and     MediaType, DC21X4_MEDIA_CODE_MASK   ;Keep mediaType bits only
	shl     MediaType, 1                        ;convert to Word Entry
	mov     MediaEntryPtr, Entry1[MediaType]    ;Notice That if media # will acceed 0fh
						    ;(meaning from 10h and above SHL will NOT work
endm                                                ;and the MSbit will be lost

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       IsMediaFD       macro
;
;       Returns if the media is full-duplex or not
;
;       assumes:
;       returns:
;              Zero flag SET   - Media is FD
;              Zero flag Reset - Media is NOT FD
;              MediToCheck     - Reserved Bits are reset to 0,
;                                other bits are preserved.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
IsMediaFD       macro   MediaToCheck
	Local   @Done

	push    MediaToCheck
	and     MediaToCheck, DC21X4_MEDIA_CODE_MASK

	cmp     MediaToCheck, MediaTPFD
	je      SHORT @Done
	cmp     MediaToCheck, MediaSymScrFD
	je      SHORT @Done
	cmp     MediaToCheck, Media100BaseFxFD
	je      SHORT @Done
	cmp     MediaToCheck, MediaMiiTpFD
	je      SHORT @Done
	cmp     MediaToCheck, MediaMii100BaseTxFD
	je      SHORT @Done
	cmp     MediaToCheck, MediaMii100BaseFxFD
@Done:
	pop     MediaToCheck

endm

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       IsLegalConnection       macro
;
;       Returns if the media type is legal in the given connection or not
;
;       assumes:
;
;       returns:
;              Carry flag SET  - Media is Illegal
;              Carry flag Reset- Media is NOT FD
;              MediToCheck     - Reserved Bits are reset to 0,
;                                other bits are preserved.
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
IsLegalConnection       macro   ConnectionToCheck
	Local   @IllegalConnection,@ExitCheck

	cmp     BYTE PTR ConnectionToCheck, MAX_MEDIA
	ja      SHORT @IllegalConnection
	clc
	jmp     SHORT @ExitCheck
@IllegalConnection:
	stc
@ExitCheck:

endm

