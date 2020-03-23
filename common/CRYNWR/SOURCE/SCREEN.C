/* File :  screen.c */

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

#include<stdio.h>
#include<conio.h>
#include<dos.h>
#include "yapcbr.h"

int hline(int startx,int starty,int endx,char line_char);
int vline(int startx,int starty,int endy,char line_char);
void make_win(int x1,int y1,int x2,int y2, int box_type, char *mesg);
void prnt_hex(unsigned char  *instr,unsigned char *outstr,int len);


/* Function to draw boxes
 left_top_col_no, left_top_row_no, right_bot_col_no, right_bot_rwo_no,
 style : 1 single line , 2 double line  */
int box (int tlx,int tly,int brx,int bry,int style)
{
    int w,h;
    char hline_ch,vline_ch,tlc,trc,brc,blc;
    if (style==1||style==0)
    {
         hline_ch = '\xC4';
	 vline_ch='\xB3';
	 tlc='\xDA';
	 trc='\xBF';
	 brc='\xD9';
	 blc='\xC0';
         }
    else if (style==2)
         {
	 hline_ch='\xCD';
	 vline_ch='\xBA';
	 tlc='\xC9';
	 trc='\xBB';
	 brc='\xBC';
	 blc='\xC8';
         }
   else
        {
	 return (0);
	 }
    gotoxy (tlx,tly);
    putch(tlc);
    w=hline(tlx+1,tly,brx-1,hline_ch);
    putch(trc);
    h=vline (brx,tly+1,bry-1,vline_ch);
    gotoxy(brx,bry);
    putch(brc);
    hline(brx-1,bry,tlx+1,hline_ch);
    gotoxy(tlx,bry);
    putch(blc);
    vline(tlx,bry-1,tly+1,vline_ch);
    return (w*h);
}

/* Function to draw Horizontal lines */

int hline (int startx, int starty, int endx, char line_char)
{
    int i;
    gotoxy (startx,starty);
    if (startx==endx) return (0);
    if (startx<endx)
    {
	 for (i=startx;i<=endx;i++)
	      putch(line_char);
	 return (i-startx);
    }
    gotoxy (endx,starty);
    for (i=endx;i<=startx;i++)
	 putch (line_char);
    return (i-endx);
}


/*  Function to draw vertical lines */

int vline (int startx, int starty, int endy, char line_char)
{
    int i;
    if (starty==endy) return (0);
    if (starty < endy )
    {
	 for (i=starty;i<=endy;i++)
	      {
	      gotoxy (startx,i);
	      putch (line_char);
	      }
	 return (i-starty);
    }
    for (i=endy;i<=starty;i++)
    {
	 gotoxy (startx,i);
	 putch (line_char);
    }
    return (endy-i);
}

/* read a keystroke without echo, reads extended keys as well */
 int read_key()
 {
   int ch;
   ch=getch();
   if(ch==0x00)ch=getch();
   return(ch);
 }


/* x1,y1 top left and x2,y2 bottom right corner, box type - single line(1)
  or double line (2) mesg is the message to be displayed on the top
  of the window
*/
void make_win(int x1,int y1,int x2,int y2, int box_type, char *mesg)
{
int center;

restore();
highvideo();
window(1,1,80,25);
box(x1,y1,x2,y2,box_type);
if(mesg != NULL){
   center=x1+((x2- x1)-strlen(mesg))/2;
   gotoxy(center,y1);
   cputs(mesg);
   lowvideo();
}
window(x1+1,y1+1,x2-1,y2-1);
clrscr();
}


/* Given a string in hex-ascii (instr)  appends the formatted string to
  outstr  */
  void prnt_hex(unsigned char *instr,unsigned char *outstr,int len)
  {
  register int i;
  for(i=0;i<len;i++)
     sprintf(outstr+strlen(outstr),"%.2X",instr[i]);
  strcat(outstr," ");
  }
