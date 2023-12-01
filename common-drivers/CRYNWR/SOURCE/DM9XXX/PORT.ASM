;*****************************************************************************
;* Name : PORT.ASM
;*
;* All rights reserved by DAVICOM, 1996
;*
;* Description :
;*
;* Functions :
;*      . PortInit
;*      . PortReadTickCounter
;*      . PortUpdateReceiveFilter
;*      . PortReset
;*      . PortResetDelay
;*      . PortPrintMessage
;*      . PortCR6Write
;*      . DM9009_Media
;*      . DM9009_Link_Check
;*
;
; Maintainers:
;
; John H.T. Ho          htho
;
;
; Revision History:
;
; Date       Modfier.   Modification Descriptions
; ---------- ---------- ------------------------------------------
; 2000.1.31     htho    support 1M HomePNA
;
; 2000.2.16     htho    dynamicaly keep a image of CR6 in [PortConfigCR6]
;
; 2000.2.21     htho    while PortReset(), set [PortConfigCR6] to CR6_DEFAULT
;                       first then set [PortConfigCR6] and CR6 according to
;                       system configuration
;
; 2000.3.9      htho    reset Ignore Remote Commands bit of DM9801 Reg 16
;                       and set the noise level for long line
;
; 2000.3.27     htho    check if PNAPHY is there before accessing it
;                       select PNAPHY before setting noise level
;                       change CR6_DEFAULT from 002C0000h to 02040000h
;                       reset noise level while dynamic auto detect select dm9801
;
; 2000.4.6      htho    rewrite check auto complete flow
;                       won't do dynamic auto detect if force media to HomePNA
;
; 2000.5.2      htho    support LONGRUN HomePNA:
;                       set Reg 16, 25 in PortReset() and DynamicAutoDetect()
;
; 2000.6.21     htho    set speed/power for HOMEPNA
;
; 2000.6.27     htho    set ignore/send remote command for HOMEPNA
;                       rewrite PNA PHY setting
;                       switching adapter support
;
; 2000.8.24     htho    support DM9009(DM9102 without 100M PHY capability)
;                       support VLAN & Tx/Rx flow control
;
; 2000.9.19     htho    support DM9801 E4
;
; 2000.10.4     htho    simulate line plug out/in by power off/on phy for DM9102A E3
;
; 2001.3.30     htho    support HPNA speed setting
;
; 2001.5.25     htho    different 9801 R24/R25 operation between E3 and E4/5...
;
; 2001.6.12     htho    default lspeed=1000 instead of 700
;
; 2001.6.12     htho    error CR31 value while lseedp=500 for homerun
;
; 2000.6.12     htho    renew nway algorithm. If partner nway incapable,
;                       disable nway and force it to the mode that user set
;
; 2001.6.12     htho    we need to write at last 2 times to dm9102a E3 to
;                       force it to correct mode after power on/off it
;
; 2001.6.21     htho    dual speed hub link fail while forced 10/100 full duplex
;
; 2001.8.13     htho    Reset PNA PHY to avoid accumulation of Noise Floor in
;                       Reg. 25 of DM9801 E3 while user warm restart the PC
;                       or unload/load driver again.
;                       This reset must take the PNA PHY a few seconds to
;                       reach a stable state, so we must pospond the pna phy
;                       setting some time later (after startup auto).
;*
;*****************************************************************************
.386

include dm9100.mac
;;include hw.inc
include hardware.asd
include phy.inc

EXTRN   rom_address : BYTE
EXTRN   my_address : BYTE
EXTRN   flagword : WORD

EXTRN   Syn_PHY : NEAR
EXTRN   Read_Register_PHY : NEAR
EXTRN   Write_Register_PHY : NEAR

Debug_eaddr_msg db      "ROM ehternet address : ",'$'

;;++, 2000.6.21, htho, set speed/power for HOMEPNA
ifdef HOMEPNA
        PUBLIC  pna_cr16
;
; Default value of "Disable Increment of Noise" (Reg.16[12])
;       HOMERUN = 1 -- disable 25% increase of noise slice
;       LONGRUN = 0 -- normal operation
; This will be done in Setup_HOMERUN_PHY()/Setup_LONGRUN_PHY
;
pna_cr16        dw      8005h   ; default=ignore/high speed/low power
         PUBLIC  p_PHY24 ; add by simon 2001.8.30
p_PHY24          dw   0
endif
;;++
;;;;++, 2000.6.27, htho
ifdef HOMEPNA
        PUBLIC  send_remote_cmd
send_remote_cmd         db      0       ; default = don't send remote command

        PUBLIC  pna_power_cmd, pna_speed_cmd
pna_power_cmd           dw      0800h   ; command low power
pna_speed_cmd           dw      0100h   ; command high speed

        PUBLIC  resend_remote_cmd_cnt, resend_remote_cmd_timer
resend_remote_cmd_cnt   db      0
resend_remote_cmd_timer dw      0
endif

        PUBLIC  switch_adapter
switch_adapter  db      0      ; 0 - none switch adapter, 1 - half, 2 - full
;;;;++

        PUBLIC  PortConfigCR0
;; Debug
;;-+, 980414, Hu-Tiong
;;PortConfigCR0          DD             (CR0_K_TXAP_NONE SHL CR0_V_TXAP) OR \
;;                                       (CR0_K_CA_0LW SHL CR0_V_CA) OR \
;;                                       (CR0_K_BL_0LW  SHL CR0_V_BL) OR \
;;                                       (CR0_K_DGW_1LW  SHL CR0_V_DGW)
;;-+, 2000.2.17, htho
;PortConfigCR0          DD             (CR0_K_TXAP_NONE SHL CR0_V_TXAP) OR \
;                                      (CR0_K_CA_0LW SHL CR0_V_CA) OR \
;                                      (CR0_K_BL_0LW  SHL CR0_V_BL) OR \
;                                      (CR0_K_DGW_4LW  SHL CR0_V_DGW)
PortConfigCR0           DD             00C00000h
;;-+
;;-+


        PUBLIC  PortConfigCR6

;;-+, 2000.3.27, htho
;;CR6_DEFAULT             EQU     002C0000h
CR6_DEFAULT             EQU     02040000h
;;-+
ifdef SINGLE_PORT
PortConfigCR6           DD      (CR6_DEFAULT OR CR6_M_ISRW)
else
PortConfigCR6           DD      CR6_DEFAULT
endif

;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
        PUBLIC  vlan, fcrx, fctx
PortConfigCR15          dd      000000006h
vlan                    db      0       ; vlan = 0: disable(default), 1: enable
fcrx                    db      0       ; fcrx = 0: disable(default), 1: enable
fctx                    db      0       ; fctx = 0: disable(default), 1: enable
;;;;++

;;;;++, 2000.9.19, htho, support DM9801 E4
pnaphy_rev      db      ?
;;;;++

;;;;++, 2000.10.4, simulate line plug out/in by power off/on phy for DM9102A E3
dm9102a_e3      db      0
;;;;++

;;++, 2001.3.30, htho, support HPNA speed setting
        PUBLIC LSpeedNum
;;-+, 2001.6.12, htho, default lspeed=1000 instead of 700
LSpeedNum       dw      1000            ; must one of {1000, 500, 1400, 1600}
;;-+
pna_cr29        dw      ?
pna_cr30        dw      ?
pna_cr31        dw      ?
;;++

;;++, 980923, Hu-Tiong
BMCR_M_RST      EQU     8000h   ; Reset mask
BMCR_M_LB       EQU     4000h   ; loopback mask
BMCR_M_SL       EQU     2000h   ; Speed Select mask
BMCR_M_ANE      EQU     1000h   ; Auto-Negotiation Enable Mask
BMCR_M_IS       EQU     0400h   ; Isolate mask
BMCR_M_RAN      EQU     0200h   ; Restart Auto-Negotiation mask
BMCR_M_DM       EQU     0100h   ; Duplex Mode mask
BMCR_M_CT       EQU     0080h   ; Collision Test

ANAR_RF         EQU     0200h   ; remote fault
ANAR_FCS        EQU     0400h   ; Flow Control Support
ANAR_T4         EQU     0200h   ; 100BASE-T4 Support
ANAR_TX_FDX     EQU     0100h   ; 100BASE-TX Full Duplex support
ANAR_TX_HDX     EQU     0080h   ; 100BASE-TX Half Duplex support
ANAR_10_FDX     EQU     0040h   ; 10BASE-T Full Duplex support
ANAR_10_HDX     EQU     0020h   ; 10BASE-T Half Duplex support
ANAR_CSMACD     EQU     0001h   ; device supports IEEE 802.3 CSMA/CD

ANAR_CAP_MASK   EQU     03E0h   ; advertisement capability mask ANAR[5..9]
ANAR_CAP_ALL    EQU     (ANAR_TX_FDX+ANAR_TX_HDX+ANAR_10_FDX+ANAR_10_HDX)

ANAR_DEFAULT_VAL        EQU     (ANAR_FCS+ANAR_CAP_ALL+ANAR_CSMACD)

anar            dw      ANAR_DEFAULT_VAL
;;++

SROMImage               DW 0  ; Contains base address of SROM memory image
                              ; (Physically - data buffer of first rcv desc)

AdapterNum              DB 0  ; Num of adapter as entry in SROM. default: 0
                              ; meaning that only one adapter is present.

        PUBLIC  SROMPortFlag
SROMPortFlag        DB      0     ; Port type : 0 - TP, 1 - Full Duplex TP.
                                  ;             2 - AutoSense
                                  ;             3 - T4
                                  ;             4 - 1M HOME PNA

        PUBLIC  InitPIDataRate
InitPIDataRate      DW      10    ; Init Data rate (stored here
                                  ; in order that it won't be deleted )

        PUBLIC  PHY_Number, PHYTYPE
PHY_Number      DB      1       ; PHY address
PHYTYPE         DB      DSIPHY
;;;;++, 2000.5.2, htho
                PUBLIC  PNATYPE
HOMERUN         EQU     0
LONGRUN         EQU     1
PNATYPE         DB      HOMERUN
;;;;++

DM9009_CR12_image       DD      0

        PUBLIC  CR6_image
CR6_image       DD      ?


; Variables for storing SROM/Final Values of 90100 GPR -
UM9100_GprCtrl         DW 0100h

UM9100_GprData10       DW 00h
UM9100_GprData100      DW 00h
UM9100_GprDataFD10     DW 00h
UM9100_GprDataFD100    DW 00h

SROM_COMM10             DB 01Dh
SROM_COMM100            DB 08Dh
SROM_COMMFD10           DB 01Dh
SROM_COMMFD100          DB 08Dh

;;
; Flag saying if an interrupt was pending before chip reset.
        PUBLIC  TulipIntPosted
TulipIntPosted          DW      0

legacy                  DB 0  ; Default: Legacy mode not active

Full_Duplex_msg         DB      'Debug: Full Duplex Mode'
Full_Duplex_msg_len     EQU     $ - Full_Duplex_msg

Half_Duplex_msg         DB      'Debug: Half Duplex Mode'
Half_Duplex_msg_len     EQU     $ - Half_Duplex_msg

PHY10_msg         DB      'Debug: Speed = 10 Mb'
PHY10_msg_len     EQU     $ - PHY10_msg

PHY100_msg         DB      'Debug: Speed = 100 Mb'
PHY100_msg_len     EQU     $ - PHY100_msg

SetupFrame_fail_msg     DB      'Fatal Error: Send setup frame is not completed.'
                        DB      CR, LF
SetupFrame_fail_msg_len EQU     $ - SetupFrame_fail_msg

SROM_Corrupted_msg      db      'Fatal Error: SROM corrupted.', 0Dh, 0Ah, '$'

SROM_Version_not_msg    DB      'Fatal Error: SROM Version is not Version 3.', 0Dh, 0Ah, '$'

SROM_Count_not_One_msg  DB      'Fatal Error: SROM support controller > 1.', 0Dh, 0Ah, '$'

No_Match_ability_msg    DB      'Fatal Error: Auto-Negotiation fail (No Match Ability)', 0Dh, 0Ah, '$'


;;++, 980310, Hu-Tiong
PerformAutoSenseMsg     db      0Dh, 0Ah, "Performing Power-Up Autosense...", 0Dh, 0Ah, '$'
CheckAutoCompleteCnt    dw      0
AutoCompleteTimeOut     dw      0
;;++

;;++, 980930, Hu-Tiong
        PUBLIC  SetCR6
SetCR6  PROC NEAR
;;--, 2000.1.31, hu-tiong
if 0
        cmp     ChipType, DM9102_CHIP
        je      pi_DM9100_CR6
        cmp     ChipType, DM9100_CHIP
        je      pi_DM9100_CR6
;;--- Set CR6 for DM9009
        call    DM9009_Media            ;;
        jmp     pi_done

pi_DM9100_CR6:
endif
;;--
;;++, 2000.1.31, hu-tiong
;if 0
        cmp     SROMPortFlag, 4
        jne     fnet_not_1m_home_pna

        and     PortConfigCR6, NOT CR6_M_FDM
        or      PortConfigCR6,  CR6_M_MSPS      ; bit18 = 1, HOME PNA
        jmp     pi_done

fnet_not_1m_home_pna:
;;++, 2000.6.27, htho, switching adapter support
        cmp     ChipType,DM9009_CHIP ;; add by simon 2001.11.8 for use 9161
        je     @F                   ;; add by simon 2001.11.8
        cmp     switch_adapter, 0
        je      use_internal_phy

        or      PortConfigCR6,  CR6_M_MSPS      ; use external phy path
        jmp     chk_sromportflag

use_internal_phy:
;;++
        and     PortConfigCR6, NOT CR6_M_MSPS
@@:
;endif
;;++
;;++, 2000.6.27, htho, switching adapter support
chk_sromportflag:
;;++
        cmp     SROMPortFlag, 1
        je      fnet_set_full_duplex

fnet_set_half_duplex:
        and     PortConfigCR6, NOT CR6_M_FDM
        jmp     pi_done

fnet_set_full_duplex:
        or      PortConfigCR6, CR6_M_FDM
        jmp     pi_done
;-------------------------------------------------------
pi_done:
;;--, 980611, Hu-Tiong, for DM9102 cut4
;;++, 980303, Hu-Tiong
;
; FIFO's dual port RAM within the DM9102's MAC has problems to handle the
; situations while the FIFO is written by the network and read by the host
; simultaneously or vice versa. Set Bit 8 in CR6 ON will inhibit simultaneous
; read/write of the FIFO.
;
ifdef SINGLE_PORT
        or      PortConfigCR6, CR6_M_ISRW ; inhibit simultaneous read/write
endif

        ret
SetCR6  ENDP


        PUBLIC  AutoDetectMediaType
AutoDetectMediaType     PROC NEAR
;;++, 2000.6.27, htho, switching adapter support
        cmp     switch_adapter, 0
        jne     set_CR6
;;++

;;;;--, 2000.4.6, htho
if 0
        cmp     CheckAutoCompleteCnt, 0
        jne     CheckAutoComplete
        ; stop MAC
;;;;    mov     dx, p_CR6
;;;;    in      eax, dx
;;;;    mov     CR6_image, eax
;;;;    and     eax, NOT CR6_M_TXSC
;
; write local capability to ANAR

;
        mov     dx, anar
        mov     bh, PHY_Number
        mov     bl, PHY_ANAR
        call    Write_Register_PHY
;
; restart auto-negotiation
;
;;;;    mov     dx, BMCR_M_SL+BMCR_M_ANE+BMCR_M_RAN+BMCR_M_DM
        mov     dx, BMCR_M_ANE+BMCR_M_RAN
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY
endif
;;;;--
;
; Check Auto-Negotiation & Link
;
Check_Link_Partner:
;
; reset status register
;
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_BMSR            ;; BMSR(Basic Mode Status Register) index
        call    Read_Register_PHY       ;; return AX = register value
;
; check if auto-negotiation complete
;
CheckAutoComplete:
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_BMSR            ;; BMSR(Basic Mode Status Register) index
        call    Read_Register_PHY       ;; return AX = register value
;;;;-+, 2000.4.6, htho
;;;;    test    ax, BMSR_M_AN           ;; Auto-Negotiation Complete ?
;;;;    jnz     Link_avail
        and     ax, (BMSR_M_AN OR BMSR_M_LS)
        cmp     ax, (BMSR_M_AN OR BMSR_M_LS)
        je      Link_Established
;;;;-+

        inc     CheckAutoCompleteCnt
        mov     ax, CheckAutoCompleteCnt
        cmp     ax, AutoCompleteTimeOut
;;;;-+, 2000.4.6, htho, recover the original one
;-+, 2000.1.31, hu-tiong
        jae     Link_Fail
;;;;    jae     Link_avail
;-+
;;;;-+
        stc
        ret
;;;;--, 2000.4.6, htho
if 0
;
; check link status
;
Link_avail:
;;-+, 2000.1.31, hu-tiong
;       mov     bh, PHY_Number          ;; assume PHY address = <00001>
;       mov     bl, PHY_BMSR            ;; BMSR(Basic Mode Status Register) index
;       call    Read_Register_PHY       ;; return AX = register value
;       test    ax, BMSR_M_LS           ;; Link established ?
;       jnz     Link_Established        ; jump if link established
        mov     dx, p_CR12
        in      eax, dx
        test    eax, 0003h
        jnz     Link_Established
;;-+
endif
;;;;--

Link_Fail:
        mov     PreviousLinkStatus, LINK_FAIL
        mov     CheckAutoCompleteCnt, 0

        test    flagword, A_OPTION      ; Auto Negotiate mode?
        jnz     auto_fail_default       ; jmp if yes
        jmp     set_CR6

auto_fail_default:
;++, 2000.1.31, hu-tiong
ifdef   HOMEPNA
;;;;++, 2000.3.27, htho
        cmp     PHYTYPE, PNAPHY
        jne     @F
;;;;++
        mov     InitPIDataRate, 1
        mov     SROMPortFlag, 4
;;;;-+, 2000.3.27
        jmp     set_CR6
@@:
;;;;else
endif
;;;;-+
        mov     InitPIDataRate, 10      ; if link failed, assume it's 10base
        mov     SROMPortFlag, 0
;;;;--, 2000.3.27, htho
;;;;endif
;;;;--
;;-+
        jmp     set_CR6

Link_Established:
        mov     PreviousLinkStatus, LINK_PASS
        mov     CheckAutoCompleteCnt, 0
;
; check if link partner is capable of NWAY
;
        mov     bh, PHY_Number          ;; assume PHY address
        mov     bl, PHY_ANER            ;; ANER(Auto-Negotiation Expansion Register)
        call    Read_Register_PHY
        test    ax, ANER_M_LAA         ;; Link Partner Auto-negotiation able
        jz      partner_NWAY_incapable

partner_NWAY_capable:
        mov     bh, PHY_Number
        mov     bl, PHY_ANLPAR          ;; Auto-Negotiation Partner Ability Register
        call    Read_Register_PHY
        push    ax

        ;; Local ability
        mov     bh, PHY_Number
        mov     bl, PHY_ANAR            ;; Auto-Negotiation Advertisement Register
        call    Read_Register_PHY
;; -- Decide negotiation result
        pop     bx                      ;; Partner ability

ability_100basetx_FD:
        test    ax, 100h                ;; 100BASE-TX Full-Duplex ability
        jz      ability_100baset4
        test    bx, 100h
        jz      ability_100baset4
        mov     InitPIDataRate, 100
        mov     SROMPortFlag, 1

        jmp     set_CR6

ability_100baset4:
        test    ax,200h                 ;; 100BASE-T4 ability
        jz      ability_100basetx
        test    bx, 200h
        jz      ability_100basetx
        mov     InitPIDataRate, 100
        mov     SROMPortFlag, 3
        jmp     set_CR6

ability_100basetx:
        test    ax, 80h                 ;; 100BASE-TX Half-Duplex ability
        jz      ability_10basefd
        test    bx, 80h
        jz      ability_10basefd
        mov     InitPIDataRate, 100
        mov     SROMPortFlag, 0

        jmp     set_CR6

ability_10basefd:
        test    ax, 40h                 ;; 10BASE-T Full-Duplex ability
        jz      ability_10base
        test    bx, 40h
        jz      ability_10base
        mov     InitPIDataRate, 10
        mov     SROMPortFlag, 1
        jmp     set_CR6

ability_10base:
;;++, 2000.6.12, htho, renew nway alogrithm
        test    ax, 20h                 ;; 10BASE-T Half-Duplex ability
        jz      capability_mismatch
        test    bx, 20h
        jz      capability_mismatch
;;++
        mov     InitPIDataRate, 10
        mov     SROMPortFlag, 0
        jmp     set_CR6

;;++, 2000.6.12, htho, renew nway alogrithm
capability_mismatch:
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_BMCR
        call    Read_Register_PHY
        test    ax, 2000h
        jz      PHY_10MB

;;--- 100MB
PHY_100MB:
        mov     InitPIDataRate, 100
;       jmp     force_media_type
        jmp     set_CR6

PHY_10MB:
        mov     InitPIDataRate, 10
        jmp     set_CR6
;;++

partner_NWAY_incapable:
;;++, 980303, Hu-Tiong
;; If auto-negotiation failed, line speed of remote partner can still
;; be distinquished but duplex mode has no way to find out.
;; We just assume it to be in half duplex mode.
        test    flagword, A_OPTION      ; Auto Negotiate speed and duplex mode?
        jz      force_media_type        ; jmp if yes
        mov     SROMPortFlag, 0
;;++
find_partner_speed:
COMMENT %
        cmp     PHYTYPE, DSIPHY
        je      dsi_phy
; if it's a NS's DP83840 compatible PHY
; Check PHY Address Register (PAR -- 19h) bit 6
; bit6 = 1 - 10Mb
;        0 - 100Mb
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_PAR             ;; PAR (PHY Address Register)
        call    Read_Register_PHY

        test    ax, 40h
        jnz     PHY_10MB
        jmp     PHY_100MB
%
dsi_phy:
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_BMCR
        call    Read_Register_PHY
        test    ax, 2000h
        jz      parallel_detect_PHY_10MB

;;--- 100MB
parallel_detect_PHY_100MB:
        mov     InitPIDataRate, 100
;       jmp     force_media_type
        jmp     set_CR6

parallel_detect_PHY_10MB:
        mov     InitPIDataRate, 10
        jmp     set_CR6

force_media_type:
;
; disable auto-negotiation, and set BMCR to the foced media type
;
        xor     dx, dx

        cmp     InitPIDataRate, 100
        jne     force_duplex
        or      dx, BMCR_M_SL
force_duplex:
        cmp     SROMPortFlag, 1
        jne     set_BMCR
        or      dx, BMCR_M_DM
set_BMCR:
;;++, 2001.6.12, htho, we need to write at last 2 times to dm9102a E3 to
;; force it to correct mode after power on/off it
        push    dx
;;++
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY

;;++, 2001.6.12, htho, we need to write at last 2 times to dm9102a E3 to
;; force it to correct mode after power on/off it
        pop     dx

        cmp     dm9102a_e3, 1
        jne     @F

        push    dx

        mov     cx, 0FFFh
abc_loop:
        push    cx
        call    SROMDelay
        pop     cx
        loop    abc_loop

        pop     dx

        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY
@@:
;;++
;;---------------------------------------------------------------------------
; Set correct value into CR6
;-----------------------------
set_CR6:
;;;;++, 2001.8.13, htho
; Reset PNA PHY to avoid accumulation of Noise Floor in Reg. 25 of DM9801 E3
; while user warm restart the PC or unload/load driver again.
; This reset must take the PNA PHY a few seconds to reach a stable state, so
; we must pospond the pna phy setting some time later (after startup auto).
ifdef HOMEPNA
        cmp     PHYTYPE, PNAPHY
        jne     @F
        mov     dx, p_CR6
        in      eax, dx
        push    eax
        or      eax, CR6_M_MSPS
        out     dx, eax
        cmp     PNATYPE, LONGRUN
        je      slr
        call    Setup_HOMERUN_PHY
        jmp     espna
slr:
        call    Setup_LONGRUN_PHY
espna:
        pop     eax
        mov     dx, p_CR6
        out     dx, eax
@@:
endif
;;;;++

        call    SetCR6

        clc
        ret
AutoDetectMediaType     ENDP
;;++

        PUBLIC  DynamicAutoDetect
DynamicAutoDetect  PROC NEAR
;;++, 2000.6.27, htho, switching adapter support
        cmp     switch_adapter, 0
        jne     QuitDynamicAutoDetect
;;++
;;;;++, 2000.4.6, htho
        mov     ax, flagword
        and     ax, (A_OPTION OR XF_OPTION OR XH_OPTION OR F_OPTION OR H_OPTION OR T_OPTION)
        cmp     ax, T_OPTION
        je      QuitDynamicAutoDetect
;;;;++

;add by simon 2001.8.30 
;check the phy reg24 ,if the noise_level exeeced peak_level
;then reset the noise_floor 
;***********************************
ifdef HOMEPNA
      mov       bh, PHY_Number
      mov       bl, 24
      call      Read_Register_PHY
      mov bx,p_PHY24
      mov cl,8
      shr bx,cl
      cmp al,bl
      jb check_exit
      mov       ax,p_PHY24
      mov       dl, al
      mov       dh, 0F0h
      mov       bh, PHY_Number
      mov       bl, 25
      call      Write_Register_PHY



endif

check_exit:
;***********************************

;
; check link staus from CR12[0..1] (General Purpose Pin Register)
;
        mov     dx, p_CR12
        in      eax, dx
        test    eax, 0003h
        jnz     Link_Status_Pass
        cmp     PreviousLinkStatus, LINK_PASS
        jne     QuitDynamicAutoDetect
;
; Link status change from PASS to FAIL
;
        mov     PreviousLinkStatus, LINK_FAIL

ifdef HOMEPNA
        cmp     PHYTYPE, PNAPHY
        jne     @F
        ;
        ; 100BASE-T link fail, use HOME PNA
        ;
        mov     SROMPortFlag, 4
        mov     InitPIDataRate, 1

        mov     eax, PortConfigCR6
        and     eax, NOT CR6_M_FDM      ; CR6 bit9  = 0, half duplex
        or      eax, CR6_M_MSPS         ; CR6 bit18 = 1, HOME PNA
        mov     PortConfigCR6, eax
        call    PortCR6Write

;;;;-+, 2000.6.27, rewrite PNA PHY setting
        ;
        ; PNA PHY may need to resend remote command this time
        ;
        call    PNA_Set_CR16
;;;;-+
@@:
endif

        jmp     QuitDynamicAutoDetect

Link_Status_Pass:
        cmp     PreviousLinkStatus, LINK_FAIL
        jne     QuitDynamicAutoDetect
;
; Link status change from FAIL to PASS
;
        mov     PreviousLinkStatus, LINK_PASS
        ;
        ; use 100BASE-T, CR6 bit18=0
        ;
ifdef HOMEPNA
;;-+, 2000.2.16, hu-tiong
;       mov     dx, p_CR6
;       in      eax, dx
;
;       and     eax, NOT CR6_M_MSPS     ; CR6 bit18 = 0, 100Base-T
;
;       out     dx, eax
        mov     eax, PortConfigCR6
        and     eax, NOT CR6_M_MSPS
        mov     PortConfigCR6, eax
        call    PortCR6Write
;;-+
endif
        ;
        ; reset status register
        ;
        mov     bh, PHY_Number          ; assume PHY address = <00001>
        mov     bl, PHY_BMSR            ; BMSR(Basic Mode Status Register) index
        call    Read_Register_PHY       ; return AX = register value
        ;
        ; check auto-negotiation complete & link status
        ;
        mov     cx, 05ffh
DAN_loop:
        push    cx
        mov     bh, PHY_Number          ; assume PHY address = <00001>
        mov     bl, PHY_BMSR            ; BMSR(Basic Mode Status Register) index
        call    Read_Register_PHY       ; return AX = register value
        pop     cx

        and     ax, BMSR_M_AN OR BMSR_M_LS
        cmp     ax, BMSR_M_AN OR BMSR_M_LS
        je      DAN_AutoComplete

        call    SROMDelay
        loop    DAN_loop

        mov     SROMPortFlag, 0
        mov     InitPIDataRate, 10

        jmp     DAN_set_cr6

DAN_AutoComplete:
        mov     bh, PHY_Number          ; assume PHY address = <00001>
        mov     bl, PHY_DSCSR           ; DSCSR(DAVICOM Specified Configuration and Status Register)
        call    Read_Register_PHY       ; return AX = register value

        and     ax, 0F000h

        cmp     ax, 1000h
        jne     anc_not_10m_half

        mov     SROMPortFlag, 0
        mov     InitPIDataRate, 10
        jmp     DAN_set_cr6

anc_not_10m_half:
        cmp     ax, 2000h
        jne     anc_not_10m_full

        mov     SROMPortFlag, 1
        mov     InitPIDataRate, 10
        jmp     DAN_set_cr6

anc_not_10m_full:
        cmp     ax, 4000h
        jne     anc_not_100m_half

        mov     SROMPortFlag, 0
        mov     InitPIDataRate, 100
        jmp     DAN_set_cr6

anc_not_100m_half:
        cmp     ax, 8000h
        jne     anc_not_100m_full

        mov     SROMPortFlag, 0
        mov     InitPIDataRate, 100
        jmp     DAN_set_cr6

anc_not_100m_full:
        mov     SROMPortFlag, 0
        mov     InitPIDataRate, 10

DAN_set_cr6:

;;-+, 2000.2.16, hu-tiong
;       mov     dx, p_CR6
;       in      eax, dx
        mov     eax, PortConfigCR6
;;-+

        cmp     SROMPortFlag, 1
        je      DAN_set_full_duplex

DAN_set_half_duplex:
        and     eax, NOT CR6_M_FDM
        jmp     DAN_done

DAN_set_full_duplex:
        or      eax, CR6_M_FDM
        jmp     DAN_done
;-------------------------------------------------------
DAN_done:
;;-+, 2000.2.16, hu-tiong
;       mov     dx, p_CR6
;       out     dx, eax
        mov     PortConfigCR6, eax
        call    PortCR6Write
;;-+

QuitDynamicAutoDetect:
        ret
DynamicAutoDetect  ENDP
;--------------------------------------------------------------------+
; Name : PortInit
;
; Description: Initializes the hardware.
;               . Get Ethernet address from SROM.
;               . Setup CR6 & CR12 initial value.
;               . Decide media type according to options.
;
; Enter :
;
; Return : Carry flag set if error.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
          ALIGN  4
          PUBLIC PortInit
PortInit  PROC  NEAR
        push es
        push di
        push si
        push eax
        push ecx
        push edx

        mov ax, ds
        mov es, ax
;
; -- Assert software reset
;
        mov  eax, CR0_M_SR
        mov  dx, p_CR0
        out  dx, eax

;; --- Process speed & xmt mode options
;;        test    flagword, S_OPTION
;;        jnz      fd_select                      ;; Jump if setect 10Mb
;;        mov     InitPIDataRate, 100

;;fd_select:
;;        test    flagword, F_OPTION
;;        jz      fnet_pci_enet_rom_read          ;; Jump if no select (Half-duplex)
;;        mov     SROMPortFlag, 1                 ;; Full Deplex flag

fnet_pci_enet_rom_read:                    ; DM9100 READ
        mov     cx, SROM_93LC46B_LEN       ; CX - Num of words to read ;; (64 words)
        mov     si, RcvCurrentDescriptor   ; SI - Address into where to read
        mov     si, [si].RCV_DESCRIPTOR.p_RcvBuffer
        mov     SROMImage, si
        call    ReadSROM
        jnc     fnet_verify_version             ;; Jump if not legacy

;;--, 2000.1.31, hu-tiong
if 0
        mov     legacy, 1                      ; Assume "LEGACY" SROM format
        mov     cx, 4
        mov     di, OFFSET rom_address
        mov     si, SROMImage   ;; Pointer to the contents of SROM
legacy_ieee_read:                          ; Read "LEGACY" IEEE address
        mov     ax, WORD PTR [si]
        add     si, 2
        stosw                   ;; Store to ES:DI -> rom_address
        loop    legacy_ieee_read
        jmp     pi_init_current_addr
endif
;;--
        mov     dx, OFFSET SROM_Corrupted_msg
        mov     ah, 9
        int     21h
        jmp     pi_ret

; Verify version number of SROM
;-------------------------------
fnet_verify_version:
;;--, 2000.1.31, hu-tiong
if 0
        mov     al, [si].NS_SROM_version
        cmp     al, UM9100_SROM_V0_3    ;; (03h)
        je      srom_count
;; -- SROM Version is not correct.
        stc
        mov     dx, OFFSET SROM_Version_not_msg
        mov     ah, 9
        int     21h
        jmp     pi_ret

; Read how many adapters are using this SROM
;----------------------------------------------
srom_count:
        mov     cl, [si].NS_Controller_cnt
        cmp     cl, 1
        je      srom_ieee          ;Only one adapter using this SROM
        stc                             ;; Not successful if controller > 1
        mov     dx, OFFSET SROM_Count_not_One_msg
        mov     ah, 9
        int     21h
        jmp     pi_ret
endif
;;--

srom_ieee:
; Set IEEE adress read from SROM
;---------------------------------
        lea     di, [si].NS_Ether_Addr
        mov     al, [si].NS_Dev_Number
        mov     AdapterNum, al
;;        add     BYTE PTR [di+5], al
;;        adc     BYTE PTR [di+4], 0
;;        adc     BYTE PTR [di+3], 0
;;        adc     BYTE PTR [di+2], 0
;;        adc     BYTE PTR [di+1], 0
;;        adc     BYTE PTR [di], 0

; Extract IEEE address
        push    si
        mov     si, di
        mov     di, OFFSET rom_address
        mov     ecx, 6

ieee_byte_loop:                 ; Loop over six bytes of IEEE address
        mov     al, BYTE PTR [si]
        stosb
        inc     si
        loop    ieee_byte_loop

;    Initialize current station address
;------------------------------------------------------------------
pi_init_current_addr:
        mov     di, OFFSET my_address
        mov     si, OFFSET rom_address

pi_copy_IEEE_address:
        movsw
        movsw
        movsw

        pop     si                      ;; Pop SROM pointer
;Additional SROM processing:
;---------------------------------------------------------------------
; omitted
;;++, 2000.6.27, htho, switching adapter support
        ;
        ; DS:SI --> local SROM data buffer
        ;
        call    check_switching_adapter
;;++
;;;;++, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
        call    check_dm9009

;;;;++
;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
        call    config_cr15
;;;;++
;;;;++, 2000.10.4, simulate line plug out/in by power off/on phy for DM9102A E3
        call    check_dm9102a_e3
;;;;++

;;---------------------------------------------------------------------------
;; --- Run auto-negotiation
;;;--- Read PHY OUI
;;++, 2000.3.27, htho
ifdef HOMEPNA
        mov     dx, p_CR6
        in      eax, dx

        push    eax

        or      eax, CR6_M_MSPS
        out     dx, eax

        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_PHYIDR2         ;; PHYIDR1(PHY IDENTIFIER REGISTER#2) index
        call    Read_Register_PHY       ;; return AX = register value

        mov     PHYTYPE, DSIPHY

;;;;-+, 2000.9.19, htho, support DM9801 E4
;;;;    cmp     ax, 0B900h              ; DM9801 PHY ID1=0181h, PHY ID2=B900h
        mov     bl, al
        and     bl, 0Fh
        mov     pnaphy_rev, bl
        and     ax, 0FFF0h
        cmp     ax, 0B900h
;;;;-+
        jne     restore_cr6

;;;;++, 2001.8.13, htho
; Reset PNA PHY to avoid accumulation of Noise Floor in Reg. 25 of DM9801 E3
; while user warm restart the PC or unload/load driver again.
; This reset must take the PNA PHY a few seconds to reach a stable state, so
; we must pospond the pna phy setting some time later (after startup auto).
        mov     dx, 8000h
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY
;;;;++

        mov     PHYTYPE, PNAPHY

;;;;-+, 2000.6.27, rewrite PNA PHY setting
;;;;++, 2000.5.2, htho, check if PNAPHY is HOMERUN or LONGRUN
        mov     bh, PHY_Number
        mov     bl, 31                  ; Transmit Pulse Width, Cycles
        call    Read_Register_PHY
;;-+, 2001.3.30, htho, support HPNA speed setting
;; Reg 31 will not always be 110Fh after different speed setting for DM9802
;;      cmp     ax, 110Fh
;;      jne     HomeRunFound
        cmp     ax, 4404h
        je      HomeRunFound
;;-+
;;;;;   mov     bh, PHY_Number
;;;;;   mov     bl, 29                  ; Transmit Pulse Width, Cycles
;;;;;   call    Read_Register_PHY
;;;;;   cmp     ax, 5450h
;;;;;   jne     @F
;
; LONG-RUN phy is found on board
;
        mov     PNATYPE, LONGRUN

;;;;--, 2001.8.13, htho
; Reset PNA PHY to avoid accumulation of Noise Floor in Reg. 25 of DM9801 E3
; while user warm restart the PC or unload/load driver again.
; This reset must take the PNA PHY a few seconds to reach a stable state, so
; we must pospond the pna phy setting some time later (after startup auto).
;;;;    call    Setup_LONGRUN_PHY
;;;;__

        jmp     restore_cr6

;
; HOME-RUN phy is found on board
;
HomeRunFound:
        mov     PNATYPE, HOMERUN        ; default to HOMERUN

;;;;--, 2001.8.13, htho
; Reset PNA PHY to avoid accumulation of Noise Floor in Reg. 25 of DM9801 E3
; while user warm restart the PC or unload/load driver again.
; This reset must take the PNA PHY a few seconds to reach a stable state, so
; we must pospond the pna phy setting some time later (after startup auto).
;;;;    call    Setup_HOMERUN_PHY
;;;;--

;;;;++
;;;;-+

restore_cr6:
        pop     eax
        mov     dx, p_CR6
        out     dx, eax
else
;;++, 2000.3.27, htho
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_PHYIDR1         ;; PHYIDR1(PHY IDENTIFIER REGISTER#1) index
        call    Read_Register_PHY       ;; return AX = register value
        cmp     ax, NS_OUI_MSB
        jne     not_ns_oui
        mov     bh, PHY_Number          ;; assume PHY address = <00001>
        mov     bl, PHY_PHYIDR2         ;; PHYIDR1(PHY IDENTIFIER REGISTER#2) index
        call    Read_Register_PHY       ;; return AX = register value
        and     ax, 0fc00h
        cmp     ax, NS_OUI_LSB
        jne     not_ns_oui
        mov     PHYTYPE, NSPHY
        jmp     Operation
not_ns_oui:
;;++, 2000.3.27, htho
endif
;;++

;; -- Process fource media options
Operation:

        test    flagword, A_OPTION      ; Auto Negotiate speed and duplex mode?
        jnz     Auto_Negotiate          ; jmp if yes

;;;;++, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
     ;;   mark by simon
     ;;   cmp     ChipType, DM9009_CHIP   ; no 100M PHY capability
     ;;   je      Not_100HD
;;;;++

        test    flagword, XF_OPTION     ; forced 100Mb Full-Duplex?
        jz      Not_100FD               ; jmp if not

        mov     InitPIDataRate, 100     ; speed = 100Mb
        mov     SROMPortFlag, 1         ; Full Duplex TP
;;-+, 2001.6.21, htho, dual speed hub link fail while forced 10/100 full duplex
;;      mov     anar, ANAR_FCS+ANAR_TX_FDX+ANAR_CSMACD
        mov     anar, ANAR_FCS+ANAR_TX_FDX+ANAR_TX_HDX+ANAR_CSMACD
;;-+
        jmp     short Auto_Negotiate

Not_100FD:
        test    flagword, XH_OPTION     ; forced 100Mb Half-Duplex?
        jz      Not_100HD               ; jmp if not

        mov     InitPIDataRate, 100     ; speed = 100Mb
        mov     SROMPortFlag, 0         ; Half Duplex
        mov     anar, ANAR_FCS+ANAR_TX_HDX+ANAR_CSMACD
        jmp     short Auto_Negotiate

Not_100HD:
        test    flagword, F_OPTION      ; forced 10Mb Full-Duplex?
        jz      Not_10FD                ; jmp if not

        mov     InitPIDataRate, 10      ; speed = 10Mb
        mov     SROMPortFlag, 1         ; Full Duplex TP
;;-+, 2001.6.21, htho, dual speed hub link fail while forced 10/100 full duplex
;;      mov     anar, ANAR_FCS+ANAR_10_FDX+ANAR_CSMACD
        mov     anar, ANAR_FCS+ANAR_10_FDX+ANAR_10_HDX+ANAR_CSMACD
;;-+
        jmp     short Auto_Negotiate

Not_10FD:
        test    flagword, H_OPTION      ; forced 10Mb Half-Duplex?
        jz      Not_10HD                ; jmp if not, auto as default

        mov     InitPIDataRate, 10      ; speed = 10Mb
        mov     SROMPortFlag, 0         ; Half Duplex
        mov     anar, ANAR_FCS+ANAR_10_HDX+ANAR_CSMACD
        jmp     Auto_Negotiate

Not_10HD:
;;++2000.1.31, Hu-Tiong
ifdef  HOMEPNA
        test    flagword, T_OPTION      ; forced 1Mb HomePNA
        jz      Not_1PNA

        mov     InitPIDataRate, 1
        mov     SROMPortFlag, 4
;;;;-+, 2000.4.6, htho
;;;;    jmp     Auto_Negotiate
        cmp     PHYTYPE, PNAPHY
        je      pi_set_CR6
;;;;-+
Not_1PNA:
endif
;;++
        or      flagword, A_OPTION      ; in case that media type not specified

Auto_Negotiate:
        mov     dx, offset PerformAutoSenseMsg
        mov     ah, 9
        int     21h
;
; Reset PHY before configuration to make sure that previous installation of
; the driver will not affect the correct setting now.
; auto-negotiation.
;
;;;;++, 2000.3.27
ifdef HOMEPNA
        cmp     PHYTYPE, PNAPHY
        jne     @F

        mov     dx, p_CR6
        in      eax, dx

        and     eax, NOT CR6_M_MSPS
        out     dx, eax
@@:
endif
;;;;++

; must reset phy here, otherwise auto won't stop
        mov     dx, 8000h
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY

;;;;++, 2000.4.6, htho
;
; write local capability to ANAR
;
        mov     dx, anar
        mov     bh, PHY_Number
        mov     bl, PHY_ANAR
        call    Write_Register_PHY

        call    SROMDelay

;;;;++, 2000.10.4, simulate line plug out/in by power off/on phy for DM9102A E3
        cmp     dm9102a_e3, 1
        je      @F
;;;;++
;
; restart auto-negotiation
;
        mov     dx, BMCR_M_ANE+BMCR_M_RAN
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY

;;;;++, 2000.10.4, simulate line plug out/in by power off/on phy for DM9102A E3
        jmp     do_anc
@@:
        mov     dx, 1800h               ; power down phy
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY

        mov     cx, 5FFFh
pd_loop:
        push    cx
        call    SROMDelay               ;
        call    SROMDelay               ;
        call    SROMDelay               ;
        call    SROMDelay               ; must wait for this long time
        call    SROMDelay               ;
        call    SROMDelay               ;
        pop     cx
        loop    pd_loop

        mov     dx, 1000h               ; power on phy again
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY
do_anc:
;;;;++
;;;;++

        mov     AutoCompleteTimeOut, 0fffh
ANC_loop:
        call    SROMDelay
        call    AutoDetectMediaType
        jc      ANC_loop
        jmp     pi_port_reset
;
; notified by non MII PHY
;
pi_set_CR6:
        call    SetCR6
;
;   Reset everything, to start clean
;

pi_port_reset:
        call    PortUpdateReceiveFilter
        jnc     Update_ok
        jmp     pi_ret                          ;; Failure

Update_ok:
        clc

pi_ret:
        pop     edx
        pop     ecx
        pop     eax
        pop     si
        pop     di
        pop     es
        ret
PortInit  ENDP

;--------------------------------------------------------------------+
; Name : PortReadTickCounter
;
; Description:
;       Reads the Timer tick count register which decrements by 2 from 65536
;       to 0 every 1/36.414 of a second.  Each 2 decrements of the count
;       represents 838 nsec's.
;
; Enter :
;
; Return : AX = current count.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
        PUBLIC PortReadTickCounter
PortReadTickCounter     proc    near

        mov     al, 06h
        out     43h, al                 ;Command 8254 to latch T0's count

        ;Now read the count.

        in      al, 40h                 ;Read LSB first
        mov     ah, al
        in      al, 40h                 ;Read MSB
        xchg    al, ah                  ;Get in proper order
        ret

PortReadTickCounter     endp

EXTRN   rcv_mode_num : WORD
        PAGE
;--------------------------------------------------------------------+
; Name : PortUpdateReceiveFilter
;
; Description: This function sends a setup frame to the DM9100 with
;              the current contents of the MulticastTable,
;              and the current station address.
;
;              The DM9100 gets reset as a result of calling this routine.
;              This routine assumes that the transmit and receive objects
;              are active when the routine is called. Upon exit,
;              the transmit and receive objects are left in an active,
;              but reinitialized state.
; Enter :
;
; Return : Carry set if an error occurred.
;
; Destroied registers :
;
;---------------------------------------------------------------------+
                         ALIGN  4
                         PUBLIC PortUpdateReceiveFilter
PortUpdateReceiveFilter  PROC  NEAR
        push es
        push di
        push si
        push eax
        push bx
        push cx

        cli
        cld

        call PortReset                  ; Reset Adapter
        call XmtEnable                  ; Reenable transmitter

        mov  ax, ds                     ; ES = DS
        mov  es, ax
        call XmtGetSetupBuffer          ; Returns NEAR pointer to setup buffer
                                        ; in AX.
        mov  di, ax                     ; ES:DI points to setup buffer
        mov  bx, ax                     ; Save NEAR pointer in BX
        mov  cx, HW_K_SETUP_FRAME_SIZE  ;; (192)
        shr  cx, 2
        mov  eax, 0FFFFFFFFh
        rep  stosd                      ; Initialize setup buffer with FF's
;
; At this point, the setup buffer has been initialized with all FF's. This
; has the effect of filling the unused entries in the 16 address receive
; filter with the broadcast address. The DM9100 requires that a setup
; frame specify a valid address for all 16 entries. By setting the unused
; entries to broadcast, we don't have to worry about filling the unused
; entries with a copy of one of the valid entries, as recommended in the
; DM9100 spec.
;
; Now, place the current station address in the setup frame.
;
                                        ; DS:SI points to the current address
        mov     si, OFFSET my_address

        mov  di, bx                     ; ES:DI points to start of setup buffer
        xor  eax, eax
        lodsw                           ; Load word into AX
        stosd                           ; Store dword EAX in setup buffer
        lodsw                           ; Load word into AX
        stosd                           ; Store dword EAX in setup buffer
        lodsw                           ; Load word into AX
        stosd                           ; Store dword EAX in setup buffer

; Now, determine the number of entries in the MulticastTable, and add
; those entries to the setup frame.

        mov  cx, MulticastTable.table_current
        mov  si, OFFSET MulticastTable.table_multiaddr

pesf_loop:
        cmp  cx, 0
        je   pesf_done

        lodsw                           ; Load word into AX
        stosd                           ; Store dword EAX in setup buffer
        lodsw                           ; Load word into AX
        stosd                           ; Store dword EAX in setup buffer
        lodsw                           ; Load word into AX
        stosd                           ; Store dword EAX in setup buffer

; 16 bytes storage for each address
        add  si, 10                     ; DS:SI points to next entry in
                                        ; MulticastTable
        dec  cx
        jmp  pesf_loop

pesf_done:
        call XmtSendSetupFrame          ; Send the buffer
        jnc     sendsetup_ok
        mov  si, OFFSET SetupFrame_fail_msg
        mov  cx, SetupFrame_fail_msg_len
        call PortPrintMessage

        jmp   pesf_exit                  ; If error, preserve the carry set

sendsetup_ok:
        cmp     rcv_mode_num, 1
        je      pesf_exit
        call    RcvEnable
        clc                             ; No error...clear carry

pesf_exit:

        pop cx
        pop bx
        pop eax
        pop si
        pop di
        pop es
        ret

PortUpdateReceiveFilter  ENDP

        PAGE
;--------------------------------------------------------------------+
; Name : PortReset
;
; Description: Set the receive mode on the interface associated with handle.
;               Can't use this function in the mutli-handle.
;
; Enter :
;
; Return :
;
; Destroied registers :
;
;---------------------------------------------------------------------+
           ALIGN  4
           PUBLIC PortReset
PortReset  PROC  NEAR
        push eax
        push dx
        push cx
        push bx

        DISABLE_ADAPTER_INTERRUPT  ; Disable adapter interrupts

        mov  eax, CR0_M_SR       ; Assert software reset
        mov  dx, p_CR0
        out  dx, eax
                                   ; Delay 50 PCI cycles here
;
;       Fix this hack by calling PortResetDelay...to be done
;

;*************************************************************************
;*************************************************************************
;*** WARNING: This is a real HACK. I've put it here until I can figure ***
;*** out a more deterministic way of delaying 50 PCI cycles on an      ***
;*** arbitrary platform.                                               ***
;*************************************************************************
;*************************************************************************
        mov  cx, 0FFFFh
pr_loop:
;;        pusha
        mov     dx, p_CR0
        in      eax, dx
        test    eax, 1
        jz      swreset_ok
;;        popa
        loop pr_loop

;--- Raise the interrupt posted flag. Relevant for prevention of crash. ---
swreset_ok:
        mov     TulipIntPosted, 1

pr_skip_configs:
        mov  eax, PortConfigCR0   ; Restore CR0
        mov  dx, p_CR0
        out  dx, eax

        mov     dx, p_CR5              ;; Reset CR5
        in      eax, dx
        out     dx, eax

;;++, 2000.2.21, hu-tiong
        mov     PortConfigCR6, CR6_DEFAULT
        call    SetCR6
;;++
        mov  eax, PortConfigCR6   ; Restore CR6
        mov  dx, p_CR6
        out  dx, eax

;;;;--, 2000.6.27, rewrite PNA PHY setting
;;;;--

;;++, 980623, Hu-Tiong, DM9102 E4 happens to tx extreme long packet sometimes
;;    Solutions:
;;      1. disable Jabber Clock -- make tx cut off after a range of 2048 bytes
;;         is transmitted.
;;      2. enable Host Unjab -- make tx channel is released immediately after
;;         jabber expiration.
        mov     dx, p_CR15
;;;;-+, 2000.8.24, htho, support VLAN & Tx/Rx flow control
;;;;    in      eax, dx
;;;;    and     eax, 0FFFFFFF8h
;;;;    or      eax, 000000006h
        mov     eax, PortConfigCR15
;;;;-+
        out     dx, eax
;;-+

;;;;--, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
;;;;    cmp     ChipType, DM9009_CHIP
;;;;    je      Write_DM9009_CR12
;;;;--

        mov  ax, UM9100_GprCtrl    ; DM9100 chip - init CR12
        and  eax, 0FFFFh
        mov  dx, p_CR12
        out  dx, eax

        mov  ax, UM9100_GprData10
        cmp  InitPIDataRate, 100
        je   pr_fnet_100
        cmp     SROMPortFlag, 1
        jne  pr_CR12_data
        mov  ax, UM9100_GprDataFD10
        jmp  pr_CR12_data

pr_fnet_100:
        mov  ax, UM9100_GprData100
        cmp     SROMPortFlag, 1
        jne  pr_CR12_data
        mov  ax, UM9100_GprDataFD100

pr_CR12_data:
        and  eax, 0FFFFh
        mov  dx, p_CR12
        out  dx, eax

        jmp  pr_xmt_rcv_reset         ; skip on SIA initialization
;;;;--, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
;;Write_DM9009_CR12:
;;        mov     eax, DM9009_CR12_image
;;        mov     dx, p_CR12
;;        out     dx, eax
;;;;--

pr_xmt_rcv_reset:
        call XmtReset

        call RcvReset

        pop  bx
        pop  cx
        pop  dx
        pop  eax
        ret

PortReset  ENDP

    PAGE
;--------------------------------------------------------------------+
; Name : PortResetDelay
;
; Description:
;       Spec. calls for 50 PCI cycles of delay between reset
;       and further accesses. Slowest PCI clock is 16Mhz. At 10Mhz PCI
;       clock (with safety margin) we have to wait 50cycles/10Mhz = 5000nsec.
;       PortReadTickCounter gives 419 nsec per count. We have to delay a delta
;       count of  5000ns/419ns = 11.93. We will round it up to 12.
;
;       Bottom line is that this routine returns after 5usec.
;
; Enter :
;
; Return :      AX = current count
;
; Destroied registers :
;
;---------------------------------------------------------------------+
PortResetDelay  proc    near

        push    bx
        call    PortReadTickCounter             ;Get initial value
        mov     bx, ax                  ;Save start value

Prd_loop:               ; Loop 12 times to get the proper delay
        call    PortReadTickCounter
        neg     ax
        add     ax, bx                  ;Get difference
        cmp     ax, 12
        jb      SHORT Prd_loop
        pop     bx
        ret
PortResetDelay  endp

;--------------------------------------------------------------------+
; Name : PortPrintMessage
;
; Description:
; This function prints a message pointed to by DS:SI, that is CX bytes long.
; This function uses the BIOS video service at INT 10 to provide an OS
; independent method for displaying messages to the console during driver
; init.
;
; Enter :  DS:SI - Far pointer to message to print.
;             CX - Message length in bytes.
;
; Return :
;
; Destroied registers :
;
;---------------------------------------------------------------------+
                  PUBLIC PortPrintMessage
PortPrintMessage  PROC NEAR
        push si
        push ax
        push bx
        push cx
        pushf           ;    save flags
        cmp     cx, 0
        je      pm_exit
        cld             ;    clear direction flag
        mov  bx,0Fh     ;    Set video attributes for INT 10 call
pm_loop:                ;    do {
        lodsb           ;      get char at DS:(SI++)
        mov  ah,0EH
        int  10H        ;      call BIOS INT 10 to print to console
        loop pm_loop    ;      CX--
                        ;    while (CX != 0)
pm_exit:
        popf            ;    restore flags
        pop cx
        pop bx
        pop ax
        pop si
        ret

PortPrintMessage  ENDP

        PAGE
;--------------------------------------------------------------------+
; Name : PortCR6Write
;
; Description:
; This function handles writes to CR6. The value in EAX is written to
; CR6.
;
; Enter :  EAX = Writed data
;
; Return :
;
; Destroied registers :
;
;---------------------------------------------------------------------+
               ALIGN  4
               PUBLIC PortCR6Write
PortCR6Write  PROC  NEAR
        push eax
        push ebx
        push ecx
        push dx
        pushf
        cli


pCR6_write_CR6:
        mov  dx, p_CR6
        out  dx, eax            ; Write CR6 with desired value

pCR6_exit:
        popf
        pop dx
        pop ecx
        pop ebx
        pop eax
        ret
PortCR6Write  ENDP

;;;;--, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
if 0
;****************
;* DM9009_Media
;****************
; 1. Set CR6 value.
; 2. Set CR12's physical nedia type selection bits.
; 3. Decide half or full duplex, BNC don't have full duplex.
;------------------------------------------------------------
        public  DM9009_Media
DM9009_Media    PROC    NEAR
        mov     PortConfigCR6, CR6_DM9009_INIT
        mov     dx, p_CR12
        in      eax, dx
        and     ax, 0fffch      ;;initial bit1:0
;;--- Set CR12 physical media type selection
        test    flagword, B_OPTION              ;; BNC ?
        jz      dm_not_bnc
        mov     SROMPortFlag, 4
        or      ax, 01h
        jmp     Media_value

dm_not_bnc:
;;;;--, 980303, Hu-Tiong
;;;;    test    flagword, AF_OPTION
;;;;    jz      dm_not_fd
;;;;--
        or      PortConfigCR6, 200h     ;;full duplex

dm_not_fd:
        or      ax, 3                   ;; AutoDetect
        call    DM9009_Link_Check       ;; set carry flag if link fail(BNC)
        jc      bnc_select
        mov     SROMPortFlag, 0
        jmp     Media_value
bnc_select:
        mov     SROMPortFlag, 4

Media_value:
        mov     DM9009_CR12_image, eax
        ret
DM9009_Media    ENDP


;****************
;* DM9009_Link_Check
;****************
; Only for DM9009 to check link status.
; Set carry flag if link fail, otherwise clear carray flag.
;-----------------------------------------------------------------
DM9009_Link_Check       PROC NEAR
        push    dx
        push    eax
        mov     dx, p_CR12
        call    PortResetDelay
        in      eax, dx
        test    eax, 4          ;; GDLINK bit
        jz      nolink
        clc
        jmp     linkexit
nolink:
        stc
linkexit:
        pop     eax
        pop     dx
        ret

DM9009_Link_Check       ENDP
endif
;;;;--

;;++, 2000.2.21
        PUBLIC Port_Hardware_Reset_PHY
Port_Hardware_Reset_PHY PROC
;
; Reset PHY through CR12 General Purpose pin
;
        mov     dx, p_CR12
        mov     eax, 00000180h
        out     dx, eax

        mov     eax, 00000080h
        out     dx, eax

        mov     eax, 0
        out     dx, eax

        ret
Port_Hardware_Reset_PHY ENDP
;;++, 2000.2.21

;;;;++, 2000.6.27, rewrite PNA PHY setting
        PUBLIC Reset_MAC_PHY
Reset_MAC_PHY PROC
        mov     dx, p_CR0               ; reset MAC
        mov     eax, 1
        out     dx, eax

        call    SROMDelay

ifdef HOMEPNA
        cmp     PHYTYPE, PNAPHY
        jne     @F

        mov     dx, p_CR6
        in      eax, dx
        or      eax, CR6_M_MSPS
        out     dx, eax

        mov     dx, BMCR_M_RST
        mov     bh, PHY_Number
        mov     bl, PHY_BMCR
        call    Write_Register_PHY

@@:
endif
        ret
Reset_MAC_PHY ENDP

ifdef HOMEPNA
        PUBLIC PNA_Set_CR16
PNA_Set_CR16 PROC
        call    Write_PNA_CR16

        pushf
        cli
        cmp     send_remote_cmd, 1
        jne     @F

        mov     resend_remote_cmd_cnt, 3
        mov     resend_remote_cmd_timer, 0
@@:
        popf

        ret
PNA_Set_CR16 ENDP

Write_PNA_CR16 PROC
        mov     dx, pna_cr16
        and     dx, NOT 0F00h

        cmp     send_remote_cmd, 0
        je      @F
        or      dx, pna_power_cmd
        or      dx, pna_speed_cmd
@@:

        mov     bh, PHY_Number
        mov     bl, 16
        call    Write_Register_PHY

        ret
Write_PNA_CR16 ENDP

Setup_HOMERUN_PHY PROC
        ;
        ; disable %25 increase of noise slice for HOMERUN
        ;
;;;;++, 2000.9.19, htho, support DM9801 E4
        cmp     pnaphy_rev, 0
        jne     @F
;;;;++
        or      pna_cr16, 1000h
;;;;++, 2000.9.19, htho, support DM9801 E4
        jmp     gosetcr16
@@:
        and     pna_cr16, NOT 1000h
gosetcr16:
;;;;++
        ;
        ; PNA PHY may need to resend remote command this time
        ;
        call    PNA_Set_CR16

;;-+, 2001.5.25, different 9801 R24/R25 operation between E3 and E4/5...
;       mov     bh, PHY_Number
;       mov     bl, 24
;       call    Read_Register_PHY
;
;       mov     dl, al
;       add     dl, 3
;       mov     dh, 0F0h
;       mov     bh, PHY_Number
;       mov     bl, 25
;       call    Write_Register_PHY
        cmp     pnaphy_rev, 0
        jne     @F              ; it's 9801 E4/E5...

        ; it's 9801 E3

        mov     bh, PHY_Number
        mov     bl, 24
        call    Read_Register_PHY
        mov     p_PHY24,ax
        mov     dl, al
;**********************************************************
;add by simon 2001.8.27
;strore phy reg24's value into p_PHY24
;
;**********************************************************

       ;; add     dl, 0Dh  mark by simon, just add 8
        add     dl, 8
        mov     dh, 0F0h
        mov     bh, PHY_Number
        mov     bl, 25
        call    Write_Register_PHY

        jmp     hr_set_speed
@@:
        ; it's 9801 E4/E5...

        mov     bh, PHY_Number
        mov     bl, 17
        call    Read_Register_PHY
        or      ax, 08h

        mov     dx, ax
        mov     bh, PHY_Number
        mov     bl, 17
        call    Write_Register_PHY

        mov     bh, PHY_Number
        mov     bl, 25
        call    Read_Register_PHY

        push    ax

        mov     bh, PHY_Number
        mov     bl, 24
        call    Read_Register_PHY

        pop     dx
        mov     dl, al
        mov     bh, PHY_Number
        mov     bl, 25
        call    Write_Register_PHY

hr_set_speed:
;;-+

;;++, 2001.3.30, htho, support HPNA speed setting
;;-+, 2001.6.12, htho, default lspeed=1000 instead of 700
        cmp     LSpeedNum, 1000
;;-+
        jne     Set_HOMERUN_LSpeed_500

        mov     pna_cr29, 4014h
        mov     pna_cr30, 1C2Ch
        mov     pna_cr31, 4404h
        jmp     Set_HOMERUN_LSpeed

Set_HOMERUN_LSpeed_500:
        cmp     LSpeedNum, 500
        jne     Set_HOMERUN_LSpeed_1400

        mov     pna_cr29, 4014h
;;-+, 2001.6.12, htho, error CR31 value while lseedp=500 for homerun
;;      mov     pna_cr30, 1C2Ch
        mov     pna_cr30, 1C3Fh
;;-+
        mov     pna_cr31, 4404h
        jmp     Set_HOMERUN_LSpeed

Set_HOMERUN_LSpeed_1400:
        cmp     LSpeedNum, 1400
        jne     Set_HOMERUN_LSpeed_1600

        mov     pna_cr29, 200Ch
        mov     pna_cr30, 141Ch
        mov     pna_cr31, 4404h
        jmp     Set_HOMERUN_LSpeed

Set_HOMERUN_LSpeed_1600:
        mov     pna_cr29, 200Ch
        mov     pna_cr30, 121Ch
        mov     pna_cr31, 4404h

Set_HOMERUN_LSpeed:
        mov     dx, pna_cr29
        mov     bh, PHY_Number
        mov     bl, 29
        call    Write_Register_PHY

        mov     dx, pna_cr30
        mov     bh, PHY_Number
        mov     bl, 30
        call    Write_Register_PHY

        mov     dx, pna_cr31
        mov     bh, PHY_Number
        mov     bl, 31
        call    Write_Register_PHY
;;++
        ret
Setup_HOMERUN_PHY ENDP

Setup_LONGRUN_PHY PROC
        ;
        ; enable %25 increase of noise slice for LONGRUN
        ;
        and     pna_cr16, NOT 1000h

        ;
        ; PNA PHY may need to resend remote command this time
        ;
        call    PNA_Set_CR16

        mov     bh, PHY_Number          ; set low byte of Reg. 25 to 02h
        mov     bl, 25
        call    Read_Register_PHY
        mov     dx, ax

        and     dx, 0FF00h
        or      dx, 02h
        mov     bh, PHY_Number
        mov     bl, 25
        call    Write_Register_PHY

;;++, 2001.3.30, htho, support HPNA speed setting
;;-+, 2001.6.12, htho, default lspeed=1000 instead of 700
        cmp     LSpeedNum, 1000
;;-+
        jne     Set_LONGRUN_LSpeed_500

        mov     pna_cr29, 5450h
        mov     pna_cr30, 1C2Ch
        mov     pna_cr31, 110Fh
        jmp     Set_LONGRUN_LSpeed

Set_LONGRUN_LSpeed_500:
        cmp     LSpeedNum, 500
        jne     Set_LONGRUN_LSpeed_1400

        mov     pna_cr29, 5450h
        mov     pna_cr30, 1C3Fh
        mov     pna_cr31, 110Fh
        jmp     Set_LONGRUN_LSpeed

Set_LONGRUN_LSpeed_1400:
        cmp     LSpeedNum, 1400
        jne     Set_LONGRUN_LSpeed_1600

        mov     pna_cr29, 3010h
        mov     pna_cr30, 141Ch
        mov     pna_cr31, 110Bh
        jmp     Set_LONGRUN_LSpeed

Set_LONGRUN_LSpeed_1600:
        mov     pna_cr29, 3010h
        mov     pna_cr30, 121Ch
        mov     pna_cr31, 110Bh

Set_LONGRUN_LSpeed:
        mov     dx, pna_cr29
        mov     bh, PHY_Number
        mov     bl, 29
        call    Write_Register_PHY

        mov     dx, pna_cr30
        mov     bh, PHY_Number
        mov     bl, 30
        call    Write_Register_PHY

        mov     dx, pna_cr31
        mov     bh, PHY_Number
        mov     bl, 31
        call    Write_Register_PHY
;;++
        ret
Setup_LONGRUN_PHY ENDP
endif

;
; On Entry:
;
;       DS:SI --> local SROM data buffer
;
check_switching_adapter PROC
        cmp     [si].NS_SROM_version, 14h       ; SROM v4.01
        je      srom_v401_chk_sw
        jmp     srom_v300_chk_sw
srom_v401_chk_sw:
        cmp     [si+32], 2                      ; hlaf switching adapter
        je      half_sw_adapt
        cmp     [si+32], 3
        je      full_sw_adapt
        jmp     not_sw_adapt

srom_v300_chk_sw:
        ;
        ; while SROM version is v3.00,
        ;    half switch : Sub Vendor ID = 0391h, Sub Device ID = 8212h
        ;    full switch : Sub Vendor ID = 0491h, Sub Device ID = 8212h
        ;
        cmp     [si].NS_SS_ID, 8212h
        jne     not_sw_adapt
        cmp     [si].NS_SS_Vendor_ID, 0391h
        je      half_sw_adapt
        cmp     [si].NS_SS_Vendor_ID, 0491h
        je      full_sw_adapt
        jmp     not_sw_adapt

half_sw_adapt:
        mov     switch_adapter, 1       ; half switching adapter

        mov     InitPIDataRate, 100
        mov     SROMPortFlag, 0

        jmp     chk_sw_exit

full_sw_adapt:
        mov     switch_adapter, 2       ; full switching adapter

        mov     InitPIDataRate, 100
        mov     SROMPortFlag, 1
        jmp     chk_sw_exit

not_sw_adapt:
        mov     switch_adapter, 0       ; not switching adapter

chk_sw_exit:
        ret
check_switching_adapter ENDP
;;;;++
;;;;++, 2000.8.24, htho, support DM9009(DM9102 without 100M PHY capability)
check_dm9009 PROC
        cmp     ChipType, DM9009_CHIP
        je      its_dm9009
        cmp     [si].NS_SROM_version, 14h       ; SROM v4.01
        jne     chk_dm9009_exit
        cmp     [si+10], 90091282h
        jne     chk_dm9009_exit
        cmp     [si], 82120990h
        jne     chk_dm9009_exit
its_dm9009:
        extrn   dm9009_chip_msg: byte
        extrn   printmsg: near
        mov     dx, OFFSET dm9009_chip_msg
        call    printmsg

        test    flagword, XF_OPTION OR XH_OPTION
        jz      @F
        extrn   dm9009_warning_msg: byte
        mov     dx, OFFSET dm9009_warning_msg
        call    printmsg
@@:
      ;;  mark by simon 2002.11.7  use external phy(9161)
      ;;  mov     anar, (ANAR_FCS+ANAR_10_FDX+ANAR_10_HDX+ANAR_CSMACD)
chk_dm9009_exit:
        ret
check_dm9009 ENDP
;;;;++
;;;;++, 2000.8.24, htho, support VLAN & Tx/Rx flow control
config_cr15 proc
        cmp     vlan, 1
        je      vlan_enable
        test    byte ptr [si+43], 80h
        jz      cfg_rx_flow_control
vlan_enable:
        or      PortConfigCR15, 00000040h

cfg_rx_flow_control:
        cmp     fcrx, 1
        je      rx_flow_control_enable
        test    byte ptr [si+40], 01h
        jz      cfg_tx_flow_control
rx_flow_control_enable:
        or      PortConfigCR15, 00000400h

cfg_tx_flow_control:
        cmp     fctx, 1
        je      tx_flow_control_enable
        test    byte ptr [si+40], 0Eh
        jz      cfg_cr15_exit
tx_flow_control_enable:
        or      PortConfigCR15, 00009800h

cfg_cr15_exit:
        ret
config_cr15 endp
;;;;++
;;;;++, 2000.10.4, simulate line plug out/in by power off/on phy for DM9102A E3
        EXTRN   InitConfigRegRead: near ; invalid in runtime time
check_dm9102a_e3 proc
        mov     dm9102a_e3, 0
        mov     dx, 50h                 ; PCIPMR Power Management Register
        call    InitConfigRegRead
        shr     eax, 16                 ; PCIPMR[18..16] = 001 -- E3
        and     al, 07h                 ; PCIPMR[18..16] = 010 -- E5
        cmp     al, 01h
        jne     @F
        mov     dm9102a_e3, 1
@@:
        ret
check_dm9102a_e3 endp
;;;;++
