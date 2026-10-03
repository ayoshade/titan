pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
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
 MouseArea { anchors.fill: parent; onClicked: UiState.close() }
 Rectangle {
  id: card
  width: Math.min(UiState.panel==="launcher" ? 560 : 440,root.width-32)
  height: Math.min(UiState.panel==="session" ? 390 : 650,root.height-100)
  anchors.top: parent.top; anchors.topMargin: 58
  anchors.right: parent.right; anchors.rightMargin: UiState.panel==="launcher" ? (root.width-width)/2 : 16
  color: Theme.surface; radius: Theme.radius; border.width: 1; border.color: Theme.border
  MouseArea { anchors.fill: parent; onClicked: {} }
  Loader {
   id: loader
   anchors { fill: parent; margins: Theme.padding }
   active: root.visible
   source: UiState.panel==="launcher" ? "Launcher.qml" : UiState.panel==="controls" ? "ControlCenter.qml" : UiState.panel==="notifications" ? "NotificationCenter.qml" : "SessionMenu.qml"
   focus: true
   Keys.onEscapePressed: UiState.close()
  }
 }
}
