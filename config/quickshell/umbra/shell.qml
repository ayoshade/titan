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
  function status(): string { return JSON.stringify({panel:UiState.panel,screen:UiState.panelScreen,screens:Quickshell.screens.map(s=>s.name),accent:Theme.accentName,motion:Theme.motion,wallpaper:Theme.wallpaperEnabled}) }
  function accent(name: string): bool { if(!["silver","ice","sage"].includes(name)) return false; Theme.accentName=name; Theme.save(); return true }
  function launcher(): void { UiState.toggle("launcher") }
  function controls(): void { UiState.toggle("controls") }
  function notifications(): void { UiState.toggle("notifications") }
  function appearance(): void { UiState.toggle("appearance") }
  function media(): void { UiState.toggle("media") }
  function clock(): void { UiState.toggle("clock") }
  function connectivity(): void { UiState.toggle("connectivity") }
  function session(): void { UiState.toggle("session") }
  function close(): void { UiState.close() }
  function osd(kind: string): void { UiState.osd(kind) }
 }
 Variants { model: Quickshell.screens; Background {} }
 Variants { model: Quickshell.screens; Bar {} }
 Variants { model: Quickshell.screens; Overlay {} }
 Variants { model: Quickshell.screens; Toast {} }
}
