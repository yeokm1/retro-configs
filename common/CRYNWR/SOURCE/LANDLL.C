//********************************************************************************
// Module: LANDLL.C
// Purpose: Packet Driver DLL interface.
//
// Author: Bill Simpson
// Date: 11/4/93
//********************************************************************************
#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <stddef.h>
#include <time.h>
#include <dos.h>
#include <windows.h>


//** DLL Interface functions **
#pragma argsused
int FAR PASCAL LibMain(HINSTANCE hInstance,WORD nDataSegment,WORD nHeapSize,
   LPSTR sCmdLine)
{
   return 1;
};


#pragma argsused
int FAR PASCAL WEP(BOOL bSystemExit)
{
   // De-initializaion of the DLL   (Windows Exit Procedure (WEP))
   return 1;
};
