(* Example for use of DPMI-Calls to serve a hardware interrupt
   from Delphi 1
   Change the follwing routines to adapt to special device:
     InitIRQ    (enable interrupt from device)
     ReleaseIRQ (disable interrupt from device)
     RMInt      (interrupt service routine)
   The following demo program shows the use for input from
   serial interface (COM-port with UART of type 8250). Only few
   changes are necessary to adapt to othjer devices (see below).

   J. Rathlev, Uni-Kiel, Apr. 1998

   see : W. Oney, Systemprogrammierung f. Windows
         DPMI-Spec. Vers. 0.9
*)
unit IntDemo;

interface

uses WinTypes, Messages, WinProcs, DPMI1,dialogs,usbdefs,vds;
var xWING,yWING,zWING,bWING:longint;
var m1,m2,m3,m4,m5,m6:word;
var datalpProtMode:array[0..255] of byte;
var things:longint;
var locked:integer;
const
  errOK         = 0;    { no error on init }
  errIRQ        = 1;    { no interrupt specified }
  errSegment    = 2;    { lock segment error }

  wmCharReceived = wm_User+1; { message when character is received }
  wmusbddd= wm_user+2;{usb device descriptor}
var
  IRQCnt   : word;  (* for testing *)
  LastChar : char;
var bob:byte;
  var aa88,bb88,cc88,dd88:word;
function InitIRQ(APortAdr,AIntNr : word;
                 Handle : HWnd) : word;
function Initcb1(Handle : HWnd) : pointer;
function Initcb2(Handle : HWnd) : pointer;
function Initcb3(Handle : HWnd) : pointer;
function Initcb4(Handle : HWnd) : pointer;
function Initcb5(Handle : HWnd) : pointer;
function Initcb6(Handle : HWnd) : pointer;
procedure ReleaseIRQ;
function Releasecb(callback:pointer):byte;



 {
  ;----------------------------------------------------------------------------
  ;Offset in InfoTable of Last Device we found (needed to print Descriptors)
  ;----------------------------------------------------------------------------
}
 var LastDeviceFound :word; {DeviceInfoTable}

 {
  ;----------------------------------------------------------------------------
  ;Stage & Error Code where New Device search failed (for troubleshooting)
  ;For even stages < 200, the Error is a TD Status Error Code.
  ;  These are the ones generally caused by Devices that don't respond
  ;  like they're expected to.
  ;For odd stages < 200, the Error is an INT 14h Call Error Code.
  ;  These are generally cause by faulty code, and should not appear
  ;  in final, bug-less released of program.
  ;For stages >= 200, the "Error" is not related to an INT 14h or TD at all.
  ;  These are other kinds of Errors, usually caused by a value in one
  ;    of the Descriptors that we don't undertand how to handle.  The
  ;    "Error Code" in these instances is usually meaningless.
  ;Categorizing the Error Codes like this allows us to easily write a more
  ;  complete and meaningful description of the Bad Device Error.  It is
  ;  still necessary to look at the source code to REALLY figure out what's
  ;  going on, but the information provided is better than just writing
  ;  the raw Error Code numbers.
  ;----------------------------------------------------------------------------
}

var  NewDeviceStage :byte;
     NewDeviceError :word;



{;==============================================================================
;Data needed to Decipher an HID Report Descriptor
;==============================================================================}
var
  UsagePage    :word;
  Usage        :word;
  Collection   :word;
  ReportSize   :word;
  ReportCount  :word;
  Input        :word;
  UsageMin     :word;
  UsageMax     :word;
  LogicalMin   :word;
  LogicalMax   :word;
  PhysicalMin  :word;
  PhysicalMax  :word;
  Unitu         :word;
  UnitExponent :word;
  IOFValue     :word; {Input/Out/Feature value}




var lpProtModePtr:PInt14RequestStruc;
var lpRealModePtr:longint;

Type
Pstr = ^Istr;
Istr = Record
test:array[0..16000]of longint;     { bytes of data}
ax:word;
bx:word;
cx:word;
dx:word;
end;

Type
bstr = ^bIstr;
bIstr = Record
test:array[0..64000]of byte;     {// bytes of data}
ax:word;
bx:word;
cx:word;
dx:word;
end;
Type
wstr = ^wIstr;
wIstr = Record
test:array[0..512]of word;     {//bytes of data}
end;


var lpProtModePtr2:pstr;
var lpRealModePtr2:longint;
var lpdhold:array[0..255] of byte;



var lpProtModePtr3:wstr;
var lpRealModePtr3:longint;


implementation

Function RealMode : Boolean; assembler;
asm
  mov     ax, 01686h
  int     02Fh
end;

procedure RMInte (SI,DI,DS,ES,BP : word); far; external 'callback';
const
  HwMsk   : byte = 0;    { IRQ Mask }
  IntCtlAdr = $20;       { Portaddress of Int.-Contr. }
  Int2CtlAdr = $A0;      { Portaddress of 2.Int.-Contr. }
  IntMskAdr = $21;       { Portaddress of Int.-Maskreg. }
  Int2MskAdr = $21;      { Portaddress of 2.Int.-Maskreg. }
  EOI = $20;             { end of interrupt }

  { 8250 Register }
  IER     =     1;       {  Interrupt Enable Register }
  IIR     =     2;       {  Interrupt Identification Register }
  LCR     =     3;       {  Line Control Register }
  MCR     =     4;       {  MODEM Control Register }
  LSR     =     5;       {  Line Status Register }
  MSR     =     6;       {  MODEM Status Register }

var
  PortAdr,                { I/O-Port }
  HwInt       : word;     { IRQ Number }
  I2Ctrl      : boolean;  { 1./2. IRQ-Controller }
  OldInt      : pointer;  { old real mode interrupt routine }
  RmRegs      : TRealModeRegs;  { real mode register structure }
  MainHandle  : HWnd;      { handle of main program }

(* -------------------------------------------------------------------------
   Real Mode Interrupt Routine *)
procedure RMInt (SI,DI,DS,ES,BP : word); interrupt;
var
  Status : byte;
  Stack : ^StackArr;
  rmr   : ^TRealModeRegs;
begin
  inc (IRQCnt);   (* count for demo *)
  (* device interrupt service
     Printer port:
       Port[$378+1]:=$11;       { set bit 1 (STB) }
       Port[$378+1]:=$10;       { clear bit 1 (STB) -> clear int. }
     COM-Port:
       St:=Port[$3F8/2F8+LSR] and $1E;  { line status }
       Ch:=chr(Port[$3F8/2F8]);         { received character }
     *)
  Status:=Port[PortAdr+LSR] and $1E;
  LastChar:=chr(Port[PortAdr]);       { get received character }
  Port[PortAdr]:=ord(LastChar);       { echo }

  (* Post message for main program *)
  PostMessage (MainHandle,wmCharReceived,ord(LastChar),IRQCnt);

  (* device independent part of interrupt routine *)
  Stack:=Ptr(ds,si);
  rmr:=Ptr(es,di);
  Port[IntCtlAdr]:=EOI;
  if I2Ctrl then Port[Int2CtlAdr]:=EOI;

  (* set real mode cp:ip, update stack pointer
     (DPMI-Spez. Vers. 0.9, chap. 11.4 *)
  with rmr^ do begin
    ip:=Stack^[0];
    cs:=Stack^[1];
    flags:=Stack^[2];
    inc(sp,6);
    end;
  end;

function ssound(mhz : integer):byte;
{mhz = the frequency of the pc speaker}
 var   count    : word;   oldport,   newport  : byte;
  begin


    count := 1193280 div mhz;
    asm
      mov al,$b6
      out $43,al
      mov ax,count
      out $42,al
      mov al,ah
      out $42,al
      mov al,3
      out $61,al
    end;
    end;

function  nosound(tb:byte):byte;
  begin
    asm
      mov al,0
      out $61,al
    end;
  end;

Procedure DPMI_Call_Back6(Flags, AX, BX, CX, DX, SI, DI, DS, ES, BP:
Word); Interrupt;
var
  DPMIReg:^TRealModeRegs;

begin
  DPMIReg:=Ptr(ES,DI);
  { Return CS OK }
  DPMIReg^.AX:=0;
  DPMIReg^.Flags:=DPMIReg^.Flags and not 1;
  { Now fake return as per the DPMI spec }
  DPMIReg^.IP:=PWord(ptr(DS,SI))^;  {DS:SI is prot mode version of SS:SP}
  DPMIReg^.CS:=PWord(ptr(DS,SI+2))^;
  Inc(DPMIReg^.SP,4);  { And fake the popping on the realmode IP, add 4 }
  aa88:=DPMIReg^.dx;
  bb88:=DPMIReg^.cx;
  cc88:=DPMIReg^.bx;
  dd88:=DPMIReg^.ax;
asm
mov ax,aa88
mov bx,bb88
mov cx,cc88
mov dx,dd88
         int 128
end;
end;



Procedure DPMI_Call_Back5(Flags, AX, BX, CX, DX, SI, DI, DS, ES, BP:
Word); Interrupt;
var
  DPMIReg:^TRealModeRegs;
begin
  DPMIReg:=Ptr(ES,DI);
  { Return CS OK }
  DPMIReg^.AX:=0;
  DPMIReg^.Flags:=DPMIReg^.Flags and not 1;
  { Now fake return as per the DPMI spec }
  DPMIReg^.IP:=PWord(ptr(DS,SI))^;  {DS:SI is prot mode version of SS:SP}
  DPMIReg^.CS:=PWord(ptr(DS,SI+2))^;
  Inc(DPMIReg^.SP,4);  { And fake the popping on the realmode IP, add 4 }
  aa88:=DPMIReg^.dx;
  bb88:=DPMIReg^.cx;
  cc88:=DPMIReg^.bx;
  dd88:=DPMIReg^.ax;
asm
{mov ax,aa88
mov bx,bb88
mov cx,cc88
mov dx,dd88}
         int 127
end;
{now we try dangerous STUFF}
move(lpprotmodeptr2^,datalpprotmode,1);
m1:=datalpprotmode[0];
{m2:=datalpprotmode[1];
m3:=datalpprotmode[2];
m4:=datalpprotmode[3];
m5:=datalpprotmode[4];
m6:=datalpprotmode[5];}

{joystick
xWING:=(byte(datalpprotmode[1] shl 6) shl 2)+datalpprotmode[0];
yWING:=(datalpProtmode[1] shr 2)+((byte(byte(datalpProtmode[2] shl 4) shr 4)) shl 6);
bWING:=datalpProtmode[4];
zWING:=datalpProtmode[5];}

end;
Procedure DPMI_Call_Back4(Flags, AX, BX, CX, DX, SI, DI, DS, ES, BP:
Word); Interrupt;
var
  DPMIReg:^TRealModeRegs;

begin
  DPMIReg:=Ptr(ES,DI);
  { Return CS OK }
  DPMIReg^.AX:=0;
  DPMIReg^.Flags:=DPMIReg^.Flags and not 1;
  { Now fake return as per the DPMI spec }
  DPMIReg^.IP:=PWord(ptr(DS,SI))^;  {DS:SI is prot mode version of SS:SP}
  DPMIReg^.CS:=PWord(ptr(DS,SI+2))^;
  Inc(DPMIReg^.SP,4);  { And fake the popping on the realmode IP, add 4 }
  aa88:=DPMIReg^.dx;
  bb88:=DPMIReg^.cx;
  cc88:=DPMIReg^.bx;
  dd88:=DPMIReg^.ax;
asm
{mov ax,aa88
mov bx,bb88
mov cx,cc88
mov dx,dd88       }
         int 126
end;
end;
Procedure DPMI_Call_Back3(Flags, AX, BX, CX, DX, SI, DI, DS, ES, BP:
Word); Interrupt;
var
  DPMIReg:^TRealModeRegs;

begin
  DPMIReg:=Ptr(ES,DI);
  { Return CS OK }
  DPMIReg^.AX:=0;
  DPMIReg^.Flags:=DPMIReg^.Flags and not 1;
  { Now fake return as per the DPMI spec }
  DPMIReg^.IP:=PWord(ptr(DS,SI))^;  {DS:SI is prot mode version of SS:SP}
  DPMIReg^.CS:=PWord(ptr(DS,SI+2))^;
  Inc(DPMIReg^.SP,4);  { And fake the popping on the realmode IP, add 4 }
  aa88:=DPMIReg^.dx;
  bb88:=DPMIReg^.cx;
  cc88:=DPMIReg^.bx;
  dd88:=DPMIReg^.ax;
asm
{mov ax,aa88
mov bx,bb88
mov cx,cc88
mov dx,dd88}
         int 125
end;

end;
Procedure DPMI_Call_Back2(Flags, AX, BX, CX, DX, SI, DI, DS, ES, BP:
Word); Interrupt;
var
  DPMIReg:^TRealModeRegs;

begin
  DPMIReg:=Ptr(ES,DI);
  { Return CS OK }
  DPMIReg^.AX:=0;
  DPMIReg^.Flags:=DPMIReg^.Flags and not 1;
  { Now fake return as per the DPMI spec }
  DPMIReg^.IP:=PWord(ptr(DS,SI))^;  {DS:SI is prot mode version of SS:SP}
  DPMIReg^.CS:=PWord(ptr(DS,SI+2))^;
  Inc(DPMIReg^.SP,4);  { And fake the popping on the realmode IP, add 4 }
  aa88:=DPMIReg^.dx;
  bb88:=DPMIReg^.cx;
  cc88:=DPMIReg^.bx;
  dd88:=DPMIReg^.ax;
asm
{mov ax,aa88
mov bx,bb88
mov cx,cc88
mov dx,dd88}
         int 125
end;
  { other idea to end function
  Regs.IP:=memw[DS:SI];
  Regs.CS:=memw[DS:SI+2];
  inc(Regs.SP,6);
  }
end;


Procedure DPMI_Call_Back1(Flags, AX, BX, CX, DX, SI, DI, DS, ES, BP:
Word); Interrupt;
var
  DPMIReg:^TRealModeRegs;

begin
  DPMIReg:=Ptr(ES,DI);
  { Return CS OK }
  DPMIReg^.AX:=0;
  DPMIReg^.Flags:=DPMIReg^.Flags and not 1;
  { Now fake return as per the DPMI spec }
  DPMIReg^.IP:=PWord(ptr(DS,SI))^;  {DS:SI is prot mode version of SS:SP}
  DPMIReg^.CS:=PWord(ptr(DS,SI+2))^;
  Inc(DPMIReg^.SP,4);  { And fake the popping on the realmode IP, add 4 }
  aa88:=DPMIReg^.dx;
  bb88:=DPMIReg^.cx;
  cc88:=DPMIReg^.bx;
  dd88:=DPMIReg^.ax;
asm
{mov ax,aa88
mov bx,bb88
mov cx,cc88
mov dx,dd88}
         int 124
end;
end;



Procedure My_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 123
end;
Procedure Yi_Call_Back(rAX, rBX, rCX, rDX, rSI, rDI, rDS, rES, rBP:Word); assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 124
end;
{first wave}
Procedure Zi_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 125
end;
Procedure Ai_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 126
end;
Procedure Bi_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 127
end;
Procedure Ci_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 128
end;
{second wave}
Procedure DC1_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 129
end;

Procedure DC2_Call_Back; assembler;
asm
         cld
         lodsw
         mov      WORD PTR es:[di+2Ah], ax
         lodsw
         mov      WORD PTR es:[di+2Ch], ax
         add      WORD PTR es:[di+2Eh], 4
         int 130
end;



procedure RMInt2 (SI,DI,DS,ES,BP : word); interrupt;
var
  Status : byte;
  Stack : ^StackArr;
  rmr   : ^TRealModeRegs;
begin
   { get info received }
  (* Post message for main program *)
    PostMessage (MainHandle,wmCharReceived,ord(32),33);
  (* device independent part of interrupt routine *)
  Stack:=Ptr(ds,si);
  rmr:=Ptr(es,di);
  Port[IntCtlAdr]:=EOI;
  (* set real mode cp:ip, update stack pointer
     (DPMI-Spez. Vers. 0.9, chap. 11.4 *)
  with rmr^ do begin
    ip:=Stack^[0];
    cs:=Stack^[1];
    flags:=Stack^[2];
    inc(sp,6);
    end;
  end;


procedure getback;interrupt;
begin
things:=things+1;
showmessage('test');

end;







(* -------------------------------------------------------------------------
  Init interface for use of hardware interrupt:
  APortAdr:  address of port from which interrupt is generated
             (e.g. $3F8 (COM1),
                   $2F8 (COM2),
                   $378 (LPT1),
                   $278 (LPT2)
  AIntNr:    number of used hardware interrupt
             (e.g. 4 (COM1),
                   3 (COM2),
                   7 (LPT1),
                   5 (LPT2))
             interrupt from 2nd controller (9,10,11,..) are supported
  Handle:    handle of main program *)
function InitIRQ(APortAdr,AIntNr : word;
                 Handle : HWnd) : word;
var
  i  : integer ;
  cb : byte;
begin
  if (LockSegment(CSeg)<>0) and (LockSegment(DSeg)<>0) then begin
    if AIntNr>0 then begin
      (* Enable interrupt service for device:
         Printer port:
           Port[$378+2]:=$10;       { set bit 4 (IEN) }
         COM-Port (COM1/COM2):
           Port[$3F8/2F8+MCR]:=$0B;   { set DTR, RTS and OUT2 }
           Port[$3F8/2F8+IER]:=1;     { enable interrupt for received data }
         *)

      PortAdr:=APortAdr;
      (* set baud rate etc. *)
      Port[PortAdr+LCR]:=$80;       { set DLAB }
      Port[PortAdr]:=24;            { 4800 baud }
      Port[PortAdr+1]:=0;
      Port[PortAdr+LCR]:=3;         { n,8,1 }

      cb:=Port[PortAdr];            { clear receiver buffer reg. }

      (* set DTR, RTS and OUT2, enable receive interrupt *)
      Port[PortAdr+MCR]:=$0B;
      Port[PortAdr+IER]:=1;
      LastChar:=#0;
      IRQCnt:=0;

      (* save interrupt number and mask *)
      HwInt:=AIntNr; I2Ctrl:=HwInt>=8;
      if I2Ctrl then begin   (* 2. Contr. *)
       dec(AIntNr,8);
       InitRmInt (HwInt+$68,@RMInt,RmRegs,OldInt)
       end
      else InitRmInt (HwInt+8,@RMInt,RmRegs,OldInt);
      { set interrupt mask }
      HwMsk:=1 shl AIntNr;
      if I2Ctrl then Port[Int2MskAdr]:=Port[Int2MskAdr] and (not HwMsk)
      else Port[IntMskAdr]:=Port[IntMskAdr] and (not HwMsk);
      SetInt;
      InitIRQ:=errOK;
      MainHandle:=Handle;
      end
    else InitIRQ:=errIRQ;
    end
  else InitIRQ:=errSegment;
  end;







function Initcb1(Handle : HWnd) : pointer;
var
  i  : integer ;
  cb : byte;
  ptr:pointer;
begin
  if (LockSegment(CSeg)<>0) and (LockSegment(DSeg)<>0) then begin
      locked:=1;
       AllocRealModeCallbackAddr(@My_Call_Back,RmRegs,result);

      MainHandle:=Handle;
      end;

  end;


function Initcb2(Handle : HWnd) : pointer;
begin
{  if (LockSegment(CSeg)<>0) and (LockSegment(DSeg)<>0) then begin}
{      AllocRealModeCallbackAddr(@Yi_Call_Back,RmRegs,result);}
AllocRealModeCallbackAddr(@DPMI_Call_Back1,RmRegs,result);

      MainHandle:=Handle;
{      end;}
end;

function Initcb3(Handle : HWnd) : pointer;begin
{125}
{AllocRealModeCallbackAddr(@Zi_Call_Back,RmRegs,result);}
AllocRealModeCallbackAddr(@DPMI_Call_Back3,RmRegs,result);
end;
function Initcb4(Handle : HWnd) : pointer;begin
{AllocRealModeCallbackAddr(@Ai_Call_Back,RmRegs,result);  }
AllocRealModeCallbackAddr(@DPMI_Call_Back4,RmRegs,result);
end;
{here}
function Initcb5(Handle : HWnd) : pointer;begin
{AllocRealModeCallbackAddr(@Bi_Call_Back,RmRegs,result);}
AllocRealModeCallbackAddr(@DPMI_Call_Back5,RmRegs,result);

end;
function Initcb6(Handle : HWnd) : pointer;begin
{AllocRealModeCallbackAddr(@Ci_Call_Back,RmRegs,result);}
AllocRealModeCallbackAddr(@DPMI_Call_Back6,RmRegs,result);
end;





(* -------------------------------------------------------------------------
   Release hardware interrupt *)
procedure ReleaseIRQ;
begin
  if HwMsk>0 then begin (* restore interrupt vector *)
    (* Disable interrupt service for device:
       Printer port:
         Port[$378+2]:=0;         { clear bit 4 (IEN) }
       COM-Port:
         Port[$3F8/2F8+1]:=0;     { disable interrupt }
         Port[$3F8/2F8+4]:=0;     { clear DTR, RTS and OUT2 }
       *)
    Port[PortAdr+IER]:=0;
    Port[PortAdr+MCR]:=0;
    if I2Ctrl then begin
      Port[Int2MskAdr]:=Port[Int2MskAdr] or HwMsk;
      RlsRmInt (HwInt+$68,OldInt);
      end
    else begin
      Port[IntMskAdr]:=Port[IntMskAdr] or HwMsk;
      RlsRmInt (HwInt+8,OldInt);
      end;
    HwMsk:=0;
    end;
  UnLockSegment(CSeg); UnLockSegment(DSeg);
  end;




function Releasecb(callback:pointer):byte;
begin
  FreeRealModeCallbackAddr(Callback);
  locked:=locked-1;
{  if(locked=0)then begin}
  UnLockSegment(CSeg); UnLockSegment(DSeg);
{  end;}

end;

end.
