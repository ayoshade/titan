pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 spacing: Theme.padding
 ShellText { text: "Now playing"; font.pixelSize: Theme.titleSize }
 Rectangle {
  Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.raised; radius: 16; clip: true
  ShellIcon { anchors.centerIn: parent; name: "music"; size: 64; opacity: 0.2 }
  Image { anchors.fill: parent; source: Media.player ? Media.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 640; sourceSize.height: 640 }
 }
 MediaCard { Layout.fillWidth: true }
 Level { Layout.fillWidth: true; label: "Sound"; value: Audio.volume; onAdjusted: value=>Audio.setVolume(value) }
}
