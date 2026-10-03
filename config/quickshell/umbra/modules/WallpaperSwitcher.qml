pragma ComponentBehavior: Bound
import QtQuick
import "../components"
import "../services"
import "../theme"
// Wallpaper carousel for the current theme, after the reference
// (5cp6DkClAuM 1:56–2:08): title and theme, centred selection with an accent
// outline, applied dot, file name and "n/N · Enter to apply".
Item {
 id: root
 property int selectedIndex: Math.max(0,Wallpapers.files.indexOf(Wallpapers.current))
 readonly property string chosen: Wallpapers.files[selectedIndex] || ""
 function move(delta) { if(!Wallpapers.files.length) return; selectedIndex=Math.max(0,Math.min(Wallpapers.files.length-1,selectedIndex+delta)) }
 function apply() { if(chosen && Wallpapers.set(chosen)) UiState.close() }
 focus: true
 Keys.onLeftPressed: move(-1)
 Keys.onRightPressed: move(1)
 Keys.onReturnPressed: apply()
 Keys.onEnterPressed: apply()
 Keys.onEscapePressed: UiState.close()
 Component.onCompleted: forceActiveFocus()
 ShellText { x: 4; y: 0; text: "Wallpaper"; font.family: Theme.display; font.pixelSize: Theme.subtitleSize+2; font.weight: Font.DemiBold }
 ShellText { anchors { right: parent.right; rightMargin: 4 } y: 3; text: Theme.paletteName; color: Theme.muted; font.pixelSize: Theme.captionSize+1 }
 ListView {
  id: strip
  anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 30; bottom: parent.bottom; bottomMargin: 26 }
  orientation: ListView.Horizontal; spacing: 12; clip: true
  model: Wallpapers.files
  currentIndex: root.selectedIndex
  highlightRangeMode: ListView.StrictlyEnforceRange
  preferredHighlightBegin: (width-170)/2; preferredHighlightEnd: (width+170)/2
  highlightMoveDuration: Theme.movement
  onCurrentIndexChanged: root.selectedIndex=currentIndex
  delegate: Item {
   id: thumb
   required property string modelData
   required property int index
   readonly property bool selected: index===root.selectedIndex
   width: 170; height: strip.height
   Rectangle {
    anchors.centerIn: parent
    width: thumb.selected ? 170 : 150; height: thumb.selected ? 100 : 88; radius: Theme.radius-2
    color: Qt.alpha(Theme.text,0.06); clip: true
    border.width: thumb.selected ? 2 : 0; border.color: Theme.accent
    opacity: thumb.selected ? 1 : 0.7
    Behavior on width { NumberAnimation { duration: Theme.movement; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Theme.movement; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    Image {
     anchors { fill: parent; margins: thumb.selected ? 2 : 0 }
     source: Wallpapers.url(thumb.modelData); fillMode: Image.PreserveAspectCrop; asynchronous: true
     sourceSize.width: 340; sourceSize.height: 200
    }
    Rectangle { visible: Wallpapers.current===thumb.modelData; anchors { right: parent.right; top: parent.top; margins: 7 } width: 6; height: 6; radius: 3; color: Theme.accent }
   }
   MouseArea {
    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
    onClicked: root.selectedIndex=thumb.index
    onDoubleClicked: { root.selectedIndex=thumb.index; root.apply() }
   }
   Accessible.role: Accessible.Button; Accessible.name: modelData.split("/").pop(); Accessible.onPressAction: { root.selectedIndex=index; root.apply() }
  }
  WheelHandler { onWheel: event=>root.move(event.angleDelta.y<0 ? 1 : -1) }
 }
 ShellText {
  visible: Wallpapers.files.length===0
  anchors.centerIn: strip; width: parent.width-40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
  text: "No wallpapers for "+Theme.paletteName+" yet. Run scripts/fetch-wallpapers "+Theme.paletteName+" or add images to ~/Pictures/Wallpapers/"+Theme.paletteName+"."
  color: Theme.muted
 }
 ShellText { x: 4; anchors.bottom: parent.bottom; width: parent.width*0.6; text: root.chosen.split("/").pop(); color: Theme.muted; font.pixelSize: Theme.captionSize }
 ShellText { anchors { right: parent.right; rightMargin: 4; bottom: parent.bottom } text: (Wallpapers.files.length ? (root.selectedIndex+1)+"/"+Wallpapers.files.length+"  ·  " : "")+"Enter to apply"; color: Theme.muted; font.pixelSize: Theme.captionSize }
}
