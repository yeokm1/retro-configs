
        PUBLIC  ChipType
ChipType        DB      0       ;; 0 - DM9100, 1 - DM9009

;
; These three variables are initialized in the MACINIT.ASM module, and
; define the physically mapped block of memory that is locked down at
; init time for the transmit and receive DMA buffers. 
;
                PUBLIC p_PhysBlockVirt, p_PhysBlockPhys, PhysBlockSize
p_PhysBlockVirt DW  0
p_PhysBlockPhys DD  0
PhysBlockSize   DW  0

;
; The following variables are physical I/O address pointers to the Tulip
; and PLX control registers. These are initialized in the InitTulipRegOffsets
; function in the module macinit.asm during driver init time. As a general
; convention in this driver, any variable prefixed with a p_ is a pointer
; variable. 
;

        PUBLIC p_CR0, p_CR1, p_CR2, p_CR3, p_CR4, p_CR5, p_CR6, p_CR7
        PUBLIC p_CR8, p_CR9, p_CR10, p_CR11, p_CR12, p_CR13, p_CR14
        PUBLIC p_CR15, p_PCIID, p_PCICS, p_PCIRV, p_PCILT, p_PCIIO

p_CR0        DW ?
p_CR1        DW ?
p_CR2        DW ?
p_CR3        DW ?
p_CR4        DW ?
p_CR5        DW ?
p_CR6        DW ?
p_CR7        DW ?
p_CR8        DW ?
p_CR9        DW ?
p_CR10       DW ?
p_CR11       DW ?
p_CR12       DW ?
p_CR13       DW ?
p_CR14       DW ?
p_CR15       DW ?

p_PCIID        DW ?
p_PCICS        DW ?
p_PCIRV        DW ?
p_PCILT        DW ?
p_PCIIO        DW ?

                PUBLIC PICIntOff, PICIntOn, PICIntMask, PICAckSlave
PICIntOff       DB ?    ; Masks for enabling and disabling interrupts at
PICIntOn        DB ?    ; the PIC Chip
PICIntMask      DW ?    ; I/O Address of the PICIntMask
PICAckSlave     DB ?    ; Flag to ACK Slave interrupt for IRQ 9,10,11

; DM9100 allowes 16 addresses in its setup packet. We save  two  addresses:
; One for the satation address, the second for broadcast address. Therefore
; the multicast table can hold only 14 addresses.
;--------------------------------------------------------------------------
                PUBLIC  MulticastTable
MulticastTable  LABEL  BYTE
                DW      14              ; Max number of multicast addresses
                DW      0               ; Current number of addresses
                DB      14*16 DUP (0)   ; Storage for 14 BYTE[16] addresses

