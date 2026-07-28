pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persists Globe 3D panel state for the whole lifetime of the install (not
// just the current shell session):
// - rodFrequency: the user's chosen level of detail (rod count = 20 *
//   frequency^2, see AssemblyGlobeView/congeries::buildGeodesicFaces),
//   lets lower-end machines back off from the default 82k-rod mesh.
// - use3DGlobe: whether the Community panel shows the 3D globe instead of
//   the 2D shader globe. Defaults false (2D), the 3D globe needs the
//   optional Congeries plugin.
Singleton {
    id: root

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/globe3d.json"

    // In-memory only. It resets on a quickshell restart but survives the
    // panel being closed/reopened in between.
    property bool hasAssembledThisSession: false

    property int rodFrequency: settingsData.rodFrequency
    property bool use3DGlobe: settingsData.use3DGlobe
    property bool settingsCollapsed: settingsData.settingsCollapsed
    property bool glowEnabled: settingsData.glowEnabled
    property bool dotsFollowRodHeight: settingsData.dotsFollowRodHeight

    function _write(overrides) {
        var data = {
            rodFrequency: root.rodFrequency,
            use3DGlobe: root.use3DGlobe,
            settingsCollapsed: root.settingsCollapsed,
            glowEnabled: root.glowEnabled,
            dotsFollowRodHeight: root.dotsFollowRodHeight
        };
        for (var k in overrides)
            data[k] = overrides[k];
        writeProc.command = ["sh", "-c", "mkdir -p '" + root._configDir + "' && echo '" + JSON.stringify(data) + "' > '" + root._configPath + "'"];
        writeProc.running = true;
    }

    function writeRodFrequency(freq) {
        root._write({
            rodFrequency: freq
        });
    }

    function writeUse3DGlobe(val) {
        root._write({
            use3DGlobe: val
        });
    }

    function writeSettingsCollapsed(val) {
        root._write({
            settingsCollapsed: val
        });
    }

    function writeGlowEnabled(val) {
        root._write({
            glowEnabled: val
        });
    }

    function writeDotsFollowRodHeight(val) {
        root._write({
            dotsFollowRodHeight: val
        });
    }

    JsonAdapter {
        id: settingsData
        property int rodFrequency: 64
        property bool use3DGlobe: false
        // TOO CRAMPED. NEEDS UI UPDATEEEEE
        property bool settingsCollapsed: true
        property bool glowEnabled: true
        property bool dotsFollowRodHeight: true
    }

    FileView {
        id: settingsFile
        path: root._configPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        adapter: settingsData
        onFileChanged: reload()
    }

    Component.onCompleted: settingsFile.text()

    Process {
        id: writeProc
        running: false
    }
}
