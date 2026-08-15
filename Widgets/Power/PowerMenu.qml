pragma ComponentBehavior: Bound
import QtQuick
import "../../"
import "../LockScreen"
import "../Wm"
import "../Shared"

// Bog standard power menu, click-twice-to-confirm on the destructive ones.
Item {
    id: root
    focus: true

    signal closeRequested

    function focusMenu() {
        root.forceActiveFocus();
    }

    Keys.onEscapePressed: root.closeRequested()

    ArmedConfirm {
        id: confirmState
    }

    readonly property var _actions: [
        {
            key: "lock",
            icon: "󰌾",
            label: I18n.t("power.lock"),
            confirm: false
        },
        {
            key: "logout",
            icon: "󰍃",
            label: I18n.t("power.logOut"),
            confirm: false
        },
        {
            key: "reboot",
            icon: "󰜉",
            label: I18n.t("power.reboot"),
            confirm: true
        },
        {
            key: "shutdown",
            icon: "󰐥",
            label: I18n.t("power.shutDown"),
            confirm: true
        }
    ]

    function _activate(action) {
        if (action.confirm && !confirmState.confirm(action.key))
            return;
        switch (action.key) {
        case "lock":
            LockService.triggerLock();
            break;
        case "logout":
            WmService.logout();
            break;
        case "reboot":
            WmService.closeAppsThen("systemctl reboot || loginctl reboot");
            break;
        case "shutdown":
            WmService.closeAppsThen("systemctl poweroff || loginctl poweroff");
            break;
        }
        root.closeRequested();
    }

    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusXl
        color: Colors.bg
        border.color: Colors.outline
        border.width: 1
    }

    Row {
        anchors.centerIn: parent
        spacing: UIScale.spacingLg * 2

        Repeater {
            model: root._actions
            delegate: PowerButton {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                armed: confirmState.isArmed(modelData.key)
                onActivated: root._activate(modelData)
            }
        }
    }
}
