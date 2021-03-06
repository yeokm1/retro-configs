unit Wwrite;
interface
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  mmsystem,khz,jeff,ich,ichdma,misc,tintlist,{pci,}Forms, Dialogs, StdCtrls,mmddk,unit2;

var driverclosing:boolean;
var suicideevent:boolean;

var iset:byte;
var lpfnOldISR:pointer;
var lpOldISR1,lpOldISR2:word;
const INT_DEV=$08;


var over:byte;
var empty:boolean;
var runing:boolean;
{var length:longint;}
{var played:longint;}
var bhalf:longint;
{var tick,kcit,var got:byte;}
var loopstartchunk:longint;
var loopendchunk:longint;
var currentwavehdr:longint;
var inch:longint;
var myinc:longint;
function wavegoodbye:byte; export;
function myDAC1Write(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;export;
var htime:longint;
procedure timercallback(hwindow:hwnd;msg:word;idtimer:word;dwtime:longint); export;
procedure Starttime(hw:pointer);export;
procedure Stoptime;export;
implementation
    procedure hmemcpy(p1, p2: Pointer; L: Longint); far; external 'KERNEL';

    function Mmsystem_DriverCallback(dwCallback:longint;uflags:word;
     hdevice:word;uMessage:word;dwUser,lparam1,lparam2:longint):boolean; external 'mmsystem' name 'DriverCallback';









function bplayed1:longint; begin
{result:=(portW[ens1371port+$36])*4 ;}
end;


function clearbuf(bnum:byte):byte; var str:string;begin
HugeInc(pointer(mpc),(bhalf*bnum));
fillchar(Mpc^,bhalf,char($7F));
HugeDec(pointer(mpc),(bhalf*bnum));
end;


function loadbuf(bnum:byte):byte; var str:string;var tmp:longint;begin
HugeInc(pointer(mpc),(bhalf*bnum));
wav.seek({44+}mypos,0);
tmp:=bhalf;;
if(mymaxpos<mypos+bhalf)then begin tmp:=mymaxpos-mypos;end;
wav.read(Mpc^,tmp{bhalf});{read}
HugeDec(pointer(mpc),(bhalf*bnum));
myuserinfo.LByteCount:=myuserinfo.LByteCount+tmp;
mypos:=mypos+tmp;
myinc:=tmp;
      {
str:='lodb'+inttohex(myuserinfo.lbytecount,1);
writestr1(22,2,str);
     }
end;



function getnextinque:boolean;
var str:string;
var ptr:pointer;temp:longint;
begin
result:=false;
empty:=true;
{If we have played this one}

if(pwavehdr(written.items[0])^.lpNext and whdr_InQueue)=whdr_InQueue then begin
 {if looping}
 if((word(pwavehdr(written.items[0])^.dwloops)>1)
 and((pwavehdr(written.items[0])^.dwflags and (whdr_BeginLoop or whdr_EndLoop))=(whdr_BeginLoop or whdr_EndLoop)))then begin
 {decrease loop by one}
  word(pwavehdr(written.items[0])^.dwloops):=word(pwavehdr(written.items[0])^.dwloops)-1;
 {insert dummy to discard from queue}
  written.insert(0,written.items[0]);
 {we are not really done with this yet}
 {pwavehdr(written.items[1])^.dwflags:=pwavehdr(written.items[1])^.dwflags and not WHDR_REALLYDONE;}
  pwavehdr(written.items[1])^.lpNext:=pwavehdr(written.items[1])^.lpNext and not WHDR_InQueue;
  snipequeue;{remove this one}
 end else begin
  decqueue;{discard this one and send WOM_DONE}
 end;
end;

 if(written.count>=1)then begin{if there are more}
 empty:=false;
 {take one more card}
 {if not(IsBadReadPtr(pwavehdr(written.items[0]),sizeof(twavehdr)))then begin}
 mymaxpos:=pwavehdr(written.items[0])^.dwBufferLength;
 mypos:=0;
 wav.seek(0,0);
  if not(longint(pwavehdr(written.items[0])^.lpdata)=0)then begin
   ptr:=pointer(pwavehdr(written.items[0])^.lpdata);
   hmemcpy(wav.memory, pointer(pwavehdr(written.items[0])^.lpdata), mymaxpos);
   result:=true;
  end;
 pwavehdr(written.items[0])^.lpnext:=pwavehdr(written.items[0])^.lpnext or WHDR_InQueue;
 end;{are more}

end;

{has the chunk finished?}
function chunkover:boolean; begin
result:=false;
 if(mypos>=mymaxpos)then begin{no more to play}
result:=true;
 end;
end;

function getanotherchunk:boolean; begin
result:=false;
empty:=true;
 if(written.count>=1)then begin
  result:=getnextinque;{get one?}
 end else begin
 result:=false;{finished last one}
 end;
end;

function havemoredata:boolean; begin
result:=false;
if(chunkover)then begin
result:=getanotherchunk;{we need more data}
end else begin
result:=true;{we have more data}
end;

end;







function checkqueue:byte;
var str:string;
var ptr:pointer;temp:longint;
begin
empty:=true;
{If we have played this one}
{if not(IsBadReadPtr(pwavehdr(written.items[0]),sizeof(twavehdr)))then begin}
{if(pwavehdr(written.items[0])^.dwflags and WHDR_REALLYDONE)=WHDR_REALLYDONE then begin}
if(pwavehdr(written.items[0])^.lpNext and whdr_InQueue)=whdr_InQueue then begin


{if looping}
if((word(pwavehdr(written.items[0])^.dwloops)>1)
and((pwavehdr(written.items[0])^.dwflags and (whdr_BeginLoop or whdr_EndLoop))=(whdr_BeginLoop or whdr_EndLoop)))then begin
{decrease loop by one}
word(pwavehdr(written.items[0])^.dwloops):=word(pwavehdr(written.items[0])^.dwloops)-1;
{insert dummy to discard from queue}
written.insert(0,written.items[0]);
{we are not really done with this yet}
{pwavehdr(written.items[1])^.dwflags:=pwavehdr(written.items[1])^.dwflags and not WHDR_REALLYDONE;}
pwavehdr(written.items[1])^.lpNext:=pwavehdr(written.items[1])^.lpNext and not WHDR_InQueue;
snipequeue;{remove this one}
end else begin
decqueue;{discard this one and send WOM_DONE}
end;

{str:='discard from queue!'+inttostr(inch);
writestr1(6,7,str);}
end;
{end;}

if(written.count>=1)then begin{if there are more}
empty:=false;
{take one more card}
{if not(IsBadReadPtr(pwavehdr(written.items[0]),sizeof(twavehdr)))then begin}
mymaxpos:=pwavehdr(written.items[0])^.dwBufferLength;
mypos:=0;

{wav.clear;}
{wav.setsize(mymaxpos+$100);}
wav.seek(0,0);
if not(longint(pwavehdr(written.items[0])^.lpdata)=0)then begin
ptr:=pointer(pwavehdr(written.items[0])^.lpdata);

{if(IsBadHugeReadPtr(ptr,mymaxpos))then begin end else begin}
{if(inch=245)then begin}
{wav.write(ptr,mymaxpos);}
hmemcpy(wav.memory, pointer(pwavehdr(written.items[0])^.lpdata), mymaxpos);
temp:=(bhalf div 2)-1;

{!outport32(ens1371port+$34,temp);}

{showmessage(inttostr(mymaxpos));}
{wav.write(ptr,1000);}
{inch:=246;}
{end;}
{end;}

end;

{remember that we have played this}
{pwavehdr(written.items[0])^.dwflags:=pwavehdr(written.items[0])^.dwflags or WHDR_REALLYDONE;}
pwavehdr(written.items[0])^.lpnext:=pwavehdr(written.items[0])^.lpnext or WHDR_InQueue;

{str:='Again we load!'+inttostr(inch);
writestr1(6,7,str);}
{inch:=byte(inch+1);}

{end;}

end;{are more}


end;




function Wreaddata(bts,boffset:longint):word;
var x,b:longint;
var wrdoffset:longint;
var lngcnt:word;
var str:string;
var b1,b2,b3,b4:byte;
var slw:integer;
var sl:word;
begin
result:=0;
if not(boffset=0)then wrdoffset:=boffset div 2;
lngcnt:=bts shr 1;
{wrdcnt:=bts div 2;}
x:=0;b:=0;slw:=0;
while b<bts do begin
wav.read(b1,1);
wav.read(b2,1);
tlp(Mpc)^.test[(boffset)+x]:=b1;
tlp(Mpc)^.test[(boffset)+x+1]:=b2;
tlp(Mpc)^.test[(boffset)+x+2]:=b1;
tlp(Mpc)^.test[(boffset)+x+3]:=b2;
x:=x+2;{1:1 ratio}
b:=b+2;
end;

updatepos(lngcnt);{we only read b}
result:=bts;{we put bts in buffer}
end;



function buggy:byte;
var tmp:longint;
begin
wav.seek(mypos,0);
tmp:=lofs;
if(tmp>mymaxpos)then tmp:=mymaxpos;
if(mymaxpos<mypos+lofs)then begin tmp:=mymaxpos-mypos;end;
wav.read(Mpc^,tmp);{read}
myuserinfo.LByteCount:=myuserinfo.LByteCount+tmp;
mypos:=mypos+tmp;
myinc:=tmp;
end;

function loadhi:byte; begin
HugeInc(pointer(mpc),$10000+lofs);
{wav.read(mpc^.test,lofs);}
buggy;
HugeDec(pointer(mpc),$10000+lofs);
end;
function loadlo:byte; begin
HugeInc(pointer(mpc),$10000);
{wav.read(mpc^.test,lofs);}
buggy;
HugeDec(pointer(mpc),$10000);
end;


function load8bits(tmpa,offset:word):word; begin
result:=0;
if(mychannels=1)then begin
{if(mySamplesPerSec>88199)then begin
stereo8load16stereofull(tmpa,offset);
end else
if(mySamplesPerSec<12001)then begin
khz12mono8load16monofull(tmpa,offset);
end else
if(mySamplesPerSec<24001)then begin
khz24mono8load16monofull(tmpa,offset);
end else begin}
result:=mono8load16monofull(tmpa,offset);
{end;}
end else{}
if(mychannels=2)then begin
{ if(mySamplesPerSec<12001)then begin
 khz12stereo8load16stereofull(tmpa,offset);
 end else
 if(mySamplesPerSec<24001)then begin
 khz24stereo8load16stereofull(tmpa,offset);
 end else begin}
result:=stereo8load16stereofull(tmpa,offset);
{ end;}
end else begin
showmessage('8chanerr');
end;


end;
















{16=bits}



function load16bits(tmpa,offset:word):word; var str:string;begin
result:=0;

if(mychannels=1)then begin
 {if(mySamplesPerSec>88199)then begin
  breaddata(tmpa,offset);
 end else
 if(mySamplesPerSec<12001)then begin
  loadskip16monoquarter(tmpa,offset);
 end else
 if(mySamplesPerSec<24001)then begin
  loadskip16monohalf(tmpa,offset);
 end else begin}
result:=  loadskip16monofull(tmpa,offset);
{ end;}

end else
if(mychannels=2)then begin{stereo}

{ if(mySamplesPerSec<12001)then begin
   loadskip16stereoquarter(tmpa,offset);
 end else
 if(mySamplesPerSec<24001)then begin
   loadskip16stereohalf(tmpa,offset);
 end else begin}
result:=breaddata(tmpa,offset);
{ end;}

end else begin
showmessage('channy');
end;


end;



function loadbug(bnum,offset:longint):word; var str:string;var tmp:longint;
var ww:longint;
begin
result:=0;
wav.seek(mypos,0);
tmp:=bnum;
if(tmp>=mymaxpos)then tmp:=mymaxpos;
if(mypos+bnum>mymaxpos)then begin tmp:=mymaxpos-mypos;end;


if(mybits=8)then begin
tmp:=load8bits(tmp,offset);
end else{not}
if(mybits=16)then begin
tmp:=load16bits(tmp,offset);
end else begin
showmessage('bit error');
end;


result:=tmp;
{str:='bug'+inttostr(tmp);
writestr1(22,2,str);}
end;



function loadgub(bnum,offset:longint):word; var str:string;var tmp:longint;
var ww:longint;
begin

result:=0;
wav.seek(mypos,0);
tmp:=bnum;
if(tmp>=mymaxpos)then tmp:=mymaxpos;
if(mypos+bnum>mymaxpos)then begin tmp:=mymaxpos-mypos;end;


if(mybits=8)then begin
tmp:=load8bits(tmp,offset);
end else{not}
if(mybits=16)then begin
tmp:=load16bits(tmp,offset);
end else begin
showmessage('bit error');
end;


result:=tmp;
{str:='Gub'+inttostr(tmp);
writestr1(2,2,str);}
end;



{starts where ever}
function HIevent(bnum,offset:longint):word;
var str:string;
var writte:longint;
begin

result:=0;writte:=0;
{hi part}
while (writte<bnum) do begin
 if(havemoredata=true)then begin{verify that we have more data}
  writte:=writte+loadgub(bnum-writte,offset+writte);{get more data}
{   str:=inttostr(writte)+' more hi!';   writestr1(10,10,str);}
 end else begin{out of data?}
{    str:='none hi!';   writestr1(10,10,str);}
  HugeInc(pointer(mpc),offset+writte);
  fillchar(Mpc^,bnum-writte,char(0));
  HugeDec(pointer(mpc),offset+writte);
    writte:=bnum;{fill with blanks}
 end;

end;
result:=writte;
end;

function LOWevent(bnum,offset:longint):word;
var str:string;
var writte:longint;
begin

result:=0;writte:=0;
while (writte<bnum) do begin
if(havemoredata=true)then begin{verify that we have more data}
    writte:=writte+loadbug(bnum-writte,offset+writte);{get more data}
{    str:=inttostr(writte)+' more lo!';   writestr1(20,20,str);}
end else begin{out of data?}
{  str:='none lo!';   writestr1(20,20,str);}
  HugeInc(pointer(mpc),writte);
  fillchar(Mpc^,bnum-writte,char(0));
  HugeDec(pointer(mpc),writte);
    writte:=bnum;{fill with blanks}
end;

end;

result:=writte;
end;



function checkICHlist:byte;
var tmp:word;var str:string;
begin
result:=0;
if(fin=1)then begin
fin:=0;
tmp:=getcurrentindex and 31;


if(tmp=2)then begin{}
 if not(old=2)then begin {  loadlo;} 
lowevent(lofs,0);
{  setLastValidIndex(0);}
 end;
end else
if (tmp=0)then begin
 if not(old=0)then begin{  loadhi;}
hievent(lofs,lofs);
{  setLastValidIndex(2);}
 end;
end else

if (tmp=1)then begin
 if (old=0)then begin{  setLastValidIndex(3);}
 end;
end else
if (tmp=3)then begin
 if (old=1)then begin{  setLastValidIndex(0);}
 end;
end;
if(tmp>3)then begin
{str:='bugger'+inttostr(tmp);
writestr1(22,2,str);}
end;

if not(tmp=old)then begin
iset:=(old-1) and 31;
setLastValidIndex(iset);
end;

old:=tmp;

fin:=1;
result:=1;
end;

end;


function dummy:byte; begin
timercallback(0,0,0,0);
end;

procedure timercallback(hwindow:hwnd;msg:word;idtimer:word;dwtime:longint);
var str:string;            {dwtimer current system time}
var tmp2,tmp3:word;
begin

if (CardDetected=true)then begin
if (runing=true)then begin
if(over=0)then begin
over:=over+1;

HugeInc(pointer(mpc),$10000);{leave BDL alone}
if(checkICHlist=1)then begin end;
HugeDec(pointer(mpc),$10000);{leave BDL alone}

{tmp2:=NABMBAR_addr+PO_SR_REG;
tmp3:=port[tmp2];}
{if ((tmp3 and 1)=1)then begin{stopped? break it up!}
{setLastValidIndex(random(3));
end;    }

{str:=inttostr(tmp2);
writestr1(21,21,str);}

 if(empty=false)and(written.count>=1)and(mypos<mymaxpos{myinc{+(bhalf*got)})then begin

 end else begin{no more to play}
 empty:=true;
  if(written.count>=1)then begin
   if(checkqueue=0)then begin end;{(kill old and send its wom_done) then load new }
  end else begin  end;

 end;{no more to play}

over:=over-1;
end;{running}
end;
end;{CardDetected:=true;}
if(suicideevent=true)then begin timekillEvent(htime);suicideevent:=false; end;
end;


function Awaitfordac1play26:longint;
var str:string;
begin
result:=0;
{
while (portw[ens1371port+$26]=0) do begin
result:=result+1;
end;
}
end;

{function aawaitfordac1stop26:longint;
var str:string;
begin
result:=0;
while not(portw[ens1371pork+$26]=0) do begin
result:=result+1;
str:='playing'+inttohex((inport32(ens1371pork+$34) shr 19),8);
writestr1(2,2,str);
end;
end;}

                         {
function waitfordac1play26:byte; begin
repeat
if(1=2)then begin result:=result; end;
until not(portw[ens1371port+$26]=0);
end;

                        }

function awaitfordac1play:longint;
var str:string;
begin
result:=0;
while (portw[ens1371pork+$26]=0) do begin
result:=result+1;
{application.processmessages;}
end;
end;

function aawaitfordac1stop:longint;
var str:string;
begin
{
result:=0;
repeat
result:=result+1;
str:=inttostr(result);
writestr1(2,2,str);
until (not((portw[ens1371port+$36] shr 4)=0));
     }
result:=0;
{
repeat
result:=result+1;
str:=inttohex(result,8)+' '+inttohex((inport32(ens1371port+$34) shr 19),8);
writestr1(2,2,str);
until ((result>$3FFF)or((inport32(ens1371port+$34) shr 19)<(myblockalign)));
                   }
{
while not(portw[ens1371port+$26]=0) do begin
result:=result+1;
str:=inttostr(portw[ens1371port+$26]);}
{writestr1(1,1,str);

end;}
end;



function playdati(port:word;stre:tstream;wmptr:pointer;Len:longint;align,ival:word):byte;
var cout:word;
var bites:word;
var crash:longint;
var str:string;
begin
{make dac1 should be looping}
myuserinfo.LByteCount:=0;
portw[port+$24]:=0;
portw[port+$36]:=0;
mystop:=1;
cout:=0;
bites:=0;
result:=1;
bites:=ival*4;
fillchar(wmptr^,bites,char(0));
stre.seek($4,0);
stre.seek(0,0);
portw[port+$34]:=Ival;
while (cout<=(Len div bites))  do begin
if(mystop=0)then break;
crash:=0;
stre.read(WMptr^,bites+align);{read $400}
portw[port+$36]:=0;
while(portw[port+$36]{+align}<ival){and(mystop=1)} do begin
if(mystop=0)then break;
{application.processmessages;}
crash:=crash+1;
{str:='play:'+inttohex(myuserinfo.LByteCount,8);
writestr1(25,8,str);}
end;
cout:=cout+1;
myuserinfo.LByteCount:=longint(longint(bites)*cout);
end;
if(myuserinfo.LByteCount>mymaxpos)then myuserinfo.LByteCount:=mymaxpos;

fillchar(wmptr^,$FFFF,char(0));
{str:='play:'+inttohex(myuserinfo.LByteCount,8);
writestr1(25,8,str);}
result:=0;

end;



function myDAC1Write(wDeviceID:word;wMessage:word;DWUSER:longint;lparam1,lparam2:longint):longint;
var temp:longint;
var tmp:longint;
var wrd:word;
var str:string;
var mlpFMT:pWAVEFORMAT;
var mlpwod:pWAVEOPENDESC;
var mlpwavehdr:pwavehdr;
var mtp:pointer;
var ptempClient:PWAVEALLOC;{pointer to client information structure }
{var co:byte;}
begin

{}
if((pwavehdr(lparam1)^.dwFlags and whdr_BeginLoop)=whdr_Beginloop)then begin
{showmessage('loopy!');}

if((pwavehdr(lparam1)^.dwloops<0))then begin
{DAC1looping(true);}
myloops:=(pwavehdr(lparam1)^.dwloops);
{str:='set looping'+inttostr(myloops);
writestr1(20,4,str);}
end else
if((pwavehdr(lparam1)^.dwloops>0))then begin
{DAC1looping(true);}
myloops:=(pwavehdr(lparam1)^.dwloops);
{myloops:=0;}
{str:='set loops'+inttostr(myloops);
writestr1(20,4,str);}
end else begin
myloops:=0;
{str:='set loops empty!';
writestr1(20,4,str);}
{DAC1looping(false);}
end;
end;

if((pwavehdr(lparam1)^.dwFlags and  whdr_EndLoop)=whdr_EndLoop)then begin
{showmessage('doopy!');}
if(myloops>0)then begin
myloops:=myloops-1;
end;
if(myloops=0)then begin
{DAC1looping(false);}
end;
{str:='whdr_EndLoop!';
writestr1(20,4,str);}
end;

if((pwavehdr(lparam1)^.dwFlags and whdr_inqueue)=whdr_InQueue)then begin
{result:=result or WAVERR_STILLPLAYING;}
end;
if((pwavehdr(lparam1)^.dwFlags>31))then begin
{showmessage('eh?');}
end;


ptempClient := pointer(dwUser);
{make waveheader structure reserved equals the ptempClient}
PWAVEHDR(lParam1)^.reserved:=longint(dwUser){store ptr to my ptempclient structure in the written wavehdr};

{if you want to use the info}

{PWAVEHDR(currentwavehdr)^.reserved}

{ptempClient := pointer(PWAVEHDR(lParam1)^.reserved);}
{we remember :)}



result:=result or 0;{default to no error}
{Turn DAC1 OFF}
{!DAC1on(false);}
{dumbdelay;}
{myuser:=dwuser;}
{remember this twavehdr}
{move(pwavehdr(lparam1)^,mywavehdr,sizeof(twavehdr));}


{str:='Write start! '+inttostr(written.count);
writestr1(6,26,str);}

temp:=0;
temp:=pwavehdr(lparam1)^.dwBufferLength;

{mymaxpos:=temp;}
{wiz:=mymaxpos;}
if(temp=0)then begin

end;

{str:='0000000000';
writestr1(25,5,str);}


if(temp>$FFFF) then begin
temp:=$FFFF;
{to large! But I shall truncate it!}
end;
{myrealpos:=temp;}

{str:='0000000000';
writestr1(25,6,str);}

{str:='BC:'+inttohex(myuserinfo.LByteCount,8);
writestr1(25,6,str);}

if(temp=0)then begin

end;

if(temp<=$8)then begin

{fillchar(Mpc^,word($FFFF),char(0));}
{clearallbuffers(0);}
end else
if not(temp<=$8)then begin


mlpFmt := (myWD.LPWAVEFORMAT);
wrd:=word(mlpFmt^.nBlockAlign);
if(wrd=0)then begin
{showmessage('zero block align!');}
wrd:=1;{hello goldwave}
end;


{showmessage(inttostr(wrd));}

{for pointers larger than $F do this!}
if (
pwavehdr(lparam1)^.dwBufferLength>$10)and(
(IsBadHugeReadPtr(pointer(pwavehdr(lparam1)^.lpdata),pwavehdr(lparam1)^.dwBufferLength)=false))then begin
{showmessage('it is a good huge pointer!');}
{fillchar(Mpc^,word($FFFF),char($7F));}
{clearallbuffers($7F);}

mystop:=0;
{wav.clear;
wav.seek(0,0);
wav.write(pwavehdr(lparam1)^.lpdata[0],mymaxpos);}
{move(pwavehdr(lparam1)^.lpdata[0],Mpc^,word(temp));}
{Although they are related,24 does not equal 34}

{!DAC1on(true);{Turn DAC1 ON}
{DAC1looping(true);{looping function}

{Wait till finished playing, then send WOM_DONE}




if(1=2)and(sync=true)then begin
{if(1=playdati(ens1371port,wav,Mpc,mymaxpos,myblockalign,$400))then begin end;}
clearallbuffers($7F);
{wodBlockFinished(pwavehdr(waveheade));}
decqueue;{finished;discard this one and send WOM_DONE}
mymaxpos:=0;
myuserinfo.LByteCount:=0;{reset count to zero}
end;
runing:=true;

{that was HUGE!}
{that added one more chunk to play}
{written:=written+1;}

{wiz:=0;}
end;




{is there a next block?}
{showmessage('total hdr size'+inttostr(longint(longint(lparam2))));}

{showmessage('lpnext='+inttohex(longint(longint(pwavehdr(lparam1)^.lpnext)),8));
showmessage('reserved='+inttohex(longint(longint(pwavehdr(lparam1)^.reserved)),8));
 }



{tp:=pwavehdr(pwavehdr(lparam1)^.lpnext);}


{this is in queue}

{are we synchronous or not?}
if(1=2)then begin

{before we send the message that we are done, we must set this bit.}
{can this be done?}
if not(IsBadReadPtr(pwavehdr(lpstore[1]),sizeof(twavehdr)))then begin
pwavehdr(lpstore[1])^.dwflags:=pwavehdr(lpstore[1])^.dwflags or whdr_Done;{ set done bit }
end;
{pwavehdr(lparam1)^.dwflags:=pwavehdr(lparam1)^.dwflags or whdr_Done;{ set done bit }
{send WOM_DONE callback to our user}
wodBlockFinished(pwavehdr(lparam1));
 {
if(mywd.callback>0)then begin
if (Mmsystem_DriverCallback(
     mywd.Callback,
     hiWORD(lpstore[2]) or DCB_NOSWITCH,
     mywd.hWave,
     WOM_DONE,
     mywd.Instance,
     lparam1,
     lparam2
))then begin
str:='_write callback ok';
writestr1(30,16,str);
end else begin
str:='fail _write callback';
writestr1(30,16,str);
end;
}
end;{1=2}



end;

end;


procedure GetIntVec(IntNo: Byte; var Vector: Pointer); assembler;
asm
	MOV	AL,IntNo
	MOV	AH,35H
	INT	21H
	MOV	AX,ES
	LES	DI,Vector
	CLD
	XCHG	AX,BX
	STOSW
	XCHG	AX,BX
	STOSW
end;

procedure SetIntVec(IntNo: Byte; Vector: Pointer); assembler;
asm
	PUSH	DS
	LDS	DX,Vector
	MOV	AL,IntNo
	MOV	AH,25H
	INT	21H
	POP	DS
end;



Procedure myInt(rSI, rDI, rDS, rES, rBP:Word);interrupt; begin
asm
mov ax,ax
mov ax,ax
mov ax,ax
mov ax,ax
	sub	sp,4		    {save space for return address}
	push	bp
	mov	bp,sp
	push	ax
	push	dx
	push	ds
        mov ax,seg lpOldISR1
	mov	ds,ax
{	inc	wCount}

	mov	ax,lpOldISR1{Lo Word	of return address}
	mov	[bp+2],ax
	mov	ax,lpOldISR2{Hi Word of return address}
	mov	[bp+4],ax


	push	bx
	push	cx
	push	es
call dummy;

	pop	es
	pop	cx
	pop	bx

	pop	ds
	pop	dx
	pop	ax
	leave
	retf
end;
end;



procedure Starttime(hw:pointer);
{var wParamEvent:WORD;}
{var hWndEvent:pointer;}
begin

    if not(longint(lpfnOldISR)>0)then begin
{	/* Save the previous ISR and set ours */}
	asm cli; end;
	GetIntVec(INT_DEV,lpfnOldISR) ;
        lpOldISR1:=loword(longint(lpfnOldISR));
        lpOldISR2:=hiword(longint(lpfnOldISR));


  if (LockSegment(CSeg)<>0) and (LockSegment(DSeg)<>0) then begin
	SetIntVec(INT_DEV,ptr(seg(myInt),ofs(myInt)+18)) ;

        end;

 {	/* Unmask the interrupt and begin device I/O */}
	asm sti; end;
end;

end;



procedure Stoptime;
begin
    if (longint(lpfnOldISR)>0)then begin
    SetIntVec(INT_DEV, lpfnOldISR) ; 	{ /* Restore the prot-mode vector */}
    UnLockSegment(CSeg); UnLockSegment(DSeg);
    lpfnOldISR := ptr(0,0);

end;
end;

function wavegoodbye:byte; begin
if(written.count>0)then begin
resetqueue;
end;
if(opened>0)then begin
 if(myuserinfo.LCallback>0)then begin
   Mmsystem_DriverCallback(
   myuserinfo.LCallback,
   hiWORD(myuserinfo.LFlags) or DCB_NOSWITCH,  { flags }
   myuserinfo.hWave,
   WOM_CLOSE,myuserinfo.LInstance,0,0);
 end;

end;
end;


end.

