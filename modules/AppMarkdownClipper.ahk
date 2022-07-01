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
    this.appVersion := "0.8.0.3"
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

    ; Register hotkeys
    this.registerHotkey(this.ini.getString("hotkeys", "clipper")
      , objBindMethod(this, "hotkeyClipper") )
    this.registerHotkey(this.ini.getString("hotkeys", "copyLink")
      , objBindMethod(this, "hotkeyCopyLink")
      , "ahk_group browsers")

    condIncreaseHeading := this.ini.getString("hotkeys", "IncreaseHeading_when")
    condDecreaseHeading := this.ini.getString("hotkeys", "DecreaseHeading_when")
    this.registerHotkey(this.ini.getString("hotkeys", "IncreaseHeading")
      , objBindMethod(this, "hotkeyChangeHeading", 1)
      , condIncreaseHeading)
    this.registerHotkey(this.ini.getString("hotkeys", "DecreaseHeading")
      , objBindMethod(this, "hotkeyChangeHeading", -1)
      , condDecreaseHeading)

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

    if (!Clip.Copy() ) {
      MsgBox, 48, % this.appTitle, % AppMarkdownClipper.MSG_NO_SELECTION
      return
    }

    if !(html := Clip.GetHtml()) {
      Msgbox, 48, % this.appTitle, % format(AppMarkdownClipper.ERR_HTML_NO_DATA, title)
      return
    }

    header := Clip.parseHtmlHeader(html)
    if (!A.isInteger(header.StartFragment)) {
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

    if (this.clip.ini.clipboardOutput = "copy") {
      Clip.setText(this.clip.file.contents)
    }

    oldFile.appendContents("`n`n", newClip.file)
      .writeFile()

    this.clipperProcessConfirmation(outputFileName)
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

  hotkeyChangeHeading(numChange) {
    mdt := new markdownTools()

    text := this.getSelection({ onNoSelection: "selectLine"})

    if (!text) {
      MsgBox, 64, % this.appTitle, % "Nothing selected!"
      return
    }
    converted := mdt.mdChangeHeadingLevel(text, numChange)
    Clip.Paste(converted)
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
