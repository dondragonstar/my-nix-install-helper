# Keybind data source for Hyprland.
# Each entry generates a Hyprland bind AND an entry in the rofi keybind menu.
# Add / remove entries here; home.nix auto-wires everything on rebuild.
{
  binds = [
    # ── Applications ──
    { mods = "SUPER"; key = "Return";       action = "exec, alacritty";            description = "Open terminal (Alacritty)";     category = "Applications"; }
    { mods = "SUPER"; key = "E";            action = "exec, zeditor";              description = "Open editor (Zed)";             category = "Applications"; }
    { mods = "SUPER SHIFT"; key = "U";      action = "exec, claude-desktop";       description = "Open Claude Desktop";          category = "Applications"; }

    # ── Windows ──
    { mods = "SUPER"; key = "W";            action = "killactive";                 description = "Close active window";           category = "Windows"; }
    { mods = "SUPER"; key = "V";            action = "togglefloating";             description = "Toggle floating window";        category = "Windows"; }
    { mods = "SUPER"; key = "F";            action = "fullscreen";                 description = "Toggle fullscreen";             category = "Windows"; }
    { type = "bindm"; mods = "SUPER"; key = "mouse:272";   action = "movewindow";            description = "Move window (drag)";            category = "Windows"; }
    { type = "bindm"; mods = "SUPER"; key = "mouse:273";   action = "resizewindow";           description = "Resize window (drag)";          category = "Windows"; }

    # ── Workspaces ──
    { mods = "SUPER"; key = "1";            action = "workspace, 1";               description = "Switch to workspace 1";         category = "Workspaces"; }
    { mods = "SUPER"; key = "2";            action = "workspace, 2";               description = "Switch to workspace 2";         category = "Workspaces"; }
    { mods = "SUPER"; key = "3";            action = "workspace, 3";               description = "Switch to workspace 3";         category = "Workspaces"; }
    { mods = "SUPER"; key = "4";            action = "workspace, 4";               description = "Switch to workspace 4";         category = "Workspaces"; }
    { mods = "SUPER"; key = "5";            action = "workspace, 5";               description = "Switch to workspace 5";         category = "Workspaces"; }
    { mods = "SUPER SHIFT"; key = "1";      action = "movetoworkspace, 1";         description = "Move window to workspace 1";    category = "Workspaces"; }
    { mods = "SUPER SHIFT"; key = "2";      action = "movetoworkspace, 2";         description = "Move window to workspace 2";    category = "Workspaces"; }
    { mods = "SUPER SHIFT"; key = "3";      action = "movetoworkspace, 3";         description = "Move window to workspace 3";    category = "Workspaces"; }
    { mods = "SUPER SHIFT"; key = "4";      action = "movetoworkspace, 4";         description = "Move window to workspace 4";    category = "Workspaces"; }
    { mods = "SUPER SHIFT"; key = "5";      action = "movetoworkspace, 5";         description = "Move window to workspace 5";    category = "Workspaces"; }

    # ── System ──
    { mods = "SUPER"; key = "M";            action = "exit";                       description = "Exit Hyprland (logout)";        category = "System"; }

    # ── Launchers ──
    { mods = "SUPER"; key = "Space";        action = "exec, walker";               description = "Open app launcher (Walker)";    category = "Launchers"; }

    # ── Files ──
    { mods = "SUPER SHIFT"; key = "F";      action = "exec, thunar";               description = "Open file manager (Thunar)";    category = "Files"; }
    { mods = "SUPER SHIFT"; key = "D";      action = "exec, qdirstat";             description = "Open disk usage (QDirStat)";    category = "Files"; }

    # ── Network / Bluetooth ──
    { mods = "SUPER SHIFT"; key = "W";      action = "exec, wlctl-launcher";       description = "Open network manager (wlctl)";  category = "Network"; }
    { mods = "SUPER SHIFT"; key = "B";      action = "exec, bluetuith-launcher";   description = "Open Bluetooth (Bluetuith)";    category = "Bluetooth"; }

    # ── Wallpaper ──
    { mods = "SUPER SHIFT"; key = "Space";  action = "exec, waypaper --backend swww";  description = "Open wallpaper picker";     category = "Wallpaper"; }

    # ── Screenshots ──
    { mods = "SHIFT"; key = "Print";        action = "exec, screenshot screen";    description = "Take full-screen screenshot";   category = "Screenshots"; }
    { mods = "SUPER"; key = "Print";        action = "exec, screenshot region";    description = "Take region screenshot";        category = "Screenshots"; }

    # ── Hardware (Brightness) ──
    { type = "bindel"; mods = ""; key = "XF86MonBrightnessUp";   action = "exec, brightnessctl set +5%";  description = "Increase brightness";           category = "Hardware"; }
    { type = "bindel"; mods = ""; key = "XF86MonBrightnessDown"; action = "exec, brightnessctl set 5%-";   description = "Decrease brightness";           category = "Hardware"; }

    # ── Audio ──
    { type = "bindel"; mods = ""; key = "XF86AudioRaiseVolume";  action = "exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";  description = "Raise volume";  category = "Audio"; }
    { type = "bindel"; mods = ""; key = "XF86AudioLowerVolume";  action = "exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";   description = "Lower volume";  category = "Audio"; }
    { type = "bindl";  mods = ""; key = "XF86AudioMute";         action = "exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";  description = "Toggle mute";    category = "Audio"; }

    # ── Keybind Menu (opens Walker in keybinds-only mode) ──
    { mods = "SUPER"; key = "H";            action = "exec, walker -s keybinds";   description = "Search keybinds in Walker";      category = "Keybinds"; }
  ];
}
