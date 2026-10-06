# Creates a "Neo Prep" desktop shortcut that runs neo-prep.ps1 from this folder.
# Uses a generic Windows icon (shell32.dll), not Neo's logo.

$ErrorActionPreference = 'Stop'

$scriptDir    = Split-Path -Parent $PSCommandPath
$targetScript = Join-Path $scriptDir 'neo-prep.ps1'

if (-not (Test-Path -LiteralPath $targetScript)) {
    throw "neo-prep.ps1 not found in $scriptDir"
}

# GetFolderPath handles Desktops redirected to OneDrive.
$desktop      = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Neo Prep.lnk'
$powershell   = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$shell    = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = $powershell
$shortcut.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$targetScript`""
$shortcut.WorkingDirectory = $scriptDir
$shortcut.IconLocation     = "$env:SystemRoot\System32\shell32.dll,27"
$shortcut.Description      = 'Close distracting apps before opening Neo Browser'
$shortcut.Save()

Write-Host "Shortcut created: $shortcutPath"
