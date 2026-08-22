pragma Singleton
import QtQuick
import Quickshell

// Registry of every app template shipped in `theme/matugen/catalog/`.
// Sourced from github.com/InioX/matugen-themes (MIT) — output paths and post
// hooks follow upstream's documented setup. Everything ships DISABLED; the
// user opts in per app. Custom user entries live in ShellState alongside.
Singleton {
    id: root

    readonly property string catalogDir: Quickshell.shellDir + "/theme/matugen/catalog"
    readonly property string credit: "templates © InioX/matugen-themes (MIT)"

    readonly property var groups: [
        { id: "TERMINAL", jp: "端末" },
        { id: "EDITOR", jp: "編集" },
        { id: "SHELL", jp: "殻" },
        { id: "BROWSER", jp: "瀏覽" },
        { id: "LAUNCHER", jp: "発射" },
        { id: "NOTIFY", jp: "通知" },
        { id: "COMPOSITOR", jp: "合成" },
        { id: "DESKTOP", jp: "桌面" },
        { id: "MEDIA", jp: " media " },
        { id: "SYSTEM", jp: "系統" }
    ]

    // Each entry: { id, label, group, note, files:[{input,output,post,extras}] }
    // input is relative to catalogDir; output/post support "~"; "@CATALOG@"
    // expands to catalogDir; post strings may contain matugen {{placeholders}}.
    readonly property var entries: [
        // ===== TERMINAL =====
        { id: "alacritty", label: "Alacritty", group: "TERMINAL", files: [{ input: "alacritty.toml", output: "~/.config/alacritty/colors.toml", post: "" }], note: "add  import = [\"colors.toml\"]  to alacritty.toml" },
        { id: "kitty", label: "Kitty", group: "TERMINAL", files: [{ input: "kitty-colors.conf", output: "~/.config/kitty/themes/Matugen.conf", post: "pkill -SIGUSR1 kitty || true" }], note: "select theme Matugen once in kitty (kitten themes)" },
        { id: "ghostty", label: "Ghostty", group: "TERMINAL", files: [{ input: "ghostty", output: "~/.config/ghostty/themes/Matugen", post: "pkill -SIGUSR2 ghostty || true" }], note: "set  theme = \"Matugen\"  in config" },
        { id: "wezterm", label: "WezTerm", group: "TERMINAL", files: [{ input: "wezterm_theme.toml", output: "~/.config/wezterm/colors/matugen_theme.toml", post: "[ -f '$HOME/.config/wezterm/wezterm.lua' ] && touch '$HOME/.config/wezterm/wezterm.lua' || true" }], note: "color_scheme = \"matugen_theme\" in wezterm.lua" },
        { id: "ansi-sequences", label: "ANSI Sequences", group: "TERMINAL", files: [{ input: "terminal-sequences", output: "~/.cache/terminal-sequences", post: "cat '~/.cache/terminal-sequences' /dev/null | tee /dev/pts/[0-9]* >/dev/null 2>&1 || true" }], note: "pushes colors into every open tty; add cat to shell profile for persistence" },
        { id: "tmux", label: "tmux", group: "TERMINAL", files: [{ input: "tmux-colors.conf", output: "~/.config/tmux/generated.conf", post: "tmux source-file '~/.config/tmux/generated.conf' >/dev/null 2>&1 || true" }], note: "source generated.conf from tmux.conf" },
        { id: "mcfly", label: "McFly", group: "TERMINAL", files: [{ input: "mcfly.toml", output: "~/.local/share/mcfly/config.toml", post: "" }], note: "" },
        { id: "windows-terminal", label: "Windows Terminal", group: "TERMINAL", files: [{ input: "windows_term.json", output: "~/.local/state/yutashell/generated/windows_terminal.json", post: "" }], note: "generates the scheme preset; import manually on Windows" },

        // ===== EDITOR =====
        { id: "helix", label: "Helix", group: "EDITOR", files: [{ input: "helix.toml", output: "~/.config/helix/themes/matugen.toml", post: "" }], note: "theme = \"matugen\" in config.toml" },
        { id: "micro", label: "Micro", group: "EDITOR", files: [{ input: "micro.micro", output: "~/.config/micro/colorschemes/matugen.micro", post: "" }], note: "set colorscheme matugen" },
        { id: "neovim", label: "Neovim", group: "EDITOR", files: [{ input: "nvim-colors.vim", output: "~/.config/nvim/colors/matugen.vim", post: "pkill -SIGUSR1 nvim || true" }], note: "colorscheme matugen + SIGUSR1 autocmd in init" },
        { id: "zed", label: "Zed", group: "EDITOR", files: [{ input: "zed-colors.json", output: "~/.config/zed/themes/matugen.json", post: "" }], note: "pick Matugen Dark/Light in settings" },
        { id: "vscode", label: "VS Code", group: "EDITOR", files: [{ input: "vscode-colors", output: "~/.cache/matugen/vscode-colors", post: "" }, { input: "vscode-colors.json", output: "~/.cache/matugen/vscode-colors.json", post: "" }], note: "needs the Matugen Theme extension" },
        { id: "opencode", label: "OpenCode", group: "EDITOR", files: [{ input: "opencode-colors.json", output: "~/.config/opencode/themes/matugen.json", post: "" }], note: "/theme -> matugen, restart" },
        { id: "obsidian", label: "Obsidian", group: "EDITOR", files: [{ input: "obsidian.css", output: "~/.local/state/yutashell/generated/obsidian.css", post: "" }], note: "point a vault CSS snippet @import at the output path" },
        { id: "rmpc", label: "rmpc", group: "EDITOR", files: [{ input: "rmpc/rmpc.ron", output: "~/.config/rmpc/themes/matugen.ron", post: "" }], note: "theme: Some(\"matugen\") in config.ron" },

        // ===== SHELL =====
        { id: "starship", label: "Starship", group: "SHELL", files: [{ input: "starship-colors.toml", output: "~/.config/starship.toml", post: "" }], note: "WARNING: replaces ~/.config/starship.toml wholesale" },

        // ===== BROWSER =====
        { id: "firefox", label: "Firefox", group: "BROWSER", files: [{ input: "firefox-colors.css", output: "~/.local/state/yutashell/generated/firefox/chrome/colors.css", post: "" }], note: "@import the output (absolute path) from your profile's userChrome.css" },
        { id: "zen-browser", label: "Zen Browser", group: "BROWSER", files: [{ input: "zen-userchrome.css", output: "~/.local/state/yutashell/generated/zen/zen-userChrome.css", post: "" }, { input: "zen-usercontent.css", output: "~/.local/state/yutashell/generated/zen/zen-userContent.css", post: "" }], note: "edit outputs to your profile chrome/ dir, then @import from userChrome.css" },
        { id: "pywalfox", label: "Pywalfox", group: "BROWSER", files: [{ input: "pywalfox-colors.json", output: "~/.cache/wal/colors.json", post: "pywalfox update >/dev/null 2>&1 || true" }], note: "requires the Pywalfox extension" },
        { id: "vivaldi", label: "Vivaldi", group: "BROWSER", files: [{ input: "vivaldi.css", output: "~/.local/state/yutashell/generated/vivaldi.css", post: "" }], note: "select this folder in vivaldi custom UI modifications" },
        { id: "steam", label: "Steam (adwsteam-gtk)", group: "BROWSER", files: [{ input: "steam.css", output: "~/.config/AdwSteamGtk/custom.css", post: "adwaita-steam-gtk -i >/dev/null 2>&1 || true" }], note: "enable Custom CSS in AdwSteamGtk prefs" },
        { id: "discord-midnight", label: "Discord // Midnight", group: "BROWSER", files: [{ input: "midnight-discord.css", output: "~/.config/vesktop/themes/midnight-discord.css", post: "" }], note: "activate in vencord themes" },
        { id: "discord-system24", label: "Discord // system24", group: "BROWSER", files: [{ input: "system24.css", output: "~/.config/vesktop/themes/system24.css", post: "" }], note: "activate in vencord themes" },
        { id: "telegram", label: "Telegram", group: "BROWSER", files: [{ input: "telegram.tdesktop-theme", output: "~/.local/state/yutashell/generated/telegram.tdesktop-theme", post: "" }], note: "drag the generated file into a chat to apply" },
        { id: "heroic", label: "Heroic Launcher", group: "BROWSER", files: [{ input: "heroic.css", output: "~/.local/state/yutashell/generated/heroic.css", post: "" }], note: "set Custom Themes Path to the output folder" },

        // ===== LAUNCHER / MENU =====
        { id: "fuzzel", label: "Fuzzel", group: "LAUNCHER", files: [{ input: "fuzzel.ini", output: "~/.config/fuzzel/colors.ini", post: "" }], note: "add  include=~/.config/fuzzel/colors.ini  to fuzzel.ini" },
        { id: "rofi", label: "Rofi", group: "LAUNCHER", files: [{ input: "rofi-colors.rasi", output: "~/.config/rofi/colors.rasi", post: "" }], note: "@import \"colors.rasi\" from config.rasi" },
        { id: "wofi", label: "Wofi", group: "LAUNCHER", files: [{ input: "colors.css", output: "~/.config/wofi/colors.css", post: "" }], note: "@import \"colors.css\" from style.css" },
        { id: "television", label: "Television", group: "LAUNCHER", files: [{ input: "television.toml", output: "~/.config/television/themes/matugen.toml", post: "" }], note: "[ui] theme = \"matugen\"" },
        { id: "wlogout", label: "wlogout", group: "LAUNCHER", files: [{ input: "colors.css", output: "~/.config/wlogout/colors.css", post: "" }], note: "@import \"colors.css\" from style.css" },
        { id: "prismlauncher", label: "PrismLauncher", group: "LAUNCHER", files: [{ input: "prismlauncher.json", output: "~/.local/share/PrismLauncher/themes/Matugen/theme.json", post: "" }], note: "appearance -> Matugen" },

        // ===== NOTIFY =====
        { id: "mako", label: "Mako", group: "NOTIFY", files: [{ input: "mako", output: "~/.config/mako/mako-colors", post: "makoctl reload >/dev/null 2>&1 || true" }], note: "add  include=~/.config/mako/mako-colors  to config" },
        { id: "dunst", label: "Dunst", group: "NOTIFY", files: [{ input: "dunstrc-colors", output: "~/.config/dunst/dunstrc", post: "dunstctl reload >/dev/null 2>&1 || true" }], note: "WARNING: replaces the whole dunstrc" },
        { id: "swaync", label: "SwayNC", group: "NOTIFY", files: [{ input: "colors.css", output: "~/.config/swaync/colors.css", post: "swaync-client -rs >/dev/null 2>&1 || true" }], note: "@import \"colors.css\" from style.css" },

        // ===== COMPOSITOR =====
        { id: "hyprland", label: "Hyprland (.conf)", group: "COMPOSITOR", files: [{ input: "hyprland-colors.conf", output: "~/.config/hypr/colors.conf", post: "" }], note: "source = colors.conf in hyprland.conf" },
        { id: "hyprland-lua", label: "Hyprland (.lua)", group: "COMPOSITOR", files: [{ input: "hyprland-colors.lua", output: "~/.config/hypr/colors.lua", post: "" }], note: "require(\"colors\") in hyprland.lua — Helmsman style" },
        { id: "hyprlock", label: "Hyprlock", group: "COMPOSITOR", files: [{ input: "hyprland-colors.conf", output: "~/.config/hypr/hyprlock-colors.conf", post: "" }], note: "source from hyprlock.conf" },
        { id: "sway", label: "Sway", group: "COMPOSITOR", files: [{ input: "sway-colors.conf", output: "~/.config/sway/colors.conf", post: "swaymsg reload >/dev/null 2>&1 || true" }], note: "include colors.conf" },
        { id: "swaybar", label: "Swaybar", group: "COMPOSITOR", files: [{ input: "swaybar-colors.conf", output: "~/.config/sway/bar-colors.conf", post: "swaymsg reload >/dev/null 2>&1 || true" }], note: "include bar-colors.conf" },
        { id: "niri", label: "Niri", group: "COMPOSITOR", files: [{ input: "niri-colors.kdl", output: "~/.config/niri/colors.kdl", post: "niri msg action load-config-file >/dev/null 2>&1 || true" }], note: "include ./colors.kdl" },
        { id: "labwc", label: "Labwc", group: "COMPOSITOR", files: [{ input: "labwc", output: "~/.config/labwc/themerc-override", post: "labwc -reload >/dev/null 2>&1 || true" }], note: "" },
        { id: "mango", label: "MangoWC", group: "COMPOSITOR", files: [{ input: "mango.conf", output: "~/.config/mango/colors.conf", post: "mmsg -d reload_config >/dev/null 2>&1 || true" }], note: "source=~/.config/mango/colors.conf" },
        { id: "waybar", label: "Waybar", group: "COMPOSITOR", files: [{ input: "colors.css", output: "~/.config/waybar/colors.css", post: "pkill -SIGUSR2 waybar || true" }], note: "@import \"colors.css\" from style.css" },
        { id: "hyprwat", label: "Hyprwat", group: "COMPOSITOR", files: [{ input: "hyprwat-colors.toml", output: "~/.config/hyprwat/hyprwat-colors.conf", post: "" }], note: "source from hyprwat.conf" },

        // ===== DESKTOP =====
        { id: "gtk3", label: "GTK3", group: "DESKTOP", files: [{ input: "gtk-colors.css", output: "~/.config/gtk-3.0/colors.css", post: "gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-{{mode}}' >/dev/null 2>&1 || true" }], note: "@import 'colors.css'; from gtk-3.0/gtk.css; needs adw-gtk3 for the hook" },
        { id: "gtk4", label: "GTK4", group: "DESKTOP", files: [{ input: "gtk-colors.css", output: "~/.config/gtk-4.0/colors.css", post: "" }], note: "@import 'colors.css'; from gtk-4.0/gtk.css" },
        { id: "qt5ct", label: "Qt5ct", group: "DESKTOP", files: [{ input: "qtct-colors.conf", output: "~/.config/qt5ct/colors/matugen.conf", post: "" }], note: "set color_scheme_path in qt5ct.conf" },
        { id: "qt6ct", label: "Qt6ct", group: "DESKTOP", files: [{ input: "qtct-colors.conf", output: "~/.config/qt6ct/colors/matugen.conf", post: "" }], note: "set color_scheme_path in qt6ct.conf" },
        { id: "kde-colorscheme", label: "KDE Color Scheme", group: "DESKTOP", files: [{ input: "Matugen.colors", output: "~/.local/share/color-schemes/Matugen.colors", post: "" }], note: "pick Matugen in systemsettings" },
        { id: "kvantum", label: "Kvantum", group: "DESKTOP", files: [{ input: "kvantum-colors.kvconfig", output: "~/.config/Kvantum/matugen/matugen.kvconfig", post: "" }, { input: "kvantum-colors.svg", output: "~/.config/Kvantum/matugen/matugen.svg", post: "" }], note: "theme=matugen in kvantum.kvconfig" },
        { id: "gnome-shell", label: "GNOME Shell", group: "DESKTOP", files: [{ input: "gnome-shell.css", output: "~/.themes/Material-Gnome/gnome-shell/gnome-shell.css", post: "dconf write /org/gnome/shell/extensions/user-theme/name \"'Material-Gnome'\" >/dev/null 2>&1 || true" }], note: "needs user-themes extension + index.theme in ~/.themes/Material-Gnome" },
        { id: "cosmic", label: "COSMIC", group: "DESKTOP", files: [{ input: "cosmic_theme.ron", output: "~/.config/matugen/themes/matugen_cosmic.theme.ron", post: "python3 '@CATALOG@/cosmic_postprocess.py' '~/.config/matugen/themes/matugen_cosmic.theme.ron' >/dev/null 2>&1 || true" }], note: "import the generated theme in Cosmic Settings" },
        { id: "papirus-folders", label: "Papirus Folders", group: "DESKTOP", files: [{ input: "papirus-color", output: "~/.cache/matugen/papirus-color", post: "nohup sudo -n papirus-folders -C {{ closest_color }} -u >/dev/null 2>&1 &", extras: "colors_to_compare = [\n    { name = \"black\", color = \"#4f4f4f\" },\n    { name = \"blue\", color = \"#5294e2\" },\n    { name = \"bluegrey\", color = \"#607d8b\" },\n    { name = \"brown\", color = \"#ae8e6c\" },\n    { name = \"carmine\", color = \"#a30002\" },\n    { name = \"cyan\", color = \"#00bcd4\" },\n    { name = \"darkcyan\", color = \"#45abb7\" },\n    { name = \"deeporange\", color = \"#eb6637\" },\n    { name = \"green\", color = \"#87b158\" },\n    { name = \"grey\", color = \"#8e8e8e\" },\n    { name = \"indigo\", color = \"#5c6bc0\" },\n    { name = \"magenta\", color = \"#ca71df\" },\n    { name = \"nordic\", color = \"#81a1c1\" },\n    { name = \"orange\", color = \"#ee923a\" },\n    { name = \"palebrown\", color = \"#d1bfae\" },\n    { name = \"paleorange\", color = \"#eeca8f\" },\n    { name = \"pink\", color = \"#f06292\" },\n    { name = \"red\", color = \"#e25252\" },\n    { name = \"teal\", color = \"#16a085\" },\n    { name = \"violet\", color = \"#7e57c2\" },\n    { name = \"white\", color = \"#e4e4e4\" },\n    { name = \"yaru\", color = \"#676767\" },\n    { name = \"yellow\", color = \"#f9bd30\" },\n]\ncompare_to = '{{ colors.primary.default.hex }}'\nindex = 1" }], note: "needs passwordless sudoers for papirus-folders" },
        { id: "quickshell-palette", label: "Quickshell MD3 Palette", group: "DESKTOP", files: [{ input: "quickshell.json", output: "~/.local/state/yutashell/generated/quickshell-colors.json", post: "" }], note: "raw material-you palette json for other quickshell configs" },

        // ===== MEDIA =====
        { id: "spicetify", label: "Spicetify (Sleek)", group: "MEDIA", files: [{ input: "spicetify.ini", output: "~/.config/spicetify/Themes/Sleek/color.ini", post: "pgrep -x spicetify >/dev/null || spicetify apply -n >/dev/null 2>&1 || true" }], note: "current_theme=Sleek + color_scheme=matugen in config-xpui.ini" },
        { id: "cava", label: "Cava", group: "MEDIA", files: [{ input: "cava-colors.ini", output: "~/.config/cava/themes/matugen", post: "pkill -USR1 cava || true" }], note: "theme = 'matugen' in cava config" },

        // ===== SYSTEM =====
        { id: "btop", label: "btop++", group: "SYSTEM", files: [{ input: "btop.theme", output: "~/.config/btop/themes/matugen.theme", post: "pkill -USR2 btop || true" }], note: "choose matugen theme in btop settings" },
        { id: "yazi", label: "Yazi", group: "SYSTEM", files: [{ input: "yazi-theme.toml", output: "~/.config/yazi/theme.toml", post: "" }], note: "" },
        { id: "zellij", label: "Zellij", group: "SYSTEM", files: [{ input: "zellij-theme.kdl.tera", output: "~/.config/zellij/themes/matugen.kdl", post: "touch '~/.config/zellij/config.kdl' 2>/dev/null || true" }], note: "theme \"matugen\" in config.kdl" },
        { id: "zathura", label: "Zathura", group: "SYSTEM", files: [{ input: "zathura-colors", output: "~/.config/zathura/zathurarc", post: "" }], note: "WARNING: replaces the whole zathurarc" },
        { id: "clipse", label: "Clipse", group: "SYSTEM", files: [{ input: "clipse_theme.json", output: "~/.config/clipse/custom_theme.json", post: "" }], note: "" },
        { id: "wine", label: "Wine", group: "SYSTEM", files: [{ input: "wine.reg", output: "/tmp/wine.reg", post: "wine regedit /tmp/wine.reg >/dev/null 2>&1 || true" }], note: "imports colors into the default wine prefix" }
    ]

    function byId(id) {
        return root.entries.find(e => e.id === id) ?? null;
    }

    function labelOf(id) {
        const e = root.byId(id);
        return e ? e.label : id;
    }
}
