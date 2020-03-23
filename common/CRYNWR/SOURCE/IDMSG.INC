;***************************************************************************
;*
;*    Copyright (c) 1994,1995,1996
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
; This module contains macros that define the driver's identication messages.
;
; Maintainers:
;       mf      Maurene Fritz
;       rv      Rivki Vizen
;       gk      Gal Kaplan
;       de      Dror Efraty
;
; Revision History:
;
;   28-jul-1994  mf   Modify 8432 to SMCPWR
;
;   12-Sep-1994  rv   Modify DC21040 to DC21x40
;
;   09-Oct-1994  rv   Change DC21x40 and D21x40 to DC21x4
;
;   15-Aug-1996  gk   Add OEM support for Microdyne
;   25-Nov-1996  de   change in AWK convention.
;                     module name changed from idmsg.ash to idmsg.inc


SIGNON_MESSAGE  MACRO
        DB      'Digital Semiconductor 2104x/2114x 10/100 mbps Ethernet Controller v'
%       DB      VERSION_MAJOR, '.', VERSION_MINOR, CR, LF
;	DB 	'ENGINEERING', CR, LF
        DB      '(C) Copyright 1994-1997 Digital Equipment Corporation.'
        DB      '  All rights reserved.', CR, LF
                ENDM


SIGNON_MESSAGE  MACRO
        DB      'Digital Semiconductor 2104x/2114x 10/100 mbps Ethernet Controller v'
%       DB      VERSION_MAJOR, '.', VERSION_MINOR, CR, LF
;	DB 	'ENGINEERING', CR, LF
        DB      '(C) Copyright 1994-1997 Digital Equipment Corporation.'
        DB      '  All rights reserved.', CR, LF
                ENDM



