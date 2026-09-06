#!/usr/bin/env bash
# Calcule resume_offset -- la position physique de /swapfile dans l'ext4 -- et
# l'injecte dans hosts/nixbox/default.nix.
#
# A RELANCER si le swapfile est recree (taille changee, reinstallation,
# restauration de sauvegarde) : l'offset devient faux et le reveil echoue
# SILENCIEUSEMENT. Le systeme redemarre a froid, la session est perdue.
#
# Enchainement complet :
#   1. nrs                          -> NixOS cree /swapfile (34 Gio, un moment)
#   2. sudo /etc/nixos/tools/resume-offset.sh
#   3. nrs                          -> l'offset entre dans les parametres kernel
#   4. systemctl hibernate          -> test

set -euo pipefail

SWAP=${1:-/swapfile}
CFG=/etc/nixos/hosts/nixbox/default.nix

[ "$(id -u)" -eq 0 ] || { echo "ERREUR: a lancer en root (filefrag lit un fichier en 0600)." >&2; exit 1; }
[ -f "$CFG" ]  || { echo "ERREUR: $CFG introuvable." >&2; exit 1; }
[ -f "$SWAP" ] || { echo "ERREUR: $SWAP absent. Lance 'nrs' d'abord, NixOS le creera." >&2; exit 1; }
command -v filefrag >/dev/null || { echo "ERREUR: filefrag introuvable (e2fsprogs)." >&2; exit 1; }

sync   # sans ca les extents peuvent etre en delalloc et l'offset sortir a 0

OFFSET=$(filefrag -v "$SWAP" | awk '/^[[:space:]]*0:/ {gsub(/\.\./,"",$4); print $4; exit}')
[[ "$OFFSET" =~ ^[0-9]+$ ]] || { echo "ERREUR: offset illisible ('$OFFSET')." >&2; exit 1; }
[ "$OFFSET" -gt 0 ] || { echo "ERREUR: offset nul -- $SWAP n'est pas alloue sur le disque." >&2; exit 1; }
echo "$SWAP -> resume_offset = $OFFSET"

cp -a "$CFG" "$CFG.avant-offset"

if grep -qE '^[[:space:]]*boot\.kernelParams.*resume_offset=' "$CFG"; then
  sed -i -E "s|resume_offset=[0-9]+|resume_offset=$OFFSET|" "$CFG"
  echo "  (offset precedent remplace)"
else
  sed -i "s|^  # boot\\.kernelParams = \\[ \"resume_offset=XXXXXXXX\" \\];\$|  boot.kernelParams = [ \"resume_offset=$OFFSET\" ];|" "$CFG"
fi

if ! grep -qE '^[[:space:]]*boot\.kernelParams.*resume_offset=' "$CFG"; then
  echo "ERREUR: injection ratee, le gabarit a disparu du fichier. Restauration." >&2
  mv "$CFG.avant-offset" "$CFG"; exit 1
fi

if command -v nix-instantiate >/dev/null && ! nix-instantiate --parse "$CFG" >/dev/null 2>&1; then
  echo "ERREUR: syntaxe nix invalide apres modification. Restauration." >&2
  mv "$CFG.avant-offset" "$CFG"; exit 1
fi

echo "--- diff ---"
diff -u "$CFG.avant-offset" "$CFG" || true
echo
echo "OK. Sauvegarde : $CFG.avant-offset"
echo "Etape suivante : nrs, puis 'systemctl hibernate' pour tester."
