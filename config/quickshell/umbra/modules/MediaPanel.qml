pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../components"
import "../services"
import "../theme"
// Now playing, after the reference's album-art media card (Ob98KFByTec 7:30):
// large art, track details, progress and transport over a blurred, art-tinted
// background.
Item {
 id: root
 readonly property var player: Media.player
 function time(s) { s=Math.max(0,Math.floor(s||0)); return Math.floor(s/60)+":"+String(s%60).padStart(2,"0") }
 Rectangle {
  anchors.fill: parent; radius: Theme.panelRadius; clip: true; color: Qt.alpha(Theme.text,0.04)
  Image {
   id: backdrop; anchors.fill: parent; visible: false
   source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 200; sourceSize.height: 200
  }
  MultiEffect { anchors.fill: parent; source: backdrop; visible: backdrop.status===Image.Ready; blurEnabled: true; blur: 1; blurMax: 64; saturation: 0.2; brightness: -0.35 }
 }
 Rectangle {
  id: art
  x: 16; anchors.verticalCenter: parent.verticalCenter; width: 128; height: 128; radius: Theme.radius; clip: true; color: Qt.alpha(Theme.text,0.08)
  ShellIcon { anchors.centerIn: parent; name: "music"; size: 40; opacity: 0.35 }
  Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 256; sourceSize.height: 256 }
 }
 Column {
  anchors { left: art.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
  spacing: 3
  ShellText { width: parent.width; text: root.player ? Media.title : "Nothing playing"; font.family: Theme.display; font.pixelSize: Theme.subtitleSize+4; font.weight: Font.DemiBold }
  ShellText { width: parent.width; text: root.player ? root.player.trackArtist || "" : "Start a player to see it here"; color: Qt.alpha(Theme.text,0.8) }
  ShellText { width: parent.width; visible: !!root.player && !!root.player.trackAlbum; text: root.player ? root.player.trackAlbum || "" : ""; color: Theme.muted; font.pixelSize: Theme.captionSize }
  ShellText { width: parent.width; visible: !!root.player; text: root.player ? root.player.identity : ""; color: Theme.muted; font.pixelSize: Theme.captionSize }
  Item { width: 1; height: 8 }
  Rectangle {
   width: parent.width; height: 3; radius: 1.5; color: Qt.alpha(Theme.text,0.16)
   Rectangle { height: parent.height; radius: parent.radius; color: Theme.accent; width: root.player && root.player.lengthSupported && root.player.length>0 ? parent.width*Math.min(1,root.player.position/root.player.length) : 0 }
  }
  Item {
   width: parent.width; height: 16
   ShellText { text: root.time(root.player ? root.player.position : 0); color: Theme.muted; font.pixelSize: Theme.captionSize; font.features: { "tnum": 1 } }
   ShellText { anchors.right: parent.right; text: root.time(root.player && root.player.lengthSupported ? root.player.length : 0); color: Theme.muted; font.pixelSize: Theme.captionSize; font.features: { "tnum": 1 } }
  }
  Row {
   anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
   IconButton { symbol: "previous"; label: "Previous"; size: 34; enabled: !!root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
   IconButton { symbol: root.player && root.player.isPlaying ? "pause" : "play"; label: "Play or pause"; size: 40; enabled: !!root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
   IconButton { symbol: "next"; label: "Next"; size: 34; enabled: !!root.player && root.player.canGoNext; onClicked: root.player.next() }
  }
 }
 // MPRIS position is not pushed; refresh only while the panel is open and playing.
 Timer { interval: 1000; repeat: true; running: !!root.player && root.player.isPlaying; onTriggered: root.player.positionChanged() }
}
