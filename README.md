# rofi-wallpaper-changer

A minimal wallpaper switcher using rofi with a horizontal icon-based picker. Built for **Arch Linux + Hyprland**.

![preview](preview.png)

## Dependencies

- `rofi`
- `hyprpaper`
- `jq`
- `imagemagick` (optional, heavily recommended for auto-generating thumbnails)

## Install

```bash
bash <(curl -s https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main/install.sh)
```

The installer will ask for your wallpapers folder and save it automatically to your shell config.

## Manual install

```bash
mkdir -p ~/.config/rofi ~/.local/bin ~/.cache/rofi-wallpapers

curl -s https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main/wallpapers.rasi \
    -o ~/.config/rofi/wallpapers.rasi

curl -s https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main/change_wall.sh \
    -o ~/.local/bin/change_wall

chmod +x ~/.local/bin/change_wall
```

Then set your wallpapers directory in your `.bashrc` or `.zshrc`:

```bash
export ROFI_WALL_DIR=~/your/wallpapers/folder
```

## Usage

Run it from terminal:
```bash
change_wall
```

Or bind it to a key in your Hyprland config (`~/.config/hypr/hyprland.conf`):
```
bind = $mainMod, W, exec, ~/.local/bin/change_wall
```

Navigate with arrow keys, confirm with Enter, cancel with Escape.

## Configuration

If your monitor resolution is not 1920px wide, edit this line in `change_wall.sh`:
```bash
VISIBLE=$(( (1920 * 80 / 100) / 230 ))
#           ^^^^— your horizontal resolution
```

### wallpapers.rasi

| Property | Default | Description |
|----------|---------|-------------|
| `width` | `80%` | Width of the rofi window relative to screen |
| `height` | `280px` | Height of the rofi window |
| `spacing` | `-45px` | Overlap between images. More negative = more overlap |
| `size` (element-icon) | `220px` | Thumbnail display size |

> On smaller monitors, consider reducing `spacing` to `-20px` or `0px` to avoid excessive overlap.

### change_wall.sh

| Variable | Default | Description |
|----------|---------|-------------|
| `ROFI_WALL_DIR` | `~/wallpapers` | Path to your wallpapers folder, set via env variable |
| `VISIBLE` | calculated from 1920px | Estimated number of visible items used for centering |

### Thumbnail cache

On first run, ImageMagick automatically generates small previews of your wallpapers and stores them in `~/.cache/rofi-wallpapers/`. This makes the picker load fast every time.

You only need to clear the cache if you **add, remove, or replace** a wallpaper file:

```bash
rm -rf ~/.cache/rofi-wallpapers/*
```

Next time you run `change_wall`, the previews will be regenerated automatically.

## Notes

- Thumbnails are read from `~/.cache/rofi-wallpapers/` — filenames must match your wallpaper filenames.
- Works with multiple monitors via `hyprctl`.
- Theme is fully transparent, designed to blend with any wallpaper.
