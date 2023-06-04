UNIT XMS;
(**) INTERFACE (**)
VAR
  XMSErrorCode : byte;     { Error Code - Defined in XMS Spec }
  XMSAddr      : Pointer;  { Entry Point for HIMEM.SYS Driver }

FUNCTION XMSDriverLoaded: Boolean;
FUNCTION XMSTotalMemoryAvailable: Word;
FUNCTION XMSLargestBlockAvailable: Word;
FUNCTION XMSAllocateBlock(KBSize: Word): Word;
FUNCTION XMSReleaseBlock(Handle: Word): Boolean;
FUNCTION XMSMoveDataTo(SourceAddr: Pointer; NumBytes: LongInt;
           XMSHandle: Word; XMSOffset: LongInt): Boolean;
FUNCTION XMSGetDataFrom(XMSHandle: Word; XMSOffset: LongInt;
           NumBytes: LongInt; LowMemAddr: Pointer): Boolean;
Function lock(h : Word) : LongInt;
(**) IMPLEMENTATION (**)

TYPE
  XMSMoveStruct = record
    movelen   : LongInt;   { length of block to move in bytes }
    case integer of
      { Case 0 Variant for Low Memory to XMS }
      0: (SHandle   : Word;      { source handle = 0
                                   for conventional memory }
          SPtr      : pointer;   { source address }
          XMSHdl    : Word;      { XMS destination handle }
          XMSOffset : LongInt);  { 32 bit XMS offset }
      { Case 1 Variant for XMS to Low Memory }
      1: (XMSH      : Word;      { XMS source handle }
          XMSOfs    : LongInt;   { starting offset in XMS}
          DHandle   : Word;      { 0 when conventional memory
                                   destination }
          DPtr      : pointer);  { address in conventional memory }
    END;

VAR moveparms : XMSMoveStruct;   { structure for moving to and
                                   from XMS }

{**************************************************************}
{ XMSDriverLoaded - Returns true IF Extended Memory Driver     }
{                   HIMEM.SYS Loaded                           }
{                 - Sets Entry Point Address - XMSAddr         }
{**************************************************************}
FUNCTION XMSDriverLoaded: Boolean;
CONST
  himemseg: Word = 0;
  himemofs: Word = 0;
BEGIN
  XMSErrorCode := 0;
  ASM
    mov ax,4300h      { Check to see IF HIMEM.SYS installed }
    int 2fh
    cmp al,80h        { Returns AL = 80H IF installed }
    jne @1
    mov ax,4310h      { Now get the entry point }
    int 2fh
    mov himemofs,bx
    mov himemseg,es
  @1:
  END;
  XMSDriverLoaded := (himemseg <> 0);
  XMSAddr := Ptr(himemseg,himemofs);
END;

{**************************************************************}
{ XMSTotalMemoryAvailable - Returns Total XMS Memory Available }
{**************************************************************}
FUNCTION XMSTotalMemoryAvailable: Word;
BEGIN
  XMSErrorCode := 0;
  XMSTotalMemoryAvailable := 0;
  IF XMSAddr = nil THEN        { Check IF HIMEM.SYS Loaded }
    IF NOT XMSDriverLoaded THEN exit;
  ASM
    mov  ah,8
    call XMSAddr
    or   ax,ax
    jnz  @1
    mov  XMSErrorCode,bl  { Set Error Code }
    xor  dx,dx
    @1:
    mov  @Result,dx       { DX = total free extended memory }
  END;
END;

{**************************************************************}
{ XMSLargestBlockAvailable - Returns Largest Contiguous        }
{                            XMS Block Available               }
{**************************************************************}
FUNCTION XMSLargestBlockAvailable: Word;
BEGIN
  XMSErrorCode := 0;
  XMSLargestBlockAvailable := 0;
  IF XMSAddr = nil THEN         { Check IF HIMEM.SYS Loaded }
    IF NOT XMSDriverLoaded THEN exit;
  ASM
    mov  ah,8
    call XMSAddr
    or   ax,ax
    jnz  @1
    mov  XMSErrorCode,bl { On Error, Set Error Code }
    @1:
    mov  @Result,ax      { AX=largest free XMS block }
  END;
END;

{***************************************************************}
{ XMSAllocateBlock - Allocates Block of XMS Memory              }
{                  - Input - KBSize: No of Kilobytes requested  }
{                  - Returns Handle for memory IF successful    }
{***************************************************************}
FUNCTION XMSAllocateBlock(KBSize: Word): Word;
BEGIN
  XMSAllocateBlock := 0;
  XMSErrorCode := 0;
  IF XMSAddr = nil THEN { Check IF HIMEM.SYS Loaded }
    IF NOT XMSDriverLoaded THEN exit;
  ASM
    mov  ah,9
    mov  dx,KBSize
    call XMSAddr
    or   ax,ax
    jnz  @1
    mov  XMSErrorCode,bl { On Error, Set Error Code }
    xor  dx,dx
    @1:
    mov  @Result,dx      { DX = handle for extended memory }
  END;
END;

{**************************************************************}
{ XMSReleaseBlock - Releases Block of XMS Memory               }
{                 - Input:   Handle identifying memory to be   }
{                   released                                   }
{                 - Returns  true IF successful                }
{**************************************************************}
FUNCTION XMSReleaseBlock(Handle: Word): Boolean;
VAR OK : Word;
BEGIN
  XMSErrorCode := 0;
  XMSReleaseBlock := false;
  IF XMSAddr = nil THEN   { Check IF HIMEM.SYS Loaded }
    IF NOT XMSDriverLoaded THEN exit;
  ASM
    mov  ah,0Ah
    mov  dx,Handle
    call XMSAddr
    or   ax,ax
    jnz  @1
    mov  XMSErrorCode,bl  { On Error, Set Error Code }
    @1:
    mov  OK,ax
  END;
  XMSReleaseBlock := (OK <> 0);
END;


Function lock(h : Word) : LongInt; Assembler;
Asm
  mov  ah, $C
  mov  dx, h
  call XMSAddr {lock xms block}
  cmp  ax, 1
  je   @OK
  xor  bx, bx
  xor  dx, dx
 @OK:  {set block to nil (0) if err}
  mov  ax, bx
end;

{**************************************************************}
{ XMSMoveDataTo - Moves Block of Data from Conventional        }
{                 Memory to XMS Memory                         }
{               - Data Must have been previously allocated     }
{               - Input - SourceAddr : address of data in      }
{                                      conventional memory     }
{                       - NumBytes   : number of bytes to move }
{                       - XMSHandle  : handle of XMS block     }
{                       - XMSOffset  : 32 bit destination      }
{                                      offset in XMS block     }
{               - Returns true IF completed successfully       }
{**************************************************************}
FUNCTION XMSMoveDataTo(SourceAddr: Pointer; NumBytes: LongInt;
           XMSHandle: Word; XMSOffset: LongInt): Boolean;
VAR Status    : Word;
BEGIN
  XMSErrorCode := 0;
  XMSMoveDataTo := false;
  IF XMSAddr = nil THEN  { Check IF HIMEM.SYS Loaded }
    IF NOT XMSDriverLoaded THEN exit;
  MoveParms.MoveLen   := NumBytes;
  MoveParms.SHandle   := 0;         { Source Handle=0 For
                                      Conventional Memory}
  MoveParms.SPtr      := SourceAddr;
  MoveParms.XMSHdl    := XMSHandle;
  MoveParms.XMSOffset := XMSOffset;
  ASM
    mov  ah,0Bh
    mov  si,offset MoveParms
    call XMSAddr
    mov  Status,ax       { Completion Status }
    or   ax,ax
    jnz  @1
    mov  XMSErrorCode,bl { Save Error Code }
    @1:
  END;
  XMSMoveDataTo := (Status <> 0);
END;

{**************************************************************}
{ XMSGetDataFrom - Moves Block From XMS to Conventional Memory }
{                - Data Must have been previously allocated    }
{                  and moved to XMS                            }
{               - Input - XMSHandle  : handle of source        }
{                                      XMS block               }
{                       - XMSOffset  : 32 bit source offset    }
{                                      in XMS block            }
{                       - NumBytes   : number of bytes to move }
{                       - LowMemAddr : destination addr in     }
{                                      conventional memory     }
{               - Returns true IF completed successfully       }
{**************************************************************}
FUNCTION XMSGetDataFrom(XMSHandle: Word; XMSOffset: LongInt;
           NumBytes: LongInt; LowMemAddr: Pointer): Boolean;
VAR Status    : Word;
BEGIN
  XMSErrorCode := 0;
  XMSGetDataFrom := false;
  IF XMSAddr = nil THEN   { Check IF HIMEM.SYS Loaded }
    IF NOT XMSDriverLoaded THEN exit;
  MoveParms.MoveLen := NumBytes;  { Set-Up Structure to Pass }
  MoveParms.XMSh    := XMSHandle;
  MoveParms.XMSOfs  := XMSOffset;
  MoveParms.DHandle := 0;         { Dest Handle=0 For
                                    Conventional Memory}
  MoveParms.DPtr    := LowMemAddr;
  ASM
    mov  ah,0Bh
    mov  si,offset MoveParms
    call XMSAddr
    mov  Status,ax       { Completion Status }
    or   ax,ax
    jnz  @1
    mov  XMSErrorCode,bl { Set Error Code }
    @1:
  END;
  XMSGetDataFrom := (Status <> 0);
END;




BEGIN
  XMSAddr      := nil; { Initialize XMSAddr }
  XMSErrorCode := 0;
END.