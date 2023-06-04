unit Wpause;

interface
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  wwrite,{pci,}Forms, Dialogs, StdCtrls,mmddk,unit2;

var tip:byte;

function myDAC1Pause(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
function myDAC1Restart(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
function myDAC1GetPosition(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
implementation

{    function Mmsystem_DriverCallback(dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1,lparam2:longint):boolean; external 'mmsystem' name 'DriverCallback';
 }

{pause playback}
function myDAC1Pause(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var str:string;
var ptempClient:PWAVEALLOC;{pointer to client information structure }
begin
{showmessage('pause');}
{!DAC1on(false);}
{runing:=false;}
{DAC1looping(false);}
str:='Paused me!';
{writestr1(10,10,str);
mypaused:=1;}

result:=MMSYSERR_NOERROR;{0peration is successful.}
end;

{continue playback}
function myDAC1Restart(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var str:string;
var ptempClient:PWAVEALLOC;{pointer to client information structure }
begin
{showmessage('unpause WODM_restart');}
mypaused:=0;
{DAC1looping(true);}

{!DAC1on(true);}

{str:='unpause me!';
writestr1(10,10,str);}
{usually NOERROR}



if(1=2)then begin
{why can this be done?}
if not(IsBadReadPtr(pwavehdr(lpstore[1]),sizeof(twavehdr)))then begin
pwavehdr(lpstore[1])^.dwflags:=pwavehdr(lpstore[1])^.dwflags or whdr_Done;{ set done bit }
end;
showmessage('done');
{send WOM_DONE callback to our user}
{send a DONE message to client}
ptempclient:=pointer(dwuser);
waveCallback(PWAVEALLOC(lParam1)^, WOM_DONE, lparam1);
end;

{runing:=true;}
result:=MMSYSERR_NOERROR;{0peration is successful.}
end;


function myDAC1GetPosition(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var str:string;
var temp:longint;
var ptempClient:PWAVEALLOC;{pointer to client information structure }
begin
ptempclient:=pointer(dwuser);
result:=MMSYSERR_NOTENABLED;{default return}

if(opened>0)then begin{was open}
result:=MMSYSERR_NOERROR;{logical time to getpos}

if(written.count>0)and(opened>0)then begin
temp:=0;
end else begin
temp:=mymaxpos-Pwavealloc(dwuser)^.LByteCount;
end;

{who knows where we are?}
if(pMMTIME(lparam1)^.wtype=time_Bytes)then begin
pMMTIME(lparam1)^.cb:=temp;
end else begin
pMMTIME(lparam1)^.wtype:=time_samples;
pMMTIME(lparam1)^.Sample:=temp;{adjust for sample time}
end;

result:=MMSYSERR_NOERROR;{ok!}

if(1=33)then begin
if(written.count>0)then begin{User has already written some bytes}
{was written and open}
result:=MMSYSERR_NOERROR;{ok!}

if(pMMTIME(lparam1)^.wtype=time_Bytes)then begin
{str:='time_bytes  ';writestr1(40,20,str);}
if(1=2)then begin wiz:=wiz+myrealpos+1;end;
{winplay and mod4win use time_bytes}
if(33=2)then begin
{Pwavealloc(dwuser)^.LByteCount:=mymaxpos-((portw[ens1371port+$26]));}
Pwavealloc(dwuser)^.LByteCount:=Pwavealloc(dwuser)^.LByteCount;
end;
{if(portw[ens1371port+$36])>mymaxpos-1 then myuserinfo.LByteCount:=0;}

{!if((portw[ens1371port+$26])=0)then begin tip:=1;end;}
if(1=33)then Pwavealloc(dwuser)^.LByteCount:=mymaxpos+1;

end else begin
{str:='time_samples';writestr1(40,20,str);}
if(1=2)then begin temp:=myblockalign;myinc:=mymaxpos;wiz:=wiz+(myinc)+1;end;

{soundrec and mplayer use time_samples}
{!wiz:=(mymaxpos)-((portw[ens1371port+$26]));}
wiz:=wiz div myblockalign;
{!if(portw[ens1371port+$26])=0 then wiz:=mymaxpos+2;}

{if(wiz>=mymaxpos)then begin tip:=1;end;}

{!if((portw[ens1371port+$26])=0)then begin tip:=1;end;}
wiz:=mymaxpos+1;

end;



{str:='zzzzzzzzzz';
writestr1(25,17,str);}
{str:='pos>$'+inttohex(pMMTIME(lparam1)^.Sample,8)+'';;
writestr1(25,17,str);}


{because I am a Driver I must say when to STOP!}

if(wiz>=mymaxpos)and(myloops>0)then begin

{str:='         ';
writestr1(14,4,str,0);}
{str:=inttostr(myloops)+'LL';
writestr1(34,4,str);}
{wiz:=0;}

if whdr_EndLoop =( (pwavehdr(lpstore[1])^.dwflags and whdr_EndLoop))then begin
showmessage('whdr_endloop');
{str:='WATLERS world!';;
writestr1(11,11,str);}
end;

myloops:=myloops-1;
end;

if(myloops=0)then begin
if(tip=1)then begin
tip:=0;
{showmessage('si?');}

{if we are done then }
mymaxpos:=0;
{!portw[ens1371port+$26]:=0;}
if(1=33)then Pwavealloc(dwuser)^.LByteCount:=0;

{can this be done?}
if not(IsBadReadPtr(pwavehdr(lpstore[1]),sizeof(twavehdr)))then begin
{pwavehdr(lpstore[1])^.dwflags:=pwavehdr(lpstore[1])^.dwflags or whdr_Done;{ set done bit }
{pwavehdr(lpstore[1])^.dwflags:=pwavehdr(lpstore[1])^.dwflags and not whdr_InQueue;{ clear queue bit }
end;

{send a DONE message to client}
{waveCallback(PWAVEALLOC(lParam1)^, WOM_DONE, 0);}

end else begin
{not at maxpos and not done looping}
{str:='not at maxpos '+inttohex(mymaxpos,8)+'rly is'+inttohex(Pwavealloc(dwuser)^.LByteCount,8);
writestr1(0,0,str);}
end;
end else begin
{str:='not done looping';
writestr1(20,0,str);}

end;

end {opened written}
else begin
result:=MMSYSERR_NOERROR;{0peration is successful.}
{nothing has been written yet}
{so I cannot say where you are!}
{str:='was not written to!';
writestr1(13,13,str);}
end;
end else begin
{showmessage('not opened!');}
{was not open}
{result:=mmsyserr_notenabled;}
{str:='was not open!!';
writestr1(20,10,str);}
end;
{pMMTIME(lparam1)^.cb:=mymaxpos+1;}
{result:=MMSYSERR_NOTSUPPORTED;}

end;
end;


end.
