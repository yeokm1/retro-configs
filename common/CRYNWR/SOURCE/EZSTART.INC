;*****************************************************************************
;*****************************************************************************
;       Macros for supporting multiple lower MACs at run time in EZStart
;
;       Eng : Frank C. Huang
;       Date: 5/25/93
;*****************************************************************************
;*****************************************************************************
;
;
ASM_ETH_PROC     MACRO   y

IFDEF	EZSTART

PUBLIC          ETH_&y

IFDEF	LARGE

ETH_&y           proc    far

ELSE

ETH_&y           proc    near

ENDIF

ELSE

PUBLIC          y

IFDEF	LARGE

y               proc    far

ELSE

y               proc    near

ENDIF

ENDIF
		ENDM 

;*****************************************************************************


ASM_ETH_PROC_END  MACRO   y

IFDEF	EZSTART

ETH_&y           ENDP

ELSE

y               ENDP

ENDIF
                ENDM


;*****************************************************************************
;

ASM_TOK_PROC     MACRO   y

IFDEF	EZSTART

PUBLIC          TOK_&y

IFDEF	LARGE

TOK_&y           proc    far

ELSE

TOK_&y           proc    near

ENDIF

ELSE

PUBLIC          y

IFDEF	LARGE

y               proc    far

ELSE

y               proc    near

ENDIF

ENDIF
		ENDM 


;*****************************************************************************


ASM_TOK_PROC_END  MACRO   y

IFDEF	EZSTART

TOK_&y           ENDP

ELSE

y               ENDP

ENDIF
                ENDM

;*****************************************************************************


C_TOK_PROC     MACRO   y

IFDEF	EZSTART

PUBLIC          _TOK&y

IFDEF	LARGE

_TOK&y           proc    far

ELSE

_TOK&y           proc    near

ENDIF

ELSE

PUBLIC          y

IFDEF	LARGE

y               proc    far

ELSE

y               proc    near

ENDIF

ENDIF
		ENDM 

;*****************************************************************************


C_TOK_PROC_END  MACRO   y

IFDEF	EZSTART

_TOK&y           ENDP

ELSE

y               ENDP

ENDIF
                ENDM


;*****************************************************************************

ASM_EBM_PROC     MACRO   y

IFDEF	EZSTART

PUBLIC          EBM_&y

IFDEF	LARGE

EBM_&y           proc    far

ELSE

EBM_&y           proc    near

ENDIF

ELSE

PUBLIC          y

IFDEF	LARGE

y               proc    far

ELSE

y               proc    near

ENDIF

ENDIF
		ENDM 

;*****************************************************************************


ASM_EBM_PROC_END  MACRO   y

IFDEF	EZSTART

EBM_&y           ENDP

ELSE

y               ENDP

ENDIF
                ENDM


;*****************************************************************************

ASM_PCM_PROC     MACRO   y

IFDEF	EZSTART

PUBLIC          PCM_&y

IFDEF	LARGE

PCM_&y           proc    far

ELSE

PCM_&y           proc    near

ENDIF

ELSE

PUBLIC          y

IFDEF	LARGE

y               proc    far

ELSE

y               proc    near

ENDIF

ENDIF
		ENDM 

;*****************************************************************************


ASM_PCM_PROC_END  MACRO   y

IFDEF	EZSTART

PCM_&y           ENDP

ELSE

y               ENDP

ENDIF

                ENDM
