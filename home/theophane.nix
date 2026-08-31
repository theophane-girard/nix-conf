# Config utilisateur (home-manager) : dotfiles, shell, outils de dev.
{ pkgs, lib, username, ... }:

{
  imports = [
    # Shell Hyprland end-4 / QuickShell. Commenter cette ligne pour revenir a
    # un Hyprland nu (waybar & co, voir modules/desktop.nix).
    ./illogical-impulse.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # ------------------------------------------------------------------ packages
  home.packages = with pkgs; [
    # --- dev ---
    # Node "de secours", pour les outils globaux et les scripts jetables.
    # Pour un projet, ne PAS dependre de cette version : utiliser un
    # flake.nix + .envrc par projet (direnv est active plus bas).
    nodejs_24
    pnpm

    gh
    glab
    lazygit
    claude-code

    # --- editeur ---
    # Neovim seul : la config LazyVim vit dans ~/.config/nvim et se met a jour
    # toute seule (voir le bootstrap plus bas).
    neovim
    # Dependances attendues par LazyVim :
    gcc # compilation des parsers treesitter
    gnumake
    tree-sitter
    lua-language-server
    stylua

    # --- divers ---
    ripgrep
    tldr
    zoxide
  ];

  home.sessionVariables.EDITOR = "nvim";

  # ------------------------------------------------------------------- LazyVim
  # LazyVim est une *distribution* : lazy.nvim doit pouvoir ecrire dans
  # ~/.config/nvim (lockfile, plugins telecharges). On ne declare donc pas ce
  # dossier via home-manager, qui le rendrait en lecture seule. On l'amorce une
  # seule fois s'il est absent, ensuite il t'appartient.
  home.activation.bootstrapLazyVim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/nvim" ]; then
      run ${pkgs.git}/bin/git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
      run rm -rf "$HOME/.config/nvim/.git"
    fi
  '';

  # --------------------------------------------------------------------- yazi
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # "y" au lieu de "yazi" : le wrapper fait un cd dans le dossier quitte.
    shellWrapperName = "y";
  };

  # ----------------------------------------------------------------------- git
  # Schema home-manager 26.05 : userName/userEmail/extraConfig sont replies
  # sous programs.git.settings, et delta a son propre module.
  programs.git = {
    enable = true;
    settings = {
      user.name = "Theophane Girard";
      user.email = "girard.theophane@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # --------------------------------------------------------------------- shell
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history.size = 50000;
    shellAliases = {
      ls = "eza --group-directories-first";
      ll = "eza -l --git --group-directories-first";
      cat = "bat";
      vim = "nvim";
      # rebuild depuis ce depot
      nrs = "sudo nixos-rebuild switch --flake ~/Documents/nix-conf";
      nrt = "sudo nixos-rebuild test --flake ~/Documents/nix-conf";
      nfu = "nix flake update --flake ~/Documents/nix-conf";
    };
  };

  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.bat.enable = true;
  programs.eza.enable = true;

  # Charge automatiquement l'environnement declare par le .envrc d'un projet :
  # c'est ce qui remplace nvm / pyenv / rbenv sous NixOS.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Ne PAS changer apres le premier build.
  home.stateVersion = "26.05";
}
