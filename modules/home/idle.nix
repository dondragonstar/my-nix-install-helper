# ── Sleep-time menu (SUPER+S, Walker/Elephant) ──
#
# The hypridle+hyprlock stack this module used to own was replaced by the
# Omarchy-style quickshell system in lockshell.nix. This file keeps only the
# SUPER+S "Sleep time" menu: it calls ~/.local/bin/sleep-time (defined in
# lockshell.nix), which writes ~/.config/hypr/idle.json — the config the
# quickshell lock shell live-reloads.
{ config, pkgs, lib, ... }:

let
  homeDir = config.home.homeDirectory;
in
{
  # ── Walker / Elephant "Sleep time" menu (SUPER+S) ──
  home.file.".config/elephant/menus/sleep.lua".text = ''
    Name = "sleep"
    NamePretty = "Sleep time"
    Icon = "preferences-system-sleep"
    Cache = false
    Action = "sh -c '${homeDir}/.local/bin/sleep-time %VALUE%'"

    function GetEntries()
      return {
        { Text = "Never",        Subtext = "Disable idle lock (lid close still locks)", Value = "never" },
        { Text = "1 minute",     Subtext = "Lock after 1 min idle",                      Value = "1" },
        { Text = "2 minutes",    Subtext = "Lock after 2 min idle",                      Value = "2" },
        { Text = "5 minutes",    Subtext = "Lock after 5 min idle",                      Value = "5" },
        { Text = "10 minutes",   Subtext = "Lock after 10 min idle",                     Value = "10" },
        { Text = "15 minutes",   Subtext = "Lock after 15 min idle",                     Value = "15" },
        { Text = "30 minutes",   Subtext = "Lock after 30 min idle",                     Value = "30" },
        { Text = "60 minutes",   Subtext = "Lock after 1 hour idle",                     Value = "60" },
      }
    end
  '';
}
