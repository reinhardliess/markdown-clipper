@echo off
cd /D "%~dp0"
SET AHK2EXE="%ProgramW6432%\AutoHotkey\Compiler\Ahk2Exe.exe"

if exist .\deploy\nul rmdir .\deploy /q /s
md deploy
xcopy ..\install .\deploy\install\ /s /y >nul
xcopy ..\config .\deploy\config\ /s /y >nul
xcopy ..\config-user\user-example.ini .\deploy\config-user\ /y
copy ..\package*.json .\deploy
%AHK2EXE% /in ..\markdown-clipper.ahk /out .\deploy\markdown-clipper.exe /icon ..\icons\markdown.ico
