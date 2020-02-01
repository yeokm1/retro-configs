unit Wreset;

interface                   
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  wwrite,{pci,}Forms, Dialogs, StdCtrls,mmddk,unit2;

function myDAC1Reset(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
implementation

    function Mmsystem_DriverCallback(dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1,lparam2:longint):boolean; external 'mmsystem' name 'DriverCallback';


function myDAC1Reset(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var str:string;
var ptempClient:PWAVEALLOC;{pointer to client information structure }
begin
{!DAC1on(false);}
ptempclient:=pointer(dwuser);

{For each ptempclient^.lpnext block:
clear the whdr_inqueue,set whdr_done and send a wom_done message}
{reset everything! send a DONE}
{str:='RESET stop! and WOM_DONE';
writestr1(6,6,str);}

{send a done to all headers}
resetqueue;{we have cleared the written queue}
written.clear;
mypos:=$FFFFFFFF;

{should spit out a buch of WOM_DONE messages}
{wodPostAllHeaders;}


{DAC1looping(false);}

empty:=true;
myloops:=0;
mymaxpos:=0;
myrealpos:=0;

mystop:=0;
ptempclient^.LByteCount:=0;{byte count reset to zero}
wiz:=0;{sample count reset to zero}


if(1=2)then begin
{can this be done?}
if not(IsBadReadPtr(pwavehdr(lpstore[1]),sizeof(twavehdr)))then begin
pwavehdr(lpstore[3])^.dwflags:=pwavehdr(lpstore[3])^.dwflags and not whdr_Inqueue;{ clear que bit }
pwavehdr(lpstore[3])^.dwflags:=pwavehdr(lpstore[3])^.dwflags or whdr_Done;{ set done bit }
end;
{send close callback to our user}
{waveCallback(ptempClient^, WOM_DONE, lpstore[1]);}
{wodBlockFinished(pwavehdr(lpstore[3]));}


if(1=32)then begin
if(mywd.Callback>0)then begin{test user callback DWORD}
if (Mmsystem_DriverCallback(
     ptempclient^.lCallback,{user's callback DWORD}
     hiWORD(lpstore[2]) or DCB_NOSWITCH,
     ptempclient^.hWave,{handle to wave device}
     WOM_DONE,{the message}
     ptempclient^.LInstance,{users instance data}
     lpstore[1],{WOM_DONE pwavehdr}
     lpstore[2]{size}
))then begin

end;
end;
end;{1=32}
end;

{/* halt DMA immediately--will always set gfDMAbusy = FALSE */}

            {gfWaveOutPaused = false;
            bBreakLoop = false;
            }
{/* reset byte count */}

written.clear;
{!DAC1on(true);}


result:=MMSYSERR_NOTENABLED;{The driver failed to load or initialize.}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end;

end.
