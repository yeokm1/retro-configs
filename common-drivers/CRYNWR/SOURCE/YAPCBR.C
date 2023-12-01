/* file : yapcbr.c */
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


#include "yapcbr.h"
long access_type __ARGS((int intno,int if_class,int if_type,int if_number,
	char *type,unsigned typelen,INTERRUPT (*receiver) __ARGS((void)) ));
int driver_info __ARGS((int intno,int handle,int *version,
	int *class,int *type,int *number,int *basic));
int release_type __ARGS((int intno,int handle));
int get_address __ARGS((int intno,int handle,unsigned char *buf,int len));
int pk_stop __ARGS((int devif));
int send_pkt __ARGS((int intno,unsigned char *buffer,unsigned length));
void pkint __ARGS((int dev,unsigned short di,unsigned short si,
		    unsigned short bp,unsigned short dx,unsigned short cx,
		    unsigned short bx,unsigned short ax,unsigned short ds,
		    unsigned short es));
int set_rcv_mode __ARGS((int intno,int handle,int mode));

static INTERRUPT (*Pkvec[])() = { pkvec0,pkvec1,pkvec2,pkvec3};
static int Derr;
static char Pkt_sig[] = "PKT DRVR";	/* Packet driver signature */
static struct pktdrvr *pk;
extern int rx_head,rx_tail,tmp_tail, overflow_flag,rx_count;
extern struct pktdrvr Pktdrvr[PK_MAX];
extern struct rxstruct *rx[];
extern unsigned int rcv_count,forwd_count,lost_count;

#pragma option -r-
/* Packet driver receive routine. Called from an assembler hook that pushes
 * the caller's registers on the stack so we can access and modify them.
 * This is a rare example of call-by-location in C.
 */
void
pkint(dev,di,si,bp,dx,cx,bx,ax,ds,es)
int dev;
unsigned short di,si,bp,dx,cx,bx,ax,ds,es;
{

	pk = &Pktdrvr[dev];
	switch(ax){
	case 0:	/* Space allocate call */
		if(rx_count == (MAX_QSIZ-1)){
		   es = di = 0; /* no buffer space, return NULL */
		   lost_count++;
		   break;
		 }
		pk->tmp_tail = rx_tail;
		rx_tail++;
		if(rx_tail == MAX_QSIZ)
		    rx_tail=0;
		  es = FP_SEG(rx[pk->tmp_tail]->rcv_buffer);
		  di = FP_OFF(rx[pk->tmp_tail]->rcv_buffer);
		  rx[pk->tmp_tail]->dev = dev;
		  rx_count++;
		break;

	case 1:	/* Packet complete call */
		rx[pk->tmp_tail]->rcv_flag = SET;
		rx[pk->tmp_tail]->len = cx;
		Pktdrvr[dev].pkt_recvd++;
		rcv_count++;   /* number of packets received */
		break;

	default:
		break;
	}
 }
#pragma option -r.
/* Shut down the packet interface */
int
pk_stop(devif)
int devif;
{
	struct pktdrvr *pp;

	pp = &Pktdrvr[devif];
	/* Call driver's release_type() entry */
	if(release_type(pp->intno,pp->handle) == -1)
		printf("%s: release_type error code %u\n",pp->name,Derr);

	return 0;
}

/* Attach a packet driver to the system
 * intno: software interrupt vector.
 * net_name: interface label, e.g., "seg#0"
 */
int
pk_attach(intno,net_name)
unsigned int intno;
unsigned char net_name[];
{
	int class,type;
	char catch_all[] = {0x0};
	long handle;
	int i;

	long drvvec;
	char sig[8];	/* Copy of driver signature "PKT DRVR" */
	register struct pktdrvr *pp;
	unsigned char tmp[25];

	for(i=0;i<PK_MAX;i++){
		if(Pktdrvr[i].dev == NULLDEV)
			break;
	}
	if(i >= PK_MAX){
		printf("Too many packet drivers\n");
		return -1;
	}

	/* to be modified later
	if(if_lookup(net_name) != NULLDEV){
		printf("Interface %s already exists\n",net_name);
		return -1;
	}
	*/

	/* Verify that there's really a packet driver there, so we don't
	 * go off into the ozone (if there's any left)
	 */
	drvvec = (long)getvect(intno);
	movblock(FP_OFF(drvvec)+3, FP_SEG(drvvec),
		FP_OFF(sig),FP_SEG(sig),strlen(Pkt_sig));
	if(strncmp(sig,Pkt_sig,strlen(Pkt_sig)) != 0){
		return -1;
	}
	pp = &Pktdrvr[i];
	pp->name = strdup(net_name);
	pp->intno = intno;
	pp->dev = i;

 	/* Version 1.08 of the packet driver spec dropped the handle
 	 * requirement from the driver_info call.  However, if we are using
 	 * a version 1.05 packet driver, the following call will fail.
  	 */
	if(driver_info(intno,-1,NULL,&class,&type,NULL,NULL) == 0){
			handle = access_type(intno,class,ANYTYPE,0,ZERO,ZERO,
				Pkvec[pp->dev]);
			set_rcv_mode(intno,handle,6); /* catch all packets */
			if(handle != -1 || Derr == TYPE_INUSE){
				pp->handle = handle;
		get_address(intno,pp->handle,pp->eaddr,EADDR_LEN);
	    }
	 }
	 else
	 {
		return -1;
	 }
	pp->class = class;
	get_address(intno,pp->handle,pp->eaddr,EADDR_LEN);
	return 0;
}


long
access_type(intno,if_class,if_type,if_number,type,typelen,receiver)
int intno;
int if_class;
int if_type;
int if_number;
char *type;
unsigned typelen;
INTERRUPT (*receiver)();
{
	union REGS regs;
	struct SREGS sregs;
	segread(&sregs);
	regs.h.dl = if_number;		/* Number */
	sregs.ds = FP_SEG(type);	/* Packet type template */
	regs.x.si = FP_OFF(type);
	regs.x.cx = typelen;		/* Length of type */
	sregs.es = FP_SEG(receiver);	/* Address of receive handler */
	regs.x.di = FP_OFF(receiver);
	regs.x.bx = if_type;		/* Type */
	regs.h.ah = ACCESS_TYPE;	/* Access_type() function */
	regs.h.al = if_class;		/* Class */
	int86x(intno,&regs,&regs,&sregs);
	if(regs.x.cflag){
		Derr = regs.h.dh;
		return -1;
	} else
		return regs.x.ax;
}
int
release_type(intno,handle)
int intno;
int handle;
{
	union REGS regs;

	regs.x.bx = handle;
	regs.h.ah = RELEASE_TYPE;
	int86(intno,&regs,&regs);
	if(regs.x.cflag){
		Derr = regs.h.dh;
		return -1;
	} else
		return 0;
}



int
driver_info(intno,handle,version,class,type,number,basic)
int intno;
int handle;
int *version,*class,*type,*number,*basic;
{
	union REGS regs;

	regs.x.bx = handle;
	regs.h.ah = DRIVER_INFO;
	regs.h.al = 0xff;
	int86(intno,&regs,&regs);
	if(regs.x.cflag){
		Derr = regs.h.dh;
		return -1;
	}
	if(version != NULL)
		*version = regs.x.bx;
	if(class != NULL)
		*class = regs.h.ch;
	if(type != NULL)
		*type = regs.x.dx;
	if(number != NULL)
		*number = regs.h.cl;
	if(basic != NULL)
		*basic = regs.h.al;
	return 0;
}

int
get_address(intno,handle,buf,len)
int intno;
int handle;
unsigned char *buf;
int len;
{
	union REGS regs;
	struct SREGS sregs;

	segread(&sregs);
	sregs.es = FP_SEG(buf);
	regs.x.di = FP_OFF(buf);
	regs.x.cx = len;
	regs.x.bx = handle;
	regs.h.ah = GET_ADDRESS;
	int86x(intno,&regs,&regs,&sregs);
	if(regs.x.cflag){
		Derr = regs.h.dh;
		return -1;
	}
	return 0;
}



/* Convert hex-ascii to integer */
int
htoi(s)
unsigned char *s;
{
	int i = 0;
	unsigned char c;

	while((c = *s++) != '\0'){
		if(c == 'x')
			continue;	/* allow 0x notation */
		if('0' <= c && c <= '9')
			i = (i * 16) + (c - '0');
		else if('a' <= c && c <= 'f')
			i = (i * 16) + (c - 'a' + 10);
		else if('A' <= c && c <= 'F')
			i = (i * 16) + (c - 'A' + 10);
		else
			break;
	}
	return i;
}


/* set the receiver mode   */

int set_rcv_mode(int intno,int handle,int mode)
{

	union REGS regs;

	regs.h.ah = SET_RCV_MODE;
	regs.x.bx = handle;
	regs.x.cx = mode;
	regs.x.dx = 00;
	int86(intno,&regs,&regs);
	if(regs.x.cflag){
		Derr = regs.h.dh;
		return -1;
	} else
		return 0;
}
