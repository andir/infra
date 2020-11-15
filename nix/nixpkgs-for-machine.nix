{ name, system, config ? import ./config.nix }:
let
  sources = import ./sources.nix;
  overlays = import ./overlays.nix { inherit system; };
in
if sources ? "${name}-nixpkgs" then
  import sources."${name}-nixpkgs"
  {
    inherit system;
    inherit overlays;
  }
else import ./default.nix { inherit system config; }
