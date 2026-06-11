#!/usr/bin/env bash
LAST="$HOME/.cache/last_wallpaper"
CONFIG_FILE="$HOME/.config/rofi-wallpaper-changer/wall_dir"
WALL_DIR="${ROFI_WALL_DIR:-$(cat "$CONFIG_FILE" 2>/dev/null)}"
WALL_DIR="${WALL_DIR:-$HOME/wallpapers}"

if [[ ! -f "$LAST" ]]; then
    wall=$(find "$WALL_DIR" -type f | sort | head -n 1)
else
    wall=$(cat "$LAST")
fi

[[ -z "$wall" || ! -f "$wall" ]] && exit 0

sleep 1
hyprctl hyprpaper preload "$wall"
for m in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$m,$wall"
done
hyprctl hyprpaper unload unused
