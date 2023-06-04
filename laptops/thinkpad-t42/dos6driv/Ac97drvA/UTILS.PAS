unit Utils;

interface
uses forms,SysUtils, WinTypes, WinProcs, Classes, Controls;

function MapPhysicalToLinear(dwphysical,dwlength:pointer):pointer;export;
function CreateHugePointer (dwLinearBase,dwLength:POINTER):pointer;export;
procedure HugeInc(var HugePtr: Pointer; Amount: LongInt); export;
procedure HugeDec(var HugePtr: Pointer; Amount: LongInt); export;

function getPCIvendorid(num:string):string;
function getUSBvendorid(num:string):string;
procedure delay(t:longint);export;
procedure freeze(t:longint);export;
function bins16(xx:word):String;export;
function freeRealModePointer(var p: pointer): boolean;export;
function allocRealModePointer(var P: pointer; Size: longInt): boolean;export;
function bins8(xx:byte):String;export;
implementation
    procedure HugeShift; far; external 'KERNEL' index 113;
    procedure hmemcpy(p1, p2: Pointer; L: Longint); far; external 'KERNEL';


function bins8(xx:byte):String;
var ss:String[32];
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



Function NewSelector(Base,Limit:longint) : Word;
Var Sel : Word;
Begin
  Sel := AllocSelector(0);
  If (sel<>0) and (setSelectorBase(sel,base)=sel) and (setSelectorLimit(sel,
limit)=0)
    then newSelector:=sel
    else newSelector:=0;
End;



function allocRealModePointer(var P: pointer; Size: longInt): boolean;
var
  Selector,
  base : word;
  LinearBase : longint;
begin
  result := false;
  LinearBase := MakeLong(0,hiword(longint(p)) shr 12) +
                  hiword(longint(P)) shl 4 + loword(longint(P));
                  {converts 20-bit address into a 32-bit one}
                  {i.e. $ffff:0006 into $000ffff6}
  Selector := AllocSelector(DSeg); {Copies DSeg Selector properties }
  base := SetSelectorBase(Selector, LinearBase);
  SetSelectorLimit(Selector, Size);
  if (Selector <> 0) and (base<>0) then  begin
    P := Ptr(Selector, 0);
    result := true;
  end;
end;

function freeRealModePointer(var p: pointer): boolean;
var
  fr : Word;
begin
  fr := FreeSelector(hiword(longint(p)));
  {seletor is at hiword(p)}
  if (fr=0) then begin {ok}
    p := nil;
    result := true;
  end else begin	{fail}
    result := false;
  end;
end;

{ code Test:    The Rom-Bios' date is allways at $ffff:0005 (real-mode)}
{
var
  P: pChar;
begin
  P := Ptr($FFFF, $0005);   {FFFF5 -> data da Rom-Bios
  if AllocRealModePointer(Pointer(p), 8) then 8 chars to RomBios' date
  begin
     Use p to read ROM Bios' date here
    FreeRealModePointer(Pointer(p));   dispose p
  end;

 }


function HiByte(A: Word): Byte;
inline(
  $58/       { POP AX    }
  $8A/$C4/   { MOV AL,AH }
  $32/$E4);  { XOR AH,AH }

function LoByte(A: Word): Byte;
inline(
  $58/       { POP AX    }
  $32/$E4);  { XOR AH,AH }





function bins16(xx:word):String;
var ss:String[32];
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
result:=ss;
end;


procedure delay(t:longint);
var x,y,z:longint;
begin
x:=0;
while x<t do begin
y:=gettickcount;
application.processmessages;
if(z<>y)then begin
z:=y;x:=x+1;
end;
end;
end;

procedure freeze(t:longint);
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


{for the pci buss}
function getPCIvendorid(num:string):string;
var venid:tstringlist;
{var venidFFFF:TS_StringList;}
begin
result:='';
if(fileexists('vendorid.pci'))then begin
venid:=TStringList.create;
venid.loadfromfile('vendorid.pci');
result:=venid.values[num];
if(result='')then begin end else
result:=' ('+result+')';
venid.free;
end;
end;


{for the USB buss}
function getUSBvendorid(num:string):string;
var venid:tstringlist;
{var venidFFFF:TS_StringList;}
begin
result:='';
if(fileexists('vendorid.usb'))then begin
venid:=TStringList.create;
venid.loadfromfile('vendorid.usb');
result:=venid.values[num];
if(result='')then begin end else
result:=' ('+result+')';
venid.free;
end;
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




end.
