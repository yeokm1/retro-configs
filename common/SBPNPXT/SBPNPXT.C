/******************************************************************************/
/*   This DOS program sets up SoundBlaster PnP ISA sound card on a 8088 or    */
/*   80286 based system where Creative's original utility may not work        */
/*   properly. This C source code is developed with Turbo C 2.0, and tested   */
/*   working with SB16 Vibra CT4170 card. But it "should" also work on any    */
/*   later AT system and a few other SB PnP cards in general.                 */
/*                                                                            */
/*   The program is non-TSR, occupies zero memory after execution.            */
/*   It's better to put it in AUTOEXEC.BAT and position it AFTER the          */
/*   'BLASTER' environment var:                                               */
/*   -------------------------------------------                              */
/*   set BLASTER=A220 I5 D1 H1 P330 T2                                        */
/*   SBPNPXT.EXE                                                              */
/*   -------------------------------------------                              */
/*                                                                            */
/*   This source code is license free. You can copy, modify and distribute    */
/*   it for any non-commercial purposes.                                      */
/*                                                                            */
/*   Chen Wang  2013-05                                                       */
/******************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <dos.h>

#define PNP_ADDRESS       0x279
#define PNP_WRITE_DATA    0xA79
#define PNP_MIN_READ_DATA 0x0203
#define PNP_MAX_READ_DATA 0x03FF

/** Typedefs ******************************************************************/
typedef unsigned int SIZE;
typedef unsigned char BYTE;
#define BOOL  int
#define TRUE  1
#define FALSE 0

/** Global vars ***************************************************************/
static int      g_nReadPort = 0;
static int      g_nBaseIO_A = 0x0220;
static int      g_nBaseIO_P = 0x0330;
static int      g_nBaseIO_G = 0x0200;
static int      g_nBaseIO_E = 0x0620;
static int      g_nBaseIO_X = 0x0388;
static BYTE     g_ucIRQ     = 5;
static BYTE     g_ucDMA     = 1;
static BYTE     g_ucDMA_H   = 5;
static BYTE     g_ucSBType  = 6;
static BOOL     g_bSilent   = FALSE;

/** Forward declarations ******************************************************/
static void  send_init_key( void );
static int   isolate_next_card( BYTE *pucSID72 );
static void  write_registerb( BYTE unRegister, BYTE ucValue );
static const char* get_vendor_ascii( BYTE *pID32 );
static BOOL  parse_env( const char *szENV );
static BOOL  find_card_name( BYTE ucCSN, char *szNameBuff, int nMaxNumChars,
			 int *pnAudio, int *pnGame, int *pnWaveTable, int *pnIDE );
static BOOL  peek_resource_data( BYTE *pucData, int nBytes );
static BOOL  read_resource_tag( BYTE *pucType, SIZE *puSize );
static void  msg_out( const char *szFMT, ... );

/** Implementation ************************************************************/

/*----------------------------------------------------------------------------*/
int main( int argc, char *argv[] )
{
    BYTE ucReadPort = 0x0;
    BYTE pucSID72[9] = { 0 };
    BOOL bIsolated = FALSE;
    BYTE ucCSN = 0, unNumCSNs = 0;
    BYTE pucCtCsn[8] = { 0 };
    int nNumCtCsn = 0;
    const char *szENV = NULL;

    /* See if silent mode is required */
    if ( argc > 1 )
    {
        if ( 0 == stricmp("/S", argv[1]) )
        {
			g_bSilent = TRUE;
        }
        else
        {
            msg_out( "Invalid argument.\n" );
            return 1;
        }
    }

    szENV = getenv( "BLASTER" );
	if ( NULL != szENV )
	{
		parse_env( szENV );
		/* Debug code
		msg_out( "g_nBaseIO_A=%#x, g_ucIRQ=%#x, g_ucDMA=%#x, g_ucDMA_H=%#x,"
				 "g_nBaseIO_P=%#x, g_nBaseIO_E=%#x, g_ucSBType=%#x,"
				 "g_nBaseIO_G=%#x\n",
				  g_nBaseIO_A, g_ucIRQ, g_ucDMA, g_ucDMA_H, g_nBaseIO_P,
				  g_nBaseIO_E, g_ucSBType, g_nBaseIO_G );
		*/
	}

    /* Make sure that all PnP cards are in Wait for Key state */
	write_registerb( 0x02, 0x02 );
	delay( 1 );

    /* Put all PnP cards in Sleep state by sending initiation key twice,  */
	send_init_key( );
	delay( 1 );

    /* Clear CSN (card select number) on all PnP cards */
	write_registerb( 0x02, 0x04 );
	ucCSN = 0;

    /* Put all PnP cards to Isolation state */
	write_registerb( 0x03, 0x00 );

    /* Try to isolate the first PnP card, meanwhile, a working read port
	   has to be found within this first try*/
	g_nReadPort = 0;
	for ( ucReadPort = 0x80; !bIsolated && (ucReadPort < 0xFF);
		  ucReadPort += 0x10 )
	{
		/* Tell all PnP cards which are still in Isolate state
		   about where the read address is going to be */
		write_registerb( 0x00, ucReadPort );

		/* Calculate uncompressed 16-bit version of the read port */
		g_nReadPort = ( ucReadPort << 2 ) | 0x3;

		/* Try to isolate a PnP card whoever comes first */
		bIsolated = isolate_next_card( pucSID72 );

        /* On failure, reset all PnP cards that are in Isolate state */
        if ( !bIsolated )
        {
            write_registerb( 0x03, 0x00 );
            delay( 1);
        }
	}
	/* No card found, or, no available read port found (unlikely) */
	if ( !bIsolated ) g_nReadPort = 0;

    /* Try to find all PnP cards */
    while ( bIsolated )
    {
        /* Decompress the current PnP card's ID */
		const char *szID = get_vendor_ascii( pucSID72 );

        ucCSN ++; /* calculate the next free CSN */
        unNumCSNs++; /* increment total number of PnP cards */

        /* Assign CSN (Card Select Number) to this PnP card,
           this automatically put this card in Config state */
		write_registerb( 0x06, ucCSN );
		delay( 1 );

		/* If this card is Creative Labs, record its CSN */
        if ( (NULL != szID) && (strlen(szID) > 3) &&
             ('C' == szID[0]) && ('T' == szID[1]) && ('L' == szID[2]) &&
             (nNumCtCsn < 8) )
        {
            pucCtCsn[nNumCtCsn++] = ucCSN;
        }

        /* Transit this card back to Sleep state and transit all
           PnP cards without CSN to Isolate state */
		write_registerb( 0x03, 0x00 );
		delay( 1 );

        /* Try to isolate a PnP card whoever comes next */
		bIsolated = isolate_next_card( pucSID72 );
    }

    /* Show card search result
    if ( 0 == nNumCtCsn )
    {
        msg_out( "No Creative Labs PnP card found.\n" );
    }
    else if ( nNumCtCsn > 1 )
    {
		msg_out( "Multiple Creative Labs cards found, "
				 "but only one of them will be configured.\n" );
    }
    */

    /* Look for sound blaster card and configure it */
    if ( nNumCtCsn > 0 )
    {
        /* Look for sound blaster card */
        char szLabel[64] = { 0 };
		int nAudio = -1, nGame = -1, nWaveTable = -1, nIDE = -1;
        BYTE ucSbCsn = 0;
        int i = 0;
        while( i < nNumCtCsn )
        {
            if ( find_card_name(pucCtCsn[i], szLabel, 64,
				 &nAudio, &nGame, &nWaveTable, &nIDE) && (nAudio >= 0) )
            {
                ucSbCsn = pucCtCsn[i];
                break;
            }
            i++;
        }

        /* If found, configure it */
        if ( ucSbCsn > 0 )
		{
			msg_out( "Configuring [%s] ...\n", szLabel );

            if (  NULL == szENV )
				msg_out( "'BLASTER' environment variable is missing"
						 "--using default values instead.\n" );

            /* Put the PnP card with the CSN in Config state */
            write_registerb( 0x03, ucSbCsn );
            delay( 1 );

            /* Select the audio device */
            write_registerb( 0x07, (BYTE)nAudio );

            /* Set Base IO address */
            write_registerb( 0x60, (BYTE)((g_nBaseIO_A >> 8) & 0x00FF) );
            write_registerb( 0x61, (BYTE)(g_nBaseIO_A & 0x00FF) );
			msg_out( "Base-IO=%XH", g_nBaseIO_A );

            /* Set MIDI address */
            write_registerb( 0x62, (BYTE)((g_nBaseIO_P >> 8) & 0x00FF) );
            write_registerb( 0x63, (BYTE)(g_nBaseIO_P & 0x00FF) );
			msg_out( ", MIDI-Port=%XH", g_nBaseIO_P );

            /* Set ??? address */
            write_registerb( 0x64, (BYTE)((g_nBaseIO_X >> 8) & 0x00FF) );
            write_registerb( 0x65, (BYTE)(g_nBaseIO_X & 0x00FF) );
			/*msg_out( ", ???-Port=%XH", g_nBaseIO_X );*/

            /* Set IRQ */
            write_registerb( 0x70, g_ucIRQ );
            write_registerb( 0x71, 0x02 );
            write_registerb( 0x72, g_ucIRQ );
            write_registerb( 0x73, 0x02 );
			msg_out( ", IRQ=%d", g_ucIRQ );

            /* Set DMA chanel */
            write_registerb( 0x74, g_ucDMA );
            write_registerb( 0x75, g_ucDMA_H );
			msg_out( ", DMA=%d", g_ucDMA );
			msg_out( ", High-DMA=%d", g_ucDMA_H );

            /*g_ucSBType*/

            /* Activate audio device on this PnP card */
            write_registerb( 0x30, 0x01 );

            /* Optionally configure Game device */
            if ( nGame >= 0 )
            {
                /* Select the Game device */
                write_registerb( 0x07, (BYTE)nGame );

                /* Set Base IO address */
                write_registerb( 0x60, (BYTE)((g_nBaseIO_G >> 8) & 0x00FF) );
                write_registerb( 0x61, (BYTE)(g_nBaseIO_G & 0x00FF) );
                /*msg_out( ", Game-Port=%XH", g_nBaseIO_G );*/

                /* Activate the Game device on this PnP card */
                write_registerb( 0x30, 0x01 );
            }

            /* Optionally configure WaveTable device */
			if ( nWaveTable >= 0 )
			{
                /* Select the WaveTable device */
                write_registerb( 0x07, (BYTE)nWaveTable );

                /* Set Base IO address */
                write_registerb( 0x60, (BYTE)((g_nBaseIO_E >> 8) & 0x00FF) );
                write_registerb( 0x61, (BYTE)(g_nBaseIO_E & 0x00FF) );
				msg_out( ", WavEffects-Port=%XH ", g_nBaseIO_E );

                /* Set magic ports (undocumented ports)  */
                write_registerb( 0x62, (BYTE)((0x0A20 >> 8) & 0x00FF) );
                write_registerb( 0x63, (BYTE)(0x0A20 & 0x00FF) );
                write_registerb( 0x64, (BYTE)((0x0E20 >> 8) & 0x00FF) );
				write_registerb( 0x65, (BYTE)(0x0E20 & 0x00FF) );

                /* Activate the WaveTable device on this PnP card */
				write_registerb( 0x30, 0x01 );
            }

            /* Optionally configure IDE device */
            if ( nIDE >= 0 )
            {
                /* Select the IDE device */
                write_registerb( 0x07, (BYTE)nIDE );

                /* Set Base IO address */
                write_registerb( 0x60, (BYTE)((0x0170 >> 8) & 0x00FF) );
                write_registerb( 0x61, (BYTE)(0x0170 & 0x00FF) );
				write_registerb( 0x62, (BYTE)((0x0376 >> 8) & 0x00FF) );
				write_registerb( 0x63, (BYTE)(0x0376 & 0x00FF) );
                /*msg_out( ", IDE-Port=%XH", 0x0170 );*/

                /* Set IRQ */
                write_registerb( 0x70, 0x0F );
                write_registerb( 0x71, 0x02 );
                /*msg_out( ", IDE-IRQ=%XH", 0x0E );*/

                /* Activate the IDE device on this PnP card */
                write_registerb( 0x30, 0x01 );
            }

            msg_out( "\n" );

            /* If the environment var 'BLASTER' is not yet set, remind
               the user to add it */
            if (  NULL == szENV )
            {
				msg_out( "You may need to add the environment variable like this:\n"
                         "set BLASTER=A%X I%d D%d H%d P%X ", g_nBaseIO_A,
                         g_ucIRQ, g_ucDMA, g_ucDMA_H, g_nBaseIO_P );
				if ( nWaveTable >= 0 )
                {
                    msg_out( "E%X\n", g_nBaseIO_E );
                }
                else
                {
                    msg_out( "\n" );
                }
            }

            /* Transit this card back to Sleep state and transit all
               PnP cards without CSN to Isolate state */
            write_registerb( 0x03, 0x00 );
            delay( 1 );
        }
        else
        {
            msg_out( "No SoundBlaster PnP card found.\n" );
        }
    }
    else
    {
        msg_out( "No SoundBlaster PnP card found.\n" );
    }

    /* Bring all PnP cards back to normal operation state */
	write_registerb( 0x02, 0x02 );
	delay( 1 );
	write_registerb( 0x02, 0x02 );

    return 0;
}

/*----------------------------------------------------------------------------*/
static void send_init_key( void )
{
	static BYTE s_ucVals[] =
	{
		0x00, 0x00, 0x6A, 0xB5, 0xDA, 0xED, 0xF6, 0xFB, 0x7D, 0xBE,
		0xDF, 0x6F, 0x37, 0x1B, 0x0D, 0x86, 0xC3, 0x61, 0xB0, 0x58,
		0x2C, 0x16, 0x8B, 0x45, 0xA2, 0xD1, 0xE8, 0x74, 0x3A, 0x9D,
		0xCE, 0xE7, 0x73, 0x39,
	};

	int i = 0, n = sizeof(s_ucVals)/sizeof(*s_ucVals);
	while( i < n )
	{
		outportb( PNP_ADDRESS, s_ucVals[i] );
		++i;
	}
}

/*----------------------------------------------------------------------------*/
static BOOL isolate_next_card( BYTE *pucSID72 )
{
	BOOL bSuccess = ( NULL != pucSID72 ) &&
	                ( PNP_MIN_READ_DATA <= g_nReadPort ) &&
	                ( g_nReadPort <= PNP_MAX_READ_DATA );

	if ( bSuccess )
	{
		int i = 0, nBit = 0, nValid = 0, nSum = 0x6A;

		/* Start the serial isolation protocol */
		outportb( PNP_ADDRESS, 0x01 );
		delay( 1 );

		/* Read 72-bit Serial ID */
		memset( pucSID72, 0, 9 );
		for ( i = 0; i < 72; i++ )
		{
			nBit = ( 0x55 == inportb(g_nReadPort) );
			delay( 1 );
			nBit = ( 0xAA == inportb(g_nReadPort) ) && nBit;
			delay( 1 );
			nValid = nValid || nBit;
			if ( i < 64 )
				nSum = ( nSum >> 1 ) |
				       ( ((nSum ^ (nSum >> 1) ^ nBit) << 7)
				         & 0xFF );
			pucSID72[i/8] = ( pucSID72[i/8] >> 1 ) |
			      	        ( nBit ? 0x80 : 0 );
		}
		nValid = nValid && ( pucSID72[8] == nSum );

		/* On success, one PnP card has been isolated and the other
		   PnP cards have automatically returned to Sleep state */
		bSuccess = ( 0 != nValid );
	}

	return bSuccess;
}

/*----------------------------------------------------------------------------*/
static void write_registerb( BYTE unRegister, BYTE ucValue )
{
	outportb( PNP_ADDRESS, unRegister );
	outportb( PNP_WRITE_DATA, ucValue );
}

/*----------------------------------------------------------------------------*/
static const char* get_vendor_ascii( BYTE *pID32 )
{
    static char s_szASC[9] = { 0 };
    if ( NULL != pID32 )
    {
		const char szHex2Asc[] = "0123456789ABCDEF";
		s_szASC[0] = '@' + ( (pID32[0] & 0x7C) >> 2 );
    	s_szASC[1] = '@' + ( ((pID32[0] & 0x3) << 3) +
			                 ((pID32[1] & 0xE0) >> 5) );
    	s_szASC[2] = '@' + ( pID32[1] & 0x1F );
    	s_szASC[3] = szHex2Asc[(pID32[2] >> 4)];
    	s_szASC[4] = szHex2Asc[(pID32[2] &  0xF)];
    	s_szASC[5] = szHex2Asc[(pID32[3] >> 4)];
    	s_szASC[6] = szHex2Asc[(pID32[3] &  0xF)];
    	s_szASC[7] = 0;
    }
    return ( 0 != s_szASC[0] )? s_szASC : NULL;
}

/*----------------------------------------------------------------------------*/
static BOOL parse_env( const char *szENV )
{
	/* szENV = e.g: A220 I5 D1 H5 P330 E620 T1 */

	BOOL bSuccess = ( NULL != szENV );

	/* Scan for items and parse */
	const char *sz = szENV, *szItem = NULL;
    while( bSuccess )
	{
		/* If current char is a letter, check for start of item */
		if ( isalpha(*sz) )
		{
			/* If we are not in an item, start a new item */
			if ( NULL == szItem )
				szItem = sz;
			/* otherwise, if the letter is not a hex-digit, faile,
			   as each item allows only one letter at beninning */
			else if ( !isxdigit(*sz) )
				bSuccess = FALSE;
		}
		/* otherwise, if current char is a delimiter, check for end of item */
		else if ( (' ' == *sz) || ('\0' == *sz) )
		{
			/* If we are currelty in an item, end it */
			if ( NULL != szItem )
			{
				/* Parse the item if it has valid length */
				int nLen = sz - szItem;
				if ( (2 <= nLen) && (nLen < 16) )
				{
					/* Copy all hex-digits and add a zero-terminator at the end*/
					char szHex[16];
					int nValue = 0;
					memcpy( szHex, szItem + 1, (nLen - 1) * sizeof(*szItem) );
					szHex[nLen-1] = '\0';
					/* Convert from hex-string to integer value */
					sscanf( szHex, "%x", &nValue );
					/* Assign the value of known type to corresponding global vars */
					switch ( *szItem )
					{
						case 'a':
						case 'A':
							g_nBaseIO_A = nValue;
							break;

						case 'i':
						case 'I':
							g_ucIRQ = nValue;
							break;

						case 'd':
						case 'D':
							g_ucDMA = nValue;
							break;

						case 'h':
						case 'H':
							g_ucDMA_H = nValue;
							if ( g_ucDMA_H == g_ucDMA ) g_ucDMA_H = 0;
							break;

						case 'p':
						case 'P':
							g_nBaseIO_P = nValue;
							break;

						case 'e':
						case 'E':
							g_nBaseIO_E = nValue;
							break;

						case 't':
						case 'T':
							g_ucSBType = nValue;
							break;

						case 'g':
						case 'G':
							g_nBaseIO_G = nValue;
							break;

						default:
							/* Ignore everything else */
							break;
					}
				}

				szItem = NULL;
			}


		}
		/* otherwise, only hex-digit is acceptable between a letter and a delimiter */
		else if ( NULL != szItem )
		{
			bSuccess = ( isxdigit(*sz) );
		}
		else
		{
			/* ignore anything outside of an item */
		}

        /* On zero-terminator, finish parsing */
        if ( '\0' != *sz )
           sz++;
        else
            break;
	}
}

/*----------------------------------------------------------------------------*/
static BOOL find_card_name( BYTE ucCSN, char *szNameBuff, int nMaxNumChars,
			int *pnAudio, int *pnGame, int *pnWaveTable, int *pnIDE )
{
	/* Assume that one PnP card is already assigned a CSN (Card Select Number)
	   and can be uniquely identified by this CSN, and this card is not in
	   Wait for Key state */

	BOOL bSuccess = ( ucCSN > 0 ) &&
	                ( PNP_MIN_READ_DATA <= g_nReadPort ) &&
	                ( g_nReadPort <= PNP_MAX_READ_DATA ) &&
                    ( NULL != szNameBuff ) && ( nMaxNumChars > 0 );

	/* A few handy vars */
	BYTE ucType = 0;
	SIZE uSize = 0;
	BOOL bEOF = FALSE;
	int nNumDevices = 0;
	int nAudio = -1, nGame = -1, nWaveTable = -1, nIDE = -1;

	/* Put the PnP card with the CSN in Config state, and reset
		the pointer to the begining of the resource stream */
	write_registerb( 0x03, ucCSN );
	delay( 1 );

    /*  Ignore the serial ID of this card */
	if ( bSuccess )
	{
		bSuccess = peek_resource_data( NULL, 9 );
	}

    /* Clear name buffer */
    if ( bSuccess )
    {
		*szNameBuff = '\0';
    }

	/* Scan, read and process all tagged resources. Since all resource
	   data are serialized, any read error will abort and fail the
	   entire process  */
	while ( bSuccess && !bEOF )
	{
		/* Read next tag */
		bSuccess = read_resource_tag( &ucType, &uSize );
		if ( !bSuccess ) break;

		/* Dispatch each specific task to the corresponding parser */
		switch ( ucType )
		{
			/* Short tags -------- */

			case 0x01: /* PnP version number */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x02: /* logical device ID */
				nNumDevices++;
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x03: /* compatible device ID */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x04: /* IRQ format */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x05: /* DMA format */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x06: /* start dependent function */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x07: /* end dependent function */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x08: /* port descriptor */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x09: /* fixed location I/O port descriptor */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x0e: /* vendor defined data */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x0F: /* end */
				bSuccess = peek_resource_data( NULL, uSize );
				bEOF = TRUE;
				break;

			/* Long tags -------- */

			case 0x81: /* memory range descriptor */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x82: /* ANSI Identifier String  */
				if ( (uSize < nMaxNumChars) && ('\0' == *szNameBuff) )
                {
                    bSuccess = peek_resource_data( szNameBuff, uSize );
					if ( bSuccess ) szNameBuff[uSize] = '\0';
				}
                else if ( uSize < 64 )
                {
                    char szBuff[64];
                    bSuccess = peek_resource_data( szBuff, uSize );
                    if ( bSuccess )
                    {
                        szBuff[uSize] = '\0';
						if ( 0 == stricmp("Audio", szBuff) )
							nAudio = nNumDevices - 1;
						if ( 0 == stricmp("Game", szBuff) )
							nGame = nNumDevices - 1;
						if ( 0 == stricmp("WaveTable", szBuff) )
							nWaveTable = nNumDevices - 1;
						if ( 0 == stricmp("IDE", szBuff)  )
							nIDE = nNumDevices - 1;
                    }
                }
				else
				{
					bSuccess = peek_resource_data( NULL, uSize );
				}
				break;

			case 0x83: /* unicode string */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x84: /* vendor */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x85: /* 32-bit Memory Range Descriptor */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			case 0x86: /* 32-bit Fixed Location Memory Range Descriptor */
				bSuccess = peek_resource_data( NULL, uSize );
				break;

			default:
				if ( uSize > 0  )
					bSuccess = peek_resource_data( NULL, uSize );
		}
	}
    
    /* Optionally fill output vars */
	if ( NULL != pnAudio ) *pnAudio = nAudio;
	if ( NULL != pnGame ) *pnGame = nGame;
	if ( NULL != pnWaveTable ) *pnWaveTable = nWaveTable;
	if ( NULL != pnIDE ) *pnIDE = nIDE;

	/* Transit this PnP card back to Sleep state and transit all
		PnP cards without CSN to Isolate state */
	write_registerb( 0x03, 0x00 );
	delay( 1 );

	return bSuccess;
}

/*----------------------------------------------------------------------------*/
static BOOL peek_resource_data( BYTE *pucData, int nBytes )
{
	BOOL bSuccess = TRUE;

	/* Read resource data until required number of bytes reached */
	int  nBytesRead = 0;
	BYTE unStatus = 0, ucByte = 0;
	while ( nBytesRead < nBytes )
	{
		/* Poll the status until the data is ready on the bus or timeout */
		int i = 0;
		for ( i = 0; i < 50; i++ )
		{
			outportb( PNP_ADDRESS, 0x05 );
			unStatus = inportb( g_nReadPort );
			if ( unStatus & 0x01 ) break;
			delay( 1 );
		}

		/* If a byte of data is ready on the bus, pick it up */
		if ( unStatus & 0x01 )
		{
			/* Read next byte of resource data */
			outportb( PNP_ADDRESS, 0x04 );
			ucByte = inportb( g_nReadPort );
			if ( pucData != NULL ) pucData[nBytesRead] = ucByte;
			nBytesRead++;
		}
		/* otherwise, stop and fail */
		else
		{
			bSuccess = FALSE;
			break;
		}
	}

	return bSuccess;
}

/*----------------------------------------------------------------------------*/
static BOOL read_resource_tag( BYTE *pucType, SIZE *puSize )
{
	BOOL bSuccess = ( NULL != pucType ) && ( NULL != puSize );

    BYTE ucTag = 0, pucBuff[2] = { 0 };
    if ( bSuccess)
    {
        bSuccess = peek_resource_data( &ucTag, 1 );
    }

	if ( bSuccess )
	{
		if ( 0 == ucTag ) /* invalid tag */
		{
			bSuccess = FALSE;
		}
		else if ( ucTag & 0x80 ) /* large item */
		{
			*pucType = ucTag;
            bSuccess = peek_resource_data( pucBuff, 2 );
            if ( bSuccess )
                *puSize = ( pucBuff[1] << 8 ) | pucBuff[0];
		}
		else /* small item */
		{
			*pucType = ( ucTag >> 3 ) & 0x0F;
			*puSize = ucTag & 0x07;
		}

		/* check for invalid data here */
		bSuccess = bSuccess && ( *pucType != 0x00 ) &&
				   ( *pucType != 0xFF ) && ( *puSize != 0xFFFF );
	}

	return bSuccess;
}

/*----------------------------------------------------------------------------*/
void msg_out( const char *szFMT, ... )
{
	if ( !g_bSilent )
	{
		va_list args;
		va_start ( args, szFMT );
		vprintf ( szFMT, args );
		va_end ( args );
	}
}



