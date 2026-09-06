{
  description = "Configuration NixOS de Theophane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NOS dotfiles : fork de end-4/dots-hyprland. C'est ICI qu'on edite la
    # config du shell Hyprland (barre, hypr/, quickshell/, kitty...), plus dans
    # ~/.config qui est ecrase a chaque switch.
    #   ?submodules=1 est OBLIGATOIRE : le repo a un submodule
    #   (dots/.config/quickshell/ii/modules/common/widgets/shapes) sans lequel
    #   les formes Material de QuickShell manquent.
    #   nix flake update dotfiles   -> recupere tes derniers commits pousses
    dotfiles = {
      url = "git+https://github.com/theophane-girard/dots-hyprland?submodules=1";
      flake = false;
    };

    # Shell Hyprland "illogical impulse" (end-4 / QuickShell), portage NixOS.
    # N'expose qu'un module home-manager : homeManagerModules.default.
    illogical-flake = {
      url = "github:soymou/illogical-flake";
      # Force quickshell + NUR a se construire contre NOTRE nixpkgs : sans ca
      # deux nixpkgs cohabitent et les libs Qt de quickshell ne correspondent
      # plus a celles des paquets kdePackages installes a cote.
      inputs.nixpkgs.follows = "nixpkgs";
      # Son input "dotfiles" pointait sur end-4/dots-hyprland en amont direct.
      # On le detourne vers notre fork ci-dessus : le module illogical-flake ne
      # s'en sert qu'a deux endroits (dots/.config et dots/.local/share, qu'il
      # recopie dans ~), donc la substitution est sans risque.
      # CONTREPARTIE : "nix flake update illogical-flake" n'avance plus les
      # dotfiles avec quickshell. Quand quickshell bouge, rebaser le fork sur
      # end-4/main soi-meme.
      inputs.dotfiles.follows = "dotfiles";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";

      # Fabrique un systeme NixOS a partir d'un dossier hosts/<hostname>/
      mkHost =
        { hostname
        , username ? "theophane"
        , extraModules ? [ ]
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;

          # Dispo dans tous les modules via leurs arguments
          specialArgs = { inherit hostname username; };

          modules = [
            ./hosts/${hostname}/default.nix
            ./modules/base.nix
            ./modules/users.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-bak";
              # "inputs" est necessaire a home/illogical-impulse.nix, qui
              # importe un module fourni par un flake externe.
              home-manager.extraSpecialArgs = { inherit username inputs; };
              home-manager.users.${username} = import ./home/${username}.nix;
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        # Renommer cette cle + le dossier hosts/nixbox/ pour une autre machine.
        nixbox = mkHost { hostname = "nixbox"; };

        # Ajouter une machine :
        # framework = mkHost {
        #   hostname = "framework";
        #   extraModules = [ ./modules/desktop.nix ];
        # };
      };
    };
}
