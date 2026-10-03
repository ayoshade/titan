pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "../theme"
Rectangle {
 id: root
 implicitHeight: 100; radius: Theme.radius; color: Theme.raised
 RowLayout {
  anchors { fill: parent; margins: 12 } spacing: 12
  Rectangle {
   implicitWidth: 66; implicitHeight: 66; radius: 12; color: Theme.border; clip: true
   ShellIcon { anchors.centerIn: parent; name: "music"; size: 26; opacity: 0.4 }
   Image { anchors.fill: parent; source: Media.player ? Media.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 132; sourceSize.height: 132 }
  }
  ColumnLayout {
   Layout.fillWidth: true; spacing: 3
   ShellText { text: Media.title; Layout.fillWidth: true; font.weight: Font.Medium }
   ShellText { text: Media.player ? Media.player.trackArtist || Media.player.identity : "Waiting for playback"; color: Theme.muted; font.pixelSize: Theme.captionSize; Layout.fillWidth: true }
   RowLayout {
    spacing: 8
    IconButton { symbol: "previous"; label: "Previous"; size: 26; enabled: !!Media.player && Media.player.canGoPrevious; onClicked: Media.player.previous() }
    IconButton { symbol: Media.player && Media.player.isPlaying ? "pause" : "play"; label: "Play or pause"; size: 26; enabled: !!Media.player && Media.player.canTogglePlaying; onClicked: Media.player.togglePlaying() }
    IconButton { symbol: "next"; label: "Next"; size: 26; enabled: !!Media.player && Media.player.canGoNext; onClicked: Media.player.next() }
   }
  }
 }
}
