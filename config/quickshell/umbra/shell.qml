pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "modules"
ShellRoot {
 IpcHandler {
  target: "shell"
  function launcher(): void { UiState.toggle("launcher") }
  function controls(): void { UiState.toggle("controls") }
  function notifications(): void { UiState.toggle("notifications") }
  function session(): void { UiState.toggle("session") }
  function close(): void { UiState.close() }
  function osd(kind: string): void { UiState.osd(kind) }
 }
 Variants { model: Quickshell.screens; Background {} }
 Variants { model: Quickshell.screens; Bar {} }
 Variants { model: Quickshell.screens; Overlay {} }
 Variants { model: Quickshell.screens; Toast {} }
}
