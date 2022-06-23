#NoEnv
#Warn All, OutputDebug
; to avoid warnings from bigA library
#Warn UseUnsetLocal, Off
#SingleInstance force
#MaxThreadsPerHotkey 1

; include all libraries and modules here
#Include, %A_ScriptDir%\node_modules\rd-regexp-ahk\rd_RegExp.ahk
#Include, %A_ScriptDir%\node_modules\rd-utility-ahk\rd_Utility.ahk
#Include, %A_ScriptDir%\node_modules\rd-config-ahk\rd_WinIniFile.ahk
#Include, %A_ScriptDir%\node_modules\rd-config-ahk\rd_ConfigWithDefaults.ahk
#Include, %A_ScriptDir%\node_modules\biga.ahk\export.ahk
#Include, %A_ScriptDir%\lib\winclip\WinClipAPI.ahk
#Include, %A_ScriptDir%\lib\winclip\WinClip.ahk

#Include, %A_ScriptDir%\modules\rd_WinClip.ahk
#Include, %A_ScriptDir%\modules\AppMarkdownClipper.ahk
#include, %A_ScriptDir%\modules\markdown.ahk
#Include, %A_ScriptDir%\modules\nonobj-warn.ahk

global A := new bigA()
global U := new rd_Utility()
global Clip := new rd_WinClip()

; create App instance
global App := new AppMarkdownClipper().init()

return

; #Include, %A_ScriptDir%\lib\ahk-lib\debug.ahk
