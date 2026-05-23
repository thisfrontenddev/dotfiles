# Fedora-only since 2026-05-23 — invoked by scripts/fedora/setup-nix.sh.
# macOS installs the same tools via Brewfile; Arch installs them via paru
# (e.g. `paru -S starship tmux fzf lazygit gh commitizen cloc watchman fnm
# rustup tldr bat eza ripgrep fastfetch btop`).
{ pkgs, user, ... }: {
  home.username = user.username;
  home.homeDirectory = user.homeDirectory;
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
