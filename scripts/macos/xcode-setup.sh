#!/bin/bash

function remove_previous_cli() {
    sudo rm -rf /Library/Developer/CommandLineTools
}

function install() {
    sudo xcode-select --install
}

function hang_until_installed() {
    # Wait until XCode Command Line Tools installation has finished.
    until $(xcode-select --print-path &> /dev/null); do
    sleep 5;
    done
}

echo "Performing a clean installation for XCode Command Line Tools..."
echo

remove_previous_cli
install

echo
echo "Waiting for you to finish the setup..."
hang_until_installed
echo "XCode Command Line Tools installed !"
echo
