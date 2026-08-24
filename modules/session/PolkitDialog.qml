import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui

// PolkitDialog — themed privilege agent. Registers on the session bus the
// moment it exists; whenever an app needs root (systemctl, nmcli, …) the
// dialog drops in on the Overlay layer so it even shows above the lock
// screen. Response field echo is driven by the flow.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: agent.isActive || hideDelay.running
    mask: Region {
        item: agent.isActive ? surface : null
    }

    // above everything — polkit can appear over the lock screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 440

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow

    Timer {
        id: hideDelay

        interval: 190
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (root.flow)
                root.flow.cancelAuthenticationRequest();
        }

        YSurface {
            id: surface

            open: agent.isActive
            cascade: bodyCol
            anchorX: "center"
            cardW: root.cardW
            cardH: bodyCol.implicitHeight + Theme.sp4 * 2
            restGap: Theme.sp4
            flareTop: false

            Column {
                id: bodyCol

                x: Theme.sp4
                y: Theme.sp4
                width: parent.width - Theme.sp4 * 2
                spacing: Theme.sp3

                Text {
                    width: parent.width
                    text: "PRIVILEGE REQUEST"
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 3
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: root.flow && root.flow.message.length > 0
                    text: root.flow ? root.flow.message : ""
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: root.flow && root.flow.actionId.length > 0
                    text: root.flow ? root.flow.actionId : ""
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }

                // multiple auth identities — cycle selection (rare; usually one)
                Row {
                    visible: root.flow && root.flow.identities.length > 1
                    spacing: Theme.sp2

                    YButton {
                        label: "IDENTITY " + (root.flow ? root.flow.identities.indexOf(root.flow.selectedIdentity) + 1 : 0) + "/" + (root.flow ? root.flow.identities.length : 0)
                        onClicked: {
                            if (!root.flow)
                                return;
                            const ids = root.flow.identities;
                            const idx = (ids.indexOf(root.flow.selectedIdentity) + 1) % ids.length;
                            root.flow.selectedIdentity = ids[idx];
                        }
                    }
                }

                YField {
                    id: respField

                    width: parent.width
                    visible: root.flow && root.flow.responseVisible
                    placeholder: root.flow ? root.flow.inputPrompt : "password"
                    echoMode: root.flow && root.flow.responseVisible ? (root.flow.inputPrompt.toLowerCase().indexOf("password") >= 0 ? TextInput.Password : TextInput.Normal) : TextInput.Password

                    onAccepted: {
                        if (root.flow)
                            root.flow.submit(text);
                        text = "";
                    }

                    navKeys: true

                    onNavEscape: {
                        if (root.flow)
                            root.flow.cancelAuthenticationRequest();
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: root.flow && root.flow.supplementaryMessage.length > 0
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? Theme.alert : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                }

                Row {
                    spacing: Theme.sp2
                    anchors.right: parent.right

                    YButton {
                        label: "CANCEL"
                        onClicked: {
                            if (root.flow)
                                root.flow.cancelAuthenticationRequest();
                        }
                    }

                    YButton {
                        label: "AUTHORIZE"
                        tone: "acid"
                        onClicked: {
                            if (!root.flow)
                                return;
                            root.flow.submit(respField.text);
                            respField.text = "";
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: agent

        function onFlowChanged() {
            if (agent.isActive && root.flow && root.flow.responseVisible)
                respField.forceFocus();
        }
    }
}
