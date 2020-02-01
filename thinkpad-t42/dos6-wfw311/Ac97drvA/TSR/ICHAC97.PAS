{$S-,N-}
{$M 1024, 0, 0}
Program ICHAC97;

Uses
  Crt,Dos,xms;

VAR
  I       : LongInt;
  Result  : LongInt;
  Hdl     : Word;          { Handle for Extended memory allocated }
  HiMemOK : boolean;
  pciaddress:longint;
var T:text;
    Str:string;
    re:integer;
    x:byte;
    lng:longint;

Var SavedInt9Bh:Pointer;
Var low,high:word;


Procedure Int9Bh(AX, BX, CX, DX, SI, DI, DS, ES, BP:Word); interrupt;
begin
  ax:=low;
  bx:=high;
  cx:=$AC97
end;


begin
HiMemOK := XMSDriverLoaded;
 IF NOT HiMemOK THEN Halt;
  Hdl := XMSAllocateBlock(1024);{Round Up to next KB}
  for i:=0 to 64 do begin
    XMSMoveDataTo(@I, 4, Hdl,i*4);{Copy some numbers to that memory}
  end;
 str:='Reserved XMS 1024KB'+char(0);
 XMSMoveDataTo(@str, 20, Hdl,0);{Copy some text to that memory}
 pciaddress:=lock(Hdl);{Get Address}

low:=word(pciaddress);
high:=word(longint(pciaddress) shr 16);

  GetIntVec($9B, SavedInt9Bh);
  SetIntvec($9B, @Int9Bh);
  Writeln('TSR installed.');
  Keep(0);
end.
