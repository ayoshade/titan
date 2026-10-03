pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
// User settings. Defaults and validation come from theme/settings-schema.json;
// values live outside Git in $XDG_STATE_HOME/titan/settings.json. The Settings
// app and `scripts/workflow settings get|set` edit the same file.
QtObject {
 id: root
 readonly property var schema: JSON.parse(schemaFile.text() || "{\"sections\":[],\"settings\":{}}")
 readonly property var defaults: { const d={}; for(const k in schema.settings) d[k]=schema.settings[k].default; return d }
 property var stored: ({})
 readonly property var values: Object.assign({},defaults,stored)
 readonly property string path: (Quickshell.env("XDG_STATE_HOME")||Quickshell.env("HOME")+"/.local/state")+"/titan/settings.json"
 function valid(key,value) {
  const s=schema.settings[key]; if(!s) return false
  if(s.type==="bool") return typeof value==="boolean"
  if(s.type==="int") return Number.isInteger(value) && value>=s.min && value<=s.max
  if(s.type==="choice") return s.options.includes(value)
  if(s.type==="color") return value==="" || /^#[0-9a-fA-F]{6}$/.test(value)
  if(s.type==="string") return typeof value==="string" && value.length<=64
  if(s.type==="map") return typeof value==="object" && value!==null
  return false
 }
 function set(key,value) {
  if(!valid(key,value)) { console.warn("Rejected setting",key); return false }
  const next=Object.assign({},stored); next[key]=value; stored=next
  file.setText(JSON.stringify(stored,null,2)+"\n")
  return true
 }
 function reset(key) { const next=Object.assign({},stored); delete next[key]; stored=next; file.setText(JSON.stringify(stored,null,2)+"\n") }
 property FileView schemaFile: FileView { path: Qt.resolvedUrl("settings-schema.json"); blockLoading: true }
 property FileView file: FileView {
  path: root.path
  watchChanges: true
  atomicWrites: true
  __printErrors: false
  onFileChanged: reload()
  onLoaded: {
   try {
    const raw=JSON.parse(text()||"{}"), clean={}
    for(const k in raw) if(root.valid(k,raw[k])) clean[k]=raw[k]
    root.stored=clean
   } catch(e) { console.warn("Invalid settings file:",e) }
  }
 }
}
