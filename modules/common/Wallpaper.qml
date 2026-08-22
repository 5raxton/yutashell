pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import "."

Singleton {
    id: root

    // ======== WALLPAPER INDEX ========
    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property var entries: []
    property bool scanning: false
    property string current: ShellState.wallpaperPath
    // true while matugen is regenerating every enabled template — UI binds
    // "APPLYING" feedback chips to this
    property bool generating: false

    function rescan() {
        root.scanning = true;
        scanProc.command = ["find", wallDir, "-maxdepth", "2", "-type", "f", "(",
            "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", "-o", "-iname", "*.bmp", ")"];
        scanProc.running = true;
    }

    // ======== APPLY PIPELINE: index -> awww -> matugen -> live recolor ========
    function apply(path) {
        const p = String(path).trim();
        if (p.length === 0 || root.generating)
            return;
        root.current = p;
        if (ShellState.wallpaperPath !== p)
            ShellState.set("wallpaperPath", p);

        // -m dark: our palette is dark-first; --source-color-index 0 picks the
        // most dominant color instead of prompting (matugen 4.x hard-fails
        // without a TTY when several source colors are candidates)
        root.generating = true;
        genProc.imagePath = p;
        genProc.command = ["matugen", "-c", genConfigPath, "image", p, "-m", "dark", "--source-color-index", "0"];
        genProc.running = true;

        paintTimer.imagePath = p;
        paintTimer.restart();
    }

    function applyNext() {
        if (root.entries.length === 0)
            return;
        let idx = root.entries.findIndex(e => e.path === root.current);
        idx = (idx + 1) % root.entries.length;
        apply(root.entries[idx].path);
    }

    function applyRandom() {
        if (root.entries.length === 0)
            return;
        let idx = Math.floor(Math.random() * root.entries.length);
        if (root.entries[idx].path === root.current && root.entries.length > 1)
            idx = (idx + 1) % root.entries.length;
        apply(root.entries[idx].path);
    }

    // ======== TEMPLATE REGISTRY ========
    // Built-in catalog entries live in TemplateCatalog (all OFF by default);
    // ShellState.tplEnabled holds the enabled ids, ShellState.customTpl holds
    // user-added entries shaped like catalog ones.
    readonly property string genConfigPath: Quickshell.env("HOME") + "/.local/state/yutashell/matugen.toml"

    function _expand(p) {
        return String(p ?? "").replace("@CATALOG@", TemplateCatalog.catalogDir).replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    // multi-line literal string ('''…'''): no escape processing, tolerates
    // embedded single quotes in paths/hooks ('' inside '…' is INVALID toml)
    function _toml(s) {
        return "'''" + String(s ?? "").replace(/'''/g, "''") + "'''";
    }

    function enabledIds() {
        try {
            const v = JSON.parse(ShellState.tplEnabled);
            return Array.isArray(v) ? v : [];
        } catch (e) {
            return [];
        }
    }

    function customList() {
        try {
            const v = JSON.parse(ShellState.customTpl);
            return Array.isArray(v) ? v : [];
        } catch (e) {
            return [];
        }
    }

    // Unified rows for settings/IPC: {id,label,group,note,output,enabled,custom,installed,snippet}
    function templatesList() {
        const on = root.enabledIds();
        const out = [];
        for (const e of TemplateCatalog.entries) {
            out.push({
                id: e.id,
                label: e.label,
                group: e.group,
                note: e.note ?? "",
                output: e.files[0]?.output ?? "",
                enabled: on.includes(e.id),
                custom: false,
                installed: root.appInstalled(e.id),
                snippet: root.snippetFor(e.id)
            });
        }
        for (const c of root.customList()) {
            out.push({
                id: c.id,
                label: c.label ?? c.id,
                group: "CUSTOM",
                note: c.note ?? "",
                output: c.files?.[0]?.output ?? "",
                enabled: on.includes(c.id),
                custom: true,
                installed: true,
                snippet: null
            });
        }
        return out.sort((a, b) => a.id.localeCompare(b.id));
    }

    function setTemplateEnabled(id, onOff) {
        // ON requires a known id so typos can't pollute the registry;
        // OFF is always allowed (also cleans legacy garbage entries)
        const known = !!TemplateCatalog.byId(id) || root.customList().some(c => c.id === id);
        if (onOff && !known)
            return;
        // never enable a template for an app that isn't installed
        if (onOff && !root.appInstalled(id)) {
            console.warn("[wallpaper] refusing to enable", id, "— binary not found");
            return;
        }
        const cur = root.enabledIds().filter(x => x !== id);
        if (onOff)
            cur.push(id);
        ShellState.set("tplEnabled", JSON.stringify(cur));
        writeGenConfig();
        _syncSnippet(id, onOff);
        if (Theme.followWallpaper && String(ShellState.wallpaperPath ?? "").length > 0)
            apply(ShellState.wallpaperPath);
    }

    // ======== APP PRESENCE + AUTO-SNIPPETS ========
    // Toggling a template should be zero-friction: the shell detects which
    // themed apps are actually installed and writes the include line into
    // their configs itself (managed "# >>> yutashell" blocks).
    readonly property var binMap: ({
            "alacritty": ["alacritty"],
            "kitty": ["kitty"],
            "ghostty": ["ghostty"],
            "wezterm": ["wezterm"],
            "tmux": ["tmux"],
            "mcfly": ["mcfly"],
            "helix": ["hx"],
            "micro": ["micro"],
            "neovim": ["nvim"],
            "zed": ["zed", "zeditor", "zed-editor"],
            "opencode": ["opencode"],
            "obsidian": ["obsidian"],
            "rmpc": ["rmpc"],
            "starship": ["starship"],
            "pywalfox": ["pywalfox"],
            "vivaldi": ["vivaldi"],
            "fuzzel": ["fuzzel"],
            "rofi": ["rofi"],
            "wofi": ["wofi"],
            "television": ["tv"],
            "mako": ["mako"],
            "dunst": ["dunst"],
            "swaync": ["swaync"],
            "hyprland": ["hyprland"],
            "hyprland-lua": ["hyprland"],
            "hyprlock": ["hyprlock"],
            "sway": ["sway"],
            "niri": ["niri"],
            "labwc": ["labwc"],
            "mango": ["mango"],
            "waybar": ["waybar"],
            "hyprwat": ["hyprwat"],
            "qt5ct": ["qt5ct"],
            "qt6ct": ["qt6ct"],
            "kvantum": ["kvantummanager"],
            "cava": ["cava"],
            "spicetify": ["spicetify"],
            "btop": ["btop"],
            "yazi": ["yazi"],
            "zellij": ["zellij"],
            "zathura": ["zathura"],
            "clipse": ["clipse"],
            "wine": ["wine"]
        })

    // id -> is the app present? ids WITHOUT a binMap entry are config-drop
    // targets (css/json files, browsers…) and count as installed.
    property var bins: ({})
    property bool binsResolved: false

    function appInstalled(id) {
        return !(id in root.binMap) || root.bins[id] === true;
    }

    // include-line rules: what to inject where so the template actually loads.
    // Missing entry = app has no include mechanism we dare automate.
    readonly property var snippetRules: ({
            "alacritty": {
                file: "~/.config/alacritty/alacritty.toml",
                line: "import = [\"~/.config/alacritty/colors.toml\"]",
                // TOML forbids duplicate keys AND stray bare keys after table
                // headers, so alacritty can't take an appended block — we
                // merge our path into the existing import array instead.
                mode: "toml-import",
                path: "~/.config/alacritty/colors.toml"
            },
            "kitty": {
                file: "~/.config/kitty/kitty.conf",
                line: "include themes/Matugen.conf"
            },
            "ghostty": {
                file: "~/.config/ghostty/config",
                line: "theme = \"Matugen\""
            },
            "tmux": {
                file: "~/.config/tmux/tmux.conf",
                line: "source ~/.config/tmux/generated.conf"
            },
            "fuzzel": {
                file: "~/.config/fuzzel/fuzzel.ini",
                line: "include=~/.config/fuzzel/colors.ini"
            },
            "rofi": {
                file: "~/.config/rofi/config.rasi",
                line: "@import \"colors.rasi\""
            },
            "wofi": {
                file: "~/.config/wofi/style.css",
                line: "@import \"colors.css\";"
            },
            "mako": {
                file: "~/.config/mako/config",
                line: "include=~/.config/mako/mako-colors"
            },
            "swaync": {
                file: "~/.config/swaync/style.css",
                line: "@import \"colors.css\";"
            },
            "hyprland": {
                file: "~/.config/hypr/hyprland.conf",
                line: "source=~/.config/hypr/colors.conf"
            },
            "hyprlock": {
                file: "~/.config/hypr/hyprlock.conf",
                line: "source=~/.config/hypr/hyprlock-colors.conf"
            },
            "waybar": {
                file: "~/.config/waybar/style.css",
                line: "@import \"colors.css\";"
            },
            "gtk3": {
                file: "~/.config/gtk-3.0/gtk.css",
                line: "@import 'colors.css';"
            },
            "gtk4": {
                file: "~/.config/gtk-4.0/gtk.css",
                line: "@import 'colors.css';"
            },
            "wlogout": {
                file: "~/.config/wlogout/style.css",
                line: "@import \"colors.css\";"
            }
        })

    function snippetFor(id) {
        return root.snippetRules[id] ?? null;
    }

    // ---- managed-block plumbing (serialized through a queue) ----
    property var _snipQueue: []

    function _syncSnippet(id, onOff) {
        if (!root.snippetRules[id])
            return;
        root._snipQueue.push({
                id: id,
                on: onOff
            });
        if (_snipQueue.length === 1)
            _snipStep();
    }

    function _snipStep() {
        const job = _snipQueue[0];
        const r = root.snippetRules[job.id];
        const p = String(r.file).replace(/^~/, Quickshell.env("HOME"));
        snipReader.command = ["sh", "-c", "mkdir -p '" + p.slice(0, p.lastIndexOf("/")) + "' && cat '" + p + "' 2>/dev/null || true"];
        snipReader.running = true;
    }

    function _snipApply(raw) {
        const job = _snipQueue.shift();
        const r = root.snippetRules[job.id];
        _snipTarget = String(r.file).replace(/^~/, Quickshell.env("HOME"));
        const BEGIN = "# >>> yutashell-matugen";
        const END = "# <<< yutashell-matugen";
        // strip any managed block(s), then re-add only when enabling
        let body = String(raw ?? "").replace(new RegExp("\\n?" + BEGIN + "[\\s\\S]*?" + END + "[^\\n]*\\n?", "g"), "\n");
        if ((r.mode ?? "block") === "toml-import") {
            body = root._snipToml(body, job.on, r);
        } else if (job.on) {
            body = body.replace(/\n*$/, "\n") + BEGIN + "\n" + r.line + "\n" + END + "\n";
        }
        snipStage.setText(body); // stages AND writes; onSaved copies into place
    }

    // TOML import-array surgery: merge our path into an existing single-line
    // `import = [...]`, else add one right after [general], else append a
    // managed [general] block. Disabling removes our path wherever it is.
    function _snipToml(body, on, r) {
        const quoted = "\"" + r.path + "\"";
        const arrRe = /^(import\s*=\s*\[)([^\]]*)(\].*)$/m;
        const m = body.match(arrRe);
        if (on) {
            if (body.indexOf(quoted) !== -1)
                return body; // already wired
            if (m) {
                const inner = m[2].trim();
                const merged = inner.length === 0 ? quoted : inner.replace(/,\s*$/, "") + ", " + quoted;
                return body.replace(arrRe, "$1" + merged + "$3");
            }
            if (/^\[general\]\s*$/m.test(body)) {
                let done = false;
                const out = body.replace(/^(\[general\][^\n]*\n)/m, (whole) => {
                    if (done)
                        return whole;
                    done = true;
                    return whole + "import = [" + quoted + "]\n";
                });
                if (done)
                    return out;
            }
            console.warn("[wallpaper] no import array in", r.file, "— appending managed [general] block");
            return body.replace(/\n*$/, "\n") + "# >>> yutashell-matugen\n[general]\nimport = [" + quoted + "]\n# <<< yutashell-matugen\n";
        }
        // off: drop our entry from the array (leave everything else intact)
        if (m && m[2].indexOf(quoted) !== -1) {
            const parts = m[2].split(",").map(s => s.trim()).filter(s => s.length > 0 && s !== quoted);
            const inner = parts.join(", ");
            return body.replace(arrRe, "$1" + inner + "$3");
        }
        return body; // nothing of ours outside managed blocks (already stripped)
    }

    property string _snipTarget: ""

    // staging file — written by FileView, moved into the app config by shell
    FileView {
        id: snipStage

        path: Quickshell.env("HOME") + "/.local/state/yutashell/snippet.stage"
        printErrors: false
        atomicWrites: true
        blockWrites: true

        onSaved: {
            snipCopier.command = ["sh", "-c", "cp '" + snipStage.path + "' '" + root._snipTarget.replace(/'/g, "'\\''") + "'; rm -f '" + snipStage.path + "'"];
            snipCopier.running = true;
        }
    }

    Process {
        id: snipReader

        stdout: StdioCollector {
            onStreamFinished: root._snipApply(this.text)
        }
        stderr: StdioCollector {}
    }

    Process {
        id: snipCopier

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: if (root._snipQueue.length > 0)
            root._snipStep()
    }

    // one-shot probe: which themed binaries actually exist?
    Process {
        id: binProbe

        onExited: (code) => console.warn("[wallpaper] binProbe exited code", code)
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                console.warn("[wallpaper] binProbe stderr:", this.text.trim())
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const id of this.text.trim().split("\n"))
                    if (id.length > 0)
                        found[id] = true;
                root.bins = found;
                root.binsResolved = true;
                console.warn("[wallpaper] bins resolved:", JSON.stringify(Object.keys(found)));
                // auto-prune: drop enabled templates whose app is absent so
                // stale state can never keep generating dead configs
                const kept = root.enabledIds().filter(id => root.appInstalled(id));
                const gone = root.enabledIds().filter(id => !root.appInstalled(id));
                if (gone.length > 0) {
                    console.warn("[wallpaper] pruned absent-app templates:", gone.join(", "));
                    ShellState.set("tplEnabled", JSON.stringify(kept));
                    writeGenConfig();
                }
            }
        }
    }

    function addTemplate(id, input, output, postHook) {
        const key = String(id).trim().toLowerCase().replace(/[^a-z0-9_-]/g, "");
        if (!key || !input || !output)
            return false;
        if (TemplateCatalog.byId(key))
            return false;
        if (root.customList().some(t => t.id === key))
            return false;
        const list = root.customList();
        list.push({
            id: key,
            label: key,
            group: "CUSTOM",
            note: "",
            files: [{
                    input: String(input),
                    output: String(output),
                    post: String(postHook ?? "")
                }]
        });
        ShellState.set("customTpl", JSON.stringify(list));
        writeGenConfig();
        return true;
    }

    function removeTemplate(id) {
        const kept = root.customList().filter(t => t.id !== id);
        if (kept.length === root.customList().length)
            return;
        // disable while the entry is still known, then drop it
        setTemplateEnabled(id, false);
        ShellState.set("customTpl", JSON.stringify(kept));
        writeGenConfig();
    }

    function _entrySections(entry, baseId) {
        // one [templates.X] block per file part; multi-file entries get _n suffixes
        let s = "";
        let n = 0;
        for (const f of entry.files ?? []) {
            const secId = (entry.files.length > 1 ? baseId + "_" + (++n) : baseId).replace(/[^a-z0-9_-]/g, "");
            s += "\n[templates." + secId + "]\n";
            s += "input_path = " + _toml(_expand(f.input.startsWith("/") || f.input.startsWith("~") ? f.input : TemplateCatalog.catalogDir + "/" + f.input)) + "\n";
            s += "output_path = " + _toml(_expand(f.output)) + "\n";
            if (f.post && String(f.post).length > 0)
                s += "post_hook = " + _toml(_expand(f.post)) + "\n";
            if (f.extras)
                s += f.extras.replace(/\n/g, "\n") + "\n";
        }
        return s;
    }

    function writeGenConfig() {
        // Coalesce rapid toggles into one setText — overlapping writes get
        // dropped by FileView.
        genFlush.restart();
    }

    Timer {
        id: genFlush

        interval: 100
        onTriggered: {
            const shellTpl = Quickshell.shellDir + "/theme/matugen/yutashell.json";
            let s = "[config]\n";
            s += "\n[templates.yutashell]\n";
            s += "input_path = " + root._toml(shellTpl) + "\n";
            s += "output_path = " + root._toml("~/.local/state/yutashell/theme.json".replace(/^~/, Quickshell.env("HOME"))) + "\n";

            const on = root.enabledIds();
            for (const id of on) {
                const cat = TemplateCatalog.byId(id);
                if (cat)
                    s += root._entrySections(cat, id);
            }
            for (const c of root.customList()) {
                if (on.includes(c.id))
                    s += root._entrySections(c, c.id);
            }
            genConfigFile.setText(s);
        }
    }

    // ======== INTERNALS ========
    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().length ? this.text.trim().split("\n") : [];
                lines.sort();
                root.entries = lines.map(p => ({
                        path: p,
                        label: p.split("/").pop()
                    }));
                root.scanning = false;
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: genProc
        property string imagePath: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    console.warn("[wallpaper] matugen:", t);
            }
        }
        onExited: (code, status) => {
            root.generating = false;
            if (code !== 0) {
                console.warn("[wallpaper] matugen failed for", imagePath);
                return;
            }
            Theme.setFollowWallpaper(true);
        }
    }

    Timer {
        id: paintTimer
        property string imagePath: ""
        interval: 250
        onTriggered: {
            // start the daemon detached if missing, then retry the paint until
            // its socket is up (fixed sleeps raced and dropped wallpapers)
            const img = imagePath.replace(/'/g, "'\\''");
            daemonProc.command = ["sh", "-c",
                "pgrep -x awww-daemon >/dev/null || setsid awww-daemon >/dev/null 2>&1 &\n" +
                "for i in 1 2 3 4 5 6 7 8; do awww img '" + img + "' && exit 0; sleep 0.25; done\n" +
                "echo 'awww img failed after retries' >&2; exit 1"];
            daemonProc.running = true;
        }
    }

    Process {
        id: daemonProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    console.warn("[wallpaper] awww:", t);
            }
        }
    }

    FileView {
        id: genConfigFile
        path: root.genConfigPath
        printErrors: false
    }

    Component.onCompleted: {
        writeGenConfig();
        rescan();
        try {
            const probe = Object.keys(root.binMap).map(id => "for b in " + root.binMap[id].join(" ") + "; do command -v \"$b\" >/dev/null 2>&1 && echo " + id + " && break; done").join("\n");
            console.warn("[wallpaper] probing", Object.keys(root.binMap).length, "app binaries");
            binProbe.command = ["sh", "-c", probe + "\ntrue"];
            binProbe.running = true;
        } catch (err) {
            console.warn("[wallpaper] binProbe setup failed:", err);
        }
        if (Theme.followWallpaper && String(ShellState.wallpaperPath ?? "").length === 0)
            console.warn("[wallpaper] follow-wallpaper is on but no wallpaper has been applied yet");
    }
}
