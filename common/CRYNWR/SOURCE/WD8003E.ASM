version	equ	0

;  Copyright, 1992, Russell Nelson, Crynwr Software

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

	include	defs.asm

code	segment para public
	assume	cs:code, ds:code

	org	100h
start:
	jmp	start_1

copyleft_msg	label	byte
 db "The WD8003E driver has been renamed ``SMC_WD''."
 db CR,LF,'$'

start_1:
	mov	dx,offset copyleft_msg
	mov	ah,9
	int	21h

	int	20h

code	ends

	end	start
