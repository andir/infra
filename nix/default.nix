let
  sources = import ./sources.nix;

  # morph needs a newer buildGoPackage since they track nixpkgs unstable
  unstable = import sources.nixpkgs-unstable {};

  overlays = [
    (_: pkgs: { inherit (import sources.niv {}) niv; })
    (_: _: { morph = unstable.callPackage (sources.morph + "/nix-packaging") {}; })
    (_: _: { c3schedule = import sources.c3schedule {}; })
    (import ./packages { inherit sources; })
    (_: _: { nix-pre-commit-hooks = import (sources."pre-commit-hooks.nix"); })
  ];

in
import sources.nixpkgs { inherit overlays; config = {}; }
