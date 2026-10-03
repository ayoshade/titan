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
 function move(delta) { if(!results.length) return; selectedIndex=Math.max(0,Math.min(results.length-1,selectedIndex+delta)) }
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
   onTextChanged: root.selectedIndex=0
   Keys.onLeftPressed: root.move(-1)
   Keys.onRightPressed: root.move(1)
   Keys.onDownPressed: root.move(1)
   Keys.onUpPressed: root.move(-1)
   Keys.onEscapePressed: UiState.close()
   onAccepted: root.apply()
   Component.onCompleted: { root.selectedIndex=Math.max(0,root.results.findIndex(p=>p.id===Theme.paletteName)); cards.positionViewAtIndex(root.selectedIndex,ListView.Center); forceActiveFocus() }
  }
  ShellText { text: root.results.length ? (root.selectedIndex+1)+"/"+root.results.length : "0/0"; color: Theme.muted; font.pixelSize: Theme.captionSize }
 }
 ListView {
  id: cards
  Layout.fillWidth: true; Layout.fillHeight: true
  orientation: ListView.Horizontal; clip: true; spacing: 10
  model: root.results
  // The selected card stays centred, as in the reference carousel.
  currentIndex: root.selectedIndex
  highlightRangeMode: ListView.StrictlyEnforceRange
  preferredHighlightBegin: (width-150)/2; preferredHighlightEnd: (width+150)/2
  highlightMoveDuration: Theme.movement
  onCurrentIndexChanged: root.selectedIndex=currentIndex
  delegate: Rectangle {
   id: tile
   required property var modelData
   required property int index
   width: 150; height: cards.height
   radius: Theme.radius-2
   color: modelData.surface
   border.width: root.selectedIndex===index ? 2 : 0
   border.color: Theme.accent
   opacity: root.selectedIndex===index ? 1 : 0.75
   Behavior on opacity { NumberAnimation { duration: Theme.duration } }
   Behavior on border.color { ColorAnimation { duration: Theme.duration } }
   Column {
    anchors.centerIn: parent; spacing: 14
    Row {
     anchors.horizontalCenter: parent.horizontalCenter; spacing: 5
     Repeater { model: tile.modelData.swatches.slice(0,6); Rectangle { required property string modelData; width: 12; height: 12; radius: 6; color: modelData } }
    }
    ShellText { text: tile.modelData.id; width: tile.width-12; horizontalAlignment: Text.AlignHCenter; color: tile.modelData.text; font.pixelSize: Theme.captionSize }
   }
   Rectangle { visible: Theme.paletteName===tile.modelData.id; anchors { right: parent.right; top: parent.top; margins: 7 } width: 6; height: 6; radius: 3; color: Theme.accent }
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
  ShellText { text: Theme.applyError || (root.results.length ? "" : "No matching themes"); color: Theme.applyError ? Theme.danger : Theme.muted; font.pixelSize: Theme.captionSize; Layout.fillWidth: true }
  Action { text: Theme.applying ? "Applying…" : "Enter to apply"; enabled: !!root.chosen && !Theme.applying; implicitHeight: 22; onClicked: root.apply(); contentItem: ShellText { text: parent.text; font.pixelSize: Theme.captionSize; color: Theme.muted; horizontalAlignment: Text.AlignRight } }
 }
}
