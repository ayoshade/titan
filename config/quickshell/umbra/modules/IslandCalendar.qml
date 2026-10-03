pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../components"
import "../services"
import "../theme"
// Month view the island morphs into. Geometry follows the reference
// (docs/research/island-notch.md): 44 px columns, 32 px rows, six weeks.
Item {
 id: root
 property bool open: false
 property int monthShift: 0
 width: Theme.calendarWidth; height: Theme.calendarHeight
 onOpenChanged: if(open) monthShift=0
 function shift(delta) { monthShift+=delta }
 SystemClock { id: clock; precision: SystemClock.Minutes }
 readonly property date month: new Date(clock.date.getFullYear(),clock.date.getMonth()+monthShift,1)
 readonly property int firstDay: Settings.values.weekStart==="sunday" ? 0 : Settings.values.weekStart==="monday" ? 1 : Qt.locale().firstDayOfWeek%7
 readonly property int lead: (month.getDay()-firstDay+7)%7
 readonly property date gridStart: new Date(month.getFullYear(),month.getMonth(),1-lead)

 component NavButton: Rectangle {
  id: nav
  property string symbol
  property string label
  property int delta
  width: 28; height: 28; radius: 14; y: 15
  color: Qt.alpha(Theme.text,navMouse.containsMouse ? 0.12 : 0.06)
  Behavior on color { ColorAnimation { duration: Theme.duration } }
  ShellIcon { anchors.centerIn: parent; name: nav.symbol; size: 13; opacity: 0.85 }
  MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shift(nav.delta) }
  Accessible.role: Accessible.Button; Accessible.name: label; Accessible.onPressAction: root.shift(delta)
 }
 NavButton { x: 15; symbol: "arrow-left"; label: "Previous month"; delta: -1 }
 NavButton { x: root.width-43; symbol: "arrow-right"; label: "Next month"; delta: 1 }
 ShellText {
  anchors.horizontalCenter: parent.horizontalCenter; y: 19
  text: Qt.formatDate(root.month,"MMMM yyyy")
  font.pixelSize: 15; font.weight: Font.DemiBold
  MouseArea { anchors { fill: parent; margins: -6 } cursorShape: root.monthShift ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.monthShift=0 }
  Accessible.role: Accessible.Button; Accessible.name: Qt.formatDate(root.month,"MMMM yyyy")+(root.monthShift ? ", return to this month" : ""); Accessible.onPressAction: root.monthShift=0
 }
 Row {
  x: 14; y: 52
  Repeater {
   model: 7
   ShellText {
    required property int index
    width: 44; horizontalAlignment: Text.AlignHCenter
    text: Qt.locale().dayName((root.firstDay+index)%7,Locale.NarrowFormat)
    font.pixelSize: 11; color: Theme.muted
   }
  }
 }
 Grid {
  x: 14; y: 75; columns: 7
  Repeater {
   model: 42
   Item {
    id: cell
    required property int index
    readonly property date date: new Date(root.gridStart.getFullYear(),root.gridStart.getMonth(),root.gridStart.getDate()+index)
    readonly property bool inMonth: date.getMonth()===root.month.getMonth()
    readonly property bool today: date.toDateString()===clock.date.toDateString()
    width: 44; height: 32
    Rectangle {
     anchors.centerIn: parent; width: 26; height: 26; radius: 13
     color: cell.today ? Theme.accent : Qt.alpha(Theme.text,dayMouse.containsMouse ? 0.08 : 0)
    }
    ShellText {
     anchors.centerIn: parent
     text: cell.date.getDate()
     font.pixelSize: 13; font.weight: cell.today ? Font.Bold : Font.Normal
     color: cell.today ? Theme.notch : cell.inMonth ? Qt.alpha(Theme.text,0.92) : Qt.alpha(Theme.text,0.28)
    }
    MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
    Accessible.role: Accessible.StaticText; Accessible.name: Qt.formatDate(cell.date,"dddd d MMMM yyyy")+(today ? ", today" : "")
   }
  }
 }
 WheelHandler { onWheel: event=>root.shift(event.angleDelta.y>0 ? -1 : 1) }
}
