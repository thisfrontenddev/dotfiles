#!/usr/bin/env bash

function finder_defaults() {
  echo "Setting Finder defaults..."
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder AppleShowAllFiles -bool false
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  killall Finder
}

function dock_defaults() {
  echo "Setting Dock defaults..."
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock tilesize -int 16
  defaults write com.apple.dock minimize-to-application -bool true
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock mru-spaces -bool false
  defaults write com.apple.dock expose-animation-duration -float 0.12
  killall Dock
}

function screenshot_defaults() {
  echo "Setting screenshot defaults..."
  mkdir -p ~/Screenshots
  defaults write com.apple.screencapture location -string "~/Screenshots"
  defaults write com.apple.screencapture show-thumbnail -bool false
  defaults write com.apple.screencapture type -string "jpg"
  defaults write com.apple.screencapture disable-shadow -bool true
  killall SystemUIServer
}

function music_defaults() {
  echo "Setting music defaults..."
  defaults write com.apple.Music userWantsPlaybackNotifications -bool false
}

function keyboard_defaults() {
  echo "Setting keyboard defaults..."
  defaults write -g InitialKeyRepeat -int 10
  defaults write -g KeyRepeat -int 1
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool true
  # Disable press-and-hold for apps where key repeat is more useful
  defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
  defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false
  defaults write com.apple.Terminal ApplePressAndHoldEnabled -bool false
  defaults write com.googlecode.iterm2 ApplePressAndHoldEnabled -bool false
  defaults write org.alacritty ApplePressAndHoldEnabled -bool false
  defaults write com.mitchellh.ghostty ApplePressAndHoldEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
}

function trackpad_defaults() {
  echo "Setting trackpad defaults..."
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
}

function misc_defaults() {
  echo "Setting misc defaults..."
  defaults write com.apple.TextEdit RichText -int 0
  defaults write com.apple.ActivityMonitor ShowCategory -int 0
  defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"
  defaults write com.apple.LaunchServices LSQuarantine -bool false
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
}

finder_defaults
dock_defaults
screenshot_defaults
music_defaults
keyboard_defaults
trackpad_defaults
misc_defaults

echo "All set! Some settings will only be working after a full reboot."
