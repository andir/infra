let
  sources = import ./sources.nix;
  overlays = [
    (_: pkgs: { inherit (import sources.niv {}) niv; })
    (_: pkgs: { morph = pkgs.callPackage (sources.morph + "/nix-packaging") {}; })
  ];
in import sources.nixpkgs { inherit overlays; config = {}; }
