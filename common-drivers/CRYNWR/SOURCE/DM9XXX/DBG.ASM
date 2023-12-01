
code	segment para public
	assume	cs:code, ds:code
;;++, 00/01/31, hu-tiong
IFDEF	DEBUGDOS
include debug.asm
ENDIF	;-- DEBUGDOS
;;++
code	ends
	end
