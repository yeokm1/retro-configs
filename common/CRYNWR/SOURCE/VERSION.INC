;***************************************************************************
;*
;*    Copyright (c) 1994
;*    by Digital Equipment Corporation, Maynard, Mass.
;*    All Rights Reserved.
;*
;*    This software is furnished under a license and may be used and  copied
;*    only  in  accordance  with  the  terms  of  such  license and with the
;*    inclusion of the above copyright notice.  This software or  any  other
;*    copies  thereof may not be provided or otherwise made available to any
;*    other person.  No title to and ownership of  the  software  is  hereby
;*    transferred.
;*
;*    The information in this software is subject to change  without  notice
;*    and  should  not  be  construed  as  a commitment by Digital Equipment
;*    Corporation.
;*
;*    Digital assumes no responsibility for the use or  reliability  of  its
;*    software on equipment which is not supplied by Digital.
;*
;***************************************************************************
;
; This file contains the defines which set the driver version number.
;
;
; Maintainers:
;   mf  Maurene Fritz
;   de  Dror Efraty
;
; Revision History:
;
; 21-jun-1994   mf      Change minor version number to 31 (was 30)
; 12-jul-1994   mf      Change minor version number to 31x (special version)
; 28-jul-1994   mf      Change minor version number to 32
; 29-Aug-1994   mf+rv+ymf Change minor to 33
; 18-Oct-1994   rv+ymf  Change minor to 0, Major to 1
; 24-Nov-1994   ymf     Change minor to 01
; 04-Jan-1995   ymf     Change minor to 02
; 14-Feb-1995   ymf     Change minor to 03
; 05-Apr-1995   ymf     Change major to 2, minor to 0
; 03-Aug-1995   ymf     Change minor to 01 (IBM cert)
; 20-Aug-1995   as      Change minor to 02
; 06-Nov-1995   as      Change minor to 03 (Tulip Bug workaround PBL=16)
; 26-Nov-1995   as      Change minor to 10
; 14-Dec-1995   as      Change minor to 11
; 14-Feb-1996   as      Change minor to 20 (DS21142 support)
; 11-Apr-1996   as      Change minor to 21
; 14-Apr-1996   as      Change minor to 22
; 05-May-1996   as      Change minor to 30 (Rx FIFO bug workaround)
; 27-May-1996   as      Change minor to 40 (DS21143 support)
; 23-oct-1996   as      Change minor to 41 (ML6692 support)
; 19-Nov-1996   de      Change minor to 50
; 25-Nov-1996   de      Change module name from version.ash to version.inc
; 24-Apr-1996   de      Change minor to 60
; 17-Sep-1997   de      Change minor to 61
; 03-Feb-1998	md	Change minor to 62

VERSION_MAJOR EQU <'2'>
VERSION_MINOR EQU <'62'>
