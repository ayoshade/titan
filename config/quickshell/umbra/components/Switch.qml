pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
// Capsule toggle: accent track and dark knob when on.
Rectangle {
 id: root
 property bool checked: false
 property string label: ""
 signal toggled()
 implicitWidth: 40; implicitHeight: 22; radius: height/2
 color: checked ? Theme.accent : Qt.alpha(Theme.text,0.14)
 Behavior on color { ColorAnimation { duration: Theme.duration } }
 Rectangle {
  width: parent.height-6; height: width; radius: width/2; y: 3
  x: root.checked ? parent.width-width-3 : 3
  color: root.checked ? Theme.notch : Qt.alpha(Theme.text,0.55)
  Behavior on x { NumberAnimation { duration: Theme.hover; easing.type: Easing.OutCubic } }
 }
 MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
 Accessible.role: Accessible.CheckBox; Accessible.checked: checked; Accessible.name: label; Accessible.onToggleAction: toggled(); Accessible.onPressAction: toggled()
}
