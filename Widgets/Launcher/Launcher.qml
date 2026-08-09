pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../"

// Port of AGS's Launcher.ts + PopupWindow(layout:"top", transition:"slide_down") -
// same duration (200ms) and the same favorites-row-when-empty /
// results-list-when-typing behavior. Toggled via `quickshell ipc call
// launcher toggle`, see shell.qml.
//
// Uses Easing.InOutCubic everywhere rather than AGS's actual
// cubic-bezier(0.16,1,0.3,1) - Easing.BezierSpline with that curve produced a
// visible jump right at the end of every reveal (same issue already hit and
// fixed the same way on the battery bar/MusicChip reveals elsewhere in this
// project), so plain InOutCubic wins for actually being smooth over being a
// pixel-exact curve match.
PanelWindow {
    id: root

    // Matches AGS options.launcher.margin (80pt) - gap kept above the panel.
    readonly property real _topMargin: Math.round(80 * UIScale.value)

    property bool _open: LauncherService.open

    readonly property int _maxResults: 6

    // Panel width isn't fixed - like AGS's width:0 (shrink-to-fit), it hugs
    // the favorites row's natural content width, with a floor wide enough to
    // keep result rows (icon + title + description) readable.
    readonly property real _favIconBox: Math.round(76 * UIScale.value)
    readonly property real _favRowSpacing: Math.round(10 * UIScale.value)
    readonly property real _panelPad: Math.round(14 * UIScale.value)
    readonly property real _minPanelWidth: Math.round(320 * UIScale.value)
    readonly property real _panelWidth: Math.max(root._minPanelWidth, root._favorites.length * root._favIconBox + Math.max(0, root._favorites.length - 1) * root._favRowSpacing + root._panelPad * 2)

    property string _searchText: ""

    // Prebuilt lowercase haystack per app, computed once when the app list
    // changes rather than per keystroke. The previous _matches() lowercased
    // name/genericName/comment/keywords on every app for every character
    // typed - with a few hundred apps that's thousands of throwaway string
    // allocations per keystroke, on the same thread that has to hit a
    // ~7ms frame budget at 140Hz.
    readonly property var _searchIndex: {
        var out = [];
        var vals = DesktopEntries.applications.values;
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i];
            if (e.noDisplay)
                continue;
            var hay = (e.name || "").toLowerCase();
            if (e.genericName)
                hay += " " + e.genericName.toLowerCase();
            if (e.comment)
                hay += " " + e.comment.toLowerCase();
            var kw = e.keywords;
            for (var k = 0; kw && k < kw.length; k++)
                hay += " " + kw[k].toLowerCase();
            out.push({
                entry: e,
                hay: hay
            });
        }
        out.sort((a, b) => a.entry.name.localeCompare(b.entry.name));
        return out;
    }

    readonly property var _results: {
        if (root._searchText === "")
            return [];
        var t = root._searchText.toLowerCase();
        var out = [];
        for (var i = 0; i < root._searchIndex.length && out.length < root._maxResults; i++)
            if (root._searchIndex[i].hay.includes(t))
                out.push(root._searchIndex[i].entry);
        return out;
    }

    // Persisted, user-editable (LauncherFavoritesService) - starred from a
    // search result or right-click-removed from the favorites row.
    readonly property var _favorites: {
        // heuristicLookup() is a method call, not a property read, so QML
        // can't tell this binding depends on the app list - touching
        // .values.length first (like TaskbarItem.qml does) forces a
        // re-evaluation once DesktopEntries finishes its async scan, instead
        // of permanently caching an empty result from before it loaded.
        var _ = DesktopEntries.applications.values.length;
        var out = [];
        var ids = LauncherFavoritesService.ids;
        for (var i = 0; i < ids.length; i++) {
            var e = DesktopEntries.heuristicLookup(ids[i]);
            if (e)
                out.push(e);
        }
        return out;
    }

    function _launch(entry) {
        if (!entry)
            return;
        entry.execute();
        LauncherService.close();
    }

    WlrLayershell.namespace: "zesis:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand, not Exclusive - Exclusive grabs keyboard focus compositor-wide
    // in a way that also blocked clicking into other monitors while this was
    // open, which AGS's own on-demand launcher never does. The earlier
    // "needs a click first" issue turned out to be a focus-timing problem
    // instead (see onVisibleChanged below), not the focus mode itself.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    visible: false

    // Unmap only once the slide-out has actually had time to finish (see
    // unmapTimer) - same two-stage lifecycle as FullscreenOverlay/AnimatedPopup.
    on_OpenChanged: {
        if (root._open) {
            unmapTimer.stop();
            root._searchText = "";
            searchInput.text = "";
            root.visible = true;
        } else {
            unmapTimer.restart();
        }
    }

    // Deferred one pass so the surface is actually mapped before either the
    // focus request or the slide goes out.
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => searchInput.forceActiveFocus());
    }

    // Click-outside-to-dismiss area - AGS's Padding()/EventBox has no visible
    // styling at all (no dimmer), it's purely a click catcher. TapHandler on
    // an explicitly-sized Item, matching the same proven pattern
    // FullscreenOverlay.qml uses for its own dismiss-tap backdrop.
    Item {
        anchors.fill: parent

        TapHandler {
            onTapped: LauncherService.close()
        }
    }

    // The panel is always at its natural full size - what animates is its own
    // y position, sliding down from fully off-screen (above the top edge)
    // into its resting spot. That's the actual GtkRevealer slide_down effect:
    // the whole thing translates down into place, it doesn't unroll in place.
    Item {
        id: panelHost
        anchors.horizontalCenter: parent.horizontalCenter
        width: root._panelWidth
        height: panelBg.height
        // Closed position is exactly one panel-height above the screen top,
        // matching GtkRevealer's slide_down: AGS's revealer child is
        // [80pt padding][panel], and the revealer's height animates 0 ->
        // (80pt + panelHeight), so the panel travels that distance and no
        // more - roughly 380px. An arbitrary large constant here (an earlier
        // attempt used -2000) makes the panel cover ~2080px in the same
        // 200ms, i.e. ~5x AGS's speed - which is what read as a fast,
        // juddery snap rather than a smooth slide, since at 140Hz that's
        // ~74px of movement per frame.
        y: root._open ? root._topMargin : -panelBg.height

        Behavior on y {
            NumberAnimation {
                id: slideAnim
                duration: Anim.medium
                easing.type: Easing.InOutCubic
            }
        }

        // Unmounts strictly Anim.medium after a close starts, on a plain
        // clock instead of the animation's own running state - a Behavior's
        // inner animation can restart/retarget (exactly what -height was
        // doing above) and onRunningChanged firing off of that isn't a
        // reliable "the slide is actually done" signal.
        Timer {
            id: unmapTimer
            interval: Anim.medium
            onTriggered: root.visible = false
        }

        // AGS's floating-widget shadow (box-shadow: 0 0 5px 0 rgba(0,0,0,.6)),
        // approximated with a single translucent rounded rect rather than a
        // MultiEffect blur (whose source texture would have to be regenerated
        // every frame the panel resizes). Deliberately just one, not a stack
        // of three: each is a full-panel-sized, semi-transparent, antialiased
        // rounded rect, so every extra one is another full-panel blend plus
        // another AA rounded-rect shader pass on every frame of the slide.
        Rectangle {
            anchors.fill: panelBg
            anchors.margins: -3
            radius: panelBg.radius + 3
            color: "#26000000"
        }

        Rectangle {
            id: panelBg
            readonly property real _pad: Math.round(14 * UIScale.value)

            width: parent.width
            height: launcherContent.implicitHeight + _pad * 2
            radius: Math.round(16 * UIScale.value)
            color: Colors.bg
            // AGS's popover border sits at ~95% opacity (border.opacity:96 in
            // options.ts) - much more solid than the 0.6 used elsewhere in
            // this project's popups, which is why the panel was reading as
            // washed-out/blended into the wallpaper instead of clearly defined.
            border.color: Colors.withAlpha(Colors.outline, 0.9)
            border.width: 1

            ColumnLayout {
                id: launcherContent
                x: panelBg._pad
                y: panelBg._pad
                width: parent.width - panelBg._pad * 2
                spacing: Math.round(10 * UIScale.value)

                // Built locally instead of reusing StyledTextInput - that
                // component's icon glyph is hardcoded to a "Material Icons"
                // font that isn't actually installed on this system (neither
                // is AGS's own "Ubuntu Nerd Font"), so it rendered as a
                // random fallback-font glyph instead of a magnifying glass.
                // This uses a JetBrainsMono Nerd Font glyph (nf-fa-search)
                // that's actually present.
                Rectangle {
                    id: searchBox
                    Layout.fillWidth: true
                    implicitHeight: Math.round(32 * UIScale.value)
                    radius: UIScale.radiusSm
                    color: searchInput.activeFocus ? Colors.withAlpha(Colors.accent, 0.08) : Colors.withAlpha(Colors.text, 0.04)
                    border.color: searchInput.activeFocus ? Colors.withAlpha(Colors.accent, 0.4) : Colors.withAlpha(Colors.text, 0.06)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: searchInput.forceActiveFocus()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: UIScale.spacingSm
                        anchors.rightMargin: UIScale.spacingSm
                        spacing: Math.round(7 * UIScale.value)

                        Text {
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: UIScale.fontLead
                            color: searchInput.activeFocus ? Colors.accent : Colors.muted
                            Behavior on color {
                                ColorAnimation {
                                    duration: Anim.fast
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: Math.round(20 * UIScale.value)

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: searchInput.text.length === 0
                                text: "Search"
                                color: Colors.muted
                                font.pixelSize: UIScale.fontBody
                            }

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.text
                                selectionColor: Colors.withAlpha(Colors.accent, 0.35)
                                font.pixelSize: UIScale.fontBody
                                clip: true
                                onTextChanged: root._searchText = text
                                Keys.onReturnPressed: {
                                    var pick = root._searchText !== "" ? (root._results.length > 0 ? root._results[0] : null) : (root._favorites.length > 0 ? root._favorites[0] : null);
                                    root._launch(pick);
                                }
                                Keys.onEscapePressed: LauncherService.close()
                            }
                        }
                    }
                }

                // Favorites row - shown when the search box is empty, like AGS's Favorites().
                // Right-click a favorite to unpin it (see the star on results below to pin one).
                // Stays mounted and animates its height/opacity rather than being
                // visible-toggled, which is what made switching back from a search
                // feel abrupt. Like resultsClip below, this is a single animated
                // container - the icons inside it never resize.
                RowLayout {
                    id: favRow
                    readonly property bool _shown: root._searchText === "" && root._favorites.length > 0

                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: favRow._shown ? root._favIconBox : 0
                    clip: true
                    visible: root._favorites.length > 0
                    opacity: favRow._shown ? 1 : 0
                    spacing: root._favRowSpacing

                    // enabled: root.visible - on_OpenChanged resets _searchText while
                    // the window is still unmapped, so without this gate the favorites
                    // row would animate 0 -> 76 at the same time the panel slides in.
                    // Two concurrent animations, one of which changes panelBg.height
                    // every frame (and therefore the whole panel's geometry) while the
                    // other slides it, is a needless per-frame relayout on top of the
                    // slide. Gated this way the row is already at full height before
                    // the window maps, so opening/closing animates exactly one
                    // property - like GtkRevealer does.
                    Behavior on Layout.preferredHeight {
                        enabled: root.visible
                        NumberAnimation {
                            duration: Anim.medium
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on opacity {
                        enabled: root.visible
                        NumberAnimation {
                            duration: Anim.medium
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Repeater {
                        model: root._favorites
                        delegate: Rectangle {
                            id: favBtn
                            required property var modelData

                            Layout.preferredWidth: root._favIconBox
                            Layout.preferredHeight: root._favIconBox
                            radius: UIScale.radiusMd
                            color: favArea.containsMouse ? Colors.withAlpha(Colors.text, 0.08) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Anim.fast
                                }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: Math.round(56 * UIScale.value)
                                // Without this the SVG is decoded on the GUI thread,
                                // stalling whatever frame it lands on (the result rows
                                // already load async).
                                asynchronous: true
                                source: Quickshell.iconPath(favBtn.modelData.icon, "application-x-executable")
                            }

                            MouseArea {
                                id: favArea
                                anchors.fill: parent
                                enabled: favRow._shown
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton)
                                        LauncherFavoritesService.remove(favBtn.modelData.id);
                                    else
                                        root._launch(favBtn.modelData);
                                }
                            }
                        }
                    }
                }

                // Results list - shown while typing.
                //
                // ONE animated, clipped container holding _maxResults fixed-height
                // rows that never move or resize. Only this container's height is
                // animated, so a frame costs a single layout invalidation instead of
                // one per visible row; rows past the current result count are simply
                // clipped away. The previous version animated Layout.preferredHeight
                // on every row AND gave each its own clip - attached-Layout changes
                // force a synchronous relayout that propagates all the way up
                // (row -> list -> content -> panel -> host), and per-item clipping
                // breaks Qt Scene Graph batching. Doing that 6x per frame is what
                // kept the motion from ever feeling smooth.
                Item {
                    id: resultsClip

                    readonly property real _rowH: Math.round(52 * UIScale.value)
                    readonly property real _rowSpacing: Math.round(2 * UIScale.value)
                    readonly property int _count: root._results.length

                    Layout.fillWidth: true
                    Layout.preferredHeight: resultsClip._count > 0 ? resultsClip._count * resultsClip._rowH + (resultsClip._count - 1) * resultsClip._rowSpacing : 0
                    clip: true

                    // Gated for the same reason favRow's is - see there.
                    Behavior on Layout.preferredHeight {
                        enabled: root.visible
                        NumberAnimation {
                            duration: Anim.medium
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Column {
                        width: resultsClip.width
                        spacing: resultsClip._rowSpacing

                        Repeater {
                            model: root._maxResults
                            delegate: Rectangle {
                                id: resRow
                                required property int index

                                readonly property var _entry: root._results[resRow.index] ?? null
                                readonly property bool _shown: resRow._entry !== null
                                // Keeps the last real entry around while the row is
                                // being clipped away, so its content doesn't blank out
                                // mid-animation.
                                property var _lastEntry: null
                                on_EntryChanged: if (resRow._entry)
                                    resRow._lastEntry = resRow._entry
                                readonly property var _display: resRow._entry ?? resRow._lastEntry
                                readonly property bool _isFav: resRow._display ? LauncherFavoritesService.isFavorite(resRow._display.id) : false

                                width: resultsClip.width
                                height: resultsClip._rowH
                                radius: UIScale.radiusSm
                                color: resArea.containsMouse ? Colors.withAlpha(Colors.accent, 0.1) : "transparent"
                                // Opacity is a pure GPU/scene-graph property - unlike
                                // height it never triggers a layout pass, so fading
                                // rows in/out here costs nothing per frame.
                                opacity: resRow._shown ? 1 : 0
                                Behavior on opacity {
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

                                // Launches on click - declared first/underneath so favStar (below) can
                                // still claim its own smaller area on top of this.
                                MouseArea {
                                    id: resArea
                                    anchors.fill: parent
                                    enabled: resRow._shown
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._launch(resRow._entry)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(6 * UIScale.value)
                                    anchors.rightMargin: Math.round(34 * UIScale.value)
                                    spacing: Math.round(10 * UIScale.value)

                                    IconImage {
                                        implicitSize: Math.round(34 * UIScale.value)
                                        asynchronous: true
                                        source: resRow._display ? Quickshell.iconPath(resRow._display.icon, "application-x-executable") : ""
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            text: resRow._display ? resRow._display.name : ""
                                            color: resArea.containsMouse ? Colors.accent : Colors.text
                                            font.pixelSize: UIScale.fontBody
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: resRow._display ? resRow._display.comment : ""
                                            color: Colors.textDim
                                            font.pixelSize: UIScale.fontCaption
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Favorite toggle - "the place to put apps as favorites". Sits on top
                                // of resArea above (later in the file = higher z), so a click here
                                // claims the event instead of also launching the app.
                                Rectangle {
                                    id: favStar
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: Math.round(4 * UIScale.value)
                                    width: Math.round(26 * UIScale.value)
                                    height: width
                                    radius: width / 2
                                    color: favStarArea.containsMouse ? Colors.withAlpha(Colors.text, 0.1) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: resRow._isFav ? "★" : "☆"
                                        color: resRow._isFav ? Colors.accent : Colors.textDim
                                        font.pixelSize: UIScale.fontBody
                                    }

                                    MouseArea {
                                        id: favStarArea
                                        anchors.fill: parent
                                        enabled: resRow._shown
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (resRow._entry)
                                            LauncherFavoritesService.toggle(resRow._entry.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
