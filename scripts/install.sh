#!/usr/bin/env bash
# yutashell installer — distro-aware dependency check + config install.
#
# Usage:
#   scripts/install.sh [--dry-run] [--dest DIR]
#
# What it does:
#   1. detects the distro's package manager
#   2. checks runtime dependencies, printing the exact package command for
#      anything missing (never auto-installs without --yes)
#   3. rsyncs the config into ~/.config/quickshell/yuta-qs (no clobber of
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

# package rows per distro: <binary>:<pacman>:<dnf>:<apt>:<zypper>
# probe the CLI binary each subsystem actually ships (nmcli/bluetoothctl,
# not the "networkmanager"/"bluez" meta names)
DEPS="
qs:quickshell:quickshell:quickshell:-
hyprland:hyprland:hyprland:hyprland:-
matugen:matugen:matugen:matugen:-
grim:grim:grim:grim:-
slurp:slurp:slurp:slurp:-
curl:curl:curl:curl:-
pipewire:pipewire:pipewire:pipewire:-
nmcli:networkmanager:NetworkManager:network-manager:NetworkManager
bluetoothctl:bluez:bluez:bluez:bluez
"

echo "== yutashell install =="
echo "source: $SRC"
echo "dest:   $DEST"
echo "distro pkg mgr: ${PKGMGR:-unknown}"

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
    echo "all runtime dependencies present"
fi

optional="cava cliphist gpu-screen-recorder hyprsunset hyprpicker ddcutil powerprofilesctl"
have_opt=""
for b in $optional; do
    command -v "$b" >/dev/null 2>&1 && have_opt="$have_opt $b"
done
echo "optional backends detected:${have_opt:- none}"
echo "(absent optional features hide themselves in the shell — see README)"

if [ "$DRY_RUN" = 1 ]; then
    echo "--dry-run: skipping file copy"
    exit 0
fi

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
    --exclude 'state.json' \
    "$SRC/" "$DEST/"
echo "installed to $DEST"
echo "launch with: qs -c $(basename "$DEST")   (or add to Hyprland autostart)"
