return function(b)
 local menus={
  {"SUPER + Space","Titan menu","root"},{"SUPER + ALT + Space","Apps menu","apps"},
  {"SUPER + CTRL + E","Emojis","emojis"},{"SUPER + CTRL + C","Capture menu","capture"},
  {"SUPER + CTRL + O","Toggle menu","toggle"},{"SUPER + CTRL + H","Hardware menu","hardware"},
  {"SUPER + SHIFT + code:201","Titan menu","root"},{"SUPER + Escape","System menu","system"},
  {"SUPER + K","Keybindings","keybindings"},{"SUPER + ALT + K","Tmux keybindings","tmux-help"},
  {"SUPER + CTRL + K","Herdr keybindings","herdr-help"},{"SUPER + CTRL + Q","Calculator","calculator"},
  {"XF86Calculator","Calculator","calculator"},{"SUPER + CTRL + Space","Background switcher","background"},
  {"SUPER + CTRL + S","Share","share"},{"SUPER + CTRL + period","Transcode","transcode"},
  {"SUPER + CTRL + R","Set reminder","reminder"},{"SUPER + CTRL + ALT + R","Show reminders","reminders"},
  {"SUPER + CTRL + ALT + E","World clock","worldclock"},{"SUPER + SHIFT + CTRL + A","Agent","agent"}
 }
 for _,entry in ipairs(menus) do b.shell(entry[1],entry[2],"menu "..entry[3]) end
 b.shell("XF86PowerOff","Power menu","menu system",{locked=true})
 b.shell("SUPER + SHIFT + Space","Toggle top bar","bar")
 b.shell("SUPER + SHIFT + CTRL + Space","Theme menu","themes")
 b.task("SUPER + BackSpace","Toggle window transparency","transparency")
 b.task("SUPER + SHIFT + BackSpace","Toggle window gaps","gaps")
 b.task("SUPER + CTRL + BackSpace","Toggle single-window square aspect","square")
 b.task("SUPER + CTRL + ALT + F","Toggle full screen desktop","desktop")
 b.shell("SUPER + comma","Dismiss last notification","dismissOne")
 b.shell("SUPER + SHIFT + comma","Dismiss all notifications","dismissAll")
 b.shell("SUPER + CTRL + comma","Toggle silencing notifications","dnd")
 b.shell("SUPER + ALT + comma","Invoke last notification","invokeLast")
 b.shell("SUPER + SHIFT + ALT + comma","Open notification history","notifications")
 b.task("SUPER + CTRL + I","Toggle locking on idle (always-awake policy)","policy idle")
 b.task("SUPER + CTRL + N","Toggle nightlight","nightlight")
 b.task("SUPER + CTRL + Delete","Toggle laptop display (always-awake policy)","policy display")
 b.task("SUPER + CTRL + ALT + Delete","Toggle laptop display mirroring","mirror")
 -- The lid bindings intentionally honor this machine's explicit always-on policy.
 b.task("switch:on:Lid Switch","Lid closed: keep desktop awake","policy lid",{locked=true})
 b.task("switch:off:Lid Switch","Lid opened: keep desktop awake","policy lid",{locked=true})
 b.task("Print","Screenshot","capture screenshot")
 b.task("ALT + Print","Screenrecording","capture record")
 b.task("SUPER + ALT + code:34","Make webcam overlay smaller","webcam smaller")
 b.task("SUPER + ALT + code:35","Make webcam overlay larger","webcam larger")
 b.task("SUPER + Print","Color picker","capture color")
 b.task("SUPER + CTRL + Print","Extract text (OCR) from screenshot","capture text")
 -- Scoped picker bindings are removed by handle, never by somebody else's chord.
 local layers=0
 local selection={}
 hl.on("layer.opened",function(layer)
  if layer.namespace~="selection" then return end
  layers=layers+1
  if layers~=1 then return end
  for _,entry in ipairs({{"Return","window"},{"CTRL + Return","full"},{"Tab","next"},{"CTRL + Tab","prev"},{"Left","left"},{"Right","right"},{"Up","up"},{"Down","down"}}) do
   table.insert(selection,b.task(entry[1],"Capture selection "..entry[2],"selection "..entry[2]))
  end
 end)
 hl.on("layer.closed",function(layer)
  if layer.namespace~="selection" or layers==0 then return end
  layers=layers-1
  if layers==0 then for _,handle in ipairs(selection) do handle:unbind() end; selection={} end
 end)
 b.task("SUPER + SHIFT + CTRL + R","Clear reminders","reminder-clear")
 b.task("SUPER + CTRL + ALT + T","Show time","info time")
 b.task("SUPER + CTRL + ALT + B","Show battery remaining","info battery")
 b.shell("SUPER + CTRL + ALT + W","Toggle weather","menu weather")
 b.shell("SUPER + CTRL + A","Audio","controls")
 b.shell("SUPER + CTRL + B","Bluetooth","connectivity")
 b.shell("SUPER + CTRL + D","Display","controls")
 b.shell("SUPER + CTRL + ALT + D","Calendar","clock")
 b.shell("SUPER + CTRL + W","Network","connectivity")
 b.shell("SUPER + CTRL + P","Power","controls")
 b.task("SUPER + CTRL + T","Activity","app activity")
 for i=1,9 do b.shell("SUPER + CTRL + code:"..(i+9),"Bar panel "..i,"panelAt "..i) end
 b.bind("SUPER + CTRL + Z","Zoom in",function() hl.config({cursor={zoom_factor=(hl.get_config("cursor.zoom_factor") or 1)+1}}) end)
 b.bind("SUPER + CTRL + ALT + Z","Reset zoom",function() hl.config({cursor={zoom_factor=1}}) end)
 b.run("SUPER + CTRL + L","Lock system",os.getenv("HOME").."/dotfiles/scripts/lock")
end
