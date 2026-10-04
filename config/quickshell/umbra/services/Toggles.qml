pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
// Night light and game mode state from `bin/workflow toggles`; both are
// changed through the same workflow operations agents use.
QtObject {
 id: root
 property bool nightlight: false
 property bool gameMode: false
 // The island announces a change from any source (key, panel or agent) once
 // the first state has loaded, as in the reference (OeT5VgeLSIQ 0:55).
 property bool ready: false
 onNightlightChanged: if(ready) UiState.indicate("nightlight")
 onGameModeChanged: if(ready) UiState.indicate("gamemode")
 readonly property string workflow: Paths.workflow
 function refresh() { if(!query.running) query.running=true }
 function toggle(op) { if(runner.running) return; runner.command=[workflow,op]; runner.running=true }
 property Process query: Process {
  command: [root.workflow,"toggles"]
  onExited: { root.published.reload(); root.ready=true }
  stdout: StdioCollector { onStreamFinished: { try { const s=JSON.parse(text); root.nightlight=s.nightlight; root.gameMode=s.gameMode } catch(e) {} } }
 }
 property Process runner: Process { onExited: root.refresh() }
 // A temperature change restarts wlsunset, debounced while a slider moves.
 readonly property int temperature: Settings.values.nightlightTemp
 onTemperatureChanged: if(nightlight) applyTimer.restart()
 property Timer applyTimer: Timer { interval: 600; onTriggered: { if(!root.runner.running) { root.runner.command=[root.workflow,"nightlight","apply"]; root.runner.running=true } else restart() } }
 Component.onCompleted: refresh()
 property FileView published: FileView {
  path: (Quickshell.env("XDG_RUNTIME_DIR")||"/run/user/1000")+"/titan/toggles.json"
  watchChanges: true; __printErrors: false
  onFileChanged: reload()
  onLoaded: { try { const s=JSON.parse(text()); root.nightlight=s.nightlight; root.gameMode=s.gameMode } catch(e) {} }
 }
}
