pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
PanelWindow {
 required property var modelData
 screen: modelData
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.layer: WlrLayer.Background
 WlrLayershell.namespace: "umbra-background"
 color: Theme.background
 mask: Region {}
 Image { anchors.fill: parent; visible: Theme.wallpaperEnabled; source: "file://"+Quickshell.env("HOME")+"/dotfiles/assets/wallpapers/blacksite.svg"; fillMode: Image.PreserveAspectCrop; sourceSize.width: 1920; sourceSize.height: 1080; asynchronous: true }
}
