#!/usr/bin/env bash
# =============================================================================
#  reparer-maison.sh — Répare les problèmes trouvés sur ton PC maison (KDE neon)
#  et ajoute ce que la fac a en plus (seulement ce qui manque ici).
#  Chaque réparation est expliquée et demande ton accord. Fichiers sauvegardés
#  avant modification (suffixe .avant-reparation-DATE). sudo demandé seulement
#  pour installer des paquets.
# =============================================================================
#  Usage : bash reparer-maison.sh          (demande pour chaque réparation)
#          bash reparer-maison.sh --voir   (montre ce qui serait fait, ne touche à rien)
#          bash reparer-maison.sh --oui    (accepte tout)
#          bash reparer-maison.sh --seulement treesitter,noice   (seulement ces réparations)
#  Réparations : cflags thefuck git outils lazyvim treesitter noice menage
#  Ajouts de la fac : scripts terminal outils-c projet raccourcis
#  (les ajouts utilisent kit-etudiant.sh : mets-le dans le même dossier que ce script)
# =============================================================================
# shellcheck disable=SC2088  # les « ~/ » entre guillemets sont des libellés affichés (git sait développer ~ lui-même)
set -uo pipefail
VOIR=0; OUI=0; SEUL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --voir) VOIR=1 ;; --oui) OUI=1 ;;
    --seulement) shift; SEUL=${1:-} ;; --seulement=*) SEUL=${1#*=} ;;
    -h|--aide) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "option inconnue : $1"; exit 1 ;;
  esac; shift
done
choisi() { [ -z "$SEUL" ] || [[ ",$SEUL," == *",$1,"* ]]; }
[ "$(id -u)" -eq 0 ] && { echo "Lance-le avec ton utilisateur : il demandera sudo quand il en a besoin."; exit 1; }

DATE=$(date +%Y%m%d-%H%M)
BIN="$HOME/.local/bin"; NV="$HOME/.config/nvim"
if [ -t 1 ]; then V=$'\e[32m'; R=$'\e[31m'; J=$'\e[33m'; B=$'\e[1;34m'; N=$'\e[0m'; else V=""; R=""; J=""; B=""; N=""; fi
declare -a FAIT=() RATE=() SAUTE=()

titre()  { printf '\n%s== %s%s\n' "$B" "$1" "$N"; }
expl()   { printf '   %s\n' "$@"; }
ok()     { FAIT+=("$1"); printf '   %s✔ %s%s\n' "$V" "$1" "$N"; }
ko()     { RATE+=("$1"); printf '   %s✘ %s%s\n' "$R" "$1" "$N"; }
saute()  { SAUTE+=("$1"); printf '   %s– %s%s\n' "$J" "$1" "$N"; }
accord() {  # accord "question" : 0 si oui
  [ "$VOIR" -eq 1 ] && { printf '   %s(--voir : rien n'"'"'est modifié)%s\n' "$J" "$N"; return 1; }
  [ "$OUI" -eq 1 ] && return 0
  local r; read -rp "   → $1 [o/N] " r; [[ $r == [oOyY] ]]
}
sauver() { [ -e "$1" ] && cp -a "$1" "$1.avant-reparation-$DATE"; }

# ---- 1. C : -std=c11 cache des fonctions POSIX --------------------------------
rep_cflags() {
  titre "1. Compilation C : fonctions POSIX invisibles"
  if ! grep -q 'export CFLAGS="-std=c11 ' ~/.zshrc 2>/dev/null; then saute "CFLAGS non trouvé dans ~/.zshrc"; return; fi
  if grep -q '_DEFAULT_SOURCE' ~/.zshrc; then saute "déjà corrigé"; return; fi
  expl "Avec -std=c11 seul, strdup, getline, kill, fileno… ne sont pas déclarées." \
       "Résultat : avertissements, et strdup qui renvoie un pointeur tronqué (plantage)." \
       "Correction : ajouter -D_DEFAULT_SOURCE à tes CFLAGS (crun, csan, cmem, cdebug)."
  accord "Corriger ~/.zshrc ?" || { saute "CFLAGS laissé tel quel"; return; }
  sauver ~/.zshrc
  sed -i 's/export CFLAGS="-std=c11 /export CFLAGS="-std=c11 -D_DEFAULT_SOURCE /' ~/.zshrc && ok "CFLAGS corrigé" || ko "CFLAGS"
}

# ---- 2. thefuck : chargé deux fois, et cassé avec Python 3.12 -----------------
rep_thefuck() {
  titre "2. thefuck"
  local plugin=0; grep -qw thefuck ~/.zsh-plugins 2>/dev/null && plugin=1
  if [ $plugin -eq 1 ] && grep -q '^eval $(thefuck --alias)' ~/.zshrc 2>/dev/null; then
    expl "thefuck est chargé deux fois : par le plugin oh-my-zsh ET par une ligne eval dans ~/.zshrc." \
         "Ça ralentit chaque ouverture de terminal pour rien."
    if accord "Retirer la ligne en double de ~/.zshrc ?"; then
      sauver ~/.zshrc; sed -i '/^eval $(thefuck --alias)$/d' ~/.zshrc && ok "doublon thefuck retiré" || ko "doublon thefuck"
    else saute "doublon thefuck laissé"; fi
  else saute "pas de doublon"; fi
  if command -v thefuck >/dev/null && ! thefuck --version >/dev/null 2>&1; then
    expl "thefuck plante (il ne marche pas avec Python 3.12 : module « imp » supprimé)." \
         "Correction : l'installer avec Python 3.11 via pipx (tu as déjà les deux)."
    if accord "Installer thefuck avec Python 3.11 ?"; then
      pipx install --force --python python3.11 thefuck && ok "thefuck réparé (Python 3.11)" || ko "thefuck"
    else saute "thefuck laissé cassé"; fi
  else saute "thefuck fonctionne (ou absent)"; fi
}

# ---- 3. git --------------------------------------------------------------------
rep_git() {
  titre "3. git"
  local mail; mail=$(git config --global --get user.mail 2>/dev/null)
  if [ -n "$mail" ]; then
    expl "Clé « user.mail » mal écrite : git l'ignore. La bonne clé est « user.email »."
    if accord "Corriger ?"; then
      [ -z "$(git config --global --get user.email)" ] && git config --global user.email "$mail"
      git config --global --unset user.mail && ok "user.mail → user.email" || ko "user.mail"
    else saute "user.mail laissé"; fi
  else saute "pas de faute user.mail"; fi
  local cle='includeIf.hasconfig:remote.*.url:https://git.unistra.fr/**.path'
  if [ -f ~/.gitconfig-unistra ] && [ -z "$(git config --global --get "$cle")" ]; then
    expl "Ton identité fac (~/.gitconfig-unistra) ne s'applique qu'aux dépôts clonés en SSH." \
         "Les dépôts clonés en https://git.unistra.fr ne l'utilisent pas."
    if accord "Ajouter la règle https ?"; then
      git config --global "$cle" "~/.gitconfig-unistra" && ok "identité fac aussi en https" || ko "includeIf https"
    else saute "includeIf https non ajouté"; fi
  else saute "identité fac : rien à faire"; fi
}

# ---- 4. outils manquants pour LazyVim -----------------------------------------
gh_lazygit() {
  local tag h
  tag=$(curl -fsSI https://github.com/jesseduffield/lazygit/releases/latest | tr -d '\r' | sed -n 's#^[Ll]ocation: .*/tag/##p')
  h=$(curl -fsSL "https://github.com/jesseduffield/lazygit/releases/expanded_assets/$tag" \
      | grep -o 'href="[^"]*_linux_x86_64\.tar\.gz"' | head -1 | sed 's/^href="//;s/"$//')
  [ -n "$h" ] || return 1
  mkdir -p "$BIN" && curl -fsSL "https://github.com$h" | tar -xz -C "$BIN" lazygit
}
rep_outils() {
  titre "4. Outils dont LazyVim a besoin"
  local paquets=()
  command -v rg >/dev/null      || paquets+=(ripgrep)
  command -v fdfind >/dev/null || command -v fd >/dev/null || paquets+=(fd-find)
  command -v wl-copy >/dev/null || paquets+=(wl-clipboard)
  if [ ${#paquets[@]} -gt 0 ]; then
    expl "ripgrep : chercher du texte (Espace /)   fd : chercher un fichier (Espace Espace)" \
         "wl-clipboard : sous Wayland, sans lui « y » dans Neovim ne va PAS dans le presse-papier du système" \
         "À installer : ${paquets[*]}"
    if accord "Installer avec apt (sudo demandé) ?"; then
      sudo apt install -y "${paquets[@]}" && ok "installé : ${paquets[*]}" || ko "apt ${paquets[*]}"
    else saute "${paquets[*]} non installés"; fi
  else saute "ripgrep, fd, wl-clipboard déjà là"; fi
  if [ "$VOIR" -eq 0 ] && command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
    mkdir -p "$BIN"; ln -sf "$(command -v fdfind)" "$BIN/fd" && ok "commande fd (lien vers fdfind)"
  fi
  if ! command -v lazygit >/dev/null; then
    expl "lazygit : git en menus, ouvert par Espace g g dans LazyVim. Pas dans apt pour Ubuntu 24.04."
    if accord "Télécharger lazygit dans ~/.local/bin ?"; then gh_lazygit && ok "lazygit installé" || ko "lazygit"
    else saute "lazygit non installé"; fi
  else saute "lazygit déjà là"; fi
  local nmaj=0; command -v node >/dev/null && nmaj=$(node -v | sed 's/^v//;s/\..*//')
  if [ "$nmaj" -lt 20 ]; then
    expl "Node absent ou trop vieux : Mason ne peut pas installer le serveur bash (complétion, doc dans les scripts)."
    if accord "Installer Node 22 avec snap (sudo demandé) ?"; then
      sudo snap install node --classic --channel=22/stable && ok "Node 22 installé" || ko "Node"
    else saute "Node non installé"; fi
  else saute "Node $nmaj déjà là"; fi
}

# ---- 5. LazyVim : historique des copies, scripts bash, extra inutile ----------
# 1re ligne du bash.lua écrit par une version précédente de ce script (shellcheck lancé deux fois)
BASH_LUA_V1='-- Scripts bash : serveur de langage (complétion, doc) + shellcheck (erreurs). shfmt formate déjà.'
YANKY=lazyvim.plugins.extras.coding.yanky; VSCODE=lazyvim.plugins.extras.vscode
rep_lazyvim() {
  titre "5. LazyVim"
  [ -f "$NV/lazyvim.json" ] || { saute "LazyVim introuvable (~/.config/nvim/lazyvim.json)"; return; }
  command -v jq >/dev/null || { ko "jq absent"; return; }
  local fb="$NV/lua/plugins/bash.lua" json=0 bash=0
  jq -e --arg y "$YANKY" --arg v "$VSCODE" '(.extras // []) as $e | ($e | index($y)) != null and ($e | index($v)) == null' \
     "$NV/lazyvim.json" >/dev/null 2>&1 || json=1
  if [ ! -f "$fb" ] || [ "$(head -1 "$fb")" = "$BASH_LUA_V1" ]; then bash=1; fi
  if [ $json -eq 0 ] && [ $bash -eq 0 ]; then saute "yanky et support bash déjà en place"; return; fi
  [ $json -eq 1 ] && expl "Ajouter « yanky » : historique de tout ce que tu copies (Espace p), comme à la fac." \
       "Retirer l'extra « vscode » : il ne sert qu'avec l'extension vscode-neovim, absente chez toi."
  if [ $bash -eq 1 ] && [ -f "$fb" ]; then
    expl "Corriger lua/plugins/bash.lua : shellcheck y est lancé deux fois (par bashls ET par nvim-lint)," \
         "d'où des erreurs en double et un Neovim plus lent dans les scripts. Comme à la fac : une seule fois."
  elif [ $bash -eq 1 ]; then
    expl "Ajouter le support bash : serveur de langage + shellcheck (erreurs dans tes scripts)."
  fi
  accord "Modifier ta config LazyVim ?" || { saute "LazyVim laissé tel quel"; return; }
  if [ $json -eq 1 ]; then
    sauver "$NV/lazyvim.json"
    local tmp; tmp=$(mktemp)
    if jq --arg y "$YANKY" --arg v "$VSCODE" '.extras = (((.extras // []) + [$y]) | unique | map(select(. != $v)))' \
         "$NV/lazyvim.json" >"$tmp" && cat "$tmp" >"$NV/lazyvim.json"; then ok "extras : + yanky, − vscode"; else ko "lazyvim.json"; fi
    rm -f "$tmp"
  fi
  if [ $bash -eq 1 ]; then
    mkdir -p "$NV/lua/plugins"; sauver "$fb"
    cat >"$fb" <<'LUA'
-- Scripts bash (comme à la fac) : bashls = complétion, doc, et erreurs shellcheck.
-- shellcheck une seule fois : bashls le lance déjà ; nvim-lint seulement si bashls est impossible (pas de npm).
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
    ok "lua/plugins/bash.lua : shellcheck une seule fois"
  fi
  local NVIM; NVIM=$(command -v nvim) || { ko "nvim introuvable"; return; }
  expl "Téléchargement des plugins et outils (1 à 2 minutes)…"
  timeout 600 "$NVIM" --headless "+Lazy! install" +qa >/dev/null 2>&1 && ok "plugins à jour (yanky)" || ko "Lazy install"
  local lua; lua=$(mktemp --suffix=.lua)
  cat >"$lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim" } })
local reg = require("mason-registry")
pcall(reg.refresh)
vim.wait(4000, function() return false end, 100)   -- laisser LazyVim commencer ses installations d'abord
local noms = vim.split(vim.env.REP_MASON or "", " ", { trimempty = true })
for _, n in ipairs(noms) do
  local ok, p = pcall(reg.get_package, n)
  if ok and not p:is_installed() and not p:is_installing() then pcall(function() p:install() end) end
end
vim.wait(600000, function()
  for _, p in ipairs(reg.get_all_packages()) do if p:is_installing() then return false end end
  return true
end, 1000)
for _, n in ipairs(noms) do
  local ok, p = pcall(reg.get_package, n)
  io.stdout:write(n .. " : " .. ((ok and p:is_installed()) and "OK" or "ÉCHEC") .. "\n")
end
LUA
  local outils="shellcheck bash-language-server"
  grep -q 'extras.lang.docker' "$NV/lazyvim.json" && outils="$outils dockerfile-language-server docker-compose-language-service hadolint"
  grep -q 'extras.lang.yaml' "$NV/lazyvim.json" && outils="$outils yaml-language-server"
  command -v npm >/dev/null || expl "npm absent : les serveurs bash, docker et yaml échoueront (réparation 4 : Node)."
  REP_MASON="$outils" timeout 900 "$NVIM" --headless "+luafile $lua" +qa 2>/dev/null | sed 's/^/   /'
  rm -f "$lua"
}

# ---- 5b. Treesitter : erreurs rouges « query.lua … "tab" » ---------------------
TS_LANGS="c cpp bash make lua luadoc vim vimdoc regex query markdown markdown_inline diff printf json yaml dockerfile python toml"
ts_verifier() {   # affiche OK ou la liste des langages dont les règles de coloration plantent
  local NVIM=$1 lua; lua=$(mktemp --suffix=.lua)
  cat >"$lua" <<'LUA'
require("lazy").load({ plugins = { "nvim-treesitter" } })
local mauvais = {}
for _, l in ipairs(vim.split(vim.env.TS_LANGS or "", " ", { trimempty = true })) do
  for _, q in ipairs({ "highlights", "injections" }) do
    local ok, err = pcall(vim.treesitter.query.get, l, q)
    if not ok then table.insert(mauvais, l .. "/" .. q .. " : " .. (tostring(err):gsub("%s+", " "):sub(1, 100))) end
  end
end
io.stdout:write(#mauvais == 0 and "OK\n" or (table.concat(mauvais, "\n") .. "\n"))
LUA
  TS_LANGS="$TS_LANGS" timeout 120 "$NVIM" --headless "+luafile $lua" +qa 2>/dev/null
  rm -f "$lua"
}
rep_treesitter() {
  titre "5b. Treesitter (erreurs rouges, ligne de commande invisible)"
  local NVIM; NVIM=$(command -v nvim) || { saute "nvim introuvable"; return; }
  [ -d "$NV" ] || { saute "pas de config Neovim"; return; }
  local avant; avant=$(ts_verifier "$NVIM")
  if [ "$avant" = OK ]; then saute "règles de coloration : aucune erreur"; return; fi
  expl "Des règles de coloration ne correspondent plus à tes parseurs :" "$(printf '%s\n' "$avant" | head -5 | sed 's/^/     /')" \
       "C'est ce qui affiche les erreurs rouges et casse la ligne de commande (noice)." \
       "Réparation : mettre à jour les plugins, puis recompiler tous les parseurs (1 à 3 minutes)."
  accord "Réparer ?" || { saute "treesitter laissé tel quel"; return; }
  local d="$HOME/.local/share/nvim/site"
  rm -rf "$d/parser" "$d/parser-info" "$d/queries"
  timeout 900 "$NVIM" --headless "+Lazy! sync" +qa >/dev/null 2>&1 || expl "Lazy sync : délai dépassé, on continue"
  local lua; lua=$(mktemp --suffix=.lua)
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
  local apres; apres=$(ts_verifier "$NVIM")
  if [ "$apres" != OK ]; then
    # 2e essai : les règles elles-mêmes sont abîmées (fichier modifié dans le plugin) → le réinstaller propre
    expl "Encore des erreurs : le plugin nvim-treesitter lui-même est abîmé. Réinstallation propre…"
    rm -rf "$HOME/.local/share/nvim/lazy/nvim-treesitter" "$d/parser" "$d/parser-info" "$d/queries"
    timeout 900 "$NVIM" --headless "+Lazy! install" +qa >/dev/null 2>&1
    lua=$(mktemp --suffix=.lua)
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
    apres=$(ts_verifier "$NVIM")
  fi
  if [ "$apres" = OK ]; then ok "parseurs recompilés, plus aucune erreur"
  else ko "treesitter : encore des erreurs ($(printf '%s' "$apres" | head -1))"; fi
}

# ---- 5c. Ligne de commande en bas (au lieu de la fenêtre flottante) -----------
rep_noice() {
  titre "5c. Ligne de commande de Neovim (invisible)"
  [ -d "$NV/lua/plugins" ] || { saute "pas de config LazyVim"; return; }
  if grep -qs 'enabled = false' "$NV/lua/plugins/commande-en-bas.lua"; then saute "ligne de commande classique déjà en place"; return; fi
  expl "Quand tu tapes « : », rien ne s'affiche : c'est noice qui dessine la ligne de commande, et il plante." \
       "Réparation sûre : rendre la ligne de commande et les messages à Neovim, en bas de l'écran," \
       "comme dans Vim. Elle s'affiche alors toujours, même si un plugin a un souci."
  accord "Remettre la ligne de commande classique en bas ?" || { saute "ligne de commande laissée à noice"; return; }
  sauver "$NV/lua/plugins/commande-en-bas.lua"
  cat >"$NV/lua/plugins/commande-en-bas.lua" <<'LUA'
-- Ligne de commande et messages classiques de Neovim, en bas de l'écran (noice ne les gère plus)
-- Pour revenir à noice : supprimer ce fichier.
return {
  { "folke/noice.nvim", opts = { cmdline = { enabled = false }, messages = { enabled = false } } },
}
LUA
  ok "ligne de commande classique en bas (supprimer lua/plugins/commande-en-bas.lua pour revenir)"
}

# ---- 6. Ménage -----------------------------------------------------------------
rep_menage() {
  titre "6. Ménage"
  if [ -d ~/.vim/plugged ] && [ ! -f ~/.vimrc ] && [ ! -f ~/.vim/vimrc ] && grep -q 'alias vim="nvim"' ~/.zshrc 2>/dev/null; then
    expl "~/.vim/plugged : plugins Vim sans aucune config, et « vim » ouvre déjà Neovim chez toi."
    if accord "Supprimer ~/.vim/plugged (et ~/.vim/autoload/plug.vim) ?"; then
      rm -rf ~/.vim/plugged ~/.vim/autoload/plug.vim && ok "anciens plugins Vim retirés" || ko "~/.vim/plugged"
    else saute "~/.vim/plugged gardé"; fi
  else saute "~/.vim/plugged : rien à faire"; fi
  if [ -d "$NV.bak" ] && [ -z "$(ls -A "$NV.bak")" ]; then
    expl "~/.config/nvim.bak : dossier vide, inutile."
    if accord "Le supprimer ?"; then rmdir "$NV.bak" && ok "~/.config/nvim.bak retiré"; else saute "nvim.bak gardé"; fi
  fi
  if command -v flatpak >/dev/null; then
    expl "Runtimes flatpak en double (GL.default ×6, KDE Platform ×3) : place perdue."
    if accord "Lancer « flatpak uninstall --unused » ?"; then
      flatpak uninstall --unused -y && ok "runtimes flatpak inutiles retirés" || ko "flatpak --unused"
    else saute "flatpak laissé"; fi
  fi
  if dpkg -s docker-compose >/dev/null 2>&1; then
    expl "docker-compose (version 1, en Python) est abandonné. Remplaçant : « docker compose » (v2)."
    if accord "Installer docker-compose-v2 et retirer l'ancien (sudo demandé) ?"; then
      sudo apt install -y docker-compose-v2 && sudo apt remove -y docker-compose && ok "docker compose v2" || ko "docker-compose"
    else saute "docker-compose v1 gardé"; fi
  fi
}

# =============================================================================
#  7. AJOUTS DE LA FAC — seulement ce qui manque ici, rien de ce qui marche déjà
#     (Konsole, Klipper, autojump, ton zsh, ton Neovim restent tels quels)
# =============================================================================
LOG="$HOME/.cache/reparer-maison-$DATE.log"
KIT_SH=""
for c in "$(dirname "$(readlink -f "$0")")/kit-etudiant.sh" "$HOME/kit-etudiant/kit-etudiant.sh"; do
  [ -f "$c" ] && { KIT_SH=$c; break; }
done
manque() { ! command -v "$1" >/dev/null 2>&1; }
kit_la() { [ -n "$KIT_SH" ] && return 0; ko "kit-etudiant.sh introuvable : mets-le dans le même dossier que ce script"; return 1; }
# kit_fn FONCTION args : lance UNE fonction de kit-etudiant.sh (mêmes téléchargements qu'à la fac,
# dans ~/.local/bin), dans un sous-shell : rien d'autre du kit ne s'exécute ni ne reste chargé.
# shellcheck disable=SC2034  # KIT_SOURCE_ONLY et LOGF sont lus par kit-etudiant.sh
kit_fn() {
  mkdir -p "$(dirname "$LOG")"
  ( KIT_SOURCE_ONLY=1
    # shellcheck source=/dev/null
    . "$KIT_SH" || exit 1
    LOGF=$LOG; mkdir -p "$BIN" "$WORK/dl" "$WORK/x" "$KIT"; export PATH="$BIN:$PATH"
    "$@" ) >>"$LOG" 2>&1
}
installer_un() {   # installer_un OUTIL : même source et même version que sur le PC fac
  case $1 in
    shellcheck) kit_fn installer_gh koalaman/shellcheck 'linux\.x86_64\.tar\.xz$' shellcheck ;;
    shfmt)      kit_fn installer_gh mvdan/sh '^shfmt_v.*_linux_amd64$' 'shfmt_v*_linux_amd64:shfmt' ;;
    bats)       kit_fn installer_bats ;;
    tldr)       kit_fn installer_gh tealdeer-rs/tealdeer '^tealdeer-linux-x86_64-musl$' tealdeer-linux-x86_64-musl:tldr \
                  && kit_fn tldr_pages ;;
    eza)        kit_fn installer_gh eza-community/eza '^eza_x86_64-unknown-linux-musl\.tar\.gz$' eza ;;
    delta)      kit_fn installer_gh dandavison/delta 'x86_64-unknown-linux-musl\.tar\.gz$' delta ;;
    watchexec)  kit_fn installer_gh watchexec/watchexec 'x86_64-unknown-linux-musl\.tar\.xz$' watchexec ;;
    trash-put)  timeout 900 pipx install --force trash-cli >>"$LOG" 2>&1 ;;
    clang-tidy|clang-format) timeout 900 pipx install --force "$1" >>"$LOG" 2>&1 ;;
    *) return 1 ;;
  esac
}
installer_liste() {
  local o n; mkdir -p "$(dirname "$LOG")"
  for o in "$@"; do
    n=${o/trash-put/trash-cli}; printf '   … %s\n' "$n"
    if installer_un "$o"; then ok "$n installé"; else ko "$n (détails : $LOG)"; fi
  done
}

ajout_scripts() {
  titre "7a. Scripts bash : shellcheck, shfmt, bats"
  local a=(); manque shellcheck && a+=(shellcheck); manque shfmt && a+=(shfmt); manque bats && a+=(bats)
  [ ${#a[@]} -gt 0 ] || { saute "shellcheck, shfmt, bats déjà là"; return; }
  expl "shellcheck tp.sh : liste les erreurs d'un script, directement dans le terminal" \
       "shfmt -d tp.sh / -w tp.sh : montre / corrige la mise en forme d'un script" \
       "bats : tests automatiques pour tes scripts bash" \
       "À installer dans ~/.local/bin : ${a[*]}"
  kit_la || return
  accord "Installer ?" || { saute "${a[*]} non installés"; return; }
  installer_liste "${a[@]}"
}

ajout_terminal() {
  titre "7b. Terminal : tldr, eza, delta, watchexec, trash-cli"
  local a=()
  manque tldr && a+=(tldr); manque eza && a+=(eza); manque delta && a+=(delta)
  manque watchexec && a+=(watchexec); manque trash-put && a+=(trash-put)
  [ ${#a[@]} -gt 0 ] || { saute "tldr, eza, delta, watchexec, trash-cli déjà là"; return; }
  expl "tldr tar : exemples courts d'une commande, en français (plus rapide que man)" \
       "eza : pour l'alias « lt » (dossier en arbre, comme à la fac)" \
       "delta : git diff / git log -p lisibles (couleurs, numéros de ligne)" \
       "watchexec -e c,h -- make run : recompile et relance à chaque sauvegarde" \
       "trash-cli : pour l'alias « tp » (corbeille au lieu de rm ; trash-list, trash-restore)" \
       "À installer dans ~/.local/bin : ${a[*]/trash-put/trash-cli (pipx)}"
  kit_la || return
  accord "Installer ?" || { saute "${a[*]/trash-put/trash-cli} non installés"; return; }
  installer_liste "${a[@]}"
}

ajout_c() {
  titre "7c. C : tests Check, clang-tidy, clang-format, gdb-dashboard"
  if ! pkg-config --exists check 2>/dev/null; then
    local p=(check); manque pkg-config && p+=(pkg-config)
    expl "Check : bibliothèque de tests unitaires, pour « make test » dans un projet kit-projet." \
         "À installer avec apt : ${p[*]}"
    if accord "Installer avec apt (sudo demandé) ?"; then
      sudo apt install -y "${p[@]}" && ok "installé : ${p[*]}" || ko "apt ${p[*]}"
    else saute "Check non installé"; fi
  else saute "Check déjà là"; fi
  local a=(); manque clang-tidy && a+=(clang-tidy); manque clang-format && a+=(clang-format)
  if [ ${#a[@]} -gt 0 ]; then
    expl "clang-tidy : « make tidy », repère les bugs probables (fuites, débordements…)" \
         "clang-format : « make format », met tout le projet en forme d'un coup" \
         "À installer avec pipx : ${a[*]}"
    command -v pipx >/dev/null || { ko "pipx absent"; a=(); }
    if [ ${#a[@]} -gt 0 ]; then
      if accord "Installer ?"; then installer_liste "${a[@]}"; else saute "${a[*]} non installés"; fi
    fi
  else saute "clang-tidy, clang-format déjà là"; fi
  if [ -f ~/.gdb-dashboard ] && grep -x 'define dash' ~/.gdbinit >/dev/null 2>&1; then saute "gdb-dashboard déjà là"; return; fi
  expl "gdb-dashboard : dans gdb (ou cdebug), tape « dash » : source, variables, pile en panneaux." \
       "Ajoute aussi à ~/.gdbinit (sauvegardé) : historique gardé, affichage lisible des structures."
  kit_la || return
  accord "Installer ?" || { saute "gdb-dashboard non installé"; return; }
  mkdir -p "$(dirname "$LOG")"
  if curl -fsSL https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/master/.gdbinit -o ~/.gdb-dashboard 2>>"$LOG" \
     && kit_fn ecrire_gdbinit; then ok "gdb-dashboard (commande dash dans gdb)"; else ko "gdb-dashboard (détails : $LOG)"; fi
}

adapter_aide() {   # l'aide-mémoire de la fac, ajusté à ce PC (autojump, Klipper, pas de tmux…)
  local f="$HOME/.config/kit-etudiant/aide.md"
  [ -f "$f" ] || return 0
  sed -i -e 's/^# Aide-mémoire kit-etudiant .*/# Aide-mémoire (PC maison)/' \
         -e '/^| `z tp1` |/d' \
         -e 's/^| `j dossier` | comme autojump (zoxide) |/| `j dossier` | sauter à un dossier déjà visité (autojump) |/' \
         -e 's/historique CopyQ de tout/historique Klipper de tout/' \
         -e '/^## Tes fichiers perso/,$d' "$f"
  command -v tmux >/dev/null || sed -i -e '/^| tmux |/d' -e '/^## tmux$/,/^$/d' "$f"
  command -v gedit >/dev/null || sed -i '/^| `gedit fichier` |/d' "$f"
}
ajout_projet() {
  titre "7d. Projets : kit-projet, kit-aide, doc-c"
  local a=(); manque kit-projet && a+=(kit-projet); manque kit-aide && a+=(kit-aide); manque doc-c && a+=(doc-c)
  [ ${#a[@]} -gt 0 ] || { saute "kit-projet, kit-aide, doc-c déjà là"; return; }
  expl "kit-projet tp3 : crée un projet C prêt (Makefile : make run, test, valgrind, analyse, tidy, format)" \
       "kit-aide : l'aide-mémoire de la fac (raccourcis zsh, Neovim, gdb), adapté à ce PC" \
       "doc-c : la doc C complète hors ligne (cppreference) dans le navigateur" \
       "À ajouter : ${a[*]}   (modèles et aide dans ~/.config/kit-etudiant)"
  kit_la || return
  accord "Ajouter ?" || { saute "${a[*]} non ajoutés"; return; }
  local o
  for o in "${a[@]}"; do
    case $o in
      kit-projet) if kit_fn ecrire_modeles; then ok "kit-projet"; else ko "kit-projet (détails : $LOG)"; fi ;;
      kit-aide)   if kit_fn ecrire_aide && adapter_aide; then ok "kit-aide"; else ko "kit-aide (détails : $LOG)"; fi ;;
      doc-c)      printf '   … doc-c (téléchargement de la doc)\n'
                  if kit_fn installer_cppref; then ok "doc-c"; else ko "doc-c (détails : $LOG)"; fi ;;
    esac
  done
}

ajout_raccourcis() {
  titre "7e. Raccourcis de la fac : lt, lg, tp, mkcd, git lg"
  local debut='# >>> ajouts fac (reparer-maison) >>>' fin='# <<< ajouts fac (reparer-maison) <<<'
  if [ ! -f ~/.zshrc ]; then saute "~/.zshrc introuvable"
  elif grep -xF "$debut" ~/.zshrc >/dev/null; then saute "alias de la fac déjà dans ~/.zshrc"
  else
    local l=()
    grep -q '^[^#]*alias lt=' ~/.zshrc || l+=("(( \$+commands[eza] ))       && alias lt='eza --tree --level=2 --icons=auto'   # dossier en arbre")
    grep -q '^[^#]*alias lg=' ~/.zshrc || l+=("(( \$+commands[lazygit] ))   && alias lg=lazygit")
    grep -q '^[^#]*alias tp=' ~/.zshrc || l+=("(( \$+commands[trash-put] )) && alias tp=trash-put                     # corbeille au lieu de rm")
    grep -q 'mkcd *()' ~/.zshrc        || l+=('mkcd() { mkdir -p -- "$1" && cd -- "$1"; }                             # créer un dossier et y entrer')
    if [ ${#l[@]} -eq 0 ]; then saute "lt, lg, tp, mkcd déjà définis"
    else
      expl "Quelques lignes à la fin de ~/.zshrc (sauvegardé avant), comme à la fac :" \
           "  lt : dossier en arbre (remplace le « lt » de common-aliases, qui triait par date)" \
           "  lg : lazygit      tp fichier : corbeille      mkcd dossier : le créer et y entrer"
      if accord "Ajouter à ~/.zshrc ?"; then
        sauver ~/.zshrc
        { printf '\n%s\n' "$debut"
          printf '%s\n' '[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || path=("$HOME/.local/bin" $path)' "${l[@]}" "$fin"
        } >>~/.zshrc && ok "alias ajoutés à ~/.zshrc" || ko "~/.zshrc"
      else saute "alias non ajoutés"; fi
    fi
  fi
  command -v git >/dev/null || return
  local g=()
  [ -z "$(git config --global --get alias.lg)" ] && g+=("alias.lg=log --oneline --graph --decorate --all")
  [ -z "$(git config --global --get init.defaultBranch)" ] && g+=("init.defaultBranch=main")
  if command -v delta >/dev/null && [ -z "$(git config --global --get core.pager)" ]; then
    g+=("core.pager=delta" "interactive.diffFilter=delta --color-only" "delta.navigate=true" "delta.line-numbers=true")
  fi
  [ ${#g[@]} -gt 0 ] || { saute "git : réglages de la fac déjà là"; return; }
  expl "git, comme à la fac (seulement les réglages que tu n'as pas déjà) :" "${g[@]/#/  }"
  [ -n "$(git config --global --get alias.lg)" ] || expl "git lg : historique en graphe, toutes les branches"
  [[ " ${g[*]} " == *" core.pager=delta "* ]] && expl "delta : diffs colorés avec numéros de ligne (n / N pour sauter d'un fichier à l'autre)"
  accord "Régler git ?" || { saute "git laissé tel quel"; return; }
  local kv r=0
  for kv in "${g[@]}"; do git config --global "${kv%%=*}" "${kv#*=}" || r=1; done
  [ $r -eq 0 ] && ok "git : ${#g[@]} réglage(s) de la fac" || ko "git config"
}

# ---- 8. À vérifier par toi (pas modifié) ---------------------------------------
infos() {
  titre "8. À savoir (rien n'est modifié)"
  grep -q 'QT_QPA_PLATFORM=xcb' ~/.zshrc 2>/dev/null && expl \
    "~/.zshrc force QT_QPA_PLATFORM=xcb : les applis Qt lancées depuis le terminal tournent en X11" \
    "au lieu de Wayland (parfois floues). Si c'était seulement pour LibreOffice, tu peux la retirer."
  command -v neofetch >/dev/null && expl "neofetch n'est plus maintenu : fastfetch le remplace."
  expl "Images docker : « docker system df » pour voir la place, « docker image prune » pour nettoyer."
}

printf '%sreparer-maison%s — sauvegardes : *.avant-reparation-%s\n' "$B" "$N" "$DATE"
choisi cflags && rep_cflags
choisi thefuck && rep_thefuck
choisi git && rep_git
choisi outils && rep_outils
choisi lazyvim && rep_lazyvim
choisi treesitter && rep_treesitter
choisi noice && rep_noice
choisi menage && rep_menage
choisi scripts && ajout_scripts
choisi terminal && ajout_terminal
choisi outils-c && ajout_c
choisi projet && ajout_projet
choisi raccourcis && ajout_raccourcis
[ -z "$SEUL" ] && infos
printf '\n%s==================== BILAN ====================%s\n' "$B" "$N"
printf '%s✔ fait : %d%s   %s✘ raté : %d%s   %s– sauté : %d%s\n' "$V" "${#FAIT[@]}" "$N" "$R" "${#RATE[@]}" "$N" "$J" "${#SAUTE[@]}" "$N"
[ ${#RATE[@]} -gt 0 ] && printf '   ✘ %s\n' "${RATE[@]}"
[ -f "$LOG" ] && echo "Journal des téléchargements : $LOG"
echo "Ouvre un nouveau terminal pour profiter des changements de ~/.zshrc."
