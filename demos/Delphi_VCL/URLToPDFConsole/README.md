# URLToPDFConsole Demo

Enhanced console application for converting URLs/HTML/SVG files to PDF or PNG format.

## Features

- Convert web pages (URLs) to PDF or PNG
- Convert local HTML/SVG files to PDF or PNG  
- Automatic content size detection for optimal output
- Support for relative paths in local HTML files
- Configurable timeout
- Zero margins for PDF output
- Support for dynamic/JavaScript-rendered content

## Command Line Interface

```
URLToPDFConsole.exe inputuri output.file [--resources-root=path] [--timeout=600]
```

### Parameters

- `inputuri`: URL (http/https) or local file path (HTML/SVG)
- `output.file`: Output file path (.pdf or .png extension determines format)
- `--resources-root=path`: Optional. Base directory for relative paths in local HTML files (default: resources)
- `--timeout=600`: Optional. Timeout in seconds (default: 600)

### Examples

```bash
# Convert web page to PDF
URLToPDFConsole.exe https://www.example.com output.pdf

# Convert local HTML to PNG with custom resources directory
URLToPDFConsole.exe index.html report.png --resources-root=./assets/

# Convert SVG to PDF with custom timeout
URLToPDFConsole.exe chart.svg chart.pdf --timeout=120

# Test with included test file
URLToPDFConsole.exe test.html test.pdf
```

## Technical Details

- Based on CEF4Delphi's off-screen rendering (OSR)
- Uses subprocess architecture (URLToPDFConsole.exe + URLToPDFConsole_sp.exe)
- Content size detection using JavaScript evaluation
- PDF generation with custom page sizing and zero margins
- Enhanced error handling in threaded environment

## Building

1. Ensure CEF4Delphi source is available
2. Open URLToPDFConsole.dpr in Delphi
3. Build both URLToPDFConsole.exe and URLToPDFConsole_sp.exe
4. Ensure both executables are in the same directory with CEF binaries

## Requirements

- CEF4Delphi framework
- CEF binaries (see main CEF4Delphi readme for download links)
- Windows 10+ (for current CEF version)
- Delphi compiler (tested with recent versions)