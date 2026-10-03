pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
ColumnLayout {
 id: root
 property string label
 property string symbol: "volume"
 property real value: 0
 signal adjusted(real level)
 spacing: 6
 RowLayout {
  Layout.fillWidth: true
  ShellText { text: root.label; font.pixelSize: Theme.captionSize; color: Theme.muted; Layout.fillWidth: true }
  ShellText { text: Math.round(root.value*100)+"%"; color: Theme.muted; font.pixelSize: Theme.captionSize }
 }
 Slider {
  id: slider
  Layout.fillWidth: true
  from: 0; to: 1; value: root.value; implicitHeight: 28
  leftPadding: 0; rightPadding: 0
  onMoved: root.adjusted(value)
  background: Rectangle {
   x: slider.leftPadding; y: slider.topPadding+slider.availableHeight/2-height/2
   width: slider.availableWidth; height: 26; radius: 13; color: Theme.raised
   Rectangle { width: Math.max(26,slider.visualPosition*parent.width); height: parent.height; radius: 13; color: Theme.accent }
   ShellIcon { anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } name: root.symbol; size: 14; opacity: 0.8 }
  }
  handle: Item { width: 0; height: 0 }
  Accessible.name: root.label
 }
}
