pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
 id: root
 property string paletteName: "graphite"
 property string applyError: ""
 readonly property var palettes: JSON.parse(catalog.text() || "[]")
 readonly property var palette: palettes.find(p=>p.id===paletteName) || palettes[0] || ({})
 property FileView catalog: FileView { path: Qt.resolvedUrl("palettes.json"); blockLoading: true }
 function apply(name) { if(applicator.running || !palettes.some(p=>p.id===name)) return false; applyError=""; applicator.command=[Paths.script("apply-theme"),name]; applicator.running=true; return true }
 readonly property bool applying: applicator.running
 property Process applicator: Process { stderr: StdioCollector { onStreamFinished: { if(text.trim()) root.applyError=text.trim() } } onExited: (code,status)=>{ if(code!==0 && !root.applyError) root.applyError="Theme could not be applied" } }
 property string accentName: "silver"
 property bool motion: true
 property bool wallpaperEnabled: true
 readonly property color background: palette.background || "#080a0d"
 readonly property color shell: palette.shell || "#050607"
 readonly property color surface: palette.surface || "#121417"
 readonly property color raised: palette.raised || "#202328"
 readonly property color border: palette.border || "#30343b"
 readonly property color text: palette.text || "#e1e5e9"
 readonly property color muted: palette.muted || "#9299a3"
 readonly property color accent: accentName==="custom" && Settings.values.accentCustom ? Settings.values.accentCustom : accentName==="theme" ? palette.accent || "#aeb8c4" : accentName==="ice" ? "#8faebc" : accentName==="sage" ? "#9fae9d" : "#aeb8c4"
 // Notch surface: saneAspect keeps the island pure black under every palette.
 readonly property color notch: palette.notch || "#000000"
 readonly property color danger: palette.danger || "#c48787"
 readonly property string sans: Settings.values.bodyFont || "Inter"
 readonly property string display: Settings.values.displayFont || sans
 readonly property string mono: "JetBrains Mono"
 readonly property int small: 4
 readonly property int gap: 8
 readonly property int padding: 16
 readonly property int radius: Settings.values.cornerRadius
 readonly property int pill: 22
 readonly property int fontSize: Settings.values.fontSize
 readonly property int titleSize: fontSize+8
 readonly property int subtitleSize: fontSize+2
 readonly property int captionSize: fontSize-2
 readonly property int heroSize: fontSize+16
 // Compact notch geometry measured from saneAspect's 2026-10-02 island at 1920×1080.
 readonly property int islandWidth: Settings.values.islandWidth
 readonly property int islandHeight: Settings.values.islandHeight
 readonly property bool notchMode: Settings.values.notchMode
 readonly property int notchFlare: Settings.values.notchFlare
 readonly property int islandTop: notchMode ? 0 : Settings.values.islandGap
 readonly property int islandPadding: 20
 readonly property int clockSize: 16
 // Click-expanded dashboard island (same reference, 10:36–10:49).
 readonly property int dashboardWidth: 648
 readonly property int dashboardHeight: 167
 readonly property int dashboardRadius: 30
 // Calendar morph (10:37.8–10:38.5).
 readonly property int calendarWidth: 336
 readonly property int calendarHeight: 280
 readonly property int expandedIslandWidth: 370
 readonly property int expandedIslandHeight: 78
 readonly property int panelWidth: 420
 readonly property int launcherWidth: 520
 readonly property int panelRadius: Settings.values.panelRadius
 readonly property int innerRadius: Math.max(6,panelRadius-8)
 readonly property int barHeight: 48
 // Motion timings from Settings (Motion section); zero when motion is reduced.
 readonly property bool animate: motion && !Settings.values.reduceMotion
 readonly property int duration: animate ? Settings.values.fadeMs : 0
 readonly property int movement: animate ? Settings.values.movementMs : 0
 readonly property int hover: animate ? Settings.values.hoverMs : 0
 readonly property real bounce: Settings.values.bounce/100
 // Choices live in ~/.config/titan/preferences.json; preferences-default.json ships the defaults.
 function save() { userPreferences.setText(JSON.stringify({theme:paletteName,accent:accentName,motion:motion,wallpaper:wallpaperEnabled},null,2)+"\n") }
 function load(p) {
  root.paletteName=root.palettes.some(t=>t.id===p.theme) ? p.theme : "graphite"
  root.accentName=["theme","silver","ice","sage","custom"].includes(p.accent) ? p.accent : "silver"
  root.motion=p.motion!==false; root.wallpaperEnabled=p.wallpaper!==false
 }
 function merged() { let d={}, u={}; try { d=JSON.parse(defaultPreferences.text()||"{}") } catch(e) {} try { u=JSON.parse(userPreferences.text()||"{}") } catch(e) { console.warn("Invalid preferences:",e) } return Object.assign({},d,u) }
 property FileView defaultPreferences: FileView { path: Qt.resolvedUrl("preferences-default.json"); blockLoading: true }
 property FileView userPreferences: FileView {
  path: (Quickshell.env("XDG_CONFIG_HOME")||Quickshell.env("HOME")+"/.config")+"/titan/preferences.json"
  watchChanges: true; atomicWrites: true; __printErrors: false
  onFileChanged: reload()
  onLoaded: root.load(root.merged())
  onLoadFailed: root.load(root.merged())
 }
}
