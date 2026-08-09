pragma ComponentBehavior: Bound
import QtQuick
import "../Wm"
import "../../"

// Dynamic dot-to-pill workspace indicator, styled after the AGS bar widget:
// empty workspaces are small dots, occupied ones grow, the active workspace
// stretches into an accent-filled pill. Only currently-existing workspaces
// are shown, so the row grows/shrinks as workspaces come and go.
Item {
    id: root

    readonly property real _dotSize: Math.round(9 * UIScale.value)
    readonly property real _occupiedSize: Math.round(12 * UIScale.value)
    readonly property real _pillWidth: Math.round(30 * UIScale.value)
    readonly property real _pillHeight: Math.round(16 * UIScale.value)
    readonly property real _gap: Math.round(15 * UIScale.value)
    readonly property real _hPad: Math.round(10 * UIScale.value)

    readonly property var _sortedWorkspaces: {
        var list = WmService.workspaces.filter(w => !isNaN(parseInt(w.name)));
        list.sort((a, b) => parseInt(a.name) - parseInt(b.name));
        return list;
    }

    readonly property int _activeId: {
        var active = WmService.focusedMonitor?.activeWorkspace;
        var id = active ? parseInt(active.name) : NaN;
        return isNaN(id) ? -1 : id;
    }

    function _isOccupied(id) {
        return WmService.toplevels.some(t => t.workspace && parseInt(t.workspace.name) === id);
    }

    implicitWidth: row.implicitWidth + root._hPad * 2
    implicitHeight: Math.round(26 * UIScale.value)

    // Same panel-button box as every other bar widget (AGS flatButtons:false
    // parity) - the dots themselves already carry their own fill color, this
    // is the outer "chip" behind the whole indicator.
    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusMd
        color: Colors.withAlpha(Colors.text, groupHover.hovered ? 0.14 : 0.05)
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    HoverHandler {
        id: groupHover
    }

    WheelHandler {
        onWheel: function (w) {
            var ids = root._sortedWorkspaces.map(ws => parseInt(ws.name));
            if (ids.length === 0)
                return;
            var idx = ids.indexOf(root._activeId);
            if (idx < 0)
                idx = 0;
            var next = w.angleDelta.y > 0 ? ids[(idx - 1 + ids.length) % ids.length] : ids[(idx + 1) % ids.length];
            WmService.focusWorkspace(next);
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root._gap

        Repeater {
            model: root._sortedWorkspaces

            delegate: Rectangle {
                id: pill
                required property var modelData

                readonly property int wsId: parseInt(pill.modelData.name)
                readonly property bool isActive: pill.wsId === root._activeId
                readonly property bool isOccupied: root._isOccupied(pill.wsId)

                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                width: pill.isActive ? root._pillWidth : (pill.isOccupied ? root._occupiedSize : root._dotSize)
                height: pill.isActive ? root._pillHeight : (pill.isOccupied ? root._occupiedSize : root._dotSize)
                radius: height / 2
                color: pill.isActive ? Colors.accent : Colors.withAlpha(Colors.text, pill.isOccupied ? 0.75 : 0.25)

                Behavior on width {
                    NumberAnimation {
                        duration: Anim.medium
                        easing.type: Easing.InOutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Anim.medium
                        easing.type: Easing.InOutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Anim.fast
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WmService.focusWorkspace(pill.wsId)
                }
            }
        }
    }
}
