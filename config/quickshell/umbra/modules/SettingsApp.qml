pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../components"
import "../services"
import "../theme"
// Titan Settings, after saneAspect's settings window (nKomstQedmE, J8s7O2IGogE
// 6:15–7:30): searchable sidebar, hero card, grouped rows. Rows are generated
// from theme/settings-schema.json; "@" keys are actions or composite rows.
FloatingWindow {
 id: win
 title: "Titan Settings"
 implicitWidth: 820; implicitHeight: 560
 minimumSize: Qt.size(640,420)
 color: Theme.shell
 visible: true
 onVisibleChanged: if(!visible) UiState.settingsOpen=false
 readonly property var schema: Settings.schema
 readonly property var sections: schema.sections || []
 readonly property var section: sections.find(s=>s.id===UiState.settingsSection) || sections[0] || ({groups:[]})
 property var history: []
 property int historyIndex: -1
 function go(id) { if(id===UiState.settingsSection && historyIndex>=0) return; history=history.slice(0,historyIndex+1).concat([id]); historyIndex=history.length-1; UiState.settingsSection=id; search.text=""; content.contentY=0 }
 function step(delta) { const i=historyIndex+delta; if(i<0 || i>=history.length) return; historyIndex=i; UiState.settingsSection=history[i]; content.contentY=0 }
 Component.onCompleted: go(UiState.settingsSection)
 Connections { target: UiState; function onSettingsSectionChanged() { if(win.history[win.historyIndex]!==UiState.settingsSection) win.go(UiState.settingsSection) } }
 readonly property string query: search.text.trim().toLowerCase()
 function labelFor(key) { return key.startsWith("@") ? special[key] ? special[key].label : key : (schema.settings[key]||{}).label || key }
 readonly property var special: ({
  "@theme": {label:"Theme"}, "@wallpaper": {label:"Wallpaper"}, "@accent": {label:"Accent colour"},
  "@dnd": {label:"Do not disturb"}, "@clearNotifications": {label:"Clear notification history"},
  "@lockNow": {label:"Lock now"}, "@idlePolicy": {label:"Idle policy"},
  "@powerProfile": {label:"Power profile"}, "@nightlight": {label:"Night light"}, "@gameMode": {label:"Game mode"},
  "@restartShell": {label:"Restart shell"}, "@doctor": {label:"Run health check"}, "@about": {label:"About"}
 })
 // Search flattens every section into one group of matching rows.
 readonly property var groups: query==="" ? section.groups : [{label:"Results", keys:sections.flatMap(s=>s.groups.flatMap(g=>g.keys)).filter(k=>labelFor(k).toLowerCase().includes(query) || k.toLowerCase().includes(query))}]
 FileView { id: hostname; path: "/etc/hostname" }
 Shortcut { sequence: "Escape"; onActivated: win.visible=false }
 Shortcut { sequences: [StandardKey.Back]; onActivated: win.step(-1) }
 Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }

 // ── Sidebar ─────────────────────────────────────────────────────────────
 Rectangle {
  id: sidebar
  width: 230; height: parent.height
  color: Qt.darker(Theme.shell,1.25)
  Rectangle {
   x: 12; y: 12; width: parent.width-24; height: 34; radius: 12
   color: Qt.alpha(Theme.text,0.06)
   border.width: search.activeFocus ? 1 : 0; border.color: Qt.alpha(Theme.accent,0.6)
   ShellIcon { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 13; opacity: 0.5 }
   TextField {
    id: search
    anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
    placeholderText: "Search Settings"; placeholderTextColor: Theme.muted
    color: Theme.text; font.family: Theme.sans; font.pixelSize: Theme.fontSize+1
    background: Item {}
    Keys.onEscapePressed: text=""
   }
  }
  ListView {
   x: 12; y: 56; width: parent.width-24; height: parent.height-68
   spacing: 4; clip: true; interactive: contentHeight>height
   model: win.sections
   delegate: Rectangle {
    id: item
    required property var modelData
    readonly property bool current: win.query==="" && UiState.settingsSection===modelData.id
    width: ListView.view.width; height: 40; radius: 12
    color: current ? Qt.alpha(Theme.text,0.09) : itemMouse.containsMouse ? Qt.alpha(Theme.text,0.05) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.hover } }
    Rectangle {
     x: 6; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 14
     color: item.current ? Theme.accent : Qt.alpha(Theme.text,0.08)
     ShellIcon { anchors.centerIn: parent; name: item.modelData.icon; size: 14; opacity: item.current ? 1 : 0.8 }
    }
    ShellText { x: 44; anchors.verticalCenter: parent.verticalCenter; text: item.modelData.label; font.pixelSize: Theme.fontSize+2; font.weight: item.current ? Font.DemiBold : Font.Normal }
    MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(item.modelData.id) }
    Accessible.role: Accessible.PageTab; Accessible.name: modelData.label; Accessible.selected: current; Accessible.onPressAction: win.go(modelData.id)
   }
  }
 }

 // ── Content ─────────────────────────────────────────────────────────────
 Item {
  anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
  Row {
   x: 16; y: 12; spacing: 6; z: 2
   Repeater {
    model: [{symbol:"arrow-left",delta:-1,label:"Back"},{symbol:"arrow-right",delta:1,label:"Forward"}]
    Rectangle {
     id: nav
     required property var modelData
     readonly property bool enabledNav: modelData.delta<0 ? win.historyIndex>0 : win.historyIndex<win.history.length-1
     width: 30; height: 28; radius: 9; color: Qt.alpha(Theme.text,navMouse.containsMouse && enabledNav ? 0.10 : 0.05)
     ShellIcon { anchors.centerIn: parent; name: nav.modelData.symbol; size: 13; opacity: nav.enabledNav ? 0.9 : 0.3 }
     MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.step(nav.modelData.delta) }
     Accessible.role: Accessible.Button; Accessible.name: modelData.label
    }
   }
  }
  Flickable {
   id: content
   anchors { fill: parent; topMargin: 50; leftMargin: 16; rightMargin: 16 }
   contentHeight: column.implicitHeight+20; clip: true
   boundsBehavior: Flickable.StopAtBounds
   ScrollBar.vertical: ScrollBar { policy: content.contentHeight>content.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
   Column {
    id: column
    width: content.width-8; spacing: 10
    Rectangle {
     visible: win.query===""
     width: parent.width; height: 132; radius: Theme.radius+4; color: Qt.alpha(Theme.text,0.045)
     Column {
      anchors.centerIn: parent; spacing: 6
      Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; radius: 28; color: Qt.alpha(Theme.accent,0.16); ShellIcon { anchors.centerIn: parent; name: win.section.icon || "settings"; size: 24 } }
      ShellText { anchors.horizontalCenter: parent.horizontalCenter; text: win.section.label || ""; font.family: Theme.display; font.pixelSize: Theme.titleSize; font.weight: Font.DemiBold }
      ShellText { anchors.horizontalCenter: parent.horizontalCenter; text: win.section.description || ""; color: Theme.muted }
     }
    }
    Repeater {
     model: win.groups
     Column {
      id: group
      required property var modelData
      width: column.width; spacing: 6
      ShellText { visible: group.modelData.label!==""; text: group.modelData.label.toUpperCase(); color: Theme.muted; font.pixelSize: Theme.captionSize; font.letterSpacing: 0.6; leftPadding: 2; topPadding: 4 }
      ShellText { visible: group.modelData.keys.length===0; text: "No matching settings"; color: Theme.muted }
      Rectangle {
       visible: group.modelData.keys.length>0
       width: parent.width; height: rows.implicitHeight; radius: Theme.radius+4; color: Qt.alpha(Theme.text,0.045)
       Column {
        id: rows
        width: parent.width
        Repeater {
         model: group.modelData.keys
         SettingRow { required property string modelData; required property int index; key: modelData; first: index===0; width: rows.width }
        }
       }
      }
     }
    }
   }
  }
 }

 component SettingRow: Item {
  id: row
  property string key
  property bool first: false
  readonly property var spec: key.startsWith("@") ? ({type:key}) : Settings.schema.settings[key] || ({})
  readonly property var value: Settings.values[key]
  readonly property bool tall: spec.type==="int" || key==="@about" || key==="@idlePolicy"
  implicitHeight: tall ? 64 : 46
  Rectangle { visible: !row.first; x: 14; width: parent.width-28; height: 1; color: Qt.alpha(Theme.text,0.06) }
  ShellText { id: label; x: 14; y: row.tall ? 12 : (parent.height-height)/2; text: win.labelFor(row.key); font.pixelSize: Theme.fontSize+1 }
  ShellText { visible: !!row.spec.hint && !row.tall; anchors { left: label.right; leftMargin: 8; baseline: label.baseline } text: row.spec.hint || ""; color: Theme.muted; font.pixelSize: Theme.captionSize }
  // Value controls on the right
  Switch {
   visible: row.spec.type==="bool" || ["@dnd","@nightlight","@gameMode"].includes(row.key)
   anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
   label: win.labelFor(row.key)
   checked: row.key==="@dnd" ? UiState.dnd : row.key==="@nightlight" ? Toggles.nightlight : row.key==="@gameMode" ? Toggles.gameMode : !!row.value
   onToggled: row.key==="@dnd" ? UiState.dnd=!UiState.dnd : row.key==="@nightlight" ? Toggles.toggle("nightlight") : row.key==="@gameMode" ? Toggles.toggle("game-mode") : Settings.set(row.key,!row.value)
  }
  Item {
   visible: row.spec.type==="int"
   anchors.fill: parent
   ShellText { anchors { right: parent.right; rightMargin: 14 } y: label.y; text: row.value+" "+(row.spec.unit||""); color: Theme.muted }
   Slider {
    id: slider
    x: 14; y: 36; width: parent.width-28; height: 18
    from: row.spec.min||0; to: row.spec.max||1; stepSize: 1; snapMode: Slider.SnapAlways
    value: row.value||0
    onMoved: Settings.set(row.key,Math.round(value))
    leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
    background: Rectangle {
     y: (slider.height-height)/2; width: slider.availableWidth; height: 4; radius: 2; color: Qt.alpha(Theme.text,0.12)
     Rectangle { width: slider.visualPosition*parent.width; height: parent.height; radius: 2; color: Theme.accent }
    }
    handle: Rectangle { x: slider.visualPosition*(slider.availableWidth-width); y: (slider.height-height)/2; width: 16; height: 16; radius: 8; color: Qt.lighter(Theme.accent,1.25); border.width: slider.pressed ? 3 : 0; border.color: Qt.alpha(Theme.accent,0.5) }
    Accessible.name: win.labelFor(row.key)
   }
   Accessible.role: Accessible.Slider; Accessible.name: win.labelFor(row.key)
  }
  Row {
   visible: row.spec.type==="choice" || row.key==="@powerProfile"
   anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
   spacing: 4
   Repeater {
    model: row.key==="@powerProfile" ? [{id:PowerProfile.PowerSaver,label:"Saver"},{id:PowerProfile.Balanced,label:"Balanced"},{id:PowerProfile.Performance,label:"Performance"}] : (row.spec.options||[]).map(o=>({id:o,label:o.charAt(0).toUpperCase()+o.slice(1)}))
    Rectangle {
     id: chip
     required property var modelData
     readonly property bool selected: row.key==="@powerProfile" ? PowerProfiles.profile===modelData.id : row.value===modelData.id
     width: chipLabel.implicitWidth+20; height: 26; radius: 13
     color: selected ? Qt.alpha(Theme.accent,0.24) : Qt.alpha(Theme.text,chipMouse.containsMouse ? 0.10 : 0.05)
     ShellText { id: chipLabel; anchors.centerIn: parent; text: chip.modelData.label; font.pixelSize: Theme.captionSize+1; color: chip.selected ? Theme.accent : Theme.text }
     MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.key==="@powerProfile" ? PowerProfiles.profile=chip.modelData.id : Settings.set(row.key,chip.modelData.id) }
     Accessible.role: Accessible.RadioButton; Accessible.checked: selected; Accessible.name: modelData.label
    }
   }
  }
  TextField {
   visible: row.spec.type==="string" || row.spec.type==="color"
   anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
   width: Math.min(240,parent.width*0.45); height: 30
   text: row.value||""; placeholderText: row.spec.placeholder || (row.spec.type==="color" ? "#rrggbb" : ""); placeholderTextColor: Theme.muted
   color: Theme.text; font.family: Theme.sans; font.pixelSize: Theme.fontSize
   leftPadding: row.spec.type==="color" ? 30 : 10
   background: Rectangle { radius: 9; color: Qt.alpha(Theme.text,0.06); border.width: parent.activeFocus ? 1 : 0; border.color: Qt.alpha(Theme.accent,0.7)
    Rectangle { visible: row.spec.type==="color" && /^#[0-9a-fA-F]{6}$/.test(row.value||""); x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: row.value||"transparent" } }
   onEditingFinished: { if(text!==row.value && Settings.set(row.key,text) && row.key==="accentCustom" && text) { Theme.accentName="custom"; Theme.save() } }
   Accessible.name: win.labelFor(row.key)
  }
  // Composite rows
  Row {
   visible: row.key==="@theme" || row.key==="@wallpaper"
   anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
   spacing: 6
   ShellText { text: row.key==="@theme" ? Theme.paletteName : "Choose…"; color: Theme.muted }
   ShellIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow-right"; size: 12; opacity: 0.6 }
  }
  MouseArea {
   visible: ["@theme","@wallpaper","@clearNotifications","@lockNow","@restartShell","@doctor"].includes(row.key)
   anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
   onClicked: {
    if(row.key==="@theme") UiState.toggle("themes")
    else if(row.key==="@wallpaper") UiState.toggle("wallpapers")
    else if(row.key==="@clearNotifications") Notices.dismissAll()
    else if(row.key==="@lockNow") Quickshell.execDetached([Paths.script("lock")])
    else if(row.key==="@restartShell") Quickshell.execDetached([Paths.script("shell-restart")])
    else if(row.key==="@doctor") Quickshell.execDetached(["kitty","--hold",Paths.script("doctor")])
   }
   Rectangle { anchors.fill: parent; radius: Theme.radius; color: Qt.alpha(Theme.text,parent.containsMouse ? 0.03 : 0) }
  }
  ShellText {
   visible: ["@clearNotifications","@lockNow","@restartShell","@doctor"].includes(row.key)
   anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
   text: row.key==="@clearNotifications" ? Notices.items.values.length+" stored" : row.key==="@doctor" ? "Opens Kitty" : ""; color: Theme.muted; font.pixelSize: Theme.captionSize
  }
  Row {
   visible: row.key==="@accent"
   anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
   spacing: 7
   Repeater {
    model: [{id:"theme",color:Theme.palette.accent||"#aeb8c4"},{id:"silver",color:"#aeb8c4"},{id:"ice",color:"#8faebc"},{id:"sage",color:"#9fae9d"},{id:"custom",color:Settings.values.accentCustom||"transparent"}]
    Rectangle {
     id: swatch
     required property var modelData
     readonly property bool selected: Theme.accentName===modelData.id
     visible: modelData.id!=="custom" || !!Settings.values.accentCustom
     width: 18; height: 18; radius: 9; color: modelData.color
     border.width: selected ? 2 : 0; border.color: Theme.text
     Rectangle { anchors.centerIn: parent; visible: swatch.selected; width: 6; height: 6; radius: 3; color: Theme.notch }
     MouseArea { anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; onClicked: { Theme.accentName=swatch.modelData.id; Theme.save() } }
     Accessible.role: Accessible.RadioButton; Accessible.checked: selected; Accessible.name: modelData.id+" accent"
    }
   }
  }
  ShellText {
   visible: row.key==="@idlePolicy" || row.key==="@about"
   x: 14; y: 32; width: parent.width-28
   text: row.key==="@idlePolicy" ? "Always awake: idle locking and display-off are disabled on this machine (docs/always-awake.md)." : "Titan · Umbra shell on "+(hostname.text().trim()||"this machine")+" · theme "+Theme.paletteName+" · settings in ~/.local/state/titan/settings.json"
   color: Theme.muted; font.pixelSize: Theme.captionSize; wrapMode: Text.Wrap
  }
 }
}
