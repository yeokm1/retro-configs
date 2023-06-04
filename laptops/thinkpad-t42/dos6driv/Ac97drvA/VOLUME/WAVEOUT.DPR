program Waveout;

uses
  Forms,
  Wout in 'WOUT.PAS' {Form1};

{$R *.RES}

begin
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
