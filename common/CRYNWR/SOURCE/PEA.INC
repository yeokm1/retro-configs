;------------------------------------------------------------------------;
; This file contains definitions used by the PEA (NotePort) and the      ;
; LPT ports.                                                             ;
;                                                                        ;
; Modification History:                                                  ;
;               02/25/92        JRA                                      ;
;               Removed from EDLC.INC and created this file.             ;
;------------------------------------------------------------------------;

;-----------------------------------------------------------------------;
; PEA register defintions -  these are selected before an I/O operation ;
; is done to the PEA.  See also the file RAVEN.MAC.                     ;
;-----------------------------------------------------------------------;

;
; These correspond to the A3-A0 address bits of the 8005.
; Since we are dealing in 8-bit mode, bit 0 is used to address the correct
; byte.  If bit 0 = 0 then we address the low-order byte of the register,
; if bit 0 = 1 we address the high order byte.  The literals below are used
; for addressing the low-order byte.  See raven.mac for the actual macros
; which address both bytes.
;
; N.B.  The above discussion holds for all registers except the REA register.
;       Since the high byte of the REA register is used for status information.

PEA_COMMAND_REG   EQU   00h
PEA_STATUS_REG    EQU   00h
PEA_CONFIG1_REG   EQU   02h
PEA_CONFIG2_REG   EQU   04h
PEA_REA_PTR_REG   EQU   06h
PEA_WINDOW_REG    EQU   08h
PEA_RX_PTR_REG    EQU   0Ah
PEA_TX_PTR_REG    EQU   0Ch
PEA_DMA_ADDR_REG  EQU   0Eh

;------ The PEA board status register, --------------;
;------ this is the high byte of the REA register ---;
PEA_BOARD_STATUS_REG EQU 07h

;
; Use these to address the high order byte of the register.
;
PEA_COMMAND_REG_HI   EQU   01h
PEA_STATUS_REG_HI    EQU   01h
PEA_CONFIG1_REG_HI   EQU   03h
PEA_CONFIG2_REG_HI   EQU   05h
PEA_WINDOW_REG_HI    EQU   09h
PEA_RX_PTR_REG_HI    EQU   0Bh
PEA_TX_PTR_REG_HI    EQU   0Eh
PEA_DMA_ADDR_REG_HI  EQU   0Fh

;---------------------- Theory of operation ----------------------------;
;
;  The PEA is attached to the host computer via a parallel port.
;  A parallel port (known throughout here as LPT), consists of 3
;  registers.  These are the 'data', 'control', and 'status' registers.
;
;  Input and Output to the PEA is done by reading/writing to the data
;  port of the LPT.
;
;  NOTE:
;  A "-" in front of the bit name below means that it is low-active,
;  ie; a zero when true.
;
;  LPT control register bit assignments:
;  -------------------------------------
;   bit 7: Reserved
;   bit 6: Reserved
;   bit 5: Direction (1 = read)
;   bit 4: Irq enable
;   bit 3: Select printer
;   bit 2: -Initialize
;   bit 1: Auto-feed
;   bit 0: Strobe
;
;  The initialize bit in combination with the strobe bit determines whether we
;  are talking to the "PEA Command Register" or to the 8005.  If both the
;  initialize and strobe bits toggle then that indicates that we are doing
;  I/O to the PEA Command Register.  If the initialize bit is set to 1 and
;  only the strobe bit toggles then we are doing I/O to the 8005.  The PEA
;  Command Register is described later.
;
;  LPT status register bit assignments:
;  -------------------------------------
;   bit 7: -Busy
;   bit 6: -Ack
;   bit 5: Paper Empty
;   bit 4: Select in
;   bit 3: -Error
;   bit 2: -Interrupt request
;   bit 1: Reserved
;   bit 0: Reserved
;
;  PEA Command Register bit assignments:
;  -------------------------------------
;  This register is a write only register in the PEA interface that
;  controls the source/destination of reads and writes throught the LPT
;  data register.
;
;  PEA command register bit assignments:
;  -------------------------------------
;   bit 7: WFI (Wait for interrupt)         (See discussion below)
;   bit 6: Target select 1 ------------+
;                                      |--> These two select the target (see below).
;   bit 5: Target select 0 ------------+
;   bit 4: Read/-Write
;   bit 3: (address bits to
;   bit 2:  select the register in the 8005
;   bit 1:  for subsequent
;   bit 0:  data strobes).
;
;  The following are the combinations of bits (7-4) and their effects and
;  meanings.  These bits are used to select the target, and to specify whether
;  we are reading or writing to it.
;
;   bit 7   bit 6   bit 5   bit 4   Explanation
;   -----   -----   -----   -----   -------------------------------------
;   0       0       0       X       Selects Printer, disables 8005.
;                                   This also has the effect of generating
;                                   an ACK pulse which will trigger a printer
;                                   interrupt.
;   0       0       1       0       Write to the 8005 (see below).
;   0       0       1       1       Read from the 8005 (see below).
;   0       1       0       0       Select EEPROM only for write.
;                                   (See below).
;   0       1       0       1       Select EEPROM only for read.
;                                   (See below).
;   0       1       1       1       Reads a nibble from status register.
;                                   High nibble with data register bit7=1,
;                                   Low nibble with data register bit7=0.
;   1       0       0       X       PEA can detect interrupt, in conjunction
;                                   with the IRQ_Enable in LPT control reg
;                                   traps ints that we can read thru the PEA status.
;   1       0       1       X       Allows printer interrupts also.
;   1       1       0       X       Allows printer interrupts also.
;
;
; WFI Bit
; -------
; The WFI allows interrupts from the printer and/or 8005 to generate
; an ACK pulse to the parallel port - thereby generating an interrupt to
; the system.  This is true only if interrupts are enabled.
; Otherwise, the WFI bit must always be enabled in order to trap the
; fact that the printer has generated an ACK (an interrupt).
;
; The fact that the printer (and the 8005) generated an interrupt is
; latched in the PEA status register (bits 0 and 1).
;
; In order to clear the Printer ACK indication, the WFI
; bit must be cleared.  This will allow us to receive another ACK
; indication from the printer.
;
; The following lists the valid conditions which may obtain:
;
;   WFI is HI:
;   ----------
;   Case A:
;     IF
;         the 8005 is not selected AND the 8005 interrupts
;     THEN
;         an ACK pulse is generated which triggers an interrupt to the system,
;         the 8005 interrupt bit in the PEA Status register holds the
;         8005 interrupt indication until it is cleared at the 8005.
;
;     Note: if the 8005 is selected then we have control over the 8005
;           interrupts.  If we clear the 8005 interrupts (RX and TX) then
;           the PEA Status bit is also cleared, unless there is another
;           interrupt from the 8005.
;
;   Case B:
;     IF
;         the 8005 is not selected AND the printer interrupts
;     THEN
;         the ACK pulse from the printer is re-generated and sent to the LPT
;         port.
;         The printer interrupt bit in the PEA Status register holds the
;         fact that the printer interrupted until WFI is forced low again.
;
;     Note: if the 8005 is selected then the printer will NOT interrupt
;           again, since we have control and besides there is no mechanism
;           that would cause another interrupt to occur.  That would only
;           happen until the printer handler regains control again and sends
;           another character.
;
;   WFI is LOW:
;   -----------
;   Case C:
;     IF
;         the 8005 is not selected AND the printer interrupts
;     THEN
;         the ACK pulse is passed on thru to the system unmolested,
;         the information is NOT latched in the PEA status register.
;
;     Note: We always maintain WFI high to avoid the situation where we
;           miss a printer ACK being latched.  The only time that WFI is
;           low is whenever we drive it low to clear it.  In that case
;           the Note for Case B applies.
;
;  PEA Board Status register bit assignments
;  -----------------------------------------
;  This register is used to read the status of the PEA.
;   bit 7: reserved (1)
;   bit 6: reserved (1)
;   bit 5: 0
;   bit 4: -Transmit LED (sending data, twisted-pair only)
;   bit 3: -Auto Polarity detect (twisted-pair cable is wired wrong, advisory)
;   bit 2: -Link Detect (twisted-pair only)
;   bit 1: -8005 Interrupt
;   bit 0: -Printer Interrupt
;
;  If WFI is set then bit 1 will be a 0 if we have an 8005 interrupt,
;  bit 0 will be a 0 if have a printer interrupt.
;
;  In all of the following descriptions we will use the notation (d, i, s) to
;  indicate the state of the direction, initialize, and strobe bits in the LPT
;  control port respectively.
;
;  For example, (1, 0, 1) indicates that the direction bit is
;  set to a read, the initialize bit to a 0, and the strobe bit to a 1.
;
;
;  Writing to the PEA Command Register:
;  ------------------------------------
;  1. Load the data that you wish to write to the PEA command register into
;     the LPT data port.
;  2. Write (0, 0, 1) to the LPT control port.
;  3. Write (0, 1, 0) to the LPT control port.
;
;  Writing to the 8005
;  -------------------
;  1. Select the 8005 register for writing by using the PEA Command Register.
;  2. Write the data to be written to the 8005 register into the LPT data port.
;  3. Write (0, 1, 1) to the LPT control port.
;  4. Poll the LPT status port ACK bit until it goes to 0.
;  5. Write (0, 1, 0) to the LPT control port.
;  6. Poll the LPT status port ACK bit until it goes to 1.
;
;  NOTE: the initialize bit MUST not toggle.
;
;  Reading from the 8005
;  ---------------------
;  1. Select the 8005 register for reading by using the PEA Command Register.
;  2. Write (1, 1, 1) to the LPT control port.
;  3. Poll the LPT status port ACK bit until it goes to 0.
;  4. Read data from the LPT data port.
;  5. Write (1, 1, 0) to the LPT control port.
;  6. Poll the LPT status port ACK bit until it goes to 1.
;
;  NOTE: the initialize bit MUST not toggle.
;
;  Reading from the 8005 in nibble (degraded, non-bidirectional  mode)
;  --------------------------------------------------------------------
;  1. Select the 8005 register to read in nibble mode by using the PEA Command
;     Register.
;  2. Write (0, 1, 1) to the LPT control port.
;     Note that the direction bit is NOT set to read.
;  3. If you wish to read the hi nibble then write a byte with bit 7 = 1
;     to the LPT data port.
;  4. Poll the LPT status port ACK bit until it goes to 0.
;  5. Read the LPT status port.  The nibble selected will appear as
;     follows:
;       LPT Status Bit          Name                 Nibble bit
;       --------------          ------------         ----------
;        bit 7                   Busy                 3
;        bit 5                   Paper Empty          2
;        bit 4                   Select In            1
;        bit 3                   Error                0
;  6. Select the next nibble to read from the 8005 register by writing any
;     value to the LPT data register with bit 7 the opposite of what was
;     done in Step 1.  This again is done by setting or clearing
;     bit 7 in the data register.  For example, if we selected the low nibble
;     in Step 1 by clearing bit 7, we now set bit 7 to select the high nibble.
;  7. Read the nibble as in Step 4.
;  7. Write (0, 1, 0) to the LPT control port.
;  8. Poll the LPT status port ACK bit until it goes to 1.
;
;
;  Deselect the 8005 by selecting the printer
;  ------------------------------------------
;  To (deselect the ethernet/select the printer) the 8005 select, and EE select
;  bits are all set to 0 in the PEA command register.  This is done
;  when we have determined that we are all done handling the ethernet.
;  Note that the WFI bit must be set if we wish to receive notification that
;  a printer interrupt has occurred.  We always set this bit in our driver
;  whether it is a polled driver or an interrupt driver.
;
;  Writing the EEPROM
;  -------------------
;  Before writing the EEPROM, the EEPROM must be enabled for writing
;  and the contents erased.  The EEPROM is enabled for writing by sending
;  the following bit sequence {1, 0, 0, 1, 1, X, X, X, X} where X is a don't
;  care.  The contents of the EEPROM are erased by writing the bit sequence
;  {1, 0, 0, 1, 0, X, X, X, X}.   The bit sequence is preceded by writing a
;  0 first.
;
;      To enable the EEPROM for writing, and to erase the contents
;      -----------------------------------------------------------
;       1. Select the EEPROM for writing via the PEA command register.
;       2. Write the next bit in the appropriate sequence above as bit 0 to
;          the LPT data port.  This sequence must be preceded by writing
;          a 0 as the first bit.
;       3. Write (0, 1, 1) to the LPT control port.
;       4. Write (0, 1, 0) to the LPT control port.
;       5. Do steps 2-4 until all 9 bits have been written.
;       6. Deselect the EEPROM.
;       7. Select the EEPROM for writing.
;       8. If we are erasing the contents then -
;              a. Poll the Paper Empty bit in the LPT status register
;                 until it is becomes a 1.
;               b. Deselect the EEPROM.
;
;      To write the contents of the EEPROM
;      -----------------------------------
;      This too is written a bit a time into each individual EEPROM address.
;      Each EEPROM address corresponds to a word value.  The bits are written
;      from high order bit to low order bit.
;      For each EEPROM address the following 25 bits of data are written -
;      {1, 0, 1, A5, A4, A3, A2, A1, A0, D15, D14, D13, ..., D1, D0}.
;      A5-A0 indicate the EEPROM address we are writing to, D15-D0 are the
;      16 bits of data that we are writing a bit at a time into the specified
;      location.  The bit sequence is preceded by writing a 0 as the first bit.
;
;       1. Select the EEPROM for writing via the PEA command register.
;       2. Write the next bit in the 25-bit sequence as bit 0 to the
;          LPT data port.  This 25 bit sequence must be preceded by
;          writing a 0.
;       3. Write (0, 1, 1) to the LPT control port.
;       4. Write (0, 1, 0) to the LPT control port.
;       5. Do steps 2-4 until all 25 bits have been written.
;       6. Write a 0 to the LPT data port.
;       7. Deselect the EEPROM.
;       8. Select the EEPROM for writing.
;       9. Poll the Paper Empty bit in the LPT status register until it is
;          a 1.
;
;  Reading the EEPROM
;  ------------------
;  The EEPROM is read by writing to EEPROM the following sequence:
;  {1, 1, 0, A5, A4, A3, A2, A1, A0} where A5-A0 specifies the EEPROM
;  address which we want to read.  This sequence is preceded by writing a
;  0 as the first bit.
;
;  We then read, a bit at at time, the 16 bits contained at that
;  location.  Each bit is read via the Paper Empty bit in LPT status port.
;
;       1. Select the EEPROM for reading via the PEA command register.
;       2. Write the 9-bit command sequence to indicate which address we
;          are going to be reading from.  This sequence must be preceded by
;          writing a 0 bit first.
;       3. Write (0, 1, 1) to the LPT control port.
;       4. Write (0, 1, 0) to the LPT control port.
;       5. Do steps 2-4 until all bits have been written.
;       6. Write a 0 to the LPT data port.
;       7. Write (1, 1, 1) to the LPT control port.
;       8. Read the data from the LPT status port.
;       9. Write (1, 1, 0) to the LPT control port.
;      10. The Paper empty bit now contains the next bit in the word.  High
;          order bit is read first.
;      11. Repeat steps 7-10 until all 16 bits of data are read.
;      12. Deselect the EEPROM.
;
;
;  Running in Interrupt Mode
;  -------------------------
;  To utilize interrupts with the PEA the following guidelines must
;  be followed.
;
;    Enabling the generation and reception of interrupts
;    ---------------------------------------------------
;       1. The WFI bit in the PEA command register must be set and
;          remain set.
;       2. The IRQ Enable bit in the LPT control register must be set.
;       3. The 8005 interrupts indications must be enabled.
;       4. System interrupts must be enabled in order to receive the
;          interrupts.
;
;    Disabling Interrupt Indications
;    -------------------------------
;    Interrupts can be disabled in any of the following ways:
;
;       1. By disabling system interrupts (CLI).
;       2. By not enabling 8005 interrupt indications.
;       3. By not acknowledging the interrupt at the 8005.
;       4. By not EOI'ing the PIC.
;          *** Note on EOI:  We use the Non-Specific EOI to the PIC.
;              The Non-specific EOI will clear the highest priority
;              interrupt.  This is true as long as we are in our ISR,
;              unless we allow interrupts (STI) in which case a higher level
;              interrupt can occur.  In that case, if we STI before we EOI
;              then the wrong interrupt may be cleared.  Therefore we need
;              to either EOI right away before STI, or not STI before we EOI.
;       5. The IRQENABLE bit must be disabled when we are handling the Ethernet.
;          If it is not, then any I/O that is done to the 8005 will cause
;          a "false" interrupt to occur.  These interrupts will not be latched
;          in the PEA status register.
;
;
;    Determining the origin of the Interrupt
;    ---------------------------------------
;       1. When an interrupt fires the PEA status register must be checked.
;       2. Bit 1 = 0 indicates that the 8005 interrupted.
;       3. Bit 0 = 0 indicates that the Printer interrupted.
;
;    Interrupt Service Routine
;    -------------------------
;       1. Do not allow the ISR to go re-entrant.
;       1. Determine the origin(s) of the interrupt (see above).
;       2. If the 8005 interrupted then handle the Ethernet.
;       3. On the way out of the 8005 interrupt handler:
;               a. If the printer interrupted:
;                  . Clear the printer interrupt indication by setting
;                    WFI = 0 in the PEA command register.
;                  . Execute the next handler in the chain.
;               b. Disable the ethernet (enable the printer) leaving WFI
;                  high.
;
;
; General Notes:
; --------------
;       1. In order to prevent a process from accessing the printer
;          whenever the ethernet is enabled, we must run with system
;          interrupts disabled.  If a routine is called which may re-enable
;          interrupts then we must be sure to disable the ethernet portion
;          of the PEA.
;       2. We leave the WFI bit set whether the driver is an interrupt driver
;          or a polled driver.  This must be the case for an interrupt based
;          driver, and in the case of a polled driver it won't matter because
;          we will not see the interrupt.  The difference having WFI set
;          is that the PEA hardware regenerates the ACK from the printer
;          ACK instead of just passing it through.
;       3. To ensure proper operation the NotePort driver should be installed
;          AFTER any other driver which may use the printer.  This may not
;          be feasible in some cases.
;
;---------------------------------------------------------------------------


IFDEF NIBBLE_MODE
;
; Set in the LPT data port to indicate which nibble
; we want to read.
;
LO_NIBBLE       equ     00h             ; bit 7 is cleared
HI_NIBBLE       equ     80h             ; bit 7 is set
ENDIF

;
; Used for callNovell macro
;
ENABLE_INTS     equ     0               ; Used to enable ints on a Novell Call
DISABLE_INTS    equ     1               ; Used to disable ints on a Novell Call

;
; Supported LPT ports -
; These are indices into BIOS memory where we find the LPT addresses.
;
LPT1            equ     0
LPT2            equ     2
LPT3            equ     4

;
; Where we find the LPT addresses
;
BIOS_SEG        equ     40h
LPT_OFF         equ     08h

;
; Used to check for presence of NotePort by writing to a register.
;
CHECK_VALUE     equ     55aah

;
; LPT control port bit definitions
;
LPT_CTL_STROBE          equ     01h
LPT_CTL_AUTOFEED        equ     02h
LPT_CTL_INITIALIZE      equ     04h
LPT_CTL_SELECTPRINTER   equ     08h
LPT_CTL_IRQENABLE       equ     10h
LPT_CTL_DIRECTION       equ     20h
LPT_CTL_RESERVED1       equ     40h
LPT_CTL_RESERVED2       equ     80h

;
; LPT status port bit definitions
;
LPT_STATUS_RESERVED1    equ     01h
LPT_STATUS_RESERVED2    equ     02h
LPT_STATUS_INTREQUEST   equ     04h
LPT_STATUS_ERROR        equ     08h
LPT_STATUS_SELECT_IN    equ     10h
LPT_STATUS_PAPEREMPTY   equ     20h
LPT_STATUS_ACK          equ     40h
LPT_STATUS_BUSY         equ     80h

;
; To determine if the printer is still printing
;
PRINTING                equ     LPT_CTL_STROBE

;
; To finish up the printing for the printer
;
FINISH_PRINT            equ     NOT LPT_CTL_STROBE

;
; The following bits need to be set to a known state.
; STROBE    -  0
; DIRECTION -  WRITE (0)
; IRQENABLE -  (whatever it was on entry)
;
;
; So use this mask with Saved_Control
;
;
DEFAULT_CONTROL equ     0DEH

;---------------------------------------------------------
; LPT Status port mask values
;---------------------------------------------------------
PEA_ACK                 equ     LPT_STATUS_ACK
PAPER_EMPTY             equ     LPT_STATUS_PAPEREMPTY
BUSY_HIGH               equ     LPT_STATUS_BUSY

;---------------------------------------------------------
; LPT Control port mask values
;---------------------------------------------------------

;---------------- Strobe begin write to the PEA command register -----
; direction = write(0), initialize = 0, strobe = 1
;
IFDEF TOSHIBA
PEA_CMD_STROBE_BEGIN    equ 01h
ELSE
PEA_CMD_STROBE_BEGIN    equ 01h
ENDIF

;---------------- Strobe end write to the PEA command register -----
; direction = write(0), initialize = 1, strobe = 0
;
IFDEF TOSHIBA
PEA_CMD_STROBE_END      equ 04h
ELSE
PEA_CMD_STROBE_END      equ 04h
ENDIF

;---------------- Strobe begin for write ------------------------------
; direction = write(0), initialize = 1, strobe = 1.
;
IFDEF TOSHIBA
PEA_STROBE_WRITE_BEGIN equ 05h
ELSE
PEA_STROBE_WRITE_BEGIN equ 05h
ENDIF

;---------------- Strobe end for write ------------------------------
; direction = write(0), initialize = 1, strobe = 0.
;
IFDEF TOSHIBA
PEA_STROBE_WRITE_END equ  04h
ELSE
PEA_STROBE_WRITE_END equ  04h
ENDIF

IFDEF NIBBLE_MODE
;---------------- Strobe begin for read ------------------------------
; direction = write(0), initialize = 1, strobe = 1.
;
PEA_STROBE_READ_BEGIN equ 05h

;---------------- Strobe end for read ------------------------------
; direction = write(0), initialize = 1, strobe = 0.
;
PEA_STROBE_READ_END equ 04h
ELSE
;---------------- Strobe begin for read ------------------------------
; direction = read(1), initialize = 1, strobe = 1.
;
IFDEF TOSHIBA
PEA_STROBE_READ_BEGIN equ 0e5h
ELSE
PEA_STROBE_READ_BEGIN equ 25h
ENDIF

;---------------- Strobe end for read ------------------------------
; direction = read(1), initialize = 1, strobe = 0.
;
IFDEF TOSHIBA
PEA_STROBE_READ_END equ 0e4h
ELSE
PEA_STROBE_READ_END equ 24h
ENDIF
ENDIF

;----------------------------------------------------------------
; PEA Command Register mask values
;----------------------------------------------------------------

WFI_STATE           equ     80h    ; State of the WFI bit to use

;-------------- Disable Ethernet/Enable Printer ------------------
; WFI = WFI_STATE, Target select 1 = 0, Target select 0 = 0.
;
PEA_ENABLE_PRINTER  equ 00h OR WFI_STATE

;--------------- Select EEPROM for reading -----------------------------------
; WFI = WFI_STATE, Target select 1 = 1, Target select 0 = 0, Read = 1
SEL_READ_EEPROM     equ  50h OR WFI_STATE

;--------------- Select EEPROM for writing -----------------------------------
; WFI = WFI_STATE, Target select 1 = 1, Target select 0 = 0, Read = 0
SEL_WRITE_EEPROM    equ  40h OR WFI_STATE


IFDEF NIBBLE_MODE
;-------------- Select 8005 registers for reading ----------------------------
; WFI = WFI_STATE, Target select 1 = 1, Target select 1 = 1, Read = 1
;
SEL_READ_8005_REG    equ      70h OR WFI_STATE     ; default to high nibble
ELSE
;-------------- Select 8005 registers for reading ----------------------------
; WFI = WFI_STATE, Target select 1 = 0, Target select 0 = 1, Read = 1
;
SEL_READ_8005_REG    equ      30h OR WFI_STATE
ENDIF

;-------------- Select 8005 registers for writing ----------------------------
; WFI = WFI_STATE, Target select 1 = 0, Target select 0 = 1, Read = 0 (write)
;
SEL_WRITE_8005_REG   equ      20h OR WFI_STATE

;--------------------------;
; PEA Board Status values. ;
;--------------------------;

; Use to test if we have determined link integrity.
;
UTP_TEST_LINK   EQU     04h

;
; 8005 interrupted
;
INTERRUPT_8005        EQU     02h

;
; Printer interrupted
;
INTERRUPT_PRINTER     EQU     01h
