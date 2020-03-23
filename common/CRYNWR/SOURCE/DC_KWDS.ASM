PAGE    ,132
NAME    DC_KWDS
TITLE   DC_KWDS  --  Digital Internal Use Only

;***************************************************************************
;*
;*    Copyright (c) 1993 - 1997
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

;***************************************************************************
;
;     This module deals with the process of the keywords from the
;     protocol.ini . The keywords are parsed, and put into the public
;     structure UserKWDS. It was formerly a part of macinit module.
;
;***************************************************************************

.xlist                                  ; disable listing the include file
include seg_defs.inc
include driver.inc
include ndis.inc
include dc_kwds.inc
include dc_regs.inc
include syssrvcs.inc
include nic.inc
include dc_kwds.ash
.list                                   ; enable listing
.386

; The defparm macro is used to build the KWDKeywords table. The KWDKeywords
; table holds the PROTOCOL.INI keyaords that this driver supports. See the
; declaration of KWDKeywords below for more details.
;
defparm         MACRO   kp_len, kp_min, kp_max, kp_store, kp_name
                DW      kp_len
                DW      kp_min
                DW      kp_max
                DW      kp_store
                DB      kp_name
                ENDM

; This structure is used by KWDProcessKeyword to translate a string
; PROTOCOL.INI parameter to a word-length numeric value. It is also
; used for printing keyword values.

stringtrans     STRUC
st_string       db      32 DUP (0)
st_value        dw      ?
stringtrans     ENDS

; Struct used for the translation of the ConnectionType
; keyword, into separate SiaMode and DataRate. The size of this
; structure must be 4. If it is changed, the translation routine
; must be changed too.

ConnectionTypeTrans     STRUC
ct_SiaMode      dw	-1
ct_DataRate     dw	-1
ConnectionTypeTrans     ENDS


START_DATA_SEGMENT_INIT

	include	tolower.asm

;----------------------------------------------------------------------------
; The following variables hold the adapter configuration values as extracted
; from PROTOCOL.INI.
;----------------------------------------------------------------------------
KWDPIName              DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
KWDConnectionType      KwdEntrySTRUC <>
KWDExtMWI	       KwdEntrySTRUC <>
KWDExtMRL	       KwdEntrySTRUC <>
KWDExtMRM	       KwdEntrySTRUC <>
KWDPINetAddress        DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;----------------------------------------------------------------------------
; Definitions of keywords which can be set in the PROTOCOL.INI file
; for the driver's use
;----------------------------------------------------------------------------
KWDKeywords    LABEL   BYTE

defparm 16,     0,     0,      KWDPIName, <'drivername',0,0,0,0,0,0>
defparm 2,      0,     26,     UserKWDS.SlotNumber_UV, <'slot',0,0,0,0,0,0,0,0,0,0,0,0>
defparm 2,      4,     16,     UserKWDS.TXBuffers_UV, <'num_tx_buffers',0,0>
defparm 2,      4,     16,     UserKWDS.TXBuffers_UV, <'transmitbuffers',0>
defparm 2,      4,     16,     UserKWDS.RXBuffers_UV, <'num_rx_buffers',0,0>
defparm 2,      4,     16,     UserKWDS.RXBuffers_UV, <'receivebuffers',0,0>

GprCtrlParm     LABEL   BYTE   ; DEBUG parameter: Not published in README
defparm 2,      0,    512,     UserKWDS.GPR_Ctrl_UV,<'gen_purpose_ctl',0>
GprDataParm     LABEL   BYTE   ; DEBUG parameter: Not published in README
defparm 2,      0,    512,     UserKWDS.GPR_Data_UV,<'gen_purpose_dat',0>

SIAdefparm      LABEL   BYTE
defparm 16,     OFFSET SIAparams, 0, UserKWDS.SelectedConnectionType_UV, <'sia_mode',0,0,0,0,0,0,0,0>
defparm 32,     OFFSET ConnectionTypeParams, 0, KWDConnectionType, <'connectiontype',0,0>
defparm 16,     OFFSET TxTrparams, 0, UserKWDS.TxTHR_UV, <'tx_threshold',0,0,0,0>
defparm 16,     OFFSET CRCparams, 0, UserKWDS.SwCRC_UV, <'software_crc',0,0,0,0>
defparm 2,      0, 1,  UserKWDS.SwCRC_UV, <'softwarecrc',0,0,0,0,0>
defparm 16,     OFFSET TURBOparams, 0, UserKWDS.Turbo_UV,<'turbo',0,0,0,0,0,0,0,0,0,0,0>
defparm 16,     OFFSET MULTIAparams, 0,UserKWDS.PcType_UV,<'multia',0,0,0,0,0,0,0,0,0,0>
defparm 16,     OFFSET SNOOZEparams, 0,UserKWDS.Snooze_UV,<'snooze',0,0,0,0,0,0,0,0,0,0>
defparm 2,      0, 1,  UserKWDS.Snooze_UV,<'snoozemode',0,0,0,0,0,0>
defparm 2,      0, 32, UserKWDS.PBL_UV,<'burstlength',0,0,0,0,0>
defparm 2,      1, 0FFh, UserKWDS.CFLT_UV,<'pcilatencytimer',0>
defparm 2,      32, 128, UserKWDS.CAL_UV,<'cachelinesize',0,0,0>
defparm 2,      0, 1, KWDExtMWI,<'ext_mwi',0,0,0,0,0,0,0,0,0>
defparm 2,      0, 1, KWDExtMRL,<'ext_mrl',0,0,0,0,0,0,0,0,0>
defparm 2,      0, 1, KWDExtMRM,<'ext_mrm',0,0,0,0,0,0,0,0,0>

DataRatedefparm  LABEL   BYTE
defparm 16,     OFFSET DataRateparams, 0, UserKWDS.LineSpeed_UV,  <'data_rate',0,0,0,0,0,0,0>
defparm 16,     0,      0,      KWDPINetAddress,  <'netaddress',0,0,0,0,0,0>


NUMKEYWORDS     equ     (($-KWDKeywords)/(SIZE knownparams))


;----------------------------------------------------------------------------
; Optional values for the string-valued keywords settable
; in the PROTOCOL.INI file.
;----------------------------------------------------------------------------
SIAparams       LABEL   BYTE    ; define the valid SIA_MODE parameter strings,
                                ; and the equivalent KWDPISIA value for each.
stringtrans     {'autodetect',          ConnectionAutoSense}
stringtrans     {'autosense',           ConnectionAutoSense}
stringtrans     {'tp',                  ConnectionTp}
stringtrans     {'aui',                 ConnectionAui}
stringtrans     {'bnc',                 ConnectionBnc}
stringtrans     {'t4',                  Connection100BaseT4}
stringtrans     {'tp_full_duplex',      ConnectionTpFD}
stringtrans     {'tp_link_disable',     ConnectionTpLinkDisable}
        DB      0               ; mark end of array


TxTrparams      LABEL   BYTE    ; define translation values for transmit
                                ; threshold in CSR6 .
stringtrans     {'lw128',       TX_THRESHOLD_72}
stringtrans     {'lw256',       TX_THRESHOLD_96}
stringtrans     {'lw512',       TX_THRESHOLD_128}
stringtrans     {'lw1024',      TX_THRESHOLD_160}
stringtrans     {'fp',          TX_THRESHOLD_FP}
        DB      0               ; mark end of array


CRCparams       LABEL   BYTE    ; define the valid SOFTWARE_CRC param strings,
                                ; and the equivalent XmtCRCThreshold for each.
stringtrans     {'enabled',	ALWAYS_CALC_SOFTWARE_CRC}     ; generate CRC
stringtrans     {'disabled',    NEVER_CALC_SOFTWARE_CRC}    ; don't generate CRC
        DB      0               ; mark end of array

TURBOparams     LABEL   BYTE    ; define the valid TURBO param strings,
                                ; and the equivalent KWDTurbo for each.
stringtrans     {'enabled',             1}     ; Disable HPPE bit if relevant.
stringtrans     {'disabled',            0}     ; Don't touch HPPE bit.
        DB      0               ; mark end of array

MULTIAparams     LABEL   BYTE   ; define the valid MULTIA param strings,
                                ; and the equivalent KWD_MULTIA for each.
stringtrans     {'yes',             	MULTIA_PC}  ; Use of 'Multia' board
        DB      0               ; mark end of array

SNOOZEparams     LABEL   BYTE    ; define the valid SNOOZE param strings,
                                 ; and the equivalent KWDSnooze for each.
stringtrans     {'enable',             1}     ; Enable Snooze mode.
stringtrans     {'disable',            0}     ; Disable Snooze mode.(default)
        DB      0               ; mark end of array

DataRateparams  LABEL   BYTE    ; define the valid DATA_RATE param strings,
                                ; and the equivalent Data Rate for each.
stringtrans     {'mb10',             10}     ; Line speed - 10MB
stringtrans     {'mb100',            100}    ; Line speed - 100MB
        DB      0               ; mark end of array

ConnectionTypeParams	LABEL	BYTE	; defines the valid ConnectionType strings,
					; and the equivalent entry in the ConnetionType
					; translation table.
stringtrans	{'autosense',			0}     ; Connection type - Autosense
stringtrans	{'autodetect',			0}     ; Connection type - Autodetect
stringtrans	{'_10base2_(bnc)',		1}     ; Connection type - BNC
stringtrans	{'_10baset',			2}     ; Connection type - TP 10
stringtrans	{'_10baset_fd',			3}     ; Connection type - TP 10 FDX
stringtrans	{'_10baset_no_link_test',	4}     ; Connection type - TP 10 Link Disable
stringtrans	{'_10base5_(aui)',		5}     ; Connection type - AUI
stringtrans	{'_100basetx',			6}     ; Connection type - TP 100
stringtrans	{'_100basetx_fd',		7}     ; Connection type - TP 100 FDX
stringtrans	{'_100baset4',			8}     ; Connection type - T4
	DB	0

ALIGN 4
ConnetionTypeTranslationTable  LABEL	BYTE	; defines the translation table of
						; ConnectionType to SIA_MODE and DATA_RATE
ConnectionTypeTrans 	{ConnectionAutoSense,	10}	;ConnectionType = Autosense/Autodetect
ConnectionTypeTrans 	{ConnectionBnc,		10}	;ConnectionType = BNC
ConnectionTypeTrans 	{ConnectionTp,		10}	;ConnectionType = TP
ConnectionTypeTrans 	{ConnectionTpFD,	10}	;ConnectionType = TP_FULL_DUPLEX
ConnectionTypeTrans 	{ConnectionTpLinkDisable,10}	;ConnectionType = TP_LINK_DISABLED
ConnectionTypeTrans 	{ConnectionAui,		10}	;ConnectionType = AUI
ConnectionTypeTrans 	{ConnectionTp,		100}	;ConnectionType = TP_100
ConnectionTypeTrans 	{ConnectionTpFD,	100}	;ConnectionType = TP_100_FULL_DUPLEX
ConnectionTypeTrans 	{Connection100BaseT4,	100}	;ConnectionType = T4
ConnectionTypeTrans 	{Connection100BaseFx,	100}	;ConnectionType = FX
ConnectionTypeTrans 	{Connection100BaseFxFD,	100}	;ConnectionType = FX_FULL_DUPLEX

;---------------------------------------------------------------
; The following are used for translating user-defined IEEE addresses to
; internal driver tables format.
KWDHexByteTb    DB "0123456789ABCDEF0123456789abcdef"
EvenFlag        DB      0  ; toggle flag for translation


;----------------------------------------------------------------------------
;
; Driver Messages Printed During Init stage
;
;----------------------------------------------------------------------------
CR EQU 0Dh      ; ASCII Carriage Return
LF EQU 0Ah      ; ASCII Line Feed

KWDMsg_warning     DB 'DC_KWDS Warning: ',0

KWDMsg_PI_ik       DB 'Invalid keyword in PROTOCOL.INI.',CR,LF,0

KWDMsg_PI_many_params       DB 'PROTOCOL.INI keyword has too many parameters.',CR,LF,0

KWDMsg_PI_few_params       DB 'PROTOCOL.INI keyword has too few parameters.',CR,LF,0

KWDMsg_PI_low       DB 'PROTOCOL.INI parameter too low, ignored.',CR,LF,0

KWDMsg_PI_high       DB 'PROTOCOL.INI parameter too high, ignored.',CR,LF,0

KWDMsg_PI_long       DB 'PROTOCOL.INI string parameter too long, ignored.',CR,LF,0

KWDMsg_PI_invstr     DB 'Invalid PROTOCOL.INI string parameter, ignored.',CR,LF,0

KWDMsg_Invalid_Cal   DB 'Invalid PROTOCOL.INI cache line parameter, ignored.',CR,LF,0

KWDMsg_no_PI_info    DB 'FATAL - Could not get protocol.ini information.',CR,LF,0

KWDMsg_no_mac_entry  DB 'FATAL - MAC driver entry does not exist in protocol.ini.',CR,LF,0
;-------------------------------------------------------------------------------
;               Data structure used to hold user selections
;-------------------------------------------------------------------------------
UserKWDS	UserSelectionsSTRUC     <>
two_words	dd	?

END_DATA_SEGMENT_INIT

        PAGE

START_CODE_SEGMENT_INIT


        PAGE
ParseKWDS PROC NEAR
; we really parse them in parse_params
	clc
	ret
ParseKWDS ENDP

;parse_args is called with si -> first parameter (CR if none).
	public	parse_args
parse_args:
	push	ds
	pop	es

parse_args_0:
	extrn	skip_blanks: near
	call	skip_blanks
	cmp	al,CR			; end of the list?
	je	parse_args_1		; yes, done.
	mov	bx, OFFSET cgroup:KWDKeywords	; get the list of known KWDKeywords
	mov	cx, NUMKEYWORDS		; and the count of them.
parse_args_2:
	push	si
	lea	di,[bx].knownparams.kp_name
parse_args_4:
	lodsb
	call	to_lower
	cmp	al,[di]	
	jne	parse_args_3		; no match, but might be delimiter.
	inc	di			; keep going.
	jmp	parse_args_4
parse_args_3:
	mov	al,[si-1]
	cmp	al,'='			; end of KEY=VALUE?
	jne	parse_args_5		; no, just a mismatch.
	cmp	byte ptr [di],0		; end of the keyword string?
	jne	parse_args_5		; no, just a mismatch.
; si -> value.
	add	sp,2			; was pushed as si.
	cmp	[bx].knownparams.kp_len,2	; integer or string
	jne	parse_args_6		; integer is two bytes long.
	mov	di,offset cgroup:two_words
	extrn	get_number: near
	push	bx
	call	get_number		; returns cy if no digits at all.  cx=number.
	pop	bx
        cmp	cx, [bx].knownparams.kp_min ; check for lower than min
        jl	kpk_lower
        cmp	cx, [bx].knownparams.kp_max ; check for higher than max
        jg	kpk_higher
        mov	di, [bx].knownparams.kp_store ; get offset
        mov	WORD PTR ds:[di].KwdEntrySTRUC.Selected, TRUE
        mov	WORD PTR ds:[di].KwdEntrySTRUC.Wval, cx	      ; save value
	jmp	parse_args_0		; continue with the next argument.

parse_args_6:
;we have a string parameter.
	mov	di, [bx].knownparams.kp_store	; where to store the parameter
	cmp	[bx].knownparams.kp_min, 0	; translate to numeric?
	jne	kpk_translate			; branch if yes

	push	cx			;we're gonna need it later.
	mov	cx, [bx].knownparams.kp_len	; get max. length allowed
kpk_store:
	lodsb
	stosb
	cmp	al,' '
	je	kpk_store_1
	cmp	al,CR
	loopne	kpk_store
	dec	si			; point si to the CR again.
kpk_store_1:
	xor	al,al			; store a terminating null.
	dec	di
	stosb
	pop	cx
	jmp	parse_args_0		; continue with the next argument.

kpk_translate:
	mov	di, [bx].knownparams.kp_min ; -> array of stringtrans structs
kpk_translate_again:
	push	si
	push	di
kpk_check_trans:
	lodsb
	call	to_lower
	cmp	al,[di]	
	jne	kpk_check_trans_1
	inc	di
	jmp	kpk_check_trans
kpk_check_trans_1:
	mov	al,[di]			; end of keyword?
	or	al,al			; no, no match.
	jne	kpk_check_trans_3
	mov	al,[si-1]		; did it match?
	cmp	al,' '
	je	kpk_check_trans_2	;yes.
	cmp	al,CR
	jne	kpk_check_trans_3	;no
	dec	si			; point si at the CR.
kpk_check_trans_2:
	pop	di
	add	sp,2			; pushed as si.
	mov	ax, ds:[di].stringtrans.st_value ; get value for this string
	mov	di, [bx].knownparams.kp_store	; where to store the parameter
	mov	[di].KwdEntrySTRUC.Selected, TRUE         ; mark as selected
	mov	[di].KwdEntrySTRUC.Wval, ax               ; store it!
	jmp	parse_args_0		; continue with the next argument.

kpk_check_trans_3:
	pop	di
	pop	si
	add	di, SIZEOF stringtrans	; no, advance to next stringtrans
	cmp	BYTE PTR ds:[di], 0	; have we checked them all?
	jne	kpk_translate_again	; branch if not -- try this one

	jmp	kpk_invalid_parm	; announce invalid string parameter

parse_args_5:
	pop	si
	add	bx, size knownparams	; skip try the next keyword.
	dec	cx
	jne	parse_args_2
	DataAddress	dx, KWDMsg_PI_ik
	stc
	ret
kpk_lower:
	DataAddress	dx, KWDMsg_PI_low
	stc
	ret
kpk_higher:
	DataAddress	dx, KWDMsg_PI_high
	stc
	ret
kpk_invalid_parm:
        DataAddress	dx, KWDMsg_PI_invstr
	stc
	ret
parse_args_1:
	push	si			; preserve this for continued argument parsing.
	call	KWDTranslateKeywords
	pop	si
	clc
	ret




;*****************************
; KWDTranslateConnectionType *
;*****************************
;  This routine translates the single keyword
;  ConnectionType into the pair SiaMode and DataRate

KWDTranslateConnectionType PROC NEAR
	mov    	si, KWDConnectionType.Wval	; index in the translatin table
	shl	si, 2				; multiply by 4 - the size of one table entry

	mov	ax, ConnetionTypeTranslationTable[si].ConnectionTypeTrans.ct_SiaMode
	mov	UserKWDS.SelectedConnectionType_UV.Wval, ax
	mov	UserKWDS.SelectedConnectionType_UV.Selected, TRUE

	mov	ax, ConnetionTypeTranslationTable[si].ConnectionTypeTrans.ct_DataRate
	mov	UserKWDS.LineSpeed_UV.Wval, ax
        mov	UserKWDS.LineSpeed_UV.Selected, TRUE

	ret
KWDTranslateConnectionType ENDP


KWDTranslateSlot PROC NEAR
;*******************
; KWDTranslateSlot *
;*******************
;  This routine translates the user slot selection from the
;  range of 16-26 to the range of 1-11. It also sets the BusType
;  selection to PCI_BUS_TYPE. It will be changed when CardBus
;  support is inserted

	mov	ax, UserKWDS.SlotNumber_UV.Wval
	cmp	ax, 0
	je	kts_exit
	cmp	ax, 16
	jl	kts_illegal_slot
	cmp	ax, 26
	jg	kts_illegal_slot

	sub	ax, 15
	mov	UserKWDS.SlotNumber_UV.Wval, ax
	mov	UserKWDS.BUS_UV.Selected, TRUE
	mov	UserKWDS.BUS_UV.Wval, BUS_TYPE_PCI

	jmp	kts_exit
kts_illegal_slot:
	mov	UserKWDS.SlotNumber_UV.Selected, FALSE

kts_exit:
	ret
KWDTranslateSlot ENDP


;******************
; KWDTranslateCal *
;******************
;  This routine translates the legal user cal keyword,
;  (the cache line size) into the value written into CSR0
;  bits 14-15. The legal values - 16, 32, 64, 128 are translated
;  to 0-3. The routine uses ax, cx, and si.
;
KWDTranslateCal PROC NEAR
	mov	ax, UserKWDS.CAL_UV.Wval
	cmp	ax, 32
	je	ktc_cal_32
	cmp	ax, 64
	je	ktc_cal_64
	cmp	ax, 128
	je	ktc_cal_128

;
; Error Message for invalid CAL  (NON-FATAL)
;
        DataAddress	dx, KWDMsg_warning
        call	DisplayMessage

        DataAddress	dx, KWDMsg_Invalid_Cal
        call    DisplayMessage

	mov	UserKWDS.CAL_UV.Selected, False
	jmp	ktc_exit

ktc_cal_32:
	mov	UserKWDS.CAL_UV.Bval, 1
	jmp	ktc_exit

ktc_cal_64:
	mov	UserKWDS.CAL_UV.Bval, 2
	jmp	ktc_exit

ktc_cal_128:
	mov	UserKWDS.CAL_UV.Bval, 3

ktc_exit:
	ret
KWDTranslateCal ENDP


;**********************
;* KWDTranslateExtPCI *
;**********************
;  This routine translates the three keywords for the three
;  extended PCI commands into one bitmask of the relevant bits
;  in CSR0. The bitmask is a "disabling bitmask", which means
;  that the bits that are set disable their respective extended
;  PCI commends.
;
KWDTranslateExtPCI PROC NEAR
	mov	UserKWDS.ExtPCIOFF_UV.Selected, TRUE

	cmp	KWDExtMWI.Selected, TRUE
	jne	ktep_mrm
	cmp	KWDExtMWI.Wval, 0
	jne	ktep_mrm

	or	UserKWDS.ExtPCIOFF_UV.Wval, MWI_capable
ktep_mrm:
	cmp	KWDExtMRM.Selected, TRUE
	jne	ktep_mrl
	cmp	KWDExtMRM.Wval, 0
	jne	ktep_mrl

	or	UserKWDS.ExtPCIOFF_UV.Wval, MRM_capable
ktep_mrl:
	cmp	KWDExtMRL.Selected, TRUE
	jne	ktep_exit
	cmp	KWDExtMRL.Wval, 0
	jne	ktep_exit

	or	UserKWDS.ExtPCIOFF_UV.Wval, MRL_capable
ktep_exit:
	ret
KWDTranslateExtPCI ENDP


KWDTranslateEthernetAddress PROC NEAR

	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di

; check if user has specified an IEEE address in PROTOCOL.INI.
	mov     si, OFFSET KWDPINetAddress
	cmp     DWORD PTR [si], 0
	jne     ktea_user_address
	cmp     DWORD PTR [si+4], 0
	jne     ktea_user_address
	cmp     DWORD PTR [si+8], 0
	jne     ktea_user_address
	jmp     ktea_exit     ; User hasn't specified anything else, quit

; User specified IEEE address in PROTOCOL.INI . Copy from there.
; Two loops: external loop goes over 12 nibbles of address(= 6 bytes).
; Internal loop translates each nibble to value. Note that the user inputted
; 12 BYTES in ascii format, which are then translated to 6 bytes in actual
; memory. Each of the user's bytes is translated to one nibble in the data
; tables. For this reason EvenFlag is used and toggled.
ktea_user_address:
	mov     di, OFFSET UserKWDS.NetAddress_UV
	mov	BYTE PTR [di], TRUE
	inc	di
	mov     cx, 12
ktea_user_IEEE:
	push    ax
	push    cx
	mov     ax, 0
	mov     bx, OFFSET KWDHexByteTb
	mov     cx, 01Fh
ktea_str_to_int:
	mov     dx, WORD PTR [bx]
	cmp     BYTE PTR [si], dL
	je      ktea_str_found
	inc     bx
	inc     ax
	loop    ktea_str_to_int

ktea_str_found:
	and     al, 0Fh
	cmp     EvenFlag, 0
	je      ktea_str_found_even
	or      [di], al
	inc     di
	mov     EvenFlag, 0
	jmp     ktea_str_found_cont

ktea_str_found_even:
	shl     ax, 4
	mov     [di], al
	mov     EvenFlag, 1

ktea_str_found_cont:
	pop     cx
	pop     ax
	inc     si
	loop    ktea_user_IEEE

ktea_exit:
	pop  	di
	pop     si
	pop     dx
	pop     cx
	pop     bx
	pop     ax
	ret

KWDTranslateEthernetAddress endp


;**************************************************
;   KWDTRANSLATEKEYWORDS
;
;   This routine translates a certain keywords to
;   a different presentation. It transforms:
;   1. ConnectionType -> SIA_MODE + DATA_RATE
;   2. CacheAlignment - 16,32,64,128 -> 1,1,2,3 resp.
;   3. Slot -> Slot + Bus
;   4. EXT_MRM, EXT_MRL, EXT_MWI -> ExtPCIOff bitmask
;   5. NetAddress - string -> IEEE 6 bytes address
;***************************************************
KWDTranslateKeywords PROC NEAR

	cmp	KWDConnectionType.Selected, TRUE
	jne	ktk_cal
	call	KWDTranslateConnectionType

ktk_cal:
	cmp	UserKWDS.CAL_UV.Selected, TRUE
	jne	ktk_slot
	call	KWDTranslateCal

ktk_slot:
	cmp	UserKWDS.SlotNumber_UV.Selected, TRUE
	jne	ktk_ext_mwi
	call	KWDTranslateSlot

ktk_ext_mwi:
	mov	al, KWDExtMWI.Selected
	or	al, KWDExtMRM.Selected
	or	al, KWDExtMRL.Selected
	jz	ktk_net_address
	call	KWDTranslateExtPCI

ktk_net_address:
	call	KWDTranslateEthernetAddress

	shl	UserKWDS.CFLT_UV.WVal, 8	; shift the latency timer selection
					; to the correct bits in CFLT

ktk_exit:
	ret
KWDTranslateKeywords ENDP


END_CODE_SEGMENT_INIT
END

