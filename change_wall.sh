#!/usr/bin/env bash
# rofi-wallpaper-changer — horizontal rofi picker with cached, square thumbnails.
set -uo pipefail
shopt -s nullglob

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

CONFIG_FILE="$XDG_CONFIG_HOME/rofi-wallpaper-changer/wall_dir"
CACHE_BASE="$XDG_CACHE_HOME/rofi-wallpapers"
LAST_WALL="$XDG_CACHE_HOME/last_wallpaper"
THEME="${ROFI_WALLPAPER_THEME:-$XDG_CONFIG_HOME/rofi/wallpapers.rasi}"

WALL_DIR="${ROFI_WALL_DIR:-}"
if [[ -z "$WALL_DIR" && -r "$CONFIG_FILE" ]]; then
    IFS= read -r WALL_DIR < "$CONFIG_FILE" || true
fi
WALL_DIR="${WALL_DIR:-$HOME/wallpapers}"
WALL_DIR="${WALL_DIR/#\~/$HOME}"
WALL_DIR="${WALL_DIR%/}"

WARM=0
[[ "${1:-}" == "--warm" ]] && WARM=1

# Thumbnail canvas; keep in sync with element-icon in wallpapers.rasi.
THUMB=250

JOBS=$(nproc 2>/dev/null || echo 4)
(( JOBS > 8 )) && JOBS=8
(( JOBS < 1 )) && JOBS=1

err() { printf 'change_wall: %s\n' "$*" >&2; }

if [[ ! -d "$WALL_DIR" ]]; then
    err "wallpaper directory not found: $WALL_DIR"
    err "set ROFI_WALL_DIR or write the path to $CONFIG_FILE"
    exit 1
fi

# ---------------------------------------------------------------------------
# Cache: one subdirectory per wallpaper folder, thumbnails keyed by name, mtime
# and size, so replacing an image (even with preserved timestamps) regenerates.
# ---------------------------------------------------------------------------
dirkey=$(printf '%s' "$WALL_DIR" | cksum 2>/dev/null | cut -d' ' -f1)
CACHE_DIR="$CACHE_BASE/${dirkey:-default}"

# Drop caches written by an older thumbnail style (this also removes the
# per-directory cache we are about to recreate).
if [[ ! -e "$CACHE_BASE/.layout-3" ]]; then
    mkdir -p "$CACHE_BASE"
    find "$CACHE_BASE" -mindepth 1 ! -name '.layout-3' -delete 2>/dev/null
    : > "$CACHE_BASE/.layout-3"
fi

mkdir -p "$CACHE_DIR" || exit 1

# Serialize the picker and the background --warm run.
if command -v flock >/dev/null 2>&1; then
    exec 9>"$CACHE_DIR/.lock" || true
    flock -w 10 9 2>/dev/null || true
fi

is_image() {
    case "${1,,}" in
        *.png|*.jpg|*.jpeg|*.jfif|*.webp|*.gif|*.bmp|*.tif|*.tiff|*.avif|*.heic)
            return 0 ;;
    esac
    return 1
}

MAGICK=""
for candidate in magick convert; do
    if command -v "$candidate" >/dev/null 2>&1; then
        MAGICK=$(command -v "$candidate")
        break
    fi
done

gen_thumb() {
    # $1 = source image, $2 = destination png
    local src=$1 dst=$2 tmp ref
    tmp="${dst}.tmp.$$.png"
    ref=$src
    case "${src,,}" in
        *.gif | *.webp) ref="${src}[0]" ;;
    esac
    if "$MAGICK" "$ref" -limit thread 1 -strip \
        -define jpeg:size=520x520 \
        -thumbnail "${THUMB}x${THUMB}^" -gravity center -extent "${THUMB}x${THUMB}" \
        "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$dst"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# ---------------------------------------------------------------------------
# Scan (two find calls, no per-file forks) and queue missing/stale thumbs.
# ---------------------------------------------------------------------------
declare -A MTIME=() FSIZE=()
while IFS= read -r -d '' name && IFS= read -r -d '' mtime && IFS= read -r -d '' fsize; do
    MTIME["$name"]="${mtime%%.*}"
    FSIZE["$name"]=$fsize
done < <(find -L "$WALL_DIR" -mindepth 1 -maxdepth 1 -type f -printf '%f\0%T@\0%s\0' 2>/dev/null)

mapfile -d '' SORTED < <(find -L "$WALL_DIR" -mindepth 1 -maxdepth 1 -type f -printf '%f\0' 2>/dev/null | sort -z)

NAMES=()
FILES=()
KEYS=()
THUMBS=()
PENDING_SRC=()
PENDING_DST=()
declare -A VALID=()
skipped=0

for name in "${SORTED[@]}"; do
    is_image "$name" || continue
    [[ -n "${MTIME[$name]:-}" ]] || continue
    if [[ "$name" == *","* || "$name" == *$'\n'* || "$name" == *$'\x1f'* ]]; then
        (( skipped++ ))
        continue
    fi
    file="$WALL_DIR/$name"
    [[ -f "$file" ]] || continue

    name_hash=$(printf '%s' "$name" | cksum | cut -d' ' -f1)
    key="${name_hash}.${MTIME[$name]}.${FSIZE[$name]}.png"
    thumb="$CACHE_DIR/$key"
    VALID["$key"]=1

    NAMES+=("$name")
    FILES+=("$file")
    KEYS+=("$key")

    if [[ ! -f "$thumb" ]]; then
        if [[ -n "$MAGICK" ]]; then
            PENDING_SRC+=("$file")
            PENDING_DST+=("$thumb")
        fi
    fi
done

TOTAL=${#NAMES[@]}

if (( skipped > 0 )); then
    err "skipped $skipped file(s) whose names contain a comma or newline"
fi

if (( TOTAL == 0 )); then
    err "no wallpapers found in $WALL_DIR"
    [[ -n "$MAGICK" ]] || err "ImageMagick is not installed, so only common image names are listed"
    exit 1
fi

THUMB_LIST=$(mktemp)
INPUT=$(mktemp)
trap 'rm -f -- "${THUMB_LIST:-}" "${INPUT:-}"' EXIT

# ---------------------------------------------------------------------------
# Generate pending thumbnails in parallel.
# ---------------------------------------------------------------------------
if (( ${#PENDING_SRC[@]} > 0 )); then
    : > "$THUMB_LIST"
    for ((i = 0; i < ${#PENDING_SRC[@]}; i++)); do
        printf '%s\0%s\0' "${PENDING_SRC[$i]}" "${PENDING_DST[$i]}" >> "$THUMB_LIST"
    done
    export -f gen_thumb
    export MAGICK THUMB
    xargs -0 -r -n2 -P"$JOBS" -a "$THUMB_LIST" bash -c 'gen_thumb "$@"' _
fi

# ---------------------------------------------------------------------------
# Resolve icons (fall back to the original image if conversion failed) and
# prune thumbnails that no longer belong to a wallpaper.
# ---------------------------------------------------------------------------
for ((i = 0; i < TOTAL; i++)); do
    thumb="$CACHE_DIR/${KEYS[$i]}"
    if [[ -f "$thumb" ]]; then
        THUMBS+=("$thumb")
    else
        THUMBS+=("${FILES[$i]}")
    fi
done

if [[ -n "$MAGICK" ]]; then
    for cached in "$CACHE_DIR"/*.png; do
        [[ -n "${VALID[${cached##*/}]:-}" ]] || rm -f -- "$cached"
    done
fi

if (( WARM )); then
    exit 0
fi

if [[ ! -f "$THEME" ]]; then
    err "theme not found: $THEME"
    err "re-run install.sh or set ROFI_WALLPAPER_THEME"
    exit 1
fi

# ---------------------------------------------------------------------------
# Rotate the list so the current wallpaper is the preselected first item.
# ---------------------------------------------------------------------------
current=""
if [[ -r "$LAST_WALL" ]]; then
    IFS= read -r current < "$LAST_WALL" || true
fi
current_name="${current##*/}"

START=0
for ((i = 0; i < TOTAL; i++)); do
    if [[ "${NAMES[$i]}" == "$current_name" ]]; then
        START=$i
        break
    fi
done

ROTATED_NAMES=()
ROTATED_THUMBS=()
for ((i = START; i < TOTAL; i++)); do
    ROTATED_NAMES+=("${NAMES[$i]}")
    ROTATED_THUMBS+=("${THUMBS[$i]}")
done
for ((i = 0; i < START; i++)); do
    ROTATED_NAMES+=("${NAMES[$i]}")
    ROTATED_THUMBS+=("${THUMBS[$i]}")
done

for ((i = 0; i < TOTAL; i++)); do
    printf '%s\0icon\x1f%s\n' "${ROTATED_NAMES[$i]}" "${ROTATED_THUMBS[$i]}"
done > "$INPUT"

# ---------------------------------------------------------------------------
# Rofi packs the horizontal list from the left, so a short row (a folder with
# two or three wallpapers) would hug the edge. Derive a left margin from the
# theme geometry and the focused monitor to keep the cards centered. All
# values are logical pixels; rofi applies the monitor scale.
# ---------------------------------------------------------------------------
theme_block() {
    # $1 = widget selector, e.g. window / element-icon
    sed -n "/^$1[[:space:]]*{/,/^}/p" "$THEME" 2>/dev/null
}

theme_number() {
    # $1 = widget block, $2 = property name
    sed -n "s/.*$2:[[:space:]]*\(-*[0-9.]*\)[a-z%]*;.*/\1/p" <<<"$1" | head -1
}

row_margin() {
    local n=$1 pct pad icon spacing border bw bx=0 mw scale inner ew content m
    local win_block icon_block list_block elem_block flat focused

    win_block=$(theme_block window)
    icon_block=$(theme_block element-icon)
    list_block=$(theme_block listview)
    elem_block=$(theme_block element)

    pct=$(theme_number "$win_block" width)
    pad=$(theme_number "$win_block" padding)
    icon=$(theme_number "$icon_block" size)
    spacing=$(theme_number "$list_block" spacing)

    bw=$(sed -n 's/.*border:[[:space:]]*\([^;]*\);.*/\1/p' <<<"$elem_block" | head -1)
    # shellcheck disable=SC2086
    set -- $bw
    case $# in
        1) bx=$(( 2 * ${1%px} )) ;;
        4) bx=$(( ${2%px} + ${4%px} )) ;;
    esac

    [[ -n "$pct" && -n "$pad" && -n "$icon" && -n "$spacing" ]] || { echo 0; return; }
    command -v hyprctl >/dev/null 2>&1 || { echo 0; return; }

    flat=$(hyprctl monitors -j 2>/dev/null | tr -d '\n' |
        sed 's/}[[:space:]]*,[[:space:]]*{/}\n{/g')
    focused=$(grep -m1 '"focused":[[:space:]]*true' <<<"$flat")
    [[ -n "$focused" ]] || focused=$(head -1 <<<"$flat")

    mw=$(sed -n 's/.*"width":[[:space:]]*\([0-9]*\).*/\1/p' <<<"$focused")
    scale=$(sed -n 's/.*"scale":[[:space:]]*\([0-9.]*\).*/\1/p' <<<"$focused")
    [[ -n "$mw" && -n "$scale" ]] || { echo 0; return; }

    m=$(awk -v w="$mw" -v s="$scale" -v pct="$pct" -v pad="$pad" \
        -v icon="$icon" -v sp="$spacing" -v bx="$bx" -v n="$n" 'BEGIN {
            if (w <= 0 || pct <= 0 || icon <= 0) { print 0; exit }
            lw = (s > 0 ? w / s : w)
            inner = lw * pct / 100 - 2 * pad
            ew = icon + bx
            step = ew + sp
            if (step <= 0) { print 0; exit }
            # Cards that fit without scrolling; center those, not the total.
            cols = int((inner - ew) / step) + 1
            if (cols < 1) cols = 1
            k = (n < cols ? n : cols)
            content = ew + (k - 1) * step
            m = int((inner - content) / 2 + 0.5)
            print (m > 0 ? m : 0)
        }')
    echo "${m:-0}"
}

command -v rofi >/dev/null 2>&1 || { err "rofi not found"; exit 1; }

MARGIN=$(row_margin "$TOTAL")
ROFI_EXTRA=()
if [[ "$MARGIN" =~ ^[0-9]+$ ]] && (( MARGIN > 0 )); then
    ROFI_EXTRA=(-theme-str "listview { margin: 0px 0px 0px ${MARGIN}px; }")
fi

selected=$(rofi \
    -dmenu \
    -i \
    -no-custom \
    -show-icons \
    -selected-row 0 \
    -theme "$THEME" \
    "${ROFI_EXTRA[@]}" \
    < "$INPUT")

[[ -n "$selected" ]] || exit 0

wall="$WALL_DIR/$selected"
[[ -f "$wall" ]] || { err "selected file no longer exists: $wall"; exit 0; }

# ---------------------------------------------------------------------------
# Apply. hyprpaper >= 0.7 accepts an empty monitor to cover every output.
# Older versions still need preload/unload around one call per monitor.
# ---------------------------------------------------------------------------
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

if ! command -v hyprctl >/dev/null 2>&1; then
    err "hyprctl not found — not applying the wallpaper"
    exit 1
fi

apply_wallpaper "$wall"

active=$(hyprctl hyprpaper listactive 2>/dev/null)
if [[ -n "$active" && "$active" != *"$wall"* ]]; then
    err "hyprpaper does not report $wall as active; check 'hyprctl hyprpaper listactive'"
fi

tmp_last=$(mktemp "$XDG_CACHE_HOME/.last_wallpaper.XXXXXX") &&
    printf '%s\n' "$wall" > "$tmp_last" &&
    mv -f "$tmp_last" "$LAST_WALL"
