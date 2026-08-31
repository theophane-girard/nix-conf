# Comptes utilisateurs.
{ pkgs, username, ... }:

{
  users.mutableUsers = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "Theophane Girard";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video"
      "audio"
      "input"
      "docker" # docker sans sudo
      "scanner" # acces aux scanners SANE
      "lp" # imprimantes + scanners multifonctions
      "ydotool" # frappe clavier simulee, utilisee par les raccourcis end-4
    ];

    # A CHANGER au premier boot : passwd
    initialPassword = "changeme";

    # Alternative sans mot de passe en clair : generer avec
    #   mkpasswd -m sha-512
    # hashedPassword = "$6$...";

    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... theophane@framework"
    ];
  };

  security.sudo.wheelNeedsPassword = true;
}
