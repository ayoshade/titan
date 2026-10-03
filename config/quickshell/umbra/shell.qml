pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "theme"
import "modules"
ShellRoot {
 IpcHandler {
  target: "shell"
  function status(): string { return JSON.stringify({barVisible:UiState.barVisible,menu:UiState.menuKind,panel:UiState.panel,screen:UiState.panelScreen,screens:Quickshell.screens.map(s=>s.name),theme:Theme.paletteName,accent:Theme.accentName,motion:Theme.motion,wallpaper:Theme.wallpaperEnabled}) }
  function accent(name: string): bool { if(!["silver","ice","sage"].includes(name)) return false; Theme.accentName=name; Theme.save(); return true }
  function themes(): void { UiState.toggle("themes") }
  function wallpapers(): void { UiState.toggle("wallpapers") }
  function theme(name: string): bool { return Theme.apply(name) }
  function launcher(): void { UiState.toggle("launcher") }
  function controls(): void { UiState.toggle("controls") }
  function notifications(): void { UiState.toggle("notifications") }
  function appearance(): void { UiState.toggle("appearance") }
  function media(): void { UiState.toggle("media") }
  function clock(): void { UiState.toggle("clock") }
  function island(): void { UiState.toggleIsland("") }
  function welcome(): void { UiState.toggle("welcome") }
  function settings(section: string): void { UiState.openSettings(section) }
  function connectivity(): void { UiState.toggle("connectivity") }
  function session(): void { UiState.toggle("session") }
  function menu(kind: string): void { UiState.menu(kind) }
  function bar(): void { UiState.barVisible=!UiState.barVisible; UiState.saveShell() }
  function setBar(visible: bool): void { UiState.barVisible=visible; UiState.saveShell() }
  function dismissOne(): void { Notices.dismissOne() }
  function dismissAll(): void { Notices.dismissAll() }
  function invokeLast(): void { Notices.invokeLast() }
  function dnd(): void { UiState.dnd=!UiState.dnd }
  function cycleAudio(): void { Audio.cycleOutput() }
  function cycleMedia(): void { Media.cyclePlayer() }
  function panelAt(index: int): void {
   const panels=["connectivity","controls","clock","notifications","media","appearance","session"]
   if(index>=1 && index<=panels.length) UiState.toggle(panels[index-1])
  }
  function close(): void { UiState.close() }
  function osd(kind: string): void { UiState.osd(kind) }
 }
 Variants { model: Quickshell.screens; Background {} }
 LazyLoader { active: UiState.settingsOpen; SettingsApp {} }
 Variants { model: Quickshell.screens; Bar {} }
 Variants { model: Quickshell.screens; Overlay {} }
 Variants { model: Quickshell.screens; Toast {} }
}
