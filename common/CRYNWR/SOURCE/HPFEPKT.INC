; Include file for ATT2MD01 Chip register definitions and constants.

;******************************************************************************
;       MACROS       MACROS       MACROS       MACROS       MACROS
;******************************************************************************

;******************************************************************************
; Adds 1 to a 32-bit value that is composed of two 16-bit values.
; Assumes DS->CGroup.
;******************************************************************************
INC_STAT        MACRO   Stat
        add     Stat, 1                 ;; Add 1 to lower 16 bits
        adc     Stat + 2, 0             ;; Add 1 to upper 16 bits if lower
                                        ;;   overflowed
ENDM

;******************************************************************************
; Switches card to specified page.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
SWITCH_PAGE     MACRO   Page
        setport PagingReg
        mov     ax, Page                ;; Page to switch to
        out     dx, ax
ENDM

;******************************************************************************
; Disables card interrups.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
INTS_OFF        MACRO
        setport OptionLSWReg
        mov     ax, INT_EN or RESET_LB  ;; Disable ints by setting to 0
        out     dx, ax
ENDM

;******************************************************************************
; Enables card interrups.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
INTS_ON         MACRO
        setport OptionLSWReg
        mov     ax, INT_EN or SET_LB    ;; Enable ints by setting to 1
        out     dx, ax
ENDM

;******************************************************************************
; Enables memory-mapped mode.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
MEM_MAP_ENABLE  MACRO
        setport OptionLSWReg
        mov     ax, MMAP_DIS or RESET_HB ;; Enable memory-mapped mode
        out     dx, ax
ENDM

;******************************************************************************
; Disables memory-mapped mode.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
MEM_MAP_DISABLE MACRO
        setport OptionLSWReg
        mov     ax, MMAP_DIS or SET_HB  ;; Disabe memory-mapped mode
        out     dx, ax
ENDM

;******************************************************************************
; Puts the card in reset.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
RESET_CARD      MACRO
        setport OptionLSWReg        
        mov     ax, HW_RST or RESET_LB  ;; Set HW_RST bit to 0
        out     dx, ax
ENDM

;******************************************************************************
; Takes card out of reset.
; Assumes DS->CGroup.
; Modifies DX, AX.
;******************************************************************************
UNRESET_CARD    MACRO
        setport OptionLSWReg        
        mov     ax, HW_RST or SET_LB    ;; Set HW_RST bit to 1
        out     dx, ax
ENDM

;*****************************************************************************
;  Hardware Constants
;*****************************************************************************

;******************************************************************************
; ATT2MD01 Register Page Constants
;******************************************************************************
PERFORMANCE_PAGE        equ     0000b   ; Page 0
MAC_ADDRESS_PAGE        equ     0001b   ; Page 1
HARDWARE_MAP_PAGE       equ     0010b   ; Page 2
EEPROM_CONTROL_PAGE     equ     0011b   ; Page 3
MAC_CONTROL_PAGE        equ     0100b   ; Page 4
MMU_CONFIG_PAGE         equ     0101b   ; Page 5
ID_MAC_ADDRESS_PAGE     equ     0110b   ; Page 6
MMU_POINTER_PAGE        equ     0111b   ; Page 7

;******************************************************************************
; ATT2MD01 Register Addresses
;******************************************************************************
; Present on all pages
HardwareIDReg           equ     00h  ; R:  (16)Unique card ID
TraceReg                equ     00h  ; W:  (16)Used for debug output
PagingReg               equ     02h  ; R:  (16),15:4, Card ID
                                        ; W:  (16),3:0, Switch pages
OptionLSWReg            equ     04h  ; RW: (16)Select card functions
OptionMSWReg            equ     06h  ; RW: (16)Select card functions
                                        
; Page 0 - Performance                  
InterruptStatusReg      equ     08h  ; RW: (16)Which ints are pending
InterruptMaskReg        equ     0Ah  ; RW: (16)Select ints to allow
FragmentLengthReg       equ     0Ch  ; RW: (16)12:0, Current fragment  len
OffsetReg               equ     0Eh  ; RW: (16)12:0, Offset to start read
DataReg                 equ     10h  ; RW: (32)I/O mode data port
DataRegWord             equ     12h  ; RW: WORDs must be read from here
TxMemoryFreeCountReg    equ     14h  ; RD: (32)Amount of free Tx mem
RxPktCountReg           equ     18h  ; RD: (8)Rx count of pkts on card
TxPktCountReg           equ     19h  ; RD: (8)Tx count of pkts on card
                                        
; Page 1 - MAC Address/Hash Table       
MACAddressReg           equ     08h  ; RW: (8)Cards MAC address
HashByte0Reg            equ     10h  ; RW: (8)Cards multicast filter
                                        
; Page 2 - Hardware Mapping             
MemMapLSWReg            equ     08h  ; RW: (16)LSW of cards mem addr
MemMapMSWReg            equ     0Ah  ; RW: (16)MSW of cards mem addr
IOMapReg                equ     0Ch  ; RW: (8)Cards I/O address
IRQChannelReg           equ     0Dh  ; RW: (8)IRQ and edge/level int
SRAMReg                 equ     0Eh  ; RW: (8)How much RAM on card
BMReg                   equ     0Fh  ; RW: (8)Controls BM functions
                                        
; Page 3 - EEPROM/Boot ROM              
EEPROMControlReg        equ     08h  ; RW: (16)Used to load EEPROM
                                        
; Page 4 - LAN Configuration            
LANCntrCfg10Reg         equ     08h  ; RW: (16)Set 10M XCVR functions
LANCntrCfgVGReg         equ     0Ah  ; RW: (16)Set 100M XCVR functions
MACConfiguration1Reg    equ     0Ch  ; RW: (8)Types of pkts to accept
MACConfiguration2Reg    equ     0Dh  ; RW: (8)Misc MAC functions
                                        ; The follow clear when read:
DroppedPktCountReg      equ     10h  ; R:  (16),11:0, Pkts cant fit in mem
CRCCountReg             equ     12h  ; R:  (8)Pkts with CRC
TxPktAbortCountReg      equ     13h  ; R:  (8)Aborted Tx pkts
                                        
; Page 5 - MMU                          
RxMemoryStopReg         equ     0Ch  ; RW: (16)End of Rx ring addr
TxMemoryStopReg         equ     0Eh  ; RW: (16)End of Tx ring addr
                                        
; Page 6 - Card ID/Physical LAN Address 
BoardIDReg              equ     08h  ; R:  (8)EISA/ISA card ID
IFDEF HP_PROD
BoardIDChecksumReg      equ     0Ch  ; R:  (8)Added to ID to get FFh
SoftwareModelReg        equ     0Dh  ; R:  (8)Config program defined
ENDIF; HP_PROD
PhysicalLANAddressReg   equ     10h  ; R:  (8)MAC addr of card
IFDEF HP_PROD
PhysicalLANChecksumReg  equ     16h  ; R:  (8)Added to addr to get FFh
ENDIF; HP_PROD
                                        
; Page 7 - MMU Current Pointers         
RxMemoryBeginRingReg    equ     08h  ; R:  (16)Current begin of Rx ring
RxMemoryEndRingReg      equ     0Ah  ; R:  (16)Current end of Rx ring
TxMemoryBeginRingReg    equ     0Ch  ; R:  (16)Current begin of Tx ring
TxMemoryEndRingReg      equ     0Eh  ; R:  (16)Current end of Rx ring
IFDEF HP_PROD
MemoryDebugReg          equ     1Ah  ; RW: (16)Used for memory tests
ENDIF; HP_PROD
                                                
;******************************************************************************
; HardwareIDReg bits/masks
;******************************************************************************
HW_ID_0                 equ     50h     ; Hardware ID bytes.
HW_ID_1                 equ     48h
HW_ID_2_REVA            equ     50h     ; Rev. A ID. NOTE: lower nibble not used
HW_ID_3                 equ     53h

;******************************************************************************
; OptionLSWReg bits/masks
;******************************************************************************
DEBUG_EN                equ     8000h   ; 0:Disable, 1:Enable Debug Dump Pointer
IFDEF HP_PROD
RX_HDR                  equ     4000h   ; 0:Disable, 1:Enable putting pkt into
                                        ;   system memory before Rx interrupt
ELSE; NOT HP_PROD
RES_14                  equ     4000h   ; Reserved, set to 0
ENDIF; NOT HP_PROD
MMAP_DIS                equ     2000h   ; 0:Enable, 1:Disable memory mapping.
                                        ;   MMAP_DIS must be 0 and MEM_EN must 
                                        ;   be 1 for memory-mapped mode to be 
                                        ;   enabled
EE_EN                   equ     1000h   ; 0:Disable,1:Enable EEPROM writing
BM_WRITE                equ     0800h   ; 0:Slave, 1:Bus Master for Tx data
BM_READ                 equ     0400h   ; 0:Slave, 1:Bus Master for Rx data
TRI_INT                 equ     0200h   ; 0:Dont, 1:Do tri-state the int
MEM_EN                  equ     0040h   ; Configurator program set this to
                                        ;   0:Disable, 1:Enable mem map.
                                        ;   See MMAP_DIS.
IO_EN                   equ     0020h   ; 0:Disable, 1:Enable I/O transfers
BOOT_EN                 equ     0010h   ; 0:Disable, 1:Enable boot ROM access
FAKE_INT                equ     0008h   ; 0:No int, 1:int
INT_EN                  equ     0004h   ; 0:Disable, 1:Enable ints from card
HW_RST                  equ     0002h   ; 0:Reset, 1:Out of reset 

;******************************************************************************
; OptionMSWReg bits/masks
;******************************************************************************
PRIORITY_TX             equ     0080h   ; 0:Don't, 1:Do all Tx pkts as priority
EE_LOAD                 equ     0040h   ; 1:EEPROM loading, 0 when done
ADV_NXT_PKT             equ     0004h   ; 1:Advance to next pkt in Rx queue, 
                                        ;   h/w will set to 0 when done
TX_CMD                  equ     0002h   ; 1:Tell h/w download done, h/w will set 
                                        ;   to 0 when done

;******************************************************************************
; InterruptStatusReg/InterruptMaskReg bits/masks.  These bits will 0 when a 1 
; is written to them.
;******************************************************************************
RX_PACKET               equ     0400h   ; 0:No, 1:Yes pkt has been Rx
RX_ERROR                equ     0200h   ; 0:No, 1:Yes Rx pkt had error
TX_SPACE_AVAIL          equ     0010h   ; 0:<8192, 1:>=8192 Tx free bytes 
TX_COMPLETE             equ     0008h   ; 0:No, 1:Yes a Tx has completed
TX_ERROR                equ     0002h   ; 0:No, 1:Yes Tx pkt had error
                                        
;******************************************************************************
; TxMemoryFreeCountReg bits/masks.
;******************************************************************************
AUTO_COMPARE            equ     8000h   ; Says at least 8k is available for Tx.
                                        ;   NOTE: This mask is for the upper 
                                        ;   word of the register.

;******************************************************************************
; IRQChannelReg bits/masks.
;******************************************************************************
IFDEF HP_PROD
ZERO_WAIT_EN            equ     80h     ; 0:No, 1:Yes assers NOWS signal
ENDIF; HP_PROD
LEVEL_IRQ               equ     10h     ; 0:Edge, 1:Level type interrupts.
                                        ;   Only valid on EISA cards.
IRQ_MASK                equ     0Fh     ; Isolate the IRQ bits

;******************************************************************************
; SRAMReg bits/masks.
;******************************************************************************
RAM_SIZE_MASK           equ     0E0h    ; AND to get SRAM size index
RAM_SIZE_SHIFT          equ     5       ; Shift count to put index in lower bits

;******************************************************************************
; BMReg bits/masks.
;******************************************************************************
BM_SLAVE                equ     04h     ; 0:Slave, 1:BM mode

;******************************************************************************
; EEPROMControlReg bits/masks.
;******************************************************************************
EEPROM_LOAD             equ     0001h   ; 0->1 loads the EEPROM into registers.
                                        ;   When it goes back to 0, load is 
                                        ;   complete.  This should take ~600us.

;******************************************************************************
; LANCntrCfg10Reg bits/masks.
;******************************************************************************
SQU_ST                  equ     0100h   ; 0:No, 1:Yes collision signal sent 
                                        ;   after Tx.  Only used for AUI.
MAC10_SEL               equ     00C0h   ; Get bits to indicate MAC
AUI_SEL                 equ     0020h   ; Status of AUI selection
LOW_TH                  equ     0010h   ; 0:No, 1:Yes allow better cabling
LINK_BEAT_DIS           equ     0008h   ; 0:Enable, 1:Disable link beat
LINK_BEAT_ST            equ     0004h   ; 0:No, 1:Yes link beat being Rx
R_ROL_ST                equ     0002h   ; 0:No, 1:Yes Rx twisted pair has been 
                                        ;   reversed
AUI_ST                  equ     0001h   ; 0:No, 1:Yes use AUI on TP card

; MAC Selection, use with MAC10_SEL bits
AUTO_SEL_10             equ     0h      ; Auto select
IFDEF HP_PROD
XCVR_LXT901_10          equ     1h      ; LXT901 10BaseT transceiver
ENDIF; HP_PROD
XCVR_7213               equ     2h      ; 7213 transceiver
XCVR_82503              equ     3h      ; 82503 transceiver


;******************************************************************************
; LANCntrCfgVGReg bits/masks.
;******************************************************************************
FRAME_FORMAT            equ     0800h   ; 0:802.3, 1:802.5 frames
BRIDGE                  equ     0400h   ; 0:No, 1:Yes tell hub it's a bridge
PROM_MODE               equ     0200h   ; 0:No, 1:Yes tell hub card is 
                                        ;   promiscuous
REPEATER                equ     0100h   ; 0:No, 1:Yes tell hub MAC wants to be
                                        ;   a cascaded repeater
MAC100_SEL              equ     0080h   ; 0:No, 1:Yes use 100 Mbit MAC
LINK_UP_ST              equ     0040h   ; 0:No, 1:Yes endnode logged in
LINK_CABLE_ST           equ     0020h   ; 0:No, 1:Yes cable can hear tones from 
                                        ;   hub
LOAD_ADDR               equ     0010h   ; 0->1 card addr will be sent to hub.  
                                        ;   100ms later the link status bits are 
                                        ;   valid
LINK_CMD                equ     0008h   ; 0->1 link will attempt to log in. 
                                        ;   100ms later the link status bits are 
                                        ;   valid
LINK_GOOD_ST            equ     0002h   ; 0:No, 1:Yes cable passed training
VG_RESET                equ     0001h   ; 0:Yes, 0:No reset the 100VG MAC


;******************************************************************************
; MACConfiguration1Reg bits/masks.
;******************************************************************************
RX_IDLE                 equ     80h     ; 0:Yes, 1:No currently receiving pkts
TX_IDLE                 equ     40h     ; 0:Yes, 1:No currently Txing pkts
RX_EN                   equ     20h     ; 0:No, 1:Yes allow receiving of pkts
TX_EN                   equ     10h     ; 0:No, 1:Yes allow transmiting of pkts
ACC_ERRORED             equ     08h     ; 0:No, 1:Yes allow Rx of errored pkts
ACC_MC                  equ     04h     ; 0:No, 1:Yes allow Rx of multicast pkts
ACC_BC                  equ     02h     ; 0:No, 1:Yes allow Rx of broadcast pkts
ACC_PHY                 equ     01h     ; 0:No, 1:Yes allow Rx of ALL physical pkts

MAC1MODEMASK		equ	0f0h	; Hide ACC bits
MAC1MODE1		equ	00h	; Receive nothing, must also disable RX
MAC1MODE2		equ	00h	; 
MAC1MODE3		equ	MAC1MODE2 OR ACC_BC
MAC1MODE4		equ	MAC1MODE3 OR ACC_MC
MAC1MODE5		equ	MAC1MODE4 ; set mc hash to all ones also
MAC1MODE6		equ	MAC1MODE5 OR ACC_PHY ; Promiscuous

; Note MODE6 will receive all GOOD packets on the LAN. This really needs
; a mode 7 defined to be LAN Analyzer mode, which will receive errored and
; runt packets, and keep the CRC bytes.

MAC1MODE7		equ	MAC1MODE6 OR ACC_ERRORED
;******************************************************************************
; MACConfiguration2Reg bits/masks.
;******************************************************************************
TR_MODE                 equ     80h     ; 0:No, 1:Yes support Token Ring formats
TX_SAME                 equ     40h     ; 0:No, 1:Yes Tx same packet continuous
LBK_XCVR                equ     20h     ; 0:No, 1:Yes loopback through MAC & 
                                        ;   transceiver
LBK_MAC                 equ     10h     ; 0:No, 1:Yes loopback through MAC
CRC_I                   equ     08h     ; 0:No, 1:Yes inhibit CRC on Tx packets
KEEP_CRC                equ     02h     ; 0:No, 1:Yes keep CRC on Rx packets.  
                                        ;   The length will reflect this.

MAC2MODEMASK		equ	02h
MAC2MODE1		equ	00h
MAC2MODE2		equ	00h
MAC2MODE3		equ	00h
MAC2MODE4		equ	00h
MAC2MODE5		equ	00h
MAC2MODE6		equ	00h
MAC2MODE7		equ	KEEP_CRC
;******************************************************************************
; BoardIDReg bits/masks.
;******************************************************************************
;
REV_NIB			equ		00Fh
;
; List of boards we support
IFDEF HP_PROD
HPJ2577_REVA_EID		equ		080F1F022h
HPJ2577_TYPE_REVA		equ		00h
HPJ2573_REVA_EID		equ		050F1F022h
HPJ2573_TYPE_REVA		equ		01h
HP27248B_EID			equ		02019F022h
HP27248B_TYPE			equ		02h
HPJ2577_EID			equ		04019F022h
HPJ2577_TYPE			equ		03h
HPJ2573_EID			equ		05019F022h
HPJ2573_TYPE			equ		04h

;******************************************************************************
; SoftwareModelReg bits/masks.
;******************************************************************************

ENDIF; HP_PROD

;******************************************************************************
; Set/Reset bits
;******************************************************************************
SET_HB                  equ     0100h   ; 0:Set fields to 0 whose mask is 1
SET_LB                  equ     0001h   ; HB sets upper byte, LB sets lower byte
RESET_HB                equ     0000h   ; For readability when resetting bits
RESET_LB                equ     0000h   ; For readability when resetting bits

;******************************************************************************
; Misc. Constants
;******************************************************************************
LAN_100                 equ     100     ; lan_type value for VG
LAN_10                  equ     10      ; lan_type value for 10BaseT

;******************************************************************************
; Receive Header Definition.
;******************************************************************************
RxHeaderStructure       struc
        RxLength        dw      ?       ; Pkt length is bits 12:0.
        RxStatus        dw      ?       ; Status of the packet
RxHeaderStructure       ends

PKT_LEN_MASK    equ     1FFFh           ; AND with RxLength to get length bits

; Receive Packet Status.  Note, the error bits are only valid if ACC_ERRORED 
; bit in the MAC Configuration Register 1 is set.
RX_PRI                  equ     8000h   ; 0:No, 1:Yes packet is priority
SDF_ERR                 equ     4000h   ; 0:No, 1:Yes start of frame error
SKEW_ERR                equ     2000h   ; 0:No, 1:Yes skew out of range
BAD_SYMBOL_ERR          equ     1000h   ; 0:No, 1:Yes invalid symbol received
RCV_IPM_ERR             equ     0800h   ; 0:No, 1:Yes pkt had an invalid packet 
                                        ;   marker
SYMBOL_BAL_ERR          equ     0400h   ; 0:No, 1:Yes symbol balance error
VG_ALN_ERR              equ     0200h   ; 0:No, 1:Yes non-octet received
TRUNC_ERR               equ     0100h   ; 0:No, 1:Yes the packet was truncated
RUNT_ERR                equ     0040h   ; 0:No, 1:Yes pkt length < Min Pkt 
                                        ;   Length Reg.
ALN_ERR                 equ     0010h   ; 0:No, 1:Yes align error. 
CRC_ERR                 equ     0008h   ; 0:No, 1:Yes CRC occurred. 

; The last three bits indicate the type of destination address
MULTI_ADDR_HASH         equ     0006h   ; 110: Addr multicast, matched hash
BROADCAST_ADDR          equ     0003h   ; x11: Addr broadcast
MULTI_ADDR_NO_HASH      equ     0002h   ; 010: Addr multicast, didn't match hash
PHYS_ADDR_MATCH         equ     0001h   ; x01: Addr was physical and mine
PHYS_ADDR_NO_MATCH      equ     0000h   ; x00: Addr was physical but not mine


