pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 spacing: Theme.padding
 RowLayout {
  ShellText { text: "Notifications"; font.pixelSize: Theme.titleSize; Layout.fillWidth: true }
  Action { text: UiState.dnd ? "DND on" : "DND off"; selected: UiState.dnd; onClicked: UiState.dnd=!UiState.dnd }
  Action { text: "Clear"; onClicked: Notices.dismissAll() }
 }
 ShellText { text: "All quiet."; visible: Notices.items.values.length===0; color: Theme.muted }
 ScrollView {
  Layout.fillWidth: true; Layout.fillHeight: true; clip: true
  ColumnLayout {
   width: parent.width; spacing: Theme.gap
   Repeater { model: Notices.items; NotificationCard { required property var modelData; notification: modelData; Layout.fillWidth: true } }
  }
 }
}
