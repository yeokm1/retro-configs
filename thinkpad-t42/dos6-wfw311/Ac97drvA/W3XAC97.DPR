library W3xac97;

uses
  SysUtils,
  tintlist,
  Forms,
  wintypes,
  winprocs,
  dialogs,
  pci,
  Mmddk in 'MMDDK.PAS' {Form1},
  Unit2 in 'UNIT2.PAS',
  Wodmessa in 'WODMESSA.PAS',
  Drvprc in 'DRVPRC.PAS',
  Wwrite in 'WWRITE.PAS',
  Auxmessa in 'AUXMESSA.PAS',
  Wopen in 'WOPEN.PAS',
  Wpause in 'WPAUSE.PAS',
  Wsetvol in 'WSETVOL.PAS',
  Wreset in 'WRESET.PAS',
  Khz in 'KHZ.PAS',
  ICH in 'ICH.PAS';

var closin:boolean;
var was:longint;
{$R *.RES}
{$D wave:Intel Sound 2016 }

function Mmsystem_DriverCallback(dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1,lparam2:longint):boolean; external 'mmsystem' name 'DriverCallback';


               {
function OtherDriverProc(DriverIdentifier: Longint; DriverId: THandle;
Msg: Word; lParam1, lParam2: Longint): Longint;  external 'speaker' name 'DriverProc';
              }

function DriverProc(DriverIdentifier: Longint; DriverId: THandle;
Msg: Word; lParam1, lParam2: Longint): Longint; export;
begin
result:=NewDriverProc(DriverIdentifier,DriverId,Msg, lParam1, lParam2);
end;



{
function OtherWodMessage(wDeviceID:word;wMessage:word;Instance:longint;lparam1,lparam2:longint):longint;
external 'speakr' name 'WodMessage';
 }



function deaddelay2(vo:longint):word;
var x,y:longint;
var str:string;
begin
for x:=0 to vo do begin
{str:='Usr'+inttohex(x,4);
writestr1(1,1,str);}
y:=x;
end;
result:=0;
end;

function wotostr(x:longint):string; begin
if(x=5)then result:='OPEN' else
if(x=6)then result:='CLOSE ' else
if(x=7)then result:='PREPARE' else
if(x=8)then result:='UNPREPARE' else
if(x=9)then result:='WRITE' else
if(x=10)then result:='PAUSE' else
if(x=11)then result:='RESTART' else
if(x=12)then result:='UNPAUSE' else
if(x=13)then result:='GETPOS' else
if(x=16)then result:='GETVOLUME' else
if(x=17)then result:='SETVOLUME' else
if(x=20)then result:='BREAKLOOP' else
result:=inttohex(x,8);
end;

function WodMessage(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
var str:string;
begin
     {
if(wMessage=WODM_WRITE)then begin
showmessage('write');
end;
 }
{if (wmessage=wodm_RESET)then showmessage('was a reset!');}
     {
if not(was=wMessage)then begin
was:=wMessage;
deaddelay2($F0);

str:='Usr'+inttohex(dwuser,8);
writestr1(30,25,str);
str:='Msg$'+wotostr(wmessage);
writestr1(30,26,str);
str:='lp1$'+inttohex(lparam1,8);
writestr1(30,27,str);
str:='lp2$'+inttohex(lparam2,8);
writestr1(30,28,str);

end;
    }

{result:=OtherWodMessage(wDeviceID,wMessage,dwuser,lparam1,lparam2);}

if(CardDetected=true)then begin
result:=MyWodMessage(wDeviceID,wMessage,dwuser,lparam1,lparam2);
end else begin
result:=0;{Default Result}
end;


{if (wmessage=wodm_RESET)then showmessage('was a reset end!');}

{
if not(was=wMessage)then begin
was:=wMessage;


showmessage(
'Usr'+inttohex(dwuser,8)+
'Msg$'+inttohex(wmessage,8)+
'lp1$'+inttohex(lparam1,8)+
'lp2$'+inttohex(lparam2,8));
end;
    }
end;


exports DriverProc,WodMessage,AuxMessage,timercallback,finish;

begin
suicideevent:=false;
driverclosing:=false;
form1created:=false;
opened:=0;
mypaused:=0;
wiz:=0;
toto:=0;
runing:=true;
closin:=false;
myBlockAlign:=1;
{waveheader:=0;}
mymaxpos:=0;
mypos:=1;
myuserinfo.lbytecount:=0;
empty:=true;
inch:=0;
over:=0;
myinc:=0;
mybits:=8;
mychannels:=1;
mydrvoffset:=0;
carddetected:=false;
{clunk:=0;}
{lengths:=0;}
{played:=0;}
{isrunning:=false;}
{thing.host:=$F0;}
{thing.device:=$F0;}
fin:=1;
  Application.Title := 'ICH Sound Driver';
end.
