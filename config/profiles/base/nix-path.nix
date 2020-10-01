{ lib, ... }:
{
  nix.nixPath = lib.mkForce [];
  programs.command-not-found.enable = lib.mkDefault false;
}
