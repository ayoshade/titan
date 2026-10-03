pragma Singleton
import QtQuick
import "."
import "../theme"
import Quickshell.Services.Notifications
QtObject {
 id: root
 readonly property var items: server.trackedNotifications
 property var latest: null
 property bool showToast: false
 function dismissOne() { const n=items.values[items.values.length-1]; if(n) n.dismiss() }
 function invokeLast() { const n=items.values[items.values.length-1]; if(n && n.actions.length) n.actions[0].invoke() }
 function dismissAll() { for(const n of items.values.slice()) n.dismiss() }
 property NotificationServer server: NotificationServer {
  actionsSupported: true
  persistenceSupported: true
  bodyMarkupSupported: false
  onNotification: n => {
   n.tracked=true
   root.latest=n
   root.showToast=!UiState.dnd
   root.expiry.restart()
   if(trackedNotifications.values.length>50) trackedNotifications.values[0].dismiss()
  }
 }
 property Timer expiry: Timer { interval: Settings.values.toastSeconds*1000; onTriggered: root.showToast=false }
 property Connections latestConnection: Connections { target: root.latest; function onClosed() { root.showToast=false; root.latest=null } }
}
