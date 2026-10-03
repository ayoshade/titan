pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
// Three-column dashboard revealed when the island expands. Positions follow the
// measured reference layout (docs/research/island-notch.md); the island clips it.
Item {
 id: root
 required property string screenName
 property bool open: false
 width: Theme.dashboardWidth; height: Theme.dashboardHeight
 readonly property int rowTop: 43
 readonly property int rowPitch: 19
 SystemClock { id: clock; precision: SystemClock.Minutes }

 function appIcon(appId) {
  const entry=appId ? DesktopEntries.heuristicLookup(appId) : null
  const icon=entry ? entry.icon : appId
  if(icon && icon.startsWith("/")) return "file://"+icon
  const path=icon ? Quickshell.iconPath(icon,true) : ""
  return path || Qt.resolvedUrl("../assets/icons/apps.svg")
 }
 function toplevelApp(t) { return t.wayland ? t.wayland.appId : t.lastIpcObject ? t.lastIpcObject.class || "" : "" }
 function focusWorkspace(id) { Hyprland.dispatch("hl.dsp.focus({workspace="+id+"})"); UiState.closeIsland() }
 function duration(seconds) { const s=Math.max(0,Math.floor(seconds||0)); return Math.floor(s/60)+":"+String(s%60).padStart(2,"0") }

 // ── Left: focused window and workspaces ──────────────────────────────────
 // The Wayland toplevel list is complete at startup; Hyprland's active toplevel waits for the next focus event.
 readonly property var focused: ToplevelManager.activeToplevel
 Row {
  x: 16; y: 16; height: 16; spacing: 7
  Image {
   anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14
   source: root.focused ? root.appIcon(root.focused.appId) : Qt.resolvedUrl("../assets/icons/apps.svg")
   sourceSize.width: 28; sourceSize.height: 28; asynchronous: true
  }
  ShellText {
   anchors.verticalCenter: parent.verticalCenter; width: 172
   text: root.focused && root.focused.title ? root.focused.title : "Desktop"
   font.pixelSize: 13; font.weight: Font.DemiBold
  }
 }
 readonly property int workspaceTotal: Math.max(5,...Hyprland.workspaces.values.filter(w=>w.id>0 && w.id<=10).map(w=>w.id))
 readonly property int activeWorkspace: { const w=Hyprland.workspaces.values.find(w=>w.active && w.monitor && w.monitor.name===screenName); return w ? w.id : 1 }
 // Five rows fit the reference height; with more workspaces, keep the active one in view.
 readonly property int firstRow: Math.max(1,Math.min(activeWorkspace-2,workspaceTotal-4))
 readonly property int firstEmpty: { for(let i=1;i<=10;i++) { const w=Hyprland.workspaces.values.find(w=>w.id===i); if(!w || w.toplevels.values.length===0) return i } return 10 }
 Repeater {
  model: 5
  Item {
   id: row
   required property int index
   readonly property int wsId: root.firstRow+index
   readonly property var workspace: Hyprland.workspaces.values.find(w=>w.id===wsId) || null
   readonly property var apps: workspace ? workspace.toplevels.values : []
   readonly property bool active: wsId===root.activeWorkspace
   x: 10; y: root.rowTop+index*root.rowPitch; width: 196; height: root.rowPitch
   Rectangle {
    anchors.fill: parent; radius: 6
    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Qt.alpha(Theme.text,0.07) } GradientStop { position: 1; color: "transparent" } }
    opacity: rowMouse.containsMouse ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.duration } }
   }
   WorkspaceMark { x: 4; anchors.verticalCenter: parent.verticalCenter; active: row.active; occupied: row.apps.length>0; activeWidth: 6; activeHeight: 13; idleWidth: 5; idleHeight: 10 }
   ShellText {
    x: 20; anchors.verticalCenter: parent.verticalCenter
    text: row.wsId; font.pixelSize: 13; font.weight: row.active ? Font.DemiBold : Font.Normal
    color: row.active ? Theme.text : row.apps.length>0 ? Qt.alpha(Theme.text,0.8) : Theme.muted
   }
   Row {
    x: 42; anchors.verticalCenter: parent.verticalCenter; spacing: 4
    Repeater {
     model: row.apps.slice(0,6)
     Image {
      required property var modelData
      width: 13; height: 13; sourceSize.width: 26; sourceSize.height: 26; asynchronous: true
      source: root.appIcon(root.toplevelApp(modelData))
     }
    }
   }
   MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.focusWorkspace(row.wsId) }
   Accessible.role: Accessible.Button; Accessible.name: "Workspace "+wsId+(apps.length ? ", "+apps.length+" windows" : ", empty"); Accessible.onPressAction: root.focusWorkspace(wsId)
  }
 }
 Item {
  x: 10; y: root.rowTop+5*root.rowPitch; width: 196; height: root.rowPitch
  Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 10; radius: 2.5; color: "transparent"; border.width: 1; border.color: Qt.alpha(Theme.text,0.12) }
  ShellText { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "+"; font.pixelSize: 13; color: newMouse.containsMouse ? Theme.text : Qt.alpha(Theme.muted,0.6) }
  MouseArea { id: newMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.focusWorkspace(root.firstEmpty) }
  Accessible.role: Accessible.Button; Accessible.name: "New workspace"; Accessible.onPressAction: root.focusWorkspace(root.firstEmpty)
 }

 // ── Centre: clock, week strip, media ─────────────────────────────────────
 Rectangle {
  id: calendarHit
  x: 214; y: 6; width: 220; height: 80; radius: 14
  color: Qt.alpha(Theme.text,calendarMouse.containsMouse ? 0.05 : 0)
  Behavior on color { ColorAnimation { duration: Theme.duration } }
  MouseArea { id: calendarMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggleCalendar(root.screenName) }
  Accessible.role: Accessible.Button; Accessible.name: "Open calendar"; Accessible.onPressAction: UiState.toggleCalendar(root.screenName)
 }
 ShellText {
  anchors.horizontalCenter: parent.horizontalCenter; y: 13
  text: Qt.formatDateTime(clock.date,Settings.values.clock24 ? "HH:mm" : "h:mm")
  font.pixelSize: 23; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
 }
 Row {
  anchors.horizontalCenter: parent.horizontalCenter; y: 41
  Repeater {
   model: 7
   Item {
    id: day
    required property int index
    readonly property date date: new Date(clock.date.getFullYear(),clock.date.getMonth(),clock.date.getDate()+index-3)
    readonly property bool today: index===3
    readonly property bool weekend: date.getDay()===0 || date.getDay()===6
    width: 28; height: 35
    opacity: index===0 || index===6 ? 0.3 : 1
    Rectangle { anchors.centerIn: parent; width: 32; height: 35; radius: 9; color: Qt.alpha(Theme.text,0.07); visible: day.today }
    ShellText {
     anchors.horizontalCenter: parent.horizontalCenter; y: 4
     text: day.today ? Qt.formatDate(day.date,"ddd").toUpperCase() : Qt.formatDate(day.date,"ddd").charAt(0)
     font.pixelSize: 10; font.weight: day.today ? Font.DemiBold : Font.Normal
     color: day.today ? Theme.text : day.weekend ? Qt.alpha(Theme.danger,0.75) : Theme.muted
    }
    ShellText {
     anchors.horizontalCenter: parent.horizontalCenter; y: day.today ? 15 : 18
     text: day.date.getDate()
     font.pixelSize: day.today ? 17 : 13; font.weight: day.today ? Font.DemiBold : Font.Normal
     color: day.today ? Theme.accent : day.weekend ? Theme.danger : Qt.alpha(Theme.text,0.75)
    }
   }
  }
 }
 Item {
  id: media
  visible: !!Media.player && Settings.values.dashboardMedia
  x: 209; y: 108; width: 236; height: 32
  readonly property var player: Media.player
  Rectangle {
   id: art
   width: 28; height: 28; radius: 8; anchors.verticalCenter: parent.verticalCenter
   color: Qt.alpha(Theme.text,0.08); clip: true
   ShellIcon { anchors.centerIn: parent; name: "music"; size: 14; opacity: 0.45 }
   Image { anchors.fill: parent; source: media.player ? media.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 56; sourceSize.height: 56 }
  }
  Row {
   x: 37; y: 2; spacing: 7
   ShellText { id: trackTitle; width: Math.min(implicitWidth,62); text: Media.title; font.pixelSize: 13; font.weight: Font.DemiBold }
   ShellText { width: Math.min(implicitWidth,72); text: media.player ? media.player.trackArtist : ""; font.pixelSize: 12; color: Theme.muted; anchors.baseline: trackTitle.baseline }
  }
  Row {
   x: 37; y: 19; spacing: 6
   readonly property real length: media.player && media.player.lengthSupported ? media.player.length : 0
   ShellText { text: root.duration(media.player ? media.player.position : 0); font.pixelSize: 10; color: Theme.muted; font.features: { "tnum": 1 } }
   Rectangle {
    anchors.verticalCenter: parent.verticalCenter; width: 69; height: 3; radius: 1.5; color: Qt.alpha(Theme.text,0.14)
    Rectangle { height: parent.height; radius: parent.radius; color: Theme.accent; width: parent.parent.length>0 && media.player ? parent.width*Math.min(1,media.player.position/parent.parent.length) : 0 }
   }
   ShellText { text: root.duration(parent.length); font.pixelSize: 10; color: Theme.muted; font.features: { "tnum": 1 } }
  }
  Row {
   anchors { right: parent.right; verticalCenter: parent.verticalCenter }
   Repeater {
    model: [{symbol:"previous",label:"Previous"},{symbol:"play",label:"Play or pause"},{symbol:"next",label:"Next"}]
    Item {
     id: control
     required property var modelData
     width: 22; height: 22
     readonly property string symbol: modelData.symbol==="play" && media.player && media.player.isPlaying ? "pause" : modelData.symbol
     ShellIcon { anchors.centerIn: parent; name: control.symbol; size: control.modelData.symbol==="play" ? 14 : 12; opacity: controlMouse.containsMouse ? 1 : 0.85 }
     MouseArea {
      id: controlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: { const p=media.player; if(!p) return; if(control.modelData.symbol==="previous") p.previous(); else if(control.modelData.symbol==="next") p.next(); else p.togglePlaying() }
     }
     Accessible.role: Accessible.Button; Accessible.name: modelData.label
    }
   }
  }
  // MPRIS position is not pushed; refresh it only while the dashboard shows a playing track.
  Timer { interval: 1000; repeat: true; running: root.open && !!media.player && media.player.isPlaying; onTriggered: media.player.positionChanged() }
 }
 ShellText {
  visible: !Media.player && Settings.values.dashboardMedia
  anchors.horizontalCenter: parent.horizontalCenter; y: 116
  text: "Nothing playing"; font.pixelSize: 12; color: Qt.alpha(Theme.muted,0.6)
 }

 // ── Right: status ────────────────────────────────────────────────────────
 readonly property var connectedDevices: Bluetooth.devices.values.filter(d=>d.connected)
 readonly property bool bluetoothOn: !!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
 readonly property bool micMuted: !!Audio.source && !!Audio.source.audio && Audio.source.audio.muted
 readonly property int noticeCount: Notices.items.values.length
 ShellText { x: 457; y: 16; text: "Status"; font.pixelSize: 13; color: Theme.muted }
 Repeater {
  model: [
   {kind:"battery", value:Math.round((UPower.displayDevice.ready ? UPower.displayDevice.percentage : 1)*100)+"%", detail:UPower.onBattery ? "on battery" : "plugged in", strong:true, panel:"controls"},
   {kind:"signal", value:NetState.active ? NetState.active.name : NetState.label==="Connected" ? "Wired" : "Offline", detail:NetState.active ? Math.round(NetState.active.signalStrength*100)+"%" : "", strong:NetState.label!=="Offline", panel:"connectivity"},
   {kind:"bluetooth", value:root.connectedDevices.length ? root.connectedDevices[0].name : root.bluetoothOn ? "Bluetooth on" : "Bluetooth off", detail:root.connectedDevices.length>1 ? "+"+(root.connectedDevices.length-1) : "", strong:root.connectedDevices.length>0, panel:"connectivity"},
   {kind:Audio.muted ? "mute" : "volume", value:Audio.muted ? "Muted" : Math.round(Audio.volume*100)+"%", detail:root.micMuted ? "mic off" : "mic on", strong:!Audio.muted, panel:"controls"},
   {kind:"bell", value:root.noticeCount ? root.noticeCount+(root.noticeCount===1 ? " notification" : " notifications") : "No notifications", detail:UiState.dnd ? "silenced" : "", strong:root.noticeCount>0, panel:"notifications"}
  ]
  Item {
   id: status
   required property int index
   required property var modelData
   x: 451; y: root.rowTop+index*root.rowPitch; width: 185; height: root.rowPitch
   Rectangle { anchors.fill: parent; radius: 6; color: Qt.alpha(Theme.text,statusMouse.containsMouse ? 0.05 : 0) }
   Item {
    x: 6; width: 20; height: parent.height
    BatteryGlyph { visible: status.modelData.kind==="battery"; anchors.verticalCenter: parent.verticalCenter; bodyWidth: 18; bodyHeight: 9 }
    SignalBars { visible: status.modelData.kind==="signal"; anchors.verticalCenter: parent.verticalCenter; strength: NetState.active ? NetState.active.signalStrength : NetState.label==="Offline" ? 0 : 1; scale: 0.85; transformOrigin: Item.Left }
    ShellIcon { readonly property bool glyph: ["bluetooth","volume","mute","bell"].includes(status.modelData.kind); visible: glyph; anchors.verticalCenter: parent.verticalCenter; x: 2; name: glyph ? status.modelData.kind : "bell"; size: 12; opacity: 0.6 }
   }
   Row {
    x: 32; anchors.verticalCenter: parent.verticalCenter; spacing: 6
    ShellText { id: value; width: Math.min(implicitWidth,115); text: status.modelData.value; font.pixelSize: 13; font.weight: status.modelData.strong ? Font.DemiBold : Font.Normal; color: status.modelData.strong ? Theme.text : Theme.muted }
    ShellText { width: Math.min(implicitWidth,60); text: status.modelData.detail; visible: text!==""; font.pixelSize: 11; color: Theme.muted; anchors.baseline: value.baseline }
   }
   MouseArea { id: statusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: UiState.toggle(status.modelData.panel) }
   Accessible.role: Accessible.Button; Accessible.name: modelData.value+" "+modelData.detail; Accessible.onPressAction: UiState.toggle(modelData.panel)
  }
 }
 onOpenChanged: if(open) Toggles.refresh()
 Row {
  x: 457; y: 136; spacing: 5
  Repeater {
   model: [{op:"nightlight",key:"nightlight",symbol:"moon",label:"Night light"},{op:"game-mode",key:"gameMode",symbol:"toggle",label:"Game mode"}]
   Rectangle {
    id: chip
    required property var modelData
    readonly property bool on: Toggles[modelData.key]
    width: chipRow.implicitWidth+16; height: 21; radius: height/2
    color: on ? Qt.alpha(Theme.accent,chipMouse.containsMouse ? 0.32 : 0.24) : Qt.alpha(Theme.text,chipMouse.containsMouse ? 0.11 : 0.07)
    Behavior on color { ColorAnimation { duration: Theme.duration } }
    Row {
     id: chipRow; anchors.centerIn: parent; spacing: 5
     ShellIcon { anchors.verticalCenter: parent.verticalCenter; name: chip.modelData.symbol; size: 11; opacity: chip.on ? 1 : 0.7 }
     ShellText { anchors.verticalCenter: parent.verticalCenter; text: chip.modelData.label; font.pixelSize: 11; font.weight: Font.Medium; color: chip.on ? Theme.accent : Qt.alpha(Theme.text,0.85) }
    }
    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Toggles.toggle(chip.modelData.op) }
    Accessible.role: Accessible.CheckBox; Accessible.checked: on; Accessible.name: modelData.label
   }
  }
 }
}
