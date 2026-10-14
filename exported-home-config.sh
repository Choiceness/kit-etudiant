#!/usr/bin/env bash
# shellcheck disable=SC2088  # "~/" inside quotes is only displayed, never expanded
# =============================================================================
#  exported-home-config.sh - my home setup on a Linux Mint PC, without root
#    zsh + oh-my-zsh + powerlevel10k, Neovim + LazyVim, C and Bash tools
#    Everything goes into $HOME. Safe to re-run. Can be uninstalled.
# =============================================================================
#  Usage: bash exported-home-config.sh [options]
#    --home ARCHIVE   use my home config (home-config.tar.gz from export-home-config.sh)
#    --p10k FILE      use only this powerlevel10k config (~/.p10k.zsh)
#    --update         reinstall / update everything
#    --no-conda       skip micromamba (valgrind, gdb, cppcheck, bear, tmux, check, node)
#    --no-terminal    do not create the GNOME Terminal "Home" profile
#    --only A,B       run only these steps (see --list)
#    --list           list the steps
#    --uninstall      remove everything that was installed
#    --all            with --uninstall: also remove personal files
#    -h, --help       show this help
# =============================================================================
set -uo pipefail

# Never use root
sudo()   { echo "FORBIDDEN: this script never uses sudo" >&2; return 97; }
su()     { echo "FORBIDDEN: this script never uses su" >&2; return 97; }
pkexec() { echo "FORBIDDEN: this script never uses pkexec" >&2; return 97; }

NAME="exported-home-config"
VERSION="3.0.0 (2026-10-14)"
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
OPT="$PREFIX/opt"
SHR="$PREFIX/share"
CFG="$HOME/.config/$NAME"
WORK="$HOME/.cache/$NAME"          # not /tmp: often mounted noexec
MAMBA_ROOT="$HOME/micromamba"
NVIM_CFG="$HOME/.config/nvim"
ZCUSTOM="$HOME/.oh-my-zsh/custom"
MANIFEST="$CFG/manifest"
LOGF="$WORK/install-$(date +%Y%m%d-%H%M%S).log"
MARK_BEGIN=">>> $NAME >>>"
MARK_END="<<< $NAME <<<"
BAK=".before-home-config"

# Old name of this project (versions 1 and 2)
OLD_CFG="$HOME/.config/kit-etudiant"
OLD_WORK="$HOME/.cache/kit-etudiant"

MM="$OPT/micromamba/micromamba"
ARCHIVE=""; ARCHIVE_DIR=""; FONT="MesloLGS NF 15"; MARGIN=5
REASON=""; UPDATE=0; NO_CONDA=0; NO_TERM=0; ALL=0; ONLY=""; P10K_SRC=""; MODE=install
declare -a OKS=() FAILS=() TODO=()

if [ -t 1 ]; then GRN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; BLU=$'\e[1;34m'; DIM=$'\e[2m'; RST=$'\e[0m'
else GRN=""; RED=""; YEL=""; BLU=""; DIM=""; RST=""; fi

STEPS=(prep cli zsh shell_tools c_tools python conda neovim tmux config doc terminal clipboard)
declare -A DESC=(
  [prep]="folders, checks (noexec, glibc, disk space), PATH"
  [cli]="rg fd bat eza delta lazygit jq yazi gh glow watchexec hyperfine duf sd btop gdu direnv chezmoi croc rclone tldr"
  [zsh]="zsh (zsh-bin), oh-my-zsh, powerlevel10k, autosuggestions, syntax-highlighting, you-should-use, zsh-bat, fzf, zoxide"
  [shell_tools]="shellcheck, shfmt, bats-core"
  [c_tools]="gdb-dashboard"
  [python]="uv + clang-format, clang-tidy, trash-cli, thefuck"
  [conda]="micromamba + valgrind gdb cppcheck bear tmux check pkg-config node xclip"
  [neovim]="Neovim + LazyVim (clangd, codelldb debugger, bash), plugins and Mason tools"
  [tmux]="tmux.conf, tpm, tmux-sensible, tmux-resurrect"
  [config]=".zshrc, bash fallback, gdbinit, git + delta, cnew, memo"
  [doc]="offline C docs (cppreference, cdoc command)"
  [terminal]="MesloLGS NF font, GNOME Terminal \"Home\" profile (Konsole colors), Caps Lock = Escape"
  [clipboard]="CopyQ: clipboard history (terminal, Neovim, browser), Super+V"
)

# ---- Output ------------------------------------------------------------------
log()   { printf '%s\n' "$*" >>"$LOGF"; }
title() { printf '\n%s==> %s%s\n' "$BLU" "$1" "$RST"; log "==> $1"; }
ok()    { OKS+=("$1"); printf '  %s[ok]%s   %s\n' "$GRN" "$RST" "$1"; log "OK   $1"; }
fail()  { FAILS+=("$1: $2"); printf '  %s[FAIL]%s %s %s(%s)%s\n' "$RED" "$RST" "$1" "$DIM" "$2" "$RST"; log "FAIL $1: $2"; }
info()  { printf '  %s[info]%s %s\n' "$YEL" "$RST" "$1"; log "INFO $1"; }
todo()  { TODO+=("$1"); }

# run "Name" command args...: run, log, report ok/fail
run() {
  local name=$1; shift
  REASON=""
  log "---- $name: $*"
  if "$@" >>"$LOGF" 2>&1; then ok "$name"; return 0; fi
  fail "$name" "${REASON:-see $LOGF}"; return 1
}
# tool "Name" MARKER_PATH command...: skip if already installed (unless --update)
tool() {
  local name=$1 marker=$2; shift 2
  if [ "$UPDATE" -eq 0 ] && [ -e "$marker" ]; then ok "$name (already there)"; return 0; fi
  run "$name" "$@"
}
record() { mkdir -p "$CFG"; printf '%s\n' "$1" >>"$MANIFEST"; }

# ---- GitHub downloads (no API, so no rate limit) -----------------------------
download() {     # download URL FILE
  mkdir -p "$(dirname "$2")"
  curl -fL --retry 3 --retry-delay 3 --connect-timeout 20 -sS -o "$2" "$1"
}
gh_tag() {       # latest release tag, read from the /releases/latest redirect
  curl -fsSI --retry 3 --connect-timeout 20 "https://github.com/$1/releases/latest" \
    | tr -d '\r' | sed -n 's#^[Ll]ocation: .*/releases/tag/##p' | tail -1
}
gh_asset() {     # gh_asset owner/repo REGEX -> URL of the matching file in the latest release
  local repo=$1 re=$2 tag h name
  tag=$(gh_tag "$repo")
  [ -n "$tag" ] || { echo "no release found for $repo" >&2; return 1; }
  while read -r h; do
    name=${h##*/}
    if [[ $name =~ $re ]]; then echo "https://github.com$h"; return 0; fi
  done < <(curl -fsSL --retry 3 "https://github.com/$repo/releases/expanded_assets/$tag" \
             | grep -o 'href="/[^"]*/releases/download/[^"]*"' | sed 's/^href="//;s/"$//')
  echo "no file matching /$re/ in $repo ($tag)" >&2; return 1
}
extract() {      # extract ARCHIVE DIR   (returns 2 if not an archive)
  case "$1" in
    *.tar.gz|*.tgz)  tar -xzf "$1" -C "$2" ;;
    *.tar.xz|*.txz)  tar -xJf "$1" -C "$2" ;;
    *.tar.bz2|*.tbz) tar -xjf "$1" -C "$2" ;;
    *.zip) if command -v unzip >/dev/null; then unzip -q -o "$1" -d "$2"
           else python3 -m zipfile -e "$1" "$2"; fi ;;
    *) return 2 ;;
  esac
}
check_runs() {   # does the binary actually start? (glibc, noexec...)
  "$1" --version >/dev/null 2>&1 || "$1" version >/dev/null 2>&1 || "$1" -V >/dev/null 2>&1
}
# install_bin URL "name_in_archive[:final_name]"...   (name can be a glob)
install_bin() {
  local url=$1; shift
  local base=${url##*/} f d spec src dst path rc
  f="$WORK/dl/$base"; d="$WORK/x/$base"
  echo "download: $url"
  download "$url" "$f" || return 1
  rm -rf "$d"; mkdir -p "$d"
  extract "$f" "$d"; rc=$?
  if [ $rc -eq 2 ]; then cp "$f" "$d/$base"; elif [ $rc -ne 0 ]; then return 1; fi
  for spec in "$@"; do
    src=${spec%%:*}; dst=${spec##*:}; [ "$src" = "$spec" ] && dst=${src}
    path=$(find "$d" -type f -name "$src" | head -1)
    [ -n "$path" ] || { echo "'$src' not found in $base" >&2; return 1; }
    install -m 755 "$path" "$BIN/$dst" || return 1
    record "$BIN/$dst"
  done
  rm -rf "$d" "$f"
}
install_gh() {   # install_gh owner/repo REGEX spec...
  local repo=$1 re=$2 url first; shift 2
  url=$(gh_asset "$repo" "$re") || return 1
  install_bin "$url" "$@" || return 1
  first=${1##*:}; check_runs "$BIN/$first"
}
# System libraries missing for the programs of an extracted AppImage
missing_libs() {
  local d=$1 lp b
  command -v ldd >/dev/null || return 0
  lp=$(find "$d" -name '*.so*' \( -type f -o -type l \) -printf '%h\n' 2>/dev/null | sort -u | paste -sd:)
  for b in "$d"/usr/bin/*; do
    [ -f "$b" ] && [ -x "$b" ] || continue
    head -c4 "$b" | grep -q ELF || continue
    LD_LIBRARY_PATH="$lp" ldd "$b" 2>/dev/null | awk '/not found/{print $1}'
  done | sort -u | paste -sd' '
}
# AppImage: extracted (no FUSE needed), launcher in ~/.local/bin
appimage() {     # appimage URL_or_FILE NAME [COMMAND]
  local src=$1 name=$2 cmd=${3:-$2} f
  f="$WORK/dl/$name.AppImage"
  if [ -f "$src" ]; then cp "$src" "$f"; else download "$src" "$f" || return 1; fi
  chmod +x "$f"
  rm -rf "${WORK:?}/squashfs-root" "${OPT:?}/${name:?}"
  (cd "$WORK" && "$f" --appimage-extract >/dev/null) || return 1
  mv "$WORK/squashfs-root" "$OPT/$name"
  rm -f "$f"
  local m; m=$(missing_libs "$OPT/$name")
  if [ -n "$m" ]; then
    rm -rf "${OPT:?}/${name:?}"
    REASON="missing system libraries: $m (ask the IT team)"; echo "$REASON"; return 1
  fi
  # a small script, not a symlink: some AppRun look for files next to themselves
  printf '#!/bin/sh\nexec "%s/AppRun" "$@"\n' "$OPT/$name" >"$BIN/$cmd"; chmod +x "$BIN/$cmd"
  record "$OPT/$name"; record "$BIN/$cmd"
}
desktop_entry() {  # desktop_entry ID "Name" "Command" "Icon" "Categories"
  local file="$SHR/applications/$NAME-$1.desktop"
  mkdir -p "$SHR/applications"
  cat >"$file" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=$4
Categories=$5
Terminal=false
EOF
  record "$file"
}
appimage_icon() { readlink -f "$OPT/$1/.DirIcon" 2>/dev/null || echo "$1"; }

# Delimited block in a config file (replaced on each run)
add_block() {    # add_block FILE CONTENT [COMMENT_START] [COMMENT_END]
  local f=$1 content=$2 c=${3:-#} end=${4:+ $4} tmp
  if [ -f "$f" ] && [ ! -f "$f$BAK" ]; then cp "$f" "$f$BAK"; fi
  [ -e "$f" ] || printf 'created:%s\n' "$f" >>"$MANIFEST"
  tmp=$(mktemp "$WORK/block.XXXXXX")
  [ -f "$f" ] && awk -v d="$c $MARK_BEGIN$end" -v e="$c $MARK_END$end" \
    '$0==d{s=1;next} $0==e{s=0;next} !s' "$f" >"$tmp"
  printf '%s %s%s\n%s\n%s %s%s\n' "$c" "$MARK_BEGIN" "$end" "$content" "$c" "$MARK_END" "$end" >>"$tmp"
  cat "$tmp" >"$f"; rm -f "$tmp"
}
remove_block() { # remove_block FILE [COMMENT_START] [COMMENT_END]
  local f=$1 c=${2:-#} end=${3:+ $3} tmp
  [ -f "$f" ] || return 0
  tmp=$(mktemp "$WORK/block.XXXXXX")
  awk -v d="$c $MARK_BEGIN$end" -v e="$c $MARK_END$end" '$0==d{s=1;next} $0==e{s=0;next} !s' "$f" >"$tmp"
  cat "$tmp" >"$f"; rm -f "$tmp"
}
# Is the command provided by the system (outside ~/.local/bin)?
system_has() {
  local p="" d
  local IFS=:
  for d in $PATH; do [ "$d" = "$BIN" ] || p="$p:$d"; done
  PATH="${p#:}" command -v "$1" >/dev/null 2>&1
}
# Was this file written by this script (or by its old version)?
managed() { [ -f "$1" ] && head -1 "$1" | grep -qE "$NAME|kit-etudiant"; }

# =============================================================================
#  STEPS
# =============================================================================
step_prep() {
  title "Preparation"
  mkdir -p "$BIN" "$OPT" "$SHR/applications" "$CFG" "$WORK/dl" "$WORK/x"
  add_block "$HOME/.profile" \
'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
  ok "folders created, ~/.local/bin added to PATH (~/.profile)"
}

# ---- Command line tools ------------------------------------------------------
tldr_pages() {   # tldr --update, with a fallback if the network intercepts TLS
  "$BIN/tldr" --update && return 0
  echo "fallback: downloading the pages directly"
  local l p="$HOME/.cache/tealdeer/tldr-pages" f
  for l in en fr; do
    f="$WORK/dl/tldr-$l.zip"
    download "https://github.com/tldr-pages/tldr/releases/latest/download/tldr-pages.$l.zip" "$f" || return 1
    rm -rf "$p/pages.$l"; mkdir -p "$p/pages.$l"; extract "$f" "$p/pages.$l" || return 1; rm -f "$f"
  done
  "$BIN/tldr" tar >/dev/null
}
step_cli() {
  title "Command line tools"
  #     Name       GitHub repo               File (regex)                             Binary[:name]
  local L=(
    "ripgrep   BurntSushi/ripgrep         x86_64-unknown-linux-musl\.tar\.gz$       rg"
    "fd        sharkdp/fd                 x86_64-unknown-linux-musl\.tar\.gz$       fd"
    "bat       sharkdp/bat                x86_64-unknown-linux-musl\.tar\.gz$       bat"
    "eza       eza-community/eza          ^eza_x86_64-unknown-linux-musl\.tar\.gz$  eza"
    "delta     dandavison/delta           x86_64-unknown-linux-musl\.tar\.gz$       delta"
    "lazygit   jesseduffield/lazygit      _linux_x86_64\.tar\.gz$                   lazygit"
    "jq        jqlang/jq                  ^jq-linux-amd64$                          jq-linux-amd64:jq"
    "yazi      sxyazi/yazi                ^yazi-x86_64-unknown-linux-musl\.zip$     yazi ya"
    "gh        cli/cli                    _linux_amd64\.tar\.gz$                    gh"
    "glow      charmbracelet/glow         _Linux_x86_64\.tar\.gz$                   glow"
    "watchexec watchexec/watchexec        x86_64-unknown-linux-musl\.tar\.xz$       watchexec"
    "hyperfine sharkdp/hyperfine          x86_64-unknown-linux-musl\.tar\.gz$       hyperfine"
    "duf       muesli/duf                 _linux_x86_64\.tar\.gz$                   duf"
    "sd        chmln/sd                   x86_64-unknown-linux-musl\.tar\.gz$       sd"
    "btop      aristocratos/btop          ^btop-x86_64-.*linux-musl\.tar\.gz$       btop"
    "gdu       dundee/gdu                 ^gdu_linux_amd64_static\.tgz$             gdu_linux_amd64_static:gdu"
    "direnv    direnv/direnv              ^direnv\.linux-amd64$                     direnv.linux-amd64:direnv"
    "chezmoi   twpayne/chezmoi            ^chezmoi-linux-amd64-musl$                chezmoi-linux-amd64-musl:chezmoi"
    "croc      schollz/croc               _Linux-64bit\.tar\.gz$                    croc"
    "rclone    rclone/rclone              -linux-amd64\.zip$                        rclone"
    "tldr      tealdeer-rs/tealdeer       ^tealdeer-linux-x86_64-musl$              tealdeer-linux-x86_64-musl:tldr"
  )
  local line name repo re specs final
  for line in "${L[@]}"; do
    read -r name repo re specs <<<"$line"
    final=${specs%% *}; final=${final##*:}
    # shellcheck disable=SC2086
    tool "$name" "$BIN/$final" install_gh "$repo" "$re" $specs
  done
  [ -x "$BIN/tldr" ] && tool "tldr pages (French + English)" "$HOME/.cache/tealdeer/tldr-pages" tldr_pages
}

# ---- zsh + oh-my-zsh + powerlevel10k ----------------------------------------
install_zsh() {  # zsh-bin: static, relocatable zsh (by the author of powerlevel10k)
  local f="$WORK/dl/zsh-bin-install" man_before=0 terminfo_before=0
  [ -d "$PREFIX/man" ] && man_before=1
  [ -d "$SHR/terminfo" ] && terminfo_before=1
  download https://raw.githubusercontent.com/romkatv/zsh-bin/master/install "$f" || return 1
  sh "$f" -q -d "$PREFIX" -e no || return 1
  record "$BIN/zsh"; record "$SHR/zsh"
  local z; for z in "$BIN"/zsh-*; do [ -e "$z" ] && record "$z"; done
  for z in "$SHR"/man/man1/zsh*; do [ -e "$z" ] && record "$z"; done
  [ $man_before -eq 0 ] && [ -d "$PREFIX/man" ] && record "$PREFIX/man"
  [ $terminfo_before -eq 0 ] && [ -d "$SHR/terminfo" ] && record "$SHR/terminfo"
  "$BIN/zsh" --version
}
install_fzf() {
  local new=0
  if [ -d "$HOME/.fzf/.git" ]; then git -C "$HOME/.fzf" pull -q --ff-only || return 1
  else git clone -q --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" || return 1; new=1; fi
  "$HOME/.fzf/install" --bin || return 1
  ln -sfn "$HOME/.fzf/bin/fzf" "$BIN/fzf"
  [ $new -eq 1 ] && record "$HOME/.fzf"
  record "$BIN/fzf"; "$BIN/fzf" --version
}
clone() {        # clone owner/repo DIR: clone, or pull with --update
  if [ -d "$2/.git" ]; then
    [ "$UPDATE" -eq 1 ] && { git -C "$2" pull -q --ff-only || return 1; }
    return 0
  fi
  git clone -q --depth 1 "https://github.com/$1.git" "$2" || return 1
  record "$2"
}
setup_p10k() {   # my home config if given, otherwise the "rainbow" style
  if [ -n "$P10K_SRC" ]; then
    cp "$P10K_SRC" "$HOME/.p10k.zsh" || return 1
    echo "powerlevel10k config copied from $P10K_SRC (personal file: never removed)"
    return 0
  elif [ -f "$HOME/.p10k.zsh" ]; then
    echo "~/.p10k.zsh already there: kept"; return 0
  else
    cp "$ZCUSTOM/themes/powerlevel10k/config/p10k-rainbow.zsh" "$HOME/.p10k.zsh" || return 1
    echo "default rainbow style (change it with: p10k configure)"
  fi
  record "$HOME/.p10k.zsh"
}
# My home plugin list (~/.zsh-plugins), used when --home is not given
default_plugins() {
  printf '%s\n' you-should-use git autojump fancy-ctrl-z command-not-found colored-man-pages \
    common-aliases copybuffer copyfile dirhistory history web-search sudo zsh-bat \
    zsh-syntax-highlighting zsh-autosuggestions thefuck
}
read_plugins() { # reads "plugins=( ... )" from a file
  sed -n '/plugins=(/,/)/p' "$1" | sed 's/#.*//; s/plugins=(//; s/)//' | tr -s ' \t' '\n\n' | grep -v '^$'
}
write_plugins() {  # writes plugins.zsh (each plugin only if it can work)
  local p list fzf_seen=0
  if [ -n "$ARCHIVE_DIR" ] && [ -f "$ARCHIVE_DIR/zsh/zsh-plugins" ]; then list=$(read_plugins "$ARCHIVE_DIR/zsh/zsh-plugins")
  elif [ -n "$ARCHIVE_DIR" ] && [ -f "$ARCHIVE_DIR/zsh/zshrc" ]; then list=$(read_plugins "$ARCHIVE_DIR/zsh/zshrc")
  else list=$(default_plugins); fi
  {
    echo "# oh-my-zsh plugins (same list as at home). Rewritten on each install."
    echo 'plugins=()'
    while read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        autojump) echo '# autojump needs root: zoxide instead ("z dir" or "j dir")'
                  echo '(( $+commands[zoxide] )) && plugins+=(zoxide)' ;;
        fzf) fzf_seen=1; echo '(( $+commands[fzf] )) && plugins+=(fzf)' ;;
        thefuck|zoxide|direnv) printf '(( $+commands[%s] )) && plugins+=(%s)\n' "$p" "$p" ;;
        zsh-bat) echo '(( $+commands[bat] )) && plugins+=(zsh-bat)' ;;
        *) printf '[[ -d $ZSH/plugins/%s || -d $ZSH/custom/plugins/%s ]] && plugins+=(%s)\n' "$p" "$p" "$p" ;;
      esac
    done <<<"$list"
    [ $fzf_seen -eq 1 ] || { echo '# fzf (loaded by ~/.fzf.zsh at home)'; echo '(( $+commands[fzf] )) && plugins+=(fzf)'; }
  } >"$CFG/plugins.zsh"
  grep -c 'plugins+=' "$CFG/plugins.zsh"
}
step_zsh() {
  title "zsh + oh-my-zsh + powerlevel10k"
  tool "zsh (zsh-bin, no root)" "$BIN/zsh" install_zsh
  tool "fzf" "$BIN/fzf" install_fzf
  tool "zoxide" "$BIN/zoxide" install_gh ajeetdsouza/zoxide 'x86_64-unknown-linux-musl\.tar\.gz$' zoxide
  run "oh-my-zsh" clone ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh" || return
  run "powerlevel10k theme" clone romkatv/powerlevel10k "$ZCUSTOM/themes/powerlevel10k"
  run "zsh-autosuggestions" clone zsh-users/zsh-autosuggestions "$ZCUSTOM/plugins/zsh-autosuggestions"
  run "zsh-syntax-highlighting" clone zsh-users/zsh-syntax-highlighting "$ZCUSTOM/plugins/zsh-syntax-highlighting"
  run "you-should-use" clone MichaelAquilina/zsh-you-should-use "$ZCUSTOM/plugins/you-should-use"
  run "zsh-bat" clone fdellwing/zsh-bat "$ZCUSTOM/plugins/zsh-bat"
  run "powerlevel10k config (~/.p10k.zsh)" setup_p10k
}

# ---- Shell, C, Python, conda tools ------------------------------------------
install_bats() {
  local d="$WORK/x/bats"
  rm -rf "$d"; git clone -q --depth 1 https://github.com/bats-core/bats-core.git "$d" || return 1
  "$d/install.sh" "$PREFIX" || return 1
  record "$BIN/bats"; record "$PREFIX/libexec/bats-core"; record "$PREFIX/lib/bats-core"
  record "$SHR/man/man1/bats.1"; record "$SHR/man/man7/bats.7"
  rm -rf "$d"; "$BIN/bats" --version
}
step_shell_tools() {
  title "Shell scripts: shellcheck, shfmt, bats"
  tool shellcheck "$BIN/shellcheck" install_gh koalaman/shellcheck 'linux\.x86_64\.tar\.xz$' shellcheck
  tool shfmt "$BIN/shfmt" install_gh mvdan/sh '^shfmt_v.*_linux_amd64$' 'shfmt_v*_linux_amd64:shfmt'
  tool "bats-core (bash tests)" "$BIN/bats" install_bats
}
step_c_tools() {
  title "C: gdb-dashboard"
  tool "gdb-dashboard" "$HOME/.gdb-dashboard" bash -c \
    "curl -fsSL https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/master/.gdbinit -o '$HOME/.gdb-dashboard' && echo '$HOME/.gdb-dashboard' >>'$MANIFEST'"
}

uv_tool() {      # uv_tool PACKAGE [PYTHON_VERSION]: install it and link its commands into ~/.local/bin
  local p=$1 py=${2:-} e target td n=0
  td=$("$BIN/uv" tool dir) || return 1
  UV_TOOL_BIN_DIR="$OPT/uv-bin" "$BIN/uv" tool install --upgrade ${py:+--python "$py"} "$p" || return 1
  record "$OPT/uv-bin"; record "$td/$p"
  for e in "$OPT/uv-bin"/*; do
    target=$(readlink -f "$e")
    case "$target" in "$td/$p/"*) ln -sfn "$e" "$BIN/${e##*/}"; record "$BIN/${e##*/}"; n=$((n + 1)) ;; esac
  done
  echo "$n command(s) linked for $p"; [ "$n" -gt 0 ]
}
step_python() {
  title "Python: uv + tools"
  tool "uv (Python tool manager)" "$BIN/uv" install_gh astral-sh/uv '^uv-x86_64-unknown-linux-musl\.tar\.gz$' uv uvx
  record "$HOME/.cache/uv"
  [ -x "$BIN/uv" ] || { fail "Python tools" "uv missing"; return; }
  local td; td=$("$BIN/uv" tool dir 2>/dev/null)
  tool "trash-cli (trash bin)" "$td/trash-cli" uv_tool trash-cli
  tool clang-format "$td/clang-format" uv_tool clang-format
  tool clang-tidy "$td/clang-tidy" uv_tool clang-tidy
  tool "thefuck (fixes the last command)" "$td/thefuck" uv_tool thefuck 3.11
  record "$HOME/.local/share/uv/python"
  record "$HOME/.local/share/uv"
}

conda_env() {
  local pk=(valgrind gdb cppcheck bear tmux check pkg-config nodejs xclip)
  if [ -d "$MAMBA_ROOT/envs/outils" ]; then
    "$MM" -r "$MAMBA_ROOT" install -y -n outils -c conda-forge --override-channels "${pk[@]}" || return 1
    [ "$UPDATE" -eq 1 ] && { "$MM" -r "$MAMBA_ROOT" update -y -n outils --all || return 1; }
  else
    "$MM" -r "$MAMBA_ROOT" create -y -n outils -c conda-forge --override-channels "${pk[@]}" || return 1
  fi
  "$MM" -r "$MAMBA_ROOT" clean -a -y
}
conda_links() {  # the system keeps priority: only link what is missing
  local e="$MAMBA_ROOT/envs/outils/bin" b
  for b in valgrind vgdb gdb gdbserver cppcheck bear tmux node npm npx checkmk xclip; do
    [ -e "$e/$b" ] || continue
    if system_has "$b"; then echo "$b: system version kept"; continue; fi
    ln -sfn "$e/$b" "$BIN/$b"; record "$BIN/$b"
  done
}
step_conda() {
  title "micromamba: valgrind, gdb, cppcheck, bear, tmux, check, node"
  if system_has micromamba; then
    info "this PC already has a micromamba: using a separate one in ~/.local/opt, without a micromamba command"
  fi
  tool micromamba "$OPT/micromamba/micromamba" bash -c "
    mkdir -p '$OPT/micromamba' && curl -fsSL -o '$OPT/micromamba/micromamba' \
      https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-linux-64 \
    && chmod +x '$OPT/micromamba/micromamba' && echo '$OPT/micromamba' >>'$MANIFEST'"
  # no "micromamba" link in ~/.local/bin: never hide the one of the PC
  [ -x "$OPT/micromamba/micromamba" ] || { fail "tools environment" "micromamba missing"; return; }
  record "$MAMBA_ROOT"; record "$HOME/.mamba"
  run "\"outils\" environment (conda-forge)" conda_env || return
  run "links in ~/.local/bin (when missing from the system)" conda_links
}

# ---- Neovim + LazyVim --------------------------------------------------------
install_nvim() {
  local url f="$WORK/dl/nvim.tar.gz"
  url=$(gh_asset neovim/neovim '^nvim-linux-x86_64\.tar\.gz$') || return 1
  download "$url" "$f" || return 1
  rm -rf "$OPT/nvim"; mkdir -p "$OPT/nvim"
  tar -xzf "$f" -C "$OPT/nvim" --strip-components=1 || return 1
  ln -sfn "$OPT/nvim/bin/nvim" "$BIN/nvim"
  record "$OPT/nvim"; record "$BIN/nvim"; rm -f "$f"
  "$BIN/nvim" --version | head -1
}
nvim_marker() {
  echo "Created by $NAME.sh. Rewritten on each install: lazyvim.json, lua/plugins/$NAME.lua, lua/config/options.lua. Everything else is mine." \
    >"$NVIM_CFG/.$NAME"
}
setup_lazyvim() {
  if [ ! -f "$NVIM_CFG/.$NAME" ]; then
    if [ -e "$NVIM_CFG" ]; then
      [ -e "$NVIM_CFG$BAK" ] || mv "$NVIM_CFG" "$NVIM_CFG$BAK"
      echo "old Neovim config moved to $NVIM_CFG$BAK"
      rm -rf "$NVIM_CFG"
    fi
    git clone -q --depth 1 https://github.com/LazyVim/starter "$NVIM_CFG" || return 1
    rm -rf "$NVIM_CFG/.git"
    nvim_marker
  fi
  mkdir -p "$NVIM_CFG/lua/plugins" "$NVIM_CFG/lua/config"
  # no background update checks (slow on a network home)
  [ -f "$NVIM_CFG/lua/config/lazy.lua" ] && sed -i \
    -e 's/enabled = true, -- check for plugin updates periodically/enabled = false, -- no automatic update checks/' \
    -e 's/enabled = false, -- kit-etudiant : pas de vérification automatique/enabled = false, -- no automatic update checks/' \
    "$NVIM_CFG/lua/config/lazy.lua"
  cat >"$NVIM_CFG/lazyvim.json" <<'JSON'
{
  "extras": [
    "lazyvim.plugins.extras.coding.yanky",
    "lazyvim.plugins.extras.dap.core",
    "lazyvim.plugins.extras.lang.clangd"
  ],
  "install_version": 8,
  "news": { "NEWS.md": "0" },
  "version": 8
}
JSON
  # Mason registry pinned to a version: no GitHub API calls (rate limited on the school network).
  # --update moves to the latest version.
  local reg=""
  [ "$UPDATE" -eq 0 ] && reg=$(sed -n 's/.*mason-registry@\([^"]*\)".*/\1/p' "$NVIM_CFG/lua/plugins/$NAME.lua" 2>/dev/null | head -1)
  [ -n "$reg" ] || reg=$(gh_tag mason-org/mason-registry)
  local reg_line="-- default registry"
  [ -n "$reg" ] && reg_line="opts.registries = { \"github:mason-org/mason-registry@$reg\" }"
  cat >"$NVIM_CFG/lua/plugins/$NAME.lua" <<LUA
-- Managed by $NAME.sh (rewritten on each install). My plugins: lua/plugins/perso.lua
return {
  -- Bash: bashls only if npm can install it
  { "neovim/nvim-lspconfig", opts = function(_, opts)
      opts.servers = opts.servers or {}
      if vim.fn.executable("npm") == 1 or vim.fn.executable("bash-language-server") == 1 then
        opts.servers.bashls = {}
      end
    end },
  -- shellcheck runs once: through bashls, or through nvim-lint when bashls is missing
  { "mfussenegger/nvim-lint", opts = function(_, opts)
      if vim.fn.executable("npm") == 0 and vim.fn.executable("bash-language-server") == 0 then
        opts.linters_by_ft = opts.linters_by_ft or {}
        opts.linters_by_ft.sh = { "shellcheck" }
        opts.linters_by_ft.bash = { "shellcheck" }
      end
    end },
  -- Mason: pinned registry, add shellcheck, remove duplicates
  { "mason-org/mason.nvim", opts = function(_, opts)
      ${reg_line}
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "shellcheck")
      local seen, unique = {}, {}
      for _, t in ipairs(opts.ensure_installed) do
        if not seen[t] then seen[t] = true; table.insert(unique, t) end
      end
      opts.ensure_installed = unique
    end },
  -- Classic command line and messages at the bottom
  { "folke/noice.nvim", opts = { cmdline = { enabled = false }, messages = { enabled = false } } },
}
LUA
  cat >"$NVIM_CFG/lua/config/options.lua" <<'LUA'
-- Managed by exported-home-config.sh (rewritten on each install). My options: lua/config/perso.lua
vim.opt.relativenumber = false
vim.opt.scrolloff = 5

-- Swap files on the local disk instead of the network home (private folder)
local swap = "/tmp/" .. (vim.env.USER or "me") .. "-nvim-swap"
if vim.fn.isdirectory(swap) == 0 then vim.fn.mkdir(swap, "p", tonumber("700", 8)) end
vim.opt.directory = swap .. "//"

pcall(require, "config.perso")
LUA
  rm -f "$NVIM_CFG/lua/config/kit_raccourcis.lua"
  [ -f "$NVIM_CFG/lua/config/perso.lua" ] || printf -- '-- My Neovim options (never overwritten)\n' >"$NVIM_CFG/lua/config/perso.lua"
  [ -f "$NVIM_CFG/lua/plugins/perso.lua" ] || printf -- '-- My Neovim plugins (never overwritten)\nreturn {}\n' >"$NVIM_CFG/lua/plugins/perso.lua"
  return 0
}
nvim_plugins() {
  if [ "$UPDATE" -eq 1 ]; then timeout 900 "$BIN/nvim" --headless "+Lazy! sync" +qa
  else timeout 900 "$BIN/nvim" --headless "+Lazy! install" +qa; fi
  local n; n=$(find "$HOME/.local/share/nvim/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  echo "Neovim plugins installed: $n"
  record "$HOME/.local/share/nvim"; record "$HOME/.local/state/nvim"; record "$HOME/.cache/nvim"
  [ "$n" -ge 20 ]
}
nvim_mason() {   # install the Mason tools and wait (otherwise nvim --headless quits too early)
  local tools="clangd codelldb shellcheck shfmt stylua tree-sitter-cli"
  command -v npm >/dev/null && tools="$tools bash-language-server"
  cat >"$WORK/mason.lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim" } })
local reg = require("mason-registry")
pcall(reg.refresh)
-- let LazyVim start its own installs first (avoids "Package is already installing")
vim.wait(4000, function() return false end, 100)
local names = vim.split(vim.env.EHC_MASON or "", " ", { trimempty = true })
for _, n in ipairs(names) do
  local ok, p = pcall(reg.get_package, n)
  if not ok then io.stdout:write("unknown package: " .. n .. "\n")
  elseif not p:is_installed() and not p:is_installing() then pcall(function() p:install() end) end
end
vim.wait(900000, function()
  for _, p in ipairs(reg.get_all_packages()) do if p:is_installing() then return false end end
  return true
end, 1000)
for _, n in ipairs(names) do
  local ok, p = pcall(reg.get_package, n)
  io.stdout:write(n .. ": " .. ((ok and p:is_installed()) and "OK" or "FAILED") .. "\n")
end
LUA
  [ -f /etc/ssl/certs/ca-certificates.crt ] && export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
  EHC_MASON="$tools" npm_config_cache="$HOME/.npm" timeout 1200 "$BIN/nvim" --headless "+luafile $WORK/mason.lua" +qa
  record "$HOME/.npm"
  local o missing=""
  for o in clangd codelldb shellcheck shfmt; do [ -e "$HOME/.local/share/nvim/mason/bin/$o" ] || missing="$missing $o"; done
  [ -z "$missing" ] || { REASON="Mason tools missing:$missing (run the script again)"; return 1; }
}
nvim_parsers() { # compile the syntax parsers (C, bash...) and wait
  cat >"$WORK/ts.lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
local ok, ts = pcall(require, "nvim-treesitter")
local langs = vim.split(vim.env.EHC_TS or "c bash", " ", { trimempty = true })
if ok and type(ts.install) == "function" then
  local task = ts.install(langs)
  if task and task.wait then task:wait(600000) end
else
  vim.cmd("TSInstallSync " .. table.concat(langs, " "))
end
local dir = vim.fn.stdpath("data") .. "/site/parser/"
local broken = 0
for _, l in ipairs(langs) do
  local good = pcall(vim.treesitter.query.get, l, "highlights")
  if not good then broken = broken + 1 end
  io.stdout:write(l .. ": " .. (vim.uv.fs_stat(dir .. l .. ".so") and (good and "OK" or "BROKEN QUERIES") or "FAILED") .. "\n")
end
if broken > 0 then os.exit(1) end
LUA
  EHC_TS="c cpp bash make markdown markdown_inline lua vim vimdoc regex query diff printf" \
    timeout 900 "$BIN/nvim" --headless "+luafile $WORK/ts.lua" +qa
  [ -e "$HOME/.local/share/nvim/site/parser/c.so" ]
}
step_neovim() {
  title "Neovim + LazyVim"
  tool "Neovim" "$BIN/nvim" install_nvim
  [ -x "$BIN/nvim" ] || { fail "LazyVim" "Neovim missing"; return; }
  run "LazyVim config (~/.config/nvim)" setup_lazyvim || return
  run "LazyVim plugins (first time: a few minutes)" nvim_plugins
  tool "Mason tools (clangd, codelldb, shellcheck, shfmt, bashls)" "$HOME/.local/share/nvim/mason/bin/clangd" nvim_mason
  if [ "$UPDATE" -eq 1 ] || [ ! -e "$HOME/.local/share/nvim/site/parser/c.so" ]; then
    run "syntax parsers (C, bash...)" nvim_parsers \
      || info "the parsers will compile the first time nvim starts (wait about 1 minute)"
  fi
  command -v npm >/dev/null || info "node missing: no bash language server in Neovim (shellcheck still works)"
}

# ---- tmux --------------------------------------------------------------------
step_tmux() {
  title "tmux: config + plugins"
  local p="$HOME/.tmux/plugins" r
  mkdir -p "$p"
  for r in tpm tmux-sensible tmux-resurrect; do
    run "$r" clone "tmux-plugins/$r" "$p/$r"
  done
  if [ -f "$HOME/.tmux.conf" ] && ! managed "$HOME/.tmux.conf"; then
    if [ -f "$HOME/.tmux.conf$BAK" ]; then
      info "personal ~/.tmux.conf (no $NAME header): left as is"; return 0
    fi
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf$BAK"
  fi
  write_tmux_conf
  ok "~/.tmux.conf (Ctrl-b | and Ctrl-b - to split)"
}
write_tmux_conf() {
  {
    cat <<TMUX
# Managed by $NAME.sh. My settings: ~/.tmux.perso.conf
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
setw -g mode-keys vi
set -sg escape-time 10
set -g focus-events on
set -g default-terminal "tmux-256color"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "config reloaded"
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
TMUX
    [ -x "$BIN/zsh" ] && printf 'set -g default-shell "%s"\n' "$BIN/zsh"
    printf '%s\n' "if-shell 'test -f ~/.tmux.perso.conf' 'source-file ~/.tmux.perso.conf'" "run -b '~/.tmux/plugins/tpm/tpm'"
  } >"$HOME/.tmux.conf"
}

# ---- Config files ------------------------------------------------------------
write_zshrc() {
  if [ -f "$HOME/.zshrc" ] && ! managed "$HOME/.zshrc"; then
    [ -f "$HOME/.zshrc$BAK" ] || cp "$HOME/.zshrc" "$HOME/.zshrc$BAK"
    echo "old ~/.zshrc saved as ~/.zshrc$BAK"
  fi
  cat >"$HOME/.zshrc" <<'ZSHRC'
# Managed by exported-home-config.sh (delete this line to keep your own version)
# My additions: ~/.config/exported-home-config/perso.zsh

# Powerlevel10k instant prompt (keep at the top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

typeset -U path PATH
path=("$HOME/.local/bin" $path)
[[ -x "$HOME/.local/bin/zsh" ]] && export SHELL="$HOME/.local/bin/zsh"
export EDITOR=nvim VISUAL=nvim

# ---- oh-my-zsh ----
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
zstyle ':omz:update' mode disabled
HIST_STAMPS="dd/mm/yyyy"
HISTSIZE=50000
SAVEHIST=50000
source "$HOME/.config/exported-home-config/plugins.zsh"
source "$ZSH/oh-my-zsh.sh"

# ---- Aliases ----
alias vim=nvim vi=nvim
(( $+commands[zoxide] ))    && alias j=z
(( $+commands[eza] ))       && alias lt='eza --tree --level=2 --icons=auto'
(( $+commands[lazygit] ))   && alias lg=lazygit
(( $+commands[gedit] )) || { (( $+commands[xed] )) && alias gedit=xed; }
(( $+commands[trash-put] )) && alias tp=trash-put
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# ---- C: crun, csan, cmem, cdebug ----
# -D_DEFAULT_SOURCE: makes strdup, getline... visible with -std=c11
export CC=gcc
CFLAGS_DEV="-std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -g"
CFLAGS_SAN="$CFLAGS_DEV -O0 -fsanitize=address,undefined -fno-omit-frame-pointer"
LDLIBS_DEV="-lm"
_c_build() {  # _c_build "flags" file.c
  [[ -f $2 ]] || { print -u2 "Usage: ${funcstack[2]} file.c [args]"; return 1; }
  $CC ${=1} "$2" -o "${2%.c}" ${=LDLIBS_DEV}
}
_c_bin() { [[ $1 == /* ]] && print -r -- "${1%.c}" || print -r -- "./${1%.c}"; }
crun()   { _c_build "$CFLAGS_DEV" "${1-}" || return; local b=$(_c_bin "$1"); shift; "$b" "$@"; }
csan()   { _c_build "$CFLAGS_SAN" "${1-}" || return; local b=$(_c_bin "$1"); shift; "$b" "$@"; }
cmem()   { _c_build "$CFLAGS_DEV" "${1-}" || return; local b=$(_c_bin "$1"); shift; valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes "$b" "$@"; }
cdebug() { _c_build "$CFLAGS_DEV" "${1-}" || return; local b=$(_c_bin "$1"); shift; gdb -q --args "$b" "$@"; }

# ---- Personal settings, then prompt ----
[[ -f "$HOME/.config/exported-home-config/perso.zsh" ]] && source "$HOME/.config/exported-home-config/perso.zsh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
ZSHRC
}
write_bashrc() {  # bash fallback (ssh, scripts): same aliases and C commands
  cat >"$CFG/bashrc.sh" <<'BASHRC'
# Bash fallback, loaded from ~/.bashrc. Main shell is zsh: type "zsh".
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
case $- in *i*) ;; *) return 0 ;; esac
command -v nvim >/dev/null && { alias vim=nvim vi=nvim; export EDITOR=nvim VISUAL=nvim; }
HISTSIZE=50000; HISTFILESIZE=100000; HISTCONTROL=ignoreboth:erasedups
shopt -s histappend autocd cdspell globstar checkwinsize
[ -f "$HOME/.fzf/shell/key-bindings.bash" ] && . "$HOME/.fzf/shell/key-bindings.bash"
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v eza >/dev/null && alias ll='eza -la --git --group-directories-first' lt='eza --tree --level=2'
command -v lazygit >/dev/null && alias lg=lazygit
command -v gedit >/dev/null || { command -v xed >/dev/null && alias gedit=xed; }
command -v trash-put >/dev/null && alias tp=trash-put

# C: crun, csan, cmem, cdebug
export CC=gcc
CFLAGS_DEV="-std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -g"
CFLAGS_SAN="$CFLAGS_DEV -O0 -fsanitize=address,undefined -fno-omit-frame-pointer"
LDLIBS_DEV="-lm"
# shellcheck disable=SC2086
_c_build() { [ -f "$2" ] || { echo "Usage: ${FUNCNAME[1]} file.c [args]" >&2; return 1; }; $CC $1 "$2" -o "${2%.c}" $LDLIBS_DEV; }
_c_bin() { case $1 in /*) echo "${1%.c}" ;; *) echo "./${1%.c}" ;; esac; }
crun()   { _c_build "$CFLAGS_DEV" "${1-}" || return; local b; b=$(_c_bin "$1"); shift; "$b" "$@"; }
csan()   { _c_build "$CFLAGS_SAN" "${1-}" || return; local b; b=$(_c_bin "$1"); shift; "$b" "$@"; }
cmem()   { _c_build "$CFLAGS_DEV" "${1-}" || return; local b; b=$(_c_bin "$1"); shift; valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes "$b" "$@"; }
cdebug() { _c_build "$CFLAGS_DEV" "${1-}" || return; local b; b=$(_c_bin "$1"); shift; gdb -q --args "$b" "$@"; }
BASHRC
  add_block "$HOME/.bashrc" '[ -f "$HOME/.config/exported-home-config/bashrc.sh" ] && . "$HOME/.config/exported-home-config/bashrc.sh"'
}
write_gdbinit() {
  add_block "$HOME/.gdbinit" 'set history save on
set history filename ~/.gdb_history
set print pretty on
set disassembly-flavor intel
define dash
  source ~/.gdb-dashboard
end
document dash
Show gdb-dashboard (source, variables, stack). Type: dash
end'
}
git_default() {  # git_default KEY VALUE: only if not already set by me
  if [ -z "$(git config --global --get "$1" 2>/dev/null)" ]; then
    git config --global "$1" "$2" && printf 'git:%s\n' "$1" >>"$MANIFEST"
  fi
}
setup_git() {
  command -v git >/dev/null || return 1
  git_default alias.lg "log --oneline --graph --decorate --all"
  git_default init.defaultBranch main
  if [ -x "$BIN/delta" ]; then
    git_default core.pager delta
    git_default interactive.diffFilter "delta --color-only"
    git_default delta.navigate true
    git_default delta.line-numbers true
  fi
}
write_templates() {  # C project template + cnew command
  local m="$CFG/templates/c-project"
  rm -rf "$CFG/templates"; mkdir -p "$m/src" "$m/tests"
  cat >"$m/Makefile" <<'MAKE'
#   make          build (ASan + UBSan)       make run       build and run
#   make test     unit tests (Check)         make valgrind  memory leaks (without ASan)
#   make analyse  gcc -fanalyzer             make check     cppcheck
#   make tidy     clang-tidy                 make format    clang-format
#   make compdb   compile_commands.json      make clean
CC      := gcc
CFLAGS  := -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -g -O0
SAN     := -fsanitize=address,undefined -fno-omit-frame-pointer
SRC     := $(wildcard src/*.c)
OBJ     := $(SRC:src/%.c=build/%.o)
BIN     := build/prog
TSRC    := $(wildcard tests/*.c)
# Check from micromamba, or from the system
CHECK   := $(HOME)/micromamba/envs/outils
export PKG_CONFIG_PATH := $(CHECK)/lib/pkgconfig:$(PKG_CONFIG_PATH)
PKGCFG  := $(firstword $(wildcard $(CHECK)/bin/pkg-config) pkg-config)
CHECKF   = $(shell $(PKGCFG) --cflags --libs check 2>/dev/null) -Wl,-rpath,$(CHECK)/lib

all: $(BIN)

$(BIN): $(OBJ)
	$(CC) $(CFLAGS) $(SAN) $^ -o $@ -lm

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) $(SAN) -MMD -c $< -o $@

build:
	mkdir -p build

run: all
	./$(BIN)

test: | build
	$(CC) $(CFLAGS) -Isrc $(TSRC) $(filter-out src/main.c,$(SRC)) $(CHECKF) -lm -o build/tests
	./build/tests

valgrind: clean
	$(MAKE) --no-print-directory SAN= all
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./$(BIN)

analyse:
	@for f in $(SRC); do $(CC) $(CFLAGS) -fanalyzer -c $$f -o /dev/null || exit 1; done; echo "analyse OK"

check:
	cppcheck --enable=all --inconclusive --suppress=missingIncludeSystem -q src/

tidy:
	clang-tidy $(SRC) -- $(CFLAGS) -Isrc

format:
	clang-format -i $(SRC) $(wildcard src/*.h)

compdb: clean
	bear -- $(MAKE) --no-print-directory

clean:
	rm -rf build

-include $(OBJ:.o=.d)
.PHONY: all run test valgrind analyse check tidy format compdb clean
MAKE
  printf '#ifndef CALC_H\n#define CALC_H\n\nint add(int a, int b);\n\n#endif\n' >"$m/src/calc.h"
  printf '#include "calc.h"\n\nint add(int a, int b)\n{\n    return a + b;\n}\n' >"$m/src/calc.c"
  printf '#include <stdio.h>\n#include <stdlib.h>\n#include "calc.h"\n\nint main(void)\n{\n    printf("2 + 3 = %%d\\n", add(2, 3));\n    return EXIT_SUCCESS;\n}\n' >"$m/src/main.c"
  cat >"$m/tests/test_calc.c" <<'C'
#include <check.h>
#include <stdlib.h>
#include "calc.h"

START_TEST(test_add)
{
    ck_assert_int_eq(add(2, 3), 5);
    ck_assert_int_eq(add(-1, 1), 0);
}
END_TEST

int main(void)
{
    Suite *s = suite_create("calc");
    TCase *tc = tcase_create("base");
    tcase_add_test(tc, test_add);
    suite_add_tcase(s, tc);
    SRunner *sr = srunner_create(s);
    srunner_run_all(sr, CK_NORMAL);
    int failed = srunner_ntests_failed(sr);
    srunner_free(sr);
    return failed == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
C
  printf -- '-std=c11\n-D_DEFAULT_SOURCE\n-Wall\n-Wextra\n-Isrc\n' >"$m/compile_flags.txt"
  printf 'BasedOnStyle: LLVM\nIndentWidth: 4\nColumnLimit: 100\nBreakBeforeBraces: Linux\n' >"$m/.clang-format"
  printf "Checks: 'clang-analyzer-*,bugprone-*,cert-*,-cert-err33-c,-bugprone-easily-swappable-parameters'\nWarningsAsErrors: ''\n" >"$m/.clang-tidy"
  printf 'build/\n*.o\n*.d\na.out\ncompile_commands.json\n.cache/\nvgcore.*\ncore\n' >"$m/.gitignore"
  cat >"$BIN/cnew" <<'SH'
#!/usr/bin/env bash
# cnew NAME: create a C project (Makefile, Check tests, clang-format...)
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: cnew NAME" >&2; exit 1; }
[ -e "$1" ] && { echo "'$1' already exists" >&2; exit 1; }
mkdir -p "$1"
cp -r "$HOME/.config/exported-home-config/templates/c-project/." "$1/"
git -C "$1" init -q 2>/dev/null || true
echo "Project '$1' created.  cd $1 && make run   (make test, make valgrind, make analyse...)"
SH
  chmod +x "$BIN/cnew"; record "$BIN/cnew"
}
write_memo() {   # cheat sheet + memo command
  cat >"$CFG/memo.md" <<'MEMO'
# Mémo

## Terminal (zsh)
| Touche / commande | Effet |
|---|---|
| flèche droite | accepter la suggestion grise |
| Ctrl-R / Ctrl-T / Alt-C | historique / fichier / dossier (fzf) |
| `z tp1` | sauter à un dossier déjà visité |
| `ll` / `la` / `lt` | liste détaillée / tout / arbre |
| `cat fichier` | affichage coloré avec numéros (bat) |
| `tldr tar` | exemples courts en français |
| `rg motif` / `fd nom` | chercher du texte / un fichier |
| `tp fichier` | corbeille (`trash-list`, `trash-restore`) |
| `man 3 strdup` | page de manuel en couleurs |
| `j dossier` | comme autojump (zoxide) |
| `fuck` | corrige la dernière commande (thefuck) |
| Ctrl-Z | revenir au programme mis en pause (fancy-ctrl-z) |
| Alt-← / Alt-→ | dossier précédent / suivant (dirhistory) |
| Ctrl-O | copier la ligne tapée (copybuffer) |
| `copyfile f` | copier le contenu d'un fichier |
| `google mot` | recherche web (web-search) |
| `cdoc` | doc C hors ligne (cppreference) |
| `lg` | lazygit |
| `p10k configure` | refaire le style du prompt |
| `gedit fichier` | éditeur graphique (xed sur Mint) |
| `memo` | cette page |

## Compiler du C
| Commande | Effet |
|---|---|
| `crun prog.c [args]` | compiler (avertissements stricts) + lancer |
| `csan prog.c` | idem avec AddressSanitizer + UBSan |
| `cmem prog.c` | idem sous valgrind (fuites) |
| `cdebug prog.c` | compiler + ouvrir gdb (taper `dash` dedans) |
| `cnew tp1` | nouveau projet avec Makefile et tests |
| `make run` / `test` / `valgrind` / `analyse` / `format` | dans un projet |
| `watchexec -e c,h -- make run` | recompiler à chaque sauvegarde |

## Neovim / LazyVim (leader = Espace)
| Touche | Effet |
|---|---|
| Espace Espace / Espace / | chercher un fichier / du texte |
| Espace e | explorateur de fichiers |
| `K` | prototype de la fonction sous le curseur |
| `gK` (ou Ctrl-K en insertion) | paramètres attendus |
| Espace s M | **chercher une page man** (explication complète) |
| `gd` / `gr` | définition / références |
| `]d` `[d` / Espace x x | erreur suivante, précédente / liste des erreurs |
| Espace c a / Espace c r / Espace c f | correction proposée / renommer / formater |
| Espace c h | basculer .c ↔ .h |
| Espace d b / Espace d c | point d'arrêt / lancer le débogueur |
| Espace d i / Espace d O / Espace d o | entrer / ligne suivante / sortir |
| Ctrl-/ | terminal intégré |
| Espace g g | lazygit |
| Espace (attendre) | tous les raccourcis |

## Copier / coller
| Où | Comment |
|---|---|
| Neovim | `y` copier, `d` couper, `p` / `P` coller après / avant |
| Neovim | Espace p : **historique des copies**, choisir et coller |
| Neovim | juste après `p` : `[y` / `]y` remplace par la copie précédente / suivante |
| Terminal | sélectionner à la souris = copié ; **clic molette** = coller |
| Terminal | Ctrl-Shift-C / Ctrl-Shift-V (Ctrl-C arrête le programme) |
| Partout | **Super+V** : historique CopyQ de tout ce que tu as copié |
| tmux | Ctrl-b = : historique des copies faites dans tmux |

## gdb
`dash` panneaux · `break main` · `run` · `next` · `step` · `print x` · `bt`

## tmux
Ctrl-b | et Ctrl-b - découper · Ctrl-b flèches · Ctrl-b d puis `tmux a`

## Tes fichiers perso (jamais écrasés)
`~/.config/exported-home-config/perso.zsh` · `~/.config/nvim/lua/config/perso.lua` · `~/.config/nvim/lua/plugins/perso.lua` · `~/.tmux.perso.conf`
MEMO
  cat >"$BIN/memo" <<'SH'
#!/usr/bin/env bash
# memo: show my cheat sheet
f="$HOME/.config/exported-home-config/memo.md"
if command -v glow >/dev/null && command -v less >/dev/null; then exec glow -p "$f"
elif command -v glow >/dev/null; then exec glow "$f"
elif command -v bat >/dev/null; then exec bat --style=plain -l md "$f"
else exec less "$f"; fi
SH
  chmod +x "$BIN/memo"; record "$BIN/memo"
}
warm_up_zsh() {  # first start: downloads gitstatus (git prompt) and builds the completion cache
  [ -x "$BIN/zsh" ] || return 0
  TERM=xterm-256color timeout 120 "$BIN/zsh" -i -c 'exit' </dev/null
  record "$HOME/.cache/gitstatus"
  local c; for c in "$HOME"/.cache/p10k-*; do [ -e "$c" ] && record "$c"; done
  for c in "$HOME"/.zcompdump*; do [ -e "$c" ] && record "$c"; done
  return 0
}
step_config() {
  title "Config: zsh, bash fallback, gdb, git, C template"
  if [ -f "$HOME/.zshrc" ] && ! managed "$HOME/.zshrc" && [ -f "$HOME/.zshrc$BAK" ]; then
    info "personal ~/.zshrc (no $NAME header): left as is"
  else
    run "~/.zshrc" write_zshrc
  fi
  [ -f "$CFG/perso.zsh" ] || printf '# My zsh aliases and settings (never overwritten)\n' >"$CFG/perso.zsh"
  run "zsh plugins (home list)" write_plugins
  run "bash fallback (~/.bashrc)" write_bashrc
  run "~/.gdbinit (dash command)" write_gdbinit
  run "git (lg alias, delta)" setup_git
  run "C project template + cnew command" write_templates
  run "cheat sheet (memo command)" write_memo
  run "first zsh start (git prompt)" warm_up_zsh
}

# ---- Offline C docs ----------------------------------------------------------
write_cdoc() {
  local c; c=$(find "$OPT/cppreference" -path '*/en/c.html' 2>/dev/null | head -1)
  [ -n "$c" ] || return 1
  printf '#!/usr/bin/env bash\n# cdoc: offline C documentation (cppreference) in the browser\nexec xdg-open "%s"\n' "$c" >"$BIN/cdoc"
  chmod +x "$BIN/cdoc"; record "$BIN/cdoc"
}
install_cppref() {
  local url f="$WORK/dl/cppref.tar.xz"
  url=$(gh_asset PeterFeicht/cppreference-doc '^html-book-.*\.tar\.xz$') || return 1
  download "$url" "$f" || return 1
  rm -rf "$OPT/cppreference"; mkdir -p "$OPT/cppreference"
  tar -xJf "$f" -C "$OPT/cppreference" || return 1
  rm -f "$f"; record "$OPT/cppreference"
  write_cdoc
}
step_doc() {
  title "Offline C docs"
  tool "offline C docs (cppreference)" "$OPT/cppreference" install_cppref
  [ -d "$OPT/cppreference" ] && [ ! -x "$BIN/cdoc" ] && run "cdoc command" write_cdoc
  man -w 3 printf >/dev/null 2>&1 || info "no section 3 man pages on this PC: use cdoc"
}

# ---- Terminal: font, "Home" profile, Caps Lock = Escape ---------------------
install_meslo() {
  local d="$SHR/fonts/MesloLGS-NF" s
  mkdir -p "$d"
  for s in Regular Bold Italic "Bold Italic"; do
    download "https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20${s// /%20}.ttf" \
      "$d/MesloLGS-NF-${s// /-}.ttf" || return 1
  done
  record "$d"
  command -v fc-cache >/dev/null && fc-cache -f "$SHR/fonts"
  return 0
}
terminal_profile() {  # GNOME Terminal "Home" profile: Breeze colors (Konsole) + MesloLGS NF + zsh
  command -v gsettings >/dev/null || { REASON="gsettings missing"; return 1; }
  gsettings list-schemas 2>/dev/null | grep -x org.gnome.Terminal.ProfilesList >/dev/null \
    || { REASON="GNOME Terminal missing"; return 1; }
  local PL=org.gnome.Terminal.ProfilesList list default uuid P
  list=$(gsettings get "$PL" list) || return 1
  default=$(gsettings get "$PL" default | tr -d "'")
  if [ -f "$CFG/terminal-profile" ]; then
    uuid=$(sed -n 's/^uuid=//p' "$CFG/terminal-profile")
  else
    uuid=$(cat /proc/sys/kernel/random/uuid)
    printf 'uuid=%s\nbefore=%s\n' "$uuid" "$default" >"$CFG/terminal-profile"
  fi
  case "$list" in
    *"$uuid"*) ;;
    "@as []"|"[]") gsettings set "$PL" list "['$uuid']" || return 1 ;;
    *) gsettings set "$PL" list "${list%]}, '$uuid']" || return 1 ;;
  esac
  P="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"
  gsettings set "$P" visible-name 'Home' &&
  gsettings set "$P" font "$FONT" &&
  gsettings set "$P" use-system-font false &&
  gsettings set "$P" use-theme-colors false &&
  gsettings set "$P" background-color '#232627' &&
  gsettings set "$P" foreground-color '#fcfcfc' &&
  gsettings set "$P" palette "['#232627', '#ed1515', '#11d116', '#f67400', '#1d99f3', '#9b59b6', '#1abc9c', '#fcfcfc', '#7f8c8d', '#c0392b', '#1cdc9a', '#fdbc4b', '#3daee9', '#8e44ad', '#16a085', '#ffffff']" &&
  gsettings set "$P" audible-bell false || return 1
  if [ -x "$BIN/zsh" ]; then
    gsettings set "$P" use-custom-command true && gsettings set "$P" custom-command "$BIN/zsh" || return 1
  fi
  gsettings set "$PL" default "$uuid"
}
terminal_margin() {  # inner margin like Konsole (TerminalMargin), through the GTK CSS
  mkdir -p "$HOME/.config/gtk-3.0"
  add_block "$HOME/.config/gtk-3.0/gtk.css" "VteTerminal, vte-terminal { padding: ${MARGIN}px; }" '/*' '*/'
}
write_caps() {
  mkdir -p "$HOME/.config/autostart"
  cat >"$HOME/.config/autostart/$NAME-caps-escape.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Caps Lock as Escape
Comment=Shift+Caps Lock keeps caps lock
Exec=setxkbmap -option caps:escape_shifted_capslock
X-GNOME-Autostart-Delay=5
EOF
  record "$HOME/.config/autostart/$NAME-caps-escape.desktop"
}
step_terminal() {
  title "Terminal: font, Konsole colors, Caps Lock = Escape"
  tool "MesloLGS NF font (for powerlevel10k)" "$SHR/fonts/MesloLGS-NF" install_meslo
  if [ "$NO_TERM" -eq 0 ]; then
    run "GNOME Terminal \"Home\" profile (Breeze + $FONT + zsh)" terminal_profile
    run "text margin like Konsole (${MARGIN} px)" terminal_margin
  else info "terminal profile skipped (--no-terminal)"; fi
  run "Caps Lock = Escape (next session)" write_caps
  todo "Close ALL terminals and open a new one: \"Home\" profile, zsh, Konsole colors"
  todo "First nvim start: let the downloads finish (1 to 2 minutes)"
  todo "Prompt style: p10k configure (or --p10k with my home file)"
  todo "Cheat sheet: memo"
}

# ---- Clipboard: CopyQ --------------------------------------------------------
install_copyq() {
  # Pinned: CopyQ 17 needs glibc 2.43 (too recent for Mint), 16 needs glibc 2.38
  local url=https://github.com/hluk/CopyQ/releases/download/v16.0.0/CopyQ-16.0.0-x86_64.AppImage g
  g=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')
  if [ "$(printf '%s\n' "2.38" "$g" | sort -V | head -1)" != "2.38" ]; then
    REASON="glibc $g too old (2.38 needed): use flatpak --user install flathub com.github.hluk.copyq"
    echo "$REASON"; return 1
  fi
  appimage "$url" copyq copyq || return 1
  desktop_entry copyq "CopyQ (clipboard history)" "$BIN/copyq" "$(appimage_icon copyq)" "Utility;"
  mkdir -p "$HOME/.config/autostart"
  cat >"$HOME/.config/autostart/$NAME-copyq.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CopyQ
Exec=$BIN/copyq
X-GNOME-Autostart-Delay=6
EOF
  record "$HOME/.config/autostart/$NAME-copyq.desktop"
  if [ ! -f "$HOME/.config/copyq/copyq-commands.ini" ]; then   # Super+V opens the history
    mkdir -p "$HOME/.config/copyq"
    cat >"$HOME/.config/copyq/copyq-commands.ini" <<'EOF'
[Commands]
1\Command=copyq: toggle()
1\GlobalShortcut=meta+v
1\IsGlobalShortcut=true
1\Name=Show history
size=1
EOF
    record "$HOME/.config/copyq"
  fi
}
step_clipboard() {
  title "Clipboard: CopyQ"
  tool "CopyQ (clipboard history, Super+V)" "$OPT/copyq" install_copyq
  todo "CopyQ starts with the next session (or run: copyq &). Super+V opens the history"
}

# =============================================================================
#  CHECKS, REPORT, MIGRATION, UNINSTALL
# =============================================================================
preflight() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "${RED}Do not run this as root: it installs for YOUR user.${RST}"; exit 1
  fi
  [ "$(uname -m)" = x86_64 ] || { echo "Unsupported CPU $(uname -m) (x86_64 only)."; exit 1; }
  local missing="" c
  for c in curl tar gzip xz git find install awk sed; do command -v "$c" >/dev/null || missing="$missing $c"; done
  [ -z "$missing" ] || { echo "${RED}Required commands missing:$missing${RST}"; exit 1; }
  mkdir -p "$BIN" "$WORK/dl" "$WORK/x" "$CFG"
  : >"$LOGF"
  printf '#!/bin/sh\necho ok\n' >"$BIN/.ehc-test"; chmod +x "$BIN/.ehc-test"
  if [ "$("$BIN/.ehc-test" 2>/dev/null)" != ok ]; then
    rm -f "$BIN/.ehc-test"
    echo "${RED}Your home is mounted noexec: no program can run from it. Ask the IT team.${RST}"
    exit 1
  fi
  rm -f "$BIN/.ehc-test"
  if [ -f "$CFG/bashrc.sh" ] && grep -q 'ble.sh' "$CFG/bashrc.sh" 2>/dev/null; then
    echo "${YEL}A version 1 install is present. Remove it first:${RST}"
    echo "    bash $0 --uninstall --all"
    exit 1
  fi
  command -v unzip >/dev/null || command -v python3 >/dev/null || info "neither unzip nor python3: .zip files will fail"
  command -v gcc >/dev/null || info "gcc missing: Neovim syntax parsers cannot be compiled"
  printf '%s%s %s%s - log: %s\n' "$BLU" "$NAME" "$VERSION" "$RST" "$LOGF"
  printf '  glibc: %s   |   free space in ~: %s\n' \
    "$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')" "$(df -h "$HOME" | awk 'NR==2{print $4}')"
  command -v quota >/dev/null && quota -s 2>/dev/null | tail -n +2 | sed 's/^/  quota: /'
  printf '  %sSpace needed: about 2.5 GB (about 0.8 GB for Neovim and its tools).%s\n' "$DIM" "$RST"
  export PATH="$BIN:$PATH"
}
report() {
  printf '\n%s======================== SUMMARY ========================%s\n' "$BLU" "$RST"
  printf '%s%d ok%s\n' "$GRN" "${#OKS[@]}" "$RST"
  if [ ${#FAILS[@]} -gt 0 ]; then
    printf '%s%d failed:%s\n' "$RED" "${#FAILS[@]}" "$RST"
    printf '   - %s\n' "${FAILS[@]}"
    printf '   Running the script again only retries what is missing.\n'
  fi
  if [ ${#TODO[@]} -gt 0 ]; then
    printf '%sTo do:%s\n' "$YEL" "$RST"; printf '   - %s\n' "${TODO[@]}"
  fi
  printf '%sDisk used:%s ' "$DIM" "$RST"
  du -shc "$PREFIX" "$HOME/.oh-my-zsh" "$MAMBA_ROOT" "$HOME/.fzf" "$NVIM_CFG" 2>/dev/null | tail -1 | cut -f1
  printf 'Full log: %s\n' "$LOGF"
}

# Versions 1 and 2 were called kit-etudiant: rename everything once
migrate_legacy() {
  [ -d "$OLD_CFG" ] && [ ! -e "$CFG" ] || return 0
  echo "Old install found (kit-etudiant): renaming it to $NAME"
  local f old new
  mv "$OLD_CFG" "$CFG" || return 1
  mkdir -p "$WORK"
  if [ -d "$OLD_WORK" ]; then mv "$OLD_WORK"/install-*.log "$WORK"/ 2>/dev/null; rm -rf "$OLD_WORK"; fi
  [ -f "$CFG/manifeste" ] && mv "$CFG/manifeste" "$MANIFEST"
  [ -f "$CFG/terminal-profil" ] && sed 's/^avant=/before=/' "$CFG/terminal-profil" >"$CFG/terminal-profile" && rm -f "$CFG/terminal-profil"
  [ -f "$CFG/terminal-avant.sh" ] && mv "$CFG/terminal-avant.sh" "$CFG/terminal-before.sh"
  rm -rf "$CFG/modeles" "$CFG/aide.md"

  # paths and markers inside config files, old backups
  for f in .zshrc .bashrc .profile .gdbinit .inputrc .tmux.conf .vimrc .config/gtk-3.0/gtk.css; do
    [ -f "$HOME/$f" ] && sed -i -e "s#\.config/kit-etudiant/#.config/$NAME/#g" \
      -e "s#>>> kit-etudiant >>>#$MARK_BEGIN#" -e "s#<<< kit-etudiant <<<#$MARK_END#" "$HOME/$f"
    [ -e "$HOME/$f.avant-kit" ] && [ ! -e "$HOME/$f$BAK" ] && mv "$HOME/$f.avant-kit" "$HOME/$f$BAK"
  done
  [ -d "$NVIM_CFG.avant-kit" ] && [ ! -e "$NVIM_CFG$BAK" ] && mv "$NVIM_CFG.avant-kit" "$NVIM_CFG$BAK"

  # Neovim
  if [ -f "$NVIM_CFG/.kit-etudiant" ]; then
    rm -f "$NVIM_CFG/.kit-etudiant"; nvim_marker
    [ -f "$NVIM_CFG/lua/plugins/kit.lua" ] && mv "$NVIM_CFG/lua/plugins/kit.lua" "$NVIM_CFG/lua/plugins/$NAME.lua"
    setup_lazyvim >/dev/null
  fi

  # autostart and menu entries
  for f in kit-caps-echap:caps-escape kit-copyq:copyq; do
    old="$HOME/.config/autostart/${f%%:*}.desktop"; new="$HOME/.config/autostart/$NAME-${f##*:}.desktop"
    [ -f "$old" ] && mv "$old" "$new"
  done
  [ -f "$SHR/applications/kit-copyq.desktop" ] && mv "$SHR/applications/kit-copyq.desktop" "$SHR/applications/$NAME-copyq.desktop"

  # old commands (kit-projet, kit-aide, doc-c) are replaced by cnew, memo, cdoc
  rm -f "$BIN/kit-projet" "$BIN/kit-aide" "$BIN/doc-c"
  if [ -f "$MANIFEST" ]; then
    sed -i -e 's/^cree:/created:/' \
      -e "s#\.config/kit-etudiant#.config/$NAME#g" -e "s#\.cache/kit-etudiant#.cache/$NAME#g" \
      -e "s#/autostart/kit-caps-echap\.desktop#/autostart/$NAME-caps-escape.desktop#" \
      -e "s#/autostart/kit-copyq\.desktop#/autostart/$NAME-copyq.desktop#" \
      -e "s#/applications/kit-copyq\.desktop#/applications/$NAME-copyq.desktop#" \
      -e '\#/kit-projet$#d' -e '\#/kit-aide$#d' -e '\#/doc-c$#d' "$MANIFEST"
    # zsh-bin also installed terminfo files (not recorded by the old version)
    grep -qx "$BIN/zsh" "$MANIFEST" && [ -d "$SHR/terminfo" ] && record "$SHR/terminfo"
  fi
  managed "$HOME/.tmux.conf" && write_tmux_conf
  mkdir -p "$BIN"
  write_templates >/dev/null && write_memo >/dev/null
  [ -d "$OPT/cppreference" ] && write_cdoc
  echo "Done: kit-projet -> cnew, kit-aide -> memo, doc-c -> cdoc"
}

remove_terminal_profile() {
  [ -f "$CFG/terminal-profile" ] && command -v gsettings >/dev/null || return 0
  local PL=org.gnome.Terminal.ProfilesList uuid before list
  uuid=$(sed -n 's/^uuid=//p' "$CFG/terminal-profile"); before=$(sed -n 's/^before=//p' "$CFG/terminal-profile")
  [ -n "$uuid" ] || return 0
  list=$(gsettings get "$PL" list 2>/dev/null) || return 0
  list=$(printf '%s' "$list" | sed "s/, '$uuid'//; s/'$uuid', //; s/'$uuid'//")
  case "$list" in "[]"|"@as []") gsettings reset "$PL" list ;; *) gsettings set "$PL" list "$list" ;; esac
  if [ -n "$before" ]; then gsettings set "$PL" default "$before"; else gsettings reset "$PL" default; fi
  command -v dconf >/dev/null && dconf reset -f "/org/gnome/terminal/legacy/profiles:/:$uuid/"
  echo "\"Home\" terminal profile removed"
}
reset_terminal_tests() {  # --all: undo the terminal settings changed by hand during early tests
  command -v gsettings >/dev/null || return 0
  local PL=org.gnome.Terminal.ProfilesList id P k
  id=$(gsettings get "$PL" default 2>/dev/null | tr -d "'"); [ -n "$id" ] || return 0
  P="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$id/"
  for k in palette use-theme-colors background-color foreground-color font use-system-font use-custom-command custom-command; do
    gsettings reset "$P" "$k" 2>/dev/null
  done
  gsettings reset org.cinnamon.desktop.default-applications.terminal exec 2>/dev/null
  echo "default terminal settings reset"
}
uninstall() {
  echo "Removes everything $NAME created, and its blocks in your config files."
  [ "$ALL" -eq 1 ] && echo "--all: your personal files and the terminal test settings go too."
  if [ -t 0 ]; then read -rp "Continue? [y/N] " r; [[ $r == [yYoO] ]] || exit 0; fi
  mkdir -p "$WORK"
  local p f
  [ -x "$BIN/uv" ] && "$BIN/uv" cache clean >/dev/null 2>&1

  # 1. config blocks, files created from scratch, git settings
  for f in .bashrc .profile .inputrc .gdbinit; do
    remove_block "$HOME/$f"; rm -f "$HOME/$f$BAK"
  done
  remove_block "$HOME/.config/gtk-3.0/gtk.css" '/*' '*/'; rm -f "$HOME/.config/gtk-3.0/gtk.css$BAK"
  if [ -f "$MANIFEST" ]; then
    grep '^created:' "$MANIFEST" | sort -u | while IFS= read -r p; do
      f=${p#created:}
      [ -f "$f" ] && ! grep -qvE '^[[:space:]]*$|^\$include /etc/inputrc$' "$f" && rm -f "$f"
    done
    grep '^git:' "$MANIFEST" | sort -u | while IFS= read -r p; do
      git config --global --unset "${p#git:}" 2>/dev/null
    done
    git config --global --remove-section delta 2>/dev/null
  fi
  for f in .vimrc .tmux.conf .zshrc; do
    if [ -f "$HOME/$f$BAK" ]; then mv -f "$HOME/$f$BAK" "$HOME/$f"
    elif managed "$HOME/$f"; then rm -f "$HOME/$f"; fi
  done

  # 2. Neovim config: never deleted without --all (it may contain my work)
  if [ -f "$NVIM_CFG/.$NAME" ]; then
    if [ "$ALL" -eq 1 ]; then rm -rf "$NVIM_CFG"
    else mv "$NVIM_CFG" "$NVIM_CFG.saved-$(date +%Y%m%d-%H%M)"; echo "Neovim config moved to $NVIM_CFG.saved-*"; fi
    [ -d "$NVIM_CFG$BAK" ] && mv "$NVIM_CFG$BAK" "$NVIM_CFG"
  fi

  # 3. terminal
  remove_terminal_profile
  [ -f "$CFG/terminal-before.sh" ] && bash "$CFG/terminal-before.sh" 2>/dev/null
  [ "$ALL" -eq 1 ] && reset_terminal_tests

  # 4. installed files and folders
  if [ -f "$MANIFEST" ]; then
    grep -vE '^(created|git):' "$MANIFEST" | sort -u | while IFS= read -r p; do
      case "$p" in
        ""|"$HOME"|"$HOME/"|"$PREFIX"|"$BIN"|"$OPT"|"$SHR"|"$HOME/.config"|"$HOME/.cache"|"$NVIM_CFG") continue ;;
        "$HOME"/*) rm -rf -- "$p" ;;
      esac
    done
  fi

  # 5. tool caches, tmux plugins, empty folders
  rm -rf "$HOME/.tmux/plugins" "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup" \
         "$HOME/.cache/tealdeer" "$HOME/.cache/starship" "$HOME/.cache/glow" "$HOME/.cache/blesh" \
         "$HOME/.local/state/blesh" "$HOME/.local/state/gh" "$HOME/.config/glow" "$HOME"/.cache/.pwntools-cache-* \
         "$HOME/.cache/tree-sitter" "$HOME/.cache/thefuck" "$HOME/.config/thefuck" "$HOME/.local/share/zoxide"
  [ -f "$HOME/.gitconfig" ] && [ ! -s "$HOME/.gitconfig" ] && rm -f "$HOME/.gitconfig"

  # 6. --all: personal files and leftovers from early tests
  if [ "$ALL" -eq 1 ]; then
    rm -rf "$CFG/perso.sh" "$CFG/perso.zsh" "$HOME/.vim/perso.vim" "$HOME/.vim/vsnip" "$HOME/.tmux.perso.conf" \
           "$HOME/.config/kitty" "$HOME/.local/kitty.app" "$HOME/.local/bin/kitty" "$HOME/.local/bin/kitten" \
           "$HOME/.config/starship.toml" "$HOME/.config/starship-simple.toml" "$HOME/.p10k.zsh" \
           "$HOME"/.local/share/applications/kitty*.desktop
  fi
  find "$PREFIX" "$HOME/.vim" "$HOME/.tmux" "$HOME/.config/rclone" "$HOME/.config/autostart" "$HOME/.config/kitty" "$HOME/.config/gtk-3.0" \
       -depth -type d -empty -delete 2>/dev/null
  if [ -d "$CFG" ]; then
    if [ "$ALL" -eq 1 ]; then rm -rf "$CFG"
    else find "$CFG" -mindepth 1 -maxdepth 1 ! -name perso.sh ! -name perso.zsh -exec rm -rf {} + 2>/dev/null; fi
  fi
  rm -rf "$WORK"
  echo "Done. Close all terminals and open a new one."
  [ "$ALL" -eq 0 ] && echo "Kept: ~/.config/$NAME/perso.zsh, ~/.tmux.perso.conf, the Neovim config (~/.config/nvim.saved-*), ~/.p10k.zsh"
  return 0
}
show_help() { awk 'NR>2 && /^[^#]/{exit} NR>2{sub(/^# ?/,""); print}' "$0"; }

# Load the functions without running anything (used by fix-home-config.sh)
[ "${EHC_SOURCE_ONLY:-0}" = 1 ] && return 0 2>/dev/null

# =============================================================================
#  MAIN
# =============================================================================
while [ $# -gt 0 ]; do
  case "$1" in
    --update|--maj) UPDATE=1 ;;
    --no-conda|--sans-conda) NO_CONDA=1 ;;
    --no-terminal|--sans-terminal) NO_TERM=1 ;;
    --home|--maison) shift; ARCHIVE=${1:-} ;;
    --home=*|--maison=*) ARCHIVE=${1#*=} ;;
    --p10k) shift; P10K_SRC=${1:-} ;;
    --p10k=*) P10K_SRC=${1#*=} ;;
    --only|--seulement) shift; ONLY=${1:-} ;;
    --only=*|--seulement=*) ONLY=${1#*=} ;;
    --list|--liste) for e in "${STEPS[@]}"; do printf '  %-12s %s\n' "$e" "${DESC[$e]}"; done; exit 0 ;;
    --uninstall|--desinstaller) MODE=uninstall ;;
    --all|--tout) ALL=1 ;;
    -h|--help|--aide) show_help; exit 0 ;;
    *) echo "unknown option: $1 (see --help)"; exit 1 ;;
  esac
  shift
done
# old step names
ONLY=$(sed -e 's/\bprepa\b/prep/g' -e 's/\boutils_shell\b/shell_tools/g' -e 's/\boutils_c\b/c_tools/g' \
           -e 's/\bpresse_papier\b/clipboard/g' <<<"$ONLY")

migrate_legacy || { echo "${RED}Could not rename the old install (kit-etudiant).${RST}"; exit 1; }
if [ "$MODE" = uninstall ]; then uninstall; exit 0; fi
if [ -n "$ARCHIVE" ]; then
  [ -e "$ARCHIVE" ] || { echo "not found: $ARCHIVE"; exit 1; }
  ARCHIVE_DIR="$WORK/home"; rm -rf "$ARCHIVE_DIR"; mkdir -p "$ARCHIVE_DIR"
  if [ -d "$ARCHIVE" ]; then cp -r "$ARCHIVE"/. "$ARCHIVE_DIR"/
  else tar -xzf "$ARCHIVE" -C "$ARCHIVE_DIR" || { echo "cannot read archive: $ARCHIVE"; exit 1; }; fi
  for d in home-config kit-maison; do [ -d "$ARCHIVE_DIR/$d" ] && ARCHIVE_DIR="$ARCHIVE_DIR/$d"; done
  [ -z "$P10K_SRC" ] && [ -f "$ARCHIVE_DIR/zsh/p10k.zsh" ] && P10K_SRC="$ARCHIVE_DIR/zsh/p10k.zsh"
  profile=$(find "$ARCHIVE_DIR/konsole" -name '*.profile' 2>/dev/null | head -1)
  if [ -n "$profile" ]; then
    f=$(sed -n 's/^Font=//p' "$profile" | head -1)
    [ -n "$f" ] && FONT="$(cut -d, -f1 <<<"$f") $(cut -d, -f2 <<<"$f")"
    m=$(sed -n 's/^TerminalMargin=//p' "$profile" | head -1); [ -n "$m" ] && MARGIN=$m
  fi
fi
if [ -n "$P10K_SRC" ] && [ ! -f "$P10K_SRC" ]; then echo "file not found: $P10K_SRC"; exit 1; fi
[ -n "$P10K_SRC" ] && P10K_SRC=$(readlink -f "$P10K_SRC")

preflight
for e in "${STEPS[@]}"; do
  if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$e,"* ]]; then continue; fi
  [ "$e" = conda ] && [ "$NO_CONDA" -eq 1 ] && { info "conda step skipped (--no-conda)"; continue; }
  "step_$e"
done
rm -rf "$WORK/dl" "$WORK/x"
report
[ ${#FAILS[@]} -eq 0 ]
