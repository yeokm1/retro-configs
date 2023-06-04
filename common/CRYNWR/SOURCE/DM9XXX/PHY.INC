;; -- PHY Registers
PHY_BMCR		EQU	00h
PHY_BMSR		EQU	01h
PHY_PHYIDR1		EQU	02h
PHY_PHYIDR2		EQU	03h
PHY_ANAR		EQU	04h
PHY_ANLPAR		EQU	05h
PHY_ANER		EQU	06h
PHY_DCR 		EQU	12h
PHY_FCSCR		EQU	13h
PHY_DECR		EQU	15h
PHY_SRR 		EQU	16h
PHY_PCR 		EQU	17h
PHY_LBREMR		EQU	18h
PHY_DSCSR		EQU	17
PHY_10BTCSR		EQU	18
PHY_PAR 		EQU	19h
PHY_10BTSR		EQU	1Bh
PHY_10BTCR		EQU	1Ch

;; -- Pattern thtough CR9 to program PHY
PHY_clkL_Write_0	EQU	00000h
PHY_clkH_Write_0	EQU	10000h
PHY_clkL_Write_1	EQU	20000h
PHY_clkH_Write_1	EQU	30000h

PHY_clkL_Read		EQU	40000h
PHY_clkH_Read		EQU	50000h

CR9_M_MDI	       EQU     80000h
CR9_S_MDI	       EQU     19

BMCR_M_DM		EQU	0100h	       ; Duplex Mode mask.

BMSR_M_AN		EQU	0020h	       ; Auto-Negotiation complete mask
BMSR_M_LS		EQU	0004h	       ; Link Status mask.

ANER_M_LAA		EQU	0001h	       ; Link Partner Auto-Negotiation Able mask

;;PAR_M_SI10		  EQU	  0040h 	 ; Speed Indication mask

;;--- PHY Chip
DSIPHY			EQU	0
NSPHY			EQU	1
;;++, 2000.3.27
PNAPHY			EQU	2
;;++

NS_OUI_MSB		EQU	0010000000000000B
NS_OUI_LSB		EQU	0101110000000000B

