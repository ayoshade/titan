pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
QtObject {
 id: root
 property string panel: ""
 property var panelScreen: null
 property string context: ""
 property string message: ""
 property bool dnd: false
 function toggle(name) {
  panelScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  panel = panel === name ? "" : name
 }
 function close() { panel = "" }
 function osd(kind) { context = kind; if (kind === "brightness") Brightness.refresh(); root.timeout.restart() }
 function inform(text) { message = text; context = "message"; root.timeout.restart() }
 property Timer timeout: Timer { interval: 2500; onTriggered: { root.context = ""; root.message = "" } }
}
