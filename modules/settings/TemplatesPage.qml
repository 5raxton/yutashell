import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "ui"

// Template catalog browser — every matugen-themes template grouped by app
// family, all OFF until the user opts in. Search + add-custom form.
Column {
    id: root

    property real contentW: 300

    width: contentW
    spacing: Theme.sp3

    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property var rows: Wallpaper.templatesList()
    readonly property int enabledCount: rows.filter(r => r.enabled).length

    // sections rebuild recreates every group header + TemplateRow (~60
    // delegates) — debounce the search text so typing doesn't do that per key
    property string settledQuery: ""
    Timer {
        id: settleTimer

        interval: 180
        onTriggered: root.settledQuery = root.query
    }
    onQueryChanged: settleTimer.restart()

    // groups in catalog order, CUSTOM last; empty groups dropped; query filtered
    readonly property var sections: {
        const q = root.settledQuery;
        const out = [];
        const gs = TemplateCatalog.groups.concat([{ id: "CUSTOM", jp: "" }]);
        for (const g of gs) {
            const rs = root.rows.filter(r => {
                if (r.group !== g.id)
                    return false;
                if (q.length === 0)
                    return true;
                return r.id.includes(q) || r.label.toLowerCase().includes(q) || String(r.output).toLowerCase().includes(q);
            });
            if (rs.length > 0)
                out.push({
                    id: g.id,
                    jp: g.jp ?? "",
                    rows: rs
                });
        }
        return out;
    }

    // embedded-only today — the host page (appearance "05 Matugen templates")
    // renders the section header, so none here or it doubles up

    Row {
        spacing: Theme.sp2

        YField {
            id: searchField

            width: root.contentW - 96
            placeholder: "search apps…"
        }

        YButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 88
            tone: form.visible ? "default" : "acid"
            label: form.visible ? "cancel" : "+ custom"
            onClicked: {
                form.visible = !form.visible;
                if (!form.visible)
                    formError.label = "";
                else
                    fieldId.forceFocus();
            }
        }
    }

    // ===== ADD-CUSTOM FORM =====
    Column {
        id: form

        visible: false
        width: parent.width
        spacing: Theme.sp2

        YField {
            id: fieldId

            width: parent.width
            placeholder: "template id · e.g. my-app"
        }

        YField {
            id: fieldInput

            width: parent.width
            placeholder: "input .tera template path"
        }

        YField {
            id: fieldOutput

            width: parent.width
            placeholder: "output path · ~ ok · rewritten on every apply"
            onAccepted: submit()
        }

        Row {
            spacing: Theme.sp2

            YButton {
                width: 72
                tone: "acid"
                label: "add"
                onClicked: submit()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: formError.label
                visible: formError.label.length > 0
                color: Theme.alert
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }

        function submit() {
            const ok = Wallpaper.addTemplate(fieldId.text, fieldInput.text, fieldOutput.text, "");
            if (ok) {
                fieldId.text = "";
                fieldInput.text = "";
                fieldOutput.text = "";
                formError.label = "";
                form.visible = false;
            } else {
                formError.label = "! bad args or duplicate id";
            }
        }

        Item {
            id: formError

            property string label: ""
            width: 0
            height: 0
        }

        Text {
            width: parent.width
            text: "templates use matugen syntax — {{colors.primary.default.hex}} etc. outputs regenerate on every wallpaper apply while enabled."
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLabel
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.hairline
    }

    // ===== GROUPED ROWS =====
    Repeater {
        model: root.sections

        delegate: Column {
            id: groupCol

            required property var modelData

            width: root.contentW
            spacing: 2

            YSection {
                width: parent.width
                label: groupCol.modelData.id
                chip: groupCol.modelData.rows.filter(r => r.enabled).length + "/" + groupCol.modelData.rows.length
            }

            Repeater {
                model: groupCol.modelData.rows

                delegate: TemplateRow {
                    width: root.contentW
                }
            }

            Item {
                width: 1
                height: Theme.sp2
            }
        }
    }

    Text {
        visible: root.sections.length === 0
        width: parent.width
        text: Theme.jpEnabled ? "該当なし — no match" : "no match for \"" + root.query + "\""
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.letterSpacing: 1.5
        horizontalAlignment: Text.AlignHCenter
        topPadding: Theme.sp3
    }

    Text {
        width: parent.width
        text: "toggling rewrites ~/.local/state/yutashell/matugen.toml and regenerates immediately when follow-wallpaper is on."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.WordWrap
    }
}
