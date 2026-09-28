#!/usr/bin/env bash
# Config-only by default. Bash 3 compatible; no downloaded code is executed.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash install.sh [options]

  --packages       First install the explicit Ubuntu/Debian package list.
  --with-node      With --packages, also install distro nodejs and npm.
  --yes            With --packages, permit apt's noninteractive -y option.
  --no-auto-zsh    Set up zsh without automatic entry from interactive Bash.
  --dry-run        Show the plan without changing files or running apt.
  --uninstall      Remove only managed startup blocks; retain config/backups.
  --help           Show this help.

Default: offline config installation; zsh and Python 3 must already exist.
Run as your normal Linux user, not root. No chsh or system policy changes.
An exported, absolute ZDOTDIR is honored. Symlinked edit targets are refused.
EOF
}

fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

want_packages=0
with_node=0
assume_yes=0
auto_zsh=1
dry_run=0
mode=install
while [ "$#" -gt 0 ]; do
    case "$1" in
        --packages) want_packages=1 ;;
        --with-node) with_node=1 ;;
        --yes) assume_yes=1 ;;
        --no-auto-zsh) auto_zsh=0 ;;
        --dry-run) dry_run=1 ;;
        --uninstall) mode=uninstall ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1. Use --help." ;;
    esac
    shift
done

if [ "$with_node" -eq 1 ] && [ "$want_packages" -ne 1 ]; then
    fail '--with-node requires --packages.'
fi
if [ "$assume_yes" -eq 1 ] && [ "$want_packages" -ne 1 ]; then
    fail '--yes requires --packages.'
fi
if [ "$mode" = uninstall ] && { [ "$want_packages" -eq 1 ] || [ "$auto_zsh" -eq 0 ]; }; then
    fail '--uninstall cannot be combined with --packages or --no-auto-zsh.'
fi
if [ "${MJ_WSL_TEST:-0}" != 1 ]; then
    [ "$(uname -s)" = Linux ] || fail 'Run this inside your Linux/WSL distribution.'
    [ "$(id -u)" -ne 0 ] || fail 'Run as your normal user; do not run the installer with sudo.'
fi
[ -n "${HOME:-}" ] && [ "$HOME" != / ] || fail 'HOME must name your normal home directory.'
case "$HOME" in /*) ;; *) fail 'HOME must be an absolute path.' ;; esac
script_dir=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

if [ "$want_packages" -eq 1 ]; then
    [ -f "$script_dir/packages.sh" ] && [ ! -L "$script_dir/packages.sh" ] || fail 'Missing regular packages.sh beside install.sh.'
    package_args=()
    if [ "$with_node" -eq 1 ]; then package_args+=(--with-node); fi
    if [ "$assume_yes" -eq 1 ]; then package_args+=(--yes); fi
    if [ "$dry_run" -eq 1 ]; then package_args+=(--dry-run); fi
    # Bash 3 with nounset does not permit expanding an empty array.
    if [ "${#package_args[@]}" -gt 0 ]; then
        bash "$script_dir/packages.sh" "${package_args[@]}"
    else
        bash "$script_dir/packages.sh"
    fi
fi

if [ "$mode" = install ] && ! command -v zsh >/dev/null 2>&1; then
    if [ "$dry_run" -eq 1 ] && [ "$want_packages" -eq 1 ]; then
        printf '%s\n' 'Dry run: zsh will be required after the package step.'
    else
        fail 'zsh is missing. Install it through your approved package channel, or use --packages.'
    fi
fi
if ! command -v python3 >/dev/null 2>&1; then
    if [ "$dry_run" -eq 1 ] && [ "$want_packages" -eq 1 ]; then
        printf '%s\n' 'Dry run: Python 3 will be installed before configuration.'
        printf '%s\n' 'Then copy shell/ and bin/ into ~/.config/mj-wsl and append the managed startup blocks.'
        printf '%s\n' 'No files or packages were changed. A detailed config preflight needs Python 3.'
        exit 0
    fi
    fail 'Python 3 is required for atomic startup edits. Install it, or use --packages.'
fi

python3 -B - "$script_dir" "$mode" "$dry_run" "$auto_zsh" <<'PY'
import datetime
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile

bundle = Path(sys.argv[1])
operation = sys.argv[2]
dry_run = sys.argv[3] == "1"
auto_zsh = sys.argv[4] == "1"
home = Path(os.environ["HOME"])
config = home / ".config" / "mj-wsl"
state_dir = home / ".local" / "state" / "mj-wsl"
backup_root = state_dir / "backups"
state_file = state_dir / "install.json"

START = {
    "zsh": b"# >>> MJ WSL: zsh (managed) >>>",
    "bash": b"# >>> MJ WSL: bash (managed) >>>",
}
END = {
    "zsh": b"# <<< MJ WSL: zsh (managed) <<<",
    "bash": b"# <<< MJ WSL: bash (managed) <<<",
}
ZSH = b'''# >>> MJ WSL: zsh (managed) >>>
if [[ -o interactive ]] && [[ -r "$HOME/.config/mj-wsl/shell/mj.zsh" ]]; then
    source "$HOME/.config/mj-wsl/shell/mj.zsh"
fi
# <<< MJ WSL: zsh (managed) <<<
'''
BASH = b'''# >>> MJ WSL: bash (managed) >>>
if [[ $- == *i* ]] && [[ -t 0 && -t 1 ]] &&
   [[ ${MJ_SKIP_ZSH:-0} != 1 ]] && [[ ${MJ_ZSH_STARTED:-0} != 1 ]] &&
   command -v zsh >/dev/null 2>&1; then
    export MJ_ZSH_STARTED=1
    exec zsh
fi
# <<< MJ WSL: bash (managed) <<<
'''


def fail(message):
    raise RuntimeError(message)


def check_path(path, expect_directory=False):
    """Refuse links before reading or writing; never replace a user's symlink."""
    path = Path(path)
    anchors = [home, bundle]
    if "zdotdir" in globals():
        anchors.append(zdotdir)
    matching = [root for root in anchors if root == path or root in path.parents]
    # System ancestors can legitimately be symlinks, e.g. /var on macOS tests.
    # Inspect the managed/startup root and every child, not unrelated ancestors.
    anchor = min(matching, key=lambda root: len(root.parts)) if matching else path.parent
    chain = [anchor]
    for part in path.relative_to(anchor).parts:
        chain.append(chain[-1] / part)
    for part in chain:
        if part.is_symlink():
            fail("Refusing symlinked path: {}. Use a regular target or set this up manually.".format(part))
        if part.exists() and part != path and not part.is_dir():
            fail("A parent is not a directory: {}".format(part))
    if path.exists():
        if expect_directory and not path.is_dir():
            fail("Expected a directory: {}".format(path))
        if not expect_directory and not path.is_file():
            fail("Expected a regular file: {}".format(path))


def strip_block(data, kind, path):
    result = []
    inside = False
    for line in data.splitlines(keepends=True):
        marker = line.rstrip(b"\r\n")
        if marker == START[kind]:
            if inside:
                fail("Nested managed block in {}; fix its markers before retrying.".format(path))
            inside = True
        elif marker == END[kind]:
            if not inside:
                fail("Unmatched managed block end in {}; startup/config files were not changed.".format(path))
            inside = False
        elif not inside:
            result.append(line)
    if inside:
        fail("Unclosed managed block in {}; startup/config files were not changed.".format(path))
    return b"".join(result)


def with_block(data, block):
    if not block:
        return data
    if data and not data.endswith(b"\n"):
        data += b"\n"
    return data + block


def file_mode(path, default):
    if path.exists():
        return stat.S_IMODE(path.stat().st_mode)
    return default


def ensure_private_directory(path):
    """Create only absent paths; preserve modes on existing user directories."""
    missing = []
    current = path
    while not current.exists():
        missing.append(current)
        current = current.parent
    for directory in reversed(missing):
        directory.mkdir(mode=0o700)


def atomic_write(path, data, mode):
    ensure_private_directory(path.parent)
    fd, temporary = tempfile.mkstemp(prefix=".mj-wsl-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, str(path))
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


try:
    if "ZDOTDIR" in os.environ:
        raw_zdotdir = os.environ["ZDOTDIR"]
        if not raw_zdotdir or not os.path.isabs(raw_zdotdir):
            fail("Exported ZDOTDIR must be a nonempty absolute path; received {!r}.".format(raw_zdotdir))
        zdotdir = Path(raw_zdotdir)
    else:
        zdotdir = home
    zshrc = zdotdir / ".zshrc"
    bashrc = home / ".bashrc"
    for directory in (home, zdotdir, config, config / "shell", config / "bin", state_dir, backup_root):
        check_path(directory, expect_directory=True)
    check_path(state_file)
    previous_state = {}
    if state_file.exists():
        try:
            previous_state = json.loads(state_file.read_text(encoding="utf-8"))
        except (ValueError, OSError) as error:
            fail("Cannot read installer state at {}: {}".format(state_file, error))
        if not isinstance(previous_state, dict) or previous_state.get("schema") != 1:
            fail("Unrecognized installer state at {}.".format(state_file))

    targets = {str(zshrc): "zsh", str(bashrc): "bash"}
    previous_targets = previous_state.get("startup_files", [])
    if not isinstance(previous_targets, list):
        fail("Invalid startup_files in {}.".format(state_file))
    for previous in previous_targets:
        if not isinstance(previous, str) or not os.path.isabs(previous):
            fail("Invalid startup path in {}.".format(state_file))
        path = Path(previous)
        if path.name == ".zshrc":
            targets[str(path)] = "zsh"
        elif path == bashrc:
            targets[str(path)] = "bash"
        else:
            fail("Unexpected startup path in state: {}".format(path))

    # Read and validate everything before creating backups or changing any file.
    changes = []
    for filename, kind in sorted(targets.items()):
        path = Path(filename)
        check_path(path)
        old_data = path.read_bytes() if path.exists() else b""
        cleaned = strip_block(old_data, kind, path)
        block = b""
        if operation == "install":
            if path == zshrc:
                block = ZSH
            elif path == bashrc and auto_zsh:
                block = BASH
        new_data = with_block(cleaned, block)
        if new_data != old_data:
            changes.append((path, new_data, file_mode(path, 0o600)))

    if operation == "install":
        source_main = bundle / "shell" / "mj.zsh"
        source_local = bundle / "shell" / "local.zsh.example"
        source_bin = bundle / "bin"
        for source in (source_main, source_local):
            check_path(source)
            if not source.exists():
                fail("Bundle is incomplete; missing {}.".format(source))
        check_path(source_bin, expect_directory=True)
        if not source_bin.exists():
            fail("Bundle is incomplete; missing {}.".format(source_bin))
        copies = [(source_main, config / "shell" / "mj.zsh", 0o644)]
        local = config / "shell" / "local.zsh"
        check_path(local)
        if not local.exists():
            copies.append((source_local, local, 0o600))
        for source in sorted(source_bin.iterdir()):
            check_path(source)
            copies.append((source, config / "bin" / source.name, 0o755))
        for source, destination, default_mode in copies:
            check_path(destination)
            source_data = source.read_bytes()
            new_mode = file_mode(destination, default_mode)
            if destination.parent == config / "bin":
                new_mode |= stat.S_IXUSR
            if (not destination.exists() or destination.read_bytes() != source_data or
                    file_mode(destination, default_mode) != new_mode):
                changes.append((destination, source_data, new_mode))

    if operation == "uninstall" and not changes and not previous_state:
        print("No managed startup blocks or installer state were found; no files changed.")
        sys.exit(0)

    new_state = {
        "schema": 1,
        "installed": operation == "install",
        "config_directory": str(config),
        "startup_files": sorted(targets),
        "auto_zsh": auto_zsh if operation == "install" else False,
    }
    stable_previous = dict(previous_state)
    stable_previous.pop("updated_at", None)
    if changes or new_state != stable_previous:
        new_state["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        state_bytes = (json.dumps(new_state, indent=2, sort_keys=True) + "\n").encode("utf-8")
        changes.append((state_file, state_bytes, file_mode(state_file, 0o600)))

    label = "Dry run" if dry_run else "Plan"
    print("{}: {} MJ WSL configuration.".format(label, operation))
    print("Configuration: {}".format(config))
    print("zsh startup: {}".format(zshrc))
    if operation == "install":
        print("Bash auto-entry: {}".format("enabled for interactive TTY sessions" if auto_zsh else "disabled"))
        print("Existing shell/local.zsh is preserved.")
    for destination, _, _ in changes:
        action = "Update" if destination.exists() else "Create"
        print("  {} {}".format(action, destination))
    if dry_run:
        print("No files changed. Backups would be saved under {}.".format(backup_root))
        sys.exit(0)
    if not changes:
        print("Already configured as requested; startup/config files are unchanged.")
        sys.exit(0)

    ensure_private_directory(backup_root)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ-")
    backup = Path(tempfile.mkdtemp(prefix=stamp, dir=str(backup_root)))
    original_files = []
    for index, (destination, _, _) in enumerate(changes):
        entry = {"path": str(destination), "existed": destination.exists()}
        if destination.exists():
            saved_name = "{:03d}-{}".format(index, destination.name)
            saved = backup / saved_name
            # cp -p preserves original permissions and timestamps on both BSD/GNU.
            subprocess.check_call(["cp", "-p", str(destination), str(saved)])
            entry["backup"] = saved_name
        original_files.append(entry)
    manifest = {"operation": operation, "files": original_files}
    atomic_write(backup / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode("utf-8"), 0o600)

    completed = []
    try:
        for destination, data, mode in changes:
            atomic_write(destination, data, mode)
            completed.append(destination)
    except BaseException:
        # Restore only files written by this attempt, using the pre-edit snapshots.
        entries = {entry["path"]: entry for entry in original_files}
        for destination in reversed(completed):
            entry = entries[str(destination)]
            try:
                if entry["existed"]:
                    saved = backup / entry["backup"]
                    atomic_write(destination, saved.read_bytes(), stat.S_IMODE(saved.stat().st_mode))
                    shutil.copystat(str(saved), str(destination))
                else:
                    destination.unlink()
            except OSError as restore_error:
                print("Restore needed for {}: {}".format(destination, restore_error), file=sys.stderr)
        raise
    print("Backups: {}".format(backup))
    if operation == "uninstall":
        print("Managed startup blocks removed. Configuration, backups and installed packages were kept.")
    else:
        print("Installed. Open a new WSL terminal, or run zsh to enter the configured shell.")
        print("To bypass Bash auto-entry once: MJ_SKIP_ZSH=1 bash")
except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
    print("install.sh: {}".format(error), file=sys.stderr)
    sys.exit(1)
PY
