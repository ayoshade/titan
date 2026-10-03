pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../components"
import "../services"
import "../theme"
// Pop-up panels. Each panel stands alone in a black outer frame with a graphite
// inner surface, as in the reference. The control center drops below the
// island's status icons; other panels open at the top centre.
PanelWindow {
 id: root
 required property var modelData
 screen: modelData
 visible: UiState.panel!=="" && UiState.panelScreen===modelData.name
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.namespace: "umbra-overlay"
 WlrLayershell.layer: WlrLayer.Overlay
 WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
 color: "transparent"
 readonly property string panel: UiState.panel
 readonly property bool docked: panel==="controls"
 readonly property bool carousel: panel==="themes" || panel==="wallpapers"
 readonly property int frame: carousel ? 0 : 8
 readonly property var fixedHeight: ({ launcher: 100+Settings.values.launcherResults*((Settings.values.launcherDescriptions ? 58 : 44)+4), notifications: 560, session: 430, media: 300, commands: 560 })
 MouseArea { anchors.fill: parent; onClicked: UiState.close() }
 Rectangle {
  id: card
  readonly property int contentWidth: root.panel==="themes" || root.panel==="wallpapers" ? 600 : root.panel==="launcher" ? Theme.launcherWidth : root.docked ? 440+24 : Theme.panelWidth
  width: Math.min(contentWidth+root.frame*2,root.width-32)
  height: Math.min(root.panel==="themes" ? 170 : root.panel==="wallpapers" ? 200 : root.docked ? (loader.item ? loader.item.implicitHeight : 400)+24+root.frame*2 : root.fixedHeight[root.panel] || 560, root.height-card.y-24)
  y: root.docked ? Theme.islandTop+Theme.islandHeight+8 : 8
  x: root.docked ? Math.max(16,Math.min(root.width-width-16,root.width/2+Theme.islandWidth/2-120)) : (root.width-width)/2
  color: Theme.notch; radius: Theme.panelRadius+root.frame
  MouseArea { anchors.fill: parent; onClicked: {} }
  scale: root.visible ? 1 : 0.94
  opacity: root.visible ? 1 : 0
  transformOrigin: Item.Top
  Behavior on scale { NumberAnimation { duration: Theme.movement*0.7; easing.type: Easing.OutBack; easing.overshoot: Theme.bounce } }
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  Behavior on height { enabled: root.docked; NumberAnimation { duration: Theme.movement*0.8; easing.type: Easing.OutCubic } }
  Rectangle {
   id: surface
   anchors { fill: parent; margins: root.frame }
   radius: Theme.panelRadius
   color: root.carousel ? "transparent" : Theme.surface
   clip: true
   Loader {
    id: loader
    anchors { fill: parent; margins: root.carousel ? 14 : 12 }
    active: root.visible
    source: root.panel==="themes" ? "ThemeSwitcher.qml" : root.panel==="wallpapers" ? "WallpaperSwitcher.qml" : root.panel==="commands" ? "CommandPanel.qml" : root.panel==="launcher" ? "Launcher.qml" : root.panel==="controls" ? "ControlCenter.qml" : root.panel==="notifications" ? "NotificationCenter.qml" : root.panel==="media" ? "MediaPanel.qml" : "SessionMenu.qml"
    focus: true
    Keys.onEscapePressed: UiState.close()
   }
  }
 }
}
