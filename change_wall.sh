#!/usr/bin/env bash
CONFIG_FILE="$HOME/.config/rofi-wallpaper-changer/wall_dir"
WALL_DIR="${ROFI_WALL_DIR:-$(cat "$CONFIG_FILE" 2>/dev/null)}"
WALL_DIR="${WALL_DIR:-$HOME/wallpapers}"
CACHE_DIR="$HOME/.cache/rofi-wallpapers"
mkdir -p "$CACHE_DIR"
TMP=$(mktemp)

NAMES=()
THUMBS=()
for file in "$WALL_DIR"/*; do
    [[ -f "$file" ]] || continue
    name=$(basename "$file")
    thumb="$CACHE_DIR/$name"
    if [[ ! -f "$thumb" ]]; then
        if command -v magick &> /dev/null; then
            magick "$file" -strip -resize 400x225^ -gravity center -extent 400x225 "$thumb"
        elif command -v convert &> /dev/null; then
            convert "$file" -strip -resize 400x225^ -gravity center -extent 400x225 "$thumb"
        else
        	echo "Warning: ImageMagick not found, install it for better performance: sudo pacman -S imagemagick"
            thumb="$file" # Fallback to original image if ImageMagick is missing
        fi
    fi
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

VISIBLE=$(( (1920 * 80 / 100) / 230 ))
OFFSET=$(( VISIBLE / 2 ))

ROTATED_NAMES=()
ROTATED_THUMBS=()
START=$(( (TOTAL - (OFFSET % TOTAL)) % TOTAL ))
for (( i=START; i<TOTAL; i++ )); do
    ROTATED_NAMES+=("${NAMES[$i]}")
    ROTATED_THUMBS+=("${THUMBS[$i]}")
done
for (( i=0; i<START; i++ )); do
    ROTATED_NAMES+=("${NAMES[$i]}")
    ROTATED_THUMBS+=("${THUMBS[$i]}")
done

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

echo "$wall" > "$HOME/.cache/last_wallpaper"
hyprctl hyprpaper unload unused
