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
    property bool netOpen: false
    property bool btOpen: false
    property bool notifyCenterOpen: false
    property bool audioOpen: false
    property bool mediaOpen: false

    // one surface at a time — opening any popup closes the others
    function _exclusive(name) {
        root.panelOpen = name === "panel";
        root.pickerOpen = name === "picker";
        root.launcherOpen = name === "launcher";
        root.netOpen = name === "net";
        root.btOpen = name === "bt";
        root.notifyCenterOpen = name === "notifycenter";
        root.audioOpen = name === "audio";
        root.mediaOpen = name === "media";
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

    function toggleNet() {
        root._exclusive(root.netOpen ? "" : "net");
    }

    function closeNet() {
        root.netOpen = false;
    }

    function toggleBt() {
        root._exclusive(root.btOpen ? "" : "bt");
    }

    function closeBt() {
        root.btOpen = false;
    }

    function toggleNotifyCenter() {
        root._exclusive(root.notifyCenterOpen ? "" : "notifycenter");
    }

    function closeNotifyCenter() {
        root.notifyCenterOpen = false;
    }

    function toggleAudio() {
        root._exclusive(root.audioOpen ? "" : "audio");
    }

    function closeAudio() {
        root.audioOpen = false;
    }

    function toggleMedia() {
        root._exclusive(root.mediaOpen ? "" : "media");
    }

    function closeMedia() {
        root.mediaOpen = false;
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
    readonly property alias barNet: adapter.barNet
    readonly property alias barBt: adapter.barBt
    readonly property alias barAudio: adapter.barAudio

    // notifications
    readonly property alias notifyDnd: adapter.notifyDnd
    readonly property alias notifyTimeout: adapter.notifyTimeout
    readonly property alias notifyMaxVisible: adapter.notifyMaxVisible
    readonly property alias notifyActions: adapter.notifyActions
    readonly property alias notifyFields: adapter.notifyFields
    readonly property alias notifyPerApp: adapter.notifyPerApp
    readonly property alias notifyHistory: adapter.notifyHistory
    readonly property alias notifyCorner: adapter.notifyCorner

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

    // audio / OSD knobs
    readonly property alias audioCeiling: adapter.audioCeiling
    readonly property alias osdCorner: adapter.osdCorner
    readonly property alias osdWidth: adapter.osdWidth
    readonly property alias osdFadeMs: adapter.osdFadeMs
    readonly property alias nlTemp: adapter.nlTemp
    readonly property alias nlActive: adapter.nlActive

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
            property bool barNet: true
            property bool barBt: true
            property bool barAudio: true

            // notifications: timeout seconds (0 = honor client), fields JSON,
            // per-app overrides JSON [{"match","mode"}], history dump JSON,
            // toast corner (tr|tl)
            property bool notifyDnd: false
            property int notifyTimeout: 6
            property int notifyMaxVisible: 3
            property bool notifyActions: true
            property string notifyFields: "{\"app\":true,\"body\":true,\"icon\":true,\"time\":true}"
            property string notifyPerApp: "[]"
            property string notifyHistory: "[]"
            property string notifyCorner: "tr"

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

    // audio: overdrive ceiling percent (100+), OSD corner (tl|tc|tr|bl|bc|br),
    // OSD card width, OSD fade delay ms, night light temperature (K)
    property int audioCeiling: 130
    property string osdCorner: "bc"
    property int osdWidth: 420
    property int osdFadeMs: 1600
    property int nlTemp: 4500
    property bool nlActive: false
        }
    }

    Component.onCompleted: {
        // Seed defaults ONLY when the file is absent/empty. A transient read
        // race must never clobber the user's persisted prefs with defaults.
        if (stateFile.loadFailed && stateFile.text().length === 0)
            stateFile.writeAdapter();
    }
}
