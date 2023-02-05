{ callCabal2nix, sourceIgnoreFunc, clash-prelude }:

let
  sourceExclIgnored = sourceIgnoreFunc ./.;
in
  callCabal2nix "clash-lib" ./. { inherit clash-prelude; }
