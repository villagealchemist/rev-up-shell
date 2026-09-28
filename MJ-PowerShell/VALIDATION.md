# Validation record

Built September 28, 2026.

## Executed checks

- **172 developer-helper assertions:** Git/GitHub argument forwarding; messages and paths with spaces; push shorthand; failure stops; commit labels; clone directory inference and navigation; selected Python interpreter; virtual environment state restoration; editor selection; profile reload and syntax-only checks. External Git/editor operations in this suite were mocked, so the tests did not contact remotes, create real commits, or launch editors.
- **73 Unix/integration assertions:** file preservation, empty-file creation, paths with spaces and brackets, wildcards, hidden files, navigation, supported listing flags, unknown-option errors, file and pipeline text filters, grep statuses, word/line/byte counts, command lookup, profile backup and reload. Real Git staging/status/diff and repository-root checks used a disposable local repository with isolated Git configuration. No repository was pushed.
- **Installer checks:** existing Unicode/CRLF content and literal dollar signs preserved; repeated installs do not duplicate loaders; local settings retained; startup loading; alias behavior after reload; uninstall restores the original profile content in the test fixture.
- **Interactive terminal checks:** Emacs keys, completion and history bindings; predictions enabled and disabled; prompt inside/outside Git; existing exit code preserved, including with strict error handling.
- **Assembled artifact:** parser check, load check, exported-command lookup, and scan for selected PowerShell 7-only syntax. Source is ASCII so Windows PowerShell 5.1 does not misread non-ASCII script text.

## Runtime and boundaries

Runtime tests used Microsoft's portable **PowerShell 7.6.6 on Apple Silicon macOS**. Its archive SHA-256 matched the official release asset metadata:

`6df833d094ebac1c1a74340d7b3437f4aaf5e03ce640484a1c4359f3ce8b3db1`

The source targets Windows PowerShell 5.1 and PowerShell 7. **Windows PowerShell 5.1 has not been executed for these tests.** Windows-specific Python launcher discovery, clipboard operations, editor launches, and workplace policy behavior need checks in the VM. Configured key bindings were verified in a local terminal; Citrix/macOS interception of physical keys was not tested. Following replacement/rotated log files is not guaranteed.

No existing Mac shell profile or Git configuration was changed. No changes have been made to the your organization VM by this bundle creation. The PowerShell test runtime is kept in the task's working directory and is not included in the downloadable bundle.

## First checks in the VM

After installing and reopening PowerShell, run `mj-help`, `mj-doctor`, and `zcheck`. Try `ls -la`, use Ctrl+R, and check `status` inside an existing work repository. Any missing application shown by `mj-doctor` remains a separate approved-software installation task.
