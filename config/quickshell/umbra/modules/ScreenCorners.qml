pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services"
import "../theme"
// Rounded display corners, after saneAspect's notch update (nKomstQedmE 14:30–16:15).
// They sit on the overlay layer, so full-screen windows keep them, take no input,
// and fade out in game mode.
PanelWindow {
 id: root
 required property var modelData
 screen: modelData
 readonly property bool shown: Settings.values.screenCorners && !Toggles.gameMode
 visible: shown || corners.opacity>0
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.namespace: "umbra-corners"
 WlrLayershell.layer: WlrLayer.Overlay
 WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
 color: "transparent"
 // An empty input region lets every click reach the windows below.
 mask: Region {}
 component Corner: Shape {
  id: corner
  property int turns: 0
  readonly property int r: Settings.values.screenCornerRadius
  width: r; height: r
  preferredRendererType: Shape.CurveRenderer
  transform: Rotation { origin.x: corner.r/2; origin.y: corner.r/2; angle: corner.turns*90 }
  ShapePath {
   strokeWidth: 0; strokeColor: "transparent"; fillColor: "#000000"
   startX: 0; startY: 0
   PathLine { x: corner.r; y: 0 }
   PathArc { x: 0; y: corner.r; radiusX: corner.r; radiusY: corner.r; direction: PathArc.Counterclockwise }
   PathLine { x: 0; y: 0 }
  }
 }
 Item {
  id: corners
  anchors.fill: parent
  opacity: root.shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.duration } }
  Corner { anchors { left: parent.left; top: parent.top } }
  Corner { anchors { right: parent.right; top: parent.top } turns: 1 }
  Corner { anchors { right: parent.right; bottom: parent.bottom } turns: 2 }
  Corner { anchors { left: parent.left; bottom: parent.bottom } turns: 3 }
 }
}
