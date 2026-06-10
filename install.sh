#!/usr/bin/env bash
WALL_DIR="${ROFI_WALL_DIR:-$HOME/wallpapers}"
CACHE_DIR="$HOME/.cache/rofi-wallpapers"
TMP=$(mktemp)

NAMES=()
THUMBS=()
for file in "$WALL_DIR"/*; do
    [[ -f "$file" ]] || continue
    name=$(basename "$file")
    thumb="$CACHE_DIR/$name"
    NAMES+=("$name")
    THUMBS+=("$thumb")
done

TOTAL=${#NAMES[@]}
if (( TOTAL == 0 )); then
    echo "No wallpapers found in $WALL_DIR"
    echo "Set your wallpaper directory: export ROFI_WALL_DIR=~/your/folder"
    rm "$TMP"
    exit 1
fi

# Approximate visible items on screen (adjust 1920 to your resolution)
VISIBLE=$(( (1920 * 80 / 100) / 230 ))
OFFSET=$(( VISIBLE / 2 ))

# Rotate array so the list starts visually centered
ROTATED_NAMES=()
ROTATED_THUMBS=()
START=$(( TOTAL - OFFSET ))
for (( i=START; i<TOTAL; i++ )); do
    ROTATED_NAMES+=("${NAMES[$i]}")
    ROTATED_THUMBS+=("${THUMBS[$i]}")
done
for (( i=0; i<START; i++ )); do
    ROTATED_NAMES+=("${NAMES[$i]}")
    ROTATED_THUMBS+=("${THUMBS[$i]}")
done

# Write entries to rofi pipe
for (( i=0; i<TOTAL; i++ )); do
    printf "%s\0icon\x1f%s\n" "${ROTATED_NAMES[$i]}" "${ROTATED_THUMBS[$i]}"
done > "$TMP"

selected=$(
    rofi \
        -dmenu \
        -selected-row 0 \
        -theme ~/.config/rofi/wallpapers.rasi \
        < "$TMP"
)

rm "$TMP"
[[ -z "$selected" ]] && exit

wall="$WALL_DIR/$selected"
hyprctl hyprpaper preload "$wall"
for m in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$m,$wall"
done
hyprctl hyprpaper unload unused
