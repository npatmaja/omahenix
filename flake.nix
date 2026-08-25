{
	description = "This is where everything begin!";

	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

		# Home manager
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		nix-darwin = {
			url = "github:nix-darwin/nix-darwin";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		herdr.url = "github:herdrdev/herdr/v0.8.2";
	};

	outputs = { self, nixpkgs, home-manager, nix-darwin, herdr, ... }:
		let
			systems = [
				"aarch64-darwin"
				"x86_64-linux"
			];

			mkHome = system:
				home-manager.lib.homeManagerConfiguration {
					pkgs = nixpkgs.legacyPackages.${system};
					extraSpecialArgs = {
						inherit herdr;
					};
					modules = [
						./machine.nix
						./home.nix
					];
				};

			forAllSystems = f:
				nixpkgs.lib.genAttrs systems (system: f system);

			mkDarwin = system:
				nix-darwin.lib.darwinSystem {
					inherit system;
					specialArgs = {
						machine = import ./machine.nix;
					};
					modules = [
						./darwin.nix
					];
				};
		in
		{
			darwinConfigurations.aarch64-darwin = mkDarwin "aarch64-darwin";

			homeConfigurations = forAllSystems mkHome;
		};
}
