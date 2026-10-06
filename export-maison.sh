#!/usr/bin/env bash
# export-maison.sh — À LANCER SUR TON PC MAISON. Lecture seule.
# Rassemble ta config de thème (zsh, powerlevel10k, Konsole, Neovim) dans ~/kit-maison.tar.gz,
# à utiliser ensuite sur le PC de la fac :  bash kit-etudiant.sh --maison kit-maison.tar.gz
set -u
D=~/kit-maison; rm -rf "$D"; mkdir -p "$D"/{zsh,konsole,nvim}
masque() { sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}/<email>/g'; }
for f in .zshrc .zsh-plugins .p10k.zsh; do [ -f ~/$f ] && masque < ~/$f > "$D/zsh/${f#.}"; done
ls ~/.oh-my-zsh/custom/plugins ~/.oh-my-zsh/custom/themes > "$D/zsh/custom.txt" 2>/dev/null
cp ~/.config/konsolerc "$D/konsole/" 2>/dev/null
cp ~/.local/share/konsole/*.profile ~/.local/share/konsole/*.colorscheme "$D/konsole/" 2>/dev/null
prof=$(sed -n 's/^DefaultProfile=//p' ~/.config/konsolerc 2>/dev/null)
cs=$(sed -n 's/^ColorScheme=//p' ~/.local/share/konsole/"$prof" 2>/dev/null); cs=${cs:-Breeze}
for d in ~/.local/share/konsole /usr/share/konsole; do
  [ -f "$d/$cs.colorscheme" ] && { cp "$d/$cs.colorscheme" "$D/konsole/actif-$cs.colorscheme"; break; }
done
echo "Schéma de couleurs actif : $cs" > "$D/konsole/actif.txt"
cp ~/.config/nvim/lazyvim.json "$D/nvim/" 2>/dev/null
cp -r ~/.config/nvim/lua "$D/nvim/" 2>/dev/null
tar -czf ~/kit-maison.tar.gz -C ~ kit-maison
echo "Fichiers rassemblés :"; find "$D" -type f | sed "s|$HOME/||"
echo "Archive : ~/kit-maison.tar.gz"
