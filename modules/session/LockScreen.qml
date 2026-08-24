import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "../widgets"

// LockScreen — secure wl_session_lock overlay. The compositor guarantees a
// surface per screen; monitor selection ("all"/"primary"/explicit list) only
// decides WHICH surfaces render the full visual (clock + auth). Non-selected
// screens get an opaque veil with its own minimal chrome — they stay locked
// either way, that's protocol.
//
// Auth: one PamContext here; the handshake STATE lives in Session so the IPC
// layer could drive it too. Wrong attempts snap the card sideways instantly
// (no easing — brutalist), never smooth.
Item {
    id: root

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarUrl: ShellState.lockAvatar.length > 0 ? "file://" + ShellState.lockAvatar : "file://" + Quickshell.env("HOME") + "/.face"
    readonly property string hostName: SystemStats.hostname.length > 0 ? SystemStats.hostname.toUpperCase() : (Quickshell.env("HOSTNAME") || "").toUpperCase()

    WlSessionLock {
        id: lock

        locked: Session.locked

        // one surface per screen — selection only decides WHICH surfaces
        // render the full visual (clock + auth); all screens stay locked
        WlSessionLockSurface {
            color: Theme.bg

            // veil chrome for NON-selected screens (the full visual covers it
            // wherever it renders)
            Column {
                anchors.centerIn: parent
                spacing: Theme.sp2
                visible: !(screen !== null && Session.lockScreenSelected(screen.name))

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 10
                    height: 10
                    rotation: 45
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.faint
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (Theme.jpEnabled ? "施錠中" : "SESSION LOCKED")
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 3
                }
            }

            LockVisual {
                anchors.fill: parent
                // `screen` is null until the compositor assigns the surface —
                // never dereference it before then (was a boot-time TypeError)
                visible: screen !== null && Session.lockScreenSelected(screen.name)
            }
        }
    }

    // bridge object handed to Session so lockSubmit() reaches the field here
    QtObject {
        id: bridge

        function submit(pw) {
            if (pam.responseRequired) {
                pam.respond(pw);
            } else {
                root._pendingPw = pw;
            }
        }
    }

    Component.onCompleted: Session.authBridge = bridge

    property string _pendingPw: ""

    PamContext {
        id: pam

        config: ShellState.pamService
        user: root.userName

        // PAM asked for the password — flush whatever the user typed
        onResponseRequiredChanged: {
            if (responseRequired && root._pendingPw.length > 0) {
                respond(root._pendingPw);
                root._pendingPw = "";
            }
        }

        onCompleted: result => {
            const ok = result === PamResult.Success;
            Session._authDone(ok);
            root._pendingPw = "";
            if (!ok)
                restartTimer.restart();
        }

        onError: {
            Session._authDone(false);
            restartTimer.restart();
        }
    }

    // re-arm PAM shortly after a failed attempt so the next submit works
    Timer {
        id: restartTimer

        interval: 250
        onTriggered: {
            pam.abort();
            pam.start();
        }
    }

    Connections {
        target: Session

        function onLockedChanged() {
            if (Session.locked) {
                root._pendingPw = "";
                Session.authAttempts = 0;
                pam.abort();
                pam.start();
            } else {
                pam.abort();
            }
        }
    }

    component LockVisual: Item {
        id: vis

        readonly property bool sel: visible

        // ---- entrance ceremony: stage drops in, then the card rises ----
        SequentialAnimation {
            id: enterAnim

            ParallelAnimation {
                NumberAnimation {
                    target: stageWrap
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.movSlow
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: stageShift
                    property: "y"
                    from: -14
                    to: 0
                    duration: Theme.movSlow
                    easing.type: Easing.OutCubic
                }
            }
            PauseAnimation {
                duration: 90
            }
            ParallelAnimation {
                NumberAnimation {
                    target: cardWrap
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.movSlow
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: cardRise
                    property: "y"
                    from: 18
                    to: 0
                    duration: Theme.movSlow
                    easing.type: Easing.OutCubic
                }
            }
        }

        Component.onCompleted: if (Session.locked)
            enterAnim.restart()

        Connections {
            function onLockedChanged() {
                if (Session.locked)
                    enterAnim.restart();
            }

            target: Session
        }

        // ---- backdrop texture: hairline power-line columns + ghost host ----
        Repeater {
            model: Math.floor(parent.width / 120)

            Rectangle {
                required property int index

                x: index * 120 + 60
                width: 1
                height: parent.height
                color: Theme.hairline
                opacity: 0.35
            }
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -Theme.sp3
            anchors.bottomMargin: -Theme.fsDisplay * 2
            text: root.hostName.length > 0 ? root.hostName : "YUTA"
            color: Theme.surface
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsDisplay * 7
            font.weight: Font.ExtraBold
            font.letterSpacing: 6
        }

        // ---- clock stage ----
        Item {
            id: stageWrap

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.13
            height: 150

            Translate {
                id: stageShift
            }

            transform: stageShift

            // micro chrome line
            Text {
                id: chromeLine

                anchors.horizontalCenter: parent.horizontalCenter
                text: (Theme.jpEnabled ? "システム施錠" : "SYSTEM LOCKED") + (root.hostName.length > 0 ? " · " + root.hostName : "")
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 3
            }

            // viewfinder corner brackets frame the clock
            Repeater {
                model: [
                        {
                            "dx": -1,
                            "dy": -1
                        },
                        {
                            "dx": 1,
                            "dy": -1
                        },
                        {
                            "dx": -1,
                            "dy": 1
                        },
                        {
                            "dx": 1,
                            "dy": 1
                        }
                    ]

                delegate: Item {
                    required property var modelData

                    x: stageWrap.width / 2 + modelData.dx * (clockRow.width / 2 + 26) - (modelData.dx < 0 ? 14 : 0)
                    y: 22 + (modelData.dy < 0 ? 0 : 96)
                    width: 14
                    height: 14

                    Rectangle {
                        width: 14
                        height: 1
                        y: parent.modelData.dy < 0 ? 0 : 13
                        color: Theme.faint
                    }

                    Rectangle {
                        width: 1
                        height: 14
                        x: parent.modelData.dx < 0 ? 0 : 13
                        color: Theme.faint
                    }
                }
            }

            Row {
                id: clockRow

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: chromeLine.bottom
                anchors.topMargin: Theme.sp2 + 6
                spacing: 0

                property bool colonOn: true

                Timer {
                    interval: 1000
                    running: vis.sel && Session.locked
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: clockRow.colonOn = !clockRow.colonOn
                }

                Text {
                    anchors.baseline: parent.bottom
                    text: Qt.formatDateTime(new Date(), "HH")
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsDisplay * 4
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 2

                    Timer {
                        interval: 1000
                        running: vis.sel && Session.locked
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH")
                    }
                }

                Text {
                    anchors.baseline: parent.bottom
                    visible: clockRow.colonOn
                    text: ":"
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsDisplay * 4
                    font.weight: Font.ExtraBold
                }

                Text {
                    anchors.baseline: parent.bottom
                    text: Qt.formatDateTime(new Date(), "mm")
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsDisplay * 4
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 2

                    Timer {
                        interval: 1000
                        running: vis.sel && Session.locked
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: parent.text = Qt.formatDateTime(new Date(), "mm")
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clockRow.bottom
                anchors.topMargin: Theme.sp2
                text: Qt.formatDateTime(new Date(), "dddd · d MMMM yyyy").toUpperCase()
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.letterSpacing: 3

                Timer {
                    interval: 60000
                    running: vis.sel && Session.locked
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: parent.text = Qt.formatDateTime(new Date(), "dddd · d MMMM yyyy").toUpperCase()
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clockRow.bottom
                anchors.topMargin: Theme.sp2 + 22
                width: 42
                height: 2
                color: Theme.acid
            }
        }

        // ---- auth card ----
        Item {
            id: cardWrap

            width: 340
            height: 196

            opacity: 1
            transform: Translate {
                id: cardRise
            }

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 46

            Rectangle {
                id: card

                property real shakeX: 0

                anchors.fill: parent
                transform: Translate {
                    x: card.shakeX
                }
                color: Theme.surface
                border.width: 1
                border.color: Session.authAttempts > 0 ? Theme.alert : Session.authBusy ? Theme.acidDeep : Theme.lineStrong

                function snapShake() {
                    shakeSeq.restart();
                }

                SequentialAnimation {
                    id: shakeSeq

                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: -9
                        duration: 1
                    }
                    PauseAnimation {
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: 9
                        duration: 1
                    }
                    PauseAnimation {
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: -5
                        duration: 1
                    }
                    PauseAnimation {
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: 0
                        duration: 1
                    }
                }

                // acid top edge while verifying
                Rectangle {
                    visible: Session.authBusy
                    x: 1
                    y: 1
                    width: parent.width - 2
                    height: 2
                    color: Theme.acid
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.sp4
                    spacing: Theme.sp3

                    Row {
                        spacing: Theme.sp3
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            id: avatarRing

                            width: 48
                            height: 48
                            color: Theme.bgAlt
                            border.width: 1
                            border.color: Session.authBusy ? Theme.acid : Theme.hairline

                            Image {
                                id: avatarImg

                                anchors.fill: parent
                                anchors.margins: 2
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 96
                                sourceSize.height: 96
                                source: root.avatarUrl
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !avatarImg.visible
                                text: root.userName.charAt(0).toUpperCase()
                                color: Theme.acid
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.bold: true
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: root.userName
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                font.weight: Font.Bold
                            }

                            Text {
                                text: Theme.jpEnabled ? "認証" : "AUTHENTICATE"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.letterSpacing: 2
                            }
                        }
                    }

                    YField {
                        id: pwField

                        width: parent.width
                        placeholder: Theme.jpEnabled ? "パスワード" : "password"
                        echoMode: TextInput.Password
                        enabled: !Session.authBusy

                        onAccepted: {
                            if (text.length === 0)
                                return;
                            Session.lockSubmit(text);
                            text = "";
                        }

                        navKeys: true

                        onNavEscape: text = ""

                        Component.onCompleted: if (Session.locked)
                            forceFocus()

                        Connections {
                            target: Session

                            function onLockedChanged() {
                                if (Session.locked)
                                    pwField.forceFocus();
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Session.authBusy
                            text: Theme.jpEnabled ? "確認中…" : "VERIFYING…"
                            color: Theme.acid
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 2
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !Session.authBusy && Session.authAttempts > 0
                            text: Theme.jpEnabled ? "拒否 · 再試行" : "DENIED · TRY AGAIN"
                            color: Theme.alert
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 2
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Session.authAttempts > 0
                            text: "×" + Session.authAttempts
                            color: Theme.alert
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                        }
                    }
                }

                Connections {
                    target: Session

                    function onAuthAttemptsChanged() {
                        if (Session.authAttempts > 0)
                            card.snapShake();
                    }
                }
            }
        }

        // bottom chrome
        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.sp4
            text: root.hostName
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.letterSpacing: 2
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Theme.sp4
            text: "YUTASHELL // " + (ShellState.idleAction !== "none" ? ShellState.idleAction.toUpperCase() + " AFTER IDLE" : "SECURE SHELL")
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.letterSpacing: 2
        }
    }
}
