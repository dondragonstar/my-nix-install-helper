{ config, pkgs, lib, ... }:

let
  keybinds = import ../../keybinds.nix;

  # Escape a string for use in Lua string literals
  escapeLua = lib.replaceStrings ["\\" "\""] ["\\\\" "\\\""];

  # Human-readable key combo for the menu display
  displayKeys = b:
    let mods = b.mods or ""; in
    if mods == "" then b.key
    else "${lib.replaceStrings [" "] [" + "] mods} + ${b.key}";

  # Generate Lua table entries for the Elephant keybinds menu
  keybindsLuaEntries = lib.concatStringsSep ",\n" (map (b: ''
        {
          Text = "${escapeLua b.description}",
          Subtext = "${escapeLua (displayKeys b)}  (${b.category})",
          Value = "${escapeLua (displayKeys b)}",
        }'') keybinds.binds);

  # Map keybind type to Lua hl.bind options
  bindOpts = type:
    if type == "bindm" then ", { mouse = true }"
    else if type == "bindl" then ", { locked = true }"
    else if type == "bindel" then ", { locked = true, repeating = true }"
    else "";

  # Map hyprlang action string to hl.dsp.* dispatcher call
  # Actions are: "exec, CMD", "killactive", "togglefloating", "fullscreen",
  # "movewindow", "resizewindow", "workspace, N", "movetoworkspace, N", "exit"
  mkDispatcher = action:
    let
      parts = lib.splitString ", " action;
      cmd = builtins.head parts;
      arg = if builtins.length parts > 1 then builtins.elemAt parts 1 else "";
    in
    if cmd == "exec" then "hl.dsp.exec_cmd(\"${escapeLua arg}\")"
    else if cmd == "killactive" then "hl.dsp.window.close()"
    else if cmd == "togglefloating" then "hl.dsp.window.float({ action = \"toggle\" })"
    else if cmd == "fullscreen" then "hl.dsp.window.fullscreen()"
    else if cmd == "movewindow" then "hl.dsp.window.drag()"
    else if cmd == "resizewindow" then "hl.dsp.window.resize()"
    else if cmd == "workspace" then "hl.dsp.focus({ workspace = ${arg} })"
    else if cmd == "movetoworkspace" then "hl.dsp.window.move({ workspace = ${arg} })"
    else if cmd == "exit" then "hl.dsp.exit()"
    else "hl.dsp.exec_cmd(\"hyprctl dispatch ${escapeLua action}\")";

  # Generate a Lua hl.bind() line from a keybind entry
  mkBindLineLua = b:
    let
      type = b.type or "bind";
      modsKey = if b.mods == "" then b.key
                else "${lib.replaceStrings [" "] [" + "] b.mods} + ${b.key}";
    in
    "hl.bind(\"${escapeLua modsKey}\", ${mkDispatcher b.action}${bindOpts type})";

  hyprlandBindsLua = lib.concatStringsSep "\n" (map mkBindLineLua keybinds.binds);
in
{
  # Restore the last waypaper choice at login so wallpapers persist across
  # reboot/re-login (waypaper saves `wallpaper =` in config.ini; the old
  # autostart hardcoded wallpaper1.jpg and forgot the choice every boot).
  home.file.".local/bin/restore-wallpaper" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -u
      cfg="$HOME/.config/waypaper/config.ini"
      wp=""
      if [ -f "$cfg" ]; then
        wp="$(awk -F' = ' '$1=="wallpaper" {print $2; exit}' "$cfg" 2>/dev/null || true)"
      fi
      if [ -n "$wp" ]; then
        wp="''${wp/#\~/$HOME}"
      fi
      if [ -n "$wp" ] && [ -f "$wp" ]; then
        exec awww img "$wp"
      fi
      exec awww img "$HOME/Pictures/wallpapers_flat/wallpaper1.jpg"
    '';
  };

  # ── Hyprland config (Lua — v0.55+ native Lua config API) ──
  # NOTE: waybar is NOT started here. It runs as a systemd user service
  # (see waybar.nix) so it survives nixos-rebuild without a reboot.
  home.file.".config/hypr/hyprland.lua".text = ''
    -- Hyprland Lua config (generated from /etc/nixos/modules/home/hyprland.nix)

    -- Monitor
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    -- Autostart
    hl.on("hyprland.start", function()
        hl.exec_cmd("awww-daemon")
        hl.exec_cmd("sleep 1 && restore-wallpaper")
        hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
        -- Import Wayland display + Hyprland IPC into systemd user manager so
        -- services (quickshell) can connect to the running instance.
        -- MOZ_ENABLE_WAYLAND=0 is also imported so Walker/uwsm-launched apps
        -- (which bypass the Hyprland env block) keep Firefox on XWayland.
        hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE MOZ_ENABLE_WAYLAND")
        -- Start the quickshell status bar (via systemd so it survives rebuilds).
        -- NOTE: graphical-session.target cannot be started manually (RefuseManualStart),
        -- so we start quickshell directly instead of relying on target pull-in.
        hl.exec_cmd("systemctl --user start quickshell")
        -- Lock/idle shell + sleep-lock watcher (Omarchy-style, see lockshell.nix)
        hl.exec_cmd("systemctl --user start hydra-lock-shell")
        hl.exec_cmd("systemctl --user start hydra-sleep-lock")
        -- Walker daemon (systemd user service — self-healing; starts elephant
        -- itself. The old `uwsm app -- sh -c '...'` autostart left a dead
        -- daemon after the 2.16.2 activate/connect_changed panic, so every
        -- open was a ~3.4s cold start.)
        hl.exec_cmd("systemctl --user start walker")
        hl.exec_cmd("systemctl --user start tumblerd")
    end)

    -- Environment
    hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")
    -- Force Firefox to XWayland: native-Wayland popups (menus, suggestions)
    -- collapse to 10px slivers in FF 153 — GTK layout bug, compositor-agnostic
    hl.env("MOZ_ENABLE_WAYLAND", "0")

    -- Config sections
    hl.config({
        input = {
            kb_layout = "us",
            follow_mouse = 1,
            touchpad = {
                natural_scroll = true,
                scroll_factor = 1.0,
            },
        },
        general = {
            gaps_in = 4,
            gaps_out = 8,
            border_size = 2,
        },
        decoration = {
            rounding = 6,
        },
    })

    -- Device-specific
    hl.device({
        name = "elan0518:00-04f3:31fc-touchpad",
        scroll_factor = 1.0,
    })

    -- Gestures
    hl.gesture({
        fingers = 3,
        direction = "horizontal",
        action = "workspace",
    })

    -- Animations
    hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
    hl.curve("snappy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })
    hl.curve("smooth", { type = "bezier", points = { {0.25, 1}, {0.5, 1} } })

    hl.animation({ leaf = "windows", enabled = true, speed = 4, style = "popin 80%", bezier = "snappy" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, style = "popin 80%", bezier = "snappy" })
    hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "smooth" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4, style = "slide", bezier = "snappy" })
    hl.animation({ leaf = "layers", enabled = true, speed = 3, style = "fade", bezier = "smooth" })

    -- Keybinds (generated from keybinds.nix)
  '' + "\n" + hyprlandBindsLua + "\n" + ''

    -- Window rules
    hl.window_rule({
        name = "pavucontrol-float",
        match = { class = "^(org.pulseaudio.pavucontrol)$" },
        float = true,
        center = true,
        size = { 900, 600 },
    })
    hl.window_rule({
        name = "claude-desktop-float",
        match = { class = "^(claude-desktop)$" },
        float = true,
        center = true,
        size = { "60%", "80%" },
    })
    hl.window_rule({
        name = "waypaper-float",
        match = { class = "^(waypaper)$" },
        float = true,
        center = true,
        size = { "60%", "70%" },
    })
    hl.window_rule({
        name = "wlctl-float",
        match = { title = "^(wlctl)$" },
        float = true,
        center = true,
        size = { 900, 550 },
    })
    hl.window_rule({
        name = "bluetuith-float",
        match = { title = "^(bluetuith)$" },
        float = true,
        center = true,
        size = { 900, 550 },
    })
  '';

  # NOTE: To revert, also restore mkBindLine and hyprlandBinds from git history
  # ── ROLLBACK: uncomment this block and delete hyprland.lua above to revert ──
  # home.file.".config/hypr/hyprland.conf".text = ''
  #   monitor=,preferred,auto,1
  #
  #   exec-once = awww-daemon
  #   exec-once = sleep 1 && restore-wallpaper
  #   exec-once = hyprctl setcursor Bibata-Modern-Classic 24
  #
  #   exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE MOZ_ENABLE_WAYLAND
  #   exec-once = systemctl --user start quickshell
  #   exec-once = uwsm app -- sh -c 'systemctl --user start elephant && walker --gapplication-service'
  #   exec-once = systemctl --user start tumblerd
  #
  #   env = XCURSOR_THEME,Bibata-Modern-Classic
  #   env = XCURSOR_SIZE,24
  #   env = HYPRCURSOR_SIZE,24
  #   env = MOZ_ENABLE_WAYLAND,0
  #
  #   input {
  #     kb_layout = us
  #     follow_mouse = 1
  #     touchpad {
  #       natural_scroll = true
  #       scroll_factor = 1.0
  #     }
  #   }
  #
  #   device {
  #     name = elan0518:00-04f3:31fc-touchpad
  #     scroll_factor = 1.0
  #   }
  #
  #   gestures {
  #     workspace_swipe = true
  #     workspace_swipe_fingers = 3
  #     workspace_swipe_distance = 300
  #     workspace_swipe_cancel_ratio = 0.3
  #     workspace_swipe_create_new = false
  #   }
  #
  #   general {
  #     gaps_in = 4
  #     gaps_out = 8
  #     border_size = 2
  #   }
  #
  #   decoration {
  #     rounding = 6
  #   }
  #
  #   animations {
  #     enabled = true
  #
  #     bezier = snappy, 0.05, 0.9, 0.1, 1.0
  #     bezier = smooth, 0.25, 1, 0.5, 1
  #
  #     animation = windows, 1, 4, snappy, popin 80%
  #     animation = windowsOut, 1, 4, snappy, popin 80%
  #     animation = fade, 1, 3, smooth
  #     animation = workspaces, 1, 4, snappy, slide
  #     animation = layers, 1, 3, smooth, fade
  #   }
  #
  #   # ── Keybinds (generated from keybinds.nix) ──
  # '' + "\n" + "    # Regenerate hyprlang binds from keybinds.nix using mkBindLine" + "\n" + ''
  #   # ── Window rules ──
  #   windowrule = match:class ^(org.pulseaudio.pavucontrol)$, float on, center on, size 900 600
  #   windowrule = match:class ^(claude-desktop)$, float on, center on, size 60% 80%
  #   windowrule = match:class ^(waypaper)$, float on, center on, size 60% 70%
  #   windowrule = match:title ^(wlctl)$, float on, center on, size 900 550
  #   windowrule = match:title ^(bluetuith)$, float on, center on, size 900 550
  # '';

  # ── Keybind menu (Elephant Lua — integrated into Walker search) ──
  home.file.".config/elephant/menus/keybinds.lua".text = ''
    Name = "keybinds"
    NamePretty = "Keybinds"
    Icon = "preferences-desktop-keyboard-shortcuts"
    Cache = false
    Action = "sh -c 'echo -n %VALUE% | wl-copy && notify-send \"Keybinds\" \"Copied shortcut to clipboard\"'"

    function GetEntries()
      return {
        ${keybindsLuaEntries}
      }
    end
  '';

  # ── Alacritty ──
  home.file.".config/alacritty/alacritty.toml".source = ../../alacritty.toml;

  # ── wlctl (NetworkManager TUI) config ──
  home.file.".config/impala/config.toml".text = ''
    [keybindings]
    quit = "escape"
    toggle_power = "o"
    scan = "s"
    connect = "space"
    disconnect = "d"
    toggle_connect = "space"
    up = "up"
    down = "down"
    toggle_enable = "o"
    start = "n"
    stop = "x"
    restart = "r"
    toggle_autoconnect = "a"
    back = "backspace"
  '';
}
