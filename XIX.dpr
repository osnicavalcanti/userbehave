program XIX;

uses
  Forms,
  Main in 'Main.pas' {Form1},
  uPerfInfo in 'uPerfInfo.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
