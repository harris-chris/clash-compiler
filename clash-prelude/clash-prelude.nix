{ callCabal2nix, sourceIgnoreFunc }:

let
  sourceExclIgnored = sourceIgnoreFunc ./.;
in
  callCabal2nix "clash-prelude" sourceExclIgnored {}
