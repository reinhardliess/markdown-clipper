/*
  Extends Winclip class
  Reinhard Liess, 2021
*/

class rd_WinClip extends WinClip {

  ; timeout 100ms, overwrites default
  TIMEOUT := 0.1

  /**
   * Constructor
   *
  */
  ; __New() {
  ;   this.base.__New()
  ; }

  /**
   * Parses HTML clipboard header into object
   * @param {string} html - HTML clipboard data including header
   * @returns {object | undefined } all header fields as `key: value` pairs
   *
  */
  parseHtmlHeader(html) {
    re := new rd_RegExp()
    match := re.match(html, "s)^.+StartHTML:(\d+)")
    if (!match) {
      return ""
    }
    ; all header string offsets are adjusted for Autohotkey (1-based)
    header := Substr(html, 1, match[1] )
    headerData := re.matchAll(header, "im)^([A-Z]+):(.+)$")
    obj := {}
    for index, match in headerData {
      obj[match[1]] := WinClipAPI.isInteger(match[2])
        ? format("{1:d}", match[2]) + 1
        : Trim(match[2])
    }
    return obj
  }

  /**
  * Copy text format to clipboard
  * @param {float} [timeout] - timeout in seconds, fractions ok,
  *   to wait for clipboard contents
  * @param {integer} [method:=1] - key combo to use to copy to clipboard
  * @returns {boolean} false, if timed out
  */
  CopyText( timeout := "", method := 1 ) {
    timeout := timeout ? timeout : this.TIMEOUT
    clipboard := ""
    if( method = 1 )
      SendInput, ^{Ins}
    else
      SendInput, ^{vk43sc02E} ;ctrl+c
    ClipWait,% timeout
    return (ErrorLevel = 0)
  }

  /**
   * Returns text clipboard data
   * @returns {string} text clipboard data
   *
  */
  GetText() {
    return clipboard
  }

/**
  * Writes text in clipboard
  * @param {string} textData - text to copy to clipboard
  * @returns {boolean} true if textData is truthy
*/
  SetText(textData) {
    if ( textData = "" ) {
      return false
    }
    clipboard := textData
    return true
  }

  /**
  * Paste text from clipboard
  * @param {string} [plainText] - text to paste
  * @param {integer} [method:=1] - key combo to use to copy to clipboard
  * @returns {boolean} true if plainText is truthy
  */
  Paste( plainText = "", method = 1 ) {
    if ( plainText == "" ) {
      return false
    }
    this.SetText( plainText )
    if( method = 1 ) {
      SendInput, +{Ins}
    } else {
      SendInput, ^{vk56sc02F} ;ctrl+v
    }
    return true
  }
}
