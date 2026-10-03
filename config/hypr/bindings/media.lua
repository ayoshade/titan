return function(b)
 local repeatOpts={locked=true,repeating=true}
 local locked={locked=true}
 for _,entry in ipairs({
  {"XF86AudioRaiseVolume","Volume up","audio volume +5"},
  {"XF86AudioLowerVolume","Volume down","audio volume -5"},
  {"ALT + XF86AudioRaiseVolume","Volume up precise","audio volume +1"},
  {"ALT + XF86AudioLowerVolume","Volume down precise","audio volume -1"},
  {"XF86MonBrightnessUp","Brightness up","brightness +5"},
  {"XF86MonBrightnessDown","Brightness down","brightness -5"},
  {"SHIFT + XF86MonBrightnessUp","Brightness maximum","brightness 100"},
  {"SHIFT + XF86MonBrightnessDown","Brightness minimum","brightness 1"},
  {"ALT + XF86MonBrightnessUp","Brightness up precise","brightness +1"},
  {"ALT + XF86MonBrightnessDown","Brightness down precise","brightness -1"},
  {"XF86KbdBrightnessUp","Keyboard brightness up","keyboard-light up"},
  {"XF86KbdBrightnessDown","Keyboard brightness down","keyboard-light down"}
 }) do b.task(entry[1],entry[2],entry[3],repeatOpts) end
 for _,entry in ipairs({
  {"XF86AudioMute","Mute","audio mute"},{"XF86AudioMicMute","Mute microphone","audio mic"},
  {"XF86KbdLightOnOff","Keyboard backlight cycle","keyboard-light cycle"},
  {"XF86TouchpadToggle","Toggle touchpad","touchpad toggle"},{"XF86TouchpadOn","Enable touchpad","touchpad on"},
  {"XF86TouchpadOff","Disable touchpad","touchpad off"},{"XF86AudioNext","Next track","media next"},
  {"ALT + XF86AudioPlay","Next track","media next"},{"XF86AudioPause","Pause","media play-pause"},
  {"XF86AudioPlay","Play","media play-pause"},{"XF86AudioPrev","Previous track","media previous"},
  {"ALT + SHIFT + XF86AudioPlay","Previous track","media previous"},{"XF86Eject","Eject media","eject"},
  {"SHIFT + XF86AudioMute","Switch audio output","audio switch"},
  {"SHIFT + XF86AudioPause","Switch media source","media switch"},{"SHIFT + XF86AudioPlay","Switch media source","media switch"}
 }) do b.task(entry[1],entry[2],entry[3],locked) end
end
