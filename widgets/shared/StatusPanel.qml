import QtQuick
import QtQuick.Layouts
import "../../"

// Centered "can't show controls" panel for device cards: icon, message, Retry, and an
// Unlock button for a locked keyring. KeychainService.unlock() is async, so after an
// unlock started here `retry` fires only once the unlock has finished.
ColumnLayout {
    id: root

    property string icon: ""
    property string message: ""
    property bool showUnlock: false
    property string unlockLabel: I18n.t("common.unlockKeyring")
    property string retryLabel: I18n.t("common.retry")
    signal retry

    property bool _awaitingUnlock: false

    spacing: UIScale.spacingMd

    Connections {
        target: KeychainService
        function onUnlockingChanged() {
            if (!KeychainService.unlocking && root._awaitingUnlock) {
                root._awaitingUnlock = false;
                root.retry();
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.icon
        color: Colors.muted
        font.pixelSize: Math.round(36 * UIScale.value)
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        color: Colors.text
        font.pixelSize: UIScale.fontBody
        text: root.message
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: UIScale.spacingSm
        ActionButton {
            visible: root.showUnlock
            label: root.unlockLabel
            onActivated: {
                root._awaitingUnlock = true;
                KeychainService.unlock();
            }
        }
        ActionButton {
            label: root.retryLabel
            ghost: true
            onActivated: root.retry()
        }
    }
}
