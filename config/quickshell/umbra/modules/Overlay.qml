pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components"
import "../services"
import "../theme"
PanelWindow {
 id: root
 required property var modelData
 screen: modelData
 visible: UiState.panel!=="" && UiState.panelScreen===modelData.name
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.namespace: "umbra-overlay"
 WlrLayershell.layer: WlrLayer.Overlay
 WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
 color: "transparent"
 SystemClock { id: clock; precision: SystemClock.Minutes }
 MouseArea { anchors.fill: parent; onClicked: UiState.close() }
 Rectangle {
  id: card
  width: Math.min(UiState.panel==="launcher" ? Theme.launcherWidth : Theme.panelWidth,root.width-32)
  height: Math.min(UiState.panel==="clock" ? 400 : UiState.panel==="session" ? 430 : UiState.panel==="appearance" ? 400 : 640,root.height-40)
  anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
  color: Theme.shell; radius: Theme.panelRadius; border.width: 1; border.color: "#262a30"
  MouseArea { anchors.fill: parent; onClicked: {} }
  scale: root.visible ? 1 : 0.9
  opacity: root.visible ? 1 : 0
  transformOrigin: Item.Top
  Behavior on scale { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  ColumnLayout {
   anchors { fill: parent; margins: 10 } spacing: 8
   RowLayout {
    Layout.fillWidth: true; spacing: 0
    ShellText { text: Qt.formatDateTime(clock.date,"HH:mm"); font.weight: Font.Medium; leftPadding: 8; Layout.fillWidth: true }
    Repeater {
     model: [{panel:"launcher",symbol:"apps",label:"Applications"},{panel:"controls",symbol:"controls",label:"Control center"},{panel:"media",symbol:"music",label:"Media"},{panel:"notifications",symbol:"bell",label:"Notifications"},{panel:"appearance",symbol:"settings",label:"Appearance"},{panel:"session",symbol:"power",label:"Session"}]
     IconButton { required property var modelData; symbol: modelData.symbol; label: modelData.label; selected: UiState.panel===modelData.panel; onClicked: UiState.toggle(modelData.panel) }
    }
    IconButton { symbol: "close"; label: "Close"; onClicked: UiState.close() }
   }
   Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    color: Theme.surface; radius: Theme.innerRadius
    Loader {
     id: loader
     anchors { fill: parent; margins: 14 }
     active: root.visible
     source: UiState.panel==="launcher" ? "Launcher.qml" : UiState.panel==="controls" ? "ControlCenter.qml" : UiState.panel==="notifications" ? "NotificationCenter.qml" : UiState.panel==="clock" ? "ClockPanel.qml" : UiState.panel==="appearance" ? "Appearance.qml" : UiState.panel==="media" ? "MediaPanel.qml" : UiState.panel==="connectivity" ? "Connectivity.qml" : "SessionMenu.qml"
     focus: true
     Keys.onEscapePressed: UiState.close()
    }
   }
  }
 }
}
