pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower
import "../theme"
// Solid battery: accent fill on a dark track with a detached tip.
Row {
 id: root
 property int bodyWidth: 25
 property int bodyHeight: 12
 readonly property real level: UPower.displayDevice.ready ? UPower.displayDevice.percentage : 1
 readonly property bool low: UPower.onBattery && level<0.15
 spacing: 1.5
 Rectangle {
  width: root.bodyWidth; height: root.bodyHeight; radius: Math.round(root.bodyHeight/3)
  color: Qt.alpha(Theme.text,0.14)
  Rectangle {
   width: Math.max(height,parent.width*root.level); height: parent.height; radius: parent.radius
   color: root.low ? Theme.danger : Theme.accent
  }
 }
 Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 2; height: Math.round(root.bodyHeight/3); radius: 1; color: Qt.alpha(Theme.text,0.22) }
}
