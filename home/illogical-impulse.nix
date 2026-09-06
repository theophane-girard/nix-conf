# Shell Hyprland "illogical impulse" (end-4 / QuickShell), portage NixOS :
#   https://github.com/soymou/illogical-flake
# qui suit en amont direct https://github.com/end-4/dots-hyprland
#
# C'est un module HOME-MANAGER, pas un module NixOS. Il ne touche PAS a la
# session Hyprland elle-meme : c'est modules/desktop.nix (programs.hyprland)
# qui reste patron. Ce module se contente de deux choses :
#   - installer dans le profil utilisateur QuickShell (wrappe avec les bons
#     chemins QML/Qt) et sa centaine de dependances ;
#   - recopier les dotfiles end-4 dans ~/.config a chaque switch.
#
# ATTENTION, la recopie est destructive : a CHAQUE nixos-rebuild switch, ces
# entrees de ~/.config sont supprimees puis reecrites depuis le depot amont.
#
#   Kvantum  chrome-flags.conf  code-flags.conf  darklyrc  dolphinrc  fish
#   fontconfig  foot  fuzzel  hypr  kde-material-you-colors  kdeglobals
#   kitty  matugen  mpv  quickshell  starship.toml  thorium-flags.conf
#   wlogout  xdg-desktop-portal  zshrc.d
#
# Toute retouche manuelle dans ces dossiers est perdue au switch suivant : les
# personnalisations vont dans ~/.config/hypr/custom/*.lua (non ecrase, sauf
# env.lua et general.lua que le module regenere) ou dans
# ~/.config/illogical-impulse/config.json (cree une seule fois, jamais ecrase).
# ~/.config/nvim n'est PAS dans la liste : LazyVim n'est pas concerne.
{ inputs, lib, pkgs, ... }:

let
  # Fichiers que matugen genere DANS les dossiers effaces par la recopie
  # end-4 (voir le hook de sauvegarde plus bas). Chemins relatifs a ~/.config.
  matugenGenerated = [
    "hypr/hyprland/colors.lua"   # bordures de fenetres, couleur de fond
    "hypr/hyprlock/colors.conf"  # ecran de verrouillage
    "fuzzel/fuzzel_theme.ini"    # launcher
  ];

  colorBackupDir = "$HOME/.cache/hm-matugen-colors";
in
{
  imports = [ inputs.illogical-flake.homeManagerModules.default ];

  programs.illogical-impulse = {
    enable = true;

    dotfiles = {
      kitty.enable = true;

      # Obligatoire : le kitty.conf de end-4 contient "shell fish". Sans fish
      # installe, le terminal ne s'ouvre plus. fish ne devient PAS le shell de
      # connexion pour autant : zsh reste celui de modules/users.nix, fish ne
      # tourne qu'a l'interieur de kitty.
      fish.enable = true;

      # Prompt starship fourni par end-4. C'est pour ca que programs.starship
      # a ete retire de home/theophane.nix : les deux ecrivent
      # ~/.config/starship.toml, et la recopie ci-dessus gagnerait en silence.
      starship.enable = true;
    };
  };

  # Les couleurs du theme sont generees par matugen, mais ses fichiers de
  # sortie atterrissent DANS les dossiers que la recopie efface, et le depot
  # dotfiles en contient un instantane fige. Sans ce hook, chaque switch
  # reinstalle donc la palette d'un ancien fond d'ecran, et le reload qui suit
  # l'applique : les bordures de fenetres, hyprlock et fuzzel repartent sur de
  # vieilles couleurs, alors que QuickShell garde les bonnes (les siennes
  # vivent dans ~/.local/state, hors de la recopie).
  # On sauve donc ces fichiers avant la copie ; la restauration se fait dans le
  # hook de reload ci-dessous, pour garantir l'ordre (deux entryAfter sur la
  # meme dependance ne sont pas ordonnes entre eux).
  home.activation.saveMatugenColorsBeforeDotfiles =
    lib.hm.dag.entryBefore [ "copyIllogicalImpulseConfigs" ] ''
      for rel in ${lib.concatStringsSep " " matugenGenerated}; do
        [ -f "$HOME/.config/$rel" ] || continue
        run mkdir -p "$(dirname "${colorBackupDir}/$rel")"
        run cp -a "$HOME/.config/$rel" "${colorBackupDir}/$rel"
      done
    '';

  # La recopie ci-dessus est un "rm -rf" suivi d'un "cp -r" (voir
  # copyIllogicalImpulseConfigs dans le module amont). Or Hyprland surveille sa
  # config et la recharge des qu'elle bouge : quand le switch est lance DEPUIS
  # une session Hyprland, le rechargement tombe dans la fenetre ou
  # ~/.config/hypr n'existe plus. Resultat : "cannot open hyprland.lua", aucun
  # bind enregistre, et le compositeur bascule en emergency mode -- il ne reste
  # que Super+Q, Super+R et Super+M. Le fichier est pourtant intact une fois la
  # copie finie ; il suffit de recharger apres coup.
  # Sans effet si aucune session ne tourne (boot, ou rebuild depuis un TTY) :
  # la boucle ne trouve alors aucune socket.
  home.activation.reloadHyprlandAfterDotfiles =
    lib.hm.dag.entryAfter [ "copyIllogicalImpulseConfigs" ] ''
      # Remet les couleurs matugen sauvees juste avant la copie, sinon le
      # reload qui suit applique l'instantane fige du depot.
      for rel in ${lib.concatStringsSep " " matugenGenerated}; do
        [ -f "${colorBackupDir}/$rel" ] || continue
        run cp -a "${colorBackupDir}/$rel" "$HOME/.config/$rel"
      done

      for instanceDir in /run/user/$UID/hypr/*/; do
        [ -S "$instanceDir/.socket.sock" ] || continue
        export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$instanceDir")"
        run ${pkgs.hyprland}/bin/hyprctl reload || true
      done
    '';

  # Le fichier hypr/hyprland/execs.lua de end-4 lance
  # "hyprctl setcursor Bibata-Modern-Classic 24" au demarrage, mais aucun des
  # deux depots ne fournit le theme. Sans ce bloc : curseur par defaut, souvent
  # invisible sous XWayland.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
