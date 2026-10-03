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
 readonly property bool dashboard: UiState.islandScreen===modelData.name
 // Fixed height fits the dashboard and its shadow, so the surface is not
 // reconfigured on every animation frame. Input is limited by the mask.
 implicitHeight: Theme.islandTop+Theme.dashboardHeight+32
 exclusiveZone: Theme.barHeight
 color: "transparent"
 WlrLayershell.namespace: "umbra-bar"
 WlrLayershell.keyboardFocus: dashboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
 mask: Region { item: island }
 RectangularShadow {
  anchors.fill: island; radius: island.radius
  offset.y: 4; blur: 22; spread: 0
  color: Qt.rgba(0,0,0,0.55)
 }
 Rectangle {
  id: island
  anchors { top: parent.top; topMargin: Theme.islandTop; horizontalCenter: parent.horizontalCenter }
  // Hovering the compact pill widens it slightly, as in the reference.
  property real bump: state==="" && hover.hovered ? 10 : 0
  Behavior on bump { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  width: Theme.islandWidth+(bar.workspaceCount-5)*11+bump
  height: Theme.islandHeight
  radius: height/2
  color: Theme.notch
  clip: true
  state: bar.dashboard ? "dashboard" : UiState.context!=="" ? "osd" : ""
  states: [
   State { name: "osd"; PropertyChanges { island.width: Theme.expandedIslandWidth; island.height: Theme.expandedIslandHeight; island.radius: 22 } },
   State { name: "dashboard"; PropertyChanges { island.width: Theme.dashboardWidth; island.height: Theme.dashboardHeight; island.radius: Theme.dashboardRadius } }
  ]
  // Measured at 30 fps: opening overshoots ~1% and settles in ~330 ms;
  // closing drops the height first, then narrows.
  transitions: [
   Transition {
    to: "dashboard"
    NumberAnimation { properties: "width,height,radius"; duration: Theme.motion ? 330 : 0; easing.type: Easing.OutBack; easing.overshoot: 0.45 }
   },
   Transition {
    from: "dashboard"
    SequentialAnimation {
     NumberAnimation { properties: "height,radius"; duration: Theme.motion ? 140 : 0; easing.type: Easing.InOutCubic }
     NumberAnimation { property: "width"; duration: Theme.motion ? 380 : 0; easing.type: Easing.OutCubic }
    }
   },
   Transition { NumberAnimation { properties: "width,height,radius"; duration: Theme.duration; easing.type: Easing.OutCubic } }
  ]
  HoverHandler {
   id: hover
   onHoveredChanged: if(bar.dashboard) { if(hovered) leave.stop(); else leave.restart() }
  }
  Timer { id: leave; interval: 350; onTriggered: if(!hover.hovered) UiState.closeIsland() }
  Item {
   anchors.fill: parent
   focus: bar.dashboard
   Keys.onEscapePressed: UiState.closeIsland()
  }
  Item {
   id: compact
   anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.islandPadding; rightMargin: Theme.islandPadding }
   height: Theme.islandHeight
   opacity: bar.dashboard ? 0 : 1
   visible: opacity>0
   Behavior on opacity { NumberAnimation { duration: Theme.motion ? 120 : 0 } }
   MouseArea {
    anchors { fill: parent; leftMargin: -Theme.islandPadding; rightMargin: -Theme.islandPadding }
    cursorShape: Qt.PointingHandCursor
    onClicked: UiState.toggleIsland(bar.modelData.name)
   }
   Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4
    Repeater {
     model: bar.workspaceCount
     WorkspaceMark {
      id: mark
      required property int index
      readonly property var workspace: Hyprland.workspaces.values.find(w=>w.id===index+1) || null
      active: !!workspace && workspace.active && !!workspace.monitor && workspace.monitor.name===bar.modelData.name
      occupied: !!workspace && workspace.toplevels.values.length>0
      height: Theme.islandHeight
      MouseArea { anchors { fill: parent; leftMargin: -2; rightMargin: -2 } cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("hl.dsp.focus({workspace="+(mark.index+1)+"})") }
      Accessible.role: Accessible.Button; Accessible.name: "Workspace "+(index+1); Accessible.onPressAction: Hyprland.dispatch("hl.dsp.focus({workspace="+(mark.index+1)+"})")
     }
    }
   }
   SystemClock { id: clock; precision: SystemClock.Minutes }
   ShellText {
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date,"HH:mm")
    font.pixelSize: Theme.clockSize; font.weight: Font.Medium
    font.features: { "tnum": 1 }
    Accessible.role: Accessible.Button; Accessible.name: "Open island dashboard"; Accessible.onPressAction: UiState.toggleIsland(bar.modelData.name)
   }
   Row {
    id: status
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: 7
    SignalBars {
     strength: NetState.active ? NetState.active.signalStrength : NetState.label==="Offline" ? 0 : 1
     opacity: NetState.label==="Offline" ? 0.4 : 1
    }
    BatteryGlyph {}
    Accessible.role: Accessible.Button
    Accessible.name: "Controls · "+NetState.label+" · battery "+Math.round((UPower.displayDevice.ready ? UPower.displayDevice.percentage : 1)*100)+"%"
    Accessible.onPressAction: UiState.toggle("controls")
   }
   MouseArea { anchors { fill: status; margins: -6 } cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggle("controls") }
  }
  IslandDashboard {
   anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
   screenName: bar.modelData.name
   open: bar.dashboard
   opacity: bar.dashboard ? 1 : 0
   visible: opacity>0
   Behavior on opacity { NumberAnimation { duration: Theme.motion ? (bar.dashboard ? 220 : 90) : 0 } }
  }
  RowLayout {
   anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 13 }
   visible: island.state==="osd"
   spacing: 12
   ShellIcon { name: UiState.context==="volume" ? (Audio.muted ? "mute" : "volume") : UiState.context==="brightness" ? "sun" : "bell"; size: 18 }
   ColumnLayout {
    Layout.fillWidth: true; spacing: 5
    ShellText { text: UiState.context==="volume" ? (Audio.muted ? "Muted" : "Volume  "+Math.round(Audio.volume*100)+"%") : UiState.context==="brightness" ? "Brightness  "+Math.round(Brightness.value*100)+"%" : UiState.message; Layout.fillWidth: true }
    Rectangle { visible: UiState.context==="volume" || UiState.context==="brightness"; Layout.fillWidth: true; implicitHeight: 3; radius: 2; color: Theme.border; Rectangle { width: parent.width*(UiState.context==="volume" ? Audio.volume : Brightness.value); height: 3; radius: 2; color: Theme.accent } }
   }
  }
 }
}
