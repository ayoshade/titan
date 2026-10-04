-- Exact Omarchy chords, independently implemented for Titan/Quickshell.
-- Reference: a85e29abb556816f4644cf975e98da694b486aa8. See docs/keybindings.md.
local root=TITAN_ROOT.."/"
local b={}
function b.bind(key,description,action,opts)
 opts=opts or {}; opts.description=description
 return hl.bind(key,action,opts)
end
function b.run(key,description,command,opts)
 return b.bind(key,description,hl.dsp.exec_cmd(command),opts)
end
function b.task(key,description,operation,opts)
 return b.run(key,description,root.."bin/workflow "..operation,opts)
end
function b.shell(key,description,method,opts)
 return b.run(key,description,"qs -c umbra ipc call shell "..method,opts)
end
for _,module in ipairs({"applications","tiling","utilities","clipboard","media","voxtype"}) do
 dofile(root.."config/hypr/bindings/"..module..".lua")(b)
end
-- Runtime overrides are generated from validated Titan state, never shell text.
local runtime=(os.getenv("XDG_STATE_HOME") or os.getenv("HOME").."/.local/state").."/titan/hypr-runtime.lua"
local file=io.open(runtime,"r")
if file then file:close(); dofile(runtime) end
