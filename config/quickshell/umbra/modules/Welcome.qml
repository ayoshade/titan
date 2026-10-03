pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../services"
import "../theme"
// First-login welcome: a short "make it yours" checklist. Shown once for new
// users (no ~/.local/state/titan/welcome-done); reopen with `titan-shell ipc welcome`.
Item {
 id: root
 implicitWidth: 440
 implicitHeight: column.implicitHeight
 focus: true
 Keys.onEscapePressed: UiState.close()
 Component.onCompleted: forceActiveFocus()
 property string fetchState: ""
 Process {
  id: fetch
  command: [Paths.script("fetch-wallpapers"),"--count","12",Theme.paletteName]
  onExited: (code)=>root.fetchState=code===0 ? "done" : "failed"
 }
 component Step: Rectangle {
  id: step
  property string symbol
  property string title
  property string detail
  property string trailing: ""
  signal activated()
  width: column.width; height: 56; radius: Theme.radius
  color: Qt.alpha(Theme.text,stepMouse.containsMouse ? 0.09 : 0.05)
  Behavior on color { ColorAnimation { duration: Theme.hover } }
  Rectangle {
   x: 10; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; radius: 18; color: Qt.alpha(Theme.accent,0.18)
   ShellIcon { anchors.centerIn: parent; name: step.symbol; size: 16 }
  }
  Column {
   anchors { left: parent.left; leftMargin: 58; right: tail.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
   ShellText { width: parent.width; text: step.title; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSize+1 }
   ShellText { width: parent.width; text: step.detail; color: Theme.muted; font.pixelSize: Theme.captionSize }
  }
  ShellText { id: tail; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: step.trailing; color: Theme.muted; font.pixelSize: Theme.captionSize }
  MouseArea { id: stepMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: step.activated() }
  Accessible.role: Accessible.Button; Accessible.name: title+", "+detail; Accessible.onPressAction: activated()
 }
 Column {
  id: column
  width: parent.width; spacing: 8
  Column {
   width: parent.width; spacing: 6; bottomPadding: 6
   Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 120; height: 30; radius: 15; color: Theme.notch
    Row { anchors.centerIn: parent; spacing: 4
     Repeater { model: 5; Rectangle { required property int index; width: index===0 ? 7 : 5; height: index===0 ? 13 : 9; radius: width/2; anchors.verticalCenter: parent.verticalCenter; color: index===0 ? Theme.accent : Qt.alpha(Theme.text,0.2) } }
    }
   }
   ShellText { anchors.horizontalCenter: parent.horizontalCenter; text: "Welcome to Titan"; font.family: Theme.display; font.pixelSize: Theme.titleSize; font.weight: Font.DemiBold }
   ShellText { anchors.horizontalCenter: parent.horizontalCenter; text: "A few steps to make it yours. Everything here can change later."; color: Theme.muted }
  }
  Step { symbol: "palette"; title: "Pick a theme"; detail: "Colours for the shell, terminal and windows"; trailing: Theme.paletteName; onActivated: UiState.toggle("themes") }
  Step {
   symbol: "image"; title: "Get wallpapers"; detail: "Download a set for "+Theme.paletteName+" from Wallhaven"
   trailing: root.fetchState==="running" ? "Downloading…" : root.fetchState==="done" ? "Done ✓" : root.fetchState==="failed" ? "Failed, retry" : "12 images"
   onActivated: { if(fetch.running) return; root.fetchState="running"; fetch.running=true }
  }
  Step { symbol: "wifi"; title: "Connect to Wi-Fi"; detail: "Networks, Bluetooth and sound live in the control center"; onActivated: UiState.toggle("connectivity") }
  Step { symbol: "keyboard"; title: "Learn the keys"; detail: "Super+Space opens everything; Super+K lists every shortcut"; onActivated: UiState.menu("keybindings") }
  Step { symbol: "settings"; title: "Make it yours"; detail: "Island, fonts, motion and more in Settings"; onActivated: UiState.openSettings("appearance") }
  Item {
   width: parent.width; height: 48
   Rectangle {
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    width: startText.implicitWidth+36; height: 36; radius: 18; color: startMouse.containsMouse ? Qt.lighter(Theme.accent,1.1) : Theme.accent
    ShellText { id: startText; anchors.centerIn: parent; text: "Get started"; color: Theme.notch; font.weight: Font.DemiBold }
    MouseArea { id: startMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: UiState.finishWelcome() }
    Accessible.role: Accessible.Button; Accessible.name: "Get started"; Accessible.onPressAction: UiState.finishWelcome()
   }
   ShellText { anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } text: "Reopen any time: titan-shell ipc welcome"; color: Theme.muted; font.pixelSize: Theme.captionSize }
  }
 }
}
