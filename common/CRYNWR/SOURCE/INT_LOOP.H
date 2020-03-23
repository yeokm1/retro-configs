#define	MAX_LPBK_TX_RETRY	5
#define	MAX_TRY_AGAIN_COUNT	10
#define	TRUE	   		1
#define	FALSE	   		0

#define	EXPECTED_CRC_ERR	0x101	// Loopback test expected CRC error, did not occur.
#define	ACPT_MANUAL_ERR		0x102	// Manual CRC test failed.	
#define	ACPT_BAD_ADDR_ERR	0x103	// Loopback test accepted a bad address?
#define	DISABLED_RAM_ERR	0x104	// Ram was supposed to be enabled for a given test,
#define	NO_XMIT_RESPONSE	0x105	// No response from transmitter.
#define	FIFO_ERR		0x106	// Error in FIFO data.
#define	REJ_MANUAL_ERR		0x107	// ?
#define	BAD_PKT_ERR		0x108	// ?
#define	INT_LOOP_DELAY		36		// 2 seconds ÷ 36 ticks.
#define	LPBK_MODE0 		0x000
#define	LPBK_MODE1 		0x002
#define	LPBK_MODE2 		0x004
#define	LPBK_MODE3 		0x006
