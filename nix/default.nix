{ system ? builtins.currentSystem, config ? import ./config.nix }:
let
  sources = import ./sources.nix;
  overlays = import ./overlays.nix { inherit system; };
in
import sources.nixpkgs { inherit system overlays config; }
