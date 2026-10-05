#!/usr/bin/env bash
# shellcheck disable=SC2088  # les « ~/ » entre guillemets sont des libellés affichés
# =============================================================================
#  kit-etudiant.sh — Boîte à outils C / Bash / Vim / Cyber pour Linux Mint
#  100 % SANS ROOT : tout s'installe dans ton $HOME
#     ~/.local/bin   ~/.local/opt   ~/.local/share   ~/.config   ~/.vim
#  Relançable : ce qui est déjà installé est sauté (--maj pour tout mettre à jour)
# =============================================================================
#  Usage : bash kit-etudiant.sh [options]
#    --maj             réinstaller / mettre à jour même ce qui existe déjà
#    --sans-lourd      sauter pwndbg, ImHex, Ghidra + Java (économise ~2,5 Go)
#    --sans-gui        sauter tout le graphique (police, kitty, espanso, applis, Ghidra)
#    --sans-cyber      sauter pwntools et CyberChef (inutiles sans cours de cyber)
#    --sans-conda      sauter micromamba (valgrind, gdb, cppcheck, bear, ctags, tmux, check, node)
#    --seulement A,B   ne lancer que ces étapes (voir --liste)
#    --liste           lister les étapes
#    --desinstaller    tout retirer (ce que le script a créé + ses blocs de config)
#    --aide            cette aide
#  Jeton GitHub facultatif : rien n'utilise l'API GitHub, donc pas de limite.
# =============================================================================
set -uo pipefail

# ---- Garde-fou : ce script ne doit JAMAIS élever ses droits -----------------
sudo()   { echo "INTERDIT : kit-etudiant n'utilise jamais sudo" >&2; return 97; }
su()     { echo "INTERDIT : kit-etudiant n'utilise jamais su" >&2; return 97; }
pkexec() { echo "INTERDIT : kit-etudiant n'utilise jamais pkexec" >&2; return 97; }

KIT_VERSION="1.1 — 2026-10-05"
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
OPT="$PREFIX/opt"
SHR="$PREFIX/share"
KIT="$HOME/.config/kit-etudiant"
WORK="$HOME/.cache/kit-etudiant"          # pas /tmp : souvent monté noexec
MAMBA_ROOT="$HOME/micromamba"
MANIF="$KIT/manifeste"
LOGF="$WORK/install-$(date +%Y%m%d-%H%M%S).log"
MARQ_DEBUT='>>> kit-etudiant >>>'
MARQ_FIN='<<< kit-etudiant <<<'

RAISON=""; MAJ=0; SANS_CYBER=0; SANS_LOURD=0; SANS_GUI=0; SANS_CONDA=0; SEULEMENT=""; MODE=installer
declare -a OKS=() KOS=() MAIN=()

if [ -t 1 ]; then V=$'\e[32m'; R=$'\e[31m'; J=$'\e[33m'; B=$'\e[1;34m'; G=$'\e[2m'; N=$'\e[0m'
else V=""; R=""; J=""; B=""; G=""; N=""; fi

ETAPES=(prepa cli shell outils_shell outils_c python conda vim tmux config doc bureau applis ghidra)
declare -A DESC=(
  [prepa]="dossiers, vérifications (noexec, glibc, place), PATH"
  [cli]="rg fd bat eza delta lazygit jq yazi gh glow watchexec hyperfine duf sd btop gdu direnv chezmoi croc rclone tldr exercism"
  [shell]="ble.sh, fzf, zoxide, starship, bash-completion"
  [outils_shell]="shellcheck, shfmt, bats-core"
  [outils_c]="clangd, pwndbg portable (~0,7 Go), gdb-dashboard"
  [python]="uv + pwntools, trash-cli, clang-format, clang-tidy"
  [conda]="micromamba + valgrind gdb cppcheck bear ctags tmux check node, bash-language-server"
  [vim]="Vim 9 si besoin, vim-plug, vimrc, snippets, 20 plugins"
  [tmux]="tmux.conf, tpm, tmux-sensible, tmux-resurrect"
  [config]="bashrc, inputrc, gdbinit, git+delta, thème gruvbox, modèles de projet C, kit-projet"
  [doc]="doc C hors ligne (cppreference, commande doc-c), aide-mémoire kit-aide"
  [bureau]="police Nerd (réglée dans le terminal), kitty + thème, espanso, Caps→Échap, action Nemo"
  [applis]="KeePassXC, Flameshot, ImHex, CyberChef, CopyQ (flatpak)"
  [ghidra]="Java 21 + Ghidra (~1,2 Go)"
)

# ---- Affichage ---------------------------------------------------------------
log()   { printf '%s\n' "$*" >>"$LOGF"; }
titre() { printf '\n%s==> %s%s\n' "$B" "$1" "$N"; log "==> $1"; }
ok()    { OKS+=("$1"); printf '  %s✔%s %s\n' "$V" "$N" "$1"; log "OK  $1"; }
ko()    { KOS+=("$1 — $2"); printf '  %s✘ %s%s %s(%s)%s\n' "$R" "$1" "$N" "$G" "$2" "$N"; log "KO  $1 — $2"; }
info()  { printf '  %s•%s %s\n' "$J" "$N" "$1"; log "..  $1"; }
amain() { MAIN+=("$1"); }

# faire "Nom" commande args... : exécute, journalise, note OK/KO
faire() {
  local nom=$1; shift
  RAISON=""
  log "---- $nom : $*"
  if "$@" >>"$LOGF" 2>&1; then ok "$nom"; return 0; fi
  ko "$nom" "${RAISON:-détails : $LOGF}"; return 1
}
# outil "Nom" CHEMIN_TEMOIN commande... : saute si déjà installé (sauf --maj)
outil() {
  local nom=$1 temoin=$2; shift 2
  if [ "$MAJ" -eq 0 ] && [ -e "$temoin" ]; then ok "$nom (déjà là)"; return 0; fi
  faire "$nom" "$@"
}
noter() { mkdir -p "$KIT"; printf '%s\n' "$1" >>"$MANIF"; }

# ---- Téléchargements GitHub SANS l'API (aucune limite de requêtes) ----------
telecharger() {  # telecharger URL FICHIER
  mkdir -p "$(dirname "$2")"
  curl -fL --retry 3 --retry-delay 3 --connect-timeout 20 -sS -o "$2" "$1"
}
gh_tag() {       # dernière version publiée, lue dans la redirection de /releases/latest
  curl -fsSI --retry 3 --connect-timeout 20 "https://github.com/$1/releases/latest" \
    | tr -d '\r' | sed -n 's#^[Ll]ocation: .*/releases/tag/##p' | tail -1
}
gh_asset() {     # gh_asset depot/projet REGEX  ->  URL du fichier de la dernière version
  local depot=$1 re=$2 tag h nom
  tag=$(gh_tag "$depot")
  [ -n "$tag" ] || { echo "version introuvable pour $depot" >&2; return 1; }
  while read -r h; do
    nom=${h##*/}
    if [[ $nom =~ $re ]]; then echo "https://github.com$h"; return 0; fi
  done < <(curl -fsSL --retry 3 "https://github.com/$depot/releases/expanded_assets/$tag" \
             | grep -o 'href="/[^"]*/releases/download/[^"]*"' | sed 's/^href="//;s/"$//')
  echo "aucun fichier /$re/ dans $depot ($tag)" >&2; return 1
}
extraire() {     # extraire ARCHIVE DOSSIER   (code 2 = pas une archive)
  case "$1" in
    *.tar.gz|*.tgz)  tar -xzf "$1" -C "$2" ;;
    *.tar.xz|*.txz)  tar -xJf "$1" -C "$2" ;;
    *.tar.bz2|*.tbz) tar -xjf "$1" -C "$2" ;;
    *.zip) if command -v unzip >/dev/null; then unzip -q -o "$1" -d "$2"
           else python3 -m zipfile -e "$1" "$2"; fi ;;
    *) return 2 ;;
  esac
}
verifier() {     # le binaire démarre-t-il vraiment ? (glibc, noexec…)
  "$1" --version >/dev/null 2>&1 || "$1" version >/dev/null 2>&1 || "$1" -V >/dev/null 2>&1
}
# installer_bin URL "nom_dans_archive[:nom_final]"...   (nom peut être un motif glob)
installer_bin() {
  local url=$1; shift
  local base=${url##*/} f d spec src dst chemin rc
  f="$WORK/dl/$base"; d="$WORK/x/$base"
  echo "téléchargement : $url"
  telecharger "$url" "$f" || return 1
  rm -rf "$d"; mkdir -p "$d"
  extraire "$f" "$d"; rc=$?
  if [ $rc -eq 2 ]; then cp "$f" "$d/$base"; elif [ $rc -ne 0 ]; then return 1; fi
  for spec in "$@"; do
    src=${spec%%:*}; dst=${spec##*:}; [ "$src" = "$spec" ] && dst=${src}
    chemin=$(find "$d" -type f -name "$src" | head -1)
    [ -n "$chemin" ] || { echo "« $src » absent de $base" >&2; return 1; }
    install -m 755 "$chemin" "$BIN/$dst" || return 1
    noter "$BIN/$dst"
  done
  rm -rf "$d" "$f"
}
installer_gh() { # installer_gh depot REGEX spec...
  local depot=$1 re=$2 url premier; shift 2
  url=$(gh_asset "$depot" "$re") || return 1
  installer_bin "$url" "$@" || return 1
  premier=${1##*:}; verifier "$BIN/$premier"
}
# Bibliothèques système manquantes pour les programmes d'une AppImage extraite
libs_manquantes() {
  local d=$1 lp b
  command -v ldd >/dev/null || return 0
  lp=$(find "$d" -name '*.so*' \( -type f -o -type l \) -printf '%h\n' 2>/dev/null | sort -u | paste -sd:)
  for b in "$d"/usr/bin/*; do
    [ -f "$b" ] && [ -x "$b" ] || continue
    head -c4 "$b" | grep -q ELF || continue
    LD_LIBRARY_PATH="$lp" ldd "$b" 2>/dev/null | awk '/not found/{print $1}'
  done | sort -u | paste -sd' '
}
# AppImage -> extraite (pas besoin de FUSE), lanceur dans ~/.local/bin
appimage() {     # appimage URL_ou_FICHIER NOM [COMMANDE]
  local src=$1 nom=$2 cmd=${3:-$2} f
  f="$WORK/dl/$nom.AppImage"
  if [ -f "$src" ]; then cp "$src" "$f"; else telecharger "$src" "$f" || return 1; fi
  chmod +x "$f"
  rm -rf "${WORK:?}/squashfs-root" "${OPT:?}/${nom:?}"
  (cd "$WORK" && "$f" --appimage-extract >/dev/null) || return 1
  mv "$WORK/squashfs-root" "$OPT/$nom"
  rm -f "$f"
  local m; m=$(libs_manquantes "$OPT/$nom")
  if [ -n "$m" ]; then   # inutile de garder une appli qui ne démarrera pas
    rm -rf "${OPT:?}/${nom:?}"
    RAISON="le système n'a pas : $m (demande au service info)"; echo "$RAISON"; return 1
  fi
  # lanceur (pas un lien : certains AppRun cherchent leurs fichiers à côté d'eux)
  printf '#!/bin/sh\nexec "%s/AppRun" "$@"\n' "$OPT/$nom" >"$BIN/$cmd"; chmod +x "$BIN/$cmd"
  noter "$OPT/$nom"; noter "$BIN/$cmd"
}
raccourci() {    # raccourci ID "Nom" "Commande" "Icône" "Catégories"
  local fic="$SHR/applications/kit-$1.desktop"
  mkdir -p "$SHR/applications"
  cat >"$fic" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=$4
Categories=$5
Terminal=false
EOF
  noter "$fic"
}
icone_appimage() { readlink -f "$OPT/$1/.DirIcon" 2>/dev/null || echo "$1"; }

# Bloc délimité dans un fichier de config (remplacé à chaque passage)
bloc_fichier() { # bloc_fichier FICHIER CONTENU [COMMENTAIRE]
  local f=$1 contenu=$2 c=${3:-#} tmp
  if [ -f "$f" ] && [ ! -f "$f.avant-kit" ]; then cp "$f" "$f.avant-kit"; fi
  [ -e "$f" ] || printf 'cree:%s\n' "$f" >>"$MANIF"
  tmp=$(mktemp "$WORK/bloc.XXXXXX")
  [ -f "$f" ] && awk -v d="$c $MARQ_DEBUT" -v e="$c $MARQ_FIN" \
    '$0==d{s=1;next} $0==e{s=0;next} !s' "$f" >"$tmp"
  printf '%s %s\n%s\n%s %s\n' "$c" "$MARQ_DEBUT" "$contenu" "$c" "$MARQ_FIN" >>"$tmp"
  cat "$tmp" >"$f"; rm -f "$tmp"
}
retirer_bloc() { # retirer_bloc FICHIER [COMMENTAIRE]
  local f=$1 c=${2:-#} tmp
  [ -f "$f" ] || return 0
  tmp=$(mktemp "$WORK/bloc.XXXXXX")
  awk -v d="$c $MARQ_DEBUT" -v e="$c $MARQ_FIN" '$0==d{s=1;next} $0==e{s=0;next} !s' "$f" >"$tmp"
  cat "$tmp" >"$f"; rm -f "$tmp"
}
# Commande présente sur le système (hors ~/.local/bin) ?
systeme_a() {
  local p="" d
  local IFS=:
  for d in $PATH; do [ "$d" = "$BIN" ] || p="$p:$d"; done
  PATH="${p#:}" command -v "$1" >/dev/null 2>&1
}

# =============================================================================
#  ÉTAPES
# =============================================================================
etape_prepa() {
  titre "Préparation"
  mkdir -p "$BIN" "$OPT" "$SHR/applications" "$KIT" "$WORK/dl" "$WORK/x"
  bloc_fichier "$HOME/.profile" \
'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
  ok "dossiers créés, ~/.local/bin ajouté au PATH (~/.profile)"
}

etape_cli() {
  titre "Outils en ligne de commande"
  #     Nom        Dépôt GitHub              Fichier (regex)                          Binaire[:nom]
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
    "exercism  exercism/cli               linux-x86_64\.tar\.gz$                    exercism"
  )
  local ligne nom depot re specs final
  for ligne in "${L[@]}"; do
    read -r nom depot re specs <<<"$ligne"
    final=${specs%% *}; final=${final##*:}
    # shellcheck disable=SC2086
    outil "$nom" "$BIN/$final" installer_gh "$depot" "$re" $specs
  done
  [ -x "$BIN/tldr" ] && faire "pages tldr en français + anglais" tldr_pages
}

tldr_pages() {   # tldr --update ; secours si le réseau intercepte le TLS (proxy de fac)
  "$BIN/tldr" --update && return 0
  echo "secours : téléchargement direct des pages"
  local l p="$HOME/.cache/tealdeer/tldr-pages" f
  for l in en fr; do
    f="$WORK/dl/tldr-$l.zip"
    telecharger "https://github.com/tldr-pages/tldr/releases/latest/download/tldr-pages.$l.zip" "$f" || return 1
    rm -rf "$p/pages.$l"; mkdir -p "$p/pages.$l"; extraire "$f" "$p/pages.$l" || return 1; rm -f "$f"
  done
  "$BIN/tldr" tar >/dev/null
}
installer_blesh() {
  local f="$WORK/dl/ble-nightly.tar.xz" d="$WORK/x/ble" s
  telecharger "https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz" "$f" || return 1
  rm -rf "$d"; mkdir -p "$d"; tar -xJf "$f" -C "$d" || return 1
  s=$(find "$d" -maxdepth 2 -name ble.sh | head -1); [ -n "$s" ] || return 1
  bash "$s" --install "$SHR" || return 1
  noter "$SHR/blesh"; rm -rf "$d" "$f"
}
installer_fzf() {
  local nouveau=0
  if [ -d "$HOME/.fzf/.git" ]; then git -C "$HOME/.fzf" pull -q --ff-only || return 1
  else git clone -q --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" || return 1; nouveau=1; fi
  "$HOME/.fzf/install" --bin || return 1
  ln -sfn "$HOME/.fzf/bin/fzf" "$BIN/fzf"
  [ $nouveau -eq 1 ] && noter "$HOME/.fzf"
  noter "$BIN/fzf"; "$BIN/fzf" --version
}
etape_shell() {
  titre "Shell : ble.sh, fzf, zoxide, starship, complétion"
  outil "ble.sh (suggestions, couleurs)" "$SHR/blesh/ble.sh" installer_blesh
  outil "fzf (recherche floue)" "$BIN/fzf" installer_fzf
  outil "zoxide (z dossier)" "$BIN/zoxide" installer_gh ajeetdsouza/zoxide 'x86_64-unknown-linux-musl\.tar\.gz$' zoxide
  outil "starship (prompt)" "$BIN/starship" installer_gh starship/starship '^starship-x86_64-unknown-linux-musl\.tar\.gz$' starship
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    ok "bash-completion (déjà fourni par le système)"
  else
    outil "bash-completion (copie perso)" "$SHR/bash-completion-git/bash_completion" \
      bash -c "git clone -q --depth 1 https://github.com/scop/bash-completion.git '$SHR/bash-completion-git' && echo '$SHR/bash-completion-git' >>'$MANIF'"
  fi
}

installer_bats() {
  local d="$WORK/x/bats"
  rm -rf "$d"; git clone -q --depth 1 https://github.com/bats-core/bats-core.git "$d" || return 1
  "$d/install.sh" "$PREFIX" || return 1
  noter "$BIN/bats"; noter "$PREFIX/libexec/bats-core"; noter "$PREFIX/lib/bats-core"
  noter "$SHR/man/man1/bats.1"; noter "$SHR/man/man7/bats.7"
  rm -rf "$d"; "$BIN/bats" --version
}
etape_outils_shell() {
  titre "Scripts shell : shellcheck, shfmt, bats"
  outil shellcheck "$BIN/shellcheck" installer_gh koalaman/shellcheck 'linux\.x86_64\.tar\.xz$' shellcheck
  outil shfmt "$BIN/shfmt" installer_gh mvdan/sh '^shfmt_v.*_linux_amd64$' 'shfmt_v*_linux_amd64:shfmt'
  outil "bats-core (tests bash)" "$BIN/bats" installer_bats
}

installer_clangd() {
  local url f="$WORK/dl/clangd.zip" b
  url=$(gh_asset clangd/clangd '^clangd-linux-.*\.zip$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$OPT/clangd"; mkdir -p "$OPT/clangd"; extraire "$f" "$OPT/clangd" || return 1
  b=$(find "$OPT/clangd" -type f -path '*/bin/clangd' | head -1); [ -n "$b" ] || return 1
  chmod +x "$b"; ln -sfn "$b" "$BIN/clangd"
  noter "$OPT/clangd"; noter "$BIN/clangd"; rm -f "$f"
  "$BIN/clangd" --version
}
installer_pwndbg() {
  local url f="$WORK/dl/pwndbg.tar.xz" d="$WORK/x/pwndbg"
  url=$(gh_asset pwndbg/pwndbg '^pwndbg_.*_x86_64-portable\.tar\.xz$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$d" "$OPT/pwndbg"; mkdir -p "$d"; tar -xJf "$f" -C "$d" || return 1
  mv "$d/pwndbg" "$OPT/pwndbg" || return 1
  ln -sfn "$OPT/pwndbg/bin/pwndbg" "$BIN/pwndbg"
  noter "$OPT/pwndbg"; noter "$BIN/pwndbg"; rm -rf "$d" "$f"
  "$BIN/pwndbg" --version
}
etape_outils_c() {
  titre "C : clangd, pwndbg, gdb-dashboard"
  outil "clangd (complétion C)" "$BIN/clangd" installer_clangd
  if [ "$SANS_LOURD" -eq 0 ]; then
    outil "pwndbg portable (gdb lisible, ~0,7 Go)" "$BIN/pwndbg" installer_pwndbg
  else info "pwndbg sauté (--sans-lourd) : gdb-dashboard reste disponible"; fi
  outil "gdb-dashboard" "$HOME/.gdb-dashboard" bash -c \
    "curl -fsSL https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/master/.gdbinit -o '$HOME/.gdb-dashboard' && echo '$HOME/.gdb-dashboard' >>'$MANIF'"
}

uv_outil() {     # uv_outil PAQUET [exécutables à exposer...]  (défaut : tous ceux du paquet)
  local p=$1 e cible td n=0; shift
  td=$("$BIN/uv" tool dir) || return 1
  UV_TOOL_BIN_DIR="$OPT/uv-bin" "$BIN/uv" tool install --upgrade "$p" || return 1
  noter "$OPT/uv-bin"; noter "$td/$p"
  if [ $# -eq 0 ]; then
    for e in "$OPT/uv-bin"/*; do
      cible=$(readlink -f "$e")
      case "$cible" in "$td/$p/"*) ln -sfn "$e" "$BIN/${e##*/}"; noter "$BIN/${e##*/}"; n=$((n + 1)) ;; esac
    done
  else            # pwntools installe des dizaines de commandes : n'exposer que celles-ci
    for e in "$@"; do ln -sfn "$td/$p/bin/$e" "$BIN/$e" || return 1; noter "$BIN/$e"; n=$((n + 1)); done
  fi
  echo "$n commande(s) exposée(s) pour $p"; [ "$n" -gt 0 ]
}
etape_python() {
  titre "Python : uv + outils"
  outil "uv (gestionnaire Python)" "$BIN/uv" installer_gh astral-sh/uv '^uv-x86_64-unknown-linux-musl\.tar\.gz$' uv uvx
  noter "$HOME/.cache/uv"
  [ -x "$BIN/uv" ] || { ko "outils Python" "uv absent"; return; }
  local td; td=$("$BIN/uv" tool dir 2>/dev/null)
  if [ "$SANS_CYBER" -eq 0 ]; then
    outil "pwntools (pwn, ROPgadget)" "$td/pwntools" uv_outil pwntools pwn ROPgadget
  else info "pwntools sauté (--sans-cyber)"; fi
  outil "trash-cli (corbeille)" "$td/trash-cli" uv_outil trash-cli
  outil clang-format "$td/clang-format" uv_outil clang-format
  outil clang-tidy "$td/clang-tidy" uv_outil clang-tidy
  noter "$HOME/.local/share/uv"
}

conda_env() {
  local pk=(valgrind gdb cppcheck bear universal-ctags tmux check pkg-config nodejs)
  if [ -d "$MAMBA_ROOT/envs/outils" ]; then
    "$BIN/micromamba" -r "$MAMBA_ROOT" install -y -n outils -c conda-forge --override-channels "${pk[@]}" || return 1
    [ "$MAJ" -eq 1 ] && { "$BIN/micromamba" -r "$MAMBA_ROOT" update -y -n outils --all || return 1; }
  else
    "$BIN/micromamba" -r "$MAMBA_ROOT" create -y -n outils -c conda-forge --override-channels "${pk[@]}" || return 1
  fi
  "$BIN/micromamba" -r "$MAMBA_ROOT" clean -a -y   # vider le cache des paquets : économise de la place
  noter "$MAMBA_ROOT"
}
conda_liens() {  # le système garde la priorité : on ne lie que ce qui manque
  local e="$MAMBA_ROOT/envs/outils/bin" b
  for b in valgrind vgdb gdb gdbserver cppcheck bear ctags tmux node npm npx checkmk; do
    [ -e "$e/$b" ] || continue
    if systeme_a "$b"; then echo "$b : version système conservée"; continue; fi
    ln -sfn "$e/$b" "$BIN/$b"; noter "$BIN/$b"
  done
}
etape_conda() {
  titre "micromamba : valgrind, gdb, cppcheck, bear, ctags, tmux, check, node"
  outil micromamba "$BIN/micromamba" installer_gh mamba-org/micromamba-releases '^micromamba-linux-64$' micromamba-linux-64:micromamba
  [ -x "$BIN/micromamba" ] || { ko "environnement outils" "micromamba absent"; return; }
  noter "$MAMBA_ROOT"; noter "$HOME/.mamba"
  faire "environnement « outils » (conda-forge)" conda_env || return
  faire "liens vers ~/.local/bin (si absent du système)" conda_liens
  if command -v npm >/dev/null; then
    outil "bash-language-server" "$BIN/bash-language-server" bash -c \
      "npm install -g --prefix '$PREFIX' bash-language-server && echo '$BIN/bash-language-server' >>'$MANIF' && echo '$PREFIX/lib/node_modules/bash-language-server' >>'$MANIF'"
  else ko "bash-language-server" "npm absent"; fi
}

vim_moderne() {  # vim >= 9, pas « tiny » ni « small »
  command -v vim >/dev/null || return 1
  local v; v=$(vim --version 2>/dev/null) || return 1
  grep -qiE '(tiny|small) version' <<<"$v" && return 1
  [ "$(head -1 <<<"$v" | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)" -ge 9 ] 2>/dev/null
}
installer_vim() {
  local url
  url=$(gh_asset vim/vim-appimage '^Vim-v.*x86_64\.AppImage$') || return 1
  appimage "$url" vim vim || return 1
  "$BIN/vim" --version | head -1
}
ecrire_vimrc() {
  if [ -f "$HOME/.vimrc" ] && ! head -1 "$HOME/.vimrc" | grep -q 'kit-etudiant'; then
    [ -f "$HOME/.vimrc.avant-kit" ] || cp "$HOME/.vimrc" "$HOME/.vimrc.avant-kit"
    echo "ancien ~/.vimrc sauvegardé : ~/.vimrc.avant-kit"
  fi
  mkdir -p "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup" "$HOME/.vim/vsnip"
  cat >"$HOME/.vimrc" <<'VIMRC'
" kit-etudiant — fichier géré par kit-etudiant.sh (retire cette 1re ligne pour qu'il n'y touche plus)
" Tes réglages perso vont dans ~/.vim/perso.vim : jamais écrasé.
set nocompatible
let mapleader = " "
" --- à régler AVANT le chargement des plugins ---
let g:ale_completion_enabled = 1
let g:polyglot_disabled = ['sensible']
let g:sneak#label = 1
let g:vsnip_snippet_dir = expand('~/.vim/vsnip')

call plug#begin('~/.vim/plugged')
Plug 'tpope/vim-sensible'            " bons réglages de base
Plug 'dense-analysis/ale'            " erreurs en direct, complétion, formatage
Plug 'sheerun/vim-polyglot'          " coloration de tous les langages
Plug 'itchyny/lightline.vim'         " barre d'état
Plug 'preservim/nerdtree'            " arbre de fichiers        <C-n>
Plug '~/.fzf'                        " fzf installé par le kit
Plug 'junegunn/fzf.vim'              " :Files :Rg :Buffers      <C-p>
Plug 'tpope/vim-commentary'          " gcc : commenter
Plug 'tpope/vim-surround'            " cs\"' ds( ysiw]
Plug 'tpope/vim-repeat'              " « . » marche avec les plugins
Plug 'tpope/vim-unimpaired'          " ]q [q ]b [b ...
Plug 'wellle/targets.vim'            " ci, da( cin) ...
Plug 'jiangmiao/auto-pairs'          " ferme ( [ { \" '
Plug 'airblade/vim-gitgutter'        " lignes modifiées (git)
Plug 'tpope/vim-fugitive'            " :Git
Plug 'mbbill/undotree'               " arbre des annulations   <leader>u
Plug 'preservim/tagbar'              " plan du fichier (ctags) <leader>t
Plug 'hrsh7th/vim-vsnip'             " snippets                <C-j>
Plug 'rafamadriz/friendly-snippets'  " snippets tout prêts
Plug 'justinmk/vim-sneak'            " s + 2 lettres : saut rapide
Plug 'liuchengxu/vim-which-key'      " <espace> puis attendre : aide-mémoire
call plug#end()

" --- Base ---
set number relativenumber signcolumn=yes scrolloff=5 mouse=a
set hidden updatetime=300 noshowmode laststatus=2 timeoutlen=500
set ignorecase smartcase expandtab shiftwidth=4 softtabstop=4
set background=dark
silent! colorscheme habamax
silent! colorscheme retrobox     " thème gruvbox intégré à Vim 9.1+
let g:lightline = {'colorscheme': 'deus'}
if has('clipboard') | set clipboard=unnamedplus | endif
" annuler même après avoir fermé le fichier ; .swp hors des dépôts
set undofile undodir=~/.vim/undo// directory=~/.vim/swap// backupdir=~/.vim/backup//

" --- ALE : C (gcc + clangd) et shell (shellcheck + bash-language-server) ---
let g:ale_linters = {'c': ['cc', 'clangd'], 'sh': ['shellcheck', 'language_server']}
let g:ale_c_cc_options = '-std=c11 -Wall -Wextra'
let g:ale_fixers = {'c': ['clang-format'], 'sh': ['shfmt'], '*': ['remove_trailing_lines', 'trim_whitespace']}
let g:ale_sh_shfmt_options = '-i 4 -ci'
set omnifunc=ale#completion#OmniFunc
nnoremap <silent> gd :ALEGoToDefinition<CR>
nnoremap <silent> gr :ALEFindReferences<CR>
nnoremap <silent> <leader>h :ALEHover<CR>
nnoremap <silent> <leader>rn :ALERename<CR>
nnoremap <silent> <leader>f :ALEFix<CR>
nmap <silent> [g <Plug>(ale_previous_wrap)
nmap <silent> ]g <Plug>(ale_next_wrap)

" --- Navigation ---
nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-p> :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>g :Rg<CR>
nnoremap <leader>u :UndotreeToggle<CR>
nnoremap <leader>t :TagbarToggle<CR>
nnoremap <leader>T :botright terminal ++rows=12<CR>
nnoremap <silent> <leader> :WhichKey '<Space>'<CR>

" --- Snippets (vsnip) : <C-j> déplier, <C-l>/<C-h> champ suivant/précédent ---
imap <expr> <C-j> vsnip#expandable() ? '<Plug>(vsnip-expand)' : '<C-j>'
smap <expr> <C-j> vsnip#expandable() ? '<Plug>(vsnip-expand)' : '<C-j>'
imap <expr> <C-l> vsnip#jumpable(1)  ? '<Plug>(vsnip-jump-next)' : '<C-l>'
smap <expr> <C-l> vsnip#jumpable(1)  ? '<Plug>(vsnip-jump-next)' : '<C-l>'
imap <expr> <C-h> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<C-h>'
smap <expr> <C-h> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<C-h>'

" --- Compiler / lancer ---
" F5 : compile le fichier courant (ASan) et le lance   F6 : make   + quickfix
augroup kit_etudiant
  autocmd!
  autocmd FileType c  nnoremap <buffer> <F5> :w<CR>:!gcc -std=c11 -Wall -Wextra -g -fsanitize=address,undefined % -o %< && ./%<<CR>
  autocmd FileType sh nnoremap <buffer> <F5> :w<CR>:!bash %<CR>
  autocmd QuickFixCmdPost [^l]* cwindow
augroup END
nnoremap <F6> :w<CR>:make<CR>
if executable('rg') | set grepprg=rg\ --vimgrep grepformat=%f:%l:%c:%m | endif
" Débogueur gdb dans Vim : :Termdebug ./prog
packadd! termdebug
let g:termdebug_wide = 1
" 3K sur printf -> man 3 printf

if filereadable(expand('~/.vim/perso.vim')) | source ~/.vim/perso.vim | endif
VIMRC
  noter "$HOME/.vim/plugged"; noter "$HOME/.vim/autoload/plug.vim"
}
ecrire_snippets() {
  local s="$HOME/.vim/vsnip"
  mkdir -p "$s"
  [ -f "$s/c.json" ] || cat >"$s/c.json" <<'JSON'
{
  "main avec arguments": {
    "prefix": "mainargs",
    "body": ["#include <stdio.h>", "#include <stdlib.h>", "", "int main(int argc, char *argv[])", "{", "\t$0", "\treturn EXIT_SUCCESS;", "}"]
  },
  "malloc vérifié": {
    "prefix": "mallocv",
    "body": ["${1:int} *${2:p} = malloc(${3:n} * sizeof *${2:p});", "if (${2:p} == NULL) {", "\tperror(\"malloc\");", "\texit(EXIT_FAILURE);", "}", "$0"]
  },
  "fopen vérifié": {
    "prefix": "fopenv",
    "body": ["FILE *${1:f} = fopen(${2:\"fichier.txt\"}, \"${3:r}\");", "if (${1:f} == NULL) {", "\tperror(\"fopen\");", "\texit(EXIT_FAILURE);", "}", "$0", "fclose(${1:f});"]
  },
  "fork + waitpid": {
    "prefix": "forkw",
    "body": ["pid_t pid = fork();", "if (pid == -1) {", "\tperror(\"fork\");", "\texit(EXIT_FAILURE);", "}", "if (pid == 0) {", "\t/* fils */", "\t$1", "\t_exit(EXIT_SUCCESS);", "}", "/* père */", "int status;", "if (waitpid(pid, &status, 0) == -1)", "\tperror(\"waitpid\");", "$0"]
  },
  "pipe + fork": {
    "prefix": "pipef",
    "body": ["int fd[2];", "if (pipe(fd) == -1) {", "\tperror(\"pipe\");", "\texit(EXIT_FAILURE);", "}", "pid_t pid = fork();", "if (pid == 0) {", "\tclose(fd[0]);", "\t$1", "\tclose(fd[1]);", "\t_exit(EXIT_SUCCESS);", "}", "close(fd[1]);", "$0", "close(fd[0]);", "waitpid(pid, NULL, 0);"]
  }
}
JSON
  [ -f "$s/sh.json" ] || cat >"$s/sh.json" <<'JSON'
{
  "script bash propre": {
    "prefix": "bashs",
    "body": ["#!/usr/bin/env bash", "set -uo pipefail", "", "die() { echo \"\\$*\" >&2; exit 1; }", "", "main() {", "\t$0", "}", "", "main \"\\$@\""]
  },
  "lecture ligne à ligne": {
    "prefix": "whileread",
    "body": ["while IFS= read -r ${1:ligne}; do", "\t$0", "done < \"${2:fichier}\""]
  },
  "options getopts": {
    "prefix": "getopts",
    "body": ["while getopts \":${1:hv}\" opt; do", "\tcase \\$opt in", "\t\th) ${2:usage}; exit 0 ;;", "\t\t*) die \"option inconnue\" ;;", "\tesac", "done", "shift \\$((OPTIND - 1))"]
  }
}
JSON
}
plug_install() {
  vim -E -s -u "$HOME/.vimrc" -i NONE +'PlugInstall --sync' +qa >/dev/null 2>&1
  local n; n=$(find "$HOME/.vim/plugged" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  echo "plugins présents : $n / 20"
  [ "$n" -ge 20 ]
}
etape_vim() {
  titre "Vim : Vim 9, vim-plug, vimrc, snippets, plugins"
  if [ -d "$OPT/vim" ]; then
    outil "Vim 9 (AppImage)" "$OPT/vim" installer_vim
  elif vim_moderne; then
    ok "Vim du système suffisant : $(vim --version | head -1 | cut -c1-40)"
  else
    info "Vim absent, « tiny » ou < 9 : installation de l'AppImage officielle"
    outil "Vim 9 (AppImage)" "$OPT/vim" installer_vim
  fi
  outil vim-plug "$HOME/.vim/autoload/plug.vim" telecharger \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim "$HOME/.vim/autoload/plug.vim"
  if [ -f "$HOME/.vimrc" ] && ! head -1 "$HOME/.vimrc" | grep -q 'kit-etudiant' && [ -f "$HOME/.vimrc.avant-kit" ]; then
    info "~/.vimrc personnel détecté (sans marque kit) : laissé tel quel"
  else
    faire "~/.vimrc" ecrire_vimrc
  fi
  faire "snippets C et bash (~/.vim/vsnip)" ecrire_snippets
  faire "plugins Vim (PlugInstall)" plug_install
}

etape_tmux() {
  titre "tmux : configuration + plugins"
  local p="$HOME/.tmux/plugins" r
  mkdir -p "$p"
  for r in tpm tmux-sensible tmux-resurrect; do
    if [ -d "$p/$r/.git" ]; then
      [ "$MAJ" -eq 1 ] && git -C "$p/$r" pull -q --ff-only
      ok "$r (déjà là)"
    else
      faire "$r" git clone -q --depth 1 "https://github.com/tmux-plugins/$r" "$p/$r" && noter "$p/$r"
    fi
  done
  if [ -f "$HOME/.tmux.conf" ] && ! head -1 "$HOME/.tmux.conf" | grep -q kit-etudiant; then
    if [ -f "$HOME/.tmux.conf.avant-kit" ]; then
      info "~/.tmux.conf personnel (sans marque kit) : laissé tel quel"; return 0
    fi
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.avant-kit"
  fi
  cat >"$HOME/.tmux.conf" <<'TMUX'
# kit-etudiant — réglages perso : ~/.tmux.perso.conf (jamais écrasé)
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
bind r source-file ~/.tmux.conf \; display "config rechargée"
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
if-shell 'test -f ~/.tmux.perso.conf' 'source-file ~/.tmux.perso.conf'
run -b '~/.tmux/plugins/tpm/tpm'
TMUX
  ok "~/.tmux.conf (Ctrl-b | et Ctrl-b - pour découper)"
}

ecrire_bashrc_kit() {
  cat >"$KIT/bashrc.sh" <<'BASHRC'
# kit-etudiant — chargé depuis ~/.bashrc. Réécrit à chaque installation.
# Tes ajouts perso : ~/.config/kit-etudiant/perso.sh (jamais écrasé).
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
case $- in *i*) ;; *) return 0 ;; esac

# 1. ble.sh d'abord (attaché tout à la fin)
[ -f "$HOME/.local/share/blesh/ble.sh" ] && source "$HOME/.local/share/blesh/ble.sh" --noattach

# 2. Historique, confort
shopt -s histappend autocd cdspell dirspell globstar checkwinsize
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '
export BAT_THEME="gruvbox-dark"
if command -v vim >/dev/null; then
  export EDITOR=vim VISUAL=vim
  export MANPAGER="vim +MANPAGER --not-a-term -"
fi

# 3. bash-completion (avant fzf)
if [ -z "${BASH_COMPLETION_VERSINFO-}" ]; then
  for _f in /usr/share/bash-completion/bash_completion "$HOME/.local/share/bash-completion-git/bash_completion"; do
    [ -f "$_f" ] && . "$_f" && break
  done
  unset _f
fi

# 4. fzf (version ble.sh si présent)
command -v fd >/dev/null && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
if [[ ${BLE_VERSION-} ]]; then
  _ble_contrib_fzf_base="$HOME/.fzf"
  ble-import -d integration/fzf-completion
  ble-import -d integration/fzf-key-bindings
elif [ -f "$HOME/.fzf/shell/key-bindings.bash" ]; then
  . "$HOME/.fzf/shell/completion.bash"
  . "$HOME/.fzf/shell/key-bindings.bash"
fi

# 5. Outils
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"
command -v direnv   >/dev/null && eval "$(direnv hook bash)"
command -v starship >/dev/null && eval "$(starship init bash)"

# 6. Alias et fonctions
command -v bat >/dev/null && alias cat='bat --paging=never'   # tableau + numéros ; « cat » normal dans un pipe
command -v eza >/dev/null && alias ll='eza -la --git --group-directories-first' && alias lt='eza --tree --level=2'
command -v trash-put >/dev/null && alias tp='trash-put'
command -v lazygit >/dev/null && alias lg='lazygit'
alias gccd='gcc -std=c11 -Wall -Wextra -g -fsanitize=address,undefined'   # compiler pour déboguer
alias gcca='gcc -std=c11 -Wall -Wextra -fanalyzer -c -o /dev/null'        # analyse statique gcc
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }
unalias alert 2>/dev/null
alert() {  # « make ; alert » -> notification à la fin
  local rc=$?
  command -v notify-send >/dev/null || return $rc
  notify-send --urgency=low "$([ $rc -eq 0 ] && echo '✔ Terminé' || echo '✘ Erreur')" \
    "$(fc -ln -1 | sed 's/^[[:space:]]*//;s/[;&|][[:space:]]*alert$//')"
  return $rc
}

# 7. Perso
[ -f "$HOME/.config/kit-etudiant/perso.sh" ] && . "$HOME/.config/kit-etudiant/perso.sh"

# 8. ble.sh attaché en dernier
[[ ! ${BLE_VERSION-} ]] || ble-attach
BASHRC
  bloc_fichier "$HOME/.bashrc" '[ -f "$HOME/.config/kit-etudiant/bashrc.sh" ] && . "$HOME/.config/kit-etudiant/bashrc.sh"'
}
ecrire_inputrc() {
  if [ ! -f "$HOME/.inputrc" ]; then
    printf 'cree:%s\n' "$HOME/.inputrc" >>"$MANIF"
    printf '$include /etc/inputrc\n' >"$HOME/.inputrc"
  fi
  bloc_fichier "$HOME/.inputrc" 'set completion-ignore-case on
set show-all-if-ambiguous on
set colored-stats on
set colored-completion-prefix on
set mark-symlinked-directories on
"\e[A": history-search-backward
"\e[B": history-search-forward'
}
ecrire_gdbinit() {
  bloc_fichier "$HOME/.gdbinit" 'set history save on
set history filename ~/.gdb_history
set print pretty on
set disassembly-flavor intel
define dash
  source ~/.gdb-dashboard
end
document dash
Active gdb-dashboard (panneaux source, variables, pile). Taper : dash
end'
}
git_def() {      # git_def CLÉ VALEUR : seulement si tu ne l'as pas déjà réglée toi-même
  if [ -z "$(git config --global --get "$1" 2>/dev/null)" ]; then
    git config --global "$1" "$2" && printf 'git:%s\n' "$1" >>"$MANIF"
  fi
}
config_git() {
  command -v git >/dev/null || return 1
  git_def alias.lg "log --oneline --graph --decorate --all"
  git_def init.defaultBranch main
  if [ -x "$BIN/delta" ]; then
    git_def core.pager delta
    git_def interactive.diffFilter "delta --color-only"
    git_def delta.navigate true
    git_def delta.line-numbers true
    git_def delta.syntax-theme gruvbox-dark
  fi
}
ecrire_modeles() {
  local m="$KIT/modeles/projet-c"
  mkdir -p "$m/src" "$m/tests"
  cat >"$m/Makefile" <<'MAKE'
# Makefile — kit-etudiant
#   make          compiler (ASan + UBSan)     make run       compiler + lancer
#   make test     tests unitaires (Check)     make valgrind  fuites mémoire (sans ASan)
#   make analyse  gcc -fanalyzer              make check     cppcheck
#   make tidy     clang-tidy                  make format    clang-format
#   make compdb   compile_commands.json       make clean
CC      := gcc
CFLAGS  := -std=c11 -Wall -Wextra -Wpedantic -Wshadow -g -O0
SAN     := -fsanitize=address,undefined -fno-omit-frame-pointer
SRC     := $(wildcard src/*.c)
OBJ     := $(SRC:src/%.c=build/%.o)
BIN     := build/prog
TSRC    := $(wildcard tests/*.c)
# Check installé par micromamba (ou par le système, sinon)
CHECK   := $(HOME)/micromamba/envs/outils
export PKG_CONFIG_PATH := $(CHECK)/lib/pkgconfig:$(PKG_CONFIG_PATH)
PKGCFG  := $(firstword $(wildcard $(CHECK)/bin/pkg-config) pkg-config)
CHECKF   = $(shell $(PKGCFG) --cflags --libs check 2>/dev/null) -Wl,-rpath,$(CHECK)/lib

all: $(BIN)

$(BIN): $(OBJ)
	$(CC) $(CFLAGS) $(SAN) $^ -o $@

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) $(SAN) -MMD -c $< -o $@

build:
	mkdir -p build

run: all
	./$(BIN)

test: | build
	$(CC) $(CFLAGS) -Isrc $(TSRC) $(filter-out src/main.c,$(SRC)) $(CHECKF) -o build/tests
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
  cat >"$m/src/calcul.h" <<'C'
#ifndef CALCUL_H
#define CALCUL_H

int somme(int a, int b);

#endif
C
  cat >"$m/src/calcul.c" <<'C'
#include "calcul.h"

int somme(int a, int b)
{
    return a + b;
}
C
  cat >"$m/src/main.c" <<'C'
#include <stdio.h>
#include <stdlib.h>
#include "calcul.h"

int main(void)
{
    printf("2 + 3 = %d\n", somme(2, 3));
    return EXIT_SUCCESS;
}
C
  cat >"$m/tests/test_calcul.c" <<'C'
#include <check.h>
#include <stdlib.h>
#include "calcul.h"

START_TEST(test_somme)
{
    ck_assert_int_eq(somme(2, 3), 5);
    ck_assert_int_eq(somme(-1, 1), 0);
}
END_TEST

int main(void)
{
    Suite *s = suite_create("calcul");
    TCase *tc = tcase_create("base");
    tcase_add_test(tc, test_somme);
    suite_add_tcase(s, tc);
    SRunner *sr = srunner_create(s);   /* chaque test dans son propre processus */
    srunner_run_all(sr, CK_NORMAL);
    int echecs = srunner_ntests_failed(sr);
    srunner_free(sr);
    return echecs == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
C
  printf -- '-std=c11\n-Wall\n-Wextra\n-Isrc\n' >"$m/compile_flags.txt"
  printf 'BasedOnStyle: LLVM\nIndentWidth: 4\nColumnLimit: 100\nBreakBeforeBraces: Linux\n' >"$m/.clang-format"
  printf "Checks: 'clang-analyzer-*,bugprone-*,cert-*,-cert-err33-c,-bugprone-easily-swappable-parameters'\nWarningsAsErrors: ''\n" >"$m/.clang-tidy"
  printf 'build/\n*.o\n*.d\na.out\ncompile_commands.json\n.cache/\nvgcore.*\ncore\n' >"$m/.gitignore"
  cat >"$BIN/kit-projet" <<'SH'
#!/usr/bin/env bash
# kit-projet NOM : crée un projet C prêt à l'emploi (Makefile, tests Check, clang-format…)
set -euo pipefail
[ $# -eq 1 ] || { echo "usage : kit-projet NOM" >&2; exit 1; }
[ -e "$1" ] && { echo "« $1 » existe déjà" >&2; exit 1; }
mkdir -p "$1"
cp -r "$HOME/.config/kit-etudiant/modeles/projet-c/." "$1/"
git -C "$1" init -q 2>/dev/null || true
echo "Projet « $1 » créé.  cd $1 && make run   (make test, make valgrind, make analyse…)"
SH
  chmod +x "$BIN/kit-projet"; noter "$BIN/kit-projet"
}
theme_prompt() {  # starship en gruvbox (seulement si tu n'as pas déjà ta config)
  [ -x "$BIN/starship" ] || { echo "starship absent"; return 1; }
  [ -f "$HOME/.config/starship.toml" ] && { echo "starship.toml perso conservé"; return 0; }
  mkdir -p "$HOME/.config"
  "$BIN/starship" preset gruvbox-rainbow -o "$HOME/.config/starship.toml" || return 1
  noter "$HOME/.config/starship.toml"
}
ecrire_aide() {
  cat >"$KIT/aide.md" <<'AIDE'
# Aide-mémoire kit-etudiant

## Terminal
| Touche / commande | Effet |
|---|---|
| Ctrl-R | chercher dans l'historique (fzf) |
| Ctrl-T | insérer un fichier (fzf) |
| Alt-C | aller dans un dossier (fzf) |
| `vim **` puis Tab | choisir un fichier avec fzf |
| flèche droite | accepter la suggestion grise |
| `z tp1` | sauter à un dossier déjà visité |
| `..` ou nom de dossier seul | y entrer |
| `tldr tar` | exemples courts en français |
| `rg motif` / `fd nom` | chercher du texte / un fichier |
| `ll` / `lt` | liste détaillée / arbre |
| `tp fichier` | mettre à la corbeille (`trash-list`, `trash-restore`) |
| `mkcd dossier` | créer + entrer |
| `commande ; alert` | notification à la fin |
| `gccd prog.c` | compiler avec avertissements + ASan |
| `gcca prog.c` | analyse statique gcc (-fanalyzer) |
| `lg` | lazygit |
| `doc-c` | doc C hors ligne (cppreference) |
| `kit-aide` | cette page |

## Projet C
| Commande | Effet |
|---|---|
| `kit-projet tp1` | nouveau projet prêt |
| `make run` | compiler (ASan) + lancer |
| `make test` | tests unitaires (Check) |
| `make valgrind` | fuites mémoire |
| `make analyse` / `check` / `tidy` | analyse statique gcc / cppcheck / clang-tidy |
| `make format` | formater le code |
| `watchexec -e c,h -- make run` | recompiler à chaque sauvegarde |

## Vim (leader = Espace)
| Touche | Effet |
|---|---|
| F5 | compiler et lancer le fichier (C ou bash) |
| F6 | make + liste des erreurs |
| `]q` `[q` / `]g` `[g` | erreur suivante (quickfix / ALE) |
| `gd` / `gr` | définition / références |
| Espace h / Espace rn / Espace f | doc / renommer / formater |
| Ctrl-N / Ctrl-P | arbre de fichiers / chercher un fichier |
| Espace g / Espace b | chercher du texte / buffers |
| Espace u / Espace t / Espace T | annulations / plan / terminal |
| Ctrl-J puis Ctrl-L | snippet : déplier puis champ suivant |
| snippets C | `mainargs` `mallocv` `fopenv` `forkw` `pipef` |
| snippets bash | `bashs` `whileread` `getopts` |
| `gcc` / `cs"'` / `s` + 2 lettres | commenter / changer guillemets / sauter |
| `3K` sur printf | man 3 printf |
| `:Termdebug ./prog` | gdb dans Vim |
| Espace (attendre) | liste des raccourcis |

## gdb
| Commande | Effet |
|---|---|
| `dash` | panneaux source, variables, pile |
| `break main` / `run` | point d'arrêt / lancer |
| `next` / `step` / `finish` | ligne suivante / entrer / sortir |
| `print x` / `bt` | afficher / pile d'appels |

## tmux
| Touche | Effet |
|---|---|
| Ctrl-b \| / Ctrl-b - | découper vertical / horizontal |
| Ctrl-b flèches | changer de panneau |
| Ctrl-b d puis `tmux a` | détacher / revenir |

## Tes fichiers perso (jamais écrasés)
`~/.config/kit-etudiant/perso.sh`  `~/.vim/perso.vim`  `~/.tmux.perso.conf`  `~/.vim/vsnip/`
AIDE
  cat >"$BIN/kit-aide" <<'SH'
#!/usr/bin/env bash
# kit-aide : aide-mémoire du kit
f="$HOME/.config/kit-etudiant/aide.md"
if command -v glow >/dev/null && command -v less >/dev/null; then exec glow -p "$f"
elif command -v glow >/dev/null; then exec glow "$f"
elif command -v bat >/dev/null; then exec bat --style=plain -l md "$f"
else exec less "$f"; fi
SH
  chmod +x "$BIN/kit-aide"; noter "$BIN/kit-aide"
}
installer_cppref() {
  local url f="$WORK/dl/cppref.tar.xz" c
  url=$(gh_asset PeterFeicht/cppreference-doc '^html-book-.*\.tar\.xz$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$OPT/cppreference"; mkdir -p "$OPT/cppreference"
  tar -xJf "$f" -C "$OPT/cppreference" || return 1
  rm -f "$f"; noter "$OPT/cppreference"
  c=$(find "$OPT/cppreference" -path '*/en/c.html' | head -1); [ -n "$c" ] || return 1
  cat >"$BIN/doc-c" <<SH
#!/usr/bin/env bash
# doc-c : documentation C hors ligne (cppreference) dans le navigateur
exec xdg-open "$c"
SH
  chmod +x "$BIN/doc-c"; noter "$BIN/doc-c"
  raccourci doc-c "Doc C (hors ligne)" "$BIN/doc-c" "help-browser" "Development;Documentation;"
}
etape_doc() {
  titre "Documentation hors ligne + aide-mémoire"
  outil "doc C hors ligne (cppreference, commande doc-c)" "$OPT/cppreference" installer_cppref
  faire "aide-mémoire (commande kit-aide)" ecrire_aide
  if ! man -w 3 printf >/dev/null 2>&1; then
    info "pages man section 3 absentes (man 3 printf) : utilise doc-c et tldr"
  fi
}
etape_config() {
  titre "Configuration : bash, readline, gdb, git, modèles"
  faire "~/.bashrc (bloc kit + ~/.config/kit-etudiant/bashrc.sh)" ecrire_bashrc_kit
  faire "~/.inputrc" ecrire_inputrc
  faire "~/.gdbinit (commande « dash »)" ecrire_gdbinit
  faire "git (alias lg, delta)" config_git
  faire "modèle de projet C + commande kit-projet" ecrire_modeles
  faire "thème du prompt (starship gruvbox)" theme_prompt
  [ -f "$KIT/perso.sh" ] || printf '# Tes alias et réglages perso (jamais écrasé par le kit)\n' >"$KIT/perso.sh"
}

installer_police() {
  local f="$WORK/dl/JetBrainsMono.tar.xz" d="$SHR/fonts/JetBrainsMonoNerd"
  telecharger https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz "$f" || return 1
  rm -rf "$d"; mkdir -p "$d"; tar -xJf "$f" -C "$d" || return 1
  # garder seulement la variante « Mono » (largeur fixe, idéale en terminal), 4 styles
  find "$d" -type f ! -name 'JetBrainsMonoNerdFontMono-Regular.ttf' ! -name 'JetBrainsMonoNerdFontMono-Bold.ttf' \
       ! -name 'JetBrainsMonoNerdFontMono-Italic.ttf' ! -name 'JetBrainsMonoNerdFontMono-BoldItalic.ttf' -delete
  [ "$(find "$d" -name '*.ttf' | wc -l)" -eq 4 ] || return 1
  rm -f "$f"; noter "$d"
  command -v fc-cache >/dev/null && fc-cache -f "$SHR/fonts"
  return 0
}
installer_kitty() {
  local url f="$WORK/dl/kitty.txz" k="$PREFIX/kitty.app" a
  url=$(gh_asset kovidgoyal/kitty '^kitty-.*-x86_64\.txz$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$k"; mkdir -p "$k"; tar -xJf "$f" -C "$k" || return 1
  ln -sfn "$k/bin/kitty" "$BIN/kitty"; ln -sfn "$k/bin/kitten" "$BIN/kitten"
  for a in kitty kitty-open; do
    sed -e "s|Icon=kitty|Icon=$k/share/icons/hicolor/256x256/apps/kitty.png|" \
        -e "s|Exec=kitty|Exec=$k/bin/kitty|" "$k/share/applications/$a.desktop" >"$SHR/applications/$a.desktop"
    noter "$SHR/applications/$a.desktop"
  done
  noter "$k"; noter "$BIN/kitty"; noter "$BIN/kitten"; rm -f "$f"
  "$BIN/kitty" --version
}
theme_kitty() {   # police + thème gruvbox pour kitty (si pas de config perso)
  local d="$HOME/.config/kitty"
  [ -f "$d/kitty.conf" ] && { echo "kitty.conf perso conservé"; return 0; }
  mkdir -p "$d"
  telecharger https://raw.githubusercontent.com/kovidgoyal/kitty-themes/master/themes/gruvbox-dark.conf "$d/kit-theme.conf" || return 1
  printf '%s\n' "# kitty — kit-etudiant (tes réglages : kitty-perso.conf)" \
    "font_family      JetBrainsMono Nerd Font Mono" "font_size        12.0" \
    "enable_audio_bell no" "include kit-theme.conf" "include kitty-perso.conf" >"$d/kitty.conf"
  touch "$d/kitty-perso.conf"
  noter "$d/kitty.conf"; noter "$d/kit-theme.conf"
}
police_terminal() {  # terminal Mint (GNOME Terminal) : police Nerd Font, réglage remis à la désinstallation
  command -v gsettings >/dev/null || { echo "gsettings absent : à régler à la main"; return 0; }
  local id ch ancienne sys
  id=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
  [ -n "$id" ] || { echo "profil GNOME Terminal introuvable"; return 0; }
  ch="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$id/"
  ancienne=$(gsettings get "$ch" font 2>/dev/null) || return 0
  sys=$(gsettings get "$ch" use-system-font 2>/dev/null) || return 0
  [ -f "$KIT/terminal-avant.sh" ] || printf 'gsettings set "%s" font %s\ngsettings set "%s" use-system-font %s\n' \
    "$ch" "$ancienne" "$ch" "$sys" >"$KIT/terminal-avant.sh"
  gsettings set "$ch" font 'JetBrainsMono Nerd Font Mono 12' && gsettings set "$ch" use-system-font false
}
installer_espanso() {
  local url
  url=$(gh_asset espanso/espanso '^Espanso-X11\.AppImage$') || return 1
  appimage "$url" espanso espanso || return 1
  [ -d "$HOME/.config/espanso" ] || noter "$HOME/.config/espanso"
  mkdir -p "$HOME/.config/espanso/match" "$HOME/.config/autostart"
  [ -f "$HOME/.config/espanso/match/kit-c.yml" ] || cat >"$HOME/.config/espanso/match/kit-c.yml" <<'YML'
# espanso — tape le déclencheur n'importe où, il se remplace
matches:
  - trigger: ":incl"
    replace: "#include <stdio.h>\n#include <stdlib.h>\n"
  - trigger: ":main"
    replace: "int main(void)\n{\n    $|$\n    return EXIT_SUCCESS;\n}"
  - trigger: ":date"
    replace: "{{d}}"
    vars:
      - name: d
        type: date
        params:
          format: "%d/%m/%Y"
YML
  cat >"$HOME/.config/autostart/kit-espanso.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=espanso (kit)
Exec=$BIN/espanso start --unmanaged
X-GNOME-Autostart-Delay=8
EOF
  noter "$HOME/.config/espanso/match/kit-c.yml"; noter "$HOME/.config/autostart/kit-espanso.desktop"
}
ecrire_bureau() {
  mkdir -p "$HOME/.config/autostart" "$SHR/nemo/actions"
  cat >"$HOME/.config/autostart/kit-caps-echap.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Caps Lock = Échap (kit)
Comment=Shift+Caps garde le verrouillage majuscules
Exec=setxkbmap -option caps:escape_shifted_capslock
X-GNOME-Autostart-Delay=5
EOF
  cat >"$SHR/nemo/actions/kit-vim.nemo_action" <<'EOF'
[Nemo Action]
Name=Ouvrir dans Vim
Comment=Ouvre les fichiers sélectionnés dans Vim (terminal)
Exec=x-terminal-emulator -e vim %F
Icon-Name=accessories-text-editor
Selection=notnone
Extensions=any;
EOF
  cat >"$SHR/nemo/actions/kit-terminal-make.nemo_action" <<'EOF'
[Nemo Action]
Name=make run ici
Comment=Lance « make run » dans ce dossier
Exec=x-terminal-emulator -e bash -c "cd %P && make run; read -rp 'Entrée pour fermer'"
Icon-Name=utilities-terminal
Selection=none
Extensions=any;
EOF
  noter "$HOME/.config/autostart/kit-caps-echap.desktop"
  noter "$SHR/nemo/actions/kit-vim.nemo_action"; noter "$SHR/nemo/actions/kit-terminal-make.nemo_action"
}
etape_bureau() {
  titre "Bureau : police, kitty, espanso, Caps→Échap, Nemo"
  outil "police JetBrainsMono Nerd Font" "$SHR/fonts/JetBrainsMonoNerd" installer_police
  outil "kitty (terminal)" "$PREFIX/kitty.app" installer_kitty
  [ -x "$BIN/kitty" ] && faire "thème gruvbox + police pour kitty" theme_kitty
  faire "police du terminal Mint (si possible)" police_terminal
  outil "espanso (raccourcis texte, X11)" "$OPT/espanso" installer_espanso
  faire "Caps Lock → Échap + actions Nemo" ecrire_bureau
  amain "Si le prompt affiche des carrés : police « JetBrainsMono Nerd Font Mono » dans les préférences du terminal"
  amain "Aide-mémoire : kit-aide"
  amain "Caps Lock → Échap : actif à la prochaine session (ou lancer : setxkbmap -option caps:escape_shifted_capslock)"
  amain "espanso : démarre seul à la prochaine session (ou : espanso start --unmanaged)"
  amain "Applets Cinnamon : clic droit sur le panneau → Applets → Télécharger"
}

installer_flameshot() {
  local url f="$WORK/dl/flameshot.zip" d="$WORK/x/flameshot" a
  url=$(gh_asset flameshot-org/flameshot 'appimage-x86_64\.zip$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$d"; mkdir -p "$d"; extraire "$f" "$d" || return 1
  a=$(find "$d" -iname '*.AppImage' | head -1); [ -n "$a" ] || return 1
  appimage "$a" flameshot flameshot || return 1
  rm -rf "$d" "$f"
  raccourci flameshot "Flameshot" "$BIN/flameshot gui" "$(icone_appimage flameshot)" "Graphics;Utility;"
}
installer_keepassxc() {
  local url
  url=$(gh_asset keepassxreboot/keepassxc '^KeePassXC-.*-x86_64\.AppImage$') || return 1
  appimage "$url" keepassxc keepassxc || return 1
  raccourci keepassxc "KeePassXC" "$BIN/keepassxc" "$(icone_appimage keepassxc)" "Utility;Security;"
}
installer_imhex() {
  local url
  url=$(gh_asset WerWolv/ImHex '^imhex-.*-x86_64\.AppImage$') || return 1
  appimage "$url" imhex imhex || return 1
  raccourci imhex "ImHex" "$BIN/imhex" "$(icone_appimage imhex)" "Development;"
}
installer_cyberchef() {
  local url f="$WORK/dl/cyberchef.zip"
  url=$(gh_asset gchq/CyberChef '^CyberChef_.*\.zip$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$OPT/cyberchef"; mkdir -p "$OPT/cyberchef"; extraire "$f" "$OPT/cyberchef" || return 1
  cat >"$BIN/cyberchef" <<'SH'
#!/usr/bin/env bash
# Ouvre CyberChef (hors ligne) dans le navigateur
exec xdg-open "$(find "$HOME/.local/opt/cyberchef" -maxdepth 1 -name 'CyberChef*.html' | head -1)"
SH
  chmod +x "$BIN/cyberchef"
  raccourci cyberchef "CyberChef" "$BIN/cyberchef" "applications-internet" "Development;Security;"
  noter "$OPT/cyberchef"; noter "$BIN/cyberchef"; rm -f "$f"
  find "$OPT/cyberchef" -maxdepth 1 -name 'CyberChef*.html' | grep -q .
}
installer_copyq() {
  command -v flatpak >/dev/null || { echo "flatpak absent sur ce PC"; return 1; }
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
  flatpak install --user -y --noninteractive flathub com.github.hluk.copyq
}
etape_applis() {
  titre "Applications : KeePassXC, Flameshot, ImHex, CyberChef, CopyQ"
  outil "KeePassXC (mots de passe)" "$OPT/keepassxc" installer_keepassxc
  outil "Flameshot (captures annotées)" "$OPT/flameshot" installer_flameshot
  if [ "$SANS_LOURD" -eq 0 ]; then
    outil "ImHex (éditeur hexadécimal)" "$OPT/imhex" installer_imhex
  else info "ImHex sauté (--sans-lourd)"; fi
  if [ "$SANS_CYBER" -eq 0 ]; then
    outil "CyberChef (hors ligne)" "$OPT/cyberchef" installer_cyberchef
  else info "CyberChef sauté (--sans-cyber)"; fi
  if command -v flatpak >/dev/null; then
    outil "CopyQ (historique presse-papier, flatpak --user)" "$HOME/.local/share/flatpak/app/com.github.hluk.copyq" installer_copyq
  else
    info "CopyQ sauté : flatpak absent sur ce PC"
  fi
}

installer_ghidra() {
  local url f d
  # Java 21 (Temurin) dans ~/.local/opt/jdk21
  url=$(gh_asset adoptium/temurin21-binaries '^OpenJDK21U-jdk_x64_linux_hotspot_.*\.tar\.gz$') || return 1
  f="$WORK/dl/jdk21.tar.gz"; telecharger "$url" "$f" || return 1
  rm -rf "$OPT/jdk21"; mkdir -p "$OPT/jdk21"
  tar -xzf "$f" -C "$OPT/jdk21" --strip-components=1 || return 1
  rm -f "$f"; noter "$OPT/jdk21"
  "$OPT/jdk21/bin/java" -version || return 1
  # Ghidra dans ~/.local/opt/ghidra
  url=$(gh_asset NationalSecurityAgency/ghidra '^ghidra_.*_PUBLIC_.*\.zip$') || return 1
  f="$WORK/dl/ghidra.zip"; d="$WORK/x/ghidra"; telecharger "$url" "$f" || return 1
  rm -rf "$d" "$OPT/ghidra"; mkdir -p "$d"; extraire "$f" "$d" || return 1
  mv "$d"/ghidra_* "$OPT/ghidra" || return 1
  rm -rf "$d" "$f"; noter "$OPT/ghidra"
  cat >"$BIN/ghidra" <<'SH'
#!/usr/bin/env bash
export JAVA_HOME="$HOME/.local/opt/jdk21"
export PATH="$JAVA_HOME/bin:$PATH"
exec "$HOME/.local/opt/ghidra/ghidraRun" "$@"
SH
  chmod +x "$BIN/ghidra"; noter "$BIN/ghidra"
  raccourci ghidra "Ghidra" "$BIN/ghidra" "$OPT/ghidra/support/ghidra.ico" "Development;Security;"
  [ -x "$OPT/ghidra/ghidraRun" ]
}
etape_ghidra() {
  titre "Ghidra + Java 21"
  outil "Ghidra + Java 21 (~1,2 Go)" "$OPT/ghidra" installer_ghidra
}

# =============================================================================
#  VÉRIFICATIONS, RAPPORT, DÉSINSTALLATION
# =============================================================================
preflight() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "${R}Ne lance pas ce script en root : il s'installe pour TON utilisateur.${N}"; exit 1
  fi
  [ "$(uname -m)" = x86_64 ] || { echo "Processeur $(uname -m) non pris en charge (x86_64 seulement)."; exit 1; }
  local manque="" c
  for c in curl tar gzip xz git find install awk sed; do command -v "$c" >/dev/null || manque="$manque $c"; done
  [ -z "$manque" ] || { echo "${R}Commandes indispensables absentes :$manque${N}"; exit 1; }
  mkdir -p "$BIN" "$WORK/dl" "$WORK/x" "$KIT"
  : >"$LOGF"
  printf '#!/bin/sh\necho ok\n' >"$BIN/.kit-test"; chmod +x "$BIN/.kit-test"
  if [ "$("$BIN/.kit-test" 2>/dev/null)" != ok ]; then
    rm -f "$BIN/.kit-test"
    echo "${R}Ton home est monté « noexec » : aucun programme ne peut s'y exécuter. Demande au service informatique.${N}"
    exit 1
  fi
  rm -f "$BIN/.kit-test"
  command -v unzip  >/dev/null || command -v python3 >/dev/null || info "ni unzip ni python3 : les .zip échoueront"
  command -v bzip2  >/dev/null || info "bzip2 absent (pas grave)"
  printf '%skit-etudiant %s%s — journal : %s\n' "$B" "$KIT_VERSION" "$N" "$LOGF"
  printf '  glibc : %s   |   place libre dans ~ : %s\n' \
    "$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')" "$(df -h "$HOME" | awk 'NR==2{print $4}')"
  command -v quota >/dev/null && quota -s 2>/dev/null | tail -n +2 | sed 's/^/  quota : /'
  printf '  %sPlace nécessaire : ~5 Go en complet, ~2,5 Go avec --sans-lourd.%s\n' "$G" "$N"
  local libre; libre=$(df -Pk "$HOME" | awk 'NR==2{print int($4/1048576)}')
  if [ "$SANS_LOURD" -eq 0 ] && [ "${libre:-0}" -lt 6 ]; then
    info "Moins de 6 Go libres : pense à --sans-lourd. Sur un home réseau, vérifie aussi ton quota (quota -s)."
  fi
  export PATH="$BIN:$PATH"
}
rapport() {
  printf '\n%s======================== BILAN ========================%s\n' "$B" "$N"
  printf '%s✔ %d réussi(s)%s\n' "$V" "${#OKS[@]}" "$N"
  if [ ${#KOS[@]} -gt 0 ]; then
    printf '%s✘ %d échec(s) :%s\n' "$R" "${#KOS[@]}" "$N"
    printf '   - %s\n' "${KOS[@]}"
    printf '   Relancer le script réessaie seulement ce qui manque.\n'
  fi
  MAIN=("Ouvrir un NOUVEAU terminal (ou : source ~/.bashrc)" "${MAIN[@]}")
  printf '%sÀ faire toi-même :%s\n' "$J" "$N"; printf '   - %s\n' "${MAIN[@]}"
  printf '%sPlace utilisée :%s ' "$G" "$N"
  du -shc "$PREFIX" "$HOME/.vim" "$MAMBA_ROOT" "$HOME/.fzf" 2>/dev/null | tail -1 | cut -f1
  printf 'Journal complet : %s\n' "$LOGF"
}
desinstaller() {
  echo "Retire tout ce que kit-etudiant a créé (liste : $MANIF) et ses blocs dans tes fichiers de config."
  if [ -t 0 ]; then read -rp "Continuer ? [o/N] " r; [ "$r" = o ] || [ "$r" = O ] || exit 0; fi
  mkdir -p "$WORK"
  local p f
  [ -x "$BIN/uv" ] && "$BIN/uv" cache clean >/dev/null 2>&1
  # 1. blocs de config + fichiers créés de zéro + réglages git
  for f in .bashrc .profile .inputrc .gdbinit; do
    retirer_bloc "$HOME/$f"; rm -f "$HOME/$f.avant-kit"
  done
  if [ -f "$MANIF" ]; then
    grep '^cree:' "$MANIF" | sort -u | while IFS= read -r p; do
      f=${p#cree:}
      [ -f "$f" ] && ! grep -qvE '^[[:space:]]*$|^\$include /etc/inputrc$' "$f" && rm -f "$f"
    done
    grep '^git:' "$MANIF" | sort -u | while IFS= read -r p; do
      git config --global --unset "${p#git:}" 2>/dev/null
    done
    git config --global --remove-section delta 2>/dev/null
  fi
  for f in .vimrc .tmux.conf; do
    if [ -f "$HOME/$f.avant-kit" ]; then mv -f "$HOME/$f.avant-kit" "$HOME/$f"
    elif [ -f "$HOME/$f" ] && head -1 "$HOME/$f" | grep -q kit-etudiant; then rm -f "$HOME/$f"; fi
  done
  # 2. fichiers et dossiers installés
  if [ -f "$MANIF" ]; then
    grep -vE '^(cree|git):' "$MANIF" | sort -u | while IFS= read -r p; do
      case "$p" in
        ""|"$HOME"|"$HOME/"|"$PREFIX"|"$BIN"|"$OPT"|"$SHR"|"$HOME/.config"|"$HOME/.cache") continue ;;
        "$HOME"/*) rm -rf -- "$p" ;;
      esac
    done
  fi
  # 3. caches laissés par les outils, plugins tmux, dossiers vides
  rm -rf "$HOME/.tmux/plugins" "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup" \
         "$HOME/.cache/tealdeer" "$HOME/.cache/starship" "$HOME/.cache/glow" "$HOME/.cache/blesh" \
         "$HOME/.local/state/blesh" "$HOME/.local/state/gh" "$HOME/.config/glow" "$HOME"/.cache/.pwntools-cache-*
  find "$PREFIX" "$HOME/.vim" "$HOME/.tmux" "$HOME/.config/rclone" "$HOME/.config/autostart" "$HOME/.config/kitty" \
       -depth -type d -empty -delete 2>/dev/null
  [ -f "$KIT/terminal-avant.sh" ] && bash "$KIT/terminal-avant.sh" 2>/dev/null
  [ -d "$KIT" ] && find "$KIT" -mindepth 1 -maxdepth 1 ! -name perso.sh -exec rm -rf {} + 2>/dev/null
  rm -rf "$WORK"
  echo "Terminé. Ouvre un nouveau terminal."
  echo "Gardés pour toi : ~/.config/kit-etudiant/perso.sh, ~/.vim/perso.vim, ~/.vim/vsnip (tes snippets), ~/.tmux.perso.conf"
}
aide() { awk 'NR>2 && /^[^#]/{exit} NR>2{sub(/^# ?/,""); print}' "$0"; }

# =============================================================================
#  PROGRAMME PRINCIPAL
# =============================================================================
while [ $# -gt 0 ]; do
  case "$1" in
    --maj) MAJ=1 ;;
    --sans-lourd) SANS_LOURD=1 ;;
    --sans-cyber) SANS_CYBER=1 ;;
    --sans-gui) SANS_GUI=1 ;;
    --sans-conda) SANS_CONDA=1 ;;
    --seulement) shift; SEULEMENT=${1:-} ;;
    --seulement=*) SEULEMENT=${1#*=} ;;
    --liste) for e in "${ETAPES[@]}"; do printf '  %-13s %s\n' "$e" "${DESC[$e]}"; done; exit 0 ;;
    --desinstaller) MODE=desinstaller ;;
    -h|--aide|--help) aide; exit 0 ;;
    *) echo "option inconnue : $1 (voir --aide)"; exit 1 ;;
  esac
  shift
done

if [ "$MODE" = desinstaller ]; then desinstaller; exit 0; fi

preflight
for e in "${ETAPES[@]}"; do
  if [ -n "$SEULEMENT" ] && [[ ",$SEULEMENT," != *",$e,"* ]]; then continue; fi
  case "$e" in
    conda)          [ "$SANS_CONDA" -eq 1 ] && { info "étape conda sautée (--sans-conda)"; continue; } ;;
    bureau|applis)  [ "$SANS_GUI" -eq 1 ] && { info "étape $e sautée (--sans-gui)"; continue; } ;;
    ghidra)         { [ "$SANS_GUI" -eq 1 ] || [ "$SANS_LOURD" -eq 1 ]; } && { info "Ghidra sauté"; continue; } ;;
  esac
  "etape_$e"
done
rm -rf "$WORK/dl" "$WORK/x"
rapport
[ ${#KOS[@]} -eq 0 ]
