import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
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

    // Whether a role's effective color actually differs from what this
    // wallpaper's own matugen generation would give it. isOverridden() alone
    // isn't enough: applying a saved theme writes every role into
    // ColorOverrides (Themes.qml snapshots the full palette, not just the
    // roles that were hand-picked), so right after loading a theme every
    // role would otherwise read as "customized" even the ones that just
    // happen to match the wallpaper's own colors. "bar" has no wallpaper
    // role to compare against, so it stays presence-based.
    function _isCustomized(roleId) {
        if (roleId === "bar")
            return ColorOverrides.isOverridden(root._editPalette, "bar");
        var raw = root._editPalette === "dark" ? Colors.rawDarkPalette : Colors.rawLightPalette;
        var baseline = raw[roleId];
        if (!baseline)
            return ColorOverrides.isOverridden(root._editPalette, roleId);
        return root._effectiveColor(roleId).toLowerCase() !== baseline.toLowerCase();
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

    // Overwriting an existing theme needs a second click within a few
    // seconds to confirm, same two-step pattern as the destructive actions
    // in PowerMenu.qml - saving a brand new name (no existing match) still
    // goes through in one click.
    property string _saveArmedFor: ""

    Timer {
        id: saveArmTimer
        interval: 3000
        onTriggered: root._saveArmedFor = ""
    }

    function _saveTheme() {
        var name = themeNameField.text.trim();
        if (name.length === 0)
            return;
        if (Themes.exists(name) && root._saveArmedFor !== name) {
            root._saveArmedFor = name;
            saveArmTimer.restart();
            return;
        }
        Themes.save(name);
        themeNameField.text = "";
        root._saveArmedFor = "";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            breadcrumb: I18n.t("appearance.breadcrumb")
            title: I18n.t("appearance.title")
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
                        text: I18n.t("appearance.interfaceScale")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: I18n.t("appearance.multiplier", [root._scaleVal.toFixed(2)])
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
                        model: [[I18n.t("appearance.small"), 0.85], [I18n.t("appearance.normal"), 1.0], [I18n.t("appearance.large"), 1.3]]
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
                        text: I18n.t("appearance.fontSize")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: I18n.t("appearance.multiplier", [root._fontVal.toFixed(2)])
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
                        text: I18n.t("appearance.spacing")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: I18n.t("appearance.multiplier", [root._spacingVal.toFixed(2)])
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
                        text: I18n.t("appearance.radius")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: I18n.t("appearance.multiplier", [root._radiusVal.toFixed(2)])
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
                    text: I18n.t("appearance.colors")
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: UIScale.fontBody
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("appearance.colorsDescription")
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                }

                // Whether edits below apply only to the active wallpaper, or
                // globally regardless of which wallpaper is set.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: UIScale.spacingXs
                    spacing: UIScale.spacingSm
                    Repeater {
                        model: [[I18n.t("appearance.scopeWallpaper"), "wallpaper"], [I18n.t("appearance.scopeGlobal"), "global"]]
                        delegate: Rectangle {
                            id: scopeBtn
                            required property var modelData
                            readonly property bool selected: ColorOverrides.scope === scopeBtn.modelData[1]
                            Layout.fillWidth: true
                            implicitHeight: Math.round(28 * UIScale.value)
                            radius: UIScale.radiusSm
                            color: scopeBtn.selected ? Colors.withAlpha(Colors.accent, 0.15) : Colors.surfaceHigh
                            border.color: scopeBtn.selected ? Colors.accent : "transparent"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: scopeBtn.modelData[0]
                                color: Colors.text
                                font.pixelSize: UIScale.fontCaption
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ColorOverrides.setScope(scopeBtn.modelData[1])
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: ColorOverrides.scope === "global" ? I18n.t("appearance.scopeGlobalDescription") : I18n.t("appearance.scopeWallpaperDescription")
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
                        model: [[I18n.t("appearance.darkMode"), "dark"], [I18n.t("appearance.lightMode"), "light"]]
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
                                text: ThemeState.palette === palBtn.modelData[1] ? I18n.t("appearance.paletteActive", [palBtn.modelData[0]]) : palBtn.modelData[0]
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
                    text: I18n.t("appearance.editingInactive", [root._editPalette === "dark" ? I18n.t("appearance.dark") : I18n.t("appearance.light")])
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
                            readonly property bool overridden: root._isCustomized(roleTile.roleId)
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
                            visible: root._isCustomized(root._openRole)
                            label: I18n.t("appearance.reset")
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
                    label: I18n.t("appearance.resetPaletteColors", [root._editPalette === "dark" ? I18n.t("appearance.dark") : I18n.t("appearance.light")])
                    onActivated: ColorOverrides.clearPalette(root._editPalette)
                }

                Divider { color: Colors.withAlpha(Colors.accent, 0.1) }

                // Saved themes - snapshots of whatever colors are in effect
                // right now (generated or overridden, doesn't matter), that
                // can be re-applied later in either scope above.
                Text {
                    text: I18n.t("appearance.themes")
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: UIScale.fontBody
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("appearance.themesDescription")
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: UIScale.spacingXs
                    spacing: UIScale.spacingSm

                    StyledTextInput {
                        id: themeNameField
                        Layout.fillWidth: true
                        placeholder: I18n.t("appearance.themeNamePlaceholder")
                        onAccepted: root._saveTheme()
                    }
                    ActionButton {
                        readonly property bool _armed: root._saveArmedFor !== "" && root._saveArmedFor === themeNameField.text.trim()
                        label: _armed ? I18n.t("appearance.saveThemeConfirm") : I18n.t("appearance.saveTheme")
                        onActivated: root._saveTheme()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: UIScale.spacingSm
                    visible: Themes.themes.length === 0
                    text: I18n.t("appearance.noThemesSaved")
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                }

                Repeater {
                    model: Themes.themes
                    delegate: ColumnLayout {
                        id: themeRow
                        required property var modelData
                        readonly property bool hasWallpaper: Themes.hasWallpaper(themeRow.modelData)
                        readonly property bool isActive: Themes.activeThemeName === themeRow.modelData.name
                        readonly property string wallpaperPath: Themes.primaryWallpaper(themeRow.modelData)
                        property bool renaming: false

                        function confirmRename() {
                            if (Themes.rename(themeRow.modelData.name, renameField.text))
                                themeRow.renaming = false;
                        }

                        Layout.fillWidth: true
                        Layout.topMargin: UIScale.spacingSm
                        spacing: Math.round(2 * UIScale.value)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: UIScale.spacingSm

                            Rectangle {
                                id: thumbRect
                                implicitWidth: Math.round(34 * UIScale.value)
                                implicitHeight: implicitWidth
                                radius: UIScale.radiusSm
                                color: Colors.surfaceHigh
                                clip: true

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    visible: themeRow.hasWallpaper
                                    source: themeRow.hasWallpaper ? ("file://" + ThemeState.thumbsDir + "/" + themeRow.wallpaperPath.substring(themeRow.wallpaperPath.lastIndexOf("/") + 1) + ".jpg") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    onStatusChanged: {
                                        if (status === Image.Error && !thumbGen.running)
                                            thumbGen.running = true;
                                    }
                                }

                                Process {
                                    id: thumbGen
                                    command: ["magick", themeRow.wallpaperPath, "-resize", "68x68^", "-gravity", "Center", "-extent", "68x68", ThemeState.thumbsDir + "/" + themeRow.wallpaperPath.substring(themeRow.wallpaperPath.lastIndexOf("/") + 1) + ".jpg"]
                                    onExited: (code, status) => {
                                        if (code === 0) {
                                            thumbImg.source = "";
                                            thumbImg.source = "file://" + ThemeState.thumbsDir + "/" + themeRow.wallpaperPath.substring(themeRow.wallpaperPath.lastIndexOf("/") + 1) + ".jpg";
                                        } else {
                                            thumbImg.source = "file://" + themeRow.wallpaperPath;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: themeRow.isActive
                                implicitWidth: Math.round(7 * UIScale.value)
                                implicitHeight: implicitWidth
                                radius: implicitWidth / 2
                                color: Colors.accent
                            }

                            Text {
                                visible: !themeRow.renaming
                                text: themeRow.modelData.name
                                color: themeRow.isActive ? Colors.accent : Colors.text
                                font.bold: themeRow.isActive
                                font.pixelSize: UIScale.fontBody
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            StyledTextInput {
                                id: renameField
                                visible: themeRow.renaming
                                Layout.fillWidth: true
                                text: themeRow.modelData.name
                                onAccepted: themeRow.confirmRename()
                                onEscapePressed: themeRow.renaming = false
                                onVisibleChanged: if (visible)
                                    field.forceActiveFocus()
                            }

                            Text {
                                visible: themeRow.isActive && !themeRow.renaming
                                text: I18n.t("appearance.themeActive")
                                color: Colors.accent
                                font.pixelSize: UIScale.fontTiny
                            }

                            ToggleSwitch {
                                visible: !themeRow.renaming
                                checked: !!themeRow.modelData.pinned
                                onToggled: Themes.togglePinned(themeRow.modelData.name)
                            }
                            Text {
                                visible: !themeRow.renaming
                                text: I18n.t("appearance.pinned")
                                color: Colors.textDim
                                font.pixelSize: UIScale.fontTiny
                            }

                            ActionButton {
                                label: themeRow.renaming ? I18n.t("appearance.renameConfirm") : I18n.t("appearance.rename")
                                onActivated: themeRow.renaming ? themeRow.confirmRename() : (themeRow.renaming = true)
                            }
                            ActionButton {
                                visible: themeRow.renaming
                                label: I18n.t("appearance.renameCancel")
                                onActivated: themeRow.renaming = false
                            }
                            ActionButton {
                                visible: !themeRow.renaming
                                label: I18n.t("appearance.applyTheme")
                                onActivated: Themes.apply(themeRow.modelData.name)
                            }
                            ActionButton {
                                visible: !themeRow.renaming
                                label: I18n.t("appearance.deleteTheme")
                                onActivated: Themes.remove(themeRow.modelData.name)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: themeRow.modelData.pinned && !themeRow.hasWallpaper
                            text: I18n.t("appearance.pinnedNoWallpaperHint")
                            color: Colors.muted
                            font.pixelSize: UIScale.fontTiny
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
