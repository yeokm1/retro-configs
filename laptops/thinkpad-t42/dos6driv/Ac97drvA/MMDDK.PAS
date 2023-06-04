unit Mmddk;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  ich,ichdma,tintlist,pci,Forms, Dialogs, StdCtrls, Buttons,inifiles;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Label1: TLabel;
    Edit1: TEdit;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;


{common constants}
{const Bit:array[0..7] of byte=(1,2,4,8,16,32,64,128);}
const BIT0=1;
const BIT1=2;
const BIT2=4;
const BIT3=8;
const BIT4=$10;
const BIT5=$20;
const BIT6=$40;
const BIT7=$80;
const BIT8=$100;
const BIT9=$200;
const BIT10=$400;
const BIT11=$800;
const BIT12=$1000;
const BIT13=$2000;
const BIT14=$4000;
const BIT15=$8000;
const BIT16=$10000;
const BIT17=$20000;
const BIT18=$40000;
const BIT19=$80000;
const BIT20=$100000;
const BIT21=$200000;
const BIT22=$400000;
const BIT23=$800000;
const BIT24=$1000000;
BIT25=$2000000;
BIT26=$4000000;
BIT27=$8000000;
BIT28=$10000000;
BIT29=$20000000;
BIT30=$40000000;
BIT31=$80000000;





{mmsystem}

const{mmsystem}
  CallBack_TypeMask   = $00070000;    { callback type mask }
  CallBack_Null       = $00000000;    { no callback }
  CallBack_Window     = $00010000;    { dwCallback is a HWND }
  CallBack_Task       = $00020000;    { dwCallback is a HTASK }
  CallBack_Function   = $00030000;    { dwCallback is a FARPROC }

{ flags for dwFlags parameter in waveOutOpen() and waveInOpen() }
const  wave_Format_Query     = $0001;
const  wave_AllowSync        = $0002;
const
  MaxPNameLen      =  32;    { max product name length (including NULL) }


{flags for dwSupport field of WAVEOUTCAPS }

const WAVECAPS_PITCH =         $0001;  { supports pitch control }
const WAVECAPS_PLAYBACKRATE =  $0002;   { supports playback rate control }
const WAVECAPS_VOLUME        = $0004;   { supports volume control }
const WAVECAPS_LRVOLUME      = $0008;   { separate left-right volume control }
const WAVECAPS_SYNC          = $0010;

type
  TWaveOutCaps = record
    wMid: Word;                 { manufacturer ID }
    wPid: Word;                 { product ID }
    vDriverVersion: word;       { version of the driver }
    szPname: array[0..MaxPNameLen-1] of Char;  { product name (NULL terminated string) }
    dwFormats: Longint;          { formats supported }
    wChannels: Word;            { number of sources supported }
    dwSupport: Longint;          { functionality supported by driver }
  end;
  PWaveOutCaps = ^TWaveOutCaps;

const
  mm_Microsoft            = 1;       { Microsoft Corp. }

{ product IDs }
  mm_MIDI_Mapper          = 1;       { MIDI Mapper }
  mm_Wave_Mapper          = 2;       { Wave Mapper }

  mm_SndBlst_MidiOut      = 3;       { Sound Blaster MIDI output port }
  mm_SndBlst_MidiIn       = 4;       { Sound Blaster MIDI input port  }
  mm_SndBlst_Synth        = 5;       { Sound Blaster internal synthesizer }
  mm_SndBlst_WaveOut      = 6;       { Sound Blaster waveform output }
  mm_SndBlst_WaveIn       = 7;       { Sound Blaster waveform input }

  mm_Adlib                = 9;       { Ad Lib-compatible synthesizer }

  mm_MPU401_MidiOut       = 10;      { MPU401-compatible MIDI output port }
  mm_MPU401_MidiIn        = 11;      { MPU401-compatible MIDI input port }

  mm_PC_Joystick          = 12;      { Joystick adapter }

const
  wave_InvalidFormat     = $00000000;       { invalid format }

  wave_Format_1M08       = $00000001;       { 11.025 kHz, Mono,   8-bit  }
  wave_Format_1S08       = $00000002;       { 11.025 kHz, Stereo, 8-bit  }
  wave_Format_1M16       = $00000004;       { 11.025 kHz, Mono,   16-bit }
  wave_Format_1S16       = $00000008;       { 11.025 kHz, Stereo, 16-bit }

  wave_Format_2M08       = $00000010;       { 22.05  kHz, Mono,   8-bit  }
  wave_Format_2S08       = $00000020;       { 22.05  kHz, Stereo, 8-bit  }
  wave_Format_2M16       = $00000040;       { 22.05  kHz, Mono,   16-bit }
  wave_Format_2S16       = $00000080;       { 22.05  kHz, Stereo, 16-bit }

  wave_Format_4M08       = $00000100;       { 44.1   kHz, Mono,   8-bit  }
  wave_Format_4S08       = $00000200;       { 44.1   kHz, Stereo, 8-bit  }
  wave_Format_4M16       = $00000400;       { 44.1   kHz, Mono,   16-bit }
  wave_Format_4S16       = $00000800;       { 44.1   kHz, Stereo, 16-bit }

  wave_Format_8M08       = $00001000;       { X   kHz, Mono,   8-bit  }
  wave_Format_8S08       = $00002000;       { X   kHz, Stereo, 8-bit  }
  wave_Format_8M16       = $00004000;       { X   kHz, Mono,   16-bit }
  wave_Format_8S16       = $00008000;       { X   kHz, Stereo, 16-bit }

{ types for wType field in MMTIME struct }
const
  time_MS         = $0001;  { time in milliseconds }
  time_Samples    = $0002;  { number of wave samples }
  time_Bytes      = $0004;  { current byte offset }
  time_SMPTE      = $0008;  { SMPTE time }
  time_MIDI       = $0010;  { MIDI time }


{ MMTIME data structure }
type
  PMMTime = ^TMMTime;
  TMMTime = record
    case wType: Word of        { indicates the contents of the variant record }
     time_MS : (ms: Longint);
     time_Samples : (sample: Longint);
     time_Bytes : (cb: Longint);
     time_SMPTE : (
        hour: Byte;
        min: Byte;
        sec: Byte;
        frame: Byte;
        fps: Byte;
        dummy: Byte);
      time_MIDI : (songptrpos: Longint);
  end;


{ Auxiliary audio device capabilities structure }
type
  PAuxCaps = ^TAuxCaps;
  TAuxCaps = record
    wMid: Word;                  { manufacturer ID }
    wPid: Word;                  { product ID }
    vDriverVersion: word;        { version of the driver }
    szPname: array[0..MaxPNameLen-1] of Char;  { product name (NULL terminated string) }
    wTechnology: Word;           { type of device }
    dwSupport: Longint;             { functionality supported by driver }
  end;
{ flags for wTechnology field in AUXCAPS structure }
const
  auxcaps_CDAudio    = 1;       { audio from internal CD-ROM drive }
  auxcaps_AuxIn      = 2;       { audio from auxiliary input jacks }

{ flags for dwSupport field in AUXCAPS structure }
const
  auxcaps_Volume     = $0001;  { supports volume control }
  auxcaps_LRVolume   = $0002;  { separate left-right volume control }



{ wave data block header }
type
  PWaveHdr = ^TWaveHdr;
  TWaveHdr = record
    lpData: longint;                {lpWaveData   pointer to locked data buffer }
    dwBufferLength: Longint;      {length of data buffer }
    dwBytesRecorded: Longint;     {used for input only }
    dwUser: Longint;              {dwWaveUser   for client's use }
    dwFlags: Longint;             {dwWaveFlags  assorted flags (see defines) }
    dwLoops: Longint;             {dwWaveLoops  loop control counter }
    lpNext: Longint{PWaveHdr};             {lpWaveNext   reserved for driver }
    reserved: Longint;            {Wavereserved reserved for driver }
    {lpnext remebers the next wavehdr}
    {reserved remembers the dwuser}
  end;

{min length is one twavehdr check total size and lpNext}


{ flags for dwFlags field of WAVEHDR }
const
  whdr_Done       = $00000001;  { done bit }
  whdr_Prepared   = $00000002;  { set if this header has been prepared }
  whdr_BeginLoop  = $00000004;  { loop start block }
  whdr_EndLoop    = $00000008;  { loop end block }
  whdr_InQueue    = $00000010;  { reserved for driver }


{ waveform output }
const
  mm_WOM_Open         = $3BB;
  mm_WOM_Close        = $3BC;
  mm_WOM_Done         = $3BD;

{ wave callback messages }
const
  wom_Open        = mm_WOM_Open;
  wom_Close       = mm_WOM_Close;
  wom_Done        = mm_WOM_Done;



const WAVERR_BASE =32;
const WAVERR_BADFORMAT       =(WAVERR_BASE + 0);    { unsupported wave format}
const  WAVERR_STILLPLAYING   =(WAVERR_BASE + 1);    { still something playing}
const  WAVERR_UNPREPARED     =(WAVERR_BASE + 2);    { header not prepared    }
const  WAVERR_SYNC           =(WAVERR_BASE + 3);    { device is synchronous  }
const  WAVERR_LASTERROR      =(WAVERR_BASE + 3);    { last error in range    }

const  MMSYSERR_BASE         =0;
const  MMSYSERR_NOERROR      =0;                     {no error }
const  MMSYSERR_ERROR        =(MMSYSERR_BASE + 1);   {unspecified error}
const  MMSYSERR_BADDEVICEID  =(MMSYSERR_BASE + 2);   {device ID out of range}
const  MMSYSERR_NOTENABLED   =(MMSYSERR_BASE + 3);   {driver failed enable}
const  MMSYSERR_ALLOCATED    =(MMSYSERR_BASE + 4);   {device already allocated}
const  MMSYSERR_INVALHANDLE  =(MMSYSERR_BASE + 5);   {device handle is invalid}
const  MMSYSERR_NODRIVER     =(MMSYSERR_BASE + 6);   {no device driver present}
const  MMSYSERR_NOMEM        =(MMSYSERR_BASE + 7);   {memory allocation error}
const  MMSYSERR_NOTSUPPORTED =(MMSYSERR_BASE + 8);   {function isn't supported}
const  MMSYSERR_BADERRNUM    =(MMSYSERR_BASE + 9);  {error value out of range}
const  MMSYSERR_INVALFLAG    =(MMSYSERR_BASE + 10);  {invalid flag passed}
const  MMSYSERR_INVALPARAM   =(MMSYSERR_BASE + 11);  {invalid parameter passed}
const  MMSYSERR_LASTERROR    =(MMSYSERR_BASE + 11);  {last error in range}


{ general waveform format structure (information common to all formats) }
type
  PWaveFormat = ^TWaveFormat;
  TWaveFormat = record
    wFormatTag: Word;         { format type }
    nChannels: Word;          { number of channels (i.e. mono, stereo, etc.) }
    nSamplesPerSec: Longint;  { sample rate }
    nAvgBytesPerSec: Longint; { for buffer estimation }
    nBlockAlign: Word;      { block size of data }
  end;

{ flags for wFormatTag field of WAVEFORMAT }
const
  wave_Format_PCM     = 1;

{ specific waveform format structure for PCM data }
type
  PPCMWaveFormat = ^TPCMWaveFormat;
  TPCMWaveFormat = record
      wf: TWaveFormat;
      wBitsPerSample: Word;
   end;


{end mmsystem}




{      Helper functions for drivers        }
const
DCB_NOSWITCH    =   $0008; {don't switch stacks for callback}
DCB_TYPEMASK    =   $0007; {callback type mask}
DCB_NULL        =   $0000; {unknown callback type}

{ flags for wFlags parameter of DriverCallback()}
DCB_WINDOW     =    $0001; {dwCallback is a HWND}
DCB_TASK       =    $0002; {dwCallback is a HTASK}
DCB_FUNCTION   =    $0003; {dwCallback is a FARPROC}



const MAXWAVEDRIVERS =10;{maximum number of wave device drivers loaded}



type  WAVEOPENDESC=record
    hWave:word;             { handle "hwave"}
    LPWAVEFORMAT:pWAVEFORMAT;  { format of wave data }
    Callback:longint;      { callback }
    Instance:longint;      { app's private instance information }
end;
type pWAVEOPENDESC =^WAVEOPENDESC;


const DRVM_USER             =$4000;

{
 * Message sent by mmsystem to wodMessage(), widMessage(), modMessage(),
 * and midMessage() when it initializes the wave and midi drivers
 }

const  DRVM_INIT  =100;
const  WODM_INIT  =DRVM_INIT;
const  WIDM_INIT  =DRVM_INIT;
const  MODM_INIT  =DRVM_INIT;
const  MIDM_INIT  =DRVM_INIT;
const  AUXM_INIT  =DRVM_INIT;

{ messages sent to wodMessage() entry-point function }
const  WODM_GETNUMDEVS     =3;{Must give}
const  WODM_GETDEVCAPS     =4;{Must give}
const  WODM_OPEN  	   =5;{must open}
const  WODM_CLOSE 	   =6;{must close}

{don't have to prepare anything}
const  WODM_PREPARE        =7;
const  WODM_UNPREPARE      =8;

const  WODM_WRITE 	   =9;{must write}
const  WODM_PAUSE  	   =10;{a}
const  WODM_RESTART        =11;{b}
const  WODM_RESET 	   =12;{c}
const  WODM_GETPOS	   =13;{d}
{const  WODM_GETPITCH       =14;
const  WODM_SETPITCH       =15;}
const  WODM_GETVOLUME      =16;
const  WODM_SETVOLUME      =17;
{const  WODM_GETPLAYBACKRATE=18;
const  WODM_SETPLAYBACKRATE=19;}
const  WODM_BREAKLOOP      =20;

{ messages sent to widMessage() entry-point function }
{
const  WIDM_GETNUMDEVS  =50;
const  WIDM_GETDEVCAPS  =51;
const  WIDM_OPEN        =52;
const  WIDM_CLOSE       =53;
const  WIDM_PREPARE     =54;
const  WIDM_UNPREPARE   =55;
const  WIDM_ADDBUFFER   =56;
const  WIDM_START       =57;
const  WIDM_STOP        =58;
const  WIDM_RESET       =59;
const  WIDM_GETPOS      =60;
                 }

{maximum number of auxiliary device drivers loaded}
const MAXAUXDRIVERS=10;
{messages sent to auxMessage() entry-point function}
const AUXDM_GETNUMDEVS=3;
const AUXDM_GETDEVCAPS=4;
const AUXDM_GETVOLUME =5;
const AUXDM_SETVOLUME =6;

{ FIXED PRELOAD SINGLE PRELOAD}

{tell mmsystem goonball function what to do}
type TMmsystem_DriverCallback=function (dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1:longint;wParam2:longint):boolean;




{export wodMessage      @2}
{you could import it}
type sounddevmsgproc =
     function (wDeviceID,wMessage:word;Instance,lparam1,lparam2:longint):longint;


{DriverProc      @1}
type aDriverProcproc =
     function (DriverIdentifier: Longint; DriverId: THandle;Msg: Word; lParam1, lParam2: Longint): Longint;

var wodEnabled:boolean;


















{data only the hardware can use}
const PCIcardVendor=$8086;{ensoniq}

{AudioPCI cards}
const PCIcardDeviceID0=$2415;{intel ICH AC'97}
const PCIcardDeviceID1=$2425;{intel ICH 0 AC'97}
const PCIcardDeviceID2=$2445;{intel ICH 2 AC'97}
const PCIcardDeviceID3=$2485;{intel ICH 3 AC'97}
const PCIcardDeviceID4=$24C5;{intel ICH 4 AC'97}
const PCIcardDeviceID5=$24D5;{intel ICH 5 AC'97}
const PCIcardDeviceID6=$266E;{intel ICH 6 AC'97}
const PCIcardDeviceID7=$27DE;{intel ICH 7 AC'97}
{HP CT5801 0043,  Revision ID=$09 ,"chip says creative es1373"}
{Audio PCI 5000,  Revision ID=$02 ,"chip says es1371"}


{CT4750 ,Revision ID-$02,"chip says creative ct5880"}

{PCI card data to acquire}
var pciBUS:byte; {The PCI BUS}
var pciFunc:byte;{The PCI BUS index}
var CardDetected:boolean;

var ens1371pork:word;{the ens1371's port[X]}
var myPCIHI:word;
var myPCILO:word;
var myPCImem:longint;{exact XMS memory location}
var mydrvoffset:longint;

const defaultPCIHI=$06D0;
const defaultPCILO=$0000;
const defaultPCImem=$06D00000;{exact XMS memory location}



{ENS1371 Card info}
const MemoryPageSwap=$c;
var drivername:string;

const Stereo_Bit=Bit0;
const Sixteen_Bit=Bit1;

const Sample_rate_converter=$10;
{you have to set ALL of these before you turn on the converter!}


SR_DAC1_Trunc_and_N=$70;  { DAC1 trunc and N register}
SR_DAC1_VFI_ACI=$71;  { DAC1 VFI(15:10) ACI(7:0)}
SR_DAC1_ACC=$72; { DAC1 Accumulator}
SR_DAC1_VFreq=$73; { DAC1 VFreq}
SR_DAC2_Trunc_and_N=$74;  { DAC2 trunc and N register}
SR_DAC2_VFI_ACI=$75;  { DAC2 VFI(15:10) ACI(7:0)}
SR_DAC2_ACC=$76; { DAC2 Accumulator}
SR_DAC2_VFreq=$77;  { DAC2 VFreq}
SR_ADC_Trunc_and_N=$78;  { ADC trunc and N register}
SR_ADC_VFI_ACI=$79;  { ADC VFI(15:10) ACI(7:0)}
SR_ADC_ACC=$7A; { ADC Accumulator}
SR_ADC_VFreq=$7B;  { ADC VFreq}

SR_DAC1_LVOL=$7C;{ DAC1 playback vol left}
SR_DAC1_RVOL=$7D;{ DAC1 playback vol right}
SR_DAC2_LVOL=$7E;{ DAC2 playback vol left}
SR_DAC2_RVOL=$7F;{ DAC2 playback vol right}




const AC97CODEC=$14;
AC97_RESET=00;{reset codec}
AC97_MASTER_VOLUME=$02;{Master volume}
AC97_LINEINPUT_VOLUME=$10;{PCM output volume}
AC97_CD_VOLUME=$12;{PCM output volume}
AC97_PCM_VOLUME=$18;{PCM output volume}


const SERIAL=$20;

{Windows selector for Memory location above 4mb}
type tlp=^ptla;
ptla=record
test:array[0..$FFF0] of byte;
end;

Type
wstr = ^wIstr;
wIstr = Record
test:array[0..$FFF0 div 2]of word;     {//words of data}
end;


Type BDBdescriptor=record
address:pointer;
settings:longint;
end;
Type
BDstr = ^bdIstr;
bdIstr = Record
Best:array[0..33] of BDBdescriptor;
end;
var Mlinear:pointer;
var Mphysical:pointer;
var Mpc:BDSTR;
var Mlength:pointer;
var Mselindex:byte;
var Msellimit:longint;

{ac97}
const samps=192;{samples}
const bofs=samps*2;{4 places}
const lofs=bofs*2;{2 buffers}
var physical1:pointer;
var physical2:pointer;
var physical3:pointer;
var physical4:pointer;
{}


var lop:longint;

{}

var sync:boolean;
var myvol:longint;
var myinc:longint;
var myblockalign:word;
var mychannels,mybits,mySamplesPerSec:longint;
var myWD:waveopendesc;
var mywaveformat:tWAVEFORMAT;
var lpstore:array[1..3] of longint;
{var mywavehdr:twavehdr;}
var opened:longint;
var toto:longint;
var written:tintegerlist;
var mypos:longint;
var mymaxpos:longint;
var myrealpos:longint;
var mypaused:word;
var wiz:longint;
{var myuser:longint;}
var myloops:longint;
var mystop:byte;

var zout:longint;

var
 Form1: TForm1;

{ function Disablesamplerateconverter:boolean;export;
 function Enablesamplerateconverter:boolean;export;}
{ function getsamplerateconvertervalue(index:byte):word;export;
 function setsamplerateconvertervalue(index:byte;value:word):boolean;export;
{ function codecbusy:boolean;
 function CODECready:boolean;
 function AC97CODECWrite(AC97IOport:word;AC97CODECreg:longint;setvalue:word):word;export;
 function Set1371MemoryPage(page:byte):boolean; export;
 function ac97CODEC_Setvalue(code:byte;value:word):boolean;export;}
{ function son:byte; export;
 function soff:byte;export;
 function sixteenbit:byte; export;
 function eightbit:byte; export;
 procedure interruptdata(val:boolean); export;}
{ procedure DAC1looping(val:boolean); export;
 procedure DAC1on(x:boolean);export;
 procedure DAC1scro(x:boolean);export;}
function findunusedcard(DEVID:word;si:word):byte;
 function dumbdelay:word;export;
 function deaddelay:word;export;
 function DetectICH:boolean;export;

implementation

{$R *.DFM}





function dumbdelay:word;
var x,y:longint;
begin
for x:=0 to $FFF0 do begin
application.processmessages;
y:=x;
end;
result:=0;
end;

function deaddelay:word;
var x,y:word;
begin
for x:=0 to $FF0 do begin
y:=x;
end;
result:=0;
end;



function Disablesamplerateconverter:boolean;
var temp:longint;
begin
temp:=inport32(ens1371pork+Sample_rate_converter);
temp:=temp or (Bit19+Bit20+Bit21+Bit22);{Disable all sources}
outport32(ens1371pork+Sample_rate_converter,temp);
end;

function Enablesamplerateconverter:boolean;
var temp:longint;
begin
{enable all sources and disable write bit}
temp:=inport32(ens1371pork+Sample_rate_converter);
temp:=inport32(ens1371pork+Sample_rate_converter) and not(Bit24+Bit22+Bit20+Bit21+Bit19);
outport32(ens1371pork+Sample_rate_converter,temp);
end;

function getsamplerateconvertervalue(index:byte):word;
var temp:longint;
var x,y:byte;
begin
result:=0;

{check busy bit}
temp:=inport32(ens1371pork+Sample_rate_converter);
y:=0;
while (y<$20)and((temp and Bit23)=Bit23) do begin
y:=y+1;
temp:=inport32(ens1371pork+Sample_rate_converter);
end;
if(y=$20)then begin showmessage('sample rate converter was busy '+inttostr(y)+' times!');end;

{temp:=temp and not $FFFF; clear data bits}
{temp:=temp and not $FE00FFFF; clear source bits}
temp:=temp and not $FE00FFFF;{clear source and data bits}
temp:=(temp or Bit19 or Bit20 or Bit21 or Bit22);{Disable all sources}
temp:=temp and not BIT24;{clear write bit}
temp:=temp or (longint((index {and $7F})) shl 25);{set register to read}
{write the data address and read data request}
outport32(ens1371pork+Sample_rate_converter,temp);

{make sure it is still ready to read}
temp:=inport32(ens1371pork+Sample_rate_converter);
if((temp and Bit23)=Bit23)then begin{BIt23 is busy bit}
{dumbdelay;}
deaddelay;{add back if not working}
temp:=inport32(ens1371pork+Sample_rate_converter);
end;

{return the data}
{temp:=temp and $FFFF;}
result:=word(temp);


end;





function setsamplerateconvertervalue(index:byte;value:word):boolean;
var temp:longint;
var x,y:byte;
begin
result:=false;

{check busy bit}
temp:=inport32(ens1371pork+Sample_rate_converter);
y:=0;
while (y<$20)and((temp and Bit23)=Bit23) do begin
y:=y+1;
temp:=inport32(ens1371pork+Sample_rate_converter);
end;
if(y=$20)then begin showmessage('sample rate converter was busy '+inttostr(y)+' times!');end;

{temp:=temp and not $FFFF; clear data bits}
{temp:=temp and not $FE00FFFF; clear source bits}
temp:=temp and not $FE00FFFF;{clear source and data bits}
temp:=(temp or Bit19 or Bit20 or Bit21 or Bit22);{Disable all sources}
temp:=temp or BIT24;{set write bit}
temp:=temp or (longint((index {and $7F})) shl 25);{set register to write}
temp:=temp or value;{value to write}
{write the data}
outport32(ens1371pork+Sample_rate_converter,temp);

{clear write bit}
temp:=temp and not BIT24;{clear write bit}
outport32(ens1371pork+Sample_rate_converter,temp);

{check status}

temp:=inport32(ens1371pork+Sample_rate_converter) and $FFFF;
if not(temp=value)then begin
{showmessage('Sample rate converter busy!');}
end;
end;


function codecbusy:boolean;
var x:longint;
begin
result:=false;
x:=inport32(ens1371pork+$14);
if((x and (Bit30))=Bit30)then begin
{WIP Work in progress}
{showmessage('working hard!');}
result:=true;
end;
end;

function CODECready:boolean;
var x:longint;
begin
result:=false;
x:=inport32(ens1371pork+$14);
if ((x and (Bit31))=Bit31)then begin
{RDY Ready}
result:=true;
end;
end;


function AC97CODECWrite(AC97IOport:word;AC97CODECreg:longint;setvalue:word):word;
var w,x,y:longint;
begin
for y:=0 to 10 do begin
if(codecbusy)then begin dumbdelay;end;{hello ?}
end;
if(codecbusy)then begin showmessage('error!');end;

x:=setvalue+(AC97CODECreg shl 16);{write register}
outport32(AC97IOport,(x));{write ac97 register}

end;

function ac97CODEC_Setvalue(code:byte;value:word):boolean;
begin
AC97CODECWrite(ens1371pork+AC97CODEC,code,value);
end;




{set ens137X memory page}
function Set1371MemoryPage(page:byte):boolean; begin
port[ens1371pork+MemoryPageSwap]:=(page and $F);
end;



function soff:byte;
var temp:word;
begin
{turn stereo off}
portw[ens1371pork+$20]:=portw[ens1371pork+$20] and  not Stereo_Bit;
end;

function son:byte; begin
{turn stereo on}
portw[ens1371pork+$20]:=portw[ens1371pork+$20] or Stereo_Bit;
end;

function eightbit:byte; begin
{temp:=not Bit0;}
portw[ens1371pork+$20]:=portw[ens1371pork+$20] and not Sixteen_Bit;
end;

function sixteenbit:byte; begin
portw[ens1371pork+$20]:=portw[ens1371pork+$20] or Sixteen_Bit;
end;


{set dac1 loop/stop}
procedure DAC1looping(val:boolean);
var temp:longint;
begin
if(val=true)then begin
temp:=portw[ens1371pork+$20] and not Bit13;
portw[ens1371pork+$20]:=temp;
end else begin
temp:=portw[ens1371pork+$20] or Bit13;;
portw[ens1371pork+$20]:=temp;
end;
end;

{turn interrupt data on}
procedure interruptdata(val:boolean); begin
if(val=true)then begin
portw[ens1371pork+$20]:=portw[ens1371pork+$20] or Bit8;
end else begin
portw[ens1371pork+$20]:=portw[ens1371pork+$20] and not Bit8;
end;
end;

procedure DAC1on(x:boolean);begin
if(x=true)then begin
port[ens1371pork]:=port[ens1371pork] or Bit6;
end else begin
port[ens1371pork]:=port[ens1371pork] and not Bit6;
end;
end;

procedure DAC1scro(x:boolean);begin
portw[ens1371pork+$20]:=portw[ens1371pork+$20] xor Bit7;
portw[ens1371pork+$20]:=portw[ens1371pork+$20] xor Bit7;
end;

function findunusedcard(DEVID:word;si:word):byte;
var temp:Word;
var b:byte;
begin
result:=0;temp:=0;
if(detectPCIdevice(DEVID,PCIcardVendor,PCIbus,PCIfunc,si))then begin
result:=1;
{showmessage('ICH FOUND!');}
{if ICH4 init}
temp:=ICH4_CFG_REG;{Command Register=$41}
b:=1;
{writePCIRegisterbyte(temp,pciBUS,pciFunc,b);}

temp:=4;{Command Register=4}
writePCIRegisterWord(temp,pciBUS,pciFunc,$105);
end else begin
end;
end;

function findunused5880card(si:word):byte;
var temp:word;
begin
result:=0;temp:=0;
if(detectPCIdevice(PCIcardDeviceID2,PCIcardVendor,PCIbus,PCIfunc,si))then begin
readPCIRegisterWord($3C,PCIbus,PCIFunc,temp);
if not(byte(temp)=0)then begin result:=2;writePCIRegisterWord($3C,PCIbus,PCIFunc,0);end;
end else begin

end;
end;

{Find,Enable and get I/O port}
function DetectICH:boolean;
var x:longint;var temp:word;
var search:word;
var ret:byte;
var str:string;
var pl:byte;
begin
CardDetected:=false;
search:=0;
pl:=0;
ret:=1;{look for unused card}
mydrvoffset:=(pl*6);{8?}
mydrvoffset:=0;
if (ret=1)then begin
result:=true;
drivername:='ICH Audio (2015)';
CardDetected:=true;
end else begin
{ret=0}
{showmessage('ens1371 not detected!');}
drivername:='not detected!';
result:=false;
end;
end;



procedure TForm1.BitBtn1Click(Sender: TObject);
begin
{form1.close;}
end;



procedure TForm1.BitBtn2Click(Sender: TObject);
var si:tinifile;
var x:longint;
begin
x:=0;
x:=strtoint(edit1.text);
if(x>$1F0000)then begin
si:=tinifile.create('ICHcfg.ini');
si.writestring('BUSMASTER','defaultPCIHi','$'+inttohex(hiword(x),4));
si.writestring('BUSMASTER','defaultPCILo','$0000');
si.writestring('BUSMASTER','defaultPCImem','$'+inttohex(x,8));
si.free;
end;




end;

procedure TForm1.FormCreate(Sender: TObject);
var si:tinifile;
begin
si:=tinifile.create('ICHcfg.ini');
edit1.text:='$'+inttohex(strtoint(si.readstring('BUSMASTER','defaultPCImem','$7F00000')),8);
si.free;

end;

end.
