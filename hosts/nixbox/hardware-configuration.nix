# ############################################################################
# PLACEHOLDER — a remplacer pendant l'installation par le fichier genere par
#   nixos-generate-config --root /mnt
# (il contient les UUID reels et les modules noyau detectes)
#
# Tel quel, ce fichier fonctionne SI tu formates avec les labels suivants :
#   mkfs.ext4  -L nixos  /dev/...   (racine)
#   mkfs.fat -F32 -n BOOT /dev/...  (partition EFI)
#   mkswap     -L swap   /dev/...   (swap, optionnel)
# ############################################################################
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ]; # "kvm-intel" sur CPU Intel
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];
  # swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  networking.useDHCP = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;
}
