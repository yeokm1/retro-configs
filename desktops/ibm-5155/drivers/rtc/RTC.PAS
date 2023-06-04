{*********************************************************************}
{*                                  R T C                            *}
{*-------------------------------------------------------------------*}
{*    Task          : utility to get/set date & time on spaark2k06   *}
{*                    RTC ISA 8 bits card (very low profile)         *}
{*-------------------------------------------------------------------*}
{*    Author        : DIEGO RODRIGUEZ                                *}
{*    developed on  : 29.01.20                                       *}
{*    last Update   : 09.02.20                                       *}
{*********************************************************************}

{$R-,S-,I-,A-,D-,L-,V-}

program RTC;

Uses                                                   {Turbo 4.0 only}
      Dos, Crt;

const
      RTCAdrPort  = $240;               { Address-Register of the RTC }
      RTCDtaPort  = $241;                  { Data-Register of the RTC }

      SECONDS     =  0;   { Addresses of some memory locations of RTC }
      MINUTES     =  2;
      HOURS       =  4;
      DAYOFWEEK   =  6;
      DAYS        =  7;
      MONTHS      =  8;
      YEARS       =  9;
      STATUSA     = 10;
      STATUSB     = 11;
      STATUSC     = 12;
      STATUSD     = 13;
      DIAGNOSIS   = 14;
      YEARHUNDRED = 50;

var
      parameter: String[1];
      year, month, day, DOW, hour, min, sec, sec100: Word;

{*********************************************************************}
{* RTCREAD: reads the content of a memory location of the RTC        *}
{* Input  : the address of the memory location in the RTC            *}
{* Output : the content of this memory location                      *}
{* Info   : if the Address is outside the permitted area             *}
{*          (0 to 63), the value -1 is returned                      *}
{*********************************************************************}

function RTCRead(Address : integer) : integer;
begin
      inline($fa);                               { disable interrupts } 
      port[RTCAdrPort] := Address;      { transmit Address to the RTC }
      RTCRead := port[RTCDtaPort];                 { read its Content }
      inline($fb)                                 { enable interrupts }
end;

{*********************************************************************}
{* RTCDT  : read a memory location for date or time from the         *}
{*          RTC and convert the result into a binary value           *}
{*          if the RTC works in BCD-Format                           *}
{* Input  : the address of the memory location in the RTC            *}
{* Output : the content of this memory location as binary value      *}
{* Info   : if the address is outside the permitted area (0 - 63)    *}
{*          the value  -1 is returned                                *}
{*********************************************************************}

function RTCDT(Address : integer) : integer;

var Value : integer;                               { store read value }

begin
  if (RTCRead(STATUSB) and 2 = 0) then         { BCD- or Binary-Mode? }
    RTCDT := RTCRead(Address)                        { is Binary-Mode }
  else                                                  { is BCD-Mode }
    begin
      Value := RTCRead(Address); { get Content of the memory location }
                                              { convert BCD to binary }
      RTCDT := (Value shr 4) * 10 + Value and 15
    end
end;

{*********************************************************************}
{* RTCWRITE: write a value into one of the memory locations of RTC   *}
{* Input   : see below                                               *}
{* Output  : none                                                    *}
{* Info    : the address can be between 0 to 63                      *}
{*********************************************************************}

procedure RTCWrite(Address : integer;       { address of the location }
                   Content : byte);                     { new content }

begin
  inline($fa);                                   { disable interrupts } 
  port[RTCAdrPort] := Address;          { transmit address to the RTC }
  port[RTCDtaPort] := Content;                      { write new value }
  inline($fb)                                     { enable interrupts }
end;

{*********************************************************************}
{* RTCWDT : if the RTC works in BCD-Format convert into a binary value *}
{*          and write it into one of the memory locations of RTC     *}
{* Input  : see below                                                *}
{* Output : none                                                     *}
{* Info   : the address can be between 0 to 63                       *}
{*********************************************************************}

procedure RTCWDT(Address : integer;         { address of the location }
                 Content : byte);                       { new content }

begin
  if (RTCRead(STATUSB) and 2 = 0) then         { BCD- or Binary-Mode? }
    RTCWrite(Address, Content)                       { is Binary-Mode }
  else                                                  { is BCD-Mode }
                                    { convert binary to BCD and store }
    RTCWrite(Address, (Content div 10) shl 4 + Content mod 10)
end;

{*********************************************************************}
{* RTCINIT : initialize RTC                                          *}
{* Input   : none                                                    *}
{* Output  : none                                                    *}
{* Info    : none                                                    *}
{*********************************************************************}

procedure RTCInit;
begin
     RTCWrite(STATUSA, $26);
     RTCWrite(STATUSB, $02); 
end;

{*********************************************************************}
{*                            MAIN PROGRAM                           *}
{*********************************************************************}

begin
 {ClrScr;}                                               { Clear Screen }
 WriteLn('RTC (c) 2020 by Diego Rodr¡guez'#13#10);
 if RTCRead(Diagnosis) and 128 = 0 then        { is the Battery o.k.? }
  begin                                         { the Battery is o.k. }
    {if RTCRead(STATUSB) and 2 = 0 then RTCInit;}      { initialize RTC }        
    if ParamCount = 1 then
    begin
      parameter := ParamStr(1);
      case parameter[1] of
       'g','G' : begin
                year := RTCDT(YEARHUNDRED)*100+RTCDT(YEARS);
                month := RTCDT(MONTHS);
                day := RTCDT(DAYS);
                hour := RTCDT(HOURS);
                min := RTCDT(MINUTES);
                sec := RTCDT(SECONDS);
                SetDate(year, month, day);
                SetTime(hour, min, sec, 0);
                WriteLn('System date updated from real time clock '#13#10);
              end;
        's','S' : begin
                GetDate(year, month, day, DOW);
                GetTime(hour, min, sec, sec100);
                RTCInit;                             { initialize RTC }        
                RTCWDT(YEARHUNDRED, year div 100);
                RTCWDT(YEARS, year mod 100);
                RTCWDT(MONTHS, month);
                RTCWDT(DAYS, day);
                RTCWDT(DAYOFWEEK, DOW+1);
                RTCWDT(HOURS, hour);
                RTCWDT(MINUTES, min);
                RTCWDT(SECONDS, sec);
                WriteLn('real time clock updated from system date '#13#10);
              end;
        else
          WriteLn('Usage: RTC [G(et) | S(et)]'); 
      end {case}
    end   {if}
    else
     begin
       WriteLn('Information from the real time clock ');
       WriteLn('====================================================='#13#10);
       WriteLn('- the clock is being operated in ', (RTCRead(STATUSB) and 2)*6+12,
               ' hour-mode');
       WriteLn('- the time: ', RTCDT(HOURS), ':', RTCDT(MINUTES):2,
               ':', RTCDT(SECONDS):2);
       Write('- the date: ');
       case RTCDT(DAYOFWEEK) of                { Read Day of the Week }
         1 : Write('Sunday, ');
         2 : Write('Monday, ');
         3 : Write('Tuesday, ');
         4 : Write('Wednesday, ');
         5 : Write('Thursday, ');
         6 : Write('Friday, ');
         7 : Write('Saturday, ')
       end;
       WriteLn(RTCDT(DAYS), '/', RTCDT(MONTHS), '/',
               RTCDT(YEARHUNDRED), RTCDT(YEARS));
     end
  end
 else                          { the Battery of the RTC is exhausted! }
  Write('       WARNING! The Battery of the clock is low!')
end.
