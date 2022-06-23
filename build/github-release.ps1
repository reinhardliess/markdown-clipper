& .\build.cmd

Set-Location -Path $PSScriptRoot

$version = Get-Content ..\modules\AppMarkdownClipper.ahk |
  Select-String 'this\.appVersion.+"(\d+\.\d+\.\d)' |
  ForEach-Object { $_.Matches[0].Groups[1].Value }

  Compress-Archive -Path .\deploy\* -DestinationPath ".\github\markdown-clipper-$version.zip"
