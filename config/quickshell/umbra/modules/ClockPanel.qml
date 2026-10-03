pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../theme"
ColumnLayout {
 id: root
 SystemClock { id: clock; precision: SystemClock.Minutes }
 readonly property var first: new Date(clock.date.getFullYear(),clock.date.getMonth(),1)
 readonly property int offset: (first.getDay()+6)%7
 readonly property int days: new Date(clock.date.getFullYear(),clock.date.getMonth()+1,0).getDate()
 spacing: 12
 ShellText { text: Qt.formatDateTime(clock.date,"HH:mm"); font.pixelSize: 46; font.weight: Font.Light; Layout.alignment: Qt.AlignHCenter }
 ShellText { text: Qt.formatDateTime(clock.date,"dddd, d MMMM"); color: Theme.muted; Layout.alignment: Qt.AlignHCenter }
 GridLayout {
  Layout.fillWidth: true; Layout.fillHeight: true; columns: 7; rowSpacing: 3; columnSpacing: 3
  Repeater { model: ["M","T","W","T","F","S","S"]; ShellText { required property string modelData; text: modelData; color: Theme.muted; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true } }
  Repeater {
   model: 35+(root.offset+root.days>35 ? 7 : 0)
   Rectangle {
    required property int index
    readonly property int day: index-root.offset+1
    Layout.fillWidth: true; implicitHeight: 26; radius: 13
    color: day===clock.date.getDate() ? Theme.accent : "transparent"
    ShellText { anchors.centerIn: parent; text: parent.day>0 && parent.day<=root.days ? parent.day : ""; color: parent.day===clock.date.getDate() ? Theme.shell : Theme.text }
   }
  }
 }
}
