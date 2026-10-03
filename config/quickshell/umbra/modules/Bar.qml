pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
PanelWindow {
 id: bar
 required property var modelData
 screen: modelData
 anchors { top: true; left: true; right: true }
 readonly property int workspaceCount: Math.max(5,...Hyprland.workspaces.values.filter(w=>w.id>0 && w.id<=10).map(w=>w.id))
 readonly property bool expanded: UiState.context!=="" || (hover.hovered && !!Media.player)
 implicitHeight: expanded ? 96 : Theme.barHeight
 exclusiveZone: Theme.barHeight
 color: "transparent"
 WlrLayershell.namespace: "umbra-bar"
 mask: Region { item: island; Region { item: launcher } Region { item: notifications } }
 SystemClock { id: clock; precision: SystemClock.Minutes }
 Rectangle {
  id: island
  anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
  width: bar.expanded ? Theme.expandedIslandWidth : Theme.islandWidth+(bar.workspaceCount-5)*12
  height: bar.expanded ? Theme.expandedIslandHeight : Theme.islandHeight
  radius: bar.expanded ? 22 : 16
  color: Theme.shell
  border.width: 1; border.color: Theme.raised
  Behavior on width { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  Behavior on height { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  HoverHandler { id: hover }
  RowLayout {
   anchors { top: parent.top; topMargin: 2; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
   height: 28; spacing: 12
   Row {
    spacing: 2
    Repeater {
     model: bar.workspaceCount
     Item {
      id: mark
      required property int index
      readonly property var workspace: Hyprland.workspaces.values.find(w=>w.id===index+1) || null
      readonly property bool active: !!workspace && workspace.active && !!workspace.monitor && workspace.monitor.name===bar.modelData.name
      width: 10; height: 26
      Rectangle {
       anchors.centerIn: parent; width: mark.active ? 7 : 5; height: mark.active ? 16 : 10; radius: 4
       color: mark.active ? Theme.accent : mark.workspace && mark.workspace.toplevels.values.length>0 ? Theme.muted : Theme.border
       Behavior on height { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
       Behavior on color { ColorAnimation { duration: Theme.duration } }
      }
      Rectangle { anchors.centerIn: parent; width: 11; height: 21; radius: 5; color: Theme.accent; opacity: mark.active ? 0.13 : 0; z: -1 }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("hl.dsp.focus({workspace="+(mark.index+1)+"})") }
      Accessible.role: Accessible.Button; Accessible.name: "Workspace "+(index+1); Accessible.onPressAction: Hyprland.dispatch("hl.dsp.focus({workspace="+(mark.index+1)+"})")
     }
    }
   }
   Item { Layout.fillWidth: true }
   Action { text: Qt.formatDateTime(clock.date,"HH:mm"); implicitWidth: 52; implicitHeight: 26; onClicked: UiState.toggle("clock") }
   Item { Layout.fillWidth: true }
   Item {
    implicitWidth: 22; implicitHeight: 26
    ShellIcon { anchors.centerIn: parent; name: NetState.active ? "wifi" : "ethernet"; size: 14; opacity: NetState.label==="Offline" ? 0.3 : 0.85 }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggle("controls") }
   }
   Item {
    implicitWidth: 26; implicitHeight: 26
    Rectangle {
     anchors.centerIn: parent; width: 22; height: 11; radius: 4; color: "transparent"; border.width: 1; border.color: Theme.muted
     Rectangle { x: 2; y: 2; height: 7; width: 18*(UPower.displayDevice.ready ? UPower.displayDevice.percentage : 1); radius: 2; color: UPower.onBattery && UPower.displayDevice.percentage<0.15 ? Theme.danger : Theme.accent }
     Rectangle { x: 22; y: 4; width: 2; height: 3; radius: 1; color: Theme.muted }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggle("controls") }
   }
  }
  RowLayout {
   anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 13 }
   visible: bar.expanded; opacity: bar.expanded ? 1 : 0
   spacing: 12
   ShellIcon { name: UiState.context==="volume" ? (Audio.muted ? "mute" : "volume") : UiState.context==="brightness" ? "sun" : UiState.context==="message" ? "bell" : "music"; size: 18 }
   ColumnLayout {
    Layout.fillWidth: true; spacing: 5
    ShellText { text: UiState.context==="volume" ? (Audio.muted ? "Muted" : "Volume  "+Math.round(Audio.volume*100)+"%") : UiState.context==="brightness" ? "Brightness  "+Math.round(Brightness.value*100)+"%" : UiState.context==="message" ? UiState.message : Media.title; Layout.fillWidth: true }
    Rectangle { visible: UiState.context==="volume" || UiState.context==="brightness"; Layout.fillWidth: true; height: 3; radius: 2; color: Theme.border; Rectangle { width: parent.width*(UiState.context==="volume" ? Audio.volume : Brightness.value); height: 3; radius: 2; color: Theme.accent } }
   }
   IconButton { visible: UiState.context==="" && !!Media.player; symbol: Media.player && Media.player.isPlaying ? "pause" : "play"; label: "Play or pause"; onClicked: Media.player.togglePlaying() }
  }
 }
 IconButton {
  id: launcher; anchors { right: island.left; rightMargin: 8; top: parent.top; topMargin: 8 }
  symbol: "apps"; label: "Applications · Super+Space"; size: 32
  background: Rectangle { radius: 16; color: launcher.hovered ? Theme.raised : Theme.shell; border.width: 1; border.color: Theme.raised }
  onClicked: UiState.toggle("launcher")
 }
 IconButton {
  id: notifications; anchors { left: island.right; leftMargin: 8; top: parent.top; topMargin: 8 }
  symbol: "controls"; label: "Control center · Super+A"; size: 32
  background: Rectangle { radius: 16; color: notifications.hovered ? Theme.raised : Theme.shell; border.width: 1; border.color: Theme.raised; Rectangle { visible: Notices.items.values.length>0; width: 4; height: 4; radius: 2; x: parent.width-8; y: 6; color: Theme.accent } }
  onClicked: UiState.toggle("controls")
 }
}
