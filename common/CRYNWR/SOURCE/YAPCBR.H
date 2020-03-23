/* file : yapcbr.h */

/* Ported from Phil Karn's Packet driver 'C' interface  */
/*  Portions Copyright (C) 1990 Phil Karn

    Copyright (C) 1992 Indian Institute of Technology Bombay
    Written by V. Srinivas and Nitin Kaulavkar,
    Dept of Computer Science and Engineering

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 1, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/


 /* Global definitions used by every source file.
 * Some may be compiler dependent.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dos.h>
#include <conio.h>

#define	__ARGS(x)	x
#define	INTERRUPT	void interrupt

/* Define null object pointer in case stdio.h isn't included */
#ifndef	NULL
/* General purpose NULL pointer */
#define	NULL (void *)0
#endif
#define NULLDEV (int ) -1
#define NULLHPTR (struct hash_table *)0  /* Null hash table pointer  */

/* standard boolean constants */
#define FALSE 0
#define TRUE 1
#define NO 0
#define YES 1
#define ZERO 0
#define SET  1
#define	RESET   0
#define FOUND   1
#define NOT_FOUND 0
#define	MAX_QSIZ   10 	/* global packet buffer queue size */
#define MAX_PKT_SIZE 1514  /* ethernet packet size */
#define DEFAULT_FLUSH_TIME 3600 /* hash table flush time in secs */

/* Various low-level and miscellaneous functions */
int htoi __ARGS((unsigned char *));
#define movblock(so,ss,do,ds,c)	movedata(ss,so,ds,do,c)
#define	PK_MAX	4     /* max number of segments supported, increase this if you need more segments */


/* Packet driver interface classes */
#define	CL_ETHERNET	1
/* Packet driver interface types (not a complete list) */
#define	TC500		1
#define	PC2000		10
#define	WD8003		14
#define	PC8250		15
#define	ANYTYPE		0xffff
#define EADDR_LEN	6

/* Packet driver function call numbers. From Appendix B. */
#define	DRIVER_INFO		1
#define	ACCESS_TYPE		2
#define	RELEASE_TYPE		3
#define	SEND_PKT		4
#define	TERMINATE		5
#define	GET_ADDRESS		6
#define	RESET_INTERFACE		7
#define GET_PARAMETERS		10
#define AS_SEND_PKT		11
#define	SET_RCV_MODE		20
#define	GET_RCV_MODE		21
#define	SET_MULTICAST_LIST	22
#define	GET_MULTICAST_LIST	23
#define	GET_STATISTICS		24
#define SET_ADDRESS		25

/* Packet driver error return codes. From Appendix C. */

#define	NO_ERROR	0
#define	BAD_HANDLE	1	/* invalid handle number */
#define	NO_CLASS	2	/* no interfaces of specified class found */
#define	NO_TYPE		3	/* no interfaces of specified type found */
#define	NO_NUMBER	4	/* no interfaces of specified number found */
#define	BAD_TYPE	5	/* bad packet type specified */
#define	NO_MULTICAST	6	/* this interface does not support multicast */
#define	CANT_TERMINATE	7	/* this packet driver cannot terminate */
#define	BAD_MODE	8	/* an invalid receiver mode was specified */
#define	NO_SPACE	9	/* operation failed because of insufficient space */
#define	TYPE_INUSE	10	/* the type had previously been accessed, and not released */
#define	BAD_COMMAND	11	/* the command was out of range, or not	implemented */
#define	CANT_SEND	12	/* the packet couldn't be sent (usually	hardware error) */
#define CANT_SET	13	/* hardware address couldn't be changed (> 1 handle open) */
#define BAD_ADDRESS	14	/* hardware address has bad length or format */
#define CANT_RESET	15	/* couldn't reset interface (> 1 handle open) */

#define	CARRY_FLAG	0x1

/* In yapcbr.c & main.c  */
struct pktdrvr {
	int class;	/* Interface class (ether ..) */
	int intno;	/* Interrupt vector */
	short handle;	/* Driver handle */
	int dev; 	/* device number of this interface */
	char *name; 	/* name of the interface */
	unsigned char eaddr[6]; /* ethernet address of the interface */
	int tmp_tail;
	unsigned long pkt_recvd; /* no of pkts recvd on the interface */
	unsigned long pkt_forward; /* no of pkts forwarded on the interface */
	unsigned long tx_errors; /* no of pkts transmission errors on the interface */
	unsigned long pkt_filtrd; /* no of pkts filtered on the same segment */
};

/* In yapcbr.c & main.c  */
struct	rxstruct {
	unsigned char rcv_buffer[MAX_PKT_SIZE];	/* packet receive buffer */
	unsigned len; 	/* packet length */
	int rcv_flag; 	/* SET if there is a valid packet in the buffer */
	int dev;  	/* interface/segment on which the packet was received */
 };

/* In yapcbr.c & main.c  */
extern struct pktdrvr Pktdrvr[];

/* In pktdrvr.c: */
void pkint __ARGS((int dev,unsigned short di,unsigned short si,
	unsigned short bp,unsigned short dx,unsigned short cx,
	unsigned short bx,unsigned short ax,unsigned short ds,
	unsigned short es));

/* In pkvec.asm: */
INTERRUPT pkvec0 __ARGS((void));
INTERRUPT pkvec1 __ARGS((void));
INTERRUPT pkvec2 __ARGS((void));
INTERRUPT pkvec3 __ARGS((void));

/* screen manipulation macros */

#define  restore()			textbackground(BLACK); \
					   textcolor(WHITE);  \
					    lowvideo()

#define reverse()		   textbackground(WHITE); \
				    textcolor(BLACK);   \
				    lowvideo()

/* End of YAPCBR.h */
