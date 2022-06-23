@echo off
REM set directory
cd /D "%~dp0"
where.exe node.exe >nul 2>&1
if Errorlevel 1 (
  echo.
  echo Please install Node.js first, opening website...
  echo.
  start https://nodejs.org/en/download/
) else (
  if not exist ..\config-user\user.ini copy ..\config-user\user-example.ini ..\config-user\user.ini  >nul
  echo Installing dependencies
  cd ..
  if exist markdown-clipper.exe (
    npm install --omit=dev
  ) else (
    npm install
  )
)
