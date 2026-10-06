# neo-prep: force-closes the apps listed in apps.default.txt and apps.local.txt
# so Neo Browser can start. Does NOT launch Neo Browser; open it yourself.
#
#   neo-prep.ps1                        close every app on both lists
#   neo-prep.ps1 -Add name1 name2.exe   add app families to apps.local.txt, then exit

[CmdletBinding(PositionalBinding = $false)]
param(
    [string[]]$Add,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$MoreNames
)

$ErrorActionPreference = 'Stop'

$scriptDir   = Split-Path -Parent $PSCommandPath
$defaultFile = Join-Path $scriptDir 'apps.default.txt'
$localFile   = Join-Path $scriptDir 'apps.local.txt'

# Never closed and never added: Windows itself, the console this script runs
# in, and Neo Browser.
$protectedNames = @(
    'System', 'Idle', 'Registry', 'smss', 'csrss', 'wininit', 'winlogon',
    'services', 'lsass', 'svchost', 'dwm', 'explorer', 'conhost',
    'powershell', 'pwsh', 'WindowsTerminal', 'OpenConsole',
    'Neo', 'NeoBrowser', 'Neo Browser'
)

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-ForExit {
    Write-Host ''
    Read-Host 'Press Enter to close' | Out-Null
}

function Initialize-LocalFile {
    if (-not (Test-Path -LiteralPath $localFile)) {
        New-Item -ItemType File -Path $localFile | Out-Null
    }
}

# One name per line; '#' starts a comment; a trailing '.exe' is tolerated.
function Read-Patterns {
    $patterns = foreach ($file in @($defaultFile, $localFile)) {
        if (Test-Path -LiteralPath $file) {
            Get-Content -LiteralPath $file |
                ForEach-Object { ($_ -replace '#.*$', '').Trim() } |
                Where-Object { $_ -ne '' } |
                ForEach-Object { $_ -replace '\.exe$', '' }
        }
    }
    return @($patterns | Sort-Object -Unique)
}

# "C:\...\bravecrashhandler.exe" -> "bravecrashhandler". $null if unusable.
function ConvertTo-AppBaseName {
    param([string]$Name)

    $base = $Name.Trim().Trim('"', "'") -replace '^.*[\\/]', ''
    $base = ($base -replace '\.exe$', '') -replace '\*+$', ''
    if ($base -notmatch '^[\w.\- ]+$') { return $null }
    return $base
}

# Turns each name into a wildcard family (name*) and appends the new ones to
# apps.local.txt. Returns one result per name; Pattern is set when the family
# is on a list (newly added or already covered) and can be closed.
function Add-LocalApps {
    param([string[]]$Names)

    Initialize-LocalFile
    $known    = @(Read-Patterns)
    $toAppend = @()

    $results = foreach ($name in $Names) {
        $base = ConvertTo-AppBaseName $name
        if (-not $base) {
            [pscustomobject]@{ Name = $name; Pattern = $null; Status = 'skipped'; Detail = 'not a valid process name' }
            continue
        }

        $pattern = "$base*"
        if ($base.Length -lt 3) {
            [pscustomobject]@{ Name = $name; Pattern = $null; Status = 'skipped'; Detail = 'too short, would match too many apps' }
            continue
        }

        $protected = $protectedNames | Where-Object { $_ -like $pattern } | Select-Object -First 1
        if ($protected) {
            [pscustomobject]@{ Name = $name; Pattern = $null; Status = 'skipped'; Detail = "would also match $protected" }
            continue
        }

        $coveredBy = $known | Where-Object { $base -like $_ } | Select-Object -First 1
        if ($coveredBy) {
            [pscustomobject]@{ Name = $name; Pattern = $pattern; Status = 'covered'; Detail = "already covered by $coveredBy" }
            continue
        }

        $known    += $pattern
        $toAppend += $pattern
        [pscustomobject]@{ Name = $name; Pattern = $pattern; Status = 'added'; Detail = '' }
    }

    if ($toAppend.Count -gt 0) {
        $existing = [IO.File]::ReadAllText($localFile)
        if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) {
            $toAppend = @('') + $toAppend
        }
        Add-Content -LiteralPath $localFile -Value $toAppend -Encoding UTF8
    }

    return @($results)
}

function Write-AddResults {
    param($Results)

    foreach ($result in $Results) {
        switch ($result.Status) {
            'added'   { Write-Host "  Added $($result.Pattern) to apps.local.txt" -ForegroundColor Green }
            'covered' { Write-Host "  $($result.Pattern): $($result.Detail)" }
            default   { Write-Host "  Skipped $($result.Name): $($result.Detail)" -ForegroundColor Yellow }
        }
    }
}

function Stop-MatchingProcesses {
    param([string[]]$Patterns)

    # Collect first so a process matched by two patterns is only stopped once.
    $targets = foreach ($pattern in $Patterns) {
        Get-Process -Name $pattern -ErrorAction SilentlyContinue
    }
    $targets = $targets |
        Where-Object { $_.Id -ne $PID -and $protectedNames -notcontains $_.ProcessName } |
        Sort-Object Id -Unique

    $closed = @{}
    $failed = @{}

    foreach ($process in $targets) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            $closed[$process.ProcessName] = 1 + [int]$closed[$process.ProcessName]
        } catch {
            # Child processes often exit with their parent before we reach them.
            if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
                $closed[$process.ProcessName] = 1 + [int]$closed[$process.ProcessName]
            } elseif (-not $failed.ContainsKey($process.ProcessName)) {
                $failed[$process.ProcessName] = $_.Exception.Message
            }
        }
    }

    return @{ Closed = $closed; Failed = $failed }
}

function Write-CloseSummary {
    param($Result, [string]$NothingMessage)

    if ($Result.Closed.Count -eq 0) {
        Write-Host $NothingMessage -ForegroundColor Green
    } else {
        Write-Host 'Closed:' -ForegroundColor Green
        foreach ($name in ($Result.Closed.Keys | Sort-Object)) {
            $count  = $Result.Closed[$name]
            $suffix = if ($count -gt 1) { " ($count processes)" } else { '' }
            Write-Host "  $name$suffix"
        }
    }

    if ($Result.Failed.Count -gt 0) {
        Write-Host ''
        Write-Host 'Could not close:' -ForegroundColor Red
        foreach ($name in ($Result.Failed.Keys | Sort-Object)) {
            Write-Host "  $name - $($Result.Failed[$name])"
        }
        Write-Host ''
        Write-Host 'Close these yourself (or end them in Task Manager) before opening Neo.' -ForegroundColor Yellow
    } else {
        Write-Host ''
        Write-Host 'Done. You can open Neo Browser now.' -ForegroundColor Green
    }
}

# Reads one line, plus any further lines that arrived in the same paste.
function Read-PastedText {
    $lines = @(Read-Host)
    if ([string]::IsNullOrWhiteSpace($lines[0])) { return '' }

    Start-Sleep -Milliseconds 150
    try {
        while ([Console]::KeyAvailable) { $lines += [Console]::ReadLine() }
    } catch {
        # No interactive console; keep the first line only.
    }
    return ($lines -join "`n")
}

# --- -Add: update apps.local.txt and exit (no admin needed) -------------------

if ($PSBoundParameters.ContainsKey('Add')) {
    $names = @($Add) + @($MoreNames) |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }

    if (-not $names) {
        Write-Host 'Usage: neo-prep.ps1 -Add <name> [<name> ...]' -ForegroundColor Yellow
        exit 1
    }

    Write-AddResults (Add-LocalApps $names)
    exit 0
}

# --- Normal run ---------------------------------------------------------------

# Relaunch elevated (one UAC prompt). If the prompt is declined, carry on
# without admin; apps you own can still be closed.
if (-not (Test-IsAdmin)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs
        exit
    } catch {
        Write-Host 'Admin rights declined; continuing without them.' -ForegroundColor Yellow
        Write-Host ''
    }
}

$Host.UI.RawUI.WindowTitle = 'Neo Prep'

if (-not (Test-Path -LiteralPath $defaultFile)) {
    Write-Host 'apps.default.txt not found next to the script:' -ForegroundColor Red
    Write-Host "  $defaultFile"
    Wait-ForExit
    exit 1
}
Initialize-LocalFile

Write-Host 'Neo Prep' -ForegroundColor Cyan
Write-Host '--------'
Write-CloseSummary (Stop-MatchingProcesses (Read-Patterns)) 'Nothing to close; none of the listed apps were running.'

# If Neo still lists apps, take its message, remember those apps and close them.
while ($true) {
    Write-Host ''
    Write-Host 'Did Neo still complain? Paste the app names it listed, or press Enter to finish.' -ForegroundColor Cyan
    $text = Read-PastedText
    if ([string]::IsNullOrWhiteSpace($text)) { break }

    $names = [regex]::Matches($text, '[\w.\-]+\.exe\b', 'IgnoreCase') |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique
    if (-not $names) {
        Write-Host 'No .exe names found in that text. Paste the list exactly as Neo shows it.' -ForegroundColor Yellow
        continue
    }

    Write-Host ''
    $results = Add-LocalApps $names
    Write-AddResults $results

    $patterns = @($results | Where-Object { $_.Pattern } | ForEach-Object { $_.Pattern })
    if ($patterns.Count -gt 0) {
        Write-Host ''
        Write-CloseSummary (Stop-MatchingProcesses $patterns) 'None of those were running.'
    }
}
