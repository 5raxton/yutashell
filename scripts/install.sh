#!/usr/bin/env bash
# yutashell installer — distro-aware dependency check + config install.
#
# Usage:
#   scripts/install.sh [--dry-run] [--yes] [--dest DIR]
#
# What it does:
#   1. detects the distro's package manager
#   2. checks runtime dependencies, printing the exact package command for
#      anything missing (never auto-installs without --yes)
#   3. checks optional backends and reports what's available
#   4. rsyncs the config into ~/.config/quickshell/yuta-qs (no clobber of
#      state.json — runtime state stays where it is)
set -u

DRY_RUN=0
ASSUME_YES=0
DEST="${HOME}/.config/quickshell/yuta-qs"
SRC="$(cd "$(dirname "$0")/.." && pwd)"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --yes) ASSUME_YES=1 ;;
        --dest) DEST="$2"; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
done

# ---- distro detection -------------------------------------------------------
PKGMGR=""
if command -v pacman >/dev/null 2>&1; then PKGMGR="pacman"
elif command -v dnf >/dev/null 2>&1; then PKGMGR="dnf"
elif command -v apt-get >/dev/null 2>&1; then PKGMGR="apt"
elif command -v zypper >/dev/null 2>&1; then PKGMGR="zypper"
elif command -v emerge >/dev/null 2>&1; then PKGMGR="emerge"
fi

# ---- required dependencies --------------------------------------------------
# probe the CLI binary each subsystem actually ships
# columns: binary:pacman:dnf:apt:zypper:emerge
DEPS="
qs:quickshell:quickshell:quickshell:quickshell:quickshell
hyprctl:hyprland:hyprland:hyprland:hyprland:hyprland
matugen:matugen:matugen:matugen:matugen:matugen
grim:grim:grim:grim:grim:grim
slurp:slurp:slurp:slurp:slurp:slurp
curl:curl:curl:curl:curl:curl
wl-copy:wl-clipboard:wl-clipboard:wl-clipboard:wl-clipboard:wl-clipboard
cliphist:cliphist:cliphist:cliphist:cliphist:cliphist
awww:awww:awww:awww:awww:awww
jq:jq:jq:jq:jq:jq
pipewire:pipewire:pipewire:pipewire:pipewire:pipewire
nmcli:networkmanager:NetworkManager:network-manager:NetworkManager:networkmanager
bluetoothctl:bluez:bluez:bluez:bluez:bluez
"

echo "== yutashell install =="
echo "source: $SRC"
echo "dest:   $DEST"
echo "distro pkg mgr: ${PKGMGR:-unknown}"
echo

missing=""
for row in $DEPS; do
    bin="${row%%:*}"
    rest="${row#*:}"
    if ! command -v "$bin" >/dev/null 2>&1; then
        case "$PKGMGR" in
            pacman) pkg="$(echo "$rest" | cut -d: -f1)" ;;
            dnf)    pkg="$(echo "$rest" | cut -d: -f2)" ;;
            apt)    pkg="$(echo "$rest" | cut -d: -f3)" ;;
            zypper) pkg="$(echo "$rest" | cut -d: -f4)" ;;
            emerge) pkg="$(echo "$rest" | cut -d: -f5)" ;;
            *)      pkg="$bin (install manually)" ;;
        esac
        echo "MISSING: $bin"
        [ "$pkg" != "-" ] && missing="$missing $pkg"
    fi
done

if [ -n "$missing" ]; then
    case "$PKGMGR" in
        pacman) cmd="sudo pacman -S --needed$missing" ;;
        dnf)    cmd="sudo dnf install$missing" ;;
        apt)    cmd="sudo apt install$missing" ;;
        zypper) cmd="sudo zypper install$missing" ;;
        emerge) cmd="sudo emerge --ask --oneshot$missing" ;;
        *)      cmd="(no package manager detected)$missing" ;;
    esac
    echo
    echo "to install missing deps:"
    echo "  $cmd"
    if [ "$ASSUME_YES" = 1 ] && [ "$PKGMGR" != "" ]; then
        echo "--yes given: running the command above"
        [ "$DRY_RUN" = 0 ] && sh -c "$cmd"
    fi
else
    echo "all required dependencies present"
fi

# ---- optional backends ------------------------------------------------------
echo
echo "--- optional backends ---"
OPTIONAL_BINS="cava hyprsunset hyprpicker ddcutil powerprofilesctl gpu-screen-recorder checkupdates"
OPTIONAL_PKGS=(
    "cava:audio visualizer in the bar"
    "hyprsunset:night light (wayland)"
    "hyprpicker:color picker"
    "ddcutil:external monitor brightness (DDC/CI)"
    "powerprofilesctl:power profile switching (power-profiles-daemon)"
    "gpu-screen-recorder:screen recording widget"
    "checkupdates:package update checker"
    "noto-fonts-cjk:Japanese labels (romaji fallback otherwise)"
)

have_opt=""
missing_opt=""
for item in "${OPTIONAL_PKGS[@]}"; do
    bin="${item%%:*}"
    desc="${item#*:}"
    if command -v "$bin" >/dev/null 2>&1; then
        have_opt="$have_opt $bin"
    else
        missing_opt="$missing_opt  $bin — $desc"
    fi
done
echo "optional backends detected:${have_opt:- none}"
if [ -n "$missing_opt" ]; then
    echo "optional backends missing:${missing_opt}"
fi
echo "(absent optional features hide themselves in the shell — see README)"

# ---- font check -------------------------------------------------------------
echo
echo "--- fonts ---"
if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
    echo "JetBrainsMono Nerd Font: found"
else
    echo "JetBrainsMono Nerd Font: NOT FOUND (required — install from nerd-fonts.com)"
fi
if fc-list 2>/dev/null | grep -qi "noto.*cjk"; then
    echo "noto-fonts-cjk: found (JP labels enabled)"
else
    echo "noto-fonts-cjk: not found (romaji fallback — optional)"
fi

if [ "$DRY_RUN" = 1 ]; then
    echo
    echo "--dry-run: skipping file copy"
    exit 0
fi

# ---- install ----------------------------------------------------------------
echo
command -v rsync >/dev/null 2>&1 || { echo "rsync required for install step" >&2; exit 1; }
if [ "$(realpath "$SRC")" = "$(realpath "$DEST")" ]; then
    echo "source and destination are the same directory — nothing to copy"
    exit 0
fi
mkdir -p "$(dirname "$DEST")"
rsync -a --delete \
    --exclude '.git/' \
    --exclude 'REFERENCEREADONLY/' \
    --exclude 'dist/' \
    --exclude '*.log' \
    "$SRC/" "$DEST/"
echo "installed to $DEST"
echo
echo "next steps:"
echo "  1. add to Hyprland autostart:  exec-once = qs -c yuta-qs"
echo "  2. bind keys (see docs/ipc.md) — e.g. SUPER+SPACE -> qs ipc call launcher toggle"
echo "  3. first launch: qs -c yuta-qs"
