pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"

Item {
    id: root

    // Simulated container width,  drag the slider to squeeze/stretch
    property real testWidth: 500
    // Local scale factor, drag to simulate Ctrl+/−
    property real testScale: 1.0

    Component.onCompleted: testWidth = width - UIScale.panelPad * 2

    // Breakpoints derived from testWidth
    readonly property int cols: testWidth > 560 ? 3 : testWidth > 340 ? 2 : 1
    readonly property bool isWide: testWidth > 420

    // Scale tokens scoped to this test, all derived from testScale
    readonly property int t_sm: Math.round(11 * testScale)
    readonly property int t_body: Math.round(13 * testScale)
    readonly property int t_head: Math.round(16 * testScale)
    readonly property real t_sp: 8 * testScale
    readonly property real t_spM: 12 * testScale
    readonly property real t_r: 7 * testScale

    // LayoutItemProxy targets defined once, out of both layouts
    // Wrapped in a zero-size invisible item so they don't render here.
    // The proxy reparents them when its layout becomes visible.
    Item {
        width: 0
        height: 0
        visible: false

        Rectangle {
            id: proxyAvatar
            implicitWidth: Math.round(56 * root.testScale)
            implicitHeight: Math.round(56 * root.testScale)
            radius: implicitWidth / 2
            color: Colors.withAlpha(Colors.accent, 0.15)
            border.color: Colors.accent
            border.width: 2
            Text {
                anchors.centerIn: parent
                text: "GS"
                font.pixelSize: root.t_head
                font.weight: Font.Bold
                color: Colors.accent
            }
        }

        Item {
            id: proxyDetails
            implicitHeight: detailCol.implicitHeight
            implicitWidth: detailCol.implicitWidth

            Column {
                id: detailCol
                width: parent.width
                spacing: root.t_sp * 0.5
                Text {
                    width: parent.width
                    text: "Zesis Shell"
                    font.pixelSize: root.t_head
                    font.weight: Font.Bold
                    color: Colors.text
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: "Responsive layout demo"
                    font.pixelSize: root.t_sm
                    color: Colors.textDim
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    implicitWidth: Math.min(modeLabel.implicitWidth + 12, parent.width)
                    implicitHeight: modeLabel.implicitHeight + 6
                    radius: 4
                    color: Colors.withAlpha(Colors.accent, 0.12)
                    clip: true
                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: root.isWide ? "wide · row" : "narrow · column"
                        font.pixelSize: root.t_sm
                        color: Colors.accent
                    }
                }
            }
        }
    }

    // Shared edge overlay component
    component EdgeOverlay: Item {
        required property real containerWidth
        anchors.fill: parent
        visible: containerWidth < parent.width - 2

        Rectangle {
            x: parent.containerWidth
            width: 1
            height: parent.height
            color: Colors.withAlpha(Colors.accent, 0.55)
        }
        Rectangle {
            x: parent.containerWidth + 1
            width: parent.width - parent.containerWidth
            height: parent.height
            color: Colors.withAlpha(Colors.bg, 0.6)
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + UIScale.spacingLg * 2
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: mainCol
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: UIScale.panelPad
                rightMargin: UIScale.panelPad
            }
            y: UIScale.spacingLg
            spacing: UIScale.spacingMd

            // Title
            Text {
                text: "Responsive Layout Test"
                color: Colors.text
                font.pixelSize: UIScale.fontHero
                font.weight: Font.Bold
            }
            Text {
                text: "Drag the sliders to simulate window resize and font zoom."
                color: Colors.textDim
                font.pixelSize: UIScale.fontBody
                Layout.bottomMargin: UIScale.spacingXs
            }

            // Controls
            Rectangle {
                Layout.fillWidth: true
                radius: UIScale.radiusMd
                color: Colors.withAlpha(Colors.surface, 0.5)
                border.color: Colors.withAlpha(Colors.outline, 0.4)
                border.width: 1
                implicitHeight: ctrlRow.implicitHeight + UIScale.spacingMd * 2

                RowLayout {
                    id: ctrlRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: UIScale.spacingMd
                    }
                    spacing: UIScale.spacingLg

                    // Scale slider
                    ColumnLayout {
                        spacing: 3
                        RowLayout {
                            spacing: UIScale.spacingSm
                            Text {
                                text: "Scale"
                                color: Colors.textDim
                                font.pixelSize: UIScale.fontSmall
                            }
                            Text {
                                text: root.testScale.toFixed(2) + "×"
                                color: Colors.accent
                                font.pixelSize: UIScale.fontSmall
                                font.weight: Font.Bold
                            }
                        }
                        Slider {
                            from: 0.5
                            to: 2.5
                            stepSize: 0.05
                            value: root.testScale
                            onMoved: root.testScale = value
                            implicitWidth: 160
                        }
                    }

                    // Width slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
                            spacing: UIScale.spacingSm
                            Text {
                                text: "Width"
                                color: Colors.textDim
                                font.pixelSize: UIScale.fontSmall
                            }
                            Text {
                                text: Math.round(root.testWidth) + " px"
                                color: Colors.accent
                                font.pixelSize: UIScale.fontSmall
                                font.weight: Font.Bold
                            }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 140
                            to: mainCol.width
                            value: root.testWidth
                            onMoved: root.testWidth = value
                        }
                    }

                    // Live status chips
                    RowLayout {
                        spacing: UIScale.spacingXs

                        Repeater {
                            model: [
                                {
                                    label: "1 col",
                                    active: root.cols === 1
                                },
                                {
                                    label: "2 col",
                                    active: root.cols === 2
                                },
                                {
                                    label: "3 col",
                                    active: root.cols === 3
                                },
                                {
                                    label: "wide",
                                    active: root.isWide
                                },
                                {
                                    label: "narrow",
                                    active: !root.isWide
                                }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: chipTxt.implicitWidth + 10
                                implicitHeight: chipTxt.implicitHeight + 6
                                radius: 4
                                color: modelData.active ? Colors.withAlpha(Colors.accent, 0.18) : Colors.withAlpha(Colors.text, 0.04)
                                border.color: modelData.active ? Colors.accent : Colors.withAlpha(Colors.outline, 0.3)
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    id: chipTxt
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: UIScale.fontTiny
                                    color: modelData.active ? Colors.accent : Colors.textDim
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "1 - Grid reflow"
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
                font.weight: Font.Bold
                font.letterSpacing: 1.3
                Layout.topMargin: UIScale.spacingXs
            }
            Text {
                text: "GridLayout columns: testWidth > 560 ? 3 : testWidth > 340 ? 2 : 1"
                color: Colors.withAlpha(Colors.textDim, 0.6)
                font.pixelSize: UIScale.fontCaption
                font.family: "monospace"
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
                Layout.bottomMargin: UIScale.spacingXs
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: cardGrid.implicitHeight

                GridLayout {
                    id: cardGrid
                    width: root.testWidth
                    columns: root.cols
                    columnSpacing: root.t_sp
                    rowSpacing: root.t_sp

                    Repeater {
                        model: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"]
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Math.round(56 * root.testScale)
                            radius: root.t_r
                            color: Colors.withAlpha(Colors.surface, 0.6)
                            border.color: Colors.withAlpha(Colors.outline, 0.4)
                            border.width: 1
                            clip: true

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - root.t_sp * 2
                                spacing: root.t_sp * 0.3
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    font.pixelSize: root.t_body
                                    font.weight: Font.DemiBold
                                    color: Colors.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "card " + (index + 1)
                                    font.pixelSize: root.t_sm
                                    color: Colors.textDim
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                EdgeOverlay {
                    containerWidth: root.testWidth
                }
            }

            Text {
                text: "2 - LayoutItemProxy"
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
                font.weight: Font.Bold
                font.letterSpacing: 1.3
                Layout.topMargin: UIScale.spacingXs
            }
            Text {
                text: "Same items, two layout hierarchies. Only one layout is visible at a time."
                color: Colors.withAlpha(Colors.textDim, 0.6)
                font.pixelSize: UIScale.fontCaption
                Layout.bottomMargin: UIScale.spacingXs
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: root.isWide ? proxyWide.implicitHeight : proxyNarrow.implicitHeight

                // Wide: avatar + details side by side
                RowLayout {
                    id: proxyWide
                    width: root.testWidth
                    visible: root.isWide
                    spacing: root.t_spM
                    LayoutItemProxy {
                        target: proxyAvatar
                    }
                    LayoutItemProxy {
                        target: proxyDetails
                        Layout.fillWidth: true
                    }
                }

                // Narrow: avatar + details stacked
                ColumnLayout {
                    id: proxyNarrow
                    width: root.testWidth
                    visible: !root.isWide
                    spacing: root.t_sp
                    LayoutItemProxy {
                        target: proxyAvatar
                    }
                    LayoutItemProxy {
                        target: proxyDetails
                        Layout.fillWidth: true
                    }
                }

                EdgeOverlay {
                    containerWidth: root.testWidth
                }
            }

            Text {
                text: "3 - Show / hide at breakpoints"
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
                font.weight: Font.Bold
                font.letterSpacing: 1.3
                Layout.topMargin: UIScale.spacingXs
            }
            Text {
                text: "Columns appear as testWidth crosses each threshold."
                color: Colors.withAlpha(Colors.textDim, 0.6)
                font.pixelSize: UIScale.fontCaption
                Layout.bottomMargin: UIScale.spacingXs
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: bpRow.implicitHeight

                RowLayout {
                    id: bpRow
                    width: root.testWidth
                    spacing: root.t_sp

                    Repeater {
                        model: [
                            {
                                label: "always",
                                threshold: 0
                            },
                            {
                                label: "> 280 px",
                                threshold: 280
                            },
                            {
                                label: "> 380 px",
                                threshold: 380
                            },
                            {
                                label: "> 500 px",
                                threshold: 500
                            }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            visible: root.testWidth > modelData.threshold
                            implicitHeight: Math.round(40 * root.testScale)
                            radius: root.t_r
                            color: modelData.threshold === 0 ? Colors.withAlpha(Colors.surface, 0.6) : Colors.withAlpha(Colors.accent, 0.08)
                            border.color: modelData.threshold === 0 ? Colors.withAlpha(Colors.outline, 0.4) : Colors.withAlpha(Colors.accent, 0.3)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: root.t_sm
                                color: modelData.threshold === 0 ? Colors.text : Colors.accent
                            }
                        }
                    }
                }

                EdgeOverlay {
                    containerWidth: root.testWidth
                }
            }

            Item {
                Layout.preferredHeight: UIScale.spacingLg
            }
        }
    }
}
