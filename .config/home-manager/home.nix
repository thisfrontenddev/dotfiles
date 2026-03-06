{ pkgs, ... }: {
  home.username = "void";
  home.homeDirectory = "/home/void";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Shell & prompt
    starship
    tmux
    fzf

    # Dev tools
    lazygit
    gh
    commitizen
    cloc
    watchman
    fnm
    rustup
    tldr

    # File & search
    bat
    eza
    ripgrep

    # System info
    fastfetch
    btop
  ];
}
