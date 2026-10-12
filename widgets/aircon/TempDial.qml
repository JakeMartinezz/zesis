pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../../"

// 270° temperature arc with a thin countdown ring around it. Never writes `value`
// itself: dragging and the wheel show a local preview and emit `committed` once.
Item {
    id: root

    property int value: 24
    property int roomTemp: 0
    property int minTemp: 16
    property int maxTemp: 32
    property color accentColor: Colors.accent
    property bool active: true
    property real countdown: 0
    property real diameter: Math.round(190 * UIScale.value)

    signal committed(int value)

    readonly property real _start: 135
    readonly property real _sweep: 270
    readonly property real _stroke: Math.round(10 * UIScale.value)
    readonly property real _ringGap: Math.round(8 * UIScale.value)
    readonly property real _r: diameter / 2 - _stroke - _ringGap
    property int _preview: value
    property bool _editing: false
    // Fades in when the unit turns on.
    property color _arc: active ? accentColor : Colors.muted
    Behavior on _arc {
        ColorAnimation {
            duration: Anim.slow
        }
    }
    readonly property int _shown: _editing ? _preview : value
    readonly property real _frac: (Math.max(minTemp, Math.min(maxTemp, _shown)) - minTemp) / (maxTemp - minTemp)

    implicitWidth: diameter
    implicitHeight: diameter

    function _valueAt(x, y) {
        var deg = Math.atan2(y - height / 2, x - width / 2) * 180 / Math.PI;
        var rel = (deg - _start + 720) % 360;
        if (rel > _sweep)
            rel = rel > _sweep + (360 - _sweep) / 2 ? 0 : _sweep;
        return Math.round(minTemp + rel / _sweep * (maxTemp - minTemp));
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        // countdown ring: drains as the next refresh approaches
        ShapePath {
            strokeColor: Colors.withAlpha(root.accentColor, root.active ? 0.35 : 0.12)
            strokeWidth: Math.max(1, Math.round(2 * UIScale.value))
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.diameter / 2 - 2
                radiusY: root.diameter / 2 - 2
                startAngle: -90
                sweepAngle: 360 * (1 - root.countdown)
            }
        }

        // track
        ShapePath {
            strokeColor: Colors.surfaceHigh
            strokeWidth: root._stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._r
                radiusY: root._r
                startAngle: root._start
                sweepAngle: root._sweep
            }
        }

        // value
        ShapePath {
            strokeColor: root._arc
            strokeWidth: root._stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._r
                radiusY: root._r
                startAngle: root._start
                sweepAngle: Math.max(0.01, root._sweep * root._frac)
            }
        }
    }

    // knob
    Rectangle {
        readonly property real _a: (root._start + root._sweep * root._frac) * Math.PI / 180
        width: root._stroke * 1.8
        height: width
        radius: width / 2
        antialiasing: true
        color: Colors.bg
        border.color: root._arc
        border.width: Math.max(2, Math.round(3 * UIScale.value))
        x: root.width / 2 + root._r * Math.cos(_a) - width / 2
        y: root.height / 2 + root._r * Math.sin(_a) - height / 2
    }

    Column {
        anchors.centerIn: parent
        spacing: UIScale.spacingXs

        // Only the digits count for centering; the degree sign hangs off their right edge.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: tempText.implicitWidth
            implicitHeight: tempText.implicitHeight

            Text {
                id: tempText
                text: root._shown
                color: root.active ? Colors.text : Colors.muted
                font.pixelSize: Math.round(root.diameter * 0.24)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.left: tempText.right
                anchors.top: tempText.top
                text: "°"
                color: tempText.color
                font.pixelSize: Math.round(tempText.font.pixelSize * 0.6)
                font.weight: Font.DemiBold
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.roomTemp > 0
            text: I18n.t("aircon.room", [root.roomTemp])
            color: Colors.textDim
            font.pixelSize: UIScale.fontSmall
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            _wheelCommit.stop();
            root._preview = root._valueAt(mouse.x, mouse.y);
            root._editing = true;
        }
        onPositionChanged: mouse => {
            if (pressed)
                root._preview = root._valueAt(mouse.x, mouse.y);
        }
        onCanceled: root._editing = false
        onReleased: {
            root._editing = false;
            if (root._preview !== root.value)
                root.committed(root._preview);
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y === 0)
                return;
            var base = root._editing ? root._preview : root.value;
            root._preview = Math.max(root.minTemp, Math.min(root.maxTemp, base + (wheel.angleDelta.y > 0 ? 1 : -1)));
            root._editing = true;
            _wheelCommit.restart();
        }
    }

    Timer {
        id: _wheelCommit
        interval: 600
        onTriggered: {
            root._editing = false;
            if (root._preview !== root.value)
                root.committed(root._preview);
        }
    }
}
