pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
ColumnLayout {
 id: root
 property string label
 property real value: 0
 signal adjusted(real level)
 spacing: Theme.small
 RowLayout {
  Layout.fillWidth: true
  ShellText { text: root.label; Layout.fillWidth: true }
  ShellText { text: Math.round(root.value*100)+"%"; color: Theme.muted; font.family: Theme.mono }
 }
 Slider {
  id: slider
  Layout.fillWidth: true
  from: 0; to: 1; value: root.value
  onMoved: root.adjusted(value)
  implicitHeight: 26
  background: Rectangle {
   x: slider.leftPadding; y: slider.topPadding + slider.availableHeight/2-height/2
   width: slider.availableWidth; height: 3; radius: 2; color: Theme.border
   Rectangle { width: slider.visualPosition*parent.width; height: parent.height; radius: 2; color: Theme.accent }
  }
  handle: Rectangle { x: slider.leftPadding+slider.visualPosition*(slider.availableWidth-width); y: slider.topPadding+slider.availableHeight/2-height/2; width: 12; height: 12; radius: 6; color: Theme.text }
 }
}
