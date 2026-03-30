#!/bin/bash

# --- Navwrite Installer ---
# Run this script in the directory containing the compiled binary and logo.
# It moves them to your local directories and creates a menu shortcut.

APP_NAME="navwrite"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APP_DIR/navwrite.desktop"
ICON_FILE="navwriter.png"
ICON_DEST_DIR="$HOME/.local/share/icons"

echo " Preparing to install Navwrite..."

# Detect the binary (handles if you compiled without -o navwrite)
SOURCE_BIN="navwrite"
if [ ! -f "./$SOURCE_BIN" ] && [ -f "./sticky_hub" ]; then
    SOURCE_BIN="sticky_hub"
fi

# Check if the binary actually exists in the folder
if [ ! -f "./$SOURCE_BIN" ]; then
    echo " Error: Could not find the binary in this folder."
    echo "Make sure you are running this script from the extracted release folder."
    exit 1
fi

# Ensure the binary has execute permissions
chmod +x "./$SOURCE_BIN"

echo " Installing executable to $BIN_DIR..."
mkdir -p "$BIN_DIR"
# Copy and rename to navwrite if it was compiled as sticky_hub
cp "./$SOURCE_BIN" "$BIN_DIR/$APP_NAME"

# Handle the custom logo
if [ -f "./$ICON_FILE" ]; then
    echo " Installing custom logo..."
    mkdir -p "$ICON_DEST_DIR"
    cp "./$ICON_FILE" "$ICON_DEST_DIR/"
    ICON_PATH="$ICON_DEST_DIR/$ICON_FILE"
else
    echo " Warning: Logo $ICON_FILE not found! Using default icon."
    ICON_PATH="accessories-text-editor"
fi

echo " Creating Application Menu shortcut..."
mkdir -p "$APP_DIR"

# Write the .desktop file
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Name=Navwrite
Comment=Floating Sticky Notes with Dropbox Sync
Exec=$BIN_DIR/$APP_NAME
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Utility;TextEditor;
StartupNotify=true
EOF

# Make the shortcut executable
chmod +x "$DESKTOP_FILE"

# Update desktop database so the menu refreshes immediately (suppress errors if command not found)
update-desktop-database "$APP_DIR" 2>/dev/null

echo ""
echo " BOOM! Navwrite is now installed on your system with your custom logo."
echo " Press your Super/Windows key and search for 'Navwrite' to launch it!"