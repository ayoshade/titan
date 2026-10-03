pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
QtObject {
 id: root
 property string panel: ""
 property var panelScreen: null
 property string context: ""
 property string message: ""
 property bool dnd: false
 property bool barVisible: true
 property string menuKind: "root"
 // Expanded island dashboard, shown on one screen at a time.
 property string islandScreen: ""
 function focusedScreen() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "") }
 function toggleIsland(screen) { const target=screen || focusedScreen(); islandScreen=islandScreen===target ? "" : target; if(islandScreen) panel="" }
 function closeIsland() { islandScreen="" }
 function menu(kind) {
  if(kind==="apps") { toggle("launcher"); return }
  if(kind==="system") { toggle("session"); return }
  const wasOpen=panel==="commands" && menuKind===kind
  menuKind=kind
  panelScreen=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  panel=wasOpen ? "" : "commands"
 }
 function saveShell() {
  saver.command=[Quickshell.env("HOME")+"/dotfiles/scripts/workflow","bar-set",String(barVisible)]
  saver.running=true
 }
 property Process saver: Process {}
 property FileView settings: FileView {
  path: (Quickshell.env("XDG_STATE_HOME")||Quickshell.env("HOME")+"/.local/state")+"/titan/shell-settings.json"
  watchChanges: true
  onFileChanged: reload()
  onLoaded: { try { root.barVisible=JSON.parse(text()).barVisible!==false } catch(e) {} }
 }
 function toggle(name) {
  panelScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  panel = panel === name ? "" : name
  if (panel) islandScreen = ""
 }
 function close() { panel = "" }
 function osd(kind) { context = kind; if (kind === "brightness") Brightness.refresh(); root.timeout.restart() }
 function inform(text) { message = text; context = "message"; root.timeout.restart() }
 property Timer timeout: Timer { interval: 2500; onTriggered: { root.context = ""; root.message = "" } }
}
