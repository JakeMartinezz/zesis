pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"
import "../Settings"
import "../LockScreen"
import "../Shared"

// Collapse-capable system tray. See docs/qml-patterns.md for the reactivity pitfalls this
// structure avoids (visible-gated sizing, Layout exclusion, itemAt() pull vs push).
// See live in ResponsiveTestPanel.qml section 5 against a synthetic maxWidth.
Rectangle {
    id: root

    // -1 = unconstrained (show every enabled+available item at natural size)
    property real maxWidth: -1

    // No background/radius of its own - sits flush on the bar's continuous
    // surface, like AGS's end box. Each icon carries its own panel-button tint.
    radius: 0
    color: "transparent"
    visible: BarItemsService.anyEnabled
    implicitWidth: layout.implicitWidth + root._pad
    implicitHeight: Math.round(34 * UIScale.value)

    readonly property real _pad: Math.round(10 * UIScale.value)
    readonly property real _gap: 4
    // Matches BarButton.qml's own implicitWidth formula for the "»" chevron
    // Let's see if whoever updates the BarButton also remembers to update this shit.
    readonly property real _chevronWidth: Math.round(26 * UIScale.value)

    function _catalogIndex(id) {
        var arr = BarItemsService.orderedItems;
        for (var i = 0; i < arr.length; i++)
            if (arr[i].id === id)
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
        var catalog = BarItemsService.orderedItems;
        for (var i = 0; i < catalog.length; i++) {
            var it = catalog[i];
            if (BarItemsService.isEnabled(it.id) && root._isAvailable(it.id))
                result.push(it.id);
        }
        return result;
    }

    // _enabledIds minus ids the user manually pinned behind the overflow toggle -
    // only this subset is eligible to sit in the main row / count toward _fitCount.
    readonly property var _autoIds: root._enabledIds.filter(id => !BarItemsService.isCollapsed(id))

    // Counts trailing items kept, so the last-declared items (e.g. clock) stay closest to
    // the pill's fixed right edge and are the last thing to collapse.
    readonly property int _fitCount: {
        if (root.maxWidth < 0)
            return root._autoIds.length;
        var budget = root.maxWidth - root._pad;
        var used = 0;
        var count = 0;
        for (var i = root._autoIds.length - 1; i >= 0; i--) {
            var d = trayRepeater.itemAt(root._catalogIndex(root._autoIds[i]));
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

    // Whether there's anything currently NOT shown in the row (manually pinned
    // behind the toggle, or pushed out by the width-driven fit).
    readonly property bool _hasHidden: root._fitCount < root._autoIds.length || root._autoIds.length < root._enabledIds.length

    // Clicking the chevron doesn't open a popup - it just drops the hidden
    // icons directly into the bar row itself, growing it inline.
    property bool _expanded: false

    // Whether id sits in the row on its own merit, regardless of _expanded -
    // i.e. the stable "always shown" classification used to decide which
    // side of the chevron an item renders on (see _leftIdsOrdered/_rightIdsOrdered).
    function _fitsWithoutExpand(id) {
        if (BarItemsService.isCollapsed(id))
            return false;
        var idx = root._autoIds.indexOf(id);
        if (idx < 0)
            return false;
        return idx >= (root._autoIds.length - root._fitCount);
    }

    // Single source of truth for main-row visibility: always-fits items, plus
    // everything else once revealed inline via the chevron toggle.
    function _isVisibleInRow(id) {
        return root._fitsWithoutExpand(id) || (root._expanded && root._enabledIds.indexOf(id) >= 0);
    }

    // Catalog-order ids that sit before/after the chevron. Kept separate from
    // the (single, never-recreated) trayRepeater's model - only their
    // Layout.column changes, so revealing/hiding never destroys+recreates a
    // delegate. Hidden ids go left of the chevron and grow leftward when
    // revealed; always-fits ids go right of it and never move (see the
    // GridLayout below for why that keeps the chevron itself stationary).
    readonly property var _leftIdsOrdered: BarItemsService.orderedItems.map(it => it.id).filter(id => root._enabledIds.indexOf(id) >= 0 && !root._fitsWithoutExpand(id))
    readonly property var _rightIdsOrdered: BarItemsService.orderedItems.map(it => it.id).filter(id => root._enabledIds.indexOf(id) >= 0 && root._fitsWithoutExpand(id))

    function _columnFor(id) {
        var li = root._leftIdsOrdered.indexOf(id);
        if (li >= 0)
            return li;
        var ri = root._rightIdsOrdered.indexOf(id);
        if (ri >= 0)
            return root._leftIdsOrdered.length + 1 + ri;
        return 0;
    }

    // Drag-to-reorder logic

    // Reorder is committed only on drop, so _enabledIds/orderedItems stay
    // stable for the whole gesture.
    property var _dragItemData: null
    property real _dragItemW: 0
    property real _dragItemH: 0
    property point _dragPos: Qt.point(0, 0)
    property string _dropBeforeId: ""
    property var _dragGrab: null

    // Last visible (non-dragged) id in row order, aka. the drop at end target
    readonly property string _dropEndTargetId: {
        if (!root._dragItemData)
            return "";
        for (var i = root._enabledIds.length - 1; i >= 0; i--) {
            var id = root._enabledIds[i];
            if (id !== root._dragItemData.id && root._isVisibleInRow(id))
                return id;
        }
        return "";
    }

    // pos is in root-local coordinates. Returns the id of the first visible
    // item (row order) whose center lies past the pointer, or "" to mean
    // append at end.
    function _computeDropBefore(draggedId, pos) {
        var coord = pos.x;
        for (var i = 0; i < root._enabledIds.length; i++) {
            var id = root._enabledIds[i];
            if (id === draggedId || !root._isVisibleInRow(id))
                continue;
            var slot = trayRepeater.itemAt(root._catalogIndex(id));
            if (!slot)
                continue;
            var center = slot.mapToItem(root, slot.width / 2, slot.height / 2);
            var centerCoord = center.x;
            if (coord < centerCoord)
                return id;
        }
        return "";
    }

    function _beginDrag(slot) {
        root._dragItemData = slot.itemData;
        root._dragItemW = slot.width;
        root._dragItemH = slot.height;
        root._dragGrab = null;
        if (slot.itemRef && slot.itemRef.grabToImage)
            slot.itemRef.grabToImage(function (result) {
                root._dragGrab = result;
            });
    }

    function _endDrag() {
        if (root._dragItemData)
            BarItemsService.moveItemBefore(root._dragItemData.id, root._dropBeforeId);
        root._dragItemData = null;
        root._dragGrab = null;
        root._dropBeforeId = "";
    }

    Component {
        id: simpleButton
        BarButton {}
    }

    // The inner Loader stays active/visible unconditionally. The wrapper's own
    // visible is the hard mount/unmount gate (disabled or unavailable ids take
    // no space at all, no animation). Layout.preferredWidth is the SOFT gate -
    // it slides between 0 and the item's natural width, like AGS's
    // Revealer(transition: "slide_left") on SysTrayToggle, so overflow/collapse
    // reveals smoothly instead of popping in/out. See docs/qml-patterns.md #1.
    component TrayItemSlot: Item {
        id: slot
        required property var itemData
        property bool reorderable: false

        readonly property real itemWidth: content.item ? content.implicitWidth : 0
        readonly property real itemHeight: content.item ? content.implicitHeight : 0
        readonly property var itemRef: content.item
        readonly property bool itemAvailable: content.item ? content.item.available !== false : true
        readonly property bool _rowVisible: root._isVisibleInRow(slot.itemData.id)

        readonly property bool _isDragging: root._dragItemData !== null && root._dragItemData.id === slot.itemData.id
        readonly property bool _showDropBefore: root._dragItemData !== null && !slot._isDragging && root._dropBeforeId === slot.itemData.id
        readonly property bool _showDropAfter: root._dragItemData !== null && root._dropBeforeId === "" && root._dropEndTargetId === slot.itemData.id
        onItemAvailableChanged: {
            var m = Object.assign({}, root._availabilityMap);
            m[slot.itemData.id] = slot.itemAvailable;
            root._availabilityMap = m;
        }

        Layout.alignment: Qt.AlignCenter
        Layout.row: 0
        Layout.column: root._columnFor(slot.itemData.id)
        visible: root._enabledIds.indexOf(slot.itemData.id) >= 0
        Layout.preferredWidth: slot._rowVisible ? slot.itemWidth : 0
        Layout.preferredHeight: slot.itemHeight
        implicitWidth: Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: Anim.medium
                easing.type: Easing.InOutCubic
            }
        }

        DragHandler {
            id: dragHandler
            enabled: slot.reorderable
            target: null
            // Let the drag take over the exclusive grab from the loaded
            // widget's own MouseArea/TapHandler once translation exceeds the
            // built-in drag threshold, so a plain click/tap still reaches the
            // widget untouched.
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

            onActiveChanged: {
                if (active)
                    root._beginDrag(slot);
                else
                    root._endDrag();
            }
            onCentroidChanged: {
                if (!active)
                    return;
                var p = slot.mapToItem(root, centroid.position.x, centroid.position.y);
                root._dragPos = p;
                root._dropBeforeId = root._computeDropBefore(slot.itemData.id, p);
            }
        }

        // Drop-target markers. Just thin accent line on whichever edge the
        // dragged item would land next to.
        Rectangle {
            visible: slot._showDropBefore
            color: Colors.accent
            radius: 1
            z: 10
            width: 2
            height: parent.height
            x: -root._gap / 2 - width / 2
            y: 0
        }
        Rectangle {
            visible: slot._showDropAfter
            color: Colors.accent
            radius: 1
            z: 10
            width: 2
            height: parent.height
            x: parent.width + root._gap / 2 - width / 2
            y: 0
        }

        // Clips independently of the slot itself, so the drop-target marker
        // lines (which deliberately poke outside the slot's bounds above)
        // stay unclipped while the icon content gets cropped as its animated
        // width slides between 0 and its natural size. clip only affects
        // painting though, not hit-testing - enabled:false is what actually
        // stops a mid-collapse (invisible but still full-sized) icon from
        // swallowing clicks meant for a neighboring slot.
        Item {
            id: contentClip
            anchors.fill: parent
            clip: true
            enabled: slot._rowVisible

            Loader {
                id: content
                active: BarItemsService.isEnabled(slot.itemData.id)
                visible: active && (item == null || item.available !== false)
                opacity: slot._isDragging ? 0.3 : 1

                Component.onCompleted: {
                    if (slot.itemData.src)
                        content.source = slot.itemData.src;
                    else
                        content.sourceComponent = simpleButton;
                }

                onLoaded: {
                    if (!slot.itemData.src) {
                        content.item.icon = slot.itemData.icon ?? "";
                        if (slot.itemData.id === "settings") {
                            content.item.active = Qt.binding(() => SettingsPanelService.open);
                            content.item.clicked.connect(() => {
                                SettingsPanelService.open = !SettingsPanelService.open;
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
    }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        rowSpacing: root._gap
        columnSpacing: root._gap

        // Every child below gets an explicit Layout.column (see _columnFor),
        // so visual order is driven by that instead of declaration/repeater
        // order. That's what lets hidden items slot in on the chevron's LEFT
        // without the chevron itself (or the trailing always-fits cluster)
        // ever having to move: with the whole tray right-edge-anchored, a
        // fixed column count to the chevron's right pins its absolute
        // position regardless of how wide the revealed group on its left
        // gets. Matches AGS's SysTrayToggle placement (chevron sits before
        // the revealable icons, after the always-shown ones stay put).
        Loader {
            id: overflowChevron
            Layout.row: 0
            Layout.column: root._leftIdsOrdered.length
            Layout.alignment: Qt.AlignCenter
            // Stays mounted while expanded too, so there's always a way to
            // collapse back even once nothing is technically "hidden" anymore.
            active: root._hasHidden || root._expanded
            visible: active
            sourceComponent: BarButton {
                icon: root._expanded ? "«" : "»"
                onClicked: root._expanded = !root._expanded
            }
        }

        Repeater {
            id: trayRepeater
            model: BarItemsService.orderedItems
            delegate: TrayItemSlot {
                id: traySlot
                required property var modelData
                itemData: traySlot.modelData
                reorderable: true
            }
        }
    }

    // Floating snapshot of the dragged item, following the pointer.
    Item {
        id: dragGhost
        visible: root._dragItemData !== null
        z: 1000
        width: root._dragItemW
        height: root._dragItemH
        x: root._dragPos.x - width / 2
        y: root._dragPos.y - height / 2
        opacity: 0.85

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Colors.barBg
            border.color: Colors.accent
            border.width: 1
            visible: ghostImage.status !== Image.Ready
        }
        Image {
            id: ghostImage
            anchors.fill: parent
            source: root._dragGrab ? root._dragGrab.url : ""
            visible: status === Image.Ready
            smooth: true
        }
    }
}
