import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "ui"
import "../net"
import "../audio"
import "../session"
import "../widgets"
import "../common/ui"
import "."

// Bar v2 (PH.14) — a data-driven organism. The layout (which segments, in
// which zone, in what order) is persisted in ShellState.barSegments and
// resolved by the BarSegments singleton; each segment composes its own
// component and honors its click-action via BarActions. Scale + position
// are persisted too. The bar stays on the Overlay layer — popups slide out
// from behind it.
PanelWindow {
    id: root

    property var tip

    // Overlay: topmost layer. Popups land on Top, so anything sliding down
    // emerges from BEHIND this bar.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool topBar: ShellState.barPosition !== "bottom"
    readonly property real scaleFactor: Math.max(0.8, Math.min(1.4, ShellState.barScale))

    anchors {
        top: root.topBar
        bottom: !root.topBar
        left: true
        right: true
    }

    implicitHeight: Math.round(Theme.barHeight * root.scaleFactor)
    color: "transparent"

    Rectangle {
        id: frame

        anchors.fill: parent
        color: Theme.bg

        // hairline — bottom edge for a top bar, top edge for a bottom bar
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: root.topBar ? parent.bottom : undefined
            anchors.top: root.topBar ? undefined : parent.top
            height: 1
            color: Theme.hairline
        }

        // the living strip — pulses at the bar's leading edge
        YPulse {
            x: Theme.outerPad
            y: root.topBar ? 0 : parent.height - height
            width: 132
            height: 2
            color: Theme.acid
            lo: 0.55
        }

        // content — sized to the natural bar height, Y-scaled to the pref
        Item {
            id: content

            x: 0
            y: 0
            width: parent.width
            height: Theme.barHeight
            transform: Scale {
                yScale: root.scaleFactor
            }

            // ---- LEFT ZONE ----
            Row {
                id: leftRow

                anchors.left: parent.left
                anchors.leftMargin: Theme.outerPad
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.rowModel("left")

                    delegate: segDelegate
                }
            }

            // ---- CENTER ZONE — true center, yields only on collision ------
            // Segments assigned zone "center" hold the exact middle of the
            // bar regardless of how wide the flanks grow; if the three zones
            // can't fit side by side the cluster slides right until it clears
            // the left row (clamped before it may kiss the right row).
            Row {
                id: centerRow

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset
                anchors.verticalCenter: parent.verticalCenter
                visible: root.centerList.length > 0

                Repeater {
                    model: root.centerList

                    delegate: segDelegate
                }
            }

            // ---- ACTIVE WINDOW — the elastic fill between zones ----------
            // Alone in the center it stretches across the whole middle; with
            // real center segments present it hands the middle over and hugs
            // the left cluster instead.
            ActiveWindow {
                anchors.left: leftRow.right
                anchors.leftMargin: Theme.sp3
                anchors.right: root.centerList.length > 0 ? centerRow.left : rightRow.left
                anchors.rightMargin: Theme.sp3
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: BarSegments.present("activewindow")
            }

            // ---- RIGHT ZONE ----
            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: Theme.outerPad
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.rowModel("right")

                    delegate: segDelegate
                }
            }
        }
    }

    // ids that render INSIDE the stats cluster instead of as their own block
    readonly property var embeddedStats: ["cputemp", "gpu", "disk"]

    function _renderable(id) {
        return id !== "activewindow" && root.embeddedStats.indexOf(id) < 0 && BarSegments.present(id);
    }

    // center-zone segments minus the active-window fill and stat embeds
    readonly property var centerList: {
        const list = BarSegments.centerVisible;
        const out = [];
        for (let i = 0; i < list.length; i++)
            if (root._renderable(list[i].id))
                out.push(list[i]);
        return out;
    }

    function rowModel(zone) {
        const list = BarSegments.zoneList(zone);
        const out = [];
        for (let i = 0; i < list.length; i++)
            if (root._renderable(list[i].id))
                out.push(list[i]);
        return out;
    }

    // 0 when the centered cluster owns its natural slot; otherwise the smallest
    // rightward shift that clears the left row, clamped so it never overlaps
    // the right row either.
    readonly property real centerOffset: {
        const mid = content.width / 2;
        const half = centerRow.width / 2 + Theme.sp3;
        const minOffset = leftRow.width + Theme.outerPad + half - mid;
        const maxOffset = mid - rightRow.width - Theme.outerPad - half;
        if (minOffset <= 0)
            return 0;
        return Math.min(minOffset, Math.max(0, maxOffset));
    }

    // ---- segment delegate: divider gutter (except first) + the segment ----
    Component {
        id: segDelegate

        Row {
            required property int index
            required property var modelData

            spacing: 0

            DividerV {
                visible: index > 0
            }

            Loader {
                sourceComponent: root.segComponent(modelData.id)
            }
        }
    }

    function segComponent(id) {
        switch (id) {
        case "identity":
            return identityComp;
        case "workspaces":
            return workspacesComp;
        case "taskbar":
            return taskbarComp;
        case "tray":
            return trayComp;
        case "media":
            return mediaComp;
        case "net":
            return netComp;
        case "bt":
            return btComp;
        case "audio":
            return audioComp;
        case "stats":
            return statsComp;
        // cputemp / gpu / disk render as columns inside the stats cluster
        case "nightlight":
            return nlComp;
        case "session":
            return sessComp;
        case "recording":
            return recComp;
        case "pluginwidgets":
            return pluginWidgetsComp;
        case "clock":
            return clockComp;
        }
        return null;
    }

    Component {
        id: identityComp

        IdentityBlock {}
    }

    Component {
        id: workspacesComp

        Workspaces {}
    }

    Component {
        id: taskbarComp

        Taskbar {
            tip: root.tip
        }
    }

    Component {
        id: trayComp

        TrayCluster {
            tip: root.tip
        }
    }

    Component {
        id: mediaComp

        MediaBlock {
            tip: root.tip
        }
    }

    Component {
        id: netComp

        NetBlock {
            tip: root.tip
        }
    }

    Component {
        id: btComp

        BtBlock {
            tip: root.tip
        }
    }

    Component {
        id: audioComp

        AudioBlock {
            tip: root.tip
        }
    }

    Component {
        id: statsComp

        StatsCluster {
            tip: root.tip
        }
    }

    Component {
        id: nlComp

        // Item root so the block fills the bar line like every other segment —
        // a bare Text inside the zone Row would top-align and ride high
        Item {
            implicitWidth: moonText.width
            implicitHeight: Theme.barHeight

            Text {
                id: moonText

                anchors.verticalCenter: parent.verticalCenter
                text: "☾"
                color: Theme.acid
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BarActions.dispatch(BarSegments.clickFor("nightlight"))
            }
        }
    }

    Component {
        id: sessComp

        // ASCII-safe rendering — the nerd-font glyph this chip used is missing
        // from common installs and rendered as a dead box
        Item {
            implicitWidth: sessRow.width
            implicitHeight: Theme.barHeight

            Row {
                id: sessRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "INHIBIT"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(Session.inhibitCount)
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BarActions.dispatch(BarSegments.clickFor("session"))
            }
        }
    }

    Component {
        id: recComp

        Item {
            implicitWidth: recRow.width
            implicitHeight: Theme.barHeight

            Row {
                id: recRow

                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    color: Theme.alert

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1.0
                            to: 0.25
                            duration: 620
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.25
                            to: 1.0
                            duration: 620
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REC"
                    color: Theme.alert
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Recording.stop()
            }
        }
    }

    Component {
        id: clockComp

        ClockBlock {}
    }

    // PH.05: widget plugins from <config>/plugins, enabled via settings
    Component {
        id: pluginWidgetsComp

        Item {
            implicitWidth: plugRow.width
            implicitHeight: Theme.barHeight

            Row {
                id: plugRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2

                Repeater {
                    model: PluginService.enabledWidgets

                    Loader {
                        required property var modelData

                        source: PluginService.componentUrl(modelData)
                        asynchronous: true
                    }
                }
            }
        }
    }
}
