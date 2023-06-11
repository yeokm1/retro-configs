uses DOS, CRT, RTC;

var
   ctrl: Word;

begin
     ctrl := getRTCreg($0D);
     writeln('Real Time Clock Register 0Dh = ', ctrl, '.');
     write('Battery is ');
     if ctrl < 128 then
        writeln('exhaust.')
     else
        writeln('alive.');
end.