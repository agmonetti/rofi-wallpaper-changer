#!/usr/bin/env bash
# rofi-wallpaper-changer — installer
set -uo pipefail

REPO_RAW="https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main"

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
BIN_DIR="$HOME/.local/bin"
ROFI_DIR="$XDG_CONFIG_HOME/rofi"
THEME="$ROFI_DIR/wallpapers.rasi"
HYPRPAPER_CONF="$XDG_CONFIG_HOME/hypr/hyprpaper.conf"

note() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

fetch() {
    # fetch <url> <destination>
    local url=$1 dest=$2 tmp
    tmp=$(mktemp) || return 1
    if ! curl -fsSL --proto '=https' --retry 2 -o "$tmp" "$url"; then
        rm -f "$tmp"
        return 1
    fi
    mv -f "$tmp" "$dest"
}

note "Installing rofi-wallpaper-changer..."

for dep in rofi curl; do
    command -v "$dep" >/dev/null 2>&1 || warn "$dep not found in PATH"
done
command -v hyprctl >/dev/null 2>&1 || warn "hyprctl not found (is Hyprland installed?)"
command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 ||
    warn "ImageMagick not found — thumbnails will be full-size and unrounded"

mkdir -p "$BIN_DIR" "$ROFI_DIR" "$(dirname "$HYPRPAPER_CONF")" ||
    die "could not create install directories"

note "Downloading files..."
if [[ -f "$THEME" ]]; then
    cp -f "$THEME" "$THEME.prev" && note "Previous theme saved as $THEME.prev"
fi
fetch "$REPO_RAW/wallpapers.rasi" "$THEME" || die "could not download wallpapers.rasi"
fetch "$REPO_RAW/change_wall.sh" "$BIN_DIR/change_wall" || die "could not download change_wall.sh"
fetch "$REPO_RAW/restore_wall.sh" "$BIN_DIR/restore_wall" || die "could not download restore_wall.sh"
chmod 644 "$THEME"
chmod 755 "$BIN_DIR/change_wall" "$BIN_DIR/restore_wall"

# Never clobber an existing hyprpaper config: only make sure splash is off.
if [[ ! -f "$HYPRPAPER_CONF" ]]; then
    printf 'splash = false\n' > "$HYPRPAPER_CONF"
elif ! grep -qE '^[[:space:]]*splash[[:space:]]*=' "$HYPRPAPER_CONF"; then
    printf '\nsplash = false\n' >> "$HYPRPAPER_CONF"
fi

# Wallpaper folder: env > interactive prompt > default. Reading from stdin is
# skipped when the installer is piped (curl | bash), where stdin is the script.
WALL_DIR="${ROFI_WALL_DIR:-}"
if [[ -z "$WALL_DIR" && -t 0 ]]; then
    read -r -p "Enter the full path to your wallpapers directory (e.g., ~/wallpapers): " WALL_DIR
fi
WALL_DIR="${WALL_DIR:-$HOME/wallpapers}"
WALL_DIR="${WALL_DIR/#\~/$HOME}"
WALL_DIR="${WALL_DIR%/}"

if [[ ! -d "$WALL_DIR" ]]; then
    note "Creating $WALL_DIR..."
    mkdir -p "$WALL_DIR" || die "could not create $WALL_DIR"
fi

CONFIG_DIR="$XDG_CONFIG_HOME/rofi-wallpaper-changer"
mkdir -p "$CONFIG_DIR" || die "could not create $CONFIG_DIR"
printf '%s\n' "$WALL_DIR" > "$CONFIG_DIR/wall_dir"

# Shell integration is still handy for `$ROFI_WALL_DIR` overrides.
SHELL_RC="$HOME/.bashrc"
case "${SHELL:-}" in
    *zsh*) SHELL_RC="$HOME/.zshrc" ;;
    *fish*) SHELL_RC="$HOME/.config/fish/config.fish" ;;
esac
mkdir -p "$(dirname "$SHELL_RC")"

escaped=$(printf '%s' "$WALL_DIR" | sed 's/[&|\\]/\\&/g')

if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null &&
    [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    note "Adding $BIN_DIR to PATH in $SHELL_RC..."
    if [[ "$SHELL_RC" == *fish* ]]; then
        printf '\nfish_add_path %s\n' "$BIN_DIR" >> "$SHELL_RC"
    else
        printf '\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$SHELL_RC"
    fi
fi

if grep -q 'ROFI_WALL_DIR' "$SHELL_RC" 2>/dev/null; then
    note "Updating existing ROFI_WALL_DIR in $SHELL_RC..."
    if [[ "$SHELL_RC" == *fish* ]]; then
        sed -i "s|^[[:space:]]*set -x ROFI_WALL_DIR.*|set -x ROFI_WALL_DIR \"$escaped\"|" "$SHELL_RC"
    else
        sed -i "s|^[[:space:]]*export ROFI_WALL_DIR=.*|export ROFI_WALL_DIR=\"$escaped\"|" "$SHELL_RC"
    fi
else
    note "Adding ROFI_WALL_DIR to $SHELL_RC..."
    {
        printf '\n# rofi-wallpaper-changer\n'
        if [[ "$SHELL_RC" == *fish* ]]; then
            printf 'set -x ROFI_WALL_DIR "%s"\n' "$WALL_DIR"
        else
            printf 'export ROFI_WALL_DIR="%s"\n' "$WALL_DIR"
        fi
    } >> "$SHELL_RC"
fi

note ""
note "Installation complete!"
note "Wallpapers: $WALL_DIR"
note "Picker:     $BIN_DIR/change_wall"
note ""
note "Add these lines to your Hyprland config:"
note "  exec-once = hyprpaper"
note "  exec-once = restore_wall"
note "  bind = \$mainMod, W, exec, ~/.local/bin/change_wall"
note ""
note "Restart your terminal or run: source $SHELL_RC"
