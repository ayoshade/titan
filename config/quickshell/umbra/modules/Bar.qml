pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
PanelWindow {
 id: bar
 required property var modelData
 screen: modelData
 anchors { top: true; left: true; right: true }
 implicitHeight: Theme.barHeight
 color: Theme.background
 WlrLayershell.namespace: "umbra-bar"
 Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
 SystemClock { id: clock; precision: SystemClock.Minutes }
 RowLayout {
  anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
  spacing: Theme.gap
  Action { text: "U /"; font.family: Theme.mono; onClicked: UiState.toggle("launcher") }
  Row {
   spacing: 3
   Repeater {
    model: Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id>0 && w.id<=10).map(w => w.id))
    Action {
     required property int index
     readonly property var workspace: Hyprland.workspaces.values.find(w => w.id===index+1) || null
     text: String(index+1).padStart(2,"0")
     selected: workspace ? workspace.active && workspace.monitor && workspace.monitor.name===bar.screen.name : false
     onClicked: Hyprland.dispatch("hl.dsp.focus({workspace="+(index+1)+"})")
    }
   }
  }
  Item { Layout.fillWidth: true }
  Action {
   text: UiState.context==="volume" ? "AUDIO  "+(Audio.muted ? "MUTED" : Math.round(Audio.volume*100)+"%") : UiState.context==="brightness" ? "DISPLAY  "+Math.round(Brightness.value*100)+"%" : UiState.context==="message" ? UiState.message : Media.player ? "♫  "+Media.title.slice(0,36) : Qt.formatDateTime(clock.date,"ddd  dd MMM  /  HH:mm")
   implicitWidth: Math.min(320,contentItem.implicitWidth+32)
   background: Rectangle { color: Theme.surface; radius: Theme.pill; border.width: 1; border.color: UiState.context!=="" ? Theme.accent : Theme.border; Behavior on border.color { ColorAnimation { duration: Theme.duration } } }
   onClicked: UiState.toggle("controls")
  }
  Item { Layout.fillWidth: true }
  ShellText { visible: !!Media.player || UiState.context!==""; text: Qt.formatDateTime(clock.date,"HH:mm"); color: Theme.muted; font.family: Theme.mono }
  Tray { bar: bar }
  Action { text: NetState.label.slice(0,18); onClicked: UiState.toggle("controls") }
  Action { text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "BT" : "bt"; onClicked: UiState.toggle("controls") }
  Action { text: Audio.muted ? "MUTE" : Math.round(Audio.volume*100)+"%"; onClicked: UiState.toggle("controls") }
  Action { text: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage*100)+"%"+(UPower.onBattery ? "" : "+") : "AC"; onClicked: UiState.toggle("controls") }
  Action { text: (UiState.dnd ? "DND " : "N ")+Notices.items.values.length; onClicked: UiState.toggle("notifications") }
  Action { text: "⏻"; onClicked: UiState.toggle("session") }
 }
}
