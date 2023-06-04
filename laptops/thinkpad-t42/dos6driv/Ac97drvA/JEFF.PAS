unit Jeff;

interface

{
; memory allocation
; allocate 256 bytes of data for DCM_OUT Buffer Descriptor List. (BDL)
; allocate 2 buffers, 64k each for now.


; Detect/reset AC97 
 ; get ICH base address regs for mixer and bus master
 ; read PCI registers 10-11; mask off BIT0
 ; save audio mixer base addy
 ; save bus master base addy

 ; read PCI command register
 ; enable IO and bus master IO_ENA+BM_ENA 

; setup the Codec (actually mixer registers) 
}
var BDL_BUFFER:pchar;{256 byte buffer for descriptor list}
var WAV_BUFFER1:pchar;{64k buffers for wav file storage}

var BDL_BUFFER_SEG:word;  {segment of our 256byte BDL buffer}
var BDL_BUFFER_OFS:word;  {offset of our 256byte BDL buffer}
var WAV_BUFFER1_SEG:word; {segment of our WAV storage}
var WAV_BUFFER1_OFS:word; {offset of our WAV storage}
var WAV_BUFFER2_SEG:word; {segment of 2nd wav buffer}
var WAV_BUFFER2_OFS:word; {offset of 2nd wav buffer}
var NAMBAR_addr:word;      {BAR for mixer}
var NABMBAR_addr:word;     {BAR for bus master regs}


implementation

end.
 