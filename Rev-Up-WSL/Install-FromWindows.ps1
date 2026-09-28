# Run from an extracted bundle inside the Windows VDI, not from inside the ZIP.
# Uses an existing WSL distribution. No elevation or policy changes.
[CmdletBinding()]
param(
    [string]$Distribution,
    [switch]$InstallPackages,
    [switch]$WithNode,
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$NoAutoZsh,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
if ($WithNode -and -not $InstallPackages) { throw '-WithNode requires -InstallPackages.' }
if ($Yes -and -not $InstallPackages) { throw '-Yes requires -InstallPackages.' }
if ($Uninstall -and ($InstallPackages -or $WithNode -or $Yes -or $NoAutoZsh)) {
    throw '-Uninstall cannot be combined with installation options.'
}
$mjWslCommand = Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $mjWslCommand) { throw 'wsl.exe was not found. Run this in Windows PowerShell inside your VDI.' }
$mjWsl = $mjWslCommand.Path
$mjTarget = @()
if ($Distribution) { $mjTarget = @('--distribution', $Distribution) }
$mjConverted = @(& $mjWsl @mjTarget --exec wslpath -a -u $PSScriptRoot)
if ($LASTEXITCODE -ne 0) {
    throw 'Could not open the existing WSL distribution or translate the bundle path. Check wsl --list --verbose and finish the Linux first-run setup.'
}
$mjLines = @($mjConverted | ForEach-Object { ([string]$_).TrimEnd("`r") } | Where-Object { $_.Length -gt 0 })
if ($mjLines.Count -ne 1 -or -not $mjLines[0].StartsWith('/')) { throw 'WSL returned an unexpected bundle path.' }
$mjInstaller = $mjLines[0].TrimEnd('/') + '/install.sh'
$mjArguments = @('--exec', 'bash', '--', $mjInstaller)
if ($InstallPackages) { $mjArguments += '--packages' }
if ($WithNode) { $mjArguments += '--with-node' }
if ($Yes) { $mjArguments += '--yes' }
if ($DryRun) { $mjArguments += '--dry-run' }
if ($NoAutoZsh) { $mjArguments += '--no-auto-zsh' }
if ($Uninstall) { $mjArguments += '--uninstall' }
& $mjWsl @mjTarget @mjArguments
if ($LASTEXITCODE -ne 0) { throw "WSL installer stopped with exit code $LASTEXITCODE. Read its message above; no alternate distribution was installed." }
if (-not $DryRun -and -not $Uninstall) {
    Write-Host 'Rev up that WSL... I am HUNGRY!'
    Write-Host 'Reopen your Ubuntu/Debian terminal, then run mj-help and mj-doctor.'
}
