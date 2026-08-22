pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---- runtime shell state (never persisted) ----
    property bool panelOpen: false
    property bool pickerOpen: false
    property bool launcherOpen: false

    // one surface at a time — opening any popup closes the others
    function _exclusive(name) {
        root.panelOpen = name === "panel";
        root.pickerOpen = name === "picker";
        root.launcherOpen = name === "launcher";
    }

    function togglePanel() {
        root._exclusive(root.panelOpen ? "" : "panel");
    }

    function openPanel() {
        root._exclusive("panel");
    }

    function closePanel() {
        root.panelOpen = false;
    }

    function togglePicker() {
        root._exclusive(root.pickerOpen ? "" : "picker");
    }

    function openPicker() {
        root._exclusive("picker");
    }

    function closePicker() {
        root.pickerOpen = false;
    }

    function toggleLauncher() {
        root._exclusive(root.launcherOpen ? "" : "launcher");
    }

    function openLauncher() {
        root._exclusive("launcher");
    }

    function closeLauncher() {
        root.launcherOpen = false;
    }

    // ---- persisted prefs (auto-written on change) ----
    readonly property alias scheme: adapter.scheme
    readonly property alias followWallpaper: adapter.followWallpaper
    readonly property alias wallpaperPath: adapter.wallpaperPath
    readonly property alias dark: adapter.dark
    readonly property alias accentOverride: adapter.accentOverride
    readonly property alias tplEnabled: adapter.tplEnabled
    readonly property alias customTpl: adapter.customTpl
    readonly property alias barTray: adapter.barTray
    readonly property alias barStats: adapter.barStats
    readonly property alias barClock: adapter.barClock
    readonly property alias barMedia: adapter.barMedia

    // control-core presentation
    readonly property alias panelW: adapter.panelW
    readonly property alias panelAnchor: adapter.panelAnchor
    readonly property alias panelLastPage: adapter.panelLastPage

    // launcher card width
    readonly property alias launcherW: adapter.launcherW

    // launcher
    readonly property alias launcherMode: adapter.launcherMode
    readonly property alias launcherAnchor: adapter.launcherAnchor
    readonly property alias launcherPins: adapter.launcherPins
    readonly property alias launcherRecents: adapter.launcherRecents

    function set(key, value) {
        adapter[key] = value;
        // Coalesce bursts into one flush — back-to-back writeAdapter() calls
        // overlap inside FileView and get silently dropped.
        flushTimer.restart();
    }

    Timer {
        id: flushTimer

        interval: 80
        onTriggered: stateFile.writeAdapter()
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
            property bool dark: true
            property string accentOverride: ""

            // matugen template registry v2:
            // tplEnabled = JSON array of ids (catalog + custom) that are ON
            // customTpl  = JSON array of user entries shaped like catalog ones
            // (legacy "templatesJson" key is intentionally dropped — old seeds
            // were all disabled and pointed at non-existent template files)
            property string tplEnabled: "[]"
            property string customTpl: "[]"

            // bar segments
            property bool barTray: true
            property bool barStats: true
            property bool barClock: true
            property bool barMedia: true

            // control-core presentation: card width (px, clamped by consumer),
            // horizontal placement (center|left|right) and last visited page
            property int panelW: 880
            property string panelAnchor: "center"
            property int panelLastPage: 0

            // launcher card width (px, clamped by consumer)
            property int launcherW: 640

            // launcher: view mode (grid|list), placement (center|left|top),
            // pinned + recent app ids as JSON arrays
            property string launcherMode: "grid"
            property string launcherAnchor: "center"
            property string launcherPins: "[]"
            property string launcherRecents: "[]"
        }
    }

    Component.onCompleted: {
        // Seed defaults ONLY when the file is absent/empty. A transient read
        // race must never clobber the user's persisted prefs with defaults.
        if (stateFile.loadFailed && stateFile.text().length === 0)
            stateFile.writeAdapter();
    }
}
