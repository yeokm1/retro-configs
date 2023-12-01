//
// Copyright (c) 1992 Standard Microsystems Corp. All Rights Reserved.
//
// Include file for Bus Interface Chips 83C583, 584, 585, 593, 594, 790//
// Network Interface Controllers 83C690 (8390), 825, 790.
//
// No defs for the 593 in 8023 Mode.
//
//////////////////////////////////////////////////////////////////////////////
//
// Defs for Bus Interface Chips . . .
//
//////////////////////////////////////////////////////////////////////////////
// Offset 0: MSR - Memory Select Register
//
#define	REG_MSR		0x000	// Register Offset
#define	MSR_RST		0x080	// LAN Controller Reset
#define	MSR_MENB	0x040	// Shared Memory Enable
#define	MSR_RA18	0x020	// Ram Address bit 18	(583, 584)
#define	MSR_0WS		0x020	// Zero Wait State	(585/790)
#define	MSR_RA17	0x010	// Ram Address bit 17	(583, 584, 585/790)
#define	MSR_RA16	0x008	// Ram Address bit 16	(583, 584, 585/790)
#define	MSR_RA15	0x004	// Ram Address bit 15	(583, 584, 585/790)
#define	MSR_RA14	0x002	// Ram Address bit 14	(583, 584, 585/790)
#define	MSR_RA13	0x001	// Ram Address bit 13	(583, 584, 585/790)
#define	MSR_MASK	0x03F	// Mask for Address bits RA18-RA13 (583, 584)
#define	MSR_585_MASK	0x01F	// Mask for Address bits RA17-RA13 (585/790)

//////////////////////////////////////////////////////////////////////////////
// Offset 1: ICR - Interface Configuration Register (583, 584)
//
#define	REG_ICR		0x001	// Register Offset
#define	ICR_STO		0x080	// EEROM Store		
#define	ICR_RIO		0x040	// Recall I/O Address
#define	ICR_RX7		0x020	// Recall All but I/O and LAN Addr
#define	ICR_RLA		0x010	// Recall LAN Address
#define	ICR_MSZ		0x008	// Memory Size
#define	ICR_IR2		0x004	// IRQ index MSB (584)
#define	ICR_OTH		0x002	// "Other"(EEROM) register access (584)
#define	ICR_16B		0x001	// Bus size bit (584)

// Unique defs for 583 . . .
//
#define	ICR_DMA		0x004	// DMA Enable (583)
#define	ICR_IO		0x002	// I/O Port Enable (583)
#define	ICR_WTS		0x001	// Word Transfer Select (583)

//////////////////////////////////////////////////////////////////////////////
// Offset 1: EER - EEROM Register (585/790)
//
#define	REG_EER		0x001	// Register Offset
#define	EER_STO		0x080	// Store EEROM Data
#define	EER_RC		0x040	// Recall Index 1
#define	EER_EA7		0x020	// EEROM Address bit 7 (write, 795)
#define	EER_UNLCK	0x010	// Unlock bit
#define	EER_EA6		0x008	// EEROM Address bit 6 (write)
#define	EER_EA5		0x004	// EEROM Address bit 5 (write)
#define	EER_EA4		0x002	// EEROM Address bit 4 (write)
#define	EER_EA3		0x001	// EEROM Address bit 3 (write)

#define	EER_INIT3	0x008	// Init Jumper Input pin 3 (read)
#define	EER_INIT2	0x004	// Init Jumper Input pin 2 (read)
#define	EER_INIT1	0x002	// Init Jumper Input pin 1 (read)
#define	EER_INIT0	0x001	// Init Jumper Input pin 0 (read)

/////////////////////////////////////////////////////////////////////////////
// Offset 02: SSR - Status Register (PCMCIA)
//
#define	REG_SSR		0x02

#define	SSR_BNC		0x80	// Turns on external BNC transciever.
#define	SSR_VX		0x40	// Indicates external power is applied to card.
#define	SSR_NLNK	0x20	// Link Integrity present.
#define	SSR_NPOL	0x10	// UTP polarity.

//////////////////////////////////////////////////////////////////////////////
// Offset 02: IOPDL - I/O Pipe Data Lo (795)
//
#define	REG_IOPDL	0x002		// Register Offset
#define	REG_IOPD	REG_IOPDL	// Register Offset for 16 bit access

//////////////////////////////////////////////////////////////////////////////
// Offset 03: IOPDH - I/O Pipe Data Hi (795)
//
#define	REG_IOPDH	0x003	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 02: IAR - I/O Address Register (583, 584) For 585/790,
//		   use IAR5 (offset 0A).
//
//	Example:
//	  0	  2	  8	  0
//	XXXX	XXXX	XXXX	XXXX
//	***0	0x00**	***0	0x0000
//
#define	REG_IAR		0x002	// Register Offset
#define	IAR_IA15	0x080	// I/O Address bit 15
#define	IAR_IA14	0x040	// I/O Address bit 14
#define	IAR_IA13	0x020	// I/O Address bit 13
#define	IAR_IA9		0x010	// I/O Address bit 9
#define	IAR_IA8		0x008	// I/O Address bit 8
#define	IAR_IA7		0x004	// I/O Address bit 7
#define	IAR_IA6		0x002	// I/O Address bit 6
#define	IAR_IA5		0x001	// I/O Address bit 5

//////////////////////////////////////////////////////////////////////////////
// Offset 03: BIO - BIOS ROM Address register (583, 584)
//
#define	REG_BIO		0x003	// Register offset
#define	BIO_RS1		0x080	// ROM Size Index 1
#define	BIO_RS0		0x040	// ROM Size Index 0
#define	BIO_BA18	0x020	// Address bit 18
#define	BIO_BA17	0x010	// Address bit 17
#define	BIO_BA16	0x008	// Address bit 16
#define	BIO_BA15	0x004	// Address bit 15
#define	BIO_BA14	0x002	// Address bit 14
#define	BIO_INT		0x001	// Hardware Interrupt

//////////////////////////////////////////////////////////////////////////////
// Offset 03: EAR - EEROM Address Register (584) This register is accessed
//		   when ICR_OTH is set.
//
#define	REG_EAR		0x003	// Register Offset
#define	EAR_EA6		0x080	// EEROM Address Bit 6
#define	EAR_EA5		0x040	// EEROM Address Bit 5
#define	EAR_EA4		0x020	// EEROM Address Bit 4
#define	EAR_EA3		0x010	// EEROM Address Bit 3
#define	EAR_RAM		0x008	// RAM Installed in ROM Socket
#define	EAR_RPE		0x004	// ROM Page Enable
#define	EAR_RP1		0x002	// ROM Page bit 1
#define	EAR_RP0		0x001	// ROM Page bit 0

//////////////////////////////////////////////////////////////////////////////
// Offset 04: IRR Interrupt Request Register (583, 584)
//
#define	REG_IRR		0x004	// Register Offset

#define	IRR_IEN		0x080	// Interrupt (IRQ) Enable
#define	IRR_IR1		0x040	// IRQ index bit 1 (For 584, Bit 2 is ICR_IR2)
#define	IRR_IR0		0x020	// IRQ index bit 0
#define	IRR_FLSH	0x010	// Flash ROM in ROM Socket (584)
#define	IRR_OUT3	0x008	// Output3 Pin Assert (584)
#define	IRR_OUT2	0x004	// Output2 Pin Assert (584)
#define	IRR_OUT1	0x002	// Output1 Pin Assert (584)
#define	IRR_0WS8	0x001	// 8-bit Zero Wait State Enable

// Unique defs for 583 . . .
//
#define	IRR_AMD		0x010	// Alternate Mode
#define	IRR_AINT	0x008	// Alternate (Hardware) Interrupt
#define	IRR_BW1		0x004	// BIOS ROM Wait State Bit 1
#define	IRR_BW0		0x002	// BIOS ROM Wait State Bit 0

// Adapter Specific Defs:
//
// Ethernet:
#define	IRR_BNC		0x004	// Enables -9V DC/DC Converter for Thin-net.
#define	IRR_LITE	0x002	// Link Integ. Test Enable (for 8003WC series)
				//  Disable (for other Elite Adapters)
// Token Ring:
#define	IRR_UTP		0x004	// Unshielded TP Cable Select (0=Shielded TP)
#define	IRR_16MBPS	0x002	// 16 MBPS Select (0=4MBPS)

//////////////////////////////////////////////////////////////////////////////
// Offset 04: HWR - Hardware Support Register (585/790)
//
#define	REG_HWR		0x004	// Register Offset
#define	HWR_SWH		0x080	// Switch Register Set
#define	HWR_LPRM	0x040	// LAN Address ROM Select
#define	HWR_ETHER	0x020	// NIC Type. 1=83C690, 0=83C825. (Read)
#define	HWR_HOST16	0x010	// Set When Host has 16 bit bus. (Read)
#define	HWR_STAT2	0x008	// Interrupt Status (Read)
#define	HWR_STAT1	0x004	// Interrupt Status (Read)
#define	HWR_GIN2	0x002	// General Purpose Input 2 (Read)
#define	HWR_PNPE	0x002	// Plug'n'Play enabled bit (795, read)
#define	HWR_GIN1	0x001	// General Purpose Input 1 (Read)

#define	HWR_MASK	0x020	// Interrupt Mask Bit (Write)
#define	HWR_NUKE	0x008	// Hardware Reset (Write)
#define	HWR_CLR1	0x004	// Clear Interrupt (Write, 585 only)
#define	HWR_HWCS	0x002	// WCS Control (Write, 585 only)
#define	HWR_CA		0x001	// Control Attention (Write, 585 only)

//////////////////////////////////////////////////////////////////////////////
// Offset 05: GP1 - General Purpose Register 1 (583)
//
#define	REG_GP1		0x005	// Register Offset
#define	GP1_BIT7	0x080	// Undefined
#define	GP1_BIT6	0x040	// Undefined
#define	GP1_BIT5	0x020	// Undefined
#define	GP1_BIT4	0x010	// Undefined
#define	GP1_BIT3	0x008	// Undefined
#define	GP1_BIT2	0x004	// Undefined
#define	GP1_BIT1	0x002	// Undefined
#define	GP1_BIT0	0x001	// Undefined

//////////////////////////////////////////////////////////////////////////////
// Offset 05: LAAR - LA Address Register (584)
//
#define	REG_LAAR	0x005	// Register Offset
#define	LAAR_M16E	0x080	// 16 Bit Host Access Enable
#define	LAAR_L16E	0x040	// 16 Bit NIC Access Enable
#define	LAAR_0WS16	0x020	// 16 Bit Zero Wait State Enable
#define	LAAR_LA23	0x010	// RAM Address bit 23
#define	LAAR_LA22	0x008	// RAM Address bit 22
#define	LAAR_LA21	0x004	// RAM Address bit 21
#define	LAAR_LA20	0x002	// RAM Address bit 20
#define	LAAR_LA19	0x001	// RAM Address bit 19
#define	LAAR_MASK	0x01F	// Masks off LA Address bits & LAAR_M16E

//////////////////////////////////////////////////////////////////////////////
// Offset 05: BPR - BIOS Page Register (585/790)
//
#define	REG_BPR		0x005	// Register Offset
#define	BPR_M16EN	0x080	// 16 Bit Host Access Enable
#define	BPR_BP15	0x040	// BIOS ROM Offset Bit 15
#define	BPR_BP14	0x020	// BIOS ROM Offset Bit 14
#define	BPR_BP13	0x010	// BIOS ROM Offset Bit 13
#define	BPR_SINT	0x008	// Software Induced Interrupt
#define	BPR_EIL		0x004	// Interrupt Enable (585)
#define	BPR_BMSTR	0x004	// Bus Master Enable (Ethernet EISA)
#define	BPR_SOFT2	0x002	// General Purpose For Software (Claim Bit)
#define	BPR_SOFT1	0x001	// General Purpose For Software (Claim Bit)

//////////////////////////////////////////////////////////////////////////////
// Offset 05: CR - Control Register (593, 594)
//
#define	REG_CR		0x005	// Register Offset
#define	CR_BIT7		0x080	// Reserved
#define	CR_RMS2		0x040	// BIOS ROM Map Select 2 (594)
#define	CR_RMS1		0x020	// BIOS ROM Map Select 1 (594)
#define	CR_RMS0		0x010	// BIOS ROM Map Select 0 (594)
#define	CR_SINT		0x008	// Software Induced Interrupt (594)
#define	CR_EIL		0x004	// Interrupt Enable
#define	CR_CLAIM1	0x002	// Claim Bit 1 (594)
#define	CR_CLAIM0	0x001	// Claim Bit 0 (594)

//////////////////////////////////////////////////////////////////////////////
// Offset 06: IJR - Initialize Jumper Register (584)
//
#define	REG_IJR		0x006	// Register Offset

#define	IJR_BIT7	0x080	// Not Defined
#define	IJR_LPOL	0x040	// Link Polarity Input (Ethernet TP)
#define	IJR_LINT	0x020	// Link Integrity Input (Ethernet TP)
#define	IJR_BIT4	0x010	// Not Defined
#define	IJR_BIT3	0x008	// Not Defined
#define	IJR_INIT2	0x004	// Jumper Input Bit 2
#define	IJR_INIT1	0x002	// Jumper Input Bit 1
#define	IJR_INIT0	0x001	// Jumper Input Bit 0

////////////////////////////////////////////////////////////////////////////
// Offset 06: INTCR - Interrupt Control Register (790)
//
#define	REG_INTCR	0x006	// Register offset

#define	INTCR_MCT	0x080	// Memory cache test bit (795)
#define	INTCR_STAG	0x040	// Staggered address enable (795)
#define	INTCR_IOPAV	0x020	// I/O pipe address visible (795)
#define	INTCR_IOPE	0x010	// I/O pipe enable (795)
#define	INTCR_SINT	0x008	// Software irq
#define	INTCR_MSK2	0x004	// Irq mask 2 (masks NIC irqs)
#define	INTCR_MSK1	0x002	// Irq mask 1 (not used)
#define	INTCR_EIL	0x001	// Enable irq line

//////////////////////////////////////////////////////////////////////////////
// Offset 07: GP2 - General Purpose Register 2 (583, 584)
//
#define	REG_GP2		0x007	// Register Offset

#define	GP2_BIT7	0x080	// General purpose bit 7
#define	GP2_BIT6	0x040	// General purpose bit 6
#define	GP2_BIT5	0x020	// General purpose bit 5
#define	GP2_BIT4	0x010	// General purpose bit 4
#define	GP2_BIT3	0x008	// General purpose bit 3
#define	GP2_PME		0x004	// Priority Mode Enable (584, Token Ring)
#define	GP2_ETRD	0x002	// Early Token Release Disable (584, Token Ring)
#define	GP2_RPLD	0x001	// RPL Disable (584, Bistro Ethernet)

//////////////////////////////////////////////////////////////////////////////
// Offset 07: REV - Revision Register (585/790)
//		  - I/O Pipe Address (write, 795)

#define	REG_REV		0x007	// Register Offset
#define	REG_IOPA	0x007	// Register Offset I/O pipe address (795, write)

#define	REV_CHIP3	0x080	// Chip type bit 3
#define	REV_CHIP2	0x040	// Chip type bit 2
#define	REV_CHIP1	0x020	// Chip type bit 1
#define	REV_CHIP0	0x010	// Chip type bit 0
#define	REV_REV3	0x008	// Chip revision bit 3
#define	REV_REV2	0x004	// Chip revision bit 2
#define	REV_REV1	0x002	// Chip revision bit 1
#define	REV_REV0	0x001	// Chip revision bit 0

// 790 Chip type is 0010. (CHIP3:0)
#define	CHIP_790_DEF	REV_CHIP1

// 585 Chip type is 0011 (CHIP3:0)
#define	CHIP_585_DEF	REV_CHIP1 OR REV_CHIP0

//////////////////////////////////////////////////////////////////////////////
// Offsets 08-0F: LAR - LAN Address Registers (All BIC's)
// Individual bits are not specifically defined.

#define	REG_LAR0	0x008	// LAN Address byte 0 (MSB) Global
#define	REG_LAR1	0x009	// LAN Address byte 1 Global
#define	REG_LAR2	0x00A	// LAN Address byte 2 Global
#define	REG_LAR3	0x00B	// LAN Address byte 3
#define	REG_LAR4	0x00C	// LAN Address byte 4
#define	REG_LAR5	0x00D	// LAN Address byte 5 (LSB)
#define	REG_BDID	0x00E	// Adapter ID byte
#define	REG_CKSM	0x00F	// LAN Address/ID byte checksum

//////////////////////////////////////////////////////////////////////////////
// Offset 09: DCFG - Driver Config Register (585/790)
//
#define	REG_DCFG	0x009	// Register Offset

#define	DCFG_BIT7	0x080
#define	DCFG_BIT6	0x040
#define	DCFG_BIT5	0x020
#define	DCFG_BIT4	0x010
#define	DCFG_BIT3	0x008
#define	DCFG_BIT2	0x004
#define	DCFG_ETRD	0x002
#define	DCFG_BIT0	0x001	// Early Token Release Disable

//////////////////////////////////////////////////////////////////////////////
// Offset 0A: IAR7 - I/O Address Register (585/790)
// Register is referred to as IAR7 instead of IAR to avoid conflicts with 
// the 584 IAR register.
//
//	Example:
//	  0	  2	  8	  0
//	XXXX	XXXX	XXXX	XXXX
//	***0	0x001*	***0	0x0000
//
#define	REG_IAR7	0x00A	// Register Offset

#define	IAR7_IA15	0x080	// I/O Address bit 15
#define	IAR7_IA14	0x040	// I/O Address bit 14
#define	IAR7_IA13	0x020	// I/O Address bit 13
#define	IAR7_IA8	0x010	// I/O Address bit 8
#define	IAR7_IA7	0x008	// I/O Address bit 7
#define	IAR7_IA6	0x004	// I/O Address bit 6
#define	IAR7_IA5	0x002	// I/O Address bit 5
#define	IAR7_PNPB	0x001	// Plug'n'Play boot bit (795)

//////////////////////////////////////////////////////////////////////////////
// Offset 0B: RAR - RAM Address Register (585/790)
//
#define	REG_RAR		0x00B	// Register Offset

#define	RAR_HRAM	0x080	// High ram address
#define	RAR_RA17	0x040	// RAM base address bit 17
#define	RAR_RWS1	0x020	// RAM window size bit 1
#define	RAR_RWS0	0x010	// RAM window size bit 0
#define	RAR_RA16	0x008	// RAM base address bit 16
#define	RAR_RA15	0x004	// RAM base address bit 15
#define	RAR_RA14	0x002	// RAM base address bit 14
#define	RAR_RA13	0x001	// RAM base address bit 13

//////////////////////////////////////////////////////////////////////////////
// Offset 0C: BIO - BIOS ROM Control Register (585/790)
// Register is referred to as BAR instead of BIO to avoid conflicts with the
// 584 BIO register.
//
#define	REG_BAR		0x00C	// Register Offset

#define	BAR_FINE	0x080	// MEMCS16 Assertion for RAM (Not ROM)
#define	BAR_BA17	0x040	// ROM base address bit 17
#define	BAR_BWS1	0x020	// ROM window size bit 1
#define	BAR_BWS0	0x010	// ROM window size bit 0
#define	BAR_BA16	0x008	// ROM base address bit 16
#define	BAR_BA15	0x004	// ROM base address bit 15
#define	BAR_BA14	0x002	// ROM base address bit 14
#define	BAR_BA13	0x001	// ROM base address bit 13

//////////////////////////////////////////////////////////////////////////////
// Offset 0D: GCR - General Control Register (585/790)
//
#define	REG_GCR		0x00D	// Register Offset

#define	GCR_EUTP	0x080	// Extended Length UTP (795)
#define	GCR_IR2		0x040	// IRQ index Bit 2 MSB
#define	GCR_0WS		0x020	// Zero Wait State
#define	GCR_RIPL	0x010	// RPL Disable (MCA)
#define	GCR_IR1		0x008	// IRQ index Bit 1
#define	GCR_IR0		0x004	// IRQ index Bit 0 LSB
#define	GCR_GPOUT	0x002	// General purpose output.
#define	GCR_LITE	0x001	// Link integrity test enable

#define	BNC_585_OFF	0x00
#define	BNC_585_ON	0x02

/////////////////////////////////////////////////////////////////////////////
// Offset 0E: ERFAL - Early Rx Fail Address Lo (795)
//
#define	REG_ERFAL	0x00E	// Register Offset
#define	REG_ERFA	0x00E	// Register Offset (16 bit access)

/////////////////////////////////////////////////////////////////////////////
// Offset 0F: ERFAH - Early Rx Fail Address Hi (795)
//
#define	REG_ERFAH	0x00F	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Defs for Network Interface Controllers . . .
// 8390/690, 790, 825
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
// 8390/690 defs
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
//Offset 10h (NIC offset 00h): CMD - Command Register
// Read	page (all)
// Write	page (all)

#define	REG_CMD		0x010	// Register Offset

#define	CMD_STP		0x001	// Stop NIC
#define	CMD_STA		0x002	// Start NIC
#define	CMD_TXP		0x004	// Transmit Packet
#define	CMD_RD0		0x008	// Remote DMA Command bit 0
#define	CMD_RD1		0x010	// Remote DMA Command bit 1
#define	CMD_RD2		0x020	// Remote DMA Command bit 2
#define	CMD_PS0		0x040	// Page Select Bit 0
#define	CMD_PS1		0x080	// Page Select Bit 1

// or in these bits for selecting a specific page . . .
#define	CMD_PAGE0	0x000
#define	CMD_PAGE1	CMD_PS0
#define	CMD_PAGE2	CMD_PS1
#define	CMD_PAGE3	CMD_PS0+CMD_PS1

//////////////////////////////////////////////////////////////////////////////
// Offset 11h (NIC offset 01h): PSTART - Page Start Register
// Read	page 0
// Write	page 2

#define	REG_PSTART	0x011	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 12h (NIC offset 02h): PSTOP - Page Stop Register
// Read	page 0
// Write	page 2

#define	REG_PSTOP	0x012	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 13h (NIC offset 03h): BNRY - Boundary Pointer Register
// Read	page 0
// Write	page 0

#define	REG_BNRY	0x013	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 14h (NIC offset 04h): TSR - Transmit Status Register
// Read only, page 0

#define	REG_TSR		0x014	// Register Offset

#define	TSR_PTX		0x001	// Packet Transmitted
#define	TSR_NDT		0x002	// Non-Deferred Transmit
#define	TSR_COL		0x004	// Transmit Collided
#define	TSR_ABT		0x008	// Xmit Aborted due to excessive collisions
#define	TSR_CRS		0x010	// Carrier Sense lost
#define	TSR_FU		0x020	// FIFO Underrun
#define	TSR_CDH		0x040	// Carrier Detect Heartbeat
#define	TSR_OWC		0x080	// Out of Window Collision

//////////////////////////////////////////////////////////////////////////////
// Offset 14h (NIC offset 04h): TPSR - Transmit Page Start Address Register
// Read	page 2
// Write	page 0

#define	REG_TPSR	0x014	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 15h (NIC offset 05h): NCR - Number of Collisions Register
// Read only, page 0

#define	REG_NCR		0x015	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 15h (NIC offset 05h): TBCR0 - Transmit Byte Count Register 0
// Write	only, page 0

#define	REG_TBCR0	0x015	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 16h (NIC offset 06h): TBCR1 - Transmit Byte Count Register 1
// Write	only, page 0

#define	REG_TBCR1	0x016	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 16h (NIC offset 06h): FIFO - FIFO Register
// Read only, page 0


#define	REG_FIFO	0x016	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 17h (NIC offset 07h): ISR - Interrrupt Status Register
// Read	page 0
// Write	page 0

#define	REG_ISR		0x017	// Register Offset

#define	ISR_PRX		0x001	// Packet Received
#define	ISR_PTX		0x002	// Packet Transmitted
#define	ISR_RXE		0x004	// Receive Error
#define	ISR_TXE		0x008	// Transmit Error
#define	ISR_OVW		0x010	// Ring Overwrite Warning
#define	ISR_CNT		0x020	// Counter Overflow Warning
#define	ISR_RDC		0x040	// Remote DMA Complete
#define	ISR_RST		0x080	// Reset Status

//////////////////////////////////////////////////////////////////////////////
// Offset 17h (NIC offset 07h): CURR - Current Page Register
// Read	page 1
// Write	page 1

#define	REG_CURR	0x017	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 17h (NIC offset 07h): ENH - Enhancement Register (790)
// Read	page 2
// Write	page 2

#define	REG_ENH		0x017	// Register Offset

#define	ENH_SBACK	0x001	// Backoff mode
//#define	ENH_		0x002h
#define	ENH_EOTINT	0x004	// End of transmit interrupt mode bit
#define	ENH_SLOT0	0x008	// Slot time bit 0
#define	ENH_SLOT1	0x010	// Slot time bit 1
#define	ENH_ALTEGO	0x020	// 690/790 mode select
#define	ENH_WAIT0	0x040	// DMA wait states bit 0
#define	ENH_WAIT1	0x080	// DMA wait states bit 1

///////////////////////////////////////////////////////////////////////////////
// Offset 19h (NIC offset 09h): TPSRL - Transmit Page Start Address Register
// Read	page 2
// Write	page 0

#define REG_TPSRL	0x19	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 19h (NIC offset 09h): UBRCV - Ultra Bitchen Receive Register (795)
// Read/Write	page 0

#define	REG_UBRCV	0x019	// Register Offset

#define	UBRCV_RE	0x004	// Indicates Rx ring is empty (read only)
#define	UBRCV_URUN	0x002	// Indicates ERX underrun
#define	UBRCV_WREN	0x001	// Ring Wrap enable

//////////////////////////////////////////////////////////////////////////////
// Offset 1Ah (NIC offset 0Ah): RBCR0 - Remote Byte Count Register 0
// Write	only, page 0

#define	REG_RBCR0	0x01A	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 1Bh (NIC offset 0Bh): RBCR1 - Remote Byte Count Register 1
// Write	only, page 0

#define	REG_RBCR1	0x01B	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 1Ch (NIC offset 0Ch): RSR - Receive Status Register
// Read only, page 0

#define	REG_RSR		0x01C	// Register Offset

#define	RSR_PRX		0x001	// Packet Received
#define	RSR_CRC		0x002	// CRC Error
#define	RSR_FAE		0x004	// Frame Alignment Error
#define	RSR_FO		0x008	// FIFO Overrun
#define	RSR_MPA		0x010	// Missed Packet
#define	RSR_PHY		0x020	// Physical Address
#define	RSR_DIS		0x040	// Receiver Disabled
#define	RSR_DFR		0x080	// Deferring

//////////////////////////////////////////////////////////////////////////////
// Offset 1Ch (NIC offset 0Ch): RCR - Receive Configuration Register
// Read	page 2
// Write	page 0

#define	REG_RCR		0x01C	// Register Offset

#define	RCR_SEP		0x001	// Save Errored Packets
#define	RCR_AR		0x002	// Accept Runt Packets
#define	RCR_AB		0x004	// Accept Broadcast Packets
#define	RCR_AM		0x008	// Accept Multicast Packets
#define	RCR_PRO		0x010	// Promiscuous Mode
#define	RCR_MON		0x020	// Monitor Mode
//#define	RCR_RES	0x040	// Reserved
//#define	RCR_RES	0x080	// Reserved

//////////////////////////////////////////////////////////////////////////////
// Offset 1Dh (NIC offset 0Dh): TCR - Transmit Configuration Register
// Read	page 2
// Write	page 0

#define	REG_TCR		0x01D	// Register Offset

#define	TCR_CRC		0x001	// Inhibit CRC
#define	TCR_LB0		0x002	// Encoded Loopback Control bit 0
#define	TCR_LB1		0x004	// Encoded Loopback Control bit 1
#define	TCR_ATD		0x008	// Auto Transmit Disable
#define	TCR_OFST	0x010	// Collision Offset Enable
//#define	TCR_RES	0x020	// Reserved
//#define	TCR_RES	0x040	// Reserved
//#define	TCR_RES	0x080	// Reserved
//////////////////////////////////////////////////////////////////////////////
// Offset 1Dh (NIC offset 0Dh): CNTR0 - Tally Counter Register 0 (FAE)
// Read only, page 0

#define	REG_CNTR0	0x01D	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 1Eh (NIC offset 0Eh): DCR - Data Configuration Register
// Read	page 2
// Write page 0

#define	REG_DCR		0x01E	// Register Offset

#define	DCR_WTS		0x001	// Word Transfer Select
#define	DCR_BOS		0x002	// Byte Order Select
#define	DCR_LAS		0x004	// Long Address Select
#define	DCR_LS		0x008	// Loopback Select
#define	DCR_AR		0x010	// Autoinitialize Remote
#define	DCR_FT0		0x020	// FIFO Threshhold Select Bit 0
#define	DCR_FT1		0x040	// FIFO Threshhold Select Bit 1
//#define	DCR_RES	0x080	// Reserved

//////////////////////////////////////////////////////////////////////////////
// Offset 1Eh (NIC offset 0Eh): CNTR1 - Tally Counter Register 1 (CRC)
// Read only, page 0

#define	REG_CNTR1	0x01E	// Register Offset

//////////////////////////////////////////////////////////////////////////////
// Offset 1Fh (NIC offset 0Fh): IMR - Interrupt Mask Register
// Read	page 2
// Write page 0

#define	REG_IMR		0x01F	// Register Offset

#define	IMR_PRXE	0x001	// Packet Received Interrupt Enable
#define	IMR_PTXE	0x002	// Packet Transmitted Interrupt Enable
#define	IMR_RXEE	0x004	// Receive Error Interrupt Enable
#define	IMR_TXEE	0x008	// Transmit Error Interrupt Enable
#define	IMR_OVWE	0x010	// Ring Overwrite Warning Interrupt Enable
#define	IMR_CNTE	0x020	// Counter Overflow Interrupt Enable
#define	IMR_RDCE	0x040	// DMA Complete Interrupt Enable
//#define	IMR_RES	0x080	// Reserved

//////////////////////////////////////////////////////////////////////////////
// Offset 1Fh (NIC offset 0Fh): CNTR2 - Tally Counter Register 2 (MPA)
// Read only, page 0

#define	REG_CNTR2	0x01F	// Register Offset

////////////////////////////////////////////////////////////////////////////// 
// Other Page 1 Register Offset Assignments
//
#define	REG_PAR0	0x11	// Offset, Physical Address Register 0
#define	REG_PAR1	0x12	// Offset, Physical Address Register 1
#define	REG_PAR2	0x13	// Offset, Physical Address Register 2
#define	REG_PAR3	0x14	// Offset, Physical Address Register 3
#define	REG_PAR4	0x15	// Offset, Physical Address Register 4
#define	REG_PAR5	0x16	// Offset, Physical Address Register 5

#define	REG_MAR0	0x18	// Offset, Multicast Address Register 0
#define	REG_MAR1	0x19	// Offset, Multicast Address Register 1
#define	REG_MAR2	0x1A	// Offset, Multicast Address Register 2
#define	REG_MAR3	0x1B	// Offset, Multicast Address Register 3
#define	REG_MAR4	0x1C	// Offset, Multicast Address Register 4
#define	REG_MAR5	0x1D	// Offset, Multicast Address Register 5
#define	REG_MAR6	0x1E	// Offset, Multicast Address Register 6
#define	REG_MAR7	0x1F	// Offset, Multicast Address Register 7



//////////////////////////////////////////////////////////////////////////////
// Offset 1Fh (NIC offset 0Fh): MANCH - Status read-back of 10BaseT LED
//                                      drivers.
// Read  page 3
// Write page 3

#define	REG_MANCH	0x01F	// Register Offset

#define	MANCH_TLED		0x01	// Transmit LED
#define	MANCH_RLED		0x02	// Receive LED
#define	MANCH_LLED		0x04	// Link Status LED
#define	MANCH_PLED		0x08	// TPRX Polarity readback
#define	MANCH_ENAPOL	0x10	// Automatic polarity correct
//#define	MANCH_xxx		0x20	// Not Used
#define	MANCH_SEL		0x40	//	Select AUI idle state
#define	MANCH_MANDIS	0x80	//	Disable Manchester encoder/decoder






