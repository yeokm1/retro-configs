
INTEL_82596	EQU	01h
INTEL_82557	EQU	02h
;CHIP	= INTEL_82596
CHIP	= INTEL_82557

SPECIAL_FFFF_HANDLING_82559ER EQU 1	; used to patch in valid PHY eeprom description in case
					; of unprogrammed eeprom
					; comment it if you dont want this

US_ENGLISH	EQU	1
LANGUAGE EQU US_ENGLISH	; Used in the messages.inc file

NOWARN	RES
vers		equ	10
WARN

if	CHIP EQ INTEL_82596
short_name	equ	<"e10ppkt">
long_name	equ <"Intel EtherExpress(tm) PRO/10 PCI">
else
short_name	equ	<"e100bpkt">
long_name	equ <"Intel EtherExpress(tm) PRO/10 & PRO/100B PCI">
endif

