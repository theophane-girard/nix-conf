# nix-conf

Configuration NixOS declarative (flake + home-manager), pensee pour etre clonee
depuis l'installeur puis reutilisee au quotidien.

```
flake.nix                 entrees (nixpkgs 26.05, home-manager) + liste des machines
hosts/nixbox/
  default.nix             bootloader, LUKS, packages propres a la machine, stateVersion
  hardware-configuration.nix   PLACEHOLDER -> a remplacer pendant l'install
modules/
  base.nix                nix/flakes, locale FR, reseau, outils CLI
  users.nix               compte utilisateur, groupes, sudo
  desktop.nix             session Hyprland, pipewire, greetd, polices, impression/scan, apps
  dev.nix                 docker + docker compose
home/theophane.nix        dotfiles utilisateur (git, zsh, starship, direnv...)
home/illogical-impulse.nix   shell Hyprland end-4 / QuickShell (barre, launcher, theming)
```

## Avant de partir : pousser le depot

```bash
cd ~/Documents/nix-conf
git init && git add -A && git commit -m "init nixos config"
git remote add origin <url>
git push -u origin main
```

Un flake ne voit que les fichiers **suivis par git** : apres chaque nouveau
fichier, `git add` avant de rebuild.

## Installation sur la machine cible

### 1. Booter la cle, partitionner

```bash
# clavier azerty dans le live
loadkeys fr

# exemple GPT UEFI sur /dev/nvme0n1 (ADAPTER LE DISQUE)
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1GB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root ext4 1GB 100%

# les LABELS comptent : le placeholder hardware-configuration.nix s'appuie dessus
mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
```

### 2. Reseau

```bash
nmtui        # wifi
# ou rien a faire en ethernet
```

### 3. Recuperer la config + le hardware reel

```bash
nix-shell -p git   # si git absent de l'ISO

git clone <url-du-depot> /mnt/etc/nixos
cd /mnt/etc/nixos

# genere le vrai hardware-configuration.nix, directement au bon endroit
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/etc/nixos/hosts/nixbox/hardware-configuration.nix
```

`--show-hardware-config` ecrit sur la sortie standard : rien ne traine dans le
depot, contrairement a `nixos-generate-config --root /mnt` qui deposerait aussi
un `configuration.nix` inutile a la racine.

Le fichier genere remplace integralement le placeholder : UUID reels, modules
noyau detectes, et l'entree `boot.initrd.luks.devices` si la racine est
chiffree (elle est detectee automatiquement -- laisser dans ce cas le bloc LUKS
de `hosts/nixbox/default.nix` COMMENTE, sinon l'option est definie deux fois).

Relire le fichier genere : verifier `kvm-amd` / `kvm-intel` selon le CPU, et la
presence d'un bloc `fileSystems` pour `/` et `/boot` (s'il manque, c'est que
tout n'etait pas monte au moment de la generation).

```bash
git add -A   # obligatoire, sinon le flake ignore le nouveau fichier
```

### 4. Installer

```bash
nixos-install --flake /mnt/etc/nixos#nixbox
# si nix rale sur les flakes :
#   nixos-install --extra-experimental-features 'nix-command flakes' --flake /mnt/etc/nixos#nixbox

reboot
```

Login : utilisateur `theophane`, mot de passe `changeme` (defini dans
`modules/users.nix`) -> le changer immediatement avec `passwd`.

## Premier boot : recaler le depot

A l'install le depot atterrit dans `/etc/nixos`, qui appartient a root, alors que
les alias `nrs`/`nrt`/`nfu` pointent vers `~/Documents/nix-conf`. Une seule fois :

```bash
sudo cp -r /etc/nixos ~/Documents/nix-conf
sudo chown -R $USER:users ~/Documents/nix-conf
cd ~/Documents/nix-conf

# pousser le hardware-configuration.nix genere pendant l'install
git add -A && git commit -m "hardware: nixbox" && git push
```

Ensuite `/etc/nixos` ne sert plus : avec les flakes c'est `--flake <chemin>` qui
decide. Mettre a jour la machine depuis le depot :

```bash
cd ~/Documents/nix-conf && git pull && nrs
```

Toujours `git pull` AVANT `nrs` : sans ca tu reconstruis l'ancienne version sans
aucun message d'erreur.

## Au quotidien

```bash
sudo nixos-rebuild switch --flake ~/Documents/nix-conf   # alias: nrs
sudo nixos-rebuild test   --flake ~/Documents/nix-conf   # alias: nrt, sans persister
nix flake update          --flake ~/Documents/nix-conf   # alias: nfu
sudo nixos-rebuild switch --rollback
```

Ou ajouter un package :

| Portee | Fichier |
| --- | --- |
| toutes les machines | `modules/base.nix` |
| cette machine seulement | `hosts/nixbox/default.nix` |
| apps graphiques | `modules/desktop.nix` |
| utilisateur (pas besoin de sudo) | `home/theophane.nix` |

Chercher un nom de package : `nix search nixpkgs <terme>` ou search.nixos.org.

## Ajouter une machine

```bash
cp -r hosts/nixbox hosts/<nom>
```
puis declarer l'entree dans `flake.nix` (`nixosConfigurations.<nom> = mkHost {...}`).


## Shell Hyprland end-4 (illogical impulse)

La barre, le launcher, le centre de notifications, l'ecran de verrouillage et le
theming Material You viennent de
[soymou/illogical-flake](https://github.com/soymou/illogical-flake), portage
NixOS de [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
(variante QuickShell, pas AGS).

### Comment c'est branche

| Ou | Quoi |
| --- | --- |
| `flake.nix` | input `illogical-flake`, avec `inputs.nixpkgs.follows = "nixpkgs"` |
| `flake.nix` | `inputs` passe a home-manager via `extraSpecialArgs` |
| `home/illogical-impulse.nix` | import du module + options (`enable`, `dotfiles.*`), theme de curseur |
| `home/theophane.nix` | importe le fichier ci-dessus ; `programs.starship` retire |
| `modules/desktop.nix` | garde la partie SYSTEME (session Hyprland, portals, audio) ; `ydotoold` + `geoclue2` ajoutes ; outillage Hyprland retire (fourni cote utilisateur) |
| `modules/users.nix` | groupe `ydotool` |

Le module est un module **home-manager**, et il ne declare pas
`wayland.windowManager.hyprland` : la session Hyprland reste celle de
`programs.hyprland` dans `modules/desktop.nix`. Une seule source de verite.

### Le piege principal : la recopie destructive

A **chaque** `nixos-rebuild switch`, un script d'activation supprime puis
recopie ces entrees de `~/.config` depuis le depot amont :

```
Kvantum  chrome-flags.conf  code-flags.conf  darklyrc  dolphinrc  fish
fontconfig  foot  fuzzel  hypr  kde-material-you-colors  kdeglobals  kitty
matugen  mpv  quickshell  starship.toml  thorium-flags.conf  wlogout
xdg-desktop-portal  zshrc.d
```

Consequences :

- **Ne jamais editer ces dossiers a la main**, le switch suivant efface tout.
  Les personnalisations vont dans `~/.config/hypr/custom/*.lua` (preserve, sauf
  `env.lua` et `general.lua` que le module regenere) et dans
  `~/.config/illogical-impulse/config.json` (cree une seule fois, jamais
  ecrase ensuite).
- `~/.config/nvim` n'est **pas** dans la liste : LazyVim n'est pas concerne.
- `programs.starship` a ete retire de `home/theophane.nix` : c'est le prompt de
  end-4 qui gagne, et le declarer des deux cotes revenait a voir sa propre
  config disparaitre sans message d'erreur.

### Polices : pourquoi elles sont declarees cote systeme

Symptome sans ce correctif : le shell affiche `settings`, `wifi`, `volume_up`
en toutes lettres a la place des icones. Material Symbols est une police a
**ligatures** -- si elle est absente, le nom de l'icone s'affiche tel quel.

Cause : `fontconfig` fait partie des dossiers que le script d'activation
recopie, donc il fait `rm -rf ~/.config/fontconfig` a **chaque** switch. Or
c'est precisement la que home-manager ecrit le fragment
`conf.d/<prio>-hm-<label>.conf` qui apprend a fontconfig ou trouver
`/etc/profiles/per-user/<nom>/share/fonts` -- un chemin que fontconfig ne
connait pas par defaut sur NixOS (c'est ecrit noir sur blanc dans le source de
home-manager, `modules/misc/fontconfig.nix`). Le flake installe donc ses
polices dans un dossier invisible, puis efface le fichier qui l'aurait rendu
visible.

Correctif : declarer les polices dans `fonts.packages` (`modules/desktop.nix`).
Elles atterrissent dans `/run/current-system/sw/share/fonts`, connu de
fontconfig et hors de `~/.config` : la recopie ne peut plus rien casser. C'est
d'ailleurs ce que recommande le README du flake amont.

**Reste non resolu :** la police d'interface `gabarito` n'existe pas dans
nixpkgs, elle vient de NUR (`nurPkgs.repos.skiletro.gabarito`) et donc du
profil utilisateur -- elle reste invisible. Consequence purement cosmetique :
repli sur la sans-serif par defaut. Pour la recuperer il faudrait ajouter NUR
en input de ce flake et la mettre dans `fonts.packages`.

Verifier apres un switch :

```bash
fc-list | grep -i "material symbols"   # doit renvoyer au moins une ligne
```

### Choix a connaitre

- **`dotfiles.fish.enable` doit rester a `true`.** Le `kitty.conf` de end-4
  contient `shell fish` : sans fish installe, le terminal ne s'ouvre plus. Ca
  ne change pas le shell de connexion, qui reste zsh (`modules/users.nix`).
- **Le curseur est ajoute par nous.** `hypr/hyprland/execs.lua` lance
  `hyprctl setcursor Bibata-Modern-Classic 24` mais aucun des deux depots ne
  fournit le paquet : d'ou le bloc `home.pointerCursor` avec
  `pkgs.bibata-cursors`.
- **Les dotfiles sont epingles par le mainteneur amont**, pas par nous. C'est
  volontaire : `quickshell` et les dotfiles doivent avancer ensemble.
  `nix flake update illogical-flake` fait avancer les deux d'un coup.

### Reglage de l'ecran

Il ne passe plus par une option Nix : la config Hyprland est en Lua.
Editer `~/.config/hypr/custom/variables.lua` (preserve entre les switch), ou
`hyprctl keyword monitor ...` pour tester a chaud. Noms des ecrans :
`hyprctl monitors`.

### Mises a jour : qui bouge, quand, et comment revenir

Les trois composants ne viennent pas du meme endroit.

| Composant | Source | Comment le faire monter |
| --- | --- | --- |
| Hyprland | `nixpkgs` (branche stable) | changer `nixos-26.05` en `nixos-26.11` dans `flake.nix` -- tous les 6 mois |
| QuickShell | input de `illogical-flake` | `nix flake update illogical-flake` |
| dotfiles end-4 | input de `illogical-flake` | idem -- les deux avancent **ensemble**, c'est voulu |

Hyprland reste sur 0.55.x tant qu'on est sur `nixos-26.05` : une branche stable
recoit des correctifs, pas de montees de version majeures. `nix flake update`
n'y changera rien.

QuickShell et les dotfiles sont epingles ensemble par le mainteneur amont, et
c'est une bonne chose : ces deux-la doivent etre d'accord entre eux, sinon
l'interface casse sans message d'erreur.

**Point de friction a connaitre :** a cause du `inputs.nixpkgs.follows`,
QuickShell se compile contre notre nixpkgs 26.05. Si une version future exige
un Qt plus recent, la compilation echouera -- il faudra alors rester sur
l'ancienne version, ou attendre le passage a `nixos-26.11`.

### Regle : une seule chose a la fois

Eviter `nfu` (`nix flake update` sans argument), qui fait tout bouger d'un coup :
quand ca casse, on ne sait pas quoi accuser.

```bash
nix flake update illogical-flake --flake ~/Documents/nix-conf
nrt                              # tester sans persister au boot
# si ca marche : git commit flake.lock, puis nrs
```

Revenir en arriere sur une mise a jour ratee :

```bash
git checkout HEAD~1 flake.lock && nrs
```

`flake.lock` etant suivi par git, on revient a l'etat d'avant aux memes octets
pres. Et si le systeme ne boote plus, le menu de demarrage garde les 10
generations precedentes.

**Le seul angle mort :** `~/.config/illogical-impulse/config.json` n'est cree
qu'une fois et jamais reecrit. Apres une grosse mise a jour des dotfiles, un
fichier perime peut ne plus correspondre au nouveau shell -- et revenir sur le
`flake.lock` ne le repare pas. Le supprimer force sa recreation au switch
suivant.

### Quand ca casse a l'evaluation

```bash
# 1. lire le nom du paquet fautif dans le message d'erreur
nix search nixpkgs <nom>

# 2. le probleme est peut-etre deja corrige en amont
nix flake update illogical-flake --flake ~/Documents/nix-conf

# 3. repli : commenter ./illogical-impulse.nix dans home/theophane.nix,
#    remettre programs.starship.enable = true, et decommenter la liste de
#    paquets Hyprland dans modules/desktop.nix
```

Un `nixos-rebuild switch` qui echoue ne casse rien : le systeme actuel continue
de tourner, seul le nouveau profil n'est pas cree. Et si le nouveau systeme
boote mal, le menu de demarrage garde les 10 generations precedentes.

## Node / versions par projet

Pas de nvm : sous NixOS on epingle l'environnement **par projet** avec direnv
(deja active). Dans un depot :

```bash
cat > .envrc <<'EOF'
use flake
EOF

cat > flake.nix <<'EOF'
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs_22 pkgs.pnpm ];
      };
    };
}
EOF

direnv allow
```

En entrant dans le dossier, la bonne version de Node est dans le PATH ; en
sortant, elle disparait. Le `nodejs_24` de `home/theophane.nix` ne sert que de
repli pour les scripts hors projet.

Pour une version de Node absente de nixpkgs 26.05, pointer un autre commit de
nixpkgs dans les inputs du flake du projet (voir lazamar.co.uk/nix-versions).

## Neovim / LazyVim

Le premier `nixos-rebuild switch` clone le starter LazyVim dans `~/.config/nvim`
s'il n'existe pas. Ensuite ce dossier est a toi : LazyVim gere ses propres
plugins (`:Lazy`), home-manager n'y touche plus. Pour repartir de zero :

```bash
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim
nrs   # re-clone le starter
```

## Scanner

`hardware.sane` + `sane-airscan` couvrent les scanners reseau en eSCL/WSD, et
avahi assure la decouverte mDNS. Verifier :

```bash
scanimage -L        # liste les scanners vus
simple-scan         # GUI
```

Si le scanner reseau n'apparait pas, decommenter le bloc `airscan-manual` dans
`modules/desktop.nix` pour coder son URL eSCL en dur.
