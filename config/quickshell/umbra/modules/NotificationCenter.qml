pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../components"
import "../services"
import "../theme"
// Notification history grouped by app, newest first. Each group shows its
// latest notification; "+N more" expands the rest.
Item {
 id: root
 property var expanded: ({})
 readonly property var groups: {
  const map={}, order=[]
  for(const n of Notices.items.values.slice().reverse()) { const k=n.appName||"Notification"; if(!map[k]) { map[k]=[]; order.push(k) } map[k].push(n) }
  return order.map(k=>({app:k, items:map[k]}))
 }
 Item {
  id: header
  width: parent.width; height: 36
  ShellText { anchors.verticalCenter: parent.verticalCenter; text: "Notifications"; font.family: Theme.display; font.pixelSize: Theme.subtitleSize+2; font.weight: Font.DemiBold }
  Row {
   anchors { right: parent.right; verticalCenter: parent.verticalCenter } spacing: 12
   ShellText { anchors.verticalCenter: parent.verticalCenter; text: "Do not disturb"; color: Theme.muted; font.pixelSize: Theme.captionSize+1 }
   Switch { anchors.verticalCenter: parent.verticalCenter; checked: UiState.dnd; label: "Do not disturb"; onToggled: UiState.dnd=!UiState.dnd }
   ShellText {
    visible: Notices.items.values.length>0; anchors.verticalCenter: parent.verticalCenter
    text: "Clear all"; color: clearMouse.containsMouse ? Theme.text : Theme.muted; font.pixelSize: Theme.captionSize+1
    MouseArea { id: clearMouse; anchors { fill: parent; margins: -4 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notices.dismissAll() }
   }
  }
 }
 ShellText { visible: root.groups.length===0; anchors.centerIn: parent; text: "You're all caught up"; color: Theme.muted }
 Flickable {
  anchors { fill: parent; topMargin: header.height+8 }
  contentHeight: list.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
  Column {
   id: list
   width: parent.width; spacing: 12
   Repeater {
    model: root.groups
    Column {
     id: group
     required property var modelData
     readonly property bool open: !!root.expanded[modelData.app]
     width: list.width; spacing: 6
     Item {
      width: parent.width; height: 20
      ShellText { anchors.verticalCenter: parent.verticalCenter; text: group.modelData.app; color: Theme.muted; font.pixelSize: Theme.captionSize+1; font.weight: Font.Medium }
      ShellText {
       visible: group.modelData.items.length>1
       anchors { right: parent.right; verticalCenter: parent.verticalCenter }
       text: group.open ? "Show less" : "+"+(group.modelData.items.length-1)+" more"; color: Theme.accent; font.pixelSize: Theme.captionSize+1
       MouseArea { anchors { fill: parent; margins: -4 } cursorShape: Qt.PointingHandCursor; onClicked: { const e=Object.assign({},root.expanded); e[group.modelData.app]=!group.open; root.expanded=e } }
      }
     }
     Repeater {
      model: group.open ? group.modelData.items : group.modelData.items.slice(0,1)
      NotificationCard { required property var modelData; notification: modelData; width: group.width }
     }
    }
   }
  }
 }
}
