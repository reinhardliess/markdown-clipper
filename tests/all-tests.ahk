#NoEnv
#SingleInstance force
#Warn All, OutputDebug
#Warn UseUnsetLocal, Off
#NoTrayIcon

SetWorkingDir, %A_ScriptDir%

; include all libraries and modules here
#Include, %A_ScriptDir%\..\node_modules\rd-regexp-ahk\rd_RegExp.ahk
#Include, %A_ScriptDir%\..\node_modules\rd-utility-ahk\rd_Utility.ahk
#Include, %A_ScriptDir%\..\node_modules\biga.ahk\export.ahk
#Include, %A_ScriptDir%\..\node_modules\json.ahk\export.ahk
#Include, %A_ScriptDir%\..\lib\winclip\WinClipAPI.ahk
#Include, %A_ScriptDir%\..\lib\winclip\WinClip.ahk
#Include, %A_ScriptDir%\..\modules\rd_WinClip.ahk
#Include, %A_ScriptDir%\..\modules\AppMarkdownClipper.ahk
#include, %A_ScriptDir%\..\modules\markdown.ahk

; testing library
#include, %A_ScriptDir%\..\node_modules\unit-testing.ahk\export.ahk


; set defaults
StringCaseSense Locale

; for timings
SetBatchLines, -1

global App := new AppMarkdownClipper()
global assert := new unittesting()
global U      := new rd_Utility()
global A      := new BigA()

OnError("ShowError")

; -- Tests --

assert.group("MarkdownClip")
test_markdownClip()

assert.group("MarkdownFile")
test_markdownFile()

assert.group("MarkdownTools")
test_markdownTools()

assert.group("App Class")
test_appClass()

assert.group("rd_WinClip class")
test_WinClip()

; -End of tests --

; assert.fullReport()
assert.writeTestResultsToFile()
OutputDebug, % U.fileRead("result.tests.log")

ExitApp, % assert.failTotal

; cspell:disable

test_markdownClip() {

  assert.label("getHeadingLink - should retrieve a url from heading if it exists")

  clip := new markdownClip()

  markdown := "## [Variable Capacity and Memory](https://www.autohotkey.com/docs/Variables.htm#cap)"
  link := clip.getHeadingLink(markdown)
  assert.test(link, "https://www.autohotkey.com/docs/Variables.htm#cap")

  markdown := "## Variable Capacity and Memory[#](https://www.autohotkey.com/docs/Variables.htm#cap)"
  link := clip.getHeadingLink(markdown)
  assert.test(link, "https://www.autohotkey.com/docs/Variables.htm#cap")

  assert.label("Property: shouldAddHeader")

  clip := loadJSON("clip--append-vars")
  clip.base := markdownClip
  assert.test(clip.shouldAddHeader, false)

  clip := loadJSON("clip--append-novars")
  clip.base := markdownClip
  assert.test(clip.shouldAddHeader, true)

  assert.label("clipperBuildFileName - should expand variables: source/title to create output file name")

  clip := loadJSON("clip--browser")
  clip.base := markdownClip

  assert.test(clip.clipperBuildFileName("clipper\${source}\${title}.md")
    , "clipper\autohotkey-com\objects-definition-usage-autohotkey.md")

  clip := new markdownClip()

  assert.label("processWords - should convert a string to separator-delimited lowercase string with max. n words")
  assert.test(clip.processWords("Testing in JavaScript today", 3, "|"), "testing|in|javascript")

  assert.label("clipperPostProcess - should convert Setext style H1/H2 headings to ATX style")

  clip.file.contents := "
  ( ltrim
    Characteristics of a good Test[#](https://domain.com)
    ==============================

    Learn characteristics of a good test
    ------------------------------------

    A test suite is a collection of tests.
  )"

  expected =
  ( ltrim
    # Characteristics of a good Test[#](https://domain.com)

    ## Learn characteristics of a good test

    A test suite is a collection of tests.
  )
  assert.test(clip.clipperPostProcess().file.contents, expected)

  assert.label("clipperPostProcess - should remove links from inline code in Markdown text")

  clip.file.contents := "
  ( ltrim
    Ad qui aut cumque ``quos earum [corporis](link) ut`` adipisci.

    Repellendus quis ``quidem aperiam [iusto](link)``.
    Unde natus neque nihil sed expedita est eveniet.
  )"

  expected =
  ( ltrim
    Ad qui aut cumque ``quos earum corporis ut`` adipisci.

    Repellendus quis ``quidem aperiam iusto``.
    Unde natus neque nihil sed expedita est eveniet.
  )

  assert.test(clip.clipperPostProcess().file.contents, expected)

  assert.label("clipperPostProcess - should unescape Markdown in inline code in Markdown text")

  clip.file.contents := "
  ( ltrim
    Ad qui aut cumque ``quos \_earum corporis`` adipisci.

    Repellendus quis ``quidem 12\*3 aperiam iusto``.
  )"

  expected := "
  ( ltrim
    Ad qui aut cumque ``quos _earum corporis`` adipisci.

    Repellendus quis ``quidem 12*3 aperiam iusto``.
  )"

  assert.test(clip.clipperPostProcess().file.contents, expected)

  ; -- Insert source info --

  assert.label("insertSourceInfo - should return 'slim' when a heading is found and has no link")
  clip := loadJSON("clip--browser-sourceauto-noappend-novars")
  clip.base := markdownClip

  clip.file.contents := "## Objects - Definition & Usage | AutoHotkey"

  assert.test(clip.getSourceInfoType(), "slim")
  clip.InsertSourceInfo()

}

test_markdownFile() {

  old =
  ( ltrim
    # Heading 1

    Some text.
  )

  new =
  ( ltrim
  # Learn characteristics of a good test

  A test suite is a collection of tests that you can run against a piece of software.
  )

  expected =
  ( ltrim
    # Heading 1

    Some text.

   # Learn characteristics of a good test

   A test suite is a collection of tests that you can run against a piece of software.

  )

  oldClip := new markdownFile("", old)
  newClip := new markdownFile("", new)
  expectedClip := new markdownFile("", expected)

  assert.label("appendContents - should merge source objects's contents + 1 empty line + object")
  assert.test(oldClip.appendContents("`n`n", newClip), expectedClip)

  assert.label("appendContents - should return new object's contents, because the source object is empty")

  oldClip.contents := ""
  expectedClip := newClip.Clone()
  expectedClip.contents .= "`n"
  assert.test(oldClip.appendContents("`n`n", newClip), expectedClip)
}

test_markdownTools() {

  mdt := new markdownTools()

  block := loadText("block-urls")
  expected := loadText("block-urls-converted")

  assert.label("should remove link urls from Markdown text")
  actual := mdt.removeLinkUrl(block)
  assert.test(actual, expected)

  assert.label("should convert a convential code block into a fenced code block")
  actual := mdt.convertCodeBlock(loadText("block"), "css")
  expected := loadText("block-converted")
  assert.test(actual, expected)
}

; -- App Class --

test_appClass() {

  assert.label("formatAppWindowTitle - formats window title removing app name")
  actual := App.formatAppWindowTitle("Objects - Definition & Usage | AutoHotkey - Google Chrome")
  assert.test(actual, "Objects - Definition & Usage | AutoHotkey")

  actual := App.formatAppWindowTitle("Frequently Asked Questions (FAQ) | AutoHotkey – Opera")
  assert.test(actual, "Frequently Asked Questions (FAQ) | AutoHotkey")

}

test_WinClip() {

  Clip := new rd_WinClip()
  html =
  ( ltrim join`r`n
  Version:0.9
  StartHTML:0000000166
  EndHTML:0000004238
  StartFragment:0000000202
  EndFragment:0000004202
  SourceURL:https://devdocs.io/dom/element/insertadjacenthtml
  <html>
  </html>
  )
  assert.label("parseHtmlHeader - parses HTML clipboard header, returning object")
  actual := Clip.parseHtmlHeader(html)
  expected := { Version: "0.9", StartHTML: 167, EndHTML: 4239
    , StartFragment: 203, EndFragment: 4203
    , SourceURL: "https://devdocs.io/dom/element/insertadjacenthtml"}
  assert.test(actual, expected)

  assert.label("GetText - should return the correct clipboard contents in text format")
  clipboard := "This is a test"
  assert.test(Clip.GetText(), "This is a test")

  assert.label("SetText - should set the correct clipboard contents in text format")
  Clip.SetText("This is another test")
  assert.test(Clip.GetText(), "This is another test")

}

ShowError(exception) {
    Msgbox, 16, Error, % "Error in " exception.what " on line " exception.Line "`n`n" exception.Message "`n"
    return true
}

; ; returns two merged objects
; merge(obj1, obj2) {
;   temp := A.cloneDeep(obj1)
;   obj := A.merge(temp, obj2)
;   return temp
; }

loadJSON(filename) {

  fullFileName := A_ScriptDir "\json\" filename ".json"
  contents := U.fileRead(fullFileName)
  if (!JSON.test(contents)) {
    throw Exception(fullFileName " is not a valid JSON file.")
  }
  return JSON.parse(contents)
}

loadText(filename) {
  fullFileName := A_ScriptDir "\text\" filename ".txt"
  contents := U.fileRead(fullFileName)
  return contents
}