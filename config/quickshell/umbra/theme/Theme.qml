pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
 id: root
 property string accentName: "silver"
 property bool motion: true
 property bool wallpaperEnabled: true
 readonly property color background: "#080a0d"
 readonly property color shell: "#050607"
 readonly property color surface: "#121417"
 readonly property color raised: "#202328"
 readonly property color border: "#30343b"
 readonly property color text: "#e1e5e9"
 readonly property color muted: "#9299a3"
 readonly property color accent: accentName==="ice" ? "#8faebc" : accentName==="sage" ? "#9fae9d" : "#aeb8c4"
 readonly property color danger: "#c48787"
 readonly property string sans: "Inter"
 readonly property string mono: "JetBrains Mono"
 readonly property int small: 4
 readonly property int gap: 8
 readonly property int padding: 16
 readonly property int radius: 16
 readonly property int pill: 22
 readonly property int fontSize: 12
 readonly property int titleSize: 20
 readonly property int subtitleSize: 14
 readonly property int captionSize: 10
 readonly property int heroSize: 28
 readonly property int islandWidth: 248
 readonly property int islandHeight: 32
 readonly property int expandedIslandWidth: 370
 readonly property int expandedIslandHeight: 78
 readonly property int panelWidth: 420
 readonly property int launcherWidth: 520
 readonly property int panelRadius: 26
 readonly property int innerRadius: 18
 readonly property int barHeight: 48
 readonly property int duration: motion ? 220 : 0
 function save() { preferences.setText(JSON.stringify({accent:accentName,motion:motion,wallpaper:wallpaperEnabled},null,2)+"\n") }
 property FileView preferences: FileView {
  path: Quickshell.env("HOME")+"/dotfiles/config/quickshell/umbra/theme/preferences.json"
  watchChanges: true
  onFileChanged: reload()
  onLoaded: {
   try { const p=JSON.parse(text()); root.accentName=["silver","ice","sage"].includes(p.accent) ? p.accent : "silver"; root.motion=p.motion!==false; root.wallpaperEnabled=p.wallpaper!==false }
   catch(e) { console.warn("Invalid shell preferences:",e) }
  }
 }
}
