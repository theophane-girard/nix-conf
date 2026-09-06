# Environnement graphique COTE SYSTEME : session Hyprland, audio, impression,
# scanner, apps. La barre / le launcher / les notifications viennent du shell
# end-4, declare cote utilisateur dans home/illogical-impulse.nix.
{ config, pkgs, username, ... }:

{
  # ---------------------------------------------------------------- compositeur
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Portals (partage d'ecran, file pickers)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ------------------------------------------------------------------- greeter
  services.greetd = {
    enable = true;

    # Autologin AU BOOT uniquement. La session Hyprland demarre sans rien
    # demander, puis QuickShell verrouille l'ecran de lui-meme : les dotfiles
    # ont lock.launchOnStartup = true (Config.qml), qui declenche le verrou des
    # qu'une nouvelle instance Hyprland apparait. Et lock.useHyprlock = false,
    # donc c'est bien l'ecran illogical-impulse -- pas hyprlock -- qui s'affiche
    # et qui reclame le mot de passe.
    #
    # CE QUE CA COUTE : entre le demarrage du compositeur et l'apparition de
    # hyprlock, la session est techniquement ouverte. Si hyprlock plante ou est
    # tue depuis un TTY, le bureau est accessible sans mot de passe. Le greeter,
    # lui, ne laissait pas cette fenetre.
    # A relativiser ici : la racine n'est pas chiffree (LUKS commente dans
    # hosts/nixbox/default.nix), donc un acces physique lit deja le disque.
    # Si tu actives LUKS un jour, reconsidere ce bloc.
    # start-hyprland, PAS Hyprland : depuis la 0.55 le binaire nu affiche
    # "Hyprland was started without start-hyprland" et tourne en mode debug.
    # Le wrapper est ce que lance le hyprland.desktop upstream ; il prepare la
    # session (log, garde-fous, relance propre) avant d'exec le compositeur.
    settings.initial_session = {
      command = "${config.programs.hyprland.package}/bin/start-hyprland";
      user = username;
    };

    # Apres un logout volontaire (pas un reboot), on retombe ici.
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      user = "greeter";
    };
  };

  # ------------------------------------------------- verrouillage d'ecran (PAM)
  # L'ecran de verrouillage II s'authentifie via /etc/pam.d/login, qui existe :
  # rien a faire pour lui.
  #
  # hyprlock reste le PLAN B : hypridle.conf le lance si QuickShell est mort
  # ("pidof qs quickshell hyprlock || hyprlock"). Or hyprlock vient du profil
  # utilisateur, donc rien ne creait /etc/pam.d/hyprlock -- PAM retombait sur
  # /etc/pam.d/other, un pam_deny integral. Le plan B verrouillait l'ecran sans
  # qu'aucun mot de passe ne puisse l'ouvrir. Cette option ecrit la pile PAM.
  programs.hyprlock.enable = true;

  # ------------------------------------------------------ empreinte digitale
  # Lecteur Goodix 27c6:609c du Framework 13, pilote goodixmoc de libfprint.
  # Fournit le demon fprintd + fprintd-enroll / fprintd-list.
  services.fprintd.enable = true;

  # services.fprintd.enable bascule fprintAuth a true sur TOUS les services PAM.
  # Ce n'est pas ce qu'on veut : pam_fprintd s'y insere en "sufficient" AVANT
  # pam_unix, donc chaque saisie de mot de passe commencerait par attendre un
  # doigt. L'ecran de verrouillage II lance deja l'empreinte de son cote, en
  # parallele et avec sa propre pile PAM -- il n'a pas besoin de celle-ci.
  #   login : utilise par l'ecran de verrouillage II pour le mot de passe
  #   sudo  : sinon chaque sudo reclame le doigt avant le mot de passe
  # Mettre l'un des deux a true si tu veux l'empreinte a cet endroit aussi.
  security.pam.services.login.fprintAuth = false;
  security.pam.services.sudo.fprintAuth = false;
  security.pam.services.hyprlock.enableGnomeKeyring = true;

  # --------------------------------------------------------------------- audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  # ------------------------------------------------------------------- polices
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      inter
      jetbrains-mono

      # Polices attendues par le shell end-4.
      #
      # POURQUOI ICI et pas dans home.packages : le script d'activation de
      # illogical-flake fait "rm -rf ~/.config/fontconfig" a chaque switch (ce
      # dossier fait partie de sa liste de recopie). Or c'est exactement la que
      # home-manager ecrit le fragment qui apprend a fontconfig ou trouver
      # /etc/profiles/per-user/<nom>/share/fonts -- ce chemin n'est pas connu
      # de fontconfig par defaut sur NixOS. Le flake installe donc ses polices
      # dans un dossier que fontconfig ne regarde pas, puis efface le fichier
      # qui l'y aurait fait regarder.
      #
      # Symptome : Material Symbols est une police a LIGATURES. Sans elle, le
      # shell affiche le nom de l'icone en clair ("settings", "wifi") au lieu
      # du glyphe.
      #
      # Declarees au niveau systeme, elles atterrissent dans
      # /run/current-system/sw/share/fonts, connu de fontconfig et hors de
      # ~/.config : la recopie ne peut plus rien casser.
      material-symbols
      rubik
      nerd-fonts.jetbrains-mono
      nerd-fonts.ubuntu
      nerd-fonts.ubuntu-mono
      nerd-fonts.caskaydia-cove
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.mononoki
      nerd-fonts.space-mono
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Inter" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # ------------------------------------------------------------------ services
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ydotoold : daemon qui simule des frappes clavier. Plusieurs raccourcis des
  # dotfiles end-4 passent par lui. Le compte doit etre dans le groupe
  # "ydotool" (fait dans modules/users.nix).
  programs.ydotool.enable = true;

  # Geolocalisation : QuickShell l'utilise via QtPositioning (meteo, et
  # hyprsunset qui suit le lever/coucher du soleil). Les dotfiles end-4
  # lancent un agent geoclue au demarrage de la session.
  services.geoclue2.enable = true;

  # mDNS : indispensable pour que l'imprimante et le scanner reseau
  # soient decouverts tout seuls.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ---------------------------------------------------------- impression + scan
  services.printing = {
    enable = true;
    drivers = with pkgs; [ gutenprint ];
  };

  hardware.sane = {
    enable = true;
    # sane-airscan = protocoles eSCL (AirScan) et WSD : couvre la grande
    # majorite des scanners reseau recents sans driver proprietaire.
    extraBackends = [ pkgs.sane-airscan ];
    # Ouvre le port 8612 (BJNP), utilise par la decouverte des Canon.
    openFirewall = true;
  };

  # Si le scanner reseau n'est pas trouve tout seul (mDNS capricieux), coder
  # son URL eSCL en dur : REMPLACER le bloc hardware.sane.extraBackends ci-dessus
  # par celui-ci (ne pas le dupliquer). Ce fichier surcharge
  # celui fourni par sane-airscan car extraBackends est applique en dernier.
  #
  # hardware.sane.extraBackends = [
  #   pkgs.sane-airscan
  #   (pkgs.writeTextFile {
  #     name = "airscan-manual";
  #     destination = "/etc/sane.d/airscan.conf";
  #     text = ''
  #       [devices]
  #       "Canon TS6300" = http://192.168.1.29/eSCL/
  #     '';
  #   })
  # ];

  # ----------------------------------------------------------- apps graphiques
  environment.systemPackages = with pkgs; [
    # services.fprintd.enable ne met PAS fprintd dans le PATH systeme, or il
    # faut que /run/current-system/sw/lib/security/pam_fprintd.so existe :
    # c'est le chemin que reference pam/fprintd.conf dans les dotfiles, le seul
    # stable a travers les generations. Fournit aussi fprintd-enroll / -list.
    fprintd

    # Hyprland toolkit
    #
    # Presque vide, et c'est voulu : le shell end-4 installe tout son outillage
    # dans le profil UTILISATEUR (home/illogical-impulse.nix). Le dupliquer ici
    # ferait tourner deux barres et deux daemons de notification.
    #
    # Pour revenir a un Hyprland nu : commenter l'import de
    # home/illogical-impulse.nix dans home/theophane.nix, remettre
    # programs.starship.enable dans ce meme fichier, et decommenter la liste
    # ci-dessous.
    #
    #   waybar         # barre           -> QuickShell
    #   wofi           # launcher        -> fuzzel
    #   mako           # notifications   -> QuickShell
    #   hyprpaper      # fond d'ecran    -> swww
    #   hyprlock hypridle kitty
    #   grim slurp swappy      # captures -> hyprshot / slurp / swappy
    #   wl-clipboard cliphist
    #   brightnessctl playerctl pavucontrol

    nautilus

    # Navigateurs
    firefox
    google-chrome

    # Multimedia
    spotify

    # VPN
    # L'appli fournit le GUI et la commande protonvpn. Elle pilote les
    # tunnels via NetworkManager (active dans modules/base.nix) : sans lui,
    # la connexion echoue au moment de monter l'interface.
    proton-vpn

    # BitTorrent
    # Le GUI Qt. Pour une seedbox sans session graphique, ce serait
    # qbittorrent-nox + services.qbittorrent : ce n'est pas l'usage ici.
    qbittorrent

    # Scan (GUI simple : detecte les backends SANE ci-dessus)
    simple-scan
  ];
}
