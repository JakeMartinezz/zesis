pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared"
import "../../"

// Tapo light controls for the bar popup (full) and the desktop widget (compact), laid out like AirconCard: header + power
// switch, brightness dial, then white temperature or colour. Shows an error panel
// instead of controls when the light can't be reached with the stored login.
Item {
    id: root

    property bool compact: false

    readonly property var svc: TapoService
    readonly property color tint: svc.power ? svc.lightColor : Colors.muted
    readonly property bool _hardError: svc._blocked
    readonly property real _pad: compact ? UIScale.spacingSm : UIScale.spacingLg

    implicitWidth: Math.round((compact ? 250 : 320) * UIScale.value)
    implicitHeight: (_hardError ? errorCol.implicitHeight : controls.implicitHeight) + _pad * 2

    StatusPanel {
        id: errorCol
        visible: root._hardError
        anchors.fill: parent
        anchors.margins: root._pad
        icon: TapoService.icon
        message: ({
                no_openssl: I18n.t("common.errNoOpenssl"),
                no_curl: I18n.t("tapo.errNoCurl"),
                no_credentials: I18n.t("tapo.errNoCredentials"),
                no_keyring: I18n.t("tapo.errNoKeyring"),
                locked: I18n.t("common.errLocked"),
                env_perms: I18n.t("common.errEnvPerms", [root.svc.errorMessage]),
                no_host: I18n.t("tapo.errNoHost", [root.svc.errorMessage]),
                auth: I18n.t("tapo.errAuth")
            })[root.svc.errorCode] ?? ""
        showUnlock: root.svc.errorCode === "locked"
        onRetry: root.svc.retry()
    }

    ColumnLayout {
        id: controls
        visible: !root._hardError
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: root.compact ? UIScale.spacingSm : UIScale.spacingMd
        enabled: root.svc.hasState
        opacity: root.svc.hasState ? 1 : 0.5 // not `enabled`: the config overlay disables the whole card

        DeviceHeader {
            compact: root.compact
            title: root.svc.nickname || I18n.t("tapo.title")
            status: !root.svc.hasState ? I18n.t("tapo.offline") : !root.svc.power ? I18n.t("tapo.off") : I18n.t("tapo.on") + " · " + I18n.t(root.svc.isWhite ? "tapo.white" : "tapo.color")
            checked: root.svc.power
            accentColor: root.tint
            onToggled: root.svc.toggle()
        }

        ArcDial {
            Layout.alignment: Qt.AlignHCenter
            diameter: Math.round((root.compact ? 150 : 210) * UIScale.value)
            value: root.svc.brightness
            minValue: 1
            maxValue: 100
            step: 5
            unit: "%"
            caption: I18n.t("tapo.brightness")
            showRing: false
            accentColor: root.tint
            active: root.svc.power
            onCommitted: v => root.svc.set({ brightness: v })
        }

        Text {
            Layout.fillWidth: true
            visible: root.svc.errorCode !== "" && !root._hardError
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: root.svc.errorCode === "command" ? I18n.t("tapo.errCommand", [root.svc.errorMessage]) : I18n.t("tapo.errNetwork", [root.svc.errorMessage])
            color: Colors.accent
            font.pixelSize: UIScale.fontCaption
        }

        Divider {}

        SectionLabel {
            text: I18n.t("tapo.lightSection")
        }

        OptionRow {
            Layout.fillWidth: true
            model: [I18n.t("tapo.white"), I18n.t("tapo.color")]
            currentIndex: root.svc.isWhite ? 0 : 1
            accentColor: root.tint
            onActivated: i => root.svc.set(i === 0 ? { color_temp: root.svc.colorTemp } : { color_temp: 0, hue: root.svc.hue, saturation: root.svc.saturation })
        }

        // White: colour temperature. Commits on release; the drag only previews.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.svc.isWhite
            spacing: UIScale.spacingXs
            property int _preview: root.svc.colorTemp

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("tapo.temperature")
                    color: Colors.text
                    font.pixelSize: UIScale.fontBody
                    font.weight: Font.DemiBold
                }
                Text {
                    text: (tempSlider._drag ? tempSlider.parent._preview : root.svc.colorTemp) + " K"
                    color: Colors.textDim
                    font.pixelSize: UIScale.fontSmall
                }
            }
            SettingSlider {
                id: tempSlider
                property bool _drag: false
                Layout.fillWidth: true
                from: root.svc.minTemp
                to: root.svc.maxTemp
                step: 100
                value: root.svc.colorTemp
                muted: !root.svc.power
                onMoved: v => {
                    _drag = true;
                    parent._preview = v;
                }
                onReleased: {
                    _drag = false;
                    root.svc.set({ color_temp: parent._preview });
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("tapo.warm")
                    color: Colors.textDim
                    font.pixelSize: UIScale.fontCaption
                }
                Text {
                    text: I18n.t("tapo.cool")
                    color: Colors.textDim
                    font.pixelSize: UIScale.fontCaption
                }
            }
        }

        // Colour: hue/saturation from the shared picker (its brightness axis only
        // previews; the dial above sets brightness). Debounced while dragging.
        ColorPicker {
            id: picker
            Layout.fillWidth: true
            visible: !root.svc.isWhite
            value: root.svc.lightColor.toString()
            property var _hs: null
            onPicked: hex => {
                var c = Qt.color(hex);
                _hs = { color_temp: 0, hue: Math.round(Math.max(0, c.hsvHue) * 360), saturation: Math.max(1, Math.round(c.hsvSaturation * 100)) };
                pickCommit.restart();
            }
            Timer {
                id: pickCommit
                interval: 300
                onTriggered: root.svc.set(picker._hs)
            }
        }
    }
}
