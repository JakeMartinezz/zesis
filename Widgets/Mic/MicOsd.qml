import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Sound"
import "../../"

PanelWindow {
    id: micOSD

    WlrLayershell.layer: WlrLayer.Overlay
    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: -1
    implicitHeight: Math.round(130 * UIScale.value)
    color: "transparent"
    visible: false

    property bool _ready: false
    property bool _dragging: false
    property bool _hovered: false
    property real osdVol: MicService.vol
    property bool osdMuted: MicService.muted

    Timer {
        interval: 500
        running: true
        onTriggered: micOSD._ready = true
    }

    function _show() {
        if (!_ready || !AudioService.osdEnabled)
            return;
        if (!visible) {
            osdPill.opacity = 0;
            osdPill.scale = 0.88;
            visible = true;
        }
        osdShowAnim.restart();
        osdDismissTimer.restart();
    }

    onOsdVolChanged: _show()
    onOsdMutedChanged: _show()

    Timer {
        id: osdDismissTimer
        interval: 1500
        onTriggered: {
            if (!micOSD._hovered && !micOSD._dragging)
                osdHideAnim.start();
        }
    }

    ParallelAnimation {
        id: osdShowAnim
        NumberAnimation {
            target: osdPill
            property: "opacity"
            to: 1
            duration: Anim.fast
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: osdPill
            property: "scale"
            to: 1
            duration: Anim.medium
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    SequentialAnimation {
        id: osdHideAnim
        NumberAnimation {
            target: osdPill
            property: "opacity"
            to: 0
            duration: Anim.medium
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: micOSD.visible = false
        }
    }

    Item {
        id: osdPill
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(70 * UIScale.value)
        width: osdRect.implicitWidth
        height: osdRect.implicitHeight
        opacity: 0
        scale: 0.88
        transformOrigin: Item.Top

        HoverHandler {
            onHoveredChanged: {
                micOSD._hovered = hovered;
                if (!hovered && !micOSD._dragging)
                    osdDismissTimer.restart();
                else
                    osdDismissTimer.stop();
            }
        }

        Rectangle {
            id: osdRect
            implicitWidth: Math.round(280 * UIScale.value)
            implicitHeight: Math.round(52 * UIScale.value)
            radius: implicitHeight / 2
            color: Colors.surface
            border.color: Colors.withAlpha(Colors.outline, 0.8)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(16 * UIScale.value)
                anchors.rightMargin: Math.round(16 * UIScale.value)
                spacing: Math.round(10 * UIScale.value)

                Text {
                    text: micOSD.osdMuted || micOSD.osdVol === 0 ? "󰍭" : "󰍬"
                    font.pixelSize: Math.round(20 * UIScale.value)
                    color: micOSD.osdMuted ? Colors.muted : Colors.accent
                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                }

                Item {
                    id: osdSlider
                    Layout.fillWidth: true
                    implicitHeight: Math.round(8 * UIScale.value)

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Colors.surfaceHigh

                        Rectangle {
                            width: parent.width * Math.min(micOSD.osdVol, 1.0)
                            height: parent.height
                            radius: parent.radius
                            color: micOSD.osdMuted ? Colors.muted : Colors.accent
                            opacity: micOSD.osdMuted ? 0.45 : 1.0
                            Behavior on width {
                                NumberAnimation {
                                    duration: Anim.drag
                                    easing.type: Easing.OutQuad
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Anim.fast
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.round(44 * UIScale.value)
                        cursorShape: Qt.SizeHorCursor
                        preventStealing: true
                        function setVol(x) {
                            var a = MicService.source?.audio;
                            if (a)
                                a.volume = Math.max(0, Math.min(1.0, x / width));
                        }
                        onPressed: function (m) {
                            setVol(m.x);
                        }
                        onPositionChanged: function (m) {
                            if (pressed) {
                                setVol(m.x);
                                micOSD._dragging = true;
                                osdDismissTimer.stop();
                            }
                        }
                        onReleased: {
                            micOSD._dragging = false;
                            if (!micOSD._hovered)
                                osdDismissTimer.restart();
                        }
                    }
                }

                Text {
                    text: micOSD.osdMuted ? I18n.t("mic.muted") : (Math.round(micOSD.osdVol * 100) + "%")
                    color: micOSD.osdMuted ? Colors.muted : Colors.text
                    font.pixelSize: Math.round(13 * UIScale.value)
                    font.family: "monospace"
                    font.weight: Font.Medium
                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                }
            }
        }
    }
}
