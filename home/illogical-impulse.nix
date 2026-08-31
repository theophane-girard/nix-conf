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
{ inputs, pkgs, ... }:

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
