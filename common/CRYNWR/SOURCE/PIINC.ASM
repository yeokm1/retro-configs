CTL_B	equ	0 ; Offset of channel B control register
DATA_B	equ	1 ; Offset of channel B data register
CTL_A	equ	2 ; Offset of channel A control register
DATA_A	equ	3 ; Offset of channel A data register
DMAEN	equ	4 ; Offset of DMA control register

; Timer chip offsets
TMR0	equ	8h 	; Offset of timer 0 register
TMR1	equ	9h 	; Offset of timer 1 register
TMR2	equ	0Ah 	; Offset of timer 2 register
TMRCMD	equ	0Bh 	; Offset of timer command register

; Timer chip equates
SC0	equ	00h	; Select counter 0
SC1	equ	40h	; Select counter 1
SC2	equ	80h	; Select counter 2
CLATCH	equ	00h	; Counter latching operation
MSB	equ	20h	; Read/load MSB only
LSB	equ	10h	; Read/load LSB only
LSB_MSB	equ	30h	; Read/load LSB, then MSB
MODE0	equ	00h	; Interrupt on terminal count
MODE1	equ	02h	; Programmable one shot
MODE2	equ	04h	; Rate generator
MODE3	equ	06h	; Square wave rate generator
MODE4	equ	08h	; Software triggered strobe
MODE5	equ	0ah	; Hardware triggered strobe
BCD	equ	01h	; BCD counter

; DMA controller registers
DMA_STAT	equ	8	; DMA controller status register
DMA_MASK        equ	10	; DMA controller mask register
DMA_MODE        equ	11	; DMA controller mode register
DMA_RESETFF	equ	12	; DMA controller first/last flip flop
; DMA data
DMA_DISABLE 	equ	04h	; Disable channel n
DMA_ENABLE	equ	00h	; Enable channel n
; Single transfers, incr. address, auto init, writes, ch. n
DMA_RX_MODE	equ	54h
; Single transfers, incr. address, no auto init, reads, ch. n
DMA_TX_MODE 	equ	48h

