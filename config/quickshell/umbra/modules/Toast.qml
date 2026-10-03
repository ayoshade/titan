pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../theme"
// Notification pop-up: a black-framed card that drops in below the island.
PanelWindow {
 id: root
 required property var modelData
 screen: modelData
 readonly property bool shown: Notices.showToast && !!Notices.latest && modelData===Quickshell.screens[0] && UiState.panel!=="notifications" && UiState.panel!=="controls"
 visible: shown || slide.running
 anchors { top: true }
 margins { top: Theme.islandTop+Theme.islandHeight+10 }
 exclusionMode: ExclusionMode.Ignore
 implicitWidth: 380
 implicitHeight: frame.height+16
 color: "transparent"
 WlrLayershell.namespace: "umbra-toast"
 Rectangle {
  id: frame
  width: parent.width; height: (card.item ? card.item.implicitHeight : 60)+12
  radius: Theme.radius+6; color: Theme.notch
  y: root.shown ? 0 : -12
  opacity: root.shown ? 1 : 0
  Behavior on y { NumberAnimation { id: slide; duration: Theme.movement*0.8; easing.type: Easing.OutBack; easing.overshoot: Theme.bounce } }
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  Loader {
   id: card
   anchors { fill: parent; margins: 6 }
   active: !!Notices.latest
   sourceComponent: NotificationCard { notification: Notices.latest }
  }
 }
}
