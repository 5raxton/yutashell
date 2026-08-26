import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "../bar"

Column {
    id: root

    width: parent.width
    spacing: Theme.sp3

    function applyPreset(preset) {
        BarSegments.applyPreset(preset.id);
    }

    function saveCurrentAsPreset(label) {
        let presets = [];
        try {
            presets = JSON.parse(ShellState.customPresets);
            if (!Array.isArray(presets))
                presets = [];
        } catch (e) {}
        presets.push({
            id: "custom-" + Date.now(),
            label: label,
            desc: "User preset",
            segments: JSON.parse(ShellState.barSegments),
            barScale: ShellState.barScale,
            barPosition: ShellState.barPosition,
            wsMode: ShellState.wsMode
        });
        ShellState.set("customPresets", JSON.stringify(presets));
    }

    function deleteCustomPreset(presetId) {
        let presets = [];
        try {
            presets = JSON.parse(ShellState.customPresets);
            if (!Array.isArray(presets))
                presets = [];
        } catch (e) {}
        presets = presets.filter(p => p.id !== presetId);
        ShellState.set("customPresets", JSON.stringify(presets));
    }

    YSection {
        width: parent.width
        index: "01"
        label: "Built-in presets"
    }

    Grid {
        columns: parent.width > 560 ? 3 : 2
        spacing: Theme.sp2

        Repeater {
            model: BarSegments.layoutPresets

            delegate: Rectangle {
                required property var modelData

                width: (root.width - Theme.sp2 * 2) / (root.width > 560 ? 3 : 2)
                height: 88
                color: Theme.bg
                radius: Theme.sp1
                border.width: 1
                border.color: Theme.hairline

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.sp2
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Text {
                            text: modelData.label
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.weight: Font.Bold
                        }

                        Item { width: 4; height: 1 }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.barScale + "x"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                        }
                    }

                    Text {
                        width: parent.width
                        text: modelData.desc
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    Item { width: 1; height: 1 }

                    Row {
                        spacing: Theme.sp1

                        Repeater {
                            model: modelData.segments.filter(s => s.enabled)

                            delegate: Rectangle {
                                required property var modelData

                                width: Math.max(segLabel.width + 8, 18)
                                height: 14
                                radius: 2
                                color: Theme.acid

                                Text {
                                    id: segLabel
                                    anchors.centerIn: parent
                                    text: BarSegments.abbrFor(modelData.id)
                                    color: Theme.bg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 7
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 1 }

                    YButton {
                        width: 72
                        height: 22
                        label: "APPLY"
                        onClicked: root.applyPreset(modelData)
                    }
                }
            }
        }
    }

    YSection {
        width: parent.width
        index: "02"
        label: "Custom presets"
        chip: {
            try {
                const cp = JSON.parse(ShellState.customPresets);
                return Array.isArray(cp) ? String(cp.length) : "0";
            } catch (e) {}
            return "0";
        }
    }

    Row {
        spacing: Theme.sp2

        YButton {
            width: 140
            height: 28
            label: "SAVE CURRENT"
            onClicked: {
                let count = 0;
                try {
                    const cp = JSON.parse(ShellState.customPresets);
                    if (Array.isArray(cp)) count = cp.length;
                } catch (e) {}
                root.saveCurrentAsPreset("Custom " + (count + 1));
            }
        }
    }

    Repeater {
        model: {
            try {
                const cp = JSON.parse(ShellState.customPresets);
                return Array.isArray(cp) ? cp : [];
            } catch (e) {}
            return [];
        }

        delegate: Rectangle {
            required property var modelData

            width: root.width
            height: 48
            color: Theme.bg
            radius: Theme.sp1
            border.width: 1
            border.color: Theme.hairline

            Row {
                anchors.fill: parent
                anchors.margins: Theme.sp2
                spacing: Theme.sp2

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 72 - 60 - Theme.sp2 * 2
                    spacing: 2

                    Text {
                        text: modelData.label
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.weight: Font.Bold
                    }

                    Text {
                        text: modelData.barScale + "x · " + modelData.barPosition.toUpperCase() + " · " + modelData.segments.filter(s => s.enabled).length + " segments"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                    }
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 22
                    label: "APPLY"
                    onClicked: root.applyPreset(modelData)
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 22
                    label: "DEL"
                    onClicked: root.deleteCustomPreset(modelData.id)
                }
            }
        }
    }

    Text {
        visible: {
            try {
                const cp = JSON.parse(ShellState.customPresets);
                return !Array.isArray(cp) || cp.length === 0;
            } catch (e) {}
            return true;
        }
        text: "No custom presets saved yet."
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
    }
}
