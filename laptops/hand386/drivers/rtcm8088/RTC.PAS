Unit RTC;

interface

function getRTCreg(reg: byte): byte;
procedure setRTCreg(reg: byte; value: byte);
procedure initRTC;
function HexStr(v: Word): String;

const
     RTC_minute = $02;
     RTC_second = $00;
     RTC_hour   = $04;
     RTC_day    = $07;
     RTC_month  = $08;
     RTC_year   = $09;

var
   RTC_port: word;

implementation

uses DOS, CRT;

function getRTCreg(reg: byte): byte;
begin
     port[RTC_port] := reg;
     getRTCreg := port[RTC_port+1];
end;

procedure setRTCreg(reg: byte; value: byte);
begin
     port[RTC_port] := reg;
     port[RTC_port+1] := value;
end;

procedure initRTC;
begin
     setRTCreg($0A, $20);
     setRTCreg($0B, $27);
end;

function HexStr(v: Word): String;
var
   value: String[5];
   digit, digit_val: byte;
   syms: String[16];
begin
     syms := '0123456789ABCDEF';
     value := '$0000';
     digit := 5;
     while v > 0 do
     begin
          digit_val := v mod 16;
          value[digit] := syms[digit_val+1];
          dec(digit);
          v := v div 16;
     end;
     HexStr := value;
end;

var
   err: integer;
   port: word;

begin
{     clrscr;
     writeln(getRTCreg(RTC_day), '/', getRTCreg(RTC_month), '/', getRTCreg(RTC_year));
     writeln(getRTCreg(RTC_hour), ':', getRTCreg(RTC_minute), '.', getRTCreg(RTC_second));
}
    writeln('(c) 2019 Alejandro Valero Sebastian (Wilco2009)');
    if paramcount = 0 then
       RTC_port := $2C0
    else begin
         Val(paramstr(1), port, err);
         if err=0 then
            RTC_port := port
         else
             writeln('ERROR: Port not valid (must be a numeric value between $0000 and $FFFF.');
    end;
    writeln('Using port: ',HexStr(RTC_port), '.');
end.