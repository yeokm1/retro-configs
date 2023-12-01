
{
ษออออออออออออออออออออออออออออออออัอออออออออออออออออออออออออออออออออออออป
บ Filename       : TIMER.PAS     ณ  Program / Unit : [U]               บ
บ Description    :               ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ                                                                      บ
บ                                                                      บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ Compiler       : Turbo Pascal 6.0                                    บ
บ OS-Version     : MS-DOS 5.0                                          บ
บ Last edit      : 27-JAN-93                                           บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ Author         : Oliver Rehmann                                      บ
บ Copyright      : Oliver Rehmann                                      บ
ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}

UNIT TIMER;

INTERFACE

USES DOS;

TYPE  _TIMER = OBJECT
                 Starttime   : LONGINT;
                 Duration    : LONGINT;
                 _Timeout    : BOOLEAN;

                 CONSTRUCTOR Init(tDuration : LONGINT);
                 PROCEDURE   Start;
                 FUNCTION    Timeout : BOOLEAN;

               END;

FUNCTION  GetSystemTime : String;

IMPLEMENTATION

FUNCTION  GetSystemTime : String;
VAR tmp     : String;
    Time    : String;
    TimeTmp : Byte;
    Hour,Minute,Second,Sec100 : Word;
BEGIN
     GetTime(Hour,Minute,Second,Sec100);
     Str(Hour:2,tmp);   If Pos(' ',tmp)<>0 then Time :=   '0'+tmp[2] else Time :=      tmp;
     Time := Time+':';
     Str(Minute:2,tmp); If Pos(' ',tmp)<>0 then Time := Time+'0'+tmp[2] else Time := Time+tmp;
     Time := Time+':';
     Str(Second:2,tmp); If Pos(' ',tmp)<>0 then Time := Time+'0'+tmp[2] else Time := Time+tmp;
     TimeTmp := Hour; GetSystemTime := Time
END;

FUNCTION GetSysTime : LONGINT;
VAR Hour,Minute,Second,Sec100 : Word;
    tSysTime                  : LONGINT;
BEGIN
  tSysTime   := 0;
  GetTime(Hour,Minute,Second,Sec100);
  tSysTime   := Hour*3600;                { each hour has 3600 seconds }
  tSysTime   := tSysTime + (Minute*60);   { each min  has 60 seconds   }
  tSysTime   := tSysTime + Second;
  GetSysTime := tSysTime;
END;

CONSTRUCTOR _TIMER.Init(tDuration : LONGINT);
BEGIN
  Duration := tDuration;
  _Timeout := FALSE;
END;

PROCEDURE _TIMER.Start;
BEGIN
  _Timeout := FALSE;
  Starttime := GetSysTime;
END;

FUNCTION _TIMER.Timeout : BOOLEAN;
BEGIN
  IF ((Starttime + Duration) < GetSysTime) THEN _Timeout := TRUE;
  Timeout := _Timeout;
END;

BEGIN
END.
