/*
 * Central management class for "Markdown Clipper"
 * Copyright(c) 2021-2022 Reinhard Liess
 * MIT Licensed
*/

class AppMarkdownClipper {

  ; class variables

  static ICON_FILE := "icons/markdown.ico"

  static ERR_HTML_NO_DATA := "There was no valid HTML data in the clipboard for the app with the window title '{1}'."
  static MSG_NO_SELECTION := "Warning: Nothing selected"

  static ERR_NOGROUP_BROWSERS := "
  ( ltrim
    Section '[windowgroup.browsers]' wasn't found in both user and default INI files, specifically:
      {1}
      {2}
  )"

  static ERR_KEY_NOT_FOUND := "
  ( ltrim
    Key '{1}' wasn't found in section '{2}', in both user and default INI files, specifically:
      {3}
      {4}
  )"

  ; instance variables
  	re := new rd_RegExp()

    /**
    * Constructor
    * Sets defaults
    * @returns {object} this
    */
  __New() {

    ; global settings

    SetWorkingDir, %A_ScriptDir%
    StringCaseSense Locale
    SetTitleMatchMode, 2
    Sendmode, Input

    ; UTF-8, no BOM
    FileEncoding, % "UTF-8-RAW"

    ; SetBatchLines, -1

  }

  /**
   * Initialization method
   * @returns {object} this
   *
  */
  init() {

    ; initialization
    this.appName := "Markdown Clipper"
    ;@Ahk2Exe-Let name=%A_PriorLine~U)^(.+"){1}(.+)".*$~$2%
    this.appVersion := "0.12.0"
    ;@Ahk2Exe-Let version=%A_PriorLine~U)^(.+"){1}(.+)".*$~$2%

    ;@Ahk2Exe-SetVersion %U_version%
    ;@Ahk2Exe-SetName %U_name%
    ;@Ahk2Exe-SetDescription %U_name%
    ;@Ahk2Exe-SetCopyright Copyright (c) 2022`, Reinhard Liess

    this.appTitle := this.appName " " this.appVersion

    OnError(objBindMethod(this, "globalErrorHandler"))

    this.logFile := U.buildFileName(A_ScriptFullPath, {ext: "log"})
    this.loggingEnabled := true

    ;@Ahk2Exe-IgnoreBegin
    if (FileExist(AppMarkdownClipper.ICON_FILE)) {
      menu, Tray, Icon, % AppMarkdownClipper.ICON_FILE
    }
    this.appTitle .= " [Script]"
    ;@Ahk2Exe-IgnoreEnd
    menu, Tray, Tip, % this.appTitle

    this.ini := new rd_ConfigWithDefaults(new rd_WinIniFile("config-user/user.ini")
      , new rd_WinIniFile("config/default.ini"))

    this.ini.ERR_NOT_FOUND := format(AppMarkdownClipper.ERR_KEY_NOT_FOUND
      , "{1}", "{2}"
      , this.ini.user.iniFile
      , this.ini.default.iniFile)

    ; Register browsers window group
    try {
      this.registerWindowGroup("browsers", "windowgroup.browsers")
    } catch error {
      error.message := format(AppMarkdownClipper.ERR_NOGROUP_BROWSERS
        , this.ini.user.iniFile
        , this.ini.default.iniFile)
      throw error
    }

    this.registerWindowGroup("markdown", "windowgroup.markdown")

    ; Register main hotkeys
    this.registerCustomHotkey("Clipper", "hotkeyClipper")
    this.registerCustomHotkey("CopyLink", "hotkeyCopyLink")

    this.registerCustomHotkey("IncreaseHeading", "hotkeyChangeHeading", 1)
    this.registerCustomHotkey("DecreaseHeading", "hotkeyChangeHeading", -1)
    this.registerCustomHotkey("ConvertCodeblock", "hotkeyConvertCodeblock")
    this.registerCustomHotkey("CreateLink", "hotkeyCreateLink")
    this.registerCustomHotkey("ConvertToUL", "hotkeyUL")

    this.processCapslockHotkeys()

    return this
  }

  ; -- handlers, callbacks --

  /**
   * Hotkey handler for markdown clipper
   *
  */
  hotkeyClipper() {

    WinGet, appPath, ProcessPath, A
    WinGetTitle, title, A

    this.ClipSave()

    if (!Clip.Copy() ) {
      this.displayMessageNoSelection()
      return
    }

    if !(html := Clip.GetHtml()) {
      Msgbox, 48, % this.appTitle, % format(AppMarkdownClipper.ERR_HTML_NO_DATA, title)
      this.ClipRestore()
      return
    }

    header := Clip.parseHtmlHeader(html)
    if (!A.isInteger(header.StartFragment)) {
      this.ClipRestore()
      this.showErrorMessage(AppMarkdownClipper.ERR_HTML_NO_DATA, title)
    }

    this.clip := new markdownClip()
    this.clip.file := new markdownFile()
    this.clip.isBrowser := !!WinActive("ahk_group browsers")
    this.clip.appName := format("{1:T}", U.splitPath(appPath).basename)
    this.clip.title := this.clip.isBrowser
      ? this.formatAppWindowTitle(title)
      : title

    this.clip.source := Substr(html, header.StartFragment)
    this.clip.sourceUrl := header.sourceURL
    if (this.clip.isBrowser && !this.clip.sourceUrl) {
      this.clip.sourceUrl := this.getUrlFromBrowser()
    }

    ; Get INI data
    this.clip.ini.insertSourceInfo := this.ini.getString("clipper", "InsertSourceInfo")
    this.clip.ini.command := U.expandEnvVars(App.ini.getString("clipper", "CmdFromHtml"))
    this.clip.ini.savePath := U.expandEnvVars(this.ini.getString("Clipper", "SavePath"))
    this.clip.ini.clipboardOutput := this.ini.getString("clipper", "ClipboardOutput")

    outputFilename := this.clip.clipperBuildFileName(this.clip.ini.savePath)
    Path := U.splitPath(outputFileName)
    FileCreateDir, % Path.drive Path.dir

    oldFile := new MarkdownFile(outputFilename).readFile()
    this.clip.appendToExisting := !!oldFile.contents

    newClip := this.clip
      .clipperPreProcess()
      .convertHtml()
      .clipperPostProcess()
      .InsertSourceInfo()

    this.ClipRestore(0)

    if (this.clip.ini.clipboardOutput = "copy") {
      Clip.setText(this.clip.file.contents)
    }

    oldFile.appendContents("`n`n", newClip.file)
      .writeFile()

    this.clipperProcessConfirmation(outputFileName)
  }

  displayMessageNoSelection() {
    MsgBox, 48, % this.appTitle, % AppMarkdownClipper.MSG_NO_SELECTION
  }

  trimText(text) {
    Return Trim(text, "`r`n`t ")
  }

  clipperProcessConfirmation(outputFileName) {

    confirmation := this.ini.getString("clipper", "confirmation")
    Switch confirmation {
      Case "beep":
        SoundBeep
      Case "open":
        Run, % outputFileName
    }

  }

  /**
  * Saves clipboard contents
  */
  ClipSave() {
  	; this variable must be global or saving the clipboard doesn't work
    global gClipSaved

    gClipSaved := ClipboardAll
  }

  /**
  * Restores previously saved clipboard after optional delay
  * @param {integer} [nDelay=0] - delay in ms
  */
  ClipRestore(nDelay:=500) {
    ; this variable must be global or saving the clipboard doesn't work
    global gClipSaved

    ; yield to other processes
    Sleep, 0
    if (nDelay) {
      Sleep, nDelay
    }
    clipboard := gClipSaved
    gClipSaved := ""
  }

  /**
   * Hotkey handler for converting selection into an unordered list
  */
  hotkeyUL() {

    this.ClipSave()
    text := this.getSelection({ onNoSelection: "selectLine"})

    if (!this.trimText(text)) {
      this.displayMessageNoSelection()
      return
    }

    re := new rd_RegExp().setPcreOptions("(*ANYCRLF)")
    converted := re.replace(text, "m)^(.*)$", "- $1")
    ; remove unwanted list item created by LF
    converted := re.replace(converted, "- $")

    Clip.Paste(converted)
    this.ClipRestore()
  }

  /**
   * Hotkey handler for copying url as markdown
   * Uses selection as title if available
  */
  hotkeyCopyLink() {
    link := "", title := ""

    if (Clip.CopyText()) {
      title := Clip.GetText()
    }

    if (!link) {
      link := this.getUrlFromBrowser()
    }

    if (!title) {
      WinGetTitle, title, A
      title := this.formatAppWindowTitle(title)
    }

    ; write link back to clipboard as markdown
    Clip.SetText(format("[{1}]({2})", title, link))

    if (this.ini.getString("CopyLink", "confirmation") = "beep") {
      SoundBeep
    }

  }

  hotkeyCreateLink() {
    linkUrl := Clipboard
    text := this.getSelection({ onNoSelection: "selectWord"})

    Clip.Paste(format("[{}]({})", text, linkUrl))
    Sleep, 300
    clipboard := linkUrl
  }

  hotkeyChangeHeading(numChange) {
    mdt := new markdownTools()

    this.ClipSave()
    text := this.getSelection({ onNoSelection: "selectLine"})

    if (!this.trimText(text)) {
      this.displayMessageNoSelection()
      this.ClipRestore()
      return
    }
    converted := mdt.changeHeadingLevel(text, numChange)
    Clip.Paste(converted)
    this.ClipRestore()
  }

  hotkeyConvertCodeBlock() {
    static language

    if (!language) {
      language := this.ini.getString("ConvertCodeBlock", "DefaultLanguage")
    }

    mdt := new MarkdownTools()

    InputBox, language, Markdown: Convert To Code Block, Enter language,, 300, 130,,, Locale, , %language%
    if (ErrorLevel = 1) {
      Return
    }
    KeyWait, Enter

    this.ClipSave()
    text := this.getSelection()

    if (converted := mdt.convertCodeBlock(text, language)) {
      Clip.Paste(converted "`n")
      ; Create empty code block, if no selection and set new cursor position
      if (!this.trimText(text)) {
        Send, {up 2}
      }
    }
    this.ClipRestore()
  }

  /**
   * Generic error handler
   * @param {message} message - error message with placeholders
   * @param {string*} param - parameters (variadic)
   *
  */
  showErrorMessage(message, param*) {
    throw Exception(format(message, param*), -2)
  }


  /**
   * Global error handler
   * @param {object} exception - exception object
   * @returns {boolean} true (exit current thread)
   *
  */
  globalErrorHandler(exception) {
    message := exception.message
    if (Errorlevel && A_LastError) {
      message .= format("`n`nWindows error: {1} ({2})", U.getWindowsErrorText(A_LastError), A_LastError)
    }
    this.appendToLog("error", message)
    Msgbox, 16, % this.appTitle, % message
    return true
  }

  ; -- general purpose methods --

  /**
   * Retrieves url from Internet browser
   * Will activate window that matches winTitle
   * @param {string} [winTitle] - Autohotkey WinTitle string
   * @returns {string} url
   *
  */
  getUrlFromBrowser(winTitle := "A") {
    if (winTitle != "A") {
      WinActivate, % wintitle
    }
    ; Prevent accidental locking of computer
    KeyWait, LWin
    ; Ctrl+l
    Send, ^{vk4Csc026}
    if (Clip.CopyText(0.3)) {
      return Clip.GetText()
    } else {
      Throw Exception("Clipboard: Nothing to copy", -2)
    }
  }

  ; Capslock combo hotkeys
  processCapslockHotkeys() {
    sectionHotkeys := this.ini.user.getSection("Hotkeys")
    ; https://regex101.com/r/Hu3Nqm/latest
    if (A.some(sectionHotkeys, objBindMethod(this.re, "isMatchB", "i)(?<!when)=\s*Capslock &"))) {
      ; If Capslock special hotkey is used, switch off Capslock
      SetCapsLockState, AlwaysOff
    }
  }

  /**
   * Registers hotkey
   * @param {string} hotkey - hotkey to register
   * @param {object} handler - BoundFunc object
   * @param {string} condition - #IfWinActive Wintitle condition
   * @returns {void}
   *
  */
  registerHotkey(hotkey, handler, condition :="") {

    if (!hotkey) {
      return
    }
    if (condition) {
      Hotkey, IfWinActive, % condition
    }
    Hotkey, % hotkey, % handler
    if (condition) {
      ; clear condition
      Hotkey, IfWinActive
    }
  }

  /**
  * Registers custom hotkey
  * @param {string} iniKey - key in [hotkeys]
  * @param {string} handler - name of handler method
  * @param {any*}   args - arguments to pass to handler
  * @returns {void}
  */
  registerCustomHotkey(iniKey, handler, args*) {
    condition := this.ini.getString("hotkeys", iniKey "_when")
    this.registerHotkey(this.ini.getString("hotkeys", iniKey)
    , objBindMethod(this, handler, args*)
    , condition)
  }

  /**
   * Registers window group
   * can be used as ahk_group in wintitle expression, or #IfWinActive hotkey
   * @param {string} groupName - name of group
   * @param {string} iniSection - section of inifile
   * @returns {string[]} members of group
  */
  registerWindowGroup(groupName, iniSection) {

    members := this.ini.getArray(iniSection, "wintitle")
    for _, member in members {
      GroupAdd, % groupName, % member
    }
    return members
  }

  /**
   * Returns formatted window title
   * @param {string} title - title to format
   * @returns {string} formatted title
   *
  */
  formatAppWindowTitle(title) {

    ; split title by any kind of dash
    parts := StrSplit(title, [" - ", " – ", " — "], " ")
    ; remove the rightmost element
    parts := A.dropRight(parts)
    return A.join(parts, " - ")

  }

  /**
    * Writes message to log file & debug console
    * @param {string} logClass - type of log entry, e.g. "error"
    * @param {string} text - message to log
    * @returns {void}
  */
  appendToLog(logClass, text) {

    if (!this.loggingEnabled) {
      return
    }

    re := new rd_RegExp()

    formatString := U.expandAhkVars("%A_Year%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%.%A_MSec% [{1:-7U}] - {2}`r`n")

    text := re.replace(text, "\r?\n", " ")
    textToLog := format(formatString, logClass, text)

    try {
      U.fileAppend(textToLog, this.logFile)
    } catch error {
      this.loggingEnabled := false
      Msgbox, 16, % this.appTitle, % "Error writing to log file. Logging will be switched off."
    }

    OutputDebug, % textToLog

  }

  /**
  * Retrieves selection via clipboard
  * @param {object} options - option object
  * @param {string} [options.onNoSelection=""] - selectLine or selectWord
  * @param {float} [options.timeout=0.1] - clipboard waiting timeout
  * @returns {string | undefined} selected text
  */
  getSelection(options:="") {

    if (!options) {
      options := {}
    }

    clipTimeout  := options.hasKey("timeout") ? options.timeout : 0.1
    noSelect     := options.onNoSelection

    text := ""
    if (Clip.CopyText(clipTimeout)) {
      text := Clip.GetText()
    }

    ; for apps copying the whole line with \r?\n, if nothing is selected
    compatMode := !!RegexMatch(text, "^.*\r?\n$")

    if (!text || compatMode) {
      if (noSelect = "selectLine") {
        Send, {HOME}+{END}
      } else if (noSelect = "selectWord") {
        Send, ^{LEFT}^+{RIGHT}
      }
      if (Clip.CopyText(clipTimeout)) {
        text := Clip.GetText()
      }
    }

    return text

  }

}
