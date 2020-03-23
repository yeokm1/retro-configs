/* File : main.c */

/*
    Copyright (C) 1992 Indian Institute of Technology, Bombay
    Written by V. Srinivas and Nitin Kaulavkar,
    Dept of Computer Science and Engineering.

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
#include <stdio.h>
#include <dos.h>
#include <conio.h>
#include <time.h>
#include <ctype.h>

/* Externs defined in yapcbr.c */
extern long access_type __ARGS((int intno,int if_class,int if_type,int if_number
	   ,char *type,unsigned typelen,INTERRUPT (*receiver) __ARGS((void)) ));
extern int driver_info __ARGS((int intno,int handle,int *version,
	int *class,int *type,int *number,int *basic));
extern int release_type __ARGS((int intno,int handle));
extern int get_address __ARGS((int intno,int handle,unsigned char *buf,int len));
extern int pk_stop __ARGS((int devif));

/* Externs defined in pkvec.asm */
extern int send_pkt __ARGS((int intno,unsigned char *buffer,unsigned length));
extern void learn_addr __ARGS(( unsigned char *s));

/* Externs defined in timer.c */
extern  void init_timer();
extern  void release_timer();

/* defined in this  file */
void disp_statistics();
void pk_detach();

/* global variables */
int rx_head =0,rx_tail=0,tmp_tail,rx_count=0;
unsigned long rcv_count=0,lost_count=0,forwd_count=0,brodcst=0,transmit_errs=0;
int err_val;
int directvideo = 1;
int overflow_flag = RESET;
int no_of_ifaces;  /* number of interfaces   */
int send_err;
/* The pc timer raises an interrupt 18.2 times a sec, 182 ticks make 10 sec */
unsigned int flush_time,sec=0,ticks=182;
struct rxstruct *rx[MAX_QSIZ]  ;  /* global packet buffer, keep it large enough */
struct pktdrvr Pktdrvr[PK_MAX];   /* packet driver interface table */
unsigned char att_param[PK_MAX][2][10]; /* the configuration parameters */
unsigned char *hash_tableptr; /* points to the 64k hash table */
struct rxstruct *rxptr;  /* points to the global pkt receive buffer */


void main(int argc, char *argv[])
{
    int mode,retval,hashret,dev;
    unsigned char *dest, *src;
    struct pktdrvr *pk;
    int i,ret_dev,ch;    /* handy variables */
    time_t t;
    char uptime[80];
    char option[80];
    int done = 0;

    if(argc > 2){
        fprintf(stderr,"\nUsage yapcbr [Hash Table Flush Time in Mins]\n");
        exit(1);
    }
    if(argc == 3){
        flush_time=atoi(argv[1]);
        flush_time=((0<flush_time)&&(flush_time<1000))?(flush_time*60):DEFAULT_FLUSH_TIME;
    }
    else flush_time = DEFAULT_FLUSH_TIME;
    /* malloc the global packet buffer  */
    for(i=0; i<MAX_QSIZ; i++){
        rx[i] = (struct rxstruct *)malloc(sizeof(struct rxstruct));
        if(rx[i] == (struct rxstruct *) NULL){
            fprintf(stderr,"main.c : Unable to malloc \n");
            exit(-1);
        }
    }

    /* calloc the 64k buffer for the hash table      */
    if((hash_tableptr = (unsigned char *) calloc(65535,1)) == (unsigned char *)NULL){
        fprintf(stderr,"main.c : Unable to calloc \n");
        exit(-1);
    }

    /* necessary initialization */
reset_bridge:    /* jump to here when the bridge is reset */
    /* initialize the hash table entries to zero  */
    memset(hash_tableptr,0x0,65535);
    /* initialize the pkt driver table        */
    for(i=0;i<PK_MAX;i++){
        pk = &Pktdrvr[i];
        pk->dev = NULLDEV;
        pk->tx_errors=pk->pkt_forward=pk->pkt_recvd=pk->pkt_filtrd=0;
    }
/* initialize the statistical variables */
    rcv_count=lost_count=forwd_count=brodcst=0;
    rx_head=rx_tail=rx_count =0;

/* initialize the global receiver buffer  */
    for(i=0;i<MAX_QSIZ; i++) rx[i]->rcv_flag = RESET;

    rxptr = rx[rx_head];  /* point to the head of the queue */
    clrscr();

/* Initialize the receiver's of all the interfaces  */
    strcpy(att_param[0][1],"Seg#1");
    strcpy(att_param[1][1],"Seg#2");
    strcpy(att_param[2][1],"Seg#3");
    strcpy(att_param[3][1],"Seg#4");
    no_of_ifaces = 0;
    for(i=0x60;i<0x80; i++)
	if(pk_attach(i, att_param[no_of_ifaces][1]) != -1)
	    if (++no_of_ifaces > PK_MAX) {
		fprintf(stderr,"Maximum no of interfaces supported is %s \n",PK_MAX);
		exit(1);
	    }
    clrscr();
    time(&t);
    reverse();
    sprintf(uptime," RUNNING YetAnotherPCBRidge...(V 1.02)  Up Since %s",ctime(&t));
    make_win(2,2,79,24,2,uptime);
    gotoxy(3,3);cprintf("Portions Copyright (C) 1990 Phil Karn\r\n  Copyright (C) 1992 Indian Institute of Technology, Bombay  ");
    restore();
    highvideo();
    gotoxy(30,6);reverse();cprintf("Configuration");restore();
    gotoxy(5,8);cprintf("Number Of Segments  -> %u         Hash Table Flush Time %u Mins ",no_of_ifaces,flush_time/60);
    gotoxy(2,9);cprintf("Segment      Ethernet Address   Int Vect ");
    init_timer();  /* timer interrupt to flush the hash table */

    for(i=0;i<no_of_ifaces;i++){
        gotoxy(3,10+i);
        option[0]='\0';
        prnt_hex(Pktdrvr[i].eaddr,option,6);
        cprintf(" %s        %s      %.2Xh ",Pktdrvr[i].name,option,Pktdrvr[i].intno);
    }
    gotoxy(2,21);  reverse();
    cprintf("  Q - Quit  C - Clear Hash Table  R - Reset Bridge");
    restore();
    _setcursortype(_NOCURSOR);
    while(!done) {        /* endlessly wait and process the packets */
        rxptr = rx[rx_head];
        /* is there any packet in the queue ?  */
        if(rxptr->rcv_flag == SET){ /* There is a packet !! */
            dev = rxptr->dev;
            /* check whether the destination is on the same segment */
#ifdef  DBG
            printf("Checking hash table \n");
#endif
            if((ret_dev = hash_learn(dev))!= -1){
#ifdef  DBG
                printf("Returned from hash_learn : device no %d \n",ret_dev);
#endif
                if(rxptr->dev != ret_dev){
#if 1
                    send_err=send_pkt(Pktdrvr[ret_dev].intno,rxptr->rcv_buffer,rxptr->len);
                    if(send_err == -1){
                        gotoxy(5,20);
                        Pktdrvr[ret_dev].tx_errors++;
                        cprintf("Error Sending packet on %s",Pktdrvr[dev].name);
                    }
                    else
#endif
                    Pktdrvr[ret_dev].pkt_forward++;
                }
                else {
#ifdef  DBG
                    printf(" Packet not forwarded i.e filtered \n");
#endif
                    Pktdrvr[ret_dev].pkt_filtrd++;
                }
            }
            else{
                /* address not in hash table,flood( i.e. multicast) */
#ifdef  DBG
                printf("Address not in hash table flooding \n");
#endif
                brodcst++;
                for(i=0;i<no_of_ifaces;i++){
                    if((Pktdrvr[i].dev != NULLDEV) && ( i!= dev)){
#if 1
                        send_err=send_pkt(Pktdrvr[i].intno,rxptr->rcv_buffer,rxptr->len);
#else
send_err = 0;
#endif
                        if(send_err == -1){
                            gotoxy(5,20);
                            cprintf("Error Sending packet on %s",Pktdrvr[i].name);
                            Pktdrvr[i].tx_errors++;
                        }
                    }
                }
            }
            rxptr->rcv_flag = RESET;
            rx_head++;
            if(rx_head == MAX_QSIZ)  /* wrap around  */
            rx_head = 0;
            rx_count--;
        }
        if(kbhit()!=0){
            switch(toupper(getch())){
            case  'Q':   done = 1; break;
            case  'C':  /* clear hash table  */
                sec=0;
                ticks=182;
                memset(hash_tableptr,0x0,65535);
                disp_statistics();
                break;
            case   'R':  /* reset  the bridge */
                pk_detach(); /* detach the interfaces */
                release_timer();
                clrscr();
                cprintf("              Wait....  Resetting Bridge ");
                sleep(2);
                goto reset_bridge;
            default :    break;
            }
        }
	disp_statistics();
    }  /* while */
    release_timer();
    pk_detach();
    _setcursortype(_NORMALCURSOR);
    window(1,1,80,25);
    clrscr();
    highvideo();
    cprintf("\r\n       YetAnotherPCBRidge Version  1.02 \r\n\r\n");
    normvideo();
    cprintf("Portions Copyright (C) 1990 Phil Karn \r\n");
    cprintf("Copyright (C) 1992 Indian Institute of Technology Bombay\r\n");
    cprintf("Copyright (C) 1996 Russell Nelson\r\n\r\n");
    cprintf("This Program is free software see the file COPYING for\r\n");
    cprintf("details;  NO WARRANTY  see the file COPYING for details\r\n\r\n");
    exit(0);
}

void disp_statistics()
{
    time_t t;
    struct pktdrvr *pp;
    int i;

    t = time(&t);
    gotoxy(2,14);cprintf(" Statistics            %s",ctime(&t));
    gotoxy(1,15);
    cprintf("Seg#  Recvd       Forwded     Filtrd      Broadcst     Lost   TxErr");
    for(i=0;i<no_of_ifaces;i++){
        gotoxy(1,16+i);
        pp=&Pktdrvr[i];
        cprintf(" %-1.1d    %-10.10lu  %-10.10lu  %-10.10lu  %-10.10lu   %-5.5lu  %-5.5lu",
            i,pp->pkt_recvd,pp->pkt_forward,pp->pkt_filtrd,brodcst,
            lost_count,pp->tx_errors);
    }
}


void pk_detach() {
    int i;
    for(i =0;i<no_of_ifaces;i++) if(pk_stop(i) == -1) {
        printf("Error while Releasing\n");
        exit(-1);
    }
}
