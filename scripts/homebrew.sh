#!/usr/bin/env bash

function install_homebrew() {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) & wait"
    (
        echo;
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"';
    ) >> /Users/$USER/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

function install_deps() {
    # Brew dependencies installation
    while true; do

    read -p "Install brew dependencies? (y/n) " yn

    case $yn in 
        [yY] ) brew bundle install --force;
            break;;
        [nN] ) echo;
            exit;;
        * ) echo;;
    esac

    done
}

# Install homebrew only if not installed
if ! command -v brew &>/dev/null; then
    echo "\`brew\` could not be found, installing..."
    install_homebrew
    install_deps
else
    echo "Homebrew already installed, moving on."
    install_deps
fi