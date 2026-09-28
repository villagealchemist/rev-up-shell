#!/usr/bin/env bash
# Explicit Debian/Ubuntu package bootstrap. No curl|sh, added repositories, or upgrades.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash packages.sh [--with-node] [--yes] [--dry-run]

Installs: zsh git openssh-client nano less ca-certificates curl build-essential
          jq unzip zip ripgrep fd-find fzf bat tmux python3 python3-venv python3-pip
Optional when apt has candidates: zsh-autosuggestions zsh-syntax-highlighting

  --with-node  Also install distribution nodejs/npm. Versions are not pinned.
  --yes        Explicitly pass -y to apt-get install; default keeps its prompt.
  --dry-run    Print the package plan; do not run apt, sudo, or network commands.
  --help       Show this help.

Run as your normal Ubuntu/Debian user. sudo is used only for apt-get.
No Docker, third-party repositories, system upgrade, or shell change is done.
EOF
}

fail() { printf 'packages.sh: %s\n' "$*" >&2; exit 1; }

with_node=0
assume_yes=0
dry_run=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --with-node) with_node=1 ;;
        --yes) assume_yes=1 ;;
        --dry-run) dry_run=1 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1. Use --help." ;;
    esac
    shift
done

if [ "${MJ_WSL_TEST:-0}" != 1 ]; then
    [ "$(uname -s)" = Linux ] || fail 'Run this inside your Linux/WSL distribution.'
    [ "$(id -u)" -ne 0 ] || fail 'Run as your normal user, not root; the script invokes sudo for apt.'
fi
release_file=/etc/os-release
if [ "${MJ_WSL_TEST:-0}" = 1 ] && [ -n "${MJ_WSL_OS_RELEASE:-}" ]; then
    release_file=$MJ_WSL_OS_RELEASE
fi
[ -r "$release_file" ] || fail "Cannot read distribution information: $release_file"
distro_id=
distro_like=
while IFS='=' read -r key value || [ -n "${key:-}" ]; do
    # Parse values as data. Never source an os-release file as shell code.
    value=${value%$'\r'}
    case "$value" in
        \"*\") value=${value#\"}; value=${value%\"} ;;
        \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    case "$key" in
        ID) distro_id=$value ;;
        ID_LIKE) distro_like=$value ;;
    esac
done < "$release_file"
case " $distro_id $distro_like " in
    *' ubuntu '*|*' debian '*) ;;
    *) fail "Unsupported distribution '$distro_id'. This package list is for Ubuntu/Debian and their derivatives." ;;
esac

packages=(zsh git openssh-client nano less ca-certificates curl build-essential jq unzip zip ripgrep fd-find fzf bat tmux python3 python3-venv python3-pip)
if [ "$with_node" -eq 1 ]; then
    packages+=(nodejs npm)
    printf '%s\n' 'Node notice: installing distro nodejs/npm; versions are unpinned and may differ from a project requirement.'
fi
printf 'Distribution: %s\n' "$distro_id"
printf '%s\n' 'Requested packages:'
printf '  %s\n' "${packages[@]}"
printf '%s\n' 'Optional packages when candidates exist: zsh-autosuggestions zsh-syntax-highlighting'

if [ "$dry_run" -eq 1 ]; then
    printf '%s\n' 'Dry run: sudo apt-get update'
    if [ "$assume_yes" -eq 1 ]; then
        printf '%s\n' 'Dry run: sudo apt-get install --no-install-recommends -y [packages above, plus available optional packages]'
    else
        printf '%s\n' 'Dry run: sudo apt-get install --no-install-recommends [packages above, plus available optional packages]'
        printf '%s\n' 'apt will ask for its normal installation confirmation.'
    fi
    printf '%s\n' 'No commands requiring sudo, apt metadata updates, or network operations were run.'
    exit 0
fi

for required in sudo apt-get apt-cache awk; do
    command -v "$required" >/dev/null 2>&1 || fail "Required command is missing: $required"
done
printf '%s\n' 'Refreshing apt package metadata (this does not upgrade installed packages).'
sudo apt-get update
for optional in zsh-autosuggestions zsh-syntax-highlighting; do
    candidate=
    if policy=$(apt-cache policy "$optional" 2>/dev/null); then
        candidate=$(printf '%s\n' "$policy" | awk '/^[[:space:]]*Candidate:/ { print $2; exit }')
    fi
    if [ -n "$candidate" ] && [ "$candidate" != '(none)' ]; then
        packages+=("$optional")
        printf 'Including optional package: %s\n' "$optional"
    else
        printf 'Skipping unavailable optional package: %s\n' "$optional"
    fi
done
install_args=(apt-get install --no-install-recommends)
if [ "$assume_yes" -eq 1 ]; then install_args+=(-y); fi
sudo "${install_args[@]}" "${packages[@]}"
printf '%s\n' 'Package step completed. No system upgrade or login-shell change was performed.'
