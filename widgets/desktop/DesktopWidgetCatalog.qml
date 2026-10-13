pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../clock"
import "../weather"
import "../sysmon"
import "../power"
import "../aircon"
import "../tapo"
import "../../"

Singleton {
    id: root

    readonly property var entries: [
        {
            key: "desktop-clock",
            label: I18n.t("desktop.desktopClockLabel"),
            description: I18n.t("desktop.desktopClockDescription"),
            component: _desktopClockComp
        },
        {
            key: "bar-clock",
            label: I18n.t("desktop.barClockLabel"),
            description: I18n.t("desktop.barClockDescription"),
            component: _barClockComp
        },
        {
            key: "weather",
            label: I18n.t("desktop.weatherLabel"),
            description: I18n.t("desktop.weatherDescription"),
            component: _weatherComp
        },
        {
            key: "sysmon",
            label: I18n.t("desktop.sysmonLabel"),
            description: I18n.t("desktop.sysmonDescription"),
            component: _sysmonComp
        },
        {
            key: "vending",
            label: I18n.t("desktop.vendingLabel"),
            description: I18n.t("desktop.vendingDescription"),
            component: _vendingComp
        },
        {
            key: "aircon",
            label: I18n.t("desktop.airconLabel"),
            description: I18n.t("desktop.airconDescription"),
            component: _airconComp
        },
        {
            key: "tapo",
            label: I18n.t("desktop.tapoLabel"),
            description: I18n.t("desktop.tapoDescription"),
            component: _tapoComp
        }
    ]

    function componentFor(key) {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].key === key)
                return entries[i].component;
        return null;
    }

    Component {
        id: _desktopClockComp
        DesktopClock {}
    }
    Component {
        id: _barClockComp
        Clock {}
    }
    Component {
        id: _weatherComp
        WeatherDisplay {}
    }

    Component {
        id: _sysmonComp
        SysMonDesktopWidget {}
    }
    Component {
        id: _vendingComp
        VendingMachine {}
    }

    Component {
        id: _airconComp
        DeviceDesktop {
            service: AirconService
            AirconCard {
                anchors.fill: parent
                compact: true
            }
        }
    }
    Component {
        id: _tapoComp
        DeviceDesktop {
            service: TapoService
            TapoCard {
                anchors.fill: parent
                compact: true
            }
        }
    }
}
