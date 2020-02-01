unit Khz;

interface
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  jeff,ich,ichdma,misc,tintlist,{pci,}Forms, Dialogs, StdCtrls,mmddk,unit2;


var wav:tmemorystream;
var new,old,fin:byte;

function updatepos(tmp:word):word; export;
function Breaddata(bts,boffset:longint):word;export;
function loadskip16monofull(samp,boffset:word):word;export;
function loadskip16monohalf(samp,boffset:word):word;export;
function loadskip16monoquarter(samp,boffset:word):word;export;
function loadskip16stereohalf(samp,boffset:word):word;export;
function loadskip16stereoquarter(samp,boffset:word):word;export;


function mono8load16monofull(samp,boffset:word):word;export;
function khz12mono8load16monofull(samp,boffset:word):word;export;
function khz24mono8load16monofull(samp,boffset:word):word;export;
function khz12stereo8load16stereofull(samp,boffset:word):word;export;
function khz24stereo8load16stereofull(samp,boffset:word):word;export;
function stereo8load16stereofull(samp,boffset:word):word;export;



implementation


function updatepos(tmp:word):word; begin
myuserinfo.LByteCount:=myuserinfo.LByteCount+tmp;
mypos:=mypos+tmp;
myinc:=tmp;
end;


{gets 12000khz mono 8 bit plays l+r 16}
function khz12mono8load16monofull(samp,boffset:word):word;
var x,b,ssw:word;
var wrdoffset:word;
var si1:byte;
var i1,i2:integer;
var jb:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
jb:=0;
while b<=samp do begin
wav.read(si1,1);
i1:=si1;
i1:=i1 - $80;
i1:=i1 * 128;
{i2:=si2;i2:=i2 - $80;i2:=i2 * 128;}
wstr(Mpc)^.test[(wrdoffset)+x]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=word(i1);
wstr(Mpc)^.test[(wrdoffset)+x+2]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=word(i1);
wstr(Mpc)^.test[(wrdoffset)+x+4]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+5)]:=word(i1);
wstr(Mpc)^.test[(wrdoffset)+x+6]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+7)]:=word(i1);
jb:=jb+1;{read one byte}
x:=x+8;{jump 4 words}
b:=b+16;{fill 8 bytes}
end;
updatepos(jb);{we only read this much}
result:=b;
end;

{gets 12000khz stereo 8 bit plays l+r 16}
function khz12stereo8load16stereofull(samp,boffset:word):word;
var x,b,ssw:word;
var wrdoffset:word;
var si1,si2:word;
var i1,i2:integer;
var jb:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
jb:=0;
while b<=samp do begin
wav.read(ssw,2);
si1:=(lobyte(ssw));
si2:=(hibyte(ssw));
i1:=si1;i1:=i1 - $80;i1:=i1 * 128;
i2:=si2;i2:=i2 - $80;i2:=i2 * 128;
{}
wstr(Mpc)^.test[(wrdoffset)+x]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=word(i2);
wstr(Mpc)^.test[(wrdoffset)+x+2]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=word(i2);
wstr(Mpc)^.test[(wrdoffset)+x+4]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+5)]:=word(i2);
wstr(Mpc)^.test[(wrdoffset)+x+6]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+7)]:=word(i2);
jb:=jb+2;{read two bytes}
x:=x+8;{jump 4 words}
b:=b+16;{fill 8 bytes}
end;
updatepos(jb);{we only read this much}
result:=b;
end;







{gets 24000khz mono 8 bit plays l+r 16}
function khz24mono8load16monofull(samp,boffset:word):word;
var x,b,ssw:word;
var wrdoffset:word;
var si1:byte;
var i1,i2:integer;
var jb:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
jb:=0;
while b<=samp do begin
wav.read(si1,1);
i1:=si1;
i1:=i1 - $80;
i1:=i1 * 128;
{i2:=si2;i2:=i2 - $80;i2:=i2 * 128;}
wstr(Mpc)^.test[(wrdoffset)+x]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=word(i1);
wstr(Mpc)^.test[(wrdoffset)+x+2]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=word(i1);
jb:=jb+1;{read one byte}
x:=x+4;{jump 4 words}
b:=b+8;{fill 8 bytes}
end;
updatepos(jb);{we only read this much}
result:=b;
end;

{gets 24000khz stereo 8 bit plays l+r 16}
function khz24stereo8load16stereofull(samp,boffset:word):word;
var x,b,ssw:word;
var wrdoffset:word;
var si1,si2:word;
var i1,i2:integer;
var jb:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
jb:=0;
while b<=samp do begin
wav.read(ssw,2);
si1:=(lobyte(ssw));
si2:=(hibyte(ssw));
i1:=si1;i1:=i1 - $80;i1:=i1 * 128;
i2:=si2;i2:=i2 - $80;i2:=i2 * 128;
{}
wstr(Mpc)^.test[(wrdoffset)+x]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=word(i2);
wstr(Mpc)^.test[(wrdoffset)+x+2]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=word(i2);
jb:=jb+2;{read two bytes}
x:=x+4;{jump 4 words}
b:=b+8;{fill 8 bytes}
end;
updatepos(jb);{we only read this much}
result:=b;
end;



{gets mono 8 bit plays l+r 16}
function mono8load16monofull(samp,boffset:word):word;
var x,b,ssw:word;
var wrdoffset:word;
var si1:byte;
var i1,i2:integer;
var jb:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
jb:=0;
while b<samp do begin
wav.read(si1,1);
i1:=si1;
i1:=i1 - $80;
i1:=i1 * 128;
{i2:=si2;i2:=i2 - $80;i2:=i2 * 128;}
wstr(Mpc)^.test[(wrdoffset)+x]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=word(i1);
jb:=jb+1;{read one byte}
x:=x+2;{jump 2 words}
b:=b+4;{fill 4 bytes}
end;
updatepos(jb);{we only read this much}
result:=b;
end;



{gets l+r 8 bit plays l+r 16}
function stereo8load16stereofull(samp,boffset:word):word;
var x,b,ssw:word;
var wrdoffset:word;
var si1,si2:word;
var i1,i2:integer;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
while b<{=}samp do begin
wav.read(ssw,2);
si1:=(lobyte(ssw));
si2:=(hibyte(ssw));
i1:=si1;i1:=i1 - $80;i1:=i1 * 128;
i2:=si2;i2:=i2 - $80;i2:=i2 * 128;
wstr(Mpc)^.test[(wrdoffset)+x]:=word(i1);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=word(i2);
x:=x+2;
b:=b+4;
end;
updatepos(x);{we only read this much}
result:=b;
end;


{16m >16s}
{48khz load 16 mono out 16 stereo}
function loadskip16monofull(samp,boffset:word):word;
var x,b:word;
var wrdoffset:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
while b<=samp do begin
wav.read(wstr(Mpc)^.test[(wrdoffset)+x],2);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
x:=x+2;
b:=b+4;
end;
updatepos(x);{we only read this much}
result:=b;
end;



{16m/2 >16s}
{24khz load 16 mono out 16 stereo}
function loadskip16monohalf(samp,boffset:word):word;
var z,x,b:word;
var wrdoffset:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
z:=0;
while b<=samp do begin
wav.read(wstr(Mpc)^.test[(wrdoffset)+x],2);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+2)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
z:=z+2;
x:=x+4;
b:=b+8;
end;
updatepos(z);{we only read this much}
result:=b;
end;




{16m/4 >16s}
{12khz load 16 mono out 16 mono}
function loadskip16monoquarter(samp,boffset:word):word;
var x,b,z:word;
var wrdoffset:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
z:=0;
while b<=samp do begin
wav.read(wstr(Mpc)^.test[(wrdoffset)+x],2);
wstr(mpc)^.test[(wrdoffset)+(x+1)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+2)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+4)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+5)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+6)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+7)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
z:=z+2;{file data loaded}
x:=x+8;{bskips}
b:=b+16;{totfill}
end;
updatepos(z);{we only read this much}
result:=b;
end;

{16s/2 >16s}
{24khz load 16 stereo out 16 stereo}
function loadskip16stereohalf(samp,boffset:word):word;
var x,b,z:word;
var wrdoffset:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
z:=0;
while b<=samp do begin
wav.read(wstr(Mpc)^.test[(wrdoffset)+x],2);
wav.read(wstr(Mpc)^.test[(wrdoffset)+x+1],2);
wstr(mpc)^.test[(wrdoffset)+(x+2)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=wstr(mpc)^.test[(wrdoffset)+(x+1)];
z:=z+4;{file data loaded}
x:=x+4;{word skips}
b:=b+8;{totfill}
end;
updatepos(z);{we only read this much}
result:=b;
end;


{16s/4 >16s}
{12khz load 16 stereo out 16 stereo}
function loadskip16stereoquarter(samp,boffset:word):word;
var x,b,z:word;
var wrdoffset:word;
begin
wrdoffset:=boffset div 2;
x:=0;
b:=0;
z:=0;
while b<=samp do begin
wav.read(wstr(Mpc)^.test[(wrdoffset)+x],2);
wav.read(wstr(Mpc)^.test[(wrdoffset)+x+1],2);
wstr(mpc)^.test[(wrdoffset)+(x+2)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+3)]:=wstr(mpc)^.test[(wrdoffset)+(x+1)];
wstr(mpc)^.test[(wrdoffset)+(x+4)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+5)]:=wstr(mpc)^.test[(wrdoffset)+(x+1)];
wstr(mpc)^.test[(wrdoffset)+(x+6)]:=wstr(mpc)^.test[(wrdoffset)+(x)];
wstr(mpc)^.test[(wrdoffset)+(x+7)]:=wstr(mpc)^.test[(wrdoffset)+(x+1)];
z:=z+4;{file data loaded}
x:=x+8;{word skips}
b:=b+16;{totfill}
end;
updatepos(z);{we only read this much}
result:=b;
end;





function Breaddata(bts,boffset:longint):word;
var x,b:longint;
var wrdoffset:longint;
var str:string;
begin
if not(boffset=0)then wrdoffset:=boffset div 2;
x:=0;b:=0;
while b<bts do begin
wav.read(tlp(Mpc)^.test[(boffset)+x],1);
x:=x+1;
b:=b+1;
end;
updatepos(bts);
result:=bts;
end;



end.
