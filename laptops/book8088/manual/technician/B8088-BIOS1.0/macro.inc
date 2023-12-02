;=========================================================================
; macro.inc - Defines macros
;       setloc
;-------------------------------------------------------------------------
;
;=========================================================================

;=========================================================================
; setloc - Set location. Insert 0FFh bytes until specifed location is reached.
;-------------------------------------------------------------------------
%imacro setloc  1.nolist
%assign pad_bytes (%1-($-$$)-START)
%if pad_bytes < 0
%assign over_bytes -pad_bytes
%error Preceding code extends beyond setloc location by over_bytes bytes
%endif
%if pad_bytes > 0
%warning Inserting pad_bytes bytes
 times  pad_bytes db 0FFh
%endif
%endm
