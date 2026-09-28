# Rev up that WSL... I'm HUNGRY!

Your Ubuntu/Debian WSL kitchen: real zsh, your Git vocabulary, Python environments, completion, history search, a colored prompt, and a way to save the whole shell setup before it disappears into the void again.

## Get it onto the VDI

Clone this private repository using the [root install guide](../README.md), then enter the **Rev-Up-WSL** folder. Keep its files together. Git access and script execution follow your workplace policies.

The bundle contains shell/configuration files and a Windows launcher. It contains no personal credentials or old work repositories. The tools themselves come from your distro's configured package repositories during installation.

## Start the kitchen

This package targets **Ubuntu and Debian**. It uses the already-installed distribution and does not create a second WSL instance.

1. Open your Ubuntu/Debian terminal once and finish any first-run Linux username/password setup.
2. In **Windows PowerShell**, run `wsl --list --verbose`. Check the exact distro name. WSL 1 and WSL 2 can run this shell setup; containers and other virtualization features have their own requirements.
3. Open **Windows PowerShell in the Rev-Up-WSL folder of your clone or extracted bundle**, then run:

```powershell
.\Install-FromWindows.ps1 -InstallPackages
```

If you have several distributions, specify the exact name, for example `-Distribution Ubuntu-24.04`. Omitting it uses your existing default distribution.

The package step may ask for your **Linux sudo password** and normal package-manager confirmation. That password belongs to the Linux account you created in Ubuntu/Debian. Windows' disabled `sudo.exe` setting is separate. Type the password in the terminal; Linux normally shows no characters while you type. [Microsoft's WSL account guide](https://learn.microsoft.com/en-us/windows/wsl/setup/environment#set-up-your-linux-username-and-password).

After installation, close and reopen the Ubuntu/Debian terminal. You should see the hungry greeting and your zsh prompt. Run `mj-help` and `mj-doctor`.

### Want Node/npm too?

Add `-WithNode` to the installation command. This installs the versions available from your configured distro repositories. If your team pins a specific Node version, use that project's setup instructions instead. Python, Git and the core shell tools are already in the standard package set.

### Already have the Linux tools?

Run the launcher without `-InstallPackages` for an offline, configuration-only installation. It requires zsh and Python 3 to be present. Add `-DryRun` to preview changes without writing files or installing packages.

### Directly from Ubuntu/Debian

If you prefer the Linux terminal, enter the Rev-Up-WSL folder of your clone or extracted bundle through `/mnt/c/...`, then run `bash install.sh --packages`. Use quotes around paths containing spaces. Afterward, `exec zsh -l` starts your configured shell immediately.

The optional flags are `--with-node`, `--yes` (skip apt's normal confirmation), `--no-auto-zsh`, and `--dry-run`. `--with-node` and `--yes` require `--packages`. The Windows equivalents are `-WithNode`, `-Yes`, `-NoAutoZsh`, and `-DryRun`.

## What's on the menu

The package bootstrap installs missing pieces from existing Ubuntu/Debian repositories:

- zsh, Git, the OpenSSH client, curl, CA certificates, and the compiler/build essentials.
- Python 3, pip and venv support.
- ripgrep, fd-find, fzf, bat, jq, tmux, nano, less, zip and unzip.
- zsh autosuggestions and syntax highlighting when those packages are available.
- Node.js/npm only with the optional Node flag.

There is no Oh My Zsh download step, shell-framework dependency, custom font requirement, external install script piped into a shell, added vendor repository, or full OS upgrade. Optional plugins load from installed distro files. If one is absent, the base shell still works.

Docker, cloud CLIs, GitHub CLI, VS Code and project-specific SDK versions remain separate choices. `mj-doctor` shows what is available. The installer does not change your Git identity, retrieve tokens, change Windows policy, alter VPN settings, or edit `/etc/wsl.conf`.

## The commands your hands expect

| What you want | Type |
|---|---|
| Files, including hidden ones | `ll`, `la`, `ls -lah` |
| Up / up twice / up several | `..`, `...`, `up 3` |
| Previous directory | `cd -` |
| Make a directory and enter it | `mkcd "new project"` |
| Enter your source folder | `csrc` |
| Enter repo root / named project | `croot`, `cproj api` |
| Clone and enter | `clone <your-approved-repo-url>` |
| Python environment | `venv`, then `deactivate` when done |
| Edit a file | `edit file.txt` |
| Edit personal shell settings | `zedit` |
| Reload the shell settings | `revupzsh` or `reload-profile` |
| Open a Linux folder in Windows | `wopen .` |
| Copy text to Windows / paste it back | `pwd \| wclip`, `wpaste` |
| Inspect available tools | `mj-doctor` |
| Back up this configuration | `mj-backup /path/to/approved/backup-folder` |

Native Linux tools provide their normal flags: `grep`, `head`, `tail`, `find`, `sed`, `awk`, `cp`, `mv` and so on. `fd` and `bat` use Ubuntu/Debian's `fdfind` and `batcat` names when needed. Use `mj-help` for the installed shortcut list.

Your existing Git shortcuts are included: `status`, `add`, `commit`, `checkout`, `branch`, `log`, `amend`, `pull`, `merge`, `stash`, `rebase`, `fetch`, `origin`, `restore`, `diff`, `diff-staged`, `diff-files`, `log-pretty`, `log-graph`, `pr`, and `prs`.

`push dry origin HEAD`, `push u origin HEAD`, and `push lease origin HEAD` preserve your stackable push shorthand. `nv` skips hooks only when you explicitly request it. `syncmain` and `syncdevelop` stop if a step fails.

Your `gai`, `gaip`, `gair`, `gman` and `gtest` helpers stage **all** repository changes and create the corresponding labeled commit. `gtest` makes a test-labeled commit; it does not run tests. Normal `commit` only commits what you staged yourself.

## Keys and shell behavior

- **Ctrl+R:** history search; fzf supplies fuzzy history search when its packaged integration is installed.
- **Up/Down:** history matching the prefix you already typed.
- **Tab/Shift+Tab:** completion / previous item.
- **Ctrl+A / Ctrl+E:** start / end of the line.
- **Alt+B / Alt+F:** back / forward one word.
- **Ctrl+W / Ctrl+K / Ctrl+Y:** cut word / cut to end / paste cut text.
- **Ctrl+L:** clear the screen.

The prompt shows your folder, Git branch/ref and active Python environment. It uses ordinary terminal colors and ASCII text. `NO_COLOR=1` disables the prompt/greeting colors and `NO_MEOW=1` suppresses the greeting. Individual tools and plugins control their own colors.

The installer adds a guarded block to `.bashrc` so a normal interactive WSL Bash session enters zsh. It does not change the account's login shell. A Bash session launched from the configured zsh stays Bash, rather than bouncing back. Use `--no-auto-zsh` / `-NoAutoZsh` to omit the automatic entry; run `zsh -l` yourself instead. Citrix/macOS can still intercept physical keys before Windows receives them.

## Where your work belongs

Use **`~/src` inside Linux** for repositories built with Linux tools. Access it from Windows with `wopen ~/src` or the `\\wsl$\<distribution>\home\<linux-user>\src` share. Microsoft recommends the Linux filesystem for this workflow's performance. [Working across WSL filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems).

The WSL filesystem is still stored on your VDI. It does not make VM-local files backed up. Push work to the approved Git remote and keep other work in the team's approved backed-up storage. Avoid moving a running WSL virtual disk into OneDrive.

For VS Code, use the **Windows installation plus the WSL extension**, then run `code .` from a Linux repository. That opens a WSL-connected editor; it does not require installing the Linux desktop version of VS Code. The first connection can install its WSL-side server components. [Microsoft's VS Code + WSL guide](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-vscode).

## Personal settings, recovery, and keeping this one

Managed files live in `~/.config/mj-wsl/`. Your editable settings are in `shell/local.zsh`; use `zedit` to open them. Existing local settings are kept during reinstall. Add project shortcuts and choose your editor in that file. Its comments show the available settings. Keep credentials out of it.

Before changing existing startup or managed files, the installer creates a dated backup under `~/.local/state/mj-wsl/backups`. It refuses symlinked startup/managed targets rather than silently replacing a dotfiles manager's links.

`mj-backup` archives the managed configuration. Give it an approved backup destination; its default export directory is still local. That archive includes your local settings as written. It does not include command history, repositories, installed packages, or the whole Linux home directory.

For a **full distribution backup**, save work and stop active development processes first. In Windows PowerShell, use Microsoft's `wsl --export <exact-distribution-name> <approved-path.tar>` command. The archive may contain all data in the distro; it is separate from the small shell-settings backup. [WSL export reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#export-a-distribution).

To remove the automatic startup hooks, run `bash install.sh --uninstall` from the bundle, or `.\Install-FromWindows.ps1 -Uninstall` from Windows. Then reopen the terminal. Your managed configuration and backups are retained.

## If something stops

- **No distribution listed:** WSL may be enabled without a usable Linux installation yet. Finish the intended distro's installation and first-run account setup.
- **Linux sudo denied:** the Linux user needs permission to install packages. Existing Windows admin restrictions do not answer that question. A configuration-only install works once zsh/Python are already provided.
- **Package download or certificate error:** preserve the exact error for IT or the team that manages package access. The bundle keeps your configured network/certificate settings intact.
- **PowerShell scripts or the attachment blocked:** use the approved transfer/installation route. The Linux installer is also readable and runnable directly from the distro.
- **Windows open/clipboard/editor commands missing:** WSL interop or the Windows application may not be available. Linux shell commands remain usable.
- **Wrong distro:** rerun using the exact `-Distribution` name from `wsl --list --verbose`.

## Validation

See **VALIDATION.md** for the executed checks and limitations. This bundle was built on your Mac; it has not been installed or tested inside the your organization VDI.
