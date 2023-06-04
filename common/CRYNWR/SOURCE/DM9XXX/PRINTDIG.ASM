


;; Data : DWORD -> EAX, WORD -> AX, BYTE -> AL
;; Mode : BL = 1 -> byteout, 2 -> wordout, 3 -> dwordout
        PUBLIC  Printdig
Printdig        PROC    NEAR
        cmp     bl, 3
        je     dwout
        cmp     bl, 2
        je     wout
        cmp     bl, 1
        je     bout

        public  dwout, wout, bout, digitout

;; Data : DWORD -> DX:AX, WORD -> AX, BYTE -> AL
dwout:
        mov     edx, eax        ;; DX:AX = EAX
        shr     edx, 16

        mov     cl,'0'                  ;prepare to eliminate leading zeroes.
        xchg    ax,dx                   ;just output 32 bits in hex.
        call    wout                    ;output dx.
        xchg    ax,dx

wout:
        push    ax
        mov     al,ah
        call    bout
        pop     ax

bout:
        mov     ah,al
        shr     al, 4
        call    digitout
        mov     al,ah

digitout:
        and     al,0fh
        add     al,90h  ;binary digit to ascii hex digit.
        daa
        adc     al,40h
        daa
        cmp     al,cl                   ;leading zero?
        je      digitout_1
        mov     cl,-1                   ;no more leading zeros.
        call     charout
digitout_1:
        ret

Printdig        ENDP

        public  charout
charout PROC    NEAR
;;charout:
        push    ax                      ;print the char in al.
        push    dx
        mov     ah, 0Eh
        mov     bx, 0Fh         ;; Set video attributes for INT 10 call
        int     10h             ;; call BIOS INT 10 to print to console
        pop     dx
        pop     ax
        ret
charout         ENDP

printcrlf       PROC
linereturn:
        push    ax
        mov     al, 0Ah         ;; LF
        call    charout
        mov     al, 0Dh         ;; CR
        call    charout
        pop     cx
        ret
printcrlf       ENDP

;IFDEF OK
;; Data : WORD -> CX
        PUBLIC  Printwdig
Printwdig        PROC    NEAR

        push    ax
        mov     al,ah
        call    wbout
        pop     ax

wbout:
        mov     ah,al
        shr     al, 4
        call    wdigitout
        mov     al,ah

wdigitout:
        and     al,0fh
        add     al,90h  ;binary digit to ascii hex digit.
        daa
        adc     al,40h
        daa
        cmp     al,cl                   ;leading zero?
        je      wdigitout_1
        mov     cl,-1                   ;no more leading zeros.

        push    bx
        push    es
        mov     bx, 0b800h
        mov     es, bx
        mov     byte ptr es:[si], al
        inc     si
        mov     byte ptr es:[si], 12
        inc     si
        pop     es
        pop     bx

wdigitout_1:
        ret
Printwdig        ENDP
;ENDIF   ;;OK
