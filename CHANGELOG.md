- apps.nix: fix Claude Desktop not opening from SUPER SHIFT+U — wrapper pointed at /home/hydragon2000/Claude_Desktop-1.18286.0-x86_64.AppImage but the AppImage had been moved into ~/Applications/ (silent keybind failure, no terminal output); update path; remove stale unmanaged ~/.local/bin/claude-desktop orphan (pre-streaming-pass wrapper, no flake source) + its lockfile
- apps.nix: fix Brave screenshare — `--ozone-platform=wayland` → `--ozone-platform-hint=auto` (hard ozone flag crashed GPU init on integrated graphics: black screen with cursor instead of portal picker), add `--disable-gpu-compositing`; flags now apply from any launcher
- theme.nix: move agent protocol symlinks from home root to ~/agents/ (AGENTS.md, GEMINI.md) — home declutter; agents reach them at ~/agents/AGENTS.md + ~/agents/GEMINI.md
- apps.nix: fix Brave+Vesktop screenshare from walker/keybind — switch Brave from pkgs.brave.override to runCommand wrapper (like vesktop) that bakes XDG_SESSION_TYPE=wayland, NIXOS_OZONE_WL=1, ELECTRON_OZONE_PLATFORM_HINT=auto into the script; add same env exports to vesktop wrapper; home.sessionVariables only reach shell-launched apps, not walker/elephant systemd scopes
- modules/home/idle.nix (new), keybinds.nix, modules/home/hyprland.nix, home.nix: add sleep system via hypridle — idle lock targets the ReGreet login page (greetd 0.9+ lock support, `loginctl lock-session`; greetd 0.10.3 + regreet 0.3.0 already on system), display off 1 min after lock, before-sleep lock on suspend so waking lands on login; default 5 min, runtime override via new ~/.local/bin/sleep-time (minutes | never, rewrites hypridle.conf + restarts user service), SUPER+S walker sleep menu (elephant menus/sleep.lua), SUPER+L lock now; hypridle runs as systemd user service started from hyprland.lua autostart

# Changelog
- apps.nix, configuration.nix: remove torrenting stack (qbittorrent, aria2, Torrent download dirs, dl/nyaa/yts CLIs) — deleted by user request; leech-only setup fully removed
- configuration.nix: add aria2 to systemPackages — dl --aria2 fallback downloader for nyaa .torrent files (replaces staged sed script from SDD session)
- theme.nix: force gtk-application-prefer-dark-theme=1 — qBittorrent 5.2.2 shows light when QT_QPA_PLATFORMTHEME=gtk3 (ColorScheme=Dark stored but GTK palette overrides); HM gtk3 extraConfig puts it in settings.ini
- apps.nix: add qbittorrent (5.2.2) + torrent download folders (Anime/Movies/Series) — leech-only torrent setup
- keybinds.nix, modules/home/hyprland.nix: Hyprland Meta Elevation — migrate config to Lua (hyprland.lua; hyprlang deprecated since 0.55), clipboard history SUPER+V (walker -m clipboard), togglefloating → SUPER+T, animations (curves snappy/smooth, global speed 10), 3-finger touchpad gestures; fix hl.monitor (output = "" + global bezier = "default") after smoke test showed 1.5x zoom + on-screen config errors
- apps.nix: restore claude-desktop wrapper (AppImage launcher + stale-socket cleanup) dropped in the streaming pass — claude:// desktop entries and PATH binary work again
- modules/home/zsh.nix, apps.nix, hyprland.nix, keybinds.nix: reverse swaync — remove notification center (package, autostart, SUPER+N) after user rejected it; restore rebuild alias → bin/rebuild so switch auto-commits + pushes via https/github-cred again
- flake.nix, apps.nix, configuration.nix, keybinds.nix, hyprland.nix: streaming/daily-drive pass — add Zen Browser (youwen5 flake, official binary, DisableAppUpdate baked; wrapped with locked Widevine CDM pref) + set as default browser; package firefox with widevine-cdm prefs (Netflix/Prime now play in both — CDM copy at ~/.widevine-cdm via home.file; Linux VMP exemption); add obs-studio, ffmpeg-full, noisetorch, swaync (autostart + SUPER+N), exfatprogs, ntfs3g (Windows USB drives); power-profiles-daemon (laptop battery slider); v4l2loopback virtual camera (exclusive_caps for OBS); keybinds SUPER+O (OBS), XF86AudioMicMute toggle
- zsh.nix: fix stale nixos-rebuild comment above bootbuild alias (nh os boot)
- configuration.nix: add nvd to systemPackages — nh 4.4.2's programs.nh module has no nvd.enable option, so the diff binary must be explicit; without it nh os switch skips package diffs
- configuration.nix, modules/home/zsh.nix, bin/rebuild: migrate update/rebuild workflow to nh (programs.nh.enable + clean, aliases → nh os switch/build/boot/clean, rebuild script engine → nh) — nvd diffs on every switch, single-command update, less bespoke shell; nix.gc timer dropped (nh module warns it conflicts with programs.nh.clean)
- apps.nix: override brave with --ozone-platform=wayland + WebRTCPipeWireCapturer — under XWayland its share picker only lists X11 windows, full-screen share impossible
- modules/home/git.nix, AGENTS.md: route all GitHub pushes over HTTPS via url.insteadOf rewrite + path-aware credential helper (~/.local/bin/github-cred) — SSH port 22 (and 443 fallback) blocked on this network, breaking git push; professional repos now rewrite git@github-professional: too

Newest first. Every commit that touches a `.nix` file MUST add an entry here
(enforced by `hooks/pre-commit`). One line per change: what and why.

- apps.nix: add cheese — webcam already works (uvcvideo loaded, video group, PipeWire); missing a GUI camera app
- apps.nix: bake Wayland screen-share flags into a `vesktop` binary wrapper (runCommand shipping bin + package icons) instead of the desktop entry — walker/elephant-launched Vesktop lost streaming flags / black-screened; wrapper guarantees --ozone-platform-hint=auto --enable-features=WebRTCPipeWireCapturer --disable-gpu-sandbox --disable-gpu-compositing from any launcher; --disable-gpu-compositing added to avoid intermittent black window on NVIDIA+Wayland (SCANOUT GBM buffer allocation failure after window close-to-tray + reopen)
- apps.nix, configuration.nix, home.nix, modules/home/drive.nix: add rclone + FUSE — Google Drive mounted at ~/Documents via systemd user service (vfs-cache full), programs.fuse.userAllowOther for non-root mounts
- configuration.nix: give greeter user video/render/input/seat/tty groups — cage/ReGreet couldn't access DRM+input devices, causing glitchy rendering and flaky login
- configuration.nix: seed /var/lib/regreet/state.toml in regreet-wallpaper service — ReGreet fell back to default login shell (tty) when no session selected; now Hyprland is pre-selected in the dropdown
- zsh.nix: restore `rebuild` alias → `/etc/nixos/bin/rebuild` (auto-commit + push) — regressed to plain `nixos-rebuild switch` in the greeter swap; script now guards hardware-configuration.nix staging behind ALLOW_HWCONFIG=1, auto-detects branch/remote/hostname, falls back to ~/.ssh/config if no personal key
- configuration.nix: swap login greeter ReGreet → greetd + tuigreet (--time --remember --cmd Hyprland) — ReGreet couldn't launch the Hyprland session after auth (session discovery issue), threw back to tty; tuigreet is a direct-command greeter, no session-discovery
- configuration.nix: drop regreet-only packages from systemPackages (imagemagick, catppuccin-gtk override, papirus-icon-theme, bibata-cursors) — no longer needed without the GTK greeter
- home.nix, modules/home: re-add quickshell as default bar via my.barChoice (waybar stays optional), start it from hyprland exec-once; drop modules/home/login.nix (regreet wallpaper-sync obsolete with tuigreet)
- apps.nix: wrap antigravity in a script that unsets NIXOS_OZONE_WL and adds --no-sandbox — app crashes on Wayland without it
- zsh.nix: rebuild alias → plain sudo nixos-rebuild switch (was bin/rebuild script)
- flake.nix, configuration.nix: pin xdg-desktop-portal-hyprland to cc8e5ef (new xdph input) — hyprland-input bundle (08d99f7) spins at ~100% CPU after screenshot/screencast (hyprwm/xdg-desktop-portal-hyprland#411, fixed in #417), overheating CPU to 75C+
- hyprland.nix: import MOZ_ENABLE_WAYLAND into systemd user manager too — Walker/uwsm-launched apps bypass the Hyprland env block, so Firefox fell back to native Wayland (10px popup slivers); now inherited via systemd scope
- home.nix, hyprland.nix: force MOZ_ENABLE_WAYLAND=0 (session vars + Hyprland env) — Firefox 153 native-Wayland popups collapse to 10px slivers (GTK layout bug, repro'd on fresh profile; XWayland renders correctly)
- hyprland.nix: import HYPRLAND_INSTANCE_SIGNATURE into systemd user manager — fixes quickshell workspace highlights (quickshell had no IPC socket env, logged "$HYPRLAND_INSTANCE_SIGNATURE is unset")
- flake.nix, configuration.nix: pin Hyprland to v0.56.1 input and override package+xdph — fixes Firefox popup sliver bug (hyprwm/Hyprland#14936, missing from nixpkgs 26.05's 0.55.4)
- home.nix: switch default bar from waybar to quickshell
- hyprland.nix, quickshell.nix: start quickshell via exec-once=systemctl --user start quickshell (graphical-session.target refuses manual start — RefuseManualStart=yes)

## 2026-07-30
- feat: udev rule in storage.nix to expose internal NTFS partitions in file-manager sidebars (UDISKS_SYSTEM=0)
- feat: storage module (modules/system/storage.nix) — NTFS (ntfs3/ntfs-3g) read-only, udisks2 + gvfs for click-to-mount drives and Android MTP phones (libmtp/jmtpfs); fixes phone-over-USB and Windows partitions not appearing in Thunar
- feat: bin/rebuild script — nixos-rebuild switch then auto-commit (via Ollama gen-commit-msg.py) and git push; rebuild alias updated to point at the script
- refactor: split home.nix into 7 focused modules under modules/home/ (hyprland, walker, waybar, theme, git, zsh, apps)
- feat: waybar managed via systemd user service instead of hyprland exec-once (survives rebuilds)
- revert: remove antigravity wrapper, use plain package
- feat: auto garbage collection (weekly, 7d retention) and nix store optimisation via systemd timers
- feat: nix-community cachix substituter for faster binary cache hits
- feat: new shell aliases — gc (garbage collect), bootbuild (safe rebuild on next boot), check (flake check)
- feat: add nix-output-monitor for readable build output
- fix: remove duplicate firefox and ollama from systemPackages (already provided by programs.firefox and services.ollama)
## 2026-07-28
- feat: nixup — curses TUI for selective flake input updating (Catppuccin Mocha theme, multi-select, dry-build, Walker entry, SUPER+U)

## 2026-07-22
- feat: add brave browser to home.packages

## 2026-07-21
- fix: add `hide_quick_activation = true` and `quick_activate = []` to Walker config to suppress F1-F4 top results
- fix: clear Walker `quick_activate` default to stop F1-F4 appearing as search results

## 2026-07-19
- feat: add `update` and `gcsize` shell aliases for flake upgrade + GC size estimate
- refactor: /etc/nixos is now the git repo root; repo/ subdir and sync.sh copy loop retired (zero-drift: the live config IS the repo)
- chore: hardware-configuration.nix is now tracked (flakes only see git-tracked files)
- feat: machine.nix isolates all machine-specific values; flake.nix validates gpu against a closed enum with a clear eval-time error
- feat: modules/hardware/ profiles (hybrid-nvidia, nvidia, amd, intel, vm, generic); configuration.nix is now fully machine-agnostic; ollama-cuda moved into nvidia profiles
- feat: bootstrap.sh — new-machine installer; sysfs-only GPU/CPU detection, numeric vendor IDs, confirm loop, generic fallback, dry-build gate before nixos-install
- feat: AGENTS.md canonical AI protocol; distributed as ~/AGENTS.md + ~/GEMINI.md symlinks via home-manager, CLAUDE.md symlink at repo root, import in ~/.claude/CLAUDE.md
- feat: committed git hooks (core.hooksPath=hooks) — identity check, CHANGELOG gate, hardware-config guard, nix syntax gate; optional Ollama commit messages
- docs: README rewritten for repo-as-truth workflow, bootstrap install, and recovery story
