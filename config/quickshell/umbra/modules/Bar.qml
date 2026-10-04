pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
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
 readonly property bool islandOpen: UiState.islandScreen===modelData.name
 readonly property bool dashboard: islandOpen && UiState.islandView==="dashboard"
 readonly property bool calendar: islandOpen && UiState.islandView==="calendar"
 // Game mode turns the notch into a full-width bar, as in the reference (5cp6DkClAuM 0:38).
 readonly property bool gameBar: Toggles.gameMode
 // Fixed height fits the tallest island state and its shadow, so the surface is not
 // reconfigured on every animation frame. Input is limited by the mask.
 implicitHeight: Theme.islandTop+Math.max(Theme.dashboardHeight,Theme.calendarHeight)+32
 exclusiveZone: Theme.barHeight
 color: "transparent"
 WlrLayershell.namespace: "umbra-bar"
 // Exclusive focus makes Hyprland send the island a pointer leave as it opens,
 // which collapsed it before rows could be clicked. OnDemand keeps the pointer
 // and gives Escape/arrow keys after the first click inside.
 WlrLayershell.keyboardFocus: islandOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
 mask: Region { item: island }
 RectangularShadow {
  anchors.fill: island; radius: island.radius
  offset.y: 4; blur: 22; spread: 0
  color: Qt.rgba(0,0,0,0.55)
 }
 // Concave fillets that blend the notch into the top edge (Settings → Notch flare).
 component Flare: Shape {
  id: flare
  property bool mirrored: false
  visible: Theme.notchMode && Theme.notchFlare>0 && !bar.gameBar
  width: Theme.notchFlare; height: Theme.notchFlare
  y: 0
  preferredRendererType: Shape.CurveRenderer
  transform: Scale { origin.x: flare.width/2; xScale: flare.mirrored ? -1 : 1 }
  ShapePath {
   strokeWidth: 0; strokeColor: "transparent"; fillColor: Theme.notch
   startX: 0; startY: 0
   PathLine { x: flare.width; y: 0 }
   PathLine { x: flare.width; y: flare.height }
   PathArc { x: 0; y: 0; radiusX: flare.width; radiusY: flare.height; direction: PathArc.Counterclockwise }
  }
 }
 Flare { x: island.x-width }
 Flare { x: island.x+island.width; mirrored: true }
 Rectangle {
  id: island
  anchors { top: parent.top; topMargin: bar.gameBar && state==="" ? 0 : Theme.islandTop; horizontalCenter: parent.horizontalCenter }
  // Hovering the compact pill widens it slightly, as in the reference.
  property real bump: state==="" && hover.hovered && !bar.gameBar ? 10 : 0
  Behavior on bump { NumberAnimation { duration: Theme.hover; easing.type: Easing.OutCubic } }
  width: bar.gameBar ? bar.width : Theme.islandWidth+(bar.workspaceCount-5)*11+bump
  height: Theme.islandHeight
  radius: bar.gameBar ? 0 : height/2
  color: Theme.notch
  clip: true
  state: bar.dashboard ? "dashboard" : bar.calendar ? "calendar" : UiState.context!=="" ? "osd" : ""
  states: [
   State { name: "osd"; PropertyChanges { island.width: Theme.expandedIslandWidth; island.height: Theme.expandedIslandHeight; island.radius: 22 } },
   State { name: "dashboard"; PropertyChanges { island.width: Theme.dashboardWidth; island.height: Theme.dashboardHeight; island.radius: Theme.dashboardRadius } },
   State { name: "calendar"; PropertyChanges { island.width: Theme.calendarWidth; island.height: Theme.calendarHeight; island.radius: Theme.dashboardRadius } }
  ]
  // Measured at 30 fps: opening overshoots ~1% and settles in ~330 ms;
  // closing drops the height first, then narrows. The calendar morph uses the
  // same spring; collapsing from it shrinks both axes together (~370 ms).
  // Durations scale from Settings → Motion (330 ms and 45% bounce by default).
  transitions: [
   Transition {
    to: "dashboard,calendar"
    NumberAnimation { properties: "width,height,radius"; duration: Theme.movement; easing.type: Easing.OutBack; easing.overshoot: Theme.bounce }
   },
   Transition {
    from: "dashboard"
    SequentialAnimation {
     NumberAnimation { properties: "height,radius"; duration: Theme.movement*0.42; easing.type: Easing.InOutCubic }
     NumberAnimation { property: "width"; duration: Theme.movement*1.15; easing.type: Easing.OutCubic }
    }
   },
   Transition {
    from: "calendar"
    ParallelAnimation {
     NumberAnimation { property: "width"; duration: Theme.movement*0.73; easing.type: Easing.OutCubic }
     NumberAnimation { properties: "height,radius"; duration: Theme.movement*1.12; easing.type: Easing.InOutCubic }
    }
   },
   Transition { NumberAnimation { properties: "width,height,radius"; duration: Theme.duration; easing.type: Easing.OutCubic } }
  ]
  // Notch mode squares the top corners so the island meets the screen edge.
  Rectangle {
   visible: Theme.notchMode || bar.gameBar
   width: parent.width; height: Math.min(parent.radius,parent.height/2); color: parent.color
  }
  HoverHandler {
   id: hover
   onHoveredChanged: if(bar.islandOpen) { if(hovered) leave.stop(); else leave.restart() }
  }
  Timer { id: leave; interval: 350; onTriggered: if(!hover.hovered) UiState.closeIsland() }
  Item {
   anchors.fill: parent
   focus: bar.islandOpen
   Keys.onEscapePressed: UiState.closeIsland()
   Keys.onLeftPressed: if(bar.calendar) calendarView.shift(-1)
   Keys.onRightPressed: if(bar.calendar) calendarView.shift(1)
  }
  Item {
   id: compact
   anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.islandPadding; rightMargin: Theme.islandPadding }
   height: Theme.islandHeight
   opacity: bar.islandOpen ? 0 : 1
   visible: opacity>0
   Behavior on opacity { NumberAnimation { duration: Theme.duration*0.6 } }
   MouseArea {
    anchors { fill: parent; leftMargin: -Theme.islandPadding; rightMargin: -Theme.islandPadding }
    cursorShape: Qt.PointingHandCursor
    onClicked: UiState.toggleIsland(bar.modelData.name)
   }
   // A toggle announcement crossfades the compact contents (OeT5VgeLSIQ 0:55).
   readonly property bool announcing: UiState.indicator!==""
   Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4
    opacity: compact.announcing ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.duration*0.6 } }
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
    opacity: compact.announcing ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.duration*0.6 } }
    text: Qt.formatDateTime(clock.date,Settings.values.clock24 ? "HH:mm" : "h:mm")
    font.pixelSize: Theme.clockSize; font.weight: Font.Medium
    font.features: { "tnum": 1 }
    Accessible.role: Accessible.Button; Accessible.name: "Open island dashboard"; Accessible.onPressAction: UiState.toggleIsland(bar.modelData.name)
   }
   Row {
    id: status
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: 7
    opacity: compact.announcing ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.duration*0.6 } }
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
   ToggleIndicator {
    anchors.centerIn: parent
    kind: UiState.indicator
    opacity: compact.announcing ? 1 : 0
    visible: opacity>0
    Behavior on opacity { NumberAnimation { duration: Theme.duration*0.6 } }
   }
  }
  IslandDashboard {
   anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
   screenName: bar.modelData.name
   open: bar.dashboard
   opacity: bar.dashboard ? 1 : 0
   visible: opacity>0
   Behavior on opacity { NumberAnimation { duration: bar.dashboard ? Theme.duration*1.1 : Theme.duration*0.45 } }
  }
  IslandCalendar {
   id: calendarView
   anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
   open: bar.calendar
   opacity: bar.calendar ? 1 : 0
   visible: opacity>0
   Behavior on opacity { NumberAnimation { duration: bar.calendar ? Theme.duration*0.8 : Theme.duration*0.55 } }
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
