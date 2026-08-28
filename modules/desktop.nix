# Environnement graphique : Hyprland + Wayland + audio.
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
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
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

  # --------------------------------------------------------------------- polices
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-emoji
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

  # ------------------------------------------------------------------- services
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

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

    # Navigateur
    firefox
  ];
}
