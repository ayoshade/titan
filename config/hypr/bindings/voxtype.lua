return function(b)
 -- Omarchy also registers dictation only when voxtype is installed.
 if os.execute("command -v voxtype >/dev/null 2>&1") then
  b.run("SUPER + CTRL + X","Toggle dictation","voxtype record toggle")
  b.run("F9","Start dictation (push-to-talk)","voxtype record start")
  b.run("F9","Stop dictation (push-to-talk)","voxtype record stop",{release=true})
 end
end
