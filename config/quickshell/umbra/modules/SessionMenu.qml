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
 spacing: Theme.padding
 ShellText { text: "SESSION / UMBRA"; color: Theme.muted; font.family: Theme.mono }
 Action { Layout.fillWidth: true; text: "Lock"; onClicked: { Quickshell.execDetached([Quickshell.env("HOME")+"/dotfiles/scripts/lock"]); UiState.close() } }
 Action { Layout.fillWidth: true; text: "Suspend"; onClicked: { Quickshell.execDetached(["systemctl","suspend"]); UiState.close() } }
 Repeater {
  model: ["Log out","Reboot","Power off"]
  Action { required property string modelData; Layout.fillWidth: true; text: modelData; onClicked: root.pending=modelData }
 }
 ShellText { text: "Confirm "+root.pending.toLowerCase()+"?"; visible: root.pending!=="" }
 RowLayout {
  visible: root.pending!==""
  Action { text: "Cancel"; onClicked: root.pending="" }
  Action { text: "Confirm"; onClicked: {
   if(root.pending==="Log out") Hyprland.dispatch("hl.dsp.exit()")
   else Quickshell.execDetached(["systemctl",root.pending==="Reboot" ? "reboot" : "poweroff"])
   UiState.close()
  } }
 }
}
