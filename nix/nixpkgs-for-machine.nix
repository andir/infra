{ name, system, config ? null }:
let
  _config = if config == null then import ./config.nix else config;
  sources = import ./sources.nix;
  overlays = import ./overlays.nix { inherit system; config = _config; };
in
if sources ? "${name}-nixpkgs" then
  import sources."${name}-nixpkgs"
  {
    inherit system overlays;
    config = _config;
  }
else import ./default.nix ({ inherit system; config = _config; })
