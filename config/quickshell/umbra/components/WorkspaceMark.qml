pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../theme"
// Vertical capsule: glowing accent when active, dim accent when occupied, faint when empty.
Item {
 id: root
 property bool active: false
 property bool occupied: false
 property int activeWidth: 9
 property int activeHeight: 15
 property int idleWidth: 7
 property int idleHeight: 11
 implicitWidth: pill.width; implicitHeight: activeHeight
 RectangularShadow {
  anchors.fill: pill; radius: pill.radius; blur: 7; spread: 0
  color: Theme.accent; opacity: root.active ? 0.65 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
 }
 Rectangle {
  id: pill
  anchors.centerIn: parent
  width: root.active ? root.activeWidth : root.idleWidth; height: root.active ? root.activeHeight : root.idleHeight; radius: width/2
  color: root.active ? Theme.accent : root.occupied ? Qt.alpha(Theme.accent,0.42) : Qt.alpha(Theme.text,0.11)
  Behavior on width { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  Behavior on height { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
  Behavior on color { ColorAnimation { duration: Theme.duration } }
 }
}
