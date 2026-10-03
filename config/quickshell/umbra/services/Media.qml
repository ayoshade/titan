pragma Singleton
import QtQuick
import "."
import Quickshell.Services.Mpris
QtObject {
 property var selectedPlayer: null
 function cyclePlayer() {
  const players=Mpris.players.values
  if(players.length) selectedPlayer=players[(players.indexOf(player)+1)%players.length]
 }
 readonly property var player: Mpris.players.values.includes(selectedPlayer) ? selectedPlayer : Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
 readonly property string title: player ? player.trackTitle || player.identity : "No media playing"
}
