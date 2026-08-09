pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../"
import "../Bar"
import "../Shared"

Item {
    id: root
    focus: true

    Component.onCompleted: scanner.running = true

    readonly property string _wallpapersDir: ThemeState.wallpaperFolder
    on_WallpapersDirChanged: scanner.running = true

    // Monitor picker - opened when a wallpaper is clicked, same as WallpaperPanel.qml
    property bool _monitorPickerOpen: false
    property string _monitorPickerPath: ""
    property point _monitorPickerPos: Qt.point(0, 0)

    component PickerRow: Rectangle {
        id: pickRow
        property string label: ""
        signal activated

        width: parent ? parent.width : 0
        implicitHeight: Math.round(32 * UIScale.value)
        radius: UIScale.radiusSm
        color: pickHover.hovered ? Colors.surfaceHigh : "transparent"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: UIScale.spacingSm
            text: pickRow.label
            color: Colors.text
            font.pixelSize: UIScale.fontSmall
        }

        HoverHandler {
            id: pickHover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pickRow.activated()
        }
    }

    ListModel {
        id: wallpapers
    }

    Process {
        id: scanner
        // -L: follow symlinks, including when the wallpaper folder itself is one
        command: ["bash", "-c", "find -L \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort > \"$2\"", "--", root._wallpapersDir, Quickshell.env("HOME") + "/.cache/zesis/wallpapers.txt"]
        stdout: StdioCollector {}
        onExited: () => listReader.reload()
    }

    FileView {
        id: listReader
        path: Quickshell.env("HOME") + "/.cache/zesis/wallpapers.txt"
        onLoaded: {
            var lines = text().split("\n");
            wallpapers.clear();
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line !== "")
                    wallpapers.append({
                        path: line
                    });
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusLg
        topLeftRadius: BarConfig.side === "top" ? 0 : UIScale.radiusLg
        topRightRadius: BarConfig.side === "top" ? 0 : UIScale.radiusLg
        bottomLeftRadius: BarConfig.side === "bottom" ? 0 : UIScale.radiusLg
        bottomRightRadius: BarConfig.side === "bottom" ? 0 : UIScale.radiusLg
        color: Colors.bg
        border.color: Colors.outline
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(16 * UIScale.value)
        spacing: Math.round(12 * UIScale.value)

        // Header row
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Themes"
                color: Colors.text
                font.pixelSize: Math.round(16 * UIScale.value)
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            // Dark / Light pill toggle
            Rectangle {
                Layout.preferredWidth: Math.round(120 * UIScale.value)
                Layout.preferredHeight: Math.round(32 * UIScale.value)
                radius: Math.round(16 * UIScale.value)
                color: Colors.surface

                Rectangle {
                    id: pillSlider
                    width: Math.round(56 * UIScale.value)
                    height: Math.round(26 * UIScale.value)
                    radius: Math.round(13 * UIScale.value)
                    anchors.verticalCenter: parent.verticalCenter
                    x: ThemeState.palette === "dark" ? Math.round(3 * UIScale.value) : Math.round(61 * UIScale.value)
                    color: Colors.accent
                    Behavior on x {
                        NumberAnimation {
                            duration: Anim.medium
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "Dark"
                        color: ThemeState.palette === "dark" ? Colors.bg : Colors.textDim
                        font.pixelSize: UIScale.fontCaption
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on color {
                            ColorAnimation {
                                duration: Anim.medium
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Light"
                        color: ThemeState.palette === "light" ? Colors.bg : Colors.textDim
                        font.pixelSize: UIScale.fontCaption
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on color {
                            ColorAnimation {
                                duration: Anim.medium
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ThemeState.togglePalette()
                }
            }
        }

        // Search bar
        StyledTextInput {
            id: searchField
            Layout.fillWidth: true
            showClearButton: true
            placeholder: "Search wallpapers..."
        }

        // Wallpaper list
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.round(4 * UIScale.value)
            clip: true
            model: wallpapers

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            WheelHandler {
                onWheel: event => {
                    listView.contentY = Math.max(listView.originY, Math.min(listView.originY + listView.contentHeight - listView.height, listView.contentY - event.angleDelta.y * 0.5));
                }
            }

            delegate: WallpaperItem {
                id: wpItem
                required property string path
                wallpaperPath: path
                width: listView.width - Math.round(8 * UIScale.value)
                visible: searchField.text === "" || path.toLowerCase().includes(searchField.text.toLowerCase())
                height: visible ? implicitHeight : 0
                onActivated: {
                    var p = wpItem.mapToItem(root, wpItem.width / 2, wpItem.height / 2);
                    root._monitorPickerPath = wpItem.wallpaperPath;
                    root._monitorPickerPos = p;
                    root._monitorPickerOpen = true;
                }
            }

            Text {
                anchors.centerIn: parent
                visible: wallpapers.count === 0 && !scanner.running
                text: "No wallpapers found in\n" + root._wallpapersDir
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 9999
        propagateComposedEvents: true
        onPressed: mouse => {
            root.forceActiveFocus();
            mouse.accepted = false;
        }
    }

    // Monitor picker - opened when a wallpaper is clicked, lets a multi-monitor
    // setup apply the wallpaper to just one screen. Same pattern as WallpaperPanel.qml.
    Item {
        id: monitorPicker
        anchors.fill: parent
        visible: root._monitorPickerOpen
        z: 10000

        MouseArea {
            anchors.fill: parent
            onClicked: root._monitorPickerOpen = false
        }

        Rectangle {
            id: pickerFrame
            x: Math.max(0, Math.min(root._monitorPickerPos.x, monitorPicker.width - width))
            y: Math.max(0, Math.min(root._monitorPickerPos.y, monitorPicker.height - height))
            width: Math.round(200 * UIScale.value)
            implicitHeight: pickerCol.implicitHeight + UIScale.spacingSm * 2
            radius: UIScale.radiusMd
            color: Colors.bg
            border.color: Colors.outline
            border.width: 1

            // Swallow clicks inside the menu so they don't reach the backdrop dismiss area
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: pickerCol
                x: UIScale.spacingSm
                y: UIScale.spacingSm
                width: parent.width - UIScale.spacingSm * 2
                spacing: 2

                Text {
                    text: "Apply to..."
                    color: Colors.muted
                    font.pixelSize: UIScale.fontTiny
                    font.weight: Font.Bold
                    leftPadding: UIScale.spacingXs
                    bottomPadding: UIScale.spacingXs
                }

                PickerRow {
                    width: pickerCol.width
                    label: "All Monitors"
                    onActivated: {
                        ThemeState.apply(root._monitorPickerPath, "");
                        root._monitorPickerOpen = false;
                    }
                }

                Repeater {
                    model: Quickshell.screens
                    delegate: PickerRow {
                        id: monRow
                        required property var modelData
                        width: pickerCol.width
                        label: monRow.modelData.name
                        onActivated: {
                            ThemeState.apply(root._monitorPickerPath, monRow.modelData.name);
                            root._monitorPickerOpen = false;
                        }
                    }
                }
            }
        }
    }
}
