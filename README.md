# kit-etudiant

Boîte à outils **C, Bash et Vim** pour Linux Mint, installée **sans droits administrateur**.

Un seul script installe un environnement de travail complet dans ton dossier personnel : éditeur configuré, complétion intelligente, débogueur lisible, analyse statique, tests unitaires, prompt avec infos git, thème cohérent. Aucun `sudo`, aucun fichier système modifié.

```bash
bash kit-etudiant.sh --sans-lourd --sans-cyber
```

---

## Sommaire

- [Principe](#principe)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Options](#options)
- [Ce qui est installé](#ce-qui-est-installé)
- [Après l'installation](#après-linstallation)
- [Au quotidien](#au-quotidien)
- [Thème](#thème)
- [Personnaliser](#personnaliser)
- [Mettre à jour, désinstaller](#mettre-à-jour-désinstaller)
- [Où vont les fichiers](#où-vont-les-fichiers)
- [Dépannage](#dépannage)
- [État des tests](#état-des-tests)
- [Projets utilisés](#projets-utilisés)

---

## Principe

| | |
|---|---|
| **Sans root** | Tout va dans `$HOME`. Le script refuse de tourner en root et ne peut pas appeler `sudo`. |
| **Relançable** | Ce qui est déjà installé est sauté. Relancer ne réessaie que ce qui a échoué (quelques secondes). |
| **Réversible** | `--desinstaller` retire tout ce que le script a créé et remet tes fichiers de config d'origine. |
| **Transparent** | Chaque fichier créé est noté dans un manifeste. Journal complet de chaque installation. |
| **Sans limite GitHub** | Les téléchargements ne passent pas par l'API GitHub, donc pas de blocage sur un réseau partagé. |

---

## Prérequis

| Élément | Détail |
|---|---|
| Système | Linux x86_64 (testé pour Linux Mint 21 / 22, base Ubuntu) |
| Commandes | `bash`, `curl`, `tar`, `gzip`, `xz`, `git`, `find`, `awk`, `sed` |
| Recommandé | `unzip` (sinon `python3` prend le relais) |
| glibc | 2.34 ou plus pour l'AppImage Vim (Mint 21 et 22 conviennent) |
| Place disque | environ **2,5 Go** avec `--sans-lourd`, environ **5 Go** en complet |
| Home | ne doit pas être monté `noexec` (le script le vérifie) |

Vérifier sa place avant de lancer :

```bash
quota -s     # sur un home réseau
df -h ~
```

---

## Installation

```bash
git clone https://github.com/TON_PSEUDO/kit-etudiant.git
cd kit-etudiant
bash kit-etudiant.sh --sans-lourd --sans-cyber
```

Ou directement :

```bash
curl -fsSLO https://raw.githubusercontent.com/TON_PSEUDO/kit-etudiant/main/kit-etudiant.sh
bash kit-etudiant.sh --sans-lourd --sans-cyber
```

À la fin, un **bilan** affiche ce qui a réussi, ce qui a échoué (avec la raison) et ce qu'il reste à faire à la main.

---

## Options

| Option | Effet |
|---|---|
| *(aucune)* | installe tout |
| `--sans-lourd` | saute pwndbg, ImHex, Ghidra et Java (économise environ 2,5 Go) |
| `--sans-cyber` | saute pwntools et CyberChef |
| `--sans-gui` | saute tout le graphique (police, kitty, espanso, applications, Ghidra) |
| `--sans-conda` | saute micromamba (valgrind, gdb, cppcheck, bear, ctags, tmux, Check, Node) |
| `--seulement A,B` | ne lance que les étapes citées |
| `--maj` | réinstalle et met à jour même ce qui existe déjà |
| `--liste` | affiche les étapes |
| `--desinstaller` | retire tout (voir plus bas) |
| `--aide` | aide |

### Étapes

| Étape | Contenu |
|---|---|
| `prepa` | dossiers, vérifications (noexec, glibc, place), PATH |
| `cli` | outils en ligne de commande (rg, fd, bat, eza, delta, lazygit…) |
| `shell` | ble.sh, fzf, zoxide, starship, bash-completion |
| `outils_shell` | shellcheck, shfmt, bats-core |
| `outils_c` | clangd, pwndbg, gdb-dashboard |
| `python` | uv, pwntools, trash-cli, clang-format, clang-tidy |
| `conda` | micromamba, valgrind, gdb, cppcheck, bear, ctags, tmux, Check, Node, bash-language-server |
| `vim` | Vim 9 si besoin, vim-plug, vimrc, snippets, 20 plugins |
| `tmux` | tmux.conf, tpm, tmux-sensible, tmux-resurrect |
| `config` | bashrc, inputrc, gdbinit, git + delta, thème du prompt, modèle de projet C |
| `doc` | documentation C hors ligne, aide-mémoire |
| `bureau` | police Nerd Font, kitty, espanso, Caps Lock → Échap, actions Nemo |
| `applis` | KeePassXC, Flameshot, ImHex, CyberChef, CopyQ |
| `ghidra` | Java 21 et Ghidra |

Exemple pour ajouter une seule étape plus tard :

```bash
bash kit-etudiant.sh --seulement ghidra
```

---

## Ce qui est installé

Classé du plus utile au moins utile pour du C et du Bash.

### Indispensable

| Outil | Rôle |
|---|---|
| Vim 9 + configuration | éditeur (AppImage officielle si le Vim du système est absent, « tiny » ou trop ancien) |
| ALE | erreurs gcc et shellcheck pendant la frappe, complétion, formatage |
| clangd | complétion C, aller à la définition |
| Makefile modèle + `kit-projet` | compiler, tester, analyser en une commande |
| valgrind | fuites mémoire |
| gdb + gdb-dashboard | débogage avec panneaux source, variables, pile |
| shellcheck | bugs dans les scripts bash |
| ble.sh | suggestions grises et coloration pendant la frappe |
| fzf | recherche floue dans l'historique, les fichiers, les dossiers |
| bash-completion | Tab connaît les options de git, gcc, make… |
| Caps Lock → Échap | confort dans Vim (Shift + Caps garde les majuscules) |
| Snippets C et Bash | squelettes `malloc`, `fork`, `pipe`, `fopen`, script bash… |
| tldr | exemples courts de commandes, en français, hors ligne |
| Doc C hors ligne | cppreference dans le navigateur, sans internet |

### Très utile

| Outil | Rôle |
|---|---|
| starship + Nerd Font | prompt avec branche git, fichiers modifiés, code d'erreur, durée |
| bat | `cat` avec tableau, numéros de ligne et couleurs |
| ripgrep, fd | chercher du texte, trouver un fichier |
| zoxide | `z tp1` saute directement à un dossier connu |
| tmux | écran découpé, session qui survit à une coupure SSH |
| delta, lazygit | diffs git lisibles, git avec des menus |
| clang-format, shfmt | formatage du C et du Bash |
| cppcheck, clang-tidy | analyse statique |
| Check, bats | tests unitaires C (chaque test isolé) et Bash |
| watchexec | recompile à chaque sauvegarde |
| trash-cli | corbeille en ligne de commande |
| chezmoi | sauvegarde de la configuration sur git |
| gdu, duf | voir ce qui remplit le disque ou le quota |

### Plugins Vim

| Plugin | Rôle |
|---|---|
| NERDTree | arbre de fichiers |
| fzf.vim | recherche de fichiers, de texte, de buffers |
| vim-fugitive, vim-gitgutter | git dans Vim, lignes modifiées dans la marge |
| undotree | historique des annulations en arbre |
| vim-commentary, vim-surround, auto-pairs, targets.vim | édition rapide |
| vim-sneak | saut rapide avec deux lettres |
| vim-vsnip + friendly-snippets | snippets |
| tagbar | plan du fichier |
| vim-which-key | rappel des raccourcis |
| lightline, vim-polyglot, vim-sensible, vim-repeat, vim-unimpaired | barre d'état, coloration, réglages, confort |

### Utile parfois

| Outil | Rôle |
|---|---|
| kitty | terminal rapide, thèmes faciles |
| eza, yazi | liste de fichiers jolie, explorateur dans le terminal |
| gh, glow | GitHub en ligne de commande, lecture de Markdown |
| btop, jq, sd, hyperfine, direnv | processus, JSON, remplacement de texte, mesure de vitesse, variables par dossier |
| bear, ctags | `compile_commands.json` pour clangd, index des symboles |
| bash-language-server | complétion Bash dans Vim |
| espanso | raccourcis texte dans toutes les applications (X11) |
| KeePassXC, Flameshot | mots de passe, captures annotées |
| rclone, croc | transfert de fichiers entre machines |
| exercism | exercices C et Bash corrigés |

### Optionnel (cyber, gros volume)

| Outil | Rôle | Option pour l'éviter |
|---|---|---|
| pwndbg | gdb orienté exploitation (~0,7 Go) | `--sans-lourd` |
| ImHex | éditeur hexadécimal (~0,6 Go) | `--sans-lourd` |
| Ghidra + Java 21 | rétro-ingénierie (~1,2 Go) | `--sans-lourd` |
| pwntools, CyberChef | exploits Python, encodage et crypto | `--sans-cyber` |

---

## Après l'installation

1. Ouvrir un **nouveau terminal**.
2. Lire l'aide-mémoire : `kit-aide`.
3. Vérifier l'essentiel :
   ```bash
   kit-projet tp1 && cd tp1
   make run && make test && make valgrind
   ```
4. Fermer la session et la rouvrir (Caps Lock → Échap, espanso).
5. Si le prompt affiche des carrés : choisir la police **JetBrainsMono Nerd Font Mono** dans les préférences du terminal.

---

## Au quotidien

### Terminal

| Commande | Effet |
|---|---|
| `Ctrl-R` / `Ctrl-T` / `Alt-C` | historique / fichier / dossier (fzf) |
| flèche droite | accepter la suggestion grise |
| `z dossier` | sauter à un dossier déjà visité |
| `..` ou un nom de dossier seul | y entrer |
| `tldr tar` | exemples courts |
| `ll`, `lt` | liste détaillée, arbre |
| `cat fichier` | affichage avec numéros (bat) |
| `tp fichier` | corbeille |
| `mkcd dossier` | créer et entrer |
| `commande ; alert` | notification à la fin |
| `gccd prog.c` | compiler avec avertissements et AddressSanitizer |
| `gcca prog.c` | analyse statique gcc (`-fanalyzer`) |
| `lg`, `git lg` | lazygit, historique en graphe |
| `doc-c` | documentation C hors ligne |
| `kit-aide` | aide-mémoire complet |

### Projet C

```bash
kit-projet tp1 && cd tp1
```

| Commande | Effet |
|---|---|
| `make run` | compiler (ASan + UBSan) et lancer |
| `make test` | tests unitaires Check |
| `make valgrind` | fuites mémoire (recompile sans ASan) |
| `make analyse` | `gcc -fanalyzer` |
| `make check` / `make tidy` | cppcheck / clang-tidy |
| `make format` | clang-format |
| `make compdb` | `compile_commands.json` via bear |
| `watchexec -e c,h -- make run` | recompiler à chaque sauvegarde |

### Vim (leader = Espace)

| Touche | Effet |
|---|---|
| `F5` | compiler et lancer le fichier courant (C ou Bash) |
| `F6` | `make` + liste des erreurs |
| `gd` / `gr` | définition / références |
| `]g` `[g` | erreur suivante / précédente |
| `Espace h` / `Espace rn` / `Espace f` | documentation / renommer / formater |
| `Ctrl-N` / `Ctrl-P` | arbre de fichiers / chercher un fichier |
| `Espace g` / `Espace b` | chercher du texte / buffers |
| `Espace u` / `Espace t` / `Espace T` | annulations / plan / terminal |
| `Ctrl-J` puis `Ctrl-L` | déplier un snippet, champ suivant |
| `3K` sur une fonction | page `man 3` |
| `:Termdebug ./prog` | gdb dans Vim |
| `Espace` (attendre) | liste des raccourcis |

Snippets fournis : `mainargs`, `mallocv`, `fopenv`, `forkw`, `pipef` (C) et `bashs`, `whileread`, `getopts` (Bash).

### gdb

Taper `dash` dans gdb pour afficher le tableau de bord (source, variables, pile, registres).

---

## Thème

Palette **gruvbox** partout :

| Élément | Réglage |
|---|---|
| Prompt | preset starship `gruvbox-rainbow` |
| kitty | thème `gruvbox-dark` + police Nerd Font |
| Terminal Mint | police Nerd Font réglée automatiquement si possible |
| Vim | `retrobox` (gruvbox intégré à Vim 9.1) + lightline `deus` |
| bat, delta | `gruvbox-dark` |

Exemple de prompt dans un dépôt git :

```
 etudiant  …/tp1   main ?   10:42
```

Changer de style :

```bash
starship preset --list
starship preset tokyo-night -o ~/.config/starship.toml
kitten themes              # dans kitty, choix interactif
```

Ta config starship ou kitty existante n'est jamais écrasée.

---

## Personnaliser

Ces fichiers sont à toi. Le script ne les écrase jamais, même avec `--maj`, et la désinstallation les garde.

| Fichier | Pour |
|---|---|
| `~/.config/kit-etudiant/perso.sh` | tes alias et variables Bash |
| `~/.vim/perso.vim` | tes réglages Vim (thème, raccourcis) |
| `~/.vim/vsnip/` | tes snippets |
| `~/.tmux.perso.conf` | tes réglages tmux |
| `~/.config/kitty/kitty-perso.conf` | tes réglages kitty |

Exemple dans `perso.sh` :

```bash
alias gs='git status -sb'
alias vg='valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes'
export BAT_THEME="Nord"
```

Puis `source ~/.bashrc`.

Pour retrouver cette configuration sur une autre machine :

```bash
chezmoi add ~/.config/kit-etudiant/perso.sh ~/.vim/perso.vim
```

---

## Mettre à jour, désinstaller

```bash
bash kit-etudiant.sh --maj --sans-lourd --sans-cyber    # tout mettre à jour
bash kit-etudiant.sh --desinstaller                      # tout retirer
```

La désinstallation :

- supprime tout ce qui figure dans le manifeste ;
- retire les blocs ajoutés dans `.bashrc`, `.profile`, `.inputrc`, `.gdbinit` ;
- remet ton ancien `.vimrc` et `.tmux.conf` s'il y en avait ;
- annule uniquement les réglages git qu'elle a ajoutés ;
- remet la police d'origine du terminal Mint ;
- **garde** tes fichiers perso et tes snippets.

---

## Où vont les fichiers

```
~/.local/bin/                 commandes (liens et lanceurs)
~/.local/opt/                 programmes complets (clangd, Vim, cppreference…)
~/.local/share/               ble.sh, police, uv, raccourcis du menu, actions Nemo
~/.config/kit-etudiant/
    bashrc.sh                 config Bash du kit (réécrite à chaque passage)
    perso.sh                  TES réglages (jamais touché)
    aide.md                   aide-mémoire
    modeles/projet-c/         modèle utilisé par kit-projet
    manifeste                 liste de tout ce qui a été créé
~/.vimrc  ~/.vim/             config et plugins Vim
~/.tmux.conf  ~/.tmux/        config et plugins tmux
~/micromamba/                 environnement « outils » (valgrind, gdb, tmux…)
~/.cache/kit-etudiant/        journaux d'installation
```

Les fichiers modifiés sont sauvegardés une fois sous `*.avant-kit` (exemple : `~/.bashrc.avant-kit`).

---

## Dépannage

| Problème | Solution |
|---|---|
| « home monté noexec » | aucun programme ne peut s'exécuter depuis le home : contacter le service informatique |
| Quota plein | relancer avec `--sans-lourd`, regarder avec `gdu ~`, vider avec `micromamba clean -a` |
| Une ligne ✘ dans le bilan | lire le journal indiqué, puis relancer le script (il ne refait que ce qui manque) |
| « le système n'a pas : libX.so » | application graphique impossible sans cette bibliothèque système : demander au service informatique, ou ignorer |
| Échecs de téléchargement | vérifier le proxy (`env \| grep -i proxy`), relancer |
| Carrés à la place des icônes | police **JetBrainsMono Nerd Font Mono** dans le terminal |
| Plugins Vim manquants | `vim +PlugInstall +qa` |
| `man 3 printf` introuvable | utiliser `doc-c` et `tldr` |
| Revenir à l'état d'origine | `bash kit-etudiant.sh --desinstaller` |

---

## État des tests

Testé le 5 octobre 2026 sur Ubuntu 24.04 (glibc 2.39) avec un **utilisateur sans aucun droit** et de faux `sudo`, `su`, `pkexec` qui enregistrent toute tentative.

| Vérification | Résultat |
|---|---|
| Tentatives d'élévation de droits | 0 |
| Écritures hors du home | aucune (hors fichiers temporaires dans `/tmp`) |
| Installation `--sans-lourd --sans-cyber` | 63 réussis, 1,7 Go sans micromamba |
| Programmes installés | tous démarrent |
| Vim + 20 plugins | chargés sans erreur |
| Projet modèle | `make run`, `test`, `valgrind`, `analyse`, `tidy`, `format` fonctionnent |
| Relance | 4 secondes, aucun doublon dans les fichiers de config |
| Désinstallation | `.bashrc` et `.profile` identiques à l'original, fichiers perso conservés |

**Pas encore testé** : la partie micromamba (réseau bloqué pendant les tests), le réglage automatique de la police du terminal Mint, le lancement des applications graphiques.

---

## Projets utilisés

Le script ne fait que télécharger les versions officielles de ces projets depuis leurs dépôts :

[Vim](https://github.com/vim/vim-appimage) ·
[vim-plug](https://github.com/junegunn/vim-plug) ·
[ALE](https://github.com/dense-analysis/ale) ·
[clangd](https://github.com/clangd/clangd) ·
[ble.sh](https://github.com/akinomyoga/ble.sh) ·
[fzf](https://github.com/junegunn/fzf) ·
[starship](https://github.com/starship/starship) ·
[zoxide](https://github.com/ajeetdsouza/zoxide) ·
[bat](https://github.com/sharkdp/bat) ·
[fd](https://github.com/sharkdp/fd) ·
[ripgrep](https://github.com/BurntSushi/ripgrep) ·
[delta](https://github.com/dandavison/delta) ·
[lazygit](https://github.com/jesseduffield/lazygit) ·
[shellcheck](https://github.com/koalaman/shellcheck) ·
[shfmt](https://github.com/mvdan/sh) ·
[bats-core](https://github.com/bats-core/bats-core) ·
[gdb-dashboard](https://github.com/cyrus-and/gdb-dashboard) ·
[uv](https://github.com/astral-sh/uv) ·
[micromamba](https://github.com/mamba-org/micromamba-releases) ·
[tealdeer](https://github.com/tealdeer-rs/tealdeer) ·
[cppreference-doc](https://github.com/PeterFeicht/cppreference-doc) ·
[kitty](https://github.com/kovidgoyal/kitty) ·
[Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) ·
[tmux plugins](https://github.com/tmux-plugins)

Chacun reste sous sa propre licence.
