pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
// Four bottom-aligned bars; strength is 0–1.
Row {
 id: root
 property real strength: 1
 spacing: 1.5; height: 12
 Repeater {
  model: [4,7,9,12]
  Rectangle {
   required property int index
   required property int modelData
   y: root.height-height
   width: 3; height: modelData; radius: 1
   color: root.strength>index/4+0.05 || (index===0 && root.strength>0) ? Theme.accent : Qt.alpha(Theme.text,0.16)
  }
 }
}
