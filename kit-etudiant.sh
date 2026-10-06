#!/usr/bin/env bash
# shellcheck disable=SC2088  # les « ~/ » entre guillemets sont des libellés affichés
# =============================================================================
#  kit-etudiant.sh 2.5 — Ton environnement « maison » sur Linux Mint, SANS ROOT
#     zsh + oh-my-zsh + powerlevel10k   ·   Neovim + LazyVim (clangd, débogueur)
#     GNOME Terminal aux couleurs de Konsole + police MesloLGS NF
#     Outils C / Bash : gdb, valgrind, shellcheck, cppcheck, rg, fd, lazygit…
#  Tout s'installe dans ton $HOME. Relançable. Désinstallable.
# =============================================================================
#  Usage : bash kit-etudiant.sh [options]
#    --maison ARCHIVE  reprendre ta config maison (kit-maison.tar.gz de export-maison.sh)
#    --p10k FICHIER    utiliser seulement ta config powerlevel10k (~/.p10k.zsh)
#    --maj             tout réinstaller / mettre à jour
#    --sans-conda      sauter micromamba (valgrind, gdb, cppcheck, bear, tmux, check, node)
#    --sans-terminal   ne pas créer le profil GNOME Terminal « Maison »
#    --seulement A,B   ne lancer que ces étapes (voir --liste)
#    --liste           lister les étapes
#    --desinstaller    tout retirer (marche aussi pour une installation version 1)
#    --tout            avec --desinstaller : retirer aussi tes fichiers perso
#    --aide            cette aide
# =============================================================================
set -uo pipefail

# ---- Garde-fou : ce script ne doit JAMAIS élever ses droits -----------------
sudo()   { echo "INTERDIT : kit-etudiant n'utilise jamais sudo" >&2; return 97; }
su()     { echo "INTERDIT : kit-etudiant n'utilise jamais su" >&2; return 97; }
pkexec() { echo "INTERDIT : kit-etudiant n'utilise jamais pkexec" >&2; return 97; }

KIT_VERSION="2.5 — 2026-10-06"
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
OPT="$PREFIX/opt"
SHR="$PREFIX/share"
KIT="$HOME/.config/kit-etudiant"
WORK="$HOME/.cache/kit-etudiant"          # pas /tmp : souvent monté noexec
MAMBA_ROOT="$HOME/micromamba"
NVIM_CFG="$HOME/.config/nvim"
ZCUSTOM="$HOME/.oh-my-zsh/custom"
MANIF="$KIT/manifeste"
LOGF="$WORK/install-$(date +%Y%m%d-%H%M%S).log"
MARQ_DEBUT='>>> kit-etudiant >>>'
MARQ_FIN='<<< kit-etudiant <<<'

MM="$OPT/micromamba/micromamba"
MAISON=""; MAISON_DIR=""; POLICE="MesloLGS NF 15"; MARGE=5
RAISON=""; MAJ=0; SANS_CONDA=0; SANS_TERM=0; TOUT=0; SEULEMENT=""; P10K_SRC=""; MODE=installer
declare -a OKS=() KOS=() MAIN=()

if [ -t 1 ]; then V=$'\e[32m'; R=$'\e[31m'; J=$'\e[33m'; B=$'\e[1;34m'; G=$'\e[2m'; N=$'\e[0m'
else V=""; R=""; J=""; B=""; G=""; N=""; fi

ETAPES=(prepa cli zsh outils_shell outils_c python conda neovim tmux config doc terminal presse_papier)
declare -A DESC=(
  [prepa]="dossiers, vérifications (noexec, glibc, place), PATH"
  [cli]="rg fd bat eza delta lazygit jq yazi gh glow watchexec hyperfine duf sd btop gdu direnv chezmoi croc rclone tldr"
  [zsh]="zsh (zsh-bin), oh-my-zsh, powerlevel10k, autosuggestions, syntax-highlighting, you-should-use, zsh-bat, fzf, zoxide"
  [outils_shell]="shellcheck, shfmt, bats-core"
  [outils_c]="gdb-dashboard"
  [python]="uv + clang-format, clang-tidy, trash-cli"
  [conda]="micromamba + valgrind gdb cppcheck bear tmux check pkg-config node xclip"
  [neovim]="Neovim + LazyVim (clangd, débogueur codelldb, bash), plugins et outils Mason"
  [tmux]="tmux.conf, tpm, tmux-sensible, tmux-resurrect"
  [config]=".zshrc, repli bash, gdbinit, git + delta, modèle de projet C, kit-projet, kit-aide"
  [doc]="doc C hors ligne (cppreference, commande doc-c)"
  [terminal]="police MesloLGS NF, profil GNOME Terminal « Maison » (couleurs Konsole), Caps Lock → Échap"
  [presse_papier]="CopyQ : historique de tout ce que tu copies (terminal, Neovim, navigateur), Super+V"
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
bloc_fichier() { # bloc_fichier FICHIER CONTENU [DÉBUT_COMMENTAIRE] [FIN_COMMENTAIRE]
  local f=$1 contenu=$2 c=${3:-#} fin=${4:+ $4} tmp
  if [ -f "$f" ] && [ ! -f "$f.avant-kit" ]; then cp "$f" "$f.avant-kit"; fi
  [ -e "$f" ] || printf 'cree:%s\n' "$f" >>"$MANIF"
  tmp=$(mktemp "$WORK/bloc.XXXXXX")
  [ -f "$f" ] && awk -v d="$c $MARQ_DEBUT$fin" -v e="$c $MARQ_FIN$fin" \
    '$0==d{s=1;next} $0==e{s=0;next} !s' "$f" >"$tmp"
  printf '%s %s%s\n%s\n%s %s%s\n' "$c" "$MARQ_DEBUT" "$fin" "$contenu" "$c" "$MARQ_FIN" "$fin" >>"$tmp"
  cat "$tmp" >"$f"; rm -f "$tmp"
}
retirer_bloc() { # retirer_bloc FICHIER [DÉBUT_COMMENTAIRE] [FIN_COMMENTAIRE]
  local f=$1 c=${2:-#} fin=${3:+ $3} tmp
  [ -f "$f" ] || return 0
  tmp=$(mktemp "$WORK/bloc.XXXXXX")
  awk -v d="$c $MARQ_DEBUT$fin" -v e="$c $MARQ_FIN$fin" '$0==d{s=1;next} $0==e{s=0;next} !s' "$f" >"$tmp"
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

# ---- Outils en ligne de commande -------------------------------------------
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
  )
  local ligne nom depot re specs final
  for ligne in "${L[@]}"; do
    read -r nom depot re specs <<<"$ligne"
    final=${specs%% *}; final=${final##*:}
    # shellcheck disable=SC2086
    outil "$nom" "$BIN/$final" installer_gh "$depot" "$re" $specs
  done
  [ -x "$BIN/tldr" ] && outil "pages tldr en français + anglais" "$HOME/.cache/tealdeer/tldr-pages" tldr_pages
}

# ---- zsh + oh-my-zsh + powerlevel10k ----------------------------------------
installer_zsh() {   # zsh-bin : zsh statique et déplaçable, par l'auteur de powerlevel10k
  local f="$WORK/dl/zsh-bin-install" man_avant=0
  [ -d "$PREFIX/man" ] && man_avant=1
  telecharger https://raw.githubusercontent.com/romkatv/zsh-bin/master/install "$f" || return 1
  sh "$f" -q -d "$PREFIX" -e no || return 1
  noter "$BIN/zsh"; noter "$SHR/zsh"
  local z; for z in "$BIN"/zsh-*; do [ -e "$z" ] && noter "$z"; done
  for z in "$SHR"/man/man1/zsh*; do [ -e "$z" ] && noter "$z"; done
  [ $man_avant -eq 0 ] && [ -d "$PREFIX/man" ] && noter "$PREFIX/man"
  "$BIN/zsh" --version
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
cloner() {        # cloner depot/projet DOSSIER : clone, ou met à jour avec --maj
  if [ -d "$2/.git" ]; then
    [ "$MAJ" -eq 1 ] && { git -C "$2" pull -q --ff-only || return 1; }
    return 0
  fi
  git clone -q --depth 1 "https://github.com/$1.git" "$2" || return 1
  noter "$2"
}
config_p10k() {   # ta config de la maison si fournie, sinon le style « rainbow »
  if [ -n "$P10K_SRC" ]; then
    cp "$P10K_SRC" "$HOME/.p10k.zsh" || return 1
    echo "config powerlevel10k copiée depuis $P10K_SRC (c'est la tienne : jamais supprimée)"
    return 0
  elif [ -f "$HOME/.p10k.zsh" ]; then
    echo "~/.p10k.zsh déjà là : conservé"; return 0
  else
    cp "$ZCUSTOM/themes/powerlevel10k/config/p10k-rainbow.zsh" "$HOME/.p10k.zsh" || return 1
    echo "style rainbow par défaut (refaire avec : p10k configure)"
  fi
  noter "$HOME/.p10k.zsh"
}
# Ta liste de plugins maison (fichier ~/.zsh-plugins), utilisée si --maison n'est pas donné
plugins_defaut() {
  printf '%s\n' you-should-use git autojump fancy-ctrl-z command-not-found colored-man-pages \
    common-aliases copybuffer copyfile dirhistory history web-search sudo zsh-bat \
    zsh-syntax-highlighting zsh-autosuggestions thefuck
}
lire_plugins() {  # lit « plugins=( … ) » dans un fichier
  sed -n '/plugins=(/,/)/p' "$1" | sed 's/#.*//; s/plugins=(//; s/)//' | tr -s ' \t' '\n\n' | grep -v '^$'
}
ecrire_plugins() {  # génère ~/.config/kit-etudiant/plugins.zsh (chaque plugin seulement s'il peut marcher)
  local p liste fzf_vu=0
  if [ -n "$MAISON_DIR" ] && [ -f "$MAISON_DIR/zsh/zsh-plugins" ]; then liste=$(lire_plugins "$MAISON_DIR/zsh/zsh-plugins")
  elif [ -n "$MAISON_DIR" ] && [ -f "$MAISON_DIR/zsh/zshrc" ]; then liste=$(lire_plugins "$MAISON_DIR/zsh/zshrc")
  else liste=$(plugins_defaut); fi
  {
    echo "# kit-etudiant — plugins oh-my-zsh, repris de ta config maison. Réécrit à chaque installation."
    echo 'plugins=()'
    while read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        autojump) echo '# autojump (absent sans root) remplacé par zoxide : « z dossier », ou « j dossier »'
                  echo '(( $+commands[zoxide] )) && plugins+=(zoxide)' ;;
        fzf) fzf_vu=1; echo '(( $+commands[fzf] )) && plugins+=(fzf)' ;;
        thefuck|zoxide|direnv) printf '(( $+commands[%s] )) && plugins+=(%s)\n' "$p" "$p" ;;
        zsh-bat) echo '(( $+commands[bat] )) && plugins+=(zsh-bat)' ;;
        *) printf '[[ -d $ZSH/plugins/%s || -d $ZSH/custom/plugins/%s ]] && plugins+=(%s)\n' "$p" "$p" "$p" ;;
      esac
    done <<<"$liste"
    [ $fzf_vu -eq 1 ] || { echo '# fzf : chargé par ~/.fzf.zsh à la maison'; echo '(( $+commands[fzf] )) && plugins+=(fzf)'; }
  } >"$KIT/plugins.zsh"
  grep -c 'plugins+=' "$KIT/plugins.zsh"
}
etape_zsh() {
  titre "zsh + oh-my-zsh + powerlevel10k"
  outil "zsh (zsh-bin, sans root)" "$BIN/zsh" installer_zsh
  outil "fzf" "$BIN/fzf" installer_fzf
  outil "zoxide" "$BIN/zoxide" installer_gh ajeetdsouza/zoxide 'x86_64-unknown-linux-musl\.tar\.gz$' zoxide
  faire "oh-my-zsh" cloner ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh" || return
  faire "thème powerlevel10k" cloner romkatv/powerlevel10k "$ZCUSTOM/themes/powerlevel10k"
  faire "zsh-autosuggestions" cloner zsh-users/zsh-autosuggestions "$ZCUSTOM/plugins/zsh-autosuggestions"
  faire "zsh-syntax-highlighting" cloner zsh-users/zsh-syntax-highlighting "$ZCUSTOM/plugins/zsh-syntax-highlighting"
  faire "you-should-use" cloner MichaelAquilina/zsh-you-should-use "$ZCUSTOM/plugins/you-should-use"
  faire "zsh-bat" cloner fdellwing/zsh-bat "$ZCUSTOM/plugins/zsh-bat"
  faire "config powerlevel10k (~/.p10k.zsh)" config_p10k
}

# ---- Outils shell, C, Python, conda ------------------------------------------
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
etape_outils_c() {
  titre "C : gdb-dashboard"
  outil "gdb-dashboard" "$HOME/.gdb-dashboard" bash -c \
    "curl -fsSL https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/master/.gdbinit -o '$HOME/.gdb-dashboard' && echo '$HOME/.gdb-dashboard' >>'$MANIF'"
}

uv_outil() {     # uv_outil PAQUET [VERSION_PYTHON] : installe et expose ses commandes dans ~/.local/bin
  local p=$1 py=${2:-} e cible td n=0
  td=$("$BIN/uv" tool dir) || return 1
  UV_TOOL_BIN_DIR="$OPT/uv-bin" "$BIN/uv" tool install --upgrade ${py:+--python "$py"} "$p" || return 1
  noter "$OPT/uv-bin"; noter "$td/$p"
  for e in "$OPT/uv-bin"/*; do
    cible=$(readlink -f "$e")
    case "$cible" in "$td/$p/"*) ln -sfn "$e" "$BIN/${e##*/}"; noter "$BIN/${e##*/}"; n=$((n + 1)) ;; esac
  done
  echo "$n commande(s) exposée(s) pour $p"; [ "$n" -gt 0 ]
}
etape_python() {
  titre "Python : uv + outils"
  outil "uv (gestionnaire Python)" "$BIN/uv" installer_gh astral-sh/uv '^uv-x86_64-unknown-linux-musl\.tar\.gz$' uv uvx
  noter "$HOME/.cache/uv"
  [ -x "$BIN/uv" ] || { ko "outils Python" "uv absent"; return; }
  local td; td=$("$BIN/uv" tool dir 2>/dev/null)
  outil "trash-cli (corbeille)" "$td/trash-cli" uv_outil trash-cli
  outil clang-format "$td/clang-format" uv_outil clang-format
  outil clang-tidy "$td/clang-tidy" uv_outil clang-tidy
  outil "thefuck (corrige ta dernière commande)" "$td/thefuck" uv_outil thefuck 3.11
  noter "$HOME/.local/share/uv/python"
  noter "$HOME/.local/share/uv"
}

conda_env() {
  local pk=(valgrind gdb cppcheck bear tmux check pkg-config nodejs xclip)
  if [ -d "$MAMBA_ROOT/envs/outils" ]; then
    "$MM" -r "$MAMBA_ROOT" install -y -n outils -c conda-forge --override-channels "${pk[@]}" || return 1
    [ "$MAJ" -eq 1 ] && { "$MM" -r "$MAMBA_ROOT" update -y -n outils --all || return 1; }
  else
    "$MM" -r "$MAMBA_ROOT" create -y -n outils -c conda-forge --override-channels "${pk[@]}" || return 1
  fi
  "$MM" -r "$MAMBA_ROOT" clean -a -y
}
conda_liens() {  # le système garde la priorité : on ne lie que ce qui manque
  local e="$MAMBA_ROOT/envs/outils/bin" b
  for b in valgrind vgdb gdb gdbserver cppcheck bear tmux node npm npx checkmk xclip; do
    [ -e "$e/$b" ] || continue
    if systeme_a "$b"; then echo "$b : version système conservée"; continue; fi
    ln -sfn "$e/$b" "$BIN/$b"; noter "$BIN/$b"
  done
}
etape_conda() {
  titre "micromamba : valgrind, gdb, cppcheck, bear, tmux, check, node"
  if systeme_a micromamba; then
    info "un micromamba existe déjà sur ce PC (celui de la fac) : le kit utilise le sien, dans ~/.local/bin, sous un autre nom de commande"
  fi
  outil micromamba "$OPT/micromamba/micromamba" bash -c "
    mkdir -p '$OPT/micromamba' && curl -fsSL -o '$OPT/micromamba/micromamba' \
      https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-linux-64 \
    && chmod +x '$OPT/micromamba/micromamba' && echo '$OPT/micromamba' >>'$MANIF'"
  # pas de lien « micromamba » dans ~/.local/bin : ne jamais masquer celui de la fac
  [ -x "$OPT/micromamba/micromamba" ] || { ko "environnement outils" "micromamba absent"; return; }
  noter "$MAMBA_ROOT"; noter "$HOME/.mamba"
  faire "environnement « outils » (conda-forge)" conda_env || return
  faire "liens vers ~/.local/bin (si absent du système)" conda_liens
}

# ---- Neovim + LazyVim --------------------------------------------------------
installer_nvim() {
  local url f="$WORK/dl/nvim.tar.gz"
  url=$(gh_asset neovim/neovim '^nvim-linux-x86_64\.tar\.gz$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$OPT/nvim"; mkdir -p "$OPT/nvim"
  tar -xzf "$f" -C "$OPT/nvim" --strip-components=1 || return 1
  ln -sfn "$OPT/nvim/bin/nvim" "$BIN/nvim"
  noter "$OPT/nvim"; noter "$BIN/nvim"; rm -f "$f"
  "$BIN/nvim" --version | head -1
}
config_lazyvim() {
  if [ ! -f "$NVIM_CFG/.kit-etudiant" ]; then
    if [ -e "$NVIM_CFG" ]; then
      [ -e "$NVIM_CFG.avant-kit" ] || mv "$NVIM_CFG" "$NVIM_CFG.avant-kit"
      echo "ancienne config Neovim mise de côté : $NVIM_CFG.avant-kit"
      rm -rf "$NVIM_CFG"
    fi
    git clone -q --depth 1 https://github.com/LazyVim/starter "$NVIM_CFG" || return 1
    rm -rf "$NVIM_CFG/.git"
    echo "config Neovim créée par kit-etudiant (lazyvim.json, lua/plugins/kit.lua et lua/config/options.lua sont réécrits ; le reste est à toi)" >"$NVIM_CFG/.kit-etudiant"
  fi
  mkdir -p "$NVIM_CFG/lua/plugins" "$NVIM_CFG/lua/config"
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
  # Registre Mason figé sur une version : pas d'appel à l'API GitHub (limitée sur un réseau
  # partagé comme celui de la fac) et des outils stables. --maj passe à la dernière version.
  local reg=""
  [ "$MAJ" -eq 0 ] && reg=$(sed -n 's/.*mason-registry@\([^"]*\)".*/\1/p' "$NVIM_CFG/lua/plugins/kit.lua" 2>/dev/null | head -1)
  [ -n "$reg" ] || reg=$(gh_tag mason-org/mason-registry)
  local ligne_reg=""
  [ -n "$reg" ] && ligne_reg="registries = { \"github:mason-org/mason-registry@$reg\" }, "
  cat >"$NVIM_CFG/lua/plugins/kit.lua" <<LUA
-- kit-etudiant : réécrit à chaque installation. Tes plugins : lua/plugins/perso.lua
return {
  -- Bash : serveur de langage (complétion, doc) + shellcheck (erreurs) ; shfmt formate déjà
  -- bashls seulement si on peut l'avoir (npm pour l'installer, ou déjà installé) : sinon
  -- Mason réessaierait à chaque ouverture et afficherait une erreur rouge.
  { "neovim/nvim-lspconfig", opts = function(_, opts)
      opts.servers = opts.servers or {}
      if vim.fn.executable("npm") == 1 or vim.fn.executable("bash-language-server") == 1 then
        opts.servers.bashls = {}
      end
    end },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { sh = { "shellcheck" }, bash = { "shellcheck" } } } },
  { "mason-org/mason.nvim", opts = { ${ligne_reg}ensure_installed = { "shellcheck", "shfmt", "codelldb" } } },
  -- Ligne de commande et messages classiques de Vim, en bas de l'écran
  { "folke/noice.nvim", opts = { cmdline = { enabled = false }, messages = { enabled = false } } },
}
LUA
  cat >"$NVIM_CFG/lua/config/options.lua" <<'LUA'
-- kit-etudiant : réécrit à chaque installation. Tes options : lua/config/perso.lua
vim.opt.relativenumber = false   -- numéros de ligne classiques
vim.opt.scrolloff = 5
pcall(require, "config.perso")
LUA
  rm -f "$NVIM_CFG/lua/config/kit_raccourcis.lua"   # ancien remappage Ctrl-C/Ctrl-V (v2.2), retiré
  [ -f "$NVIM_CFG/lua/config/perso.lua" ] || printf -- '-- Tes options Neovim (jamais écrasé par le kit)\n' >"$NVIM_CFG/lua/config/perso.lua"
  [ -f "$NVIM_CFG/lua/plugins/perso.lua" ] || printf -- '-- Tes plugins Neovim (jamais écrasé par le kit)\nreturn {}\n' >"$NVIM_CFG/lua/plugins/perso.lua"
  return 0
}
nvim_plugins() {
  if [ "$MAJ" -eq 1 ]; then timeout 900 "$BIN/nvim" --headless "+Lazy! sync" +qa
  else timeout 900 "$BIN/nvim" --headless "+Lazy! install" +qa; fi
  local n; n=$(find "$HOME/.local/share/nvim/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  echo "plugins Neovim installés : $n"
  noter "$HOME/.local/share/nvim"; noter "$HOME/.local/state/nvim"; noter "$HOME/.cache/nvim"
  [ "$n" -ge 20 ]
}
nvim_mason() {   # installe les outils Mason et attend la fin (sinon nvim --headless quitte trop tôt)
  local outils="clangd codelldb shellcheck shfmt stylua tree-sitter-cli"
  command -v npm >/dev/null && outils="$outils bash-language-server"
  cat >"$WORK/kit-mason.lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim" } })
local reg = require("mason-registry")
pcall(reg.refresh)
local noms = vim.split(vim.env.KIT_MASON or "", " ", { trimempty = true })
for _, n in ipairs(noms) do
  local ok, p = pcall(reg.get_package, n)
  if not ok then io.stdout:write("paquet inconnu : " .. n .. "\n")
  elseif not p:is_installed() and not p:is_installing() then pcall(function() p:install() end) end
end
vim.wait(900000, function()
  for _, p in ipairs(reg.get_all_packages()) do if p:is_installing() then return false end end
  return true
end, 1000)
for _, n in ipairs(noms) do
  local ok, p = pcall(reg.get_package, n)
  io.stdout:write(n .. " : " .. ((ok and p:is_installed()) and "OK" or "ÉCHEC") .. "\n")
end
LUA
  [ -f /etc/ssl/certs/ca-certificates.crt ] && export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
  KIT_MASON="$outils" npm_config_cache="$HOME/.npm" timeout 1200 "$BIN/nvim" --headless "+luafile $WORK/kit-mason.lua" +qa
  noter "$HOME/.npm"
  [ -e "$HOME/.local/share/nvim/mason/bin/clangd" ]
}
nvim_parseurs() {  # compile les parseurs de coloration (C, bash…) et attend la fin
  cat >"$WORK/kit-ts.lua" <<'LUA'
require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
local ok, ts = pcall(require, "nvim-treesitter")
local langs = vim.split(vim.env.KIT_TS or "c bash", " ", { trimempty = true })
if ok and type(ts.install) == "function" then
  local tache = ts.install(langs)
  if tache and tache.wait then tache:wait(600000) end
else
  vim.cmd("TSInstallSync " .. table.concat(langs, " "))
end
local dir = vim.fn.stdpath("data") .. "/site/parser/"
local casses = 0
for _, l in ipairs(langs) do
  local bon = pcall(vim.treesitter.query.get, l, "highlights")
  if not bon then casses = casses + 1 end
  io.stdout:write(l .. " : " .. (vim.uv.fs_stat(dir .. l .. ".so") and (bon and "OK" or "RÈGLES CASSÉES") or "ÉCHEC") .. "\n")
end
if casses > 0 then os.exit(1) end
LUA
  KIT_TS="c cpp bash make markdown markdown_inline lua vim vimdoc regex query diff printf" \
    timeout 900 "$BIN/nvim" --headless "+luafile $WORK/kit-ts.lua" +qa
  [ -e "$HOME/.local/share/nvim/site/parser/c.so" ]
}
etape_neovim() {
  titre "Neovim + LazyVim"
  outil "Neovim" "$BIN/nvim" installer_nvim
  [ -x "$BIN/nvim" ] || { ko "LazyVim" "Neovim absent"; return; }
  faire "config LazyVim (~/.config/nvim)" config_lazyvim || return
  faire "plugins LazyVim (1re fois : quelques minutes)" nvim_plugins
  outil "outils Mason (clangd, codelldb, shellcheck, shfmt, bashls)" "$HOME/.local/share/nvim/mason/bin/clangd" nvim_mason
  if [ "$MAJ" -eq 1 ] || [ ! -e "$HOME/.local/share/nvim/site/parser/c.so" ]; then
    faire "parseurs de coloration (C, bash…)" nvim_parseurs \
      || info "les parseurs se compileront au premier lancement de nvim (attendre 1 minute)"
  fi
  command -v npm >/dev/null || info "node absent : pas de serveur bash dans Neovim (shellcheck marche quand même)"
}

# ---- tmux --------------------------------------------------------------------
etape_tmux() {
  titre "tmux : configuration + plugins"
  local p="$HOME/.tmux/plugins" r
  mkdir -p "$p"
  for r in tpm tmux-sensible tmux-resurrect; do
    faire "$r" cloner "tmux-plugins/$r" "$p/$r"
  done
  if [ -f "$HOME/.tmux.conf" ] && ! head -1 "$HOME/.tmux.conf" | grep -q kit-etudiant; then
    if [ -f "$HOME/.tmux.conf.avant-kit" ]; then
      info "~/.tmux.conf personnel (sans marque kit) : laissé tel quel"; return 0
    fi
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.avant-kit"
  fi
  {
    cat <<'TMUX'
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
TMUX
    [ -x "$BIN/zsh" ] && printf 'set -g default-shell "%s"\n' "$BIN/zsh"
    printf '%s\n' "if-shell 'test -f ~/.tmux.perso.conf' 'source-file ~/.tmux.perso.conf'" "run -b '~/.tmux/plugins/tpm/tpm'"
  } >"$HOME/.tmux.conf"
  ok "~/.tmux.conf (Ctrl-b | et Ctrl-b - pour découper)"
}

# ---- Configuration -----------------------------------------------------------
ecrire_zshrc() {
  if [ -f "$HOME/.zshrc" ] && ! head -1 "$HOME/.zshrc" | grep -q kit-etudiant; then
    [ -f "$HOME/.zshrc.avant-kit" ] || cp "$HOME/.zshrc" "$HOME/.zshrc.avant-kit"
    echo "ancien ~/.zshrc sauvegardé : ~/.zshrc.avant-kit"
  fi
  cat >"$HOME/.zshrc" <<'ZSHRC'
# kit-etudiant — géré par kit-etudiant.sh. Tes ajouts : ~/.config/kit-etudiant/perso.zsh
# (retire cette 1re ligne pour que le script ne touche plus à ce fichier)

# Prompt instantané powerlevel10k : doit rester tout en haut
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
zstyle ':omz:update' mode disabled        # pas de mise à jour surprise (examens)
HIST_STAMPS="dd/mm/yyyy"
HISTSIZE=50000
SAVEHIST=50000
source "$HOME/.config/kit-etudiant/plugins.zsh"   # ta liste de plugins maison
source "$ZSH/oh-my-zsh.sh"

# ---- Alias ----
alias vim=nvim vi=nvim
(( $+commands[zoxide] ))    && alias j=z           # habitude autojump
(( $+commands[eza] ))       && alias lt='eza --tree --level=2 --icons'
(( $+commands[lazygit] ))   && alias lg=lazygit
(( $+commands[gedit] )) || { (( $+commands[xed] )) && alias gedit=xed; }   # Mint : xed = gedit
(( $+commands[trash-put] )) && alias tp=trash-put
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# ---- C : tes commandes de la maison (crun, csan, cmem, cdebug) ----
# -D_DEFAULT_SOURCE : rend visibles strdup, getline, kill, fileno… malgré -std=c11
export CC=gcc
CFLAGS_KIT="-std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -g"
CFLAGS_SAN="$CFLAGS_KIT -O0 -fsanitize=address,undefined -fno-omit-frame-pointer"
LDLIBS_KIT="-lm"
_kit_cc() {   # _kit_cc "drapeaux" fichier.c
  [[ -f $2 ]] || { print -u2 "Usage : ${funcstack[2]} fichier.c [arguments]"; return 1; }
  $CC ${=1} "$2" -o "${2%.c}" ${=LDLIBS_KIT}
}
_kit_bin() { [[ $1 == /* ]] && print -r -- "${1%.c}" || print -r -- "./${1%.c}"; }
crun()   { _kit_cc "$CFLAGS_KIT" "${1-}" || return; local b=$(_kit_bin "$1"); shift; "$b" "$@"; }
csan()   { _kit_cc "$CFLAGS_SAN" "${1-}" || return; local b=$(_kit_bin "$1"); shift; "$b" "$@"; }
cmem()   { _kit_cc "$CFLAGS_KIT" "${1-}" || return; local b=$(_kit_bin "$1"); shift; valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes "$b" "$@"; }
cdebug() { _kit_cc "$CFLAGS_KIT" "${1-}" || return; local b=$(_kit_bin "$1"); shift; gdb -q --args "$b" "$@"; }

# ---- Perso puis thème ----
[[ -f "$HOME/.config/kit-etudiant/perso.zsh" ]] && source "$HOME/.config/kit-etudiant/perso.zsh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
ZSHRC
}
ecrire_bashrc_kit() {   # repli bash (SSH, scripts) : mêmes alias et commandes C
  cat >"$KIT/bashrc.sh" <<'BASHRC'
# kit-etudiant — repli bash (chargé depuis ~/.bashrc). Ton shell principal est zsh : tape « zsh ».
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
export CC=gcc
CFLAGS_KIT="-std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -g"
CFLAGS_SAN="$CFLAGS_KIT -O0 -fsanitize=address,undefined -fno-omit-frame-pointer"
LDLIBS_KIT="-lm"
# shellcheck disable=SC2086
_kit_cc() { [ -f "$2" ] || { echo "Usage : ${FUNCNAME[1]} fichier.c [arguments]" >&2; return 1; }; $CC $1 "$2" -o "${2%.c}" $LDLIBS_KIT; }
_kit_bin() { case $1 in /*) echo "${1%.c}" ;; *) echo "./${1%.c}" ;; esac; }
crun()   { _kit_cc "$CFLAGS_KIT" "${1-}" || return; local b; b=$(_kit_bin "$1"); shift; "$b" "$@"; }
csan()   { _kit_cc "$CFLAGS_SAN" "${1-}" || return; local b; b=$(_kit_bin "$1"); shift; "$b" "$@"; }
cmem()   { _kit_cc "$CFLAGS_KIT" "${1-}" || return; local b; b=$(_kit_bin "$1"); shift; valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes "$b" "$@"; }
cdebug() { _kit_cc "$CFLAGS_KIT" "${1-}" || return; local b; b=$(_kit_bin "$1"); shift; gdb -q --args "$b" "$@"; }
BASHRC
  bloc_fichier "$HOME/.bashrc" '[ -f "$HOME/.config/kit-etudiant/bashrc.sh" ] && . "$HOME/.config/kit-etudiant/bashrc.sh"'
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
  fi
}
ecrire_modeles() {
  local m="$KIT/modeles/projet-c"
  rm -rf "$KIT/modeles"; mkdir -p "$m/src" "$m/tests"
  cat >"$m/Makefile" <<'MAKE'
# Makefile — kit-etudiant
#   make          compiler (ASan + UBSan)     make run       compiler + lancer
#   make test     tests unitaires (Check)     make valgrind  fuites mémoire (sans ASan)
#   make analyse  gcc -fanalyzer              make check     cppcheck
#   make tidy     clang-tidy                  make format    clang-format
#   make compdb   compile_commands.json       make clean
CC      := gcc
CFLAGS  := -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -g -O0
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
  printf '#ifndef CALCUL_H\n#define CALCUL_H\n\nint somme(int a, int b);\n\n#endif\n' >"$m/src/calcul.h"
  printf '#include "calcul.h"\n\nint somme(int a, int b)\n{\n    return a + b;\n}\n' >"$m/src/calcul.c"
  printf '#include <stdio.h>\n#include <stdlib.h>\n#include "calcul.h"\n\nint main(void)\n{\n    printf("2 + 3 = %%d\\n", somme(2, 3));\n    return EXIT_SUCCESS;\n}\n' >"$m/src/main.c"
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
  printf -- '-std=c11\n-D_DEFAULT_SOURCE\n-Wall\n-Wextra\n-Isrc\n' >"$m/compile_flags.txt"
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
ecrire_aide() {
  cat >"$KIT/aide.md" <<'AIDE'
# Aide-mémoire kit-etudiant 2.0

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
| `doc-c` | doc C hors ligne (cppreference) |
| `lg` | lazygit |
| `p10k configure` | refaire le style du prompt |
| `gedit fichier` | éditeur graphique (xed sur Mint) |
| `kit-aide` | cette page |

## Compiler du C
| Commande | Effet |
|---|---|
| `crun prog.c [args]` | compiler (avertissements stricts) + lancer |
| `csan prog.c` | idem avec AddressSanitizer + UBSan |
| `cmem prog.c` | idem sous valgrind (fuites) |
| `cdebug prog.c` | compiler + ouvrir gdb (taper `dash` dedans) |
| `kit-projet tp1` | nouveau projet avec Makefile et tests |
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
`~/.config/kit-etudiant/perso.zsh` · `~/.config/nvim/lua/config/perso.lua` · `~/.config/nvim/lua/plugins/perso.lua` · `~/.tmux.perso.conf`
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
prechauffer_zsh() {   # 1er lancement : télécharge gitstatus (prompt git) et prépare la complétion
  [ -x "$BIN/zsh" ] || return 0
  TERM=xterm-256color timeout 120 "$BIN/zsh" -i -c 'exit' </dev/null
  noter "$HOME/.cache/gitstatus"
  local c; for c in "$HOME"/.cache/p10k-*; do [ -e "$c" ] && noter "$c"; done
  for c in "$HOME"/.zcompdump*; do [ -e "$c" ] && noter "$c"; done
  return 0
}
etape_config() {
  titre "Configuration : zsh, repli bash, gdb, git, modèles"
  if [ -f "$HOME/.zshrc" ] && ! head -1 "$HOME/.zshrc" | grep -q kit-etudiant && [ -f "$HOME/.zshrc.avant-kit" ]; then
    info "~/.zshrc personnel (sans marque kit) : laissé tel quel"
  else
    faire "~/.zshrc" ecrire_zshrc
  fi
  [ -f "$KIT/perso.zsh" ] || printf '# Tes alias et réglages zsh perso (jamais écrasé par le kit)\n' >"$KIT/perso.zsh"
  faire "plugins zsh (ta liste maison)" ecrire_plugins
  faire "repli bash (~/.bashrc)" ecrire_bashrc_kit
  faire "~/.gdbinit (commande « dash »)" ecrire_gdbinit
  faire "git (alias lg, delta)" config_git
  faire "modèle de projet C + commande kit-projet" ecrire_modeles
  faire "aide-mémoire (commande kit-aide)" ecrire_aide
  faire "premier démarrage de zsh (prompt git)" prechauffer_zsh
}

# ---- Doc C hors ligne ---------------------------------------------------------
installer_cppref() {
  local url f="$WORK/dl/cppref.tar.xz" c
  url=$(gh_asset PeterFeicht/cppreference-doc '^html-book-.*\.tar\.xz$') || return 1
  telecharger "$url" "$f" || return 1
  rm -rf "$OPT/cppreference"; mkdir -p "$OPT/cppreference"
  tar -xJf "$f" -C "$OPT/cppreference" || return 1
  rm -f "$f"; noter "$OPT/cppreference"
  c=$(find "$OPT/cppreference" -path '*/en/c.html' | head -1); [ -n "$c" ] || return 1
  printf '#!/usr/bin/env bash\n# doc-c : documentation C hors ligne (cppreference) dans le navigateur\nexec xdg-open "%s"\n' "$c" >"$BIN/doc-c"
  chmod +x "$BIN/doc-c"; noter "$BIN/doc-c"
}
etape_doc() {
  titre "Documentation C hors ligne"
  outil "doc C hors ligne (cppreference, commande doc-c)" "$OPT/cppreference" installer_cppref
  man -w 3 printf >/dev/null 2>&1 || info "pages man section 3 absentes sur ce PC : utilise doc-c"
}

# ---- Terminal : police, profil « Maison », Caps → Échap ---------------------
installer_meslo() {
  local d="$SHR/fonts/MesloLGS-NF" s
  mkdir -p "$d"
  for s in Regular Bold Italic "Bold Italic"; do
    telecharger "https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master/MesloLGS%20NF%20${s// /%20}.ttf" \
      "$d/MesloLGS-NF-${s// /-}.ttf" || return 1
  done
  noter "$d"
  command -v fc-cache >/dev/null && fc-cache -f "$SHR/fonts"
  return 0
}
profil_terminal() {   # profil GNOME Terminal « Maison » : couleurs Breeze (Konsole) + MesloLGS NF + zsh
  command -v gsettings >/dev/null || { RAISON="gsettings absent"; return 1; }
  gsettings list-schemas 2>/dev/null | grep -x org.gnome.Terminal.ProfilesList >/dev/null \
    || { RAISON="GNOME Terminal absent"; return 1; }
  local PL=org.gnome.Terminal.ProfilesList liste defaut uuid P
  liste=$(gsettings get "$PL" list) || return 1
  defaut=$(gsettings get "$PL" default | tr -d "'")
  if [ -f "$KIT/terminal-profil" ]; then
    uuid=$(sed -n 's/^uuid=//p' "$KIT/terminal-profil")
  else
    uuid=$(cat /proc/sys/kernel/random/uuid)
    printf 'uuid=%s\navant=%s\n' "$uuid" "$defaut" >"$KIT/terminal-profil"
  fi
  case "$liste" in
    *"$uuid"*) ;;
    "@as []"|"[]") gsettings set "$PL" list "['$uuid']" || return 1 ;;
    *) gsettings set "$PL" list "${liste%]}, '$uuid']" || return 1 ;;
  esac
  P="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"
  gsettings set "$P" visible-name 'Maison' &&
  gsettings set "$P" font "$POLICE" &&
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
marge_terminal() {   # marge intérieure comme Konsole (TerminalMargin), via le CSS de GTK
  mkdir -p "$HOME/.config/gtk-3.0"
  bloc_fichier "$HOME/.config/gtk-3.0/gtk.css" "VteTerminal, vte-terminal { padding: ${MARGE}px; }" '/*' '*/'
}
ecrire_caps() {
  mkdir -p "$HOME/.config/autostart"
  cat >"$HOME/.config/autostart/kit-caps-echap.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Caps Lock = Échap (kit)
Comment=Shift+Caps garde le verrouillage majuscules
Exec=setxkbmap -option caps:escape_shifted_capslock
X-GNOME-Autostart-Delay=5
EOF
  noter "$HOME/.config/autostart/kit-caps-echap.desktop"
}
etape_terminal() {
  titre "Terminal : police, couleurs Konsole, Caps → Échap"
  outil "police MesloLGS NF (celle de powerlevel10k)" "$SHR/fonts/MesloLGS-NF" installer_meslo
  if [ "$SANS_TERM" -eq 0 ]; then
    faire "profil GNOME Terminal « Maison » (Breeze + $POLICE + zsh)" profil_terminal
    faire "marge du texte comme Konsole (${MARGE} px)" marge_terminal
  else info "profil terminal sauté (--sans-terminal)"; fi
  faire "Caps Lock → Échap (prochaine session)" ecrire_caps
  amain "Fermer TOUS les terminaux puis en rouvrir un : profil « Maison », zsh, couleurs Konsole"
  amain "Premier lancement de nvim : laisser finir les téléchargements (1 à 2 minutes)"
  amain "Style du prompt : p10k configure (ou --p10k avec ton fichier de la maison)"
  amain "Aide-mémoire : kit-aide"
}

# ---- Presse-papier : CopyQ --------------------------------------------------
installer_copyq() {
  # Version figée : CopyQ 17 exige glibc 2.43 (trop récente pour Mint) ; la 16 demande glibc 2.38
  local url=https://github.com/hluk/CopyQ/releases/download/v16.0.0/CopyQ-16.0.0-x86_64.AppImage g
  g=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')
  if [ "$(printf '%s\n' "2.38" "$g" | sort -V | head -1)" != "2.38" ]; then
    RAISON="glibc $g trop ancienne (2.38 minimum) : utilise plutôt flatpak --user install flathub com.github.hluk.copyq"
    echo "$RAISON"; return 1
  fi
  appimage "$url" copyq copyq || return 1
  raccourci copyq "CopyQ (historique du presse-papier)" "$BIN/copyq" "$(icone_appimage copyq)" "Utility;"
  mkdir -p "$HOME/.config/autostart"
  cat >"$HOME/.config/autostart/kit-copyq.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CopyQ (kit)
Exec=$BIN/copyq
X-GNOME-Autostart-Delay=6
EOF
  noter "$HOME/.config/autostart/kit-copyq.desktop"
  if [ ! -f "$HOME/.config/copyq/copyq-commands.ini" ]; then   # Super+V : ouvrir l'historique
    mkdir -p "$HOME/.config/copyq"
    cat >"$HOME/.config/copyq/copyq-commands.ini" <<'EOF'
[Commands]
1\Command=copyq: toggle()
1\GlobalShortcut=meta+v
1\IsGlobalShortcut=true
1\Name=Afficher l'historique
size=1
EOF
    noter "$HOME/.config/copyq"
  fi
}
etape_presse_papier() {
  titre "Presse-papier : CopyQ"
  outil "CopyQ (historique du presse-papier, Super+V)" "$OPT/copyq" installer_copyq
  amain "CopyQ démarre à la prochaine session (ou lancer : copyq &). Super+V ouvre l'historique"
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
  if [ -f "$KIT/bashrc.sh" ] && grep -q 'ble.sh' "$KIT/bashrc.sh" 2>/dev/null; then
    echo "${J}Une installation version 1 est présente. Retire-la d'abord :${N}"
    echo "    bash $0 --desinstaller --tout"
    exit 1
  fi
  command -v unzip >/dev/null || command -v python3 >/dev/null || info "ni unzip ni python3 : les .zip échoueront"
  command -v gcc >/dev/null || info "gcc absent : les parseurs de coloration de Neovim ne pourront pas se compiler"
  printf '%skit-etudiant %s%s — journal : %s\n' "$B" "$KIT_VERSION" "$N" "$LOGF"
  printf '  glibc : %s   |   place libre dans ~ : %s\n' \
    "$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')" "$(df -h "$HOME" | awk 'NR==2{print $4}')"
  command -v quota >/dev/null && quota -s 2>/dev/null | tail -n +2 | sed 's/^/  quota : /'
  printf '  %sPlace nécessaire : environ 2,5 Go (dont ~0,8 Go pour Neovim et ses outils).%s\n' "$G" "$N"
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
  if [ ${#MAIN[@]} -gt 0 ]; then
    printf '%sÀ faire toi-même :%s\n' "$J" "$N"; printf '   - %s\n' "${MAIN[@]}"
  fi
  printf '%sPlace utilisée :%s ' "$G" "$N"
  du -shc "$PREFIX" "$HOME/.oh-my-zsh" "$MAMBA_ROOT" "$HOME/.fzf" "$NVIM_CFG" 2>/dev/null | tail -1 | cut -f1
  printf 'Journal complet : %s\n' "$LOGF"
}
retirer_profil_terminal() {
  [ -f "$KIT/terminal-profil" ] && command -v gsettings >/dev/null || return 0
  local PL=org.gnome.Terminal.ProfilesList uuid avant liste
  uuid=$(sed -n 's/^uuid=//p' "$KIT/terminal-profil"); avant=$(sed -n 's/^avant=//p' "$KIT/terminal-profil")
  [ -n "$uuid" ] || return 0
  liste=$(gsettings get "$PL" list 2>/dev/null) || return 0
  liste=$(printf '%s' "$liste" | sed "s/, '$uuid'//; s/'$uuid', //; s/'$uuid'//")
  case "$liste" in "[]"|"@as []") gsettings reset "$PL" list ;; *) gsettings set "$PL" list "$liste" ;; esac
  if [ -n "$avant" ]; then gsettings set "$PL" default "$avant"; else gsettings reset "$PL" default; fi
  command -v dconf >/dev/null && dconf reset -f "/org/gnome/terminal/legacy/profiles:/:$uuid/"
  echo "profil terminal « Maison » retiré"
}
reset_essais_terminal() {  # --tout : annule les réglages faits à la main pendant nos essais
  command -v gsettings >/dev/null || return 0
  local PL=org.gnome.Terminal.ProfilesList id P k
  id=$(gsettings get "$PL" default 2>/dev/null | tr -d "'"); [ -n "$id" ] || return 0
  P="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$id/"
  for k in palette use-theme-colors background-color foreground-color font use-system-font use-custom-command custom-command; do
    gsettings reset "$P" "$k" 2>/dev/null
  done
  gsettings reset org.cinnamon.desktop.default-applications.terminal exec 2>/dev/null
  echo "terminal par défaut remis à zéro"
}
desinstaller() {
  echo "Retire tout ce que kit-etudiant a créé (versions 1 et 2) et ses blocs dans tes fichiers de config."
  [ "$TOUT" -eq 1 ] && echo "Option --tout : tes fichiers perso et les réglages d'essai du terminal partent aussi."
  if [ -t 0 ]; then read -rp "Continuer ? [o/N] " r; [ "$r" = o ] || [ "$r" = O ] || exit 0; fi
  mkdir -p "$WORK"
  local p f
  [ -x "$BIN/uv" ] && "$BIN/uv" cache clean >/dev/null 2>&1
  # 1. blocs de config, fichiers créés de zéro, réglages git
  for f in .bashrc .profile .inputrc .gdbinit; do
    retirer_bloc "$HOME/$f"; rm -f "$HOME/$f.avant-kit"
  done
  retirer_bloc "$HOME/.config/gtk-3.0/gtk.css" '/*' '*/'; rm -f "$HOME/.config/gtk-3.0/gtk.css.avant-kit"
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
  for f in .vimrc .tmux.conf .zshrc; do
    if [ -f "$HOME/$f.avant-kit" ]; then mv -f "$HOME/$f.avant-kit" "$HOME/$f"
    elif [ -f "$HOME/$f" ] && head -1 "$HOME/$f" | grep -q kit-etudiant; then rm -f "$HOME/$f"; fi
  done
  # 2. config Neovim : jamais supprimée sans --tout (elle peut contenir ton travail)
  if [ -f "$NVIM_CFG/.kit-etudiant" ]; then
    if [ "$TOUT" -eq 1 ]; then rm -rf "$NVIM_CFG"
    else mv "$NVIM_CFG" "$NVIM_CFG.kit-sauvegarde-$(date +%Y%m%d-%H%M)"; echo "config Neovim mise de côté : $NVIM_CFG.kit-sauvegarde-*"; fi
    [ -d "$NVIM_CFG.avant-kit" ] && mv "$NVIM_CFG.avant-kit" "$NVIM_CFG"
  fi
  # 3. terminal
  retirer_profil_terminal
  [ -f "$KIT/terminal-avant.sh" ] && bash "$KIT/terminal-avant.sh" 2>/dev/null
  [ "$TOUT" -eq 1 ] && reset_essais_terminal
  # 4. fichiers et dossiers installés
  if [ -f "$MANIF" ]; then
    grep -vE '^(cree|git):' "$MANIF" | sort -u | while IFS= read -r p; do
      case "$p" in
        ""|"$HOME"|"$HOME/"|"$PREFIX"|"$BIN"|"$OPT"|"$SHR"|"$HOME/.config"|"$HOME/.cache"|"$NVIM_CFG") continue ;;
        "$HOME"/*) rm -rf -- "$p" ;;
      esac
    done
  fi
  # 5. caches des outils, plugins tmux, dossiers vides
  rm -rf "$HOME/.tmux/plugins" "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup" \
         "$HOME/.cache/tealdeer" "$HOME/.cache/starship" "$HOME/.cache/glow" "$HOME/.cache/blesh" \
         "$HOME/.local/state/blesh" "$HOME/.local/state/gh" "$HOME/.config/glow" "$HOME"/.cache/.pwntools-cache-* \
         "$HOME/.cache/tree-sitter" "$HOME/.cache/thefuck" "$HOME/.config/thefuck"
  # 6. --tout : fichiers perso et restes de nos essais
  if [ "$TOUT" -eq 1 ]; then
    rm -rf "$KIT/perso.sh" "$KIT/perso.zsh" "$HOME/.vim/perso.vim" "$HOME/.vim/vsnip" "$HOME/.tmux.perso.conf" \
           "$HOME/.config/kitty" "$HOME/.local/kitty.app" "$HOME/.local/bin/kitty" "$HOME/.local/bin/kitten" \
           "$HOME/.config/starship.toml" "$HOME/.config/starship-simple.toml" "$HOME/.p10k.zsh" \
           "$HOME"/.local/share/applications/kitty*.desktop
  fi
  find "$PREFIX" "$HOME/.vim" "$HOME/.tmux" "$HOME/.config/rclone" "$HOME/.config/autostart" "$HOME/.config/kitty" "$HOME/.config/gtk-3.0" \
       -depth -type d -empty -delete 2>/dev/null
  if [ -d "$KIT" ]; then
    if [ "$TOUT" -eq 1 ]; then rm -rf "$KIT"
    else find "$KIT" -mindepth 1 -maxdepth 1 ! -name perso.sh ! -name perso.zsh -exec rm -rf {} + 2>/dev/null; fi
  fi
  rm -rf "$WORK"
  echo "Terminé. Ferme tous les terminaux et ouvre-en un nouveau."
  [ "$TOUT" -eq 0 ] && echo "Gardés pour toi : ~/.config/kit-etudiant/perso.zsh, ~/.tmux.perso.conf, ta config Neovim (~/.config/nvim.kit-sauvegarde-*), ton ~/.p10k.zsh"
  return 0
}
aide() { awk 'NR>2 && /^[^#]/{exit} NR>2{sub(/^# ?/,""); print}' "$0"; }

# Permet de charger les fonctions sans rien lancer (tests)
[ "${KIT_SOURCE_ONLY:-0}" = 1 ] && return 0 2>/dev/null

# =============================================================================
#  PROGRAMME PRINCIPAL
# =============================================================================
while [ $# -gt 0 ]; do
  case "$1" in
    --maj) MAJ=1 ;;
    --sans-conda) SANS_CONDA=1 ;;
    --sans-terminal) SANS_TERM=1 ;;
    --maison) shift; MAISON=${1:-} ;;
    --maison=*) MAISON=${1#*=} ;;
    --p10k) shift; P10K_SRC=${1:-} ;;
    --p10k=*) P10K_SRC=${1#*=} ;;
    --seulement) shift; SEULEMENT=${1:-} ;;
    --seulement=*) SEULEMENT=${1#*=} ;;
    --liste) for e in "${ETAPES[@]}"; do printf '  %-13s %s\n' "$e" "${DESC[$e]}"; done; exit 0 ;;
    --desinstaller) MODE=desinstaller ;;
    --tout) TOUT=1 ;;
    -h|--aide|--help) aide; exit 0 ;;
    *) echo "option inconnue : $1 (voir --aide)"; exit 1 ;;
  esac
  shift
done

if [ "$MODE" = desinstaller ]; then desinstaller; exit 0; fi
if [ -n "$MAISON" ]; then
  [ -e "$MAISON" ] || { echo "introuvable : $MAISON"; exit 1; }
  MAISON_DIR="$WORK/maison"; rm -rf "$MAISON_DIR"; mkdir -p "$MAISON_DIR"
  if [ -d "$MAISON" ]; then cp -r "$MAISON"/. "$MAISON_DIR"/
  else tar -xzf "$MAISON" -C "$MAISON_DIR" || { echo "archive illisible : $MAISON"; exit 1; }; fi
  [ -d "$MAISON_DIR/kit-maison" ] && MAISON_DIR="$MAISON_DIR/kit-maison"
  [ -z "$P10K_SRC" ] && [ -f "$MAISON_DIR/zsh/p10k.zsh" ] && P10K_SRC="$MAISON_DIR/zsh/p10k.zsh"
  profil=$(find "$MAISON_DIR/konsole" -name '*.profile' 2>/dev/null | head -1)
  if [ -n "$profil" ]; then
    f=$(sed -n 's/^Font=//p' "$profil" | head -1)
    [ -n "$f" ] && POLICE="$(cut -d, -f1 <<<"$f") $(cut -d, -f2 <<<"$f")"
    m=$(sed -n 's/^TerminalMargin=//p' "$profil" | head -1); [ -n "$m" ] && MARGE=$m
  fi
fi
if [ -n "$P10K_SRC" ] && [ ! -f "$P10K_SRC" ]; then echo "fichier introuvable : $P10K_SRC"; exit 1; fi
[ -n "$P10K_SRC" ] && P10K_SRC=$(readlink -f "$P10K_SRC")

preflight
for e in "${ETAPES[@]}"; do
  if [ -n "$SEULEMENT" ] && [[ ",$SEULEMENT," != *",$e,"* ]]; then continue; fi
  [ "$e" = conda ] && [ "$SANS_CONDA" -eq 1 ] && { info "étape conda sautée (--sans-conda)"; continue; }
  "etape_$e"
done
rm -rf "$WORK/dl" "$WORK/x"
rapport
[ ${#KOS[@]} -eq 0 ]
