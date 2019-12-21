{ lib, ... }:
{
  nix.nixPath = lib.mkForce [];
}
