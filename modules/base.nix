# Socle commun a toutes les machines : nix, locale, reseau, outils CLI.
{ pkgs, lib, ... }:

{
  # ----------------------------------------------------------------- nix / nixpkgs
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
  };

  # Ramasse-miettes hebdo + compaction du store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  # ------------------------------------------------------------- locale / clavier
  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  console.keyMap = "fr"; # TTY
  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  # ------------------------------------------------------------------- reseau
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # --------------------------------------------------------------------- divers
  services.fwupd.enable = true; # mises a jour firmware
  zramSwap.enable = true;

  # Sortie de veille / hibernation propre sur portable
  services.upower.enable = true;

  # ----------------------------------------------------------- outils de base
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    htop
    btop
    tree
    unzip
    p7zip
    ripgrep
    fd
    fzf
    jq
    bat
    eza
    dust
    file
    pciutils
    usbutils
    lsof
    nixpkgs-fmt
    nix-tree
  ];

  # PAS de lib.mkDefault ici : nixpkgs declare deja EDITOR = mkDefault "nano"
  # (nixos/modules/programs/environment.nix). Deux mkDefault = meme priorite
  # = conflit non resolu. Une valeur nue (priorite 100) gagne proprement.
  environment.variables.EDITOR = "vim";

  programs.zsh.enable = true;
  programs.git.enable = true;
}
