# Mes notes C : compiler, vérifier, m'organiser en TP et en exam

Ce que j'ai compris sur mes outils (PC fac et PC maison, même config), et ma façon de bosser pour les TP et l'exam.

---

## 1. crun, csan, cmem, cdebug

### Ce ne sont pas des alias, ce sont des fonctions

- Un **alias** remplace juste un mot par un autre. Exemple : `alias vim=nvim`.
- Une **fonction** est un petit programme : elle peut tester, calculer, enchaîner des commandes.

`crun` doit être une fonction parce qu'il vérifie que le fichier existe, fabrique le nom du programme (`prog.c` → `prog`) et passe le reste des arguments à mon programme. Un alias ne sait pas faire ça.

Elles sont dans mon `~/.zshrc`. Pour voir leur code : `which crun`.

### crun = gcc + les bonnes options + lancement

`crun prog.c 5 7` fait exactement :

```sh
gcc -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -g prog.c -o prog -lm && ./prog 5 7
```

| Option | Pourquoi |
|---|---|
| `-std=c11` | version du langage C |
| `-D_DEFAULT_SOURCE` | rend visibles `strdup`, `getline`… que `-std=c11` cache |
| `-Wall -Wextra -Wpedantic` | avertissements (gcc n'en montre presque aucun par défaut) |
| `-Wshadow` | une variable qui en cache une autre du même nom |
| `-Wconversion` | conversion qui perd des données (int → char…) |
| `-g` | numéros de ligne pour gdb et valgrind |
| `-o prog` | nom du programme (sinon `a.out`) |
| `-lm` | bibliothèque maths (`sqrt`, `pow`) |
| `&& ./prog` | lance seulement si la compilation a réussi |

Exemple avec un programme qui a 2 vrais bugs :

```
$ gcc fuite.c
(rien du tout)

$ crun fuite.c
fuite.c:7:14: warning: conversion from 'int' to 'char' may change value [-Wconversion]
fuite.c:10:13: warning: declaration of 'n' shadows a previous local [-Wshadow]
```

gcc seul compile sans rien dire. Les options de crun trouvent les deux bugs.

### La fonction ligne par ligne (version maison)

```zsh
crun() {
    [ -f "$1" ] || { echo "Usage : crun fichier.c [arguments]"; return 1; }
    local src="$1" bin="${1%.c}"; shift
    $CC ${=CFLAGS} "$src" -o "$bin" ${=LDLIBS} && "./$bin" "$@"
}
```

Avec `crun prog.c 5 7` :

| Morceau | Ce qu'il fait |
|---|---|
| `$1` | 1er argument : `prog.c` |
| `[ -f "$1" ] \|\| { …; return 1; }` | si le fichier n'existe pas : message d'aide et arrêt |
| `local` | variables qui n'existent que dans la fonction |
| `${1%.c}` | `prog.c` sans `.c` → `prog` |
| `shift` | enlève `prog.c`, donc `$@` devient `5 7` |
| `$CC` | `gcc` |
| `${=CFLAGS}` | les options, découpées en mots séparés |
| `&&` | la suite seulement si gcc a réussi |
| `"./$bin" "$@"` | lance `./prog 5 7` |

- **`${=CFLAGS}` et pas `$CFLAGS`** : zsh (contrairement à bash) ne découpe pas une variable aux espaces. Sans le `=`, gcc recevrait `"-std=c11 -Wall …"` comme une seule option et la refuserait.
- **`./prog` et pas `prog`** : le dossier courant n'est pas dans le PATH, exprès (sinon un faux `ls` posé dans un dossier serait lancé à la place du vrai). `./` = « celui d'ici ».

À la fac c'est la même chose, découpé en petites fonctions communes à crun, csan, cmem, cdebug.

### Les limites

1. **Un seul .c à la fois.** Pour plusieurs fichiers : gcc à la main ou `make` (voir partie 3).
2. **À la maison, `CFLAGS` est exporté** : `make` et `./configure` le reprennent tout seuls, donc le Makefile d'un prof qui ne définit pas `CFLAGS` compile avec mes options. À la fac la variable s'appelle `CFLAGS_DEV` et n'est pas exportée, pas ce souci.
3. **Le programme prend le nom du fichier** et écrase un fichier qui s'appellerait déjà comme ça.

⚠️ **En exam** : si le sujet impose une commande (genre `gcc -std=c99 -Wall -Werror`), faire la vérif finale avec **cette** commande. Ses options peuvent refuser un truc que crun accepte (ex : `strdup` sans `-D_DEFAULT_SOURCE`).

### cmem = valgrind (pas mieux, c'est le même)

`cmem prog.c` compile avec les options de crun (dont `-g`, pour avoir les lignes), puis lance :

```sh
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./prog
```

| Option | Effet |
|---|---|
| `--leak-check=full` | détaille chaque fuite avec la ligne du `malloc` |
| `--show-leak-kinds=all` | toutes les sortes de fuites, pas seulement les certaines |
| `--track-origins=yes` | pour une variable lue sans être initialisée : où elle a été créée |

La différence sur un programme qui oublie un `free` :

```
$ valgrind ./fuite
   definitely lost: 40 bytes in 1 blocks
Rerun with --leak-check=full to see details of leaked memory

$ cmem fuite.c
40 bytes in 1 blocks are definitely lost
   at malloc
   by main (fuite.c:8)        ← la ligne du malloc jamais libéré
```

Valgrind seul dit qu'il y a une fuite, avec les options il dit **où**.

### csan ou cmem ?

| | `csan` (AddressSanitizer) | `cmem` (valgrind) |
|---|---|---|
| vitesse | rapide | lent |
| débordement de tableau | ✔ (même ceux que valgrind rate) | parfois |
| variable non initialisée | ✘ | ✔ |
| quand | **le programme plante** | **vérifier les fuites avant de rendre** |

---

## 2. Ce que fait gcc en vrai : 4 étapes

```
prog.c ─► 1. préprocesseur ─► 2. compilation ─► 3. assemblage ─► prog.o ─► 4. édition de liens ─► prog
          colle les #include    C → assembleur     → code machine            + libc (printf…)
          remplace les #define                                               + libm si -lm
```

- `-D_DEFAULT_SOURCE` agit à l'étape 1 (c'est un `#define` en tête de fichier)
- `-std=c11`, les `-W…`, `-g` agissent à l'étape 2
- `-lm` agit à l'étape 4

Voir chaque étape :

```sh
gcc -E prog.c | less     # 1 : stdio.h copié en entier dans mon code
gcc -S prog.c            # 2 : prog.s, mon code en assembleur
gcc -c prog.c            # 3 : prog.o, code machine pas encore complet
gcc prog.o -o prog -lm   # 4 : programme final
```

---

## 3. Mes .h « pas détectés »

En vrai clangd voit un nouveau .h dès que je fais `:w` sur le .c. Le problème vient presque toujours d'une de ces causes, et le message dit laquelle.

**1. Chevrons au lieu de guillemets**
Message : `'outil.h' file not found with <angled> include; use "quotes" instead`

```c
#include <outil.h>   // ✘ chevrons = seulement les dossiers du système
#include "outil.h"   // ✔ guillemets = d'abord à côté du .c
```

`<>` pour le système (`stdio.h`…), `""` pour mes fichiers. Espace c a corrige tout seul.

**2. Le .h est dans un autre dossier**
Message : `'outil.h' file not found` puis `Call to undeclared function 'somme'`.
Si le .h est dans `include/` et le .c dans `src/`, créer `compile_flags.txt` à la racine du projet :

```
-std=c11
-Iinclude
```

Et ajouter `-Iinclude` à gcc. (Les projets `cnew` l'ont déjà, avec `-Isrc`.)

**3. Neovim ne dit rien mais la compilation échoue**
Message de gcc : `undefined reference to 'somme'`.
Le .h ne fait que **déclarer** (« somme existe »), le code est dans `outil.c`. `#include` = simple copier-coller à l'étape 1. Si je ne donne pas `outil.c` à gcc, l'étape 4 ne trouve pas `somme`. Donc **tous les .c** :

```sh
gcc -std=c11 -Wall -Wextra -g main.c outil.c -o prog && ./prog
```

ou `make run` dans un projet `cnew` (compile tous les .c de `src/`).

**Plus rare** : deux .h avec le même `#ifndef OUTIL_H` (souvent après un copier-coller). Le 2e est ignoré en silence. Chaque .h doit avoir son propre nom de garde.

Si l'erreur reste affichée après correction : `:w`, et en dernier recours `:LspRestart`.

---

## 4. Les versions du C

| Version | Ce qui change pour moi |
|---|---|
| C89/C90 | la base. Pas de `//`, variables seulement en début de bloc |
| **C99** | **le gros saut** : `//`, `for (int i = 0; …)`, variables n'importe où, `bool` (`<stdbool.h>`), `int32_t` (`<stdint.h>`), `snprintf` |
| C11 | `gets` supprimé, `_Static_assert`, threads. Presque invisible en TP |
| C17 | seulement des corrections |
| C23 | `bool`/`true`/`false` sans include, `nullptr`, `typeof`, `0b1010`, `1'000'000`, `strdup` standard |

- En `-std=c89`, `//` et `for (int i…)` sont des **erreurs**.
- Entre C99, C11 et C17, un code de TP compile pareil.
- Sans `-std`, gcc 13 (Mint 22) est en `gnu17`.

### Pourquoi `-D_DEFAULT_SOURCE`

Deux standards différents :
- **ISO C** : le langage (`printf`, `malloc`…)
- **POSIX** : le standard Unix (`strdup`, `getline`, `fileno`…)

`-std=c11` = ISO C strict, donc gcc cache POSIX. `strdup` devient « implicit declaration » : gcc croit qu'elle renvoie un `int` (32 bits) au lieu d'un pointeur (64 bits), le pointeur est coupé en deux et **ça plante**. `-D_DEFAULT_SOURCE` remet POSIX.

**Pour moi** : rester en `c11`, en exam compiler avec la version demandée (souvent `c99` ou `c11`), ne pas utiliser de trucs C23.

---

## 5. Ma routine (chaque TP, et l'exam)

1. `mkcd tp5` → `nvim main.c` → `mainn` + Entrée (squelette `int main(void)`)
2. 10 lignes max, puis **Ctrl-S** (ça remet aussi l'indentation). Regarder les signes rouges.
3. **]e** = erreur suivante, **Espace c d** = message complet.
4. **Ctrl-Z** → `crun main.c` → **Ctrl-Z** pour revenir (ensuite **↑** pour relancer).
5. gcc dit `main.c:42:7: error…` → **`:42`** dans Neovim. Toujours lire **la première** erreur.
6. Ne pas retaper les tests : les mettre dans `entree.txt` → `crun main.c < entree.txt`.
   Comparer avec le résultat attendu : `./main < entree.txt | diff - attendu.txt` (rien = identique).
7. **Plantage (segfault)** → `csan main.c`, chercher la première ligne qui cite `main.c:NN`.
8. **Avant de rendre** :
   - `cmem main.c` doit afficher `All heap blocks were freed` et `ERROR SUMMARY: 0 errors`
   - recompiler **avec la commande exacte du sujet**

⚠️ `:!crun %` dans Neovim ne marche **pas** (crun est dans `.zshrc`, que `:!` ne charge pas).

---

## 6. Raccourcis Neovim (Espace = leader)

★ = à connaître en premier

### Bouger et modifier

| Touche | Effet |
|---|---|
| ★ `:42` | aller ligne 42 |
| ★ `u` / `Ctrl-R` | annuler / refaire |
| ★ `dd` `yy` `p` | couper / copier ligne / coller |
| ★ `gcc` | commenter / décommenter (sélection : `V`, `j`…, puis `gc`) |
| `ciw` / `ci(` / `ci"` | remplacer le mot / l'intérieur des `()` / des `""` |
| `.` | refaire la dernière modif |
| `%` | accolade correspondante |
| `*` | chercher le mot sous le curseur (`n` / `N`) |
| `s` + 2 lettres | sauter n'importe où à l'écran |
| `gg` / `G` | début / fin du fichier |
| `:%s/ancien/nouveau/g` | remplacer partout |

### Comprendre le code (clangd)

| Touche | Effet |
|---|---|
| ★ `K` | prototype + doc de la fonction sous le curseur |
| ★ `]e` / `[e` | erreur suivante / précédente |
| ★ `Espace c d` | message d'erreur complet |
| ★ `Espace s M` | page man (`strtok`, `fgets`…) |
| `Ctrl-K` (en écriture) | paramètres attendus |
| `gd` / `gr` | définition / où c'est utilisé |
| `Espace c a` | correction proposée |
| `Espace c r` | renommer partout |
| `Espace c h` | .c ↔ .h |
| `Espace x x` | liste de toutes les erreurs |

### Complétion et modèles (snippets)

- **Entrée** accepte, **Tab** passe au champ suivant du modèle
- `mainn` → `main(void)` · `main` → `main(argc, argv)`
- `#incl` → `#include ""` · `#ifndef` → début de .h
- `printf`, `for`, `while`, `switch`
- `chkmem` → vérifie qu'un `malloc` n'a pas renvoyé NULL

### Fichiers et fenêtres

| Touche | Effet |
|---|---|
| ★ `Ctrl-S` | enregistrer |
| ★ `Espace Espace` | ouvrir un fichier |
| `Shift-H` / `Shift-L` | fichier précédent / suivant |
| `Espace \|` | deux fichiers côte à côte (`Ctrl-H` / `Ctrl-L` pour passer de l'un à l'autre) |
| `Espace /` | chercher un texte dans tout le dossier |
| `Espace p` | historique des copies |
| `Espace q q` | tout quitter |

### Débogueur (seulement si csan et printf ne suffisent pas)

`Espace d b` point d'arrêt · `Espace d c` lancer · `Espace d O` ligne suivante · `Espace d i` entrer dans la fonction · `Espace d o` en sortir · `Espace d t` arrêter

---

## 7. Raccourcis terminal (zsh)

| Touche | Effet |
|---|---|
| ★ `↑` | commande précédente (taper `cr` puis `↑` : seulement celles qui commencent par `cr`) |
| ★ `→` | accepter la suggestion grise |
| ★ `Ctrl-C` | **arrêter un programme** (boucle infinie) |
| ★ `Ctrl-D` | **fin de saisie** quand le programme lit au clavier |
| `Ctrl-R` | chercher dans tout l'historique |
| `Alt-.` | colle le dernier mot de la commande d'avant (`nvim main.c` puis `crun ` + `Alt-.`) |
| `Ctrl-U` / `Ctrl-W` | effacer la ligne / le dernier mot |
| `Ctrl-Shift-C` / `Ctrl-Shift-V` | copier / coller |
| `cd -` | dossier précédent |
| `clear` | effacer l'écran |

- L'historique des commandes est dans `~/.zsh_history`. zsh y écrit chaque commande tout de suite, et il est partagé entre tous mes terminaux.
- Une commande qui commence par **un espace** n'est pas enregistrée.

---

## 8. Disposition de l'écran (3 options à tester cette semaine)

### Option A : sujet à gauche, Neovim à droite, Ctrl-Z pour compiler

- **Super+←** sur le sujet, **Super+→** sur le terminal (Meta à la maison, même touche).
- Ctrl-Z / Ctrl-Z pour aller au shell et revenir.
- Le sujet reste toujours visible.

### Option B : terminal dans Neovim, à droite du code

Par défaut **Ctrl-/** ouvre le terminal en bas. Pour l'avoir à droite (à faire une fois à la fac et une fois à la maison) :

```sh
cat > ~/.config/nvim/lua/plugins/terminal-right.lua <<'EOF'
-- Neovim terminal (Ctrl-/) on the right, 40% of the width
return {
  { "folke/snacks.nvim", opts = { terminal = { win = { position = "right", width = 0.4 } } } },
}
EOF
```

Le script d'installation ne touche jamais ce fichier. Pour revenir en bas : `rm ~/.config/nvim/lua/plugins/terminal-right.lua`. Trop étroit ? Mettre `0.5` au lieu de `0.4`.

| Touche | Effet |
|---|---|
| `Ctrl-/` | ouvrir / cacher le terminal |
| `Ctrl-H` / `Ctrl-L` | aller au code / au terminal |
| `Échap Échap` (vite) | remonter dans un long message (`k`, `Ctrl-U`) |
| `i` | retaper dans le terminal |

⚠️ Dans ce terminal, `Ctrl-L` change de fenêtre au lieu d'effacer : taper `clear`.

Fermer ou cacher :

| Je veux… | Comment | Ce qui reste |
|---|---|---|
| cacher | `Ctrl-/` | tout (le shell continue, l'affichage est gardé) |
| fermer pour de bon | `exit` ou `Ctrl-D` sur une ligne vide | affichage perdu, **historique des commandes gardé** |
| quitter Neovim | `Espace q q` | pareil |

Avec le sujet aussi à l'écran c'est trop serré : terminal en plein écran (double-clic sur la barre de titre) et sujet avec **Alt-Tab**.

### Option C : Neovim à droite, 2 terminaux à gauche

```
┌───────────────┬────────────────────┐
│ Terminal 1    │                    │
│ (compile tout │      Neovim        │
│  seul)        │      (code)        │
├───────────────┤                    │
│ Terminal 2    │                    │
│ (tests, man,  │                    │
│  valgrind)    │                    │
└───────────────┴────────────────────┘
```

| Fenêtre | Touches (Super à la fac, Meta à la maison) |
|---|---|
| Neovim | `Super+→` |
| Terminal 1 | `Super+←` puis `Super+↑` |
| Terminal 2 | `Super+←` puis `Super+↓` |

- Nouvelle fenêtre de terminal : **Ctrl+Shift+N**, puis `j tp5`.
- À la souris : tirer la barre de titre dans un coin de l'écran.

**Terminal 1 : recompile et relance à chaque Ctrl-S dans Neovim**

```sh
watchexec -c -e c,h -- 'gcc -Wall -Wextra -g *.c -o prog && ./prog'
```

`*.c` compile tous les .c du dossier (plus de souci de .h). **Ctrl-C** pour arrêter. Si le programme lit au clavier, mettre `./prog < entree.txt` dans la commande, ou le lancer dans le terminal 2.

**Terminal 2 : tout le reste à la main** (programme qui attend le clavier, `csan`, `cmem`, `man 3 strtok`, `diff`).

Points faibles : changer de fenêtre = souris ou **Alt-Tab** (un seul Alt-Tab = fenêtre précédente), et le sujet est caché derrière (bien le lire au début, noter l'important en commentaire en haut du .c).

**Garder l'option où je vais le plus vite.**

---

## 9. Hors connexion

Tout marche sans internet une fois installé, parce que tout tourne en local : shellcheck, clangd, bashls, débogueur, coloration, `crun`, `gdb` + `dash`, `valgrind`, `make test`, `man`, `tldr`, `cdoc`.

Internet sert seulement à installer ou mettre à jour : `:Lazy update`, `:Mason`, nouveau langage, `tldr --update`, `google mot`. Si un outil manque, une notification rouge peut apparaître au démarrage, sans gravité.

Test à la maison : couper le Wi-Fi, `echo $1` dans un `.sh` (shellcheck doit souligner) et `int x = "a";` dans un `.c` (clangd doit afficher une erreur).

---

## 10. À vérifier avant l'exam

- [ ] `man 3 printf` à la fac. Si « Aucune entrée » : il manque les pages man du C (Espace s M ne trouvera rien, reste `cdoc`).
- [ ] L'exam se passe sur **mon compte habituel** ? (sinon ma config n'y sera pas)
- [ ] La **commande de compilation** demandée dans le sujet.
- [ ] Choisir ma disposition (A, B ou C).
- [ ] Faire un ancien sujet chronométré, Wi-Fi coupé.
- [ ] 5 nouveaux raccourcis par jour, chaque TP sans la souris.
