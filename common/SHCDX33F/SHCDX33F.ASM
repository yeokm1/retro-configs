;
; SHCDX33F -- "SHSUCDX V3.03F" by Jack R. Ellis, 2-Aug-2012.
;
; Derived from V3.03 SHSUCDX by Jason Hood.   All old code "macros" are
; gone, and other changes have been included, so SHCDX33F now assembles
; PROPERLY and fully-optimized (with 32-bit OR 16-bit NASM!) with only:
;
;        NASM -o SHCDX33F.COM -l SHCDX33F.LST SHCDX33F.ASM
;
; SHCDX33F    2-Aug-12   Directory or non-directory input flagged, for
;			   directory-only caching by UDVD2 or UIDE.
; SHCDX33E    9-Jul-09   /I switch added per user request.
; SHCDX33D   30-May-09   Drive-Not-Ready stack ERROR fixed.
; SHCDX33C    9-Nov-06   Stack size increased.
; SHCDX33B   20-Oct-06   Fixed "No Drives Assigned" message output.
; SHCDX33A   26-Dec-05   Added equivalent memory-error correction from
;			   Jason Hood's V3.03 SHSUCDX.  Thanks, Jason!
; SHCDX32D   19-Dec-05   Tables & buffers 32-bit aligned for UltraDMA.
; SHCDX32C   29-Jun-05   NO inline code-mods, /QQ /V omitted, smaller.
; SHCDX32B   29-May-05   Option message fixed, Help message shortened.
; SHCDX32A   28-May-05   Initial release.
;
;*****************************************************************************
;
; SHSUCDX Version 3.00
; Jason Hood, September to November, 2004.
; http://shsucdx.adoxa.cjb.net    <jadoxa@yahoo.com.au>
;
; v3.01, March, 2005.
; v3.02, April/May, 2005.
; v3.03, December, 2005.
;
; This version is a rewrite of SHSUCDX V1.4b and my version 2 into NASM.
; The resident size is now less than 6K for one drive.
; Acknowledgement to Ralf Brown's Interrupt List.
;
; jmh 030602 - added VARBLKSIZE conditional to force use of variable block
;	       sizes; use a fixed 2K if not defined.
; jmh 040802 - converted to NASM, added stuff from redir.h.
; jmh 041112 - added CDROOT conditional to use \\D.\A. form.
; jmh 041117 - removed VARBLKSIZE
;
; revised March 1, 1994
;
;*****************************************************************************
;
; SHSUCDX V1.4b
; (c)John H. McCoy, 1994 - 2000 Sam Houston St. Univ., TX 77341-2206
; <csc_jhm@shsu.edu>
;
; SHSUCDX is an un-loadable CD-ROM redirector substitute for MSCDEX.  V1.1a
; supports up to 10 CD drives.  Each drive is single sector buffered and the
; last 10 directory entries are cached.  This version finally fixes (I hope)
; a problem with handling some directory entries.  It has also been changed
; to allow lower case characters in directory and file names.  LC characters
; are not valid, but some NT/Win95 mastering programs put them in.
;
; About 17K of RAM is needed to install SHSUCDX.  The resident size for a
; single drive is less than 11K.  Each additional drive increases the size
; by 2500 bytes.  Multiple drivers are supported.  The driver name, drive
; letter, drive unit and number of drives for each driver can be specified
; on the command line.
;
; SHSUCDX does not attempt to read the CD-ROM until an access request is
; made.  Thus, the CD drive need not be ready when SHSUCDX is loaded.  If
; more than 7 seconds elapse between requests, a media check is made.  The
; buffers and cache are flushed and the CD is re-read only if the driver
; reports a media change.  This reduces network traffic but can result in
; missing a "fast" media change on a local drive.
;
; When SHSUCDX unloads it marks the drives it used as invalid.
;
; SHSUCDX has been run under MS-DOS 4, 5, 6 and 7 stand-alone, Windows 3.1,
; and in a specific DOS window under OS2.   A CD-ROM driver that supports
; the CD-ROM extensions must be loaded before SHSUCDX.  By default, SHSUCDX
; looks for a driver named SHSU-CDN.
;
; SHSUCDX is a copyright-reserved, free-use program.
;
; Microsoft has not documented the redirector functions.  I have borrowed
; from and am particularly indebted to the authors of:
;
;    A CD-ROM redirector for HighSierra and ISO 9660 disks.
;       Jim Harper, DDJ, March 1993
;    Inside the ISO-9660 Filesystem Format
;       William and Lynne Jolitz, DDJ, December 1992
;    Undocumented DOS, Chapter 4.
;       Andrew Schulman, et. al, Addison Wesley, 1990
;
; Written for MASM 6.0b, C functions use MSC 5.1 compiler.
;
;*****************************************************************************

	cpu	8086	;Allow only 8086 commands.
%define NM 'SHCDX33F'	;Our "name" and "date" for messages.
%define DT '2-Aug-2012'
%define	s short		;Default conditional jumps to "short".
%define	CR 00Dh		;ASCII carriage-return.
%define	LF 00Ah		;ASCII line-feed.
%define HS		;If defined, include High Sierra support.
%define CDIMAGE 	;If defined, include Image-on-CD support.
%define JOLIET		;If defined, use Joliet (required by DOSLFN 0.40a).
;%define CDROOT 	;If defined, use the CD root form of "\\D.\A.\".
;
; Macro "jccl" (jump condition-code LONG).  Generates a 5-byte sequence
;   (2 commands) for cases where a 2-byte "short" jump is out of range.
;
;   Parameter 1:  Desired "jmp" condition code.
;   Parameter 2:  Target label, if condition code is met.
;
;   Example:  jccl e, Label  ==>  jne s  $+5
;                                 jmp    Label
;
%imacro jccl 2.nolist
	j%-1 s	$+5
	jmp	%2
%endmacro
;
; Various useful DOS structures
;
; List of Lists
;
struc LoL
		resd	 1
  .CurSFT	resd	 1
		resd	 1
		resd	 1
		resw	 1
		resd	 1
  .CDS		resd	 1
		resd	 1
		resw	 1
		resb	 1
  .LastDrive	resb	 1
endstruc
;
; Current Directory Structure
;
struc CDS
  .CurrPath	resb	67
  .Flags	resw	 1
		resd	 1
  .Redir	resd	 1
		resw	 1
  .RootOff	resw	 1
endstruc
;
; Offsets in the CDS File Name
;
%ifdef CDROOT
  %define DriveOff	 2
  %define RootSlashOff	 7
%else
  %define DriveOff	 0
  %define RootSlashOff	 2
%endif
;
; System File Table
;
struc SFT
  .RefCnt	resw	 1		; Reference count
  .Mode 	resw	 1		; Open Mode
  .DirAttrib	resb	 1
  .Flags	resw	 1
  .DCB		resd	 1		; Device control block
  .Cluster	resw	 1		; Initial cluster
  .HHMMSS	resw	 1		; Hour, Min, Sec/2
  .YYMMDD	resw	 1		; Year, Month, Day
  .FilSiz	resd	 1		; file size/EOF location
  .FilPos	resd	 1		; Current file position
  .FBN		resd	 1		; first block of file extent
  .Owner	resw	 1
  .DirIndex	resb	 1		; directory index
  .Name 	resb	11		; file name
  .Unknown	resb	 4
  .OwnerMach	resw	 1		; machine number of owner
  .OwnerPSP	resw	 1		; psp of owner task
  .Status	resw	 1
endstruc
;
; DOS Search Data Block
;
struc SDB
  .DriveLet	resb	 1		; Drive Letter
  .TemPlate	resb	11		; Search template
  .SAttr	resb	 1		; Search attribute
  .Entry	resw	 1		; Entry Count within dir
  .ParentBlk	resd	 1		; Blk # of start of parent
  .ParentSize	resw	 1		; Size of parent, in blocks
endstruc
;
; DOS Found Data Block
;
struc FDB
  .FName	resb	11		; Found Filename
  .Fattr	resb	 1		; Attr of found file
  .Reserved	resb	10
  .FTime	resd	 1
  .Cluster	resw	 1
  .FSize	resd	 1
endstruc
;
; DOS return codes (actually documented, here for convenience).
;
%define INVALIDFUNC	0x01
%define FILENOTFOUND	0x02
%define PATHNOTFOUND	0x03
%define ACCESSDENIED	0x05
%define INVALIDDRIVE	0x0f
%define NOMOREFILES	0x12
%define DRIVENOTREADY	0x15

%define PATHSEPARATOR	'\'
;
; Stack frame (interrupt)
;
struc frame
  fr_OldBP	resw	 1
  fr_RetAddr	resd	 1
  fr_Flags	resw	 1
  fr_Parm1	resw	 1
endstruc
;
; SHSUCDX Directory Entry (arranged to have the same offsets as the FDB)
;
struc DirEnt
  .FName	resb	11
  .Fattr	resb	 1
  .ParentBlk	resd	 1
  .BlkNo	resd	 1
  .Forw 	resw	 1
  .FTime	resw	 1
  .FDate	resw	 1
  .Back 	resw	 1
  .FSize	resd	 1
endstruc
;
; Drive Entry
;
struc DrvEnt
  .DevHdrp	resd	 1
  .Strategyp	resd	 1
  .Interruptp	resd	 1
  .No		resb	 1
  .Unit 	resb	 1
  .Type 	resb	 1
  .Bufp 	resw	 1
  .LastAccess	resw	 1
  .BufBlkNo	resd	 1
  .VolSize	resw	 1
  .RootEnt	resb	DirEnt_size	; volume label is stored in FName
		resb	 3		; ALIGNMENT bytes for UltraDMA!!!
endstruc
;
; Request Header
;
struc rh
  .Length	resb	 1		; header size in bytes
  .SubUnit	resb	 1		; MSCDEX fills in CD drive unit
  .Command	resb	 1		; device command code
  .Status	resw	 1		; device command status
  .Reserved	resb	 8
endstruc

struc rhIOCTL
  .Header	resb	rh_size 	; RH common
  .MediaDesc	resb	 1
  .CBPtr	resd	 1
  .Bytes	resw	 1		; Control Block length
  .StartSector	resw	 1
  .VolIdPtr	resd	 1
endstruc

struc rhReadLong
  .Header	resb	rh_size 	; RH common
  .AddrMode	resb	 1
  .Bufp 	resd	 1
  .Count	resw	 1
  .StartBlk	resd	 1
  .ReadMode	resb	 1
  .ISize	resb	 1
  .ISkip	resb	 1
endstruc

rhcmdIOCTL_In	equ	 3
rhcmdIOCTL_Out	equ	12
rhcmdReadLong	equ    128
;
; CD Rom types
;
%define UNKNOWN 	-1
%define HIGHSIERRA	24		; the Flags offset
%define ISO9660 	25
;
; Device Driver return status codes
;
%define DEV_DONE		0x0100
%define DEV_BUSY		0x0200
%define DEV_ERROR		0x8000
;
; ISO & HSC common CD ROM Directory offsets
;
%define ExAttroff	 1
%define Blkoff		 2
%define Sizeoff 	10
%define Dateoff 	18
%define FIDLenoff	32
%define Nameoff 	33

%define resm(from,to) resb (to-from+1)	; multi-resb field definition

struc Date_Time
	resb Dateoff	; (offset into dir entry)
  .Yr	resb 1		; base 1900
  .Mth	resb 1		; 1-12
  .Day	resb 1		; 1-31
  .Hr	resb 1		; 0-23
  .Min	resb 1		; 0-59
  .Sec	resb 1		; 0-59
endstruc
;
; ISO9660 description based upon standard
;
struc isoVol
  .Type 		resb	1	; 1
  .ID			resm(  2,  6)	; "CD001"
  .Version		resb	1	; 1
  .Unused1		resb	1	; 00
  .SysID		resm(  9, 40)	;  32 a chars
  .VolID		resm( 41, 72)	;  32 d chars
  .Unused2		resm( 73, 80)	; 00
  .VolSizeLSB		resd	1
  .VolSizeMSB		resd	1
  .Unused3		resm( 89,120)	; 00
  .SetSizeLSB		resw	1
  .SetSizeMSB		resw	1
  .SetSeqLSB		resw	1
  .SetSeqMSB		resw	1
  .BlkSizeLSB		resw	1
  .BlkSizeMSB		resw	1
  .PathTabSizeLSB	resd	1
  .PathTabSizeMSB	resd	1
  .PathTabLocLSB	resd	1
  .PathTabAltLocLSB	resd	1
  .PathTabLocMSB	resd	1
  .PathTabAltLocMSB	resd	1
  .DirRec		resm(157,190)
  .VolSetID		resm(191,318)	; 128 d chars
  .PubID		resm(319,446)	; 128 a chars
  .PrepID		resm(447,574)	; 128 a chars
  .AppID		resm(575,702)	; 128 a chars
  .CopyRightID		resm(703,739)	;  37 d chars
  .AbstractID		resm(740,776)	;  37 d chars
  .BiblioID		resm(777,813)	;  37 d chars
  .CreateDate		resm(814,830)	; YYYYMMDDHHMMSSssZ
  .ModDate		resm(831,847)	; YYYYMMDDHHMMSSssZ
  .ExpDate		resm(848,864)	; YYYYMMDDHHMMSSssZ
  .EffDate		resm(865,881)	; YYYYMMDDHHMMSSssZ
  .StdVer		resb	1	; 1
  .Reserved		resb	1	; 00
endstruc

struc isoDir
  .RecLen		resb	1
  .ExAttrRecLen 	resb	1
  .ExtLocLSB		resd	1
  .ExtLocMSB		resd	1
  .DataLenLSB		resd	1
  .DataLenMSB		resd	1
  .Date 		resb	(Date_Time.Sec + 1 - Date_Time.Yr)
  .Offset		resb	1	; -48 to +52, 15 min increments from GMT
  .Flags		resb	1
  .FileUnitSize 	resb	1
  .InterLeave		resb	1
  .VolSeqNoLSB		resw	1
  .VolSeqNoMSB		resw	1
  .FIDLen		resb	1
  .FileID		resb	1	; d chars
endstruc
;
; High Sierra description based upon "Inside the ISO-9660 Filesytem Format",
;  Jolitz & Jolitz, DDJ, Dec. 1992.
;
struc hsVol
  .LbnLSB		resd	1
  .LbnMSB		resd	1
  .Type 		resb	1	; 1
  .ID			resm( 10, 14)	; "CDROM"
  .Version		resb	1	; 1
  .Reserved1		resb	1
  .SysID		resm( 17, 48)	;  32 a chars
  .VolID		resm( 49, 80)	;  32 d chars
  .Reserved2		resm( 81, 88)
  .VolSizeLSB		resd	1
  .VolSizeMSB		resd	1
  .Reserved3		resm( 97,128)
  .SetSizeLSB		resw	1
  .SetSizeMSB		resw	1
  .SetSeqLSB		resw	1
  .SetSeqMSB		resw	1
  .BlkSizeLSB		resw	1
  .BlkSizeMSB		resw	1
  .PathTabSizeLSB	resd	1
  .PathTabSizeMSB	resd	1
  .PathTabLocLSB	resd	1
  .PathTabAlt1LocLSB	resd	1
  .PathTabAlt2LocLSB	resd	1
  .PathTabAlt3LocLSB	resd	1
  .PathTabLocMSB	resd	1
  .PathTabAlt1LocMSB	resd	1
  .PathTabAlt2LocMSB	resd	1
  .PathTabAlt3LocMSB	resd	1
  .DirRec		resm(181,214)
  .VolSetID		resm(215,342)	; 128 d chars
  .PubID		resm(343,470)	; 128 a chars
  .PrepID		resm(471,598)	; 128 a chars
  .AppID		resm(599,726)	; 128 a chars
  .CopyRightID		resm(727,758)	;   32 d chars
  .AbstractID		resm(759,790)	;   32 d chars
  .CreateDate		resm(791,806)	; YYYYMMDDHHMMSSss
  .ModDate		resm(807,822)	; YYYYMMDDHHMMSSss
  .ExpDate		resm(823,838)	; YYYYMMDDHHMMSSss
  .EffDate		resm(839,854)	; YYYYMMDDHHMMSSss
  .StdVer		resb	1
  .Reserved4		resb	1	; 00
endstruc

struc hsDir
  .RecLen		resb	1
  .ExtRecLen		resb	1
  .ExtLocLSB		resd	1
  .ExtLocMSB		resd	1
  .DataLenLSB		resd	1
  .DataLenMSB		resd	1
  .Date 		resb	(Date_Time.Sec + 1 - Date_Time.Yr)
  .Flags		resb	1
  .Reserved1		resb	1
  .InterLeave		resb	1
  .SkipFactor		resb	1
  .VolSeqNoLSB		resw	1
  .VolSeqNoMSB		resw	1
  .FIDLen		resb	1
  .FileID		resb	1
endstruc

%define A_SUBDIR	10h
;
; Redirector equates
;
%define REDIR		11h		; make these defines so mpx can
%define InstallChk	00h		;  combine into one word
ChDir		equ	05h		; these must be EQU for creating
Close		equ	06h		;  the table
Read		equ	08h
GetSP		equ	0ch
GetFA	 	equ	0fh
Open		equ	16h
FindFirst	equ	1Bh
FindNext	equ	1Ch
Seek		equ	21h
PathName	equ	23h
EOpen		equ	2eh
NoRedir 	equ	0ffh		; equate required for table terminator
;
; MSCDEX equates
;
%define MSCDEX		15h
%define MSCDEX_Q	0DADAh		; Query
%define MSCDEX_R	0ADADh		; Return
;
; SMARTDrive equate
;
%define SMARTDRV_Q	0BABEh
;
; DOSLFN equates
;
%define DOSLFN_Q	9877h
%define DOSLFN_R	8766h
;
; Return codes
;
%define RC_DOS		254		; unsupported version of DOS
%define RC_INSTALLED	253		; already installed
%define RC_CD		252		; can't find CD driver
%define RC_UNIT 	251		; unit doesn't exist
%define RC_LETTER	250		; no available drive letter
%define RC_DRIVE	249		; no drives assigned
%define RC_MEM		248		; not enough memory
%define RC_UNINST	247		; can't uninstall
%define RC_OPT		246		; problem with option
%define RC_OK		0		; help, tilde/ro, successful uninstall
					; 1..32 first drive number (A=1)

  %assign COMPILE_FLAG 03A01h
%ifdef CDROOT
  %assign COMPILE_FLAG COMPILE_FLAG+0002h
%endif
%ifdef HS
  %assign COMPILE_FLAG COMPILE_FLAG+0004h
%endif
%ifdef JOLIET
  %assign COMPILE_FLAG COMPILE_FLAG+0008h
%endif
%ifdef CDIMAGE
  %assign COMPILE_FLAG COMPILE_FLAG+0010h
%endif

%define MAXDRIVES	8
%define CACHEENTRIES	10
%define CACHESIZE	CACHEENTRIES * DirEnt_size
%define SECTORSIZE	2048
%define SECTORSHIFT	11

	org	100h
	jmp	Begin
;
; Copyright Message (Credits).
;
  db	CR			; overwrite JMP if TYPEd

CopyrightMsg

  db	CR, NM,', ',DT,'.   Based on V3.03 SHSUCDX by Jason Hood and'
  db	CR, '    V1.4b SHSUCDX by John H. McCoy, Sam Houston State University.'
  db	001h,01Ah,0
;
; Initialization Options Table.
;
Options dw Opt?
		db '?'
	dw OptC
		db 'C'
	dw DoDrivr
		db 'D'
	dw OptIgn		;Ignore MSCDEX expanded-memory.
		db 'E'
	dw OptI
		db 'I'
	dw OptIgn		;Ignore MSCDEX Kanji.
		db 'K'
	dw DoLtr
		db 'L'
	dw OptIgn		;Ignore MSCDEX buffers.
		db 'M'
	dw OptQ
		db 'Q'
	dw OptR
		db 'R'
	dw OptIgn		;Ignore MSCDEX sharing.
		db 'S'
	dw OptU
		db 'U'
	dw OptIgn		;Ignore /V ("verbose").
		db 'V'
	dw Opt~
		db '~'
	dw OptUnk
		db 0FFh

;
; CritIni -- "Critical Initialization", which must be done LAST!
;
;   Inputs:	(sp+4) -> KeepSize
;		(sp+2) -> RC
;		(sp)   -> IODataP
;
	times	(228) db 0	;"Push" stack to 512 bytes.
CritIni	xor	ax,ax		;Clear all sector buffers.
	pop	cx
	mov	di,[Drive+DrvEnt.Bufp]
	sub	cx,di
	rep	stosb
	mov	ax,'St'		;Set stack to 'St' for debugging.
	mov	cx,($-local_stack+1)/2
	mov	di,local_stack
	rep	stosw
	pop	ax		;Exit to DOS, or stay as a "TSR".
	pop	dx
	int	21h
	dw	0, 0, 0		;(Unused alignment "filler").

DriverIndex	dw	Drivers ; initialize here to help the below alignment
ResMax		db	MAXDRIVES

		align	16
Res_Begin	equ	$-$$+100h - 280*2
local_stack	equ	$ - 280*2	; stack goes back into the PSP
throw_sp	equ	$-2
DriveOfs	dw	0	; EAX, but low word is not needed
scratch 	dw	0	; used by 8086 code
_ES		dw	0
_DI		dw	0
_SI		dw	0
DriveNo 	db	0	; BP, preserved separately
%ifndef CDIMAGE
ChainFlag
%endif
		db	0
CEH_SP		dw	0	; SP, ignored
_BX		dw	0
_DX		dw	0
_CX		dw	0
_AX		dw	0
top_stack	equ	$

_FLAGS		dw	0
_SP		dw	0
_SS		dw	0

%ifdef CDIMAGE
cdxsda_len	equ	($-local_stack) / 2
%else
cdxsda_len	equ	0
%endif

;Old2F		dd	0	; (inlined)
FN1p		dd	0
SDBp		dd	0
DTApp		dd	0
SAttrp		dw	0
Tildes	 	dw	0	; 0 truncate names, -1 append tildes
RdOnly	 	dw	1	; 0 read-write mode, 1 read-only mode

setax		dw	SetAX	; offset for PUSH

%ifdef CDIMAGE
Active		db	1	; 1 not active, 0 active, -1 swapped, -2 nested
ChainFlag	db	0
%else
Active		db	0	; 0 not active, -1 active, -2 nested
		db	0	; (Unused alignment "filler").
%endif

GlobEntry	dw	0
GlobFlag	dw	isoDir.Flags
GlobAttr	db	0
ResDrives	db	0	; number of drives available for use
FirstDriveNo	dw	0
NoDrives	dw	MAXDRIVES
file_name	times 11 db 0	; FCB name from PathLU     \ expected
dir_name	times 11 db 0	; FCB name from directory  / consecutively
ExtFlag		db	0
MatchFlag	db	0FFh
%ifdef JOLIET
Joliet		db	0
%endif

;
; Use BP to access variables, since it's shorter than direct memory access
; (one byte for displacement, instead of two bytes for address).
;
%define BP_(var)	bp+var-top_stack

rh_io
  istruc rhIOCTL
    at rhIOCTL.Header
      istruc rh
	at rh.Length,	db rhIOCTL_size
	at rh.Command,	db rhcmdIOCTL_In
      iend
    at rhIOCTL.CBPtr,	dw IoCB_MediaChange
    at rhIOCTL.Bytes,	dw 2
  iend

rh_rl
  istruc rhReadLong
    at rhReadLong.Header
      istruc rh
	at rh.Length,	db rhReadLong_size
	at rh.Command,	db rhcmdReadLong
      iend
  iend

;
; IOCTL-in control blocks
;
IoCB_MediaChange db	9
     MediaChange db	0	; 0    don't know
				; 1    not changed
				; 0FFh media changed

CD_List	dw	CD_Nbr		; 00 Get number of CD-ROM drives
	dw	CD_Dev		; 01 Get CD-ROM drive device list
	dw	CD_CAB		; 02 Get copyright file ID
	dw	CD_CAB		; 03 Get abstract file ID
	dw	CD_CAB		; 04 Get bibliographic file ID
	dw	CD_VTOC 	; 05 Read VTOC
	dw	InvFunc		; 06 Turn debugging on
	dw	InvFunc		; 07 Turn debugging off
	dw	CD_Read 	; 08 Absolute disk read
	dw	InvFunc		; 09 Absolute disk write
	dw	InvFunc		; 0A Reserved
	dw	CD_Chek		; 0B CDROM drive check
	dw	CD_Ver		; 0C MSCDEX version
	dw	CD_Ltr		; 0D Get CD-ROM drive letters
%ifdef JOLIET
	dw	CD_VolD		; 0E Get/Set vol. descriptor preference
%else
	dw	InvFunc		; 0E Get/Set vol. descriptor preference
%endif
	dw	CD_DirE		; 0F Get directory entry
	dw	CD_Req		; 10 Send device request

;
; Table of Redirector request codes and dispatch address.
; This table must be ordered by request-code number.
;
RD_List	db ChDir
		dw RD_ChD
	db Close
		dw RD_Clos
	db Read
		dw RD_Read
	db GetSP
		dw RDGetSP
	db GetFA
		dw RDGetFA
	db Open
		dw RD_Open
	db FindFirst
		dw RD_FndF
	db FindNext
		dw RD_FndN
	db Seek
		dw RD_Seek
	db EOpen
		dw RD_EOpn
	db NoRedir
		dw RD_NoRd

Present	cmp	al, PathName		; called a lot, so handle it directly
	je s	Chain
	cmp	al, InstallChk
	jne s	Main
	push	bp
	mov	bp, sp
	cmp	word [bp+fr_Parm1], MSCDEX_Q
	jne s	Presnt1
	mov	word [bp+fr_Parm1], MSCDEX_R
Presnt1	cmp	bx, SMARTDRV_Q
	jne s	Presnt2
	mov	bx, COMPILE_FLAG
	push	cs
	pop	es
	mov	di, Drive
	mov	cx, [cs:NoDrives]
	mov	dx, DrvEnt_size
Presnt2	mov	al, 0ffh
	pop	bp
	iret

New2F	cmp	ah, REDIR		; is this call for us?
	je s	Present
	cmp	ah, MSCDEX
	je s	Main
Chain	db	0EAh			; chain out
Old2F	dd	0

Main	push	ds			; save regs and switch to local stack
	push	cs
	pop	ds
	cld
	dec	byte [Active]		;  1 -->  0 == PE, PL
	jpo s	nested			;  0 --> -1 == PE, NG
%ifdef CDIMAGE				; -1 --> -2 == PO
	jns s	Main1
	call	Swapcdx
%endif
Main1	push	bp
	mov	bp, sp
	mov	bp, [bp+2+fr_Flags]
	mov	[_FLAGS], bp
	mov	[_SP], sp
	mov	[_SP+2], ss
	cli
	push	cs
	pop	ss
	mov	sp, top_stack
	mov	bp, sp
	push	ax
	push	cx
	push	dx
	push	bx
	push	ax
	push	bp
	push	si
	push	di
	push	es
	push	ax
	push	ax
	call	Main2F
	cli
	inc	byte [BP_(Active)]	; nothing below affects the flags
	pop	ax			; restore registers and switch back
	pop	ax			; to caller's stack
	pop	es
	pop	di
	pop	si
	pop	bp
	pop	ax
	pop	bx
	pop	dx
	pop	cx
	pop	ax
	mov	sp, [_FLAGS]
	mov	ss, [_SP+2]
	mov	bp, [_SP]
	mov	[bp+2+fr_Flags], sp
	mov	sp, bp
	pop	bp

%ifdef CDIMAGE
	jnz s	Main2			; -1 --> 0 == ZR
	call	Swapcdx			;  0 --> 1 == NZ
%endif
Main2	dec	byte [ChainFlag]
cexit	pop	ds
	;sti
	js s	Chain
	iret

nested	inc	byte [Active]
	jmp s	cexit

%ifdef CDIMAGE
Swapcdx push	es
	push	si
	push	di
	push	cx
	mov	si, cdxsda
	mov	di, local_stack
	jns s	Swpcdx1
	xchg	si, di
Swpcdx1	push	cs
	pop	es
	mov	cx, cdxsda_len
	rep	movsw
	pop	cx
	pop	di
	pop	si
	pop	es
	ret
%endif

Main2F	mov	byte [BP_(ChainFlag)], 1
DR_DOS	cmp	ah, MSCDEX		; (replaced with CALL if using DR-DOS)
	jne s	DR_DOS1
	cmp	al, 10h			; Handle the MSCDEX calls
	ja s	InvFunc
	cbw
	add	al, al			; clears carry
	xchg	bx, ax
	push	word [BP_(setax)]
	call	[CD_List+bx]
	pop	ax
	jmp s	SetAX1
DR_DOS1	mov	bx, RD_List		; Handle redirector calls
DR_DOS2	cmp	[bx], al
	lea	bx, [bx+3]
	ja s	ChainEx
	jne s	DR_DOS2
	call	[bx-2]
SetAX	mov	[_AX], ax
SetAX1	pushf
	shr	byte [BP_(_FLAGS)], 1
	popf
	rcl	byte [BP_(_FLAGS)], 1
	ret

RD_NoXA	pop	ax			;Discard subroutine return address.
RD_NoRd	pop	ax			;Discard redirector return address.
ChainEx	dec	byte [BP_(ChainFlag)]	;Just chain out.   Novell does not
MExit	ret				;  like it if you declare "error".

InvDrv	mov	al, INVALIDDRIVE
	jmp s	ErrAL
InvFunc	mov	al, INVALIDFUNC
	jmp s	ErrAL
InvPath	mov	al, PATHNOTFOUND
	jmp s	ErrAL
InvFile	mov	al, FILENOTFOUND
	jmp s	ErrAL
NotRdy	mov	al, DRIVENOTREADY
ErrAL	cbw
	mov	sp, throw_sp
	stc
	jmp s	SetAX

;
; Determine if the various redirector functions are meant for us.
;
;  In: Nothing
; Out: ES:BX -> filename
;
RDF_Fn1	les	bx, [BP_(FN1p)]

;
;  In: ES:BX -> filename
; Out: Nothing
;
RDF_Drv	mov	al, [es:bx+DriveOff]
	sub	al, 'A'
	jmp s	RDForUs

;
;  In: ES:DI -> SFT
; Out: Nothing
;
RDF_SFT	mov	al, [es:di+SFT.Flags]

;
;  In: AL = drive letter with flags
; Out: Nothing
;
RDF_Flg	and	al, 3fh 		; just want drive number

RDForUs	call	ForUs
	cmp	al, 0fh
	jb s	MExit			; AL = 0, so for us, return
	je s	RD_NoXA			; Invalid drive, not for us

	; Drive not ready - invoke critical error handler
	inc	byte [BP_(Active)]	; If aborted it won't be reset
	push	es			; NB: does not reset swap data,
	push	bp
	push	si
	push	di
	mov	[BP_(CEH_SP)], sp	;     abort will *really* abort
	mov	ss, [BP_(_SP)+2]	; Need to use the DOS stack
        mov     sp, [_SP]
	mov	ah, 00011110b		; Disk data error, allow retry & fail
	mov	al, [DriveNo]
	push	ax			; Int 24 error code on stack
	mov	di, 2			; Drive not ready
	xor	bp, bp			; BP:SI driver header (not needed)
	xor	si, si
	mov	ax, 1206h		; Invoke Critical Error
	int	2fh
	push	cs
	pop	ss
	mov	sp, [CEH_SP]
	pop	di
	pop	si
	pop	bp
	pop	es
	dec	byte [BP_(Active)]
	cmp	al, 1			; Didn't retry, drive not ready
	jne s	NotRdy
	mov	al, [DriveNo]
	jmp s	RDForUs

;
; SetIfUs -- Determine if the drive is one of ours.
;
;   Inputs:	CL = drive number (0 = A)
;
;   Returns:	If for us:
;		   DriveNo and DriveOfs set appropriately
;		   BX restored to client's value
;		Does not return if not for us
;
;   Destroys:	AX,CX
;
SetIfUs	xchg	ax, cx
	call	ForUs
	jnz s	ErrAL
	mov	bx, [BP_(_BX)]
	ret

;
; SetDDD -- Search for matching drive and set DriveOfs and DriveNo.
;
;   Inputs:	CL = drive number (0 = A)
;
;   Returns:	ZR if drive is one of ours
;		   DriveOfs and DriveNo set
;		   BX = DriveOfs
;		   CX != 0
;		NZ if not our drive
;		   CX = 0
;		   BX destroyed
;
;   Destroys:	AX
;
SetDDD	mov	ax, [NoDrives]
	mov	bx, Drive
	xchg	cx, ax
	inc	cx			; clear zero if no drives
	jmp s	SetDDD2
SetDDD1	cmp	[bx+DrvEnt.No], al
	je s	SetDDD3
	add	bx, byte DrvEnt_size
SetDDD2	loop	SetDDD1
SetDDD3	mov	[BP_(DriveOfs)], bx
	mov	[DriveNo], al
	ret

;
; ForUs -- Determine if the drive is one of ours and initialize it if so.
;
;   Inputs:	AL = drive number (0 = A)
;
;   Returns:	ZR if successful
;		   AL = 00h
;		NZ if failed
;		   AL = 0fh if invalid drive (not for us)
;			15h if drive not ready
;
;   Destroys:	CX
;
ForUs	push	bx
	push	si
	push	di
	xchg	cx, ax
	call	SetDDD
	mov	al, INVALIDDRIVE
	jnz s	ForUsX

	; Force re-init if it's been a while and the media has changed.
	call	GetTiks
	sub	ax, [bx+DrvEnt.LastAccess]
	cmp	ax, 128			; approx. 7 seconds
	jb s	ForUs1
	push	es
	push	bx
	push	ds
	pop	es
	mov	bx, rh_io
	call	DDCall
	pop	bx
	pop	es
	dec	byte [BP_(MediaChange)]	; cmp MediaChange, not changed
	jz s	ForUs1
	mov	byte [bx+DrvEnt.Type], UNKNOWN

	; May need to initialize this drive
ForUs1	cmp	byte [bx+DrvEnt.Type], UNKNOWN
	jne s	ForUs2
	or	word [bx+DrvEnt.BufBlkNo+2], byte -1
	call	CdReadP
	mov	al, DRIVENOTREADY
	jnz s	ForUsX
	call	InitCD
ForUs2	call	GetTiks
	mov	[bx+DrvEnt.LastAccess], ax
	xor	al, al
ForUsX	pop	di
	pop	si
	pop	bx
	ret

;
; GetTiks -- Return the clock ticks (low word).
;
;   Inputs:	None.
;
;   Returns:	AX = clock ticks
;
GetTiks	push	ds
	xor	ax, ax
	mov	ds, ax
	mov	ax, [46ch]
	pop	ds
	ret

;
; InitCD -- Initialize the CD structures.
;
;   Inputs:	BX -> drive structure
;
;   Returns:	Nothing.
;
;   Destroys:	EAX,CX,SI,DI
;
InitCD	lea	si, [bx+DrvEnt.RootEnt]	; Flush the directory cache
	mov	cx, ISO9660
	mov	di, [si+DirEnt.Forw]
InitCD1	mov	[di+DirEnt.FName], ch
	mov	di, [di+DirEnt.Forw]
	cmp	di, si
	jne s	InitCD1
	mov	di, [bx+DrvEnt.Bufp]
	cmp	word [di+isoVol.ID], 'CD'
	jne s	InitCD2
	cmp	word [di+isoVol.ID+2], '00'
%ifndef HS
InitCD2	jne s	.ret
%else
InitCD2	je s	.iso
	cmp	word [di+hsVol.ID], 'CD'
	jne s	.ret
	cmp	word [di+hsVol.ID+2], 'RO'
	jne s	.ret

	; High Sierra
	dec	cx			; HIGHSIERRA = ISO9660 - 1
	lea	si, [di+hsVol.DirRec]
	lea	di, [di+hsVol.VolID]
	jmp s	.copy
%endif

.iso	lea	si, [di+isoVol.DirRec]	; ISO 9660 (ECMA-119)
	lea	di, [di+isoVol.VolID]
.copy	mov	[bx+DrvEnt.Type], cl
	dec	word [di+28h+2]		; VolSizeLSB (relative to VolID)
	mov	ax, [di+28h]
	js s	.copy1
	mov	ax, -1
.copy1	mov	[bx+DrvEnt.VolSize], ax

	push	es
	push	si
	push	ds
	pop	es
	push	di
	lea	di, [bx+DrvEnt.RootEnt] ; also VLabel
	mov	al, A_SUBDIR
	call	DFieldC
	pop	si
	push	di
	call	mov11b
	pop	di
	pop	si
	pop	es

%ifdef JOLIET
	rol	byte [BP_(Joliet)], 1
	jnc s	.root
 %ifdef HS
	cmp	byte [bx+DrvEnt.Type], HIGHSIERRA
	je s	.root
 %endif
	call	.root
	mov	ax, 11h			; Check for Joliet
	cwd
.copy2	call	CdReadB
	jnz s	.ret
	cmp	byte [si-isoVol.DirRec], 2  ; SVD
	jne s	.copy3
	cmp	word [si+isoVol.Unused3-isoVol.DirRec], '%/' ; escape sequence
	jne s	.copy3
	xchg	ax, cx
	mov	al, [si+isoVol.Unused3+2-isoVol.DirRec]
	cmp	al, '@'
	je s	.jol
	cmp	al, 'C'
	je s	.jol
	cmp	al, 'E'
	je s	.jol
	xchg	ax, cx
.copy3	inc	ax
	inc	byte [si-isoVol.DirRec]
	jnz s	.copy2
.ret	ret

.jol	mov	ax, [si+Sizeoff]
	mov	dx, [si+Sizeoff+2]
	mov	[di+DirEnt.FSize], ax
	mov	[di+DirEnt.FSize+2], dx
%endif
.root	mov	ax, [si+Blkoff]
	mov	dx, [si+Blkoff+2]
	mov	[di+DirEnt.ParentBlk], ax
	mov	[di+DirEnt.ParentBlk+2], dx
setblk	mov	[di+DirEnt.BlkNo], ax
	mov	[di+DirEnt.BlkNo+2], dx
%ifndef JOLIET
InitCD.ret:
%endif
	ret

;
; Redirector functions
;
;   Entry points to the various redirector functions.
;
;   Inputs:	BX destroyed (but restored by the RDForUs... fns)
;		All others as per the function
;
;   Returns:	AX & CF according to function.
;
;
; 05h:	Change directory
;  In:	SS = DOS DS
;	SDA first filename pointer -> fully-qualified directory name
;	SDA CDS pointer -> current directory structure for drive with dir
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   CDS updated with new path
;
RD_ChD	call	RDF_Fn1
	call	LookupD
	jnz s	RD_Exit
	jmp	InvPath

;
; 06h:	Close file
;  In:	ES:DI -> filled-in SFT (assumed to point at SDA's current SFT field)
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   SFT updated (redirector must decrement open count, which may be
;	     done with INT 2F/AX=1208h)
;	ES:DI must be preserved
;
RD_Clos	call	RDF_SFT
	dec	word [es:di+SFT.RefCnt]
	jns s	RD_Exit
	inc	word [es:di+SFT.RefCnt] ; assume count < 32768
RD_Exit	xor	ax, ax			; clears carry
	ret

;
; RShift -- Shift DX:AX SECTORSHIFT bits to the right.
;
RShift	mov	cx, SECTORSHIFT
RShift1	shr	dx, 1
	rcr	ax, 1
	loop	RShift1
	ret

;
; 08h:	Read from file
;  In:	ES:DI -> SFT
;		 SFT DPB field -> DPB of drive containing file
;	CX = number of bytes
;	SS = DOS DS
;	SDA DTA field -> user buffer
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   CX = number of bytes read (0000h = end of file)
;	   SFT updated
;
RD_Read	call	RDF_SFT
	xor	cx, cx
	xchg	[BP_(_CX)], cx
	jcxz	RD_Exit
	mov	si, [es:di+SFT.FilSiz+2]
	mov	bx, [es:di+SFT.FilSiz]
	mov	dx, [es:di+SFT.FilPos+2]
	mov	ax, [es:di+SFT.FilPos]
	sub	bx, ax
	sbb	si, dx
	jb s	RD_Exit 		; Can't read past EOF
	jnz s	RD_Rd1			; Chop read back if too long
	cmp	cx, bx
	jbe s	RD_Rd1
	mov	cx, bx
	jcxz	RD_Exit
RD_Rd1	mov	[BP_(scratch)], cx
	mov	si, ax			; Calculate block with start of data
	and	si, SECTORSIZE-1
	call	RShift
	add	ax, [es:di+SFT.FBN]
	adc	dx, [es:di+SFT.FBN+2]
	push	es
	les	bx, [BP_(DTApp)]
	les	bx, [es:bx]
RD_Rd2	push	di			; [scratch] < SECTORSIZE
	cmp	byte [BP_(scratch)+1], 8
	jb s	RD_RPrt
	test	si, si
	jnz s	RD_RPrt
	mov	di, [BP_(scratch)]	; Read complete blocks
	mov	cl, SECTORSHIFT
	shr	di, cl
	xchg	cx, di
	call	CdReadL
	xchg	cx, di
	jnz s	RD_RE15			; assume drive not ready
	add	ax, di			;  but could use general failure
	adc	dx, si			; SI = 0
	shl	di, cl
	mov	cx, di
	jmp s	RD_RUpd
RD_RE15	jmp	NotRdy
RD_RPrt	call	CdReadB			; Partial block
	jnz s	RD_RE15
	mov	cx, SECTORSIZE
	sub	cx, si
	cmp	cx, [BP_(scratch)]
	jb s	RD_RPt1
	mov	cx, [BP_(scratch)]
RD_RPt1	push	cx
	mov	di, [BP_(DriveOfs)]
	add	si, [di+DrvEnt.Bufp]
	mov	di, bx
	rep	movsb
	pop	cx
	xor	si, si
	add	ax, byte 1
	adc	dx, si
RD_RUpd	pop	di
	pop	ds
	push	ds
	add	[di+SFT.FilPos],   cx
	adc	[di+SFT.FilPos+2], si	; SI = 0
	push	cs
	pop	ds
	add	bx, cx
	add	[BP_(_CX)], cx
	sub	[BP_(scratch)], cx
	jnz s	RD_Rd2
	pop	es
	xor	ax, ax			; clears carry
	ret

;
; 0ch:	Get disk information
;  In:	ES:DI -> current directory structure for desired drive
; Out:	CF clear if data valid
;	   AL = sectors per cluster
;	   AH = media ID byte
;	   BX = total clusters
;	   CX = bytes per sector
;	   DX = number of available clusters
;	CF set if data invalid
;
RDGetSP	mov	bx, di
	call	RDF_Drv
	mov	bx, [BP_(DriveOfs)]
	mov	word [BP_(_CX)], SECTORSIZE
	mov	ax, [bx+DrvEnt.VolSize]	; # clusters on drive
	mov	[_BX], ax
	xor	ax, ax
	mov	[_DX], ax		; # clusters available
	inc	ax			; # sectors/cluster & Media ID
	;clc				; cleared by zero
	ret

;
; 0fh:	Get file's attributes and size
;  In:	SS = DOS DS
;	SDA first filename pointer -> fully-qualified name of file
;	SDA CDS pointer -> current directory structure for drive with file
;		(offset = FFFFh if null CDS [net direct request])
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   AX = file attributes
;	   BX:DI = file size
;	   CX = time stamp of file
;	   DX = date stamp of file
;
RDGetFA	call	RDF_Fn1
	call	Lookup
	jc s	RD_GtAX
	add	si, byte DirEnt.FTime
	lodsw
	mov	[_CX], ax
	lodsw				; DirEnt.FDate
	mov	[_DX], ax
	lodsw				; skip DirEnt.Back
	lodsw				; DirEnt.FSize
	mov	[_DI], ax
	lodsw
	mov	[_BX], ax
	mov	al, [si+DirEnt.Fattr - DirEnt.FSize-4]
	cbw
RD_GtAX	ret

;
; 2eh:	Extended open/create
;  In:	ES:DI -> uninitialized SFT for file
;	STACK: WORD file attribute for created/truncated file
;			low byte = file attributes
;			high byte = 00h normal create/open, 01h create new file
;	SDA first filename pointer -> fully-qualified filename
;	SDA extended file open action = action code
;	SDA extended file open mode = open mode for file
; Out:	CF set on error
;	   AX = error code
;	CF clear if successful
;	   CX = result code
;		01h file opened
;		02h file created
;		03h file replaced (truncated)
;	   SFT initialized (except handle count, which DOS manages itself)
;
RD_EOpn	call	RDF_Fn1
	add	bx, 2e1h - 9eh		; extended open mode (in the SDA)
	test	byte [es:bx-4], 02h	; extended open action - replace
	jnz s	No_Open
	jmp s	Test_Wr

;
; 16h:	Open file
;  In:	ES:DI -> uninitialized SFT
;	SS = DOS DS
;	SDA first filename pointer -> fully-qualified name of file to open
;	STACK: WORD file access and sharing modes
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   SFT filled (except handle count, which DOS manages itself)
;	STACK unchanged
;
RD_Open	call	RDF_Fn1
	les	bx, [BP_(_SP)]
	add	bx, byte 2+fr_Parm1	; open mode (on the stack)
Test_Wr	test	byte [es:bx], 01h	; open for write
No_Open	mov	al, ACCESSDENIED
	jccl	nz, ErrAL
	les	bx, [BP_(FN1p)]		; Look up filename
	call	Lookup
	jc s	RD_OpnX

	; Gotta be a file, not a dir
	test	byte [si+DirEnt.Fattr], A_SUBDIR
	jccl	nz, InvFile
	mov	es, [BP_(_ES)]		; Fill in SFT
	add	di, byte SFT.Name
	call	mov11b			; DirEnt.FName
	sub	di, byte SFT.Name + 11 - SFT.Mode
	or	byte [es:di], 2
	scasw				; DI += 2
	movsb				; SFT.DirAttrib = DirEnt.Fattr
	mov	ax, 8040h
	or	al, [DriveNo]
	stosw				; SFT.Flags
	add	di, byte SFT.HHMMSS - SFT.Flags-2
	add	si, byte DirEnt.FTime - DirEnt.Fattr-1
	movsw				; SFT.HHMMSS = DirEnt.FTime
	movsw				; SFT.YYMMDD = DirEnt.FDate
	lodsw				; SI += 2
	movsw				; SFT.FilSiz = DirEnt.FSize
	movsw
	xor	ax, ax
	stosw				; SFT.FilPos
	stosw
	sub	si, byte DirEnt.FSize + 4 - DirEnt.BlkNo
	movsw				; SFT.FBN = DirEnt.BlkNo
	movsw
	;clc				; cleared by SUB
RD_OpnX	ret

;
; 1bh:	Findfirst
;  In:	SS = DS = DOS DS
;	[DTA] = uninitialized 21-byte findfirst search data
;	SDA first filename pointer -> fully-qualified search template
;	SDA CDS pointer -> current directory structure for drive with file
;	SDA search attribute = attribute mask for search
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   [DTA] = updated findfirst search data
;		   (bit 7 of first byte must be set)
;	   [DTA+15h] = standard directory entry for file
;
RD_FndF	call	RDF_Fn1
	call	PathLU
	les	di, [BP_(SDBp)]		; Fill in the SDB
	mov	al, [DriveNo]
	or	al, 0c0h
	stosb				; SDB.DriveLet
	call	DirSize
	push	cx
	mov	si, file_name
	call	mov11b			; SDB.TemPlate
	mov	si, [BP_(SAttrp)]
	es
	movsb				; SDB.SAttr
	; Skip the . & .. entries in root dir
	cmp	ax, [bx+DrvEnt.RootEnt+DirEnt.BlkNo]
	jne s	RD_FF1
	cmp	dx, [bx+DrvEnt.RootEnt+DirEnt.BlkNo+2]
	jne s	RD_FF1
	mov	cl, 2			; CX = 0 from mov11b
RD_FF1	xchg	ax, cx
	stosw				; SDB.Entry
	xchg	ax, cx
	stosw				; SDB.ParentBlk
	xchg	ax, dx
	stosw
	pop	ax
	stosw				; SDB.ParentSize
	mov	al, 8			; volume label attribute
	cmp	[es:si-1], al		; SAttrp
	je s	RD_FF2
	sub	di, byte SDB.ParentSize + 2  ; point back to beginning
	call	DoFindF
	mov	al, FILENOTFOUND	; DOS will apparently zero on success
	ret
	; Handle vol id
RD_FF2	lea	si, [bx+DrvEnt.RootEnt] ; VLabel
	call	GetFDB
	call	mov11b			; FDB.FName
	stosb				; FDB.Fattr
	mov	cx, 10
ten	equ	$-2
	mov	al, 0
	add	di, cx			; clears carry
	rep	stosb			; FDB.FTime, FDB.Cluster, FDB.FSize
	ret

GetFDB	mov	di, [BP_(DTApp)]
	les	di, [es:di]
	add	di, byte SDB_size
	ret

;
; 1ch:	Findnext
;  In:	ES:DI -> CDS
;	ES:DI -> DTA (MSDOS v5.0)
;	[DTA] = 21-byte findfirst search data
; Out:	CF set on error
;	   AX = DOS error code
;	CF clear if successful
;	   [DTA] = updated findfirst search data
;		   (bit 7 of first byte must be set)
;	   [DTA+15h] = standard directory entry for file
;
RD_FndN	les	di, [BP_(SDBp)] 	; get SDBp
	mov	al, [es:di]		; SDBp->DriveLet (A = 0)
	call	RDF_Flg

	; Make sure we're not continuing an already finished searched.
	cmp	word [es:di+SDB.ParentSize], byte -1
	je s	DoFNone
	push	ds			; Get copy of search template
	push	es
	push	di
	push	ds
	push	es
	pop	ds
	pop	es
	lea	si, [di+SDB.TemPlate]
	mov	di, file_name
	call	mov11b
	pop	di
	pop	es
	pop	ds
	mov	bx, [BP_(DriveOfs)]

DoFindF

%ifdef HS
	mov	al, [bx+DrvEnt.Type]
	mov	[GlobFlag], al
%endif
	mov	al, [es:di+SDB.SAttr]
	or	al, 01h			; read-only should always match
	mov	[GlobAttr], al
	mov	ax, [es:di+SDB.Entry]	; Search parent dir for matching entry
	mov	[GlobEntry], ax
	and	al, 0c0h
	mov	[scratch], ax
	mov	dx, [es:di+SDB.ParentBlk+2]
	mov	ax, [es:di+SDB.ParentBlk]
	push	di
	mov	di, [es:di+SDB.ParentSize]
	mov	byte [MatchFlag], 0
	call	FindNam
	mov	bx, di
	pop	di
	lea	di, [di+SDB.Entry]
	push	ax
	mov	ax, [scratch]
	stosw
	pop	ax
	stosw				; SDB.ParentBlk
	xchg	ax, dx
	stosw
	xchg	ax, bx
	stosw				; SDB.ParentSize
	jz s	DoFFX
DoFNone	stc
	mov	ax, NOMOREFILES
	ret

	; Save start point for next time
DoFFX	inc	byte [es:di-8]		; SDB.Entry
	xchg	ax, cx
	call	GetFDB			; Fill in the FDB

;
; DFieldC -- Copy relevant portions of the directory entry.
;
;   Inputs:	AL = attribute
;		SI -> directory entry
;		dir_name = FCB name of file
;		ES:DI -> where to copy (DirEnt or FDB)
;
;   Returns:	ES:DI filled (name, attribute, time, date, size)
;
;   Destroys:	EAX,CX
;
DFieldC	push	di
	push	si
	mov	si, dir_name
	call	mov11b			; .FName
	pop	si
	stosb				; .Fattr
	add	di, byte DirEnt.FTime - DirEnt.Fattr-1
	mov	al, [si+Date_Time.Yr]	; Convert CD date/time to DOS format
	sub	al, 80			; ISO is from 1900, DOS is from 1980
	jnc s	DFldC1
	mov	al, 0
DFldC1	mov	cl, 4
	shl	ax, cl
	or	al, [si+Date_Time.Mth]
	inc	cx
	shl	ax, cl
	or	al, [si+Date_Time.Day]
	xchg	dx, ax
	mov	al, [si+Date_Time.Hr]
	inc	cx
	shl	ax, cl
	or	al, [si+Date_Time.Min]
	dec	cx
	shl	ax, cl
	mov	cl, [si+Date_Time.Sec]
	shr	cl, 1
	or	al, cl
	stosw
	xchg	ax, dx
	stosw
	scasw				; DI += 2
	push	si
	add	si, byte Sizeoff
	movsw				; .FSize
	movsw
	pop	si
	pop	di
	ret

;
; 21h:	Seek from end of file
;  In:	CX:DX = offset (in bytes) from end
;	ES:DI -> SFT
;		 SFT DPB field -> DPB of drive with file
;	SS = DOS DS
; Out:	CF set on error
;	   AL = DOS error code
;	CF clear if successful
;	   DX:AX = new file position
;
RD_Seek	call	RDF_SFT
	les	ax, [es:di+SFT.FilSiz]
	mov	bx, es
	add	ax, [BP_(_DX)]
	adc	bx, [BP_(_CX)]
	mov	[BP_(_DX)], bx
	clc
	ret

;
; MSCDEX functions
;
;   Entry points to the various CD-ROM functions.
;
;   Inputs:	AX = BX
;		BX corrupted (double the function number)
;		NC
;		the rest as per the function
;
;   Returns:	discard the return address to set the client's AX
;		client's CF is set accordingly
;
;
; The following function descriptions refer to the client BX, which is our AX.
;
; 00h:	Get number of drive letters (installation check)
;  In:	BX = 0
; Out:	BX = number of CD-ROM drive letters used
;	CX = starting drive letter (0 = A)
;
CD_Nbr	push	word [NoDrives]
	pop	word [BP_(_BX)]
	push	word [FirstDriveNo]
	pop	word [BP_(_CX)]
	;clc				; cleared on entry
	dec	byte [BP_(_AX)]		; return AL=FF
	ret

;
; 01h:	Get drive device list
;  In:	ES:BX -> buffer to hold drive letter list (5 bytes per drive)
; Out:	buffer filled:
;	  BYTE	subunit number in driver
;	  DWORD address of device driver header
;
CD_Dev	xchg	di, ax
	mov	cx, [NoDrives]
	mov	si, Drive+DrvEnt.DevHdrp
	jcxz	CD_DevX
CD_Dev1	mov	al, [si+DrvEnt.Unit-DrvEnt.DevHdrp]
	stosb
	movsw
	movsw
	add	si, byte DrvEnt_size - 4  ; clears carry flag
	loop	CD_Dev1
CD_DevX	ret

;
; 02h:	Get copyright file name
; 03h:	Get abstract file name
; 04h:	Get biblio file name
;  In:	ES:BX -> 38-byte buffer for name of respective file
;	   CX  = drive number (0 = A)
; Out:	CF set if drive is not a CD-ROM drive
;	   AX = 000Fh (invalid drive)
;	CF clear if successful
;
CD_CAB	call	SetIfUs
	call	CdReadP
	jnz s	CD_VTC1
	mov	di, bx
	mov	bx, [BP_(DriveOfs)]
	mov	al, [_AX]
	mov	si, [bx+DrvEnt.Bufp]
	; assume ISO
	mov	cl, 37			; CH zero from CdReadP
	lea	si, [si+isoVol.CopyRightID]
%ifdef HS
	cmp	byte [bx+DrvEnt.Type], HIGHSIERRA
	jne s	CD_CAB1
	cmp	al, 4			; no such thing for HS
	je s	CD_CAB3
	mov	cl, 32
	add	si, byte hsVol.CopyRightID - isoVol.CopyRightID
%endif
CD_CAB1	sub	al, 2
	mul	cl
	add	si, ax
CD_CAB2	lodsb
	cmp	al, ' '
	je s	CD_CAB3
	stosb
	loop	CD_CAB2
CD_CAB3	xor	al, al			; clears carry
	stosb
	ret

;
; 05h:	Read VTOC
;  In:	ES:BX -> 2048-byte buffer
;	   CX  = drive number (0 = A)
;	   DX  = sector index (0 = first volume descriptor,1=second,...)
; Out:	CF set on error
;	   AX = error code (15 = invalid drive, 21 = not ready)
;	CF clear if successful
;	   AX = volume descriptor type
;	        (1 = standard, FFh = terminator, 0 = other)
;
CD_VTOC	push	dx
	call	SetIfUs
	pop	ax
	cwd
	add	al, 10h 		; assume sector index < 240
	call	CdRdL1
CD_VTC1	jccl	nz, NotRdy		; drive not ready
	mov	al, [es:bx+isoVol.Type]
	mov	ah, 0
%ifdef HS
	mov	si, [BP_(DriveOfs)]
	cmp	byte [si+DrvEnt.Type], HIGHSIERRA
	jne s	CD_VTC2
	mov	al, [es:bx+hsVol.Type]
%endif
CD_VTC2	cmp	al, 1			; assume 0FFh is only one above 7Fh
	jle s	CD_ChkX
	jmp s	CD_Read.zero

;
; 08h:	Absolute disk read
;  In:	ES:BX -> buffer
;	   CX  = drive number (0 = A)
;	SI:DI  = starting sector number
;	   DX  = number of sectors to read
; Out:	CF set on error
;	   AL = error code (0Fh invalid drive, 15h not ready)
;	CF clear if successful
;
CD_Read	push	dx
	call	SetIfUs
	pop	cx
	jcxz	.zero			; set AX to 0 on success
	mov	dx, si
	xchg	ax, di
	call	CdReadL
	jnz s	CD_VTC1			; drive not ready
.zero	xor	ax, ax
	pop	cx
	ret

;
; 0Bh:	CDROM check
;  In:	CX = drive number (0 = A)
; Out:	BX = ADADh if MSCDEX.EXE installed
;	AX = support status
;	  0000h if drive not supported
;	  nonzero if supported
;
CD_Chek	mov	word [BP_(_BX)], MSCDEX_R
	call	SetDDD
	xchg	ax, cx
CD_ChkX	clc
	pop	cx
	ret

;
; 0Ch:	MSCDEX version
;  In:	BX = 0000h
; Out:	BH = major version
;	BL = minor version
;
CD_Ver	mov	word [BP_(_BX)], ((2<<8) + 30)
	ret

;
; 0Dh:	Drive letters
;  In:	ES:BX -> buffer for drive letter list (1 byte per drive)
; Out:	buffer filled with drive numbers (0 = A).  Each byte corresponds
;	 to the drive in the same position for function 1501h
;
CD_Ltr	xchg	di, ax
	mov	cx, [NoDrives]
	mov	si, Drive+DrvEnt.No
	jcxz	CD_LtrX
CD_Ltr1	movsb
	add	si, byte DrvEnt_size - 1  ; clears carry flag
	loop	CD_Ltr1
CD_LtrX	ret


%ifdef JOLIET
;
; 0Eh:	Get/Set Volume Descriptor Preference
;  In:	BX = subfunction
;	     00h get preference
;		 DX = 0000h
;		 Return: DX = preference settings
;	     01h set preference
;		 DH = volume descriptor preference
;		      01h = primary volume descriptor
;		      02h = supplementary volume descriptor
;		 DL = supplementary volume descriptor preference
;		      01h = shift-Kanji
;	CX = drive number (0 = A)
; Out:	CF set on error
;	   AX = error code (15 = invalid drive, 1 = invalid function)
;	CF clear if successful
;
;  In:	BL = 02h
;	     BH =  0: ISO
;		  -1: Joliet
;	Subfunctions 0 & 1 are not supported; this is only used by DOSLFN.
;
CD_VolD	cmp	al, 2
	jne s	Err01.
	cmp	[BP_(Joliet)], ah
	je s	CD_DscX
	mov	[BP_(Joliet)], ah
	clc
	mov	cx, [NoDrives]
	mov	si, Drive+DrvEnt.Type
	jcxz	CD_DscX
CD_Dsc1	mov	byte [si], UNKNOWN
	add	si, byte DrvEnt_size
	loop	CD_Dsc1
CD_DscX	ret

Err01.	jmp	InvFunc
%define err1 Err01.
%else
%define err1 InvFunc
%endif

;
; 0Fh:	Get Directory Entry
;  In:	CL = drive number (0 = A)
;	CH bit 0 = copy flag
;		     clear if direct copy
;		     set if copy removes ISO/High Sierra diffs
;	ES:BX -> ASCIZ path name
;	SI:DI -> buffer for directory entry
;		   must be 255 bytes for direct copy, 285 bytes for canonical
; Out:	CF set on error
;	   AX = error code
;	CF clear if successful
;	   AX = disk format (0 = High Sierra, 1 = ISO 9660)
;
;  In:	CL = 0FFh
;	  CH = function:
;	       0 get tilde usage in AX (0 = off, -1 = on)
;	       1 set tilde usage from BX (0 turn tildes off, anything else on)
;	       2 get read-only mode in AX (0 = off, 1 = on)
;	       3 set read-only mode from BX (0 off, anything else on)
;	CL = 0FEh
;	  ES:SI -> pointer to directory entry
;	  ES:DI -> 11-byte buffer for FCB name
;	     DX = alias number (0 for none)
;
CD_DirE	cmp	cl, 0feh
	jb s	dir_ent
	ja s	do_api
	push	es
	push	di
	call	CDtoFCB
	pop	di
	pop	es
	clc
mov11b	mov	cx, 11
	rep	movsb
	ret

dir_ent	shr	ch, 1			; Canonical entry not supported
.e1	jc s	err1
	call	SetIfUs
	cmp	byte [es:bx], PATHSEPARATOR
.e2	jccl	ne, InvFile		; must be absolute path
	sub	bx, byte RootSlashOff	; path adjustment
	call	PathLU
	call	FindEnt
	jnz s	.e2			; file not found (NC if found)
	les	di, [BP_(_DI)]		; SI:DI
	mov	cl, [si]
	mov	ch, 0
	rep	movsb
%ifdef HS
	mov	bx, [BP_(DriveOfs)]
	mov	al, [bx+DrvEnt.Type]
	sub	al, HIGHSIERRA		; HS -> 0, ISO -> 1, NC
	cbw
%else
	mov	ax, 1
%endif
	pop	cx
	ret

do_api	cmp	ch, 4
%ifdef JOLIET
	jnc s	err1
%else
	cmc
	jc s	dir_ent.e1
%endif
	xor	ax,ax		;Reset "result" in AX-reg.
	shr	ch,1		;Is this function 2 or 3?
	jnz s	do_api2		;Yes, use logic below.
	jc s	do_api1		;If function 1, use logic below.
	or	ax,[Tildes]	;Function 0:  Get Tildes flag.
	pop	cx		;Reload CX-reg. and exit.
	ret
do_api1	cmp	ax,[BP_(_BX)]	;Function 1:  Tildes wanted?
	sbb	ax,ax		;Yes, get -1 flag in AX-reg.
	mov	[Tildes],ax	;Update Tildes flag.
	clc			;Clear carry flag and exit.
	ret
do_api2	jc s	do_api3		;If function 3, use logic below.
	or	ax,[RdOnly]	;Function 2:  Get read-only flag.
	pop	cx		;Reload CX-reg. and exit.
	ret
do_api3	cmp	ax,[BP_(_BX)]	;Function 3:  Read-write wanted?
	adc	ax,ax		;Yes, get +1 flag in AX-reg.
	mov	[RdOnly],ax	;Update read-only flag.
	clc			;Clear carry flag and exit.
	ret

;
; 10h:	Device request
;  In:	   CX  = CD-ROM drive letter (0 = A, 1 = B, etc)
;	ES:BX -> CD-ROM device driver request header
; Out:	CF clear if device driver has been called
;	   ES:BX request header updated
;	CF set if device driver has not been called
;	   AX = error code (000Fh = invalid drive, 0001h = invalid function)
;	   ES:BX request header unchanged
;
CD_Req	push	ax
	call	SetDDD
	jccl	nz, InvDrv
	pop	bx
	call	DDCall
	cmp	byte [es:bx+rh.Command], rhcmdIOCTL_In
	jne s	CD_ReqX
	les	bx, [es:bx+rhIOCTL.CBPtr]	; on some drives we
	mov	ax, [es:bx]			; will miss media change
	cmp	al, 09h				; if direct access checks
	jne s	CD_ReqX
	dec	ah				; so, if media has changed
	je s	CD_ReqX				; set type to unknown to
	mov	bx, [BP_(DriveOfs)]		; force re-read on next
	mov	byte [bx+DrvEnt.Type], UNKNOWN	; non-direct access
CD_ReqX	clc				; A-Ok from our perspective
	ret

;
; CDtoFCB -- Convert a CD filename to an FCB-style name.
;
;   Inputs:	ES:SI -> directory entry
;		   DX = alias number
;
;   Returns:	SI -> dir_name = FCB name
;
;   Destroys:	AX,BX,CX,DX,DI
;
CDtoFCB	lea	di, [es:si+Nameoff]
	mov	cl, [es:si+FIDLenoff]
	mov	ch, 0
	mov	bx, dir_name
	push	bx

%ifdef JOLIET
	rol	byte [BP_(Joliet)], 1
	jnc s	CD_FCB2
	cmp	byte [es:di], 30h 	; Simple test for Joliet (but
	jae s	CD_FCB2			;  may fail in rare instances)
	shr	cl, 1
	jc s	CD_FCB1			; Not Joliet if odd
	pop	si			; Have DOSLFN convert from Joliet
	mov	bx, dx			;  (Unicode) to FCB (OEM)
	and	bx, [Tildes]
	mov	dl, 0CDh
	mov	ax, 71a8h
	int	21h
	ret
CD_FCB1	rcl	cl, 1			; restore length of shortcut/OEM name
%endif

CD_FCB2	call	ToFCB
	pop	si
	ret

;
; ToDosAT -- Convert CD flags into DOS attribute.
;
;   Inputs:	AL = flags
;
;   Returns:	AL = atttribute
;
;   Destroys:	AH
;
ToDosAT	mov	ah,al		;Copy flags to AH-reg.
	and	ax,00201h	;Mask CD dir flag in AH, hidden in AL.
	shl	ax,1		;Get DOS dir flag (16) in AH,
	shl	ah,1		;  hidden flag (2) in AL-reg.
	shl	ah,1		;Is this a directory?
	jnz s	ToDosA1		;Yes, should NOT be read-only!
	or	ax,[RdOnly]	;"Or" in read-only flag.
ToDosA1	or	al,ah		;Get all flags in AL-reg. and exit.
	ret

;
; PathLU -- Locate the directory containing a filename.
;
;   Inputs:	ES:BX -> name (complete path)
;
;   Returns:	SI -> directory (DirEnt)
;		file_name filled with FCB name
;		Does not return if not found (error 3)
;
;   Destroys:	All
;
PathLU	lea	si, [bx+RootSlashOff]	; find last path separator
	mov	di, si
	mov	cx, si
	jmp s	PathLU3
PathLU1	cmp	al, PATHSEPARATOR
	jne s	PathLU2
	mov	di, si
PathLU2	inc	si
PathLU3	mov	al, [es:si]
	test	al,al
	jnz s	PathLU1
	cmp	di, cx
	jne s	PathLU4
	call	RootEnt
	scasb				; check for trailing separator
	jne s	PathLU5			; yes, point past it
	dec	di			; no, back to the NUL
	jmp s	PathLU5
PathLU4	stosb				; Isolate directory path
	call	LookupD			; Look for the directory
	mov	byte [es:di-1], PATHSEPARATOR  ; Restore full pathname
	jccl	z, InvPath		; Gotta be a dir, not a file
PathLU5	xor	cx, cx			; NUL-terminated
	xor	dx, dx			; No tilde
	mov	bx, file_name		; "Fall thru" to ToFCB

;
; ToFCB -- Converts a filename to DOS form (blank-padded 8+3). If the alias
;	   number is not zero it will be added to the end of the name (the
;	   8 part) after a tilde, if necessary.
;	   Eg: DX = 1, ES:DI -> "readme.html" ==> BX -> "README~1HTM".
;
;   Inputs:	ES:DI -> name
;		   CX = length of name (0 if NUL-terminated)
;		   BX -> buffer for FCB name
;		   DX = alias number
;
;   Returns:	Nothing.
;
;   Destroys:	AX,BX,CX,DX,DI
;
ToFCB	mov	ax, '  '                ; Blank-pad the name
	push	bx
	push	cx
	mov	cl, 11
ToFCB1	mov	[bx], al
	inc	bx
	loop	ToFCB1
	pop	cx
	pop	bx
	mov	al, [es:di]		; Names of 0h and 1h are the
	cmp	al, 1			;  current and parent directories
	jbe s	ToFCB11
	mov	byte [ExtFlag], 0	; check extension
	cmp	al, '.'			; Ignore a leading dot (no name
	jne s	ToFCB2			;  portion) - this may cause
	inc	di			;  non-unique names
	dec	cx
ToFCB2	mov	ah, 8			; Copy up to eight characters
	call	FCBCopy 		;  for the name
	jcxz	ToFCBX
	jc s	ToFCB5
ToFCB3	call	Term			; Skip remaining name characters
	jc s	ToFCB5
	jz s	ToFCB4
	mov	byte [ExtFlag], 0FFh	; skip extension (name is long)
	loop	ToFCB3
ToFCB4	inc	cx
ToFCB5	add	bx, byte 8		; Point to the extension
	dec	cx			; Anything after the dot?
	jz s	ToFCB6
	mov	ah, 3			; Copy up to three characters
	call	FCBCopy 		;  for the extension
ToFCB6	rol	byte [ExtFlag],1
	jc s	ToFCB7
	jcxz	ToFCBX			;  check extension
	call	Term
	jz s	ToFCBX
ToFCB7	xchg	ax, dx
	xor	cx, cx			; Count of digits (CH = 0 for Match)
	and	ax, [Tildes]
	jz s	ToFCBX
ToFCB8	xor	dx, dx
	dec	bx
	div	word [ten]
	inc	cx
	push	dx			; Save digits on the stack
	test	ax,ax
	jnz s	ToFCB8
ToFCB9	dec	bx			; Determine position of tilde
	cmp	byte [bx-1], ' '	;  depending on length of filename
	je s	ToFCB9
	mov	byte [bx], '~'
ToFCB10	pop	ax
	inc	bx
	add	al, '0'
	mov	[bx], al
	loop	ToFCB10
	ret
ToFCB11	mov	al, '.'                 ; "." for current directory
	jne s	ToFCB12			;  and ".." for parent
	mov	ah, al
ToFCB12	mov	[bx], ax
ToFCBX	ret

;
; FCBCopy -- Copy characters from the filename to the FCB name.
;	     The FCB name is uppercased.   Copying stops at dot
;	     ('.'), semicolon (';') or NUL.
;
;   Inputs:	ES:DI -> filename
;		   CX = length of filename
;		   BX -> buffer for FCB name
;		   AH = maximum number of characters to copy
;
;   Returns:	DI and CX updated
;		CY if found dot
;
;   Destroys:	AX
;
FCBCopy push	bx
FCBCpy1	call	Term
	jz s	FCBCpyX
	cmp	al, 'a'			; Convert to upper-case
	jb s	FCBCpy2
	cmp	al, 'z'
	ja s	FCBCpy2
	and	al, ~20h
FCBCpy2	mov	[bx], al
	inc	bx
	dec	ah
	loopnz	FCBCpy1
	clc
FCBCpyX	pop	bx
	ret

;
; Term -- Test for a terminating filename character.
;
;   Inputs:	ES:DI -> character
;
;   Returns:	AL = character
;		DI -> next character
;		CX = 0 if character is ';' or NUL
;		ZR if character is a terminator (one of ".;\0")
;		CY if character is '.'
;
Term	mov	al, [es:di]
	inc	di
	cmp	al, '.'
	stc
	je s	TermX
	cmp	al, ';'
	je s	Term1
	cmp	al, 0
	jne s	TermX
Term1	xor	cx, cx
TermX	ret

;
; LookupD -- Look up a name and ensure it is a directory.
;
;   Inputs:	ES:BX -> path
;
;   Returns:	NZ if found
;		   SI -> directory
;		ZR if not found or not directory
;
LookupD	call	Lookup
	test	si, si
	jz s	LkupDX
	test	byte [si+DirEnt.Fattr], A_SUBDIR
LkupDX	ret

;
; Lookup -- Find a name.
;
;   Inputs:	ES:BX -> path
;
;   Returns:	NC name found
;		   SI -> directory entry
;		   file_name = name in FCB style
;		CY name not found
;		   SI = 0
;		   AX = error
;
;   Destroys:	AX,BX,CX,DX
;
Lookup	push	di
	call	RootEnt			; Start at root
	lea	di, [bx+RootSlashOff]	; Skip drive letters form \\D.\U.
Lookup1	cmp	byte [es:di], 0		; clears carry
	jz s	LookupX
	mov	bx, di
	inc	di
Lookup2	inc	bx
	mov	al, [es:bx]
	cmp	al, PATHSEPARATOR
	je s	Lookup3
	cmp	al, 0
	jne s	Lookup2
Lookup3	mov	cx, bx
	sub	cx, di			; clears carry
	jz s	LookupT
	push	bx
	xor	dx, dx
	mov	bx, file_name
	call	ToFCB
	call	DirLook
	pop	di
	jnc s	Lookup1
LookupX	pop	di
	ret
LookupT	mov	[es:di-1], cl		; remove trailing separator
	jmp s	LookupX

;
; DirLook -- Find a name in a directory.
;
;   Inputs:	SI -> directory
;		file_name = name
;
;   Returns:	NC found
;		   SI -> directory entry
;		CY not found
;		   SI = 0
;		   AX = error
;
;   Destroys:	AX,BX,CX
;
DirLook push	es
	push	di

	; Make sure it really is a directory
	test	byte [si+DirEnt.Fattr], A_SUBDIR
	jnz s	DLook0
	xor	si, si
	mov	al, PATHNOTFOUND
	jmp s	DLookEr
DLook0	push	ds
	pop	es
	mov	bx, [BP_(DriveOfs)]	; Check cache
	lea	bx, [bx+DrvEnt.RootEnt]
	call	getblk
	mov	di, [bx+DirEnt.Forw]
DLook1	cmp	[di+DirEnt.ParentBlk], ax
	jne s	DLook2
	cmp	[di+DirEnt.ParentBlk+2], dx
	jne s	DLook2
	push	si
	push	di
	mov	si, file_name
	mov	cx, 11
	repe	cmpsb
	pop	di
	pop	si
	je s	DLookF
DLook2	mov	di, [di+DirEnt.Forw]
	cmp	di, bx
	jne s	DLook1
	push	dx
	push	ax
	push	bx
	call	FindEnt
	pop	bx
	pop	ax
	pop	dx
	jz s	DLook3
	mov	al, FILENOTFOUND
DLookEr	cbw
	stc
	jmp s	DLookX
DLook3	mov	di, [bx+DirEnt.Back]	; Take from tail of cache queue
	mov	[di+DirEnt.ParentBlk], ax
	mov	[di+DirEnt.ParentBlk+2], dx
%ifdef HS
	mov	bl, [bx+DrvEnt.Type-DrvEnt.RootEnt]
	mov	bh, 0
	mov	al, [si+bx]
%else
	mov	al, [si+isoDir.Flags]
%endif
	call	ToDosAT
	call	DFieldC
	mov	dx, [si+Blkoff+2]
	mov	ax, [si+Blkoff]
	add	al, [si+ExAttroff]
	adc	ah, ch			; CH zero, CL not, from DFieldC
	adc	dx, byte 0
	call	setblk
DLookF	mov	bx, [di+DirEnt.Back]	; Found our boy -- unlink it
	mov	si, [di+DirEnt.Forw]
	mov	[si+DirEnt.Back], bx	; cur->forw->back = cur->back
	mov	[bx+DirEnt.Forw], si	; cur->back->forw = cur->forw
	call	RootEnt			; Relink our boy after RootEnt
	mov	bx, [si+DirEnt.Forw]
	mov	[si+DirEnt.Forw], di	; root->forw = cur
	mov	[di+DirEnt.Forw], bx	; cur->forw = root->forw
	mov	ax, [bx+DirEnt.Back]
	mov	[bx+DirEnt.Back], di	; root->forw->back = cur
	mov	[di+DirEnt.Back], ax	; cur->back = root->forw->back
	mov	si, di
	;clc				; (cleared by RootEnt)
DLookX	pop	di
	pop	es
	ret

;
; FindEnt -- Locate a filename's directory entry.
;
;   Inputs:	SI -> directory to search
;		file_name = name to locate (may contain question marks)
;
;   Returns:	ZR if found
;		   SI -> directory offset
;		   dir_name = name found
;		NZ if not found
;		   SI corrupted
;
;   Destroys:	AX,BX,CX,DX,DI
;
FindEnt	call	DirSize
	mov	di, cx
	and	word [BP_(scratch)], byte 0
	mov	byte [MatchFlag], 0FFh

;
; FindNam -- Find a name in a directory.
;
;   Inputs:	EAX = directory sector
;		 DI = number of sectors
;		 DX = entry number (scratch)
;		 BX -> drive entry
;		file_name = name to locate (may contain question marks)
;
;   Returns:	ZR if found
;		   SI -> directory offset
;		   dir_name = name found
;		NZ if not found
;		   SI corrupted
;		EAX, DI & DX updated
;		BX -> sector buffer
;
FindNam	push	es
	push	ds
	pop	es
	mov	bx, [bx+DrvEnt.Bufp]
FindNm1	call	CdReadB
	jnz s	FindNmX
	push	dx
	mov	dx, [BP_(scratch)]
	mov	si, bx
FindNm2	rol	byte [MatchFlag], 1	;Match only filename (not attrib)?
	jc s	FindNm3			;Yes, use logic below.
	cmp	dx, [GlobEntry]		; Ignore entries < our start entry #
	jb s	FindNm6
	push	ax
	push	si
	add	si, [GlobFlag]
	mov	al, [si]
	pop	si
	call	ToDosAT
	mov	cl, al
	and	al, [GlobAttr]
	cmp	cl, al
	pop	ax
	jne s	FindNm7
FindNm3	push	ax
	push	cx
	push	dx
	push	bx
	push	si
	push	di
	call	CDtoFCB
	mov	cx, 11
FindNm4	dec	si			; dir_name - 1 == file_name + 10
	mov	al, [si]
	;mov	al, [si-1]		; alternative to provide
	;dec	si			;  alignment at cdxsda/Drive
	cmp	al, '?'
	je s	FindNm5
	cmp	al, [si+11]
FindNm5	loope	FindNm4
	pop	di
	pop	si
	pop	bx
	pop	dx
	pop	cx
	pop	ax
FindNm6	jnz s	FindNm7
	mov	[BP_(scratch)], dx
	pop	dx
	jmp s	FindNmX
FindNm7	mov	cl, [si]
	inc	dx
	add	si, cx
	cmp	[si], ch
	jne s	FindNm2
	and	dl, 0c0h
	add	dx, byte 64
	mov	[BP_(scratch)], dx
	pop	dx
	add	ax, byte 1
	adc	dx, byte 0
	dec	di
	jns s	FindNm1
FindNmX	pop	es
	ret

;
; DirSize -- Round the directory size to a number of sectors.
;
;   Inputs:	SI -> directory entry
;
;   Returns:	 BX -> drive entry
;		 CX = sectors in directory, minus one
;		EAX = first directory sector
;
DirSize	mov	bx, [BP_(DriveOfs)]
	mov	dx, [si+DirEnt.FSize+2]
	mov	ax, [si+DirEnt.FSize]
	sub	ax, byte 1
	sbb	dx, byte 0
	call	RShift
	xchg	cx, ax
getblk	mov	dx, [si+DirEnt.BlkNo+2]
	mov	ax, [si+DirEnt.BlkNo]
	ret

;
; RootEnt -- Points SI to a directory root entry.
;
RootEnt	mov	si, [BP_(DriveOfs)]
	add	si, byte DrvEnt.RootEnt	; clears carry
	ret

;
; DDCall -- Call the drive's device driver.
;
;   Inputs:	ES:BX -> request header
;
DDCall	push	ax
	push	si
	mov	si, [BP_(DriveOfs)]
	mov	al, [si+DrvEnt.Unit]
	mov	[es:bx+rh.SubUnit], al
	call	far [si+DrvEnt.Strategyp]
	call	far [si+DrvEnt.Interruptp]
	pop	si
	pop	ax
	ret

;
; CdReadB -- Read a sector from the CD into the drive's buffer.
;
;   Inputs:	EAX = sector number
;
;   Returns:	ZR sector successfully read
;		NZ failed
;		   EAX destroyed
;
;   Destroys:	CX (1)
;
CdReadP	mov	ax, 10h
	cwd
CdReadB	push	es
	push	bx
	push	di
	mov	di, [BP_(DriveOfs)]
	cmp	ax, [di+DrvEnt.BufBlkNo]
	jne s	CdRdBl1
	cmp	dx, [di+DrvEnt.BufBlkNo+2]
	je s	CdRdBl3
CdRdBl1	push	ds
	pop	es
	mov	bx, [di+DrvEnt.Bufp]
	call	CdRdL1
	jz s	CdRdBl2
	mov	dx, -1
CdRdBl2	mov	[di+DrvEnt.BufBlkNo], ax
	mov	[di+DrvEnt.BufBlkNo+2], dx
CdRdBl3	pop	di
	pop	bx
	pop	es
	ret

;
; CdReadL -- Read a number of sectors from the CD into a buffer.
;
;   Inputs:	ES:BX -> buffer
;		  EAX = starting sector number
;		   CX = number of sectors
;
;   Returns:	ZR if successful
;		NZ if failed
;
;   NOTE:  Beginning with the 2-Aug-2012 SHCDX33F, "CDReadL" sets
;     byte 12 of the input-packet header to 1 for a non-directory
;     input, so UDVD2/UIDE can "decline" to cache CD/DVD data and
;     cache only CD/DVD directories.   This saves cache memory!
;
;     Byte 12 for input-packet headers is their ending "reserved"
;     byte, all of which have BEEN "reserved" for 20+ years!   So
;     this change should not cause trouble for anyone!     J.R.E.
;
CdRdL1	mov	cx, 1		;VTOC/Directory:  Leave CH = 0.
	jmp s	CdRdLXX		;Go do VTOC/directory input.
CdReadL	mov	ch, 1		;Normal data input:  Set CH = 1.
CdRdLXX	push	es
	push	bx
	push	di
	mov	di, bx
	mov	bx, rh_rl
	mov	[bx+rhReadLong.Bufp], di
	mov	[bx+rhReadLong.Bufp+2], es
	mov	[bx+rhReadLong.StartBlk], ax
	mov	[bx+rhReadLong.StartBlk+2], dx
	push	word [bx+rhReadLong.Header+11]	;Save last 2 header
	mov	[bx+rhReadLong.Header+12], ch	;  bytes, set "flag".
	mov	ch, 0				;Reset our CH "flag".
	mov	[bx+rhReadLong.Count], cx	;Set input sector ct.
	push	ds
	pop	es
	call	DDCall
	pop	word [bx+rhReadLong.Header+11]	;Reset header bytes.
	cmp	word [bx+rh.Status], 100h
	pop	di
	pop	bx
	pop	es
	ret
	db	0				;(Unused "filler").

align 2

cdxsda	equ	$

; drive table, cache and buffers are set up dynamically here at run time
Drive	equ	$ + cdxsda_len * 2

;
;============================================================================
;
;  EVERYTHING below this line is overwritten or discarded after installation!
;
HelpMsg					;"Help" message, invoked by /?.
db CR
db NM, " [/D:[?|*]DvrNm[,[Lettr][,[Unit][,[MaxUn]]]] [/L:n]]",CR
db "         [/D:n] [/C] [/~[+|-]] [/R[+|-]] [/I] [/U] [/Q[+]]",CR
db CR
db "   DvrNm   CD-ROM driver name.   ?  ignores invalid names.",CR
db "               *  ignores and reserves a drive at install.",CR
db "   Lettr   First letter for this driver's units.",CR
db "   Unit    First driver unit to assign a letter.",CR
db "   MaxUn   Maximum driver units to assign letters.",CR
db "   /L:0    Show number of units (255 = uninstalled).",CR
db "   /L:n    Show unit n data (1 = A:, 2 = B:, 255 = unassigned).",CR
db "   /D:n    On loading, reserve n extra drive tables (default = 8).",CR
db "           If resident, remove last n drives assigned.",CR
db "   /C      Do NOT relocate to high (or low) memory.",CR
db "   /~      Tilde creation:   /~+ on    /~- off (default).",CR
db "   /R      Read-only mode:   /R- off   /R+ on  (default).",CR
db "   /I      Install unconditionally.",CR
db "   /U      Unload.",CR
db "   /Q      Quiet:  /Q omit title  /Q+ show only drive changes.",CR
db "           [/V and MSCDEX /E /K /M /S will be IGNORED]."

CRLF	db	1		;MUST follow "help" message (terminates it)!

OptMsg	db	"Assembled with "	;"Options" message, invoked by /?
%ifndef HS				;  and shown when we are resident.
	db	"No "
%endif
	db	"HighSierra, "
%ifndef CDIMAGE
	db	"No "
%endif
	db	"Image-on-CD, "
%ifndef JOLIET
	db	"No "
%endif
	db	"Joliet, "
%ifndef CDROOT
	db	"No "
%endif
	db	"CD root form.",CR
	db	"User options:  Tilde creation o??"
TDState	equ $-2
	db	"  Read-only mode o??",1
ROState	equ $-3

DrivesInstalled db CR
		db NM," installed.",1
DrivesAssigned	db "  Drives Assigned",1
DrivesRemoved	db "  Drives Removed",1
DriveHeader	db "Drive  Driver   Unit",1
DriveLine	db "  ?:   ????????  ??",1
DrivesAvail	db "0 drive(s) available.",1

UnInstalledMsg	db CR,NM," unloaded.",1
CantUIMsg	db CR,NM," cannot unload!",1

WrongDOSMsg	db CR,"Must be DOS 3.3 or later.",1
DifVersionMsg	db CR,"Different ",NM," version loaded.",1
AlreadyInsMsg	db CR,"CD-ROM Redirector already loaded.",1

NoDriverMsg	db CR,"Cannot open CD driver ",0
NoDriveLtrMsg	db CR,"Need more drive letters.",0
HighUnitMsg	db CR,"Nonexistent units.",0
NoDrivesMsg	db CR,"No drives assigned.",0
NotEnoughMemMsg db CR,"Not enough memory.",0
FullStop	equ $-2
CantInstallMsg	db "  ",NM," cannot load!",1

UnknownOpt	db "Unknown option '"
OptChar 	db "?'.",1
DDriver 	db "/D driver name missing.",1
DLInvalid	db "/D drive letter invalid.",1
DUnitNumber	db "/D first unit (0-99) missing.",1
DMaxNumber	db "/D max. units (1-9) missing.",1
LMissingValue	db "/L unit missing.",1
LNoD		db "/L must follow /D.",1
LBadNumber	db "/L 2-digit maximum.",1

struc DrvrEnt
  .Name 	resb	8+1
  .Drive	resb	1
  .Unit 	resb	1
  .NoWanted	resb	1
  .Ignore	resb	1
endstruc

section .bss align=1			; startup will clear to zero
Drivers 	resb	DrvrEnt_size * MAXDRIVES
NoDrivers	resb	1
DriveIndex	resw	1
ResSeg		resw	1
DevHeader	resw	1
DevSegment	resw	1
DevStrategy	resw	1
DevInterrupt	resw	1
DCacheP		resw	1
IODataP		resw	1
RC		resw	1
KeepSize	resw	1
IsInstalled	resb	1
GoTSR		resb	1
CDSBase 	resd	1
CDSLen		resw	1		; for this DOS version
LastDOSDrive	resb	1
IoctlInBuf	resb	5		; get devhdr addr
InstallIt       resb    1
UnInstallIt	resb	1
HelpMe		resb	1
LoadLow 	resb	1
QuietFlag	resb	1
XQuietFlag	resb	1
		resb	1		;(Unused -- was "VerboseFlag").
BSS_size	equ	$-$$

section .text

BSS_Err	mov	si, NotEnoughMemMsg
	mov	al, RC_MEM
	jmp s	ExitMsg
DiffVer	mov	si, DifVersionMsg
	jmp s	already
AlrInst	mov	si, AlreadyInsMsg
already	mov	al, RC_INSTALLED
	jmp s	ExitMsg

DspHelp	mov	si,CopyrightMsg		;Display desired "help" data.
	call	MsgOut
	mov	si,HelpMsg
	rol	byte [IsInstalled],1
	jnc s	DspHlp3
	call	MsgOut
	mov	es,[ResSeg]
	mov	ax,'n '
	cmp	byte [es:Tildes],0
	jne s	DspHlp1
	mov	ax,'ff'
DspHlp1	mov	[TDState],ax
	mov	ax,'n '
	cmp	byte [es:RdOnly],0
	jne s	DspHlp2
	mov	ax,'ff'
DspHlp2	mov	[ROState],ax
	mov	si,OptMsg
DspHlp3	mov	al,RC_OK
ExitMsg	push	ax
exmsg	call	MsgOut
	pop	ax
ExitAL	mov	ah,04Ch
	int	021h

Begin	cld				;Zero BSS area (init variables).
	cmp	sp, section..bss.start + BSS_size
	jbe s	BSS_Err
	mov	di, section..bss.start
	mov	cx, BSS_size
	xor	al, al
	rep	stosb
	mov	[ResSeg], cs
	mov	word [RC], 04CFFh	; set default return code
	mov	si, Begin5		; is a redirector installed?
	mov	ax, MSCDEX_Q
	mov	bx, SMARTDRV_Q
	push	ax
	mov	ax, (REDIR<<8) + InstallChk
	int	2Fh
	pop	dx
	cmp	bx, SMARTDRV_Q
	je s	Begin3
	cmp	bx, COMPILE_FLAG	; v3 or later is installed
	je s	Begin1
	mov	si, DiffVer
	jmp s	Begin2
Begin1	dec	byte [IsInstalled]
	mov	[ResSeg], es
Begin2	push	ds
	pop	es
	jmp s	Begin4
Begin3	cmp	al, 0ffh
	jne s	Begin4
	cmp	dx, MSCDEX_R
	jne s	Begin4
	mov	si, AlrInst		; another redirector already installed
Begin4	push	si			; get command line parameters
	call	ParseCL
	pop	si
	rol	byte [HelpMe], 1
	jccl	c,DspHelp
	rol	byte [InstallIt], 1
	jnz s	Begin5

	; different/other version installed, didn't want help, so complain
	jmp	si

	; if not installed and /L is used without any drivers, quietly exit
Begin5	mov	al, 255
	rol	byte [IsInstalled], 1
	jc s	.ok1
	cmp	[RC], al
	je s	.ok1
	cmp	byte [NoDrivers], 0
	jccl	z,ExitAL

	; get list of lists address thereby getting DOS seg
.ok1	mov	ah, 52h			; ES:BX is LOLp
	int	21h
	mov	[FN1p+2], es		; set seg of DOS ptrs
	mov	[SDBp+2], es
	mov	[DTApp+2], es
	mov	ax, [es:bx+LoL.CDS]
	mov	dx, [es:bx+LoL.CDS+2]
	mov	[CDSBase], ax
	mov	[CDSBase+2], dx

	; find last available drive letter
	mov	al, [es:bx+LoL.LastDrive]
	dec	ax			; LoL use 1 for 'A'
	mov	[LastDOSDrive], al
	mov	ah, 30h			; set version-specific DOS parameters
	int	21h
	cmp	al, 3
	ja s	.ok2
	jb s	.BadDOS
	cmp	ah, 30
	jb s	.BadDOS
	mov	al, 51h 		; version 3.3+ values
	mov	si, 2ceh+0ch
	mov	bx, 2ceh+92h
	mov	cx, 2ceh+192h
	mov	dx, 2ceh+23ah
	jmp s	.ok3
.BadDOS	mov	si, WrongDOSMsg
	mov	al, RC_DOS
	jmp	ExitMsg
.ok2	mov	al, 58h 		; values for version 4+
	mov	si, 320h+0ch
	mov	bx, 320h+9eh
	mov	cx, 320h+19eh
	mov	dx, 320h+24dh
.ok3	mov	[CDSLen], al
	mov	[DTApp],  si
	mov	[FN1p],   bx
	mov	[SDBp],   cx
	mov	[SAttrp], dx
	rol	byte [UnInstallIt], 1
	jccl	c, UnInstl
	rol	byte [IsInstalled], 1
	jnc s	.ok9
	mov	es, [ResSeg]
	mov	cl, [ResDrives]
	mov	ch, 0
	call	RmvDrv
	and	byte [ResDrives], 0
	cmp	byte [NoDrivers], 0
	jnz s	.ok8
	rol	byte [LoadLow], 1
	jccl	c, AlrInst
	mov	al, RC_OK
	call	GetRC
	jmp	ExitAL
.ok8	mov	al, [es:ResDrives]
	test	al, al
	jccl	z, AlrInst
	mov	[ResMax], al
	dec	byte [QuietFlag]
.ok9	rol	byte [QuietFlag], 1	; take advantage of the photo op
	jc s	.quiet
	mov	si, CopyrightMsg
	call	MsgOut
.quiet	mov	di, Drive		; assign drives
	mov	si, Drivers
	jmp s	.quiet2
	; Open device driver and use IOCTL Input sub-command 0 to get
	; the device header address.
.quiet0	mov	dx, si			; DrvrEnt.Name
	mov	ax, 3D00h		; read only
	int	21h
	jnc s	.notcd1			; error when carry set
.notcd	cmp	byte [si+DrvrEnt.Ignore], '*'
	jccl	b, NoDrivr		; 0
	jne s	.quiet1			; '?'
	rol	byte [IsInstalled], 1
	jc s	.quiet1
	inc	byte [ResDrives]
	jmp s	.quiet1
.notcd1	xchg	bx, ax			; move handle to bx
	mov	cx, 5			; dta has cmd code plus a fptr
	mov	dx, IoctlInBuf		;   to device header
	mov	ax, 4402h		; IOCTL input-get devhdr addr
	int	21h
	pushf
	mov	ah, 3eh			; close file handle in bx
	int	21h
	popf
	jc s	.notcd			; error when carry set
	les	bx, [IoctlInBuf+1]
	call	AssignD
.quiet1	add	si, byte DrvrEnt_size
.quiet2	dec	byte [NoDrivers]
	jns s	.quiet0
	mov	al, [DriveIndex]
	mov	[NoDrives], al
	add	al, [ResDrives]
	jnz s	.qiet2A
	mov	si, NoDrivesMsg		; no drives assigned or reserved
	mov	al, RC_DRIVE
	jmp	IExMsg
.qiet2A	rol	byte [IsInstalled],1
	jc s	.quiet3
	mov	cl, al
	mov	ch, 0
	mov	al, DrvEnt_size 	; find Drive Table space needed
	mul	cl
	add	ax, Drive
%ifdef DOSMOVES
	call	DR_DOSI
%endif
	mov	[DCacheP], ax	 	; relocate dir cache
	mov	ax, CACHESIZE		; find cache space needed
	mul	cx
	add	ax, [DCacheP]
	mov	[IODataP], ax		; relocate IOData buffers
	mov	ax, SECTORSIZE + 4	; find buffer space needed (add one for
	mul	cx			;  a directory scan sentinel)
	add	ax, [IODataP]		; last byte to keep now in ax
	jccl	c, ShortM
	call	AllocM
	rol	byte [XQuietFlag], 1
	jc s	.quiet3
	mov	si, DrivesInstalled
	call	MsgOut
.quiet3	mov	al, [Drive+DrvEnt.No]	; Display drive assignments
	mov	[FirstDriveNo], al
	mov	cx, [NoDrives]
	rol	byte [IsInstalled], 1
	jnc s	.quiet4
	mov	es, [ResSeg]
	mov	al, [es:ResDrives]
	sub	al, cl
	mov	[ResDrives], al
.quiet4	push	ds
	pop	es
	mov	bx, Drive
	mov	si, DrivesAssigned
	call	DsplDrv
	mov	cx, [NoDrives]		;Set current directory structure
	mov	di, Drive		;  with the new drives (if any).
	jcxz	.SRoot2
.SRoot1	mov	ax, [di+DrvEnt.No]	; AH = .Unit
	les	bx, [di+DrvEnt.DevHdrp]
	inc	ax
	mov	[es:bx+20], al		; set drive number in device header
	dec	ax
	push	ax
	mul	byte [CDSLen]
	les	bx, [CDSBase]
	add	bx, ax
	pop	ax
	mov	word [es:bx+CDS.Flags], 0C080h	; physical network & redir bits
	or	word [es:bx+CDS.Redir], byte -1
	or	word [es:bx+CDS.Redir+2], byte -1
	mov	word [es:bx+CDS.RootOff], RootSlashOff	; root \ in curr_path
	add	al, 'A'
%ifdef CDROOT
	; Set to CD root form \\D.\U.
	mov	word [es:bx+CDS.CurrPath], '\\'
	mov	[es:bx+CDS.CurrPath+2], al
	mov	word [es:bx+CDS.CurrPath+3], '.\'
	add	ah, 'A'
	mov	[es:bx+CDS.CurrPath+5], ah
	mov	word [es:bx+CDS.CurrPath+6], '.'
%else
	mov	[es:bx+CDS.CurrPath], al
	mov	word [es:bx+CDS.CurrPath+1], ':'
%endif
	add	di, byte DrvEnt_size
	loop	.SRoot1
.SRoot2	rol	byte [IsInstalled], 1
	jnc s	.quiet5
	mov	es, [ResSeg]		;Copy drive tables from "temp"
	mov	al, DrvEnt_size		;  to resident program memory.
	mul	byte [es:NoDrives]
	mov	si, Drive
	mov	di, si
	add	di, ax
.CopyD1	mov	cx, DrvEnt.Bufp
	rep	movsb
	add	si, byte DrvEnt_size - DrvEnt.Bufp
	add	di, byte DrvEnt_size - DrvEnt.Bufp
	inc	byte [es:NoDrives]
	dec	byte [es:ResDrives]
	dec	byte [NoDrives]
	jnz s	.CopyD1
	mov	al, [FirstDriveNo]
	inc	ax
	call	GetRC
	jmp	ExitAL
%ifdef JOLIET
.quiet5	mov	dx, DOSLFN_Q		; is DOSLFN running?
	mov	ax, 7146h
	int	21h
	cmp	ax, DOSLFN_R		; it's installed, check if it's active
	jne s	.quiet6
	mov	es, dx
	mov	al, [es:103h]		; ctrl0
	not	al			; active & CDROM support
	test	al, 088h
	jne s	.quiet6
	dec	byte [Joliet]		; we have LFN, so use Joliet
.quiet6	jmp	Install
%else
.quiet5	jmp	Install
%endif
UnInstl	rol	byte [IsInstalled], 1
	jnc s	CantUI
	mov	ax, 352fh		; check if the vector is still ours
	int	21h
	mov	ax, es
	cmp	ax, [ResSeg]
	jne s	CantUI
	cmp	bx, New2F
	jne s	CantUI
	mov	cx, [es:NoDrives]
	jcxz	UnInst1
	mov	di, Drive
	call	ClrRoot
UnInst1	push	ds
	lds	dx, [es:Old2F]		; restore vector
	mov	ax, 252Fh
	int	21h
	pop	ds
	mov	ax, es			; determine the MCB
	add	ax, byte (Res_Begin - 40h) >> 4
	mov	es, ax			; point back to the PSP
	cmp	word [es:0], 20cdh	; check for the PSP signature
	je s	UnInst2			; no PSP, so it was relocated
	add	ax, byte 4
	mov	es, ax
UnInst2	mov	ah, 49h			; free memory
	int	21h
	mov	si, UnInstalledMsg
	mov	al, RC_OK
	jmp	ExitMsg
CantUI	mov	si, CantUIMsg
	mov	al, RC_UNINST
	jmp	ExitMsg
NoDrivr	push	si
	mov	si, NoDriverMsg
	call	MsgOut
	pop	si
	call	MsgOut				; DrvrEnt.Name
	mov	si, FullStop
	mov	al, RC_CD
	jmp s	IExMsg
BadUnit	mov	si, HighUnitMsg
	mov	al, RC_UNIT
	jmp s	IExMsg
ShortM	mov	si, NotEnoughMemMsg
	mov	al, RC_MEM
IExMsg	push	ax
	call	MsgOut
	mov	si, CantInstallMsg
	rol	byte [IsInstalled], 1
	jnc s	IExMsg1
	mov	si, CRLF
IExMsg1	jmp	exmsg

;
; AssignD -- Find a drive letter for each unit on a device.
;
;   Inputs:	ES:BX -> device driver header
;		   SI -> driver entry
;		   DI -> drive entry
;
AssignD	mov	[DevHeader], bx
	mov	[DevSegment], es
	mov	ax, [es:bx+6]
	mov	[DevStrategy], ax
	mov	ax, [es:bx+8]
	mov	[DevInterrupt], ax
	mov	dh, [si+DrvrEnt.Unit]	; first unit wanted
	mov	al, [es:bx+21]		; number of units on driver
	sub	al, dh
	jbe s	BadUnit
	mov	cl, [si+DrvrEnt.NoWanted]  ; units asked for
	mov	ch, 0
	jcxz	AsgnDr1
	cmp	cl, al			; don't exceed available units
	jbe s	AsgnDr2
AsgnDr1	mov	cl, al
AsgnDr2	mov	dl, [si+DrvrEnt.Drive]
	cmp	dl, [DriveNo]
	jnb s	AsgnDr3
	mov	dl, [DriveNo]
AsgnDr3	mov	al, [DriveIndex]
	cmp	al, [ResMax]
	jae s	AsgnDrX
	mov	al, [CDSLen]		;Find 1st available drive letter.
	mul	dl
	les	bx, [CDSBase]
	add	bx, ax
	jmp s	FindDL2
FindDL1	test	byte [es:bx+CDS.Flags+1], 0C0h  ; drive in use ?
	jz s	FindDL3
	inc	dx
	add	bx, [CDSLen]
FindDL2	cmp	dl, [LastDOSDrive]
	jbe s	FindDL1
	mov	si, NoDriveLtrMsg	;NO driver letter available!
	mov	al, RC_LETTER
	jmp	IExMsg
FindDL3	mov	[di+DrvEnt.No], dx	;Set unit and initial drive info.
	mov	byte [di+DrvEnt.Type], UNKNOWN
	mov	ax, [DevSegment]
	mov	[di+DrvEnt.DevHdrp+2], ax
	push	word [DevHeader]
	pop	word [di+DrvEnt.DevHdrp]
	mov	[di+DrvEnt.Strategyp+2], ax
	push	word [DevStrategy]
	pop	word [di+DrvEnt.Strategyp]
	mov	[di+DrvEnt.Interruptp+2], ax
	push	word [DevInterrupt]
	pop	word [di+DrvEnt.Interruptp]
	inc	dx			; next drive number
	inc	dh			; next device unit
	inc	byte [DriveIndex]
	add	di, byte DrvEnt_size
	loop	AsgnDr3
AsgnDrX	mov	[DriveNo], dl
	ret

%ifdef DOSMOVES
;
; DR-DOS moves the DOS segment between CONFIG and AUTOEXEC, so SHSUCDX will
; not work if it's INSTALLed. Fortunately, Int31 points to it (v7.01.07).
; This code gets relocated between the drives and the dir cache, if required.
; Update: the latest version has INSTALLLAST, so this is no longer needed.
;
DR_DOSS	push	ds
	push	ax
	xor	ax, ax
	mov	ds, ax
	mov	ax, [31h*4+2]
	mov	[FN1p+2], ax
	mov	[SDBp+2], ax
	mov	[DTApp+2], ax
	pop	ax
	pop	ds
	cmp	ah, MSCDEX
	ret
DR_DOSS_size equ $-DR_DOSS

;
; DR_DOSI -- Test for DR-DOS and relocate the DOS segment code.
;
;   Inputs:	AX = address of relocation
;
;   Returns:	AX = updated address for directory cache
;
DR_DOSI	push	cx			; see if we are using DR-DOS by
	xor	cx, cx			; checking the Int 31h segment
	mov	es, cx
	mov	cx, [es:31h*4+2]
	cmp	cx, [FN1p+2]
	jne s	DR_DOSX
	push	ds
	pop	es
	mov	si, DR_DOSS
	mov	di, ax
	mov	cx, DR_DOSS_size
	rep	movsb
	sub	ax, DR_DOS+3
	mov	byte [DR_DOS], 0E8h	; CALL
	mov	[DR_DOS+1], ax
	xchg	ax, di
DR_DOSX	pop	cx
	ret
%endif

;
; AllocM -- Allocate memory or use the PSP.
;
;   Inputs:	AX = last byte to keep
;
;   Returns:	[KeepSize] = paragraphs to keep
;		[ResSeg] = segment to install to
;		[GoTSR] = on if relocating into PSP
;
AllocM	add	ax, 0Fh - Res_Begin	; roundup, program size
	mov	cl, 4
	shr	ax, cl			; program paragraphs to keep
	mov	[KeepSize], ax
	rol	byte [LoadLow], 1
	jc s	AllocM3
	; try allocating memory
	mov	ax, 5802h		; get current UMB state
	int	21h
	cbw				; returns byte, but sets by word
	push	ax			; save it
	mov	ax, 5800h		; get current allocation strategy
	int	21h
	push	ax			; save it
	mov	bx, 1			; link in UMB
	mov	ax, 5803h
	int	21h
	cmp	word [ResSeg], 0A000h	; already high?
	mov	bl, 0			; high or low memory, first fit
	jnb s	AllocM1
	mov	bl, 80h
AllocM1	mov	ax, 5801h
	int	21h
	mov	bx, [KeepSize]
	mov	ah, 48h
	int	21h
	pushf
	jc s	AllocM2
	push	ax
	sub	ax, byte Res_Begin >> 4	; adjust segment for our offset
	mov	[ResSeg], ax
	pop	ax
	dec	ax			; MCB of TSR
	mov	es, ax
	inc	ax
	mov	[es:1], ax		; make it own itself
	push	ds
	mov	cx, cs
	dec	cx			; MCB of installer
	mov	ds, cx
	mov	si, 8			; copy the MCB name
	mov	di, si
	mov	cx, si
	rep	movsb
	pop	ds
AllocM2	pop	dx
	pop	bx			; restore allocation strategy
	mov	ax, 5801h
	int	21h
	pop	bx			; restore UMB state
	mov	ax, 5803h
	int	21h
	shr	dl, 1
	jnc s	AllocMX
	mov	ax, [KeepSize]		; no memory, do the PSP relocate
AllocM3	add	ax, byte 4		; save bytes by relocating into PSP
	mov	cx, cs			; (need to keep first 40h bytes)
	dec	cx			; MCB
	mov	es, cx			; find out how much memory we have
	cmp	[es:3], ax
	jccl	b, ShortM
	mov	[KeepSize], ax
	sub	word [ResSeg], byte (Res_Begin - 40h) >> 4
	dec	byte [GoTSR]
AllocMX	ret

;
; ParseCL -- Determine the command line arguments.
;
;   Inputs:	None.
;
;   Returns:	Option flags set.
;
ParseCL	mov	di, 81h
	mov	bl, [di-1]		; command line length psp +80h
	mov	bh, 0
	mov	[di+bx], bh		; NUL terminate
ParsCL1	call	GetParm
	jc s	ParsCL4
	push	di
	mov	di, Options
ParsCL2	scasw			; skip over address
	scasb
	jb s	OptUnk
	jne s	ParsCL2
ParsCL3	call	[di-3]
	jc s	BadOpt
	pop	di
	jmp s	ParsCL1
ParsCL4	cmp	byte [NoDrivers], 0
	jnz s	OptIgn
	rol	byte [IsInstalled], 1
	jc s	OptIgn
	dec	byte [HelpMe]
OptIgn	ret
OptUnk	mov	si, UnknownOpt
BadOpt	mov	al, RC_OPT
	jmp	ExitMsg

;
; GetParm -- Retrieve the next command line option and its value, if any.
;	     Options may be preceded by '/' or '-'; its value may be
;	     preceded with ':'.
;
;   Inputs:	DI -> command line (NUL terminated)
;
;   Returns:	NC if argument found
;		   AL = argument (uppercase)
;		   SI -> argument's value
;		   CX = length of value
;		   DI -> next argument
;		CY if no more options
;
GetParm	mov	al, [di]
	inc	di
	test	al, al
	jz s	GetPar4
	cmp	al, ' '
	jbe s	GetParm
	cmp	al, '/'
	je s	GetPar0
	cmp	al, '-'
	jne s	GetPar1
GetPar0	mov	al, [di]
	inc	di
	test	al, al
	jz s	GetPar4
GetPar1	call	ToUpper
	mov	[OptChar], al
	cmp	byte [di], ':'
	jne s	GetPar2
	inc	di
GetPar2	mov	si, di
	xor	cx, cx
GetPar3	mov	ah, [di]
	cmp	ah, ch
	je s	GetParX
	cmp	ah, ' '
	je s	GetParX
	cmp	ah,'/'
	je s	GetParX
	inc	di
	inc	cx
	jmp s	GetPar3
GetPar4	stc
GetParX	ret

;
; ProcessParm -- Process a command line argument.
;
;   Inputs:	AL = argument (uppercase)
;		SI -> argument's value
;		CX = length of value
;		NC
;
;   Returns:	CY if invalid argument
;		   SI -> error message
;
Opt?	dec	byte [HelpMe]		; /? display help and exit
	ret
OptI	dec	byte [InstallIt]	; /I install anyway
	mov	byte [IsInstalled], 0
	mov	[ResSeg], cs
	ret
OptU	dec	byte [UnInstallIt]	; /U uninstall driver
	ret
OptC	dec	byte [LoadLow]		; /C load in conventional memory
	ret
OptQ	dec	byte [QuietFlag]	; /Q[+|Q] quiet
	jcxz	OptQX
	lodsb
	cmp	al, '+'
	jne s	OptQX
	dec	byte [XQuietFlag]
OptQX	clc
	ret
Opt~	mov	bx, Tildes		; /~[+|-] toggle/set/unset tilde usage
	call	PlusMin
	jnz s	OptT1
	sbb	ax, ax			; CY => -1, NC => 0
	mov	[bx], ax
OptT1	xor	word [bx], byte -1	; clears carry (NOT doesn't)
OptTX	push	cs
	pop	ds
	ret
OptR	mov	bx, RdOnly		; /R[+|-] toggle/set/unset read-only
	call	PlusMin
	jnz s	OptR1
	adc	ax, ax			; CY => +1, NC => 0
	mov	[bx], ax
OptR1	xor	word [bx], byte 1	; clears carry
	jmp s	OptTX

;
; PlusMin -- Process a plus or minus for /R and /~ switches.
;
PlusMin	xor	ax,ax		;Set "NZ" flag for above.
	inc	ax
	jcxz	PlusMnX		;If no value, exit with "NZ".
	dec	ax		;Clear AX-reg. for above.
	cmp	byte [si],'+'	;Is next byte a plus?
	je s	PlusMnX		;Yes, exit with "Z".
	cmp	byte [si],'-'	;Is next byte a minus?
	jne s	PlusMnX		;No, exit with "NZ".
	stc			;Set carry flag for minus.
PlusMnX	mov	ds,[ResSeg]	;Get resident-code segment.
	ret			;Exit.

;
; DoDrivr -- Process the /D option.
;
;   Inputs:	SI -> values
;		CX = length of values
;
;   Returns:	CY if error
;		   SI -> error message
;
DoDrivr	cmp	byte [si], '1'		; reserved drive count
	jb s	DoDvr1
	cmp	byte [si],'9'
	ja s	DoDvr1
	cmp	cx, byte 1
	jne s	DoDvr1
	lodsb
	sub	al, '0'                 ; clears carry
	mov	[ResDrives], al
	ret
DoDvr1	mov	bx, [DriverIndex]
	add	word [DriverIndex], byte DrvrEnt_size
	inc	byte [NoDrivers]
	mov	di, si
	call	DvrOpt			; driver
	test	dx,dx
	jnz s	.err1
	rol	byte [IsInstalled],1
	jz s	.err1
	mov	es, [ResSeg]
	mov	bx, Drive
	mov	si, DrivesAssigned
	mov	cx, [es:NoDrives]
	call	DsplDrv
	mov	al, [es:NoDrives]
	jmp	ExitAL
.err	mov	si, DDriver
	stc
	ret
.err1	mov	al, [si]
	cmp	al, '?'
	je s	.err2
	cmp	al, '*'
	jne s	.err3
.err2	mov	[bx+DrvrEnt.Ignore], al
	inc	si
	dec	dx
	jz s	.err
.err3	push	cx
	push	di
	lea	di, [bx+DrvrEnt.Name]
	mov	cl, 8			; eight characters max.
.err4	lodsb
	call	ToUpper
	stosb
	dec	dx
	loopnz	.err4
	pop	di
	pop	cx
	call	DvrOpt			; drive letter
	test	dx,dx
	jz s	.err7
	cmp	dx, byte 1
	jne s	.err5
	lodsb
	and	al, ~20h
	sub	al, 'A'
	cmp	al, 32
	jb s	.err6
.err5	mov	si,DLInvalid		;Not a valid drive -- change
	mov	byte [si+1],'D'		;  to /D in "invalid" message.
	stc
	ret
.err6	mov	[bx+DrvrEnt.Drive], al
.err7	call	DvrOpt			; first device unit
	test	dx,dx
	jz s	.err99B
	cmp	dx, byte 2
	jbe s	.err99A
.err99	mov	si, DUnitNumber
	stc
	ret
.err99A	call	AtoI
	jc s	.err99
	mov	[bx+DrvrEnt.Unit], al
.err99B	call	DvrOpt			; maximum drives
	test	dx,dx
	jz s	DoDvrX
	cmp	dx, byte 2
	jb s	.err10
.err9	mov	si, DMaxNumber
	stc
	ret
.err10	call	AtoI
	jc s	.err9
	mov	[bx+DrvrEnt.NoWanted], al
DoDvrX	ret

;
; DvrOpt -- Retrieve a driver option.
;
;   Inputs:	DI -> start of option
;		CX = length of all remaining options
;
;   Returns:	SI -> start of option
;		DX = option length
;		DI -> start of next option
;		CX = remaining length
;
DvrOpt	xor	dx,dx
	jcxz	DvrOptX
	mov	si, di
DvrOpt1	lodsb
	dec	cx
	cmp	al, ','
	je s	DvrOpt2
	inc	dx
	test	cx, cx
	jnz s	DvrOpt1
DvrOpt2	xchg	si, di
DvrOptX	ret

;
; DoLtr -- Process the /L option.
;
;   Inputs:	SI -> values
;		CX = length of values
;
;   Returns:	CY if error
;		   SI -> error message
;
DoLtr	jcxz	DoLtr4			; /L requires a value
	cmp	cx, byte 2		; set flags for AtoI
	push	si
	call	AtoI
	pop	si
	jc s	DoLtr1
	mov	[RC], al
	mov	si, LBadNumber
	cmp	cx, byte 3
	cmc
	ret
DoLtr1	mov	di, [DriverIndex]
	cmp	di, Drivers
	jne s	DoLtr2
	mov	si, LNoD		; Haven't seen /D
	stc
	ret
DoLtr2	lodsb
	and	al, ~20h
	sub	al, 'A'
	cmp	al, 32
	jae s	DoLtr3
	sub	di, byte DrvrEnt_size - DrvrEnt.Drive
	stosb
	ret
DoLtr3	mov	si,DLInvalid		;Not a valid letter -- change
	mov	byte [si+1],'L'		;  to /L in "invalid" message.
	stc
	ret
DoLtr4	mov	si, LMissingValue
	stc
DoLtrX	ret

;
; RmvDrv -- Remove drives from the end of the list.
;
;   Inputs:	CX = number of drives to remove
;		ES -> resident segment
;
RmvDrv	mov	al, [es:NoDrives]
	cmp	cl, al			; can't remove more than assigned
	jbe s	RmvDrv1
	mov	cl, al
RmvDrv1	jcxz	DoLtrX
	sub	[es:NoDrives], cl
	add	[es:ResDrives], cl
	sub	al, cl
	mov	dl, DrvEnt_size
	mul	dl
	mov	di, Drive
	add	di, ax			; ES:DI -> first drive to remove
	push	cx
	call	ClrRoot
	pop	cx
	mov	si, DrivesRemoved
	mov	bx, di			;(Falls through to "DsplDrv").

;
; DsplDrv -- Display the drive letter associated with each driver and
;	     unit (if any) and the number of available drives.
;
;   Inputs:	   SI -> message header
;		   CX = number of drives
;		ES:BX -> Drive table
;
DsplDrv	jcxz	DspDrv8
	rol	byte [XQuietFlag], 1
	jc s	DspDrv1
	call	MsgOut
	mov	si, DriveHeader
	call	MsgOut
	mov	si, DriveLine
	jmp s	DspDrv4
DspDrv1	rol	byte [IsInstalled], 1
	jnc s	DspDrv3
	cmp	si, DrivesAssigned
	mov	si, DriveLine+1
	mov	byte [si], '-'
	jne s	DspDrv2
	mov	byte [si], '+'
DspDrv2	jmp s	DspDrv4
DspDrv3	mov	si, DriveLine+2
DspDrv4	mov	al, [es:bx+DrvEnt.No]
	add	al, 'A'
	mov	[DriveLine+2], al
	push	ds
	push	es
	push	si
	lds	si, [es:bx+DrvEnt.DevHdrp]
	add	si, byte 10		; driver name in header
	push	cs
	pop	es
	mov	di, DriveLine+7
	movsw
	movsw
	movsw
	movsw
	pop	si
	pop	es
	pop	ds
	mov	ah, ' ' - '0'           ; convert drive unit to ASCII
	mov	al, [es:bx+DrvEnt.Unit]
	cmp	al, 10
	jb s	DspDrv6
	aam
DspDrv6	add	ax, '00'
	xchg	al, ah
	mov	[DriveLine+17], ax
	push	si
	call	MsgOut
	pop	si
	add	bx, byte DrvEnt_size
	loop	DspDrv4
	jmp s	DspDrv9
DspDrv8	rol	byte [XQuietFlag], 1
	jc s	DspDrv9
	mov	si, NoDrivesMsg+1
	call	MsgOut
	mov	si, CRLF
	call	MsgOut
DspDrv9	rol	byte [XQuietFlag], 1
	jc s	MsgOutX
	mov	al, [es:ResDrives]
	test	al,al
	jz s	MsgOutX
	mov	si, DrivesAvail
	add	[si], al	;(Falls through to "MsgOut").

;
; MsgOut -- Outputs an ASCII message string ending with a "zero" or a
;	    "one".   A "one" makes this routine suffix a CR/LF.   Any
;           CR in the string causes a LF to be added by this routine.
;
;   Inputs:	SI -> message
;
;   Returns:	Nothing.
;
;   Destroys:	AX,DL,SI
;
MsgOut	mov	ah,002h 	;Get DOS "display byte" code.
	lodsb			;Get next output byte.
	cmp	al,001h		;What kind of byte is this?
	jb s	MsgOutX		;Null "terminator" -- exit now.
	je s	MsgOutT		;CR/LF "terminator" -- output them.
	call	MsgOutB		;Output this message byte.
	jmp s	MsgOut		;Go get next message byte.
MsgOutT	mov	al,CR		;Replace "terminator" with CR.
MsgOutB	push	ax		;Save and display output byte.
	mov	dl,al
	int	021h
	pop	ax		;Reload output byte.
	cmp	al,CR		;Was byte a CR?
	jne s	MsgOutX		;No, go exit.
	mov	dl,LF		;Display a LF, too!
	int	021h
MsgOutX	ret			;Exit.

;
; ClrRoot -- Remove drives from the Current Directory Structure.
;
;   Inputs:	ES:DI -> first drive
;		   CX = number of drives (not zero)
;
ClrRoot push	ds
	lea	si, [di+DrvEnt.No]
ClRoot1	mov	al, [es:si]
	mul	byte [cs:CDSLen]
	lds	bx, [cs:CDSBase]
	add	bx, ax
	cmp	word [bx+CDS.Flags], 0C080h  ; physical net redir drive ?
	jne s	ClRoot2
	and	word [bx+CDS.Flags], byte 0  ; clear drive flags
	and	word [bx+CDS.Redir], byte 0
	and	word [bx+CDS.Redir+2], byte 0
%ifdef CDROOT
	mov	ax, 'A:'
	add	al, [es:si]
	mov	[bx+CDS.CurrPath], ax
	mov	word [bx+CDS.CurrPath+2], '\'
%else
	and	byte [bx+CDS.CurrPath+3], 0
%endif
ClRoot2	add	si, byte DrvEnt_size
	loop	ClRoot1
	pop	ds
	ret

;
; AtoI -- Convert one or two characters to a number.
;
;   Inputs:	SI -> characters
;		ZR for two digits
;		NZ for one digit
;
;   Returns:	NC if succeeded
;		   AL = number
;		CY if failed
;
AtoI	mov	ah, 0
	jnz s	AtoI1
	lodsb
	sub	al, '0'
	cmp	al, 10
	jae s	AtoIX
	mov	ah, al
AtoI1	lodsb
	sub	al, '0'
	cmp	al, 10
	jae s	AtoIX
	aad
	stc
AtoIX	cmc
	ret

;
; ToUpper -- Converts a letter to uppercase.
;
;   Inputs:	AL = character
;
;   Returns:	AL = uppercase letter or unchanged
;
ToUpper	cmp	al, 'a'
	jb s	ToUpprX
	cmp	al, 'z'
	ja s	ToUpprX
	and	al, ~20h
ToUpprX	ret

;
; Insert filler so nothing is trashed when directory caches are linked.
;
%if $-Drive < MAXDRIVES*(DrvEnt_size+CACHESIZE)
  times MAXDRIVES*(DrvEnt_size+CACHESIZE) - ($-Drive) nop
%endif

;
; "Final Installation" Routine (here so it is ABOVE the drive tables!).
;
Install	mov	cx, [NoDrives]		;Initialize all drive tables
	add	cl, [ResDrives]		;  and link directory caches.
	mov	bx, Drive
Instal0	push	cx			;Save remaining drive count.
	mov	ax, [IODataP]
	mov	[bx+DrvEnt.Bufp], ax
	mov	di, [DCacheP]		; link up cache for dir entries
	mov	[bx+DrvEnt.RootEnt+DirEnt.Forw], di
	lea	si, [di+DirEnt_size]
	mov	[di+DirEnt.Forw], si	; first entry points forward to second
	lea	ax, [bx+DrvEnt.RootEnt]
	mov	[di+DirEnt.Back], ax	; and backwards to root
	mov	cx, CACHEENTRIES - 1
Instal1	mov	[si+DirEnt.Back], di	; second entry points backward to first
	mov	di, si
	add	si, byte DirEnt_size
	mov	[di+DirEnt.Forw], si	; and forward to next
	loop	Instal1
	mov	[di+DirEnt.Forw], ax	      ; last entry points forw to root
	mov	[bx+DrvEnt.RootEnt+DirEnt.Back], di ; root points back to last
	add	word [DCacheP], CACHESIZE
	add	word [IODataP], SECTORSIZE + 4
	add	bx, byte DrvEnt_size
	pop	cx			;Reload remaining drive count.
	loop	Instal0			;If more drives to go, loop back.
	mov	al, [FirstDriveNo]	; return with first drive number
	inc	ax			; A=1
	call	GetRC
	mov	[RC], al
	rol	byte [GoTSR], 1
	jnc s	Instal2
	mov	byte [RC+1], 31h	; TSR exit
	xor	cx, cx
	xchg	cx, [2Ch]		; zap evironment pointer in PSP
	jcxz	Instal2			; CX = environment ptr
	mov	es, cx			; no environment if zero
	mov	ah, 49h			; release environment
	int	21h
Instal2	mov	ax, 352Fh		; store original 2F vector
	int	21h
	mov	[Old2F], bx
	mov	[Old2F+2], es
	push	word [KeepSize]		;Stack "CritIni" parameters.
	push	word [RC]
	push	word [IODataP]
	mov	es, [ResSeg]		; copy to the resident memory
	mov	di, CritIni		; no need to copy the stack
	push	es
	push	di
	mov	[rh_io+rhIOCTL.CBPtr+2], es	; relocation item
	mov	si, di
	mov	cx, [Drive+DrvEnt.Bufp] ; don't copy the sector buffers
	sub	cx, si
	rep	movsb
	push	es			; set new 2F vector
	pop	ds
	mov	dx, New2F
	mov	ax, 252Fh
	int	21h
	retf				; jump to critical init and exit

;
; GetRC -- Determine the exit code.
;
;   Inputs:	AL = default code
;
;   Returns:	AL = exit code as specified by /L
;
GetRC	cmp	byte [RC], 255
	je s	GetRCX
	mov	es, [ResSeg]
	mov	al, [RC]
	mov	ah, [es:NoDrives]
	test	al, al
	jnz s	GetRC1
	mov	al, ah
	ret
GetRC1	cmp	al, ah
	jna s	GetRC2
	mov	al, 255
	ret
GetRC2	mov	ah, DrvEnt_size
	dec	ax
	mul	ah
	xchg	bx, ax
	mov	al, [es:bx+Drive+DrvEnt.No]
	inc	ax
GetRCX	ret
