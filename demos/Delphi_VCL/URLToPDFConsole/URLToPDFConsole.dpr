program URLToPDFConsole;

{$I ..\..\..\source\cef.inc}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF DELPHI16_UP}
  System.SysUtils,
  {$ELSE}
  SysUtils,
  {$ENDIF}
  uCEFApplication,
  uEncapsulatedBrowser in 'uEncapsulatedBrowser.pas',
  uCEFBrowserThread in 'uCEFBrowserThread.pas';

const
  IMAGE_FILE_LARGE_ADDRESS_AWARE = $0020;

// CEF needs to set the LARGEADDRESSAWARE ($20) flag which allows 32-bit processes to use up to 3GB of RAM.
{$IFDEF WIN32}{$SetPEFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}{$ENDIF}

// URLToPDFConsole - Enhanced console application for converting URLs/HTML/SVG to PDF/PNG files
//
// This application loads URLs or local HTML/SVG files and saves them as PDF or PNG files.
// Output format is determined by the output file extension (.pdf or .png).
// Page dimensions are automatically determined by the loaded content size.
// 
// Command Line Interface:
// URLToPDFConsole.exe inputuri output.file [--resources-root=path] [--timeout=600]
//
// Parameters:
// - inputuri: URL (http/https) or local file path (HTML/SVG)  
// - output.file: Output file path (.pdf or .png extension determines format)
// - --resources-root=path: Optional. Base directory for relative paths in local HTML files (default: ./resources/)
// - --timeout=600: Optional. Timeout in seconds (default: 600)
//
// Examples:
// URLToPDFConsole.exe https://www.example.com output.pdf
// URLToPDFConsole.exe index.html report.png --resources-root=./assets/
// URLToPDFConsole.exe chart.svg chart.pdf --timeout=120
//
// Features:
// - Custom page size based on actual content dimensions, zero margins for PDF
// - Support for HTML/SVG files with relative path resolution using resources-root
// - Wait for complete loading including JavaScript-rendered content
// - PDF and PNG output formats
// - Configurable timeout
//
// Architecture:
// - Uses off-screen rendering (OSR) mode
// - Encapsulated in a custom thread using URLToPDFConsole_sp.exe for CEF subprocesses
// - Content size detection after full page load
// - Enhanced error handling in threaded environment

begin
  try
    try
      CreateGlobalCEFApp;
      if WaitForMainAppEvent then
        WriteResult;
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    DestroyGlobalCEFApp;
  end;
end.
