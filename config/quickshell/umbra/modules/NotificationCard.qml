pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../components"
import "../theme"
// Notification card in the control-center style: app avatar, app name, bold
// summary, muted body, dismiss button and action chips.
Rectangle {
 id: root
 required property var notification
 property bool compact: false
 implicitHeight: content.implicitHeight+20
 radius: Theme.radius
 color: Qt.alpha(Theme.text,0.05)
 Rectangle {
  id: avatar
  x: 10; y: 10; width: 30; height: 30; radius: 15; color: Qt.alpha(Theme.accent,0.22); clip: true
  ShellText { visible: icon.status!==Image.Ready; anchors.centerIn: parent; text: (root.notification.appName||"N").charAt(0).toUpperCase(); color: Theme.accent; font.weight: Font.DemiBold }
  Image {
   id: icon; anchors.fill: parent; anchors.margins: 4; asynchronous: true
   source: { const i=root.notification.appIcon||""; return i.startsWith("/") ? "file://"+i : i.startsWith("file:") || i.startsWith("image:") ? i : i && Quickshell.hasThemeIcon(i) ? Quickshell.iconPath(i) : "" }
   sourceSize.width: 44; sourceSize.height: 44
  }
 }
 Column {
  id: content
  anchors { left: avatar.right; leftMargin: 10; right: close.left; rightMargin: 6; top: parent.top; topMargin: 10 }
  spacing: 2
  ShellText { width: parent.width; text: root.notification.appName || "Notification"; color: Theme.muted; font.pixelSize: Theme.captionSize }
  ShellText { width: parent.width; text: root.notification.summary; font.weight: Font.DemiBold; wrapMode: root.compact ? Text.NoWrap : Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2 }
  ShellText { width: parent.width; visible: text.length>0; text: root.notification.body; color: Theme.muted; wrapMode: root.compact ? Text.NoWrap : Text.Wrap; elide: Text.ElideRight; maximumLineCount: root.compact ? 1 : 4 }
  Flow {
   visible: !root.compact && root.notification.actions.length>0
   width: parent.width; spacing: 6; topPadding: 4
   Repeater {
    model: root.notification.actions
    Rectangle {
     id: chip
     required property var modelData
     width: chipText.implicitWidth+22; height: 26; radius: 13
     color: Qt.alpha(Theme.text,chipMouse.containsMouse ? 0.13 : 0.08)
     ShellText { id: chipText; anchors.centerIn: parent; text: chip.modelData.text; font.pixelSize: Theme.captionSize+1; font.weight: Font.Medium }
     MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.modelData.invoke() }
     Accessible.role: Accessible.Button; Accessible.name: modelData.text
    }
   }
  }
 }
 IconButton { id: close; anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 6 } symbol: "close"; label: "Dismiss"; size: 24; onClicked: root.notification.dismiss() }
}
