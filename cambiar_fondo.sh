#!/usr/bin/env bash
WALL_DIR="${ROFI_WALL_DIR:-$HOME/wallpapers}"  # usa la variable de entorno si existe, sino ~/wallpapers por defecto
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
    echo "No se encontraron wallpapers en $WALL_DIR"
    echo "Exportá la variable: export ROFI_WALL_DIR=~/tu/carpeta"
    rm "$TMP"
    exit 1
fi

VISIBLE=$(( (1920 * 80 / 100) / 230 ))
OFFSET=$(( VISIBLE / 2 ))

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
