pragma Singleton
import QtQuick
import Quickshell
// Titan's root (set by Hyprland as TITAN_ROOT: a packaged /usr/share/titan or
// the personal checkout) and helpers for its public commands (bin/) and
// internal scripts (scripts/).
QtObject {
 readonly property string root: Quickshell.env("TITAN_ROOT") || Quickshell.env("HOME")+"/dotfiles"
 readonly property string workflow: root+"/bin/workflow"
 function bin(name) { return root+"/bin/"+name }
 function script(name) { return root+"/scripts/"+name }
}
