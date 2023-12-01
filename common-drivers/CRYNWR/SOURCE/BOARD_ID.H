/****************************************************************************
*
*       The information contained in this file is confidential and 
*       proprietary to Standard Microsystems Corporation.  No part
*       of this file may be reproduced or distributed, in any form
*       or by any means for any purpose, without the express written
*       permission of Standard Microsystems Corporation.
*
*       
* File:         board_id.h
*
* Description:  BOARD ID DEFINITIONS
*
*       32 Bits of information are returned by 'GetBoardID ()'.
*
*       The low order 16 bits correspond to the Feature Bits which make
*       up a unique ID for a given class of boards.
*
*       e.g. STARLAN MEDIA, INTERFACE_CHIP, MICROCHANNEL
*
*       note: Board ID should be ANDed with the STATIC_ID_MASK
*             before comparing to a specific board ID.
*
*
*       The high order 16 bits correspond to the Extra Bits which do not
*       change the boards ID.
*
*       e.g. INTERFACE_584_CHIP, 16 BIT SLOT, ALTERNATE IRQ
*
*
*********************
** Revision History *
*********************
*
* $Log:   G:\sweng\src\lmcom\vcs\board_id.hv  $
 * 
 *    Rev 1.16   17 Oct 1994 11:26:24   WOOD_R
*
* Changes:	Added equate CHIP_REV_MASK for designating a Chip Revision
*     		level.  This was done for the 825XE chip.  This may be used
*		      in the future by other chips.
*
*
;+!/? **********************************************************************/


#define	STARLAN_MEDIA		0x00000001	/* StarLAN */
#define	ETHERNET_MEDIA		0x00000002	/* AUI & BNC */
#define	TWISTED_PAIR_MEDIA	0x00000003	/* AUI & UTP */
#define	EW_MEDIA		0x00000004	/* AUI, BNC, and UTP */
#define	TOKEN_MEDIA		0x00000005	/* Token Ring Media */
#define	UTP2_MEDIA		0x00000006	/* Adapter with 2 Ethernet UTP ports */
#define	MICROCHANNEL		0x00000008	/* MicroChannel Adapter */
#define	INTERFACE_CHIP		0x00000010	/* Soft Config Adapter */
#define	ADVANCED_FEATURES	0x00000020	/* used to be INTELLIGENT */
#define	BOARD_16BIT		0x00000040	/* 16 bit capability */
#define	PAGED_RAM		0x00000080	/* Adapter has paged RAM */
#define	PAGED_ROM		0x00000100	/* Adapter has paged ROM */
#define	MEDIA_MASK		0x00000007	/* Isolates Media Type */
#define	PCM_ADAPTER		0x00000200	/* PCMCIA adapter */
#define	LITE_VERSION		0x00000400	/* Reduced feature adapter, I.E. Tiger */
#define	NIC_SUPERSET		0x00000800	// NIC is Superset of 790
#define	NEC_BUS			0x00001000	// Adapter is a PC-98 Bus type.
#define	HMI_ADAPTER		0x00002000	// Adapter has integral hub.

#define	NO_AUI_MEDIA	0x00004000	// Adapter is w/o an AUI connector. Valid
                                    // only for NIC Superset. 
#define	SEE_BOARD_ID2	0x00008000  //	Use board_id2 info

#if defined(ASM_TYPE)

#define	RAM_SIZE_UNKNOWN	0x0000	/* 000 => Unknown RAM Size */
#define	RAM_SIZE_RESERVED_1	0x0001	/* 001 => Reserved */
#define	RAM_SIZE_8K		0x0002	/* 010 => 8k RAM */
#define	RAM_SIZE_16K		0x0003	/* 011 => 16k RAM */
#define	RAM_SIZE_32K		0x0004	/* 100 => 32k RAM */
#define	RAM_SIZE_64K		0x0005	/* 101 => 64k RAM */ 
#define	RAM_SIZE_RESERVED_6	0x0006	/* 110 => Reserved */ 
#define	RAM_SIZE_RESERVED_7	0x0007	/* 111 => Reserved */ 
#define	SLOT_16BIT		0x0008	/* 16 bit board - 16 bit slot */
#define	NIC_690_BIT		0x0010	/* NIC is 690 */
#define	ALTERNATE_IRQ_BIT	0x0020	/* Alternate IRQ is used */
#define	INTERFACE_5X3_CHIP	0x0000	/* 0000 = 583 or 593 chips */
#define	INTERFACE_584_CHIP	0x0040	/* 0001 = 584 chip */
#define	INTERFACE_594_CHIP	0x0080	/* 0010 = 594 chip */
#define	INTERFACE_585_CHIP	0x0100	// 585 BIC Chip
#define	RAM_SIZE_MASK		0x0007	/* Isolates RAM Size */
#define	INTERFACE_CHIP_MASK	0x03C0	/* Isolates Intfc Chip Type */
#define	NIC_825_BIT		0x0400	/* NIC is 825 Token Ring */
#define	NIC_790_BIT		0x0800	// NIC is 790 BIC/NIC Chip

#define	CHIP_REV_MASK		0x3000		/* Use two bottom bits of the */
													/* upper nibble for chip rev. */
#define	SEE_EXTRA_BITS2	0x8000		/* Use extra_bits2 info */



#else

#define	RAM_SIZE_UNKNOWN	0x00000000	/* 000 => Unknown RAM Size */
#define	RAM_SIZE_RESERVED_1	0x00010000	/* 001 => Reserved */
#define	RAM_SIZE_8K		0x00020000	/* 010 => 8k RAM */
#define	RAM_SIZE_16K		0x00030000	/* 011 => 16k RAM */
#define	RAM_SIZE_32K		0x00040000	/* 100 => 32k RAM */
#define	RAM_SIZE_64K		0x00050000	/* 101 => 64k RAM */ 
#define	RAM_SIZE_RESERVED_6	0x00060000	/* 110 => Reserved */ 
#define	RAM_SIZE_RESERVED_7	0x00070000	/* 111 => Reserved */ 
#define	SLOT_16BIT		0x00080000	/* 16 bit board - 16 bit slot */
#define	NIC_690_BIT		0x00100000	/* NIC is 690 */
#define	ALTERNATE_IRQ_BIT	0x00200000	/* Alternate IRQ is used */
#define	INTERFACE_5X3_CHIP	0x00000000	/* 0000 = 583 or 593 chips */
#define	INTERFACE_584_CHIP	0x00400000	/* 0001 = 584 chip */
#define	INTERFACE_594_CHIP	0x00800000	/* 0010 = 594 chip */
#define	INTERFACE_585_CHIP	0x01000000	// 585 BIC Chip
#define	RAM_SIZE_MASK		0x00070000	/* Isolates RAM Size */
#define	STATIC_ID_MASK		0x0000FFFF	/* Isolates Board ID */
#define	INTERFACE_CHIP_MASK	0x03C00000	/* Isolates Intfc Chip Type */
#define	NIC_825_BIT		0x04000000	/* NIC is 825 Token Ring */
#define	NIC_790_BIT		0x08000000	/* NIC is 790 BIC/NIC Chip */

#define	CHIP_REV_MASK		0x30000000	/* Use two bottom bits of the */
													/* upper nibble for chip rev. */


#define	SEE_EXTRA_BITS2	0x80000000	// Use extra_bits2 info

#endif

/* Word definitions for board types */
#define	WD8003E		ETHERNET_MEDIA
#define	WD8003EBT	WD8003E		/* functionally identical to WD8003E */
#define	WD8003S		STARLAN_MEDIA
#define	WD8003SH	WD8003S		/* functionally identical to WD8003S */
#define	WD8003WT	TWISTED_PAIR_MEDIA
#define	WD8003W		(TWISTED_PAIR_MEDIA | INTERFACE_CHIP)
#define	WD8003EB	(ETHERNET_MEDIA | INTERFACE_CHIP)
#define	WD8003EP	WD8003EB	/* with INTERFACE_584_CHIP */
#define	WD8003EW	(EW_MEDIA | INTERFACE_CHIP)
#define	WD8003ETA	(ETHERNET_MEDIA | MICROCHANNEL)
#define	WD8003STA	(STARLAN_MEDIA | MICROCHANNEL)
#define	WD8003EA	(ETHERNET_MEDIA | MICROCHANNEL | INTERFACE_CHIP)
#define	WD8003EPA	WD8003EA	/* with INTERFACE_594_CHIP */
#define	WD8003SHA	(STARLAN_MEDIA | MICROCHANNEL | INTERFACE_CHIP)
#define	WD8003WA	(TWISTED_PAIR_MEDIA | MICROCHANNEL | INTERFACE_CHIP)
#define	WD8003WPA	WD8003WA	/* with INTERFACE_594_CHIP */
#define	WD8013EBT	(ETHERNET_MEDIA | BOARD_16BIT)
#define	WD8013EB	(ETHERNET_MEDIA | BOARD_16BIT | INTERFACE_CHIP)
#define	WD8013W		(TWISTED_PAIR_MEDIA | BOARD_16BIT | INTERFACE_CHIP)
#define	WD8013EW	(EW_MEDIA | BOARD_16BIT | INTERFACE_CHIP)
#define WD8013EWC	(WD8013EW | ADVANCED_FEATURES)
#define WD8013WC	(WD8013W | ADVANCED_FEATURES)
#define WD8013EPC	(WD8013EB | ADVANCED_FEATURES)
#define WD8003WC	(WD8003W | ADVANCED_FEATURES)
#define	WD8003EPC	(WD8003EP | ADVANCED_FEATURES)
#define	WD8115TA	(TOKEN_MEDIA | MICROCHANNEL | INTERFACE_CHIP | PAGED_RAM)
#define	WD8115T		(TOKEN_MEDIA | INTERFACE_CHIP | BOARD_16BIT | PAGED_RAM)
#define	WD8208T		(WD8003WC | PAGED_ROM | PAGED_RAM)
#define	WD8208		(WD8003EPC | PAGED_ROM | PAGED_RAM)
#define	WD8208C		(EW_MEDIA | INTERFACE_CHIP | ADVANCED_FEATURES | PAGED_ROM | PAGED_RAM)
#define	WD8216T		(WD8013WC | PAGED_ROM | PAGED_RAM)
#define	WD8216		(WD8013EPC | PAGED_ROM | PAGED_RAM)
#define	WD8216C		(WD8013EWC | PAGED_ROM | PAGED_RAM)
#define	PCM10BT		(TWISTED_PAIR_MEDIA | PCM_ADAPTER | PAGED_RAM | ADVANCED_FEATURES)
#define	WD8216L		(WD8216 | LITE_VERSION)
#define	WD8216LT	(WD8216T | LITE_VERSION)
#define	WD8216LC	(WD8216C | LITE_VERSION)
#define	WD8216N		(WD8216 | NEC_BUS)
#define	WD8216TN	(WD8216T | NEC_BUS)
#define	WD8216CN	(WD8216C | NEC_BUS)
#define	WD8216TH	(WD8216T | HMI_ADAPTER)
#define	WD8216LTH	(WD8216LT | HMI_ADAPTER)
#define	WD8216T2	((WD8216T & ~MEDIA_MASK) | UTP2_MEDIA)

#define	WD8416T		(WD8216T | NIC_SUPERSET | NO_AUI_MEDIA) // UTP
#define	WD8416BT		(WD8216C | NIC_SUPERSET | NO_AUI_MEDIA) // BNC/UTP
#define	WD8416B		(WD8216  | NIC_SUPERSET | NO_AUI_MEDIA) // BNC
#define	WD8416BTA	(WD8216C | NIC_SUPERSET)					 // BNC/UTP/AUI
#define	WD8416TA		(WD8216T | NIC_SUPERSET)					 // UTP/AUI
#define	WD8416BA		(WD8216  | NIC_SUPERSET)					 // BNC/AUI

#define	WD8414T		(WD8416T   | LITE_VERSION) // UTP
#define	WD8414BT		(WD8416BT  | LITE_VERSION) // BNC/UTP
#define	WD8414B		(WD8416B   | LITE_VERSION) // BNC
#define	WD8414BTA	(WD8416BTA | LITE_VERSION) // BNC/UTP/AUI
#define	WD8414TA		(WD8416TA  | LITE_VERSION) // UTP/AUI
#define	WD8414BA		(WD8416BA  | LITE_VERSION) // BNC/AUI






/******************************************************************************

Declaration for the Routine Provided in the 'Board ID' Library.

******************************************************************************/
#if M_XENIX || AT286 || AT386 || M_UNIX
unsigned	long	GetBoardID ();
#else
unsigned	long	GetBoardID (unsigned int, int);
#endif

