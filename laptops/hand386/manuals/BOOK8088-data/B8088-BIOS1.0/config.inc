;=========================================================================
; config.inc - Compilation time settings and settings
;-------------------------------------------------------------------------
;
; Compiles with NASM 2.11.08, might work with other versions
;
;
;=========================================================================

%define DATE		'12/20/22'	; BIOS release date MM/DD/YY
%define VERSION		'1.0.2'		; BIOS version

; Machine type is defined in the Makefile
;%define MACHINE_XI8088			; Xi 8088
;%define MACHINE_FE2010A 			; Faraday FE2010A
;%define MACHINE_XT			; IBM PC/XT or highly compatible board
					; FIXME: not implemented yet
; Settings for Xi 8088
%ifdef MACHINE_XI8088
%define	START		8000h		; BIOS starts at offset 8000h
%define MODEL_BYTE	0FCh		; Pretend it is an IBM PC/AT 假装它是IBM PC/AT
;%define AT_KEYBOARD
%define MIN_RAM_SIZE	32		; At least 32 KiB to boot the system
%define MAX_RAM_SIZE	640		; Scan this much memory during POST
%define RAM_TEST_BLOCK	16384		; block size for RAM test

%endif ; MACHINE_XI8088

; Settings for IBM PC/XT
%ifdef MACHINE_XT
;%define	START		0E000h		; BIOS starts at offset 0E000h
%define	START		0C000h		; FIXME: more ROM for development
%define MODEL_BYTE	0FEh		; IBM PC/XT
%define MIN_RAM_SIZE	32		; At least 32 KiB to boot the system
%define MAX_RAM_SIZE	640		; Scan this much memory during POST
%define RAM_TEST_BLOCK	16384		; block size for RAM test
%endif ; MACHINE_XT

