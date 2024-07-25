#!/usr/bin/env bash

function is_rust_installed() {
    if ! which cargo &>/dev/null; then
        return 1
    fi
    return 0
}


function rustup_init() {
    echo "Asking rustup to use rust stable version as default..."
    if ! is_rust_installed; then
        echo "\`cargo\` not found ! Skipping rust initialization..."
    else
        rustup default stable 
    fi
}

rustup_init