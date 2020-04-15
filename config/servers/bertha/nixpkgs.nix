let
  sources = import (../../../nix/sources.nix);
  inherit (sources) bertha-nixpkgs;
in
{
  nixpkgs.pkgs = import bertha-nixpkgs {
    overlays = [
      (import ../../../nix/packages/default.nix { inherit sources; })
    ];
  };
  disabledModules = [ "system/boot/networkd.nix" ];
  imports = [
    (bertha-nixpkgs + "/nixos/modules/system/boot/networkd.nix")
  ];

  # fixup the broken mdmonitor unit by masking it
  systemd.units."mdmonitor.service".enable = false;
}
