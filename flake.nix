{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Claude Code, packaged and cached daily — far fresher than nixpkgs.
    # Deliberately does NOT follow our nixpkgs, so builds hit its binary cache.
    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs, claude-code }:
    let user = "edward.barnes@glean.co";
    in {
      darwinConfigurations."MacPro" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          {
            nixpkgs.overlays = [
              (final: prev: {
                claude-code = claude-code.packages.${prev.stdenv.hostPlatform.system}.default;
              })
            ];
          }
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Existing ~/.zshrc and ~/.zshenv get renamed instead of blocking the switch.
            home-manager.backupFileExtension = "pre-hm";
            home-manager.extraSpecialArgs = { inherit user; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}
