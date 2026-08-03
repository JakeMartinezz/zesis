pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"
import "../Weather"
import "../Globe2D"
// Only the Congeries-free types (Globe3DGate, Globe3DService) are used
// statically here, the actual 3D globe loads through the Gate's
// source-string Loader, so a missing Congeries plugin degrades to the
// Gate's own fallback message, never breaks this panel.
import "../Globe3D"
import "../Diaspora"
import "../Shared"

Item {
    id: root

    // Which globe renders below: 2D shader globe (default) or the 3D
    // instanced-rod globe. Persisted, see Globe3DService.
    readonly property bool _use3D: Globe3DService.use3DGlobe

    property bool _showConsentDialog: false

    property bool _showActivenessDialog: false
    property string _activenessDialogMode: "enable" // "enable" | "cadence"
    property int _draftCadenceSecs: LocationSharingService.activenessCadenceSecs

    property bool _stressTestEnabled: false
    property int _stressTestCount: 5000
    property var _stressTestPoints: []

    readonly property var _stressCities: [
        {
            lat: 51.5074,
            lon: -0.1278,
            weight: 5,
            spread: 1.5
        }   // London
        ,
        {
            lat: 48.8566,
            lon: 2.3522,
            weight: 5,
            spread: 1.5
        }    // Paris
        ,
        {
            lat: 52.5200,
            lon: 13.4050,
            weight: 4,
            spread: 1.5
        }   // Berlin
        ,
        {
            lat: 52.3676,
            lon: 4.9041,
            weight: 3,
            spread: 1.2
        }    // Amsterdam
        ,
        {
            lat: 55.6761,
            lon: 12.5683,
            weight: 3,
            spread: 1.2
        }   // Copenhagen
        ,
        {
            lat: 59.3293,
            lon: 18.0686,
            weight: 3,
            spread: 1.2
        }   // Stockholm
        ,
        {
            lat: 40.4168,
            lon: -3.7038,
            weight: 3,
            spread: 1.5
        }   // Madrid
        ,
        {
            lat: 41.9028,
            lon: 12.4964,
            weight: 3,
            spread: 1.5
        }   // Rome
        ,
        {
            lat: 52.2297,
            lon: 21.0122,
            weight: 2,
            spread: 1.5
        }   // Warsaw
        ,
        {
            lat: 40.7128,
            lon: -74.0060,
            weight: 4,
            spread: 1.8
        }  // New York
        ,
        {
            lat: 37.7749,
            lon: -122.4194,
            weight: 3,
            spread: 1.8
        } // San Francisco
        ,
        {
            lat: 35.6762,
            lon: 139.6503,
            weight: 3,
            spread: 1.5
        }  // Tokyo
        ,
        {
            lat: -33.8688,
            lon: 151.2093,
            weight: 1,
            spread: 2.0
        } // Sydney
        ,
        {
            lat: -23.5505,
            lon: -46.6333,
            weight: 2,
            spread: 2.0
        } // Sao Paulo
        ,
        {
            lat: 19.0760,
            lon: 72.8777,
            weight: 2,
            spread: 1.8
        }   // Mumbai
        ,
        {
            lat: 6.5244,
            lon: 3.3792,
            weight: 1,
            spread: 2.0
        }      // Lagos
    ]

    function _generateStressTestPoints(count) {
        var totalWeight = 0;
        for (var c = 0; c < _stressCities.length; c++)
            totalWeight += _stressCities[c].weight;

        var pts = [];
        for (var n = 0; n < count; n++) {
            var r = Math.random() * totalWeight;
            var city = _stressCities[0];
            for (var c2 = 0; c2 < _stressCities.length; c2++) {
                r -= _stressCities[c2].weight;
                if (r <= 0) {
                    city = _stressCities[c2];
                    break;
                }
            }
            var jitterLat = ((Math.random() + Math.random() + Math.random()) / 3 - 0.5) * 2 * city.spread;
            var jitterLon = ((Math.random() + Math.random() + Math.random()) / 3 - 0.5) * 2 * city.spread;
            var lat = Math.max(-89, Math.min(89, city.lat + jitterLat));
            var lon = city.lon + jitterLon;
            if (lon > 180)
                lon -= 360;
            if (lon < -180)
                lon += 360;
            pts.push({
                lat: lat,
                lon: lon,
                active: Math.random() < 0.3
            });
        }
        return pts;
    }

    function _regenerateStressTest() {
        root._stressTestPoints = root._generateStressTestPoints(root._stressTestCount);
    }

    readonly property var _generalQuips: ["Somewhere in a 3km circle. Could be a house, could be a park bench, could be lying about the whole thing.", "This dot has committed to nothing more specific than \"roughly here.\"", "One pixel of trust, packed into a PNG.", "Rendered with more care than accuracy.", "Blurred on purpose. The precision you're not getting is a feature.", "Wiped clean once a week, no questions asked, like nothing ever happened."]
    readonly property var _activeQuips: ["Checked in recently. Suspiciously online.", "Flagged as active - the system's way of saying \"yes, still alive, no further comment.\"", "Active. As in: awake, at a computer, at this exact moment, probably avoiding something."]
    readonly property var _inactiveQuips: ["No activeness data on this one. Could be offline. Could be a ghost. Could just have better boundaries than you.", "Keeps its comings and goings to itself. Respectable.", "Didn't opt into the surveillance upgrade. Smart."]

    function _hashPoint(lat, lon) {
        var h = Math.abs(Math.round(lat * 100) * 374761393 + Math.round(lon * 100) * 668265263);
        return h;
    }

    readonly property string _hoveredQuip: {
        var pt = globeLoader.item ? globeLoader.item.hoveredPoint : null;
        if (!pt)
            return "";
        var pool = pt.active ? root._activeQuips : root._inactiveQuips;
        var h = root._hashPoint(pt.lat, pt.lon);

        if (h % 3 === 0)
            return root._generalQuips[h % root._generalQuips.length];
        return pool[h % pool.length];
    }

    component ConsentDialog: Rectangle {
        id: dlg
        anchors.fill: parent
        radius: Math.round(16 * UIScale.value)
        color: Colors.withAlpha(Colors.bg, 0.96)
        z: 100

        visible: opacity > 0.001
        opacity: dlg._shown ? 1 : 0
        scale: dlg._shown ? 1 : 0.96
        transformOrigin: Item.Center

        property bool _shown: false
        property string titleText: ""
        property string bodyText: ""
        signal accepted
        signal cancelled

        Behavior on opacity {
            NumberAnimation {
                duration: dlg._shown ? Anim.medium : Anim.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: dlg._shown ? Anim.emphasizedDecel : Anim.emphasizedAccel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: dlg._shown ? Anim.medium : Anim.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: dlg._shown ? Anim.emphasizedDecel : Anim.emphasizedAccel
            }
        }

        MouseArea {
            // swallow clicks so they don't reach the globe/toggles underneath
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(dlg.width - UIScale.spacingLg * 2, Math.round(420 * UIScale.value))
            spacing: UIScale.spacingMd

            Text {
                Layout.fillWidth: true
                text: dlg.titleText
                color: Colors.text
                font.pixelSize: UIScale.fontSubhead
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: dlg.bodyText
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: UIScale.spacingSm
                spacing: UIScale.spacingSm

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: cancelText.implicitWidth + UIScale.spacingLg
                    implicitHeight: Math.round(34 * UIScale.value)

                    radius: cancelMa.pressed ? UIScale.radiusSm : UIScale.radiusMd
                    color: cancelHover.hovered ? Colors.withAlpha(Colors.text, 0.08) : "transparent"
                    border.color: Colors.withAlpha(Colors.text, 0.15)
                    border.width: 1
                    scale: cancelMa.pressed ? 0.96 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }

                    Text {
                        id: cancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.text
                        font.pixelSize: UIScale.fontBody
                    }

                    HoverHandler {
                        id: cancelHover
                    }
                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dlg.cancelled()
                    }
                }

                Rectangle {
                    implicitWidth: acceptText.implicitWidth + UIScale.spacingLg
                    implicitHeight: Math.round(34 * UIScale.value)
                    radius: acceptMa.pressed ? UIScale.radiusSm : UIScale.radiusMd
                    color: acceptHover.hovered ? Qt.lighter(Colors.accent, 1.1) : Colors.accent
                    scale: acceptMa.pressed ? 0.96 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }

                    Text {
                        id: acceptText
                        anchors.centerIn: parent
                        text: "Accept & Enable"
                        color: Colors.onAccent
                        font.pixelSize: UIScale.fontBody
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: acceptHover
                    }
                    MouseArea {
                        id: acceptMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dlg.accepted()
                    }
                }
            }
        }
    }

    // Shares ConsentDialog's overlay/enter-exit choreography but
    // isn't a warning, solving a captcha reveals nothing about the
    // person beyond "a human was here once" (see diaspora's README
    // "Captcha"), so there's no accept/cancel consent shape here,
    // just a challenge image + an answer field.
    component CaptchaDialog: Rectangle {
        id: capDlg
        anchors.fill: parent
        radius: Math.round(16 * UIScale.value)
        color: Colors.withAlpha(Colors.bg, 0.96)
        z: 100

        visible: opacity > 0.001
        opacity: capDlg._shown ? 1 : 0
        scale: capDlg._shown ? 1 : 0.96
        transformOrigin: Item.Center

        readonly property bool _shown: LocationSharingService.captchaImagePath !== ""

        Behavior on opacity {
            NumberAnimation {
                duration: capDlg._shown ? Anim.medium : Anim.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: capDlg._shown ? Anim.emphasizedDecel : Anim.emphasizedAccel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: capDlg._shown ? Anim.medium : Anim.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: capDlg._shown ? Anim.emphasizedDecel : Anim.emphasizedAccel
            }
        }

        function _errorText() {
            switch (LocationSharingService.captchaError) {
            case "incorrect_answer":
                return LocationSharingService.captchaAttemptsRemaining >= 0 ? "Wrong answer - " + LocationSharingService.captchaAttemptsRemaining + " attempt(s) left." : "Wrong answer.";
            case "no_active_challenge":
                return "That challenge expired.";
            case "too_soon":
                return "Requested too recently - wait a moment and try again.";
            case "unknown_token":
                return "Your identity isn't registered yet - share your location first.";
            case "request_failed":
                return "Something went wrong - check your connection and try again.";
            default:
                return "";
            }
        }

        function _submit() {
            if (answerField.text.length === 0)
                return;
            LocationSharingService.solveCaptcha(answerField.text);
            answerField.text = "";
        }

        MouseArea {
            // swallow clicks so they don't reach the globe/toggles underneath
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(capDlg.width - UIScale.spacingLg * 2, Math.round(960 * UIScale.value))
            spacing: UIScale.spacingMd

            Text {
                Layout.fillWidth: true
                text: "Verify you're human"
                color: Colors.text
                font.pixelSize: UIScale.fontSubhead
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Type the characters shown below. Solving this once marks your dot as verified, so other people's clients can filter scripted noise out of what they render - it reveals nothing else about you, and never expires unless you remove your location entirely."
                color: Colors.textDim
                font.pixelSize: UIScale.fontSmall
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(880 * UIScale.value)
                Layout.preferredHeight: Math.round(320 * UIScale.value)
                source: LocationSharingService.captchaImagePath
                cache: false
                smooth: false
                fillMode: Image.PreserveAspectFit
            }

            Text {
                Layout.fillWidth: true
                visible: LocationSharingService.captchaError !== ""
                text: capDlg._errorText()
                color: Colors.accent
                font.pixelSize: UIScale.fontCaption
                wrapMode: Text.WordWrap
            }

            StyledTextInput {
                id: answerField
                placeholder: "Type what you see"
                onAccepted: capDlg._submit()
            }

            Text {
                text: "Request a new challenge"
                color: Colors.accent
                font.pixelSize: UIScale.fontCaption

                TapHandler {
                    enabled: !LocationSharingService.captchaBusy
                    onTapped: LocationSharingService.requestCaptcha()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: UIScale.spacingSm
                spacing: UIScale.spacingSm

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: capCancelText.implicitWidth + UIScale.spacingLg
                    implicitHeight: Math.round(34 * UIScale.value)
                    radius: capCancelMa.pressed ? UIScale.radiusSm : UIScale.radiusMd
                    color: capCancelHover.hovered ? Colors.withAlpha(Colors.text, 0.08) : "transparent"
                    border.color: Colors.withAlpha(Colors.text, 0.15)
                    border.width: 1
                    scale: capCancelMa.pressed ? 0.96 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }

                    Text {
                        id: capCancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.text
                        font.pixelSize: UIScale.fontBody
                    }

                    HoverHandler {
                        id: capCancelHover
                    }
                    MouseArea {
                        id: capCancelMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LocationSharingService.dismissCaptcha()
                    }
                }

                Rectangle {
                    implicitWidth: capSubmitText.implicitWidth + UIScale.spacingLg
                    implicitHeight: Math.round(34 * UIScale.value)
                    radius: capSubmitMa.pressed ? UIScale.radiusSm : UIScale.radiusMd
                    enabled: !LocationSharingService.captchaBusy
                    opacity: enabled ? 1.0 : 0.5
                    color: capSubmitHover.hovered ? Qt.lighter(Colors.accent, 1.1) : Colors.accent
                    scale: capSubmitMa.pressed ? 0.96 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: Anim.micro
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }

                    Text {
                        id: capSubmitText
                        anchors.centerIn: parent
                        text: LocationSharingService.captchaBusy ? "Checking..." : "Submit"
                        color: Colors.onAccent
                        font.pixelSize: UIScale.fontBody
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: capSubmitHover
                    }
                    MouseArea {
                        id: capSubmitMa
                        anchors.fill: parent
                        enabled: !LocationSharingService.captchaBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capDlg._submit()
                    }
                }
            }
        }
    }

    readonly property var _visiblePoints: {
        var pts = [];
        // Stress-test data, just for performance
        var locs = root._stressTestEnabled ? root._stressTestPoints : LocationSharingService.locations;
        for (var i = 0; i < locs.length; i++) {
            // active-only is a spam filter, a fake registration has no
            // reason to also maintain the ongoing check-ins the
            // activeness tier requires (see that toggle's own comment).
            if (LocationSharingService.showActiveOnly && locs[i].active !== true)
                continue;
            // verified-only is a stronger, deliberate filter, unlike active,
            // verified requires a human to have solved a captcha once
            // (see diaspora's README "Captcha").
            if (LocationSharingService.showVerifiedOnly && locs[i].verified !== true)
                continue;
            pts.push({
                lat: locs[i].lat,
                lon: locs[i].lon,
                active: locs[i].active === true,
                verified: locs[i].verified === true
            });
        }
        return pts;
    }

    // Loader-gated so choosing 3D means the 2D globe is never instantiated
    // at all. Combined with Globe3DService's blockLoading (sync config read),
    // a cold start in 3D mode never flashes the 2D globe first.
    Loader {
        id: globeLoader
        anchors.fill: parent
        active: !root._use3D

        sourceComponent: Globe2D {
            points: root._visiblePoints
            // Default to Europe, because Europe rocks
            initialLat: (LocationSharingService.optedIn && WeatherService.locationName !== "") ? WeatherService.latitude : 50.0
            initialLon: (LocationSharingService.optedIn && WeatherService.locationName !== "") ? WeatherService.longitude : 10.0
        }
    }

    // The 3D globe view, sharing the exact same _visiblePoints (real
    // locations, filters, stress test) as the 2D globe above. Gated on
    // panelActive, not just visible: the unused engine would otherwise
    // keep its FrameAnimation running forever.
    Globe3DGate {
        anchors.fill: parent
        visible: root._use3D
        panelActive: root._use3D
        panelSource: "Globe3DPanel.qml"
        panelPoints: root._visiblePoints
    }

    // Hover tooltip (2D globe only, the 3D view has no hover hit-testing)
    Rectangle {
        id: hoverTooltip
        // Quips are still in development, disabled for now
        visible: false
        radius: UIScale.radiusSm
        color: Colors.withAlpha(Colors.bg, 0.94)
        border.color: Colors.outline
        border.width: 1
        z: 60

        width: tooltipText.implicitWidth + UIScale.spacingMd * 2
        height: tooltipText.implicitHeight + UIScale.spacingSm * 2
        x: Math.max(8, Math.min((globeLoader.item?.hoverX ?? 0) + 16, root.width - width - 8))
        y: Math.max(8, (globeLoader.item?.hoverY ?? 0) - height - 16)

        Text {
            id: tooltipText
            anchors.centerIn: parent
            width: Math.round(200 * UIScale.value)
            text: root._hoveredQuip
            color: Colors.text
            font.pixelSize: UIScale.fontSmall
            font.italic: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Base opt-in row, turning ON requires accepting the warning dialog
    // below, turning OFF is immediate. Default is always false
    // (see LocationSharingService), we never assume consent!
    Rectangle {
        id: settingsCard
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: UIScale.spacingMd
        width: Math.round(260 * UIScale.value)
        height: settingsColumn.implicitHeight + UIScale.spacingMd * 2
        radius: UIScale.radiusMd
        color: Colors.withAlpha(Colors.bg, 0.8)
        border.color: Colors.outline
        border.width: 1
        clip: true

        ColumnLayout {
            id: settingsColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: UIScale.spacingMd
            spacing: UIScale.spacingSm

            RowLayout {
                id: collapseHeader
                Layout.fillWidth: true
                spacing: UIScale.spacingSm

                Text {
                    Layout.fillWidth: true
                    text: "Location sharing"
                    color: Colors.text
                    font.pixelSize: UIScale.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    text: LocationSharingService.settingsCollapsed ? "C" : "O"
                    font.family: "Material Icons"
                    font.pixelSize: Math.round(18 * UIScale.value)
                    color: collapseHover.hovered ? Colors.accent : Colors.textDim
                    scale: collapseHover.hovered ? 1.1 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }

                    HoverHandler {
                        id: collapseHover
                    }
                    TapHandler {
                        onTapped: LocationSharingService.setSettingsCollapsed(!LocationSharingService.settingsCollapsed)
                    }
                }
            }

            Item {
                id: collapseWrapper
                Layout.fillWidth: true
                implicitHeight: LocationSharingService.settingsCollapsed ? 0 : contentColumn.implicitHeight
                clip: true
                // Fully collapsed (implicitHeight settled at 0) also drops out
                // of the ColumnLayout's visible-child set, otherwise it still
                // reserves one spacing gap below the header even at height 0,
                // leaving the collapsed card visibly off-center/too tall.
                visible: implicitHeight > 0.5

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Anim.morph
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Anim.spatial
                    }
                }

                ColumnLayout {
                    id: contentColumn
                    width: collapseWrapper.width
                    opacity: LocationSharingService.settingsCollapsed ? 0 : 1
                    spacing: UIScale.spacingSm

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: LocationSharingService.settingsCollapsed ? Anim.emphasizedAccel : Anim.emphasizedDecel
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: LocationSharingService.optedIn ? "Sharing my approximate location" : "Share my approximate location"
                            color: Colors.text
                            font.pixelSize: UIScale.fontBody
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: LocationSharingService.optedIn
                            onToggled: {
                                if (LocationSharingService.optedIn)
                                    LocationSharingService.setOptedIn(false);
                                else
                                    root._showConsentDialog = true;
                            }
                        }
                    }

                    // Second, strictly-additional tier, only meaningful once the base
                    // toggle above is already on.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: LocationSharingService.optedIn
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: "Also share when I'm active"
                            color: Colors.text
                            font.pixelSize: UIScale.fontBody
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: LocationSharingService.activenessOptedIn
                            onToggled: {
                                if (LocationSharingService.activenessOptedIn) {
                                    LocationSharingService.setActivenessOptedIn(false);
                                } else {
                                    root._activenessDialogMode = "enable";
                                    root._showActivenessDialog = true;
                                }
                            }
                        }
                    }

                    // Picking a less frequent cadence (a larger secs value)
                    // reduces how much timing precision about you gets
                    // exposed, so it commits immediately, same as disabling
                    // the tier outright above. Only picking a MORE frequent
                    // cadence than what's already active re-opens the
                    // warning dialog, since that's the direction that
                    // increases exposure.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: LocationSharingService.activenessOptedIn
                        spacing: UIScale.spacingSm

                        Text {
                            text: "How often"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                        }

                        StyledComboBox {
                            Layout.fillWidth: true
                            model: LocationSharingService.activenessCadenceOptions.map(o => ({
                                        value: o.secs,
                                        label: o.label
                                    }))
                            selectedValue: root._draftCadenceSecs
                            onChosen: value => {
                                root._draftCadenceSecs = value;
                                if (value >= LocationSharingService.activenessCadenceSecs) {
                                    LocationSharingService.setActivenessCadence(value);
                                } else {
                                    root._activenessDialogMode = "cadence";
                                    root._showActivenessDialog = true;
                                }
                            }
                        }
                    }

                    // Verification is a one-time captcha, not a privacy tier,
                    // unlike activeness above, solving one reveals nothing
                    // beyond "a human was here once" (see diaspora's README
                    // "Captcha"), so there's no warning dialog to gate it
                    // behind, just a direct request/solve flow.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: LocationSharingService.optedIn
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: LocationSharingService.verified ? "Verified" : "Not verified"
                            color: LocationSharingService.verified ? Colors.text : Colors.textDim
                            font.pixelSize: UIScale.fontBody
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: !LocationSharingService.verified
                            text: LocationSharingService.captchaBusy ? "Checking..." : "Verify"
                            color: LocationSharingService.captchaBusy ? Colors.textDim : Colors.accent
                            font.pixelSize: UIScale.fontSmall

                            TapHandler {
                                enabled: !LocationSharingService.captchaBusy
                                onTapped: LocationSharingService.requestCaptcha()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: UIScale.spacingSm
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: "Show only active dots"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: LocationSharingService.showActiveOnly
                            onToggled: LocationSharingService.setShowActiveOnly(!LocationSharingService.showActiveOnly)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: "Show only verified dots"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: LocationSharingService.showVerifiedOnly
                            onToggled: LocationSharingService.setShowVerifiedOnly(!LocationSharingService.showVerifiedOnly)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: "Show globe on dashboard"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: LocationSharingService.showBackgroundGlobe
                            onToggled: LocationSharingService.setShowBackgroundGlobe(!LocationSharingService.showBackgroundGlobe)
                        }
                    }

                    // View preference, not a privacy tier: same shared
                    // location data either way, only the renderer
                    // changes. Needs the optional Congeries plugin, a
                    // missing plugin shows the Gate's fallback message.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: "3D globe"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: Globe3DService.use3DGlobe
                            onToggled: Globe3DService.writeUse3DGlobe(!Globe3DService.use3DGlobe)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: UIScale.spacingSm
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: "Stress test (fake data)"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                            elide: Text.ElideRight
                        }

                        ToggleSwitch {
                            checked: root._stressTestEnabled
                            onToggled: {
                                root._stressTestEnabled = !root._stressTestEnabled;
                                if (root._stressTestEnabled && root._stressTestPoints.length === 0)
                                    root._regenerateStressTest();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root._stressTestEnabled
                        spacing: UIScale.spacingSm

                        Text {
                            Layout.fillWidth: true
                            text: root._stressTestPoints.length + " fake points"
                            color: Colors.textDim
                            font.pixelSize: UIScale.fontSmall
                        }

                        Text {
                            text: "Regenerate"
                            color: Colors.accent
                            font.pixelSize: UIScale.fontSmall

                            TapHandler {
                                onTapped: root._regenerateStressTest()
                            }
                        }
                    }
                } // contentColumn
            } // collapseWrapper
        } // settingsColumn
    } // settingsCard

    StatsPanel {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: UIScale.spacingMd
    }

    StatsTrendPanel {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: UIScale.spacingMd
    }

    ConsentDialog {
        _shown: root._showConsentDialog
        titleText: "Share your approximate location?"
        bodyText: "Turning this on sends a check-in to the zesis network whenever the bar starts, and roughly once a day after that for as long as it's enabled.\n\nThe server resolves your location from your IP address (not GPS), then blurs it to a random point within about 10km - the same blurred point every time, not a new one on each check-in.\n\nThat blurred point becomes visible to anyone who queries the shared location list. That's what lets other people's globes show roughly where you are.\n\nEveryone's entry is cleared together once a week, all at the same moment - not individually timed to when you were actually using it. Turning this off removes your dot immediately, turning it back on later puts you right back at the same point.\n\nThis isn't fully anonymous: the server sees and stores your real IP address alongside your identity token, even though only the blurred location is ever shown to anyone else."
        onAccepted: {
            LocationSharingService.setOptedIn(true);
            root._showConsentDialog = false;
        }
        onCancelled: root._showConsentDialog = false
    }

    ConsentDialog {
        _shown: root._showActivenessDialog
        titleText: "Share when you're active?"
        bodyText: "Unlike your location, this reveals timing: how recently you were last seen, at whatever cadence you pick below.\n\nThe server only ever exposes a coarse yes/no \"active\" flag on your dot - never a precise timestamp - but the cadence you choose is how coarse that flag is. 5 minutes means people can tell almost exactly when you're online: 2 hours means your activity blurs across most of a work session.\n\nOnly fixed cadence options are offered on purpose: a unique, custom interval would itself be a fingerprint that could help identify your dot across time, even with the location jitter intact.\n\nThis applies on top of location sharing, not instead of it - turning off location sharing turns this off too. Turning this off by itself is immediate, no confirmation needed."
        onAccepted: {
            if (root._activenessDialogMode === "enable")
                LocationSharingService.setActivenessOptedIn(true);
            else
                LocationSharingService.setActivenessCadence(root._draftCadenceSecs);
            root._showActivenessDialog = false;
        }
        onCancelled: {
            root._draftCadenceSecs = LocationSharingService.activenessCadenceSecs;
            root._showActivenessDialog = false;
        }
    }

    CaptchaDialog {}
}
