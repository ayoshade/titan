-- Titan keybindings: Omarchy-inspired window/workspace conventions.
-- Quickshell remains the desktop UI. See docs/keybindings.md for the mapping.
local home=os.getenv("HOME")
local function bind(key,action,description,opts)
 opts=opts or {}
 opts.description=description
 hl.bind(key,action,opts)
end
local function run(key,cmd,opts,description)
 bind(key,hl.dsp.exec_cmd(cmd),description or cmd,opts)
end
local function shell(key,method,description)
 run(key,"qs -c umbra ipc call shell "..method,nil,description)
end

-- Applications and shell.
run("SUPER + Return","kitty",nil,"Open terminal")
run("SUPER + SHIFT + Return","firefox",nil,"Open browser")
run("SUPER + SHIFT + B","firefox",nil,"Open browser")
run("SUPER + SHIFT + ALT + B","firefox --private-window",nil,"Open private browser")
run("SUPER + SHIFT + F","thunar",nil,"Open file manager")
run("SUPER + E","thunar",nil,"Open file manager (Titan alias)")
run("SUPER + B","firefox",nil,"Open browser (Titan alias)")
shell("SUPER + Space","launcher","Application launcher")
shell("SUPER + ALT + Space","launcher","Application launcher (Omarchy alias)")
shell("SUPER + A","controls","Control center")
shell("SUPER + CTRL + A","controls","Audio and controls")
shell("SUPER + CTRL + B","connectivity","Bluetooth and connections")
shell("SUPER + CTRL + W","connectivity","Network and connections")
shell("SUPER + CTRL + D","controls","Display and controls")
shell("SUPER + CTRL + ALT + D","clock","Calendar")
shell("SUPER + N","notifications","Notification history")
shell("SUPER + CTRL + SHIFT + Space","themes","Theme switcher")
shell("SUPER + Escape","session","Session and power menu")
shell("SUPER + SHIFT + E","session","Session menu (Titan alias)")
run("SUPER + CTRL + L",home.."/dotfiles/scripts/lock",nil,"Lock screen")
run("SUPER + L",home.."/dotfiles/scripts/lock",nil,"Lock screen (Titan alias)")
run("Print",home.."/dotfiles/scripts/screenshot region",nil,"Screenshot region")
run("SUPER + Print",home.."/dotfiles/scripts/screenshot full",nil,"Screenshot full screen")

-- Windows: close only the focused window; never bulk-close user applications.
bind("SUPER + W",hl.dsp.window.close(),"Close focused window")
bind("SUPER + Q",hl.dsp.window.close(),"Close focused window (alias)")
bind("SUPER + T",hl.dsp.window.float({action="toggle"}),"Toggle floating/tiling")
bind("SUPER + V",hl.dsp.window.float({action="toggle"}),"Toggle floating/tiling (Titan alias)")
bind("SUPER + F",hl.dsp.window.fullscreen({action="toggle"}),"Toggle fullscreen")
bind("SUPER + ALT + F",hl.dsp.window.fullscreen({mode="maximized",action="toggle"}),"Toggle maximized window")
bind("SUPER + J",hl.dsp.layout("togglesplit"),"Toggle tile split")
bind("SUPER + P",hl.dsp.window.pseudo(),"Toggle pseudo tiling")
for _,dir in ipairs({"left","right","up","down"}) do
 bind("SUPER + "..dir,hl.dsp.focus({direction=dir}),"Focus window "..dir)
 bind("SUPER + SHIFT + "..dir,hl.dsp.window.swap({direction=dir}),"Swap window "..dir)
end
bind("ALT + Tab",hl.dsp.window.cycle_next(),"Focus next window")
bind("ALT + SHIFT + Tab",hl.dsp.window.cycle_next({next=false}),"Focus previous window")
-- These paired actions intentionally share their chords: focus, then raise.
bind("ALT + Tab",hl.dsp.window.bring_to_top(),"Raise cycled window")
bind("ALT + SHIFT + Tab",hl.dsp.window.bring_to_top(),"Raise cycled window")

-- Workspaces and a scratchpad for terminals/windows kept out of the main tiles.
for i=1,10 do
 bind("SUPER + "..(i%10),hl.dsp.focus({workspace=i}),"Workspace "..i)
 bind("SUPER + SHIFT + "..(i%10),hl.dsp.window.move({workspace=i}),"Move window to workspace "..i)
 bind("SUPER + SHIFT + ALT + "..(i%10),hl.dsp.window.move({workspace=i,follow=false}),"Move window silently to workspace "..i)
end
bind("SUPER + Tab",hl.dsp.focus({workspace="e+1"}),"Next occupied workspace")
bind("SUPER + SHIFT + Tab",hl.dsp.focus({workspace="e-1"}),"Previous occupied workspace")
bind("SUPER + CTRL + Tab",hl.dsp.focus({workspace="previous"}),"Return to previous workspace")
bind("SUPER + S",hl.dsp.workspace.toggle_special("scratchpad"),"Show/hide scratchpad")
bind("SUPER + grave",hl.dsp.workspace.toggle_special("scratchpad"),"Show/hide scratchpad (alias)")
bind("SUPER + ALT + S",hl.dsp.window.move({workspace="special:scratchpad",follow=false}),"Move window to scratchpad")
bind("SUPER + SHIFT + grave",hl.dsp.window.move({workspace="special:scratchpad",follow=false}),"Move window to scratchpad (alias)")

-- Grouped windows behave like tabs; ordinary application tabs remain separate.
bind("SUPER + G",hl.dsp.group.toggle(),"Toggle window group")
bind("SUPER + ALT + G",hl.dsp.window.move({out_of_group=true}),"Remove window from group")
bind("SUPER + ALT + Tab",hl.dsp.group.next(),"Next window in group")
bind("SUPER + ALT + SHIFT + Tab",hl.dsp.group.prev(),"Previous window in group")
for _,dir in ipairs({"left","right","up","down"}) do
 bind("SUPER + ALT + "..dir,hl.dsp.window.move({into_group=dir}),"Move window into group "..dir)
end

-- Keyboard resizing uses minus/equal on this laptop's US keyboard.
bind("SUPER + minus",hl.dsp.window.resize({x=-100,y=0,relative=true}),"Resize narrower")
bind("SUPER + equal",hl.dsp.window.resize({x=100,y=0,relative=true}),"Resize wider")
bind("SUPER + SHIFT + minus",hl.dsp.window.resize({x=0,y=-100,relative=true}),"Resize shorter")
bind("SUPER + SHIFT + equal",hl.dsp.window.resize({x=0,y=100,relative=true}),"Resize taller")
bind("SUPER + mouse_down",hl.dsp.focus({workspace="e+1"}),"Next occupied workspace (wheel)")
bind("SUPER + mouse_up",hl.dsp.focus({workspace="e-1"}),"Previous occupied workspace (wheel)")
bind("SUPER + mouse:272",hl.dsp.window.drag(),"Drag window",{mouse=true})
bind("SUPER + mouse:273",hl.dsp.window.resize(),"Resize window",{mouse=true})

-- Existing hardware/media keys.
local opts={locked=true,repeating=true}
run("XF86AudioRaiseVolume",home.."/dotfiles/scripts/adjust volume up",opts)
run("XF86AudioLowerVolume",home.."/dotfiles/scripts/adjust volume down",opts)
run("XF86AudioMute",home.."/dotfiles/scripts/adjust volume mute",{locked=true})
run("XF86AudioMicMute","wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",{locked=true})
run("XF86MonBrightnessUp",home.."/dotfiles/scripts/adjust brightness up",opts)
run("XF86MonBrightnessDown",home.."/dotfiles/scripts/adjust brightness down",opts)
run("XF86AudioPlay","playerctl play-pause",{locked=true})
run("XF86AudioPause","playerctl play-pause",{locked=true})
run("XF86AudioNext","playerctl next",{locked=true})
run("XF86AudioPrev","playerctl previous",{locked=true})
