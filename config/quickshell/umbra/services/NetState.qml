pragma Singleton
import QtQuick
import "."
import Quickshell.Networking
QtObject {
 id: root
 readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
 readonly property var active: wifi ? wifi.networks.values.find(n => n.connected) || null : null
 readonly property string label: active ? active.name : Networking.devices.values.some(d => d.connected) ? "Connected" : "Offline"
 property Binding scanner: Binding { target: root.wifi; property: "scannerEnabled"; value: (UiState.panel === "controls" || UiState.panel === "connectivity") && Networking.wifiEnabled; when: root.wifi !== null }
}
