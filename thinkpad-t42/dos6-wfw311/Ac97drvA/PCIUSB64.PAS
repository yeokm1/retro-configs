{$S-,N-}
{$M 1024, 0, 0}
Program PCIUSB64;

Uses
  Crt,Dos;

Var SavedInt99h:Pointer;
Var segm,offs:word;

type datahold=record
a1:word;
a2:word;
a3:word;
a4:word;
a5:word;
a6:word;
a7:word;
a8:word;
a9:word;
a10:word;
a11:word;
a12:word;
a13:word;
a14:word;
a15:word;
a16:word;
a17:word;
a18:word;
a19:word;
a20:word;
a21:word;
a22:word;
a23:word;
a24:word;
a25:word;
a26:word;
a27:word;
a28:word;
a29:word;
a30:word;
a31:word;
a32:word;
a33:word;
a34:word;
a35:word;
a36:word;
end;
var dh:datahold;

Procedure Int99h(AX, BX, CX, DX, SI, DI, DS, ES, BP:Word); interrupt;
begin
  ax:=segm;
  bx:=offs;
  cx:=$FADE
end;


begin  
  GetIntVec($99, SavedInt99h);
  SetIntvec($99, @Int99h);
  Writeln('TSR installed.');
  segm:=seg(dh);
  offs:=ofs(dh);
  Keep(0);
end.