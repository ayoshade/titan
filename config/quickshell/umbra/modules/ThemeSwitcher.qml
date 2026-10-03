pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 id: root
 spacing: 12
 property int selectedIndex: 0
 readonly property var results: Theme.palettes.filter(p=>(p.id+" "+p.label).toLowerCase().includes(search.text.toLowerCase().trim()))
 readonly property var chosen: results[selectedIndex] || null
 function move(delta) { if(!results.length) return; selectedIndex=Math.max(0,Math.min(results.length-1,selectedIndex+delta)); cards.positionViewAtIndex(selectedIndex,ListView.Contain) }
 function apply() { if(chosen && Theme.apply(chosen.id)) UiState.close() }
 RowLayout {
  Layout.fillWidth: true; spacing: 8
  ShellIcon { name: "search"; size: 14; opacity: 0.5 }
  TextField {
   id: search
   Layout.fillWidth: true; implicitHeight: 24
   placeholderText: "Search themes…"; placeholderTextColor: Theme.muted
   color: Theme.text; font.family: Theme.sans; font.pixelSize: Theme.fontSize
   background: Item {}
   selectByMouse: true
   onTextChanged: { root.selectedIndex=0; cards.positionViewAtBeginning() }
   Keys.onLeftPressed: root.move(-1)
   Keys.onRightPressed: root.move(1)
   Keys.onDownPressed: root.move(1)
   Keys.onUpPressed: root.move(-1)
   Keys.onEscapePressed: UiState.close()
   onAccepted: root.apply()
   Component.onCompleted: { root.selectedIndex=Math.max(0,root.results.findIndex(p=>p.id===Theme.paletteName)); cards.positionViewAtIndex(root.selectedIndex,ListView.Contain); forceActiveFocus() }
  }
  ShellText { text: root.results.length ? (root.selectedIndex+1)+"/"+root.results.length : "0/0"; color: Theme.muted; font.pixelSize: Theme.captionSize }
 }
 ListView {
  id: cards
  Layout.fillWidth: true; Layout.fillHeight: true
  orientation: ListView.Horizontal; clip: true; spacing: 8
  model: root.results
  boundsBehavior: Flickable.StopAtBounds
  delegate: Rectangle {
   id: tile
   required property var modelData
   required property int index
   width: 126; height: cards.height
   radius: 12
   color: modelData.surface
   border.width: root.selectedIndex===index ? 2 : 1
   border.color: root.selectedIndex===index ? Theme.accent : modelData.raised
   Behavior on border.color { ColorAnimation { duration: Theme.duration } }
   Column {
    anchors.centerIn: parent; spacing: 16
    Row {
     anchors.horizontalCenter: parent.horizontalCenter; spacing: 3
     Repeater { model: tile.modelData.swatches; Rectangle { required property string modelData; width: 10; height: 10; radius: 5; color: modelData } }
    }
    ShellText { text: tile.modelData.id; width: tile.width-12; horizontalAlignment: Text.AlignHCenter; color: tile.modelData.text; font.pixelSize: Theme.captionSize }
   }
   Rectangle { visible: Theme.paletteName===tile.modelData.id; anchors { right: parent.right; top: parent.top; margins: 7 } width: 4; height: 4; radius: 2; color: tile.modelData.accent }
   MouseArea {
    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
    onClicked: { root.selectedIndex=tile.index; search.forceActiveFocus() }
    onDoubleClicked: { root.selectedIndex=tile.index; root.apply() }
    onWheel: event=>root.move(event.angleDelta.y<0 ? 1 : -1)
   }
   Accessible.role: Accessible.Button; Accessible.name: modelData.label; Accessible.onPressAction: { root.selectedIndex=tile.index; root.apply() }
  }
 }
 RowLayout {
  Layout.fillWidth: true
  ShellText { text: Theme.applyError || (root.results.length ? "← →  browse" : "No matching themes"); color: Theme.applyError ? Theme.danger : Theme.muted; font.pixelSize: Theme.captionSize; Layout.fillWidth: true }
  Action { text: Theme.applying ? "Applying…" : "Enter to apply"; enabled: !!root.chosen && !Theme.applying; implicitHeight: 22; onClicked: root.apply(); contentItem: ShellText { text: parent.text; font.pixelSize: Theme.captionSize; color: Theme.muted; horizontalAlignment: Text.AlignRight } }
 }
}
