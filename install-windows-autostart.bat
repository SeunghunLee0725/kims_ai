@echo off
:: KIMS AI 프록시 Windows 자동 시작 등록
:: 이 파일을 Windows에서 더블클릭하여 실행하세요.

set STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set VBS_SRC=\\wsl$\Ubuntu-22.04\home\seunghun\shlee\20260331_vscode\start-proxy-windows.vbs
set VBS_DST=%STARTUP_DIR%\kims-ai-proxy.vbs

echo [설치] KIMS AI 프록시 자동 시작 등록 중...

if not exist "%VBS_SRC%" (
    echo [오류] start-proxy-windows.vbs 파일을 찾을 수 없습니다.
    echo        경로: %VBS_SRC%
    pause
    exit /b 1
)

copy /Y "%VBS_SRC%" "%VBS_DST%"

if %errorlevel% == 0 (
    echo [성공] 자동 시작 등록 완료!
    echo        위치: %VBS_DST%
    echo.
    echo  Windows 시작 시 프록시가 자동으로 실행됩니다.
    echo  지금 바로 시작하려면 해당 .vbs 파일을 더블클릭하세요.
) else (
    echo [오류] 등록에 실패했습니다.
)
pause
