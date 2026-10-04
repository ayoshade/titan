pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
// Optional user extensions. Code loads only after an explicit enable operation.
Scope {
 id: root
 property var entries: []
 readonly property var context: ({
  colors: { background: Theme.background, surface: Theme.surface, text: Theme.text, muted: Theme.muted, accent: Theme.accent },
  fontSize: Theme.fontSize,
  reducedMotion: !Theme.animate
 })
 property FileView registry: FileView {
  path: (Quickshell.env("XDG_STATE_HOME")||Quickshell.env("HOME")+"/.local/state")+"/titan/generated/plugins.json"
  watchChanges: true
  __printErrors: false
  onFileChanged: reload()
  onLoaded: {
   try { const value=JSON.parse(text()||"[]"); root.entries=Array.isArray(value) ? value : [] }
   catch(e) { console.warn("Titan plugin registry:",e); root.entries=[] }
  }
 }
 Variants {
  model: root.entries
  delegate: Loader {
   id: loader
   required property var modelData
   asynchronous: true
   source: modelData.source || ""
   onLoaded: {
    if(item && "titanContext" in item) item.titanContext=Qt.binding(()=>root.context)
   }
   onStatusChanged: if(status===Loader.Error) console.warn("Titan plugin failed:",modelData.id)
  }
 }
}
