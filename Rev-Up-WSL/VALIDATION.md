# Validation record

Built September 28, 2026, for an existing Ubuntu/Debian WSL distribution. The user reported that WSL was installed; the distribution and VM were not inspected during this build.

## Checks executed

- **108 native zsh assertions:** source/reload behavior, PATH and hook deduplication, Git shortcuts, push shorthand/refusals, clone/navigation and failure handling, compound-command failure stops, file counts, editor choices, history settings, keymaps, greeting controls, color controls, escaped prompt content and previous exit status. Git/editor/uv interactions were mocked. A real local Python virtual environment was created without pip or network access; interpreter selection, activation and restoration were exercised.
- **12 installer/package test cases:** repeated installation, local-settings preservation, ZDOTDIR, uninstall, symlink/marker refusal, dry-run behavior, root-user guard, argument validation before package calls, optional package candidates, Node/confirmation flags, and the package-to-config handoff. Apt and sudo were mocked; no Linux packages were actually installed.
- **Windows launcher/integration mocks:** literal arguments with spaces, apostrophes and Unicode; selected/default distro arguments; translation and installer failures; invalid-option handling; Explorer path forwarding; clipboard text supplied through stdin; backup contents and unique archive names; rejection of backup destinations inside the managed configuration. No real Windows clipboard or Explorer calls were made.
- **Installed-shell end-to-end:** installed into an isolated home directory, loaded it through the generated zsh startup file, used navigation and file helpers, ran diagnostics, created and inspected a settings backup, and reloaded the profile.
- **Real terminal session:** Bash auto-entry launched zsh; an interactive Bash launched from that zsh remained Bash without an entry loop.
- **Syntax and packaging:** Bash/zsh syntax validation, PowerShell launcher parsing, LF/ASCII shell source checks, bundle manifest and ZIP integrity checks.

## Test platform and limits

The tests ran on the local Apple Silicon Mac with its Bash 3 and zsh 5.9, Python 3, and the task-local PowerShell 7.6.6 runtime. Only disposable fixture directories were modified. The user's actual Mac shell files and Git configuration were not changed.

An Ubuntu container was not available because the existing Docker daemon was stopped; it was not started for this task. **Actual Ubuntu/Debian apt installation, distro-provided fzf/plugins, Windows PowerShell 5.1, Windows clipboard APIs, WSL interop and Citrix key delivery remain unverified.** The launcher has mock argument tests on PowerShell 7; those do not prove native Windows argument/encoding behavior.

The package installer uses your existing distro repositories and their available versions. It does not pin the whole OS package set. Optional plugins are loaded only if their distro scripts are readable. Node/npm are optional, distro-supplied versions; project-specific version requirements need the team's instructions.

No email was sent and nothing was installed in the your organization VDI during this task. The output is a normal ZIP of readable source/configuration files for the user to transfer and run.

## Checks to make in the VDI

After installing and reopening the Linux terminal, run `mj-help`, `mj-doctor`, and `zcheck`. Check Ctrl+R and Tab, then use `wopen .` and the clipboard helpers if interop is enabled. Inside a work repository, check `status`. Git authentication, approved editor setup and project-specific tooling remain separate from the shell configuration.
