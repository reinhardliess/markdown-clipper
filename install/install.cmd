@echo off
REM set directory
cd /D "%~dp0"
if not exist ..\config-user\user.ini copy ..\config-user\user-example.ini ..\config-user\user.ini  >nul
