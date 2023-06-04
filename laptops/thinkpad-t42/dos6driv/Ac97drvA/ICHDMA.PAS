unit Ichdma;

interface
uses AC97;

const


{; BUS master registers, accessed via NABMBAR+offset

; ICH supports 3 different types of register sets for three types of things
; it can do, thus:
;
; PCM in (for recording) aka PI
; PCM out (for playback) aka PO
; MIC in (for recording) aka MC}

PI_BDBAR_REG            =     40       ; {PCM in buffer descriptor BAR}
PO_BDBAR_REG            =     $10     ; {PCM out buffer descriptor BAR}
MC_BDBAR_REG            =     $20     ; {MIC in buffer descriptor BAR}
{
; each buffer descriptor BAR holds a pointer which has entries to the buffer
; contents of the .WAV file we're going to play.  Each entry is 8 bytes long
; (more on that later) and can contain 32 entries total, so each BAR is
; 256 bytes in length, thus:}

BDL_SIZE                =     32*8    ; {Buffer Descriptor List size}
INDEX_MASK              =     31      ; {indexes must be 0-31}



PI_CIV_REG              =     $4       ; {PCM in current Index value (RO)}
PO_CIV_REG              =     $14     ; {PCM out current Index value (RO)}
MC_CIV_REG              =     $24     ; {MIC in current Index value (RO)}
{;8bit read only
; each current index value is simply a pointer showing us which buffer
; (0-31) the codec is currently processing.  Once this counter hits 31, it
; wraps back to 0.
; this can be handy to know, as once it hits 31, we're almost out of data to
; play back or room to record!
}


PI_LVI_REG              =     $5       ; {PCM in Last Valid Index}
PO_LVI_REG              =     $15     ; {PCM out Last Valid Index}
MC_LVI_REG              =     $25     ; {MIC in Last Valid Index}
{;8bit read/write
; The Last Valid Index is a number (0-31) to let the codec know what buffer
; number to stop on after processing.  It could be very nasty to play audio
; from buffers that aren't filled with the audio we want to play.
}


PI_SR_REG               =     $6       ; {PCM in Status register}
PO_SR_REG               =     $16     ; {PCM out Status register}
MC_SR_REG               =     $26     ; {MIC in Status register}
{;16bit read/write
; status registers.  Bitfields follow:
}


PI_PICB_REG             =     $8       ;{ PCM in position in current buffer(RO)  }
PO_PICB_REG             =     $18     ;{ PCM out position in current buffer(RO)  }
MC_PICB_REG             =     $28     ;{ MIC in position in current buffer (RO)}
{;16bit read only
; position in current buffer regs show the number of dwords left to be
; processed in the current buffer.
;
}


PI_PIV_REG              =     $0a     ; {PCM in Prefected index value}
PO_PIV_REG              =     $1a     ; {PCM out Prefected index value}
MC_PIV_REG              =     $2a     ; {MIC in Prefected index value}
{;8bit, read only
; Prefetched index value register.
; tells which buffer number (0-31) has be prefetched.  I'd imagine this
; value follows the current index value fairly closely. (CIV+1)
;
}


PI_CR_REG                 =   $0b     ; {PCM in Control Register}
PO_CR_REG                =    $1b     ; {PCM out Control Register}
MC_CR_REG               =     $2b     ; {MIC in Control Register}
{; 8bit
; Control register *MUST* only be accessed as an 8bit value.
; Control register.  See bitfields below.;}

IOCE                    =     BIT4    ;{ interrupt on complete enable.
                                        ; set this bit if you want an intrtpt
                                        ; to fire whenever LVBCI is set.}
FEIFE                   =     BIT3    ;{ set if you want an interrupt to fire
                                        ; whenever there is a FIFO (over or
                                        ; under) error. }
LVBIE                   =     BIT2    ;{ last valid buffer interrupt enable.
                                        ; set if you want an interrupt to fire
                                        ; whenever the completion of the last
                                        ; valid buffer.}
ResetReg                      =     BIT1    ;{ reset registers.  Nukes all regs
                                        ; except bits 4:2 of this register.
                                        ; Only set this bit if BIT 0 is 0}
RPBM                    =     BIT0    ;{ Run/Pause
                                        ; set this bit to start the codec!
}








 {
;
; Buffer Descriptors List
; As stated earlier, each buffer descriptor list is a set of (up to) 32
; descriptors, each 8 bytes in length.  Bytes 0-3 of a descriptor entry point
; to a chunk of memory to either play from or record to.  Bytes 4-7 of an
; entry describe various control things detailed below.
;
; Buffer pointers must always be aligned on a Dword boundry.
;
;
}
IOC                     =     BIT31   ; {Fire an interrupt whenever this
{                                        ; buffer is complete.}

BuffUP                     =     BIT30   ; {Buffer Underrun Policy.
{                                        ; if this buffer is the last buffer
                                        ; in a playback, fill the remaining
                                        ; samples with 0 (silence) or not.
                                        ; It's a good idea to set this to 1
                                        ; for the last buffer in playback,
                                        ; otherwise you're likely to get a lot
                                        ; of noise at the end of the sound.

;
; Bits 15:0 contain the length of the buffer, in number of samples, which
; are 16 bits each, coupled in left and right pairs, or 32bits each.
; Luckily for us, that's the same format as .wav files.
;
; A value of FFFF is 65536 samples.  Running at 44.1Khz, that's just about
; 1.5 seconds of sample time.  FFFF * 32bits is 1FFFFh bytes or 128k of data.
;
; A value of 0 in these bits means play no samples.
;


}


implementation

end.
 