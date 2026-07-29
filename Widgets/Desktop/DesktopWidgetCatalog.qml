pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Clock"
import "../Weather"
import "../SysMon"
import "../Globe2D"

Singleton {
    id: root

    readonly property var entries: [
        {
            key: "desktop-clock",
            label: "Desktop Clock",
            description: "Large typewriter date & time",
            component: _desktopClockComp
        },
        {
            key: "bar-clock",
            label: "Bar Clock",
            description: "Compact monospace clock pill",
            component: _barClockComp
        },
        {
            key: "weather",
            label: "Weather",
            description: "Current conditions display",
            component: _weatherComp
        },
        {
            key: "sysmon",
            label: "System Stats",
            description: "CPU, RAM, GPU, net & disk at a glance",
            component: _sysmonComp
        },
        {
            key: "globe2d",
            label: "Globe",
            description: "Spinning 2D shader globe with community locations",
            component: _globe2dComp
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
        id: _globe2dComp
        Globe2DDesktopWidget {}
    }
}
