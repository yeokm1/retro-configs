;-----------------------------------------------------------------------
;Copyright (c) 1993 ADVANCED MICRO DEVICES, INC. All Rights Reserved.
;This software is unpblished and contains the trade secrets and 
;confidential proprietary information of AMD. Unless otherwise provided
;in the Software Agreement associated herewith, it is licensed in confidence
;"AS IS" and is not to be reproduced in whole or part by any means except
;for backup. Use, duplication, or disclosure by the Government is subject
;to the restrictions in paragraph (b) (3) (B) of the Rights in Technical
;Data and Computer Software clause in DFAR 52.227-7013 (a) (Oct 1988).
;Software owned by Advanced Micro Devices, Inc., 901 Thompson Place,
;Sunnyvale, CA 94088.
;-----------------------------------------------------------------------
;
; 12-16-93 D.T.	replace the English messages under the Spanish section
;		with the Spanish messages.
;
; 03-2-94 D.T.	Delete PCnet in bad_reset_msg, bad_init_msg
;		and move error_header, usage_msg close to copyright_msg
;		add second digit to version after decimal point
;
;----------------------------------------
; Error Message
;----------------------------------------
; Multiple language support
;   in the makefile use /dXXXXX parameter to select the language
;----------------------------------------
;

;----------------------------------------
IFDEF	ENGLISH
;
;-----------------------------------------------------------------------

bad_reset_msg	db	"002: Unable to reset the device.",CR,LF,'$'

bad_init_msg	db	"003: Unable to initialize the device.",CR,LF,'$'

vds_error_msg	db	"004: VDS memory allocation failed.",CR,LF,'$'

already_msg	db	"005: There is already a packet driver at ",CR,LF,'$'

int_msg		db	"006: <int_no> should be between 0 and "
int_msg_num	LABEL	word		;
		db	"15 inclusive",CR,LF,'$'
					; from verifypi.asm(07-12-93,begin)
no_resident_msg	db	"007: Packet driver failed to initialize the board",CR,LF,'$'

packet_int_msg	db	"008: <packet_int_no> should be in the range 0x60 to 0x80"
		db	CR,LF,'$'		;

INIT_ERR_MSG_STRING	label	byte
init_err0_msg	db	"009:DMA number is not necessary for PCI device.",CR,LF,'$'
init_err1_msg	db	"010:DMA number is not necessary for VESA device.",CR,LF,'$'
init_err2_msg	db	"011:PnP device DMA number mismatch.",CR,LF,'$'
init_err3_msg	db	"012:PCI device IRQ number mismatch.",CR,LF,'$'
init_err4_msg	db	"013:VESA device IRQ number mismatch.",CR,LF,'$'
init_err5_msg	db	"014:PnP device IRQ number mismatch.",CR,LF,'$'
init_err6_msg	db	"015:Device not found.",CR,LF,'$'
init_err7_msg	db	"016:Device not found at IOADDRESS.",CR,LF,'$'
init_err8_msg	db	"017:PCI sacn can only execute on a 386 and higher processor.",CR,LF,'$'
init_err9_msg	db	"018:PCI scan specified, device not found.",CR,LF,'$'
init_err10_msg	db	"019:VESA scan specified, device not found.",CR,LF,'$'
init_err11_msg	db	"020:PnP scan specified, device not found.",CR,LF,'$'
init_err12_msg	db	"021:ISA scan specified, device not found.",CR,LF,'$'
init_err13_msg	db	"022:ISA DMA number out of range.",CR,LF,'$'
init_err14_msg	db	"023:ISA IRQ number out of range.",CR,LF,'$'
init_err15_msg	db	"024:error message.",CR,LF,'$'
init_err16_msg	db	"025:error message.",CR,LF,'$'
init_err17_msg	db	"026:error message.",CR,LF,'$'
init_err18_msg	db	"027:error message.",CR,LF,'$'
init_err19_msg	db	"028:error message.",CR,LF,'$'

usage_msg	db	"001: PCNTPK [-n] [-d] [-w] <INT=packet_int_no>",CR,LF
		db	"[IRQ=int_no] [IOADDR=io_addr] [DMA=dma_no]",CR,LF
		db	"[BUSTYPE=bus] [DMAROTATE] [TP] [FDUP=xx]",CR,LF
		db	"[LED0=xx] [LED1=xx] [LED2=xx] [LED3=xx]",CR,LF,'$'

error_header	db	"PCNTPK-DOS-",'$'

;
;
;----------------------------------------
; Information Message
;----------------------------------------
;
copyright_msg	db	"Packet driver for an PCNTPK, version ",'0'+majver/10,'0'+(majver mod 10),".",'0'+version/10,'0'+(version mod 10),CR,LF
		db	'$'

copyleft_msg	LABEL	byte		;
		db "Packet driver skeleton copyright 1988-92, Crynwr Software."
		db	CR,LF
		db "This program is free software; see the file COPYING for details."
		db	CR,LF
		db "NO WARRANTY; see the file COPYING for details."
		db	CR,LF
		db	CR,LF,'$'

int_no_msg	db	"Interrupt number ",'$'

io_addr_msg	db	"I/O port ",'$'

dma_no_msg	db	"DMA number ",'$'

location_msg	db	"Packet driver is at segment ",'$'

packet_int_num	db	"Packet interrupt number ",'$'

eaddr_msg	db	"My Ethernet address is ",'$'

aaddr_msg	db	"My ARCnet address is ",'$'

crlf_msg	db	CR,LF,'$'

;-----------------------------------------------------------------------
ENDIF		; ENGLISH

IFDEF	GERMAN
;
;-----------------------------------------------------------------------

bad_reset_msg	db	"002: ZurÅcksetzen des GerÑtes nicht mîglich.",CR,LF,'$'

bad_init_msg	db	"003: Initialisieren des GerÑtes nicht mîglich.",CR,LF,'$'

vds_error_msg	db	"004: Zuweisung des VDS-Speichers fehlgeschlagen.",CR,LF,'$'

already_msg	db	"005: Pakettreiber bereits vorhanden an Adresse ",CR,LF,'$'

int_msg		db	"006: <int_nr> mu· zwischen 0 und "
int_msg_num	LABEL	word		;
		db	"15 (einschlie·lich) liegen.",CR,LF,'$'
					; from verifypi.asm(07-12-93,begin)
no_resident_msg	db	"007: Karte konnte nicht durch Pakettreiber initialisiert werden",CR,LF,'$'

packet_int_msg	db	"008: <paket_int_nr> mu· im Bereich 0x60 bis 0x80 liegen"
		db	CR,LF,'$'		;

INIT_ERR_MSG_STRING	label	byte
init_err0_msg	db	"009:DMA-Nummer ist fÅr ein PCI-GerÑt nicht erforderlich.",CR,LF,'$'
init_err1_msg	db	"010:DMA-Nummer ist fÅr ein VESA-GerÑt nicht erforderlich.",CR,LF,'$'
init_err2_msg	db	"011:DMA-Nummer des PnP-GerÑtes stimmt nicht Åberein.",CR,LF,'$'
init_err3_msg	db	"012:IRQ-Nummer des PCI-GerÑtes stimmt nicht Åberein.",CR,LF,'$'
init_err4_msg	db	"013:IRQ-Nummer des VESA-GerÑtes stimmt nicht Åberein.",CR,LF,'$'
init_err5_msg	db	"014:IRQ-Nummer des PnP-GerÑtes stimmt nicht Åberein.",CR,LF,'$'
init_err6_msg	db	"015:GerÑt nicht gefunden.",CR,LF,'$'
init_err7_msg	db	"016:GerÑt nicht an IOADDRESS gefunden.",CR,LF,'$'
init_err8_msg	db	"017:PCI-Abtastung kann nur auf Prozessoren des Typs 386 und hîher ausgefÅhrt werden.",CR,LF,'$'
init_err9_msg	db	"018:PCI-Abtastung angegeben, GerÑt nicht gefunden.",CR,LF,'$'
init_err10_msg	db	"019:VESA-Abtastung angegeben, GerÑt nicht gefunden.",CR,LF,'$'
init_err11_msg	db	"020:PnP-Abtastung angegeben, GerÑt nicht gefunden.",CR,LF,'$'
init_err12_msg	db	"021:ISA-Abtastung angegeben, GerÑt nicht gefunden.",CR,LF,'$'
init_err13_msg	db	"022:ISA DMA-Nummer au·erhalb des gÅltigen Bereichs.",CR,LF,'$'
init_err14_msg	db	"023:ISA IRQ-Nummer au·erhalb des gÅltigen Bereichs.",CR,LF,'$'
init_err15_msg	db	"024:Fehlermeldung.",CR,LF,'$'
init_err16_msg	db	"025:Fehlermeldung.",CR,LF,'$'
init_err17_msg	db	"026:Fehlermeldung.",CR,LF,'$'
init_err18_msg	db	"027:Fehlermeldung.",CR,LF,'$'
init_err19_msg	db	"028:Fehlermeldung.",CR,LF,'$'

usage_msg	db	"001: PCNTPK [-n] [-d] [-w] <INT=paket_int_nr>",CR,LF
		db	"[IRQ=int_nr] [IOADDR=io_adr] [DMA=dma_nr]",CR,LF
		db	"[BUSTYPE=bus] [DMAROTATE] [TP] [FDUP=xx]",CR,LF
		db	"[LED0=xx] [LED1=xx] [LED2=xx] [LED3=xx]",CR,LF,'$'

error_header	db	"PCNTPK-DOS-",'$'

;
;
;----------------------------------------
; Information Message
;----------------------------------------
;
copyright_msg	db	"Pakettreiber fÅr PCNTPK, Version ",'0'+majver/10,'0'+(majver mod 10),".",'0'+version/10,'0'+(version mod 10),CR,LF
		db	'$'

copyleft_msg	LABEL	byte		;
		db "PakettreibergerÅst: Copyright 1988-92, Crynwr Software."
		db	CR,LF
		db "Dieses Programm ist kostenlos verfÅgbare Software; Einzelheiten enthÑlt die Datei COPYING."
		db	CR,LF
		db "KEINE GARANTIE; Einzelheiten enthÑlt die Datei COPYING."
		db	CR,LF
		db	CR,LF,'$'

int_no_msg	db	"Interrupt-Nummer ",'$'

io_addr_msg	db	"I/O-Adresse ",'$'

dma_no_msg	db	"DMA-Nummer ",'$'

location_msg	db	"Pakettreiber wurde geladen in Segment ",'$'

packet_int_num	db	"Paket-Interrupt-Nummer ",'$'

eaddr_msg	db	"Meine Ethernet-Adresse lautet ",'$'

aaddr_msg	db	"Meine ARCnet-Adresse lautet ",'$'

crlf_msg	db	CR,LF,'$'

;-----------------------------------------------------------------------
ENDIF		; GERMAN

IFDEF	SPANISH
;
;-----------------------------------------------------------------------

bad_reset_msg	db	"002: No puede reinicializarse el dispositivo.",CR,LF,'$'

bad_init_msg	db	"003: No puede inicializarse el dispositivo.",CR,LF,'$'

vds_error_msg	db	"004: Fall¢ la asignaci¢n de memoria VDS.",CR,LF,'$'

already_msg	db	"005: Ya existe un driver de paquete en",CR,LF,'$'

int_msg		db	"006: <n£m_int> debe estar entre 0 y "
int_msg_num	LABEL	word		;
		db	"15 inclusive",CR,LF,'$'
					; from verifypi.asm(07-12-93,begin)
no_resident_msg	db	"007: El driver de paquete no pudo inicializar la tarjeta",CR,LF,'$'

packet_int_msg	db	"008: <n£m_int_paquete> debe estar en la gama 0x60 a 0x80"
		db	CR,LF,'$'		;

INIT_ERR_MSG_STRING	label	byte
init_err0_msg	db	"009:Un n£mero de DMA no es necesario para un dispositivo PCI.",CR,LF,'$'
init_err1_msg	db	"010:Un n£mero de DMA no es necesario para un dispositivo VESA.",CR,LF,'$'
init_err2_msg	db	"011:Falta coincidencia n£mero DMA dispositivo PnP.",CR,LF,'$'
init_err3_msg	db	"012:Falta coincidencia n£mero IRQ dispositivo PCI.",CR,LF,'$'
init_err4_msg	db	"013:Falta coincidencia n£mero IRQ dispositivo VESA.",CR,LF,'$'
init_err5_msg	db	"014:Falta coincidencia n£mero IRQ dispositivo PnP.",CR,LF,'$'
init_err6_msg	db	"015:Dispositivo no hallado.",CR,LF,'$'
init_err7_msg	db	"016:Dispositivo no hallado en IOADDRESS.",CR,LF,'$'
init_err8_msg	db	"017:Exploraci¢n PCI s¢lo puede ejecutarse en un procesador 386 o superior.",CR,LF,'$'
init_err9_msg	db	"018:Especificada exploraci¢n PCI, dispositivo no hallado.",CR,LF,'$'
init_err10_msg	db	"019:Especificada exploraci¢n VESA, dispositivo no hallado.",CR,LF,'$'
init_err11_msg	db	"020:Especificada exploraci¢n PnP, dispositivo no hallado.",CR,LF,'$'
init_err12_msg	db	"021:Especificada exploraci¢n ISA especificada, dispositivo no hallado.",CR,LF,'$'
init_err13_msg	db	"022:N£mero de DMA ISA fuera de gama.",CR,LF,'$'
init_err14_msg	db	"023:N£mero de IRQ ISA fuera de gama.",CR,LF,'$'
init_err15_msg	db	"024:mensaje de error.",CR,LF,'$'
init_err16_msg	db	"025:mensaje de error.",CR,LF,'$'
init_err17_msg	db	"026:mensaje de error.",CR,LF,'$'
init_err18_msg	db	"027:mensaje de error.",CR,LF,'$'
init_err19_msg	db	"028:mensaje de error.",CR,LF,'$'

usage_msg	db	"001: PCNTPK [-n] [-d] [-w] <INT=n£m_int_paquete>",CR,LF
		db	"[IRQ=n£m_int] [IOADDR=direc_es] [DMA=n£m_dma]",CR,LF
		db	"[BUSTYPE=bus] [DMAROTATE] [TP] [FDUP=xx]",CR,LF
		db	"[LED0=xx] [LED1=xx] [LED2=xx] [LED3=xx]",CR,LF,'$'

error_header	db	"PCNTPK-DOS-",'$'

;
;
;----------------------------------------
; Information Message
;----------------------------------------
;
copyright_msg	db	"Driver de paquete para PCNTPK, versi¢n ",'0'+majver/10,'0'+(majver mod 10),".",'0'+version/10,'0'+(version mod 10),CR,LF
		db	'$'

copyleft_msg	LABEL	byte		;
		db "Esqueleto de driver de paquete Copyright 1988-92, Crynwr Software."
		db	CR,LF
		db "Este programa es software libre. Consulte detalles en el fichero COPYING."
		db	CR,LF
		db "SIN GARANTIA. Consulte detalles en el fichero COPYING."
		db	CR,LF
		db	CR,LF,'$'

int_no_msg	db	"N£mero de interrupci¢n ",'$'

io_addr_msg	db	"Puerto de E/S ",'$'

dma_no_msg	db	"N£mero de DMA ",'$'

location_msg	db	"Driver de paquete est† en segmento",'$'

packet_int_num	db	"N£mero de interrupci¢n de paquete ",'$'

eaddr_msg	db	"Mi direcci¢n Ethernet es ",'$'

aaddr_msg	db	"Mi direcci¢n ARCnet es",'$'

crlf_msg	db	CR,LF,'$'

;-----------------------------------------------------------------------
ENDIF		; SPANISH

IFDEF	FRENCH
;
;-----------------------------------------------------------------------

bad_reset_msg	db	"002: Impossible de rÇinitialiser le pÇriphÇrique.",CR,LF,'$'

bad_init_msg	db	"003: Impossible d'initialiser le pÇriphÇrique.",CR,LF,'$'

vds_error_msg	db	"004: Echec allocation mÇmoire VDS.",CR,LF,'$'

already_msg	db	"005: Il y a dÇjÖ un gestionnaire de paquet Ö ",CR,LF,'$'

int_msg		db	"006: <num_int> doit àtre compris entre 0 et "
int_msg_num	LABEL	word		;
		db	"15 inclus",CR,LF,'$'
					; from verifypi.asm(07-12-93,begin)
no_resident_msg	db	"007: Le gestionnaire de paquet n'a pas pu initialiser la carte",CR,LF,'$'

packet_int_msg	db	"008: <num_int_paquet> doit àtre compris entre 0x60 et 0x80"
		db	CR,LF,'$'		;

INIT_ERR_MSG_STRING	label	byte
init_err0_msg	db	"009:Un numÇro de DMA n'est pas nÇcessaire pour un pÇriphÇrique PCI.",CR,LF,'$'
init_err1_msg	db	"010:Un numÇro de DMA n'est pas nÇcessaire pour un pÇriphÇrique VESA.",CR,LF,'$'
init_err2_msg	db	"011:NumÇro de DMA de pÇriphÇrique PnP ne correspond pas.",CR,LF,'$'
init_err3_msg	db	"012:NumÇro d'IRQ de pÇriphÇrique PCI ne correspond pas.",CR,LF,'$'
init_err4_msg	db	"013:NumÇro d'IRQ de pÇriphÇrique VESA ne correspond pas.",CR,LF,'$'
init_err5_msg	db	"014:NumÇro d'IRQ de pÇriphÇrique PnP ne correspond pas.",CR,LF,'$'
init_err6_msg	db	"015:PÇriphÇrique non trouvÇ.",CR,LF,'$'
init_err7_msg	db	"016:PÇriphÇrique non trouvÇ Ö IOADDRESS.",CR,LF,'$'
init_err8_msg	db	"017:ExÇcution balayage PCI possible uniquement sur processeur 386 ou supÇrieur.",CR,LF,'$'
init_err9_msg	db	"018:Balayage PCI spÇcifiÇ, pÇriphÇrique non trouvÇ.",CR,LF,'$'
init_err10_msg	db	"019:Balayage VESA spÇcifiÇ, pÇriphÇrique non trouvÇ.",CR,LF,'$'
init_err11_msg	db	"020:Balayage PnP spÇcifiÇ, pÇriphÇrique non trouvÇ.",CR,LF,'$'
init_err12_msg	db	"021:Balayage ISA spÇcifiÇ, pÇriphÇrique non trouvÇ.",CR,LF,'$'
init_err13_msg	db	"022:NumÇro de DMA ISA hors limites.",CR,LF,'$'
init_err14_msg	db	"023:NumÇro d'IRQ ISA hors limites.",CR,LF,'$'
init_err15_msg	db	"024:message d'erreur.",CR,LF,'$'
init_err16_msg	db	"025:message d'erreur.",CR,LF,'$'
init_err17_msg	db	"026:message d'erreur.",CR,LF,'$'
init_err18_msg	db	"027:message d'erreur.",CR,LF,'$'
init_err19_msg	db	"028:message d'erreur.",CR,LF,'$'

usage_msg	db	"001: PCNTPK [-n] [-d] [-w] <INT=num_int_paquet>",CR,LF
		db	"[IRQ=num_int] [IOADDR=adr_es] [DMA=num_dma]",CR,LF
		db	"[BUSTYPE=bus] [DMAROTATE] [TP] [FDUP=xx]",CR,LF
		db	"[LED0=xx] [LED1=xx] [LED2=xx] [LED3=xx]",CR,LF,'$'

error_header	db	"PCNTPK-DOS-",'$'

;
;
;----------------------------------------
; Information Message
;----------------------------------------
;
copyright_msg	db	"Gestionnaire de paquet pour PCNTPK, version",'0'+majver/10,'0'+(majver mod 10),".",'0'+version/10,'0'+(version mod 10),CR,LF
		db	'$'

copyleft_msg	LABEL	byte		;
		db "Squelette de gestionnaire de paquet copyright 1988-92, Crynwr Software."
		db	CR,LF
		db "Ce programme est un logiciel gratuit; voir le fichier COPYING pour les dÇtails."
		db	CR,LF
		db "SANS GARANTIE; voir le fichier COPYING pour les dÇtails."
		db	CR,LF
		db	CR,LF,'$'

int_no_msg	db	"NumÇro d'interruption ",'$'

io_addr_msg	db	"Port d'E/S ",'$'

dma_no_msg	db	"NumÇro de DMA ",'$'

location_msg	db	"Le gestionnaire de paquet est au segment ",'$'

packet_int_num	db	"NumÇro d'interruption de paquet ",'$'

eaddr_msg	db	"Mon adresse Ethernet est ",'$'

aaddr_msg	db	"Mon adresse ARCnet est ",'$'

crlf_msg	db	CR,LF,'$'

;-----------------------------------------------------------------------
ENDIF		; FRENCH

IFDEF	ITALIAN
;
;-----------------------------------------------------------------------

bad_reset_msg	db	"002: Impossibile ripristinare la periferica.",CR,LF,'$'

bad_init_msg	db	"003: Impossibile inizializzare la periferica.",CR,LF,'$'

vds_error_msg	db	"004: Assegnazione di memoria VDS fallita.",CR,LF,'$'

already_msg	db	"005: Esiste giÖ un driver di pacchetto a ",CR,LF,'$'

int_msg		db	"006: <num_int> dovrebbe essere compreso tra 0 e "
int_msg_num	LABEL	word		;
		db	"15 incluso",CR,LF,'$'
					; from verifypi.asm(07-12-93,begin)
no_resident_msg	db	"007: Il driver di pacchetto non ha inizializzato la scheda",CR,LF,'$'

packet_int_msg	db	"008: <num_int_pacchetto> dovrebbe essere compreso tra 0x60 e 0x80"
		db	CR,LF,'$'		;

INIT_ERR_MSG_STRING	label	byte
init_err0_msg	db	"009:Numero DMA non necessario per periferica PCI.",CR,LF,'$'
init_err1_msg	db	"010:Numero DMA non necessario per periferica VESA.",CR,LF,'$'
init_err2_msg	db	"011:Non corrispondenza numero DMA periferica PnP.",CR,LF,'$'
init_err3_msg	db	"012: Non corrispondenza numero IRQ periferica PCI.",CR,LF,'$'
init_err4_msg	db	"013: Non corrispondenza numero IRQ periferica VESA.",CR,LF,'$'
init_err5_msg	db	"014: Non corrispondenza numero IRQ periferica PnP.",CR,LF,'$'
init_err6_msg	db	"015:Periferica non trovata.",CR,LF,'$'
init_err7_msg	db	"016:Periferica non trovata a IOADDRESS.",CR,LF,'$'
init_err8_msg	db	"017:Analisi PCI eseguibile solo su processori 386 e superiori.",CR,LF,'$'
init_err9_msg	db	"018:Analisi PCI specificata, periferica non trovata.",CR,LF,'$'
init_err10_msg	db	"019:Analisi VESA specificata, periferica non trovata.",CR,LF,'$'
init_err11_msg	db	"020:Analisi PnP specificata, periferica non trovata.",CR,LF,'$'
init_err12_msg	db	"021:Analisi ISA specificata, periferica non trovata.",CR,LF,'$'
init_err13_msg	db	"022:Numero DMA ISA fuori intervallo.",CR,LF,'$'
init_err14_msg	db	"023:Numero IRQ ISA fuori intervallo.",CR,LF,'$'
init_err15_msg	db	"024: messaggio di errore.",CR,LF,'$'
init_err16_msg	db	"025: messaggio di errore.",CR,LF,'$'
init_err17_msg	db	"026: messaggio di errore.",CR,LF,'$'
init_err18_msg	db	"027: messaggio di errore.",CR,LF,'$'
init_err19_msg	db	"028: messaggio di errore.",CR,LF,'$'

usage_msg	db	"001: PCNTPK [-n] [-d] [-w] <INT=num_int_pacchetto>",CR,LF
		db	"[IRQ=num_int] [IOADDR=indir_io] [DMA=num_dma]",CR,LF
		db	"[BUSTYPE=bus] [DMAROTATE] [TP] [FDUP=xx]",CR,LF
		db	"[LED0=xx] [LED1=xx] [LED2=xx] [LED3=xx]",CR,LF,'$'

error_header	db	"PCNTPK-DOS-",'$'

;
;
;----------------------------------------
; Information Message
;----------------------------------------
;
copyright_msg	db	"Driver di pacchetto per un PCNTPK, versione ",'0'+majver/10,'0'+(majver mod 10),".",'0'+version/10,'0'+(version mod 10),CR,LF
		db	'$'

copyleft_msg	LABEL	byte		;
		db "Copyright 1988-92 della maschera del driver di pacchetto, Crynwr Software."
		db	CR,LF
		db "Questo programma ä software gratuito; vedere il file COPYING per informazioni dettagliate."
		db	CR,LF
		db "NESSUNA GARANZIA; vedere il file COPYING per informazioni dettagliate."
		db	CR,LF
		db	CR,LF,'$'

int_no_msg	db	"Numero di interrupt ",'$'

io_addr_msg	db	"Porta I/O ",'$'

dma_no_msg	db	"Numero DMA ",'$'

location_msg	db	"Driver di pacchetto presso il segmento ",'$'

packet_int_num	db	"Numero di interrupt di pacchetto ",'$'

eaddr_msg	db	"Il mio indirizzo Ethernet ä",'$'

aaddr_msg	db	"Il mio indirizzo ARCnet ä",'$'

crlf_msg	db	CR,LF,'$'

;-----------------------------------------------------------------------
ENDIF		; ITALIAN
