unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, uPerfInfo, PsAPI, TlHelp32, Grids, sSkinManager,
  sSkinProvider;

  const
    RsSystemIdleProcess = 'System Idle Process';
    RsSystemProcess = 'System Process';

  type

   TActiveWindow = record
      Handle : integer;
      Caption : string;
      Name : string;
      Path : string;
      ViewStart : TDateTime;
      ViewEnd  : TDateTime;
      ViewTime : string;
      ActiveTime : string;
      MaxIdle : integer;
      TotalIdle : integer;
      MaxLock : integer;
      TotalLock : integer;
      TipoLock : integer; //0 : Manual; 2: Lock forçado pelo registro de ponto 3; Lock por idle
   end;

  TForm1 = class(TForm)
    tmrIdle: TTimer;
    Button2: TButton;
    Button4: TButton;
    tmrActiveWindow: TTimer;
    strgAtividades: TStringGrid;
    sSkinProvider1: TsSkinProvider;
    sSkinManager1: TsSkinManager;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    procedure Button4Click(Sender: TObject);
    procedure tmrActiveWindowTimer(Sender: TObject);
    procedure tmrIdleTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    function IsWinXP: Boolean;
    function IsWin2k: Boolean;
    function IsWinNT4: Boolean;
    function IsWin3X: Boolean;
    function RunningProcessesList(const List: TStrings): Boolean;
    function GetProcessNameFromWnd(Wnd: HWND): string;
    function GetActiveWindow: TActiveWindow;
    function ProcessFileName(PID: DWORD): string;
    function BuildListPS (List : TStrings): Boolean;
    function BuildListTH (List : TStrings): Boolean;
    function IdleTime: DWord;
    function GetData(ADate: TDateTime): TDateTime;
    procedure AlimentaGrid;

  public

    { Public declarations }
  end;

var
  Form1: TForm1;
  lastWindow : TActiveWindow;
  lstAtividade : array of TActiveWindow;
  bUpdateLast : boolean = false;
  bIgnoraIdle : boolean = false;
  cMaxIdle, cActiveTime, cTotalIdle : cardinal ;



const
  //Colunas da grid de atividades
  _colHandle : integer = 0;
  _ColName : integer = 1;
  _ColCaption : integer = 2;
  _ColPath : integer = 3;
  _ColViewStart : integer = 4;
  _colViewEnd  : integer = 5;
  _colViewTime : integer = 6;
  _colActiveTime : integer = 7;
  _colMaxIdle : integer = 8;
  _colTotalIdle : integer  = 9;
  _colMaxLock : integer  = 10;
  _colTotalLock : integer = 11;
  _colTipoLock : integer = 12;

implementation

    function GetLongPathName(ShortPathName: PChar; LongPathName: PChar; cchBuffer: Integer): Integer; stdcall; external kernel32 name 'GetLongPathNameW';

{$R *.DFM}

function TForm1.IsWinXP: Boolean;
begin
  Result := (Win32Platform = VER_PLATFORM_WIN32_NT) and
    (Win32MajorVersion = 5) and (Win32MinorVersion = 1);
end;

function TForm1.IsWin2k: Boolean;
begin
  Result := (Win32MajorVersion >= 5) and
    (Win32Platform = VER_PLATFORM_WIN32_NT);
end;

function TForm1.IsWinNT4: Boolean;
begin
  Result := Win32Platform = VER_PLATFORM_WIN32_NT;
  Result := Result and (Win32MajorVersion = 4);
end;

function TForm1.IsWin3X: Boolean;
begin
  Result := Win32Platform = VER_PLATFORM_WIN32_NT;
  Result := Result and (Win32MajorVersion = 3) and
    ((Win32MinorVersion = 1) or (Win32MinorVersion = 5) or
    (Win32MinorVersion = 51));
end;

function TForm1.RunningProcessesList(const List: TStrings): Boolean;
begin
  if IsWin3X or IsWinNT4 then
    Result := BuildListPS(List)
  else
    Result := BuildListTH(List);
end;

function TForm1.GetProcessNameFromWnd(Wnd: HWND): string;
var
  List: TStringList;
  PID: DWORD;
  I: Integer;
begin
  Result := '';
  if IsWindow(Wnd) then
  begin
    PID := INVALID_HANDLE_VALUE;
    Windows.GetWindowThreadProcessId(Wnd, @PID);
    List := TStringList.Create;
    try
      if RunningProcessesList(List) then
      begin
        I := List.IndexOfObject(Pointer(PID));
        if I > -1 then
          Result := List[I];
      end;
    finally
      List.Free;
    end;
  end;
end;

function TForm1.BuildListPS(List : TStrings): Boolean;
var
  PIDs: array [0..1024] of DWORD;
  Needed: DWORD;
  I: Integer;
  FileName: string;
begin
  Result := EnumProcesses(@PIDs, SizeOf(PIDs), Needed);
  if Result then
  begin
    for I := 0 to (Needed div SizeOf(DWORD)) - 1 do
    begin
      case PIDs[I] of
        0:
          FileName := RsSystemIdleProcess;
        2:
          if IsWinNT4 then
            FileName := RsSystemProcess
          else
            FileName := ProcessFileName(PIDs[I]);
          8:
          if IsWin2k or IsWinXP then
            FileName := RsSystemProcess
          else
            FileName := ProcessFileName(PIDs[I]);
          else
            FileName := ProcessFileName(PIDs[I]);
      end;
      if FileName <> '' then
        List.AddObject(FileName, Pointer(PIDs[I]));
    end;
  end;
end;

function TForm1.BuildListTH(List : TStrings): Boolean;
var
  SnapProcHandle: THandle;
  ProcEntry: TProcessEntry32;
  NextProc: Boolean;
  FileName: string;
begin
  SnapProcHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  Result := (SnapProcHandle <> INVALID_HANDLE_VALUE);
  if Result then
    try
      ProcEntry.dwSize := SizeOf(ProcEntry);
      NextProc := Process32First(SnapProcHandle, ProcEntry);
      while NextProc do
      begin
        if ProcEntry.th32ProcessID = 0 then
        begin
          FileName := RsSystemIdleProcess;
        end
        else
        begin
          if IsWin2k or IsWinXP then
          begin
            FileName := ProcessFileName(ProcEntry.th32ProcessID);
            if FileName = '' then
              FileName := ProcEntry.szExeFile;
          end
          else
          begin
            FileName := ProcEntry.szExeFile;
//              if not FullPath then
//                FileName := ExtractFileName(FileName);
          end;
        end;
        List.AddObject(FileName, Pointer(ProcEntry.th32ProcessID));
        NextProc := Process32Next(SnapProcHandle, ProcEntry);
      end;
    finally
      CloseHandle(SnapProcHandle);
    end;
end;


procedure TForm1.Button4Click(Sender: TObject);
begin
//  RunningProcessesList(ListBox3.Items);
end;

function TForm1.GetActiveWindow : TActiveWindow;
var
  Handle: THandle;
  Len: LongInt;
  Title, NameProc: string;
  PID : DWORD;
begin
  Handle := GetForegroundWindow;

  if Handle <> 0 then
  begin
    Windows.GetWindowThreadProcessId(Handle, @PID);
    Len := GetWindowTextLength(Handle) + 1;
    SetLength(Title, Len);
    GetWindowText(Handle, PChar(Title), Len);
    Result.Handle := Handle;
    Result.Caption := TrimRight(Title);
    NameProc := GetProcessNameFromWnd(Handle);
    Result.Name := ExtractFileName(NameProc);
    Result.Path := ExtractFilePath(NameProc);
    Result.ViewStart := Now;
  end;
end;

function TForm1.ProcessFileName(PID: DWORD): string;
var
  Handle: THandle;
begin
  Result := '';
  Handle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, PID);
  if Handle <> 0 then
    try
      SetLength(Result, MAX_PATH);
//        if FullPath then
//        begin
        if GetModuleFileNameEx(Handle, 0, PChar(Result), MAX_PATH) > 0 then
          SetLength(Result, StrLen(PChar(Result)))
        else
          Result := '';
(*
      end
      else
      begin
        if GetModuleBaseNameA(Handle, 0, PChar(Result), MAX_PATH) > 0 then
          SetLength(Result, StrLen(PChar(Result)))
        else
          Result := '';
      end;
*)
    finally
      CloseHandle(Handle);
    end;
end;

procedure TForm1.tmrActiveWindowTimer(Sender: TObject);
var _ActiveWindow : TActiveWindow;
    TS : TTimeStamp;
begin
  _ActiveWindow := GetActiveWindow;

(*
  if bFirstTime then
  begin
    //Inicializa lista e insere primeiro registro
    SetLength(lstAtividade, 1);
    lstAtividade[0].Handle := _ActiveWindow.Handle;
    lstAtividade[0].Caption := _ActiveWindow.Caption;
    lstAtividade[0].Name := _ActiveWindow.Name;
    lstAtividade[0].Local := _ActiveWindow.Local;
    lstAtividade[0].ViewStart := _ActiveWindow.ViewStart;
    AlimentaGrid;
    bFirstTime := false;
  end
*)
  if _ActiveWindow.Caption <> lastWindow.Caption then
  begin
    //Calcula tempo da janela anterior ativa
    if bUpdateLast then
    begin
      lstAtividade[High(lstAtividade)].ViewEnd := Now;

      TS := DateTimeToTimeStamp(now - getdata(lastWindow.ViewStart));
      Dec(TS.Date, TTimeStamp(DateTimeToTimeStamp(0)).Date);
      lstAtividade[High(lstAtividade)].ViewTime := FormatDateTime('hh:nn:ss', TS.Date + (TS.Time div 1000) / SecsPerDay);

      lstAtividade[High(lstAtividade)].ActiveTime := FormatDateTime('hh:nn:ss', TS.Date + cActiveTime / SecsPerDay);

      lstAtividade[High(lstAtividade)].MaxIdle := cMaxIdle;
      lstAtividade[High(lstAtividade)].TotalIdle := cTotalIdle;
      cTotalIdle := 0;
      cActiveTime := 0;
      cMaxIdle := 0;
    end;



    //Insere novo registro
    SetLength(lstAtividade, Length(lstAtividade) + 1);
    lstAtividade[High(lstAtividade)].Handle := _ActiveWindow.Handle;
    lstAtividade[High(lstAtividade)].Caption := _ActiveWindow.Caption;
    lstAtividade[High(lstAtividade)].Name :=  _ActiveWindow.Name;
    lstAtividade[High(lstAtividade)].Path := _ActiveWindow.Path;
    lstAtividade[High(lstAtividade)].ViewStart := getdata(_ActiveWindow.ViewStart);

//    ListBox3.Items.Add(DateTimeToStr(now) + ' ' + _ActiveWindow.Caption + ' ' + 'Tempo Total: ' + lastWindow.ViewTime);
//    ListBox3.Items.Add(_ActiveWindow.Name);

    AlimentaGrid;

    lastWindow := _ActiveWindow;

    bUpdateLast := true;
  end;
end;


function TForm1.IdleTime: DWord;
var
  LastInput: TLastInputInfo;
begin
  LastInput.cbSize := SizeOf(TLastInputInfo);
  GetLastInputInfo(LastInput);
  Result := (GetTickCount - LastInput.dwTime) DIV 1000;
end;

procedure TForm1.tmrIdleTimer(Sender: TObject);
begin
  if IdleTime > cMaxIdle then
     cMaxIdle := IdleTime;

  if IdleTime > 0 then
    cTotalIdle := cTotalIdle + 1
  else
    cActiveTime := cActiveTime + 1;

  Label1.Caption := Format('Tempo Ocioso: %d s', [IdleTime]);
  Label2.Caption := Format('Tempo Ocioso Máximo: %d s', [cMaxIdle]);
  Label3.Caption := Format('Tempo Ocioso Total: %d s', [cTotalIdle]);
  Label4.Caption := Format('Tempo Ativo: %d s', [cActiveTime]);

end;

function TForm1.GetData(ADate: TDateTime): TDateTime;
begin
  try
    if FormatDateTime('DD/MM/YYYY', ADate) > '30/12/1899' then
      result := ADate
    else
      result := Now;
  except
    result := Now;
  end;
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  //Define o caption das colunas da grid da grid de atividades
  strgAtividades.Cells[_colHandle, 0] := 'Handle';
  strgAtividades.Cells[_ColName, 0] := 'Programa';
  strgAtividades.Cells[_ColCaption, 0] := 'Título da Janela';
  strgAtividades.Cells[_ColPath, 0] := 'Local do Executável';
  strgAtividades.Cells[_ColViewStart, 0] := 'ViewStart';
  strgAtividades.Cells[_colViewEnd, 0] := 'ViewEnd';
  strgAtividades.Cells[_colViewTime, 0] := 'ViewTime';
  strgAtividades.Cells[_colActiveTime, 0] := 'Tempo Ativo';
  strgAtividades.Cells[_colMaxIdle, 0] := 'MaxIdle';
  strgAtividades.Cells[_colTotalIdle, 0] := 'TotalIdle';
  strgAtividades.Cells[_colMaxLock, 0] := 'MaxLock';
  strgAtividades.Cells[_colTotalLock, 0] := 'TotalLock';
  strgAtividades.Cells[_colTipoLock, 0] := 'TipoLock';
end;

procedure TForm1.AlimentaGrid;
begin
  if length(lstAtividade) > 1 then
  begin
    //Atualzia as informações do registro anterior
    strgAtividades.Cells[_colViewEnd, High(lstAtividade)] := DateTimeToStr(lstAtividade[Pred(High(lstAtividade))].ViewEnd);
    strgAtividades.Cells[_colViewTime, High(lstAtividade)] := lstAtividade[Pred(High(lstAtividade))].ViewTime;
    strgAtividades.Cells[_colActiveTime, High(lstAtividade)] := lstAtividade[Pred(High(lstAtividade))].ActiveTime;
    strgAtividades.Cells[_colMaxIdle, High(lstAtividade)] := IntToStr(lstAtividade[Pred(High(lstAtividade))].MaxIdle);
    strgAtividades.Cells[_colTotalIdle, High(lstAtividade)] := IntToStr(lstAtividade[Pred(High(lstAtividade))].TotalIdle);
    strgAtividades.Cells[_colMaxLock, High(lstAtividade)] := inttostr(lstAtividade[Pred(High(lstAtividade))].MaxLock);
    strgAtividades.Cells[_colTotalLock, High(lstAtividade)] := IntToStr(lstAtividade[Pred(High(lstAtividade))].TotalLock);
    strgAtividades.Cells[_colTipoLock, High(lstAtividade)] := inttostr(lstAtividade[Pred(High(lstAtividade))].TipoLock);

  if length(lstAtividade) = strgAtividades.RowCount then
    strgAtividades.RowCount := strgAtividades.RowCount + 1;
  end;

  //Registra as informações do novo registro
  strgAtividades.Cells[_colHandle, pred(strgAtividades.RowCount)] := IntToStr(lstAtividade[High(lstAtividade)].Handle);
  strgAtividades.Cells[_ColName, pred(strgAtividades.RowCount)] := lstAtividade[High(lstAtividade)].Name;
  strgAtividades.Cells[_ColCaption, pred(strgAtividades.RowCount)] := lstAtividade[High(lstAtividade)].Caption;
  strgAtividades.Cells[_ColPath, pred(strgAtividades.RowCount)] := lstAtividade[High(lstAtividade)].Path;
  strgAtividades.Cells[_ColViewStart, pred(strgAtividades.RowCount)] := DateTimeToStr(lstAtividade[High(lstAtividade)].ViewStart);

end;

end.
