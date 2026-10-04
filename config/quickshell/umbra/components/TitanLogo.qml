pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
// The repository/package root owns the artwork; keep its supplied colours.
Item {
 implicitWidth: 180
 implicitHeight: 82
 Image {
  anchors.fill: parent
  source: "file://"+Paths.root+"/logo.png"
  fillMode: Image.PreserveAspectFit
  smooth: true
 }
 Accessible.role: Accessible.Graphic
 Accessible.name: "Titan logo"
}
