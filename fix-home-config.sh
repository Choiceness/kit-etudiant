#!/usr/bin/env bash
# =============================================================================
#  fix-home-config.sh - fixes my home PC (KDE neon) and adds what the school
#  PC has (only what is missing here).
#  Each change is explained and asks first. Files are backed up before a change
#  (suffix .before-fix-DATE). sudo is only asked to install packages.
# =============================================================================
#  Usage: bash fix-home-config.sh              (asks for each change)
#         bash fix-home-config.sh --dry-run    (shows what would be done, changes nothing)
#         bash fix-home-config.sh --yes        (accepts everything)
#         bash fix-home-config.sh --only treesitter,noice   (only these steps)
#  Fixes: rename cflags thefuck git tools lazyvim treesitter noice cleanup
#  School additions: scripts terminal c-tools project shortcuts
#  (the additions use exported-home-config.sh: keep it in the same folder)
# =============================================================================
# shellcheck disable=SC2088  # "~/" inside quotes is only displayed
set -uo pipefail
DRY=0; YES=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|--voir) DRY=1 ;; --yes|--oui) YES=1 ;;
    --only|--seulement) shift; ONLY=${1:-} ;; --only=*|--seulement=*) ONLY=${1#*=} ;;
    -h|--help|--aide) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $1"; exit 1 ;;
  esac; shift
done
# old step names
ONLY=$(sed -e 's/\boutils-c\b/c-tools/g' -e 's/\boutils\b/tools/g' -e 's/\bmenage\b/cleanup/g' \
           -e 's/\bprojet\b/project/g' -e 's/\braccourcis\b/shortcuts/g' <<<"$ONLY")
chosen() { [ -z "$ONLY" ] || [[ ",$ONLY," == *",$1,"* ]]; }
[ "$(id -u)" -eq 0 ] && { echo "Run it as your user: it asks for sudo when needed."; exit 1; }

DATE=$(date +%Y%m%d-%H%M)
BIN="$HOME/.local/bin"; NV="$HOME/.config/nvim"
CFG="$HOME/.config/exported-home-config"
LOG="$HOME/.cache/fix-home-config-$DATE.log"
if [ -t 1 ]; then GRN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; BLU=$'\e[1;34m'; RST=$'\e[0m'
else GRN=""; RED=""; YEL=""; BLU=""; RST=""; fi
declare -a DONE=() FAILED=() SKIPPED=()

title()   { printf '\n%s== %s%s\n' "$BLU" "$1" "$RST"; }
say()     { printf '   %s\n' "$@"; }
ok()      { DONE+=("$1");    printf '   %s[ok]%s   %s\n' "$GRN" "$RST" "$1"; }
fail()    { FAILED+=("$1");  printf '   %s[FAIL]%s %s\n' "$RED" "$RST" "$1"; }
skip()    { SKIPPED+=("$1"); printf '   %s[--]%s   %s\n' "$YEL" "$RST" "$1"; }
confirm() {  # confirm "question": 0 if yes
  [ "$DRY" -eq 1 ] && { printf '   %s(dry run: nothing changed)%s\n' "$YEL" "$RST"; return 1; }
  [ "$YES" -eq 1 ] && return 0
  local r; read -rp "   -> $1 [y/N] " r; [[ $r == [yYoO] ]]
}
backup() { [ -e "$1" ] && cp -a "$1" "$1.before-fix-$DATE"; }

# ---- Helpers for the school additions ---------------------------------------
INSTALLER=""
for c in "$(dirname "$(readlink -f "$0")")/exported-home-config.sh" "$HOME/exported-home-config/exported-home-config.sh"; do
  [ -f "$c" ] && { INSTALLER=$c; break; }
done
missing() { ! command -v "$1" >/dev/null 2>&1; }
need_installer() { [ -n "$INSTALLER" ] && return 0; fail "exported-home-config.sh not found: put it in the same folder as this script"; return 1; }
# installer_fn FUNCTION args: run ONE function of exported-home-config.sh in a subshell
# (same downloads as at school, into ~/.local/bin)
# shellcheck disable=SC2034  # EHC_SOURCE_ONLY and LOGF are read by exported-home-config.sh
installer_fn() {
  mkdir -p "$(dirname "$LOG")"
  ( EHC_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    . "$INSTALLER" || exit 1
    LOGF=$LOG; mkdir -p "$BIN" "$WORK/dl" "$WORK/x" "$CFG"; export PATH="$BIN:$PATH"
    "$@" ) >>"$LOG" 2>&1
}
install_one() {  # same source and version as on the school PC
  case $1 in
    shellcheck) installer_fn install_gh koalaman/shellcheck 'linux\.x86_64\.tar\.xz$' shellcheck ;;
    shfmt)      installer_fn install_gh mvdan/sh '^shfmt_v.*_linux_amd64$' 'shfmt_v*_linux_amd64:shfmt' ;;
    bats)       installer_fn install_bats ;;
    tldr)       installer_fn install_gh tealdeer-rs/tealdeer '^tealdeer-linux-x86_64-musl$' tealdeer-linux-x86_64-musl:tldr \
                  && installer_fn tldr_pages ;;
    eza)        installer_fn install_gh eza-community/eza '^eza_x86_64-unknown-linux-musl\.tar\.gz$' eza ;;
    delta)      installer_fn install_gh dandavison/delta 'x86_64-unknown-linux-musl\.tar\.gz$' delta ;;
    watchexec)  installer_fn install_gh watchexec/watchexec 'x86_64-unknown-linux-musl\.tar\.xz$' watchexec ;;
    trash-put)  timeout 900 pipx install --force trash-cli >>"$LOG" 2>&1 ;;
    clang-tidy|clang-format) timeout 900 pipx install --force "$1" >>"$LOG" 2>&1 ;;
    *) return 1 ;;
  esac
}
install_list() {
  local o n; mkdir -p "$(dirname "$LOG")"
  for o in "$@"; do
    n=${o/trash-put/trash-cli}; printf '   ... %s\n' "$n"
    if install_one "$o"; then ok "$n installed"; else fail "$n (see $LOG)"; fi
  done
}
adapt_memo() {   # the school cheat sheet, adjusted to this PC (autojump, Klipper, no tmux...)
  local f="$CFG/memo.md"
  [ -f "$f" ] || return 0
  sed -i -e 's/^# Mémo$/# Mémo (PC maison)/' \
         -e '/^| `z tp1` |/d' \
         -e 's/^| `j dossier` | comme autojump (zoxide) |/| `j dossier` | sauter à un dossier déjà visité (autojump) |/' \
         -e 's/historique CopyQ de tout/historique Klipper de tout/' \
         -e '/^## Tes fichiers perso/,$d' "$f"
  command -v tmux >/dev/null || sed -i -e '/^| tmux |/d' -e '/^## tmux$/,/^$/d' "$f"
  command -v gedit >/dev/null || sed -i '/^| `gedit fichier` |/d' "$f"
}

# ---- 0. Rename what an older version of this script created -----------------
OLD_BASH_LUA_V2='-- Scripts bash (comme à la fac) : bashls = complétion, doc, et erreurs shellcheck.'
OLD_BLOCK_BEGIN='# >>> ajouts fac (reparer-maison) >>>'
OLD_BLOCK_END='# <<< ajouts fac (reparer-maison) <<<'
BLOCK_BEGIN='# >>> fix-home-config >>>'
BLOCK_END='# <<< fix-home-config <<<'
write_bash_lua() {
  mkdir -p "$NV/lua/plugins"
  cat >"$NV/lua/plugins/bash.lua" <<'LUA'
-- Bash: bashls (completion, docs, shellcheck). nvim-lint runs shellcheck only when bashls is missing.
return {
  { "neovim/nvim-lspconfig", opts = function(_, opts)
      opts.servers = opts.servers or {}
      if vim.fn.executable("npm") == 1 or vim.fn.executable("bash-language-server") == 1 then
        opts.servers.bashls = {}
      end
    end },
  { "mfussenegger/nvim-lint", opts = function(_, opts)
      if vim.fn.executable("npm") == 0 and vim.fn.executable("bash-language-server") == 0 then
        opts.linters_by_ft = opts.linters_by_ft or {}
        opts.linters_by_ft.sh = { "shellcheck" }
        opts.linters_by_ft.bash = { "shellcheck" }
      end
    end },
}
LUA
}
write_cmdline_lua() {
  cat >"$NV/lua/plugins/cmdline-bottom.lua" <<'LUA'
-- Classic command line and messages at the bottom (delete this file to go back to noice)
return {
  { "folke/noice.nvim", opts = { cmdline = { enabled = false }, messages = { enabled = false } } },
}
LUA
}
fix_rename() {
  title "0. Old names and French comments"
  local old_cfg="$HOME/.config/kit-etudiant" todo=()
  [ -d "$old_cfg" ] && [ ! -e "$CFG" ] && todo+=("~/.config/kit-etudiant -> ~/.config/exported-home-config, kit-projet/kit-aide/doc-c -> cnew/memo/cdoc")
  grep -qxF "$OLD_BLOCK_BEGIN" ~/.zshrc 2>/dev/null && todo+=("block at the end of ~/.zshrc: English comments")
  grep -q '>>> kit-etudiant >>>' ~/.gdbinit 2>/dev/null && todo+=("~/.gdbinit block markers")
  [ -f "$NV/lua/plugins/commande-en-bas.lua" ] && todo+=("lua/plugins/commande-en-bas.lua -> cmdline-bottom.lua")
  [ "$(head -1 "$NV/lua/plugins/bash.lua" 2>/dev/null)" = "$OLD_BASH_LUA_V2" ] && todo+=("lua/plugins/bash.lua: English comments")
  [ ${#todo[@]} -gt 0 ] || { skip "nothing to rename"; return; }
  say "An older version of this script used French names and comments. Renaming:" "${todo[@]/#/  }"
  confirm "Rename?" || { skip "old names kept"; return; }

  if [ -d "$old_cfg" ] && [ ! -e "$CFG" ]; then
    local cmds=()
    [ -e "$BIN/kit-projet" ] && cmds+=(cnew); [ -e "$BIN/kit-aide" ] && cmds+=(memo); [ -e "$BIN/doc-c" ] && cmds+=(cdoc)
    mv "$old_cfg" "$CFG"
    [ -f "$CFG/manifeste" ] && mv "$CFG/manifeste" "$CFG/manifest"
    rm -rf "$CFG/modeles" "$CFG/aide.md" "$HOME/.cache/kit-etudiant"
    rm -f "$BIN/kit-projet" "$BIN/kit-aide" "$BIN/doc-c"
    [ -f "$CFG/manifest" ] && sed -i -e '\#/kit-projet$#d' -e '\#/kit-aide$#d' -e '\#/doc-c$#d' "$CFG/manifest"
    if [ ${#cmds[@]} -gt 0 ] && need_installer; then
      local c r=0
      for c in "${cmds[@]}"; do
        case $c in
          cnew) installer_fn write_templates || r=1 ;;
          memo) { installer_fn write_memo && adapt_memo; } || r=1 ;;
          cdoc) installer_fn write_cdoc || r=1 ;;
        esac
      done
      [ $r -eq 0 ] && ok "commands renamed: ${cmds[*]}" || fail "commands (see $LOG)"
    else ok "~/.config/exported-home-config"; fi
  fi
  if grep -qxF "$OLD_BLOCK_BEGIN" ~/.zshrc 2>/dev/null; then
    backup ~/.zshrc
    sed -i -e "s|^$OLD_BLOCK_BEGIN\$|$BLOCK_BEGIN|" -e "s|^$OLD_BLOCK_END\$|$BLOCK_END|" \
      -e '/^# >>> fix-home-config >>>$/,/^# <<< fix-home-config <<<$/{s/ *# dossier en arbre$//; s/ *# corbeille au lieu de rm$//; s/ *# créer un dossier et y entrer$//}' ~/.zshrc \
      && ok "~/.zshrc block" || fail "~/.zshrc block"
  fi
  if grep -q '>>> kit-etudiant >>>' ~/.gdbinit 2>/dev/null; then
    sed -i -e 's/>>> kit-etudiant >>>/>>> exported-home-config >>>/' -e 's/<<< kit-etudiant <<</<<< exported-home-config <<</' \
      -e 's/^Active gdb-dashboard (panneaux source, variables, pile). Taper : dash$/Show gdb-dashboard (source, variables, stack). Type: dash/' ~/.gdbinit \
      && ok "~/.gdbinit markers" || fail "~/.gdbinit"
  fi
  if [ -f "$NV/lua/plugins/commande-en-bas.lua" ]; then
    write_cmdline_lua && rm -f "$NV/lua/plugins/commande-en-bas.lua" && ok "cmdline-bottom.lua" || fail "cmdline-bottom.lua"
  fi
  if [ "$(head -1 "$NV/lua/plugins/bash.lua" 2>/dev/null)" = "$OLD_BASH_LUA_V2" ]; then
    write_bash_lua && ok "bash.lua" || fail "bash.lua"
  fi
}

# ---- 1. C: -std=c11 hides POSIX functions -----------------------------------
fix_cflags() {
  title "1. C compiler flags: hidden POSIX functions"
  if ! grep -q 'export CFLAGS="-std=c11 ' ~/.zshrc 2>/dev/null; then skip "CFLAGS not found in ~/.zshrc"; return; fi
  if grep -q '_DEFAULT_SOURCE' ~/.zshrc; then skip "already fixed"; return; fi
  say "With -std=c11 alone, strdup, getline, kill, fileno... are not declared." \
      "Result: warnings, and strdup returning a truncated pointer (crash)." \
      "Fix: add -D_DEFAULT_SOURCE to CFLAGS (crun, csan, cmem, cdebug)."
  confirm "Fix ~/.zshrc?" || { skip "CFLAGS unchanged"; return; }
  backup ~/.zshrc
  sed -i 's/export CFLAGS="-std=c11 /export CFLAGS="-std=c11 -D_DEFAULT_SOURCE /' ~/.zshrc && ok "CFLAGS fixed" || fail "CFLAGS"
}

# ---- 2. thefuck: loaded twice, broken with Python 3.12 ----------------------
fix_thefuck() {
  title "2. thefuck"
  local plugin=0; grep -qw thefuck ~/.zsh-plugins 2>/dev/null && plugin=1
  if [ $plugin -eq 1 ] && grep -q '^eval $(thefuck --alias)' ~/.zshrc 2>/dev/null; then
    say "thefuck is loaded twice: by the oh-my-zsh plugin AND by an eval line in ~/.zshrc." \
        "It slows down every new terminal."
    if confirm "Remove the duplicate line from ~/.zshrc?"; then
      backup ~/.zshrc; sed -i '/^eval $(thefuck --alias)$/d' ~/.zshrc && ok "thefuck duplicate removed" || fail "thefuck duplicate"
    else skip "thefuck duplicate kept"; fi
  else skip "no duplicate"; fi
  if command -v thefuck >/dev/null && ! thefuck --version >/dev/null 2>&1; then
    say "thefuck crashes (it does not work with Python 3.12: the imp module was removed)." \
        "Fix: install it with Python 3.11 through pipx."
    if confirm "Install thefuck with Python 3.11?"; then
      pipx install --force --python python3.11 thefuck && ok "thefuck fixed (Python 3.11)" || fail "thefuck"
    else skip "thefuck left broken"; fi
  else skip "thefuck works (or is not installed)"; fi
}

# ---- 3. git --------------------------------------------------------------------
fix_git() {
  title "3. git"
  local mail; mail=$(git config --global --get user.mail 2>/dev/null)
  if [ -n "$mail" ]; then
    say "The key \"user.mail\" is a typo and git ignores it. The right key is \"user.email\"."
    if confirm "Fix it?"; then
      [ -z "$(git config --global --get user.email)" ] && git config --global user.email "$mail"
      git config --global --unset user.mail && ok "user.mail -> user.email" || fail "user.mail"
    else skip "user.mail kept"; fi
  else skip "no user.mail typo"; fi
  local key='includeIf.hasconfig:remote.*.url:https://git.unistra.fr/**.path'
  if [ -f ~/.gitconfig-unistra ] && [ -z "$(git config --global --get "$key")" ]; then
    say "The school identity (~/.gitconfig-unistra) only applies to repos cloned with SSH," \
        "not to repos cloned with https://git.unistra.fr."
    if confirm "Add the https rule?"; then
      git config --global "$key" "~/.gitconfig-unistra" && ok "school identity also for https" || fail "includeIf https"
    else skip "includeIf https not added"; fi
  else skip "school identity: nothing to do"; fi
}

# ---- 4. Tools LazyVim needs ----------------------------------------------------
gh_lazygit() {
  local tag h
  tag=$(curl -fsSI https://github.com/jesseduffield/lazygit/releases/latest | tr -d '\r' | sed -n 's#^[Ll]ocation: .*/tag/##p')
  h=$(curl -fsSL "https://github.com/jesseduffield/lazygit/releases/expanded_assets/$tag" \
      | grep -o 'href="[^"]*_linux_x86_64\.tar\.gz"' | head -1 | sed 's/^href="//;s/"$//')
  [ -n "$h" ] || return 1
  mkdir -p "$BIN" && curl -fsSL "https://github.com$h" | tar -xz -C "$BIN" lazygit
}
fix_tools() {
  title "4. Tools LazyVim needs"
  local pkgs=()
  command -v rg >/dev/null      || pkgs+=(ripgrep)
  command -v fdfind >/dev/null || command -v fd >/dev/null || pkgs+=(fd-find)
  command -v wl-copy >/dev/null || pkgs+=(wl-clipboard)
  if [ ${#pkgs[@]} -gt 0 ]; then
    say "ripgrep: search text (Space /)   fd: find a file (Space Space)" \
        "wl-clipboard: on Wayland, without it \"y\" in Neovim does NOT reach the system clipboard" \
        "To install: ${pkgs[*]}"
    if confirm "Install with apt (asks for sudo)?"; then
      sudo apt install -y "${pkgs[@]}" && ok "installed: ${pkgs[*]}" || fail "apt ${pkgs[*]}"
    else skip "${pkgs[*]} not installed"; fi
  else skip "ripgrep, fd, wl-clipboard already there"; fi
  if [ "$DRY" -eq 0 ] && command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
    mkdir -p "$BIN"; ln -sf "$(command -v fdfind)" "$BIN/fd" && ok "fd command (link to fdfind)"
  fi
  if ! command -v lazygit >/dev/null; then
    say "lazygit: git in menus, opened with Space g g in LazyVim. Not in apt for Ubuntu 24.04."
    if confirm "Download lazygit into ~/.local/bin?"; then gh_lazygit && ok "lazygit installed" || fail "lazygit"
    else skip "lazygit not installed"; fi
  else skip "lazygit already there"; fi
  local nmaj=0; command -v node >/dev/null && nmaj=$(node -v | sed 's/^v//;s/\..*//')
  if [ "$nmaj" -lt 20 ]; then
    say "Node missing or too old: Mason cannot install the bash language server (completion, docs in scripts)."
    if confirm "Install Node 22 with snap (asks for sudo)?"; then
      sudo snap install node --classic --channel=22/stable && ok "Node 22 installed" || fail "Node"
    else skip "Node not installed"; fi
  else skip "Node $nmaj already there"; fi
}

# ---- 5. LazyVim: copy history, bash scripts, unused extra ---------------------
# first line of the bash.lua written by the first version of this script (shellcheck ran twice)
OLD_BASH_LUA_V1='-- Scripts bash : serveur de langage (complétion, doc) + shellcheck (erreurs). shfmt formate déjà.'
YANKY=lazyvim.plugins.extras.coding.yanky; VSCODE=lazyvim.plugins.extras.vscode
fix_lazyvim() {
  title "5. LazyVim"
  [ -f "$NV/lazyvim.json" ] || { skip "LazyVim not found (~/.config/nvim/lazyvim.json)"; return; }
  command -v jq >/dev/null || { fail "jq missing"; return; }
  local fb="$NV/lua/plugins/bash.lua" json=0 bash=0
  jq -e --arg y "$YANKY" --arg v "$VSCODE" '(.extras // []) as $e | ($e | index($y)) != null and ($e | index($v)) == null' \
     "$NV/lazyvim.json" >/dev/null 2>&1 || json=1
  if [ ! -f "$fb" ] || [ "$(head -1 "$fb")" = "$OLD_BASH_LUA_V1" ]; then bash=1; fi
  if [ $json -eq 0 ] && [ $bash -eq 0 ]; then skip "yanky and bash support already there"; return; fi
  [ $json -eq 1 ] && say "Add \"yanky\": history of everything you copy (Space p), like at school." \
       "Remove the \"vscode\" extra: only useful with the vscode-neovim extension, not installed here."
  if [ $bash -eq 1 ] && [ -f "$fb" ]; then
    say "Fix lua/plugins/bash.lua: shellcheck runs twice (through bashls AND nvim-lint)," \
        "so errors show up twice and Neovim is slower in scripts. Like at school: only once."
  elif [ $bash -eq 1 ]; then
    say "Add bash support: language server + shellcheck (errors in your scripts)."
  fi
  confirm "Change your LazyVim config?" || { skip "LazyVim unchanged"; return; }
  if [ $json -eq 1 ]; then
    backup "$NV/lazyvim.json"
    local tmp; tmp=$(mktemp)
    if jq --arg y "$YANKY" --arg v "$VSCODE" '.extras = (((.extras // []) + [$y]) | unique | map(select(. != $v)))' \
         "$NV/lazyvim.json" >"$tmp" && cat "$tmp" >"$NV/lazyvim.json"; then ok "extras: + yanky, - vscode"; else fail "lazyvim.json"; fi
    rm -f "$tmp"
  fi
  if [ $bash -eq 1 ]; then
    backup "$fb"; write_bash_lua
    ok "lua/plugins/bash.lua: shellcheck runs once"
  fi
  local NVIM; NVIM=$(command -v nvim) || { fail "nvim not found"; return; }
  say "Downloading plugins and tools (1 to 2 minutes)..."
  timeout 600 "$NVIM" --headless "+Lazy! install" +qa >/dev/null 2>&1 && ok "plugins up to date (yanky)" || fail "Lazy install"
  local lua; lua=$(mktemp --suffix=.lua)
  cat >"$lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim" } })
local reg = require("mason-registry")
pcall(reg.refresh)
vim.wait(4000, function() return false end, 100)   -- let LazyVim start its own installs first
local names = vim.split(vim.env.FIX_MASON or "", " ", { trimempty = true })
for _, n in ipairs(names) do
  local ok, p = pcall(reg.get_package, n)
  if ok and not p:is_installed() and not p:is_installing() then pcall(function() p:install() end) end
end
vim.wait(600000, function()
  for _, p in ipairs(reg.get_all_packages()) do if p:is_installing() then return false end end
  return true
end, 1000)
for _, n in ipairs(names) do
  local ok, p = pcall(reg.get_package, n)
  io.stdout:write(n .. ": " .. ((ok and p:is_installed()) and "OK" or "FAILED") .. "\n")
end
LUA
  local tools="shellcheck bash-language-server"
  grep -q 'extras.lang.docker' "$NV/lazyvim.json" && tools="$tools dockerfile-language-server docker-compose-language-service hadolint"
  grep -q 'extras.lang.yaml' "$NV/lazyvim.json" && tools="$tools yaml-language-server"
  command -v npm >/dev/null || say "npm missing: the bash, docker and yaml servers will fail (step 4: Node)."
  FIX_MASON="$tools" timeout 900 "$NVIM" --headless "+luafile $lua" +qa 2>/dev/null | sed 's/^/   /'
  rm -f "$lua"
}

# ---- 5b. Treesitter: red "query.lua ... tab" errors --------------------------
TS_LANGS="c cpp bash make lua luadoc vim vimdoc regex query markdown markdown_inline diff printf json yaml dockerfile python toml"
ts_check() {     # prints OK or the languages whose highlight queries fail
  local NVIM=$1 lua; lua=$(mktemp --suffix=.lua)
  cat >"$lua" <<'LUA'
require("lazy").load({ plugins = { "nvim-treesitter" } })
local bad = {}
for _, l in ipairs(vim.split(vim.env.TS_LANGS or "", " ", { trimempty = true })) do
  for _, q in ipairs({ "highlights", "injections" }) do
    local ok, err = pcall(vim.treesitter.query.get, l, q)
    if not ok then table.insert(bad, l .. "/" .. q .. ": " .. (tostring(err):gsub("%s+", " "):sub(1, 100))) end
  end
end
io.stdout:write(#bad == 0 and "OK\n" or (table.concat(bad, "\n") .. "\n"))
LUA
  TS_LANGS="$TS_LANGS" timeout 120 "$NVIM" --headless "+luafile $lua" +qa 2>/dev/null
  rm -f "$lua"
}
ts_rebuild() {
  local NVIM=$1 lua; lua=$(mktemp --suffix=.lua)
  cat >"$lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
local ok, ts = pcall(require, "nvim-treesitter")
local langs = vim.split(vim.env.TS_LANGS or "c", " ", { trimempty = true })
if ok and type(ts.install) == "function" then
  local t = ts.install(langs, { force = true }); if t and t.wait then t:wait(900000) end
else vim.cmd("TSInstallSync! " .. table.concat(langs, " ")) end
LUA
  TS_LANGS="$TS_LANGS" timeout 1200 "$NVIM" --headless "+luafile $lua" +qa >/dev/null 2>&1
  rm -f "$lua"
}
fix_treesitter() {
  title "5b. Treesitter (red errors, invisible command line)"
  local NVIM; NVIM=$(command -v nvim) || { skip "nvim not found"; return; }
  [ -d "$NV" ] || { skip "no Neovim config"; return; }
  local before; before=$(ts_check "$NVIM")
  if [ "$before" = OK ]; then skip "highlight queries: no error"; return; fi
  say "Some highlight queries do not match your parsers anymore:" "$(printf '%s\n' "$before" | head -5 | sed 's/^/     /')" \
      "This is what shows the red errors and breaks the command line (noice)." \
      "Fix: update the plugins, then rebuild all parsers (1 to 3 minutes)."
  confirm "Fix it?" || { skip "treesitter unchanged"; return; }
  local d="$HOME/.local/share/nvim/site"
  rm -rf "$d/parser" "$d/parser-info" "$d/queries"
  timeout 900 "$NVIM" --headless "+Lazy! sync" +qa >/dev/null 2>&1 || say "Lazy sync: timeout, going on"
  ts_rebuild "$NVIM"
  local after; after=$(ts_check "$NVIM")
  if [ "$after" != OK ]; then
    # second try: the plugin files themselves are damaged, reinstall it clean
    say "Still errors: nvim-treesitter itself is damaged. Clean reinstall..."
    rm -rf "$HOME/.local/share/nvim/lazy/nvim-treesitter" "$d/parser" "$d/parser-info" "$d/queries"
    timeout 900 "$NVIM" --headless "+Lazy! install" +qa >/dev/null 2>&1
    ts_rebuild "$NVIM"
    after=$(ts_check "$NVIM")
  fi
  if [ "$after" = OK ]; then ok "parsers rebuilt, no error left"
  else fail "treesitter: still errors ($(printf '%s' "$after" | head -1))"; fi
}

# ---- 5c. Command line at the bottom (instead of the floating window) ---------
fix_noice() {
  title "5c. Neovim command line (invisible)"
  [ -d "$NV/lua/plugins" ] || { skip "no LazyVim config"; return; }
  if grep -qs 'enabled = false' "$NV/lua/plugins/cmdline-bottom.lua" "$NV/lua/plugins/commande-en-bas.lua"; then
    skip "classic command line already there"; return
  fi
  say "When you type \":\", nothing shows up: noice draws the command line, and it crashes." \
      "Safe fix: give the command line and messages back to Neovim, at the bottom of the screen," \
      "like in Vim. They always show up, even if a plugin has a problem."
  confirm "Put the classic command line back at the bottom?" || { skip "command line left to noice"; return; }
  write_cmdline_lua
  ok "classic command line at the bottom (delete lua/plugins/cmdline-bottom.lua to go back)"
}

# ---- 6. Cleanup --------------------------------------------------------------
fix_cleanup() {
  title "6. Cleanup"
  if [ -d ~/.vim/plugged ] && [ ! -f ~/.vimrc ] && [ ! -f ~/.vim/vimrc ] && grep -q 'alias vim="nvim"' ~/.zshrc 2>/dev/null; then
    say "~/.vim/plugged: Vim plugins with no config, and \"vim\" already opens Neovim here."
    if confirm "Delete ~/.vim/plugged (and ~/.vim/autoload/plug.vim)?"; then
      rm -rf ~/.vim/plugged ~/.vim/autoload/plug.vim && ok "old Vim plugins removed" || fail "~/.vim/plugged"
    else skip "~/.vim/plugged kept"; fi
  else skip "~/.vim/plugged: nothing to do"; fi
  if [ -d "$NV.bak" ] && [ -z "$(ls -A "$NV.bak")" ]; then
    say "~/.config/nvim.bak: empty folder."
    if confirm "Delete it?"; then rmdir "$NV.bak" && ok "~/.config/nvim.bak removed"; else skip "nvim.bak kept"; fi
  fi
  if command -v flatpak >/dev/null; then
    say "Duplicate flatpak runtimes (GL.default x6, KDE Platform x3): wasted space."
    if confirm "Run \"flatpak uninstall --unused\"?"; then
      flatpak uninstall --unused -y && ok "unused flatpak runtimes removed" || fail "flatpak --unused"
    else skip "flatpak unchanged"; fi
  fi
  if dpkg -s docker-compose >/dev/null 2>&1; then
    say "docker-compose (version 1, Python) is abandoned. Replacement: \"docker compose\" (v2)."
    if confirm "Install docker-compose-v2 and remove the old one (asks for sudo)?"; then
      sudo apt install -y docker-compose-v2 && sudo apt remove -y docker-compose && ok "docker compose v2" || fail "docker-compose"
    else skip "docker-compose v1 kept"; fi
  fi
}

# =============================================================================
#  7. SCHOOL ADDITIONS: only what is missing here
#     (Konsole, Klipper, autojump, my zsh and my Neovim stay as they are)
# =============================================================================
add_scripts() {
  title "7a. Bash scripts: shellcheck, shfmt, bats"
  local a=(); missing shellcheck && a+=(shellcheck); missing shfmt && a+=(shfmt); missing bats && a+=(bats)
  [ ${#a[@]} -gt 0 ] || { skip "shellcheck, shfmt, bats already there"; return; }
  say "shellcheck tp.sh: lists the errors of a script, in the terminal" \
      "shfmt -d tp.sh / -w tp.sh: shows / fixes the formatting of a script" \
      "bats: automated tests for bash scripts" \
      "To install into ~/.local/bin: ${a[*]}"
  need_installer || return
  confirm "Install?" || { skip "${a[*]} not installed"; return; }
  install_list "${a[@]}"
}

add_terminal() {
  title "7b. Terminal: tldr, eza, delta, watchexec, trash-cli"
  local a=()
  missing tldr && a+=(tldr); missing eza && a+=(eza); missing delta && a+=(delta)
  missing watchexec && a+=(watchexec); missing trash-put && a+=(trash-put)
  [ ${#a[@]} -gt 0 ] || { skip "tldr, eza, delta, watchexec, trash-cli already there"; return; }
  say "tldr tar: short examples of a command, in French (faster than man)" \
      "eza: for the \"lt\" alias (folder as a tree, like at school)" \
      "delta: readable git diff / git log -p (colors, line numbers)" \
      "watchexec -e c,h -- make run: rebuild and rerun on every save" \
      "trash-cli: for the \"tp\" alias (trash instead of rm; trash-list, trash-restore)" \
      "To install into ~/.local/bin: ${a[*]/trash-put/trash-cli (pipx)}"
  need_installer || return
  confirm "Install?" || { skip "${a[*]/trash-put/trash-cli} not installed"; return; }
  install_list "${a[@]}"
}

add_c_tools() {
  title "7c. C: Check tests, clang-tidy, clang-format, gdb-dashboard"
  if ! pkg-config --exists check 2>/dev/null; then
    local p=(check); missing pkg-config && p+=(pkg-config)
    say "Check: unit test library, for \"make test\" in a cnew project." \
        "To install with apt: ${p[*]}"
    if confirm "Install with apt (asks for sudo)?"; then
      sudo apt install -y "${p[@]}" && ok "installed: ${p[*]}" || fail "apt ${p[*]}"
    else skip "Check not installed"; fi
  else skip "Check already there"; fi
  local a=(); missing clang-tidy && a+=(clang-tidy); missing clang-format && a+=(clang-format)
  if [ ${#a[@]} -gt 0 ]; then
    say "clang-tidy: \"make tidy\", finds likely bugs (leaks, overflows...)" \
        "clang-format: \"make format\", formats the whole project at once" \
        "To install with pipx: ${a[*]}"
    command -v pipx >/dev/null || { fail "pipx missing"; a=(); }
    if [ ${#a[@]} -gt 0 ]; then
      if confirm "Install?"; then install_list "${a[@]}"; else skip "${a[*]} not installed"; fi
    fi
  else skip "clang-tidy, clang-format already there"; fi
  if [ -f ~/.gdb-dashboard ] && grep -x 'define dash' ~/.gdbinit >/dev/null 2>&1; then skip "gdb-dashboard already there"; return; fi
  say "gdb-dashboard: in gdb (or cdebug), type \"dash\": source, variables, stack in panels." \
      "Also adds to ~/.gdbinit (backed up): saved history, readable structs."
  need_installer || return
  confirm "Install?" || { skip "gdb-dashboard not installed"; return; }
  mkdir -p "$(dirname "$LOG")"
  if curl -fsSL https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/master/.gdbinit -o ~/.gdb-dashboard 2>>"$LOG" \
     && installer_fn write_gdbinit; then ok "gdb-dashboard (dash command in gdb)"; else fail "gdb-dashboard (see $LOG)"; fi
}

add_project() {
  title "7d. Projects: cnew, memo, cdoc"
  local a=(); missing cnew && a+=(cnew); missing memo && a+=(memo); missing cdoc && a+=(cdoc)
  [ ${#a[@]} -gt 0 ] || { skip "cnew, memo, cdoc already there"; return; }
  say "cnew tp3: creates a ready C project (Makefile: make run, test, valgrind, analyse, tidy, format)" \
      "memo: the school cheat sheet (zsh, Neovim, gdb shortcuts), adjusted to this PC" \
      "cdoc: the full offline C documentation (cppreference) in the browser" \
      "To add: ${a[*]}   (templates and cheat sheet in ~/.config/exported-home-config)"
  need_installer || return
  confirm "Add?" || { skip "${a[*]} not added"; return; }
  local o
  for o in "${a[@]}"; do
    case $o in
      cnew) if installer_fn write_templates; then ok "cnew"; else fail "cnew (see $LOG)"; fi ;;
      memo) if installer_fn write_memo && adapt_memo; then ok "memo"; else fail "memo (see $LOG)"; fi ;;
      cdoc) printf '   ... cdoc (downloading the docs)\n'
            if installer_fn install_cppref; then ok "cdoc"; else fail "cdoc (see $LOG)"; fi ;;
    esac
  done
}

add_shortcuts() {
  title "7e. School shortcuts: lt, lg, tp, mkcd, git lg"
  if [ ! -f ~/.zshrc ]; then skip "~/.zshrc not found"
  elif grep -qxF "$BLOCK_BEGIN" ~/.zshrc || grep -qxF "$OLD_BLOCK_BEGIN" ~/.zshrc; then skip "school aliases already in ~/.zshrc"
  else
    local l=()
    grep -q '^[^#]*alias lt=' ~/.zshrc || l+=("(( \$+commands[eza] ))       && alias lt='eza --tree --level=2 --icons=auto'")
    grep -q '^[^#]*alias lg=' ~/.zshrc || l+=("(( \$+commands[lazygit] ))   && alias lg=lazygit")
    grep -q '^[^#]*alias tp=' ~/.zshrc || l+=("(( \$+commands[trash-put] )) && alias tp=trash-put")
    grep -q 'mkcd *()' ~/.zshrc        || l+=('mkcd() { mkdir -p -- "$1" && cd -- "$1"; }')
    if [ ${#l[@]} -eq 0 ]; then skip "lt, lg, tp, mkcd already defined"
    else
      say "A few lines at the end of ~/.zshrc (backed up first), like at school:" \
          "  lt: folder as a tree (replaces the \"lt\" of common-aliases, which sorted by date)" \
          "  lg: lazygit      tp file: trash      mkcd dir: create it and cd into it"
      if confirm "Add to ~/.zshrc?"; then
        backup ~/.zshrc
        { printf '\n%s\n' "$BLOCK_BEGIN"
          printf '%s\n' '# School aliases (same as exported-home-config)' \
            '[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || path=("$HOME/.local/bin" $path)' "${l[@]}" "$BLOCK_END"
        } >>~/.zshrc && ok "aliases added to ~/.zshrc" || fail "~/.zshrc"
      else skip "aliases not added"; fi
    fi
  fi
  command -v git >/dev/null || return
  local g=()
  [ -z "$(git config --global --get alias.lg)" ] && g+=("alias.lg=log --oneline --graph --decorate --all")
  [ -z "$(git config --global --get init.defaultBranch)" ] && g+=("init.defaultBranch=main")
  if command -v delta >/dev/null && [ -z "$(git config --global --get core.pager)" ]; then
    g+=("core.pager=delta" "interactive.diffFilter=delta --color-only" "delta.navigate=true" "delta.line-numbers=true")
  fi
  [ ${#g[@]} -gt 0 ] || { skip "git: school settings already there"; return; }
  say "git, like at school (only the settings you do not have yet):" "${g[@]/#/  }"
  [ -n "$(git config --global --get alias.lg)" ] || say "git lg: history as a graph, all branches"
  [[ " ${g[*]} " == *" core.pager=delta "* ]] && say "delta: colored diffs with line numbers (n / N to jump between files)"
  confirm "Set up git?" || { skip "git unchanged"; return; }
  local kv r=0
  for kv in "${g[@]}"; do git config --global "${kv%%=*}" "${kv#*=}" || r=1; done
  [ $r -eq 0 ] && ok "git: ${#g[@]} school setting(s)" || fail "git config"
}

# ---- 8. Good to know (nothing changed) ---------------------------------------
notes() {
  title "8. Good to know (nothing changed)"
  grep -q 'QT_QPA_PLATFORM=xcb' ~/.zshrc 2>/dev/null && say \
    "~/.zshrc forces QT_QPA_PLATFORM=xcb: Qt apps started from the terminal run on X11" \
    "instead of Wayland (sometimes blurry). If it was only for LibreOffice, you can remove it."
  command -v neofetch >/dev/null && say "neofetch is no longer maintained: fastfetch replaces it."
  say "Docker images: \"docker system df\" shows the space, \"docker image prune\" cleans up."
}

printf '%sfix-home-config%s - backups: *.before-fix-%s\n' "$BLU" "$RST" "$DATE"
chosen rename && fix_rename
chosen cflags && fix_cflags
chosen thefuck && fix_thefuck
chosen git && fix_git
chosen tools && fix_tools
chosen lazyvim && fix_lazyvim
chosen treesitter && fix_treesitter
chosen noice && fix_noice
chosen cleanup && fix_cleanup
chosen scripts && add_scripts
chosen terminal && add_terminal
chosen c-tools && add_c_tools
chosen project && add_project
chosen shortcuts && add_shortcuts
[ -z "$ONLY" ] && notes
printf '\n%s==================== SUMMARY ====================%s\n' "$BLU" "$RST"
printf '%sdone: %d%s   %sfailed: %d%s   %sskipped: %d%s\n' "$GRN" "${#DONE[@]}" "$RST" "$RED" "${#FAILED[@]}" "$RST" "$YEL" "${#SKIPPED[@]}" "$RST"
[ ${#FAILED[@]} -gt 0 ] && printf '   FAILED: %s\n' "${FAILED[@]}"
[ -f "$LOG" ] && echo "Download log: $LOG"
echo "Open a new terminal to get the ~/.zshrc changes."
