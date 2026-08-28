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
  desktop.nix             Hyprland, pipewire, greetd, polices, apps
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

# genere le vrai hardware-configuration.nix (UUID + modules noyau detectes)
nixos-generate-config --root /mnt --no-filesystems
cp /mnt/etc/nixos/hardware-configuration.nix hosts/nixbox/hardware-configuration.nix
```

`--no-filesystems` garde les `fileSystems` par label deja ecrits ici. Sans ce
flag, le fichier genere contient les UUID reels : c'est tout aussi bien, il
remplace alors integralement le placeholder.

Reajuster ensuite dans `hosts/nixbox/default.nix` :
- `kvm-amd` / `kvm-intel` selon le CPU
- le bloc `boot.initrd.luks.devices` si la racine est chiffree

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
