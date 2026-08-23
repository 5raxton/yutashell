#!/usr/bin/env bash
# YUTASHELL install / bootstrap
# Checks the dependency matrix and optionally installs the missing pieces on
# Arch. Non-destructive — every step is a checklist; use --install to pull
# packages, --link to symlink this repo into ~/.config/quickshell.
set -u

CONFIG_DIR="$HOME/.config/quickshell/yuta-qs"
REQUIRED=(quickshell ttf-jetbrains-mono-nerd matugen awww grim slurp wl-clipboard cliphist)
OPTIONAL=(noto-fonts-cjk cava hyprsunset ddcutil power-profiles-daemon hyprpicker pacman-contrib gpu-screen-recorder networkmanager bluez pipewire wireplumber)

have() { command -v "$1" >/dev/null 2>&1; }
pkg() { pacman -Q "$1" >/dev/null 2>&1; }

say()  { printf '\033[1;32m[ok]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[--]\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31m[!!]\033[0m %s\n' "$1"; }

echo "YUTASHELL bootstrap — dependency matrix"
echo "---------------------------------------"

missing_required=()
for p in "${REQUIRED[@]}"; do
    if pkg "$p"; then say "required  $p"; else warn "required  $p (missing)"; missing_required+=("$p"); fi
done

echo
for p in "${OPTIONAL[@]}"; do
    if pkg "$p"; then say "optional  $p"; else warn "optional  $p (missing — related features hide gracefully)"; fi
done

echo
if [ "${#missing_required[@]}" -gt 0 ]; then
    echo "Missing required packages: ${missing_required[*]}"
    if [[ "${1:-}" == "--install" ]]; then
        echo "Installing…"
        sudo pacman -S --needed "${missing_required[@]}"
    else
        echo "Run: $0 --install   to install them (or install manually)."
    fi
else
    say "all required deps present"
fi

if [[ "${1:-}" == "--install" ]]; then
    echo "Installing optional packages…"
    sudo pacman -S --needed "${OPTIONAL[@]}"
fi

if [[ "${1:-}" == "--link" || "${1:-}" == "--install" ]]; then
    mkdir -p "$(dirname "$CONFIG_DIR")"
    if [ ! -e "$CONFIG_DIR" ]; then
        ln -s "$(pwd)" "$CONFIG_DIR"
        say "linked repo -> $CONFIG_DIR"
    elif [ -L "$CONFIG_DIR" ]; then
        say "already linked"
    else
        warn "$CONFIG_DIR exists and is not a symlink — leaving it alone"
    fi
fi

echo
echo "Next steps:"
echo "  1. Add to your Hyprland/Helmsman autostart:  qs -c yuta-qs   (or quickshell -p $CONFIG_DIR)"
echo "  2. Bind keys (see README 'Keybinds & IPC') — e.g. SUPER A -> qs ipc call launcher toggle"
echo "  3. Fonts: JetBrainsMono Nerd Font is required; noto-fonts-cjk enables the Japanese labels"
