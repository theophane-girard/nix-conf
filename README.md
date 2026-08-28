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
  desktop.nix             Hyprland, pipewire, greetd, polices, impression/scan, apps
  dev.nix                 docker + docker compose
home/theophane.nix        dotfiles utilisateur (git, zsh, starship, direnv...)
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
