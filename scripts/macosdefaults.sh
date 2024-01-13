#!/usr/bin/env bash

function finder_defaults() {
  echo "Setting Finder defaults..."

  # Show file extensions
  defaults write NSGlobalDomain "AppleShowAllExtensions" -bool "true"

  # Show hidden files
  defaults write com.apple.finder "AppleShowAllFiles" -bool "false"

  # Keep folders on top when sorting by name
  defaults write com.apple.finder "_FXSortFoldersFirst" -bool "true"

  # Search the current folder by default
  defaults write com.apple.finder "FXDefaultSearchScope" -string "SCcf"

  # Remove delay when hovering toolbar title
  defaults write NSGlobalDomain "NSToolbarTitleViewRolloverDelay" -float "0"

  killall Finder
}

function dock_defaults() {
  echo "Setting Dock defaults..."

  # Dock autohides
  defaults write com.apple.dock "autohide" -bool "true"
  # Dock shows instantaneously
  defaults write com.apple.dock "autohide-delay" -float "0"
  # Dock autohide instantaneously
  defaults write com.apple.dock "autohide-time-modifier" -float "0"
  # Show recent applications
  defaults write com.apple.dock "show-recents" -bool "false"
  killall Dock
}

function screenshot_defaults() {
  echo "Setting screenshot defaults..."

  # Set screenshots directory to ~/Screenshots
  mkdir -p ~/Screenshots
  defaults write com.apple.screencapture "location" -string "~/Screenshots"

  # Don't show thumbnail when taking screenshot
  defaults write com.apple.screencapture "show-thumbnail" -bool "false"

  # Set screenshot format to jpg
  defaults write com.apple.screencapture "type" -string "jpg"

  killall SystemUIServer
}

function music_defaults() {
  echo "Setting music defaults..."
  # Don't display notification when a new song starts in Music.app
  defaults write com.apple.Music "userWantsPlaybackNotifications" -bool "false"
}

function keyboard_defaults() {
  echo "Setting keyboard defaults..."

  # Fast initial key repeat -> normal minimum is 15 (225 ms)
  defaults write -g InitialKeyRepeat -int 10
  
  # Fast key repeat -> normal minimum is 2 (30 ms)
  defaults write -g KeyRepeat -int 1

  # Disable key repeat for most applications
  # defaults write NSGlobalDomain "ApplePressAndHoldEnabled" -bool "true"

  # Enable key repeat for some applications
  # App ID can be found with :
  # osascript -e 'id of app "App Name"'
  defaults write com.microsoft.VSCode "ApplePressAndHoldEnabled" -bool "false"
  defaults write com.apple.terminal "ApplePressAndHoldEnabled" -bool "false"
  defaults write com.googlecode.iterm2 "ApplePressAndHoldEnabled" -bool "false"
  defaults write org.alacritty "ApplePressAndHoldEnabled" -bool "false"
}

finder_defaults
dock_defaults
screenshot_defaults
dock_defaults
music_defaults
keyboard_defaults

echo "All set! Some settings will only be working after a full reboot."
