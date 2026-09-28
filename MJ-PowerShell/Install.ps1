# Install only into the current user's PowerShell profile directory.
# Run this in the Windows shell you want to configure. No elevation required.
[CmdletBinding()]
param(
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$mjBegin = '# >>> MJ POWERSHELL ENV >>>'
$mjEnd = '# <<< MJ POWERSHELL ENV <<<'
$mjPattern = '(?ms)^' + [regex]::Escape($mjBegin) + '\r?\n.*?^' + [regex]::Escape($mjEnd) + '\r?\n?'
$mjParent = Split-Path $ProfilePath -Parent
if (-not $mjParent) { throw 'ProfilePath must include its parent directory.' }
$mjTargetDir = Join-Path $mjParent 'MJ'
$mjSource = Join-Path $PSScriptRoot 'MJ.Profile.ps1'
$mjContent = ''
if (Test-Path -LiteralPath $ProfilePath) { $mjContent = [string](Get-Content -LiteralPath $ProfilePath -Raw) }
$mjMatches = [regex]::Matches($mjContent, $mjPattern)
if (($mjContent.Contains($mjBegin) -or $mjContent.Contains($mjEnd)) -and $mjMatches.Count -ne 1) {
    throw 'The existing MJ profile block is incomplete or duplicated. Resolve it before installation.'
}
if ($Uninstall -and $mjMatches.Count -eq 0) { Write-Host 'No MJ loader block found. Nothing changed.'; return }
if (-not $Uninstall -and -not (Test-Path -LiteralPath $mjSource)) { throw "Missing bundle file: $mjSource" }

# Parse before touching any profile.
if (-not $Uninstall) {
    $mjTokens = $null; $mjErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($mjSource, [ref]$mjTokens, [ref]$mjErrors)
    if ($mjErrors.Count) { throw "The profile did not parse in this PowerShell version: $($mjErrors[0])" }
}
New-Item -ItemType Directory -Path $mjParent -Force | Out-Null
$mjBackup = Join-Path $mjParent ('MJ-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,6)))
New-Item -ItemType Directory -Path $mjBackup | Out-Null
if (Test-Path -LiteralPath $ProfilePath) { Copy-Item -LiteralPath $ProfilePath -Destination (Join-Path $mjBackup 'original-profile.ps1') }
if (Test-Path -LiteralPath $mjTargetDir) { Copy-Item -LiteralPath $mjTargetDir -Destination (Join-Path $mjBackup 'MJ') -Recurse }

if ($Uninstall) {
    $mjUpdated = [regex]::Replace($mjContent, $mjPattern, '')
} else {
    New-Item -ItemType Directory -Path $mjTargetDir -Force | Out-Null
    Copy-Item -LiteralPath $mjSource -Destination (Join-Path $mjTargetDir 'MJ.Profile.ps1') -Force
    $mjExample = Join-Path $PSScriptRoot 'MJ.Local.example.ps1'
    $mjLocalTarget = Join-Path $mjTargetDir 'MJ.Local.ps1'
    if (-not (Test-Path -LiteralPath $mjLocalTarget) -and (Test-Path -LiteralPath $mjExample)) {
        Copy-Item -LiteralPath $mjExample -Destination $mjLocalTarget
    }
    $mjBlock = @'
# >>> MJ POWERSHELL ENV >>>
. (Join-Path $PSScriptRoot 'MJ/MJ.Profile.ps1')
# <<< MJ POWERSHELL ENV <<<
'@
    $mjBlock += [Environment]::NewLine
    if ($mjMatches.Count) {
        # MatchEvaluator avoids interpreting dollar signs in the replacement.
        $mjUpdated = [regex]::Replace($mjContent, $mjPattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $mjBlock })
    } else {
        $mjSeparator = ''; if ($mjContent.Length -and -not $mjContent.EndsWith("`n")) { $mjSeparator = [Environment]::NewLine }
        $mjUpdated = $mjContent + $mjSeparator + $mjBlock
    }
}
$mjTemp = $ProfilePath + '.mj-tmp-' + [guid]::NewGuid().ToString('N')
try {
    [IO.File]::WriteAllText($mjTemp, $mjUpdated, (New-Object Text.UTF8Encoding($true)))
    Move-Item -LiteralPath $mjTemp -Destination $ProfilePath -Force
} finally {
    if (Test-Path -LiteralPath $mjTemp) { Remove-Item -LiteralPath $mjTemp -Force }
}
Write-Host "Original files backed up to: $mjBackup"
if ($Uninstall) {
    Write-Host 'MJ startup loader removed. Restart PowerShell to clear loaded functions. Your MJ files remain available.'
} else {
    Write-Host "Installed for this PowerShell edition: $ProfilePath"
    Write-Host 'Close and reopen PowerShell, then run mj-help and mj-doctor.'
    Write-Host 'If your organization blocks profile scripts, use its approved support process. This installer does not change policy.'
}
