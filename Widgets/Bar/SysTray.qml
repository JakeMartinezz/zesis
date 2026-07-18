pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"
import "../Home"
import "../LockScreen"
import "../Shared"

// Collapse-capable system tray. See docs/qml-patterns.md for the reactivity pitfalls this
// structure avoids (visible-gated sizing, Layout exclusion, itemAt() pull vs push).
// See live in ResponsiveTestPanel.qml section 5 against a synthetic maxWidth.
Rectangle {
    id: root

    // -1 = unconstrained (show every enabled+available item at natural size)
    property real maxWidth: -1

    radius: 100
    color: Colors.barBg
    visible: BarItemsService.anyEnabled
    implicitWidth: BarConfig.isVertical ? Math.round(50 * UIScale.value) : (layout.implicitWidth + root._pad)
    implicitHeight: BarConfig.isVertical ? (layout.implicitHeight + root._pad) : Math.round(50 * UIScale.value)

    readonly property real _pad: Math.round(24 * UIScale.value)
    readonly property real _gap: 4
    // Matches BarButton.qml's own implicitWidth formula for the "»" chevron
    // Let's see if whoever updates the BarButton also remembers to update this shit.
    readonly property real _chevronWidth: Math.round(30 * UIScale.value)

    function _catalogIndex(id) {
        for (var i = 0; i < BarItemsService.items.length; i++)
            if (BarItemsService.items[i].id === id)
                return i;
        return -1;
    }

    // Pushed by each TrayItemSlot via onItemAvailableChanged, see docs/qml-patterns.md #1
    property var _availabilityMap: ({})

    function _isAvailable(id) {
        return root._availabilityMap[id] !== false;
    }

    readonly property var _enabledIds: {
        var result = [];
        for (var i = 0; i < BarItemsService.items.length; i++) {
            var it = BarItemsService.items[i];
            if (BarItemsService.isEnabled(it.id) && root._isAvailable(it.id))
                result.push(it.id);
        }
        return result;
    }

    // Counts trailing items kept, so the last-declared items (e.g. clock) stay closest to
    // the pill's fixed right edge and are the last thing to collapse.
    readonly property int _fitCount: {
        if (BarConfig.isVertical || root.maxWidth < 0)
            return root._enabledIds.length;
        var budget = root.maxWidth - root._pad;
        var used = 0;
        var count = 0;
        for (var i = root._enabledIds.length - 1; i >= 0; i--) {
            var d = trayRepeater.itemAt(root._catalogIndex(root._enabledIds[i]));
            var w = d ? d.itemWidth : 0;
            var next = used + (count > 0 ? root._gap : 0) + w;
            var reserve = (i > 0) ? (root._gap + root._chevronWidth) : 0;
            if (next + reserve > budget)
                break;
            used = next;
            count++;
        }
        return count;
    }

    readonly property bool _hasOverflow: root._fitCount < root._enabledIds.length

    // Overflowed items are a PREFIX of _enabledIds, since _fitCount counts trailing items
    // kept. A disabled/unavailable id isn't in _enabledIds at all, so this returns false
    // for it, structurally absent, not overflowed.
    function _isOverflowed(id) {
        var idx = root._enabledIds.indexOf(id);
        return idx >= 0 && idx < (root._enabledIds.length - root._fitCount);
    }

    // Single source of truth for main-row visibility: enabled+available AND not collapsed
    function _isVisibleInRow(id) {
        var idx = root._enabledIds.indexOf(id);
        if (idx < 0)
            return false;
        return idx >= (root._enabledIds.length - root._fitCount);
    }

    readonly property real _maxOverflowedItemWidth: {
        var max = 0;
        for (var i = 0; i < root._enabledIds.length - root._fitCount; i++) {
            var d = trayRepeater.itemAt(root._catalogIndex(root._enabledIds[i]));
            if (d && d.itemWidth > max)
                max = d.itemWidth;
        }
        return max;
    }
    readonly property real _maxOverflowedItemHeight: {
        var max = 0;
        for (var i = 0; i < root._enabledIds.length - root._fitCount; i++) {
            var d = trayRepeater.itemAt(root._catalogIndex(root._enabledIds[i]));
            if (d && d.itemHeight > max)
                max = d.itemHeight;
        }
        return max;
    }

    Component {
        id: simpleButton
        BarButton {}
    }

    // The inner Loader stays active/visible unconditionally, the wrapper's own visible
    // is the ONE place overflow/disabled/unavailable state is expressed. See
    // docs/qml-patterns.md #1.
    component TrayItemSlot: Item {
        id: slot
        required property var itemData
        // Popup usage sets this true unconditionally, the popup row itself already gates
        // visibility on overflow state, so the icon inside it should always show once the
        // row is shown. Main-row usage leaves this false, so visibility comes straight from
        // root._isVisibleInRow, the single source of truth that already accounts for
        // disabled/unavailable ids (not just overflow).
        property bool forceVisible: false

        readonly property real itemWidth: content.item ? content.implicitWidth : 0
        readonly property real itemHeight: content.item ? content.implicitHeight : 0
        readonly property var itemRef: content.item
        readonly property bool itemAvailable: content.item ? content.item.available !== false : true
        onItemAvailableChanged: {
            var m = Object.assign({}, root._availabilityMap);
            m[slot.itemData.id] = slot.itemAvailable;
            root._availabilityMap = m;
        }

        Layout.alignment: Qt.AlignCenter
        visible: slot.forceVisible || root._isVisibleInRow(slot.itemData.id)
        Layout.preferredWidth: slot.itemWidth
        Layout.preferredHeight: slot.itemHeight
        implicitWidth: Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        Loader {
            id: content
            active: BarItemsService.isEnabled(slot.itemData.id)
            visible: active && (item == null || item.available !== false)

            Component.onCompleted: {
                if (slot.itemData.src)
                    content.source = slot.itemData.src;
                else
                    content.sourceComponent = simpleButton;
            }

            onLoaded: {
                if (!slot.itemData.src) {
                    content.item.icon = slot.itemData.icon ?? "";
                    if (slot.itemData.id === "home") {
                        content.item.active = Qt.binding(() => HomePanelService.open);
                        content.item.clicked.connect(() => {
                            HomePanelService.open = !HomePanelService.open;
                        });
                    } else if (slot.itemData.id === "lock") {
                        content.item.clicked.connect(() => {
                            LockService.triggerLock();
                        });
                    }
                }
            }
        }
    }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        rowSpacing: root._gap
        columnSpacing: root._gap
        rows: BarConfig.isVertical ? -1 : 1
        columns: BarConfig.isVertical ? 1 : -1

        Loader {
            id: overflowChevron
            Layout.alignment: Qt.AlignCenter
            active: !BarConfig.isVertical && root._hasOverflow
            visible: active
            sourceComponent: BarButton {
                icon: "»"
                onClicked: overflowPopup.visible ? overflowPopup.close() : overflowPopup.open()
            }
        }

        Repeater {
            id: trayRepeater
            model: BarItemsService.items
            delegate: TrayItemSlot {
                id: traySlot
                required property var modelData
                itemData: traySlot.modelData
            }
        }
    }

    AnimatedPopup {
        id: overflowPopup
        anchorItem: overflowChevron
        implicitWidth: Math.max(Math.round(180 * UIScale.value), root._maxOverflowedItemWidth + Math.round(90 * UIScale.value) + UIScale.spacingSm * 4)
        readonly property real _rowHeight: Math.max(Math.round(30 * UIScale.value), root._maxOverflowedItemHeight)
        implicitHeight: Math.min(Math.round(320 * UIScale.value), Math.max(1, root._enabledIds.length - root._fitCount) * (_rowHeight + 2) + Math.round(16 * UIScale.value))
        content: Component {
            Flickable {
                contentWidth: width
                contentHeight: overflowCol.implicitHeight
                clip: true

                ColumnLayout {
                    id: overflowCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: BarItemsService.items
                        delegate: RowLayout {
                            id: ovRow
                            required property var modelData
                            readonly property bool overflowed: root._isOverflowed(ovRow.modelData.id)
                            Layout.fillWidth: true
                            Layout.leftMargin: UIScale.spacingSm
                            Layout.rightMargin: UIScale.spacingSm
                            visible: ovRow.overflowed
                            spacing: UIScale.spacingSm

                            TrayItemSlot {
                                itemData: ovRow.modelData
                                forceVisible: true
                            }
                            Text {
                                text: ovRow.modelData.label
                                Layout.fillWidth: true
                                color: Colors.text
                                font.pixelSize: UIScale.fontSmall
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
