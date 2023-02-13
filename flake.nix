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
          # hashable = self.haskell.lib.dontCheck (hself.callHackage "hashable" "1.3.0.0" {});
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

    getDevShellFromPkgs = packages:
      let
        pkgs = packages.appendOverlays [ clashDependenciesOverlay ];
        # clash-packages = getClashPackages packages;
        # buildInputs = map
        #   (key: packages.lib.attrsets.getAttr key clash-packages)
        #   (packages.lib.attrsets.attrNames clash-packages);
      in pkgs.haskellPackages.shellFor {
        name = "${thisPackageName}-devshell";
        packages = p: [ p.tasty-hedgehog p.type-errors ];
        buildInputs = with pkgs; [];
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
        devShell = getDevShellFromPkgs systemPkgs;
        clashPackages = getClashPackages systemPkgs;
        testPackages = with systemPkgs.haskellPackages; {
          inherit tasty-hedgehog;
          # base = systemPkgs.haskellPackages.base;
        };
        packages = clashPackages // testPackages;
      in {
        inherit packages;
        inherit devShell;
      };
    overlays = {};
  in
    (flake-utils.lib.eachSystem [ "x86_64-linux" ] getPerSystem) //
    {
      inherit overlays;
    };
}
