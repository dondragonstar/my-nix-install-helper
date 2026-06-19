{
  description = "hydragon2000's NixOS + Hyprland system";

  inputs = {
    # 26.05 "Yarara" is the current stable release as of install time.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.hydragon2000-pc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.hydragon2000 = import ./home.nix;
          home-manager.backupFileExtension = "hm-backup";
        }
      ];
    };
  };
}
