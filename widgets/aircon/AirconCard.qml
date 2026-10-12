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

    // Selectable pill shared by the fan "auto" button and the extras.
    component Chip: Rectangle {
        id: chip
        property color tint: Colors.accent
        property bool selected: false
        property string icon: ""
        property string label: ""
        signal clicked

        implicitWidth: chipRow.implicitWidth + UIScale.spacingMd
        implicitHeight: Math.round(26 * UIScale.value)
        radius: height / 2
        color: selected ? Colors.withAlpha(tint, 0.22) : Colors.withAlpha(Colors.text, chipHover.hovered ? 0.08 : 0.05)
        border.color: selected ? Colors.withAlpha(tint, 0.5) : "transparent"
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Math.round(4 * UIScale.value)
            Text {
                visible: chip.icon.length > 0
                text: chip.icon
                color: chip.selected ? chip.tint : Colors.textDim
                font.pixelSize: UIScale.fontSmall
            }
            Text {
                visible: chip.label.length > 0
                text: chip.label
                color: chip.selected ? Colors.text : Colors.textDim
                font.pixelSize: UIScale.fontSmall
            }
        }
        HoverHandler {
            id: chipHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: chip.clicked()
        }
    }

    // unlock() is async: retry only once it has finished
    property bool _awaitingUnlock: false
    Connections {
        target: KeychainService
        function onUnlockingChanged() {
            if (!KeychainService.unlocking && root._awaitingUnlock) {
                root._awaitingUnlock = false;
                root.svc.retry();
            }
        }
    }

    // ---- error panel ----
    ColumnLayout {
        id: errorCol
        visible: root._hardError
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: UIScale.spacingMd

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: AirconService.acIcon
            color: Colors.muted
            font.pixelSize: Math.round(36 * UIScale.value)
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Colors.text
            font.pixelSize: UIScale.fontBody
            text: ({
                    no_openssl: I18n.t("aircon.errNoOpenssl"),
                    no_keyring: I18n.t("aircon.errNoKeyring"),
                    no_device: I18n.t("aircon.errNoDevice"),
                    locked: I18n.t("aircon.errLocked"),
                    env_perms: I18n.t("aircon.errEnvPerms", [root.svc.errorMessage])
                })[root.svc.errorCode] ?? ""
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: UIScale.spacingSm
            ActionButton {
                visible: root.svc.errorCode === "locked"
                label: I18n.t("aircon.unlock")
                onActivated: {
                    root._awaitingUnlock = true;
                    KeychainService.unlock();
                }
            }
            ActionButton {
                label: I18n.t("aircon.retry")
                ghost: true
                onActivated: root.svc.retry()
            }
        }
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
        opacity: enabled ? 1 : 0.5

        // header: title, offline badge, power
        RowLayout {
            Layout.fillWidth: true
            spacing: UIScale.spacingSm
            Text {
                text: I18n.t("aircon.title")
                color: Colors.text
                font.pixelSize: root.compact ? UIScale.fontBody : UIScale.fontSubhead
                font.weight: Font.DemiBold
            }
            Text {
                visible: !root.svc.online
                text: I18n.t("aircon.offline")
                color: Colors.muted
                font.pixelSize: UIScale.fontCaption
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                id: powerBtn
                implicitWidth: Math.round((root.compact ? 32 : 40) * UIScale.value)
                implicitHeight: implicitWidth
                radius: width / 2
                color: root.svc.power ? root.tint : Colors.withAlpha(Colors.text, powerHover.hovered ? 0.12 : 0.06)
                Behavior on color {
                    ColorAnimation {
                        duration: Anim.slow
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0425) // md-power
                    color: root.svc.power ? Colors.bg : Colors.text
                    font.pixelSize: Math.round(parent.width * 0.5)
                }
                HoverHandler {
                    id: powerHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.svc.toggle("t_power")
                }
            }
        }

        TempDial {
            Layout.alignment: Qt.AlignHCenter
            diameter: Math.round((root.compact ? 150 : 200) * UIScale.value)
            value: root.svc.targetTemp
            roomTemp: root.svc.roomTemp
            minTemp: root.svc.minTemp
            maxTemp: root.svc.maxTemp
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

        // mode segmented control with a sliding indicator
        Item {
            id: modeRow
            Layout.fillWidth: true
            implicitHeight: Math.round((root.compact ? 34 : 44) * UIScale.value)
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
                color: Colors.withAlpha(Colors.text, 0.05)
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
                color: Colors.withAlpha(root.tint, 0.22)
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
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modeCell.modelData.icon
                                color: modeCell.index === modeRow._selected ? root.tint : Colors.textDim
                                font.pixelSize: Math.round((root.compact ? 15 : 18) * UIScale.value)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !root.compact
                                width: Math.min(implicitWidth, modeCell.width - 4)
                                elide: Text.ElideRight
                                text: I18n.t("aircon." + modeCell.modelData.key)
                                color: modeCell.index === modeRow._selected ? Colors.text : Colors.textDim
                                font.pixelSize: UIScale.fontTiny
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

        // fan: auto chip + 5 rising bars
        RowLayout {
            Layout.fillWidth: true
            spacing: UIScale.spacingSm
            Text {
                visible: !root.compact
                text: I18n.t("aircon.fanLabel")
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
            }
            Chip {
                tint: root.tint
                selected: root.svc.fan === root.svc.fanAuto
                label: I18n.t("aircon.fanAuto")
                onClicked: root.svc.set({ t_fan_speed: root.svc.fanAuto })
            }
            Item {
                Layout.fillWidth: true
            }
            Row {
                spacing: Math.round(4 * UIScale.value)
                Repeater {
                    model: root.svc.fans
                    delegate: Rectangle {
                        id: bar
                        required property var modelData
                        required property int index
                        readonly property bool lit: root.svc.fan !== root.svc.fanAuto && root.svc.fan >= modelData.value
                        anchors.bottom: parent.bottom
                        width: Math.round(8 * UIScale.value)
                        height: Math.round((8 + index * 4) * UIScale.value)
                        radius: Math.round(2 * UIScale.value)
                        color: lit ? root.tint : Colors.withAlpha(Colors.text, 0.12)
                        Behavior on color {
                            ColorAnimation {
                                duration: Anim.fast
                            }
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: root.svc.set({ t_fan_speed: bar.modelData.value })
                        }
                    }
                }
            }
        }

        // extras chips
        Flow {
            Layout.fillWidth: true
            spacing: Math.round(6 * UIScale.value)
            Repeater {
                model: root.svc.extras
                delegate: Chip {
                    id: extra
                    required property var modelData
                    tint: root.tint
                    selected: root.svc.view[modelData.prop] === 1
                    icon: modelData.icon
                    label: root.compact ? "" : I18n.t("aircon." + modelData.key)
                    onClicked: root.svc.toggle(extra.modelData.prop)
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
