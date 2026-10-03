local home=os.getenv("HOME")
local function run(key,cmd,opts) hl.bind(key,hl.dsp.exec_cmd(cmd),opts or {}) end
local function shell(key,method) run(key,"qs -c umbra ipc call shell "..method) end
run("SUPER + Return","kitty")
run("SUPER + E","thunar")
run("SUPER + B","firefox")
shell("SUPER + Space","launcher")
shell("SUPER + A","controls")
shell("SUPER + T","themes")
shell("SUPER + N","notifications")
shell("SUPER + SHIFT + E","session")
run("SUPER + L",home.."/dotfiles/scripts/lock")
run("Print",home.."/dotfiles/scripts/screenshot region")
run("SUPER + Print",home.."/dotfiles/scripts/screenshot full")
hl.bind("SUPER + Q",hl.dsp.window.close())
hl.bind("SUPER + V",hl.dsp.window.float({action="toggle"}))
hl.bind("SUPER + F",hl.dsp.window.fullscreen({action="toggle"}))
for _,dir in ipairs({"left","right","up","down"}) do
 hl.bind("SUPER + "..dir,hl.dsp.focus({direction=dir}))
 hl.bind("SUPER + SHIFT + "..dir,hl.dsp.window.move({direction=dir}))
end
for i=1,10 do
 hl.bind("SUPER + "..(i%10),hl.dsp.focus({workspace=i}))
 hl.bind("SUPER + SHIFT + "..(i%10),hl.dsp.window.move({workspace=i}))
end
hl.bind("SUPER + mouse:272",hl.dsp.window.drag(),{mouse=true})
hl.bind("SUPER + mouse:273",hl.dsp.window.resize(),{mouse=true})
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
