pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
ScrollView {
 id: root
 clip: true
 ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
 ColumnLayout {
  width: root.availableWidth; spacing: 12
  RowLayout {
   Layout.fillWidth: true
   ColumnLayout {
    Layout.fillWidth: true; spacing: 2
    ShellText { text: "umbra"; font.pixelSize: Theme.subtitleSize; font.weight: Font.DemiBold }
    ShellText { text: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage*100)+"% · "+(UPower.onBattery ? "On battery" : "Plugged in") : "System online"; font.pixelSize: Theme.captionSize; color: Theme.muted }
   }
   Tray { bar: root.QsWindow.window }
   IconButton { symbol: "lock"; label: "Lock · Super+L"; onClicked: { Quickshell.execDetached([Quickshell.env("HOME")+"/dotfiles/scripts/lock"]); UiState.close() } }
   IconButton { symbol: "power"; label: "Session"; onClicked: UiState.toggle("session") }
  }
  GridLayout {
   Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
   ToggleTile { Layout.fillWidth: true; text: "Wi-Fi"; symbol: "wifi"; subtitle: NetState.label; selected: Networking.wifiEnabled; onClicked: UiState.toggle("connectivity") }
   ToggleTile { Layout.fillWidth: true; text: "Focus"; symbol: "moon"; subtitle: UiState.dnd ? "On" : "Off"; selected: UiState.dnd; onClicked: UiState.dnd=!UiState.dnd }
   ToggleTile { Layout.fillWidth: true; text: "Bluetooth"; symbol: "bluetooth"; subtitle: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "On" : "Off"; selected: !!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled; onClicked: UiState.toggle("connectivity") }
   ToggleTile { Layout.fillWidth: true; text: "Power"; symbol: "bolt"; subtitle: PowerProfiles.profile===PowerProfile.PowerSaver ? "Saver" : PowerProfiles.profile===PowerProfile.Performance ? "Performance" : "Balanced"; selected: PowerProfiles.profile!==PowerProfile.PowerSaver; onClicked: { PowerProfiles.profile=PowerProfiles.profile===PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced } }
  }
  Level { Layout.fillWidth: true; label: "Sound"; symbol: Audio.muted ? "mute" : "volume"; value: Audio.volume; onAdjusted: value=>Audio.setVolume(value) }
  RowLayout {
   Layout.fillWidth: true
   Action { text: Audio.muted ? "Unmute" : "Mute"; implicitHeight: 28; enabled: !!Audio.sink; onClicked: Audio.toggleMute() }
   Action { text: Audio.source && Audio.source.audio && Audio.source.audio.muted ? "Mic off" : "Mic on"; implicitHeight: 28; enabled: !!Audio.source; onClicked: Audio.source.audio.muted=!Audio.source.audio.muted }
   Item { Layout.fillWidth: true }
   Action { text: "Devices ›"; implicitHeight: 28; onClicked: UiState.toggle("connectivity") }
  }
  Level { Layout.fillWidth: true; label: "Display"; symbol: "sun"; value: Brightness.value; onAdjusted: value=>Brightness.setValue(value) }
  MediaCard { Layout.fillWidth: true }
  RowLayout {
   Layout.fillWidth: true
   ShellText { text: "Notifications"; color: Theme.muted; font.pixelSize: Theme.captionSize; Layout.fillWidth: true }
   Action { text: "View all ›"; implicitHeight: 26; onClicked: UiState.toggle("notifications") }
  }
  Rectangle {
   visible: Notices.items.values.length===0
   Layout.fillWidth: true; implicitHeight: 54; radius: Theme.radius; color: Theme.raised
   ShellText { anchors.centerIn: parent; text: "You're all caught up"; color: Theme.muted; font.pixelSize: Theme.captionSize }
  }
  Repeater { model: Notices.items.values.slice(-2); NotificationCard { required property var modelData; notification: modelData; Layout.fillWidth: true } }
 }
}
