pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../services"
import "../theme"
// Wallpaper layer. A new wallpaper fades in over the old one while its blur
// clears, matching the reference's soft change (5cp6DkClAuM 1:52–2:08).
PanelWindow {
 id: root
 required property var modelData
 screen: modelData
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.layer: WlrLayer.Background
 WlrLayershell.namespace: "umbra-background"
 color: Theme.background
 mask: Region {}
 readonly property string wanted: Theme.wallpaperEnabled && Settings.values.wallpaperEnabled ? Wallpapers.url(Wallpapers.current) : ""
 property int front: 0
 readonly property var layers: [first, second]
 onWantedChanged: { const back=layers[1-front]; if(back.source.toString()===wanted && back.status===Image.Ready) reveal(back); else back.source=wanted }
 Component.onCompleted: { first.source=wanted; first.opacity=1 }
 function reveal(layer) {
  if(layer===layers[front] || layer.source.toString()!==wanted) return
  fade.target=layer; fade.restart()
 }
 component Layer: Image {
  id: layer
  property real blurAmount: 0
  anchors.fill: parent
  fillMode: Image.PreserveAspectCrop
  asynchronous: true
  sourceSize.width: root.width; sourceSize.height: root.height
  opacity: 0
  layer.enabled: blurAmount>0
  layer.effect: MultiEffect { blurEnabled: true; blur: layer.blurAmount; blurMax: 48 }
  onStatusChanged: if(status===Image.Ready) root.reveal(layer)
 }
 Layer { id: first }
 Layer { id: second }
 SequentialAnimation {
  id: fade
  property var target: null
  ScriptAction { script: { fade.target.z=1; root.layers[root.front].z=0; fade.target.blurAmount=Theme.animate ? 1 : 0 } }
  ParallelAnimation {
   NumberAnimation { target: fade.target; property: "opacity"; from: 0; to: 1; duration: Theme.animate ? 700 : 0; easing.type: Easing.OutCubic }
   NumberAnimation { target: fade.target; property: "blurAmount"; to: 0; duration: Theme.animate ? 900 : 0; easing.type: Easing.OutCubic }
  }
  ScriptAction { script: { const old=root.layers[root.front]; old.opacity=0; old.source=""; root.front=root.layers.indexOf(fade.target) } }
 }
}
