pragma Singleton
import QtQuick
import "."
import Quickshell.Services.Mpris
QtObject {
 readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
 readonly property string title: player ? player.trackTitle || player.identity : "No media playing"
}
