UNIT PKTDRVR;
{
浜様様様様様様様様様様様様様様様用様様様様様様様様様様様様様様様様様様融
� Filename       : PKTDRVR.PAS   �  Program / Unit : [U]               �
� Description    : Turbo Pascal  青陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�
�                  Object to interface with Crynrware packet drivers.  �
�                                                                      �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� Compiler       : Turbo Pascal 7.0                                    �
� OS-Version     : MS-DOS 6.0                                          �
� Last edit      : 08-Oct-93                                           �
� Version        : 1.0                                                 �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� Author         : Oliver Rehmann                                      �
� Copyright      : (C) 1993 Oliver Rehmann                             �
�                                                                      �
� Released to public domain.                                           �
� The author can not be held responsible for any damages resulting     �
� from the use of this software.                                       �
藩様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様夕
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � CONSTRUCTOR Init                                                     �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Initializes packet driver object                   �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
CONSTRUCTOR TPKTDRVR.Init(IntNo : Integer);
BEGIN
  Inherited Init;

  pktInt    := IntNo;
  pktStatus := NOT_INITIALIZED;
  FillChar(pktAccessInfo,SizeOf(pktAccessInfo),#00);

  TestForPktDriver;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � DESTRUCTOR Done                                                      �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Calls inherited destructor of TOBJECT              �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
DESTRUCTOR TPKTDRVR.Done;
BEGIN

  { Release allocated handle }
  IF (pktStatus = INITIALIZED) THEN
  BEGIN
    ReleaseType;
  END;

  Inherited Done;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION GetStatus : TPKTSTATUS                                      �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Returns current object status                      �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
FUNCTION TPKTDRVR.GetStatus : TPKTSTATUS;
BEGIN
  GetStatus := pktStatus;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION GetAccessType                                               �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Returns information about type of interface, class,�
 �                 � interface number.                                  �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
PROCEDURE TPKTDRVR.GetAccessType(VAR pktAccessType : TACCESSTYPE);
BEGIN
  pktAccessType := pktAccessInfo;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE TestForPktDriver;                                          �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Tests if the assigned interrupt points to a valid  �
 �                 � packet driver.                                     �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE ScanForPktDriver                                           �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Scans interrupts ($60-$7F) for a packet driver.    �
 �                 � Stops if it has found a valid driver.              �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE DriverInfo                                                 �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Returns some information on the assigned packet    �
 �                 � driver                                             �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE AccessType                                                 �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Accesses the packet driver.                        �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE ReleaseType                                                �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Releases a specific type handle.                   �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE SendPkt                                                    �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Sends a data packet by accessing the packet driver.�
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE TerminateDriver                                            �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Terminates the Driver associated with pktHandle    �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE GetAddress                                                 �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Gets the hardware address from the driver.         �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE ResetInterface                                             �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Does what it says.                                 �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE GetParameters                                              �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Gets specific parameters from the driver.          �
 �                 � Not all drivers support this function.             �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 13-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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


{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE AsSendPkt                                                  �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Sends a data packet by accessing the packet driver.�
 �                 � Upcall is called when order was placed.            �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE SetRCVmode                                                 �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Sets the receive mode of the driver.               �
 �                 � For meaning of mode see "packet_d.109"             �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION GetRCVmode : Word                                           �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Gets the receive mode from the driver.             �
 �                 � For meaning of mode see "packet_d.109"             �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE SetMulticastList                                           �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Assigns a multicast list to the driver.            �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE GetMulticastList                                           �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Retrieves a pointer to a multicast list.           �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE GetStatistics                                              �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Retrieves statistics about received and sent       �
 �                 � packets, bytes, errors.                            �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE SetAddress                                                 �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : �                                                    �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
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

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE GetError                                                   �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Returns the last error. 0 means NO ERROR           �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
FUNCTION TPKTDRVR.GetError  : Byte;
BEGIN
  GetError := pktError;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE GetHandle                                                  �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Returns the accessed handle.                       �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 17-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
FUNCTION TPKTDRVR.GetHandle : Word;
BEGIN
  GetHandle := pktHandle;
END;

BEGIN
END.
