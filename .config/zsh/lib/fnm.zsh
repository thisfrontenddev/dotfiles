if ! (command -v fnm >/dev/null); then
    echo "fnm not installed, skipping initialization."
else
    eval "$(fnm env --use-on-cd)"
fi

