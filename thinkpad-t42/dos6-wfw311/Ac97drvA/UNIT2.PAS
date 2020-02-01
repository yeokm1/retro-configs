unit Unit2;

interface            
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  {pci,}Forms, Dialogs, StdCtrls,mmddk;
var xol:byte;

type
  Twavealloc = record
    LCallback: longint; {client's callback}
    LInstance: longint; {client's instance data}
    hWave: word;         {handle for stream}
    LFlags:longint;     {allocation flags}
    LByteCount: Longint; {bytecount}
    pcmwf: TPCMWAVEFORMAT; {formtat of wave data}
  end;
 Pwavealloc = ^TWavealloc;

const WHDR_REALLYDONE=$80000000; {My internal driver flag for wave headers }

var myuserinfo: Twavealloc;
var waveheade:longint;

var lpDeadHeads:PWAVEHDR;{ death row for wave headers }

function MapPhysicalToLinear(dwphysical,dwlength:pointer):pointer;export;
function CreateHugePointer (dwLinearBase,dwLength:POINTER):pointer;export;
function aWodMessage(wDeviceID:word;wMessage:word;Instance:longint;lparam1,lparam2:longint):longint;export;
procedure HugeInc(var HugePtr: Pointer; Amount: LongInt); export;
procedure HugeDec(var HugePtr: Pointer; Amount: LongInt); export;
procedure writestr(row,col:byte;st:string;color:byte);export;
procedure writestr1(row,col:byte;st:string); export;
procedure clearallbuffers(val:byte); export;
procedure waveCallback(pwave:Twavealloc;msg:word;lparam1:longint); export;
procedure wodBlockFinished(lpHdr:pwavehdr); export;
procedure wodPostAllHeaders;export;
procedure resetqueue; export;
procedure decqueue; export;
procedure snipequeue; export;
implementation
    procedure HugeShift; far; external 'KERNEL' index 113;
    procedure hmemcpy(p1, p2: Pointer; L: Longint); far; external 'KERNEL';
    function Mmsystem_DriverCallback(dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1,lparam2:longint):boolean; external 'mmsystem' name 'DriverCallback';



procedure waveCallback(pwave:Twavealloc;msg:word;lparam1:longint); begin
if not(pwave.lcallback=0)then begin
if (Mmsystem_DriverCallback(
     pwave.LCallback,{user's callback DWORD}
     hiWORD(pWave.LFlags) or DCB_NOSWITCH,  { flags }
     pwave.hWave,{handle to wave device}
     msg,{the message}
     pwave.LInstance,{users instance data}
     lparam1,{WOM_DONE pwavehdr}
     0{size of wavehdr?}
))then begin
{return does not matter MMSYSTEM handles everything}
end;
end;
end;


{grab lpnext before you call this}
procedure wodBlockFinished(lpHdr:pwavehdr); var str:string;begin
{  We are giving the block back to the application.  The header is no
   longer in our queue, so we reset the WHDR_INQUEUE bit.  Also, we
   clear our driver specific bit and cauterize the lpNext pointer.}
  lphdr^.dwflags:=lphdr^.dwflags or WHDR_DONE;
  lpHdr^.dwFlags:=lpHdr^.dwFlags and not(WHDR_INQUEUE or WHDR_REALLYDONE);
  lpHdr^.lpNext :=0;
  waveCallback(PWAVEALLOC(lpHdr^.reserved)^, WOM_DONE, longint(lpHdr));
{  str:='wodblockfinished:'+inttohex(longint(lpHdr),8);
  writestr1(10,10,str);}
end;



procedure clearallbuffers(val:byte); begin
fillchar(Mpc^,word($FFFF),char(val));{clear the sound data p0}
HugeInc(pointer(Mpc),$FFFF);{forward a page}
fillchar(Mpc^,word($FFFF),char(val));{clear the sound data p1}
HugeDec(pointer(Mpc),$FFFF);{back a page}
end;


procedure wodPostAllHeaders;
var lpNuke:PWAVEHDR; { wavehdr to free }
str:string;
begin
lpNuke:=pwavehdr(waveheade);
    {free the lpDeadHeads}
    while ( lpNuke = pwavehdr(waveheade) ) do begin
        waveheade := longint(pwavehdr(waveheade)^.lpNext);
        wodBlockFinished( lpNuke );

{        str:='post:'+inttohex(waveheade,8);
        writestr1(36,16,str);}
    end;

end;

function nextwavehd:longint; var str:string;begin
result:=0;
if not(waveheade=0) then begin
{str:='got next waveheader:'+inttohex(waveheade,8);
writestr1(26,16,str);}
result:=longint(pwavehdr(waveheade)^.lpnext);
end else begin
{str:='bad waveheader';
writestr1(26,16,str);}
end;
end;



function donewavehdr:byte;
var temp:longint;
begin
result:=0;
temp:=waveheade;

if not(waveheade=0)then begin
{set to next waveheader}
if not(nextwavehd=0)then begin
waveheade:=nextwavehd;
{get new max pos}
mymaxpos:=pwavehdr(waveheade)^.dwBufferLength;
myuserinfo.LByteCount:=0;{reset count to zero}
result:=1;
end else begin
{the end}
mymaxpos:=0;
myuserinfo.LByteCount:=0;{reset count to zero}
end;

end;

{kill old waveheader}
wodBlockFinished(pwavehdr(temp));
end;



{remove one and say wom_done}
procedure decqueue; begin
if(written.count>0)then begin
wodBlockFinished(pwavehdr(written.items[0]));{send WOM_DONE to pwavehdr in queue}
if(written.count=1)then  begin
written.clear;{zero based array with a one based counter}
end else
if(written.count>1)then begin
written.delete(0);{remove from queue}
end;

end;
end;

{just remove one}
procedure snipequeue; begin
if(written.count>0)then begin

if(written.count=1)then  begin
written.clear;{zero based array with a one based counter}
end else
if(written.count>1)then begin
written.delete(0);{remove from queue}
end;

end;
end;



procedure resetqueue;
var x:word;
begin
x:=0;
while written.count>1 do begin
wodBlockFinished(pwavehdr(written.items[0]));{send WOM_DONE to pwavehdr in queue}
written.delete(0);{remove from queue}
{application.processmessages;}
end;
if(written.count=1)then begin
wodBlockFinished(pwavehdr(written.items[0]));{send WOM_DONE to pwavehdr in queue}
written.clear;
end;
{queue now empty}
end;




procedure wodPostDoneHeaders;
var lpNuke:PWAVEHDR; { wavehdr to free }
var lpPrev:PWAVEHDR; { previous wavehdr (temporary)}
begin
    lpPrev := NIL;

lpNuke:=lpDeadHeads;
while not(lpNuke=nil) do begin
lpNuke := pwavehdr(lpNuke^.lpNext);

{we enter a dead loop that waits for the buffers to really be done}
    if (( lpNuke^.dwFlags and WHDR_REALLYDONE )=WHDR_REALLYDONE) then begin

    {clear lpnext, clear deadheads}
            if not( lpPrev=NIL ) then begin
                lpPrev^.lpNext := 0;
            end else begin
                lpDeadHeads := NIL;
            end;

            { from lpNuke down, we need to wodBlockFinished() }
               while ( lpPrev = lpNuke ) do begin
                lpNuke := pwavehdr(lpNuke^.lpNext);
                wodBlockFinished( lpPrev );
            end;

            break;

    end;
    lpNuke^.dwFlags:=(lpNuke^.dwFlags or WHDR_REALLYDONE);
    lpPrev := lpNuke;
    end;


end;



procedure SetCursorPosition(Column, Row : byte);
begin
asm
   mov ah,$02;
   mov bx,$00;    {* Display Page Number. 0 for Graphics Modes! *}
   mov dl,Column; {* Row/Column are Zero-Based! *}
   mov dh,Row;
   int $10;
   end;
end;


procedure WriteCharAtCursor(x : byte; Color : byte);
begin
asm
   mov ah,$0A;
   mov AL,x;
   mov BH,$00;    {* Display Page Number. * for Graphics Modes! *}
   mov BL,Color   {* For Graphics Modes only? *}
   mov CX,1;      {* Word for number of characters to write *}
   int $10;
   end;
end;


procedure writestr(row,col:byte;st:string;color:byte);
var x:byte;
begin
SetCursorPosition(row,col);
for x:=0 to ord(st[0])-1 do begin
SetCursorPosition(row+x,col);
WriteCharAtCursor(ord(st[x+1]),color);
end;

end;


procedure writestr1(row,col:byte;st:string); begin
xol:=xol+1;
if(xol>8) then xol:=1;
writestr(row,col,st,xol);
end;


procedure HugeInc(var HugePtr: Pointer; Amount: LongInt); assembler;
asm
  mov ax, Amount.Word[0]    { Store Amount in DX:AX. }
  mov dx, Amount.Word[2]
  les bx, HugePtr           { Get the reference to HugePtr. }
  add ax, es:[bx]           { Add the offset parts. }
  adc dx, 0                 { Propagate carry to the high word of Amount. }
  mov cx, Offset HugeShift
  shl dx, cl                { Shift high word of Amount for segment. }
  add es:[bx+2], dx         { Increment the segment of HugePtr. }
  mov es:[bx], ax
end;


{ Decrement a huge pointer. }
procedure HugeDec(var HugePtr: Pointer; Amount: LongInt); assembler;
asm
  les bx, HugePtr         { Store HugePtr ptr in es:[bx] }
  mov ax, es:[bx]
  sub ax, Amount.Word[0]  { Subtract the offset parts }
  mov dx, Amount.Word[2]
  adc dx, 0               { Propagate carry to the high word of Amount }
  mov cx, OFFSET HugeShift
  shl dx, cl              { Shift high word of Amount for segment }
  sub es:[bx+2], dx
  mov es:[bx], ax
end;





function DPMISetSelectorLimit(selector:word;dwlimit:longint):boolean;
begin
result:=true;
asm
         mov  ax, 0008h
         mov  bx, selector
         mov  cx, word ptr [dwLimit+2]
         mov  dx, word ptr [dwLimit]
         int  31h
         jnc  @success
         mov result,0
       @success:
end;
end;



function MapPhysicalToLinear(dwphysical,dwlength:pointer):pointer;
var dwlinear:longint;
var xa:word;
begin
{this should be able to map up to 4 gigabytes}
{reads memory from pci cards also}
if(hiword(longint(dwphysical))>0)then
begin

asm
    push    di
              push    si
              mov     bx, WORD PTR [dwPhysical+2] {; Load arguments.}
              mov     cx, WORD PTR [dwPhysical]
              mov     si, WORD PTR [dwLength+2]
              mov     di, WORD PTR [dwLength]
              mov     ax, 800h
              int     31h                         {; Issue DPMI call.}
              jnc     @fine_return
              xor     bx, bx                     { ; zero out return}
              mov     cx, bx                     { ; regs on error}
      @fine_return:
              mov     WORD PTR [dwLinear+2], bx  { ; Return value.}
              mov     WORD PTR [dwLinear], cx
              pop     si
              pop     di
end;
end else begin showmessage('small!');end;
result:=pointer(dwlinear);
end;




function CreateHugePointer (dwLinearBase,dwLength:POINTER):pointer;
   var
      tempSelector:word;
      codeSelector:word;
      dataSelector:word;
      dwLimit:longint;
     begin
      if(dwLength = ptr(0,0))then begin  result:=ptr(0,0);end;
      dwLimit := longint(dwLength) -1;
      asm
         mov ax, cs
         mov codeSelector, ax
      end;
      tempSelector := AllocSelector(codeSelector);
      if (tempSelector=0)then begin  result:=nil;end;
      if (PrestoChangoSelector (codeSelector, tempSelector)>1)then
         begin
         SetSelectorBase(tempSelector, longint(dwLinearBase));
         DPMISetSelectorLimit(tempSelector, dwLimit);
{         SetSelectorLimit(tempSelector, dwLimit);}
         dataSelector := AllocSelector(tempSelector);
         end else
         dataSelector := 0;
      DPMISetSelectorLimit(tempSelector, 0);
      FreeSelector(tempSelector);
      result:= pointer(MAKELONG(0, dataSelector));
   end;

procedure  wodGetDevCaps(lpCaps:pchar; wSize:word);
var wc:tWAVEOUTCAPS;
var x:word;
begin
    wc.wMid := MM_MICROSOFT;
    wc.wPid := MM_SNDBLST_WAVEOUT;
    wc.vDriverVersion := random($FFFF);
    wc.dwFormats := WAVE_FORMAT_1M08 or WAVE_FORMAT_2M08;
    wc.wChannels := 1;
    wc.dwSupport := 0;
{    LoadString(ghModule, IDS_SNDBLSTWAVEOUT, wc.szPname, MAXPNAMELEN);}

x:=sizeof(wc);
if(wSize>=x)then  move(wc,lpCaps, sizeof(wc));
end;

 {
function OtherWodMessage(wDeviceID:word;wMessage:word;Instance:longint;lparam1,lparam2:longint):longint;
external 'speaker' name 'WodMessage';
}


function badWodMessage(wDeviceID:word;wMessage:word;Instance:longint;lparam1,lparam2:longint):longint;
var lpFMT:pWAVEFORMAT;
var lpwod:pWAVEOPENDESC;
begin
{showmessage('This is a WodMessage!'+inttostr(wmessage)+'  '+inttohex(wmessage,8));
                        }



result:=MMSYSERR_NOTSUPPORTED;{Default Result}


{have we started yet?}
if not(wodEnabled)then begin
result:=MMSYSERR_NOTENABLED;

if(wMessage=WODM_INIT)then begin
{showmessage('WDOM_INIT!');}
wodEnabled:=true;
result:=0;
end else begin
showmessage('not enabled and not WODM_INIT');
end;

end;

{we only support one device!}
if not(wDeviceid=0)then begin
showmessage('Supports only one device!');
result:=MMSYSERR_BADDEVICEID;
showmessage('one at a time!');
end;


if(wMessage=WODM_GETNUMDEVS)then begin
result:=1;{one wave driver}
{showmessage('GETNUMDEVS');}
end else
if(wMessage=WODM_GETDEVCAPS)then begin
{get them!}
showmessage('getdevcaps');

    pWAVEOUTCAPS(lparam1)^.wMid := MM_MICROSOFT;
    pWAVEOUTCAPS(lparam1)^.wPid := MM_SNDBLST_WAVEOUT;
    pWAVEOUTCAPS(lparam1)^.vDriverVersion := random($FFFF);
    pWAVEOUTCAPS(lparam1)^.dwFormats := WAVE_FORMAT_1M08 or WAVE_FORMAT_2M08;
    pWAVEOUTCAPS(lparam1)^.wChannels := 1;
    pWAVEOUTCAPS(lparam1)^.dwSupport := 0;
    pWAVEOUTCAPS(lparam1)^.szPname[0]:='W';
    pWAVEOUTCAPS(lparam1)^.szPname[1]:='a';
    pWAVEOUTCAPS(lparam1)^.szPname[2]:='t';
    pWAVEOUTCAPS(lparam1)^.szPname[3]:='l';
    pWAVEOUTCAPS(lparam1)^.szPname[4]:='e';
    pWAVEOUTCAPS(lparam1)^.szPname[5]:='r';
    pWAVEOUTCAPS(lparam1)^.szPname[6]:=char(0);

{wodGetDevCaps(pchar(lparam1), word(lparam2));}
{wodGetDevCaps((LPBYTE)dwParam1, (WORD)dwParam2); }
result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
{usually}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end else
if(wMessage=WODM_OPEN)then begin
result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
result:=MMSYSERR_ALLOCATED;
result:=MMSYSERR_NOMEM;
{result:=MMSYSERROR_BADFORMAT;}
result:=MMSYSERR_NOERROR;{0peration is successful.}

{showmessage('open');}
{showmessage('open');}
{
 dwParam1 contains a pointer to a WAVEOPENDESC
 dwParam2 contains wave driver specific flags in the LOWORD
 and generic driver flags in the HIWORD
}
{
            /* make sure we can handle the format */
}

            lpwod := pWAVEOPENDESC(lParam1);
            lpFmt := (lpwod^.LPWAVEFORMAT);

            if (not(lpFmt^.wFormatTag = WAVE_FORMAT_PCM) or
                not((lpFmt^.nChannels = 1)or(lpFmt^.nChannels = 2)) or
                (lpFmt^.nSamplesPerSec < 8000) or
                (lpFmt^.nSamplesPerSec > 44100) or
                not(lpFmt^.nAvgBytesPerSec = lpFmt^.nSamplesPerSec) or
                (lpFmt^.nBlockAlign < 1) or
                not((PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample = 16)or(PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample = 8)))
            then begin
{                result:=WAVERR_BADFORMAT;}
     {           showmessage('I dont support that format!');}
            end else begin
                showmessage(inttostr(lpFmt^.nSamplesPerSec));
     {did they just want format information?}
            if (lParam2 and WAVE_FORMAT_QUERY)=WAVE_FORMAT_QUERY then result:=0;

            end;



           { /* attempt to 'acquire' the Wave output hardware */}
{            if ( wodAcquireHardware() ) then begin
                D1("Wave output hardware is not available!");
                result:=MMSYSERR_ALLOCATED;
            end;]

          {              /* allocate my per-client structure */
            pOutClient = (NPWAVEALLOC)LocalAlloc(LPTR, sizeof(WAVEALLOC));
            if (pOutClient == NULL) then begin
                wodReleaseHardware();
                result:=MMSYSERR_NOMEM;
            end;}
{           and fill it with info }
{
            pOutClient->dwCallback  = ((LPWAVEOPENDESC)dwParam1)->dwCallback;
            pOutClient->dwInstance  = ((LPWAVEOPENDESC)dwParam1)->dwInstance;
            pOutClient->hWave       = ((LPWAVEOPENDESC)dwParam1)->hWave;
            pOutClient->dwFlags     = dwParam2;
            pOutClient->dwByteCount = 0L;
            pOutClient->pcmwf       = *((LPPCMWAVEFORMAT)lpFmt);

            /* give the client my driver dw */
            *((LPDWORD)dwUser) = MAKELONG(pOutClient, 0);

            /* set the sample rate */
            dspSetSampleRate((WORD)lpFmt->nSamplesPerSec);

            /* sent client his OPEN callback message */
            waveCallback(pOutClient, WOM_OPEN, 0L);

            result:=0;

}


end else
if(wMessage=WODM_CLOSE)then begin
showmessage('close');
{clean up and close}

{wait, in case there's one last 2K block being played}
{ call client's callback }
{
            pOutClient = (NPWAVEALLOC)LOWORD(dwUser);
            waveCallback(pOutClient, WOM_CLOSE, 0L);

}
{ free the allocated memory }
{            LocalFree((LOCALHANDLE)pOutClient);}


{ now 'release' the Wave output hardware }
result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
result:=WAVERR_STILLPLAYING;
result:=MMSYSERR_NOERROR;{0peration is successful.}
end else
if(wMessage=WODM_WRITE)then begin
showmessage('write');
{test your data structures}
{/* check if it's been prepared */}
{/* if it is already in our Q, then we cannot do this */}
{/* store the pointer to my WAVEALLOC structure in the wavehdr */}
{/* add the buffer to our queue */}

result:=WAVERR_UNPREPARED;{The data block has not been prepared.}
result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end else
if(wMessage=WODM_PAUSE)then begin
{wodPause();}
showmessage('pause');
result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}

{usually}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end else
if(wMessage=WODM_RESTART)then begin
{            wodResume();}
showmessage('restart');
{usually NOERROR}
result:=0;
end else
if(wMessage=WODM_RESET)then begin
showmessage('reset');
{/* halt DMA immediately--will always set gfDMAbusy = FALSE */}

            {gfWaveOutPaused = false;
            bBreakLoop = false;
            }
{/* reset byte count */}


result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end else
if(wMessage=WODM_BREAKLOOP)then begin
{if you are playing}
{                bBreakLoop = 1;}
showmessage('breaktime');
result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end else
if(wMessage=WODM_GETPOS)then begin
showmessage('getpos');
{waveGetPos(dwUser, (LPMMTIME)dwParam1, (SIZE OF LPMMTIME)dwParam2);}
result:=0;
end else
{showmessage('uhh....');}
{NOTHING? well what are we doing then?}
end;



function aWodMessage(wDeviceID:word;wMessage:word;Instance:longint;lparam1,lparam2:longint):longint;
begin
result:=badWodMessage(wDeviceID,wMessage,Instance,lparam1,lparam2);
{result:=OtherWodMessage(wDeviceID,wMessage,Instance,lparam1,lparam2);}
end;


end.
