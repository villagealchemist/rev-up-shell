# Rev up that shell... I'm HUNGRY!

A home for MJ's WSL and PowerShell setup, so this shell configuration survives the next machine change.

- **[Rev-Up-WSL](Rev-Up-WSL/START-HERE.md):** native zsh for an existing Ubuntu/Debian WSL distribution, Bash/zsh keys, Git shortcuts, Python environments, completion, history search, prompt, and Windows integration helpers.
- **[MJ-PowerShell](MJ-PowerShell/README.md):** the matching Windows shell profile with familiar navigation, Unix-style helpers, Git/Python/editor shortcuts, and PSReadLine keys.

## Start from Windows PowerShell inside the VDI

Git must already be installed. Open your Ubuntu/Debian distribution once first and finish its Linux account setup. This repository is private; authenticate as the GitHub account with access using your permitted Git credential method when cloning. Keep credentials out of commands and files.

Run these commands in a folder where you want to keep the repository:

```powershell
git clone https://github.com/villagealchemist/rev-up-shell.git
if ($LASTEXITCODE -ne 0) { throw 'Git clone failed. Resolve the access or destination error before continuing.' }
Set-Location .\rev-up-shell
.\Rev-Up-WSL\Install-FromWindows.ps1 -InstallPackages
```

The WSL installer uses your existing default distribution. Add `-Distribution Ubuntu-24.04` (using your exact name from `wsl --list --verbose`) if you need another installed distro. Package installation may ask for your Linux sudo password. It leaves normal apt confirmation enabled.

Reopen Ubuntu/Debian afterward, then run `mj-help` and `mj-doctor`.

To install the PowerShell environment as well, run `.\MJ-PowerShell\Install.ps1` from the repository root in the Windows PowerShell edition you use, then reopen that shell.

## Start directly inside Ubuntu/Debian instead

If Git is missing, install it using your permitted distro package workflow first. With Git and access to this private repository already configured:

```bash
mkdir -p ~/src && cd ~/src &&
git clone https://github.com/villagealchemist/rev-up-shell.git &&
cd rev-up-shell/Rev-Up-WSL &&
bash install.sh --packages &&
exec zsh -l
```

Use one installation route. The WSL package step uses your existing Ubuntu/Debian repositories. Add `--with-node` for the distro's Node/npm packages. Omit `--packages` for configuration only when zsh and Python 3 are already installed.

## What installation changes

The installers preserve existing startup content, add a managed loader, and save backups. Reinstalling updates the managed files while retaining personal settings. WSL configuration goes under `~/.config/mj-wsl`; PowerShell configuration goes under the current edition's user profile directory. Installation does not change global Git identity or Windows execution policy.

This is a source configuration repository. Software packages are downloaded from the existing distro repositories when requested. Corporate projects, credentials, command history, and machine backups do not belong here. The Git ignore rules exclude common local settings and backup files; review changes before committing anything new.

## Update or remove

From the repository root, use `git pull --ff-only`, review the changes, then rerun the installer you used. A Git pull alone does not update files already installed into your shell profile. Existing local settings are retained.

For uninstall commands, optional flags, troubleshooting, and the full shortcut lists, use the two guides linked above. Platform validation and remaining limitations are recorded in [WSL validation](Rev-Up-WSL/VALIDATION.md) and [PowerShell validation](MJ-PowerShell/VALIDATION.md). These files were tested on macOS with isolated fixtures, not inside the work VDI.
