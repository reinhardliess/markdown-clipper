# Markdown Clipper (for Windows)

## Description

Markdown Clipper is an app enabling users to clip a selection from any app that copies HTML format to the Windows clipboard, convert it to Markdown and save it to a file (and optionally copy the converted Markdown to the clipboard again).

This makes it a useful tool, especially if you use Markdown-based note-taking apps.

All apps that copy HTML format to the clipboard are supported: Web browsers, email clients, text processors, Windows HTML Help, etc.

The program performing the actual conversion can be [configured](#conversion-options).

Also, a number of [additional hotkeys](#hotkeys) are supported to perform various actions on Markdown text.

Installation instructions are [here](#installation).

## Configuration

There are two configuration INI files: [default.ini](./config/default.ini) and `user.ini`. The default file stores all the defaults for the app and should never be edited because it might be overwritten during an update of the app, all changes should be made to the user file instead, all settings needing to be changed should be copied to the user file.

All possible configuration settings are documented in the default file.

### Conversion Options

Every command line program that converts HTML to Markdown can be used with Markdown Clipper, the default is [to-markdown-cli](https://github.com/ff6347/to-markdown-cli#readme), because it creates IMO the cleanest Markdown output without any unnecessary HTML tags.
It requires the installation of Node for Windows, though, see [Installation](#installation).

```ini
; HTML to Markdown program/script to execute
; use variables to set input/output file
CmdFromHtml= node_modules\.bin\html2md.cmd -g -i ${input} -o ${output}
```

An alternative would be Pandoc ([Installation](https://pandoc.org/installing.html), [User’s Guide](https://pandoc.org/MANUAL.html#options)).

```ini
; change in user.ini
CmdFromHtml= pandoc --wrap=none -r html -t markdown_github-native_divs-native_spans -o ${output} ${input}
```

#### Decision Table

| to-markdown-cli             | Pandoc                                                                                                      |
| --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Needs `Node.js`             | Is somewhat faster (machine-dependant)                                                                      |
| Creates very clean Markdown | Sometimes Adds HTML tags you might not want, and the clipped snippet might look more like HTML than Markdown |
| Complex tables → HTML table | Often creates beautiful Markdown tables                                                                     |
|                             | Very configurable (e.g. supports Markdown reference links)                                                  |

### Hotkeys

- All hotkeys that work on Markdown text can be made local by restricting the hotkey scope to the `Markdown` window group (otherwise the hotkeys will be global). Example:

  ```ini
  IncreaseHeading=^#Numpad2
  IncreaseHeading_when= ahk_group markdown
  ```

All `_when` settings can use any valid [Wintitle](https://www.autohotkey.com/docs/misc/WinTitle.htm) Autohotkey condition.  
<br>
| Function/Feature                                                            | Default Hotkey | Scope                        |
| --------------------------------------------------------------------------- | -------------- | ---------------------------- |
| Clipping HTML to Markdown                                                   | Alt+Ctrl+M     | Global                       |
| [Copy address/title as Markdown](#copy-address-and-page-title-as-markdown)  | unassigned     | Browsers window group        |
| [Create Markdown link from clipboard](#create-markdown-link-from-clipboard) | unassigned     | Global/Markdown window group |
| [Increase heading level](#increasedecrease-heading-level)                   | unassigned     | Global/Markdown window group |
| [Decrease heading level](#increasedecrease-heading-level)                   | unassigned     | Global/Markdown window group |
| [Convert to fenced code block](#convert-selection-to-fenced-code-block)     | unassigned     | Global/Markdown window group |
| Turn selection into unordered list                                          | unassigned     | Global/Markdown window group |

Hotkeys can be customized. Check out the [List of Keys](https://www.autohotkey.com/docs/KeyList.htm) and [Hotkey Modifier Symbols](https://www.autohotkey.com/docs/Hotkeys.htm#Symbols).

List of most common modifiers:

| Symbol | Description            |
| ------ | ---------------------- |
| #      | Win (Windows logo key) |
| !      | Alt                    |
| ^      | Ctrl                   |
| +      | Shift                  |

```ini
; change in user.ini
; Definition of hotkeys
[Hotkeys]
; Alt+Ctrl+M
Clipper=!^m
; unassigned
CopyLink=
```

### Additional Features

#### Copy Address and Page Title as Markdown

- Copies URL and website title as Markdown. If there's a selection, the selection will be used instead of the page title
- Local hotkey, restricted to window group `Browsers`

#### Create Markdown Link from Clipboard

- Uses current selection as link text and clipboard contents as link URL to create a Markdown link

#### Increase/Decrease heading level

- Increases/decreases the heading level of the current line (no selection necessary) or a multi-line selection

#### Convert Selection to Fenced Code Block

- Converts selected indented code block to fenced code block
- Converts selection to fenced code block with the following post-processing
  - Remove links, keeping only the link text
  - Remove bold/italics formatting
  - Unescape Markdown
- If there's no selection, an empty code block in the selected language is pasted

A language can be input (and the default language can be configured)

### Output File

The file/path name for the generated Markdown output file can be customized, Windows environment variables are supported. There are two internal variables, `${source}` and `${title}`, that will be expanded when the file is created, if the file already exists, the new clipped content will be appended.

Default:

```ini
; change in user.ini
[Clipper]
savePath=%USERPROFILE%\documents\markdown-clipper\\${source}-${title}.md
```

|               | Source          | Title             |
| ------------- | --------------- | ----------------- |
| **Browser**   | Domain name     | Title of website |
| **Other app** | Executable name | Window title      |

## Post-Processing

Some types of mandatory post-processing are performed:

- Convert [Setext style H1/H2 to ATX style](https://github.com/updownpress/markdown-lint/blob/master/rules/003-header-style.md)
- Remove linefeeds from link text
- Replace `[](link)` with `[#](link)`
- Inline `` `code` ``: Convert `[text](link)` to `text`, unescape Markdown

## Installation

- Download the latest binary release from the [Releases](https://github.com/reinhardliess/markdown-clipper/releases) page.
- Install [Node.js](https://nodejs.org/en/download/) for Windows\*
- Run `.\install\install.cmd` or `.\install\install-cli.cmd`\*
- Set up a user [configuration](#configuration) in `.\config-user\user.ini`
- Run the `markdown-clipper` executable

\* if you plan on using `to-markdown-cli`, see [Conversion Options](#conversion-options)
