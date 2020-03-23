/* History:126,1 */
/* public domain by Russell Nelson, nelson@crynwr.com.  Politeness dictates
 * that you leave this notice intact */

#include <stdio.h>
#include <dos.h>
#include "pktdrvr.h"

char buffer[1514];			/* single buffer */
int packet_len;				/* the length of data in buffer */

int intno;				/* our handle */
int oldmode;
char myeaddr[6];			/* our Ethernet address */

/* Borland C pushes registers in the following order.  MS-C may push them
** in a different order.
*/
int interrupt receiver(bp, di, si, ds, es, dx, cx, bx, ax, ip, cs, flags)
{
	if (packet_len || cx > sizeof(buffer)) {
		es = di = 0;		/* discard this packet */
	} else if (ax == 0) {
		es = FP_SEG(buffer);	/* tell them to stick it in our buffer */
		di = FP_OFF(buffer);
	} else {
		packet_len = cx;	/* second upcall -- remember size. */
	}
}

dump_bytes(char *bytes, int count)
{
	int n;
	char buf[16];
	int address;
	void fmtline();

	address = 0;
	while(count){
		if (count > 16) n = 16;
		else n = count;
		fmtline(address,bytes,n);
		address += n;
		count -= n;
		bytes += n;
	}
}
/* Print a buffer up to 16 bytes long in formatted hex with ascii
 * translation, e.g.,
 * 0000: 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f  0123456789:;<=>?
 */
void
fmtline(addr,buf,len)
int addr;
char *buf;
int len;
{
	char line[80];
	register char *aptr,*cptr;
	unsigned register char c;
	void ctohex();

	memset(line,' ',sizeof(line));
	ctohex(line,addr >> 8);
	ctohex(line+2,addr & 0xff);
	aptr = &line[6];
	cptr = &line[55];
	while(len-- != 0){
		c = *buf++;
		ctohex(aptr,c);
		aptr += 3;
		c &= 0x7f;
		*cptr++ = isprint(c) ? c : '.';
	}
	*cptr++ = '\n';
	fwrite(line,1,(unsigned)(cptr-line),stdout);
}
/* Convert byte to two ascii-hex characters */
static
void
ctohex(buf,c)
register char *buf;
register int c;
{
	static char hex[] = "0123456789abcdef";

	*buf++ = hex[c >> 4];
	*buf = hex[c & 0xf];
}


int
main()
{
	int handle;
	char idle_chars[] = "-/|\\";
	int idle_index = 0;

	/* search for the first packet driver in memory */
	for (intno = 0x60; intno <= 0x80; intno++) {
		if (test_for_pd(intno))
			break;
	}
	/* if there is none, crap out */
	if (!test_for_pd(intno)) {
		fprintf(stderr, "No packet driver found");
		exit(1);
	}
	/* get a handle so that we can receive packets */
	handle = access_type(intno,
		CL_ETHERNET,		/* has to be an Ethernet driver */
		0xffff,			/* we don't care whose it is. */
		0,			/* we want the first piece of hardware */
		NULL,			/* doesn't matter because we want all */
		0,			/* zero type length, that is, all. */
		receiver);		/* -> our upcall */
	/* get the adaptor's Ethernet address */
	get_address (intno,handle,myeaddr,sizeof myeaddr);
	/* put the interface into promiscuous mode */
	oldmode = set_mode(intno,handle,6);
	while (!kbhit()) {
#if 0
		printf("%c\b", idle_chars[idle_index++]);
		idle_index %= (sizeof(idle_chars)-1);
#endif
		if (packet_len) {
			dump_bytes(buffer, packet_len);
#if 0
			/* send packet back */
			memcpy(buffer,buffer+6,6);
			memcpy(buffer+6,myeaddr,6);
			send_pkt(intno,buffer,packet_len);
#endif
			packet_len = 0;
		}
	}
	getch();
	set_mode(intno,handle,oldmode);
	release_type(intno, handle);
	return 0;
}

