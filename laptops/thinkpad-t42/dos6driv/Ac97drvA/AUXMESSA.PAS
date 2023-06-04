unit Auxmessa;

interface
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  {pci,}Forms, Dialogs, StdCtrls,mmddk,unit2;

function AuxMessage(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
implementation

function AuxMessage(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var temp:longint;
begin

     {
showmessage(
'AuxUsr'+inttohex(dwuser,8)+
'AuxMsg$'+inttohex(wmessage,8)+
'Auxlp1$'+inttohex(lparam1,8)+
'Auxlp2$'+inttohex(lparam2,8));
    }

if(wMessage=AUXM_INIT)then begin
result:=MMSYSERR_NOERROR;
end else
if(wMessage=AUXDM_GETNUMDEVS)then begin
result:=1;
{showmessage('Aux 1 dev!');}
result:=MMSYSERR_NOERROR;
end else
if(wMessage=AUXDM_GETDEVCAPS)then begin
{we now give information}
    PAuxCaps(lparam1)^.wMid:=MM_MICROSOFT;
    PAuxCaps(lparam1)^.wPid:=MM_SNDBLST_WAVEOUT;
    PAuxCaps(lparam1)^.vDriverVersion:=1234;
    PAuxCaps(lparam1)^.dwSupport := auxcaps_Volume or auxcaps_LRVolume;
    PAuxCaps(lparam1)^.szPname[0]:='W';
    PAuxCaps(lparam1)^.szPname[1]:='a';
    PAuxCaps(lparam1)^.szPname[2]:='t';
    PAuxCaps(lparam1)^.szPname[3]:='l';
    PAuxCaps(lparam1)^.szPname[4]:='e';
    PAuxCaps(lparam1)^.szPname[5]:='r';
    PAuxCaps(lparam1)^.szPname[6]:=char(0);
    PAuxCaps(lparam1)^.wTechnology:=auxcaps_AuxIn or auxcaps_CDAudio;
    PAuxCaps(lparam1)^.dwSupport:=auxcaps_Volume or auxcaps_LRVolume;
result:=MMSYSERR_NOERROR;
end else
if(wMessage=AUXDM_GETVOLUME)then begin
showmessage('Aux get vol');{The volume is wanted?}
if not(isbadreadptr(pLONGINT(lparam1),4))then begin

{get the volume}
{temp:=($FFFF-getsamplerateconvertervalue(SR_DAC1_RVOL)) shl 16;
temp:=temp+($FFFF-getsamplerateconvertervalue(SR_DAC1_LVOL));
pLONGINT(lparam1)^:=temp;{R:L}
end;
result:=MMSYSERR_NOERROR;
end else
if(wMessage=AUXDM_SETVOLUME)then begin
showmessage('Aux set vol');
{lword1 shoud be the new volume}

{Set the volume}
{setsamplerateconvertervalue(SR_DAC1_LVOL,$FFFF-loword(lparam1));
setsamplerateconvertervalue(SR_DAC1_RVOL,$FFFF-hiword(lparam1));
 }
result:=MMSYSERR_NOERROR;
end else begin
result:=mmsyserr_notsupported;
end;


end;



end.
