# rofi-wallpaper-changer

A minimal wallpaper switcher using rofi with a horizontal icon-based picker. Built for **Arch Linux + Hyprland**.

![preview](preview.png)

## Dependencies

- `rofi`
- `hyprpaper`
- `jq`

## Install

```bash
bash <(curl -s https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main/install.sh)
```

The installer will ask for your wallpapers folder and save it automatically to your shell config.

## Manual install

```bash
mkdir -p ~/.config/rofi ~/.local/bin ~/.cache/rofi-wallpapers

curl -s https://raw.githubusercontent.com/TU_USUARIO/rofi-wallpaper-changer/main/wallpapers.rasi \
    -o ~/.config/rofi/wallpapers.rasi

curl -s https://raw.githubusercontent.com/TU_USUARIO/rofi-wallpaper-changer/main/cambiar_fondo.sh \
    -o ~/.local/bin/cambiar_fondo

chmod +x ~/.local/bin/cambiar_fondo
```

Then set your wallpapers directory in your `.bashrc` or `.zshrc`:

```bash
export ROFI_WALL_DIR=~/your/wallpapers/folder
```

## Usage

Run it from terminal:
```bash
cambiar_fondo
```

Or bind it to a key in your Hyprland config (`~/.config/hypr/hyprland.conf`):
```
bind = $mainMod, W, exec, ~/.local/bin/cambiar_fondo
```

Navigate with arrow keys, confirm with Enter, cancel with Escape.

## Configuration

If your monitor resolution is not 1920px wide, edit this line in `cambiar_fondo.sh`:
```bash
VISIBLE=$(( (1920 * 80 / 100) / 230 ))
#           ^^^^— your horizontal resolution
```

## Notes

- Thumbnails are read from `~/.cache/rofi-wallpapers/` — filenames must match your wallpaper filenames.
- Works with multiple monitors via `hyprctl`.
- Theme is fully transparent, designed to blend with any wallpaper.
