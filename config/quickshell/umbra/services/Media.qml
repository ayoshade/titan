pragma Singleton
import QtQuick
import "."
import "../theme"
import Quickshell.Services.Mpris
QtObject {
 property var selectedPlayer: null
 function cyclePlayer() {
  const players=Mpris.players.values
  if(players.length) selectedPlayer=players[(players.indexOf(player)+1)%players.length]
 }
 // Settings → Media → Preferred player matches the MPRIS identity or desktop entry.
 readonly property string preferred: (Settings.values.mediaPlayer || "").toLowerCase()
 readonly property var preferredPlayer: preferred ? Mpris.players.values.find(p => (p.identity+" "+p.desktopEntry).toLowerCase().includes(preferred)) || null : null
 readonly property var player: Mpris.players.values.includes(selectedPlayer) ? selectedPlayer : preferredPlayer || Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
 readonly property string title: player ? player.trackTitle || player.identity : "No media playing"
}
