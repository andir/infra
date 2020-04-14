let
  inherit (import (../../../nix/sources.nix)) bertha-nixpkgs;
in
{
  nixpkgs.pkgs = import bertha-nixpkgs {
    overlays = [
      (import ../../../nix/packages/default.nix)
    ];
  };
  disabledModules = [ "system/boot/networkd.nix" ];
  imports = [
    (bertha-nixpkgs + "/nixos/modules/system/boot/networkd.nix")
  ];
}
