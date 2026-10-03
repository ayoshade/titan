return function(b)
 b.bind("SUPER + W","Close window",hl.dsp.window.close())
 b.bind("SUPER + Q","Close window",hl.dsp.window.close())
 b.task("CTRL + ALT + Delete","Close all windows","close-all")
 b.bind("SUPER + J","Toggle window split",hl.dsp.layout("togglesplit"))
 b.bind("SUPER + P","Pseudo window",hl.dsp.window.pseudo())
 b.bind("SUPER + T","Toggle window floating/tiling",hl.dsp.window.float({action="toggle"}))
 b.bind("SUPER + F","Full screen",hl.dsp.window.fullscreen({mode="fullscreen"}))
 b.task("SUPER + CTRL + F","Tiled full screen","tiled-fullscreen")
 b.bind("SUPER + ALT + F","Full width",hl.dsp.window.fullscreen({mode="maximized"}))
 b.task("SUPER + O","Pop window out (float & pin)","pop")
 b.task("SUPER + ALT + Home","Save window width","width save")
 b.task("SUPER + Home","Restore window width","width restore")
 b.task("SUPER + L","Toggle workspace layout","layout")
 for _,dir in ipairs({"left","right","up","down"}) do
  b.bind("SUPER + "..dir,"Focus window "..dir,hl.dsp.focus({direction=dir}))
  b.bind("SUPER + SHIFT + "..dir,"Swap window "..dir,hl.dsp.window.swap({direction=dir}))
  b.bind("SUPER + SHIFT + ALT + "..dir,"Move workspace to monitor "..dir,hl.dsp.workspace.move({monitor=dir:sub(1,1)}))
  b.bind("SUPER + ALT + "..dir,"Move window into group "..dir,hl.dsp.window.move({into_group=dir}))
 end
 for i=1,10 do
  local key="code:"..(i+9)
  b.bind("SUPER + "..key,"Switch to workspace "..i,hl.dsp.focus({workspace=tostring(i)}))
  b.bind("SUPER + SHIFT + "..key,"Move window to workspace "..i,hl.dsp.window.move({workspace=tostring(i)}))
  b.bind("SUPER + SHIFT + ALT + "..key,"Move window silently to workspace "..i,hl.dsp.window.move({workspace=tostring(i),follow=false}))
 end
 for _,key in ipairs({"S","grave"}) do
  b.bind("SUPER + "..key,"Toggle scratchpad",hl.dsp.workspace.toggle_special("scratchpad"))
 end
 for _,key in ipairs({"SUPER + ALT + S","SUPER + SHIFT + grave"}) do
  b.bind(key,"Move window to scratchpad",hl.dsp.window.move({workspace="special:scratchpad",follow=false}))
 end
 b.bind("SUPER + Tab","Next workspace",hl.dsp.focus({workspace="e+1"}))
 b.bind("SUPER + SHIFT + Tab","Previous workspace",hl.dsp.focus({workspace="e-1"}))
 b.bind("SUPER + CTRL + Tab","Former workspace",hl.dsp.focus({workspace="previous"}))
 for _,reverse in ipairs({false,true}) do
  local key=reverse and "ALT + SHIFT + Tab" or "ALT + Tab"
  b.bind(key,reverse and "Focus previous window" or "Focus next window",hl.dsp.window.cycle_next({next=not reverse}))
  b.bind(key,"Reveal active window on top",hl.dsp.window.bring_to_top())
 end
 b.bind("CTRL + ALT + Tab","Focus next monitor",hl.dsp.focus({monitor="+1"}))
 b.bind("CTRL + ALT + SHIFT + Tab","Focus previous monitor",hl.dsp.focus({monitor="-1"}))
 for _,step in ipairs({{mods="",size=100},{mods=" + ALT",size=25},{mods=" + CTRL",size=300}}) do
  for _,vertical in ipairs({false,true}) do
   for _,positive in ipairs({false,true}) do
    local delta=step.size*(positive and 1 or -1)
    local key="SUPER"..step.mods..(vertical and " + SHIFT" or "").." + code:"..(positive and 21 or 20)
    b.bind(key,"Resize "..(vertical and "vertically " or "horizontally ")..delta.."px",hl.dsp.window.resize({x=vertical and 0 or delta,y=vertical and delta or 0,relative=true}))
   end
  end
 end
 b.bind("SUPER + mouse_down","Scroll workspace forward",hl.dsp.focus({workspace="e+1"}))
 b.bind("SUPER + mouse_up","Scroll workspace backward",hl.dsp.focus({workspace="e-1"}))
 b.bind("SUPER + mouse:272","Move window",hl.dsp.window.drag(),{mouse=true})
 b.bind("SUPER + mouse:273","Resize window",hl.dsp.window.resize(),{mouse=true})
 b.bind("SUPER + G","Toggle window grouping",hl.dsp.group.toggle())
 b.bind("SUPER + ALT + G","Move window out of group",hl.dsp.window.move({out_of_group=true}))
 for _,key in ipairs({"SUPER + ALT + Tab","SUPER + CTRL + Right","SUPER + ALT + mouse_down"}) do
  b.bind(key,"Next window in group",hl.dsp.group.next())
 end
 for _,key in ipairs({"SUPER + ALT + SHIFT + Tab","SUPER + CTRL + Left","SUPER + ALT + mouse_up"}) do
  b.bind(key,"Previous window in group",hl.dsp.group.prev())
 end
 for i=1,5 do b.bind("SUPER + ALT + code:"..(i+9),"Switch to group window "..i,hl.dsp.group.active({index=i})) end
 b.task("SUPER + slash","Monitor scaling up","scale up")
 b.task("SUPER + ALT + slash","Monitor scaling down","scale down")
end
