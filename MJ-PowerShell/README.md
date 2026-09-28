# MJ's PowerShell environment

A familiar shell for your Windows work desktop: Bash/zsh editing keys, Unix-style helpers, your existing Git shortcuts, Python environments, editor shortcuts, a small colored prompt, and a profile backup command.

The base profile needs no WSL, administrator rights, custom font, or third-party module. Git, Python, GitHub CLI and editors are used when installed. Missing tools produce a useful error instead of being downloaded automatically. This is a new reconstruction based on your current zsh configuration, not a recovered previous work profile.

## Install in the Windows VM

1. Clone this repository using the [root install guide](../README.md), then enter the **MJ-PowerShell** folder. An extracted copy of this folder also works.
2. Open **PowerShell** in that folder. Windows PowerShell 5.1 and PowerShell 7 have separate startup profiles; run the installer in each edition you actually use.
3. Run:

```powershell
.\Install.ps1
```

4. Close and reopen PowerShell. Run `mj-help`, then `mj-doctor`.

The installer copies `MJ.Profile.ps1` into the current shell's user profile directory and adds one loader block to `$PROFILE.CurrentUserAllHosts`. It backs up existing files before changing them. Reinstalling replaces the managed profile, keeps your `MJ.Local.ps1`, and does not duplicate the loader. Your other profile commands remain in place. Host-specific profiles load later and can override these settings.

If your organization blocks profile scripts, request its approved profile/script setup. This bundle does not change execution policy, remove download security markings, or request elevation. It has not been run inside your work VM.

### Copy-and-paste route

If getting a ZIP into the VM is awkward, the entire environment is also in the one readable file **MJ.Profile.ps1**. Copy its contents into a new `MJ.Profile.ps1` file using an editor inside the VM. Open PowerShell in that file's folder and load it for the current session:

```powershell
. .\MJ.Profile.ps1
```

To make that file load at startup, back up your existing user profile and append a loader using its actual path. Replace the example path below with the file you saved:

```powershell
$mjFile = (Resolve-Path -LiteralPath 'C:\path\to\MJ.Profile.ps1').Path
$mjStartup = $PROFILE.CurrentUserAllHosts
New-Item -ItemType Directory -Path (Split-Path $mjStartup -Parent) -Force | Out-Null
$mjExisting = ''
if (Test-Path -LiteralPath $mjStartup) {
    Copy-Item -LiteralPath $mjStartup -Destination ($mjStartup + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $mjExisting = [string](Get-Content -LiteralPath $mjStartup -Raw)
}
$mjLoader = ". '" + $mjFile.Replace("'", "''") + "'"
if (-not (($mjExisting -split '\r?\n') -contains $mjLoader)) {
    Set-Content -LiteralPath $mjStartup -Value ($mjExisting + "`r`n" + $mjLoader) -Encoding UTF8
}
```

Run that startup step once, then reopen PowerShell. The bundled installer/uninstaller manages its own marked loader; if you use this manual route, remove the manual loader line yourself to uninstall. Do not replace an existing profile with the whole file without keeping a backup.

## Your daily commands

| Habit | Command |
|---|---|
| List / include hidden files | `ls`, `ls -la`, `ll`, `la` |
| Home / previous folder / parent | `cd`, `cd -`, `..`, `...`, `up 3` |
| Make a folder and enter it | `mkcd "new project"` |
| Create nested folders / an empty file | `mkdir -p "new project/src"`, `touch notes.txt` |
| Find an executable or command | `which git` |
| Find lines / show file edges | `grep -in error app.log`, `head -n 20 app.log`, `tail -n 20 app.log` |
| Follow a log | `tail -f app.log` |
| Open in associated app | `open .`, `open report.pdf` |
| Copy / read the clipboard | `pwd \| pbcopy`, `pbpaste` |
| Enter repository root / saved project | `croot`, `cproj api` |
| Edit / reload your profile | `pedit`, `zedit`, `reload-profile`, `revupzsh` |
| Check what's installed | `mj-doctor` |
| Save this setup | `backup-profile 'C:\approved-backup-folder'` |

`mj-unixhelp` is the authoritative list of supported Unix flags. These are practical helpers, not complete GNU replacements. File-listing and lookup commands retain useful PowerShell objects, so you can still pipe them to `Where-Object` or `Select-Object`. `ls -l`/`-h` are accepted compatibility flags; they do not reproduce GNU's permission columns or human-size layout.

## Your Git vocabulary

`branch`, `log`, `checkout`, `add`, `status`, `commit`, `amend`, `pull`, `merge`, `ignored`, `stash`, `rebase`, `fetch`, `origin`, `restore`, `diff`, `diff-staged`, `diff-files`, `log-pretty`, `log-graph`, `pr`, `prs`.

`clone repo-url [new-folder]` clones a repository and enters its folder after a successful clone.

These forward arguments to Git or GitHub CLI. For example, `commit -m "Fix parser"` and `checkout -b feature/example` work. `diff` means **git diff** here; use `Compare-Object` for PowerShell's comparison command. Git's own repository state, hooks, authentication and configuration still apply.

Your stackable push vocabulary is preserved:

```powershell
push dry origin HEAD
push u origin HEAD
push lease origin HEAD
```

`dry` means dry run, `u` sets upstream, `lease`/`ff` means force-with-lease, and `tags` pushes tags. `nv` skips hooks only when explicitly supplied. Plain force shorthand is refused, matching your current zsh setup. These commands perform real Git operations when you run them; profile startup performs none.

`syncmain` / `syncdevelop` fetch the named remote branch, check it out, and pull with `--ff-only`, stopping on an error.

Your `gai`, `gaip`, `gair`, `gman` and `gtest` helpers **stage all repository changes and create a labeled commit**. `gtest` creates a `[test]` commit; it does not execute a test suite. Use `commit` for an ordinary commit of only what you staged yourself.

## Python and editors

`python` chooses the active environment first, then a Windows Python 3 launcher, then an installed Python executable. `pip` runs that same interpreter's pip module. `notebook` runs its notebook module.

`venv` creates `.venv` and activates it; `venv other-folder` chooses another path. It uses installed `uv` without downloading an interpreter, or Python's own `venv`. Existing valid environments are reused. `activate` / `deactivate` change and restore the current process environment. Activating does not execute code from the environment's activation script.

`edit file` chooses your configured editor, then installed VS Code, Notepad or a terminal editor. Native `code`, `npm`, `pnpm`, `kubectl`, `terraform` and other tools continue to work when installed. `storm`/`ws` and `charm` appear when a corresponding JetBrains launcher is on PATH.

`zcheck` parses your main profile without executing it. `zpedit`, `zpcat` and `zpcheck` edit, display and syntax-check the startup profile.

`restart` clears the screen and reloads the profile in the current process. To start a fresh shell, close and reopen the terminal.

## Keys and appearance

| Key | Action |
|---|---|
| Tab / Shift+Tab | Completion menu / previous completion |
| Ctrl+R | Search history |
| Up / Down | Search history matching what you typed |
| Ctrl+A / Ctrl+E | Beginning / end of line |
| Alt+B / Alt+F | Back / forward a word |
| Ctrl+W / Ctrl+K | Cut previous word / cut to end |
| Ctrl+Y | Paste the text cut with those editing keys |
| Ctrl+L | Clear screen |

Use your terminal's Paste command for the system clipboard; Ctrl+Y is the editor's cut buffer. Citrix or macOS may intercept some key combinations before they reach Windows. The terminal still determines which physical keys it receives.

`mj-keys Windows` changes editing style for the session; `mj-keys Emacs` returns to Bash-like keys. `mj-keys Vi` uses PSReadLine's Vi defaults.

The prompt shows the current folder, Git branch (or detached commit), active Python environment, and a failed-command indicator. It uses standard terminal colors and ASCII characters. Set `NO_COLOR` to disable colors and `NO_MEOW` to suppress the small startup greeting. History predictions appear only when the installed PSReadLine and terminal support them. No history is sent anywhere by this profile.

## Personal settings and backups

The installer creates **MJ.Local.ps1** beside the managed profile. Edit it to set your preferred editor, greeting, keys, prompt name and named project folders. For the manual route, copy `MJ.Local.example.ps1` beside your saved profile and rename it to `MJ.Local.ps1`.

```powershell
$global:MJConfig.Editor = 'code'
$global:MJConfig.Projects['api'] = 'C:\work\api'
$global:MJConfig.ShowGreeting = $false
```

Keep custom settings here so reinstalling the main profile does not erase them. Define custom functions with `function global:name { ... }` so they survive `reload-profile`.

`backup-profile` creates a dated backup directory beside the profile by default. Give it an approved backed-up folder to keep a copy outside VM-local storage. It includes the profile and local settings, not installed applications or command history. Keep secrets out of profile/config files; the backup copies those files as written.

To uninstall the installer-managed startup hook, run this from the original bundle folder:

```powershell
.\Install.ps1 -Uninstall
```

Then reopen PowerShell. Existing settings are retained, and the managed files/backups remain available for recovery.

## Syntax worth remembering

- PowerShell cmdlet names and parameters are case-insensitive.
- This does not change PowerShell into Bash. Use `$env:NAME = 'value'` for environment variables and `. .\file.ps1` to dot-source a PowerShell script. Bash/zsh scripts are not valid PowerShell profiles.
- `rm`, `cp` and `mv` keep their ordinary PowerShell semantics. Use `Remove-Item`, `Copy-Item` and `Move-Item` explicitly in scripts. GNU options such as `rm -rf` are not supplied by this profile.
- PowerShell 5.1 does not support Bash's `&&`/`||` syntax. The supplied compound helpers stop on failure explicitly.
- Aliases are for interactive convenience. Prefer explicit commands in team scripts.
- The profile does not migrate personal credentials, Git identity, package-registry authentication, or macOS-only application paths.

## Validation

See **VALIDATION.md** for the checks actually run and platform limitations.

## References

- [PowerShell profiles](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)
- [PowerShell aliases and functions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_aliases)
- [PSReadLine editing and history options](https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption)
- [PSReadLine keyboard functions](https://learn.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline_functions)
