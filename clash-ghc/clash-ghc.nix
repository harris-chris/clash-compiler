{ callCabal2nix, sourceIgnoreFunc, clash-prelude, clash-lib, haskell }:

let
  sourceExclIgnored = sourceIgnoreFunc ./.;
in
  haskell.lib.enableSharedExecutables
      (callCabal2nix "clash-ghc" sourceExclIgnored { inherit clash-prelude clash-lib; })
