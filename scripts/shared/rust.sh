#!/usr/bin/env bash

# Ensure Nix profile is in PATH (rustup is installed via Home Manager)
if [[ -d "$HOME/.nix-profile/bin" ]]; then
    export PATH="$HOME/.nix-profile/bin:$PATH"
fi

if command -v rustup &>/dev/null; then
    echo "Setting rust stable as default toolchain..."
    rustup default stable
else
    echo "rustup not found — install via Nix/Home Manager first"
fi