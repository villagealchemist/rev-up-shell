#requires -Version 5.1

# MJ PowerShell environment. Windows PowerShell 5.1 / PowerShell 7.
# Load with: . .\MJ.Profile.ps1
# No installers, network requests, elevation, or execution-policy changes.

$global:MJProfilePath = $PSCommandPath
$global:MJProfileVersion = '1.0.0'
$mjDefaults = @{
    PromptName = 'alchemist'
    EditMode = 'Emacs'
    ShowGit = $true
    ShowGreeting = $true
    ShowVenv = $true
    Predictions = $true
    Projects = @{}
    Editor = ''
}
if (-not (Get-Variable MJConfig -Scope Global -ErrorAction SilentlyContinue)) {
    $global:MJConfig = @{}
}
foreach ($mjKey in $mjDefaults.Keys) {
    if (-not $global:MJConfig.ContainsKey($mjKey)) { $global:MJConfig[$mjKey] = $mjDefaults[$mjKey] }
}

function global:Get-MJExecutable {
    param([Parameter(Mandatory=$true)][string]$Name)
    $mjCommand = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($mjCommand) { return $mjCommand.Path }
    return $null
}

function global:Invoke-MJExternal {
    param([Parameter(Mandatory=$true)][string]$Command, [string[]]$ArgumentList = @())
    $mjExecutable = Get-MJExecutable $Command
    if (-not $mjExecutable) { throw "'$Command' is not installed or is not on PATH. Check your approved software catalog." }
    & $mjExecutable @ArgumentList
    $global:LASTEXITCODE = $LASTEXITCODE
}

function global:prompt {
    $mjLastSucceeded = $?
    $mjSavedExit = $global:LASTEXITCODE
    try {
        $mjLocation = (Get-Location).Path
        $mjDisplay = $mjLocation
        if ($mjLocation -eq $HOME) { $mjDisplay = '~' }
        elseif ($mjLocation.StartsWith($HOME + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            $mjDisplay = '~' + $mjLocation.Substring($HOME.Length)
        }
        $mjBranch = ''
        if ($global:MJConfig.ShowGit -and (Get-Location).Provider.Name -eq 'FileSystem') {
            $mjGit = Get-MJExecutable 'git'
            if ($mjGit) {
                $mjBranch = & $mjGit symbolic-ref --quiet --short HEAD 2>$null
                if ($LASTEXITCODE -ne 0) { $mjBranch = & $mjGit rev-parse --short HEAD 2>$null }
                if ($LASTEXITCODE -ne 0) { $mjBranch = '' }
            }
        }
        $mjPrefix = [string]$global:MJConfig.PromptName
        $mjVenv = ''
        if ($global:MJConfig.ShowVenv -and $env:VIRTUAL_ENV) { $mjVenv = ' (' + (Split-Path $env:VIRTUAL_ENV -Leaf) + ')' }
        $mjFailure = ''
        if (-not $mjLastSucceeded) { $mjFailure = ' !' }
        if ($env:NO_COLOR) {
            $mjGitText = ''; if ($mjBranch) { $mjGitText = ' [' + $mjBranch + ']' }
            return "$mjPrefix $mjDisplay$mjGitText$mjVenv$mjFailure > "
        }
        Write-Host "$mjPrefix " -NoNewline -ForegroundColor DarkGray
        Write-Host $mjDisplay -NoNewline -ForegroundColor Magenta
        if ($mjBranch) { Write-Host " [$mjBranch]" -NoNewline -ForegroundColor Cyan }
        if ($mjVenv) { Write-Host $mjVenv -NoNewline -ForegroundColor Green }
        if ($mjFailure) { Write-Host $mjFailure -NoNewline -ForegroundColor Red }
        return ' > '
    }
    catch { return 'PS> ' }
    finally { $global:LASTEXITCODE = $mjSavedExit }
}

function global:Set-MJKeys {
    param([ValidateSet('Emacs','Windows','Vi')][string]$Mode = 'Emacs')
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) {
        Write-Warning 'PSReadLine is unavailable in this host. Commands still work; custom editing keys need PSReadLine.'
        return
    }
    Set-PSReadLineOption -EditMode $Mode -ErrorAction Stop
    $global:MJConfig.EditMode = $Mode
    if ($Mode -eq 'Vi') { return }
    foreach ($mjBinding in @(
        @('Tab','MenuComplete'), @('Shift+Tab','TabCompletePrevious'),
        @('Ctrl+r','ReverseSearchHistory'), @('UpArrow','HistorySearchBackward'),
        @('DownArrow','HistorySearchForward'), @('Ctrl+l','ClearScreen'),
        @('Ctrl+Spacebar','MenuComplete')
    )) {
        try { Set-PSReadLineKeyHandler -Key $mjBinding[0] -Function $mjBinding[1] -ErrorAction Stop }
        catch { Write-Verbose "Key binding unavailable: $($mjBinding[0])" }
    }
}

function global:mj-keys { param([ValidateSet('Emacs','Windows','Vi')][string]$Mode = 'Emacs'); Set-MJKeys $Mode }

function global:mj-doctor {
    [pscustomobject]@{ Check='PowerShell'; Value=$PSVersionTable.PSVersion.ToString() }
    [pscustomobject]@{ Check='Language mode'; Value=$ExecutionContext.SessionState.LanguageMode }
    [pscustomobject]@{ Check='Profile loaded'; Value=$global:MJProfilePath }
    [pscustomobject]@{ Check='Startup profile'; Value=$PROFILE.CurrentUserAllHosts }
    [pscustomobject]@{ Check='Execution policy'; Value=(Get-ExecutionPolicy) }
    [pscustomobject]@{ Check='PSReadLine'; Value=((Get-Module PSReadLine | Select-Object -First 1).Version) }
    foreach ($mjTool in @('git','gh','py','python3','python','uv','node','npm','pnpm','code','webstorm','pycharm','rg','fzf','bat')) {
        $mjPath = Get-MJExecutable $mjTool
        if (-not $mjPath) { $mjPath = 'not found (optional)' }
        [pscustomobject]@{ Check=$mjTool; Value=$mjPath }
    }
}

function global:croot {
    $mjGit = Get-MJExecutable 'git'
    if (-not $mjGit) { throw 'Git is not installed or not on PATH.' }
    $mjRoot = & $mjGit rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'This directory is not inside a Git repository.' }
    Set-Location -LiteralPath $mjRoot
}

function global:cproj {
    param([string]$Name)
    if (-not $Name) {
        $global:MJConfig.Projects.GetEnumerator() | Sort-Object Name | Select-Object Name,Value
        return
    }
    if (-not $global:MJConfig.Projects.ContainsKey($Name)) { throw "No project named '$Name'. Add it to MJConfig.Projects in MJ.Local.ps1." }
    Set-Location -LiteralPath $global:MJConfig.Projects[$Name]
}

function global:backup-profile {
    param([string]$Destination)
    if (-not $Destination) { $Destination = Join-Path (Split-Path $global:MJProfilePath -Parent) 'backups' }
    $mjBackupDir = Join-Path $Destination ('mj-profile-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,6)))
    New-Item -ItemType Directory -Path $mjBackupDir -Force -ErrorAction Stop | Out-Null
    Copy-Item -LiteralPath $global:MJProfilePath -Destination (Join-Path $mjBackupDir 'MJ.Profile.ps1') -ErrorAction Stop
    $mjLocal = Join-Path (Split-Path $global:MJProfilePath -Parent) 'MJ.Local.ps1'
    if (Test-Path -LiteralPath $mjLocal) { Copy-Item -LiteralPath $mjLocal -Destination $mjBackupDir -ErrorAction Stop }
    if (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts) {
        Copy-Item -LiteralPath $PROFILE.CurrentUserAllHosts -Destination (Join-Path $mjBackupDir 'startup-profile.ps1') -ErrorAction Stop
    }
    Write-Host "Profile backup saved to $mjBackupDir"
    Write-Host 'Copies profile/config only; command history and installed tools are not included.'
    return $mjBackupDir
}

function global:mj-help {
@'
YOUR SHELL, LESS WINDOWS-Y
  mj-unixhelp / mj-devhelp     Exact commands, flags and examples
  mj-doctor                   Profile, runtime and installed-tool checks
  mj-keys Emacs|Windows|Vi     Change editing keys for this session
  pedit / reload-profile      Edit / reload this profile
  cproj / cproj name          List / enter your configured projects
  croot                       Enter the current Git repository root
  backup-profile [folder]     Save profile/config backup (no history)

DEFAULT KEYS (Emacs)
  Tab / Shift+Tab             Complete / cycle backward
  Ctrl+r                     Search command history
  Up / Down                  Search history with the prefix you typed
  Ctrl+a / Ctrl+e             Start / end of line
  Alt+b / Alt+f               Back / forward one word
  Ctrl+w / Ctrl+k / Ctrl+y    Cut previous word / cut to end / paste cut text
  Ctrl+l                     Clear screen
  Shift+Insert               Terminal paste when supported

This is PowerShell syntax and object pipelines with Unix-style helpers.
rm/cp/mv retain PowerShell behavior. Use full cmdlet names in scripts.
Type help <command> or Get-Help <cmdlet> for PowerShell's own help.
'@
}


# Small, explicit Unix-style helpers for Windows PowerShell 5.1 and PowerShell 7.
# Dot-source this file. These helpers never evaluate directory-local code.

function global:MJExpandHomePath {
    param([string]$Path)
    if ($Path -eq '~') { return $HOME }
    if ($Path.StartsWith('~/') -or $Path.StartsWith('~\')) {
        return (Join-Path -Path $HOME -ChildPath $Path.Substring(2))
    }
    return $Path
}

function global:MJFileSystemPath {
    param([string]$Path)
    $provider = $null
    $drive = $null
    $expanded = MJExpandHomePath $Path
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $expanded, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'FileSystem') {
        throw "This helper requires a filesystem path: $Path"
    }
    return $resolved
}

function global:MJPlainArguments {
    param([string]$CommandName, [object[]]$Arguments)
    $afterDash = $false
    foreach ($argument in $Arguments) {
        $value = [string]$argument
        if (-not $afterDash -and $value -eq '--') {
            $afterDash = $true
            continue
        }
        if (-not $afterDash -and $value.StartsWith('-')) {
            throw "${CommandName}: unsupported option '$value'. Use -- before a name beginning with -. See mj-unixhelp."
        }
        $value
    }
}

function global:MJChangeDirectory {
    param([string]$Path)
    $before = (Get-Location).Path
    $target = MJExpandHomePath $Path
    Set-Location -LiteralPath $target -ErrorAction Stop
    $global:MJPreviousDirectory = $before
}

# PowerShell's stock aliases would take precedence over functions with these names.
# This file is intended to be dot-sourced from the user's profile.
foreach ($mjAliasName in @('ls', 'cd', 'mkdir', 'head', 'tail', 'grep', 'wc',
        'which', 'open', 'touch', 'll', 'la', 'l', 'up', 'mkcd', 'repojump',
        'countfiles', 'countall', 'pbcopy', 'pbpaste')) {
    if (Test-Path -LiteralPath ('Alias:' + $mjAliasName)) {
        Remove-Item -LiteralPath ('Alias:' + $mjAliasName) -Force -ErrorAction Stop
    }
}
Remove-Variable -Name mjAliasName -ErrorAction SilentlyContinue

function global:ls {
    $force = $false
    $recurse = $false
    $reverse = $false
    $afterDash = $false
    $paths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($argument in $args) {
        $value = [string]$argument
        if (-not $afterDash -and $value -eq '--') {
            $afterDash = $true
        } elseif (-not $afterDash -and $value.StartsWith('-')) {
            if ($value.Length -lt 2) { throw 'ls: use -- before a path named -.' }
            foreach ($flag in $value.Substring(1).ToCharArray()) {
                switch -CaseSensitive ([string]$flag) {
                    'a' { $force = $true }
                    'A' { $force = $true }
                    'l' { } # Keep native objects and native PowerShell formatting.
                    'h' { } # Accepted for muscle memory; no custom size formatting.
                    'R' { $recurse = $true }
                    'r' { $reverse = $true }
                    default { throw "ls: unsupported option '-$flag'. See mj-unixhelp." }
                }
            }
        } else {
            $paths.Add((MJExpandHomePath $value))
        }
    }
    if ($paths.Count -eq 0) { $paths.Add('.') }
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path -ErrorAction Stop) {
            $items = @(Get-ChildItem -LiteralPath $path -Force:$force -Recurse:$recurse -ErrorAction Stop |
                Sort-Object -Property FullName)
        } else {
            $items = @(Get-ChildItem -Path $path -Force:$force -Recurse:$recurse -ErrorAction Stop |
                Sort-Object -Property FullName)
        }
        if (-not $force) { $items = @($items | Where-Object { -not $_.Name.StartsWith('.') }) }
        if ($reverse) { [array]::Reverse($items) }
        $items
    }
}

function global:ll { ls -l @args }
function global:la { ls -a @args }
function global:l { ls -al @args }

function global:cd {
    $arguments = @($args)
    if ($arguments.Count -eq 0) {
        MJChangeDirectory $HOME
        return
    }
    if ($arguments.Count -eq 1 -and [string]$arguments[0] -eq '-') {
        $previous = Get-Variable -Name MJPreviousDirectory -Scope Global -ErrorAction SilentlyContinue
        if ($null -eq $previous -or [string]::IsNullOrEmpty([string]$previous.Value)) {
            throw 'cd: no previous directory in this session.'
        }
        MJChangeDirectory ([string]$previous.Value)
        return
    }
    $paths = @(MJPlainArguments 'cd' $arguments)
    if ($paths.Count -ne 1) { throw 'Usage: cd [path | -]. Use -- before a path beginning with -.' }
    MJChangeDirectory $paths[0]
}

function global:.. {
    if ($args.Count -ne 0) { throw 'Usage: .. (no options)' }
    MJChangeDirectory '..'
}
function global:... {
    if ($args.Count -ne 0) { throw 'Usage: ... (no options)' }
    MJChangeDirectory (Join-Path '..' '..')
}

function global:up {
    if ($args.Count -gt 1) { throw 'Usage: up [levels], from 0 through 1024.' }
    $levels = 1
    if ($args.Count -eq 1) {
        if (-not [int]::TryParse([string]$args[0], [ref]$levels) -or $levels -lt 0 -or $levels -gt 1024) {
            throw 'up: levels must be an integer from 0 through 1024.'
        }
    }
    if ($levels -eq 0) { return }
    $target = '.'
    for ($i = 0; $i -lt $levels; $i++) { $target = Join-Path $target '..' }
    MJChangeDirectory $target
}

function global:mkdir {
    $afterDash = $false
    $paths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($argument in $args) {
        $value = [string]$argument
        if (-not $afterDash -and $value -eq '--') {
            $afterDash = $true
        } elseif (-not $afterDash -and $value -eq '-p') {
            # Creating parents and allowing existing directories is always enabled.
        } elseif (-not $afterDash -and $value.StartsWith('-')) {
            throw "mkdir: unsupported option '$value'. Supported option: -p."
        } else { $paths.Add($value) }
    }
    if ($paths.Count -eq 0) { throw 'Usage: mkdir [-p] [--] path ...' }
    foreach ($path in $paths) {
        [System.IO.Directory]::CreateDirectory((MJFileSystemPath $path))
    }
}

function global:mkcd {
    $paths = @(MJPlainArguments 'mkcd' $args)
    if ($paths.Count -ne 1) { throw 'Usage: mkcd [--] path' }
    $fullPath = MJFileSystemPath $paths[0]
    $null = [System.IO.Directory]::CreateDirectory($fullPath)
    MJChangeDirectory $fullPath
}

function global:repojump {
    $paths = @(MJPlainArguments 'repojump' $args)
    if ($paths.Count -gt 2) { throw 'Usage: repojump [starting-path] or repojump name directory' }
    if ($paths.Count -eq 2) {
        # Preserve the existing named-shortcut call shape without running repoenv.
        MJChangeDirectory $paths[1]
        return
    }
    $start = '.'
    if ($paths.Count -eq 1) { $start = $paths[0] }
    $candidate = MJFileSystemPath $start
    if ([System.IO.File]::Exists($candidate)) { $candidate = [System.IO.Path]::GetDirectoryName($candidate) }
    if (-not [System.IO.Directory]::Exists($candidate)) { throw "repojump: directory does not exist: $start" }
    while ($null -ne $candidate) {
        $marker = Join-Path $candidate '.git'
        if ([System.IO.Directory]::Exists($marker) -or [System.IO.File]::Exists($marker)) {
            MJChangeDirectory $candidate
            return
        }
        $parent = [System.IO.Directory]::GetParent($candidate)
        if ($null -eq $parent) { $candidate = $null } else { $candidate = $parent.FullName }
    }
    throw 'repojump: no .git file or directory found in this path or its parents.'
}

function global:touch {
    $paths = @(MJPlainArguments 'touch' $args)
    if ($paths.Count -eq 0) { throw 'Usage: touch [--] path ...' }
    foreach ($path in $paths) {
        $fullPath = MJFileSystemPath $path
        $now = Get-Date
        if ([System.IO.Directory]::Exists($fullPath)) {
            [System.IO.Directory]::SetLastWriteTime($fullPath, $now)
            [System.IO.Directory]::SetLastAccessTime($fullPath, $now)
        } else {
            if (-not [System.IO.File]::Exists($fullPath)) {
                $stream = [System.IO.File]::Open($fullPath, [System.IO.FileMode]::OpenOrCreate,
                    [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
                $stream.Dispose()
            }
            [System.IO.File]::SetLastWriteTime($fullPath, $now)
            [System.IO.File]::SetLastAccessTime($fullPath, $now)
        }
    }
}

function global:which {
    $all = $false
    $afterDash = $false
    $names = New-Object 'System.Collections.Generic.List[string]'
    foreach ($argument in $args) {
        $value = [string]$argument
        if (-not $afterDash -and $value -eq '--') { $afterDash = $true }
        elseif (-not $afterDash -and $value -eq '-a') { $all = $true }
        elseif (-not $afterDash -and $value.StartsWith('-')) { throw "which: unsupported option '$value'. Supported option: -a." }
        else { $names.Add($value) }
    }
    if ($names.Count -eq 0) { throw 'Usage: which [-a] [--] command-name ...' }
    foreach ($name in $names) {
        Get-Command -Name $name -All:$all -ErrorAction Stop
    }
}

function global:MJTextLines {
    param([AllowNull()][object]$Value)
    $text = [string]$Value
    $lines = [regex]::Split($text, '\r\n|\n|\r')
    $length = $lines.Length
    if ($length -gt 1 -and $lines[$length - 1] -eq '') { $length-- }
    for ($i = 0; $i -lt $length; $i++) { $lines[$i] }
}

function global:MJLineArguments {
    param([string]$CommandName, [object[]]$Arguments)
    $count = 10
    $follow = $false
    $path = $null
    $afterDash = $false
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $value = [string]$Arguments[$i]
        if (-not $afterDash -and $value -eq '--') { $afterDash = $true }
        elseif (-not $afterDash -and $value -eq '-n') {
            $i++
            if ($i -ge $Arguments.Count -or -not [int]::TryParse([string]$Arguments[$i], [ref]$count) -or $count -lt 0) {
                throw "${CommandName}: -n requires a nonnegative integer."
            }
        } elseif (-not $afterDash -and $value -eq '-f' -and $CommandName -eq 'tail') { $follow = $true }
        elseif (-not $afterDash -and $value.StartsWith('-')) { throw "${CommandName}: unsupported option '$value'. See mj-unixhelp." }
        else {
            if ($null -ne $path) { throw "${CommandName}: supply one file or pipeline input." }
            $path = $value
        }
    }
    if ($follow -and $null -eq $path) { throw 'tail: -f requires a file path.' }
    [pscustomobject]@{ Count = $count; Follow = $follow; Path = $path }
}

function global:head {
    begin {
        $options = MJLineArguments 'head' $args
        $hasPipeline = $MyInvocation.ExpectingInput
        if ($hasPipeline -and $null -ne $options.Path) { throw 'head: choose a file or pipeline input, not both.' }
        if (-not $hasPipeline -and $null -eq $options.Path) { throw 'head: provide a file or pipeline input.' }
        $seen = 0
    }
    process {
        if ($hasPipeline) {
            foreach ($item in $input) {
                foreach ($line in (MJTextLines $item)) {
                    if ($seen -lt $options.Count) { $line; $seen++ }
                }
            }
        }
    }
    end {
        if ($null -ne $options.Path) {
            $fullPath = MJFileSystemPath $options.Path
            if (-not [System.IO.File]::Exists($fullPath)) { throw "head: file does not exist: $($options.Path)" }
            if ($options.Count -gt 0) {
                foreach ($line in [System.IO.File]::ReadLines($fullPath)) {
                    $line
                    $seen++
                    if ($seen -ge $options.Count) { break }
                }
            }
        }
    }
}

function global:tail {
    begin {
        $options = MJLineArguments 'tail' $args
        $hasPipeline = $MyInvocation.ExpectingInput
        if ($hasPipeline -and $null -ne $options.Path) { throw 'tail: choose a file or pipeline input, not both.' }
        if (-not $hasPipeline -and $null -eq $options.Path) { throw 'tail: provide a file or pipeline input.' }
        $queue = New-Object 'System.Collections.Generic.Queue[string]'
    }
    process {
        if ($hasPipeline -and $options.Count -gt 0) {
            foreach ($item in $input) {
                foreach ($line in (MJTextLines $item)) {
                    $queue.Enqueue($line)
                    if ($queue.Count -gt $options.Count) { $null = $queue.Dequeue() }
                }
            }
        }
    }
    end {
        if ($null -ne $options.Path) {
            $fullPath = MJFileSystemPath $options.Path
            if (-not [System.IO.File]::Exists($fullPath)) { throw "tail: file does not exist: $($options.Path)" }
            if ($options.Follow) {
                Get-Content -LiteralPath $fullPath -Encoding UTF8 -Tail $options.Count -Wait -ErrorAction Stop
                return
            }
            if ($options.Count -gt 0) {
                foreach ($line in [System.IO.File]::ReadLines($fullPath)) {
                    $queue.Enqueue($line)
                    if ($queue.Count -gt $options.Count) { $null = $queue.Dequeue() }
                }
            }
        }
        foreach ($line in $queue) { $line }
    }
}

function global:MJInputFiles {
    param([string[]]$Paths, [bool]$Recurse = $false)
    foreach ($path in $Paths) {
        $expanded = MJExpandHomePath $path
        if (Test-Path -LiteralPath $expanded -ErrorAction Stop) {
            $items = @(Get-Item -LiteralPath $expanded -Force -ErrorAction Stop)
        } else {
            $items = @(Get-Item -Path $expanded -Force -ErrorAction Stop)
        }
        foreach ($item in $items) {
            if ($item.PSProvider.Name -ne 'FileSystem') { throw "A filesystem path is required: $path" }
            if ($item.PSIsContainer) {
                if (-not $Recurse) { throw "Cannot read directory '$path' as a file; grep requires -r to search directories." }
                Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force -ErrorAction Stop |
                    Sort-Object -Property FullName
            } else { $item }
        }
    }
}

function global:MJGrepArguments {
    param([object[]]$Arguments)
    $options = [pscustomobject]@{
        IgnoreCase = $false; Number = $false; Invert = $false; Fixed = $false
        Recurse = $false; List = $false; Quiet = $false; Pattern = $null
        Paths = (New-Object 'System.Collections.Generic.List[string]')
    }
    $afterDash = $false
    foreach ($argument in $Arguments) {
        $value = [string]$argument
        if (-not $afterDash -and $value -eq '--') { $afterDash = $true }
        elseif (-not $afterDash -and $value.StartsWith('-')) {
            if ($value.Length -lt 2) { throw 'grep: - as a stdin placeholder is unsupported; pipe text instead.' }
            foreach ($flag in $value.Substring(1).ToCharArray()) {
                switch -CaseSensitive ([string]$flag) {
                    'i' { $options.IgnoreCase = $true }
                    'n' { $options.Number = $true }
                    'v' { $options.Invert = $true }
                    'F' { $options.Fixed = $true }
                    'r' { $options.Recurse = $true }
                    'R' { $options.Recurse = $true }
                    'l' { $options.List = $true }
                    'q' { $options.Quiet = $true }
                    default { throw "grep: unsupported option '-$flag'. See mj-unixhelp." }
                }
            }
        } elseif ($null -eq $options.Pattern) { $options.Pattern = $value }
        else { $options.Paths.Add($value) }
    }
    if ($null -eq $options.Pattern) { throw 'Usage: grep [-invFrRlq] [--] pattern [file ...]' }
    if (-not $options.Fixed) { $null = [regex]$options.Pattern }
    return $options
}

function global:MJGrepMatch {
    param([string]$Text, [object]$Options)
    $matched = $true
    if ($Options.Pattern.Length -ne 0) {
        $matched = [bool]($Text | Select-String -Pattern $Options.Pattern -SimpleMatch:$Options.Fixed `
            -CaseSensitive:(-not $Options.IgnoreCase) -Quiet -ErrorAction Stop)
    }
    if ($Options.Invert) { return (-not $matched) }
    return $matched
}

function global:grep {
    begin {
        $global:LASTEXITCODE = 2
        $options = MJGrepArguments $args
        $hasPipeline = $MyInvocation.ExpectingInput
        if ($hasPipeline -and $options.Paths.Count -gt 0) { throw 'grep: choose files or pipeline input, not both.' }
        if (-not $hasPipeline -and $options.Paths.Count -eq 0) {
            if ($options.Recurse) { $options.Paths.Add('.') }
            else { throw 'grep: provide a file or pipeline input; -r defaults to the current directory.' }
        }
        if ($hasPipeline -and $options.Recurse) { throw 'grep: -r/-R require file or directory input.' }
        $found = $false
        $lineNumber = 0L
    }
    process {
        if ($hasPipeline) {
            try {
                foreach ($item in $input) {
                    foreach ($line in (MJTextLines $item)) {
                        $lineNumber++
                        if ($found -and ($options.List -or $options.Quiet)) { continue }
                        if (MJGrepMatch $line $options) {
                            $found = $true
                            if ($options.Quiet) { continue }
                            if ($options.List) { '(standard input)' }
                            elseif ($options.Number) { '{0}:{1}' -f $lineNumber, $line }
                            else { $line }
                        }
                    }
                }
            } catch { $global:LASTEXITCODE = 2; throw }
        }
    }
    end {
        try {
            if (-not $hasPipeline) {
                $files = @(MJInputFiles -Paths $options.Paths.ToArray() -Recurse $options.Recurse)
                $showFilename = ($files.Count -gt 1 -or $options.Recurse)
                foreach ($file in $files) {
                    $lineNumber = 0L
                    foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
                        $lineNumber++
                        if (MJGrepMatch $line $options) {
                            $found = $true
                            if ($options.Quiet) { break }
                            if ($options.List) { $file.FullName; break }
                            $prefix = ''
                            if ($showFilename) { $prefix = $file.FullName + ':' }
                            if ($options.Number) { $prefix += [string]$lineNumber + ':' }
                            $prefix + $line
                        }
                    }
                    if ($found -and $options.Quiet) { break }
                }
            }
            if ($found) { $global:LASTEXITCODE = 0 } else { $global:LASTEXITCODE = 1 }
        } catch { $global:LASTEXITCODE = 2; throw }
    }
}

function global:MJMeasureFile {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    $reader = $null
    $result = [pscustomobject]@{ Lines = 0L; Words = 0L; Bytes = [long]$stream.Length; Path = $Path }
    try {
        $reader = New-Object System.IO.StreamReader -ArgumentList $stream
        $buffer = New-Object 'char[]' 8192
        $inWord = $false
        while (($readCount = $reader.Read($buffer, 0, $buffer.Length)) -gt 0) {
            for ($i = 0; $i -lt $readCount; $i++) {
                $character = $buffer[$i]
                if ($character -eq "`n") { $result.Lines++ }
                if ([char]::IsWhiteSpace($character)) { $inWord = $false }
                elseif (-not $inWord) { $result.Words++; $inWord = $true }
            }
        }
    } finally {
        if ($null -ne $reader) { $reader.Dispose() } else { $stream.Dispose() }
    }
    return $result
}

function global:MJCountOutput {
    param([object]$Record, [bool]$Lines, [bool]$Words, [bool]$Bytes)
    $fields = [ordered]@{}
    if ($Lines) { $fields['Lines'] = $Record.Lines }
    if ($Words) { $fields['Words'] = $Record.Words }
    if ($Bytes) { $fields['Bytes'] = $Record.Bytes }
    $fields['Path'] = $Record.Path
    [pscustomobject]$fields
}

function global:wc {
    begin {
        $showLines = $false
        $showWords = $false
        $showBytes = $false
        $afterDash = $false
        $paths = New-Object 'System.Collections.Generic.List[string]'
        foreach ($argument in $args) {
            $value = [string]$argument
            if (-not $afterDash -and $value -eq '--') { $afterDash = $true }
            elseif (-not $afterDash -and $value.StartsWith('-')) {
                if ($value.Length -lt 2) { throw 'wc: - as a stdin placeholder is unsupported; pipe text instead.' }
                foreach ($flag in $value.Substring(1).ToCharArray()) {
                    switch -CaseSensitive ([string]$flag) {
                        'l' { $showLines = $true }
                        'w' { $showWords = $true }
                        'c' { $showBytes = $true }
                        default { throw "wc: unsupported option '-$flag'. Supported options: -l -w -c." }
                    }
                }
            } else { $paths.Add($value) }
        }
        if (-not $showLines -and -not $showWords -and -not $showBytes) {
            $showLines = $true; $showWords = $true; $showBytes = $true
        }
        $hasPipeline = $MyInvocation.ExpectingInput
        if ($hasPipeline -and $paths.Count -gt 0) { throw 'wc: choose files or pipeline input, not both.' }
        if (-not $hasPipeline -and $paths.Count -eq 0) { throw 'wc: provide files or pipeline input.' }
        $record = [pscustomobject]@{ Lines = 0L; Words = 0L; Bytes = 0L; Path = '(pipeline)' }
        $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    }
    process {
        if ($hasPipeline) {
            foreach ($item in $input) {
                foreach ($line in (MJTextLines $item)) {
                    $record.Lines++
                    $record.Words += [regex]::Matches($line, '\S+').Count
                    $record.Bytes += $utf8.GetByteCount($line + "`n")
                }
            }
        }
    }
    end {
        if ($hasPipeline) {
            MJCountOutput $record $showLines $showWords $showBytes
        } else {
            $files = @(MJInputFiles -Paths $paths.ToArray())
            $total = [pscustomobject]@{ Lines = 0L; Words = 0L; Bytes = 0L; Path = 'total' }
            foreach ($file in $files) {
                if ($showLines -or $showWords) { $record = MJMeasureFile $file.FullName }
                else {
                    $record = [pscustomobject]@{
                        Lines = 0L; Words = 0L; Bytes = [long]$file.Length; Path = $file.FullName
                    }
                }
                $total.Lines += $record.Lines
                $total.Words += $record.Words
                $total.Bytes += $record.Bytes
                MJCountOutput $record $showLines $showWords $showBytes
            }
            if ($files.Count -gt 1) { MJCountOutput $total $showLines $showWords $showBytes }
        }
    }
}

function global:open {
    $paths = @(MJPlainArguments 'open' $args)
    if ($paths.Count -eq 0) { $paths = @('.') }
    foreach ($path in $paths) { Invoke-Item -LiteralPath (MJExpandHomePath $path) -ErrorAction Stop }
}

function global:MJCountFiles {
    param([bool]$IncludeDirectories, [object[]]$Arguments)
    $paths = @(MJPlainArguments 'countfiles/countall' $Arguments)
    if ($paths.Count -gt 1) { throw 'Usage: countfiles [path] or countall [path]' }
    $path = '.'
    if ($paths.Count -eq 1) { $path = $paths[0] }
    $fullPath = MJFileSystemPath $path
    if (-not [System.IO.Directory]::Exists($fullPath)) { throw "Directory does not exist: $path" }
    (Get-ChildItem -LiteralPath $fullPath -ErrorAction Stop |
        Where-Object {
            -not $_.Name.StartsWith('.') -and ($IncludeDirectories -or -not $_.PSIsContainer)
        } |
        Measure-Object).Count
}

function global:countfiles { MJCountFiles -IncludeDirectories $false -Arguments $args }
function global:countall { MJCountFiles -IncludeDirectories $true -Arguments $args }

function global:pbcopy {
    begin {
        $clipboardCommand = Get-Command -Name Set-Clipboard -CommandType Cmdlet -ErrorAction SilentlyContinue
        if ($null -eq $clipboardCommand) { throw 'pbcopy: Set-Clipboard is unavailable in this PowerShell session.' }
        $values = @(MJPlainArguments 'pbcopy' $args)
        $hasPipeline = $MyInvocation.ExpectingInput
        if ($hasPipeline -and $values.Count -gt 0) { throw 'pbcopy: supply text arguments or pipeline input, not both.' }
        if (-not $hasPipeline -and $values.Count -eq 0) { throw 'pbcopy: supply text arguments or pipeline input.' }
        $textItems = New-Object 'System.Collections.Generic.List[string]'
        foreach ($value in $values) { $textItems.Add([string]$value) }
    }
    process {
        if ($hasPipeline) {
            foreach ($item in $input) { $textItems.Add([string]$item) }
        }
    }
    end {
        $text = [string]::Join("`n", $textItems.ToArray())
        & $clipboardCommand -Value $text -ErrorAction Stop
    }
}

function global:pbpaste {
    if ($args.Count -ne 0) { throw 'Usage: pbpaste (no options)' }
    $clipboardCommand = Get-Command -Name Get-Clipboard -CommandType Cmdlet -ErrorAction SilentlyContinue
    if ($null -eq $clipboardCommand) { throw 'pbpaste: Get-Clipboard is unavailable in this PowerShell session.' }
    & $clipboardCommand -Raw -ErrorAction Stop
}

function global:mj-unixhelp {
    if ($args.Count -ne 0) { throw 'Usage: mj-unixhelp (no options)' }
    @'
Unix-style helpers (PowerShell commands, not a Bash emulator)

  ls [-aAhlRr] [--] [path ...]  List native PowerShell objects; flags combine.
    -a/-A include hidden items, without synthetic . or .. entries.
    -l/-h are accepted compatibility no-ops: standard PowerShell formatting,
    including byte sizes, is retained. -R recurses; -r reverses name order.
    ll = ls -l, la = ls -a, l = ls -al. Each path is sorted separately.
  cd [path]                   No path goes HOME; cd - swaps with previous cd.
  .. / ...                    Go up one / two directories.
  up [levels]                 Go up 0-1024 levels (default 1).
  mkdir [-p] [--] path ...     Create directories and parents; existing is OK.
  mkcd [--] path              Create parents and enter the directory.
  repojump [starting-path]    Enter nearest parent containing a .git marker.
  repojump name directory    Enter directory; name is a compatibility label.
                             Neither form runs repoenv or directory-local code.
  touch [--] path ...         Create empty files or update timestamps;
                             existing file contents are never truncated.
  which [-a] [--] name ...    PowerShell command objects, including aliases,
                             functions, cmdlets, and executables; -a lists all.
  head [-n count] [--] [file] First 10 text lines, or a nonnegative count.
  tail [-n count] [-f] [--] [file]
                             Last 10 lines; -f watches one existing file.
  grep [-invFrRlq] [--] pattern [file ...]
    -i ignore case, -n line numbers, -v invert, -F literal pattern,
    -r/-R recurse (default path .), -l filenames only, -q no output.
    Flags combine. Uses Select-String/.NET regex, not POSIX basic regex.
    -r and -R use PowerShell recursion; they do not enable link following.
    Recursive searches include hidden files. Intended for text files.
    Multiple-file/recursive matches use absolute filename prefixes.
    $LASTEXITCODE: 0 = match, 1 = no match, 2 = error. -q returns no boolean;
    PowerShell $? is not grep's match status. Invalid options stop execution.
  wc [-lwc] [--] [file ...]   Count objects with Lines/Words/Bytes/Path fields.
    No flags shows all counts. Multiple files add a total row.
    Files: Lines counts LF characters, Bytes is actual file size, and Words
    splits on .NET whitespace. Text decoding is UTF-8 with BOM detection.
    Pipeline: counts logical text lines, serialized as UTF-8 plus one LF per
    line, without a BOM. It does not measure a pipeline object's memory size.
  open [--] [path ...]        Open paths in their registered app; default .
  countfiles [path]           Count immediate visible files, excluding dotnames.
  countall [path]             Count immediate visible files and directories,
                             excluding dotnames; neither count is recursive.
  pbcopy [--] [text ...]      Copy text arguments or pipeline to the clipboard.
  pbpaste                    Get raw clipboard text via Get-Clipboard.
    Clipboard helpers require the PowerShell clipboard cmdlets and a working
    desktop clipboard. pbcopy joins items with LF, without an added final LF.

Head, tail, grep, wc accept either paths or pipeline input, never both.
Pipeline text tools stringify objects; use Select-Object -ExpandProperty or
Out-String when you want a specific property or formatted table as text.
Embedded newlines are split into lines; a final newline adds no empty line.
Head consumes upstream input even after it has emitted the requested lines.
Head/tail allow one literal file path. Tail -f uses Get-Content -Wait; Ctrl+C
stops it, and following replacement/rotated files is not guaranteed.
File readers default to UTF-8 with BOM detection; tail -f requests UTF-8.
Use native Get-Content -Encoding when you need a different file encoding.

Quote paths containing spaces. ~ and ~/... expand to HOME (not ~otheruser).
ls, grep and wc prefer an existing literal path (including bracket characters),
then try PowerShell path wildcards; other path helpers use literal paths.
Use -- for operands beginning with -. Unknown flags error.
These wrappers do not accept PowerShell cmdlet switches such as -Force.
Use Get-ChildItem, Set-Location, New-Item, etc. for their full native options.
rm, cp, mv, shell quoting, variable expansion, pipes and redirects retain
PowerShell semantics. No sh syntax, permission emulation, auto-installs, or
directory-local startup scripts are provided.
'@
}


# Developer helpers. PowerShell 5.1 and 7; dot-source as part of the MJ profile.
# Requires Invoke-MJExternal, Get-MJExecutable, and $global:MJProfilePath.
# These functions change the current shell only. They do not install anything.

# The built-in diff alias takes precedence over functions. The assembled profile
# is dot-sourced into the global session, so remove the alias in that scope.
Remove-Item -LiteralPath Alias:diff -Force -ErrorAction SilentlyContinue

function global:branch { Invoke-MJExternal -Command 'git' -ArgumentList (@('branch') + @($args)) }
function global:log { Invoke-MJExternal -Command 'git' -ArgumentList (@('log') + @($args)) }
function global:checkout { Invoke-MJExternal -Command 'git' -ArgumentList (@('checkout') + @($args)) }
function global:add { Invoke-MJExternal -Command 'git' -ArgumentList (@('add') + @($args)) }
function global:status { Invoke-MJExternal -Command 'git' -ArgumentList (@('status') + @($args)) }
function global:commit { Invoke-MJExternal -Command 'git' -ArgumentList (@('commit') + @($args)) }
function global:amend { Invoke-MJExternal -Command 'git' -ArgumentList (@('commit', '--amend') + @($args)) }
function global:pull { Invoke-MJExternal -Command 'git' -ArgumentList (@('pull') + @($args)) }
function global:merge { Invoke-MJExternal -Command 'git' -ArgumentList (@('merge') + @($args)) }
function global:ignored { Invoke-MJExternal -Command 'git' -ArgumentList (@('status', '--ignored') + @($args)) }
function global:stash { Invoke-MJExternal -Command 'git' -ArgumentList (@('stash') + @($args)) }
function global:rebase { Invoke-MJExternal -Command 'git' -ArgumentList (@('rebase') + @($args)) }
function global:fetch { Invoke-MJExternal -Command 'git' -ArgumentList (@('fetch') + @($args)) }
function global:origin { Invoke-MJExternal -Command 'git' -ArgumentList (@('fetch', 'origin') + @($args)) }
function global:restore { Invoke-MJExternal -Command 'git' -ArgumentList (@('restore') + @($args)) }
function global:diff { Invoke-MJExternal -Command 'git' -ArgumentList (@('diff') + @($args)) }
function global:diff-staged { Invoke-MJExternal -Command 'git' -ArgumentList (@('diff', '--staged') + @($args)) }
function global:diff-files { Invoke-MJExternal -Command 'git' -ArgumentList (@('diff', '--stat') + @($args)) }
function global:log-pretty { Invoke-MJExternal -Command 'git' -ArgumentList (@('log', '--pretty=oneline', '--abbrev-commit') + @($args)) }
function global:log-graph { Invoke-MJExternal -Command 'git' -ArgumentList (@('log', '--graph', '--oneline', '--all') + @($args)) }
function global:pr { Invoke-MJExternal -Command 'gh' -ArgumentList (@('pr', 'view', '--web') + @($args)) }
function global:prs { Invoke-MJExternal -Command 'gh' -ArgumentList (@('pr', 'status') + @($args)) }

function global:push {
    [string[]]$pushFlags = @()
    [string[]]$gitArguments = @()
    foreach ($argument in $args) {
        switch -CaseSensitive ([string]$argument) {
            { $_ -ceq 'nv' -or $_ -ceq '--nv' } {
                $pushFlags += '--no-verify'; break
            }
            { $_ -ceq 'lease' -or $_ -ceq 'ff' -or $_ -ceq 'force-with-lease' -or $_ -ceq '--force-with-lease' } {
                $pushFlags += '--force-with-lease'; break
            }
            { $_ -ceq 'f' -or $_ -ceq '-f' -or $_ -ceq 'force' -or $_ -ceq '--force' } {
                $global:LASTEXITCODE = 1
                throw "Refusing unsafe force shorthand. Use 'lease' or 'ff' for --force-with-lease."
            }
            { $_ -ceq 'tags' -or $_ -ceq '--tags' } {
                $pushFlags += '--tags'; break
            }
            { $_ -ceq 'u' -or $_ -ceq 'upstream' -or $_ -ceq 'track' } {
                $pushFlags += '-u'; break
            }
            { $_ -ceq 'dry' -or $_ -ceq 'dry-run' -or $_ -ceq '--dry-run' } {
                $pushFlags += '--dry-run'; break
            }
            default { $gitArguments += [string]$argument }
        }
    }
    Invoke-MJExternal -Command 'git' -ArgumentList (@('push') + $pushFlags + $gitArguments)
}

function global:Invoke-MJSyncBranch {
    param([string]$Branch)
    Invoke-MJExternal -Command 'git' -ArgumentList @('fetch', 'origin', $Branch)
    if ($global:LASTEXITCODE -ne 0) { return }
    Invoke-MJExternal -Command 'git' -ArgumentList @('checkout', $Branch)
    if ($global:LASTEXITCODE -ne 0) { return }
    Invoke-MJExternal -Command 'git' -ArgumentList @('pull', '--ff-only', 'origin', $Branch)
}
function global:syncmain { Invoke-MJSyncBranch -Branch 'main' }
function global:syncdevelop { Invoke-MJSyncBranch -Branch 'develop' }

function global:clone {
    if ($args.Count -lt 1 -or $args.Count -gt 2) {
        throw 'Usage: clone <repository-url> [new-directory]'
    }
    $repository = [string]$args[0]
    if ([string]::IsNullOrWhiteSpace($repository) -or $repository.StartsWith('-')) {
        throw 'Provide a repository URL or path that does not begin with a dash.'
    }
    if ($PWD.Provider.Name -ne 'FileSystem') {
        throw 'Run clone from a filesystem directory.'
    }
    if ($args.Count -eq 2) {
        $destination = [string]$args[1]
        if ([string]::IsNullOrWhiteSpace($destination)) {
            throw 'The new directory must not be empty.'
        }
    } else {
        $repositoryPath = $null
        $repositoryUri = $null
        if ([Uri]::TryCreate($repository, [UriKind]::Absolute, [ref]$repositoryUri) -and
            $repositoryUri.Scheme -in @('http', 'https', 'ssh', 'git', 'file')) {
            $repositoryPath = $repositoryUri.AbsolutePath.TrimEnd('/')
            $repositoryPath = [Uri]::UnescapeDataString($repositoryPath)
        } elseif ($repository -match '^(?:[^@\s/:]+@)?[^/\s:]+:(.+)$') {
            $repositoryPath = $Matches[1].TrimEnd('/', '\')
        } elseif ($repository -notmatch '://') {
            $repositoryPath = $repository.TrimEnd('/', '\')
        }
        $destination = ''
        if (-not [string]::IsNullOrWhiteSpace($repositoryPath)) {
            $destination = ($repositoryPath -split '[/\\]')[-1] -replace '(?i)\.git$', ''
        }
        if ([string]::IsNullOrWhiteSpace($destination) -or $destination -in @('.', '..') -or
            $destination -match '[<>:"/\\|?*\x00-\x1f]' -or $destination -match '[. ]$') {
            throw 'Could not infer a safe directory name. Use clone <repository-url> <new-directory>.'
        }
    }
    $destinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($destination)
    Invoke-MJExternal -Command 'git' -ArgumentList @('clone', '--', $repository, $destination)
    if ($global:LASTEXITCODE -ne 0) { return }
    Set-Location -LiteralPath $destinationPath -ErrorAction Stop
}

# These intentionally stage ALL repository changes before making a commit,
# matching the zsh helpers. gtest creates a [test] commit; it does not run tests.
function global:Invoke-MJTaggedCommit {
    param([string]$Prefix, [string[]]$MessageParts, [switch]$AllowEmpty)
    Invoke-MJExternal -Command 'git' -ArgumentList @('add', '-A')
    if ($global:LASTEXITCODE -ne 0) { return }
    [string[]]$commitArguments = @('commit')
    if ($AllowEmpty) { $commitArguments += '--allow-empty' }
    $message = $Prefix + ' ' + ($MessageParts -join ' ')
    $commitArguments += @('-m', $message)
    Invoke-MJExternal -Command 'git' -ArgumentList $commitArguments
}
function global:gai { Invoke-MJTaggedCommit -Prefix '[AI:accepted]' -MessageParts @($args) }
function global:gaip { Invoke-MJTaggedCommit -Prefix '[AI:partial]' -MessageParts @($args) }
function global:gair { Invoke-MJTaggedCommit -Prefix '[AI:rejected]' -MessageParts @($args) }
function global:gman { Invoke-MJTaggedCommit -Prefix '[manual]' -MessageParts @($args) }
function global:gtest { Invoke-MJTaggedCommit -Prefix '[test]' -MessageParts @($args) -AllowEmpty }

function global:Get-MJUsablePythonExecutable {
    param([string]$Name)
    # Examine all candidates so a Windows Store execution alias cannot hide a
    # real Python later on PATH. Do not launch Store stubs to test them.
    $candidates = @(Get-Command -Name $Name -CommandType Application -All -ErrorAction SilentlyContinue)
    foreach ($candidate in $candidates) {
        $candidatePath = $candidate.Path
        if ([string]::IsNullOrWhiteSpace($candidatePath)) { continue }
        if ($candidatePath -match '(?i)[\\/]Microsoft[\\/]WindowsApps[\\/]') { continue }
        return $candidatePath
    }
    return $null
}

function global:Get-MJPythonInvocation {
    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    if (-not [string]::IsNullOrWhiteSpace($env:VIRTUAL_ENV)) {
        if ($isWindowsHost) {
            $virtualPython = Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'
        } else {
            $virtualPython = Join-Path $env:VIRTUAL_ENV 'bin/python'
        }
        if (Test-Path -LiteralPath $virtualPython -PathType Leaf) {
            return [pscustomobject]@{ Command = $virtualPython; Prefix = @() }
        }
    }
    if ($isWindowsHost) {
        $pythonLauncher = Get-MJUsablePythonExecutable -Name 'py'
        if ($pythonLauncher) {
            return [pscustomobject]@{ Command = $pythonLauncher; Prefix = @('-3') }
        }
    }
    foreach ($pythonName in @('python3', 'python')) {
        $pythonExecutable = Get-MJUsablePythonExecutable -Name $pythonName
        if ($pythonExecutable) {
            return [pscustomobject]@{ Command = $pythonExecutable; Prefix = @() }
        }
    }
    throw 'Python was not found. Install or request an approved Python 3 runtime; Windows Store execution aliases are skipped.'
}

function global:Invoke-MJPython {
    param([string[]]$ArgumentList = @())
    $pythonInvocation = Get-MJPythonInvocation
    Invoke-MJExternal -Command $pythonInvocation.Command -ArgumentList (@($pythonInvocation.Prefix) + $ArgumentList)
}
function global:python { Invoke-MJPython -ArgumentList @($args) }
function global:pip { Invoke-MJPython -ArgumentList (@('-m', 'pip') + @($args)) }
function global:notebook { Invoke-MJPython -ArgumentList (@('-m', 'notebook') + @($args)) }

function global:activate {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$Path = '.venv')
    $directory = Get-Item -LiteralPath $Path -ErrorAction Stop
    if (-not ($directory -is [System.IO.DirectoryInfo])) {
        throw "Virtual environment path must be a filesystem directory: $Path"
    }
    $environmentPath = $directory.FullName
    $configPath = Join-Path $environmentPath 'pyvenv.cfg'
    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    if ($isWindowsHost) {
        $scriptsPath = Join-Path $environmentPath 'Scripts'
        $pythonPath = Join-Path $scriptsPath 'python.exe'
    } else {
        $scriptsPath = Join-Path $environmentPath 'bin'
        $pythonPath = Join-Path $scriptsPath 'python'
    }
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
        throw "This is not a usable Python virtual environment for this OS: $environmentPath"
    }
    # Validate the new target before touching any previous activation.
    $existingState = Get-Variable -Name MJVirtualEnvironmentState -Scope Global -ErrorAction SilentlyContinue
    if ($existingState -and $null -ne $existingState.Value) { deactivate }
    $global:MJVirtualEnvironmentState = @{
        Path = $env:PATH
        VirtualEnv = [Environment]::GetEnvironmentVariable('VIRTUAL_ENV', 'Process')
        VirtualEnvPrompt = [Environment]::GetEnvironmentVariable('VIRTUAL_ENV_PROMPT', 'Process')
        PythonHome = [Environment]::GetEnvironmentVariable('PYTHONHOME', 'Process')
    }
    $env:VIRTUAL_ENV = $environmentPath
    $env:VIRTUAL_ENV_PROMPT = $directory.Name
    $env:PATH = $scriptsPath + [IO.Path]::PathSeparator + $env:PATH
    Remove-Item -LiteralPath Env:PYTHONHOME -ErrorAction SilentlyContinue
    Write-Host ("Activated {0}. Run deactivate to restore this shell's environment." -f $environmentPath)
}

function global:deactivate {
    $stateVariable = Get-Variable -Name MJVirtualEnvironmentState -Scope Global -ErrorAction SilentlyContinue
    if (-not $stateVariable -or $null -eq $stateVariable.Value) {
        Write-Host 'No virtual environment activated by this profile is currently tracked.'
        return
    }
    $state = $stateVariable.Value
    $savedVariables = @{
        PATH = $state.Path
        VIRTUAL_ENV = $state.VirtualEnv
        VIRTUAL_ENV_PROMPT = $state.VirtualEnvPrompt
        PYTHONHOME = $state.PythonHome
    }
    foreach ($variableName in $savedVariables.Keys) {
        $variablePath = 'Env:' + $variableName
        if ($null -eq $savedVariables[$variableName]) {
            Remove-Item -LiteralPath $variablePath -ErrorAction SilentlyContinue
        } else {
            Set-Item -LiteralPath $variablePath -Value ([string]$savedVariables[$variableName])
        }
    }
    $global:MJVirtualEnvironmentState = $null
}

function global:venv {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$Path = '.venv')
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Provide a virtual environment directory.' }
    # Absolute paths cannot be mistaken for uv/Python command options.
    $targetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (Test-Path -LiteralPath (Join-Path $targetPath 'pyvenv.cfg') -PathType Leaf) {
        activate -Path $targetPath
        return
    }
    if (Test-Path -LiteralPath $targetPath) {
        $targetItem = Get-Item -LiteralPath $targetPath -ErrorAction Stop
        if (-not ($targetItem -is [IO.DirectoryInfo]) -or
            @(Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction Stop).Count -gt 0) {
            throw "Refusing to overwrite a nonempty path that is not a virtual environment: $targetPath"
        }
    }
    $uvExecutable = Get-MJExecutable -Name 'uv'
    if ($uvExecutable) {
        # Prevent uv from downloading an interpreter as a side effect.
        Invoke-MJExternal -Command $uvExecutable -ArgumentList @('venv', '--no-python-downloads', $targetPath)
    } else {
        Invoke-MJPython -ArgumentList @('-m', 'venv', $targetPath)
    }
    if ($global:LASTEXITCODE -ne 0) { return }
    activate -Path $targetPath
}

function global:edit {
    [string[]]$fileArguments = @($args)
    if ($fileArguments.Count -eq 0) { $fileArguments = @('.') }
    $configVariable = Get-Variable -Name MJConfig -Scope Global -ErrorAction SilentlyContinue
    $configuredEditor = $null
    if ($configVariable -and $null -ne $configVariable.Value) {
        $configuredEditor = [string]$configVariable.Value.Editor
    }
    if (-not [string]::IsNullOrWhiteSpace($configuredEditor)) {
        $editorExecutable = Get-MJExecutable -Name $configuredEditor
        if (-not $editorExecutable) {
            throw "The configured editor '$configuredEditor' was not found. Set MJConfig.Editor to one executable name or path, without arguments, or leave it empty for automatic selection."
        }
        Invoke-MJExternal -Command $editorExecutable -ArgumentList $fileArguments
        return
    }
    foreach ($editorName in @('code', 'code-insiders', 'notepad.exe', 'nano', 'vi')) {
        $editorExecutable = Get-MJExecutable -Name $editorName
        if ($editorExecutable) {
            Invoke-MJExternal -Command $editorExecutable -ArgumentList $fileArguments
            return
        }
    }
    throw 'No supported editor command is on PATH. Open the file with your approved editor, or add its command to PATH.'
}

function global:Get-MJProfileFile {
    $profileVariable = Get-Variable -Name MJProfilePath -Scope Global -ErrorAction SilentlyContinue
    if (-not $profileVariable -or [string]::IsNullOrWhiteSpace([string]$profileVariable.Value)) {
        throw 'MJProfilePath is not set. Load the complete standalone profile first.'
    }
    return [string]$profileVariable.Value
}
function global:Get-MJUserProfileFile {
    $userProfilePath = [string]$PROFILE.CurrentUserAllHosts
    if ([string]::IsNullOrWhiteSpace($userProfilePath)) {
        throw 'This host did not provide a CurrentUserAllHosts profile path.'
    }
    return $userProfilePath
}
function global:Test-MJProfileSyntax {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "The profile file does not exist: $Path"
    }
    $parseTokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        $global:LASTEXITCODE = 1
        $messages = @($parseErrors | ForEach-Object {
            'Line {0}, column {1}: {2}' -f $_.Extent.StartLineNumber, $_.Extent.StartColumnNumber, $_.Message
        })
        throw ("Profile syntax errors in {0}:`n{1}" -f $Path, ($messages -join "`n"))
    }
    $global:LASTEXITCODE = 0
    Write-Host ("Profile syntax OK: {0}" -f $Path)
}
function global:pedit { edit (Get-MJProfileFile) }
function global:zedit { pedit }
function global:zcat { Get-Content -LiteralPath (Get-MJProfileFile) -ErrorAction Stop }
function global:zcheck { Test-MJProfileSyntax -Path (Get-MJProfileFile) }
function global:zpedit { edit (Get-MJUserProfileFile) }
function global:zpcat { Get-Content -LiteralPath (Get-MJUserProfileFile) -ErrorAction Stop }
function global:zpcheck { Test-MJProfileSyntax -Path (Get-MJUserProfileFile) }
function global:reload-profile {
    $profileFile = Get-MJProfileFile
    if (-not (Test-Path -LiteralPath $profileFile -PathType Leaf)) {
        throw "The profile file no longer exists: $profileFile"
    }
    . $profileFile
}
function global:revupzsh { reload-profile }
function global:restart {
    # PowerShell cannot exec-replace its host. Reload in the current shell so
    # Windows Terminal, VS Code, remoting, and existing jobs remain intact.
    Clear-Host
    reload-profile
}

# Keep the native `code` command untouched. Create optional JetBrains shortcuts
# only when the corresponding external launcher already exists.
if (Get-MJExecutable -Name 'webstorm') {
    function global:storm { Invoke-MJExternal -Command 'webstorm' -ArgumentList @($args) }
    function global:ws { Invoke-MJExternal -Command 'webstorm' -ArgumentList @($args) }
} elseif (Get-MJExecutable -Name 'webstorm64.exe') {
    function global:storm { Invoke-MJExternal -Command 'webstorm64.exe' -ArgumentList @($args) }
    function global:ws { Invoke-MJExternal -Command 'webstorm64.exe' -ArgumentList @($args) }
}
if (Get-MJExecutable -Name 'pycharm') {
    function global:charm { Invoke-MJExternal -Command 'pycharm' -ArgumentList @($args) }
} elseif (Get-MJExecutable -Name 'pycharm64.exe') {
    function global:charm { Invoke-MJExternal -Command 'pycharm64.exe' -ArgumentList @($args) }
}

function global:mj-devhelp {
    @'
Git: branch log checkout add status commit amend pull merge ignored stash
     rebase fetch origin restore diff diff-staged diff-files log-pretty log-graph
GitHub CLI: pr [number] opens a PR in the browser; prs shows PR status.
push [dry] [u] [tags] [lease|ff] [nv] [remote] [refspec]
  Flags stack. nv explicitly skips hooks; it is NEVER added automatically.
  f, -f, force, and --force are refused; use lease/ff when intended.
syncmain / syncdevelop: fetch, checkout, then fast-forward-only pull; stop on error.
clone <repository-url> [new-directory]: clone, then enter the directory on success.
  The directory can be inferred for common HTTPS, SSH, and scp-style Git URLs.
gai / gaip / gair / gman: STAGE ALL changes and commit with the matching label.
gtest: STAGE ALL and make a [test] commit (allows empty); it DOES NOT RUN TESTS.
  Pass commit messages after the helper, for example: gman "Fix parser".
python / pip / notebook: use the active venv, then Windows py -3, then python3/python.
  pip is Python's pip module, so it follows the selected interpreter.
venv [path]: create and activate .venv (or path); reuse an existing environment.
  Prefer installed uv without interpreter downloads; otherwise use Python's venv.
activate [path] / deactivate: switch this process's environment, then restore it.
edit <file>: use an installed code/code-insiders/notepad/nano/vi command.
  MJConfig.Editor can select a single executable name/path, without arguments.
pedit / zedit: edit THIS PowerShell profile. zcat: print it.
zcheck: parse this managed profile without running it.
zpedit / zpcat / zpcheck: edit, print, or parse CurrentUserAllHosts bootstrap profile.
reload-profile / revupzsh: reload this profile. restart: clear screen and reload.
  restart does not create or replace a process; existing functions/jobs remain.
code stays native. storm/ws and charm exist only when a matching launcher is found.
'@
}



# Optional user-maintained settings. Nothing is loaded from project folders.
$mjLocalPath = Join-Path (Split-Path $global:MJProfilePath -Parent) 'MJ.Local.ps1'
if ((Test-Path -LiteralPath $mjLocalPath) -and $mjLocalPath -ne $global:MJProfilePath) {
    try { . $mjLocalPath } catch { Write-Warning "MJ.Local.ps1 could not load: $_" }
}

if ($Host.Name -eq 'ConsoleHost') {
    try {
        if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
            if (-not (Get-Module PSReadLine)) { Import-Module PSReadLine -ErrorAction Stop }
            Set-MJKeys $global:MJConfig.EditMode
            Set-PSReadLineOption -HistoryNoDuplicates -MaximumHistoryCount 50000 -BellStyle None -ErrorAction Stop
            $mjReadLineOptions = (Get-Command Set-PSReadLineOption).Parameters
            if (-not $global:MJConfig.Predictions -and $mjReadLineOptions.ContainsKey('PredictionSource')) {
                Set-PSReadLineOption -PredictionSource None -ErrorAction Stop
            }
            if ($global:MJConfig.Predictions -and $Host.UI.SupportsVirtualTerminal -and $mjReadLineOptions.ContainsKey('PredictionSource')) {
                try {
                    Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
                    if ($mjReadLineOptions.ContainsKey('PredictionViewStyle')) {
                        Set-PSReadLineOption -PredictionViewStyle InlineView -ErrorAction Stop
                    }
                } catch { Write-Verbose 'History predictions are unavailable in this console.' }
            }
            if ($global:MJConfig.ShowGreeting -and -not $env:NO_MEOW -and -not $global:MJGreetingShown) {
                Write-Host ' /\_/\   shell restored. chaos contained.  (mj-help)' -ForegroundColor Magenta
                $global:MJGreetingShown = $true
            }
        }
    } catch { Write-Verbose "Interactive key setup skipped: $_" }
}
Remove-Variable mjDefaults,mjKey,mjLocalPath,mjReadLineOptions -ErrorAction SilentlyContinue
