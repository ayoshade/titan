pragma Singleton
import QtQuick
import "."
import Quickshell.Services.Pipewire
QtObject {
 readonly property var sink: Pipewire.defaultAudioSink
 readonly property var source: Pipewire.defaultAudioSource
 readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
 readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
 property PwObjectTracker tracker: PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(x => x !== null) }
 function cycleOutput() {
  const sinks=Pipewire.nodes.values.filter(n=>n.isSink && !n.isStream && n.audio)
  if(sinks.length) Pipewire.preferredDefaultAudioSink=sinks[(sinks.indexOf(sink)+1)%sinks.length]
 }
 function setVolume(value) { if(sink && sink.audio) sink.audio.volume = Math.max(0,Math.min(1,value)) }
 function toggleMute() { if(sink && sink.audio) sink.audio.muted = !sink.audio.muted }
}
