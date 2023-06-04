Program TrafficMonitor;
{
ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ TRAFMON Version 1.0  (Released to public domain)                       บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ Author : O. Rehmann                                                    บ
บ                                                                        บ
บ e-mail : 100016.732@compuserve.com                                     บ
บ        : CZ8OR@zcvx00.decnet.ascom.ch                                  บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ Sample program to monitor ethernet traffic.                            บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ ATTENTION:                                                             บ
บ                                                                        บ
บ The author can not be held responsible for any damages resulting out   บ
บ of the use of this software !!!                                        บ
บ                                                                        บ
ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
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
{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION  ByteToHEXASCII (...) : String;                             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Converts Byte    to a HEX-ASCII-String             บ
 บ                 ณ requests.                                          บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
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
{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION  WordToHEXASCII (...) : String;                             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Converts tWord   to a HEX-ASCII-String             บ
 บ                 ณ requests.                                          บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
VAR tStr : String;
BEGIN
  tStr := ByteToHexASCII(Hi(tWord));
  tStr := tStr+ByteToHexASCII(Lo(tWord));
  WordToHexASCII := tStr;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION  GetEthernetAddress                                         บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Converts a 6 byte ethernet address into a dash     บ
 บ                 ณ separated string.                                  บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
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
{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE TranslateEthernetAddress(..);                              บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Translates a dash separated ethernet address into  บ
 บ                 ณ 6 Bytes.                                           บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
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

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ FUNCTION SwapWord;                                                   บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Swaps the Hi and Lo byte of a word.                บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
FUNCTION SwapWord(sWord : Word) : Word;
VAR tWord : Word;
BEGIN
  tWord := (Lo(sWord) SHL 8) + Hi(sWord);
  SwapWord := tWord;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE InitPktDriver;                                             บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Initialize packet driver.                          บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
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

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ PROCEDURE TerminatePktDriver;                                        บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤยฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Description   : ณ Releases the handle and terminates packet driver.  บ
 บ                 ณ                                                    บ
 วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤลฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
 บ Creation date : ณ 23-SEPT-93                                         บ
 ศอออออออออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
PROCEDURE TerminatePktDriver;
BEGIN
  pktDriver.ReleaseType;
END;

{ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
 บ Main Program                                                         บ
 ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ}
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
        Write('Û');
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

