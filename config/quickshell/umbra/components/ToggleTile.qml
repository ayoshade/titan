pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
Button {
 id: root
 property string symbol: "wifi"
 property string subtitle: ""
 property bool selected: false
 implicitHeight: 58
 hoverEnabled: true
 contentItem: RowLayout {
  spacing: 10
  Rectangle {
   implicitWidth: 32; implicitHeight: 32; radius: 16
   color: root.selected ? Theme.accent : Theme.border
   ShellIcon { anchors.centerIn: parent; name: root.symbol; size: 17; opacity: root.selected ? 0.9 : 0.6 }
  }
  ColumnLayout {
   spacing: 2; Layout.fillWidth: true
   ShellText { text: root.text; font.weight: Font.Medium; Layout.fillWidth: true }
   ShellText { text: root.subtitle; font.pixelSize: Theme.captionSize; color: Theme.muted; Layout.fillWidth: true }
  }
 }
 leftPadding: 10; rightPadding: 10
 background: Rectangle { radius: Theme.pill; color: root.hovered || root.down ? Theme.border : Theme.raised; Behavior on color { ColorAnimation { duration: Theme.duration } } }
 Accessible.name: text+" "+subtitle
}
