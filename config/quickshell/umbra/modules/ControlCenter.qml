pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "../components"
import "../services"
import "../theme"
// Control center after saneAspect's reference (5cp6DkClAuM 0:22–0:41,
// J8s7O2IGogE 5:30): tile grid, slider cards with drill-in pages, media and
// notifications. Detail pages slide in over the main page.
Item {
 id: root
 property string page: UiState.controlsPage
 readonly property int pad: 12
 implicitWidth: 440
 implicitHeight: page==="main" ? main.implicitHeight : Math.min(560,detail.item ? detail.item.implicitHeight : 400)
 Behavior on implicitHeight { NumberAnimation { duration: Theme.movement*0.8; easing.type: Easing.OutCubic } }
 clip: true
 function open(name) { UiState.controlsPage=name }
 property bool powerOpen: false
 property string powerPending: ""
 // Lock runs at once; log out, reboot and power off need a second click or Confirm.
 function powerAction(id) {
  if(id==="lock") { Quickshell.execDetached([Paths.script("lock")]); UiState.close(); return }
  if(powerPending!==id) { powerPending=id; return }
  if(id==="logout") Hyprland.dispatch("hl.dsp.exit()")
  else Quickshell.execDetached(["systemctl",id==="reboot" ? "reboot" : "poweroff"])
  UiState.close()
 }
 Keys.onEscapePressed: page==="main" ? UiState.close() : open("main")
 Component.onDestruction: UiState.controlsPage="main"

 component Card: Rectangle {
  radius: Theme.radius+4
  color: Qt.alpha(Theme.text,0.045)
 }
 component SectionHead: Item {
  id: head
  property string title
  property string target: ""
  property string actionText: ""
  signal action()
  width: parent ? parent.width : 0; height: 26
  ShellText { anchors.verticalCenter: parent.verticalCenter; text: head.title; font.pixelSize: Theme.fontSize; font.weight: Font.Medium }
  Rectangle {
   visible: head.target!==""
   anchors { right: parent.right; verticalCenter: parent.verticalCenter }
   width: 24; height: 24; radius: 12; color: Qt.alpha(Theme.text,chevMouse.containsMouse ? 0.12 : 0.06)
   ShellIcon { anchors.centerIn: parent; name: "chevron-right"; size: 12; opacity: 0.8 }
   MouseArea { id: chevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open(head.target) }
   Accessible.role: Accessible.Button; Accessible.name: head.title+" details"
  }
  ShellText {
   visible: head.actionText!==""
   anchors { right: parent.right; verticalCenter: parent.verticalCenter }
   text: head.actionText; font.pixelSize: Theme.captionSize; color: actMouse.containsMouse ? Theme.text : Theme.muted
   MouseArea { id: actMouse; anchors { fill: parent; margins: -4 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: head.action() }
  }
 }

 // ── Main page ───────────────────────────────────────────────────────────
 Column {
  id: main
  width: root.width; spacing: 10
  x: root.page==="main" ? 0 : -root.width*0.3
  opacity: root.page==="main" ? 1 : 0
  visible: opacity>0
  Behavior on x { NumberAnimation { duration: Theme.movement; easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  topPadding: 0; bottomPadding: 0
  readonly property int tileWidth: (width-52-16)/2
  Row {
   spacing: 8
   Tile { width: main.tileWidth; symbol: "wifi"; title: "Wi-Fi"; subtitle: NetState.active ? NetState.active.name : Networking.wifiEnabled ? (NetState.label==="Connected" ? "Wired" : "Not connected") : "Off"; on: Networking.wifiEnabled; onClicked: root.open("wifi"); onPressAndHold: Networking.wifiEnabled=!Networking.wifiEnabled }
   Tile { width: main.tileWidth; symbol: "focus"; title: "Focus"; subtitle: UiState.dnd ? "On" : "Off"; on: UiState.dnd; onClicked: UiState.dnd=!UiState.dnd }
   // The reference keeps its power menu inside the control center (course
   // chapter "The Power Menu", Mcjr5T2pHxw 11:54): this button reveals it.
   Tile { symbol: "lock"; on: root.powerOpen; onClicked: { root.powerOpen=!root.powerOpen; root.powerPending="" } Accessible.name: "Power menu" }
  }
  Card {
   id: power
   width: parent.width; height: root.powerOpen ? (root.powerPending ? 104 : 64) : 0
   visible: height>0; clip: true
   Behavior on height { NumberAnimation { duration: Theme.movement*0.7; easing.type: Easing.OutCubic } }
   Row {
    x: 10; y: 10; spacing: (parent.width-20-4*44)/3
    Repeater {
     model: [{id:"lock",symbol:"lock",label:"Lock"},{id:"logout",symbol:"logout",label:"Log out"},{id:"reboot",symbol:"refresh",label:"Reboot"},{id:"poweroff",symbol:"power",label:"Power off"}]
     Column {
      id: action
      required property var modelData
      spacing: 0
      Tile { anchors.horizontalCenter: parent.horizontalCenter; width: 44; height: 44; symbol: action.modelData.symbol; on: root.powerPending===action.modelData.id; onClicked: root.powerAction(action.modelData.id); Accessible.name: action.modelData.label }
     }
    }
   }
   Rectangle {
    visible: root.powerPending!==""
    x: 10; y: 62; width: parent.width-20; height: 34; radius: 17; color: Qt.alpha(Theme.danger,0.14)
    ShellText { x: 14; anchors.verticalCenter: parent.verticalCenter; text: ({logout:"Log out",reboot:"Reboot",poweroff:"Power off"})[root.powerPending]+" now?"; font.weight: Font.DemiBold }
    Rectangle {
     anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
     width: confirmLabel.implicitWidth+22; height: 26; radius: 13; color: Theme.danger
     ShellText { id: confirmLabel; anchors.centerIn: parent; text: "Confirm"; color: Theme.notch; font.weight: Font.DemiBold; font.pixelSize: Theme.captionSize+1 }
     MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.powerAction(root.powerPending) }
     Accessible.role: Accessible.Button; Accessible.name: "Confirm"
    }
   }
  }
  Row {
   spacing: 8
   readonly property var device: Bluetooth.devices.values.find(d=>d.connected) || null
   Tile { width: main.tileWidth; symbol: "bluetooth"; title: "Bluetooth"; subtitle: parent.device ? parent.device.name : Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "On" : "Off"; on: !!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled; onClicked: root.open("bluetooth"); onPressAndHold: if(Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled=!Bluetooth.defaultAdapter.enabled }
   Tile { width: main.tileWidth; symbol: "toggle"; title: "Game Mode"; subtitle: Toggles.gameMode ? "On" : "Off"; on: Toggles.gameMode; onClicked: Toggles.toggle("game-mode") }
   Tile { symbol: "moon"; on: Toggles.nightlight; onClicked: Toggles.toggle("nightlight"); Accessible.name: "Night light "+(Toggles.nightlight ? "on" : "off") }
  }
  Card {
   width: parent.width; height: 70
   Column {
    anchors { fill: parent; margins: 12; topMargin: 8 } spacing: 4
    SectionHead { title: "Sound"; target: "sound" }
    PillSlider { width: parent.width; symbol: Audio.muted ? "mute" : "volume"; label: "Volume"; value: Audio.volume; onMoved: Audio.setVolume(value) }
   }
  }
  Card {
   width: parent.width; height: 70
   Column {
    anchors { fill: parent; margins: 12; topMargin: 8 } spacing: 4
    SectionHead { title: "Display"; target: "display" }
    PillSlider { width: parent.width; symbol: "sun"; label: "Brightness"; value: Brightness.value; onMoved: Brightness.setValue(value) }
   }
  }
  // Background apps: shown only when the system tray has items.
  Card {
   visible: SystemTray.items.values.length>0
   width: parent.width; height: 44
   ShellText { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Running"; color: Theme.muted; font.pixelSize: Theme.captionSize+1 }
   Tray { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } bar: root.QsWindow.window }
  }
  Card {
   visible: Settings.values.ccMedia && !!Media.player
   width: parent.width; height: 70
   Rectangle {
    id: art
    x: 10; anchors.verticalCenter: parent.verticalCenter; width: 50; height: 50; radius: Theme.radius-4; clip: true; color: Qt.alpha(Theme.text,0.08)
    ShellIcon { anchors.centerIn: parent; name: "music"; size: 18; opacity: 0.4 }
    Image { anchors.fill: parent; source: Media.player ? Media.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 100; sourceSize.height: 100 }
   }
   Column {
    anchors { left: art.right; leftMargin: 10; right: controls.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
    ShellText { width: parent.width; text: Media.title; font.weight: Font.DemiBold }
    ShellText { width: parent.width; text: Media.player ? Media.player.trackArtist || Media.player.identity : ""; color: Theme.muted; font.pixelSize: Theme.captionSize }
   }
   Row {
    id: controls
    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
    IconButton { symbol: "previous"; label: "Previous"; size: 30; onClicked: Media.player.previous() }
    IconButton { symbol: Media.player && Media.player.isPlaying ? "pause" : "play"; label: "Play or pause"; size: 30; onClicked: Media.player.togglePlaying() }
    IconButton { symbol: "next"; label: "Next"; size: 30; onClicked: Media.player.next() }
   }
  }
  Card {
   visible: Settings.values.ccNotifications
   width: parent.width
   height: Math.max(110,noteColumn.implicitHeight+20)
   Column {
    id: noteColumn
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 8 } spacing: 6
    SectionHead { title: "Notifications"; actionText: Notices.items.values.length ? "Clear all" : ""; onAction: Notices.dismissAll() }
    ShellText { visible: Notices.items.values.length===0; text: "No notifications"; color: Theme.muted; font.pixelSize: Theme.captionSize }
    Repeater {
     model: Notices.items.values.slice(-3).reverse()
     Rectangle {
      id: note
      required property var modelData
      width: noteColumn.width; height: 56; radius: Theme.radius-2; color: Qt.alpha(Theme.text,0.05)
      Rectangle {
       x: 10; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 14; color: Qt.alpha(Theme.accent,0.25)
       ShellText { anchors.centerIn: parent; text: (note.modelData.appName||"N").charAt(0).toUpperCase(); color: Theme.accent; font.weight: Font.DemiBold }
      }
      Column {
       anchors { left: parent.left; leftMargin: 48; right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
       ShellText { width: parent.width; text: note.modelData.appName; color: Theme.muted; font.pixelSize: Theme.captionSize }
       ShellText { width: parent.width; text: note.modelData.summary; font.weight: Font.DemiBold }
       ShellText { width: parent.width; text: note.modelData.body; color: Theme.muted; font.pixelSize: Theme.captionSize; visible: text!=="" }
      }
      IconButton { anchors { right: parent.right; rightMargin: 4; top: parent.top; topMargin: 4 } symbol: "close"; label: "Dismiss"; size: 22; onClicked: note.modelData.dismiss() }
     }
    }
   }
  }
 }

 // ── Detail pages ────────────────────────────────────────────────────────
 Loader {
  id: detail
  width: root.width
  x: root.page==="main" ? root.width : 0
  opacity: root.page==="main" ? 0 : 1
  visible: opacity>0
  Behavior on x { NumberAnimation { duration: Theme.movement; easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  active: root.page!=="main"
  sourceComponent: root.page==="wifi" ? wifiPage : root.page==="bluetooth" ? bluetoothPage : root.page==="sound" ? soundPage : displayPage
 }
 component PageHead: Item {
  id: ph
  property string title
  property bool switchable: false
  property bool checked: false
  signal toggled()
  width: parent ? parent.width : 0; height: 36
  Rectangle {
   anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 14; color: Qt.alpha(Theme.text,backMouse.containsMouse ? 0.12 : 0.06)
   ShellIcon { anchors.centerIn: parent; name: "back"; size: 13 }
   MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open("main") }
   Accessible.role: Accessible.Button; Accessible.name: "Back"
  }
  ShellText { x: 38; anchors.verticalCenter: parent.verticalCenter; text: ph.title; font.pixelSize: Theme.subtitleSize+2; font.weight: Font.DemiBold }
  Switch { visible: ph.switchable; anchors { right: parent.right; verticalCenter: parent.verticalCenter } checked: ph.checked; label: ph.title; onToggled: ph.toggled() }
 }
 component Caption: ShellText { color: Theme.muted; font.pixelSize: Theme.captionSize; topPadding: 4 }
 component ListRow: Rectangle {
  id: lr
  property string symbol: ""
  property string title
  property string subtitle: ""
  property bool selected: false
  property string actionText: ""
  signal clicked()
  signal action()
  width: parent ? parent.width : 0; height: subtitle ? 46 : 36; radius: Theme.radius-4
  color: Qt.alpha(Theme.text,rowMouse.containsMouse ? 0.09 : 0.05)
  Rectangle {
   visible: lr.symbol!==""
   x: 8; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13
   color: lr.selected ? Theme.accent : Qt.alpha(Theme.text,0.07)
   ShellIcon { anchors.centerIn: parent; name: lr.symbol; size: 12 }
  }
  Column {
   anchors { left: parent.left; leftMargin: lr.symbol ? 42 : 12; right: trail.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
   ShellText { width: parent.width; text: lr.title; font.weight: lr.selected ? Font.DemiBold : Font.Normal }
   ShellText { width: parent.width; text: lr.subtitle; color: Theme.muted; font.pixelSize: Theme.captionSize; visible: text!=="" }
  }
  MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lr.clicked() }
  Item {
   id: trail
   anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
   width: lr.actionText ? actionChip.width : lr.selected ? 16 : 0; height: 24
   ShellIcon { visible: lr.selected && !lr.actionText; anchors.centerIn: parent; name: "check"; size: 14 }
   Rectangle {
    id: actionChip
    visible: lr.actionText!==""
    anchors.verticalCenter: parent.verticalCenter; width: chipText.implicitWidth+20; height: 24; radius: 12
    color: Qt.alpha(Theme.text,chipMouse.containsMouse ? 0.14 : 0.08)
    ShellText { id: chipText; anchors.centerIn: parent; text: lr.actionText; font.pixelSize: Theme.captionSize; font.weight: Font.Medium; color: Theme.accent }
    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lr.action() }
   }
  }
  Accessible.role: Accessible.Button; Accessible.name: title+(subtitle ? ", "+subtitle : "")+(selected ? ", selected" : ""); Accessible.onPressAction: clicked()
 }

 Component {
  id: wifiPage
  Column {
   id: wp
   spacing: 8
   property var pending: null
   property string error: ""
   readonly property var networks: NetState.wifi ? NetState.wifi.networks.values.slice().sort((a,b)=>b.connected-a.connected || b.signalStrength-a.signalStrength) : []
   PageHead { title: "Wi-Fi"; switchable: true; checked: Networking.wifiEnabled; onToggled: Networking.wifiEnabled=!Networking.wifiEnabled }
   ListRow {
    visible: !!NetState.active
    symbol: "wifi"; selected: true
    title: NetState.active ? NetState.active.name : ""
    subtitle: NetState.active ? "Connected · "+Math.round(NetState.active.signalStrength*100)+"% signal" : ""
    actionText: "Disconnect"; onAction: NetState.active.disconnect()
   }
   Row {
    width: parent.width
    Caption { text: "Networks"; width: parent.width-scanLabel.width }
    Caption { id: scanLabel; text: Networking.wifiEnabled ? "● Scanning" : "Wi-Fi off" }
   }
   Repeater {
    model: wp.networks.filter(n=>!n.connected).slice(0,7)
    ListRow {
     required property var modelData
     symbol: "wifi"; title: modelData.name
     subtitle: Math.round(modelData.signalStrength*100)+"%"+(modelData.stateChanging ? " · connecting…" : "")
     onClicked: { wp.pending=modelData; wp.error=""; modelData.connect() }
    }
   }
   Connections {
    target: wp.pending
    function onConnectionFailed(reason) { wp.error=reason===ConnectionFailReason.NoSecrets ? "Enter the password for "+wp.pending.name : "Connection failed: "+ConnectionFailReason.toString(reason) }
   }
   Caption { visible: wp.error!==""; text: wp.error; color: Theme.danger; width: parent.width; wrapMode: Text.Wrap }
   Row {
    visible: wp.pending!==null && wp.error!==""
    spacing: 8; width: parent.width
    TextField { id: psk; width: parent.width-90; placeholderText: "Password"; placeholderTextColor: Theme.muted; echoMode: TextInput.Password; color: Theme.text; background: Rectangle { color: Qt.alpha(Theme.text,0.07); radius: Theme.radius-4 } onAccepted: { wp.pending.connectWithPsk(text); clear() } }
    Action { text: "Join"; onClicked: { wp.pending.connectWithPsk(psk.text); psk.clear() } }
   }
   Caption { text: "Hold the Wi-Fi tile to switch the radio off or on."; width: parent.width; wrapMode: Text.Wrap }
  }
 }
 Component {
  id: bluetoothPage
  Column {
   spacing: 8
   readonly property var adapter: Bluetooth.defaultAdapter
   readonly property var saved: Bluetooth.devices.values.filter(d=>d.paired)
   readonly property var nearby: Bluetooth.devices.values.filter(d=>!d.paired)
   Component.onCompleted: if(adapter && adapter.enabled) adapter.discovering=true
   Component.onDestruction: if(adapter) adapter.discovering=false
   PageHead { title: "Bluetooth"; switchable: true; checked: !!parent.adapter && parent.adapter.enabled; onToggled: if(parent.adapter) parent.adapter.enabled=!parent.adapter.enabled }
   Caption { text: "Saved" }
   Caption { visible: parent.saved.length===0; text: "No saved devices"; topPadding: 0 }
   Repeater {
    model: parent.saved
    ListRow {
     required property var modelData
     symbol: "headphones"; title: modelData.name; selected: modelData.connected
     subtitle: modelData.connected ? "Connected" : modelData.state===BluetoothDeviceState.Connecting ? "Connecting…" : "Saved"
     actionText: modelData.connected ? "Disconnect" : "Connect"
     onAction: modelData.connected ? modelData.disconnect() : modelData.connect()
    }
   }
   Row {
    width: parent.width
    Caption { text: "Nearby"; width: parent.width-scan.width }
    Caption { id: scan; text: parent.parent.adapter && parent.parent.adapter.discovering ? "● Scanning" : "" }
   }
   Caption { visible: parent.nearby.length===0; text: "Looking for devices… put the device in pairing mode"; topPadding: 0; width: parent.width; wrapMode: Text.Wrap }
   Repeater {
    model: parent.nearby.slice(0,6)
    ListRow {
     required property var modelData
     symbol: "bluetooth"; title: modelData.name || modelData.address
     actionText: "Pair"; onAction: Quickshell.execDetached(["kitty","bluetoothctl"])
    }
   }
   Caption { text: "Pairing opens bluetoothctl so the PIN can be confirmed securely."; width: parent.width; wrapMode: Text.Wrap }
  }
 }
 Component {
  id: soundPage
  Column {
   id: sound
   spacing: 8
   readonly property var outputs: Pipewire.nodes.values.filter(n=>n.isSink && !n.isStream && n.audio)
   readonly property var inputs: Pipewire.nodes.values.filter(n=>!n.isSink && !n.isStream && n.audio)
   readonly property var apps: Pipewire.nodes.values.filter(n=>n.isStream && !n.isSink && n.audio)
   // Trackers are not Items, so they have no visual parent: reference by id.
   PwObjectTracker { objects: sound.apps }
   PageHead { title: "Sound" }
   Caption { text: "Output" }
   Repeater {
    model: parent.outputs
    ListRow {
     required property var modelData
     symbol: /headphone|headset/i.test(modelData.description) ? "headphones" : /hdmi|displayport/i.test(modelData.description) ? "monitor" : "volume"
     title: modelData.description || modelData.name; selected: Audio.sink===modelData
     onClicked: Pipewire.preferredDefaultAudioSink=modelData
    }
   }
   PillSlider { width: parent.width; symbol: "volume"; label: "Output volume"; value: Audio.volume; onMoved: Audio.setVolume(value) }
   Caption { text: "Input" }
   Repeater {
    model: parent.inputs
    ListRow {
     required property var modelData
     symbol: "mic"; title: modelData.description || modelData.name; selected: Audio.source===modelData
     onClicked: Pipewire.preferredDefaultAudioSource=modelData
    }
   }
   PillSlider { width: parent.width; symbol: "mic"; label: "Input volume"; enabled: !!Audio.source && !!Audio.source.audio; value: Audio.source && Audio.source.audio ? Audio.source.audio.volume : 0; onMoved: Audio.source.audio.volume=value }
   Caption { visible: parent.apps.length>0; text: "Apps" }
   Repeater {
    model: parent.apps
    Column {
     required property var modelData
     width: parent.width; spacing: 4
     ShellText { text: modelData.properties["application.name"] || modelData.description || modelData.name; font.weight: Font.Medium; width: parent.width }
     PillSlider { width: parent.width; symbol: "volume"; label: "App volume"; value: modelData.audio ? modelData.audio.volume : 0; onMoved: modelData.audio.volume=value }
    }
   }
  }
 }
 Component {
  id: displayPage
  Column {
   id: displayCol
   spacing: 8
   // Scale chips per monitor (OeT5VgeLSIQ 8:30). `workflow scale list` offers
   // 1.0–2.0× snapped to scales Hyprland accepts for each panel.
   property var scales: ({})
   function refresh() { if(!lister.running) lister.running=true }
   Component.onCompleted: refresh()
   Process {
    id: lister
    command: [Paths.workflow,"scale","list"]
    stdout: StdioCollector { onStreamFinished: { try { const m={}; for(const x of JSON.parse(text)) m[x.name]=x; displayCol.scales=m } catch(e) {} } }
   }
   Process { id: setter; onExited: displayCol.refresh() }
   PageHead { title: "Display" }
   Repeater {
    model: Hyprland.monitors.values
    Rectangle {
     id: mon
     required property var modelData
     readonly property var ipc: modelData.lastIpcObject || ({})
     readonly property var info: displayCol.scales[modelData.name] || null
     width: parent.width; height: card.implicitHeight+20; radius: Theme.radius; color: Qt.alpha(Theme.text,0.05)
     Column {
      id: card
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 8
      Row {
       spacing: 8
       Rectangle { width: 26; height: 26; radius: 13; color: Qt.alpha(Theme.text,0.07); ShellIcon { anchors.centerIn: parent; name: "monitor"; size: 12 } }
       Column {
        ShellText { text: mon.modelData.name+(mon.modelData.focused ? "  ·  focused" : ""); font.weight: Font.DemiBold }
        ShellText { text: (mon.ipc.width||"?")+"×"+(mon.ipc.height||"?")+" · "+Math.round(mon.ipc.refreshRate||0)+" Hz"; color: Theme.muted; font.pixelSize: Theme.captionSize }
       }
      }
      Row {
       spacing: 6
       visible: !!mon.info
       Repeater {
        model: mon.info ? mon.info.scales : []
        Rectangle {
         id: chip
         required property real modelData
         readonly property bool current: !!mon.info && Math.abs(mon.info.scale-modelData)<0.001
         width: 58; height: 30; radius: 10
         color: current ? Theme.accent : chipArea.containsMouse ? Qt.alpha(Theme.text,0.1) : Qt.alpha(Theme.text,0.06)
         Behavior on color { ColorAnimation { duration: Theme.hover } }
         ShellText { anchors.centerIn: parent; text: (Number.isInteger(chip.modelData) ? chip.modelData.toFixed(1) : String(+chip.modelData.toFixed(3)))+"×"; color: chip.current ? Theme.notch : Theme.text; font.weight: Font.Medium; font.features: { "tnum": 1 } }
         MouseArea {
          id: chipArea
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: if(!chip.current && !setter.running) { setter.command=[Paths.workflow,"scale","set",mon.modelData.name,String(chip.modelData)]; setter.running=true }
         }
         Accessible.role: Accessible.RadioButton; Accessible.name: "Scale "+chip.modelData+"×"; Accessible.checked: current
        }
       }
      }
      PillSlider { width: parent.width; symbol: "sun"; label: "Brightness"; visible: mon.modelData.name.startsWith("eDP"); value: Brightness.value; onMoved: Brightness.setValue(value) }
      Caption { visible: !mon.modelData.name.startsWith("eDP"); text: "External brightness is not controlled by Titan yet."; topPadding: 6 }
     }
    }
   }
   ListRow { symbol: "moon"; title: "Night Light"; subtitle: Toggles.nightlight ? "On · "+Settings.values.nightlightTemp+" K" : "Off"; selected: Toggles.nightlight; onClicked: Toggles.toggle("nightlight") }
   // Warmer toward the right, as in the reference Display page.
   PillSlider { width: parent.width; symbol: "moon"; label: "Night light temperature"; value: (6000-Settings.values.nightlightTemp)/3500; onMoved: Settings.set("nightlightTemp",Math.round((6000-value*3500)/100)*100) }
   Caption { text: "Super+/ and Super+Alt+/ also step the scale. Resolution stays in the Hyprland monitor profile."; width: parent.width; wrapMode: Text.Wrap }
  }
 }
}
