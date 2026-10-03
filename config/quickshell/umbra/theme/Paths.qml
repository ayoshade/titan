pragma Singleton
import QtQuick
import Quickshell
// Titan's root (set by Hyprland as TITAN_ROOT: a packaged /usr/share/titan or
// the personal checkout) and helpers for its scripts.
QtObject {
 readonly property string root: Quickshell.env("TITAN_ROOT") || Quickshell.env("HOME")+"/dotfiles"
 readonly property string workflow: root+"/scripts/workflow"
 function script(name) { return root+"/scripts/"+name }
}
