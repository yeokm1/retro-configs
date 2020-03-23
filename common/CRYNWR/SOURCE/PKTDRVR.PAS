UNIT PKTDRVR;
{
ษออออออออออออออออออออออออออออออออัอออออออออออออออออออออออออออออออออออออป
บ Filename       : PKTDRVR.PAS   ณ  Program / Unit : [U]               บ
บ Description    : Turbo Pascal  ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ                  Object to interface with Crynrware packet drivers.  บ
บ                                                                      บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ Compiler       : Turbo Pascal 7.0                                    บ
บ OS-Version     : MS-DOS 6.0                                          บ
บ Last edit      : 08-Oct-93                                           บ
บ Version        : 1.0                                                 บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ Author         : Oliver Rehmann                                      บ
บ Copyright      : (C) 1993 Oliver Rehmann                             บ
บ                                                                      บ
บ Released to public domain.                                           บ
บ The author can not be held responsible for any damages resulting     บ
บ from the use of this software.                                       บ
ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}

INTERFACE

USES DOS,OBJECTS;

{$I PACKET.INC}

CONST
     Pkt_Sig  : String[08] = 'PKT DRVR';
     ParamLen : Byte       = 14;

TYPE TPKTSTATUS    = (NO_PKTDRVR,INITIALIZED,NOT_INITIALIZED);
     TACCESSTYPE   = RECORD
		       if_class      : Byte;    { Interface class  }
		       if_type       : Word;    { Interface Type   }
		       if_number     : Byte;    { Interface number }
		       type_         : Pointer;
		       typelen       : Word;    { length of type_, set to 0 if
						  you want to receive all pkts }
		       receiver      : Pointer; { receive handler }
		     END;

      TPKTPARAMS   = RECORD
		       major_rev     : Byte; { Major revision ID of packet specs }
		       minor_rev     : Byte; { Minor revision ID of packet specs }
		       length        : Byte; { Length of structure in Bytes      }
		       addr_len      : Byte; { Length of a MAC address           }
		       mtu           : Word; { MTU, including MAC headers        }
		       multicast_aval: Word; { buffer size for multicast addr.   }
		       rcv_bufs      : Word; { (# of back-to-back MTU rcvs) - 1  }
		       xmt_bufs      : Word; { (# of successive xmits) - 1       }
		       int_num       : Word; { Interrupt # to hook for post-EOI
					       processing, 0 == none }

		     END;

      TDRVRINFO    = RECORD
		       Version       : Word; { Packet driver version   }
		       Class         : Byte; { Driver class  }
		       Type_         : Word; { Driver type   }
		       Number        : Byte; { Driver number }
		       pName         : Pointer;
		       Functionality : Byte; { How good is this driver }
		     END;

       TSTATISTICS = RECORD
		       packets_in    : LongInt;
		       packets_out   : LongInt;
		       bytes_in      : LongInt;
		       bytes_out     : LongInt;
		       errors_in     : LongInt;
		       errors_out    : LongInt;
		       packets_lost  : LongInt;
		     END;

       TPKTDRVR = OBJECT(TOBJECT)

private
		  pktInt         : Integer;
		  pktHandle      : Integer;
		  pktRecvHandler : Pointer;
		  pktStatus      : TPKTSTATUS;
		  pktError       : Byte;
		  pktRegs        : Registers;

		  pktAccessInfo  : TACCESSTYPE;

		  PROCEDURE   TestForPktDriver;
public
		  CONSTRUCTOR Init(IntNo : Integer);
		  DESTRUCTOR  Done; VIRTUAL;

		  PROCEDURE   ScanForPktDriver;

		  FUNCTION    GetStatus                          : TPKTSTATUS;
		  FUNCTION    GetError                           : Byte;
		  FUNCTION    GetHandle                          : Word;

		  PROCEDURE   GetAccessType   (VAR pktAccessType : TACCESSTYPE);
		  PROCEDURE   DriverInfo      (VAR pktInfo       : TDRVRINFO  );

		  PROCEDURE   AccessType      (VAR pktAccessType : TACCESSTYPE);
		  PROCEDURE   ReleaseType;
		  PROCEDURE   TerminateDriver;

		  PROCEDURE   GetAddress      (Buffer : Pointer;BufLen : Word; VAR BufCopied : Word);
		  PROCEDURE   ResetInterface;
		  PROCEDURE   GetParameters   (VAR pktParams : TPKTPARAMS);

		  PROCEDURE   SendPkt         (Buffer : Pointer;BufLen : Word );
		  PROCEDURE   As_SendPkt      (Buffer : Pointer;BufLen : Word;Upcall : Pointer     );

		  PROCEDURE   SetRCVmode      (Mode   : Word);
		  FUNCTION    GetRCVmode              : Word;

		  PROCEDURE   SetMulticastList(VAR mcList : Pointer; VAR mcLen : Word);
		  PROCEDURE   GetMulticastList(VAR mcList : Pointer; VAR mcLen : Word);

		  PROCEDURE   GetStatistics   (VAR pktStatistics : TSTATISTICS       );
		  PROCEDURE   SetAddress      (Address : Pointer; VAR AddrLen  : Word);

		  END;

IMPLEMENTATION

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ CONSTRUCTOR Init                                                     บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Initializes packet driver object                   บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
CONSTRUCTOR TPKTDRVR.Init(IntNo : Integer);
BEGIN
  Inherited Init;

  pktInt    := IntNo;
  pktStatus := NOT_INITIALIZED;
  FillChar(pktAccessInfo,SizeOf(pktAccessInfo),#00);

  TestForPktDriver;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ DESTRUCTOR Done                                                      บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Calls inherited destructor of TOBJECT              บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
DESTRUCTOR TPKTDRVR.Done;
BEGIN

  { Release allocated handle }
  IF (pktStatus = INITIALIZED) THEN
  BEGIN
    ReleaseType;
  END;

  Inherited Done;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION GetStatus : TPKTSTATUS                                      บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Returns current object status                      บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
FUNCTION TPKTDRVR.GetStatus : TPKTSTATUS;
BEGIN
  GetStatus := pktStatus;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION GetAccessType                                               บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Returns information about type of interface, class,บ
 บ                 ณ interface number.                                  บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.GetAccessType(VAR pktAccessType : TACCESSTYPE);
BEGIN
  pktAccessType := pktAccessInfo;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE TestForPktDriver;                                          บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Tests if the assigned interrupt points to a valid  บ
 บ                 ณ packet driver.                                     บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.TestForPktDriver;
VAR tPointer  : Pointer;
    Signature : String[08];
    I         : Integer;
BEGIN
  Signature := '';
  GetIntVec(pktInt,tPointer);
  FOR I := 3 TO 10 DO
  BEGIN
    Signature := Signature + Chr(Mem[Seg(tPointer^):Ofs(tPointer^)+I]);
  END;
  IF (POS(Pkt_Sig,Signature) = 0) THEN
    pktStatus := NO_PKTDRVR
  ELSE
    pktStatus := INITIALIZED;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE ScanForPktDriver                                           บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Scans interrupts ($60-$7F) for a packet driver.    บ
 บ                 ณ Stops if it has found a valid driver.              บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.ScanForPktDriver;
VAR I : Integer;
BEGIN
  I := $60; { Lower range of possible pktdrvr interrupt }
  REPEAT
    pktInt := I;
    TestForPktDriver;
    Inc(I);
  UNTIL (I = $80) OR (pktStatus = INITIALIZED);
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE DriverInfo                                                 บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Returns some information on the assigned packet    บ
 บ                 ณ driver                                             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.DriverInfo(VAR pktInfo : TDRVRINFO);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := DRIVER_INFO;
    AL := $FF;
    BX := pktHandle;
    Intr(pktInt,pktRegs); { Call Packet Driver }
    IF (pktRegs.Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
    BEGIN
      pktError := 0;
      IF (pktError = NO_ERROR) THEN
      BEGIN
	pktInfo.Version       := BX;
	pktInfo.Class         := CH;
	pktInfo.Type_         := DX;
	pktInfo.Number        := CL;
	pktInfo.pName         := Ptr(DS,SI);
	pktInfo.Functionality := AL;
      END;
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE AccessType                                                 บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Accesses the packet driver.                        บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.AccessType(VAR pktAccessType : TACCESSTYPE);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := ACCESS_TYPE;
    AL := pktAccessType.if_class;
    BX := pktAccessType.if_type;
    CX := pktAccessType.typelen;
    DL := pktAccessType.if_number;
    DS := Seg(pktAccessType.type_^);
    SI := Ofs(pktAccessType.type_^);
    ES := Seg(pktAccessType.receiver^);
    DI := Ofs(pktAccessType.receiver^);
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError      := DH
    ELSE
    BEGIN
      pktError      := 0;
      pktHandle     := AX;
      pktAccessInfo := pktAccessType;
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE ReleaseType                                                บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Releases a specific type handle.                   บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.ReleaseType;
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := RELEASE_TYPE;
    BX := pktHandle;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE SendPkt                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Sends a data packet by accessing the packet driver.บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.SendPkt(Buffer : Pointer;BufLen : Word);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := SEND_PKT;
    CX := BufLen;
    DS := Seg(Buffer^);
    ES := DS;
    SI := Ofs(Buffer^);
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE TerminateDriver                                            บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Terminates the Driver associated with pktHandle    บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE   TPKTDRVR.TerminateDriver;
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := TERMINATE;
    BX := pktHandle;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE GetAddress                                                 บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Gets the hardware address from the driver.         บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.GetAddress (Buffer : Pointer;BufLen : Word; VAR BufCopied : Word);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := GET_ADDRESS;
    BX := pktHandle;
    CX := BufLen;
    ES := Seg(Buffer^);
    DI := Ofs(Buffer^);
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError  := DH
    ELSE
    BEGIN
      pktError  := 0;
      BufCopied := CX;
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE ResetInterface                                             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Does what it says.                                 บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.ResetInterface;
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := RESET_INTERFACE;
    BX := pktHandle;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE GetParameters                                              บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Gets specific parameters from the driver.          บ
 บ                 ณ Not all drivers support this function.             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 13-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.GetParameters(VAR pktParams : TPKTPARAMS);
VAR b : Byte;
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := GET_PARAMETERS;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
    BEGIN
      pktError := 0;
      FOR b := 0 TO ParamLen-1 DO  { Copy contents of structure }
	Mem[Seg(pktParams):Ofs(PktParams)+b] := Mem[ES:DI+b];
    END;
  END;
END;


{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE AsSendPkt                                                  บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Sends a data packet by accessing the packet driver.บ
 บ                 ณ Upcall is called when order was placed.            บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.As_SendPkt(Buffer : Pointer;BufLen : Word;Upcall : Pointer);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := AS_SEND_PKT;
    CX := BufLen;
    DS := Seg(Buffer);
    SI := Ofs(Buffer);
    ES := Seg(Upcall^);
    DI := Ofs(Upcall^);
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE SetRCVmode                                                 บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Sets the receive mode of the driver.               บ
 บ                 ณ For meaning of mode see "packet_d.109"             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.SetRCVmode(Mode : Word);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := SET_RCV_MODE;
    BX := pktHandle;
    CX := Mode;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION GetRCVmode : Word                                           บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Gets the receive mode from the driver.             บ
 บ                 ณ For meaning of mode see "packet_d.109"             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
FUNCTION TPKTDRVR.GetRCVmode : Word;
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := GET_RCV_MODE;
    BX := pktHandle;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError   := DH
    ELSE
    BEGIN
      pktError   := 0;
      GetRCVmode := AX;
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE SetMulticastList                                           บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Assigns a multicast list to the driver.            บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.SetMulticastList(VAR mcList : Pointer; VAR mcLen : Word);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := SET_MULTICAST_LIST;
    CX := mcLen;
    ES := Seg(mcList^);
    DI := Ofs(mcList^);
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
      pktError := 0;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE GetMulticastList                                           บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Retrieves a pointer to a multicast list.           บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.GetMulticastList(VAR mcList : Pointer; VAR mcLen : Word);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := GET_MULTICAST_LIST;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
    BEGIN
      pktError := 0;
      mcList   := Ptr(ES,DI);
      mcLen    := CX;
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE GetStatistics                                              บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Retrieves statistics about received and sent       บ
 บ                 ณ packets, bytes, errors.                            บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.GetStatistics(VAR pktStatistics : TSTATISTICS);
VAR b : Byte;
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := GET_STATISTICS;
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
    BEGIN
      pktError := 0;
      FOR b := 0 TO SizeOf(TSTATISTICS)-1 DO  { Copy contents of structure }
	Mem[Seg(pktStatistics):Ofs(pktStatistics)+b] := Mem[DS:SI+b];
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE SetAddress                                                 บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ                                                    บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TPKTDRVR.SetAddress(Address : Pointer; VAR AddrLen : Word);
BEGIN
  WITH pktRegs DO
  BEGIN
    AH := SET_ADDRESS;
    CX := AddrLen;
    ES := Seg(Address^);
    DI := Ofs(Address^);
    Intr(pktInt,pktRegs);
    IF (Flags AND Carry_Flag) = Carry_Flag THEN
      pktError := DH
    ELSE
    BEGIN
      pktError := 0;
      AddrLen  := CX;
    END;
  END;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE GetError                                                   บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Returns the last error. 0 means NO ERROR           บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
FUNCTION TPKTDRVR.GetError  : Byte;
BEGIN
  GetError := pktError;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE GetHandle                                                  บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Returns the accessed handle.                       บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 17-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
FUNCTION TPKTDRVR.GetHandle : Word;
BEGIN
  GetHandle := pktHandle;
END;

BEGIN
END.
