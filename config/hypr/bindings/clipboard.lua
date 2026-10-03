return function(b)
 local function send(mods,key,terminal)
  return function()
   local window=hl.get_active_window()
   local class=window and (window.class or ""):lower() or ""
   local selected=terminal and (class=="kitty" or class=="alacritty" or class=="foot" or class=="com.mitchellh.ghostty") and "CTRL SHIFT" or mods
   hl.dispatch(hl.dsp.send_key_state({mods=selected,key=key,state="down"}))
   hl.timer(function() hl.dispatch(hl.dsp.send_key_state({mods=selected,key=key,state="up"})) end,{timeout=50,type="oneshot"})
  end
 end
 b.bind("SUPER + A","Select all",send("CTRL","A"))
 b.bind("SUPER + C","Universal copy",send("CTRL","C",true))
 b.bind("SUPER + V","Universal paste",send("CTRL","V",true))
 b.bind("SUPER + X","Universal cut",send("CTRL","X"))
 b.shell("SUPER + CTRL + V","Clipboard manager","menu clipboard")
end
