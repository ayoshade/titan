pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
ScrollView {
 id: root
 clip: true
 property var pendingNetwork: null
 property string networkError: ""
 ColumnLayout {
  width: root.availableWidth
  spacing: Theme.padding
  ShellText { text: "CONTROL / UMBRA"; font.family: Theme.mono; color: Theme.muted }
  RowLayout {
   Action { text: Networking.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"; selected: Networking.wifiEnabled; onClicked: Networking.wifiEnabled=!Networking.wifiEnabled }
   Action { text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "Bluetooth on" : "Bluetooth off"; enabled: !!Bluetooth.defaultAdapter; onClicked: Bluetooth.defaultAdapter.enabled=!Bluetooth.defaultAdapter.enabled }
   Action { text: UiState.dnd ? "DND on" : "DND off"; onClicked: UiState.dnd=!UiState.dnd }
  }
  Level { Layout.fillWidth: true; label: Audio.muted ? "Volume · muted" : "Volume"; value: Audio.volume; onAdjusted: value => Audio.setVolume(value) }
  RowLayout {
   Action { text: Audio.muted ? "Unmute" : "Mute"; enabled: !!Audio.sink; onClicked: Audio.toggleMute() }
   Action { text: Audio.source && Audio.source.audio && Audio.source.audio.muted ? "Microphone off" : "Microphone on"; enabled: !!Audio.source; onClicked: Audio.source.audio.muted=!Audio.source.audio.muted }
  }
  Repeater {
   model: Pipewire.nodes.values.filter(n => n.isSink && n.audio)
   Action {
    required property var modelData
    Layout.fillWidth: true
    text: modelData.description || modelData.name
    selected: Audio.sink===modelData
    onClicked: Pipewire.preferredDefaultAudioSink=modelData
   }
  }
  Level { Layout.fillWidth: true; label: "Display brightness"; value: Brightness.value; onAdjusted: value => Brightness.setValue(value) }
  ShellText { text: "POWER PROFILE"; color: Theme.muted; font.family: Theme.mono }
  RowLayout {
   Action { text: "Saver"; selected: PowerProfiles.profile===PowerProfile.PowerSaver; onClicked: PowerProfiles.profile=PowerProfile.PowerSaver }
   Action { text: "Balanced"; selected: PowerProfiles.profile===PowerProfile.Balanced; onClicked: PowerProfiles.profile=PowerProfile.Balanced }
   Action { text: "Performance"; enabled: PowerProfiles.hasPerformanceProfile; selected: PowerProfiles.profile===PowerProfile.Performance; onClicked: PowerProfiles.profile=PowerProfile.Performance }
  }
  MediaCard { Layout.fillWidth: true }
  ShellText { text: "NETWORK / "+NetState.label; color: Theme.muted; font.family: Theme.mono; Layout.fillWidth: true }
  Repeater {
   model: NetState.wifi ? NetState.wifi.networks : null
   delegate: Action {
    required property var modelData
    Layout.fillWidth: true
    text: (modelData.connected ? "● " : "○ ")+modelData.name+"  "+Math.round(modelData.signalStrength*100)+"%"+(modelData.stateChanging ? " …" : "")
    selected: modelData.connected
    onClicked: { root.pendingNetwork=modelData; root.networkError=""; modelData.connect() }
   }
  }
  Connections {
   target: root.pendingNetwork
   function onConnectionFailed(reason) { root.networkError=reason===ConnectionFailReason.NoSecrets ? "Enter the network password below." : "Connection failed: "+ConnectionFailReason.toString(reason) }
  }
  ShellText { text: root.networkError; color: Theme.danger; visible: text.length>0; Layout.fillWidth: true; wrapMode: Text.Wrap }
  RowLayout {
   visible: root.pendingNetwork!==null && root.networkError.length>0
   TextField { id: password; Layout.fillWidth: true; placeholderText: "Wi-Fi password"; placeholderTextColor: Theme.muted; echoMode: TextInput.Password; color: Theme.text; background: Rectangle { color: Theme.raised; radius: Theme.radius } }
   Action { text: "Connect"; onClicked: { root.pendingNetwork.connectWithPsk(password.text); password.clear() } }
  }
  Action { text: "Advanced network settings"; onClicked: Quickshell.execDetached(["kitty","nmtui"]) }
  RowLayout {
   ShellText { text: "BLUETOOTH DEVICES"; color: Theme.muted; font.family: Theme.mono; Layout.fillWidth: true }
   Action { text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Stop scan" : "Scan"; enabled: !!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled; onClicked: Bluetooth.defaultAdapter.discovering=!Bluetooth.defaultAdapter.discovering }
  }
  Repeater {
   model: Bluetooth.devices
   Action {
    required property var modelData
    Layout.fillWidth: true
    text: (modelData.connected ? "● " : "○ ")+modelData.name+(modelData.paired ? "" : " · pair")
    onClicked: { if(modelData.paired) modelData.connected=!modelData.connected; else Quickshell.execDetached(["kitty","bluetoothctl"]) }
   }
  }
  ShellText { text: "New-device pairing opens bluetoothctl for secure PIN confirmation."; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
 }
 Component.onDestruction: { if(Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering=false }
}
