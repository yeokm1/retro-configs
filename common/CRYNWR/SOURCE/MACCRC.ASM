;*******************************************************************************
;
; MACCRC.ASM
;
; ASM file for Dec Tulip and Fast Ethernet boards that provides FAST CRC calc
; Routine.
;
;Written by:   Moti Haimovsky
;	       Dror Efrati
;
; Date:        1-APR-1997
;
;
; Copyright (C) 1994 by Digital Equipment Corporation 
; All rights reserved.
;
; Modification History:
;
;       By            Date     Ver.  Modification Description
; --------------- ----------- ----- --------------------------------------
;*******************************************************************************
include  SEG_DEFS.INC
include  MacCRC.ash
.386

START_DATA_SEGMENT_RUNTIME
;***********************************************************************\
;                                                                       *
; The CRC fast (software) calculation table.                            *
;                                                                       *
;***********************************************************************/
	align 4

CRCTable	dd	000000000h
		dd	077073096h
		dd	0EE0E612Ch
		dd	0990951BAh
		dd	0076DC419h
		dd	0706AF48Fh
		dd	0E963A535h
		dd	09E6495A3h
		dd	00EDB8832h
		dd	079DCB8A4h
		dd	0E0D5E91Eh
		dd	097D2D988h
		dd	009B64C2Bh
		dd	07EB17CBDh
		dd	0E7B82D07h
		dd	090BF1D91h
		dd	01DB71064h
		dd	06AB020F2h
		dd	0F3B97148h
		dd	084BE41DEh
		dd	01ADAD47Dh
		dd	06DDDE4EBh
		dd	0F4D4B551h
		dd	083D385C7h
		dd	0136C9856h
		dd	0646BA8C0h
		dd	0FD62F97Ah
		dd	08A65C9ECh
		dd	014015C4Fh
		dd	063066CD9h
		dd	0FA0F3D63h
		dd	08D080DF5h
		dd	03B6E20C8h
		dd	04C69105Eh
		dd	0D56041E4h
		dd	0A2677172h
		dd	03C03E4D1h
		dd	04B04D447h
		dd	0D20D85FDh
		dd	0A50AB56Bh
		dd	035B5A8FAh
		dd	042B2986Ch
		dd	0DBBBC9D6h
		dd	0ACBCF940h
		dd	032D86CE3h
		dd	045DF5C75h
		dd	0DCD60DCFh
		dd	0ABD13D59h
		dd	026D930ACh
		dd	051DE003Ah
		dd	0C8D75180h
		dd	0BFD06116h
		dd	021B4F4B5h
		dd	056B3C423h
		dd	0CFBA9599h
		dd	0B8BDA50Fh
		dd	02802B89Eh
		dd	05F058808h
		dd	0C60CD9B2h
		dd	0B10BE924h
		dd	02F6F7C87h
		dd	058684C11h
		dd	0C1611DABh
		dd	0B6662D3Dh
		dd	076DC4190h
		dd	001DB7106h
		dd	098D220BCh
		dd	0EFD5102Ah
		dd	071B18589h
		dd	006B6B51Fh
		dd	09FBFE4A5h
		dd	0E8B8D433h
		dd	07807C9A2h
		dd	00F00F934h
		dd	09609A88Eh
		dd	0E10E9818h
		dd	07F6A0DBBh
		dd	0086D3D2Dh
		dd	091646C97h
		dd	0E6635C01h
		dd	06B6B51F4h
		dd	01C6C6162h
		dd	0856530D8h
		dd	0F262004Eh
		dd	06C0695EDh
		dd	01B01A57Bh
		dd	08208F4C1h
		dd	0F50FC457h
		dd	065B0D9C6h
		dd	012B7E950h
		dd	08BBEB8EAh
		dd	0FCB9887Ch
		dd	062DD1DDFh
		dd	015DA2D49h
		dd	08CD37CF3h
		dd	0FBD44C65h
		dd	04DB26158h
		dd	03AB551CEh
		dd	0A3BC0074h
		dd	0D4BB30E2h
		dd	04ADFA541h
		dd	03DD895D7h
		dd	0A4D1C46Dh
		dd	0D3D6F4FBh
		dd	04369E96Ah
		dd	0346ED9FCh
		dd	0AD678846h
		dd	0DA60B8D0h
		dd	044042D73h
		dd	033031DE5h
		dd	0AA0A4C5Fh
		dd	0DD0D7CC9h
		dd	05005713Ch
		dd	0270241AAh
		dd	0BE0B1010h
		dd	0C90C2086h
		dd	05768B525h
		dd	0206F85B3h
		dd	0B966D409h
		dd	0CE61E49Fh
		dd	05EDEF90Eh
		dd	029D9C998h
		dd	0B0D09822h
		dd	0C7D7A8B4h
		dd	059B33D17h
		dd	02EB40D81h
		dd	0B7BD5C3Bh
		dd	0C0BA6CADh
		dd	0EDB88320h
		dd	09ABFB3B6h
		dd	003B6E20Ch
		dd	074B1D29Ah
		dd	0EAD54739h
		dd	09DD277AFh
		dd	004DB2615h
		dd	073DC1683h
		dd	0E3630B12h
		dd	094643B84h
		dd	00D6D6A3Eh
		dd	07A6A5AA8h
		dd	0E40ECF0Bh
		dd	09309FF9Dh
		dd	00A00AE27h
		dd	07D079EB1h
		dd	0F00F9344h
		dd	08708A3D2h
		dd	01E01F268h
		dd	06906C2FEh
		dd	0F762575Dh
		dd	0806567CBh
		dd	0196C3671h
		dd	06E6B06E7h
		dd	0FED41B76h
		dd	089D32BE0h
		dd	010DA7A5Ah
		dd	067DD4ACCh
		dd	0F9B9DF6Fh
		dd	08EBEEFF9h
		dd	017B7BE43h
		dd	060B08ED5h
		dd	0D6D6A3E8h
		dd	0A1D1937Eh
		dd	038D8C2C4h
		dd	04FDFF252h
		dd	0D1BB67F1h
		dd	0A6BC5767h
		dd	03FB506DDh
		dd	048B2364Bh
		dd	0D80D2BDAh
		dd	0AF0A1B4Ch
		dd	036034AF6h
		dd	041047A60h
		dd	0DF60EFC3h
		dd	0A867DF55h
		dd	0316E8EEFh
		dd	04669BE79h
		dd	0CB61B38Ch
		dd	0BC66831Ah
		dd	0256FD2A0h
		dd	05268E236h
		dd	0CC0C7795h
		dd	0BB0B4703h
		dd	0220216B9h
		dd	05505262Fh
		dd	0C5BA3BBEh
		dd	0B2BD0B28h
		dd	02BB45A92h
		dd	05CB36A04h
		dd	0C2D7FFA7h
		dd	0B5D0CF31h
		dd	02CD99E8Bh
		dd	05BDEAE1Dh
		dd	09B64C2B0h
		dd	0EC63F226h
		dd	0756AA39Ch
		dd	0026D930Ah
		dd	09C0906A9h
		dd	0EB0E363Fh
		dd	072076785h
		dd	005005713h
		dd	095BF4A82h
		dd	0E2B87A14h
		dd	07BB12BAEh
		dd	00CB61B38h
		dd	092D28E9Bh
		dd	0E5D5BE0Dh
		dd	07CDCEFB7h
		dd	00BDBDF21h
		dd	086D3D2D4h
		dd	0F1D4E242h
		dd	068DDB3F8h
		dd	01FDA836Eh
		dd	081BE16CDh
		dd	0F6B9265Bh
		dd	06FB077E1h
		dd	018B74777h
		dd	088085AE6h
		dd	0FF0F6A70h
		dd	066063BCAh
		dd	011010B5Ch
		dd	08F659EFFh
		dd	0F862AE69h
		dd	0616BFFD3h
		dd	0166CCF45h
		dd	0A00AE278h
		dd	0D70DD2EEh
		dd	04E048354h
		dd	03903B3C2h
		dd	0A7672661h
		dd	0D06016F7h
		dd	04969474Dh
		dd	03E6E77DBh
		dd	0AED16A4Ah
		dd	0D9D65ADCh
		dd	040DF0B66h
		dd	037D83BF0h
		dd	0A9BCAE53h
		dd	0DEBB9EC5h
		dd	047B2CF7Fh
		dd	030B5FFE9h
		dd	0BDBDF21Ch
		dd	0CABAC28Ah
		dd	053B39330h
		dd	024B4A3A6h
		dd	0BAD03605h
		dd	0CDD70693h
		dd	054DE5729h
		dd	023D967BFh
		dd	0B3667A2Eh
		dd	0C4614AB8h
		dd	05D681B02h
		dd	02A6F2B94h
		dd	0B40BBE37h
		dd	0C30C8EA1h
		dd	05A05DF1Bh
		dd	02D02EF8Dh
CRCTableSize	equ	$-CRCTable

END_DATA_SEGMENT_RUNTIME

START_CODE_SEGMENT_RUNTIME
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CRC_Calc
;
; This routine calculates packet CRC.
; It returns the CRC value in EAX.
;
; Called by: o DriverSend
;
;               SI -> packet body (one contiguous buffer only)
;               CX -  packet lenght (without the CRC)
;               Interrupts enabled
;
;
; Outputs:	Calculated packet CRC is in packet buffer at offset [CX]
;		EAX-  Packet CRC
; 		BX -  Preserved
; 		CX -  Destroyed
;		SI -  Points right after end of packet
;               DI -  Destroyed
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	align	4
CRC_Calc	proc 	near

        push	bx

	mov	eax, 0FFFFFFFFh		; EAX = CRC accumulator
	lea	di, CRCTable            ; DI = pointer to table


	align 4
CT_GetNextByte:
	xor	bx, bx

	mov	bl, al                  ; BL = low CRC byte
	xor	bl, [si]                ; BX = index to table
	inc     si                      ; ESI = points to next byte

	shr	eax, 8

	shl	bx, 2                   ; BX = points into table (longwords)

	xor	eax, [bx][di]

	loop	CT_GetNextByte

	not	eax			; xor EAX with FFFFFFFFh

	pop	bx
	ret

CRC_Calc	ENDP

END_CODE_SEGMENT_RUNTIME

START_CODE_SEGMENT_INIT
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; VerifyCRCTable
;
; This routine verifies CRC table correctness.
;
; Called by: o DriverInit
;
;
; Outputs:
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
CRC_VerifyTable	proc	near

	mov	cx, CRCTableSize
	lea	si, CRCTable
	call	CRC_Calc
	cmp	eax, 6FCF9E13h
	je	SHORT GoodCRCTable
	DataAddress	dx, CRCTableErr
	stc
GoodCRCTable:

	ret

CRC_VerifyTable	endp

END_CODE_SEGMENT_INIT

;-----------------;
; Sanity checking ;
;-----------------;

;OS type checking
;----------------
IF OS EQ DOS
	%OUT MacCRC.ASM Compiling for DOS.
ELSEIF OS EQ OS2
	%OUT MacCRC.ASM Compiling for OS2.
ELSE
	.ERR
	%OUT MacCRC.ASM Illegal OS value.
ENDIF

;NOS type checking
;-----------------
IF NOS EQ ODI
	%OUT MacCRC.ASM Compiling for ODI.
ELSEIF NOS EQ NDIS2
	%OUT MacCRC.ASM Compiling for NDIS2.
ELSE
	.ERR
	%OUT MacCRC.ASM Illegal NOS value.
ENDIF



END
