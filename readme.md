# NavWrite

<p align="center">
  <img src="navwriter.png" alt="NavWrite Logo" width="128">
</p>

<p align="center">
  <b>A fast, floating, distraction-free scratchpad for Linux.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux-orange.svg" alt="Platform: Linux">
  <img src="https://img.shields.io/badge/Toolkit-GTK%2B%203.0-blue.svg" alt="Toolkit: GTK 3">
  <img src="https://img.shields.io/badge/Language-Vala-purple.svg" alt="Language: Vala">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT">
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#key-features">Features</a> •
  <a href="#preview">Preview</a> •
  <a href="#installation">Installation</a> •
  <a href="#build-from-source">Build from Source</a> •
  <a href="#usage">Usage</a> •
  <a href="#data-storage">Storage</a> •
  <a href="#uninstallation">Uninstall</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**NavWrite** is designed around a single core principle: **capturing thoughts instantly without breaking your cognitive flow**.

Traditional note applications require opening heavy windows, managing documents, or manually saving files. NavWrite lives quietly on your screen as an ambient, draggable floating hub. Click it, type, and click away—notes are saved automatically and the editor dismisses instantly.

---

## Key Features

- **Ambient Floating Hub**: A lightweight, always-on-top draggable circular diode with a subtle pulsing animation that stays accessible from any workspace.
- **Single-Click Capture**: Open any note or start a blank scratchpad in under a second.
- **Zero-Friction Auto-Save**: Saves every single keystroke in real-time; closes automatically the moment you click away to return to your work.
- **Smart Chronological Organization**: Notes are automatically ordered by your most recently modified pads first, ensuring active thoughts remain at your fingertips without manual reordering.
- **Dynamic Scrollable Shelf**: Cleanly accommodates large collections of notes without overflowing the screen.
- **Automatic Cloud Sync**: Automatically detects and synchronizes with your Dropbox folder (`~/Dropbox/StickyNotes`) with zero configuration required. Falls back gracefully to local storage (`~/StickyNotes`).
- **System Tray Integration**: Easily hide the hub for deep-focus sessions, access settings, or quit cleanly from your desktop panel.
- **Strict Single-Instance**: Launching NavWrite while it is already active simply brings your existing hub and notes to the front.

---

## Preview

<p align="center">
  <img src="assets/note_2.png" width="500" alt="NavWrite Hub and Note List">
</p>

<p align="center">
  <img src="assets/note_1.png" width="500" alt="NavWrite Note Editor">
</p>

<p align="center">
  <img src="assets/note_3.png" width="500" alt="Quick Capture in Action">
</p>

---

## Installation

NavWrite includes a streamlined installer script that sets up the executable, desktop launcher, and application icon in standard user directories (`~/.local`).

### Automated Install

1. Clone or download this repository:
   ```bash
   git clone https://github.com/onisa-jr/navwrite.git
   cd navwrite
   ```

2. Run the installer:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. Launch **NavWrite** from your desktop applications menu or by running:
   ```bash
   navwrite
   ```

---

## Build from Source

NavWrite is written in [Vala](https://wiki.gnome.org/Projects/Vala) and compiled to native machine code using GTK+ 3 and Cairo.

### Prerequisites (Ubuntu / Debian / Linux Mint)

```bash
sudo apt update
sudo apt install valac libgtk-3-dev gcc libm-dev
```

### Prerequisites (Arch Linux / Fedora)

- **Arch Linux**:
  ```bash
  sudo pacman -S vala gtk3
  ```
- **Fedora**:
  ```bash
  sudo dnf install vala gtk3-devel gcc
  ```

### Compile Command

```bash
valac --pkg gtk+-3.0 sticky_hub.vala -X -lm -o navwrite
```

> **Note:** The `-X -lm` flag links the C standard math library, which powers the real-time sine-wave diode pulse animation.

---

## Usage

| Action | How to Perform |
| :--- | :--- |
| **Move the Hub** | Click and drag the circular green diode anywhere on your display. |
| **View Notes Shelf** | Click the hub once to toggle the notes menu. |
| **Create a Note** | Click `+ New Note` at the bottom of the menu shelf. |
| **Edit a Note** | Click any note title from the list. |
| **Delete a Note** | Click the `✕` on the right side of any note and confirm `Yes`. |
| **Dismiss & Auto-Save** | Click anywhere outside the editor window. NavWrite auto-saves and closes immediately. |
| **Hide / Restore Hub** | Right-click the system tray icon and select **Hide Hub** or **Show Hub**. |

---

## Data Storage

All notes are stored as plain text (`.txt`) files, making your notes transparent, portable, and easy to back up, grep, or edit with standard UNIX utilities:

- **With Dropbox**: `~/Dropbox/StickyNotes/`
- **Local Fallback**: `~/StickyNotes/`

---

## Uninstallation

To remove NavWrite from your system, simply run:

```bash
./install.sh --uninstall
```

Or remove the installed files manually:

```bash
rm -f ~/.local/bin/navwrite
rm -f ~/.local/share/applications/navwrite.desktop
rm -f ~/.local/share/icons/navwriter.png
update-desktop-database ~/.local/share/applications 2>/dev/null
```

> Your notes in `~/Dropbox/StickyNotes/` or `~/StickyNotes/` remain untouched and safe.

---

## Architecture & Design

- **Core Framework**: Vala & GTK+ 3.0 (`Gtk.Application`, `Gtk.Window`, Cairo vector rendering).
- **Single-Instance Enforcement**: Managed via `GApplication` with D-Bus registration (`com.navwrite.stickybubble`).
- **Dynamic Placement Engine**: Intelligent collision detection that positions cards based on available monitor screen geometry and edge boundaries.
- **Non-Blocking Persistence**: Auto-save triggers on title and text buffer modifications with zero UI stutter.

---

## Roadmap

- [ ] Multi-note simultaneous pinning
- [ ] Keyboard shortcut daemon (global hotkey toggle)
- [ ] Markdown syntax highlighting
- [ ] Configurable color themes and diode pulse styles
- [ ] Optional client-side AES-256 note encryption

---

## License

This project is licensed under the [MIT License](LICENSE).
