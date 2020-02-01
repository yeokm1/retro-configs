 unit Wopen;

                    
interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  {pci,}ich,wwrite,Forms, Dialogs, StdCtrls,mmddk,unit2;


function myDAC1Open(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
function myDAC1Close(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
implementation


    function Mmsystem_DriverCallback(dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1,lparam2:longint):boolean; external 'mmsystem' name 'DriverCallback';


const mono=1;{from mmsystem call}
const stereo=2;
function ok(index:byte;value:word):boolean; begin end;
function setsampto(bits:word;freq:longint;spk:word;nBlockAlign:word):byte;
var temp:longint;
begin
result:=0;{default no error}
if not(

{(freq=64000) or}
(freq=32000) or
(freq=16000) or
{(freq=8000) or
{(freq=96000) or}
(freq=48000) or
(freq=24000) or
(freq=12000) or
{(freq=88200) or}
(freq=44100) or
(freq=22050) or
(freq=11025)

)then begin
result:=result or 1;{fail}
end else begin
codecConfig(freq);{set samples to freq}
end;

if(
(freq=88200) or
(freq=44100) or
(freq=22050) or
(freq=11025))then begin
{codecConfig(44100);{set samples to 44.1khz}
end;
if(
(freq=96000)or
(freq=48000)or
(freq=24000) or
(freq=12000) )then begin
{codecConfig(48000);{set samples to 48khz  }
end;



if not((spk=1) or (spk=2)) then begin
{showmessage('howmany channel audio?');}
result:=result or 2;
end;
if not((bits=16){or(bits=8)})then begin
result:=result or 4;
end;

if(bits=16)then begin{16-bit}
{8000khz?}
if(freq=8000)and(spk=mono)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0a00);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$1500);
{soff;
{sixteenbit;}
end else
if(freq=8000)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0A00);{C}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$1500);
{{son;}
{sixteenbit;}
end else

if(freq=11025)and(spk=mono)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0C00);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5666);{11025?}
{soff;}
{sixteenbit;}
end else
if(freq=11025)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0C00);{5}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5666);{11025?}
{son;}
{sixteenbit;}
end else
if(freq=22050)and(spk=mono)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$1C00);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$2CCC);{22050?}
{soff;}
{sixteenbit;}
end else
if(freq=22050)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$1C00);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$2CCC);{11025?}
{son;}
{sixteenbit;}
end else
if(freq=32000)and(spk=mono)then begin{16bit}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$2900);
ok(SR_DAC1_ACC,$000);
ok(SR_DAC1_VFreq,$1500);{needs adjusted}
{soff;}
{sixteenbit;}
end else
if(freq=32000)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$2900);
ok(SR_DAC1_ACC,$8000);
ok(SR_DAC1_VFreq,$1500);{32000?}
{son;}
{sixteenbit;}
end else
if(freq=44100)and(spk=mono)then begin{16bit}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$3800);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5666);{22050?}
{soff;}
{sixteenbit;}
end else
if(freq=44100)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$3800);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5666);{11025?}
{son;}
{sixteenbit;}
end else
if(freq=48000)and(spk=mono)then begin{16bit mono}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$4002);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$0000);{22050?}
{soff;}
{sixteenbit;}
end else
if(freq=48000)and(spk=stereo)then begin{16bit stereo}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$4002);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$0000);{11025?}
{son;}
{sixteenbit;}
end else

begin
{showmessage('what in the 16-bits?');}
end;



end else
if(bits=8)then begin

{turn stereo off}
{temp:=not Bit1;
{portw[ens1371port+$20]:=portw[ens1371port+$20] and temp;
{this is 8bit so turn on the 8-bit bit}
{temp:=not Bit0;
{portw[ens1371port+$20]:=portw[ens1371port+$20] and temp;
}

{8000khz?}
if(freq=8000)and(spk=mono)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0A00);
{ok(SR_DAC1_ACC,$2DCC);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$1500);
{soff;}
{eightbit;}
end else
if(freq=8000)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0A00);
{ok(SR_DAC1_ACC,$11C6);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$1500);
{son;}
{eightbit;}
end else

{11025}
if(freq=11025)and(spk=mono)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0C0B);
{ok(SR_DAC1_ACC,$2DCC);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5666);
{soff;}
{eightbit;}
end else
if(freq=11025)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$0C0C);
{ok(SR_DAC1_ACC,$11C6);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5666);
{son;}
{eightbit;}

end else

{22050khz?}
if(freq=22050)and(spk=mono)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$1C06);
{ok(SR_DAC1_ACC,$1D08);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$2CCC);
{soff;}
{eightbit;}
end else
if(freq=22050)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$1C08);
{ok(SR_DAC1_ACC,$1088);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$2CCC);
{son;}
{eightbit;}
end else
if(freq=32000)and(spk=mono)then begin{8bit}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$2906);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$1500);{needs adjusted}
{soff;}
{eightbit;}
end else
if(freq=32000)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$2906);
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$1500);{needs adjusted}
{son;}
{eightbit;}
end else
if(freq=44100)and(spk=mono)then begin{8bit}
ok(SR_DAC1_Trunc_and_N,$0100);
{ok(SR_DAC1_VFI_ACI,$1C06);}
ok(SR_DAC1_VFI_ACI,$3806);
{ok(SR_DAC1_ACC,$1D08);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$5999);
{soff;}
{eightbit;}
end else
if(freq=44100)and(spk=stereo)then begin
ok(SR_DAC1_Trunc_and_N,$0100);
{ok(SR_DAC1_VFI_ACI,$1C08);}
ok(SR_DAC1_VFI_ACI,$3806);
ok(SR_DAC1_ACC,$0000);
{ok(SR_DAC1_ACC,$0000);}
ok(SR_DAC1_VFreq,$5999);
{son;}
{eightbit;}
end else
if(freq=48000)and(spk=mono)then begin{8bit mono}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$4002);
{ok(SR_DAC1_ACC,$1560);}
ok(SR_DAC1_ACC,$0000);
ok(SR_DAC1_VFreq,$0000);
{soff;}
{eightbit;}
end else
if(freq=48000)and(spk=stereo)then begin{8bit stereo}
ok(SR_DAC1_Trunc_and_N,$0100);
ok(SR_DAC1_VFI_ACI,$4002);
ok(SR_DAC1_ACC,$0000);
{ok(SR_DAC1_ACC,$1560);}
ok(SR_DAC1_VFreq,$0000);
{son;}
{eightbit;}

end else


 begin
{showmessage('what in the 8-bits?');}
end;



end  else begin
{showmessage('what the bits?');}
end;


end;







{open wave driver}
function myDAC1Open(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var lpFMT:pWAVEFORMAT;
var lpwod:pWAVEOPENDESC;
var lpwavehdr:pwavehdr;
var ptempClient:PWAVEALLOC;{pointer to client information structure }

begin
{showmessage('open!');}

result:=0;{default to ok}


if ((lParam2 and wave_AllowSync)=wave_AllowSync) then
    begin
{            showmessage('Open a synchronous noise!');}
sync:=true;
            {result:=result or WAVERR_SYNC;}
            result:=0;
    end else begin
sync:=false;
    end;


{result:=OtherWodMessage(wDeviceID,wMessage,Instance,lparam1,lparam2);}



lpwod := pWAVEOPENDESC(lParam1);
lpFmt := (lpwod^.LPWAVEFORMAT);


            if (not(lpFmt^.wFormatTag = WAVE_FORMAT_PCM) or
                not(
{                (lpFmt^.nSamplesPerSec = 8000) or
                (lpFmt^.nSamplesPerSec = 16000) or
                (lpFmt^.nSamplesPerSec = 32000) or
                (lpFmt^.nSamplesPerSec = 64000) or                      }

                (lpFmt^.nSamplesPerSec = 11025) or
                (lpFmt^.nSamplesPerSec = 22050) or
                (lpFmt^.nSamplesPerSec = 44100) or
{                ((lpFmt^.nSamplesPerSec = 88200) and (lpFmt^.nChannels=1))or}

                (lpFmt^.nSamplesPerSec = 12000) or
                (lpFmt^.nSamplesPerSec = 24000) or
                (lpFmt^.nSamplesPerSec = 48000)
{                ((lpFmt^.nSamplesPerSec = 96000) and (lpFmt^.nChannels=1))}
                 )or
                not(
                (PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample = 8)or
                (PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample = 16)
                )
                )
            then begin
                result:=result or WAVERR_BADFORMAT;
                {showmessage(inttostr(lpFmt^.wFormatTag)+'');
                showmessage(inttostr((PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample)));
                showmessage(inttostr(lpFmt^.nSamplesPerSec)+'? I dont support that format!');
                }
            end else begin

     {did they just want format information?}
            if (lParam2 and WAVE_FORMAT_QUERY)=WAVE_FORMAT_QUERY then
            begin
            result:=result or 0;{does not actually open the device}
            end else
            begin
     {they want to open a sound?}


if(opened>0)then begin
{showmessage('already open!');{this driver only supports one client}
result:=result or MMSYSERR_ALLOCATED;{already open!}
end else begin

{written.clear;{I guess we can forget about the old queue?}

if(not((lParam2 and WAVE_FORMAT_QUERY)=WAVE_FORMAT_QUERY))then begin
{if we are not just doing a query}




{lpstore[0]:=dwuser;}
lpstore[1]:=lParam1;
lpstore[2]:=lParam2;
move(lpwod^,myWD,14);
opened:=opened+1;
toto:=toto+1;


{we want to remember what the opening client said}
myuserinfo.LCallback:=lpwod^.Callback;
myuserinfo.LInstance:=lpwod^.Instance;
myuserinfo.hWave:=lpwod^.hWave;
myuserinfo.LFlags:=LParam2;
myuserinfo.LByteCount:=0;
myuserinfo.pcmwf:=PPCMWAVEFORMAT(lpFmt)^;

{give the client my driver dw }
plongint(DWUSER)^:=longint(@myuserinfo);

{DWUSER is actually a pointer to a longint variable}

{Pwavealloc(DWUSER)^.LbyteCount:=0;}

end;



{Disablesamplerateconverter;}
{stereo is 2 channel}
mychannels:=lpFmt^.nChannels;
{mybits:=lpFmt^.nAvgBytesPerSec;}
mybits:=PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample;
mySamplesPerSec:=PWaveFormat(lpFmt)^.nSamplesPerSec; 


myblockalign:=lpFmt^.nBlockAlign;
setsampto(
(PPCMWAVEFORMAT(lpFmt)^.wBitsPerSample),
(lpFmt^.nSamplesPerSec),
lpFmt^.nChannels,
lpFmt^.nBlockAlign
);
{Enable the -Sample Rate Converter-}
{Enablesamplerateconverter;}

wiz:=0;
myloops:=0;

{do send an open message if it was already open?}
{send client his OPEN callback message}


lpFmt := (mywd.LPWAVEFORMAT);
{callback}


{ptempclient:=pointer(dwuser);
waveCallback(ptempClient^, WOM_OPEN, 0);}

if (Mmsystem_DriverCallback(
     lpwod^.Callback,
     hiWORD(lparam2) or DCB_NOSWITCH,
     lpwod^.hWave,
     WOM_OPEN,
     lpwod^.Instance,
     0,
     0
))then begin

end else begin

end;{end callback}





end;{opened}




end;
end;{}



end;


{close wave driver}
function myDAC1Close(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var str:string;
var ptempClient:PWAVEALLOC;{pointer to client information structure }
begin

{if we are playing then we can not close!}
if(written.count=0)then begin
mystop:=0;
{We must set all chunks to _done and not _inqueue}
{When done we should send the callback a close message}
{written:=0;}
result:=0;
{is our user trying to close?}
{if(dwuser=lpstore[0])then begin
{was our user}
{end else begin
{was some other user trying to stop our user}
{end;}

{DAC1looping(false);}
wiz:=0;
myloops:=0;
mymaxpos:=0;
myrealpos:=0;


if(written.count>0)then begin
if not(IsBadReadPtr(pwavehdr(written.items[0]),sizeof(twavehdr)))then begin
if (written.count>0)or((pwavehdr(written.items[0])^.dwflags and whdr_InQueue)=whdr_InQueue)then begin
{result:=WAVERR_STILLPLAYING;}
end;
end;
end;



{send close callback to our user}
ptempclient:=pointer(dwuser);
waveCallback(ptempClient^, WOM_CLOSE, 0);



{str:='Close handle! '+inttostr(written.count);
writestr1(66,0,str);
 }

opened:=opened-1;


end else begin
{queue was still full}
{user should reset or wait till getpos=max before closing}
{after the que is empty you can close}
result:=WAVERR_STILLPLAYING;
end;
end;

end.
