import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui

// LockScreen — secure wl_session_lock overlay. The compositor guarantees a
// surface per screen; monitor selection ("all"/"primary"/explicit list) only
// decides WHICH surfaces render the full visual (clock + auth). Non-selected
// screens get an opaque veil — they stay locked either way, that's protocol.
//
// Auth: one PamContext here; the handshake STATE lives in Session so the IPC
// layer could drive it too. Wrong attempts snap the card sideways instantly
// (no easing — brutalist), never smooth.
Item {
    id: root

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarUrl: ShellState.lockAvatar.length > 0 ? "file://" + ShellState.lockAvatar : "file://" + Quickshell.env("HOME") + "/.face"

    WlSessionLock {
        id: lock

        locked: Session.locked

        // one surface per screen — selection only decides WHICH surfaces
        // render the full visual (clock + auth); all screens stay locked
        WlSessionLockSurface {
            color: Theme.bg

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

        // ---- clock block ----
        Column {
            id: clockCol

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.14
            spacing: Theme.sp2

            Text {
                id: clockText

                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "HH:mm")
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsDisplay * 4
                font.letterSpacing: 2

                Timer {
                    interval: 1000
                    running: Session.locked
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                }
            }

            Text {
                id: dateText

                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "dddd · d MMMM yyyy").toUpperCase()
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.letterSpacing: 3

                Timer {
                    interval: 60000
                    running: Session.locked
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: dateText.text = Qt.formatDateTime(new Date(), "dddd · d MMMM yyyy").toUpperCase()
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 42
                height: 2
                color: Theme.acid
            }
        }

        // ---- auth card ----
        Rectangle {
            id: card

            property real shakeX: 0

            width: 340
            height: 190
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            transform: Translate {
                x: card.shakeX
            }
            color: Theme.surface
            border.width: 1
            border.color: Session.authAttempts > 0 ? Theme.alert : Theme.lineStrong

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

            Column {
                anchors.fill: parent
                anchors.margins: Theme.sp4
                spacing: Theme.sp3

                Row {
                    spacing: Theme.sp3
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        id: avatarRing

                        width: 44
                        height: 44
                        color: Theme.bgAlt
                        border.width: 1
                        border.color: Theme.hairline

                        Image {
                            id: avatarImg

                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 88
                            sourceSize.height: 88
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
                        spacing: 2

                        Text {
                            text: root.userName
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                        }

                        Text {
                            text: "AUTHENTICATE"
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
                    placeholder: "password"
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
                        text: "VERIFYING…"
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.letterSpacing: 2
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !Session.authBusy && Session.authAttempts > 0
                        text: "DENIED · TRY AGAIN"
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

        // bottom chrome: hostname + hint
        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.sp4
            text: Quickshell.env("HOSTNAME") || ""
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.letterSpacing: 2
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Theme.sp4
            text: "YUTASHELL LOCK"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.letterSpacing: 2
        }
    }
}
