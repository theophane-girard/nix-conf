# Config specifique a la machine "nixbox".
{ pkgs, hostname, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop.nix # retirer cette ligne pour un serveur / sans GUI
    ../../modules/dev.nix
  ];

  networking.hostName = hostname;

  # ---------------------------------------------------------------- bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Racine chiffree LUKS. UUID du conteneur (pas celui du mapper) :
  #   blkid /dev/nvme0n1p2
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/4d31fa57-ab67-4e41-8f40-ab43ea8ee930";
    allowDiscards = true;
  };

  # ------------------------------------------------- packages propres a ce PC
  environment.systemPackages = with pkgs; [
    # ex: nvtopPackages.amd
  ];

  # Ne PAS changer apres l'install : ancre les migrations d'etat.
  system.stateVersion = "26.05";
}
