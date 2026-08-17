pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../bar"
import "../taskbar"
import "../shared"

Item {
    id: root

    function _isMonitorEnabled(screenName) {
        return BarConfig.enabledMonitors.length === 0 || BarConfig.enabledMonitors.includes(screenName);
    }

    function _toggleMonitor(screenName) {
        const current = BarConfig.enabledMonitors.length === 0 ? Quickshell.screens.map(s => s.name) : BarConfig.enabledMonitors.slice();
        const idx = current.indexOf(screenName);
        if (idx >= 0)
            current.splice(idx, 1);
        else
            current.push(screenName);
        BarConfig.writeEnabledMonitors(current);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            breadcrumb: I18n.t("bar.breadcrumb")
            title: I18n.t("bar.title")
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: content.implicitHeight + UIScale.spacingLg * 2
            clip: true
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: content
                x: UIScale.panelPad
                y: UIScale.spacingLg
                width: parent.width - UIScale.panelPad * 2
                spacing: UIScale.spacingMd

                // Bar side
                Text {
                    text: I18n.t("bar.side")
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: UIScale.fontBody
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: UIScale.spacingSm
                    Repeater {
                        model: [{
                                value: "top",
                                label: I18n.t("bar.top")
                            }, {
                                value: "bottom",
                                label: I18n.t("bar.bottom")
                            }]
                        delegate: Rectangle {
                            id: sideBtn
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: Math.round(32 * UIScale.value)
                            radius: UIScale.radiusSm
                            color: BarConfig.side === sideBtn.modelData.value ? Colors.withAlpha(Colors.accent, 0.15) : Colors.surfaceHigh
                            border.color: BarConfig.side === sideBtn.modelData.value ? Colors.accent : "transparent"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: sideBtn.modelData.label
                                color: Colors.text
                                font.pixelSize: UIScale.fontCaption
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BarConfig.write(sideBtn.modelData.value)
                            }
                        }
                    }
                }

                Divider {
                    color: Colors.withAlpha(Colors.accent, 0.1)
                }

                // Monitors
                Text {
                    text: I18n.t("bar.monitors")
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: UIScale.fontBody
                }
                Text {
                    text: I18n.t("bar.monitorsDescription")
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Repeater {
                    model: Quickshell.screens
                    delegate: RowLayout {
                        id: monRow
                        required property var modelData
                        Layout.fillWidth: true

                        Text {
                            text: monRow.modelData.name + (monRow.modelData.model ? " (" + monRow.modelData.model + ")" : "")
                            color: Colors.text
                            font.pixelSize: UIScale.fontBody
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        ToggleSwitch {
                            checked: root._isMonitorEnabled(monRow.modelData.name)
                            onToggled: root._toggleMonitor(monRow.modelData.name)
                        }
                    }
                }

                Divider {
                    color: Colors.withAlpha(Colors.accent, 0.1)
                }

                // Edge gap
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: I18n.t("bar.edgeGap")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: BarConfig.edgeGap + "px"
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                    }
                }
                SettingSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 40
                    step: 1
                    value: BarConfig.edgeGap
                    onMoved: function (v) {
                        BarConfig.writeEdgeGap(Math.round(v));
                    }
                }

                Divider {
                    color: Colors.withAlpha(Colors.accent, 0.1)
                }

                // End gap
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: I18n.t("bar.endGap")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    Text {
                        text: BarConfig.endGap + "px"
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                    }
                }
                SettingSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 60
                    step: 1
                    value: BarConfig.endGap
                    onMoved: function (v) {
                        BarConfig.writeEndGap(Math.round(v));
                    }
                }

                Divider {
                    color: Colors.withAlpha(Colors.accent, 0.1)
                }

                // Taskbar icons
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: I18n.t("bar.monochromeIcons")
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: UIScale.fontBody
                        Layout.fillWidth: true
                    }
                    ToggleSwitch {
                        checked: TaskbarService.monochrome
                        onToggled: TaskbarService.setMonochrome(!TaskbarService.monochrome)
                    }
                }
                Text {
                    text: I18n.t("bar.monochromeDescription")
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Divider {
                    color: Colors.withAlpha(Colors.accent, 0.1)
                }

                // Bar items
                Text {
                    text: I18n.t("bar.items")
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: UIScale.fontBody
                }
                Text {
                    text: I18n.t("bar.itemsDescription")
                    color: Colors.muted
                    font.pixelSize: UIScale.fontCaption
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ""
                        Layout.fillWidth: true
                    }
                    Text {
                        text: I18n.t("bar.visible")
                        color: Colors.muted
                        font.pixelSize: UIScale.fontCaption
                        Layout.preferredWidth: Math.round(50 * UIScale.value)
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: I18n.t("bar.collapse")
                        color: Colors.muted
                        font.pixelSize: UIScale.fontCaption
                        Layout.preferredWidth: Math.round(60 * UIScale.value)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Repeater {
                    model: BarItemsService.orderedItems
                    delegate: RowLayout {
                        id: itemRow
                        required property var modelData
                        Layout.fillWidth: true

                        Text {
                            text: itemRow.modelData.label
                            color: Colors.text
                            font.pixelSize: UIScale.fontBody
                            Layout.fillWidth: true
                        }
                        ToggleSwitch {
                            Layout.preferredWidth: Math.round(50 * UIScale.value)
                            checked: BarItemsService.isEnabled(itemRow.modelData.id)
                            onToggled: BarItemsService.toggle(itemRow.modelData.id)
                        }
                        ToggleSwitch {
                            Layout.preferredWidth: Math.round(60 * UIScale.value)
                            enabled: BarItemsService.isEnabled(itemRow.modelData.id)
                            opacity: enabled ? 1.0 : 0.4
                            checked: BarItemsService.isCollapsed(itemRow.modelData.id)
                            onToggled: BarItemsService.toggleCollapsed(itemRow.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
