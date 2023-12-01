/* File : timer.c  - pc timer interrupt handler    */
/*
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


#define  TIMER_INT	0x1c
#include <dos.h>
#include <time.h>
#include "yapcbr.h"

extern unsigned int ticks;
extern unsigned int sec;
void interrupt (*old_clock_handler)();
void interrupt clock_tick();

/* defined in main.c */
extern unsigned int flush_time;
extern unsigned char *hash_tableptr;
extern unsigned int rcv_count,lost_count,forwd_count,brodcst;


/* this handler is invoked for every clock tick   */

	void interrupt clock_tick()
	{
	  ticks = ticks-1;
	  if(ticks <= 0){
	     ticks = 182;
	     sec+=10;
	     if(sec >=flush_time){
		sec =0;
		/* flush the hash table */
		memset(hash_tableptr,0x0,65535);
	      }
	   }
	   old_clock_handler();
	}

  void init_timer()
  {
  old_clock_handler = getvect(TIMER_INT);
  setvect(TIMER_INT,clock_tick);
  }

  void release_timer()
  {
   setvect(TIMER_INT,old_clock_handler);
  }
