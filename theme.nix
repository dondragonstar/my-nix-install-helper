rec {
  # Define the single active theme here
  active = "default";

  # Define all available themes
  themes = {
    # The default theme, preserving the existing system's appearance exactly
    default = {
      waybar = {
        background = "rgba(20, 20, 20, 0.85)";
        text = "#e5e5e5";
        item-background = "rgba(40, 40, 40, 0.85)";
        item-text = "#aaaaaa";
        active-item-background = "rgba(90, 90, 90, 0.8)";
        active-item-text = "white";
        warning = "#ffb86c";
        critical = "#ff5555";
      };
      cursor = {
        name = "Bibata-Modern-Classic";
        size = 24;
      };
    };

    # Bibata Modern Classic theme
    bibata-classic = {
      waybar = {
        background = "rgba(20, 20, 20, 0.85)";
        text = "#e5e5e5";
        item-background = "rgba(40, 40, 40, 0.85)";
        item-text = "#aaaaaa";
        active-item-background = "rgba(90, 90, 90, 0.8)";
        active-item-text = "white";
        warning = "#ffb86c";
        critical = "#ff5555";
      };
      cursor = {
        name = "Bibata-Modern-Classic";
        size = 24;
      };
    };

    # Google Dot theme
    google-dot = {
      waybar = {
        background = "rgba(20, 20, 20, 0.85)";
        text = "#e5e5e5";
        item-background = "rgba(40, 40, 40, 0.85)";
        item-text = "#aaaaaa";
        active-item-background = "rgba(90, 90, 90, 0.8)";
        active-item-text = "white";
        warning = "#ffb86c";
        critical = "#ff5555";
      };
      cursor = {
        name = "Google-Dot";
        size = 24;
      };
    };
  };

  # The active theme configuration used by system templates
  current = themes.${active};
}
