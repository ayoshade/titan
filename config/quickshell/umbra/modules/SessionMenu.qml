pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
// Session menu (Super+Escape, or hold the control center's Lock button). The
// reference keeps power actions inside the control center, so this uses the
// same tiles; destructive actions confirm inline. Keys: L, E, R, P.
Item {
 id: root
 property string pending: ""
 implicitWidth: 380
 implicitHeight: column.implicitHeight
 focus: true
 Component.onCompleted: forceActiveFocus()
 Keys.onPressed: event=>{
  const map={[Qt.Key_L]:"lock",[Qt.Key_E]:"logout",[Qt.Key_R]:"reboot",[Qt.Key_P]:"poweroff"}
  if(map[event.key]) { choose(map[event.key]); event.accepted=true }
  else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter) { if(pending) confirm(); event.accepted=true }
 }
 Keys.onEscapePressed: pending ? pending="" : UiState.close()
 readonly property var labels: ({ logout:"Log out", reboot:"Reboot", poweroff:"Power off" })
 function choose(action) {
  if(action==="lock") { Quickshell.execDetached([Quickshell.env("HOME")+"/dotfiles/scripts/lock"]); UiState.close(); return }
  pending=pending===action ? "" : action
 }
 function confirm() {
  if(pending==="logout") Hyprland.dispatch("hl.dsp.exit()")
  else if(pending) Quickshell.execDetached(["systemctl",pending==="reboot" ? "reboot" : "poweroff"])
  UiState.close()
 }
 FileView { id: hostname; path: "/etc/hostname" }
 Column {
  id: column
  width: parent.width; spacing: 10
  Item {
   width: parent.width; height: 46
   Rectangle {
    id: avatar
    anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 20; color: Qt.alpha(Theme.accent,0.22)
    ShellText { anchors.centerIn: parent; text: (Quickshell.env("USER")||"?").charAt(0).toUpperCase(); color: Theme.accent; font.pixelSize: Theme.subtitleSize+2; font.weight: Font.DemiBold }
   }
   Column {
    anchors { left: avatar.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
    ShellText { text: (Quickshell.env("USER")||"")+"@"+(hostname.text().trim()||"localhost"); font.pixelSize: Theme.fontSize+2; font.weight: Font.DemiBold }
    ShellText { text: "Always awake · "+(PowerProfiles.profile===PowerProfile.Performance ? "Performance" : PowerProfiles.profile===PowerProfile.PowerSaver ? "Power saver" : "Balanced"); color: Theme.muted; font.pixelSize: Theme.captionSize }
   }
  }
  Grid {
   columns: 2; spacing: 8
   readonly property int cell: (column.width-8)/2
   Tile { width: parent.cell; symbol: "lock"; title: "Lock"; subtitle: "L"; onClicked: root.choose("lock") }
   Tile { width: parent.cell; symbol: "logout"; title: "Log out"; subtitle: root.pending==="logout" ? "Confirm below" : "E"; on: root.pending==="logout"; onClicked: root.choose("logout") }
   Tile { width: parent.cell; symbol: "refresh"; title: "Reboot"; subtitle: root.pending==="reboot" ? "Confirm below" : "R"; on: root.pending==="reboot"; onClicked: root.choose("reboot") }
   Tile { width: parent.cell; symbol: "power"; title: "Power off"; subtitle: root.pending==="poweroff" ? "Confirm below" : "P"; on: root.pending==="poweroff"; onClicked: root.choose("poweroff") }
  }
  Rectangle {
   visible: root.pending!==""
   width: parent.width; height: 48; radius: height/2; color: Qt.alpha(Theme.danger,0.12)
   ShellText { x: 18; anchors.verticalCenter: parent.verticalCenter; text: (root.labels[root.pending]||"")+" now?"; font.weight: Font.DemiBold }
   Row {
    anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter } spacing: 6
    Rectangle {
     width: cancelText.implicitWidth+26; height: 34; radius: 17; color: Qt.alpha(Theme.text,cancelMouse.containsMouse ? 0.12 : 0.07)
     ShellText { id: cancelText; anchors.centerIn: parent; text: "Cancel" }
     MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pending="" }
     Accessible.role: Accessible.Button; Accessible.name: "Cancel"
    }
    Rectangle {
     width: confirmText.implicitWidth+26; height: 34; radius: 17; color: confirmMouse.containsMouse ? Qt.lighter(Theme.danger,1.1) : Theme.danger
     ShellText { id: confirmText; anchors.centerIn: parent; text: root.labels[root.pending]||""; color: Theme.notch; font.weight: Font.DemiBold }
     MouseArea { id: confirmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.confirm() }
     Accessible.role: Accessible.Button; Accessible.name: "Confirm "+(root.labels[root.pending]||"")
    }
   }
  }
 }
}
