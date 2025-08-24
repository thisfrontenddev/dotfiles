if ! (command -v starship >/dev/null); then
    echo "Starship not installed, skipping initialization."
else
    eval "$(starship init zsh)"
fi

