pragma Singleton
import QtQuick
import "."
import Quickshell.Io
QtObject {
 id: root
 property real value: 0
 function refresh() { if (!reader.running) reader.running = true }
 function setValue(level) { writer.command = ["brightnessctl", "-d", "intel_backlight", "set", Math.max(1,Math.round(level*100))+"%"]; writer.running = true }
 property Process reader: Process {
  command: ["brightnessctl", "-d", "intel_backlight", "-m"]
  stdout: StdioCollector { onStreamFinished: { const fields=text.trim().split(","); if(fields.length>=4) root.value=parseFloat(fields[3])/100 } }
 }
 property Process writer: Process { onExited: root.refresh() }
 Component.onCompleted: refresh()
 // Sysfs backlight files do not provide reliable inotify changes. Refresh on
 // hardware-key IPC and while controls are visible, never poll a hidden panel.
 property Timer visibleRefresh: Timer { interval: 2000; repeat: true; running: UiState.panel === "controls"; onTriggered: root.refresh() }
}
