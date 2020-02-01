unit ICH;

interface

uses PCI,AC97,JEFF,ICHDMA,misc;


{Software can read all these as 32bit}


{Buffer descriptor base address register}
{32bits R/W}
{low bits reserved 2:0}
{hi bits used  31:3}
{default=0}
{CIV Current Index Value Register}
{8bits Read Only!}
{default=0}
{bits reserved 7:5}
{bits 4:0=Current index value[4:0].
Thease bits represent which buffer descriptor
within the list of 32 descriptors is currently
being processed. As each descriptor is processed,
this value is incriminated. The value rolls over
after it reaches 31}

{LVI Last Valid Index Register }
{15h 8bits Read/Write}
{default=0}
{bits reserved 7:5}
{bits used 4:0 represent the last valid descriptor in the list.
This value is updated by the software each time
it prepares a new buffer and adds it to the list.}

{SR Status Register}
{read/write 16bits}
{bits reserved 15:5}
{bit 4 FIFO overrun}
{bit 3 Buffer Completion Interrupt Status(BCIS)}

{bit 2 Last Valid Buffer Completion Interrupt LVBCI}
{remains hi for software to clear}

{bit 1 CELV Current Equals Last Valid}
{1=Current index is equal to the value in the Last Valid index Register,
and the buffer pointed to by the CIV has been processed }
{cleared by hardware}

{bit 0=DMA DCH Controller Halted}
{1=Halted,This could happen because of the Start/Stop bit being cleared or it could happen
once the controller has processed the last valid
buffer (in which case it sets bit 1 and halts)}


const
ICH_DID    =$2415 ;{ ICH device ID}
ICH0_DID   =$2425 ; {ICH0  }
ICH2_DID   =$2445 ; {ICH2 }
ICH3_DID   =$2485 ; {ICH3}
ICH4_DID   =$24c5 ; {ICH4}
ICH5_DID   =$24d5 ; {ICH5}
ICH6_DID   =$266e ; {ICH6}
ICH7_DID   =$27de ; {ICH7}


{ICH4 AC'97 PCI configuration space}
{00h VID Vendor ID}{8086h}
{02h DID Device ID}{24C5h}
{04h PCICMD PCI Command}
  {PCICMD Bit0 I/O Space Enable(IOSE)R/W This bit controls access to the Ac'97 Audio controller I/O space registers.}
  {PCICMD Bit1 Memory Space Enable(MSE)R/W This bit enables memory space addresses to the AC'97 Audio controller.}
  {PCICMD Bit2 Bus Master Enable(BME)R/W This bit controls standard PCI bus mastering capabilities.}
{06h PCISTS PCI Status}
  {PCISTS Bit13 Master Abort Status(MAS)R/WC}
{08h RID}
{0Ah PI}
{0Bh SCC}
{0Eh BCC}
const NAMBAR_REG=$10;{Native Audio Mixer Base Address}{uses bits 8 to 15 (256 bytes)}
const NABMBAR_REG=$14;{Native Audio Bus Mastering Base Address}{uses 6-15 (64 bytes)}
{}
const AC97MEMBAR=$18;{Mixer Base Address(Mem) }{(512 bytes) bits 9-31 Base Address R/W;}
const MEMBAR_REG=$1C;{Bus Master Base Address(Mem)}{(256 bytes) 8-38 Base Addressbits }
{2ch SVID}
{2eh SID}
{34h CAP_PTR}
IRQ_REG=$3C;{INTR_LN IRQ holder for PCI}
INT_REG=$3D;{INTR_PN}
{40h PCID}
ICH4_CFG_REG=$41;{CFG ICH4 config register}
{50h PID}
{52h PC}
{54h PCS}
var BAR_NativeAudioMixerBaseAddress:longint;
var BAR_NativeAudioBusMasteringBaseAddress:longint;
var BAR_MixerBaseAddress_MEM:longint;
var BAR_BustMasterBaseAddress_MEM:longint;
function codecConfig(samplerate:word):word; export;
function EnableVariableRatebit:byte; export;
function EnableDoubleRatebit:byte;
function resetregisters:byte;export;
function getac97(ac97index:longint):longint; export;
function setac97(ac97index,settovalue:longint):boolean; export;
function getCurrentIndex:word;export;
function setLastValidIndex(samplerate:word):word;export;
function SetBDLBuffer(RAMaddress:pointer):byte;export;
function codecplay(play:boolean):byte; export;
implementation

function resetregisters:byte; begin
port[NABMBAR_addr+PO_CR_REG]:=ResetReg{RR};
end;

function SetBDLBuffer(RAMaddress:pointer):byte; var tmp:word;begin
tmp:=NABMBAR_addr+PO_BDBAR_REG;
outport32(tmp,longint(RAMaddress));{point bdl buffer at your buffer data }
end;

function setac97(ac97index,settovalue:longint):boolean; var tmp:longint;begin
tmp:=NAMBAR_addr+ac97index;
portw[tmp]:=settovalue;
{shall we wait for the codec?}
end;

function getac97(ac97index:longint):longint; var tmp:longint;begin
tmp:=NAMBAR_addr+ac97index;
result:=portw[tmp];
end;



function EnableDoubleRatebit:byte;{48khz plays as 96khz}
var tmp:word;
begin
result:=0;
tmp:=NAMBAR_addr+CODEC_EXT_AUDIO_REG;{get settings}
if ((portw[tmp] and 1)=2){support for DRA} then begin
tmp:=NAMBAR_addr+CODEC_EXT_AUDIO_CTRL_REG;
portw[tmp]:=portw[tmp] or 2;{DRA double rate enable}
end else result:=1;
end;


function EnableVariableRatebit:byte;
var tmp:word;
begin
result:=0;
tmp:=NAMBAR_addr+CODEC_EXT_AUDIO_REG;{get settings}
if ((portw[tmp] and 1)=1){support for VRA} then begin
tmp:=NAMBAR_addr+CODEC_EXT_AUDIO_CTRL_REG;
portw[tmp]:=portw[tmp] or 1;{VRA variable rate enable}
end else result:=1;
end;

function codecConfig(samplerate:word):word;
var tmp:word;
begin
tmp:=NAMBAR_addr+CODEC_PCM_FRONT_DACRATE_REG;
portw[tmp]:=samplerate;
{delay 16ms}
end;

function codecplay(play:boolean):byte;var tmp:word;begin
tmp:=NABMBAR_addr+PO_CR_REG;
if(play=true)then begin portw[tmp]:=RPBM{=1};end;
if(play=false)then begin portw[tmp]:=0{not BIT0};end;
end;


function getCurrentIndex:word;
var tmp:word;
begin
tmp:=NABMBAR_addr+PO_CIV_REG;
result:=port[tmp];
end;


function setLastValidIndex(samplerate:word):word;
var tmp:word;
begin
tmp:=NABMBAR_addr+PO_LVI_REG;
port[tmp]:=samplerate;
{delay 16ms}
end;



end.
