{
  description = "hydragon2000's NixOS + Hyprland system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wlctl.url = "github:aashish-thapa/wlctl";
    # Pin Hyprland to v0.56.1 (nixpkgs 26.05 ships 0.55.4, which has the
    # popup-subsurface scaling bug that makes Firefox menus render as slivers,
    # fixed by hyprwm/Hyprland#14936 / commit 367becc, merged after 0.55.4).
    hyprland.url = "github:hyprwm/Hyprland/v0.56.1";
    # Pin xdg-desktop-portal-hyprland past the event-loop hangup fix (#417,
    # commit c4616225, 2026-07-24) — the bundle shipped via the hyprland input
    # (rev 08d99f7, 2026-07-18) spins at ~100% CPU after a screenshot/screencast
    # (hyprwm/xdg-desktop-portal-hyprland#411), heating the CPU to 75C+.
    xdph = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland/cc8e5ef8fb2acef3db488b9a33b0c48c2a4ee204";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Walker 2.17.0 from upstream git flake (pinned rev) — 26.05 ships 2.16.2,
    # whose daemon panics in walker::activate (EditableExt::connect_changed)
    # and core-dumps at login, so no resident daemon survives and every open
    # is a ~3.4s cold start. Do NOT follow nixpkgs: the walker-git.cachix.org
    # binary (already a substituter) was built against the flake's own nixpkgs,
    # so following ours would force a source rebuild.
    walker-git = {
      url = "github:abenz1267/walker/42b3ed88abf50bc52638fb2835b7f17e3ea3ac4c";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, wlctl, hyprland, xdph, walker-git, spicetify-nix, ... }: let
    machine = import ./machine.nix;
    validGpus = [ "nvidia" "amd" "intel" "hybrid-nvidia" "vm" "generic" ];
    gpu =
      if builtins.elem machine.gpu validGpus
      then machine.gpu
      else throw ''
        machine.nix error: gpu = "${machine.gpu}" is not a valid profile.
        Valid values: ${builtins.concatStringsSep " | " validGpus}
        Fix the gpu field in /etc/nixos/machine.nix and rebuild.
      '';
    hostname = machine.hostname;
    username = machine.username;
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit hostname username machine hyprland xdph; };
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        (./. + "/modules/hardware/${gpu}.nix")
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit hostname username wlctl; walker = walker-git.packages.x86_64-linux.default; inputs = { inherit spicetify-nix; }; };
          home-manager.users.${username} = import ./home.nix;
          home-manager.backupFileExtension = "hm-backup";
        }
      ];
    };
  };
}
