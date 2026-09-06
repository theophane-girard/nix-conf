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

  # --------------------------------------------------------------- hibernation
  # Le swap est DANS le conteneur LUKS : l'image memoire -- qui contient la cle
  # maitresse et le trousseau -- est donc ecrite chiffree. Au reveil la
  # passphrase est redemandee, ce qui rend l'hibernation equivalente a une
  # extinction. La veille simple, elle, laisse tout en RAM en clair.
  #
  # Taille > RAM (30,6 Gio) : l'image ne depasse jamais la taille de la RAM.
  # Priorite 0, sous celle de zram (5) : le zram reste le swap du quotidien,
  # ce fichier ne sert qu'a l'hibernation.
  swapDevices = [{
    device = "/swapfile";
    size = 34816; # Mio
    priority = 0;
  }];

  # Ou lire l'image au reveil : l'ext4 A L'INTERIEUR du conteneur, pas le
  # conteneur lui-meme. Meme UUID que fileSystems."/".
  boot.resumeDevice = "/dev/disk/by-uuid/bc94205c-2a2e-4454-9594-cd96f96668bb";

  # Position physique du swapfile dans l'ext4. Obligatoire pour un swap
  # FICHIER (inutile pour une partition), et invalide des que le fichier est
  # recree. Injecte par tools/resume-offset.sh une fois /swapfile en place.
  # boot.kernelParams = [ "resume_offset=XXXXXXXX" ];

  # ------------------------------------------------- packages propres a ce PC
  environment.systemPackages = with pkgs; [
    # ex: nvtopPackages.amd
  ];

  # Ne PAS changer apres l'install : ancre les migrations d'etat.
  system.stateVersion = "26.05";
}
