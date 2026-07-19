{
  description = "hydragon2000's NixOS + Hyprland system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wlctl.url = "github:aashish-thapa/wlctl";
  };

  outputs = { self, nixpkgs, home-manager, wlctl, ... }: let
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
      specialArgs = { inherit hostname username machine; };
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        (./. + "/modules/hardware/${gpu}.nix")
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit hostname username wlctl; };
          home-manager.users.${username} = import ./home.nix;
          home-manager.backupFileExtension = "hm-backup";
        }
      ];
    };
  };
}
