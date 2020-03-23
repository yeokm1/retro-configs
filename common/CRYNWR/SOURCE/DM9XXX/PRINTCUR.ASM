;; Data : DWORD -> EAX, DL -> Column
        public pcursor, pcol
pcursor         DB      0
pcol            DB      0

        PUBLIC  Printcur
Printcur        PROC
;;        cmp     bl, 3
;;        jmp     dwout
;;        cmp     bl, 2
;;        jmp     wout
;;        cmp     bl, 1
;;        jmp     bout
mov     pcol, dl
mov     pcursor, 65

;;        public  dwout, wout, bout, digitout

;; Data : DWORD -> DX:AX, WORD -> AX, BYTE -> AL
dwoutX:
        mov     edx, eax        ;; DX:AX = EAX
        shr     edx, 16

        mov     cl,'0'                  ;prepare to eliminate leading zeroes.
        xchg    ax,dx                   ;just output 32 bits in hex.
        call    woutX                 ;output dx.
        xchg    ax,dx

woutX:
        push    ax
        mov     al,ah
        call    boutX
        pop     ax

boutX:
        mov     ah,al
        shr     al,1
        shr     al,1
        shr     al,1
        shr     al,1
        call    digitoutX
        mov     al,ah

digitoutX:
        and     al,0fh
        add     al,90h  ;binary digit to ascii hex digit.
        daa
        adc     al,40h
        daa
        cmp     al,cl                   ;leading zero?
        je      digitout_1X
        mov     cl,-1                   ;no more leading zeros.
        call    charoutX

digitout_1X:
        ret
Printcur        ENDP

;;        public  charout
charoutX PROC    NEAR
;;charout:
        push    ax                      ;print the char in al.
        push    dx
;;        mov     ah, 0Eh
;;        mov     bx, 0Fh         ;; Set video attributes for INT 10 call

        mov     ah, 02h                 ;; Set cursor
        mov     bx, 0Fh
        mov     dl, pcursor
        mov     dh, pcol
        int     10h

        mov     ah, 0Ah
;;      mov     bx, 0fh
        mov     cx, 1
        int     10h             ;; call BIOS INT 10 to print to console
        inc     pcursor

        pop     dx
        pop     ax
        ret
charoutX         ENDP

printcrlfX               PROC
linereturnX:
        push    ax
        mov     al, 0Ah         ;; LF
        call    charout
        mov     al, 0Dh         ;; CR
        call    charout
        pop     cx
        ret
printcrlfX       ENDP
