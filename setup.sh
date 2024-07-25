#!/usr/bin/env bash

# XCode CLI installation
./scripts/xcode-setup.sh

# Install homebrew and dependencies
./scripts/homebrew.sh

# Setting MacOS defaults
./scripts/macosdefaults.sh

# Setting up rust
./scripts/rust.sh
