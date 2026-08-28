# Outillage de developpement systeme (conteneurs, virtualisation).
{ pkgs, ... }:

{
  # ------------------------------------------------------------------- docker
  virtualisation.docker = {
    enable = true;

    # Purge hebdo des images / conteneurs / volumes orphelins : sans ca
    # /var/lib/docker grossit indefiniment.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Le compte utilisateur est deja dans le groupe "docker" (modules/users.nix),
  # ce qui permet d'utiliser docker sans sudo.

  environment.systemPackages = with pkgs; [
    docker-compose # fournit "docker compose" en sous-commande
  ];
}
