# kit-etudiant 2.5

Ton environnement **C et Bash** de la maison, sur un Linux Mint de fac, **sans droits administrateur**.

zsh + oh-my-zsh + ton prompt powerlevel10k, Neovim + LazyVim (erreurs en direct, complétion, débogueur), GNOME Terminal aux couleurs de Konsole, historique du presse-papier, et tous les outils pour compiler, déboguer et tester. Aucun `sudo`, aucun fichier système modifié.

```bash
bash kit-etudiant.sh --maison ~/kit-maison.tar.gz
```

---

## Sommaire

- [Principe](#principe)
- [Installation](#installation)
- [Options](#options)
- [Ce qui est installé](#ce-qui-est-installé)
- [Les 10 réflexes](#les-10-réflexes)
- [Astuces zsh](#astuces-zsh)
- [Astuces Neovim](#astuces-neovim)
- [Compiler, tester, déboguer du C](#compiler-tester-déboguer-du-c)
- [Copier, coller, historique](#copier-coller-historique)
- [Personnaliser](#personnaliser)
- [Mettre à jour, désinstaller](#mettre-à-jour-désinstaller)
- [Dépannage](#dépannage)
- [Outils annexes](#outils-annexes)
- [Versions](#versions)
- [État des tests](#état-des-tests)

---

## Principe

| | |
|---|---|
| **Sans root** | Tout va dans `$HOME`. Le script refuse de tourner en root et ne peut pas appeler `sudo`. |
| **Relançable** | Ce qui est déjà installé est sauté. Relancer ne refait que ce qui a échoué. |
| **Réversible** | `--desinstaller` retire tout et remet tes fichiers de config d'origine. |
| **Stable** | Pas de mise à jour automatique d'oh-my-zsh, outils Mason figés. Rien ne change la veille d'un examen. |
| **Réseau partagé** | Aucun appel à l'API GitHub : pas de blocage quand toute une salle installe en même temps. |
| **Vérifié** | Après installation, chaque règle de coloration de Neovim est testée ; un problème apparaît dans le bilan, pas dans ton éditeur. |

---

## Installation

**1. Sur ton PC maison** (lecture seule, rien n'est modifié) :

```bash
bash export-maison.sh        # crée ~/kit-maison.tar.gz : prompt, plugins, police, couleurs Konsole
```

**2. Sur le PC de la fac**, copier `kit-maison.tar.gz` (clé USB, mail, git…), vérifier la place (`quota -s`, environ **2,5 Go**), puis :

```bash
git clone https://github.com/TON_PSEUDO/kit-etudiant.git
cd kit-etudiant
bash kit-etudiant.sh --maison ~/kit-maison.tar.gz
```

Compter 5 à 10 minutes. À la fin, un **bilan** liste ce qui a réussi, ce qui a échoué et ce qu'il reste à faire.

**3. Fermer tous les terminaux** et en rouvrir un (profil « Maison », zsh). **Fermer puis rouvrir la session Mint** pour Caps Lock → Échap et CopyQ.

Sans `--maison`, le kit utilise ta liste de plugins connue, MesloLGS NF 15, les couleurs Breeze, et le prompt style « rainbow » (`p10k configure` pour le refaire).

### Venir de la version 1

```bash
bash kit-etudiant.sh --desinstaller --tout
bash kit-etudiant.sh --maison ~/kit-maison.tar.gz
```

Si tu oublies, le script détecte la version 1 et s'arrête en affichant la commande à lancer.

---

## Options

| Option | Effet |
|---|---|
| `--maison ARCHIVE` | reprendre ta config maison (archive de `export-maison.sh`) |
| `--p10k FICHIER` | reprendre seulement ton prompt powerlevel10k |
| `--maj` | tout mettre à jour (plugins, outils, registre Mason) |
| `--sans-conda` | sauter micromamba (valgrind, gdb, cppcheck, bear, tmux, Check, Node, xclip) |
| `--sans-terminal` | ne pas créer le profil GNOME Terminal « Maison » |
| `--seulement A,B` | ne lancer que ces étapes (`--liste` pour les voir) |
| `--desinstaller` | tout retirer, en gardant tes fichiers perso |
| `--desinstaller --tout` | tout retirer, y compris tes fichiers perso |

---

## Ce qui est installé

### Shell et terminal

| Outil | Rôle |
|---|---|
| zsh (zsh-bin) | shell, version statique installable sans root |
| oh-my-zsh + **ton `.p10k.zsh`** | ton prompt : dossier, git, statut, durée, heure |
| Profil GNOME Terminal « Maison » | couleurs Breeze de Konsole, MesloLGS NF 15, marge 5 px, ouvre zsh |
| Caps Lock → Échap | confort dans Neovim (Shift + Caps garde les majuscules) |
| fzf | recherche floue (Ctrl-R, Ctrl-T, Alt-C, `**` + Tab) |

### Tes 17 plugins oh-my-zsh

| Plugin | Ce qu'il apporte |
|---|---|
| zsh-autosuggestions | suggestion grise d'après l'historique, flèche droite pour accepter |
| zsh-syntax-highlighting | commande verte si elle existe, rouge sinon |
| you-should-use | te rappelle l'alias quand tu tapes la commande longue |
| git | alias git (voir plus bas) |
| autojump → **zoxide** | autojump demande root ; `j dossier` et `z dossier` marchent |
| fancy-ctrl-z | Ctrl-Z sur une ligne vide : revenir au programme mis en pause |
| command-not-found | commande inconnue → indique le paquet (pour info : pas de sudo) |
| colored-man-pages | `man` en couleurs |
| common-aliases | `l`, `la`, `ll`, alias globaux `G`, `H`, `L`, `T` ; `rm`, `cp`, `mv` demandent confirmation |
| copybuffer | Ctrl-O : copier la ligne en cours de frappe |
| copyfile | `copyfile f` : copier le contenu d'un fichier |
| dirhistory | Alt-← / Alt-→ : dossier précédent / suivant ; Alt-↑ : parent |
| history | `h`, `hs mot`, `hsi mot` |
| web-search | `google mot`, `ddg mot`, `stackoverflow mot` |
| sudo | Échap Échap ajoute `sudo` devant (inutile à la fac) |
| zsh-bat | `cat` coloré avec numéros de ligne |
| thefuck | `fuck` corrige la dernière commande (installé avec Python 3.11, seul compatible) |

### Neovim + LazyVim

| Élément | Rôle |
|---|---|
| LazyVim, thème tokyonight, numéros classiques | ta config maison |
| Ligne de commande classique | `:` et les messages en bas de l'écran, comme Vim : toujours visibles |
| clangd | erreurs C en direct, complétion, aller à la définition |
| codelldb + nvim-dap | débogueur graphique |
| bash-language-server, shellcheck, shfmt | complétion, erreurs, formatage des scripts (serveur bash seulement si Node est là) |
| yanky | historique de tout ce que tu copies |
| treesitter | coloration précise du C, du Bash, du Markdown… |

### Outils C et Bash

| Outil | Rôle |
|---|---|
| `crun`, `csan`, `cmem`, `cdebug` | tes commandes maison, corrigées avec `-D_DEFAULT_SOURCE` |
| `kit-projet` | projet C prêt : Makefile, tests Check, clang-format, clang-tidy |
| gdb + gdb-dashboard, valgrind | débogage, fuites mémoire |
| cppcheck, clang-tidy, clang-format, bear | analyse statique, formatage, `compile_commands.json` |
| shellcheck, shfmt, bats | scripts : erreurs, formatage, tests |
| `doc-c`, pages man | documentation C, aussi hors ligne |

### Ligne de commande et bureau

| Outil | Rôle |
|---|---|
| ripgrep (`rg`), fd | chercher du texte, un fichier |
| bat, eza (`lt`) | `cat` joli, arbre de dossiers |
| delta, lazygit (`lg`) | diffs git lisibles, git en menus |
| tldr | exemples courts, en français, hors ligne |
| trash-cli (`tp`) | corbeille en ligne de commande |
| watchexec | relancer une commande à chaque sauvegarde |
| tmux | écran découpé, session qui survit à une coupure SSH |
| CopyQ | **Super+V** : historique de tout ce que tu copies |
| xclip | lien entre Neovim / zsh et le presse-papier |
| `gedit` | ouvre xed (l'éditeur de Mint, version de gedit) |
| gdu, duf, btop, jq, sd, hyperfine, yazi, glow, gh, direnv, chezmoi, croc, rclone | place disque, processus, JSON, remplacement de texte, mesure de vitesse, explorateur, Markdown, GitHub, variables par dossier, dotfiles, transferts |

---

## Les 10 réflexes

| # | Réflexe | Pourquoi |
|---|---|---|
| 1 | `kit-aide` | tous les raccourcis sur une page |
| 2 | Espace (attendre) dans Neovim | menu de tous les raccourcis, cherchable |
| 3 | `csan prog.c` avant de rendre un TP | AddressSanitizer trouve les erreurs mémoire invisibles |
| 4 | `]d` puis Espace c a | aller à l'erreur suivante, appliquer la correction proposée |
| 5 | `K` puis Espace s M | prototype d'une fonction, puis sa page man complète |
| 6 | Ctrl-R | retrouver une commande déjà tapée |
| 7 | `j dossier` | sauter dans un dossier sans taper le chemin |
| 8 | Espace p | recoller quelque chose copié il y a longtemps |
| 9 | `fuck` | corriger une faute de frappe ou une commande git ratée |
| 10 | `tldr commande` | exemple concret au lieu d'un man de 40 pages |

---

## Astuces zsh

### Se déplacer

| Commande | Effet |
|---|---|
| `j tp3` / `z tp3` | aller dans le dossier le plus utilisé contenant « tp3 » |
| `-` | revenir au dossier précédent |
| `...` / `....` | remonter de 2 / 3 niveaux |
| `1`, `2`… | revenir au 1er, 2e dossier récent |
| Alt-← / Alt-→ / Alt-↑ | précédent / suivant / parent |
| `take dossier` | créer un dossier et y entrer (`md` : créer seulement) |
| Alt-C | choisir un dossier avec fzf et y entrer |

### Retrouver, compléter

| Commande | Effet |
|---|---|
| Ctrl-R | historique avec recherche floue |
| `hs gcc` | toutes les commandes passées contenant « gcc » |
| `vim **` puis Tab | choisir un fichier avec fzf (marche avec toute commande) |
| `kill ` puis Tab | choisir un processus |
| Ctrl-T | insérer un chemin de fichier dans la commande |
| flèche droite | accepter la suggestion grise |

### Gagner du temps

| Commande | Effet |
|---|---|
| `fuck` | corriger la dernière commande (Entrée pour valider, Ctrl-C pour annuler) |
| Ctrl-Z, puis Ctrl-Z | mettre Neovim en pause pour taper une commande, puis y revenir |
| Ctrl-O | copier la ligne en cours (pour la coller ailleurs) |
| `ls G txt` | alias global : `G` = `| grep`, `H` = `| head`, `T` = `| tail`, `L` = `| less` |
| `google erreur gcc` | recherche web depuis le terminal |
| `zshrc` | ouvrir ton `.zshrc` (préférer `~/.config/kit-etudiant/perso.zsh`) |

### Git en 2 lettres

| Alias | Commande |
|---|---|
| `gst` | `git status` |
| `ga fichier` / `gaa` | ajouter un fichier / tout |
| `gcmsg "message"` | commit avec message |
| `gp` / `gl` | push / pull |
| `gsw br` / `gswc br` | changer de branche / en créer une |
| `gd` | voir les différences (avec delta) |
| `glog` | historique en graphe |
| `lg` | lazygit : tout ça avec des menus |

Attention : `rm`, `cp` et `mv` demandent confirmation (common-aliases). Réponds `y`. Pour supprimer sans risque : `tp fichier` (corbeille).

---

## Astuces Neovim

`vim` ouvre Neovim. Leader = **Espace**. Espace puis attendre affiche tout. Espace s k cherche un raccourci par son nom.

### Fichiers et fenêtres

| Touche | Effet |
|---|---|
| Espace Espace | chercher un fichier du projet |
| Espace / | chercher du texte dans le projet |
| Espace e | explorateur de fichiers |
| Espace f r | fichiers récents |
| Espace , | fichiers ouverts (buffers) |
| H / L | fichier ouvert précédent / suivant |
| Espace b d | fermer le fichier courant |
| Espace - / Espace \| | couper la fenêtre en bas / à droite |
| Ctrl-h / j / k / l | passer d'une fenêtre à l'autre |
| Ctrl-/ | terminal intégré |
| Espace q q | tout quitter |

### Comprendre et corriger le code

| Touche | Effet |
|---|---|
| `K` | prototype et doc de la fonction sous le curseur |
| `gK` (Ctrl-K en insertion) | paramètres attendus |
| Espace s M | page man complète (taper `strdup`, Entrée) |
| `gd` / `gr` | définition / toutes les utilisations |
| Espace c h | basculer `.c` ↔ `.h` |
| `]d` / `[d` | diagnostic suivant / précédent ; `]e` : erreur suivante |
| Espace c d | message complet de l'erreur sous le curseur |
| Espace c a | correction proposée par clangd |
| Espace c r | renommer partout |
| Espace x x | liste de toutes les erreurs |
| Espace c f | formater (fait aussi à chaque sauvegarde ; Espace u f pour couper) |

### Éditer vite (Vim de base)

| Touche | Effet |
|---|---|
| `ciw` / `ci"` / `ci(` | remplacer le mot / le texte entre guillemets / entre parenthèses |
| `.` | répéter la dernière modification |
| `u` / Ctrl-R | annuler / refaire ; Espace s u : arbre des annulations |
| `%` | sauter à la parenthèse ou accolade correspondante |
| `*` | chercher le mot sous le curseur |
| `s` + 2 lettres | sauter n'importe où à l'écran (flash) |
| `gcc` | commenter / décommenter la ligne |
| `>` / `<` en sélection | indenter |
| `qa` … `q`, puis `@a` | enregistrer une macro, la rejouer (`10@a` : 10 fois) |
| `:%s/ancien/nouveau/gc` | remplacer partout, avec confirmation |
| `gv` | resélectionner la dernière sélection |

### Afficher

| Touche | Effet |
|---|---|
| Espace u w | retour à la ligne automatique |
| Espace u l | numéros de ligne |
| Espace g b | qui a écrit cette ligne (git blame) |
| Espace g g | lazygit |

---

## Compiler, tester, déboguer du C

### Un seul fichier

| Commande | Effet |
|---|---|
| `crun prog.c [args]` | compiler (avertissements stricts, `-g`) et lancer |
| `csan prog.c` | idem avec AddressSanitizer + UBSan : débordements, use-after-free… |
| `cmem prog.c` | idem sous valgrind : fuites mémoire |
| `cdebug prog.c` | compiler et ouvrir gdb |

### Un projet

```bash
kit-projet tp1 && cd tp1
```

| Commande | Effet |
|---|---|
| `make run` | compiler (ASan + UBSan) et lancer |
| `make test` | tests unitaires Check (un segfault ne tue qu'un test) |
| `make valgrind` | fuites mémoire |
| `make analyse` / `check` / `tidy` | `gcc -fanalyzer` / cppcheck / clang-tidy |
| `make format` | clang-format |
| `make compdb` | `compile_commands.json` pour clangd (gros projets) |
| `watchexec -e c,h -- make run` | recompiler et relancer à chaque sauvegarde |

### Déboguer

**Dans gdb** (`cdebug prog.c`) : `dash` affiche source, variables et pile. Puis `break main`, `run`, `next`, `step`, `print x`, `bt`.

**Dans Neovim**, après avoir compilé avec `-g` (`crun` le fait) :

| Touche | Effet |
|---|---|
| Espace d b | point d'arrêt sur la ligne |
| Espace d c | lancer (choisir « Launch file », donner `./prog`) puis continuer |
| Espace d O / Espace d i / Espace d o | ligne suivante / entrer dans la fonction / en sortir |
| Espace d u | afficher / masquer le panneau variables, pile |
| Espace d t | arrêter |

**Pourquoi `-D_DEFAULT_SOURCE` ?** Avec `-std=c11` seul, `strdup`, `getline`, `kill` ou `fileno` ne sont pas déclarées. `strdup` renvoie alors un pointeur tronqué et le programme plante sans raison apparente.

---

## Copier, coller, historique

| Où | Comment |
|---|---|
| Neovim | `y` copier, `d` couper, `p` / `P` coller après / avant |
| Neovim | **Espace p** : historique des copies, choisir, Entrée |
| Neovim | juste après `p` : `[y` / `]y` remplace par la copie précédente / suivante |
| Terminal | sélectionner à la souris = copié ; **clic molette** = coller |
| Terminal | Ctrl-Shift-C / Ctrl-Shift-V (Ctrl-C arrête le programme en cours) |
| Partout | **Super+V** : historique CopyQ ; taper pour filtrer, Entrée pour remettre dans le presse-papier |
| zsh | Ctrl-O : copier la ligne tapée ; `copyfile f` : copier un fichier |
| tmux | Ctrl-b = : historique des copies faites dans tmux |

Le piège classique : `d` coupe, donc écrase ce que tu avais copié avec `y`. Avec yanky, rien n'est perdu : Espace p.

---

## Personnaliser

Ces fichiers sont à toi. Le script ne les écrase jamais.

| Fichier | Pour |
|---|---|
| `~/.config/kit-etudiant/perso.zsh` | tes alias et réglages zsh |
| `~/.config/nvim/lua/config/perso.lua` | tes options Neovim |
| `~/.config/nvim/lua/config/keymaps.lua` | tes raccourcis Neovim |
| `~/.config/nvim/lua/plugins/perso.lua` | tes plugins Neovim |
| `~/.tmux.perso.conf` | tes réglages tmux |
| `~/.p10k.zsh` | ton prompt (`p10k configure` pour le refaire) |

Exemples utiles dans `perso.zsh` :

```bash
alias coursc='cd ~/Etudes/Programmation-C'
eval "$(thefuck --alias oups)"     # « oups » au lieu de « fuck »
```

---

## Mettre à jour, désinstaller

```bash
bash kit-etudiant.sh --maj --maison ~/kit-maison.tar.gz   # tout mettre à jour
bash kit-etudiant.sh --desinstaller                         # tout retirer, garder le perso
bash kit-etudiant.sh --desinstaller --tout                  # tout retirer
```

La désinstallation retire le profil « Maison » et remet ton terminal par défaut, restaure tes anciens `.zshrc` et `.tmux.conf`, met ta config Neovim de côté (`~/.config/nvim.kit-sauvegarde-*`) au lieu de la supprimer, et n'annule que les réglages git qu'elle a ajoutés.

**Ne pas mettre à jour juste avant un examen.**

---

## Dépannage

| Problème | Solution |
|---|---|
| Le terminal ne s'ouvre pas dans zsh | fermer **tous** les terminaux, en rouvrir un ; sinon taper `zsh` |
| Lettres très espacées, carrés à la place des icônes | profil « Maison » → police **MesloLGS NF** |
| Une ligne ✘ dans le bilan | lire le journal indiqué, puis relancer le script |
| Bulles rouges « mason… failed to install » | Node absent : vérifier l'étape conda du bilan |
| Erreurs rouges « query.lua … Invalid node type » | `bash kit-etudiant.sh --seulement neovim --maj` |
| Neovim : `y` ne va pas dans le presse-papier | `command -v xclip` ; dans Neovim `:checkhealth vim.provider` |
| CopyQ refusé (libOpenGL ou glibc) | `flatpak install --user flathub com.github.hluk.copyq` si flatpak est présent |
| Quota plein | `gdu ~`, puis relancer avec `--sans-conda` si besoin |
| Revenir à l'état d'origine | `bash kit-etudiant.sh --desinstaller --tout` |

---

## Outils annexes

| Script | Où | Rôle |
|---|---|---|
| `export-maison.sh` | PC maison | lecture seule : rassemble prompt, plugins, police, couleurs Konsole et config Neovim dans `~/kit-maison.tar.gz` |
| `reparer-maison.sh` | PC maison | répare ce qui était cassé chez toi (CFLAGS, thefuck, git, outils LazyVim, Node, treesitter, ligne de commande, ménage). Chaque réparation demande ton accord ; `--voir` pour regarder sans rien changer |

Si tu changes de thème ou de plugins à la maison : relancer `export-maison.sh`, puis `--maison` à la fac.

---

## Versions

| Version | Changements |
|---|---|
| 2.5 | serveur bash seulement si Node est disponible ; vérification des règles de coloration après installation |
| 2.4 | ligne de commande et messages de Neovim en bas de l'écran (noice ne les gère plus) |
| 2.3 | yanky (historique des copies dans Neovim), CopyQ (historique global, Super+V) |
| 2.2 | xclip, `gedit` → xed |
| 2.1 | `--maison` : prompt, 17 plugins, police, couleurs et marge reprises de la maison ; thefuck |
| 2.0 | zsh + oh-my-zsh + powerlevel10k, Neovim + LazyVim, profil GNOME Terminal « Maison » |
| 1.x | bash + ble.sh + starship, Vim + ALE (remplacée) |

---

## État des tests

Testé le 6 octobre 2026 sur Ubuntu 24.04 avec un **utilisateur sans aucun droit**, et de faux `sudo`, `su`, `pkexec` qui enregistrent toute tentative.

| Vérification | Résultat |
|---|---|
| Tentatives d'élévation de droits | 0 |
| Installation complète avec ton archive | tout réussi sauf micromamba (réseau du test bloqué) |
| Prompt | `~/.p10k.zsh` identique au fichier maison, 17 plugins chargés |
| LazyVim | clangd actif, parseurs compilés et vérifiés, yanky, ligne de commande classique |
| Raccourcis cités dans ce README | vérifiés un par un dans Neovim et zsh |
| CopyQ 16 | démarre quand `libOpenGL.so.0` est présente (la 17 exige une glibc trop récente) |
| Désinstallation v1 / v2 | 1,7 Go → 188 Ko / 12 Mo, fichiers perso conservés |

**Pas encore testé sur un vrai poste** : micromamba (valgrind, gdb, Node, xclip), l'affichage réel du profil « Maison », CopyQ avec un vrai écran.
