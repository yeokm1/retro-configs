
;**************
;* CalcCRC *
;**************
;
; This routine calculates Ethernet Transmit CRC.
;
; Called by: XmtNDISTransmitChain
;
;               DS:SI -> packet body (one contiguous buffer only)
;               CX -  packet length in bytes (without the CRC)
;
; Outputs:      Calculated packet CRC is in packet buffer at offset [CX]
;
; Note: EAX, EBX, CX, DI, SI all get trashed. BUT, this routine is called
;       ONLY from XmtNDISTransmitChain, which preserves these registers.
;

;        .386

;DGROUP  GROUP   CODE
;      ASSUME  cs:DGROUP, ds:DGROUP, es:NOTHING, ss:NOTHING

;CODE segment para use16 public 'CODE'

                   PUBLIC  CalcCRC
CalcCRC  PROC  NEAR
        push  eax       ; CRC
        push  bx        ; Data
        push  edx       ; Carray

        mov   eax, 0FFFFFFFFh     ; EAX = CRC accumulator
        xor     edx,edx
;        ALIGN  4
byteloop:
        mov     bl, [si]
        inc     si
        push    cx
        mov     cx, 8
bitloop:                                        ; for(j=0; j< 8; j++) {
        push    eax                             ;   Carray = (Crc & 0x80000000) ? 1 : 0) ^ (CurByte & 0x01);
        mov     dl, bl                          ;   Crc <<= 1;
        and     eax, 80000000h                  ;   CurByte >>= 1;
        jnz     notop                           ;   if(Carray) {
        and     dl, 1                           ;      Crc = (Crc ^ 0x04c11db6) | Carray
        jmp     shiftop                         ;   }
notop:                                          ; }
        and     dl, 1
        xor     dl, 1   ; carray
shiftop:
        pop     eax
        shl     eax, 1     ; crc
        shr     bl, 1      ; current byte
        test    edx, 0ffffffffh
        jz      goback
        xor     eax, 04c11db6H          ; G(X)
        or      eax, edx
goback:
        loop    bitloop
        pop     cx
        loop    byteloop
        mov     cx, 32
notorder:
        shl     eax, 1          ; Inverse Order
        rcr     edx, 1
        loop    notorder
        mov     eax, edx
        not   eax
        mov   [si], eax           ; store CRC at end of buffer

        pop     edx
        pop   bx
        pop     eax
        ret

CalcCRC  ENDP

;CODE    ends
;        END
