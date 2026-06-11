#!/usr/bin/env bash

echo "Installing rofi-wallpaper-changer..."

# Create directories
mkdir -p ~/.config/rofi ~/.local/bin ~/.cache/rofi-wallpapers

# Download files
echo "Downloading files..."
curl -s https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main/wallpapers.rasi -o ~/.config/rofi/wallpapers.rasi
curl -s https://raw.githubusercontent.com/agmonetti/rofi-wallpaper-changer/main/change_wall.sh -o ~/.local/bin/change_wall
chmod +x ~/.local/bin/change_wall

# Ask for wallpaper folder
read -e -p "Enter the full path to your wallpapers directory (e.g., ~/wallpapers): " WALL_DIR

# Handle empty input or default
if [[ -z "$WALL_DIR" ]]; then
    WALL_DIR="$HOME/wallpapers"
fi

# Expand tilde if present safely
WALL_DIR="${WALL_DIR/#\~/$HOME}"

if [[ ! -d "$WALL_DIR" ]]; then
    echo "Warning: Directory $WALL_DIR does not exist. Creating it..."
    mkdir -p "$WALL_DIR"
fi

# Determine shell and config file
SHELL_RC="$HOME/.bashrc"
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
    
elif [[ "$SHELL" == *"fish"* ]]; then
    SHELL_RC="$HOME/.config/fish/config.fish"
fi

# Ensure ~/.local/bin is in PATH
if ! grep -q 'export PATH=.*\$HOME/.local/bin' "$SHELL_RC" && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "Adding ~/.local/bin to PATH in $SHELL_RC..."
    if [[ "$SHELL" == *"fish"* ]]; then
        echo 'set -x PATH $HOME/.local/bin $PATH' >> "$SHELL_RC"
    else
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    fi
fi

# Add to shell config if not already there
if grep -q "ROFI_WALL_DIR" "$SHELL_RC"; then
    echo "Updating existing ROFI_WALL_DIR in $SHELL_RC..."
    if [[ "$SHELL" == *"fish"* ]]; then
        sed -i "s|set -x ROFI_WALL_DIR.*|set -x ROFI_WALL_DIR \"$WALL_DIR\"|" "$SHELL_RC"
    else
        sed -i "s|export ROFI_WALL_DIR=.*|export ROFI_WALL_DIR=\"$WALL_DIR\"|" "$SHELL_RC"
    fi
else
    echo "Adding ROFI_WALL_DIR to $SHELL_RC..."
    echo "" >> "$SHELL_RC"
    echo "# rofi-wallpaper-changer" >> "$SHELL_RC"
    if [[ "$SHELL" == *"fish"* ]]; then
        echo "set -x ROFI_WALL_DIR \"$WALL_DIR\"" >> "$SHELL_RC"
    else
        echo "export ROFI_WALL_DIR=\"$WALL_DIR\"" >> "$SHELL_RC"
    fi
fi

echo ""
echo "Installation complete!"
echo "Make sure to place some wallpapers in $WALL_DIR"
echo "Restart your terminal or run: source $SHELL_RC"
echo "Then, you can use the command 'change_wall' to open the picker."
