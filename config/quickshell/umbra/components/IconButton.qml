pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../theme"
Button {
 id: root
 property string symbol: "apps"
 property bool selected: false
 property string label: ""
 property int size: 32
 implicitWidth: size; implicitHeight: size
 hoverEnabled: true
 contentItem: Item { ShellIcon { anchors.centerIn: parent; name: root.symbol; size: 16; opacity: root.enabled ? 1 : 0.35 } }
 background: Rectangle {
  radius: width/2
  color: root.selected || root.down ? Theme.border : root.hovered ? Theme.raised : "transparent"
  border.width: root.activeFocus ? 1 : 0; border.color: Theme.accent
  Behavior on color { ColorAnimation { duration: Theme.duration } }
 }
 Accessible.name: label
 ToolTip.visible: hovered && label!==""
 ToolTip.text: label
 ToolTip.delay: 600
}
