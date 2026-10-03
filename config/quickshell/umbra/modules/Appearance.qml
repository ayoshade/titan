pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
ColumnLayout {
 spacing: 16
 ShellText { text: "Appearance"; font.pixelSize: Theme.titleSize }
 ShellText { text: "Graphite / Blacksite"; color: Theme.muted }
 ShellText { text: "Accent"; font.pixelSize: Theme.captionSize; color: Theme.muted }
 RowLayout {
  Repeater {
   model: ["silver","ice","sage"]
   Action { required property string modelData; text: modelData.charAt(0).toUpperCase()+modelData.slice(1); selected: Theme.accentName===modelData; onClicked: { Theme.accentName=modelData; Theme.save() } }
  }
 }
 ToggleTile { Layout.fillWidth: true; text: "Motion"; subtitle: Theme.motion ? "Soft transitions" : "Reduced motion"; symbol: "bolt"; selected: Theme.motion; onClicked: { Theme.motion=!Theme.motion; Theme.save() } }
 ToggleTile { Layout.fillWidth: true; text: "Landscape"; subtitle: Theme.wallpaperEnabled ? "Blacksite" : "Solid graphite"; symbol: "moon"; selected: Theme.wallpaperEnabled; onClicked: { Theme.wallpaperEnabled=!Theme.wallpaperEnabled; Theme.save() } }
 Item { Layout.fillHeight: true }
}
