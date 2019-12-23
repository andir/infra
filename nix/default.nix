let
  sources = import ./sources.nix;
  overlays = [
    (_: pkgs: { inherit (import sources.niv {}) niv; })
    (_: pkgs: { morph = pkgs.callPackage (sources.morph + "/nix-packaging") {}; })
    (_: _: { c3schedule = import sources.c3schedule {}; })
  ];
in import sources.nixpkgs { inherit overlays; config = {}; }
