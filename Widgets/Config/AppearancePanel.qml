import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../Shared"

Item {
    id: root

    property real _scaleVal: UIScale.value
    property real _fontVal: UIScale.fontScale
    property real _spacingVal: UIScale.spacingScale
    property real _radiusVal: UIScale.radiusScale

    // Palette being edited in the Colors section, and the role whose picker is
    // currently open (only one at a time).
    property string _editPalette: ThemeState.palette
    property string _openRole: ""

    Timer {
        id: writeTimer
        interval: 0
        onTriggered: UIScale.write(root._scaleVal, root._fontVal, root._spacingVal, root._radiusVal)
    }

    function _roleById(id) {
        if (!id)
            return null;
        var roles = ColorOverrides.roles;
        for (var i = 0; i < roles.length; i++) {
            if (roles[i].id === id)
                return roles[i];
        }
        return null;
    }

    // Effective color of a role in the edited palette: Colors' palettes already
    // have the overrides merged in, so this is what the shell actually paints.
    function _effectiveColor(roleId) {
        var p = root._editPalette === "dark" ? Colors.darkPalette : Colors.lightPalette;
        if (roleId === "bar") {
            var bar = ColorOverrides.get(root._editPalette, "bar");
            return bar.length > 0 ? bar : p.background;
        }
        return p[roleId] || "#000000";
    }

    // The picker fires on every drag step; coalesce so a drag doesn't turn into
    // a write per frame.
    property string _pendingRole: ""
    property string _pendingHex: ""

    function _queueColor(roleId, hex) {
        root._pendingRole = roleId;
        root._pendingHex = hex;
        colorWriteTimer.restart();
    }

    Timer {
        id: colorWriteTimer
        interval: 120
        onTriggered: ColorOverrides.set(root._editPalette, root._pendingRole, root._pendingHex)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            breadcrumb: "INTERFACE"
            title: "Appearance"
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: content.implicitHeight + UIScale.spacingLg * 2
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: content
                x: UIScale.panelPad
                y: UIScale.spacingLg
                width: parent.width - UIScale.panelPad * 2
                spacing: UIScale.spacingMd

                // Interface scale
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Interface scale"
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root._scaleVal.toFixed(2) + "x"
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                    }
                }
                SettingSlider {
                    Layout.fillWidth: true
                    from: 0.5; to: 2.0; step: 0.05
                    value: root._scaleVal
                    onMoved: function(v) { root._scaleVal = v; writeTimer.restart(); }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: UIScale.spacingSm
                    Repeater {
                        model: [["Small", 0.85], ["Normal", 1.0], ["Large", 1.3]]
                        delegate: Rectangle {
                            id: scalePreset
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: Math.round(28 * UIScale.value)
                            radius: UIScale.radiusSm
                            color: Math.abs(root._scaleVal - scalePreset.modelData[1]) < 0.01 ? Colors.withAlpha(Colors.accent, 0.15) : Colors.surfaceHigh
                            border.color: Math.abs(root._scaleVal - scalePreset.modelData[1]) < 0.01 ? Colors.accent : "transparent"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: scalePreset.modelData[0]
                                color: Colors.text
                                font.pixelSize: UIScale.fontCaption
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root._scaleVal = scalePreset.modelData[1]; writeTimer.restart(); }
                            }
                        }
                    }
                }

                Divider { color: Colors.withAlpha(Colors.accent, 0.1) }

                // Font size
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Font size"
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root._fontVal.toFixed(2) + "x"
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                    }
                }
                SettingSlider {
                    Layout.fillWidth: true
                    from: 0.5; to: 2.0; step: 0.05
                    value: root._fontVal
                    onMoved: function(v) { root._fontVal = v; writeTimer.restart(); }
                }

                Divider { color: Colors.withAlpha(Colors.accent, 0.1) }

                // Spacing
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Spacing"
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root._spacingVal.toFixed(2) + "x"
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                    }
                }
                SettingSlider {
                    Layout.fillWidth: true
                    from: 0.5; to: 2.0; step: 0.05
                    value: root._spacingVal
                    onMoved: function(v) { root._spacingVal = v; writeTimer.restart(); }
                }

                Divider { color: Colors.withAlpha(Colors.accent, 0.1) }

                // Radius
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Radius"
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root._radiusVal.toFixed(2) + "x"
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                    }
                }
                SettingSlider {
                    Layout.fillWidth: true
                    from: 0.5; to: 2.0; step: 0.05
                    value: root._radiusVal
                    onMoved: function(v) { root._radiusVal = v; writeTimer.restart(); }
                }

                Divider { color: Colors.withAlpha(Colors.accent, 0.1) }

                // Palette colors
                Text {
                    text: "Colors"
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: UIScale.fontBody
                }
                Text {
                    Layout.fillWidth: true
                    text: "Override individual roles of the wallpaper-generated theme. Each palette keeps its own set, so dark and light can differ."
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                }

                // Which palette is being edited - defaults to the active one,
                // but the other can be set up without switching modes.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: UIScale.spacingSm
                    Repeater {
                        model: [["Dark mode", "dark"], ["Light mode", "light"]]
                        delegate: Rectangle {
                            id: palBtn
                            required property var modelData
                            readonly property bool selected: root._editPalette === palBtn.modelData[1]
                            Layout.fillWidth: true
                            implicitHeight: Math.round(28 * UIScale.value)
                            radius: UIScale.radiusSm
                            color: palBtn.selected ? Colors.withAlpha(Colors.accent, 0.15) : Colors.surfaceHigh
                            border.color: palBtn.selected ? Colors.accent : "transparent"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: palBtn.modelData[0] + (ThemeState.palette === palBtn.modelData[1] ? " (active)" : "")
                                color: Colors.text
                                font.pixelSize: UIScale.fontCaption
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root._editPalette = palBtn.modelData[1];
                                    root._openRole = "";
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root._editPalette !== ThemeState.palette
                    text: "Editing the inactive palette - changes apply when you switch to " + root._editPalette + " mode."
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                }

                // Swatch grid - the hex only shows up in the editor below,
                // once a role is actually picked.
                Grid {
                    id: roleGrid

                    readonly property real _cellPitch: Math.round(52 * UIScale.value) + UIScale.spacingSm
                    readonly property int _maxCols: Math.max(1, Math.floor((content.width + UIScale.spacingSm) / roleGrid._cellPitch))
                    readonly property int _rows: Math.max(1, Math.ceil(ColorOverrides.roles.length / roleGrid._maxCols))

                    Layout.fillWidth: true
                    Layout.topMargin: UIScale.spacingXs
                    // Balanced so the last row isn't left with a single tile.
                    columns: Math.ceil(ColorOverrides.roles.length / roleGrid._rows)
                    columnSpacing: UIScale.spacingSm
                    rowSpacing: UIScale.spacingSm

                    Repeater {
                        model: ColorOverrides.roles
                        delegate: Item {
                            id: roleTile

                            required property var modelData
                            readonly property string roleId: roleTile.modelData.id
                            readonly property bool overridden: ColorOverrides.isOverridden(root._editPalette, roleTile.roleId)
                            readonly property bool selected: root._openRole === roleTile.roleId

                            implicitWidth: Math.round(52 * UIScale.value)
                            implicitHeight: Math.round(70 * UIScale.value)

                            Rectangle {
                                id: tileSwatch
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(46 * UIScale.value)
                                height: Math.round(46 * UIScale.value)
                                radius: Math.round(10 * UIScale.value)
                                color: root._effectiveColor(roleTile.roleId)
                                border.color: roleTile.selected ? Colors.accent : Colors.withAlpha(Colors.text, 0.08)
                                border.width: roleTile.selected ? 2 : 1

                                // Overridden roles get a dot rather than a hex
                                // string, so the grid stays readable.
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: UIScale.spacingXs
                                    width: Math.round(7 * UIScale.value)
                                    height: width
                                    radius: width / 2
                                    visible: roleTile.overridden
                                    color: Colors.accent
                                    border.color: Colors.withAlpha(Colors.bg, 0.6)
                                    border.width: 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._openRole = roleTile.selected ? "" : roleTile.roleId
                                }
                            }

                            Text {
                                anchors.top: tileSwatch.bottom
                                anchors.topMargin: UIScale.spacingXs
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: roleTile.modelData.label
                                color: roleTile.selected ? Colors.accent : Colors.textDim
                                font.pixelSize: Math.round(9 * UIScale.value)
                            }
                        }
                    }
                }

                // Editor for the tile that's open. This is the only place a hex
                // code shows up.
                ColumnLayout {
                    id: roleEditor

                    readonly property var role: root._roleById(root._openRole)

                    Layout.fillWidth: true
                    Layout.topMargin: UIScale.spacingXs
                    visible: roleEditor.role !== null
                    spacing: UIScale.spacingSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: UIScale.spacingSm

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: roleEditor.role ? roleEditor.role.label : ""
                                color: Colors.text
                                font.bold: true
                                font.pixelSize: UIScale.fontBody
                            }
                            Text {
                                Layout.fillWidth: true
                                text: roleEditor.role ? roleEditor.role.desc : ""
                                color: Colors.muted
                                font.pixelSize: UIScale.fontTiny
                                wrapMode: Text.WordWrap
                            }
                        }
                        ActionButton {
                            visible: ColorOverrides.isOverridden(root._editPalette, root._openRole)
                            label: "Reset"
                            onActivated: ColorOverrides.clear(root._editPalette, root._openRole)
                        }
                    }

                    ColorPicker {
                        Layout.fillWidth: true
                        value: root._effectiveColor(root._openRole)
                        onPicked: function (hex) {
                            root._queueColor(root._openRole, hex);
                        }
                    }
                }

                ActionButton {
                    Layout.topMargin: UIScale.spacingXs
                    label: "Reset " + root._editPalette + " colors"
                    onActivated: ColorOverrides.clearPalette(root._editPalette)
                }
            }
        }
    }
}
