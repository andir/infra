let
  sources = import (../../../nix/sources.nix);
  inherit (sources) bertha-nixpkgs;
in
{
  nixpkgs.pkgs = import bertha-nixpkgs {
    overlays = [
      (import ../../../nix/packages/default.nix { inherit sources; system = "x86_64-linux"; })
      (self: super: {
        lego = super.lego.overrideAttrs (_: {
          patches = [
            ../../../retry.diff
          ];
        });
      })
    ];
    config = {
      # allow the mongodb that comes with unifi
      allowUnfree = true;
    };
  };

  # fixup the broken mdmonitor unit by masking it
  systemd.units."mdmonitor.service".enable = false;
}
