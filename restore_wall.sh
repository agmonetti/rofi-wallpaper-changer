#!/usr/bin/env bash
# rofi-wallpaper-changer — restore the last wallpaper at login.
set -uo pipefail
shopt -s nullglob

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

CONFIG_FILE="$XDG_CONFIG_HOME/rofi-wallpaper-changer/wall_dir"
LAST_WALL="$XDG_CACHE_HOME/last_wallpaper"

WALL_DIR="${ROFI_WALL_DIR:-}"
if [[ -z "$WALL_DIR" && -r "$CONFIG_FILE" ]]; then
    IFS= read -r WALL_DIR < "$CONFIG_FILE" || true
fi
WALL_DIR="${WALL_DIR:-$HOME/wallpapers}"
WALL_DIR="${WALL_DIR/#\~/$HOME}"
WALL_DIR="${WALL_DIR%/}"

err() { printf 'restore_wall: %s\n' "$*" >&2; }

is_image() {
    case "${1,,}" in
        *.png|*.jpg|*.jpeg|*.jfif|*.webp|*.gif|*.bmp|*.tif|*.tiff|*.avif|*.heic)
            return 0 ;;
    esac
    return 1
}

# hyprpaper >= 0.7 accepts an empty monitor to cover every output; older
# versions need preload/unload around one call per monitor.
apply_wallpaper() {
    local target=$1 mon
    if hyprctl hyprpaper listloaded >/dev/null 2>&1; then
        hyprctl hyprpaper preload "$target" >/dev/null 2>&1
        while IFS= read -r mon; do
            hyprctl hyprpaper wallpaper "$mon,$target" >/dev/null 2>&1
        done < <(hyprctl monitors 2>/dev/null | awk '/^Monitor[[:space:]]/{print $2}')
        hyprctl hyprpaper unload unused >/dev/null 2>&1
    else
        hyprctl hyprpaper wallpaper ",$target" >/dev/null 2>&1
    fi
}

wall=""
if [[ -r "$LAST_WALL" ]]; then
    IFS= read -r wall < "$LAST_WALL" || true
fi

if [[ -z "$wall" || ! -f "$wall" ]]; then
    wall=""
    for file in "$WALL_DIR"/*; do
        [[ -f "$file" ]] || continue
        is_image "$file" || continue
        wall="$file"
        break
    done
fi

[[ -n "$wall" && -f "$wall" ]] || exit 0

command -v hyprctl >/dev/null 2>&1 || { err "hyprctl not found"; exit 0; }
mkdir -p "$XDG_CACHE_HOME"

# Wait for hyprpaper's IPC instead of guessing with a fixed sleep.
ready=0
for ((i = 0; i < 100; i++)); do
    if hyprctl hyprpaper listactive >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 0.2
done
(( ready )) || err "hyprpaper did not answer within 20s; applying anyway"

apply_wallpaper "$wall"

active=$(hyprctl hyprpaper listactive 2>/dev/null)
if [[ -n "$active" && "$active" != *"$wall"* ]]; then
    err "hyprpaper does not report $wall as active; check 'hyprctl hyprpaper listactive'"
fi

tmp_last=$(mktemp "$XDG_CACHE_HOME/.last_wallpaper.XXXXXX") &&
    printf '%s\n' "$wall" > "$tmp_last" &&
    mv -f "$tmp_last" "$LAST_WALL"

# Warm the thumbnail cache in the background so the first open is instant.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
if [[ -n "$SCRIPT_DIR" && -x "$SCRIPT_DIR/change_wall" ]]; then
    if command -v setsid >/dev/null 2>&1; then
        setsid "$SCRIPT_DIR/change_wall" --warm >/dev/null 2>&1 < /dev/null &
    else
        "$SCRIPT_DIR/change_wall" --warm >/dev/null 2>&1 < /dev/null &
    fi
fi
