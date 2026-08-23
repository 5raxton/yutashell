pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    // ======== LIVE PALETTE TOKENS ========
    // Defaults double as the "acid" preset fallback. Everything below is
    // rewritable at runtime by the scheme engine — modules only ever read.
    property color bg: "#0a0a0c"
    property color bgAlt: "#101014"
    property color surface: "#17171c"
    property color ink: "#eae8e0"
    property color muted: "#6b6a63"
    property color faint: "#3f3e3a"
    property color hairline: "#1d1d22"
    property color lineStrong: "#2c2c34"
    property color acid: "#c8ff3d"
    property color acidDeep: "#8fbe1f"
    property color alert: "#ff3b52"

    // ======== STATIC TOKENS ========
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property bool jpEnabled: Qt.fontFamilies().some(f => /cjk|jp|japan/i.test(f))

    // ---- type ramp: five roles, nothing outside them ----
    readonly property int fsDisplay: 20   // page titles, hero text
    readonly property int fsTitle: 14     // section headers, emphasis
    readonly property int fsBody: 12      // THE reading size — rows, buttons, inputs
    readonly property int fsLabel: 10     // secondary labels, chips, meta
    readonly property int fsMicro: 8      // decorative chrome only (JP accents, watermarks)

    // ---- rhythm scale ----
    readonly property int sp1: 4          // intra-component
    readonly property int sp2: 8          // component padding baseline
    readonly property int sp3: 12         // related elements
    readonly property int sp4: 16         // sections
    readonly property int sp5: 24         // page margins
    readonly property int rowH: 40        // standard setting row
    readonly property int ctlH: 28        // buttons / fields
    readonly property int headH: 54       // panel header band
    readonly property int footH: 32       // panel footer band

    // ---- motion: positional indicators only; hover/focus snap ----
    // movFast/movMed: indicators + small moves. movSlow: surface entrances
    // (the shared drop-from-behind-the-bar choreography).
    readonly property int movFast: 120
    readonly property int movMed: 160
    readonly property int movSlow: 260
    // organism layer: movSnap = knob/chip micro-physics; movDrift = idle
    // breathing period (life runs slow, machine runs fast — never pulse text)
    readonly property int movSnap: 80
    readonly property int movDrift: 2600

    readonly property int barHeight: 44
    readonly property int outerPad: 14
    readonly property int sectionGap: 16

    readonly property string version: "0.7.0"

    // ======== SCHEME ENGINE ========
    readonly property var presets: [{
            id: "acid",
            label: "ACID"
        }, {
            id: "crimson",
            label: "CRIMSON"
        }, {
            id: "cyan",
            label: "CYAN"
        }, {
            id: "amber",
            label: "AMBER"
        }, {
            id: "catppuccin",
            label: "CATPPUCCIN"
        }, {
            id: "cyberpunk",
            label: "CYBERPUNK"
        }, {
            id: "doom",
            label: "DOOM"
        }, {
            id: "gruvbox",
            label: "GRUVBOX"
        }, {
            id: "mono",
            label: "MONOCHROME"
        }, {
            id: "tokyonight",
            label: "TOKYO NIGHT"
        }, {
            id: "kanagawa",
            label: "KANAGAWA"
        }, {
            id: "dracula",
            label: "DRACULA"
        }]

    property string activeScheme: "acid"
    property bool followWallpaper: false
    property string wallpaperSource: ""

    readonly property string sourceLabel: {
        if (root.followWallpaper)
            return root.wallpaperSource.length > 0 ? "WALL //" + root.wallpaperSource.toUpperCase() : "WALLPAPER";
        const p = root.presets.find(x => x.id === root.activeScheme);
        return p ? p.label : activeScheme.toUpperCase();
    }

    function schemePath(id) {
        const dir = Quickshell.shellDir;
        if (dir && dir.length > 0)
            return dir + "/theme/schemes/" + id + ".json";
        return Qt.resolvedUrl("schemes/" + id + ".json").toString();
    }

    function _applyTokens(map) {
        if (!map)
            return false;
        let hit = false;
        // JS objects preserve insertion order → bg is always transformed before
        // acid/alert, so the contrast fitting below can measure against it.
        for (const k in defaults) {
            if (typeof map[k] !== "string")
                continue;
            root[k] = root.dark ? map[k] : _toLight(map[k], k);
            hit = true;
        }
        if (hit) {
            _applyAccentOverride();
            checkContrast();
        }
        return hit;
    }

    function applyPreset(id) {
        schemeLoader.path = root.schemePath(id);
        schemeLoader.reload();
    }

    // ======== MODE (dark/light) & ACCENT OVERRIDE ========
    // Light mode is generated at runtime — every token map (scheme preset or
    // matugen wallpaper palette) is HSL-remapped to paper/ink, and acid/alert
    // are darkened just enough to pass the same contrast thresholds the
    // self-check asserts. No per-scheme light files to maintain.
    property bool dark: true

    function _h(hue) {
        return hue < 0 ? 0 : hue;
    }

    // darken a saturated token until it reads on the live light bg
    function _fitOnLight(col, minRatio) {
        let l = col.hslLightness;
        let out = col;
        let guard = 0;
        while (_ratio(out, root.bg) < minRatio && l > 0.06 && guard++ < 40) {
            l -= 0.02;
            out = Qt.hsla(_h(col.hslHue), col.hslSaturation, l, 1);
        }
        return out;
    }

    function _toLight(src, role) {
        const c = Qt.color(String(src));
        const h = _h(c.hslHue);
        const s = c.hslSaturation;
        const l = c.hslLightness;
        switch (role) {
        case "bg":
            return Qt.hsla(h, Math.min(s, 0.10), 0.94, 1);
        case "bgAlt":
            return Qt.hsla(h, Math.min(s, 0.12), 0.91, 1);
        case "surface":
            return Qt.hsla(h, Math.min(s, 0.16), 0.86, 1);
        case "hairline":
            return Qt.hsla(h, Math.min(s, 0.10), 0.80, 1);
        case "lineStrong":
            return Qt.hsla(h, Math.min(s, 0.16), 0.62, 1);
        case "faint":
            return Qt.hsla(h, Math.min(s, 0.08), 0.76, 1);
        case "ink":
            return Qt.hsla(h, Math.min(s, 0.24), 0.14, 1);
        case "muted":
            return Qt.hsla(h, Math.min(s, 0.12), 0.38, 1);
        case "acid":
            return _fitOnLight(Qt.hsla(h, Math.max(0.45, Math.min(s, 0.90)), Math.min(l, 0.44), 1), 3.0);
        case "acidDeep":
            return _fitOnLight(Qt.hsla(h, Math.max(0.45, Math.min(s, 0.90)), Math.min(l, 0.32), 1), 3.0);
        case "alert":
            return _fitOnLight(Qt.hsla(h, Math.max(0.60, s), Math.min(l, 0.46), 1), 2.5);
        default:
            return c;
        }
    }

    function setDark(on) {
        if (root.dark === on)
            return;
        root.dark = on;
        ShellState.set("dark", on);
        _reapplyCurrent();
    }

    function setAccent(color) {
        const c = String(color ?? "").trim();
        ShellState.set("accentOverride", (c.length === 0 || c.toLowerCase() === "none") ? "" : c);
        _reapplyCurrent();
    }

    // re-run the current source through the engine so mode/accent changes
    // repaint everything without modules knowing either exists
    function _reapplyCurrent() {
        if (root.followWallpaper && String(ShellState.wallpaperPath ?? "").length > 0) {
            // the palette file is already loaded — re-apply its current tokens
            // (no reload() here: it would race the read and log "unreadable")
            applyWallpaperTokens();
        } else if (root.activeScheme.length > 0) {
            applyPreset(root.activeScheme);
        } else {
            _applyTokens(defaults);
        }
    }

    function _applyAccentOverride() {
        const o = ShellState.accentOverride;
        if (!o || o.length === 0)
            return;
        try {
            let c = Qt.color(o);
            if (!root.dark)
                c = _fitOnLight(c, 3.0);
            root.acid = c;
            root.acidDeep = Qt.hsla(_h(c.hslHue), c.hslSaturation, Math.max(0.10, c.hslLightness * (root.dark ? 0.72 : 0.80)), 1);
        } catch (e) {
            console.warn("[theme] accent override unreadable:", o);
        }
    }

    function setFollowWallpaper(on) {
        root.followWallpaper = on;
        ShellState.set("followWallpaper", on);
        if (on) {
            // reload() is async — the onLoaded handler applies the tokens once
            // the file is actually read (the old synchronous applyWallpaperTokens
            // here raced the read and logged a spurious "unreadable" every time)
            wallThemeFile.reload();
        }
    }

    function applyWallpaperTokens() {
        try {
            const m = JSON.parse(wallThemeFile.text());
            const tokens = m.colors ?? m;
            if (_applyTokens(tokens)) {
                root.wallpaperSource = String(m.name ?? "").slice(0, 24);
                console.log("[theme] wallpaper palette applied" + (m.name ? ": " + m.name : ""));
            }
        } catch (e) {
            console.warn("[theme] theme.json unreadable:", e);
        }
    }

    // Sync-read a preset for preview swatches (settings panel).
    function previewOf(id) {
        previewLoader.path = root.schemePath(id);
        previewLoader.reload();
        try {
            return JSON.parse(previewLoader.text());
        } catch (e) {
            return null;
        }
    }

    // ======== CONTRAST SELF-CHECK ========
    function _channel(v) {
        v /= 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    }

    function _luminance(c) {
        return 0.2126 * _channel(c.r * 255) + 0.7152 * _channel(c.g * 255) + 0.0722 * _channel(c.b * 255);
    }

    function _ratio(a, b) {
        const l1 = Math.max(_luminance(a), _luminance(b));
        const l2 = Math.min(_luminance(a), _luminance(b));
        return (l1 + 0.05) / (l2 + 0.05);
    }

    function checkContrast() {
        const pairs = [["ink", "bg", 4.5], ["acid", "bg", 3.0], ["alert", "bg", 2.5]];
        for (const [fg, bgk, min] of pairs) {
            const r = _ratio(root[fg], root[bgk]);
            if (r < min)
                console.warn("[theme][contrast] " + fg + "/" + bgk + " ratio " + r.toFixed(2) + " < " + min);
        }
    }

    // ======== INTERNALS ========
    readonly property var defaults: ({
            bg: "#0a0a0c",
            bgAlt: "#101014",
            surface: "#17171c",
            ink: "#eae8e0",
            muted: "#6b6a63",
            faint: "#3f3e3a",
            hairline: "#1d1d22",
            lineStrong: "#2c2c34",
            acid: "#c8ff3d",
            acidDeep: "#8fbe1f",
            alert: "#ff3b52"
        })

    FileView {
        id: schemeLoader
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const m = JSON.parse(schemeLoader.text());
                const tokens = m.colors ?? m;
                if (root._applyTokens(tokens)) {
                    root.activeScheme = String(m.name ?? "");
                    root.wallpaperSource = "";
                    if (ShellState.scheme !== root.activeScheme)
                        ShellState.set("scheme", root.activeScheme);
                    if (ShellState.followWallpaper)
                        ShellState.set("followWallpaper", false);
                    console.log("[theme] preset applied:", root.activeScheme);
                }
            } catch (e) {
                console.warn("[theme] scheme json unreadable:", e);
            }
        }
        onLoadFailed: console.warn("[theme] scheme load failed")
    }

    FileView {
        id: previewLoader
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: wallThemeFile
        path: Quickshell.env("HOME") + "/.local/state/yutashell/theme.json"
        watchChanges: true
        printErrors: false
        preload: true
        onLoaded: {
            if (root.followWallpaper)
                root.applyWallpaperTokens();
        }
    }

    Component.onCompleted: {
        root.dark = ShellState.dark;
        if (!root.dark)
            _applyTokens(defaults);
        root.followWallpaper = ShellState.followWallpaper;
        if (ShellState.followWallpaper) {
            // reload() is async; the onLoaded handler applies tokens when ready
            wallThemeFile.reload();
        } else if (ShellState.scheme.length > 0) {
            applyPreset(ShellState.scheme);
        }
    }
}
