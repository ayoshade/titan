pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../services"
import "../theme"
// Island announcement for night light and game mode (OeT5VgeLSIQ 0:55–1:30):
// on is an accent ring and icon; off is a muted ring with a slash drawn
// through the icon, so the icon itself answers "did it turn on?".
Row {
 id: root
 property string kind: ""
 // Keep the last kind while fading out so the label does not blank first.
 property string shown: "nightlight"
 onKindChanged: if(kind!=="") shown=kind
 readonly property bool on: shown==="gamemode" ? Toggles.gameMode : Toggles.nightlight
 spacing: 8
 Accessible.role: Accessible.StaticText
 Accessible.name: label.text+(on ? " on" : " off")
 Item {
  width: 18; height: 18
  anchors.verticalCenter: parent.verticalCenter
  Rectangle {
   anchors.fill: parent; radius: width/2; color: "transparent"
   border.width: 1.4; border.color: root.on ? Theme.accent : Theme.muted
   Behavior on border.color { ColorAnimation { duration: Theme.duration } }
  }
  ShellIcon {
   id: glyph
   anchors.centerIn: parent; size: 10
   name: root.shown==="gamemode" ? "gamepad" : "moon"
   layer.enabled: true
   layer.effect: MultiEffect { colorization: 1; colorizationColor: root.on ? Theme.accent : Theme.muted }
  }
  // The slash grows across the icon when the toggle turns off.
  Rectangle {
   anchors.centerIn: parent
   width: root.on ? 0 : 13; height: 1.4; radius: 0.7
   rotation: -45; color: Theme.muted; antialiasing: true
   Behavior on width { NumberAnimation { duration: Theme.movement; easing.type: Easing.OutCubic } }
  }
 }
 ShellText {
  id: label
  anchors.verticalCenter: parent.verticalCenter
  text: root.shown==="gamemode" ? "Game Mode" : "Night Light"
  font.weight: Font.Medium
 }
}
