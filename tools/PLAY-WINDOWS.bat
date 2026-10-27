@echo off
cd /d "%~dp0"
title Silver Lake GP - server running - keep this window open
echo ==================================================
echo    SILVER LAKE GP - starting the game server...
echo ==================================================
echo.
echo Do NOT close this window while playing!
echo The game opens in your browser in a few seconds.
echo If the browser shows an error page, wait 3 seconds and press F5.
echo.

set PYCMD=
py -c "import http.server" >nul 2>nul
if %errorlevel%==0 set PYCMD=py
if not defined PYCMD python -c "import http.server" >nul 2>nul
if not defined PYCMD if %errorlevel%==0 set PYCMD=python

if defined PYCMD (
  start "" /min cmd /c "timeout /t 3 /nobreak >nul & start http://localhost:8080"
  echo Serving at http://localhost:8080  (game window opens automatically)
  echo.
  %PYCMD% -m http.server 8080
  echo.
  echo Server stopped. If you see "Address already in use" above, port 8080
  echo is busy: close other server windows or restart the PC, then run this file again.
  pause
  goto end
)

where npx >nul 2>nul
if %errorlevel%==0 (
  start "" /min cmd /c "timeout /t 4 /nobreak >nul & start http://localhost:8080"
  npx --yes serve -l 8080 .
  pause
  goto end
)

echo ==================================================
echo  Python or Node.js was not found on this PC.
echo  The game needs one of them as a tiny local server.
echo.
echo  FREE FIX (2 minutes):
echo  1) Install Python from https://www.python.org/downloads/
echo     IMPORTANT: tick the box "Add python.exe to PATH" while installing.
echo  2) Double-click PLAY-WINDOWS.bat again.
echo ==================================================
pause
:end
