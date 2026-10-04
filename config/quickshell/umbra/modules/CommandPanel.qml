pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../services"
import "../theme"
// Titan menus (Super+Space and friends) in the reference launcher style. Menu
// definitions live in assets/menus.json; dynamic lists come from bin/workflow.
SearchMenu {
 id: root
 property var entries: []
 property string result: ""
 property bool busy: false
 property string readerKind: ""
 readonly property string kind: UiState.menuKind
 readonly property var definitions: JSON.parse(menuCatalog.text()||"{}")
 FileView { id: menuCatalog; path: Qt.resolvedUrl("../assets/menus.json"); blockLoading: true }
 readonly property var definition: (definitions && definitions[kind]) || {title:kind,items:[]}
 readonly property bool inputMode: !!definition.input
 // Default row icons by action when a menu item does not name one.
 readonly property var actionIcons: ({ panel:"apps", menu:"chevron-right", capture:"capture", app:"apps", controls:"controls", settings:"settings", nightlight:"moon", dnd:"focus", bar:"island", gaps:"island", square:"island", desktop:"monitor", transparency:"palette", touchpad:"controls", mirror:"monitor", wallpaper:"palette", policy:"lock", "copy-text":"check", "clipboard-paste":"check" })
 title: definition.title || ""
 placeholder: inputMode ? definition.input : "Search…"
 keyMode: kind==="keybindings" || kind==="tmux-help" || kind==="herdr-help"
 maxRows: keyMode ? 12 : 10
 readonly property string query: text.toLowerCase()
 items: inputMode ? [] : entries.filter(e=>(e.label+" "+(e.detail||"")).toLowerCase().includes(query)).map(e=>{
  if(keyMode) return {label:e.detail||e.label, keys:(e.detail ? e.label : "").split("+").filter(k=>k), source:e}
  return {label:e.label, detail:e.detail||"", icon:e.icon||actionIcons[e.action]||"chevron-right", glyph:e.glyph||"", source:e}
 })
 onActivated: (item,index)=>{ if(item) execute(item.source.action,item.source.value) }
 onSubmitted: submit()
 function load() {
  if(!definition) return
  result=""; text=""; entries=definition.items||[]
  if(kind==="keybindings") fetch("keybindings")
  if(kind==="clipboard") fetch("clipboard-list")
  if(kind==="reminders") fetch("reminder-list")
  if(kind==="worldclock") fetch("worldclock")
  if(kind==="emojis") emojiFile.reload()
 }
 function fetch(operation) { if(reader.running) return; readerKind=kind; reader.command=[Paths.workflow,operation]; reader.running=true }
 function execute(action,value) {
  if(!action || action==="none") return
  if(action==="close") { UiState.close(); return }
  if(action==="menu") { UiState.menuKind=value; load(); return }
  if(action==="panel") { UiState.toggle(value); return }
  if(action==="controls") { UiState.controlsPage=value||"main"; UiState.toggle("controls"); return }
  if(action==="settings") { UiState.openSettings(value||""); return }
  if(action==="bar") { UiState.barVisible=!UiState.barVisible; UiState.saveShell(); return }
  if(action==="dnd") { UiState.dnd=!UiState.dnd; return }
  if(action==="wallpaper") { Settings.set("wallpaperEnabled",value==="on"); UiState.close(); return }
  const command=[Paths.workflow,action].concat(value===undefined ? [] : [value])
  if(!inputMode) { Quickshell.execDetached(command); UiState.close(); return }
  runner.command=command; runner.running=true
 }
 function submit() {
  const operation={calculator:"calculator",reminder:"reminder-set",transcode:"transcode",weather:"weather"}[kind]
  if(!operation || runner.running) return
  busy=true; execute(operation,text)
 }
 Component.onCompleted: load()
 onKindChanged: Qt.callLater(load)
 Process {
  id: reader
  onExited: (code,status)=>{ if(root.kind!==root.readerKind) Qt.callLater(root.load) }
  stdout: StdioCollector { onStreamFinished: { try { if(root.kind===root.readerKind) root.entries=JSON.parse(text) } catch(e) { root.result="No items available" } } }
  stderr: StdioCollector { onStreamFinished: { if(text.trim()) root.result="Required tool is unavailable. Run "+Paths.script("install-workflow")+"." } }
 }
 Process {
  id: runner
  stdout: StdioCollector { onStreamFinished: { if(root.kind==="calculator") root.result=text.trim() } }
  stderr: StdioCollector { onStreamFinished: { if(text.trim()) root.result=text.trim() } }
  onExited: (code,status) => { root.busy=false; if(code===0 && root.kind==="reminder") root.result="Reminder set" }
 }
 FileView {
  id: emojiFile; path: Qt.resolvedUrl("../assets/emojis.json")
  onLoaded: { if(root.kind==="emojis") root.entries=JSON.parse(text()).map(e=>({label:e.name,glyph:e.symbol,action:"copy-text",value:e.symbol})) }
 }
 SystemClock { id: clock; precision: SystemClock.Minutes; enabled: root.kind==="worldclock"; onDateChanged: { if(root.kind==="worldclock") root.fetch("worldclock") } }
 // Footer: input feedback and per-menu actions.
 footerItems: [
  ShellText { visible: root.inputMode || root.result!==""; width: parent ? parent.width : 0; text: root.busy ? "Working…" : root.result || "Enter to submit · Escape to close"; wrapMode: Text.Wrap; color: root.result ? Theme.text : Theme.muted; font.pixelSize: root.kind==="calculator" && root.result ? Theme.subtitleSize+4 : Theme.fontSize },
  Action { visible: root.kind==="calculator" && root.result!==""; text: "Copy result"; onClicked: root.execute("copy-text",root.result) },
  Action { visible: root.kind==="clipboard"; text: "Clear clipboard history"; onClicked: { root.execute("clipboard-clear"); root.entries=[] } },
  ShellText { visible: !root.inputMode && root.items.length===0; text: root.entries.length ? "No matches" : "No items yet"; color: Theme.muted }
 ]
}
