#!/usr/bin/env bash
# Generate local .desktop overrides that set GenericName to the desktop file ID
# so rofi shows "App Name (org.pulseaudio.pavucontrol)" for all apps in the launcher.
#
# For system/flatpak apps: copies the full .desktop file and replaces GenericName.
# Skips local files that have custom modifications (env vars, custom Exec, etc.)
# and only patches their GenericName in-place.
# Safe to re-run.

set -euo pipefail

LOCAL_APPS="$HOME/.local/share/applications"
mkdir -p "$LOCAL_APPS"

SYSTEM_DIRS=(
    /usr/share/applications
    /var/lib/flatpak/exports/share/applications
    "$HOME/.local/share/flatpak/exports/share/applications"
)

COUNT=0

# Collect filenames of custom local .desktop files (those that differ from system)
declare -A CUSTOM_LOCAL=()
for desktop_file in "$LOCAL_APPS"/*.desktop; do
    [[ -f "$desktop_file" ]] || continue
    filename=$(basename "$desktop_file")

    # Check if a system version exists
    has_system=false
    for dir in "${SYSTEM_DIRS[@]}"; do
        if [[ -f "$dir/$filename" ]]; then
            has_system=true
            # If local Exec differs from system Exec, it's a custom override — protect it
            local_exec=$(grep -m1 '^Exec=' "$desktop_file" 2>/dev/null || true)
            system_exec=$(grep -m1 '^Exec=' "$dir/$filename" 2>/dev/null || true)
            if [[ "$local_exec" != "$system_exec" && -n "$local_exec" ]]; then
                CUSTOM_LOCAL["$filename"]=1
            fi
            break
        fi
    done

    # If no system version exists, it's a user-created file — protect it
    if ! $has_system; then
        CUSTOM_LOCAL["$filename"]=1
    fi
done

# Process system and flatpak .desktop files — copy and override GenericName
# Skip files that have custom local modifications
for dir in "${SYSTEM_DIRS[@]}"; do
    for desktop_file in "$dir"/*.desktop; do
        [[ -f "$desktop_file" ]] || continue

        filename=$(basename "$desktop_file")
        app_id="${filename%.desktop}"
        target="$LOCAL_APPS/$filename"

        if [[ -n "${CUSTOM_LOCAL[$filename]:-}" ]]; then
            # Custom local file — only patch GenericName, don't overwrite
            sed -i '/^GenericName/d' "$target"
            sed -i '/^\[Desktop Entry\]/a GenericName='"$app_id" "$target"
        else
            # No custom local file — safe to copy from system
            cp "$desktop_file" "$target"
            sed -i '/^GenericName/d' "$target"
            sed -i '/^\[Desktop Entry\]/a GenericName='"$app_id" "$target"
        fi

        COUNT=$((COUNT + 1))
    done
done

# Patch user-only .desktop files (no system equivalent)
for desktop_file in "$LOCAL_APPS"/*.desktop; do
    [[ -f "$desktop_file" ]] || continue

    filename=$(basename "$desktop_file")
    app_id="${filename%.desktop}"

    # Skip if already processed
    if grep -q "^GenericName=$app_id$" "$desktop_file" 2>/dev/null; then
        continue
    fi

    sed -i '/^GenericName/d' "$desktop_file"
    sed -i '/^\[Desktop Entry\]/a GenericName='"$app_id" "$desktop_file"

    COUNT=$((COUNT + 1))
done

update-desktop-database "$LOCAL_APPS" 2>/dev/null || true
echo "Generated/patched $COUNT desktop entries in $LOCAL_APPS"
