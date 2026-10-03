pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
QtObject {
 id: root
 property string panel: ""
 property var panelScreen: null
 property string context: ""
 property string message: ""
 property bool dnd: false
 property bool barVisible: true
 property string menuKind: "root"
 property string controlsPage: "main"
 // Settings window state; the window is created on first open.
 property bool settingsOpen: false
 property string settingsSection: "island"
 function openSettings(section) { if (section) settingsSection = section; settingsOpen = true; panel = "" }
 // Expanded island dashboard, shown on one screen at a time.
 property string islandScreen: ""
 function focusedScreen() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "") }
 property string islandView: "dashboard"
 function toggleIsland(screen) { const target=screen || focusedScreen(); const close=islandScreen===target && islandView==="dashboard"; islandView="dashboard"; islandScreen=close ? "" : target; if(islandScreen) panel="" }
 function toggleCalendar(screen) { const target=screen || focusedScreen(); const close=islandScreen===target && islandView==="calendar"; islandView="calendar"; islandScreen=close ? "" : target; if(islandScreen) panel="" }
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
  saver.command=[Paths.workflow,"bar-set",String(barVisible)]
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
  // The calendar is an island state, not an overlay panel.
  if (name === "clock") { toggleCalendar(""); return }
  // Connections live inside the control center; appearance lives in Settings.
  if (name === "connectivity") { controlsPage = "wifi"; name = "controls"; if (panel === "controls") { return } }
  if (name === "appearance") { openSettings("appearance"); return }
  panelScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  panel = panel === name ? "" : name
  if (panel) islandScreen = ""
 }
 function close() { panel = "" }
 function osd(kind) { context = kind; if (kind === "brightness") Brightness.refresh(); root.timeout.restart() }
 function inform(text) { message = text; context = "message"; root.timeout.restart() }
 property Timer timeout: Timer { interval: 2500; onTriggered: { root.context = ""; root.message = "" } }
}
