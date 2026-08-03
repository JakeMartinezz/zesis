pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../"
import "../Bar"
import "../Shared"

BarButton {
    id: root

    readonly property bool blocked: GitUpdateService.status === "blocked"
    readonly property bool pulling: GitUpdateService.status === "pulling"
    readonly property bool available: GitUpdateService.showBadge
    property bool justSucceeded: false

    visible: available
    icon: "󰚰"
    active: popup.visible
    onClicked: popup.visible ? popup.close() : popup.open()

    Connections {
        target: GitUpdateService // qmllint disable incompatible-type
        function onPullSucceeded() {
            root.justSucceeded = true;
            successTimer.restart();
        }
    }

    Timer {
        id: successTimer
        interval: 1400
        onTriggered: {
            root.justSucceeded = false;
            popup.close();
        }
    }

    SequentialAnimation on opacity {
        running: root.visible && !root.active
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.45
            duration: 900
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1.0
            duration: 900
            easing.type: Easing.InOutSine
        }
    }

    AnimatedPopup {
        id: popup
        anchorItem: root
        implicitWidth: Math.round(300 * UIScale.value)
        implicitHeight: Math.round(190 * UIScale.value)
        content: Component {
            ColumnLayout {
                anchors.fill: parent
                spacing: UIScale.spacingMd

                Item {
                    implicitHeight: UIScale.spacingXs
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: UIScale.panelPad
                    Layout.rightMargin: UIScale.panelPad
                    spacing: UIScale.spacingSm

                    Text {
                        text: root.justSucceeded ? "✓" : "󰚰"
                        font.pixelSize: Math.round(20 * UIScale.value)
                        color: root.blocked ? "#e0a25c" : Colors.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.justSucceeded ? "Updated" : (root.blocked ? "Update needs help" : "Update available")
                        color: Colors.text
                        font.pixelSize: UIScale.fontLead
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: UIScale.panelPad
                    Layout.rightMargin: UIScale.panelPad
                    color: Colors.textDim
                    font.pixelSize: UIScale.fontSmall
                    wrapMode: Text.WordWrap
                    text: {
                        if (root.justSucceeded)
                            return "Zesis has been updated to the latest version.";
                        if (root.blocked)
                            return "There's a newer version of your desktop ready, but some files here have been changed by hand. It can't update itself safely, ask whoever set this up to take a look.";
                        if (GitUpdateService.status === "pullFailed")
                            return "The update didn't go through. Ask whoever set this up to take a look.";
                        return "There's a newer version of your desktop ready to install.";
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: UIScale.panelPad
                    Layout.rightMargin: UIScale.panelPad
                    spacing: UIScale.spacingSm

                    ActionButton {
                        visible: !root.blocked && !root.justSucceeded
                        label: root.pulling ? "Updating..." : (GitUpdateService.status === "pullFailed" ? "Try again" : "Update now")
                        onActivated: GitUpdateService.updateNow()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Hide"
                        color: hideMouseArea.containsMouse ? Colors.accent : Colors.muted
                        font.pixelSize: UIScale.fontCaption
                        Behavior on color {
                            ColorAnimation {
                                duration: Anim.fast
                            }
                        }

                        MouseArea {
                            id: hideMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                popup.close();
                                BarItemsService.toggle("gitupdate");
                            }
                        }
                    }
                }

                Item {
                    implicitHeight: UIScale.spacingXs
                }
            }
        }
    }
}
