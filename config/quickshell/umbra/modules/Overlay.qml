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
 // Search menus are flat black like the reference launcher; they and the
 // session menu size themselves to their content.
 readonly property bool flat: carousel || panel==="launcher" || panel==="commands"
 readonly property bool fitted: docked || panel==="launcher" || panel==="commands" || panel==="session"
 readonly property int frame: flat ? 0 : 8
 readonly property int inset: carousel ? 14 : flat ? 4 : 12
 readonly property var fixedHeight: ({ notifications: 520, media: 200 })
 MouseArea { anchors.fill: parent; onClicked: UiState.close() }
 Rectangle {
  id: card
  readonly property int contentWidth: root.carousel ? 600 : root.panel==="launcher" || root.panel==="commands" ? 460+root.inset*2 : root.panel==="session" ? 380+root.inset*2 : root.panel==="media" ? 460+root.inset*2 : root.docked ? 440+root.inset*2 : Theme.panelWidth
  width: Math.min(contentWidth+root.frame*2,root.width-32)
  height: Math.min(root.panel==="themes" ? 170 : root.panel==="wallpapers" ? 200 : root.fitted ? (loader.item ? loader.item.implicitHeight : 300)+root.inset*2+root.frame*2 : root.fixedHeight[root.panel] || 560, root.height-card.y-24)
  y: root.docked ? Theme.islandTop+Theme.islandHeight+8 : 8
  x: root.docked ? Math.max(16,Math.min(root.width-width-16,root.width/2+Theme.islandWidth/2-120)) : (root.width-width)/2
  color: Theme.notch; radius: Theme.panelRadius+root.frame
  MouseArea { anchors.fill: parent; onClicked: {} }
  scale: root.visible ? 1 : 0.94
  opacity: root.visible ? 1 : 0
  transformOrigin: Item.Top
  Behavior on scale { NumberAnimation { duration: Theme.movement*0.7; easing.type: Easing.OutBack; easing.overshoot: Theme.bounce } }
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  Behavior on height { enabled: root.fitted && root.visible; NumberAnimation { duration: Theme.movement*0.8; easing.type: Easing.OutCubic } }
  Rectangle {
   id: surface
   anchors { fill: parent; margins: root.frame }
   radius: Theme.panelRadius
   color: root.flat ? "transparent" : Theme.surface
   clip: true
   Loader {
    id: loader
    anchors { fill: parent; margins: root.inset }
    active: root.visible
    source: root.panel==="themes" ? "ThemeSwitcher.qml" : root.panel==="wallpapers" ? "WallpaperSwitcher.qml" : root.panel==="commands" ? "CommandPanel.qml" : root.panel==="launcher" ? "Launcher.qml" : root.panel==="controls" ? "ControlCenter.qml" : root.panel==="notifications" ? "NotificationCenter.qml" : root.panel==="media" ? "MediaPanel.qml" : "SessionMenu.qml"
    focus: true
    Keys.onEscapePressed: UiState.close()
   }
  }
 }
}
