# kit-etudiant 2.1

Ton environnement de travail **C et Bash** sur Linux Mint, installé **sans droits administrateur**.

zsh avec oh-my-zsh et powerlevel10k, Neovim avec LazyVim (erreurs en direct, complétion clangd, débogueur), GNOME Terminal aux couleurs de Konsole, et les outils pour compiler, déboguer et tester. Aucun `sudo`, aucun fichier système modifié.

```bash
bash kit-etudiant.sh --maison kit-maison.tar.gz
```

---

## Principe

| | |
|---|---|
| **Sans root** | Tout va dans `$HOME`. Le script refuse de tourner en root et ne peut pas appeler `sudo`. |
| **Relançable** | Ce qui est déjà installé est sauté. Relancer ne refait que ce qui a échoué. |
| **Réversible** | `--desinstaller` retire tout et remet tes fichiers de config d'origine. |
| **Stable** | Pas de mise à jour automatique d'oh-my-zsh, versions des outils Mason figées. Rien ne change la veille d'un examen. |
| **Réseau partagé** | Aucun appel à l'API GitHub, donc pas de blocage quand toute une salle installe en même temps. |

---

## Installation

Prérequis : Linux x86_64, `curl`, `tar`, `xz`, `git`, `gcc`, environ **2,5 Go** libres (`quota -s` pour vérifier).

**1. Sur ton PC maison**, rassembler ta config de thème (lecture seule) :

```bash
bash export-maison.sh          # crée ~/kit-maison.tar.gz
```

**2. Sur le PC de la fac :**

```bash
git clone https://github.com/TON_PSEUDO/kit-etudiant.git
cd kit-etudiant
bash kit-etudiant.sh --maison ~/kit-maison.tar.gz
```

`--maison` reprend exactement ton prompt powerlevel10k, ta liste de plugins oh-my-zsh, ta police et sa taille, la marge de Konsole et ses couleurs. Sans archive, le kit utilise ta liste de plugins connue, la police MesloLGS NF 15, les couleurs Breeze, et le prompt style « rainbow ».

L'installation prend quelques minutes. À la fin, un **bilan** liste ce qui a réussi, ce qui a échoué et ce qu'il reste à faire.

**Ensuite :** fermer **tous** les terminaux, en rouvrir un. Le profil « Maison » s'ouvre directement dans zsh.

### Venir de la version 1

```bash
bash kit-etudiant.sh --desinstaller --tout
bash kit-etudiant.sh --maison ~/kit-maison.tar.gz
```

---

## Options

| Option | Effet |
|---|---|
| `--maison ARCHIVE` | reprendre ta config maison (archive de `export-maison.sh`) |
| `--p10k FICHIER` | reprendre seulement ton prompt powerlevel10k |
| `--maj` | tout mettre à jour (plugins, outils, registre Mason) |
| `--sans-conda` | sauter micromamba (valgrind, gdb, cppcheck, bear, tmux, Check, Node) |
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
| oh-my-zsh + powerlevel10k | prompt avec dossier, branche git, état, durée, erreurs |
| zsh-autosuggestions | suggestion grise d'après l'historique (flèche droite pour accepter) |
| zsh-syntax-highlighting | commande en vert si elle existe, en rouge sinon |
| tes 17 plugins oh-my-zsh | git, sudo, dirhistory, copybuffer, common-aliases, colored-man-pages, web-search… |
| thefuck | `fuck` corrige la dernière commande (installé avec Python 3.11, seul compatible) |
| autojump → zoxide | autojump demande root : remplacé par zoxide, `j dossier` marche toujours |
| zsh-bat | `cat` coloré avec numéros de ligne |
| fzf, zoxide | Ctrl-R, Ctrl-T, Alt-C, `z dossier` |
| Profil « Maison » | GNOME Terminal aux couleurs Breeze de Konsole, police MesloLGS NF 15, marge de 5 px |
| Caps Lock → Échap | confort dans Neovim (Shift + Caps garde les majuscules) |

### Neovim + LazyVim

| Élément | Rôle |
|---|---|
| clangd | erreurs C en direct, complétion, aller à la définition |
| codelldb + nvim-dap | débogueur graphique |
| bash-language-server + shellcheck + shfmt | erreurs, complétion et formatage des scripts |
| treesitter | coloration précise du C, du Bash… |
| Pages man dans Neovim | `Espace s M` ou `man 3 strdup` : explication complète d'une fonction |

### Outils C et Bash

| Outil | Rôle |
|---|---|
| `crun`, `csan`, `cmem`, `cdebug` | compiler et lancer, avec sanitizers, sous valgrind, ou dans gdb |
| `kit-projet` | projet C prêt : Makefile, tests Check, clang-format, clang-tidy |
| gdb + gdb-dashboard, valgrind | débogage, fuites mémoire |
| cppcheck, clang-tidy, clang-format, bear | analyse statique, formatage, `compile_commands.json` |
| shellcheck, shfmt, bats | scripts : erreurs, formatage, tests |
| `doc-c` | documentation C hors ligne (cppreference) |

### Ligne de commande

ripgrep, fd, bat, eza, delta, lazygit, jq, yazi, gh, glow, watchexec, hyperfine, duf, sd, btop, gdu, direnv, chezmoi, croc, rclone, tldr, trash-cli, tmux.

---

## Au quotidien

`kit-aide` affiche l'aide-mémoire complet. L'essentiel :

| Commande / touche | Effet |
|---|---|
| `crun prog.c` | compiler avec avertissements stricts et lancer |
| `csan` / `cmem` / `cdebug prog.c` | AddressSanitizer / valgrind / gdb |
| `kit-projet tp1 && cd tp1 && make run` | nouveau projet |
| `vim fichier.c` | ouvre Neovim (LazyVim) |
| Espace Espace / Espace / | chercher un fichier / du texte |
| `K` / `gK` | prototype / paramètres de la fonction |
| Espace s M | page man d'une fonction |
| `]d` `[d` | erreur suivante / précédente |
| Espace c a | correction proposée |
| Espace d b puis Espace d c | point d'arrêt puis débogueur |
| Espace g g | lazygit |

Les commandes C ajoutent `-D_DEFAULT_SOURCE` à `-std=c11` : sans cela, `strdup`, `getline`, `kill` ou `fileno` ne sont pas déclarées et le programme peut planter de façon incompréhensible.

---

## Personnaliser

Ces fichiers sont à toi. Le script ne les écrase jamais.

| Fichier | Pour |
|---|---|
| `~/.config/kit-etudiant/perso.zsh` | tes alias et réglages zsh |
| `~/.config/nvim/lua/config/perso.lua` | tes options Neovim |
| `~/.config/nvim/lua/plugins/perso.lua` | tes plugins Neovim |
| `~/.tmux.perso.conf` | tes réglages tmux |
| `~/.p10k.zsh` | ton style de prompt (`p10k configure`) |

---

## Mettre à jour, désinstaller

```bash
bash kit-etudiant.sh --maj                  # tout mettre à jour
bash kit-etudiant.sh --desinstaller         # tout retirer, garder le perso
bash kit-etudiant.sh --desinstaller --tout  # tout retirer
```

La désinstallation retire le profil « Maison » et remet ton terminal par défaut, restaure tes anciens `.zshrc` et `.tmux.conf`, met ta config Neovim de côté (`~/.config/nvim.kit-sauvegarde-*`) au lieu de la supprimer, et n'annule que les réglages git qu'elle a ajoutés.

Ne pas mettre à jour juste avant un examen.

---

## Dépannage

| Problème | Solution |
|---|---|
| Le terminal ne s'ouvre pas dans zsh | fermer **tous** les terminaux, en rouvrir un ; sinon taper `zsh` |
| Lettres très espacées ou carrés à la place des icônes | profil « Maison » → police **MesloLGS NF** |
| Une ligne ✘ dans le bilan | lire le journal indiqué, puis relancer le script |
| Pas de serveur Bash dans Neovim | Node absent : vérifier l'étape conda dans le bilan |
| Quota plein | `gdu ~`, puis relancer avec `--sans-conda` si besoin |
| Revenir à l'état d'origine | `bash kit-etudiant.sh --desinstaller --tout` |

---

## État des tests

Testé le 5 octobre 2026 sur Ubuntu 24.04 avec un **utilisateur sans aucun droit**, et de faux `sudo`, `su`, `pkexec` qui enregistrent toute tentative.

| Vérification | Résultat |
|---|---|
| Tentatives d'élévation de droits | 0 |
| Installation complète | tout réussi sauf micromamba (réseau du test bloqué) |
| zsh + ton `.p10k.zsh` + tes 17 plugins | chargés, prompt identique au fichier maison |
| LazyVim | clangd actif sur un fichier C, parseurs compilés, outils Mason installés |
| `crun` avec `strdup` | compile et tourne |
| Profil GNOME Terminal | toutes les clés validées par le schéma de GNOME Terminal |
| Désinstallation d'une version 1 | 1,7 Go → 188 Ko, `.bashrc` et `.profile` identiques à l'original |
| Désinstallation de la version 2 | 1,7 Go → 13 Mo, fichiers perso et config Neovim conservés |

**Pas encore testé sur un vrai poste** : micromamba, et l'affichage réel du profil « Maison » dans GNOME Terminal.
