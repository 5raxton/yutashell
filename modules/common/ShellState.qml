pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---- runtime shell state (never persisted) ----
    property bool panelOpen: false

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    function openPanel() {
        root.panelOpen = true;
    }

    function closePanel() {
        root.panelOpen = false;
    }

    // ---- persisted prefs (auto-written on change) ----
    readonly property alias scheme: adapter.scheme
    readonly property alias followWallpaper: adapter.followWallpaper
    readonly property alias wallpaperPath: adapter.wallpaperPath
    readonly property alias barTray: adapter.barTray
    readonly property alias barStats: adapter.barStats
    readonly property alias barClock: adapter.barClock

    function set(key, value) {
        adapter[key] = value;
        stateFile.writeAdapter();
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/yutashell/state.json"
        printErrors: false
        blockLoading: true

        adapter: JsonAdapter {
            id: adapter

            // appearance
            property string scheme: "acid"
            property bool followWallpaper: false
            property string wallpaperPath: ""

            // matugen template registry (JSON array of {id,input,output,postHook,enabled})
            property string templatesJson: ""

            // bar segments
            property bool barTray: true
            property bool barStats: true
            property bool barClock: true
        }
    }

    function seedTemplates() {
        const t = Quickshell.env("HOME") + "/.config/matugen/templates/";
        const defaults = [
            {
                id: "alacritty",
                input: t + "alacritty.toml",
                output: "~/.config/alacritty/colors.toml",
                postHook: "",
                enabled: false
            },
            {
                id: "kitty",
                input: t + "kitty-colors.conf",
                output: "~/.config/kitty/themes/Matugen.conf",
                postHook: "pkill -SIGUSR1 kitty || true",
                enabled: false
            },
            {
                id: "fuzzel",
                input: t + "fuzzel.ini",
                output: "~/.config/fuzzel/colors.ini",
                postHook: "",
                enabled: false
            },
            {
                id: "hyprland",
                input: t + "hyprland-colors.conf",
                output: "~/.config/hypr/colors.conf",
                postHook: "",
                enabled: false
            },
            {
                id: "gtk3",
                input: t + "gtk-colors.css",
                output: "~/.config/gtk-3.0/colors.css",
                postHook: "",
                enabled: false
            },
            {
                id: "gtk4",
                input: t + "gtk-colors.css",
                output: "~/.config/gtk-4.0/colors.css",
                postHook: "",
                enabled: false
            },
            {
                id: "mako",
                input: t + "mako",
                output: "~/.config/mako/mako-colors",
                postHook: "makoctl reload || true",
                enabled: false
            },
            {
                id: "dunst",
                input: t + "dunstrc-colors",
                output: "~/.config/dunst/dunstrc",
                postHook: "dunstctl reload || true",
                enabled: false
            },
            {
                id: "starship",
                input: t + "starship-colors.toml",
                output: "~/.config/starship.toml",
                postHook: "",
                enabled: false
            },
            {
                id: "btop",
                input: t + "btop.theme",
                output: "~/.config/btop/themes/matugen.theme",
                postHook: "pkill -USR2 btop || true",
                enabled: false
            },
            {
                id: "rofi",
                input: t + "rofi-colors.rasi",
                output: "~/.config/rofi/colors.rasi",
                postHook: "",
                enabled: false
            }
        ];
        set("templatesJson", JSON.stringify(defaults));
    }

    Component.onCompleted: {
        if (stateFile.loadFailed)
            stateFile.writeAdapter();
    }
}
