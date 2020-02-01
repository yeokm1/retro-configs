unit Play;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  mmsystem,Forms, Dialogs, StdCtrls, Buttons, Spin, ExtCtrls;

  var ptrs:pointer;
  var htime:thandle;

const wmsound= wm_user+13;
var x:byte;
type
  TForm1 = class(TForm)
    Label1: TLabel;
    Button1: TButton;
    SpeedButton1: TSpeedButton;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    SpinEdit1: TSpinEdit;
    SpinEdit2: TSpinEdit;
    Shape1: TShape;
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure CheckMessages(var Msg: TMsg; var Handled: Boolean);
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure Shape1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation
procedure timercallback(hwindow:hwnd;msg:word;idtimer:word;dwtime:longint); far; external 'W3XAC97';
function finish:byte; far; external 'W3XAC97';
{$R *.DFM}

procedure int5; interrupt;var aa,bb,cc,dd,ee:word; begin
{PostMessage(form1.handle,35,35,35);{127}
PostMessage(form1.handle,wmsound,13,13);{124}
{timercallback(0,0,0,0);{try the danger}
end;


procedure Tform1.CheckMessages(var Msg: TMsg; var Handled: Boolean);
begin

if msg.message=wmsound then begin
timercallback(0,0,0,0);
end;

end;




procedure TForm1.Button2Click(Sender: TObject);
begin
x:=0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin

  Application.OnMessage:=CheckMessages;
{x:=3;
while x=3 do begin
timercallback(0,0,0,0);
application.processmessages;
end;}

end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
x:=0;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
timercallback(0,0,0,0);
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin

if(x=3)then x:=1 else x:=3;
while x=3 do begin
timercallback(0,0,0,0);
application.processmessages;
end;
end;

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
if(htime=0)then begin
ptrs:=@int5;
htime:=timesetevent(spinedit1.value,spinedit2.value,  TTimeCallBack(ptrs),0,TIME_PERIODIC);
end;
end;

procedure TForm1.BitBtn2Click(Sender: TObject);
begin
if not(htime=0) then begin
timekillEvent(htime);
htime:=0;
end;
end;

procedure TForm1.Shape1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
finish;
caption:='end';

end;

end.
