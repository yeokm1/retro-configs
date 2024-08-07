Program TrafficMonitor;
{
浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
� TRAFMON Version 1.0  (Released to public domain)                       �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� Author : O. Rehmann                                                    �
�                                                                        �
� e-mail : 100016.732@compuserve.com                                     �
�        : CZ8OR@zcvx00.decnet.ascom.ch                                  �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� Sample program to monitor ethernet traffic.                            �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� ATTENTION:                                                             �
�                                                                        �
� The author can not be held responsible for any damages resulting out   �
� of the use of this software !!!                                        �
�                                                                        �
藩様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様夕
}
{$A+,B-,D+,E-,F+,G-,I-,L+,N-,O-,R-,S-,V+,X+}
{$M $2048 $0 $8192}

USES CRT,DOS,STRINGS,TIMER,PKTDRVR;

CONST  MaxEthernetCapacity = 1250000; { Max. theroetical ethernet capacity }

TYPE
       { 6 Byte ethernet address }
       EthernetAddr = Array[00..05] of Byte;

       MACHeader    = RECORD { IEEE 802.3 header }
                        DestAddr   : EthernetAddr;
                        SourceAddr : EthernetAddr;
                        TypeLen    : Word;
                      END;

VAR Key             : Char;

    pktDriver       : TPKTDRVR;    { Instance of the TPKTDRVR object         }
    pktDriverInfo   : TDRVRINFO;   { record for driver information           }
    pktDriverAccess : TACCESSTYPE; { record used for accessing packet driver }

    TypeField       : Word;

    RcvPacket       : Array[00..1524] of Byte; { Rcv buffer       }
    RcvLength       : Word;                    { Length of packet }
    RcvHeader       : MACheader;               { Header           }

    PacketCount     : Word;                    { Packet counter   }
    PacketDelay     : Word;

    CurTraffic      : Real;
    CumTraffic      : LongInt;
    VUMeterLen      : Real;
    MyTimer         : _TIMER;

    I               : Integer;

{ ========================================================================== }
{ The receiver procedure:                                                    }
{$S-}PROCEDURE pktReceiver; ASSEMBLER;
ASM
  PUSH AX                      { Push registers onto stack }
  PUSH BX
  PUSH CX
  PUSH DX


  CMP  AX,0001                 { AX=1 means frame copied }
  JZ   @@FrameCopied
  CMP  AX,0000                 { AX=0 means allocate memory please }
  JZ   @@AllocMemory
  JMP  @@EXIT                  { Invalid register contents for AX so exit}

@@AllocMemory:

  MOV  DX,0                    { ES:DI = 0000:0000, we don't want the packet }
  MOV  ES,DX
  MOV  DI,0                    { We don't grab the packet }

  MOV  DX,SEG PacketCount      { Set correct data segment }
  MOV  DS,DX
  MOV  DX,PacketCount
  CMP  DX,0

  JNZ  @@Exit                  { buffer is not free ! }

  MOV  DX,SEG rcvPacket
  MOV  ES,DX
  MOV  DI,OFFSET rcvPacket

  MOV  DX,SEG rcvLength
  MOV  DS,DX
  MOV  SI,OFFSET RcvLength
  MOV  WORD PTR DS:[SI],CX     { Store length of frame in PacketLength }

  JMP  @@Exit

@@FrameCopied:

  MOV  DX,SEG PacketCount       { Set correct data segment }
  MOV  DS,DX
  MOV  PacketCount,1            { Set Flag to 1 }

@@Exit:

  POP  DX                      { Pop registers from stack }
  POP  CX
  POP  BX
  POP  AX
END;
{$S+}

FUNCTION ByteToHEXASCII(tByte : Byte) : String;
{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION  ByteToHEXASCII (...) : String;                             �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Converts Byte    to a HEX-ASCII-String             �
 �                 � requests.                                          �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
CONST
   HEXChars: array [0..15] of char = '0123456789ABCDEF';
VAR Nibble1 : Byte;
    Nibble2 : Byte;
    tStr    : String;
BEGIN
  Nibble1 := (tByte AND $0F);        { AND 00001111b }
  Nibble2 := (tByte AND $F0) SHR 4;  { AND 11110000b }
  tStr := HEXChars[Nibble2]+HEXChars[Nibble1];
  ByteToHEXASCII := tStr;
END;

FUNCTION WordToHEXASCII(tWord : Word) : String;
{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION  WordToHEXASCII (...) : String;                             �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Converts tWord   to a HEX-ASCII-String             �
 �                 � requests.                                          �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
VAR tStr : String;
BEGIN
  tStr := ByteToHexASCII(Hi(tWord));
  tStr := tStr+ByteToHexASCII(Lo(tWord));
  WordToHexASCII := tStr;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION  GetEthernetAddress                                         �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Converts a 6 byte ethernet address into a dash     �
 �                 � separated string.                                  �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
FUNCTION GetEthernetAddress(tEtherAddr : EthernetAddr) : String;
VAR tString : String;
    tDigit  : String[02];
    tCount  : Byte;
    AddrLen : Byte;
BEGIN
  AddrLen := SizeOf(EthernetAddr)-1;
  tString := '';

  FOR tCount := 0 TO AddrLen DO
  BEGIN
    tString := tString + ByteToHexASCII(tEtherAddr[tCount]);
    IF (tCount < AddrLen) THEN tString := tString + '-';
  END;
  GetEthernetAddress := tString;
END;

PROCEDURE TranslateEthernetAddress(tStr : String; VAR tEtheraddr : EthernetAddr);
{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE TranslateEthernetAddress(..);                              �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Translates a dash separated ethernet address into  �
 �                 � 6 Bytes.                                           �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
VAR tDigit : String;
    tByte  : Byte;
    Err    : Integer;
    tVal   : Byte;
BEGIN
  tDigit :='';
  FOR tByte := 1 TO Length(tStr) DO
  BEGIN
    IF (Copy(tStr,tByte,1) <> '-') THEN tDigit := tDigit + Copy(tStr,tByte,1);
  END;
  FOR tByte := 0 TO 5 DO
  BEGIN
    Val('$'+Copy(tDigit,(tByte*2)+1,2),tVal,Err);
    tEtheraddr[tByte] := tVal;
  END;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � FUNCTION SwapWord;                                                   �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Swaps the Hi and Lo byte of a word.                �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
FUNCTION SwapWord(sWord : Word) : Word;
VAR tWord : Word;
BEGIN
  tWord := (Lo(sWord) SHL 8) + Hi(sWord);
  SwapWord := tWord;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE InitPktDriver;                                             �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Initialize packet driver.                          �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
PROCEDURE InitPktDriver;
BEGIN
  WriteLn('Initializing packet driver....');
  IF (pktDriver.GetStatus <> INITIALIZED) THEN
  BEGIN
    WriteLn('Could not initialze packet driver...');
    WriteLn('Aborting...');
    Halt($FF);
  END
  ELSE
  BEGIN
    { Packet driver found. Show some information }
    WriteLn('Packet driver found:');
    pktDriver.DriverInfo(pktDriverInfo);

    WriteLn('Name    = ',StrPas(pktDriverInfo.PName));
    WriteLn('Version = ',pktDriverInfo.Version);
    WriteLn('IF-Type = ',pktDriverInfo.Type_);
    Write  ('Func    = ');

    CASE pktDriverInfo.Functionality OF
      01 : WriteLn('Basic functions present.');
      02 : WriteLn('Basic & extended functions present.');
      05 : WriteLn('Basic & high-performance functions present.');
      06 : WriteLn('Basic, high-performance & extended functions present.');
    END;
  END;

  { Fill in information used for accessing packet driver }
  WITH pktDriverAccess DO
  BEGIN
    if_class  := pktDriverInfo.Class;
    if_type   := ANYTYPE;
    if_number := 0;
    type_     := @TypeField;
    typelen   := 0;
    receiver  := @pktReceiver; { receiver procedure }
  END;

  { Access packet driver }
  pktDriver.AccessType(pktDriverAccess);
  WriteLn('Handle  = ',pktDriver.GetHandle);
  WriteLn;

  { Setting packet driver to promiscuous mode }
  pktDriver.SetRCVmode(6);
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � PROCEDURE TerminatePktDriver;                                        �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Releases the handle and terminates packet driver.  �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
PROCEDURE TerminatePktDriver;
BEGIN
  pktDriver.ReleaseType;
END;

{浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
 � Main Program                                                         �
 藩様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様夕}
BEGIN
  ClrScr;
  WriteLn('ETHERNET Traffic Monitor Version 1.0 (C) O. Rehmann');
  WriteLn;

  PacketCount := 0;
  CumTraffic  := 0;

  pktDriver.ScanForPktDriver;
  InitPktDriver;

  WriteLn('Press <ESC> to terminate TRAFMON ...');
  WriteLn;
  WriteLn('Packets received:');
  WriteLn;

  MyTimer.Init(2);
  MyTimer.Start;

  REPEAT
    IF KeyPressed THEN Key := ReadKey;

    { Send packet }
    IF (PacketCount = 1) THEN
    BEGIN
      Move(rcvPacket,rcvHeader,SizeOf(rcvHeader));

      { Display information }
      GotoXY(1,16);
      Write(#13,'Dest : ',GetEthernetAddress(rcvHeader.DestAddr),'  ',
                'Src  : ',GetEthernetAddress(rcvHeader.SourceAddr),'  ',
                'Type/Len : ',WordToHexASCII(SwapWord(rcvHeader.TypeLen)));

      Inc(CumTraffic,RcvLength);
      RcvLength   := 0;
      PacketCount := 0; { Reset flag that new frames can be received }
    END;

    IF MyTimer.Timeout THEN
    BEGIN
      VUMeterLen := (CumTraffic / (2*MaxEthernetCapacity))*75;
      CurTraffic := (VUMeterLen / 75 ) * 100;

      GotoXY(1,20); TextColor(White);
      FOR I := 1 TO Trunc(VUMeterLen) DO
      BEGIN
        IF (I >  7) THEN TextColor(Yellow);
        IF (I > 37) THEN TextColor(Red);
        Write('�');
      END;
      Write(Trunc(CurTraffic),'%'); ClrEOL;
      TextColor(White);

      CumTraffic := 0;
      MyTimer.Start;
    END;

  UNTIL (Key = #27);

  { Terminate packet driver }
  TerminatePktDriver;
END.

