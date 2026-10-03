pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../components"
import "../services"
import "../theme"
ColumnLayout {
 id: root
 property string pending: ""
 spacing: 12
 ShellText { text: "Session"; font.pixelSize: Theme.titleSize }
 ShellText { text: "shade / umbra"; color: Theme.muted }
 GridLayout {
  Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
  ToggleTile { Layout.fillWidth: true; text: "Lock"; symbol: "lock"; subtitle: "Secure session"; onClicked: { Quickshell.execDetached([Quickshell.env("HOME")+"/dotfiles/scripts/lock"]); UiState.close() } }
  ToggleTile { Layout.fillWidth: true; text: "Always awake"; symbol: "bolt"; subtitle: "Sleep disabled"; enabled: false }
  ToggleTile { Layout.fillWidth: true; text: "Reboot"; symbol: "refresh"; subtitle: "Restart system"; onClicked: root.pending="Reboot" }
  ToggleTile { Layout.fillWidth: true; text: "Power off"; symbol: "power"; subtitle: "Shut down"; onClicked: root.pending="Power off" }
 }
 ToggleTile { Layout.fillWidth: true; text: "Log out"; symbol: "logout"; subtitle: "Return to login"; onClicked: root.pending="Log out" }
 RowLayout {
  visible: root.pending!==""; Layout.fillWidth: true
  ShellText { text: root.pending+"?"; Layout.fillWidth: true }
  Action { text: "Cancel"; onClicked: root.pending="" }
  Action { text: "Confirm"; onClicked: {
   if(root.pending==="Log out") Hyprland.dispatch("hl.dsp.exit()")
   else Quickshell.execDetached(["systemctl",root.pending==="Reboot" ? "reboot" : "poweroff"])
   UiState.close()
  } }
 }
 Item { Layout.fillHeight: true }
}
