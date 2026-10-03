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
 spacing: Theme.padding
 readonly property var results: DesktopEntries.applications.values.filter(e => !e.noDisplay && (e.name+" "+e.genericName+" "+e.comment).toLowerCase().includes(query.text.toLowerCase())).sort((a,b) => a.name.localeCompare(b.name))
 function launch(entry) { if(entry) { entry.execute(); UiState.close() } }
 ShellText { text: "UMBRA / APPLICATIONS"; font.family: Theme.mono; color: Theme.muted }
 TextField {
  id: query; Layout.fillWidth: true; placeholderText: "Search applications…"; placeholderTextColor: Theme.muted
  color: Theme.text; font.family: Theme.sans; font.pixelSize: Theme.titleSize
  selectByMouse: true
  background: Rectangle { color: Theme.raised; radius: Theme.radius; border.color: query.activeFocus ? Theme.accent : Theme.border }
  onTextChanged: apps.currentIndex=0
  Keys.onDownPressed: apps.currentIndex=Math.min(apps.count-1,apps.currentIndex+1)
  Keys.onUpPressed: apps.currentIndex=Math.max(0,apps.currentIndex-1)
  onAccepted: root.launch(root.results[apps.currentIndex])
  Component.onCompleted: forceActiveFocus()
 }
 ListView {
  id: apps; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
  model: root.results; spacing: Theme.small; currentIndex: 0
  delegate: Action {
   required property var modelData
   required property int index
   width: apps.width; implicitHeight: 42
   text: modelData.name; selected: apps.currentIndex===index
   onClicked: root.launch(modelData)
  }
 }
 ShellText { text: "↑ ↓  navigate    ENTER  launch    ESC  close"; color: Theme.muted; font.family: Theme.mono }
}
