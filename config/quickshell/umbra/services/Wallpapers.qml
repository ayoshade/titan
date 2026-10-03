pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../theme"
// Wallpapers belong to themes, as in the reference: ~/Pictures/Wallpapers/<theme>/.
// The chosen file per theme is stored in Settings ("wallpapers" map); without a
// choice the first image is used, then the bundled Blacksite landscape.
QtObject {
 id: root
 readonly property string dir: Quickshell.env("HOME")+"/Pictures/Wallpapers"
 readonly property string bundled: Paths.root+"/assets/wallpapers/blacksite.svg"
 readonly property string theme: Theme.paletteName
 property FolderListModel folder: FolderListModel {
  folder: "file://"+root.dir+"/"+root.theme
  nameFilters: ["*.jpg","*.jpeg","*.png","*.webp"]
  showDirs: false; showDotAndDotDot: false
  sortField: FolderListModel.Name
 }
 // The bundled landscape stays choosable under every theme.
 readonly property var files: { const out=[]; for(let i=0;i<folder.count;i++) out.push(folder.get(i,"filePath")); out.push(bundled); return out }
 readonly property string saved: (Settings.values.wallpapers||{})[theme] || ""
 readonly property string current: saved || files[0]
 function set(path) { const map=Object.assign({},Settings.values.wallpapers||{}); map[theme]=path; return Settings.set("wallpapers",map) }
 function url(path) { return path ? "file://"+path : "" }
}
