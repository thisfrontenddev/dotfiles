#!/usr/bin/env bash
set -euo pipefail

find_brew() {
    if command -v brew &>/dev/null; then
        command -v brew
        return
    fi

    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return
        fi
    done

    return 1
}

confirm_optional_cask() {
    local cask="$1"
    local suffix answer

    suffix="[y/N]"

    while true; do
        printf "Install optional cask %s? %s " "$cask" "$suffix"
        IFS= read -r answer
        answer="${answer:-no}"

        case "$answer" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

select_optional_casks() {
    local optional_casks=(
        whatsapp
        notion
        little-snitch
        micro-snitch
        linear-linear
        spline
        obs
    )
    local selected=()
    local cask

    if [[ "${BREW_OPTIONAL_CASKS+x}" == "x" ]]; then
        return
    fi

    if [[ ! -t 0 ]]; then
        export BREW_OPTIONAL_CASKS=""
        return
    fi

    echo "==> Optional Homebrew casks"
    echo "    Set BREW_OPTIONAL_CASKS=all or a comma-separated cask list to skip prompts."

    for cask in "${optional_casks[@]}"; do
        if confirm_optional_cask "$cask"; then
            selected+=("$cask")
        fi
    done

    local IFS=,
    export BREW_OPTIONAL_CASKS="${selected[*]}"
}

# Install Homebrew if not present
if ! command -v brew &>/dev/null; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "==> Homebrew already installed"
fi

BREW_BIN="$(find_brew)" || {
    echo "Homebrew installation failed: brew was not found"
    exit 1
}

# Add brew to PATH for future zsh login shells. Fish PATH is managed in
# ~/.config/fish/conf.d/00-env.fish.
if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    echo >> "$HOME/.zprofile"
    echo "eval \"\$($BREW_BIN shellenv)\"" >> "$HOME/.zprofile"
fi

eval "$("$BREW_BIN" shellenv)"

select_optional_casks

# Install all packages from Brewfile
echo "==> Installing Homebrew packages..."
"$BREW_BIN" bundle install --force --file="$HOME/Brewfile"
