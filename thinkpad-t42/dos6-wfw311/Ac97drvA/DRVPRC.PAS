unit Drvprc;

interface
uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  inifiles,khz,jeff,PCI,misc,AC97,ICH,ICHdma,{usbdefs,}mmsystem,wwrite,tintlist,{pci,}Forms, Dialogs, StdCtrls,mmddk,unit2;


var enh386:boolean;
function finish:byte; export;
function NewDriverProc(DriverIdentifier: Longint; DriverId: THandle;
Msg: Word; lParam1, lParam2: Longint): Longint; export;

  procedure enhanced_mode_present (var present : boolean);export;
var form1created:boolean;
var high16,low16:word;
var TSRfound:byte;
implementation


procedure TSR_Check; assembler;
asm
        mov     ax, 0200h      { ; get real mode interrupt vector}
        mov     bl, 9Bh         {; our handler}
        int     31h             {; DPMI Call}

        or      cx, dx          {; anything there?}
        jz      @notsr
        mov     ax, 0       {; clear registers}
        mov     bx, 0
        mov     cx, 0
        int     9Bh             {; call int 60}

        cmp     cx, $AC97       {; Signature: did it do it?}
        jnz     @notsr
        mov     TSRfound, 99
        mov     low16, ax
        mov     high16, bx
@notsr:
end;


function destroydriver:byte;
begin
if not(Mpc=nil)then FreeSelector (HIWORD(longint(Mpc)));
Stoptime;
killtimer(htime,0);{?}
{resetqueue;{we have cleared the written queue}
{written.clear;}
{mypos:=$FFFFFFFF;{the end!}
{writepciregisterWord($3C,PCIbus,PCIFunc,$A);}
{codecplay(false);{disble playing}
{wav.setsize(1);}
{stopU;}
wav.free;
written.free;
end;




function clearbdlbuffer:byte;
var turn:byte;
begin
turn:=0;
while turn<33 do begin
mpc^.Best[turn].address:=nil;
mpc^.Best[turn].settings:=0;
turn:=turn+1;
end;
end;

function preparebdlbuffer:byte; begin{48khz 16-bit stereo samples(WORD)}
mpc^.best[0].address:=pointer(physical1);
mpc^.best[0].settings:=longint(BuffUP)+ samps;
mpc^.best[1].address:=pointer(physical2);
mpc^.best[1].settings:=longint(BuffUP)+ samps;
mpc^.best[2].address:=pointer(physical3);
mpc^.best[2].settings:=longint(BuffUP)+ samps;
mpc^.best[3].address:=pointer(physical4);
mpc^.best[3].settings:=longint(BuffUP)+ samps;
end;


function createdriver(pciaddrHI,pciaddrLO:word):byte;
var w:word;
var si:tinifile;
begin

Mphysical:=ptr(PCIaddrHI,PCIaddrLO);
physical1:=ptr(PCIaddrHI+1,PCIaddrLO);{data buffers}
physical2:=ptr(PCIaddrHI+1,PCIaddrLO+(bofs));
physical3:=ptr(PCIaddrHI+1,PCIaddrLO+(bofs*2));
physical4:=ptr(PCIaddrHI+1,PCIaddrLO+(bofs*3));


Msellimit:=3;
{this hardware likes 64k pages}
Mlength:=pointer((longint(((Msellimit))*$10000)));
Mlinear:=MapPhysicalToLinear(MPhysical, MLength);
{examine address}
if not(longint(Mlinear)=0)then begin
Mpc:=bdstr(CreateHugePointer (pointer(MLinear), pointer(MLength)));
if(longint(Mpc)>0)then begin
clearallbuffers($00);
{fillchar(Mpc^,word($FFFF),char($00));{clear the sound data}
{mpc^ is now our pointer to pci hardware}
end;

end else begin
showmessage('linear error!');
end;



wav:=tmemorystream.create;
wav.setsize(15000000);

written:=tintegerlist.create;
written.clear;
{startU;}
{Enable ICH AC'97}

{FindCARD}
if(findunusedcard(ICH_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH0_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH2_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH3_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH4_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH5_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH6_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else
if(findunusedcard(ICH7_DID,0)=1)then begin
readPCIRegisterword($10,pciBUS,pciFunc,w);
NAMBAR_addr:=w-1;
readPCIRegisterword($14,pciBUS,pciFunc,w);
NABMBAR_addr:=w-1;
end else begin
{no ICH chipset?}
end;

codecConfig(48000);{set samples to 48khz  }
{codecConfig(44100);{set samples to 44.1khz}
resetregisters;{reset ICH}
delay1(14);
EnableVariableRatebit;
delay1(5);
setac97(CODEC_MASTER_VOL_REG,$1010);
delay1(5);
setac97(CODEC_HP_VOL_REG,$0202);
delay1(5);
setac97(CODEC_MASTER_MONO_VOL_REG,$1010);
delay1(5);
setac97(CODEC_PCBEEP_VOL_REG,$1010);
delay1(5);
setac97(CODEC_PHONE_VOL_REG,$1010);
delay1(5);
setac97(CODEC_PCM_OUT_REG,$0808);

si:=tinifile.create('ICHcfg.ini');
myvol:=strtoint(si.readstring('Volume','PCM','$FFFFFFFF'));
si.free;
{vol change}
setac97(CODEC_PCM_OUT_REG,
{ac97CODEC_Setvalue(}(
(($1f-(hiword(myvol) div $800)) and $1f) shl 8)+
(($1f-(loword(myvol) div $800)) and $1f)
);




delay1(1);
setLastValidIndex(3);{Four buffers}
clearbdlbuffer;{BDL entires}
preparebdlbuffer;{Prepare 4 BDL entires}
SetBDLBuffer(Mphysical);{ICH Now using BDL}
codecplay(true);{enable playing}


end;



function finish:byte;
var temp:word;
begin
 if(driverclosing=false)then begin
 driverclosing:=true;
 enhanced_mode_present(enh386);
  if(enh386)then begin
   suicideevent:=true;{timekillEvent(htime);}
    while suicideevent=true do begin
      if(suicideevent)then begin enh386:=enh386;{wait for it!}end;
    end;
  end;
 {Turn DAC OFF}
temp:=4;{Command Register=4}
writePCIRegisterWord(temp,pciBUS,pciFunc,$100);
 {free resources}
 wavegoodbye;
 end;
end;


function newDriverProc(DriverIdentifier: Longint; DriverId: THandle;
Msg: Word; lParam1, lParam2: Longint): Longint;

var s:string;
var ptr:pointer;
var noj:byte;
const wdevmax=1;
const power=32;clock1=64;latch=2;
var si:tinifile;
begin
noj:=3;
result:=0;

{if(msg=DRV_RESERVED)then begin showmessage('reserved');msg:=msg-DRV_RESERVED;
msg:=msg-DRV_RESERVED;
end else
if(msg=DRV_POWER)then begin showmessage('power');msg:=msg-DRV_POWER;end else
if(msg=DRV_EXITAPPLICATION)then begin showmessage('exitapplication');msg:=msg-DRV_EXITAPPLICATION;end else
if(msg=DRV_EXITSESSION)then begin msg:=msg-DRV_EXITSESSION;end else}
if(msg=DRV_REMOVE)then begin  result:=1;
end else
if(msg=DRV_INSTALL)then begin result:=1;{showmessage('restart?');}end else
if(msg=DRV_QUERYCONFIGURE)then begin result:=1;end else
if(msg=DRV_CONFIGURE)then begin

if form1created=false then begin
Application.CreateForm(TForm1, Form1);
form1created:=true;
form1.showmodal;
form1.free;
form1created:=false;
end;


result:=1;
end else
if(msg=DRV_FREE)then begin
{runing:=false;}
finish;
{Turn DAC1 OFF}
{port[ens1371port]:=0;}
{free resources}
{enhanced_mode_present(enh386);
if(enh386)then begin
timekillEvent(htime);
end;}
destroydriver;
result:=1;
end else
if(msg=DRV_DISABLE)then begin finish;result:=1;end else
if(msg=DRV_CLOSE)then begin result:=1;{runing:=false;}end else
if(msg=DRV_OPEN)then begin result:=1;
{if (lParam2 < wDevMax) then begin result:=(lParam2 + 1)end else begin  result:=0;end;
DriverId:=0;}
end else
if(msg=DRV_ENABLE)then begin result:=1;DriverId:=0;end else
if(msg=DRV_LOAD) then begin result:=1;DriverId:=0;

if DetectICH then begin end;


TSR_Check;{There might be a TSR for XMS}

IF(TSRfound=99) then begin{TSR was found?}
si:=tinifile.create('ICHcfg.ini');
 si.writestring('TSR','XMS','Found');
 si.writestring('TSR','reservedHI','$'+inttohex(high16,4));
 si.writestring('TSR','reservedLO','$'+inttohex(low16,4));
 si.writestring('TSR','reservedXMS','$'+inttohex(makelong(low16,high16),8));
 myPCIhi:=high16;
 myPCIlo:=low16;
 myPCImem:=makelong(low16,high16);
si.free;
end else begin
si:=tinifile.create('ICHcfg.ini');
 si.writestring('TSR','XMS','Not Found');
 myPCIHI:=strtoint(si.readstring('BUSMASTER','defaultPCIHi',inttostr(defaultPCIHI)));
 myPCILO:=strtoint(si.readstring('BUSMASTER','defaultPCILo',inttostr(defaultPCILO)));
 myPCImem:=strtoint(si.readstring('BUSMASTER','defaultPCImem',inttostr(defaultPCImem)));
si.free;
end;



createdriver((mypciHI+mydrvoffset),mypciLO);
{carddetected:=true;}
if(carddetected=true)then begin
{Configure137x;}
{this timer is too slow}
{starttime(nil);}
{this timer is too slow!}
{htime:=SetTimer(0,0,0,@timercallback);}
enhanced_mode_present(enh386);
if(enh386)then begin
ptr:=@timercallback;
htime:=timesetevent(1,1000,  TTimeCallBack(ptr),0,TIME_PERIODIC);
end;


end;



end else
begin
result:=defDriverProc(DriverIdentifier,DriverId,Msg, lParam1, lParam2);
end;

end;


  procedure enhanced_mode_present (var present : boolean);
  begin asm
       push es
       mov ax, 1600h; int 2fh

       cmp ax, 1600h
       jne @enhanced_mode_present
       @not_endhanced_mode:
       mov ax, 0
       jmp @end_function
       @enhanced_mode_present:
       mov ax, 0ffffh

       @end_function:
       les di, present; stosB
       pop es
  end; end;


end.
