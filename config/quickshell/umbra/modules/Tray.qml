pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
Row {
 id: root
 required property var bar
 spacing: 8
 Repeater {
  model: SystemTray.items
  Item {
   id: cell
   required property var modelData
   width: 24; height: 32
   Image { anchors.centerIn: parent; width: 18; height: 18; source: cell.modelData.icon; sourceSize.width: 18; sourceSize.height: 18 }
   MouseArea {
    anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: event => {
     const point=cell.mapToItem(root.bar.contentItem,0,cell.height)
     if(event.button===Qt.RightButton || cell.modelData.onlyMenu) cell.modelData.display(root.bar,point.x,point.y)
     else if(event.button===Qt.MiddleButton) cell.modelData.secondaryActivate()
     else cell.modelData.activate()
    }
    onWheel: event => cell.modelData.scroll(event.angleDelta.y,false)
   }
  }
 }
}
