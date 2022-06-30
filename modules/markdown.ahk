/*
 * Markdown classes
 * Copyright(c) 2021 Reinhard Liess
 * MIT Licensed
*/

class markdownFile {

  contents := ""
  outputFilename := ""

  /**
    * Constructor
  */
  __New(fileName :="", contents :="") {

    this.outputFilename := fileName
    this.contents := contents
  }

  /**
    * Read file into this.contents, if it exists
    * @returns {object} this
  */
  readFile() {

    if (FileExist(this.outputFileName)) {
      this.contents := Trim(U.fileRead(this.outputFileName), " `t`r`n")
    }
    return this
  }

  /**
    * Write file to disk, if outputFilename is set
    * @returns {object} this
  */
  writeFile() {

    U.fileWrite(this.contents, this.outputFilename)
    return this
  }

  /**
  * Appends objMarkdownFile contents
  * @param {string} spacer - inserted between both, if this contents exists
  * @param {object} objMarkdownFile - object to append
  * @returns {object} this
  */
  appendContents(spacer, objMarkdownFile) {

    buffer :=""
    if (this.contents) {
      buffer := Trim(this.contents, " `t`r`n") spacer
    }

    this.contents := buffer Trim(objMarkdownFile.contents, " `t`r`n") "`n"
    return this
  }

}



class markdownClip {

  appName := ""
  isBrowser := false
  title := ""
  sourceUrl := ""
  source := ""
  appendToExisting := false
  ini := {}
  file := {}

  /**
    * Constructor
    * @param {object} [props] - props object
  */
  __New(props:="") {

    for key, value in props {
      this[key] := value
    }
  }

  /**
   * Build Markdown output file name
   * @param {string} path - path, optionally with ${source}, ${title} variables
   * @returns {string} generated file name
   *
  */
  clipperBuildFileName(path) {

    re := new rd_RegExp()
    variables := {}

    if (this.isBrowser && this.sourceUrl) {
      match := re.match(this.sourceUrl, "https?:\/\/(?:www\.)?(.+?)\/")
      variables.source := match[1] ? this.processWords(match[1]) : "other"
    } else {
      variables.source := this.processWords(this.appName, 3)
    }
    variables.title := this.processWords(this.title, 6)

    return U.expandCustomVars(path, variables)
  }

  /**
   * Converts string to separator-separated string with max. n words
   * Only unique words, lowercase output
   * @param {string} text - text to process
   * @param {string} [separator="-"] - word separator
   * @param {integer} [maxWords=5] - maximum number of words
   * @returns {string} converted string
  */
  processWords(text, maxWords := 5, separator := "-") {
    listWords := A.words(format("{1:L}", text))
    return A.join(A.take(A.uniq(listWords), maxWords), separator)
  }

    /**
   * Pre-process HTML before converting to Markdown
   * @param {string} html - html
   * @returns {string} converted html
   *
  */
  clipperPreProcess() {
    ; fix for 'html2md' removing non-breaking space
    this.source := RegExReplace(this.source, "<span>(\x{00A0})</span>", "$1")
    return this
  }

  /**
   * Post-process Markdown before writing it out to file
   * @param {string} markdown - Markdown content
   * @returns {string} converted Markdown
   *
  */
  clipperPostProcess() {

    re := new rd_RegExp().setPcreOptions("(*ANYCRLF)")

    ; convert Setext style H1/H2 to ATX style
    ; https://regex101.com/r/7SuDEh/2
    buffer := re.replace(this.file.contents, "m)^(.+)\r?\n=+$", "# $1" )
    buffer := re.replace(buffer, "m)^(.+)\r?\n-+$", "## $1" )

    ; remove linefeeds from link text
    ; https://regex101.com/r/H6ooBn/1/
    buffer := re.replace(buffer, "\[\s*(.+)\s*\](\(.+\))", "[$1]$2")

    ; replace [](link) with [#](link)
    ; https://regex101.com/r/9VxaZh/1
    buffer := re.replace(buffer, "m)(^.*\[)(\]\s*\(.+\))", "$1#$2" )

    ; Inline `code`, convert [text](link) to text, unescape Markdown
    ; https://regex101.com/r/8DmTZR/3/
    this.file.contents := re.replace(buffer, "``[^\r?\n``]*``", objBindMethod(this, "fn_reInlineCode") )

    return this
  }


  /**
   * Callback: Remove link url from Markdown link, unescape Markdown
   * @param {object} match - match object
   * @param {string} haystack - haystack
   * @returns {string} modified full match
   *
  */
  fn_reInlineCode(match, haystack) {
    ; OutputDebug, % match[0]
    re := new rd_RegExp().setPcreOptions("(*ANYCRLF)")
    ; https://regex101.com/r/HjY0rd/2/
    buffer := re.replace(match[0], "^(.*)\[(.+)\](\(.+)\)(.*)$", "$1$2$4")
    ; unescape Markdown
    ; https://regex101.com/r/Uju9Mr/2/
    return re.replace(buffer, "(\\)([\[\]\\\``\*\_\{\}\(\)#+\-\.!])", "$2")
  }

  /**
    * Get link embedded in Markdown heading
    * @param {string} markdown - Markdown text
    * @returns {string | undefined} link
  */
  getHeadingLink(markdown) {

    re := new rd_RegExp().setPcreOptions("(*ANYCRLF)")

    ; https://regex101.com/r/l5Kv1H/1
    ; Test heading for link, group1 = link
    match := re.match(markdown, "^#{1,6}.+\[.+\]\((.+)\)")
    return match ? match[1] : ""
  }


  /**
    * Property: Returns true if header should be appended
    * @returns {boolean}
  */
  shouldAddHeader[]
  {
    get {
      re := new rd_RegExp()

      retVal := !this.appendToExisting || !re.match(this.ini.savePath, "\$\{\w+\}")
      return retVal

    }

  }

  /**
    * Determine type of source info header to insert into markdown
    * @returns {string} "none", "slim", "full"
  */
  getSourceInfoType() {

    ; Handle "easy" cases first
    if (this.ini.InsertSourceInfo = "full") {
      return "full"
    }
    if (!this.shouldAddHeader) {
      return "none"
    }
    if (!this.isBrowser) {
      return "full"
    }

    ; Browser from here on
    ; - no heading  -> full
    ; - heading link points to site -> none
    ; - heading link points to other site -> full
    ; - no heading link -> slim

    if (!A.startsWith(this.file.contents, "#")) {
      return "full"
    }
    if (link := this.getHeadingLink(this.file.contents)) {
      if (A.startsWith(link, this.sourceUrl)) {
        ; link points to source website
        return "none"
      } else {
        return "full"
      }
    } else {
      ; clipped text starts with heading without link
      return "slim"
    }
  }

  /**
   * Insert source info to Markdown
   * @returns {string} modified Markdown
   *
  */
  InsertSourceInfo() {

    re := new rd_RegExp().setPcreOptions("(*ANYCRLF)")

    buffer := this.file.contents
    infoType := this.getSourceInfoType()

    if (this.isBrowser) {

      if (infotype = "slim") {
        ; https://regex101.com/r/GEbYr6/2/
        buffer := re.replace(buffer, "^(#{1,6}.+)", format("$1[#]({1})", this.sourceUrl))
      } else if (infoType = "full") {
        buffer := format("## {1}[#]({2})`n`n", this.title, this.sourceUrl) buffer
      }

    } else {
      ; clipped data is from app, not browser
      ; header := this.sourceUrl
      ;   ? format("## {1} ({2})`n`n", this.title, U.uriDecode(this.sourceUrl))
      ;   ; : "## " this.title "`n`n"
      header := "## " this.title "`n`n"
      buffer := header buffer
    }
    ; Make file end with a single newline character
    ; see <https://github.com/DavidAnson/markdownlint/blob/v0.24.0/doc/Rules.md#md047>
    buffer .= "`n"
    this.file.contents := buffer
    return this
  }

  /**
   * Converts HTML to Markdown
   *
  */
  convertHtml() {

    ; convert HTML to Markdown
    inFile := U.createUniqueFile("html")
    outFile := U.createUniqueFile("md")

    U.fileWrite(this.source, inFile)
    command := U.expandCustomVars(this.ini.command, { input: (inFile)
      , output: (outFile)})
    RunWait, % command, %A_ScriptDir%, Hide
    this.file.contents := U.fileRead(outFile)
    FileDelete, % inFile
    FileDelete, % outFile
    return this
  }

}

class markdownTools {

  /**
    * Increases/decreases heading level in text
    * @param {string} text - source text
    * @param {integer} numChange - value of change
    * @returns {string}
  */
  mdChangeHeadingLevel(text, numChange) {

    re := new rd_RegExp().setPcreOptions("(*ANYCRLF)")

    converted := re.replace(text, "m)^#{1,6}", objBindMethod(this, "_fn_changeHeading", numChange))
    return converted
  }

  _fn_changeHeading(numChange, match, haystack) {
    ; OutputDebug, % match[0]
    newLevel := Strlen(match[0]) + numChange
    ; newLevel := newLevel > 6 ? 6 : newLevel
    ; newLevel := newLevel < 1 ? 1 : newLevel
    return A.repeat("#", A.clamp(newLevel, 1, 6))
  }

}