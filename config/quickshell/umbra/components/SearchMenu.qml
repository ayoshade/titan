pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../theme"
// Searchable list in the reference launcher style (5cp6DkClAuM 0:48–0:53,
// J8s7O2IGogE 5:00): magnifier and "Search…", a hairline divider, compact rows
// with an icon tile, bold name and muted description; the selected row is
// lighter with an accent bar. Height follows the result count.
Item {
 id: root
 property var items: []            // [{label, detail, icon, iconSource, keys}]
 property string placeholder: "Search…"
 property string title: ""
 property int maxRows: 8
 property bool searchable: true
 property bool keyMode: false       // keybinding rows: description left, key chips right
 property alias text: field.text
 property alias currentIndex: list.currentIndex
 readonly property int rowHeight: keyMode ? 38 : 46
 signal activated(var item, int index)
 signal submitted(string text)
 implicitWidth: 460
 implicitHeight: header.height+1+(list.count ? Math.min(list.count,maxRows)*(rowHeight+2)+12 : 0)+footer.height
 function iconUrl(item) {
  if(item.iconSource) return item.iconSource.startsWith("/") ? "file://"+item.iconSource : Quickshell.hasThemeIcon(item.iconSource) ? Quickshell.iconPath(item.iconSource) : Qt.resolvedUrl("../assets/icons/apps.svg")
  return item.icon ? Qt.resolvedUrl("../assets/icons/"+item.icon+".svg") : ""
 }
 function focusSearch() { field.forceActiveFocus() }
 Item {
  id: header
  width: parent.width; height: 50
  ShellIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; opacity: 0.55 }
  TextField {
   id: field
   anchors { left: parent.left; leftMargin: 42; right: total.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
   placeholderText: root.title ? root.title+" · "+root.placeholder : root.placeholder
   placeholderTextColor: Theme.muted; color: Theme.text
   font.family: Theme.sans; font.pixelSize: Theme.fontSize+3
   background: Item {}
   selectByMouse: true
   onTextChanged: list.currentIndex=0
   Keys.onDownPressed: list.currentIndex=Math.min(list.count-1,list.currentIndex+1)
   Keys.onUpPressed: list.currentIndex=Math.max(0,list.currentIndex-1)
   Keys.onTabPressed: list.currentIndex=(list.currentIndex+1)%Math.max(1,list.count)
   onAccepted: list.count ? root.activated(root.items[list.currentIndex],list.currentIndex) : root.submitted(text)
   Component.onCompleted: forceActiveFocus()
  }
  ShellText { id: total; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: root.items.length || ""; color: Theme.muted; font.pixelSize: Theme.captionSize }
 }
 Rectangle { id: divider; anchors.top: header.bottom; x: 12; width: parent.width-24; height: 1; color: Qt.alpha(Theme.text,0.08) }
 ListView {
  id: list
  anchors { top: divider.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
  height: Math.min(list.count,root.maxRows)*(root.rowHeight+2)
  spacing: 2; clip: true; currentIndex: 0
  boundsBehavior: Flickable.StopAtBounds
  highlightMoveDuration: Theme.hover
  model: root.items
  delegate: Item {
   id: row
   required property var modelData
   required property int index
   readonly property bool selected: index===list.currentIndex
   width: list.width; height: root.rowHeight
   Rectangle {
    anchors.fill: parent; radius: Theme.radius-4
    color: row.selected ? Qt.alpha(Theme.text,0.08) : rowMouse.containsMouse ? Qt.alpha(Theme.text,0.04) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.hover } }
    Rectangle { visible: row.selected; x: 4; anchors.verticalCenter: parent.verticalCenter; width: 3; height: parent.height-18; radius: 1.5; color: Theme.accent }
   }
   Rectangle {
    id: tile
    visible: !root.keyMode
    x: 14; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 8
    color: Qt.alpha(Theme.text,0.06)
    ShellText { visible: !!row.modelData.glyph; anchors.centerIn: parent; text: row.modelData.glyph || ""; font.pixelSize: 16 }
    Image {
     visible: !row.modelData.glyph
     anchors.centerIn: parent
     readonly property bool themed: !!row.modelData.iconSource
     width: themed ? 22 : 15; height: width
     source: root.iconUrl(row.modelData) || Qt.resolvedUrl("../assets/icons/chevron-right.svg")
     sourceSize.width: width*2; sourceSize.height: height*2; asynchronous: true
     opacity: themed ? 1 : 0.85
    }
   }
   Column {
    anchors { left: parent.left; leftMargin: root.keyMode ? 16 : 54; right: keys.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
    spacing: 1
    ShellText { width: parent.width; text: row.modelData.label; font.pixelSize: Theme.fontSize+1; font.weight: root.keyMode ? Font.Normal : Font.DemiBold }
    ShellText { width: parent.width; visible: !root.keyMode && !!row.modelData.detail; text: row.modelData.detail || ""; color: Theme.muted; font.pixelSize: Theme.captionSize }
   }
   Row {
    id: keys
    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
    spacing: 4
    Repeater {
     model: row.modelData.keys || []
     Rectangle {
      required property string modelData
      width: Math.max(22,keyText.implicitWidth+12); height: 22; radius: 6
      color: Qt.alpha(Theme.text,0.07); border.width: 1; border.color: Qt.alpha(Theme.text,0.08)
      ShellText { id: keyText; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: Theme.captionSize; font.weight: Font.Medium }
     }
    }
   }
   MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { list.currentIndex=row.index; root.activated(row.modelData,row.index) } }
   Accessible.role: Accessible.ListItem; Accessible.name: modelData.label+(modelData.detail ? ", "+modelData.detail : "")+(modelData.keys ? ", "+modelData.keys.join(" ") : ""); Accessible.selected: selected; Accessible.onPressAction: root.activated(modelData,index)
  }
 }
 Item { id: footer; anchors.top: list.bottom; width: parent.width; height: footerContent.implicitHeight>0 ? footerContent.implicitHeight+12 : 0
  Column { id: footerContent; x: 16; y: 6; width: parent.width-32; spacing: 6 }
 }
 // Extra content under the list (results, actions); assign as a list.
 property alias footerItems: footerContent.data
}
