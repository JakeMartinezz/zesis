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

    Timer {
        id: writeTimer
        interval: 0
        onTriggered: UIScale.write(root._scaleVal, root._fontVal, root._spacingVal, root._radiusVal)
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
            }
        }
    }
}
