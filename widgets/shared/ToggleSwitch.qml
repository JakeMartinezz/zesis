import QtQuick
import "../../"

Item {
    id: root
    property bool checked: false
    property color knobColor: Colors.bg
    // Optional: track color when on, and a glyph drawn in the knob (e.g. a power icon).
    property color accentColor: Colors.accent
    property string icon: ""
    signal toggled

    implicitWidth: Math.round(42 * UIScale.value)
    implicitHeight: Math.round(24 * UIScale.value)

    readonly property real _margin: Math.round(3 * UIScale.value)
    readonly property real _knobSize: height - 2 * _margin

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accentColor : Colors.surfaceHigh
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anim.standard
            }
        }
    }

    Rectangle {
        width: root._knobSize
        height: root._knobSize
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - root._margin : root._margin
        scale: toggleMa.pressed ? 0.85 : 1.0
        color: root.knobColor

        Text {
            anchors.centerIn: parent
            visible: root.icon.length > 0
            text: root.icon
            color: root.checked ? root.accentColor : Colors.muted
            font.pixelSize: Math.round(parent.height * 0.55)
        }
        Behavior on x {
            NumberAnimation {
                duration: Anim.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.checked ? Anim.emphasizedDecel : Anim.emphasizedAccel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Anim.micro
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anim.standard
            }
        }
    }

    MouseArea {
        id: toggleMa
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
