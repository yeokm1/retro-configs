unit VDS;


interface
uses dpmi1,winprocs;
var rregs: TRealModeRegs;

type PDDS = ^DDS;
DDS=Record
     Region_Size         :longint   ;{ offset 0}
     Offset              :longint   ;{ offset 4}
     Seg_or_Select       :WORD      ;{ offset 8}
     Buffer_ID           :WORD      ;{ offset A}
     Physical_Address    :longint   ;{ offset C}
end;

type VDMAversion=^vdmaver;
VDmaver=record
     vMajor:BYTE;
     vMinor:BYTE;
     product:WORD;
     revision:WORD;
     mSize:WORD;
     xsize:WORD;
     flags:word;
end;

function GetVersion( version:VDmaver):BYTE;export;
function LockDMARegion(fl:word;buf:PDDS):BYTE; export;
function UnLockDMARegion(fl:word;buf:PDDS):BYTE; export;
function RequestBuffer(fl:word;buf:PDDS):byte; export;
function ReleaseBuffer(fl:word;buf:PDDS):byte; export;
function ScatterLockRegion(fl:WORD;buf:PDDS;ofs:pointer):byte;export;
function ScatterUnlockRegion(fl:WORD;buf:PDDS):byte;export;
function DisableDMA(channel:word):byte;export;
function EnableDMA(channel:word):byte;export;
function CopyFromBuffer(buf:PDDS;ofs:longint):byte;export;
function CopyToBuffer(buf:PDDS;ofs:longint):byte;export;
implementation


function GetVersion(version:VDmaver):BYTE;
var retval:BYTE;
var a,b,c,d,id,ii:word;
begin
 retval := 0;
    asm
        mov     ax,8102h
        mov     dx,0
        int     4bh
        jc      @tmp
        mov     retval,1

        mov     a,ax      {byte}
        mov     b,bx       {word product}
        mov     c,cx        {word revision}
        mov     id,di         {word min}
        mov     ii,si          {word max}
        mov     d,dx           {word flags}
    @tmp:
    end;
    version.vmajor:=lobyte(a);
    version.vmajor:=hibyte(a);
    version.product:=b;
    version.revision:=c;
    version.msize:=id;
    version.xsize:=ii;
    version.flags:=d;
    result:= retval;
end;

{think dpmi is required to get di/si registers}
function oGetVersion(version:VDmaver):byte; begin
     RRegs.AL:= $02;        { Enable DMA Translation}
     RRegs.AH:= $81;
     RRegs.DX:= 0;    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
    version.vmajor:=rregs.al;
    version.vminor:=rregs.ah;
    version.product:=rregs.bx;
    version.revision:=rregs.cx;
    version.msize:=rregs.di;
    version.xsize:=rregs.si;
    version.flags:=rregs.dx;
{we have called an interrupt}
end;


function LockDMARegion(fl:word;buf:PDDS):BYTE;
var retval:byte;
begin
    retval := 0;
    asm
            push    ds
        mov     dx,fl
        mov     ax,8103h
        lds     si,buf
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;

function UnLockDMARegion(fl:word;buf:PDDS):BYTE;
var retval:byte;
begin
    retval := 0;
   asm
        mov     dx,fl
        mov     ax,8104h
        les     di,buf
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;

function RequestBuffer(fl:word;buf:PDDS):byte;
var retval :byte;
begin
retval := 0;
    asm
        mov     dx,fl
        mov     ax,8107h
        les     di,buf
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
result:= retval;
end;

function ReleaseBuffer(fl:word;buf:PDDS):byte;
var retval:byte;
begin
 retval := 0;
    asm
        mov     dx,fl
        mov     ax,8108h
        les     di,buf
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
end;
    result:= retval;
end;

function ScatterLockRegion(fl:WORD;buf:PDDS;ofs:pointer):byte;
var retval:byte;
begin
retval := 0;
    asm
        mov     dx,fl
        mov     ax,8105h
        les     di,buf
        int     4bh
        jnc     @tmp
        mov     retval,al
        les     di,ofs
        mov     es:[di],bx
    @tmp:
    end;
    result:= retval;
end;

function ScatterUnlockRegion(fl:WORD;buf:PDDS):byte;
var retval:byte;
begin
retval := 0;
    asm
        mov     dx,fl
        mov     ax,8106h
        les     di,buf
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;


function DisableDMA(channel:word):byte;
var retval:byte;
begin
 retval := 0;
   asm
        mov     dx,0
        mov     ax,810bh
        mov     bx,channel
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;

function EnableDMA(channel:word):byte;
var retval:byte;
begin
 retval := 0;
   asm
        mov     dx,0
        mov     ax,810ch
        mov     bx,channel
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;

function CopyFromBuffer(buf:PDDS;ofs:longint):byte;
var retval:byte;
begin
    retval := 0;
    asm
        mov     dx,0
        mov     ax,810Ah
        les     di,buf
        mov     cx,word ptr ofs.[0]
        mov     bx,word ptr ofs.[2]
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;

function CopyToBuffer(buf:PDDS;ofs:longint):byte;
var retval:byte;
begin
    retval := 0;
    asm
        mov     dx,0
        mov     ax,8109h
        les     di,buf
        mov     cx,word ptr ofs.[0]
        mov     bx,word ptr ofs.[2]
        int     4bh
        jnc     @tmp
        mov     retval,al
    @tmp:
    end;
    result:= retval;
end;



{testing}





 function VDSLockDMARegion(flags16,es16,di16:word):byte; begin
{send the DDS structure location to the VDS}
     RRegs.ES:=es16;   {pointer}
     RRegs.DI:=di16;    {size}
     RRegs.AL:= $03;        { Lock DMA Region}
     RRegs.AH:= $81;
     RRegs.DX:= flags16;    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
{we have called an interrupt}
end;


 function VDSLockDMARegionPM(flags16,es16,di16:word):byte; begin
asm
MOV ES,es16
MOV DI,di16
MOV AL,$03
MOV AH,$81
MOV DX,flags16
Int $4b
end;
end;



function VDSUnLockDMARegion(flags16,es16,di16:word):byte; begin
{send the DDS structure location to the VDS}
     RRegs.ES:=es16;   {pointer}
     RRegs.DI:=di16;    {size}
     RRegs.AL:= $04;        { Unlock DMA Region}
     RRegs.AH:= $81;
     RRegs.DX:= flags16;    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
{we have called an interrupt}
end;

function VDSRequestDMABuffer(flags16,es16,di16:word):byte; begin
{send the DDS structure location to the VDS}
     RRegs.ES:=es16;   {pointer}
     RRegs.DI:=di16;    {size}
     RRegs.AL:= $07;        { Request DMA Buffer}
     RRegs.AH:= $81;
{     RRegs.DX:= flags16;}    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
{we have called an interrupt}
end;
function VDSReleaseDMABuffer(flags16,es16,di16:word):byte; begin
{send the DDS structure location to the VDS}
     RRegs.ES:=es16;   {pointer}
     RRegs.DI:=di16;    {size}
     RRegs.AL:= $08;        { Release DMA Buffer}
     RRegs.AH:= $81;
     RRegs.DX:= flags16;    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
{we have called an interrupt}
end;

function VDSDisableDMATranslation(flags16,bx16:word):byte; begin
     RRegs.AL:= $0B;        { Disable DMA Translation}
     RRegs.AH:= $81;
     RRegs.BX:= bx16;
     RRegs.DX:= flags16;    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
{we have called an interrupt}
end;

function VDSEnableDMATranslation(flags16,bx16:word):byte; begin
     RRegs.AL:= $0C;        { Enable DMA Translation}
     RRegs.AH:= $81;
     RRegs.BX:= bx16;
     RRegs.DX:= flags16;    {flags}
{call this interrupt!}
RealModeInt($4b,RRegs);
{we have called an interrupt}
end;



end.
