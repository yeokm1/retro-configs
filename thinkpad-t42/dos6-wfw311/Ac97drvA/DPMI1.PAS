(***********************************************************************
   Unit: DPMI.PAS
   Implementation of some DPMI-functions to Delphi
   J. Rathlev, Uni-Kiel, Apr. 1998

   The following functions are implemeted:
   - hook a protected mode call back into real mode interrupt
   - remove hooked interrupt
   - simulate real mode interrupt
   - enable virtual interrupt state
   - disable virtual interrupt state

   Using the first two functions allows to service a hardware interrupt
   from a Delphi program. The follwing example demonstrates the use of
   DPMI for this application:

  ***********************************************************************)

unit DPMI1;

interface

uses SysUtils;

type
  {*** Delphi errors ***}
  EInterruptError = class(Exception);
  EDPMIError = class(EInterruptError);

  (* real mode register structure for DPMI-interface *)
  TRealModeRegs = record
    case Integer of
      0: (EDI, ESI, EBP, EXX, EBX, EDX, ECX, EAX: Longint;
          Flags, ES, DS, FS, GS, IP, CS, SP, SS: Word);
      1: (DI, DIH, SI, SIH, BP, BPH, XX, XXH: Word;
          case Integer of
          0: (BX, BXH, DX, DXH, CX, CXH, AX, AXH: Word);
          1: (BL, BH, BLH, BHH, DL, DH, DLH, DHH,
              CL, CH, CLH, CHH, AL, AH, ALH, AHH: Byte));
    end;

    StackArr = array [0..2] of word;

(* hook a protected mode call back into real mode interrupt *)
procedure InitRmInt (IntNr      : byte;
                     NewInt     : pointer;
                     var RmRegs : TRealModeRegs;
                     var OldInt : pointer);

function AllocRealModeCallbackAddr(CallbackProc : Pointer;
                                     var Regs : TRealModeRegs;
                                     var Callback : Pointer) : Word;

function FreeRealModeCallbackAddr(Callback : Pointer) : Word;

(* remove hooked interrupt and restore old real mode interrupt *)
procedure RlsRmInt (IntNr  : byte;
                    OldInt : pointer);

(* simulate real mode interrupt *)
procedure RealModeInt (IntNr     : Byte;
                       var RmRegs: TRealModeRegs);

(* enable virtual interrupt state *)
procedure ClrInt;

(* disable virtual interrupt state *)
procedure SetInt;


implementation
const
  (* Fehlermelduungen *)
  DPMIError = 'Failed to execute DPMI interrupt';


{************************************************************************}
{***    DPMI-Interface                                                ***}
{************************************************************************}

(* ----------------------------------------------------------------------- *)
(* hook a protected mode call back into real mode interrupt
   IntNr:  number of interrupt to hook
   NewInt: address of Delphi interrupt routine
   RmRegs: address of real mode register structure
   OldInt: address of old real mode interrupt routine
           This address should be restored before closing the
           application by calling RlsRmInt *)
procedure InitRmInt (IntNr      : byte;
                     NewInt     : pointer;
                     var RmRegs : TRealModeRegs;
                     var OldInt : pointer);
begin
  asm
    push ds
    les  di,RmRegs          { Address to register struckture }
    lds  si,NewInt          { Address of prot. mode routine }
    mov  ax, 0303h
    int  31h
    pop  ds
    push dx                 { Real mode interrupt address }
    push cx

    mov  ax,$200            { save old interrupt vector }
    mov  bl,IntNr
    int  $31
    les  di,OldInt
    mov  es:[di],dx
    mov  es:[di+2],cx

    mov  ax,$201             { set new interruptvektor }
    mov  bl,IntNr
    pop  cx
    pop  dx
    int  $31
    end;
  end;

(* ----------------------------------------------------------------------- *)
(* remove hooked interrupt and restore old real mode interrupt *)
procedure RlsRmInt (IntNr  : byte;
                    OldInt : pointer);
begin
  asm
    mov  ax,$201             { set old interruptvektor }
    mov  bl,IntNr
    mov  dx,word ptr OldInt
    mov  cx,word ptr OldInt+2
    int  $31
    end;
  end;

(* ----------------------------------------------------------------------- *)
(* simulate real mode interrupt *)
procedure RealModeInt (IntNr      : Byte;
                       var RmRegs : TRealModeRegs);
var
  ErrorFlag: Boolean;
begin
  asm
    mov  ErrorFlag, 0       { assume success }
    mov  ax,0300h
    mov  bl,IntNr
    mov  bh,0
    mov  cx,0               { stack words to copy, assume zero }
    les  di,RmRegs          { es:di = register structure }
    int  31h
    jnc  @@End              { carry flag set on error }
    mov  ErrorFlag, 1
  @@End:
  end;
  if ErrorFlag then
    raise EDPMIError.Create(DPMIError);
end;

(* ----------------------------------------------------------------------- *)
(* enable virtual interrupt state *)
procedure ClrInt;
begin
  asm
    mov ax,$900
    int $31
    end;
  end;

(* ----------------------------------------------------------------------- *)
(* disable virtual interrupt state *)
procedure SetInt;
begin
  asm
    mov ax,$901
    int $31
    end;
  end;

{example 1}
  function AllocRealModeCallbackAddr(CallbackProc : Pointer;
                                     var Regs : TRealModeRegs;
                                     var Callback : Pointer) : Word; Assembler;
  asm
    push    ds
    lds     si,CallbackProc
    les     di,Regs
    mov     ax,0303h
    int     31h
    jnc     @@Exitpoint
    xor     cx,cx
    xor     dx,dx
    jmp     @@ExitPoint2
  @@ExitPoint:
    xor     ax,ax
  @@ExitPoint2:
    les     di,Callback
    mov     word ptr es:[di],dx
    mov     word ptr es:[di+2],cx
    pop     ds
  end;

{example 2}
  function AllocCallback (Proc: Pointer; var Regs: TRealModeRegs): Pointer;
  assembler;

asm
      PUSH    DS
      LDS     SI,Proc
      LES     DI,Regs
      MOV     AX,0303H
      INT     31H
      POP     DS
      XCHG    AX,CX
      XCHG    AX,DX
      JNC     @@1
      XOR     AX,AX
      CWD
@@1:
end;

  {example 1}
  function FreeRealModeCallbackAddr(Callback : Pointer) : Word; Assembler;
  asm
    mov     cx,word ptr Callback+2
    mov     dx,word ptr Callback
    mov     ax,0304h
    int     31h
    jc      @@ExitPoint
    xor     ax,ax
  @@ExitPoint:
  end;

  {example 2}
function FreeCallback (Callback: Pointer): Boolean; assembler;

asm
      MOV     DX,Callback.Word[0]
      MOV     CX,Callback.Word[2]
      MOV     AX,0304H
      INT     31H
      SBB     AX,AX
      INC     AX
end;

end.