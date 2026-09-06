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

    # --- rebuild ---
    # De vraies commandes plutot que des programs.zsh.shellAliases : kitty
    # lance fish (le kitty.conf end-4 contient "shell fish"), ou les alias zsh
    # n'existent pas, et ~/.config/fish est efface puis reecrit a chaque switch
    # par la recopie end-4 -- y declarer des alias serait perdu en silence.
    # Un script dans le PATH marche dans tous les shells et survit au switch.
    #
    # Le depot vit dans /etc/nixos (pas ~/Documents : ancien chemin, faux).
    #
    # nrs / nrt lisent les dotfiles depuis ~/dotfiles au lieu de GitHub
    # (--override-input), donc les modifs NON COMMITEES sont prises en compte :
    # editer -> nrs -> voir. C'est le cycle de bidouille.
    # Corollaire : tant qu'on passe par ces commandes, flake.lock ne bouge pas.
    (writeShellScriptBin "nrs" ''
      sudo nixos-rebuild switch --flake /etc/nixos#nixbox \
        --override-input dotfiles "path:$HOME/dotfiles" "$@" && hyprctl reload
    '')
    (writeShellScriptBin "nrt" ''
      sudo nixos-rebuild test --flake /etc/nixos#nixbox \
        --override-input dotfiles "path:$HOME/dotfiles" "$@" && hyprctl reload
    '')

    # Graver l'etat courant des dotfiles : commit + push, puis reverrouille
    # flake.lock sur le commit pousse. A faire quand un reglage est valide,
    # sinon la machine dependrait d'un ~/dotfiles jamais sauvegarde.
    (writeShellScriptBin "ndp" ''
      cd "$HOME/dotfiles" \
        && git add -A \
        && git commit \
        && git push \
        && sudo nix flake update dotfiles --flake /etc/nixos
    '')

    # Rebuild "propre", sans override : utilise ce que dit flake.lock.
    (writeShellScriptBin "nrc" ''
      sudo nixos-rebuild switch --flake /etc/nixos#nixbox "$@"
    '')
    (writeShellScriptBin "nfu" ''
      sudo nix flake update --flake /etc/nixos "$@"
    '')
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

    settings = {
      # Chemin absolu vers le store : l'opener ne depend pas du PATH.
      opener.chrome = [{
        run = ''${lib.getExe pkgs.google-chrome} "$@"'';
        orphan = true;
        desc = "Open in Chrome";
        for = "linux";
      }];

      # prepend_ : passe avant les regles par defaut de yazi.
      open.prepend_rules = [
        { mime = "application/pdf"; use = [ "chrome" "reveal" ]; }
        { mime = "text/html"; use = [ "chrome" "edit" "reveal" ]; }
      ];
    };

    keymap.mgr.prepend_keymap = [{
      on = "!";
      run = ''shell "$SHELL" --block'';
      desc = "Open shell at current location";
    }];
  };

  # ----------------------------------------------------------------- apparence
  # Un seul signal freedesktop : xdg-desktop-portal-gtk relit cette cle dconf et
  # l'expose via org.freedesktop.appearance color-scheme. Chrome, Firefox,
  # Electron et les apps GTK4/libadwaita le suivent sans config propre.
  # Verifie sur cette machine : la cle fait passer le portail de 0 a 1.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # GTK3 ne lit pas le portail, il lui faut la cle dans settings.ini.
  # extraConfig est vide par ailleurs : pas de collision avec le module ii.
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;

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

      # gh sert de credential helper : rien a gerer a la main, pas de PAT.
      # `gh auth login` ne peut pas ecrire cette config (lecture seule dans le
      # store), donc on la declare ici. Le token reste dans ~/.config/gh.
      credential."https://github.com".helper = "!gh auth git-credential";
      credential."https://gist.github.com".helper = "!gh auth git-credential";
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
      # nrs / nrt / nrc / nfu / ndp ne sont plus des alias : ce sont des
      # scripts declares dans home.packages (section "rebuild"), pour
      # qu'ils marchent aussi dans fish, sous kitty.
    };
  };

  # Pas de programs.starship ici : le prompt vient des dotfiles end-4
  # (home/illogical-impulse.nix), qui reecrivent ~/.config/starship.toml a
  # chaque switch. Declarer les deux = ta config ecrasee sans message.
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
