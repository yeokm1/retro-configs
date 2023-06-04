unit Misc;

interface
uses
  WinProcs,WinTypes,mmsystem;
function MapPhysicalToLinear(dwphysical,dwlength:pointer):pointer;export;
function CreateHugePointer (dwLinearBase,dwLength:POINTER):pointer;export;
procedure HugeInc(var HugePtr: Pointer; Amount: LongInt); export;
procedure HugeDec(var HugePtr: Pointer; Amount: LongInt); export;
procedure mmdelay1(t:longint);export;
procedure delay1(t:longint);export;
implementation


    procedure HugeShift; far; external 'KERNEL' index 113;

procedure delay1(t:longint);
var x,y,z:longint;
begin
x:=0;
while x<t do begin
y:=gettickcount;
if(z<>y)then begin
z:=y;x:=x+1;
end;
end;
end;
procedure mmdelay1(t:longint);
var x,y,z:longint;
begin
x:=0;
while x<t do begin
y:=timegettime;
if(z<>y)then begin
z:=y;x:=x+1;
end;
end;
end;



function MapPhysicalToLinear(dwphysical,dwlength:pointer):pointer;
var dwlinear:longint;
var xa:word;
begin
{this should be able to map up to 4 gigabytes}
{reads memory from pci cards also}
if(hiword(longint(dwphysical))>0)then
begin

asm
    push    di
              push    si
              mov     bx, WORD PTR [dwPhysical+2] {; Load arguments.}
              mov     cx, WORD PTR [dwPhysical]
              mov     si, WORD PTR [dwLength+2]
              mov     di, WORD PTR [dwLength]
              mov     ax, 800h
              int     31h                         {; Issue DPMI call.}
              jnc     @fine_return
              xor     bx, bx                     { ; zero out return}
              mov     cx, bx                     { ; regs on error}
      @fine_return:
              mov     WORD PTR [dwLinear+2], bx  { ; Return value.}
              mov     WORD PTR [dwLinear], cx
              pop     si
              pop     di
end;
end else begin {showmessage('small!');}end;
result:=pointer(dwlinear);
end;

function DPMISetSelectorLimit(selector:word;dwlimit:longint):boolean;
begin
result:=true;
asm
         mov  ax, 0008h
         mov  bx, selector
         mov  cx, word ptr [dwLimit+2]
         mov  dx, word ptr [dwLimit]
         int  31h
         jnc  @success
         mov result,0
       @success:
end;
end;

function CreateHugePointer (dwLinearBase,dwLength:POINTER):pointer;
   var
      tempSelector:word;
      codeSelector:word;
      dataSelector:word;
      dwLimit:longint;
     begin
      if(dwLength = ptr(0,0))then begin  result:=ptr(0,0);end;
      dwLimit := longint(dwLength) -1;
      asm
         mov ax, cs
         mov codeSelector, ax
      end;
      tempSelector := AllocSelector(codeSelector);
      if (tempSelector=0)then begin  result:=nil;end;
      if (PrestoChangoSelector (codeSelector, tempSelector)>1)then
         begin
         SetSelectorBase(tempSelector, longint(dwLinearBase));
         DPMISetSelectorLimit(tempSelector, dwLimit);
{         SetSelectorLimit(tempSelector, dwLimit);}
         dataSelector := AllocSelector(tempSelector);
         end else
         dataSelector := 0;
      DPMISetSelectorLimit(tempSelector, 0);
      FreeSelector(tempSelector);
      result:= pointer(MAKELONG(0, dataSelector));
   end;

procedure HugeInc(var HugePtr: Pointer; Amount: LongInt); assembler;
asm
  mov ax, Amount.Word[0]    { Store Amount in DX:AX. }
  mov dx, Amount.Word[2]
  les bx, HugePtr           { Get the reference to HugePtr. }
  add ax, es:[bx]           { Add the offset parts. }
  adc dx, 0                 { Propagate carry to the high word of Amount. }
  mov cx, Offset HugeShift
  shl dx, cl                { Shift high word of Amount for segment. }
  add es:[bx+2], dx         { Increment the segment of HugePtr. }
  mov es:[bx], ax
end;


{ Decrement a huge pointer. }
procedure HugeDec(var HugePtr: Pointer; Amount: LongInt); assembler;
asm
  les bx, HugePtr         { Store HugePtr ptr in es:[bx] }
  mov ax, es:[bx]
  sub ax, Amount.Word[0]  { Subtract the offset parts }
  mov dx, Amount.Word[2]
  adc dx, 0               { Propagate carry to the high word of Amount }
  mov cx, OFFSET HugeShift
  shl dx, cl              { Shift high word of Amount for segment }
  sub es:[bx+2], dx
  mov es:[bx], ax
end;




function bins32(xx:longint):String;
var ss:String[64];
    h1,h2:Byte;
begin
ss:='';
  h1:=32;
  repeat
    dec(h1);
    h2:=(xx shr h1) and $1;
    h2:=h2+48;
    ss:=ss+chr(h2);
  until h1=0;
bins32:=ss;
end;

function bins16(xx:longint):String;
var ss:String[64];
    h1,h2:Byte;
begin
ss:='';
  h1:=16;
  repeat
    dec(h1);
    h2:=(xx shr h1) and $1;
    h2:=h2+48;
    ss:=ss+chr(h2);
  until h1=0;
bins16:=ss;
end;

function bins8(xx:longint):String;
var ss:String[64];
    h1,h2:Byte;
begin
ss:='';
  h1:=8;
  repeat
    dec(h1);
    h2:=(xx shr h1) and $1;
    h2:=h2+48;
    ss:=ss+chr(h2);
  until h1=0;
bins8:=ss;
end;



function inttobin(Value: Longint): string;
var
  Ch: Char;

begin
   result:='';
  repeat
    Ch :='0';
    Inc(Ch, Value mod 2);
    if Ch >'9' then Inc(Ch, 7);
    Insert( Ch, Result, 1);
    Value :=Value div 2;
  until Value =0;
end;


function inport32(portnum:word):longint;begin
asm
mov dx,portnum
db 66h; in ax,dx;{in eax,edx}
db 66h; mov word ptr result,ax{mov var,eax}
end;
end;

procedure outport32(portnum:word;value:longint);begin
asm
mov dx,portnum
db 66h; mov ax, word ptr value  { mov eax, ... }
db 66h; out dx,ax               { out dx,eax  }
end;
end;


end.
 