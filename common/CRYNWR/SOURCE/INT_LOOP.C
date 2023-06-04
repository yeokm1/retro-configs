
char *GetverVersionString[] = {"@(#) SMC Ethernet XLMAC Module INT_LOOP.C v1.17\0$"};

/****************************************************************************
This module performs the internal loopback test
	Goal:	for each mode of internal loopback
		(one mode for looping around each chip, i.e. 8390, 8391, 8392 
		or 690, 691, 692)
		1) test the integrity of the data path and CRC generation logic
			a) send pkt with auto CRC
			b) compare data in fifo with what we know it should be 
		2) test the CRC recognition logic
			a) send pkt with manual CRC (a good one)
				chip should have no CRC error
			b) send pkt with manual CRC (a bad one)
				chip should have a CRC error
		3) test the address recognition logic
			a) alter the chips LAN address
			b) send pkt with manual CRC (a bad one)
				chip should have no CRC error because
				chip should reject pkt due to addr mismatch 
	Additional Info:
		the board is loaded with the LAN address '00 00 C0 00 00 00'
		this is so that a hard coded CRC may be used as apposed to
		having a CRC generation algorithm in this code

		all loopback packet data is '00'
		this is just for simplicity...the effectiveness of the test
			is not diminished

		this module includes special code for Starlan products and
		also for Microchannel products

	Note:	this code is specific for use in Intel type processors

****************************************************************************/
#include	"int_loop.h"
#include	"bicnic.h"

//#include	"lmt_bic.h"
//#include	"lmt_nic.h"
#include	"lmstruct.h"
#include	"board_id.h"
#include	"eth_eisa.h"

//#define		REG_OFFSET		0x3000

/* Definitions of global variables FCH 10-07-92 */

AdapterStructure far *	AdStr;

unsigned long	crc_errors;

int				TCR_value,
				manual_crc[4] = {0x1E, 0xD0, 0x21, 0x2F},
				fifo_hold[8],
				byp_index = FALSE,
				auto_crc = TRUE,
				loopback_mode = 0,
				fifo_depth = 8,
				looping_mode = 0,
				installed_fifo_depth= 8;

unsigned int	tpsr_hold,
				tbcr0_hold,
				tbcr1_hold,
				size_hold,
				pstart_hold = 0x08,
				pstop_hold,
				rsr_hold,
				tsr_hold,
				isr_hold,
				imr_hold,
				rcr_hold,
				local_nxtpkt_ptr;

/* Definitions of function prototypes FCH 10-07-92 */

#ifdef   EZSTART
int internal_loopback (AdapterStructure far * pAdStr);
#else
int _loadds internal_loopback (AdapterStructure far *);
#endif
int		perform_int_loop(void);
unsigned	LM_Close_Adapter (AdapterStructure far *);
int		run_lpbk_test (void);
int		test_NIC_operation(void);
int		test_data_path (void);
int		test_crc_logic (void);
int		with_good_crc (void);
int		with_bad_crc (void);
int		test_addr_logic (void);
int		good_crc (void);
int		bad_crc (void);
int		mk_bad_addr (void);
int		fix_bad_addr (void);
int		lpbk_pkt_to_mem(void);
void	 clear_lpbk_ram (void);
int		raw_lpbk_pkt_to_mem (void);
int		initiate_lpbk_xmit (void);
int		lpbk_init_NIC(void);
int		verify_fifo_crc (void);
int		lpbk_check_crc_errors(void);
int		verify_lpbk_packet (void);
void	 start_NIC (void);
void	 stop_NIC (void);
//void	 check_16bit_access (void);
//void	 recheck_16bit_access (void);

extern void _outp (unsigned, int);
extern int	_inp (unsigned);
extern int	real_timable (void);
extern unsigned long	get_time (void);
extern void fake_tenth_second (void);
 
/******************************************************************************

this performs internal loopback for batch mode

******************************************************************************/
#ifdef   EZSTART
int internal_loopback (AdapterStructure far * pAdStr)
#else
int _loadds internal_loopback (AdapterStructure far * pAdStr)
#endif
{
	int	ret_code;
	AdStr = pAdStr;

	manual_crc[0] = 0x1E;
	manual_crc[1] = 0xD0;
	manual_crc[2] = 0x21;
	manual_crc[3] = 0x2F;

	byp_index = 0;			/* dont bypass errors */
	looping_mode = 0;
	ret_code = perform_int_loop();
//	LM_Close_Adapter (AdStr); /* temporarily comment out to avoid link problems MJS 02-17-93 */
	return (ret_code);
}

/****************************************************************************

this actually performs the internal loopback test

****************************************************************************/
int perform_int_loop()
{
	int ret_code;

	if ((looping_mode == 0) || (looping_mode == 1))
	{
		loopback_mode = 0;
		lpbk_init_NIC ();
		start_NIC ();
		loopback_mode = LPBK_MODE1;			/* loopback mode 1 */
		if (ret_code = run_lpbk_test ())
			return (ret_code);

	}
	if ((looping_mode == 0) || (looping_mode == 2))
	{
		loopback_mode = 0;
		lpbk_init_NIC ();
		start_NIC ();
		loopback_mode = LPBK_MODE2;			/* loopback mode 2 */
		if (ret_code = run_lpbk_test ())
			return (ret_code);
	}
	if ((looping_mode == 0) || (looping_mode == 3))
	{
		loopback_mode = 0;
		lpbk_init_NIC ();
		start_NIC ();
		loopback_mode = LPBK_MODE3;			/* loopback mode 3 */
		if (ret_code = run_lpbk_test ())
			return (ret_code);
	}
	return (SUCCESS);
}

/****************************************************************************


****************************************************************************/
int run_lpbk_test ()
{
	int	ret_code;

	ret_code = test_NIC_operation ();
	stop_NIC ();
	return (ret_code);
}

/******************************************************************************

this tests the chips' operation by:
	 1: send the packet with auto crc and verify received crc to the static crc
	 2: send the packet with manual crc and see if it is accepted
	 3: send the packet with altered manual crc and see if it is rejected

******************************************************************************/
int test_NIC_operation()
{
	int ret_code;

	fix_bad_addr();
	good_crc ();
	if (ret_code = test_data_path ())
		return (ret_code);
	if (ret_code = test_crc_logic ())
		return (ret_code);
	if (ret_code = test_addr_logic ())
		return (ret_code);
	fix_bad_addr ();
	good_crc ();
	return (SUCCESS);				/* show no error */
}

/********************************************

*********************************************/
int test_data_path ()
{
	int	again;
	int	ret_code;

	/* let the chip do the crc and verify the data and crc from the fifo */
	auto_crc = 1;				/* use the chips crc logic */

	lpbk_init_NIC ();

	if (ret_code = lpbk_pkt_to_mem ())
		return (ret_code);

	if (ret_code = initiate_lpbk_xmit ())	/* send and report errors */
		return (ret_code);

	if (AdStr->extra_info & (NIC_690_BIT | NIC_790_BIT))
	{
#if defined (UBIO)
#else
		if (AdStr->pc_bus != PCMCIA_BUS)
			check_16bit_access (AdStr);
#endif
		ret_code = verify_lpbk_packet ();
#if defined (UBIO)
#else
		if (AdStr->pc_bus != PCMCIA_BUS)
			recheck_16bit_access (AdStr);
#endif
	}
	else
	{
                if (lpbk_check_crc_errors())
                {
                    if (!(ret_code = verify_fifo_crc()))
                        return (SUCCESS);
                }
                else
                    ret_code = EXPECTED_CRC_ERR;
	}
	return (ret_code);
}

/********************************************

*********************************************/
int test_crc_logic ()
{
	int	ret_code;

	auto_crc = 0;				/* use manual crc generation */
	/* use manual crc to check the recognition logic */
	good_crc ();
	if (ret_code = with_good_crc ())
		return (ret_code);
	/* alter the crc and see if the chip rejects the packet */
	bad_crc ();
	if (ret_code = with_bad_crc ())
		return (ret_code);
	return (SUCCESS);
}

/********************************************

*********************************************/
int with_good_crc ()
{
	int	ret_code;

	lpbk_init_NIC ();
	if (ret_code = lpbk_pkt_to_mem ())
		return (ret_code);
	if (ret_code = initiate_lpbk_xmit ())
		return (ret_code);
	if (ret_code = lpbk_check_crc_errors())
		ret_code = REJ_MANUAL_ERR;
	return (ret_code);
}

/********************************************

*********************************************/
int with_bad_crc ()
{
	int	ret_code;

	lpbk_init_NIC ();
	if (ret_code = lpbk_pkt_to_mem ())
		return (ret_code);
	if (ret_code = initiate_lpbk_xmit ())
		return (ret_code);
	if (lpbk_check_crc_errors ())
		return (SUCCESS);
	else
		return (ACPT_MANUAL_ERR);
}

/********************************************

*********************************************/
int test_addr_logic ()
{
	int	again;
	int	ret_code;

	auto_crc = 0;				/* use manual crc generation */
	/* use bad crc, make a bad dest addr, and see if the crc err is seen */

	lpbk_init_NIC ();
	mk_bad_addr ();
	bad_crc ();
	if (ret_code = lpbk_pkt_to_mem ())
		return (ret_code);
	if (ret_code = initiate_lpbk_xmit ())	/* send and report errors */
		return (ret_code);
	if (lpbk_check_crc_errors())	/* should be no crc error */
		return (ACPT_BAD_ADDR_ERR);
	return (SUCCESS);
}

/********************************************

*********************************************/
int good_crc ()
{
	manual_crc[0] = 0x1E;
	return (SUCCESS);
}

/********************************************

*********************************************/
int bad_crc ()
{
	manual_crc[0] = 0xFF;
	return (SUCCESS);
}

/***********************************

************************************/
int mk_bad_addr ()
{
	unsigned char far *RamPtr;

	RamPtr = (unsigned char *)(AdStr->ram_access);

	if (AdStr->pc_bus == PCMCIA_BUS)
	{
		*(RamPtr + REG_CMD) = CMD_STA|CMD_RD2|CMD_PAGE1;	/* select page 1 */
		*(RamPtr + REG_PAR1) = 0xFF;							/* change address */
		*(RamPtr + REG_CMD) =	CMD_STA|CMD_RD2|CMD_PAGE0;		/* select page 0 */
	}
	else if (AdStr->pc_bus == EISA_BUS)
	{
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE1);		/* select page 1 */
		_outp (AdStr->io_base+EISA_790+REG_PAR1, 0xFF);		/* change address */
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE0);		/* select page 0 */
	}
	else
	{
		_outp (AdStr->io_base+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE1);		/* select page 1 */
		_outp (AdStr->io_base+REG_PAR1, 0xFF);		/* change address */
		_outp (AdStr->io_base+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE0);		/* select page 0 */
	}
	return (SUCCESS);
}

/***************************************

****************************************/
int fix_bad_addr ()
{
	unsigned char far *RamPtr;

	RamPtr = (unsigned char *)(AdStr->ram_access);

	if (AdStr->pc_bus == PCMCIA_BUS)
	{
		*(RamPtr + REG_CMD) = CMD_STA|CMD_RD2|CMD_PAGE1;	/* select page 1 */
		*(RamPtr + REG_PAR1) = 0x00;							/* change address */
		*(RamPtr + REG_CMD) =	CMD_STA|CMD_RD2|CMD_PAGE0;		/* select page 0 */
	}
	else if (AdStr->pc_bus == EISA_BUS)
	{
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE1);		/* select page 1 */
		_outp (AdStr->io_base+EISA_790+REG_PAR1, 0x00);		/* change address */
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE0);		/* select page 0 */
	}
	else
	{
		_outp (AdStr->io_base+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE1);		/* select page 1 */
		_outp (AdStr->io_base+REG_PAR1, 0x00);		/* change address */
		_outp (AdStr->io_base+REG_CMD, CMD_STA|CMD_RD2|CMD_PAGE0);		/* select page 0 */
	}
		return (SUCCESS);
}

/******************************************************************************

set up transmit buffer in RAM

******************************************************************************/
int lpbk_pkt_to_mem()
{
	int	ret_code;

#if defined (UBIO)
#else
	if (AdStr->pc_bus != PCMCIA_BUS)
		check_16bit_access (AdStr);
#endif

//	if (AdStr->pc_bus == EISA_BUS)
//	{
//		if (!(_inp (AdStr->io_base+EISA_INT) & EISA_MENB))
//			return (DISABLED_RAM_ERR);
//	}
//	else if (AdStr->pc_bus != PCMCIA_BUS)
//	{
//		if (AdStr->nic_type != NIC_790_CHIP)
//			if (!(_inp (AdStr->io_base+REG_MSR) & MSR_MENB))
//				return (DISABLED_RAM_ERR);
//	}

	ret_code = raw_lpbk_pkt_to_mem ();

#if defined (UBIO)
#else
	if (AdStr->pc_bus != PCMCIA_BUS)
		recheck_16bit_access (AdStr);
#endif

	return (ret_code);
}

/************************************************************************

************************************************************************/
void clear_lpbk_ram ()
{
	unsigned	int		count;
	int	far	*int_ptr;

	
//	if (AdStr->pc_bus != PCMCIA_BUS)
//	{
//		outp (AdStr->io_base+REG_MSR, (char)(AdStr->ram_base >> 13));
//		check_16bit_access (AdStr);
//	}

#if defined (UBIO)
	outp (AdStr->io_base+REG_IOPA, 0);
	outp (AdStr->io_base+REG_IOPA, 0);	// Set IO pipe address to 0.
	for (count = 0; count < 0x800; count++)
		outpw (AdStr->io_base+REG_IOPD, 0xFFFF);
#else
	int_ptr = (int far *) AdStr->ram_access;

	if (AdStr->pc_bus == PCMCIA_BUS)
		int_ptr += SHMEM_NIC_OFFSET/2;	// Stupid C compiler thinks I
						// want to add SHMEM_NIC_OFFSET
						// ints instead of bytes, so
						// divide by 2.

	for (count = 0; count < 0x800; count++)
		*int_ptr++ = 0xFFFF;

	if (AdStr->pc_bus != PCMCIA_BUS)
		recheck_16bit_access (AdStr);
#endif
}

/************************************************************************

************************************************************************/
int raw_lpbk_pkt_to_mem ()
{
	int		count;
	int	far	*int_ptr;

#if defined (UBIO)

	outp (AdStr->io_base+REG_IOPA, 0);
	outp (AdStr->io_base+REG_IOPA, 0);	// Set IO pipe address to 0.
	for (count = 0; count < 2; count++)
	{
		outpw (AdStr->io_base+REG_IOPD, 0);
		outpw (AdStr->io_base+REG_IOPD, 0x00C0);
		outpw (AdStr->io_base+REG_IOPD, 0);
	}
	for (count = 0; count < 24; count++)
		outpw (AdStr->io_base+REG_IOPD, 0);

	if (auto_crc)
		count = 60;				/* dont count crc */
	else
	{
		for (count = 0; count < 2; count++)
			outpw (AdStr->io_base+REG_IOPD, (manual_crc[count*2] | (manual_crc[count*2+1] << 8)));
		count = 64;
	}
#else
	if ( ((AdStr->board_id & MICROCHANNEL) || (AdStr->extra_info & SLOT_16BIT))
		&& (!(AdStr->extra_info & (NIC_690_BIT | NIC_790_BIT))) )
	{
		int_ptr = (int far *) AdStr->ram_access;
		for (count = 0; count < 2; count++)
		{
			*int_ptr++ = 0;
			*int_ptr++ = 0;
			*int_ptr++ = (0xC0 << 8);
			*int_ptr++ = 0;
			*int_ptr++ = 0;
			*int_ptr++ = 0;
		}
		for (count = 0; count < 48; count++)
			*int_ptr++ = 0;
		if (auto_crc)
			count = 120;		/* dont count crc */
		else
		{
			for (count = 0; count < 4; count++)
				*int_ptr++ = (manual_crc[count] << 8);
			count = 128;
		}
	}
	else
	{
		int_ptr = (int far *) AdStr->ram_access;

		if (AdStr->pc_bus == PCMCIA_BUS)
			int_ptr += SHMEM_NIC_OFFSET/2;

		for (count = 0; count < 2; count++)
		{
			*int_ptr++ = 0;
			*int_ptr++ = 0x00C0;
			*int_ptr++ = 0;
		}
		for (count = 0; count < 24; count++)
				*int_ptr++ = 0;
		if (auto_crc)
			count = 60;				/* dont count crc */
		else
		{
			for (count = 0; count < 2; count++)
				*int_ptr++ = (manual_crc[count*2] | (manual_crc[count*2+1] << 8));
			count = 64;
		}
	}
#endif
	tbcr1_hold = count >> 8;			/* upper byte of count */
	tbcr0_hold	= count & 0xff;			/* lower byte of count */

	return (SUCCESS);
}

/************************************************************************

************************************************************************/
int initiate_lpbk_xmit ()
{
	unsigned	i;
	unsigned	long	start_time;

	unsigned char far *RamPtr;

	RamPtr = (unsigned char *)(AdStr->ram_access);

	if (AdStr->pc_bus == PCMCIA_BUS)
	{
		*(RamPtr + REG_CMD) = CMD_STA|CMD_PAGE0|CMD_RD2;		/* sel page 0	& start NIC */
		*(RamPtr + REG_TPSR) = tpsr_hold;		/* xmit pg strt at 0 of RAM */
		*(RamPtr + REG_TBCR1) = tbcr1_hold;		/* upper byte of count */
		*(RamPtr + REG_TBCR0) = tbcr0_hold;		/* lower byte of count */
		*(RamPtr + REG_CMD) = CMD_TXP|CMD_RD2|CMD_STA;		/* start transmission */

		start_time = get_time ();
		while (get_time () < (start_time + INT_LOOP_DELAY))
		{
			isr_hold = *(RamPtr + REG_ISR);
			if (isr_hold & ISR_PTX)
				break;
		}
		if (!(isr_hold & ISR_PTX))
			return (NO_XMIT_RESPONSE);
		for (i = 0; i < 8; i++)
			fifo_hold[i] = *(RamPtr + REG_FIFO);

		isr_hold = *(RamPtr + REG_ISR);
		rsr_hold = *(RamPtr + REG_RSR);
		tsr_hold = *(RamPtr + REG_TSR);
		*(RamPtr + REG_ISR) = isr_hold;		/* undo int status */
	}
	else if (AdStr->pc_bus == EISA_BUS)
	{	
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STA|CMD_PAGE0|CMD_RD2);		/* sel page 0	& start NIC */
		_outp (AdStr->io_base+EISA_790+REG_TPSR, tpsr_hold);		/* xmit pg strt at 0 of RAM */
		_outp (AdStr->io_base+EISA_790+REG_TPSRL, 0);      		/* xmit pg strt at 0 of RAM */
		_outp (AdStr->io_base+EISA_790+REG_TBCR1, tbcr1_hold);		/* upper byte of count */
		_outp (AdStr->io_base+EISA_790+REG_TBCR0, tbcr0_hold);		/* lower byte of count */
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_TXP|CMD_RD2|CMD_STA);		/* start transmission */
	
			if (real_timable ())
			{
				start_time = get_time ();
				while (get_time () < (start_time + INT_LOOP_DELAY))
				{
					if ((_inp (AdStr->io_base+EISA_790+REG_ISR) & ISR_PTX))
						break;
				}
			}
			else
			{
			for (i = 0; i < 30; i++)
				{
					fake_tenth_second ();
					if ((_inp (AdStr->io_base+EISA_790+REG_ISR) & ISR_PTX))
						break;
				}
			}
		isr_hold = _inp (AdStr->io_base+EISA_790+REG_ISR);
		if (!(isr_hold & ISR_PTX))
			return (NO_XMIT_RESPONSE);
		for (i = 0; i < 8; i++)
			fifo_hold[i] = _inp (AdStr->io_base+EISA_790+REG_FIFO);
		isr_hold = _inp (AdStr->io_base+EISA_790+REG_ISR);
		rsr_hold = _inp (AdStr->io_base+EISA_790+REG_RSR);
		tsr_hold = _inp (AdStr->io_base+EISA_790+REG_TSR);
		_outp (AdStr->io_base+EISA_790+REG_ISR, isr_hold);		/* undo int status */
	}
	else
	{	
		_outp (AdStr->io_base+REG_CMD, CMD_STA|CMD_PAGE0|CMD_RD2);		/* sel page 0	& start NIC */
		_outp (AdStr->io_base+REG_TPSR, tpsr_hold);		/* xmit pg strt at 0 of RAM */
		_outp (AdStr->io_base+REG_TBCR1, tbcr1_hold);		/* upper byte of count */
		_outp (AdStr->io_base+REG_TBCR0, tbcr0_hold);		/* lower byte of count */
		_outp (AdStr->io_base+REG_CMD, CMD_TXP|CMD_RD2|CMD_STA);		/* start transmission */
	
			if (real_timable ())
			{
				start_time = get_time ();
				while (get_time () < (start_time + INT_LOOP_DELAY))
				{
					if ((_inp (AdStr->io_base+REG_ISR) & ISR_PTX))
						break;
				}
			}
			else
			{
			for (i = 0; i < 30; i++)
				{
					fake_tenth_second ();
					if ((_inp (AdStr->io_base+REG_ISR) & ISR_PTX))
						break;
				}
			}
		isr_hold = _inp (AdStr->io_base+REG_ISR);
		if (!(isr_hold & ISR_PTX))
			return (NO_XMIT_RESPONSE);
		for (i = 0; i < 8; i++)
			fifo_hold[i] = _inp (AdStr->io_base+REG_FIFO);
		isr_hold = _inp (AdStr->io_base+REG_ISR);
		rsr_hold = _inp (AdStr->io_base+REG_RSR);
		tsr_hold = _inp (AdStr->io_base+REG_TSR);
		_outp (AdStr->io_base+REG_ISR, isr_hold);		/* undo int status */
	}
	return (SUCCESS);
}

/***************************************************************************

****************************************************************************/
int lpbk_init_NIC()
{
	unsigned int	i;			/* general purpose counter */
	int		count;
	int		i_pstart_hold;
	unsigned char far *RamPtr;

	RamPtr = (unsigned char *)(AdStr->ram_access);

	clear_lpbk_ram ();

	if (AdStr->pc_bus == PCMCIA_BUS)
	{
		tpsr_hold = SHMEM_NIC_OFFSET >> 8;
		i_pstart_hold = tpsr_hold + 0x08;
		pstop_hold = (SHMEM_NIC_OFFSET >> 8)+(((int)AdStr->ram_usable << 2) & 0xFF);
		local_nxtpkt_ptr = i_pstart_hold + 01;		/* for program to know where next is */
		*(RamPtr + REG_CMD) = CMD_STP|CMD_RD2|CMD_PAGE0;
		*(RamPtr + REG_RBCR0) = 0;		/* clear remote byte count */
		*(RamPtr + REG_RBCR1) = 0;

		
		for (count = 0; count < 0xFFFF; count++)
			if ((*(RamPtr + REG_ISR) & ISR_RST))
				break;

//		while (! (*(RamPtr + REG_ISR) & ISR_RST) )
//		{
//		}	/* Poll Reset Flag */

		*(RamPtr + REG_DCR) = ((fifo_depth & 0x0C) << 3) | DCR_WTS;
		*(RamPtr + REG_RCR) = 0;
		TCR_value = loopback_mode;
		if (!auto_crc)
			TCR_value |= TCR_CRC;

		*(RamPtr + REG_TCR) = TCR_value;		/* set loopback mode */
		*(RamPtr + REG_PSTART) = i_pstart_hold;	/* rcv ring strts 2k into RAM */
		*(RamPtr + REG_PSTOP) = pstop_hold;		/* stop at last RAM loc */
		*(RamPtr + REG_BNRY) = i_pstart_hold;	/* init to = REG_PSTART */
		*(RamPtr + REG_ISR) = 0xFF;		/* clear all int status bits */
		*(RamPtr + REG_IMR) = 0;		/* no interrupts yet */
		*(RamPtr + REG_CMD) = CMD_STP|CMD_RD2|CMD_PAGE1;	/* maintain rst | select page 1 */
		*(RamPtr + REG_PAR0) = 0;		/* load physical address */
		*(RamPtr + REG_PAR1) = 0;		/* load physical address */
		*(RamPtr + REG_PAR2) = 0xC0;		/* load physical address */
		for (i = 3; i < 6; i++)
			*(RamPtr + REG_PAR0 + i) = 0;	/* load physical address */
		for (i = 0; i < 8; i++)
			*(RamPtr + REG_MAR0 + i) = 0;	/* multicast bits are zero */
		*(RamPtr + REG_CURR) = local_nxtpkt_ptr;	/* init to = REG_PSTART */
		*(RamPtr + REG_CMD) =  CMD_STP|CMD_PAGE0|CMD_RD2;
	}
	else if (AdStr->pc_bus == EISA_BUS)
	{
		tpsr_hold = 0;
		i_pstart_hold = 0x08;
		pstop_hold = ((int)AdStr->ram_usable << 2) & 0xFF;
		local_nxtpkt_ptr = i_pstart_hold + 01;		/* for program to know where next is */
		_outp (AdStr->io_base+EISA_RAM, (_inp (AdStr->io_base+EISA_RAM) & 0xFC)); /* Set RAM page to 0 */
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STP|CMD_RD2|CMD_PAGE0);
		_outp (AdStr->io_base+EISA_790+REG_RBCR0, 0);		/* clear remote byte count */
		_outp (AdStr->io_base+EISA_790+REG_RBCR1, 0);
		count = 0;
		while ((!(_inp (AdStr->io_base+EISA_790+REG_ISR) & ISR_RST)) && (count < 0x1000))
			count++;
		_outp (AdStr->io_base+EISA_790+REG_DCR, ((fifo_depth & 0x0C) << 3) | 0x01);

		_outp (AdStr->io_base+EISA_790+REG_RCR, 0);
		TCR_value = loopback_mode;

		if (!auto_crc)
			TCR_value |= TCR_CRC;

		_outp (AdStr->io_base+EISA_790+REG_TCR, TCR_value);		/* set loopback mode */
		_outp (AdStr->io_base+EISA_790+REG_PSTART, i_pstart_hold);/* rcv ring strts 2k into RAM */
		_outp (AdStr->io_base+EISA_790+REG_PSTOP, pstop_hold);	/* stop at last RAM loc */
		_outp (AdStr->io_base+EISA_790+REG_BNRY, i_pstart_hold);	/* init to = REG_PSTART */
		_outp (AdStr->io_base+EISA_790+REG_ISR, 0xFF);		/* clear all int status bits */
		_outp (AdStr->io_base+EISA_790+REG_IMR, 0);		/* no interrupts yet */
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STP|CMD_RD2|CMD_PAGE1);	/* maintain rst | select page 1 */
		_outp (AdStr->io_base+EISA_790+REG_PAR0, 0);		/* load physical address */
		_outp (AdStr->io_base+EISA_790+REG_PAR1, 0);		/* load physical address */
		_outp (AdStr->io_base+EISA_790+REG_PAR2, 0xC0);		/* load physical address */
		for (i = 3; i < 6; i++)
			_outp (AdStr->io_base+EISA_790+REG_PAR0+i, 0);	/* load physical address */
		for (i = 0; i < 8; i++)
		_outp (AdStr->io_base+EISA_790+REG_MAR0+i, 0);	/* multicast bits are zero */
		_outp (AdStr->io_base+EISA_790+REG_CURR, local_nxtpkt_ptr);	/* init to = REG_PSTART */
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STP|CMD_PAGE0|CMD_RD2);
	}
	else
	{
		tpsr_hold = 0;
		i_pstart_hold = 0x08;
		pstop_hold = ((int)AdStr->ram_usable << 2) & 0xFF;
		local_nxtpkt_ptr = i_pstart_hold + 01;		/* for program to know where next is */
		_outp (AdStr->io_base+REG_CMD, CMD_STP|CMD_RD2|CMD_PAGE0);
		_outp (AdStr->io_base+REG_RBCR0, 0);		/* clear remote byte count */
		_outp (AdStr->io_base+REG_RBCR1, 0);
		count = 0;
		while ((!(_inp (AdStr->io_base+REG_ISR) & ISR_RST)) && (count < 0x1000))
			count++;

		if ((AdStr->extra_info & SLOT_16BIT) || (AdStr->board_id & MICROCHANNEL))
			_outp (AdStr->io_base+REG_DCR, ((fifo_depth & 0x0C) << 3)|DCR_WTS);

		else if ((AdStr->nic_type == NIC_790_CHIP) && (AdStr->board_id & BOARD_16BIT))
			_outp (AdStr->io_base+REG_DCR, ((fifo_depth & 0x0C) << 3)|DCR_WTS);
		else
		 	_outp (AdStr->io_base+REG_DCR, ((fifo_depth & 0x0C) << 3));

		_outp (AdStr->io_base+REG_RCR, 0);
		TCR_value = loopback_mode;

		if (!auto_crc)
			TCR_value |= TCR_CRC;

		_outp (AdStr->io_base+REG_TCR, TCR_value);		/* set loopback mode */
		_outp (AdStr->io_base+REG_PSTART, i_pstart_hold);/* rcv ring strts 2k into RAM */
		_outp (AdStr->io_base+REG_PSTOP, pstop_hold);	/* stop at last RAM loc */
		_outp (AdStr->io_base+REG_BNRY, i_pstart_hold);	/* init to = REG_PSTART */
		_outp (AdStr->io_base+REG_ISR, 0xFF);		/* clear all int status bits */
		_outp (AdStr->io_base+REG_IMR, 0);		/* no interrupts yet */
		_outp (AdStr->io_base+REG_CMD, CMD_STP|CMD_RD2|CMD_PAGE1);	/* maintain rst | select page 1 */
		_outp (AdStr->io_base+REG_PAR0, 0);		/* load physical address */
		_outp (AdStr->io_base+REG_PAR1, 0);		/* load physical address */
		_outp (AdStr->io_base+REG_PAR2, 0xC0);		/* load physical address */
		for (i = 3; i < 6; i++)
			_outp (AdStr->io_base+REG_PAR0+i, 0);	/* load physical address */
		for (i = 0; i < 8; i++)
		_outp (AdStr->io_base+REG_MAR0+i, 0);	/* multicast bits are zero */
		_outp (AdStr->io_base+REG_CURR, local_nxtpkt_ptr);	/* init to = REG_PSTART */
		_outp (AdStr->io_base+REG_CMD, CMD_STP|CMD_PAGE0|CMD_RD2);
#if defined (UBIO)
		_outp (AdStr->io_base+REG_INTCR, (_inp (AdStr->io_base+REG_INTCR)|INTCR_IOPE));
#endif
	}
	return (SUCCESS);
}

void start_NIC ()
{
	unsigned char far *RamPtr;

	RamPtr = (unsigned char *)(AdStr->ram_access);

	if (AdStr->pc_bus == PCMCIA_BUS)
	{
		*(RamPtr + REG_CMD) = CMD_STA|CMD_PAGE0|CMD_RD2;
		*(RamPtr + REG_MSR) |= 0x02;
	}
	else if (AdStr->pc_bus == EISA_BUS)
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STA|CMD_PAGE0|CMD_RD2);
	else
		_outp (AdStr->io_base+REG_CMD, CMD_STA|CMD_PAGE0|CMD_RD2);
}

void stop_NIC ()
{
	unsigned char far *RamPtr;

	RamPtr = (unsigned char *)(AdStr->ram_access);

	if (AdStr->pc_bus == PCMCIA_BUS)
	{
		*(RamPtr + REG_CMD) = CMD_STP|CMD_PAGE0|CMD_RD2;
		*(RamPtr + REG_MSR) &= 0x04;
	}
   else if (AdStr->pc_bus == EISA_BUS)
		_outp (AdStr->io_base+EISA_790+REG_CMD, CMD_STP|CMD_PAGE0|CMD_RD2);
	else
		_outp (AdStr->io_base+REG_CMD, CMD_STP|CMD_PAGE0|CMD_RD2);
}

/********************************

********************************/
int verify_fifo_crc ()
{
	int	i;

	if (fifo_hold[3] != 0)				/* is it the same? */
		return (FIFO_ERR);			/* show error */
	for (i = 0; i < 4; i++)			/* next 4 are the crc */
	{
		if (fifo_hold[i+4] != manual_crc[i])	/* miscompare */
			return (FIFO_ERR);		/* show error */
	}
	return (SUCCESS);				/* show no error */
}


/********************************

********************************/

/*****************************************************************************

this identifies and reports crc errors for internal loopback

******************************************************************************/
int lpbk_check_crc_errors()
{
	if (rsr_hold & RSR_CRC)				/* crc error? */
	{
//fix to point to rx_crc_error pointer in adapter struct . . .
//		crc_errs += _inp (AdStr->io_base+CNTR1);
		return (1);				/* show error found */
	}
	return (SUCCESS);				/* show no error */
}

/*****************************************************************************

******************************************************************************/
int verify_lpbk_packet ()
{
	int		i;
	int far		*data_ptr;
	unsigned short	packet_offset, packet_data;

	packet_data = 0x0A01;

	packet_offset = (local_nxtpkt_ptr << 8);

	if (AdStr->pc_bus == PCMCIA_BUS)
		packet_data |= SHMEM_NIC_OFFSET;	// packet_data is the NIC Header.

#if defined (UBIO)
	_outp (AdStr->io_base+REG_IOPA, (char)packet_offset);
	_outp (AdStr->io_base+REG_IOPA, (char)(packet_offset >> 8));

	if ((inpw (AdStr->io_base+REG_IOPD)) != packet_data)		/* good receive and next pkt ptr */
		return (BAD_PKT_ERR);
	inpw (AdStr->io_base+REG_IOPD);	/* over receive header */
	for (i = 0; i < 2; i++)		/* two sets of 00 00 C0 00 00 00 */
	{
		if (inpw (AdStr->io_base+REG_IOPD) != 0x0000)
			return (BAD_PKT_ERR);
		if (inpw (AdStr->io_base+REG_IOPD) != 0x00C0)
			return (BAD_PKT_ERR);
		if (inpw (AdStr->io_base+REG_IOPD) != 0x0000)
			return (BAD_PKT_ERR);
	}
	for (i = 0; i < 24; i++)
	{
		if (inpw (AdStr->io_base+REG_IOPD) != 0x0000)
			return (BAD_PKT_ERR);
	}
	if ((inpw (AdStr->io_base+REG_IOPD)) != ((manual_crc[1] << 8) + manual_crc[0]))
		return (BAD_PKT_ERR);
	data_ptr++;
	if ((inpw (AdStr->io_base+REG_IOPD)) != ((manual_crc[3] << 8) + manual_crc[2]))
		return (BAD_PKT_ERR);
#else
	data_ptr = (int far *) (AdStr->ram_access + packet_offset);

	if (*data_ptr != packet_data)		/* good receive and next pkt ptr */
		return (BAD_PKT_ERR);
	data_ptr += 2;			/* over receive header */
	for (i = 0; i < 2; i++)		/* two sets of 00 00 C0 00 00 00 */
	{
		if (*data_ptr++ != 0x0000)
			return (BAD_PKT_ERR);
		if (*data_ptr++ != 0x00C0)
			return (BAD_PKT_ERR);
		if (*data_ptr++ != 0x0000)
			return (BAD_PKT_ERR);
	}
	for (i = 0; i < 24; i++)
	{
		if (*data_ptr != 0x0000)
			return (BAD_PKT_ERR);
		data_ptr++;
	}
	if (*data_ptr != ((manual_crc[1] << 8) + manual_crc[0]))
		return (BAD_PKT_ERR);
	data_ptr++;
	if (*data_ptr != ((manual_crc[3] << 8) + manual_crc[2]))
		return (BAD_PKT_ERR);
#endif
	return (SUCCESS);
}

/*****************************************************************************


******************************************************************************/

