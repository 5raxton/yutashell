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

    // Unified rows for settings/IPC: {id,label,group,note,output,enabled,custom}
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
                custom: false
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
                custom: true
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
        const cur = root.enabledIds().filter(x => x !== id);
        if (onOff)
            cur.push(id);
        ShellState.set("tplEnabled", JSON.stringify(cur));
        writeGenConfig();
        if (Theme.followWallpaper && String(ShellState.wallpaperPath ?? "").length > 0)
            apply(ShellState.wallpaperPath);
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
        if (Theme.followWallpaper && String(ShellState.wallpaperPath ?? "").length === 0)
            console.warn("[wallpaper] follow-wallpaper is on but no wallpaper has been applied yet");
    }
}
