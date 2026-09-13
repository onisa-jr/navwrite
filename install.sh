#!/usr/bin/env bash

# ==============================================================================
# Navwrite - Application Installer
# ==============================================================================
# Installs the compiled binary, desktop launcher, and application icon
# to the standard user local directories (~/.local).
# ==============================================================================

set -euo pipefail

APP_NAME="navwrite"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_FILE="$APP_DIR/navwrite.desktop"
ICON_FILE="navwriter.png"

# Handle uninstall flag
if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
    echo "Uninstalling Navwrite..."
    rm -f "$BIN_DIR/$APP_NAME"
    rm -f "$DESKTOP_FILE"
    rm -f "$ICON_DIR/$ICON_FILE"
    update-desktop-database "$APP_DIR" 2>/dev/null || true
    echo "Navwrite has been successfully uninstalled."
    exit 0
fi

echo "Installing Navwrite..."

# 1. Detect binary
SOURCE_BIN=""
if [[ -f "./navwrite" ]]; then
    SOURCE_BIN="./navwrite"
elif [[ -f "./sticky_hub" ]]; then
    SOURCE_BIN="./sticky_hub"
fi

if [[ -z "$SOURCE_BIN" ]]; then
    echo "Error: Binary not found in current directory."
    echo "Please compile first using: valac --pkg gtk+-3.0 sticky_hub.vala -X -lm -o navwrite"
    exit 1
fi

chmod +x "$SOURCE_BIN"

# 2. Install binary
mkdir -p "$BIN_DIR"
cp --remove-destination "$SOURCE_BIN" "$BIN_DIR/$APP_NAME"
echo "  Installed binary to $BIN_DIR/$APP_NAME"

# 3. Install application icon
mkdir -p "$ICON_DIR"
if [[ -f "./$ICON_FILE" ]]; then
    cp --remove-destination "./$ICON_FILE" "$ICON_DIR/$ICON_FILE"
    ICON_TARGET="$ICON_DIR/$ICON_FILE"
    echo "  Installed application icon to $ICON_DIR/$ICON_FILE"
else
    ICON_TARGET="accessories-text-editor"
    echo "  Warning: $ICON_FILE not found, using system fallback icon."
fi

# 4. Create desktop entry
mkdir -p "$APP_DIR"
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=Navwrite
GenericName=Sticky Notes
Comment=Fast, floating scratchpad with Dropbox sync
Exec=$BIN_DIR/$APP_NAME
Icon=$ICON_TARGET
Terminal=false
Categories=Utility;TextEditor;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"
update-desktop-database "$APP_DIR" 2>/dev/null || true
echo "  Installed desktop entry to $DESKTOP_FILE"

echo ""
echo "Navwrite has been successfully installed."
echo "You can launch it from your applications menu or run 'navwrite' in your terminal."