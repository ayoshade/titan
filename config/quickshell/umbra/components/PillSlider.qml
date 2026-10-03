pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../theme"
// Tall pill slider with the icon inside the fill, as in the reference control center.
Slider {
 id: root
 property string symbol: "volume"
 property string label: ""
 from: 0; to: 1
 implicitHeight: 28; implicitWidth: 200
 leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
 background: Rectangle {
  width: root.availableWidth; height: root.height; radius: height/2
  color: Qt.alpha(Theme.text,0.07)
  Rectangle {
   width: Math.max(parent.height,root.visualPosition*parent.width); height: parent.height; radius: height/2
   color: Theme.accent
   Behavior on width { enabled: !root.pressed; NumberAnimation { duration: Theme.duration } }
  }
  ShellIcon { anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } name: root.symbol; size: 13; opacity: 0.75 }
 }
 handle: Item {}
 Accessible.name: label
}
