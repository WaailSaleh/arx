#!/bin/bash

# Cursor IDE Installation Script for Ubuntu
# This script installs Cursor IDE with desktop integration and command-line access

set -e # Exit on error

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}${GREEN}===== Cursor IDE Installation Script =====${RESET}"
echo -e "This script will install Cursor IDE with desktop integration"
echo ""

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${RED}This script is designed for Ubuntu. Proceed with caution on other distributions.${RESET}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install required dependencies
echo -e "${BLUE}Installing required dependencies...${RESET}"
sudo apt update

# For Ubuntu 24.04, use libfuse2t64, for older versions use libfuse2
if grep -q "24.04" /etc/os-release; then
    echo -e "${BLUE}Detected Ubuntu 24.04, installing libfuse2t64...${RESET}"
    sudo apt install -y libfuse2t64 wget
else
    echo -e "${BLUE}Installing libfuse2 for older Ubuntu versions...${RESET}"
    sudo apt install -y libfuse2 wget
fi

# Create necessary directories
echo -e "${BLUE}Creating directories...${RESET}"
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/share/icons

# Download Cursor AppImage
echo -e "${BLUE}Downloading Cursor AppImage...${RESET}"
CURSOR_URL="https://download.cursor.sh/linux/appImage/x64"
wget -O ~/.local/bin/cursor.AppImage "$CURSOR_URL"

# Make it executable
chmod +x ~/.local/bin/cursor.AppImage

# Download icon
echo -e "${BLUE}Downloading Cursor icon...${RESET}"
ICON_URL="https://us1.discourse-cdn.com/flex020/uploads/cursor1/original/2X/a/a4f78589d63edd61a2843306f8e11bad9590f0ca.png"
wget -O ~/.local/share/icons/cursor.png "$ICON_URL"

# Create desktop entry
echo -e "${BLUE}Creating desktop entry...${RESET}"
cat > ~/.local/share/applications/cursor.desktop << EOF
[Desktop Entry]
Name=Cursor AI IDE
GenericName=Code Editor
Comment=AI-powered code editor
Exec=$HOME/.local/bin/cursor.AppImage --no-sandbox %F
Icon=$HOME/.local/share/icons/cursor.png
Type=Application
Categories=Development;IDE;TextEditor;
MimeType=text/plain;inode/directory;
Keywords=cursor;code;editor;ai;development;programming;
StartupWMClass=Cursor
EOF

chmod +x ~/.local/share/applications/cursor.desktop

# Add command-line alias
echo -e "${BLUE}Setting up command-line access...${RESET}"
BASHRC="$HOME/.bashrc"
ALIAS_COMMENT="# Cursor IDE alias"

if ! grep -q "$ALIAS_COMMENT" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "$ALIAS_COMMENT" >> "$BASHRC"
    echo 'cursor() {' >> "$BASHRC"
    echo '    ~/.local/bin/cursor.AppImage --no-sandbox "$@" > /dev/null 2>&1 & disown' >> "$BASHRC"
    echo '}' >> "$BASHRC"
    
    # Also add to PATH if not already there
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
    fi
fi

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications
fi

echo -e "${BOLD}${GREEN}===== Installation Complete! =====${RESET}"
echo -e "Cursor IDE has been successfully installed!"
echo -e ""
echo -e "${BLUE}Usage:${RESET}"
echo -e "• Find Cursor in your applications menu"
echo -e "• Run 'cursor' or 'cursor .' in terminal (after restarting terminal)"
echo -e "• Or run directly: ~/.local/bin/cursor.AppImage"
echo -e ""
echo -e "${BLUE}Note:${RESET} Restart your terminal or run 'source ~/.bashrc' to use the 'cursor' command"
echo -e ""
echo -e "${GREEN}Enjoy coding with Cursor!${RESET}"