{ name, system, config ? null }:
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
else import ./default.nix ({ inherit system; } // (if config != null then config else { }))
