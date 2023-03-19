{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-22.11;
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self
    , nixpkgs
    , flake-utils
  }:
  let
    thisPackageName = "clash-compiler";
    thisCompiler = "ghc884";

    clashDependenciesOverlay = self: super:
      let
        gitIgnoreLines = self.lib.strings.splitString
          "\n" (builtins.readFile ./.gitignore);
        sourceIgnoreFunc = self.nix-gitignore.gitignoreSourcePure gitIgnoreLines;
        hsPkgsOverlay = hself: hsuper: {
          tasty-hedgehog = self.haskell.lib.overrideCabal hsuper.tasty-hedgehog (old: {
            version = "1.3.0.0";
            sha256 = "cgH47/aozdKlyB6GYF0qNyNk2PUJsdGKD3QjBSpbZLY=";
            revision = "1";
            editedCabalFile = "NEMwxJ1HoTbt0WW+fkzcRvxd96dEl0Yl6UUxYKxOjK0=";
          });
          type-errors = self.haskell.lib.overrideCabal hsuper.type-errors (old: {
            doCheck = false;
          });
        };
        haskellPackages = self.haskell.packages.${thisCompiler}.extend
          hsPkgsOverlay;
      in
      {
        inherit haskellPackages sourceIgnoreFunc;
      };

    getClashPackages = packages:
      let
        pkgs = packages.appendOverlays [ clashDependenciesOverlay ];
        clash-prelude = with pkgs.haskellPackages;
          callPackage ./clash-prelude/clash-prelude.nix {};
        clash-lib = with pkgs.haskellPackages;
          callPackage ./clash-lib/clash-lib.nix { inherit clash-prelude; };
        clash-ghc = with pkgs.haskellPackages;
          callPackage ./clash-ghc/clash-ghc.nix { inherit clash-prelude clash-lib; };
      in {
        inherit clash-prelude clash-lib clash-ghc;
      };

    getDevShell = pkgs: buildInputPackages:
      pkgs.mkShell {
        name = "clash-devshell";
        buildInputs = builtins.attrValues buildInputPackages;
        shellHook = ''
          command -v fish &> /dev/null && fish
        '';
      };

    getHaskellDevShell = pkgs: clashPackages:
      pkgs.haskellPackages.shellFor {
        packages = p: [p.clash-ghc];
        buildInputs = builtins.attrValues clashPackages;
        shellHook = ''
          command -v fish &> /dev/null && fish
        '';
      };

    getPerSystem = system:
      let
        pkgsConfig = { allowBroken = true; };
        systemPkgs = import nixpkgs {
          inherit system;
          config = pkgsConfig;
          overlays = [ clashDependenciesOverlay ];
        };
        clashPackages = getClashPackages systemPkgs;
      in {
        packages = clashPackages;
        devShell = getHaskellDevShell systemPkgs clashPackages;
      };
    overlays = {};
  in
    (flake-utils.lib.eachSystem [ "x86_64-linux" ] getPerSystem) //
    {
      inherit overlays;
    };
}
