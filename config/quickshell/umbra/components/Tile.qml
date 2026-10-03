pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
// Control-center tile: round icon (accent when on), title and status. With no
// text it renders as a round button.
Rectangle {
 id: root
 property string symbol: "wifi"
 property string title: ""
 property string subtitle: ""
 property bool on: false
 signal clicked()
 signal pressAndHold()
 implicitHeight: 52; implicitWidth: title ? 160 : 52
 radius: height/2
 color: mouse.containsMouse ? Qt.alpha(Theme.text,0.10) : Qt.alpha(Theme.text,0.06)
 Behavior on color { ColorAnimation { duration: Theme.hover } }
 Rectangle {
  id: badge
  x: root.title ? 7 : (root.width-width)/2; anchors.verticalCenter: parent.verticalCenter
  width: root.title ? 38 : root.height-14; height: width; radius: width/2
  color: root.on ? Theme.accent : Qt.alpha(Theme.text,0.08)
  Behavior on color { ColorAnimation { duration: Theme.duration } }
  ShellIcon { anchors.centerIn: parent; name: root.symbol; size: 15; opacity: root.on ? 1 : 0.75 }
 }
 Column {
  visible: root.title!==""
  anchors { left: badge.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
  spacing: 1
  ShellText { width: parent.width; text: root.title; font.pixelSize: Theme.fontSize+1; font.weight: Font.DemiBold }
  ShellText { width: parent.width; text: root.subtitle; font.pixelSize: Theme.captionSize; color: Theme.muted; visible: text!=="" }
 }
 MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked(); onPressAndHold: root.pressAndHold() }
 Accessible.role: Accessible.Button; Accessible.name: title ? title+", "+subtitle : symbol; Accessible.onPressAction: clicked()
}
