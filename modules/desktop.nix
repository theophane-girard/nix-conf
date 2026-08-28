# Environnement graphique : Hyprland, audio, impression, scanner, apps.
{ pkgs, ... }:

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
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      user = "greeter";
    };
  };

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
      nerd-fonts.jetbrains-mono
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
    # Hyprland toolkit
    waybar
    wofi
    hyprpaper
    hyprlock
    hypridle
    grim
    slurp
    swappy
    wl-clipboard
    cliphist
    mako
    brightnessctl
    playerctl
    pavucontrol
    nautilus
    kitty

    # Navigateurs
    firefox
    google-chrome

    # Multimedia
    spotify

    # Scan (GUI simple : detecte les backends SANE ci-dessus)
    simple-scan
  ];
}
