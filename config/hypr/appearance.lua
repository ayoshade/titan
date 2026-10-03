hl.config({
 general={gaps_in=5, gaps_out=14, border_size=1, layout="dwindle",
  col={active_border="rgba(8b929bff)", inactive_border="rgba(292d33ff)"}},
 decoration={rounding=16, active_opacity=1, inactive_opacity=1,
  shadow={enabled=true, range=18, render_power=3, color=0x66000000},
  blur={enabled=true, size=3, passes=1, vibrancy=0}},
 animations={enabled=true}, dwindle={preserve_split=true},
 misc={key_press_enables_dpms=true, mouse_move_enables_dpms=true,
  disable_hyprland_logo=true, force_default_wallpaper=0,
  background_color="rgba(08090bff)"},
})
hl.curve("restrained", {type="bezier", points={{0.2,0.8},{0.2,1}}})
for _,leaf in ipairs({"windows", "fade", "workspaces", "layers"}) do
 hl.animation({leaf=leaf, enabled=true, speed=2.5, bezier="restrained"})
end

-- Generated from the same palette catalog used by Quickshell and Kitty.
dofile(os.getenv("HOME").."/dotfiles/config/hypr/theme.lua")
