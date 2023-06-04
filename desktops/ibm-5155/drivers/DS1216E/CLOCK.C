/****************************************************************/
/*								*/
/*         --------------------------------------------         */
/*--------- DS-1216E SmartWatch Real-Time Clock Driver ---------*/
/*         --------------------------------------------         */
/*                                                              */
/*    Copyright (C) 1986, by Zenith Data Systems Corporation    */
/*								*/
/*		  Last Update: MJF: 15 May 86			*/
/*                                                              */
/****************************************************************/

/****************************************************************/
/*	This code contains a driver program for the DS-1216E	*/
/* SmartWatch real-time clock.  The program can set and display	*/
/* the contents of the SmartWatch chip, and will also set the	*/
/* current MS-DOS date and time.  The syntax is:		*/
/*								*/
/*    	    CLOCK [<MM/DD/YY>] [<HH:MM:SS>] [<DAY>]		*/
/* Where:							*/
/*    MM/DD/YY: Standard date.  The YEAR is optional - if	*/
/*		not entered, the current year from the clock	*/
/*		chip will be used.  Otherwise, years from 80-99	*/
/*		are assumed to mean 1980-1999, and years from	*/
/*		00-79 mean 2000-2079.  Note that you can use	*/
/*	        either slashes (/) or dashes (-) as the date	*/
/*		separator.					*/
/*    HH:MM:SS:	Standard time of day.  If seconds are omitted,	*/
/*		the actual seconds value will be set to 0.	*/
/*		Fractional seconds are always set to 0.		*/
/*    DAY:	The day-of-week, from Sunday-Saturday.  The	*/
/*		syntax requires only that the first two chars	*/
/*		of the day-name be entered, but additional	*/
/*		characters are accepted (ex, TU, TUE, TUES,	*/
/*		TUESD, TUESDA, or TUESDAY are OK).		*/
/*								*/
/* Parameters may be entered in any order (Date, Time, or	*/
/* Day first).  Any parameter which is not entered will be	*/
/* read from the time clock.					*/
/*								*/
/*	This code was written using the CI C-86 C Compiler,	*/
/* and the accompanying CLOCKIO.ASM file was written using the	*/
/* MASM assembler.  To build CLOCK, the following commands	*/
/* should be used:						*/
/*	CC CLOCK			{Compile CLOCK.C}	*/
/*	MASM CLOCKIO;			{Assemble CLOCKIO.A}	*/
/*	LINK CLOCK+CLOCKIO,,/map,c86s2s	{Build CLOCK.EXE}	*/
/*								*/
/* In its present state, this code may be run on the following	*/
/* machines without modification:				*/
/*								*/
/*	Z-100, Z-150, Z-160, Z-138, Z-148, and the Z-158	*/
/****************************************************************/

#include "stdio.h"			/* Include standard C definitions */

#define TRUE		1		/* Logical TRUE value */
#define FALSE		0		/* Logical FALSE value */

/****************************************************************/
/* S M A R T W A T C H   R E G I S T E R   D E F I N I T I O N S*/
/****************************************************************/
#define REGS		8		/* Number of clock registers */
#define FSECONDS	0x00		/* Decimal Seconds register */
#define SECONDS		0x01		/* Seconds register */
#define MINUTES		0x02		/* Minutes register */
#define HOURS		0x03		/* Hours register */
#define DAY		0x04		/* Day of the week */
#define     RESET	0x10		/* Reset-disable flag in chip */
#define DATE		0x05		/* Date in the month */
#define MONTH		0x06		/* Month number */
#define YEAR		0x07		/* Current year */


/****************************************************************/
/*	T I M E   S T R U C T U R E   D E F I N I T I O N	*/
/****************************************************************/
struct TIME {
    unsigned char reg;			/* Chip register */
    unsigned char min;			/* Minimum acceptable value */
    unsigned char max;			/* Maximum acceptable value */
    };
struct TIME time[3] = { {HOURS,   0, 0x23},	/* Hours */
			{MINUTES, 0, 0x59},	/* Minutes */
			{SECONDS, 0, 0x59} };	/* Seconds */
struct TIME date[3] = { {MONTH,   1, 0x12},	/* Month */
			{DATE,    1, 0x31},	/* Date */
			{YEAR,    0, 0x99} };	/* Year */


/****************************************************************/
/*		    G L O B A L   A R R A Y S			*/
/****************************************************************/
unsigned char clock[REGS];		/* Define clock I/O buffer */
char *day_name[7] = {"Sunday",   "Monday", "Tuesday", "Wednesday",
		     "Thursday", "Friday", "Saturday" };


/****************************************************************/
/* main: (argc, argv)						*/
/*								*/
/*	Main is the primary entry point into the clock program.	*/
/* It parses the input command line for time, date, and day	*/
/* entry, then writes the information into the local clock	*/
/* buffer which is used by the various time set/display sub-	*/
/* routines.							*/
/****************************************************************/
main(argc, argv)
    int argc;  char *argv[];
{   int i, j;  char present, mod, *timeptr;
    mod = FALSE;				/* Initially, no changes made */
    timeptr = NULL;				/* Flag that time not being set */
    readclk(clock);				/* Read time/date from SmartWatch */
    present = FALSE;				/* Assume clock is not present */
    for (i = 0;  i < REGS;  ++i) {		/* Check presence of real-time clock */
	if (clock[i] && clock[i] != 0xFF) present = TRUE; /* If valid data, clock OK */
	}
    if (!present) {				/* ERROR - can't find clock! */
	invalid("response from Real-Time Clock");
	exit(1);				/* Display error, exit to DOS */
	}
    clock[DAY] &= 0x0F;				/* Mask out control flags */
    for (i = 1;  i < argc;  ++i) {
	if (argv[i][0] == '?') help();		/* Show program help */
	else if (index(argv[i], '/') || index(argv[i], '-')) { /* Setting date */
	    for (j = 0;  j < strlen(argv[i]);  ++j) {
		if (argv[i][j] == '-') argv[i][j] = '/'; /* Allow MM-DD-YY */
		}
	    if (!get_time(date, argv[i], '/')) invalid("date");
	    else mod = TRUE;			/* Flag changed date */
	    }
	else if (index(argv[i], ':')) {		/* Setting time */
	    if (!(j=get_time(time, argv[i], ':'))) invalid("time");
	    else {				/* Valid time entered */
		mod = TRUE;			/* Flag changed time */
		timeptr = argv[i];		/* Record the position of the time */
		clock[FSECONDS] = 0;		/* User can't change 1/100ths seconds */
		if (j == 2) clock[SECONDS] = 0;	/* Set seconds to 0 if not entered */
		}
	    }
	else {
	    for (j = 0;  j < 7;  ++j) {
		if (strlen(argv[i]) >= 2 && strnmatch(argv[i], day_name[j])) {
		    clock[DAY] = j + 1;		/* Record entered day in binary */
		    break;
		    }
		}
	    if (j >= 7) invalid("day-of-week");
	    else mod = TRUE;			/* Flag changed day-of-week */
	    }
	}
    if (mod) {					/* Clock has been modified */
	clock[DAY] |= RESET;			/* Ensure SmartWatch ignores RESET! */
	if (timeptr) {				/* Setting time - prompt user to set */
	    putstr("Press Enter to set the time to ");
	    putstr(timeptr);			/* Display prompt and time! */
	    putstr("...");
	    while (getchar() != '\n') {		/* Wait until CR entered */
		}
	    putstr("\n");			/* Write a blank line following prompt */
	    }
	writeclk(clock);			/* Record the new date and time */
	}
    sdostim(clock);				/* Send the time to DOS */
    disp_time(clock);				/* Display the new time and date */
    } /* main */


/****************************************************************/
/* disp_time: (clock)						*/
/*								*/
/*	Disp_Time displays the current time and date, along	*/
/* with the day of week, in a human-readable format.		*/
/*								*/
/* Input:							*/
/*	Clock: Pointing to a buffer holding the BCD-encoded	*/
/*	       date and time information.			*/
/****************************************************************/
disp_time(clock)
    unsigned char clock[REGS];
{   char buff[80], day;
    strcpy(buff, "\t  Date:  ");		/* Place prompt at start of line */
    if (day = (clock[DAY] & 0x07)) {		/* Don't accept day of 0! */
	strcat(buff, day_name[day - 1]);	/* Insert the day name */
	strcat(buff, ", ");			/* Insert day->month separator */
	}
    conv_time(buff, clock[MONTH], '/');		/* Insert the month */
    conv_time(buff, clock[DATE], '/');		/* Insert the date */
    conv_time(buff, clock[YEAR]>=0x80 ? 0x19 : 0x20, 0); /* Insert century */
    conv_time(buff, clock[YEAR], ' ');		/* Insert the year */
    strcat(buff, "   Time:  ");			/* Insert time prompt */
    conv_time(buff, clock[HOURS], ':');		/* Insert the hours */
    conv_time(buff, clock[MINUTES], ':');	/* Insert the minutes */
    conv_time(buff, clock[SECONDS], '.');	/* Insert the seconds */
    conv_time(buff, clock[FSECONDS], ' ');	/* Insert fractional seconds */
    putstr(buff);				/* Display date and time! */
    } /* disp_time */


/****************************************************************/
/* conv_time: (buff, value, terminator)				*/
/*								*/
/*	Convtime is called to convert a packed-BCD digit pair	*/
/* into an ASCII string with a following terminator.		*/
/*								*/
/* Input:							*/
/*	buff:	Pointer to buffer to output to (CATed to buff)	*/
/*	value:	Packed-BCD digit to write to buffer 		*/
/*	terminator: Character to follow digits of value in buff	*/
/****************************************************************/
conv_time(buff, value, terminator)
    char *buff;  int value;  char terminator;
{   buff = &buff[strlen(buff)];			/* Point to end of buffer */
    *buff++ = (value >> 4) + '0';		/* Convert first digit */
    *buff++ = (value & 0x0F) + '0';		/* Convert second digit */
    if (terminator) *buff++ = terminator;	/* Put terminator in string */
    *buff++ = '\0';				/* Put null at end of string */
    } /* conv_time */


/****************************************************************/
/* get_time: (ts, str, endchar)					*/
/*								*/
/*	Get_Time is called to translate an ASCII string into	*/
/* either the date or time.  It is passed a pointer to the	*/
/* structure defining the allowable entry values, a pointer to	*/
/* the string, and the separator character.			*/
/*								*/
/* Input:							*/
/*	ts:	Pointer to a TIME structure (date/time)		*/
/*	str:	Pointer to string to be read			*/
/*	endchar:Terminating character in-between fields		*/
/*								*/
/* Output:							*/
/*	Number of fields entered (0 if error found)		*/
/****************************************************************/
get_time(ts, str, endchar)
    struct TIME *ts;  char *str, endchar;
{   int i, j, value[3];  struct TIME *t;
    t = ts;						/* Point to first structure */
    for (i = 0;  i < 3;  ++i, ++t) {			/* For each field of time/date... */
	if (!isdigit(*str)) return(FALSE);		/* Invalid digit found! */
	value[i] = *str++ - '0';			/* Get this digit in binary */
	if (isdigit(*str)) {				/* Get second digit of a pair */
	    value[i] = (value[i] << 4) | (*str++ - '0');/* Add in second digit */
	    }
	if (value[i] < t->min || value[i] > t->max) return(0);
	if (!(*str == endchar && i < 2) &&		/* Enforce valid separators */
	    !(!*str && i >= 1)) return(0);		/* Have to have at least 2 entries! */
	if (!*str) break;				/* Finished when at end-of-string */
	++str;
	}
    for (j = 0; j <= i; ++j, ++ts) {			/* Copy values to RAM */
	clock[ts->reg] = value[j];			/* ...from local buffer */
	}
    return(i + 1);					/* Return number of entered fields */
    } /* get_time */


/****************************************************************/
/* strnmatch(s1, s2)						*/
/*								*/
/* 	Strnmatch returns 0 if two strings are equivalent to the*/
/* length of the shorter string, ignoring case.			*/
/*								*/
/* Input:							*/
/*	s1:	Pointer to first string to be compared		*/
/*	s2:	Pointer to second string to be compared		*/
/****************************************************************/
strnmatch(s1, s2)
    char *s1, *s2;
{   while (toupper(*s1) == toupper(*s2) && *s1) ++s1, ++s2; /* Compare the strings */
    return(*s1 == '\0' || *s2 == '\0');		/* Return true if = to end of a string */
    } /* strnmatch */


/****************************************************************/
/* invalid(item)						*/
/*								*/
/*	Invalid is called when an invalid entry has been made.	*/
/* It will print an error message, beep, and return to the	*/
/* caller.							*/
/*								*/
/* Input:							*/
/*	item: Pointer to string to be displayed (which will be	*/
/*	      prefixed with "Invalid").				*/
/****************************************************************/
invalid(item)
    char *item;
{   putstr("Invalid ");			/* Print error prefix */
    putstr(item);			/* Display the error cause */
    putstr("!\007\n");			/* Beep and display newline */
    } /* invalid */


/****************************************************************/
/* help:()							*/
/*								*/
/*	Help is called to display a syntax message for use of	*/
/* the setclock program.					*/
/****************************************************************/
help()
{   putstr("\nClock: SmartWatch Set / Display Program, Version 1.1\n");
    putstr(" Copyright (C) 1986 Zenith Data Systems Corporation\n\n");
    putstr("  Syntax:  CLOCK [<MM/DD/YY>] [<HH:MM:SS>] [<DAY>]\n");
    putstr("  Example: CLOCK  11/18/86  12:00:00  Friday\n\n"); 
    } /* help */


/****************************************************************/
/* putstr(str)							*/
/*								*/
/*	Putstr write a string to the console.  The routine is	*/
/* similar to puts, but it does not write a trailing newline	*/
/* after displaying the string.					*/
/****************************************************************/
putstr(str)
    char *str;
{   while (*str) putchar(*str++);
    } /* putstr */

