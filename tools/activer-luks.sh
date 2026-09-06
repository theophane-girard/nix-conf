#!/usr/bin/env bash
# Active le bloc boot.initrd.luks dans hosts/nixbox/default.nix en y injectant
# l'UUID reel du conteneur LUKS.
#
# A LANCER DEPUIS LE CHROOT (nixos-enter), APRES le chiffrement et AVANT le
# premier reboot. Lance avant le chiffrement, il refuse de tourner.
#
# Ne depend que de blkid (util-linux), present sur le systeme actuel.
# cryptsetup, lui, n'y est pas : ne l'appelle pas ici.
#
# Procedure complete, depuis une cle USB NixOS :
#   e2fsck -f /dev/nvme0n1p2
#   resize2fs /dev/nvme0n1p2 900G          # marge large, la fin du FS est vide
#   cryptsetup reencrypt --encrypt --reduce-device-size 32M --type luks2 /dev/nvme0n1p2
#   cryptsetup open /dev/nvme0n1p2 cryptroot
#   resize2fs /dev/mapper/cryptroot        # regrossit pour remplir le conteneur
#   mount /dev/mapper/cryptroot /mnt && mount /dev/nvme0n1p1 /mnt/boot
#   nixos-enter --root /mnt
#     /etc/nixos/tools/activer-luks.sh
#     nixos-rebuild boot --flake /etc/nixos#nixbox
#   exit && reboot

set -euo pipefail

PART=${1:-/dev/nvme0n1p2}
CFG=/etc/nixos/hosts/nixbox/default.nix
PLACEHOLDER=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

[ "$(id -u)" -eq 0 ] || { echo "ERREUR: a lancer en root." >&2; exit 1; }
[ -f "$CFG" ] || { echo "ERREUR: $CFG introuvable." >&2; exit 1; }
command -v blkid >/dev/null || { echo "ERREUR: blkid introuvable." >&2; exit 1; }

TYPE=$(blkid -s TYPE -o value "$PART" 2>/dev/null || true)
if [ "$TYPE" != "crypto_LUKS" ]; then
  echo "ERREUR: $PART est de type '${TYPE:-inconnu}', pas crypto_LUKS." >&2
  echo "Chiffre le disque AVANT de lancer ce script (voir l'entete)." >&2
  exit 1
fi

if grep -qE '^[[:space:]]*boot\.initrd\.luks\.devices' "$CFG"; then
  echo "Le bloc LUKS est deja actif dans $CFG. Rien a faire."
  exit 0
fi

grep -q "$PLACEHOLDER" "$CFG" || {
  echo "ERREUR: bloc LUKS commente introuvable dans $CFG." >&2
  echo "Le fichier a change, edite-le a la main." >&2
  exit 1
}

UUID=$(blkid -s UUID -o value "$PART")
[ -n "$UUID" ] || { echo "ERREUR: UUID introuvable sur $PART." >&2; exit 1; }
echo "Conteneur LUKS $PART -> UUID $UUID"

cp -a "$CFG" "$CFG.avant-luks"

sed -i \
  -e "/# boot\.initrd\.luks\.devices/,/# };/{ s|^  # |  |; s|$PLACEHOLDER|$UUID|; }" \
  -e "s|^  # Racine chiffree LUKS : decommenter et coller l'UUID de la partition|  # Racine chiffree LUKS. UUID du conteneur (pas celui du mapper) :|" \
  -e "s|^  # \*chiffree\* (pas celle du mapper) -> blkid /dev/nvme0n1p2|  #   blkid /dev/nvme0n1p2|" \
  "$CFG"

if command -v nix-instantiate >/dev/null && ! nix-instantiate --parse "$CFG" >/dev/null 2>&1; then
  echo "ERREUR: syntaxe nix invalide apres modification. Restauration." >&2
  mv "$CFG.avant-luks" "$CFG"
  exit 1
fi

echo "--- diff ---"
diff -u "$CFG.avant-luks" "$CFG" || true
echo
echo "OK. Sauvegarde : $CFG.avant-luks"
echo "Etape suivante : nixos-rebuild boot --flake /etc/nixos#nixbox"
