Program TrafficGenerator;
{
浜様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様融
� TRAFGEN Version 1.0  (Released to public domain)                       �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� Author : O. Rehmann                                                    �
�                                                                        �
� e-mail : 100016.732@compuserve.com                                     �
�        : CZ8OR@zcvx00.decnet.ascom.ch                                  �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� Sample program to generate ethernet traffic.                           �
把陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
� ATTENTION:                                                             �
�                                                                        �
� The author can not be held responsible for any damages resulting from  �
� the use of this software !!!                                           �
�                                                                        �
� BE CAREFUL when generating traffic on a network !!!!!!!!               �
�                                                                        �
藩様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様夕
}

USES CRT,DOS,STRINGS,PKTDRVR;

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

    SendPacket      : Array[00..1524] of Byte; { Send buffer    }
    SendHeader      : MACheader;               { Header         }

    PacketCount     : LongInt;                 { Packet counter }
    Data            : String;
    PacketDelay     : Word;

{ ========================================================================== }
{ The receiver procedure:                                                    }
{ Dummy receiver because we only generate traffic but it is a good example   }
{ for a real receiver procedure.                                             }
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

  JMP  @@Exit

@@FrameCopied:

@@Exit:

  POP  DX                      { Pop registers from stack }
  POP  CX
  POP  BX
  POP  AX
END;
{$S+}

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
 � PROCEDURE ReadCfgFile;                                               �
 把陳陳陳陳陳陳陳陳堕陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Description   : � Reads the TRAFGEN.DAT file.                        �
 �                 �                                                    �
 把陳陳陳陳陳陳陳陳田陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳超
 � Creation date : � 23-SEPT-93                                         �
 藩様様様様様様様様詫様様様様様様様様様様様様様様様様様様様様様様様様様夕}
PROCEDURE ReadCfgFile;
VAR tFile : TEXT;
    tLine : String;
    tWord : Word;
    cWord : Word;
    tInt  : Integer;
BEGIN
  Assign(tFile,'TRAFGEN.DAT');
  {$I-} Reset(tFile); {$I+}
  IF (IOResult <>00) THEN
  BEGIN
    WriteLn;
    WriteLn('Error : Data file not found. [TRAFGEN.DAT]');
    Halt($FF);
  END;

  { Get destination address from CFG file }
  ReadLn(tFile,tLine);
  TranslateEthernetAddress(tLine,SendHeader.DestAddr);

  { Get our hardware address }
  pktDriver.GetAddress(@SendHeader.SourceAddr,SizeOf(SendHeader.SourceAddr),cWord);

  { Get the packet type (ex. 0800 = IP, 8137 = Netware) }
  ReadLn(tFile,tLine);
  Val('$'+tLine,tWord,tInt);

  ReadLn(tFile,Data);

  { Fill in the TypeLen field of SendHeader }
  IF (tWord > $5EE) THEN
    SendHeader.TypeLen := SwapWord(tWord)  { We have to swap the word }
  ELSE
    SendHeader.TypeLen := SwapWord(Length(Data));

  { Prepare "SendPacket", our buffer }
  tWord := SizeOf(SendHeader);
  Move(SendHeader,SendPacket,SizeOf(SendHeader));
  FOR tInt := 0 TO Length(Data)-1 DO
  BEGIN
    Mem[Seg(SendPacket):Ofs(SendPacket)+tWord+tInt] := Mem[Seg(Data):Ofs(Data)+tInt+1];
  END;
  Close(tFile);
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
  pktDriver.ScanForPktDriver;
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
  WriteLn('ETHERNET Traffic Generator Version 1.0 (C) O. Rehmann');
  WriteLn;

  InitPktDriver;
  ReadCfgFile;

  WriteLn('Press <ESC> to terminate TRAFGEN ...');
  WriteLn;
  WriteLn('Packets sent:');

  PacketCount := 0; PacketDelay := 10;
  REPEAT
    IF KeyPressed THEN Key := ReadKey;
    CASE Key OF
      '+' : BEGIN IF (PacketDelay < 100) THEN Inc(PacketDelay,1); Key := #00; END;
      '-' : BEGIN IF (PacketDelay > 1  ) THEN Dec(PacketDelay,1); Key := #00; END;
    END;

    { Send packet }
    pktDriver.SendPkt(@SendPacket,SizeOf(SendHeader)+Length(Data));

    Delay(PacketDelay);
    Inc(PacketCount);
    Write(PacketCount,' '); ClrEOL; Write(#13);

  UNTIL (Key = #27);

  { Terminate packet driver }
  TerminatePktDriver;
END.
