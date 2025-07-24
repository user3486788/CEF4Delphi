@echo off
REM Test script for URLToPDFConsole application
REM This script demonstrates various usage scenarios

echo Testing URLToPDFConsole Application
echo ===================================

echo.
echo 1. Testing local HTML file to PDF conversion:
echo URLToPDFConsole.exe test.html test_output.pdf
if exist URLToPDFConsole.exe (
    URLToPDFConsole.exe test.html test_output.pdf
    if exist test_output.pdf (
        echo SUCCESS: PDF file created
    ) else (
        echo ERROR: PDF file not created
    )
) else (
    echo ERROR: URLToPDFConsole.exe not found. Please build the project first.
)

echo.
echo 2. Testing local HTML file to PNG conversion:
echo URLToPDFConsole.exe test.html test_output.png
if exist URLToPDFConsole.exe (
    URLToPDFConsole.exe test.html test_output.png
    if exist test_output.png (
        echo SUCCESS: PNG file created
    ) else (
        echo ERROR: PNG file not created
    )
)

echo.
echo 3. Testing HTML with resources (CSS) to PDF:
echo URLToPDFConsole.exe test-resources.html test_resources.pdf --resources-root=.
if exist URLToPDFConsole.exe (
    URLToPDFConsole.exe test-resources.html test_resources.pdf --resources-root=.
    if exist test_resources.pdf (
        echo SUCCESS: PDF with CSS resources created
    ) else (
        echo ERROR: PDF with CSS resources not created
    )
)

echo.
echo 4. Testing SVG content to PDF:
echo URLToPDFConsole.exe test-svg.html test_svg.pdf
if exist URLToPDFConsole.exe (
    URLToPDFConsole.exe test-svg.html test_svg.pdf
    if exist test_svg.pdf (
        echo SUCCESS: SVG PDF created
    ) else (
        echo ERROR: SVG PDF not created
    )
)

echo.
echo 5. Testing with custom timeout:
echo URLToPDFConsole.exe test.html test_timeout.pdf --timeout=30
if exist URLToPDFConsole.exe (
    URLToPDFConsole.exe test.html test_timeout.pdf --timeout=30
    if exist test_timeout.pdf (
        echo SUCCESS: PDF with custom timeout created
    ) else (
        echo ERROR: PDF with custom timeout not created
    )
)

echo.
echo 6. Testing error handling (invalid file):
echo URLToPDFConsole.exe nonexistent.html error_test.pdf
if exist URLToPDFConsole.exe (
    URLToPDFConsole.exe nonexistent.html error_test.pdf
    echo Error handling test completed
)

echo.
echo Testing completed. Check the generated files:
if exist test_output.pdf echo - test_output.pdf
if exist test_output.png echo - test_output.png
if exist test_resources.pdf echo - test_resources.pdf
if exist test_svg.pdf echo - test_svg.pdf
if exist test_timeout.pdf echo - test_timeout.pdf

echo.
echo To test with web URLs (requires internet):
echo URLToPDFConsole.exe https://www.example.com example.pdf
echo URLToPDFConsole.exe https://www.google.com google.png

pause