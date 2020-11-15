{ system ? builtins.currentSystem }:
let
  sources = import ./sources.nix;
  overlays = import ./overlays.nix { inherit system; };
in
import sources.nixpkgs { inherit system overlays; config = import ./config.nix; }
