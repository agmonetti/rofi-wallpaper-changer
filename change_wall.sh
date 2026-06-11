#!/usr/bin/env bash
CONFIG_FILE="$HOME/.config/rofi-wallpaper-changer/wall_dir"
WALL_DIR="${ROFI_WALL_DIR:-$(cat "$CONFIG_FILE" 2>/dev/null)}"
WALL_DIR="${WALL_DIR:-$HOME/wallpapers}"
CACHE_DIR="$HOME/.cache/rofi-wallpapers"
mkdir -p "$CACHE_DIR"

# Remove orphan thumbnails
for thumb in "$CACHE_DIR"/*; do
    [[ -f "$thumb" ]] || continue
    name=$(basename "$thumb")
    [[ ! -f "$WALL_DIR/$name" ]] && rm "$thumb"
done

TMP=$(mktemp)
NAMES=()
THUMBS=()
for file in "$WALL_DIR"/*; do
    [[ -f "$file" ]] || continue
    name=$(basename "$file")
    thumb="$CACHE_DIR/$name"
    
    # Generate perfect square thumbnails (250x250)
    if [[ ! -f "$thumb" ]]; then
        if [ -f /usr/bin/magick ]; then
            /usr/bin/magick "$file" -strip -resize 250x250^ -gravity center -extent 250x250 "$thumb"
        elif [ -f /usr/bin/convert ]; then
            /usr/bin/convert "$file" -strip -resize 250x250^ -gravity center -extent 250x250 "$thumb"
        else
            echo "Warning: ImageMagick not found at /usr/bin/magick"
            thumb="$file"
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

# Calculate visible elements for centering (Adjusted to 265 for 250px size + 15px spacing)
VISIBLE=$(( (1920 * 80 / 100) / 265 ))
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
