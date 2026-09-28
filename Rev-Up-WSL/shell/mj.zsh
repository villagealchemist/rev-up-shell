# Rev Up WSL: a native zsh environment. Source this file from ~/.zshrc.
# No downloads, account setup, project hooks, or Git changes happen on startup.

export MJ_ZSH_STARTED=1
typeset -g MJ_SHELL_DIR=${${(%):-%N}:A:h}
typeset -g MJ_HOME=${MJ_SHELL_DIR:h}
typeset -g MJ_PROMPT_NAME=${MJ_PROMPT_NAME:-alchemist}
typeset -g MJ_GREETING=${MJ_GREETING:-1}
typeset -g MJ_EDITOR=${MJ_EDITOR:-}
if (( ! ${+parameters[MJ_PROJECTS]} )); then
  typeset -gA MJ_PROJECTS=()
fi

if [[ -o interactive ]]; then
  HISTFILE=${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}
  HISTSIZE=50000
  SAVEHIST=50000
  setopt extended_history share_history hist_ignore_dups hist_ignore_all_dups
  setopt hist_save_no_dups hist_find_no_dups hist_reduce_blanks hist_ignore_space
  unsetopt inc_append_history inc_append_history_time
  setopt interactive_comments no_beep
fi

# This is the only user-maintained configuration sourced by this bundle.
[[ -r "$MJ_SHELL_DIR/local.zsh" ]] && source "$MJ_SHELL_DIR/local.zsh"
if [[ -d "$MJ_HOME/bin" ]]; then
  typeset -gU path
  path=("$MJ_HOME/bin" "${path[@]}")
fi

# Clear only aliases that would hide public functions supplied below.
for _mj_name in push clone syncmain syncdevelop gai gaip gair gman gtest \
  python pip notebook venv activate edit zedit pedit zcat zcheck \
  reload-profile revupzsh restart up mkcd countfiles countall cproj croot csrc \
  wopen wclip wpaste doctor backup-profile mj-help; do
  unalias "$_mj_name" 2>/dev/null
done
unset _mj_name

function _mj_require_command {
  emulate -L zsh
  if (( ! $+commands[$1] )); then
    print -u2 -r -- "$1 is not installed or is not on PATH. Use your approved package source."
    return 127
  fi
}

# Familiar shortcuts from the personal zsh configuration.
alias branch='git branch'
alias log='git log'
alias checkout='git checkout'
alias add='git add'
alias status='git status'
alias commit='git commit'
alias amend='git commit --amend'
alias pull='git pull'
alias merge='git merge'
alias ignored='git status --ignored'
alias stash='git stash'
alias rebase='git rebase'
alias fetch='git fetch'
alias origin='git fetch origin'
alias restore='git restore'
alias diff='git diff'
alias diff-staged='git diff --staged'
alias diff-files='git diff --stat'
alias log-pretty='git log --pretty=oneline --abbrev-commit'
alias log-graph='git log --graph --oneline --all'
alias pr='gh pr view --web'
alias prs='gh pr status'

function push {
  emulate -L zsh
  _mj_require_command git || return
  local -a flags=() git_args=()
  local arg
  for arg in "$@"; do
    case "$arg" in
      nv|--nv) flags+=(--no-verify) ;;
      lease|ff|force-with-lease|--force-with-lease) flags+=(--force-with-lease) ;;
      f|-f|force|--force)
        print -u2 -- "Refusing unsafe force shorthand. Use 'lease' or 'ff' for --force-with-lease."
        return 1 ;;
      tags|--tags) flags+=(--tags) ;;
      u|upstream|track) flags+=(-u) ;;
      dry|dry-run|--dry-run) flags+=(--dry-run) ;;
      *) git_args+=("$arg") ;;
    esac
  done
  command git push "${flags[@]}" "${git_args[@]}"
}

function syncmain {
  _mj_require_command git || return
  command git fetch origin main && command git checkout main && command git pull --ff-only origin main
}
function syncdevelop {
  _mj_require_command git || return
  command git fetch origin develop && command git checkout develop && command git pull --ff-only origin develop
}

# These stage ALL changes before committing. gtest does not run a test suite.
function gai { command git add -A && command git commit -m "[AI:accepted] $*" }
function gaip { command git add -A && command git commit -m "[AI:partial] $*" }
function gair { command git add -A && command git commit -m "[AI:rejected] $*" }
function gman { command git add -A && command git commit -m "[manual] $*" }
function gtest { command git add -A && command git commit --allow-empty -m "[test] $*" }

function clone {
  emulate -L zsh
  if (( $# < 1 || $# > 2 )) || [[ -z "$1" || "$1" == -* ]]; then
    print -u2 -- 'Usage: clone <repository-url> [new-directory]; the URL must not begin with a dash.'
    return 2
  fi
  _mj_require_command git || return
  local repo_url=$1 new_dir=${2:-} repo_path repo_name
  if (( $# == 2 )); then
    [[ -n "$new_dir" ]] || { print -u2 -- 'The new directory must not be empty.'; return 2; }
  else
    repo_path=${repo_url%%[\?#]*}
    while [[ "$repo_path" == */ ]]; do repo_path=${repo_path%/}; done
    if [[ "$repo_url" == *://* ]]; then
      repo_path=${repo_path#*://}
      if [[ "$repo_path" != */* ]]; then
        print -u2 -- 'Cannot infer a directory from that URL. Supply a new-directory argument.'
        return 2
      fi
      repo_path=${repo_path#*/}
    fi
    repo_name=${repo_path##*[/:]}
    new_dir=${repo_name%.git}
    if [[ -z "$new_dir" || "$new_dir" == (.|..|-*|*[[:cntrl:]]*) ]]; then
      print -u2 -- 'Cannot infer a safe directory. Supply a new-directory argument.'
      return 2
    fi
  fi
  command git clone -- "$repo_url" "$new_dir" || return
  builtin cd -- "$new_dir"
}

function python { command python3 "$@" }
function pip { command python3 -m pip "$@" }
function notebook { command python3 -m notebook "$@" }

function activate {
  emulate -L zsh
  if (( $# > 1 )); then print -u2 -- 'Usage: activate [virtual-environment-directory]'; return 2; fi
  local env_dir=${1:-.venv}
  env_dir=${env_dir:A}
  if [[ ! -f "$env_dir/pyvenv.cfg" || ! -r "$env_dir/bin/activate" || ! -x "$env_dir/bin/python" ]]; then
    print -u2 -r -- "Not a usable Linux Python virtual environment: $env_dir"
    return 1
  fi
  # The prompt already shows the active venv. Standard activate supplies deactivate.
  local VIRTUAL_ENV_DISABLE_PROMPT=1
  source "$env_dir/bin/activate"
}

function venv {
  emulate -L zsh
  if (( $# > 1 )); then print -u2 -- 'Usage: venv [virtual-environment-directory]'; return 2; fi
  local env_dir=${1:-.venv}
  [[ -n "$env_dir" ]] || { print -u2 -- 'The virtual environment directory must not be empty.'; return 2; }
  env_dir=${env_dir:A}
  if [[ -f "$env_dir/pyvenv.cfg" ]]; then activate "$env_dir"; return; fi
  local -a entries=()
  [[ -d "$env_dir" ]] && entries=("$env_dir"/*(DN))
  if [[ -e "$env_dir" ]] && { [[ ! -d "$env_dir" ]] || (( ${#entries} )); }; then
    print -u2 -r -- "Refusing to overwrite a nonempty path that is not a virtual environment: $env_dir"
    return 1
  fi
  if (( $+commands[uv] )); then
    command uv venv --no-python-downloads "$env_dir" || return
  else
    _mj_require_command python3 || return
    command python3 -m venv "$env_dir" || return
  fi
  activate "$env_dir"
}

function edit {
  emulate -L zsh
  (( $# )) || { print -u2 -- 'Usage: edit <file-or-directory> [...]'; return 2; }
  local editor_path editor_name
  if [[ -n "$MJ_EDITOR" ]]; then
    editor_path=$(whence -p -- "$MJ_EDITOR")
    if [[ -z "$editor_path" ]]; then
      print -u2 -r -- "Configured editor '$MJ_EDITOR' was not found. MJ_EDITOR must name one executable, without arguments."
      return 127
    fi
    command "$editor_path" "$@"
    return
  fi
  for editor_name in code code-insiders nano vi; do
    if (( $+commands[$editor_name] )); then command "$editor_name" "$@"; return; fi
  done
  print -u2 -- 'No editor found. Add an approved editor to PATH or configure MJ_EDITOR.'
  return 127
}
function zedit { edit "$MJ_SHELL_DIR/local.zsh" }
function pedit { edit "$MJ_SHELL_DIR/mj.zsh" }
function zcat { command cat -- "$MJ_SHELL_DIR/local.zsh" }
function zcheck {
  command zsh -n "$MJ_SHELL_DIR/mj.zsh" || return
  if [[ -f "$MJ_SHELL_DIR/local.zsh" ]]; then command zsh -n "$MJ_SHELL_DIR/local.zsh" || return; fi
  print -- 'zsh syntax OK'
}
function reload-profile { source "$MJ_SHELL_DIR/mj.zsh" }
function revupzsh { reload-profile }
function restart { command clear; reload-profile }

alias ..='cd ..'
alias ...='cd ../..'
function up {
  emulate -L zsh
  local levels=${1:-1}
  if (( $# > 1 )) || [[ "$levels" != <-> ]] || (( levels < 1 || levels > 256 )); then
    print -u2 -- 'Usage: up [levels from 1 to 256]'
    return 2
  fi
  repeat "$levels"; do builtin cd .. || return; done
}
function mkcd {
  (( $# == 1 )) || { print -u2 -- 'Usage: mkcd <directory>'; return 2; }
  command mkdir -p -- "$1" && builtin cd -- "$1"
}
function csrc { mkcd "$HOME/src" }
function croot {
  emulate -L zsh
  _mj_require_command git || return
  local repo_root
  repo_root=$(command git rev-parse --show-toplevel) || return
  builtin cd -- "$repo_root"
}
function cproj {
  emulate -L zsh
  local project_name
  if (( $# == 0 )); then
    if (( ${#MJ_PROJECTS} == 0 )); then print -- 'No project shortcuts yet. Add paths with zedit.'; return; fi
    for project_name in ${(ok)MJ_PROJECTS}; do
      printf '%s -> %s\n' "$project_name" "${MJ_PROJECTS[$project_name]}"
    done
    return
  fi
  if (( $# != 1 )) || [[ -z ${MJ_PROJECTS[$1]-} ]]; then
    print -u2 -- 'Usage: cproj [configured-project-name]. Run cproj to list names.'
    return 2
  fi
  builtin cd -- "${MJ_PROJECTS[$1]}"
}

# GNU tools remain GNU tools: no replacement implementations of ls/grep/find/etc.
if [[ -n ${NO_COLOR:-} ]]; then
  alias ll='ls -alF --color=never'
  alias la='ls -A --color=never'
  alias l='ls -CF --color=never'
else
  alias ll='ls -alF --color=auto'
  alias la='ls -A --color=auto'
  alias l='ls -CF --color=auto'
fi
if (( ! $+commands[fd] && ! $+functions[fd] && ! $+aliases[fd] && $+commands[fdfind] )); then
  function fd { command fdfind "$@" }
fi
if (( ! $+commands[bat] && ! $+functions[bat] && ! $+aliases[bat] && $+commands[batcat] )); then
  function bat { command batcat "$@" }
fi
function countfiles {
  emulate -L zsh
  local -a entries=(*(N.))
  print -r -- ${#entries}
}
function countall {
  emulate -L zsh
  local -a entries=(*(N))
  print -r -- ${#entries}
}
function wopen { command wsl-open "$@" }
function wclip { command wsl-copy "$@" }
function wpaste { command wsl-paste "$@" }
function doctor { command mj-doctor "$@" }
function backup-profile { command mj-backup "$@" }

function _mj_prompt_escape {
  emulate -L zsh
  local value=$1
  value=${value//[[:cntrl:]]/?}
  print -rn -- "${value//\%/%%}"
}
function _mj_precmd {
  local mj_exit=$?
  emulate -L zsh
  local branch_name='' venv_name=''
  typeset -g MJ_LAST_EXIT=$mj_exit
  typeset -g _MJ_PROMPT_NAME=$(_mj_prompt_escape "$MJ_PROMPT_NAME")
  typeset -g _MJ_PROMPT_GIT='' _MJ_PROMPT_VENV=''
  typeset -g _MJ_PROMPT_STATUS='%F{green}$%f'
  if [[ -n ${NO_COLOR:-} ]]; then
    _MJ_PROMPT_STATUS='$'
    (( mj_exit )) && _MJ_PROMPT_STATUS="[${mj_exit}] \$"
  elif (( mj_exit )); then
    _MJ_PROMPT_STATUS="%F{red}[${mj_exit}] \$%f"
  fi
  if (( $+commands[git] )); then
    branch_name=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
      branch_name=$(command git rev-parse --short HEAD 2>/dev/null) || branch_name=''
    if [[ -n "$branch_name" ]]; then
      if [[ -n ${NO_COLOR:-} ]]; then
        _MJ_PROMPT_GIT=" [$(_mj_prompt_escape "$branch_name")]"
      else
        _MJ_PROMPT_GIT=" %F{magenta}[$(_mj_prompt_escape "$branch_name")]%f"
      fi
    fi
  fi
  if [[ -n ${VIRTUAL_ENV:-} ]]; then
    venv_name=${VIRTUAL_ENV:t}
    if [[ -n ${NO_COLOR:-} ]]; then
      _MJ_PROMPT_VENV=" ($(_mj_prompt_escape "$venv_name"))"
    else
      _MJ_PROMPT_VENV=" %F{yellow}($(_mj_prompt_escape "$venv_name"))%f"
    fi
  fi
  return 0
}

function mj-help {
  cat <<'MJ_HELP'
REV UP WSL
  zedit / pedit             Edit local settings / managed shell
  reload-profile, revupzsh  Reload; restart clears the screen and reloads
  zcheck / doctor           Check syntax / installed tools and WSL integration
  backup-profile [folder]   Back up shell config to an approved local destination
  ..  ...  up [n]  cd -     Navigate up / return to previous directory
  mkcd <dir>  croot         Create and enter a directory / enter repository root
  csrc                     Create and enter ~/src, inside the Linux filesystem
  cproj [name]             List or enter MJ_PROJECTS shortcuts from local settings
  ll / la / l              GNU ls views; countfiles/countall count visible entries
  fd / bat                 Native fd/bat, or distro fdfind/batcat wrappers
  edit <file>              Installed code, then nano/vi; MJ_EDITOR overrides

GIT
  branch log checkout add status commit amend pull merge ignored stash rebase
  fetch origin restore diff diff-staged diff-files log-pretty log-graph pr prs
  push [dry] [u] [tags] [lease|ff] [nv] [remote] [refspec]
    Flags stack. nv explicitly skips hooks; it is never added automatically.
    f/-f/force/--force are refused. Use lease when force-with-lease is intended.
  clone <repo-url> [dir]    Clone, then enter the result only after success
  syncmain / syncdevelop   Fetch, checkout, fast-forward-only pull; stop on failure
  gai / gaip / gair / gman  STAGE ALL changes, then commit with a tagged message
  gtest                    STAGE ALL and make a [test] commit; does NOT run tests

PYTHON AND WINDOWS
  python / pip / notebook  Python 3; pip and notebook use that interpreter
  venv [dir]               Create/reuse and activate .venv (or dir)
  activate [dir]           Activate existing venv; deactivate restores the shell
    No --break-system-packages. uv will not download a Python interpreter.
  wopen [path]             Open a WSL path with Windows
  wclip / wpaste           Pipe text to / from the Windows clipboard

KEYS AND HISTORY
  Tab / Shift+Tab          Complete / cycle back; case-insensitive matching
  Ctrl+r                  fzf history when packaged bindings exist, else built-in
  Up / Down               Search history beginning with the text already typed
  Ctrl+a/e  Alt+b/f        Start/end of line; previous/next word
  Ctrl+w/k/y  Ctrl+l       Cut word/tail, yank; clear screen
  History stays in your normal zsh history file. A leading space avoids saving
  a command, but does not protect credentials in process arguments or output.
  Set MJ_GREETING=0 in zedit, or set NO_MEOW, to silence the greeting.
MJ_HELP
}

if [[ -o interactive ]]; then
  # Keep existing completion/plugin initialization and hooks when already loaded.
  if (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
  fi
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
  zstyle ':completion:*' menu select
  bindkey -e
  bindkey '^R' history-incremental-search-backward
  bindkey '^I' expand-or-complete
  bindkey '^[[Z' reverse-menu-complete
  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey '^[[A' up-line-or-beginning-search
  bindkey '^[[B' down-line-or-beginning-search
  bindkey '^[OA' up-line-or-beginning-search
  bindkey '^[OB' down-line-or-beginning-search

  if (( $+commands[fzf] && ! $+functions[fzf-history-widget] )); then
    for _mj_script in /usr/share/doc/fzf/examples/key-bindings.zsh \
      /usr/share/fzf/key-bindings.zsh /usr/share/fzf/shell/key-bindings.zsh; do
      if [[ -r "$_mj_script" ]]; then source "$_mj_script"; break; fi
    done
  fi
  if (( $+functions[fzf-history-widget] )); then bindkey '^R' fzf-history-widget; fi
  if (( $+commands[fzf] && ! $+functions[_fzf_complete] )); then
    for _mj_script in /usr/share/doc/fzf/examples/completion.zsh \
      /usr/share/fzf/completion.zsh /usr/share/fzf/shell/completion.zsh; do
      if [[ -r "$_mj_script" ]]; then source "$_mj_script"; break; fi
    done
  fi
  if (( ! $+functions[_zsh_autosuggest_start] )); then
    for _mj_script in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
      /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
      if [[ -r "$_mj_script" ]]; then source "$_mj_script"; break; fi
    done
  fi

  setopt prompt_subst
  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd _mj_precmd
  add-zsh-hook precmd _mj_precmd
  if [[ -n ${NO_COLOR:-} ]]; then
    PROMPT='${_MJ_PROMPT_NAME} %~${_MJ_PROMPT_GIT}${_MJ_PROMPT_VENV}'$'\n''${_MJ_PROMPT_STATUS} '
  else
    PROMPT='%F{cyan}${_MJ_PROMPT_NAME}%f %F{blue}%~%f${_MJ_PROMPT_GIT}${_MJ_PROMPT_VENV}'$'\n''${_MJ_PROMPT_STATUS} '
  fi
  RPROMPT=''

  # Syntax highlighting must be loaded after other widgets. Existing instances
  # and styles are left in place, including across reload-profile calls.
  if (( ! $+functions[_zsh_highlight] )); then
    for _mj_script in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
      /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
      if [[ -r "$_mj_script" ]]; then source "$_mj_script"; break; fi
    done
  fi
  unset _mj_script
  if [[ ${MJ_GREETING:-1} != 0 && -z ${NO_MEOW:-} && ${_MJ_GREETED:-0} != 1 ]]; then
    if [[ -n ${NO_COLOR:-} ]]; then
      print -r -- "Rev up that WSL... I'm HUNGRY!"
    else
      print -P -- "%F{cyan}Rev up that WSL... I'm HUNGRY!%f"
    fi
    typeset -g _MJ_GREETED=1
  fi
fi
