pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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
 visible: UiState.barVisible
 anchors { top: true; left: true; right: true }
 readonly property int workspaceCount: Math.max(5,...Hyprland.workspaces.values.filter(w=>w.id>0 && w.id<=10).map(w=>w.id))
 readonly property bool expanded: UiState.context!=="" || (hover.hovered && !!Media.player)
 // Leave room below the island for its drop shadow; input is limited by the mask.
 implicitHeight: Theme.islandTop+island.height+28
 exclusiveZone: Theme.barHeight
 color: "transparent"
 WlrLayershell.namespace: "umbra-bar"
 mask: Region { item: island }
 SystemClock { id: clock; precision: SystemClock.Minutes }
 RectangularShadow {
  anchors.fill: island; radius: island.radius
  offset.y: 4; blur: 22; spread: 0
  color: Qt.rgba(0,0,0,0.55)
 }
 Rectangle {
  id: island
  anchors { top: parent.top; topMargin: Theme.islandTop; horizontalCenter: parent.horizontalCenter }
  width: bar.expanded ? Theme.expandedIslandWidth : Theme.islandWidth+(bar.workspaceCount-5)*11
  height: bar.expanded ? Theme.expandedIslandHeight : Theme.islandHeight
  radius: bar.expanded ? 22 : height/2
  color: Theme.notch
  Behavior on width { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  Behavior on height { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  Behavior on radius { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  HoverHandler { id: hover }
  Item {
   id: compact
   anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.islandPadding; rightMargin: Theme.islandPadding }
   height: Theme.islandHeight
   Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4
    Repeater {
     model: bar.workspaceCount
     Item {
      id: mark
      required property int index
      readonly property var workspace: Hyprland.workspaces.values.find(w=>w.id===index+1) || null
      readonly property bool active: !!workspace && workspace.active && !!workspace.monitor && workspace.monitor.name===bar.modelData.name
      readonly property bool occupied: !!workspace && workspace.toplevels.values.length>0
      width: pill.width; height: Theme.islandHeight
      RectangularShadow {
       anchors.fill: pill; radius: pill.radius; blur: 7; spread: 0
       color: Theme.accent; opacity: mark.active ? 0.65 : 0
       Behavior on opacity { NumberAnimation { duration: Theme.duration } }
      }
      Rectangle {
       id: pill
       anchors.centerIn: parent
       width: mark.active ? 9 : 7; height: mark.active ? 15 : 11; radius: width/2
       color: mark.active ? Theme.accent : mark.occupied ? Qt.alpha(Theme.accent,0.42) : Qt.alpha(Theme.text,0.11)
       Behavior on width { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
       Behavior on height { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
       Behavior on color { ColorAnimation { duration: Theme.duration } }
      }
      MouseArea { anchors { fill: parent; leftMargin: -2; rightMargin: -2 } cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("hl.dsp.focus({workspace="+(mark.index+1)+"})") }
      Accessible.role: Accessible.Button; Accessible.name: "Workspace "+(index+1); Accessible.onPressAction: Hyprland.dispatch("hl.dsp.focus({workspace="+(mark.index+1)+"})")
     }
    }
   }
   ShellText {
    id: time
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date,"HH:mm")
    font.pixelSize: Theme.clockSize; font.weight: Font.Medium
    font.features: { "tnum": 1 }
    MouseArea { anchors { fill: parent; margins: -6 } cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggle("clock") }
    Accessible.role: Accessible.Button; Accessible.name: "Clock and calendar"; Accessible.onPressAction: UiState.toggle("clock")
   }
   Row {
    id: status
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: 7
    readonly property real strength: NetState.active ? NetState.active.signalStrength : NetState.label==="Offline" ? 0 : 1
    Row {
     spacing: 1.5; height: 12
     opacity: NetState.label==="Offline" ? 0.4 : 1
     Repeater {
      model: [4,7,9,12]
      Rectangle {
       required property int index
       required property int modelData
       anchors.bottom: parent.bottom
       width: 3; height: modelData; radius: 1
       color: status.strength>index/4+0.05 || (index===0 && status.strength>0) ? Theme.accent : Qt.alpha(Theme.text,0.16)
      }
     }
    }
    Row {
     id: battery
     spacing: 1.5
     readonly property real level: UPower.displayDevice.ready ? UPower.displayDevice.percentage : 1
     readonly property bool low: UPower.onBattery && level<0.15
     Rectangle {
      width: 25; height: 12; radius: 4
      color: Qt.alpha(Theme.text,0.14)
      Rectangle {
       width: Math.max(height,parent.width*battery.level); height: parent.height; radius: parent.radius
       color: battery.low ? Theme.danger : Theme.accent
      }
     }
     Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 2; height: 4; radius: 1; color: Qt.alpha(Theme.text,0.22) }
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Controls · "+NetState.label+" · battery "+Math.round((UPower.displayDevice.ready ? UPower.displayDevice.percentage : 1)*100)+"%"
    Accessible.onPressAction: UiState.toggle("controls")
   }
   MouseArea { anchors { fill: status; margins: -6 } cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggle("controls") }
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
}
