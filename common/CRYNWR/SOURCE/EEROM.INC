
;--------------- General Equates -----------------
ifdef	CODE_386
	ASPtr	equ	ds:[ebp]
else		
	ASPtr	equ	ds:[bp]
endif

CHECKSUM	equ	0FFh
RECALL_DATA	equ	0
RECALL_LANADDR	equ	1

