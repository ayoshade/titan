pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
Rectangle {
 id: root
 required property var notification
 implicitHeight: content.implicitHeight+24
 color: Theme.raised; radius: Theme.radius
 ColumnLayout {
  id: content
  anchors { fill: parent; margins: 12 }
  spacing: Theme.gap
  RowLayout {
   ShellText { text: root.notification.appName || "Notification"; color: Theme.muted; Layout.fillWidth: true }
   Action { text: "×"; onClicked: root.notification.dismiss() }
  }
  ShellText { text: root.notification.summary; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
  ShellText { text: root.notification.body; visible: text.length>0; Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
  Flow {
   Layout.fillWidth: true; height: childrenRect.height; spacing: 4
   Repeater { model: root.notification.actions; Action { required property var modelData; text: modelData.text; onClicked: modelData.invoke() } }
  }
 }
}
