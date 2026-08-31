# Shell Hyprland "illogical impulse" (end-4 / QuickShell), portage NixOS :
#   https://github.com/xBLACKICEx/end-4-dots-hyprland-nixos
#
# C'est un module HOME-MANAGER, pas un module NixOS : il pose les dotfiles dans
# ~/.config (hypr/, quickshell/, matugen/, kitty/...) et installe dans le profil
# utilisateur la centaine de paquets dont la barre QuickShell a besoin.
#
# Il declare lui-meme wayland.windowManager.hyprland ; la partie systeme
# (session graphique, portals, polkit) reste dans modules/desktop.nix.
{ inputs, lib, pkgs, ... }:

{
  imports = [ inputs.illogical-impulse.homeManagerModules.default ];

  illogical-impulse = {
    enable = true;

    hyprland = {
      # ",preferred,auto,1" = tous les ecrans, definition preferee, pas de mise
      # a l'echelle. Ecran HiDPI : [ "eDP-1,preferred,auto,1.5" ].
      # Lister les noms d'ecrans une fois sous Hyprland : hyprctl monitors
      monitor = [ ",preferred,auto,1" ];

      # NIXOS_OZONE_WL=1 : Chrome / VSCode / Electron en Wayland natif
      # (sinon flou sur ecran HiDPI et pas de partage d'ecran).
      ozoneWayland.enable = true;

      # package / xdgPortalPackage laisses par defaut : ce sont pkgs.hyprland et
      # pkgs.xdg-desktop-portal-hyprland de nixpkgs 26.05, donc exactement les
      # memes derivations que celles activees par programs.hyprland dans
      # modules/desktop.nix. Pas de doublon reel.
    };

    dotfiles = {
      kitty.enable = true;

      # Laisse a false : programs.starship (home/theophane.nix) ecrit deja
      # ~/.config/starship.toml, activer celui-ci = collision home-manager.
      starship.enable = false;

      # Le shell de connexion est zsh (modules/users.nix), pas fish.
      fish.enable = false;
    };
  };

  # Le module amont pose systemd.enable = false. Sans la cible systemd
  # "hyprland-session.target", les services utilisateur declares par
  # home-manager (hypridle, gammastep, applet NetworkManager) ne demarrent
  # jamais. Repasser a false si Hyprland se comporte bizarrement au demarrage.
  wayland.windowManager.hyprland.systemd.enable = lib.mkForce true;

  # Curseur : les dotfiles end-4 attendent Bibata. Sans ce bloc le curseur
  # bascule sur le theme par defaut, souvent invisible sous XWayland.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
