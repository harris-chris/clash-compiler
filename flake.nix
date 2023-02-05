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
    thisCompiler = "ghc924";

    clashDependenciesOverlay = final: prev:
      let
        gitIgnoreLines = final.lib.strings.splitString
          "\n" (builtins.readFile ./.gitignore);
        sourceIgnoreFunc = final.nix-gitignore.gitignoreSourcePure gitIgnoreLines;
        hsPkgsOverlay = self: super: {
          tasty-hedgehog = final.haskell.lib.overrideCabal super.tasty-hedgehog (old: {
            src = final.fetchgit {
              url = "https://github.com/qfpl/tasty-hedgehog";
              rev = "50959b2bf6fd8fdeea7d25121768058a00536484";
              sha256 = "eJBRfw1xITs2Fehfwbo4/DcjTdVBudHdedCla7Udn7w=";
            };
          });
          type-errors = final.haskell.lib.overrideCabal super.type-errors (old: {
            doCheck = false;
          });
        };
        haskellPackages = final.haskell.packages.${thisCompiler}.extend hsPkgsOverlay;
      in
      {
        inherit haskellPackages sourceIgnoreFunc;
      };

    getClashPackages = packages:
      let
        pkgs = packages.appendOverlays [ clashDependenciesOverlay ];
        clash-prelude = with pkgs.haskellPackages;
          callPackage ./clash-prelude/clash-prelude.nix {};
        clash-lib = with pkgs.thisHaskellPackages;
          callPackage ./clash-lib/clash-lib.nix { inherit clash-prelude; };
      in {
        inherit clash-prelude clash-lib;
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
        systemPkgs = import nixpkgs { inherit system; config = pkgsConfig; };
        devShell = getDevShellFromPkgs systemPkgs;
        packages = getClashPackages systemPkgs;
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
