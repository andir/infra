{ lib, ... }:
{
  nix = {
    autoOptimiseStore = lib.mkDefault true;
    gc = {
      automatic = lib.mkDefault true;
      options = lib.mkDefault "--delete-older-than 14d";
    };
  };
}
