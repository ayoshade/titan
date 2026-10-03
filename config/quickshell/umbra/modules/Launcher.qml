pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 id: root
 spacing: 12
 readonly property string search: query.text.toLowerCase().trim()
 function score(e) { const n=e.name.toLowerCase(); return n===search ? 0 : n.startsWith(search) ? 1 : n.includes(search) ? 2 : 3 }
 readonly property var results: DesktopEntries.applications.values.filter(e=>!e.noDisplay && (e.name+" "+e.genericName+" "+e.comment).toLowerCase().includes(search)).sort((a,b)=>score(a)-score(b) || a.name.localeCompare(b.name))
 function launch(entry) { if(entry) { entry.execute(); UiState.close() } }
 RowLayout {
  Layout.fillWidth: true; spacing: 10
  ShellIcon { name: "search"; size: 18; opacity: 0.5 }
  TextField {
   id: query; Layout.fillWidth: true; placeholderText: "Search applications…"; placeholderTextColor: Theme.muted
   color: Theme.text; font.family: Theme.sans; font.pixelSize: 16
   selectByMouse: true
   background: Item {}
   onTextChanged: apps.currentIndex=0
   Keys.onDownPressed: apps.currentIndex=Math.min(apps.count-1,apps.currentIndex+1)
   Keys.onUpPressed: apps.currentIndex=Math.max(0,apps.currentIndex-1)
   onAccepted: root.launch(root.results[apps.currentIndex])
   Component.onCompleted: forceActiveFocus()
  }
  ShellText { text: root.results.length; font.pixelSize: Theme.captionSize; color: Theme.muted }
 }
 Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
 ListView {
  id: apps; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
  model: root.results; spacing: 4; currentIndex: 0
  delegate: Action {
   id: entry
   required property var modelData
   required property int index
   width: apps.width; implicitHeight: Settings.values.launcherDescriptions ? 58 : 44; selected: apps.currentIndex===index
   contentItem: RowLayout {
    spacing: 12
    Rectangle {
     implicitWidth: 36; implicitHeight: 36; radius: 10; color: Theme.border
     Image { anchors.centerIn: parent; width: 24; height: 24; source: entry.modelData.icon.startsWith("/") ? "file://"+entry.modelData.icon : Quickshell.hasThemeIcon(entry.modelData.icon) ? Quickshell.iconPath(entry.modelData.icon) : Qt.resolvedUrl("../assets/icons/apps.svg"); sourceSize.width: 48; sourceSize.height: 48 }
    }
    ColumnLayout {
     spacing: 3; Layout.fillWidth: true
     ShellText { text: entry.modelData.name; Layout.fillWidth: true; font.weight: Font.Medium }
     ShellText { visible: Settings.values.launcherDescriptions; text: entry.modelData.genericName || entry.modelData.comment || "Application"; Layout.fillWidth: true; color: Theme.muted; font.pixelSize: Theme.captionSize }
    }
    ShellText { visible: entry.selected; text: "↵"; color: Theme.muted }
   }
   onClicked: root.launch(modelData)
  }
 }
 ShellText { text: apps.count===0 ? "No matching applications" : "↑ ↓  navigate     ↵  open     esc  close"; color: Theme.muted; font.pixelSize: Theme.captionSize }
}
