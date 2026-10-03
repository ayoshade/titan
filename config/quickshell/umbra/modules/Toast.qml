pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../theme"
PanelWindow {
 required property var modelData
 screen: modelData
 visible: Notices.showToast && !!Notices.latest && modelData===Quickshell.screens[0] && UiState.panel!=="notifications"
 anchors { top: true }
 margins { top: 54 }
 exclusionMode: ExclusionMode.Ignore
 implicitWidth: 380
 implicitHeight: toast.item ? toast.item.implicitHeight : 0
 color: "transparent"
 WlrLayershell.namespace: "umbra-toast"
 Loader {
  id: toast; anchors.fill: parent
  active: !!Notices.latest
  sourceComponent: NotificationCard { notification: Notices.latest }
 }
}
