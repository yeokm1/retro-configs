unit Wsetvol;

interface
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  {pci,}ich,ac97,unit2,Forms, Dialogs, StdCtrls,mmddk,inifiles;

function myDAC1GetVol(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
function myDAC1SetVol(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
implementation

function myDAC1GetVol(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var temp:longint;

begin
{showmessage('wod getvol');}
if not(isbadreadptr(pLONGINT(lparam1),4))then begin
{get the volume}
{temp:=ac97CODEC_Getvalue(AC97_MASTER_VOLUME);}
{pLONGINT(lparam1)^:=((byte(temp shr 8) * $800) shl 16)+(byte(temp) * $800);}
pLONGINT(lparam1)^:=myvol;
end;




result:=0;{ok}

end;
function myDAC1SetVol(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var str:string;
var si:tinifile;
begin
{showmessage('wod Setvol');}
{str:='set vol:'+inttohex(lparam1,8);
writestr1(6,6,str);
}
myvol:=lparam1;


si:=tinifile.create('ICHcfg.ini');
si.writestring('Volume','PCM','$'+inttohex(myvol,8));
si.free;


if(lparam1=0)then begin
{mute}
{ac97CODEC_Setvalue(AC97_MASTER_VOLUME,$FFFF);}
setac97(CODEC_PCM_OUT_REG,$FFFF);
end else begin
{vol change}
setac97(CODEC_PCM_OUT_REG,
{ac97CODEC_Setvalue(}(
(($1f-(hiword(lparam1) div $800)) and $1f) shl 8)+
(($1f-(loword(lparam1) div $800)) and $1f)
);

{showmessage(inttohex(loword(lparam1),4));
showmessage(inttohex(($1f-(loword(lparam1) div $800)) and $1f,4));}
end;


result:=0;{ok}

end;

end.
