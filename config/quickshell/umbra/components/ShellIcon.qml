pragma ComponentBehavior: Bound
import QtQuick
Item {
 id: root
 property string name: "apps"
 property int size: 18
 implicitWidth: size; implicitHeight: size
 Image { anchors.fill: parent; source: Qt.resolvedUrl("../assets/icons/"+root.name+".svg"); sourceSize.width: root.size*2; sourceSize.height: root.size*2; smooth: true }
}
