{ config, pkgs, lib, ... }:

let
  keybinds = import ../../keybinds.nix;

  # Generate a Hyprland bind line from a keybind entry
  mkBindLine = b:
    let type = b.type or "bind"; in
    "${type} = ${b.mods}, ${b.key}, ${b.action}";

  # Human-readable key combo for the menu display
  displayKeys = b:
    let mods = b.mods or ""; in
    if mods == "" then b.key
    else "${lib.replaceStrings [" "] [" + "] mods} + ${b.key}";

  # All hyprland bind lines joined
  hyprlandBinds = lib.concatStringsSep "\n" (map mkBindLine keybinds.binds);

  # Escape a string for use in Lua string literals
  escapeLua = lib.replaceStrings ["\\" "\""] ["\\\\" "\\\""];

  # Generate Lua table entries for the Elephant keybinds menu
  keybindsLuaEntries = lib.concatStringsSep ",\n" (map (b: ''
        {
          Text = "${escapeLua b.description}",
          Subtext = "${escapeLua (displayKeys b)}  (${b.category})",
          Value = "${escapeLua (displayKeys b)}",
        }'') keybinds.binds);
in
{
  # ── Hyprland config (hyprlang — nixpkgs Hyprland is built without Lua) ──
  # NOTE: waybar is NOT started here. It runs as a systemd user service
  # (see waybar.nix) so it survives nixos-rebuild without a reboot.
  home.file.".config/hypr/hyprland.conf".text = ''
    monitor=,preferred,auto,1

    exec-once = awww-daemon
    exec-once = sleep 1 && awww img ~/Pictures/Wallpapers/wallpaper1.jpg
    exec-once = hyprctl setcursor Bibata-Modern-Classic 24

    # Import Wayland display + Hyprland IPC into systemd user manager so
    # services (quickshell) can connect to the running instance
    exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE

    # Start the quickshell status bar (via systemd so it survives rebuilds).
    # NOTE: graphical-session.target cannot be started manually (RefuseManualStart),
    # so we start quickshell directly instead of relying on target pull-in.
    exec-once = systemctl --user start quickshell

    # Walker daemon (delayed for elephant + Wayland readiness)
    # We use a small helper that ensures elephant is running before launching walker
    exec-once = uwsm app -- sh -c 'systemctl --user start elephant && walker --gapplication-service'
    exec-once = systemctl --user start tumblerd

    env = XCURSOR_THEME,Bibata-Modern-Classic
    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24

    input {
      kb_layout = us
      follow_mouse = 1
      touchpad {
        natural_scroll = true
        scroll_factor = 1.0
      }
    }

    device {
      name = elan0518:00-04f3:31fc-touchpad
      scroll_factor = 1.0
    }

    general {
      gaps_in = 4
      gaps_out = 8
      border_size = 2
    }

    decoration {
      rounding = 6
    }

    # ── Keybinds (generated from keybinds.nix) ──
  '' + "\n" + hyprlandBinds + "\n" + ''
    # ── Window rules ──
    windowrule = match:class ^(org.pulseaudio.pavucontrol)$, float on, center on, size 900 600
    windowrule = match:class ^(claude-desktop)$, float on, center on, size 60% 80%
    windowrule = match:class ^(waypaper)$, float on, center on, size 60% 70%
    windowrule = match:title ^(wlctl)$, float on, center on, size 900 550
    windowrule = match:title ^(bluetuith)$, float on, center on, size 900 550
  '';

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

  home.activation.removeStaleHyprlandLua = config.lib.dag.entryAfter ["writeBoundary"] ''
    rm -f $HOME/.config/hypr/hyprland.lua
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
