uses DOS, CRT, RTC;

var
   year, month, day, DOW, hour, min, sec, sec100: Word;

begin
     initRTC;
     GetDate(year, month, day, DOW);
     GetTime(Hour, min, sec, sec100);
     year := year mod 100;
     setRTCreg(RTC_year, year);
     setRTCreg(RTC_month, month);
     setRTCreg(RTC_day, day);
     setRTCreg(RTC_hour, hour);
     setRTCreg(RTC_minute, min);
     setRTCreg(RTC_second, sec);
     writeln('Real Time Clock updated from system date.');
     writeln(day, '/', month, '/', year);
     GetTime(Hour, min, sec, sec100);
     writeln(Hour, ':', min, ':', sec);
end.