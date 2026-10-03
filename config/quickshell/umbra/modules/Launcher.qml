pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../components"
import "../services"
import "../theme"
// Application launcher (Super+Alt+Space) in the reference style. Name matches
// rank ahead of description matches.
SearchMenu {
 id: root
 readonly property string search: text.toLowerCase().trim()
 function score(e) { const n=e.name.toLowerCase(); return n===search ? 0 : n.startsWith(search) ? 1 : n.includes(search) ? 2 : 3 }
 readonly property var entries: DesktopEntries.applications.values.filter(e=>!e.noDisplay && (e.name+" "+e.genericName+" "+e.comment).toLowerCase().includes(search)).sort((a,b)=>score(a)-score(b) || a.name.localeCompare(b.name))
 items: entries.map(e=>({label:e.name, detail:Settings.values.launcherDescriptions ? (e.genericName || e.comment || "") : "", iconSource:e.icon || "application-x-executable", entry:e}))
 placeholder: "Search…"
 maxRows: Settings.values.launcherResults
 onActivated: (item,index)=>{ if(item && item.entry) { item.entry.execute(); UiState.close() } }
 footerItems: [ ShellText { visible: root.items.length===0; text: "No matching applications"; color: Theme.muted } ]
}
