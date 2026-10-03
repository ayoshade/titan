pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 id: root
 spacing: 12
 property var entries: []
 property string result: ""
 property bool busy: false
 property string readerKind: ""
 readonly property string kind: UiState.menuKind
 readonly property var definitions: JSON.parse(menuCatalog.text()||"{}")
 FileView { id: menuCatalog; path: Qt.resolvedUrl("../assets/menus.json"); blockLoading: true }
 readonly property var definition: (definitions && definitions[kind]) || {title:kind,items:[]}
 readonly property bool inputMode: !!definition.input
 readonly property var filtered: entries.filter(e=>(e.label+" "+(e.detail||"")).toLowerCase().includes(query.text.toLowerCase()))
 function load() {
  if(!definition) return
  result=""; query.text=""; entries=definition.items||[]
  if(kind==="keybindings") fetch("keybindings")
  if(kind==="clipboard") fetch("clipboard-list")
  if(kind==="reminders") fetch("reminder-list")
  if(kind==="worldclock") fetch("worldclock")
  if(kind==="emojis") emojiFile.reload()
 }
 function fetch(operation) { if(reader.running) return; readerKind=kind; reader.command=[Quickshell.env("HOME")+"/dotfiles/scripts/workflow",operation]; reader.running=true }
 function execute(action,value) {
  if(!action || action==="none") return
  if(action==="close") { UiState.close(); return }
  if(action==="menu") { UiState.menuKind=value; load(); return }
  if(action==="panel") { UiState.toggle(value); return }
  if(action==="bar") { UiState.barVisible=!UiState.barVisible; UiState.saveShell(); return }
  if(action==="dnd") { UiState.dnd=!UiState.dnd; return }
  if(action==="wallpaper") { Theme.wallpaperEnabled=value==="on"; Theme.save(); UiState.close(); return }
  const command=[Quickshell.env("HOME")+"/dotfiles/scripts/workflow",action].concat(value===undefined ? [] : [value])
  if(!inputMode) { Quickshell.execDetached(command); UiState.close(); return }
  runner.command=command; runner.running=true
 }
 function submit() {
  const operation={calculator:"calculator",reminder:"reminder-set",transcode:"transcode",weather:"weather"}[kind]
  if(!operation || runner.running) return
  busy=true; execute(operation,query.text)
 }
 Component.onCompleted: { load(); query.forceActiveFocus() }
 onKindChanged: Qt.callLater(load)
 Process {
  id: reader
  onExited: (code,status)=>{ if(root.kind!==root.readerKind) Qt.callLater(root.load) }
  stdout: StdioCollector { onStreamFinished: { try { if(root.kind===root.readerKind) root.entries=JSON.parse(text) } catch(e) { root.result="No items available" } } }
  stderr: StdioCollector { onStreamFinished: { if(text.trim()) root.result="Required tool is unavailable. Run ~/dotfiles/scripts/install-workflow." } }
 }
 Process {
  id: runner
  stdout: StdioCollector { onStreamFinished: { if(root.kind==="calculator") root.result=text.trim() } }
  stderr: StdioCollector { onStreamFinished: { if(text.trim()) root.result=text.trim() } }
  onExited: (code,status) => { root.busy=false; if(code===0 && root.kind==="reminder") root.result="Reminder set" }
 }
 FileView {
  id: emojiFile; path: Quickshell.env("HOME")+"/dotfiles/config/quickshell/umbra/assets/emojis.json"
  onLoaded: { if(root.kind==="emojis") root.entries=JSON.parse(text()).map(e=>({label:e.symbol+"  "+e.name,action:"copy-text",value:e.symbol})) }
 }
 SystemClock { id: clock; precision: SystemClock.Minutes; enabled: root.kind==="worldclock"; onDateChanged: { if(root.kind==="worldclock") root.fetch("worldclock") } }

 ShellText { text: root.definition.title; font.pixelSize: 20; font.weight: Font.Medium; Layout.fillWidth: true }
 TextField {
  id: query; Layout.fillWidth: true; placeholderText: root.inputMode ? root.definition.input : "Search…"
  color: Theme.text; placeholderTextColor: Theme.muted; font.family: Theme.sans; selectByMouse: true
  background: Rectangle { color: Theme.raised; radius: 10 }
  onTextChanged: list.currentIndex=0
  Keys.onDownPressed: list.currentIndex=Math.min(list.count-1,list.currentIndex+1)
  Keys.onUpPressed: list.currentIndex=Math.max(0,list.currentIndex-1)
  onAccepted: root.inputMode ? root.submit() : root.execute(root.filtered[list.currentIndex]?.action,root.filtered[list.currentIndex]?.value)
 }
 ShellText { visible: root.inputMode || root.result!==""; text: root.busy ? "Working…" : root.result || "Enter to submit · Escape to close"; wrapMode: Text.Wrap; Layout.fillWidth: true; color: Theme.muted }
 Action { visible: root.kind==="calculator" && root.result!==""; text: "Copy result"; onClicked: root.execute("copy-text",root.result) }
 Action { visible: root.kind==="clipboard"; text: "Clear clipboard history"; onClicked: { root.execute("clipboard-clear"); root.entries=[] } }
 ShellText { visible: !root.inputMode && root.kind!=="worldclock" && root.filtered.length===0; text: "No items yet"; color: Theme.muted }
 ListView {
  id: list; visible: !root.inputMode && root.kind!=="worldclock"; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4; currentIndex: 0
  model: root.filtered
  delegate: Action {
   required property var modelData; required property int index
   width: list.width; implicitHeight: 62; selected: index===list.currentIndex
   contentItem: ColumnLayout {
    spacing: 3
    ShellText { text: modelData.label; Layout.fillWidth: true; font.weight: Font.Medium }
    ShellText { text: modelData.detail||""; visible: text!==""; Layout.fillWidth: true; color: Theme.muted; font.pixelSize: Theme.captionSize }
   }
   onClicked: root.execute(modelData.action,modelData.value)
  }
 }
 ColumnLayout {
  visible: root.kind==="worldclock"; Layout.fillWidth: true
  Repeater {
   model: root.kind==="worldclock" ? root.entries : []
   RowLayout {
    required property var modelData; Layout.fillWidth: true
    ShellText { text: modelData.label; Layout.fillWidth: true }
    ShellText { text: modelData.detail||""; color: Theme.muted }
   }
  }
 }
 Item { visible: root.inputMode || root.kind==="worldclock"; Layout.fillHeight: true }
 ShellText { text: "↑ ↓  navigate     ↵  select     esc  close"; color: Theme.muted; font.pixelSize: Theme.captionSize }
}
