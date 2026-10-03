pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 spacing: Theme.gap
 ShellText { text: Media.title; Layout.fillWidth: true; font.pixelSize: Theme.subtitleSize }
 ShellText { text: Media.player ? Media.player.trackArtist || Media.player.identity : "Start playback in your browser"; color: Theme.muted; Layout.fillWidth: true }
 RowLayout {
  Action { text: "Previous"; enabled: !!Media.player && Media.player.canGoPrevious; onClicked: Media.player.previous() }
  Action { text: Media.player && Media.player.isPlaying ? "Pause" : "Play"; enabled: !!Media.player && Media.player.canTogglePlaying; onClicked: Media.player.togglePlaying() }
  Action { text: "Next"; enabled: !!Media.player && Media.player.canGoNext; onClicked: Media.player.next() }
 }
}
