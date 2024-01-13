#!/usr/bin/env bash

# ./scripts/macosdefaults.sh
# exit 1;

# XCode CLI installation
if ! xcode-select -p &>/dev/null; then
    echo "XCode command line tools not set-up, installing..."
    xcode-select --install
else
    echo "XCode CLI tools already installed, moving on."
fi

# Brew installation
if ! command -v brew &>/dev/null; then
    echo "$(brew) could not be found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (
        echo
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    ) >>/Users/null/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew already installed, moving on."
fi

# Brew dependencies installation
echo "Installing software with Brewfile..."
brew bundle install

# Setting MacOS defaults
./scripts/macosdefaults.sh

# Setting up rust
rustup-init -y
