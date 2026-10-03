pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../theme"
Button {
 id: root
 property bool selected: false
 implicitHeight: 32
 implicitWidth: Math.max(32, contentItem.implicitWidth + 24)
 hoverEnabled: true
 font.family: Theme.sans
 font.pixelSize: Theme.fontSize
 contentItem: ShellText { text: root.text; color: root.enabled ? Theme.text : Theme.muted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
 background: Rectangle {
  radius: Theme.radius
  color: root.down || root.selected ? Theme.border : root.hovered ? Theme.raised : "transparent"
  border.color: root.activeFocus ? Theme.accent : "transparent"
  border.width: 1
  Behavior on color { ColorAnimation { duration: Theme.duration } }
 }
 Accessible.name: text
}
