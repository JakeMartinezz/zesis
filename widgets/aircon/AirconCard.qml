pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared"
import "../../"

// Aircon controls shared by the bar popup (full) and the desktop widget (compact).
// Shows the login form or an error panel instead of controls when needed.
Item {
    id: root

    property bool compact: false

    readonly property var svc: AirconService
    readonly property color tint: svc.modeColor(svc.mode, svc.power && svc.online)
    readonly property bool _needsLogin: svc.errorCode === "no_credentials" || svc.errorCode === "auth" || svc.errorCode === "store"
    readonly property bool _hardError: ["no_openssl", "no_keyring", "no_device", "locked", "env_perms"].indexOf(svc.errorCode) >= 0
    readonly property real _pad: compact ? UIScale.spacingSm : UIScale.spacingLg

    implicitWidth: Math.round((compact ? 250 : 320) * UIScale.value)
    implicitHeight: (_needsLogin ? loginCol.implicitHeight : _hardError ? errorCol.implicitHeight : controls.implicitHeight) + _pad * 2

    // ---- error panel ----
    StatusPanel {
        id: errorCol
        visible: root._hardError
        anchors.fill: parent
        anchors.margins: root._pad
        icon: AirconService.acIcon
        message: ({
                no_openssl: I18n.t("common.errNoOpenssl"),
                no_keyring: I18n.t("aircon.errNoKeyring"),
                no_device: I18n.t("aircon.errNoDevice"),
                locked: I18n.t("common.errLocked"),
                env_perms: I18n.t("common.errEnvPerms", [root.svc.errorMessage])
            })[root.svc.errorCode] ?? ""
        showUnlock: root.svc.errorCode === "locked"
        onRetry: root.svc.retry()
    }

    // ---- login ----
    ColumnLayout {
        id: loginCol
        visible: root._needsLogin
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: UIScale.spacingSm

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: I18n.t("aircon.loginTitle")
            color: Colors.text
            font.pixelSize: UIScale.fontSubhead
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: root.svc.errorCode === "auth" || root.svc.errorCode === "store"
            text: root.svc.errorCode === "auth" ? I18n.t("aircon.errAuth", [root.svc.errorMessage]) : I18n.t("aircon.errStore")
            color: Colors.accent
            font.pixelSize: UIScale.fontSmall
        }
        StyledTextInput {
            id: emailField
            placeholder: I18n.t("aircon.email")
            onAccepted: passField.field.forceActiveFocus()
        }
        StyledTextInput {
            id: passField
            placeholder: I18n.t("aircon.password")
            echoMode: TextInput.Password
            onAccepted: saveBtn.activated()
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: I18n.t("aircon.loginHint")
            color: Colors.textDim
            font.pixelSize: UIScale.fontCaption
        }
        ActionButton {
            id: saveBtn
            Layout.alignment: Qt.AlignRight
            label: I18n.t("aircon.save")
            enabled: emailField.text.length > 0 && passField.text.length > 0
            onActivated: {
                if (!enabled)
                    return;
                root.svc.saveCredentials(emailField.text, passField.text);
                passField.text = "";
            }
        }
    }

    // ---- controls ----
    ColumnLayout {
        id: controls
        visible: !root._needsLogin && !root._hardError
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: root.compact ? UIScale.spacingSm : UIScale.spacingMd
        enabled: root.svc.online && root.svc.hasState
        opacity: root.svc.online && root.svc.hasState ? 1 : 0.5 // not `enabled`: the config overlay disables the whole card

        DeviceHeader {
            compact: root.compact
            title: I18n.t("aircon.title")
            status: !root.svc.online ? I18n.t("aircon.offline") : !root.svc.power ? I18n.t("aircon.off") : I18n.t("aircon.on") + " · " + I18n.t("aircon." + (root.svc.modeInfo(root.svc.mode)?.key ?? "modeAuto"))
            checked: root.svc.power
            accentColor: root.tint
            onToggled: root.svc.toggle("t_power")
        }

        ArcDial {
            Layout.alignment: Qt.AlignHCenter
            diameter: Math.round((root.compact ? 150 : 210) * UIScale.value)
            value: root.svc.targetTemp
            caption: root.svc.roomTemp > 0 ? I18n.t("aircon.room", [root.svc.roomTemp]) : ""
            minValue: root.svc.minTemp
            maxValue: root.svc.maxTemp
            accentColor: root.tint
            active: root.svc.power
            countdown: root.svc.countdown
            onCommitted: v => root.svc.set({ t_temp: v })
        }

        // "updated Ns ago" - click to refresh now
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.svc.errorCode === "network" ? I18n.t("aircon.retrying") : !root.svc.live ? I18n.t("aircon.updating") : I18n.t("aircon.updatedAgo", [Math.max(0, root.svc.now - root.svc.lastUpdate)])
            color: refreshHover.hovered ? Colors.accent : Colors.textDim
            font.pixelSize: UIScale.fontCaption
            HoverHandler {
                id: refreshHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.svc.refresh()
            }
        }

        Divider {}

        SectionLabel {
            text: I18n.t("aircon.modeSection")
        }

        // mode segmented control with a sliding indicator
        Item {
            id: modeRow
            Layout.fillWidth: true
            implicitHeight: Math.round((root.compact ? 38 : 52) * UIScale.value)
            readonly property int _count: root.svc.modes.length
            readonly property real _cell: width / _count
            readonly property int _selected: {
                for (var i = 0; i < root.svc.modes.length; i++)
                    if (root.svc.modes[i].value === root.svc.mode)
                        return i;
                return -1;
            }

            Rectangle {
                anchors.fill: parent
                radius: UIScale.radiusMd
                color: Colors.withAlpha(Colors.text, 0.03)
                border.color: Colors.withAlpha(Colors.text, 0.06)
                border.width: 1
            }
            // Animated position follows selection changes only, so open/resize don't slide.
            property real _pos: Math.max(0, _selected)
            Behavior on _pos {
                NumberAnimation {
                    duration: Anim.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anim.spatial
                }
            }

            Rectangle {
                visible: modeRow._selected >= 0
                x: modeRow._pos * modeRow._cell + 2
                y: 2
                width: modeRow._cell - 4
                height: modeRow.height - 4
                radius: UIScale.radiusMd - 2
                color: Colors.withAlpha(root.tint, 0.18)
                border.color: Colors.withAlpha(root.tint, 0.5)
                border.width: 1
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: root.svc.modes
                    delegate: Item {
                        id: modeCell
                        required property var modelData
                        required property int index
                        width: modeRow._cell
                        height: modeRow.height
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: UIScale.radiusMd - 2
                            color: Colors.withAlpha(Colors.text, modeHover.hovered ? 0.05 : 0)
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modeCell.modelData.icon
                                color: modeCell.index === modeRow._selected ? root.tint : Colors.textDim
                                font.pixelSize: Math.round((root.compact ? 15 : 19) * UIScale.value)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !root.compact
                                width: Math.min(implicitWidth, modeCell.width - 4)
                                elide: Text.ElideRight
                                text: I18n.t("aircon." + modeCell.modelData.key)
                                color: modeCell.index === modeRow._selected ? root.tint : Colors.textDim
                                font.pixelSize: UIScale.fontSmall
                            }
                        }
                        TapHandler {
                            onTapped: root.svc.set({ t_work_mode: modeCell.modelData.value })
                        }
                        HoverHandler {
                            id: modeHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }

        SectionLabel {
            text: I18n.t("aircon.fanSection")
        }

        OptionRow {
            Layout.fillWidth: true
            readonly property var _values: [root.svc.fanAuto].concat(root.svc.fans.map(f => f.value))
            model: [I18n.t("aircon.fanAuto")].concat(root.svc.fans.map((f, i) => String(i + 1)))
            currentIndex: _values.indexOf(root.svc.fan)
            accentColor: root.tint
            onActivated: i => root.svc.set({ t_fan_speed: _values[i] })
        }

        // swing (t_up_down) gets its own row; the other extras live under "more options"
        RowLayout {
            Layout.fillWidth: true
            spacing: UIScale.spacingSm
            Column {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: I18n.t("aircon.swingTitle")
                    color: Colors.text
                    font.pixelSize: UIScale.fontBody
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: !root.compact
                    text: I18n.t("aircon.swingHint")
                    color: Colors.textDim
                    font.pixelSize: UIScale.fontCaption
                }
            }
            ToggleSwitch {
                checked: root.svc.view.t_up_down === 1
                accentColor: root.tint
                onToggled: root.svc.toggle("t_up_down")
            }
        }

        SettingCard {
            id: more
            property bool open: false

            // One column with no spacing, so the extras' gap can live inside the animated
            // height instead of popping in/out with the wrapper's visibility.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                // The desktop widget is a layer surface sized to its content: growing it
                // resizes and moves the window every frame. So in compact mode the extras
                // swap in place of this row (same height) instead of expanding below it.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(moreHeader.implicitHeight, compactExtras.implicitHeight)

                    RowLayout {
                        id: moreHeader
                        anchors.fill: parent
                        spacing: UIScale.spacingSm
                        // compact: crossfades with the extras row instead of expanding
                        opacity: root.compact && more.open ? 0 : 1
                        enabled: opacity > 0.5
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Anim.medium
                            }
                        }
                        Text {
                            text: String.fromCodePoint(0xF0493) // md-cog
                            color: Colors.textDim
                            font.pixelSize: Math.round(18 * UIScale.value)
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: I18n.t("aircon.moreTitle")
                                color: Colors.text
                                font.pixelSize: UIScale.fontBody
                                font.weight: Font.DemiBold
                            }
                            Text {
                                visible: !root.compact
                                text: I18n.t("aircon.moreHint")
                                color: Colors.textDim
                                font.pixelSize: UIScale.fontCaption
                            }
                        }
                        Text {
                            text: String.fromCodePoint(0xF0142) // md-chevron_right
                            color: moreHover.hovered ? Colors.accent : Colors.textDim
                            font.pixelSize: Math.round(18 * UIScale.value)
                            rotation: more.open && !root.compact ? 90 : 0
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Anim.fast
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Anim.standard
                                }
                            }
                        }
                        HoverHandler {
                            id: moreHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            // Curve picked before toggling: a binding on `more.open` would be
                            // read stale in the same update that starts the height animation.
                            onTapped: {
                                moreAnim.easing.bezierCurve = more.open ? Anim.emphasizedAccel : Anim.emphasizedDecel;
                                moreAnim.duration = more.open ? Anim.medium : Anim.morph; // closing reads better quick
                                more.open = !more.open;
                            }
                        }
                    }

                    RowLayout {
                        id: compactExtras
                        anchors.fill: parent
                        visible: root.compact
                        spacing: Math.round(6 * UIScale.value)
                        opacity: root.compact && more.open ? 1 : 0
                        enabled: opacity > 0.5
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Anim.medium
                            }
                        }
                        Text {
                            text: String.fromCodePoint(0xF0141) // md-chevron_left
                            color: backHover.hovered ? Colors.accent : Colors.textDim
                            font.pixelSize: Math.round(18 * UIScale.value)
                            HoverHandler {
                                id: backHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: more.open = false
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: root.svc.extras
                            delegate: Chip {
                                id: compactExtra
                                required property var modelData
                                tint: root.tint
                                selected: root.svc.view[modelData.prop] === 1
                                icon: modelData.icon
                                onClicked: root.svc.toggle(compactExtra.modelData.prop)
                            }
                        }
                    }
                }

                // Collapse wrapper with Anim's expand/collapse pair
                // (no overshoot: spatial dips below 0 on close).
                Item {
                    id: moreWrapper
                    Layout.fillWidth: true
                    visible: !root.compact
                    implicitHeight: more.open && !root.compact ? UIScale.spacingSm + extrasFlow.implicitHeight : 0
                    clip: true
                    Behavior on implicitHeight {
                        NumberAnimation {
                            id: moreAnim
                            duration: Anim.morph
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.emphasizedDecel
                        }
                    }

                    Flow {
                        id: extrasFlow
                        y: UIScale.spacingSm
                        width: moreWrapper.width
                        opacity: more.open ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Anim.medium
                            }
                        }
                        spacing: Math.round(6 * UIScale.value)
                        Repeater {
                            model: root.svc.extras
                            delegate: Chip {
                                id: extra
                                required property var modelData
                                tint: root.tint
                                selected: root.svc.view[modelData.prop] === 1
                                icon: modelData.icon
                                label: I18n.t("aircon." + modelData.key)
                                onClicked: root.svc.toggle(extra.modelData.prop)
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.svc.errorCode === "command"
            wrapMode: Text.WordWrap
            text: I18n.t("aircon.errCommand", [root.svc.errorMessage])
            color: Colors.accent
            font.pixelSize: UIScale.fontCaption
        }
    }
}
