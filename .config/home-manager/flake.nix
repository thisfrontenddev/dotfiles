{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Supported systems — add more as needed
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (system: {
        name = system;
        value = f system;
      }) systems);
      # Map system to default username/homedir
      userForSystem = system:
        if builtins.match ".*-darwin" system != null
        then { username = "ericmartin"; homeDirectory = "/Users/ericmartin"; }
        else { username = "void"; homeDirectory = "/home/void"; };
    in {
      homeConfigurations = builtins.listToAttrs (map (system:
        let user = userForSystem system;
        in {
          name = user.username;
          value = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.${system};
            modules = [ ./home.nix ];
            extraSpecialArgs = { inherit user; };
          };
        }
      ) systems);
    };
}

