pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
Text {
 color: Theme.text
 font.family: Theme.sans
 font.pixelSize: Theme.fontSize
 textFormat: Text.PlainText
 elide: Text.ElideRight
}
