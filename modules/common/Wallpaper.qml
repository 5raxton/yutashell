pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "."

Singleton {
    id: root

    // ======== WALLPAPER INDEX ========
    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property var entries: []
    property bool scanning: false
    property string current: ShellState.wallpaperPath

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
        if (p.length === 0)
            return;
        root.current = p;
        if (ShellState.wallpaperPath !== p)
            ShellState.set("wallpaperPath", p);

        genProc.imagePath = p;
        genProc.command = ["matugen", "-c", genConfigPath, "image", p];
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

    // ======== TEMPLATE REGISTRY ========
    readonly property string genConfigPath: Quickshell.env("HOME") + "/.local/state/yutashell/matugen.toml"

    function templatesList() {
        try {
            return JSON.parse(ShellState.templatesJson);
        } catch (e) {
            return [];
        }
    }

    function _persistTemplates(list) {
        ShellState.set("templatesJson", JSON.stringify(list));
        writeGenConfig();
        if (Theme.followWallpaper && ShellState.wallpaperPath.length > 0)
            apply(ShellState.wallpaperPath);
    }

    function setTemplateEnabled(id, on) {
        const list = templatesList().map(t => t.id === id ? Object.assign({}, t, {
                enabled: on
            }) : t);
        _persistTemplates(list);
    }

    function addTemplate(id, input, output, postHook) {
        const key = String(id).trim().toLowerCase().replace(/[^a-z0-9_-]/g, "");
        if (!key || !input || !output)
            return false;
        if (templatesList().some(t => t.id === key))
            return false;
        const list = templatesList();
        list.push({
            id: key,
            input: String(input),
            output: String(output),
            postHook: String(postHook ?? ""),
            enabled: true
        });
        _persistTemplates(list);
        return true;
    }

    function removeTemplate(id) {
        _persistTemplates(templatesList().filter(t => t.id !== id));
    }

    function writeGenConfig() {
        const shellTpl = Quickshell.shellDir + "/theme/matugen/yutashell.json";
        let s = "[config]\n";
        s += "\n[templates.yutashell]\n";
        s += "input_path = '" + shellTpl + "'\n";
        s += "output_path = '~/.local/state/yutashell/theme.json'\n";
        for (const t of templatesList()) {
            if (!t.enabled)
                continue;
            s += "\n[templates." + t.id + "]\n";
            s += "input_path = '" + t.input + "'\n";
            s += "output_path = '" + t.output + "'\n";
            if (t.postHook && String(t.postHook).length > 0)
                s += "post_hook = '" + t.postHook + "'\n";
        }
        genConfigFile.setText(s);
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
            daemonProc.command = ["sh", "-c", "pgrep -x awww-daemon >/dev/null || setsid awww-daemon >/dev/null 2>&1 & sleep 0.4; exec awww img '" + imagePath.replace(/'/g, "'\\''") + "'"];
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
        if (String(ShellState.templatesJson ?? "").length === 0)
            ShellState.seedTemplates();
        writeGenConfig();
        rescan();
        if (ShellState.followWallpaper && String(ShellState.wallpaperPath ?? "").length === 0)
            console.warn("[wallpaper] follow-wallpaper is on but no wallpaper has been applied yet");
    }
}
