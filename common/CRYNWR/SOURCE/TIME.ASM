
        include defs.asm

;<<<===========================================================================
; ReadTickCounter
;
;  Reads the Timer tick count register which decrements by 2 from 65536
;  to 0 every 1/36.414 of a second.  Each 2 decrements of the count
;  represents 838 nsec's.
;
;  Inputs    :  None
;  Outputs   :  AX = timer tick count (decrease by 2)
;  Returns   :  None
;  Preserved :  None
;  Called by :  others
;===========================================================================>>>
                
ReadTickCounter proc    near

        mov     al, 06h
        out     43h, al                 ;Command 8254 to latch T0's count

        ;Read the Timer Tick Counter
        ;---------------------------
        in      al, 40h                 ;Read LSB first
        mov     ah, al
        in      al, 40h                 ;Read MSB
        xchg    al, ah                  ;AX = timer tick count (decrease by 2)
        ret

ReadTickCounter endp

;<<<===========================================================================
; Wait419nsec
;
;  Wait for 419 nsec (1 tick = 419 nsec).
;
;  Inputs    :  None
;  Outputs   :  None
;  Returns   :  None
;  Preserved :  None
;  Called by :  others
;===========================================================================>>>
                
Wait419nsec     proc    near

        push    ax
        push    cx

        ;Read the begin timer tick count
        ;-------------------------------
        call    ReadTickCounter
        mov     cx, ax                  ;AX = timer tick count (decrease by 2)
Wait419nsecLoop:
        ;Read the last timer tick count
        ;------------------------------
        call    ReadTickCounter

        sub     cx, ax
        cmp     cx, 0                   ;1 tick = 419 nsec
        jbe     Wait419nsecLoop

        pop     cx
        pop     ax
        ret

Wait419nsec     endp


;<<<===========================================================================
; Wait2msec
;
;  Wait for 2 msec.
;
;  Inputs    :  None
;  Outputs   :  None
;  Returns   :  None
;  Preserved :  None
;  Called by :  others
;===========================================================================>>>
                
Wait2msec       proc    near

        push    cx
        mov     cx, 5000                ;about 2 msec (5000 * 419 nsec)
Wait2msecLoop:
        call    Wait419nsec
        loop    Wait2msecLoop
        pop     cx
        ret

Wait2msec       endp


;<<<===========================================================================
; Wait100msec
;
;  Wait for 100 msec.
;
;  Inputs    :  None
;  Outputs   :  None
;  Returns   :  None
;  Preserved :  None
;  Called by :  others
;===========================================================================>>>
                
Wait100msec       proc    near

        push    cx
        mov     cx, 25000               ;about 100 msec (25000 * 419 nsec)
Wait100msecLoop:
        call    Wait419nsec
        loop    Wait100msecLoop
        pop     cx
        ret

Wait100msec     endp



ConfigPhyCoef	proc	near
	push	ecx
	push	eax
	push	dx
	push	ebx
	mov	ecx,10
WaitAutoNegCmp:	
	call	Wait2msec 
	loadport
	setport	PHYSTSPort
	in	eax,dx
	test	eax,010h	; Check if AutoNeg complete
	jnz	exitAtNlp
	loop	WaitAutoNegCmp
exitAtNlp:	
	test	eax,010h
	jz	Cfgphyexit
	test	eax,02h		; Check if Link speed is 100M
	jnz	Cfgphyexit

CfPhyCoef_1:
	loadport
	setport	SRRPort
	in	eax,dx
	and	eax,0f00h
	cmp	eax,0300h
	je	PHYAdjust
	cmp	eax,0400h
	je	PHYAdjust
	cmp	eax,0500h
	jne	cfgphyexit

PHYAdjust:
	loadport
	setport	PAGEPort
	mov	eax,01h
	out	dx,eax
	setport	DSPCFGPort
	in	eax,dx
	and	eax,0FFFh
	or	eax,01000h
	out	dx,eax

	call	Wait100msec 	

	loadport
	setport	TDATAPort
	in	eax,dx
	and	eax,0FFh
	
	test	eax,080h
	jz	CfgPhyCoef

	cmp	eax,0D8h
	jb	RetPAG_0	
	cmp	eax,0FFh
	ja	RetPAG_0

CfgPhyCoef:
	loadport
	setport	TDATAPort
	mov	eax,0E8h
	out	dx,eax
	setport	DSPCFGPort
	in	eax,dx
	or	eax,020h
	out	dx,eax
	
RetPAG_0:
	loadport
	setport	PAGEPort
	mov	eax,0
	out	dx,eax
cfgphyexit:	
	pop	ebx
	pop	dx
	pop	eax
	pop	ecx

	ret
ConfigPhyCoef	endp




CheckPhySRR	proc	near
        push    eax
        push    ecx
        push    edi
	push	dx

	loadport
	setport SRRPort 
	in	eax,dx
	cmp	eax,200h
	je	MP_SilRev2
	and	eax,0FF00h
	cmp	eax,300h
	je	MP_SilRev3
	cmp	eax,400h
	je	MP_SilRev4
	cmp	eax,500h
	je	MP_SilRev4

MP_SilRev4:
	loadport
	setport PAGEPort
	mov	eax,0001h
	out	dx,eax
	setport	PMDCSRPort
	mov	eax,189Ch
	out	dx,eax
	setport	PAGEPort
	mov	eax,0
	out	dx,eax
	jmp	ChkSRRExit

MP_SilRev3:
	loadport
	setport	PAGEPort
	mov	eax,0001h
	out	dx,eax
	setport	PMDCSRPort
	mov	eax,0189ch
	out	dx,eax
	setport	TDATAPort
	mov	eax,0
	out	dx,eax
	setport	DSPCFGPort
	mov	eax,05040h
	out	dx,eax
	setport	SDCFGPort
	mov	eax,008Ch
	out	dx,eax
	setport	PAGEPort
	mov	eax,0
	out	dx,eax
	jmp	ChkSRRExit

MP_SilRev2:
	loadport
	setport	PAGEPort
	mov	eax,0001h
	out	dx,eax
	setport	PMDCSRPort
	mov	eax,0802h
	out	dx,eax
	setport	FCOCTLPort
	mov	eax,010h
	out	dx,eax
	setport	SDCFGPort
	mov	eax,0333h
	out	dx,eax
	setport	PGMCGMPort
	mov	eax,0860h
	out	dx,eax
	setport	TMRPort
	mov	eax,02100h
	out	dx,eax
	setport	CDCTL2Port
	mov	eax,04F48h
	out	dx,eax
	setport	PAGEPort
	mov	eax,0
	out	dx,eax
	setport	TENBTPort
	in	eax,dx
	or	eax,04h
	out	dx,eax
ChkSRRExit:
	pop	dx
	pop	edi
	pop	ecx
	pop	eax
	ret	

CheckPhySRR	endp	


EuphyterPhyReset        proc    near

        push    eax
        push    ebx
        push    ecx
        push    edx

        ;Reset Internal Phy
        ;------------------
	loadport
	setport	BMCRPort
        mov     eax, 08000h ;BMCR_RESET
        out     dx, eax

        call    Wait2msec

        mov     ecx, 100
WaitPhyResetLoop:
        ;Check reset MacPhyter stably ?
        ;------------------------------
	loadport
	setport	PHYID1Port
        in      eax, dx

        cmp     ax, 2000h
        je      WaitPhyResetOK

        call    Wait2msec
        loop    WaitPhyResetLoop

;WaitPhyResetFAIL:
;        pop     edx
;        pop     ecx
;        pop     ebx
;        pop     eax
;        stc
;        ret

WaitPhyResetOK:
	loadport
	setport	MISRPort
	mov	ax,0BFFFh	
	out	dx,ax
	setport	MICRPort
	mov	ax,1 SHL 1   ; Interrupt enable
	out	dx,ax
        
	setport	CFGPort
        in      eax,dx
        or      eax,1 SHL 17            ;pint_acen
        out     dx,eax
        pop     edx
        pop     ecx
        pop     ebx
        pop     eax
        clc
        ret

EuphyterPhyReset        endp
