import QtQuick
import "../shared"
import "../../"

// Bar item: bulb icon, filled in the light's colour when on, outline when off.
DeviceBarItem {
    id: root

    readonly property var svc: TapoService

    service: TapoService
    available: root.svc.errorCode !== "no_openssl" && root.svc.errorCode !== "no_curl"
    card: Component {
        TapoCard {}
    }
    onSecondaryClicked: if (root.svc.hasState) root.svc.toggle()

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.svc.power ? root.svc.icon : root.svc.offIcon
        font.pixelSize: Math.round(15 * UIScale.value)
        color: root.hot ? Colors.accent : root.svc.power ? root.svc.lightColor : Colors.muted
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }
}
