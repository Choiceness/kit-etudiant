# Mon installation (PC de la fac)

Ce que j'ai installé, où, à quoi ça sert, et comment le retrouver ou l'enlever.

Version décrite : **ExportedHomeConfig 3.0** (`exported-home-config.sh`), installé avec mon archive de la maison (`--home`).
Avant la 3.0, le projet s'appelait « kit-etudiant ». Relancer la nouvelle version renomme tout automatiquement (§8).

---

## 1. L'idée

- Sur le PC de la fac je n'ai **pas les droits administrateur** (pas de `sudo`, pas de `apt install`).
- `exported-home-config.sh` **télécharge des programmes déjà compilés** (GitHub, conda-forge…) et les range **dans mon dossier personnel** (`~`), jamais ailleurs.
- Il règle mes fichiers de config pour retrouver mon terminal de la maison : zsh + powerlevel10k + Neovim LazyVim + couleurs de Konsole.
- Tout ce qu'il crée est **noté dans une liste** (`~/.config/exported-home-config/manifest`), donc tout s'enlève **en une commande**.
- Le script **refuse d'utiliser sudo** : il redéfinit `sudo`, `su` et `pkexec` pour qu'ils s'arrêtent avec « FORBIDDEN ». Testé avec un faux sudo qui enregistrait chaque appel : **0 appel**.

Rien n'est modifié sur le système de la fac.

---

## 2. Comment ça marche sans root

| Obstacle | Solution |
|---|---|
| Pas de `apt install` | programmes précompilés dans `~/.local/bin` |
| Ces programmes ne sont pas dans le PATH | `~/.local/bin` ajouté au PATH (`~/.profile` et `.zshrc`) |
| Certains outils ont besoin de beaucoup de bibliothèques (gdb, valgrind…) | **micromamba**, un petit gestionnaire de paquets qui installe dans `~/micromamba` |
| Pas de zsh sur le PC | **zsh-bin**, un zsh autonome fait pour s'installer sans root |
| Les AppImage demandent FUSE | elles sont **extraites** dans `~/.local/opt` |
| Le réseau de la fac limite l'API GitHub | le script n'utilise pas l'API, il lit la redirection de la page « releases/latest » |
| Mon dossier personnel est sur le réseau (lent) | les fichiers temporaires de Neovim vont dans `/tmp` (disque local) |

Vérifié au départ : pas lancé en root, processeur x86_64, présence de `curl tar gzip xz git find install awk sed`, dossier personnel pas monté « noexec ». Place nécessaire : environ **2,5 Go**.

---

## 3. Les 13 étapes

`bash exported-home-config.sh --list` les affiche. Une étape seule : `bash exported-home-config.sh --only neovim,config`.

| # | Étape | Ce qu'elle fait |
|---|---|---|
| 1 | `prep` | dossiers, vérifications (noexec, glibc, place), `~/.local/bin` dans le PATH |
| 2 | `cli` | 21 petits outils en ligne de commande (§4.1) |
| 3 | `zsh` | zsh, fzf, zoxide, oh-my-zsh, powerlevel10k, plugins zsh |
| 4 | `shell_tools` | shellcheck, shfmt, bats |
| 5 | `c_tools` | gdb-dashboard (`dash` dans gdb) |
| 6 | `python` | uv, puis clang-format, clang-tidy, trash-cli, thefuck |
| 7 | `conda` | micromamba, puis valgrind, gdb, cppcheck, bear, tmux, check, pkg-config, nodejs, xclip |
| 8 | `neovim` | Neovim, LazyVim, plugins, outils Mason (clangd, débogueur…), parseurs de coloration |
| 9 | `tmux` | `.tmux.conf` et plugins tmux |
| 10 | `config` | `.zshrc`, repli bash, `.gdbinit`, git, `cnew`, `memo` |
| 11 | `doc` | doc C hors ligne (cppreference), commande `cdoc` |
| 12 | `terminal` | police MesloLGS NF, profil « Home » du terminal, Caps Lock → Échap |
| 13 | `clipboard` | CopyQ (historique de ce que je copie, Super+V) |

À la fin : un **SUMMARY** (réussis, `[FAIL]`, choses à faire) et un journal dans `~/.cache/exported-home-config/install-DATE.log`. Relancer le script ne refait que ce qui manque.

---

## 4. Tout ce qui est installé

### 4.1 Outils en ligne de commande (`~/.local/bin`)

| Outil | Commande | À quoi ça sert |
|---|---|---|
| ripgrep | `rg motif` | chercher du texte dans tous les fichiers |
| fd | `fd nom` | chercher un fichier par son nom |
| bat | `bat fichier` | `cat` coloré, avec numéros de ligne |
| eza | `eza`, `lt` | `ls` plus lisible ; `lt` = dossier en arbre |
| delta | (utilisé par git) | `git diff` lisible, couleurs et numéros de ligne |
| lazygit | `lg` | git en menus |
| jq | `jq` | lire / filtrer du JSON |
| yazi | `yazi` | explorateur de fichiers dans le terminal |
| gh | `gh` | GitHub en ligne de commande |
| glow | `glow fichier.md` | afficher du markdown (utilisé par `memo`) |
| watchexec | `watchexec` | relancer une commande à chaque sauvegarde |
| hyperfine | `hyperfine` | mesurer le temps d'une commande |
| duf | `duf` | espace disque, lisible |
| sd | `sd` | remplacer du texte (`sed` plus simple) |
| btop | `btop` | moniteur processeur / mémoire |
| gdu | `gdu` | quels dossiers prennent de la place |
| direnv | `direnv` | variables d'environnement par dossier |
| chezmoi | `chezmoi` | gérer ses fichiers de config sur plusieurs PC |
| croc | `croc` | envoyer un fichier d'un PC à un autre |
| rclone | `rclone` | synchroniser avec un cloud |
| tldr | `tldr tar` | exemples courts d'une commande, en français (pages dans `~/.cache/tealdeer`) |

Pour le C, j'utilise surtout `rg`, `fd`, `bat`, `lt`, `lg`, `tldr`.

### 4.2 Le shell : zsh, oh-my-zsh, powerlevel10k

| Quoi | Où | Rôle |
|---|---|---|
| zsh (zsh-bin) | `~/.local/bin/zsh`, `~/.local/share/zsh` | le shell. Le profil « Home » du terminal le lance |
| oh-my-zsh | `~/.oh-my-zsh` | plugins et alias pour zsh |
| powerlevel10k | `~/.oh-my-zsh/custom/themes/powerlevel10k` | le prompt. Ma config : `~/.p10k.zsh` (celle de la maison) |
| zsh-autosuggestions | `~/.oh-my-zsh/custom/plugins/` | suggestion grise, **→** pour accepter |
| zsh-syntax-highlighting | idem | commande verte si elle existe, rouge sinon |
| you-should-use | idem | rappelle un alias quand je tape la commande longue |
| zsh-bat | idem | `bat` à la place de `cat` |
| fzf | `~/.fzf`, `~/.local/bin/fzf` | **Ctrl-R** historique, **Ctrl-T** fichier, **Alt-C** dossier |
| zoxide | `~/.local/bin/zoxide` | `j tp5` / `z tp5` : aller dans un dossier déjà visité |

Plugins oh-my-zsh : **les mêmes qu'à la maison** (git, fancy-ctrl-z, command-not-found, colored-man-pages, common-aliases, copybuffer, copyfile, dirhistory, history, web-search, sudo, thefuck + ceux du tableau). Seul `autojump` (impossible sans root) est remplacé par **zoxide**, `j` marche pareil. Liste : `~/.config/exported-home-config/plugins.zsh`.

### 4.3 Scripts bash

| Outil | Commande | Rôle |
|---|---|---|
| shellcheck | `shellcheck script.sh` | erreurs et pièges d'un script |
| shfmt | `shfmt -d` / `-w` | montre / corrige la mise en forme |
| bats-core | `bats` | tests automatiques pour scripts bash |

### 4.4 C : debug, mémoire, qualité

| Outil | Vient de | Rôle |
|---|---|---|
| gcc, make, git | **le système** (déjà là, pas touché) | compiler, automatiser, versionner |
| gdb | micromamba (ou système) | débogueur |
| gdb-dashboard | `~/.gdb-dashboard` | `dash` dans gdb : source, variables, pile |
| valgrind | micromamba | fuites mémoire, variables non initialisées |
| cppcheck | micromamba | analyse statique (`make check`) |
| bear | micromamba | `compile_commands.json` pour clangd (`make compdb`) |
| check + pkg-config | micromamba | tests unitaires C (`make test`) |
| clang-format | uv (Python) | mise en forme (`make format`) |
| clang-tidy | uv (Python) | bugs probables (`make tidy`) |
| clangd | Mason (Neovim) | erreurs, complétion, définitions dans l'éditeur |
| codelldb | Mason (Neovim) | débogueur dans Neovim (`Espace d …`) |

**Le système garde la priorité** : si le PC a déjà `gdb` ou `tmux`, c'est sa version qui sert.

### 4.5 Python : uv

- **uv** (`~/.local/bin/uv`) : gestionnaire d'outils Python, sans root.
- Avec lui : **trash-cli** (`tp fichier` = corbeille), **clang-format**, **clang-tidy**, **thefuck** (`fuck`, avec Python 3.11).
- Fichiers : `~/.local/share/uv`, cache `~/.cache/uv`.

### 4.6 micromamba

- Un gestionnaire de paquets (version légère de conda) qui installe des programmes **avec leurs bibliothèques** dans un dossier à moi. C'est mon `apt` sans root.
- Programme : `~/.local/opt/micromamba/micromamba`. Données : `~/micromamba` (environnement nommé `outils`).
- Contenu : valgrind, gdb, cppcheck, bear, tmux, check, pkg-config, nodejs, xclip (depuis **conda-forge**).
- Des liens dans `~/.local/bin` (`valgrind`, `node`, `npm`…) seulement si le système n'a pas déjà la commande.
- nodejs sert à Neovim pour installer le serveur de langage bash.
- Pas de commande `micromamba` dans `~/.local/bin`, pour ne pas cacher celle du PC.
- Sans micromamba : `--no-conda` (mais valgrind, gdb, tmux… manqueraient).

### 4.7 Neovim + LazyVim

| Quoi | Où | Rôle |
|---|---|---|
| Neovim | `~/.local/opt/nvim`, lien `~/.local/bin/nvim` | l'éditeur. `vim` et `vi` ouvrent `nvim` |
| LazyVim | `~/.config/nvim` | config prête (plugins, raccourcis avec Espace) |
| plugins | `~/.local/share/nvim/lazy` | téléchargés au premier lancement |
| outils Mason | `~/.local/share/nvim/mason` | clangd, codelldb, shellcheck, shfmt, stylua, tree-sitter-cli, bash-language-server |
| parseurs | `~/.local/share/nvim/site/parser` | coloration : c, cpp, bash, make, markdown, lua, vim… |

Extras LazyVim (`~/.config/nvim/lazyvim.json`) : `coding.yanky` (historique des copies, Espace p), `dap.core` (débogueur), `lang.clangd` (C).

Fichiers **réécrits à chaque installation** : `lazyvim.json`, `lua/plugins/exported-home-config.lua`, `lua/config/options.lua`. Ce qu'ils règlent :
- bashls seulement si Node est là, sinon nvim-lint lance shellcheck (jamais les deux) ;
- registre Mason figé sur une version ;
- ligne de commande `:` et messages en bas de l'écran ;
- numéros de ligne classiques, `scrolloff = 5` ;
- fichiers `.swp` dans `/tmp/MONUSER-nvim-swap` (disque local) ;
- pas de vérification automatique des mises à jour.

**Mes fichiers, jamais écrasés** : `lua/config/perso.lua`, `lua/plugins/perso.lua`, et tout nouveau fichier que j'ajoute dans `lua/plugins/` (comme `terminal-right.lua`).

### 4.8 tmux

`~/.tmux.conf` : souris, `Ctrl-b |` et `Ctrl-b -` pour découper, plugins tpm, sensible, resurrect (`~/.tmux/plugins`). Mes réglages : `~/.tmux.perso.conf`.

### 4.9 Mes commandes C et la config

| Quoi | Où | Rôle |
|---|---|---|
| `crun`, `csan`, `cmem`, `cdebug` | `~/.zshrc` (+ `bashrc.sh` pour bash) | compiler + lancer / avec sanitizers / sous valgrind / sous gdb |
| options C | `CFLAGS_DEV` dans `.zshrc` | `-std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -g` |
| alias | `.zshrc` | `lt`, `lg`, `tp`, `j`, `vim`→nvim, `gedit`→xed, `mkcd dossier` |
| `~/.gdbinit` | bloc délimité | historique gdb, affichage lisible, `dash` |
| git | `~/.gitconfig` | `git lg`, branche `main` par défaut, `delta`. **Seulement** les réglages que je n'avais pas |
| `cnew NOM` | `~/.local/bin/cnew`, modèle dans `~/.config/exported-home-config/templates/c-project` | projet C : Makefile (`make run/test/valgrind/analyse/tidy/format/compdb`), test Check, `.clang-format`, `.clang-tidy`, `.gitignore` |
| `memo` | `~/.local/bin/memo` | mon aide-mémoire (`~/.config/exported-home-config/memo.md`) |
| `cdoc` | `~/.local/bin/cdoc`, doc dans `~/.local/opt/cppreference` | doc C complète hors ligne |

Tout ce qui sert au C commence par **c** : `crun`, `csan`, `cmem`, `cdebug`, `cnew`, `cdoc`.

### 4.10 Terminal, clavier, presse-papier

| Quoi | Où | Détail |
|---|---|---|
| police **MesloLGS NF** | `~/.local/share/fonts/MesloLGS-NF` | celle de powerlevel10k (icônes), taille 15 |
| profil GNOME Terminal **« Home »** | `gsettings` / `dconf` | couleurs Konsole (Breeze), Meslo, lance zsh, profil par défaut. L'ancien profil par défaut est mémorisé (`terminal-profile`) |
| marge du texte | `~/.config/gtk-3.0/gtk.css` (bloc délimité) | 5 px, comme Konsole |
| **Caps Lock → Échap** | `~/.config/autostart/exported-home-config-caps-escape.desktop` | `setxkbmap -option caps:escape_shifted_capslock` à chaque session. **Maj + Verr. Maj** = verrouillage majuscules |
| **CopyQ** v16 | `~/.local/opt/copyq`, `~/.config/autostart/exported-home-config-copyq.desktop` | historique des copies, **Super+V** |

CopyQ est figé en version 16 : la 17 demande une glibc plus récente que celle de Mint.

Caps Lock → Échap n'existe pas à la maison. Pour l'enlever :
```
rm ~/.config/autostart/exported-home-config-caps-escape.desktop
setxkbmap -option ""          # options clavier par défaut, tout de suite
```
(Pas encore testé sur le PC de la fac.)

---

## 5. Carte du dossier personnel

```
~
├── .local/bin/            commandes installées (rg, fd, bat, nvim, zsh, lazygit, cnew, memo, cdoc…)
├── .local/opt/            programmes en dossier : nvim, micromamba, copyq, cppreference
├── .local/share/
│   ├── nvim/              plugins, outils Mason, parseurs
│   ├── uv/                outils Python (clang-tidy, trash-cli, thefuck…)
│   ├── fonts/             MesloLGS NF
│   ├── zsh/               fichiers de zsh-bin
│   └── terminfo/          descriptions de terminaux installées avec zsh-bin
├── micromamba/            environnement « outils » (valgrind, gdb, cppcheck, bear, tmux, check, node)
├── .oh-my-zsh/            oh-my-zsh + thème + plugins
├── .fzf/                  fzf
├── .config/
│   ├── nvim/              ma config LazyVim
│   ├── exported-home-config/   manifest, plugins.zsh, memo.md, templates/, perso.zsh, bashrc.sh
│   ├── autostart/         Caps → Échap et CopyQ au démarrage
│   ├── copyq/             raccourci Super+V
│   └── gtk-3.0/gtk.css    marge du terminal
├── .zshrc  .p10k.zsh  .gdbinit  .tmux.conf  .gdb-dashboard
├── .cache/exported-home-config/   journaux d'installation
└── .npm/  .cache/uv  .cache/nvim  …   caches
```

---

## 6. Fichiers existants modifiés

Un fichier existant n'est jamais modifié sans **copie de l'original** (suffixe `.before-home-config`) ou sans **bloc délimité** que le script sait retirer.

| Fichier | Ce qui change |
|---|---|
| `~/.zshrc` | remplacé ; l'ancien est dans `.zshrc.before-home-config`. **Si j'enlève la 1re ligne (« Managed by exported-home-config.sh »), le script n'y touche plus** |
| `~/.profile` | bloc : ajoute `~/.local/bin` au PATH |
| `~/.bashrc` | bloc : charge le repli bash (mêmes alias et commandes C) |
| `~/.gdbinit` | bloc |
| `~/.config/gtk-3.0/gtk.css` | bloc (marge du terminal) |
| `~/.tmux.conf` | remplacé ; l'ancien dans `.tmux.conf.before-home-config` |
| `~/.gitconfig` | quelques clés ajoutées si absentes (notées `git:…` dans le manifest) |
| `~/.config/nvim` | une config déjà présente est déplacée dans `nvim.before-home-config` |

Les blocs sont entre `# >>> exported-home-config >>>` et `# <<< exported-home-config <<<`. Pour les voir : `grep -n exported-home-config ~/.bashrc ~/.profile ~/.gdbinit`.

---

## 7. Retrouver ce qui est installé

| Je veux voir… | Commande |
|---|---|
| les étapes | `bash exported-home-config.sh --list` |
| **tout** ce qui a été créé | `cat ~/.config/exported-home-config/manifest` |
| les commandes installées | `ls ~/.local/bin` |
| d'où vient une commande | `which rg`, `type crun` |
| la version d'un outil | `rg --version`, `nvim --version`, `gcc --version`… |
| le contenu de micromamba | `~/.local/opt/micromamba/micromamba -r ~/micromamba list -n outils` |
| les plugins Neovim / outils Mason | dans Neovim : `:Lazy` / `:Mason` |
| les plugins zsh actifs | `cat ~/.config/exported-home-config/plugins.zsh` |
| la place prise | `du -sh ~/.local ~/micromamba ~/.oh-my-zsh ~/.config/nvim` |
| mon aide-mémoire | `memo` |
| le déroulé de l'installation | dernier fichier de `~/.cache/exported-home-config/` |
| le code de `crun` | `which crun` |

---

## 8. Mettre à jour, réparer, désinstaller

| Je veux… | Commande |
|---|---|
| réparer / finir une installation | `bash exported-home-config.sh --home home-config.tar.gz` (ne refait que ce qui manque) |
| **passer de kit-etudiant à cette version** | la même commande ; elle renomme tout sans retélécharger (`kit-projet` → `cnew`, `kit-aide` → `memo`, `doc-c` → `cdoc`). Mon ancienne archive `kit-maison.tar.gz` marche aussi |
| tout mettre à jour | `bash exported-home-config.sh --update` |
| une seule partie | `bash exported-home-config.sh --only neovim` (ou `config`, `terminal`…) |
| sans toucher au terminal | `--no-terminal` |
| sans micromamba | `--no-conda` |
| reprendre mon `.p10k.zsh` | `--p10k ~/.p10k.zsh` |
| **tout désinstaller** | `bash exported-home-config.sh --uninstall` |
| tout désinstaller, **même mes fichiers perso** | `bash exported-home-config.sh --uninstall --all` |

Les anciennes options (`--maison`, `--maj`, `--seulement`, `--desinstaller`, `--tout`…) marchent encore.

La désinstallation, dans l'ordre :
1. retire les blocs de `.bashrc`, `.profile`, `.gdbinit`, `gtk.css` ;
2. remet mon ancien `.zshrc` et `.tmux.conf` s'ils existaient ;
3. retire les clés git qu'elle avait ajoutées ;
4. **met de côté** ma config Neovim (`~/.config/nvim.saved-DATE`, jamais effacée sans `--all`) ;
5. retire le profil « Home » et remet l'ancien profil par défaut ;
6. supprime tout ce qui est dans le manifest.

Gardé sans `--all` : `~/.config/exported-home-config/perso.zsh`, `~/.tmux.perso.conf`, la config Neovim mise de côté, `~/.p10k.zsh` s'il vient de la maison.

Testé sur une machine de test (sans micromamba, sans Neovim complet, sans CopyQ) : installation puis `--uninstall --all`, le dossier personnel revient à son état de départ (`.bashrc` et `.profile` identiques à l'original).

⚠️ Pas avant l'examen, sauf raison précise.

---

## 9. Fac et maison

À la maison **je n'utilise pas** `exported-home-config.sh` : mon PC a déjà tout (apt, snap, pipx). J'y lance `fix-home-config.sh`, qui :
- corrige quelques soucis (CFLAGS sans `-D_DEFAULT_SOURCE`, thefuck, git, treesitter, ligne de commande de Neovim) ;
- ajoute seulement ce que la fac a en plus (shellcheck, shfmt, bats, tldr, eza, delta, watchexec, trash-cli, Check, clang-tidy, `dash`, `cnew`, `memo`, `cdoc`, alias `lt lg tp mkcd`, `git lg`).

Il utilise des fonctions de `exported-home-config.sh` : les deux scripts doivent être dans le même dossier.

| | Fac | Maison |
|---|---|---|
| installation | `exported-home-config.sh` (sans root) | apt, snap, pipx + `fix-home-config.sh` |
| terminal | GNOME Terminal, profil « Home » (couleurs Konsole) | Konsole |
| historique des copies | CopyQ (Super+V) | Klipper (Super+V) |
| aller dans un dossier | `j` = zoxide | `j` = autojump |
| gdb, valgrind… | micromamba | apt |
| Caps Lock → Échap | oui | non |
| options C | `CFLAGS_DEV` (non exportée) | `CFLAGS` (exportée) |

Mêmes commandes des deux côtés : `crun`, `csan`, `cmem`, `cdebug`, `cnew`, `memo`, `cdoc`.

Les trois scripts :

| Script | Où | Rôle |
|---|---|---|
| `export-home-config.sh` | maison | lecture seule : met prompt, plugins, Konsole et config Neovim dans `~/home-config.tar.gz` |
| `exported-home-config.sh` | fac | installe tout sans root à partir de cette archive |
| `fix-home-config.sh` | maison | répare et ajoute ce qui manque par rapport à la fac |

---

## 10. Limites

- **Ce document décrit ce que le script installe**, pas forcément ce qui a réussi sur le PC. Pour vérifier : le SUMMARY, le journal (§7) ou `ls ~/.local/bin`. Relancer le script réessaie ce qui a raté.
- **Pas de vérification de signature** : les programmes viennent des pages officielles de leurs projets (GitHub releases, conda-forge) en HTTPS, mais le script ne vérifie ni signature ni somme de contrôle.
- **Dossier personnel sur le réseau** : un peu plus lent, et un quota (`quota -s`, `du -sh ~`). Il faut environ 2,5 Go.
- **Changer de PC de la fac** : le dossier personnel suit. Seuls les fichiers `.swp` de Neovim dans `/tmp` restent sur l'ancien PC (sans importance). Si le Linux du nouveau PC est différent, relancer le script répare ce qui ne démarre plus.
- **Exam sur un compte spécial** : si l'examen n'est pas sur mon compte, rien de tout ça n'y sera. Savoir faire avec `gcc`, `gdb`, `man` et `vim`/`nano` du système.
- **Sans internet** : tout ce qui est installé marche. Seuls les téléchargements et mises à jour demandent du réseau.
