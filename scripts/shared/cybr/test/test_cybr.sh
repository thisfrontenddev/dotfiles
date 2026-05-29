#!/usr/bin/env bash
# Shell-assertion test harness for cybr. Run: bash scripts/shared/cybr/test/test_cybr.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/lib.sh"
PASS=0; FAIL=0

assert_eq() { # desc, expected, actual
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    expected: %q\n    actual:   %q\n' "$1" "$2" "$3"; fi
}
assert_contains() { # desc, haystack, needle
  if [[ "$2" == *"$3"* ]]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    %q does not contain %q\n' "$1" "$2" "$3"; fi
}
assert_file() { # desc, path
  if [[ -e "$2" ]]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    missing: %s\n' "$1" "$2"; fi
}

# --- Task 1 tests ---
echo "== Task 1: skeleton =="
out="$(bash "$HERE/cybr" 2>&1)"; rc=$?
assert_eq "no-args exits non-zero" "1" "$rc"
assert_contains "no-args prints usage" "$out" "Usage: cybr"

echo "== Task 2: registry + list =="
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CYBR_HOME="$TMP" CYBR_CACHE="$TMP/cache" CYBR_MANIFEST="$TMP/manifest.toml"
# registry stays the real committed one ($CYBR_REGISTRY default)

# value reader
val="$(cybr::reg_get cybr-hyprland repo)"
assert_contains "reg_get reads repo url" "$val" "cybr-hyprland"
val="$(cybr::reg_get cybr-hyprland target)"
assert_eq "reg_get reads target" ".config/hypr" "$val"

# list with empty manifest
out="$(cybr::cmd_list)"
assert_contains "list shows a known component" "$out" "cybr-hyprland"
assert_contains "list marks not-enabled" "$out" "[ ] cybr-hyprland"

# list after manually enabling in manifest
mkdir -p "$(dirname "$CYBR_MANIFEST")"
printf 'cybr-hyprland = "abc123"\n' > "$CYBR_MANIFEST"
out="$(cybr::cmd_list)"
assert_contains "list marks enabled" "$out" "[x] cybr-hyprland"

echo "== Task 3: cache =="
# Build a local fake upstream git repo so tests need no network.
FAKE="$TMP/fake-remote"; mkdir -p "$FAKE"
( cd "$FAKE" && git init -q && git config user.email t@t && git config user.name t \
  && git config commit.gpgsign false \
  && echo "v1" > file.txt && git add . && git commit -qm v1 )
SHA1="$(cd "$FAKE" && git rev-parse HEAD)"

CDIR="$(cybr::cache_dir cybr-fake)"
assert_eq "cache_dir path" "$CYBR_CACHE/cybr-fake" "$CDIR"

cybr::clone_or_update cybr-fake "file://$FAKE" >/dev/null 2>&1
assert_file "clone creates cache dir" "$CDIR/file.txt"

# add a second upstream commit, then verify checkout pins to SHA1
( cd "$FAKE" && git config commit.gpgsign false && echo "v2" > file.txt && git commit -qam v2 )
cybr::clone_or_update cybr-fake "file://$FAKE" >/dev/null 2>&1
cybr::checkout cybr-fake "$SHA1" >/dev/null 2>&1
assert_eq "checkout pins to SHA" "v1" "$(cat "$CDIR/file.txt")"

echo "== Task 4: mirror + loader =="
# Fake a cached hypr-style component.
HC="$CYBR_CACHE/cybr-hyprland"; mkdir -p "$HC"
printf 'source = ~/.config/hypr/theme.conf\nbind=X\n' > "$HC/hyprland.conf"
printf 'col=1\n' > "$HC/theme.conf"
printf 'var=1\n' > "$HC/vars.conf"
TARGET="$CYBR_HOME/.config/hypr"

cybr::mirror_upstream cybr-hyprland   # symlink all but entry into target
assert_file "mirror symlinks theme.conf" "$TARGET/theme.conf"
assert_eq "theme.conf is a symlink into cache" "$HC/theme.conf" "$(readlink "$TARGET/theme.conf")"
assert_eq "entry file NOT mirrored as symlink" "" "$(readlink "$TARGET/hyprland.conf")"

cybr::scaffold_override cybr-hyprland
assert_file "override scaffolded" "$TARGET/override.conf"

cybr::write_loader cybr-hyprland
loader="$(cat "$TARGET/hyprland.conf")"
assert_contains "loader sources cached entry" "$loader" "$HC/hyprland.conf"
assert_contains "loader sources override last" "$loader" "$TARGET/override.conf"
# override must come AFTER upstream in the file (last wins)
up_line="$(grep -n "$HC/hyprland.conf" "$TARGET/hyprland.conf" | head -1 | cut -d: -f1)"
ov_line="$(grep -n "override.conf" "$TARGET/hyprland.conf" | head -1 | cut -d: -f1)"
assert_eq "override included after upstream" "true" "$([[ $ov_line -gt $up_line ]] && echo true || echo false)"

# jsonc style
WC="$CYBR_CACHE/cybr-waybar"; mkdir -p "$WC"
printf '{ "include": "~/.config/waybar/modules.jsonc" }\n' > "$WC/config.jsonc"
printf '{}\n' > "$WC/modules.jsonc"
WT="$CYBR_HOME/.config/waybar"
cybr::mirror_upstream cybr-waybar
assert_eq "waybar modules.jsonc mirrored" "$WC/modules.jsonc" "$(readlink "$WT/modules.jsonc")"
cybr::scaffold_override cybr-waybar
cybr::write_loader cybr-waybar
wloader="$(cat "$WT/config.jsonc")"
assert_contains "waybar loader includes cached entry" "$wloader" "$WC/config.jsonc"
assert_contains "waybar loader includes override" "$wloader" "override.jsonc"

echo ""
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
