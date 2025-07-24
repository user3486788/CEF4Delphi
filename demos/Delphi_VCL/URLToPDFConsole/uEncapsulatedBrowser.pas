unit uEncapsulatedBrowser;

{$I ..\..\..\source\cef.inc}

interface

uses
  {$IFDEF DELPHI16_UP}
  System.SyncObjs, System.SysUtils, System.StrUtils,
  {$ELSE}
  SyncObjs, SysUtils,
  {$ENDIF}
  uCEFTypes, uCEFBrowserThread;

type
  TOutputFormat = (ofPNG, ofPDF);
  
  TCommandLineParams = record
    InputURI: ustring;
    OutputFile: ustring;
    ResourcesRoot: ustring;
    TimeoutSeconds: integer;
    OutputFormat: TOutputFormat;
    Valid: boolean;
    ErrorMsg: ustring;
  end;

  TEncapsulatedBrowser = class
    protected
      FThread       : TCEFBrowserThread;
      FWidth        : integer;
      FHeight       : integer;
      FDelayMs      : integer;
      FScale        : single;
      FSnapshotPath : ustring;
      FErrorText    : ustring;
      FFirst        : boolean;
      FParams       : TCommandLineParams;

      procedure Thread_OnError(Sender: TObject);
      procedure Thread_OnSnapshotAvailable(Sender: TObject);
      procedure Thread_OnPDFPrintFinished(Sender: TObject);

    public
      constructor Create(aWidth, aHeight : integer; const aParams: TCommandLineParams);
      destructor  Destroy; override;
      procedure   LoadURL(const aURL : ustring);
      function    UpdateBrowserSize(aNewWidth, aNewHeight : integer): boolean;

      property Width           : integer    read FWidth;
      property Height          : integer    read FHeight;
      property DelayMs         : integer    read FDelayMs        write FDelayMs;
      property Scale           : single     read FScale          write FScale;
      property SnapshotPath    : ustring    read FSnapshotPath   write FSnapshotPath;
      property ErrorText       : ustring    read FErrorText;
      property Params          : TCommandLineParams read FParams;
  end;

function  ParseCommandLine: TCommandLineParams;
procedure CreateGlobalCEFApp;
function  WaitForMainAppEvent : boolean;
procedure WriteResult;

implementation

uses
  uCEFApplication;

var
  MainAppEvent        : TEvent;
  EncapsulatedBrowser : TEncapsulatedBrowser = nil;

function ParseCommandLine: TCommandLineParams;
var
  i: integer;
  Param, ParamName, ParamValue: string;
  ExtractedExt: string;
begin
  // Initialize with defaults
  Result.InputURI := '';
  Result.OutputFile := '';
  Result.ResourcesRoot := 'resources';
  Result.TimeoutSeconds := 600;
  Result.OutputFormat := ofPNG;
  Result.Valid := False;
  Result.ErrorMsg := '';

  // Need at least 2 parameters: inputuri and output.file
  if ParamCount < 2 then
  begin
    Result.ErrorMsg := 'URLToPDFConsole - Enhanced console application for converting URLs/HTML/SVG to PDF/PNG' + #13#10 + #13#10 +
                      'Usage: URLToPDFConsole.exe inputuri output.file [--resources-root=path] [--timeout=600]' + #13#10 + #13#10 +
                      'Parameters:' + #13#10 +
                      '  inputuri        URL (http/https) or local file path (HTML/SVG)' + #13#10 +
                      '  output.file     Output file path (.pdf or .png extension determines format)' + #13#10 +
                      '  --resources-root=path  Base directory for relative paths (default: resources)' + #13#10 +
                      '  --timeout=600   Timeout in seconds (default: 600)' + #13#10 + #13#10 +
                      'Examples:' + #13#10 +
                      '  URLToPDFConsole.exe https://www.example.com output.pdf' + #13#10 +
                      '  URLToPDFConsole.exe index.html report.png --resources-root=./assets/' + #13#10 +
                      '  URLToPDFConsole.exe chart.svg chart.pdf --timeout=120' + #13#10 + #13#10 +
                      'Features:' + #13#10 +
                      '  • Automatic content size detection for optimal output' + #13#10 +
                      '  • Zero margins for PDF output' + #13#10 +
                      '  • Support for dynamic/JavaScript-rendered content' + #13#10 +
                      '  • Local file support with relative path resolution';
    Exit;
  end;

  // Get required parameters
  Result.InputURI := ParamStr(1);
  Result.OutputFile := ParamStr(2);

  // Determine output format from file extension
  ExtractedExt := LowerCase(ExtractFileExt(Result.OutputFile));
  if ExtractedExt = '.pdf' then
    Result.OutputFormat := ofPDF
  else if (ExtractedExt = '.png') or (ExtractedExt = '.bmp') then
    Result.OutputFormat := ofPNG
  else
  begin
    Result.ErrorMsg := 'Output file must have .pdf or .png extension. Got: ' + ExtractedExt;
    Exit;
  end;

  // Parse optional parameters
  for i := 3 to ParamCount do
  begin
    Param := ParamStr(i);
    if Pos('--', Param) = 1 then
    begin
      if Pos('=', Param) > 0 then
      begin
        ParamName := Copy(Param, 3, Pos('=', Param) - 3);
        ParamValue := Copy(Param, Pos('=', Param) + 1, Length(Param));
        
        if ParamName = 'resources-root' then
          Result.ResourcesRoot := ParamValue
        else if ParamName = 'timeout' then
        begin
          try
            Result.TimeoutSeconds := StrToInt(ParamValue);
            if Result.TimeoutSeconds <= 0 then
            begin
              Result.ErrorMsg := 'Timeout must be a positive integer';
              Exit;
            end;
          except
            Result.ErrorMsg := 'Invalid timeout value: ' + ParamValue;
            Exit;
          end;
        end
        else
        begin
          Result.ErrorMsg := 'Unknown parameter: ' + ParamName;
          Exit;
        end;
      end
      else
      begin
        Result.ErrorMsg := 'Invalid parameter format: ' + Param;
        Exit;
      end;
    end
    else
    begin
      Result.ErrorMsg := 'Invalid parameter: ' + Param;
      Exit;
    end;
  end;

  // Validate input URI
  if Length(Result.InputURI) = 0 then
  begin
    Result.ErrorMsg := 'Input URI cannot be empty';
    Exit;
  end;

  // Validate output file
  if Length(Result.OutputFile) = 0 then
  begin
    Result.ErrorMsg := 'Output file cannot be empty';
    Exit;
  end;

  Result.Valid := True;
end;

function PrepareInputURI(const InputURI, ResourcesRoot: ustring): ustring;
var
  AbsolutePath: string;
begin
  Result := InputURI;
  
  // Check if it's a URL (starts with http:// or https://)
  if (Pos('http://', LowerCase(InputURI)) = 1) or (Pos('https://', LowerCase(InputURI)) = 1) then
  begin
    // It's already a URL, use as-is
    Exit;
  end;
  
  // It's a local file, convert to absolute path and file:// URL
  if FileExists(InputURI) then
    AbsolutePath := ExpandFileName(InputURI)
  else
  begin
    // Try relative to resources root
    AbsolutePath := IncludeTrailingPathDelimiter(ResourcesRoot) + InputURI;
    if FileExists(AbsolutePath) then
      AbsolutePath := ExpandFileName(AbsolutePath)
    else
    begin
      // Use original path and let CEF handle the error
      AbsolutePath := ExpandFileName(InputURI);
    end;
  end;
  
  // Convert to file:// URL
  Result := 'file:///' + StringReplace(AbsolutePath, '\', '/', [rfReplaceAll]);
end;

procedure GlobalCEFApp_OnContextInitialized;
var
  Params: TCommandLineParams;
  FinalURL: ustring;
begin
  Params := ParseCommandLine;
  
  if not Params.Valid then
  begin
    WriteLn('Error: ' + Params.ErrorMsg);
    if assigned(MainAppEvent) then MainAppEvent.SetEvent;
    Exit;
  end;

  FinalURL := PrepareInputURI(Params.InputURI, Params.ResourcesRoot);
  WriteLn('Loading: ' + FinalURL);
  WriteLn('Output: ' + Params.OutputFile + ' (' + 
          {$IFDEF DELPHI16_UP}
          IfThen(Params.OutputFormat = ofPDF, 'PDF', 'PNG')
          {$ELSE}
          case Params.OutputFormat of ofPDF: 'PDF'; else 'PNG'; end
          {$ENDIF}
          + ')');

  // Create browser with initial size - will be auto-adjusted based on content
  EncapsulatedBrowser := TEncapsulatedBrowser.Create(1024, 768, Params);
  EncapsulatedBrowser.LoadURL(FinalURL);
end;

function WaitForMainAppEvent : boolean;
var
  Params: TCommandLineParams;
  TimeoutMs: integer;
begin
  Result := True;
  
  Params := ParseCommandLine;
  if Params.Valid then
    TimeoutMs := Params.TimeoutSeconds * 1000
  else
    TimeoutMs := 600000; // Default 10 minutes

  if (MainAppEvent.WaitFor(TimeoutMs) = wrTimeout) then
    begin
      WriteLn('Timeout expired after ' + IntToStr(TimeoutMs div 1000) + ' seconds!');
      Result := False;
    end;
end;

procedure WriteResult;
begin
  if (EncapsulatedBrowser = nil) then
    WriteLn('Error: Browser initialization failed')
   else
    if (length(EncapsulatedBrowser.ErrorText) > 0) then
      WriteLn('Error: ' + EncapsulatedBrowser.ErrorText)
     else
      WriteLn('Success: Output saved as ' + EncapsulatedBrowser.SnapshotPath);
end;

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                            := TCefApplication.Create;
  GlobalCEFApp.WindowlessRenderingEnabled := True;
  GlobalCEFApp.ShowMessageDlg             := False;                    // This demo shouldn't show any window, just console messages.
  GlobalCEFApp.BrowserSubprocessPath      := 'URLToPDFConsole_sp.exe'; // This is the other EXE for the CEF subprocesses. It's on the same directory as this app.
  GlobalCEFApp.BlinkSettings              := 'hideScrollbars';         // This setting removes all scrollbars to capture a cleaner snapshot
  GlobalCEFApp.OnContextInitialized       := GlobalCEFApp_OnContextInitialized;

{
  // In case you use a custom directory for the CEF binaries you have to set these properties
  // here and in the subprocess
  GlobalCEFApp.FrameworkDirPath     := 'c:\cef';
  GlobalCEFApp.ResourcesDirPath     := 'c:\cef';
  GlobalCEFApp.LocalesDirPath       := 'c:\cef\locales';
  GlobalCEFApp.SetCurrentDir        := True;
}

  GlobalCEFApp.StartMainProcess;
end;

constructor TEncapsulatedBrowser.Create(aWidth, aHeight : integer; const aParams: TCommandLineParams);
begin
  inherited Create;

  FFirst         := True;
  FThread        := nil;
  FWidth         := aWidth;
  FHeight        := aHeight;
  FDelayMs       := 1000; // Increased delay for dynamic content
  FScale         := 1;    // This is the relative scale to a 96 DPI screen. It's calculated with the formula : scale = custom_DPI / 96
  FSnapshotPath  := aParams.OutputFile;
  FErrorText     := '';
  FParams        := aParams;
end;

destructor TEncapsulatedBrowser.Destroy;
begin
  if (FThread <> nil) then
    begin
      if FThread.TerminateBrowserThread then
        FThread.WaitFor;

      FreeAndNil(FThread);
    end;

  inherited Destroy;
end;

procedure TEncapsulatedBrowser.LoadURL(const aURL : ustring);
begin
  if (FThread = nil) then
    begin
      FThread                     := TCEFBrowserThread.Create(aURL, FWidth, FHeight, FDelayMs, FScale, FParams.OutputFormat, FSnapshotPath);
      FThread.OnError             := Thread_OnError;
      FThread.OnSnapshotAvailable := Thread_OnSnapshotAvailable;
      FThread.OnPDFPrintFinished  := Thread_OnPDFPrintFinished;
      FThread.Start;
    end
   else
    FThread.LoadUrl(aURL);
end;

function TEncapsulatedBrowser.UpdateBrowserSize(aNewWidth, aNewHeight : integer): boolean;
begin
  FWidth  := aNewWidth;
  FHeight := aNewHeight;
  Result  := assigned(FThread) and
             FThread.UpdateBrowserSize(aNewWidth, aNewHeight);
end;

procedure TEncapsulatedBrowser.Thread_OnError(Sender: TObject);
begin
  // This code is executed in the TCEFBrowserThread thread context while the main application thread is waiting for MainAppEvent.

  FErrorText := 'Error';

  if (FThread.ErrorCode <> 0) then
    FErrorText := FErrorText + ' ' + inttostr(FThread.ErrorCode);

  FErrorText := FErrorText + ' : ' + FThread.ErrorText;

  if (length(FThread.FailedUrl) > 0) then
    FErrorText := FErrorText + ' - ' + FThread.FailedUrl;

  if assigned(MainAppEvent) then
    MainAppEvent.SetEvent;
end;

procedure TEncapsulatedBrowser.Thread_OnSnapshotAvailable(Sender: TObject);
begin
  // This code is executed in the TCEFBrowserThread thread context while the main application thread is waiting for MainAppEvent.

  // For PNG/bitmap output, save the snapshot
  if FParams.OutputFormat = ofPNG then
  begin
    if (FThread = nil) or not(FThread.SaveSnapshotToFile(FSnapshotPath)) then
      FErrorText := 'There was an error copying the snapshot';

    if assigned(MainAppEvent) then
      MainAppEvent.SetEvent;
  end;
  // For PDF output, the Thread_OnPDFPrintFinished will handle completion
end;

procedure TEncapsulatedBrowser.Thread_OnPDFPrintFinished(Sender: TObject);
begin
  // This code is executed in the TCEFBrowserThread thread context while the main application thread is waiting for MainAppEvent.
  
  if assigned(MainAppEvent) then
    MainAppEvent.SetEvent;
end;

initialization
  MainAppEvent := TEvent.Create;

finalization
  MainAppEvent.Free;
  if (EncapsulatedBrowser <> nil) then FreeAndNil(EncapsulatedBrowser);

end.
