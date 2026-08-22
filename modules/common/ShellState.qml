pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---- runtime shell state (never persisted) ----
    property bool panelOpen: false
    property bool pickerOpen: false

    function togglePanel() {
        root.panelOpen = !root.panelOpen;
    }

    function openPanel() {
        root.panelOpen = true;
    }

    function closePanel() {
        root.panelOpen = false;
    }

    function togglePicker() {
        root.pickerOpen = !root.pickerOpen;
    }

    function openPicker() {
        root.pickerOpen = true;
    }

    function closePicker() {
        root.pickerOpen = false;
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
    readonly property alias panelPopout: adapter.panelPopout

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

            // control-core presentation: drawer width (px, clamped by consumer)
            // and popout mode (centered card instead of right drawer)
            property int panelW: 464
            property bool panelPopout: false
        }
    }

    Component.onCompleted: {
        // Seed defaults ONLY when the file is absent/empty. A transient read
        // race must never clobber the user's persisted prefs with defaults.
        if (stateFile.loadFailed && stateFile.text().length === 0)
            stateFile.writeAdapter();
    }
}
