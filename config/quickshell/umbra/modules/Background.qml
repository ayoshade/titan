pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../components"
PanelWindow {
 required property var modelData
 screen: modelData
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.layer: WlrLayer.Background
 WlrLayershell.namespace: "umbra-background"
 color: Theme.background
 mask: Region {}
 Rectangle { anchors { right: parent.right; bottom: parent.bottom; rightMargin: 64; bottomMargin: 86 } width: 160; height: 1; color: Theme.border }
 Column {
  anchors { right: parent.right; bottom: parent.bottom; rightMargin: 64; bottomMargin: 106 }
  spacing: 8
  ShellText { text: "U M B R A"; font.family: Theme.mono; font.pixelSize: Theme.heroSize; color: "#343a44" }
  ShellText { text: "PRIVATE SYSTEM / 01"; font.family: Theme.mono; font.pixelSize: Theme.captionSize; color: "#252b33" }
 }
}
