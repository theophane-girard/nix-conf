# Config utilisateur (home-manager) : dotfiles, shell, outils de dev.
{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # ------------------------------------------------------------------ packages
  home.packages = with pkgs; [
    # dev
    nodejs_22
    pnpm
    gh
    glab
    lazygit
    delta

    # divers
    ripgrep
    tldr
    zoxide
  ];

  # ----------------------------------------------------------------------- git
  programs.git = {
    enable = true;
    userName = "Theophane Girard";
    userEmail = "theophane.girard@sensinov.com";
    delta.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
    };
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Ne PAS changer apres le premier build.
  home.stateVersion = "26.05";
}
