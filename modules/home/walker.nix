{ config, pkgs, lib, ... }:

{
  # ── Walker (app launcher) + Elephant (desktop indexer) ──
  # Manual setup (no HM module — clean slate per Omarchy reference).

  # Walker config (generated from Nix)
  xdg.configFile."walker/config.toml".text = ''
    force_keyboard_focus = true
    selection_wrap = true
    theme = "omarchy-default"
    additional_theme_location = "~/.local/share/omarchy/default/walker/themes/"
    hide_action_hints = true
    hide_quick_activation = true

    [keybinds]
    quick_activate = []

    [placeholders]
    "default" = { input = " Search...", list = "No Results" }

    [builtins.applications]
    launch_prefix = "uwsm app -- "
    history = true

    [columns]
    symbols = 1

    [providers]
    max_results = 256
    default = [ "desktopapplications", "websearch", "menus" ]

    # Dedicated keybinds-only provider set for SUPER+H
    [providers.sets.keybinds]
    default = ["menus"]
    empty = ["menus"]

    [[providers.prefixes]]
    prefix = "/"
    provider = "providerlist"

    [[providers.prefixes]]
    prefix = "."
    provider = "files"

    [[providers.prefixes]]
    prefix = ":"
    provider = "symbols"

    [[providers.prefixes]]
    prefix = "="
    provider = "calc"

    [[providers.prefixes]]
    prefix = "@"
    provider = "websearch"

    [[providers.prefixes]]
    prefix = "$"
    provider = "clipboard"

    # Type ? to search keybinds exclusively
    [[providers.prefixes]]
    prefix = "?"
    provider = "menus:keybinds"

    [[emergencies]]
    text = "Restart Walker"
    command = "pkill walker || true; uwsm app -- walker --gapplication-service &"
  '';

  # Theme files at the Omarchy location
  home.file.".local/share/omarchy/default/walker/themes/omarchy-default/style.css".source = ../../walker-style.css;
  home.file.".local/share/omarchy/default/walker/themes/omarchy-default/layout.xml".source = ../../walker-layout.xml;

  # Elephant config: use uwsm as launch prefix so apps get proper session activation
  xdg.configFile."elephant/elephant.toml".text = ''
    launch_prefix = "uwsm app --"
  '';

  # Elephant systemd service — ensure it starts with the graphical session
  systemd.user.services.elephant = {
    Unit = {
      Description = "Elephant launcher backend";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.elephant}/bin/elephant";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
