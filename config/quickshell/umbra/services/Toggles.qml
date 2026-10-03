pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
// Night light and game mode state from `scripts/workflow toggles`; both are
// changed through the same workflow operations agents use.
QtObject {
 id: root
 property bool nightlight: false
 property bool gameMode: false
 readonly property string workflow: Quickshell.env("HOME")+"/dotfiles/scripts/workflow"
 function refresh() { if(!query.running) query.running=true }
 function toggle(op) { if(runner.running) return; runner.command=[workflow,op]; runner.running=true }
 property Process query: Process {
  command: [root.workflow,"toggles"]
  stdout: StdioCollector { onStreamFinished: { try { const s=JSON.parse(text); root.nightlight=s.nightlight; root.gameMode=s.gameMode } catch(e) {} } }
 }
 property Process runner: Process { onExited: root.refresh() }
 Component.onCompleted: refresh()
}
